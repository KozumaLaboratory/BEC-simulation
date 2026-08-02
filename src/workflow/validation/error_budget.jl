# --- Error budget: is a numerical knob justified, or just chosen? ---
#
# Every approximation in this codebase carries a knob — a Taylor tolerance, a
# table resolution, a truncation radius, a Newton tolerance. Setting one
# correctly means comparing the error it introduces against the error the caller
# has ALREADY accepted by choosing something else (`dt`, the grid, `n_points`).
# Asking each call site to do that comparison is a design failure: the knowledge
# never fits in the caller's head, so in practice the number gets copied from
# wherever it was last seen and nobody can check it again.
#
# This is the mechanism for not doing that. An `ErrorBudget` records three
# numbers measured on the SAME observable and config:
#
#   baseline        the error already present — typically |obs(dt) − obs(dt/2)|
#                   with the approximation OFF, i.e. what the caller's own
#                   choice costs before this knob does anything
#   approximation   |obs(approx) − obs(exact)|, the knob's actual contribution
#   control         |obs(deliberately-bad) − obs(exact)|, an arm that MUST
#                   breach the criterion
#
# `check(NegligibleErrorSpec(frac), budget)` then answers whether the
# approximation is negligible — and refuses to answer when it cannot mean
# anything:
#
#   :indeterminate  the baseline is degenerate (nothing to be negligible
#                   against), or THE CONTROL DOES NOT BREACH. In the second case
#                   a `:pass` would say "this comparison cannot fail", not "the
#                   approximation is good".
#   :fail           the approximation is not negligible.
#   :pass           it is, and the criterion was reachable.
#
# The control being MANDATORY is the whole point, and it is not hypothetical: it
# rejected TWO gates written for `SPIN_TAYLOR_TOL` before one stood up.
#
#   1. Control = loosen the tolerance. Cannot breach — the Taylor degree is
#      floored at 2, so at production rotation angles the schedule returns 2 for
#      every tolerance over ten decades, and that floor alone already passed.
#   2. Control = lower the floor to 1. ALSO cannot breach — an order-1 rotation
#      is still ~1e-8 relative, four orders inside the splitting error. So the
#      criterion is not held by the floor either, which is what had been claimed
#      after (1) and is retracted here.
#
# What holds it is that the rotation angle is tiny: the rotation is not the
# binding error at ANY order ≥ 1. The control that worked removes the operator
# outright, and that is the general form — show the observable MOVES when the
# operator is absent, or "negligible" was never a claim about anything.
#
# Both wrong controls would have shipped as green gates asserting nothing, and
# would have been reported as "the criterion holds". Here that outcome is
# `:indeterminate` by construction rather than a silent pass.
#
# WHAT THIS DOES NOT DO. Three preconditions, none of which it can check for you:
#
#   1. an EXACT reference must exist, or `approximation` is not separable from
#      everything else that differs;
#   2. the baseline must be the error that actually dominates, and must be one
#      the caller already chose — otherwise the ratio compares nothing;
#   3. `observable` must be the quantity you care about. Negligible in energy is
#      not negligible in a winding number. This is the precondition that gets
#      missed.
#
# And the ratio is generally NOT scale-free: if the baseline is a splitting
# error ~dt² while the approximation accumulates over ~1/dt substeps, the ratio
# grows as dt⁻³. A budget belongs to the configuration it was measured at.

export ErrorBudget, NegligibleErrorSpec, measure_error_budget

"""
    ErrorBudget(; label, baseline, approximation, control, kwargs...)

Three errors on one observable and one config: what the caller already accepted
(`baseline`), what the approximation adds (`approximation`), and what a
deliberately-degraded arm adds (`control`). `rows` optionally carries a knob
sweep — `(knob, error, cost)` NamedTuples — for reporting.
"""
struct ErrorBudget
    label::String
    baseline::Float64
    baseline_label::String
    approximation::Float64
    approximation_label::String
    control::Float64
    control_label::String
    rows::Vector{NamedTuple}
end

