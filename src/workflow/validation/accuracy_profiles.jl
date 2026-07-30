# --- Named accuracy profiles: reference / production / fast ---
#
# Two settings a config author should be able to ask for by name — "as accurate
# as this code gets" and "as fast as measurement licenses" — without having to
# know which knobs exist, which direction each one points, or what each costs.
#
# The profiles are DERIVED from `ACCURACY_KNOBS`, not written out beside it. That
# is the part that makes them hard to get wrong: adding an approximation to the
# registry makes it appear in all three profiles at once, so a new knob cannot be
# silently absent from `:reference`, and `:fast` cannot contain a knob whose trade
# nobody measured because it is built from the registry's `fast` field, which is
# `nothing` unless a measurement exists.
#
#   :reference   every knob at its most accurate setting
#   :production  the shipped defaults
#   :fast        SOLVED from a stated error budget, not hand-picked
#
# THE SPEED PROFILE IS A SOLUTION, NOT A LIST. `accuracy_profile_for_budget(frac)`
# takes each knob's measured `ladder` of `(value, rel_error, rel_cost)` and picks
# the cheapest entry whose `rel_error` is at most `frac ×` the error the DEFAULT
# setting already carries. Nobody decides that a trade is acceptable — including
# me, which matters, because the first version of this file had a hand-picked
# `fast` field and I put `ddi_pad_factor = 1.5` in it. That value's 1.9e-2
# residual is 4.4× the 4.3e-3 pad 2 already carries, i.e. it violates the
# criterion in `error_budget.jl`'s own header. The budget rule rejects it at any
# `frac ≤ 1`; the hand-picked field did not.
#
# WHAT THE MEASUREMENT SAYS TODAY: nothing moves. Measured on an H100 at 32³, Eu
# F=6 (`bench/accuracy_knob_cost.jl`), one ITP step against production 0.456 ms:
#
#   spinor_lhy = :polar_contact   0.987×   free — no speed to buy
#   spinor_lhy = :full_bdg        0.997×   free (since the fused diagonal took tables)
#   secular_ddi = true            0.986×   free — so no speed reason to approximate
#   ddi_pad_factor = 1.5          0.906×   the only real speedup, and it FAILS the budget
#   ddi_pad_factor = 3.0          1.507×   the price of :reference
#   spin_taylor = false           1.613×   the price of :reference
#   dealias_2_3 = true            1.484×   the price of being right about aliasing
#
# So the accuracy knobs are where accuracy is PAID FOR, not where speed is hiding.
# `:fast` comes out equal to `:production`, and that is the honest answer rather
# than a name with nothing behind it. The mechanism is what matters: if someone
# later measures a defensible rung, it enters without anyone choosing.
#
# COMPOSITION IS NOT MEASURED. The costs above are one knob at a time. A profile
# changes several, and they overlap (pad and dealias both add FFTs), so the
# profile's cost is NOT the product of its rows. `:reference` is measured as a
# whole by the bench's profile rows, never inferred from the per-knob ones.
#
# THREE THINGS THAT STILL NEED A HUMAN.
#
# 1. Only `ddi_pad_factor` has a ladder — both halves measured. Every other knob
#    is missing the error half, the cost half, or both, and a knob with no ladder
#    cannot move. That is a gap in the data, not a property of the knobs.
#
# 2. A profile sets `:per_run` knobs. The `:global` ones are `Ref`s; use
#    `with_reference_accuracy` for those. `accuracy_profile_report` says so rather
#    than letting the name imply full coverage.
#
# 3. `:reference` has PRECONDITIONS the value alone cannot express, and they are
#    what cost a day. `spinor_lhy = :full_bdg` tabulates ε_LHY from the
#    peak-density spinor of the state the workspace is built with, and
#    `FullBdGLHY` is scheme-dependent wherever that mean field is dynamically
#    unstable. Two separate measurements, both via `lhy_mean_field_max_growth`
#    (`bench/lhy_stability_scan.jl`, `bench/phase_gap_error_budget.jl`):
#
#      * a RAW SEED tabulates from an unrelaxed configuration — max Im ω = 1040 at
#        Eu F=6 32³ from `:flower`. Relaxing first cuts that to ≈ 9.8, two orders
#        better.
#      * and it does not reach zero, because the DIPOLE is what makes it nonzero.
#        Scaled c_dd at Eu F=6, n₀ = 1, c₁/c₀ = 0.05: c_dd = 0 gives EXACTLY 0,
#        and every nonzero c_dd is unstable, roughly linearly (2.11 → 319,
#        21.1 → 1060, 211 → 4371 for polar). Scanned over c₁/c₀ ∈ [−0.1, 0.1] and
#        q ∈ {0, 1e-3, 1e-2}: not one stable point. Over n₀ ∈ [0.01, 10]:
#        max Im ω is exactly linear in n₀ with no crossing, which is what
#        |Im ω| = n|λ_min| looks like — so no working density escapes it either.
#
#    So at Eu F=6 with the real c_dd, `:reference` has NO valid instance, and
#    "relax first" is not a workaround. `check_accuracy_preconditions` takes
#    `c_dd` and refuses on it. That makes the reference profile honest at the cost
#    of leaving the dipolar production problem without one — which is the true
#    state of affairs, and is the same fact as issue #172 seen from another side:
#    the term that is 97 % of the Eu F=6 total energy is built on a linearisation
#    with no stable point.
#
#    SCOPE. This is a statement about the UNIFORM (local-density) mean field every
#    tabulated LHY is built from, not about the trapped texture. A trap and a
#    texture's own gradients gap the low-k modes; whether the trapped state is
#    stable is a trapped-BdG question and a different instrument
#    (`solvers/hessian`'s λ_min). What is measured here is that the construction
#    of ε_LHY is ill-posed at Eu, not that the ground state does not exist.

