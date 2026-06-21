# --- Specs + check() dispatch ---
#
# A `Spec` is a declarative verdict: tolerable bounds on observables
# (`ConservationSpec`) or on operator-RHS diffs (`OperatorRHSSpec`).
# `check(spec, target)` returns a `CheckResult` carrying the pass
# boolean and per-observable details.
#
# The same spec applies to single runs, sweeps, and comparisons via
# `check` dispatch:
#
#   * `check(spec::ConservationSpec, ::RunResult)`      — single jld2 verdict
#   * `check(spec::ConservationSpec, ::RunSweep)`       — per-row verdict vector
#   * `check(spec::OperatorRHSSpec,  ::RunComparison)`  — A/B diff verdict

export ConservationSpec, OperatorRHSSpec, CheckResult, check, passed

"""
    CheckResult(status::Symbol, details, summary)
    CheckResult(pass::Bool,     details, summary)   # binary convenience

Verdict produced by `check(spec, target)`. `status ∈ {:pass, :fail,
:indeterminate}` — three-valued so a verifier can REFUSE to judge
(precondition unmet / solver not converged) instead of emitting a false
PASS or FAIL. The binary `Bool` constructor maps `true → :pass`,
`false → :fail`, so binary specs (conservation / operator-RHS) need no
change. Use `passed(r)` (== `r.status === :pass`) for the green/not-green
question; anything non-`:pass` (fail OR indeterminate) is not green.

`details` is a vector of `(name => (got=…, bound=…, pass=…))`- or
`(name => (…, status=…))`-style entries so downstream code can format
tables or filter failures. `summary` is a human-readable description.
"""
struct CheckResult
    status::Symbol
    details::Vector{Pair{Symbol, Any}}
    summary::String

    function CheckResult(status::Symbol, details, summary)
        status in (:pass, :fail, :indeterminate) || throw(
            ArgumentError(
                "CheckResult status must be :pass/:fail/:indeterminate, " *
                "got :$status"),
        )
        new(status, details, summary)
    end
end

CheckResult(pass::Bool, details, summary) =
    CheckResult(pass ? :pass : :fail, details, summary)

"""
    passed(r::CheckResult) -> Bool

`true` iff the verdict is `:pass`. The blessed green/not-green accessor —
`:fail` and `:indeterminate` are both not-green.
"""
passed(r::CheckResult) = r.status === :pass

Base.show(io::IO, r::CheckResult) = print(
    io, "CheckResult(status=:$(r.status), $(length(r.details)) checks)"
)

"""
    ConservationSpec(; bounds...)

Tolerable bounds on RunResult observables. Each kwarg maps an
observable symbol to its upper-bound (`<`). Recognised observable
names are exactly the dispatch table in
`observable_dispatch.jl` — `:norm_drift`, `:energy_drift`,
`:energy_rel_drift`, `:Fz_drift`, `:Jz_drift`, etc.

```julia
spec = ConservationSpec(norm_drift=1e-12, energy_rel_drift=1e-6, Jz_drift=5e-2)
```

Each bound `b` is checked as `observable < b` (strict). Missing
observables on the target run produce `pass=false` with a "missing"
entry in `details` (does NOT throw — keeps batch reports running).
"""
struct ConservationSpec
    bounds::Dict{Symbol, Float64}

    ConservationSpec(; kwargs...) = new(
        Dict{Symbol, Float64}(
            Symbol(k) => Float64(v) for (k, v) in kwargs),
    )
end

"""
    OperatorRHSSpec(; tol_hpsi=1e-10, tol_per_term_E=1e-10)

Bilateral operator-RHS diff verdict (Level 10). When applied to a
RunComparison:

  * `tol_hpsi` is the relative L² tolerance on `‖Hψ_a − Hψ_b‖ / ‖Hψ_a‖`
    (both runs must have ψ + Hψ saved; if missing, the check returns
    `pass=false` with `:hpsi_missing` in details)
  * `tol_per_term_E` is the relative tolerance per E_decomp term
"""
struct OperatorRHSSpec
    tol_hpsi::Float64
    tol_per_term_E::Float64

    OperatorRHSSpec(; tol_hpsi::Real=1.0e-10, tol_per_term_E::Real=1.0e-10) = new(
        Float64(tol_hpsi), Float64(tol_per_term_E)
    )
end

# --- check dispatch ----------------------------------------------------

function check(spec::ConservationSpec, r::RunResult)
    details = Pair{Symbol, Any}[]
    all_pass = true
    for (obs, bound) in spec.bounds
        got, pass = try
            v = Float64(getproperty(r, obs))
            (v, v < bound)
        catch e
            ((missing_reason=sprint(showerror, e),), false)
        end
        all_pass &= pass
        push!(details, obs => (got=got, bound=bound, pass=pass))
    end
    summary =
        "ConservationSpec on $(basename(r.path)): " *
        (all_pass ? "PASS" : "FAIL") *
        " ($(length(spec.bounds)) bound$(length(spec.bounds) == 1 ? "" : "s"))"
    CheckResult(all_pass, details, summary)
end

function check(spec::ConservationSpec, sweep::RunSweep)
    [check(spec, r) for r in sweep.runs]
end

function check(spec::OperatorRHSSpec, c::RunComparison)
    details = Pair{Symbol, Any}[]
    all_pass = true

    # Hψ diff
    Hpsi_a = c.a.hpsi
    Hpsi_b = c.b.hpsi

    if Hpsi_a !== nothing && Hpsi_b !== nothing
        size(Hpsi_a) == size(Hpsi_b) || throw(
            ArgumentError(
                "Hψ shapes differ: $(size(Hpsi_a)) vs $(size(Hpsi_b))"),
        )
        num = sqrt(sum(abs2, Hpsi_a .- Hpsi_b))
        den = sqrt(sum(abs2, Hpsi_a))
        rel = num / max(den, 1e-30)
        hp_pass = rel < spec.tol_hpsi
        push!(details, :hpsi_rel_l2 => (
            got=rel, bound=spec.tol_hpsi, pass=hp_pass))
        all_pass &= hp_pass
    else
        push!(
            details,
            :hpsi_missing => (
                got="$(c.label_a) has Hpsi: $(Hpsi_a !== nothing); " *
                    "$(c.label_b) has Hpsi: $(Hpsi_b !== nothing)",
                bound=spec.tol_hpsi, pass=false),
        )
        all_pass = false
    end

    # Per-term E_decomp diff
    common_terms = intersect(keys(c.a.e_decomp), keys(c.b.e_decomp))
    for term in sort(collect(common_terms))
        ea = c.a.e_decomp[term]
        eb = c.b.e_decomp[term]
        denom = max(abs(ea), abs(eb), 1e-30)
        rel = abs(ea - eb) / denom
        term_pass = rel < spec.tol_per_term_E
        push!(details, Symbol("E_$term") => (
            got=rel, bound=spec.tol_per_term_E, pass=term_pass))
        all_pass &= term_pass
    end

    summary = "OperatorRHSSpec $(c.label_a) vs $(c.label_b): " *
              (all_pass ? "PASS" : "FAIL")
    CheckResult(all_pass, details, summary)
end