function ErrorBudget(;
    label::String,
    baseline::Real,
    approximation::Real,
    control::Real,
    baseline_label::String="already accepted",
    approximation_label::String="approximation",
    control_label::String="control",
    rows::Vector{<:NamedTuple}=NamedTuple[],
)
    ErrorBudget(label, Float64(baseline), baseline_label,
        Float64(approximation), approximation_label,
        Float64(control), control_label, Vector{NamedTuple}(rows))
end

"""
    NegligibleErrorSpec(frac = 1e-3)

The approximation must contribute less than `frac` of the baseline error.

`frac` is the only judgement left, and it is a cheap one: it says how much of
the error budget the approximation is allowed to occupy, not what any physical
tolerance should be. 1e-3 means "at most a tenth of a percent of an error the
caller already lives with".
"""
struct NegligibleErrorSpec
    frac::Float64
    NegligibleErrorSpec(frac::Real=1.0e-3) =
        frac > 0 ? new(Float64(frac)) :
        throw(ArgumentError("frac must be > 0, got $frac"))
end

function check(spec::NegligibleErrorSpec, b::ErrorBudget)
    bound = spec.frac * b.baseline
    details = Pair{Symbol, Any}[
        :baseline => (got=b.baseline, label=b.baseline_label),
        :approximation => (got=b.approximation, bound=bound,
            pass=b.approximation < bound, label=b.approximation_label),
        :control => (got=b.control, bound=bound,
            breaches=b.control >= bound, label=b.control_label),
        :ratio => (got=b.baseline > 0 ? b.approximation / b.baseline : NaN,),
    ]

    if !(b.baseline > 0) || !isfinite(b.baseline)
        return CheckResult(:indeterminate, details,
            "$(b.label): baseline error is $(b.baseline) — there is nothing for the " *
            "approximation to be negligible against, so no verdict is possible.")
    end
    if !(b.control >= bound)
        return CheckResult(:indeterminate, details,
            "$(b.label): the control ($(b.control_label), error $(b.control)) does NOT " *
            "breach $(spec.frac)×baseline = $bound. A pass would mean the comparison " *
            "cannot fail, not that the approximation is good — pick a control that " *
            "attacks whatever actually holds the criterion.")
    end

    pass = b.approximation < bound
    CheckResult(pass, details,
        "$(b.label): approximation error $(b.approximation) " *
        (pass ? "<" : "≥") * " $(spec.frac)×baseline = $bound " *
        "(ratio $(b.baseline > 0 ? b.approximation / b.baseline : NaN)); " *
        "control breaches at $(b.control).")
end

"""
    measure_error_budget(; label, exact, refined, approx, control, kwargs...)

Run the four arms and assemble an [`ErrorBudget`](@ref). Each argument is a
zero-argument closure returning the observable as a real number:

* `exact`    — the approximation switched OFF, at the caller's configuration
* `refined`  — the same, at a refined configuration (finer `dt`, finer grid, …).
  `|exact − refined|` is the baseline: the error the caller's own choice carries.
* `approx`   — the approximation ON, at the caller's configuration
* `control`  — a deliberately degraded arm that must breach the criterion

`sweep` optionally maps knob values to closures for a reported (non-judged)
table of `(knob, error, cost)`.
"""
function measure_error_budget(;
    label::String,
    exact::Function,
    refined::Function,
    approx::Function,
    control::Function,
    baseline_label::String="refinement",
    approximation_label::String="approximation",
    control_label::String="control",
    sweep=nothing,
)
    o_exact = Float64(exact())
    o_refined = Float64(refined())
    o_approx = Float64(approx())
    o_control = Float64(control())

    rows = NamedTuple[]
    if sweep !== nothing
        for (knob, f) in sweep
            t0 = time_ns()
            o = Float64(f())
            push!(rows, (knob=knob, error=abs(o - o_exact), cost=elapsed_s(t0)))
        end
    end

    ErrorBudget(;
        label,
        baseline=abs(o_refined - o_exact), baseline_label,
        approximation=abs(o_approx - o_exact), approximation_label,
        control=abs(o_control - o_exact), control_label,
        rows,
    )
end