export ACCURACY_PROFILE_NAMES, DEFAULT_ERROR_BUDGET_FRAC,
    accuracy_profile, accuracy_profile_for_budget, accuracy_profile_report,
    check_accuracy_preconditions

const ACCURACY_PROFILE_NAMES = (:reference, :production, :fast)

"""Default budget for `:fast`: a looser setting may add at most this fraction of
the error the production setting already carries. 1.0 means "no worse than what
we already accept" — deliberately generous, and even so nothing currently
qualifies."""
const DEFAULT_ERROR_BUDGET_FRAC = 1.0

"""
    accuracy_profile_for_budget(frac = DEFAULT_ERROR_BUDGET_FRAC) -> NamedTuple

The fastest admissible per-run settings: for each knob, the cheapest rung of its
measured `ladder` whose `rel_error` is at most `frac ×` the error its DEFAULT
setting already carries. A knob with no ladder keeps its default — no ladder means
no measurement, and an unmeasured trade is not a trade.

This is what `:fast` is. It is solved, not chosen.
"""
function accuracy_profile_for_budget(frac::Real=DEFAULT_ERROR_BUDGET_FRAC)
    frac > 0 || throw(ArgumentError("budget frac must be > 0, got $frac"))
    per_run = filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
    vals = map(per_run) do k
        isempty(k.ladder) && return k.default
        bound = frac * k.accepted_error
        admissible = filter(r -> r.rel_error <= bound, k.ladder)
        isempty(admissible) && return k.default
        argmin(r -> r.rel_cost, admissible).value
    end
    NamedTuple{Tuple(k.name for k in per_run)}(Tuple(vals))
end

"""
    accuracy_profile(name) -> NamedTuple

The `:per_run` settings for a named profile, keyed by knob name — pass them to
`make_workspace` or write them into a spec. Derived from [`ACCURACY_KNOBS`], so
every registered knob is present by construction.

```julia
p = accuracy_profile(:reference)
ws = make_workspace(; grid, atom, interactions, sim_params, psi_init,
                    enable_ddi=true, c_dd,
                    ddi_padding=p.ddi_padding, ddi_pad_factor=p.ddi_pad_factor,
                    secular_ddi=p.secular_ddi, spinor_lhy=p.spinor_lhy)
```
"""
function accuracy_profile(name::Symbol)
    name in ACCURACY_PROFILE_NAMES || throw(
        ArgumentError(
            "unknown accuracy profile :$name; expected one of $ACCURACY_PROFILE_NAMES"),
    )
    # `:fast` is not a list of values — it is the budget solution, so it is
    # delegated rather than duplicated here.
    name === :fast && return accuracy_profile_for_budget()
    per_run = filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
    vals = map(per_run) do k
        name === :reference ? k.reference : k.default
    end
    NamedTuple{Tuple(k.name for k in per_run)}(Tuple(vals))
end

"""
    accuracy_profile_report(name; io = stdout)

Print what a profile sets, what it differs from production on, and what that
difference costs — plus the two things it does not cover (`:global` knobs and the
`:reference` precondition).
"""
function accuracy_profile_report(name::Symbol; io::IO=stdout)
    p = accuracy_profile(name)
    prod = accuracy_profile(:production)
    println(io, "accuracy profile :$name  (per-run knobs only)")
    println(io, "="^78)
    for k in filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
        v = getfield(p, k.name)
        mark = isequal(v, getfield(prod, k.name)) ? " " : "*"
        println(io, "  $mark $(k.name) = $(repr(v))")
    end
    changed = [
        k for k in filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
        if !isequal(getfield(p, k.name), getfield(prod, k.name))
    ]
    if isempty(changed)
        println(io, "\n  (identical to :production)")
    else
        println(io, "\n  * differs from :production — what each trade costs:")
        for k in changed
            println(
                io, "    $(k.name): $(repr(getfield(prod, k.name))) → $(repr(getfield(p, k.name)))"
            )
            for line in _wrap(k.note, 66)
                println(io, "        $line")
            end
        end
    end
    println(
        io,
        """

NOT set by this profile:
  * the :global knobs ($(join((string(k.name) for k in ACCURACY_KNOBS if k.scope === :global), ", "))).
    Use `with_reference_accuracy(f)` for those.
  * the :reference preconditions — call `check_accuracy_preconditions(name;
    relaxed_initial_state, c_dd)` before trusting a reference run.
    `spinor_lhy = :full_bdg` tabulates from a uniform BdG spectrum, which is
    dynamically unstable (⇒ ε_LHY scheme-dependent) in two cases: a raw seed
    rather than a relaxed state, and — measured at Eu F=6, unfixable by any
    relaxation — ANY nonzero c_dd. So :reference has no valid instance for a
    dipolar gas; quote the closed form you used and its own residual.""",
    )
    nothing
end

"""
    check_accuracy_preconditions(name; relaxed_initial_state::Bool, c_dd = 0.0)
        -> CheckResult

Whether a profile's assumptions hold for how it is about to be used.

`:reference` requires `spinor_lhy = :full_bdg`, which tabulates ε_LHY from the
peak-density spinor of the state the workspace is built with — and is
scheme-dependent wherever that mean field is dynamically unstable, because the
zero-point sum drops the complex branches while the counterterms still subtract
all `D` of them. Two independent ways to land there, and the second one is fatal:

  * an UNRELAXED initial state. Measured max Im ω = 1040 from a `:flower` seed at
    Eu F=6 32³; relaxing with `lhy = none` first brings it to ≈ 9.8.
  * an ACTIVE DIPOLE, which cannot be relaxed away. `c_dd = 0` gives exactly
    zero; every nonzero `c_dd` is unstable, roughly linearly in it, at every
    `c₁/c₀ ∈ [−0.1, 0.1]`, every `q ∈ {0, 1e-3, 1e-2}` and every
    `n₀ ∈ [0.01, 10]` scanned (`bench/lhy_stability_scan.jl`). So there is no
    stable point to move to, and this returns `:fail` rather than advice.

`c_dd` defaults to 0 so a non-dipolar caller is unaffected; pass the real value
and a dipolar `:reference` run is refused before it is spent.

Returns `:fail` rather than throwing, so a caller can report it alongside other
checks; `passed(r)` is the green/not-green question.
"""
function check_accuracy_preconditions(name::Symbol; relaxed_initial_state::Bool,
    c_dd::Real=0.0)
    p = accuracy_profile(name)
    needs_stable = hasproperty(p, :spinor_lhy) && p.spinor_lhy === :full_bdg
    details = Pair{Symbol, Any}[
        :profile => (got=name,),
        :spinor_lhy => (got=hasproperty(p, :spinor_lhy) ? p.spinor_lhy : nothing,
            needs_stable_mean_field=needs_stable),
        :relaxed_initial_state => (got=relaxed_initial_state,),
        :c_dd => (got=Float64(c_dd),),
    ]
    # The dipole comes FIRST: it is the unfixable one, and reporting the
    # relaxation advice for a dipolar run would send the caller after a
    # workaround that has been measured not to work.
    if needs_stable && c_dd != 0
        return CheckResult(:fail, details,
            ":$name uses spinor_lhy = :full_bdg with c_dd = $(Float64(c_dd)) ≠ 0. " *
            "full_bdg tabulates ε_LHY from a uniform BdG spectrum, and an active " *
            "dipole makes that spectrum dynamically unstable at every c₁, q and " *
            "density scanned at Eu F=6 (c_dd = 0 gives exactly 0; 2.11 → 319, " *
            "21.1 → 1060, 211 → 4371), so ε_LHY is scheme-dependent and no " *
            "relaxation or tolerance reaches a stable point. There is currently " *
            "NO reference LHY for a dipolar spinor gas — the closed forms do not " *
            "detect this but are not derived for an unstable mean field either. " *
            "Quote the closed form you used and its own residual instead of " *
            "claiming a reference. Scope: this is the uniform local-density mean " *
            "field, not the trapped state.")
    end
    if needs_stable && !relaxed_initial_state
        return CheckResult(:fail, details,
            ":$name uses spinor_lhy = :full_bdg, which tabulates ε_LHY from the " *
            "peak-density spinor of the state the workspace is built with. The " *
            "initial state is not relaxed, so the table would come from a " *
            "dynamically-unstable configuration where ε_LHY is scheme-dependent " *
            "(measured max Im ω = 1040 on a raw seed at Eu F=6 32³, against ≈ 9.8 " *
            "after relaxing). Relax first with lhy = none or a closed form, then " *
            "rebuild the workspace from that ψ and re-converge.")
    end
    CheckResult(:pass, details, ":$name preconditions hold")
end
