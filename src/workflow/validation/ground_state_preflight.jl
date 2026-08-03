# --- One gate to call BEFORE spending compute on a ground state ---
#
# Everything here is a trap that cost real time in August 2026, encoded so the
# next person meets it as a refusal in under a second instead of as a NaN, a
# silently wrong number, or a day of measurement.
#
# WHY A FUNCTION AND NOT A DOCUMENT. Each of these was already written down
# somewhere — a config header, a docstring, a knob note — and each was walked past
# anyway, by me, while reading the file that said it. `c1_ratio`'s pole was in the
# header of the config I had open. A check that runs is the only kind that gets
# read.
#
# THE BUDGET IS THE DESIGN. Five checks, each traceable to one measurement, and a
# stated list of what is NOT checked. The temptation is to keep adding — every
# incident suggests another rule — and that produces a gate nobody can reason
# about. If a sixth check is worth more than one of these, replace one.
#
# WHAT THIS DOES NOT CHECK, and must not be read as covering:
#   * grid resolution / box size — `grid_resolution` planning is a separate tool
#   * whether `dt` is STABLE. The stability limit was bracketed at ONE point
#     (between 1e-3 and 2e-3 at c₀ ≈ 34000) and no criterion was established, so
#     this warns on the ITP error and refuses nothing on stability.
#   * the trapped state's dynamical stability, which is a trapped-BdG question
#   * anything about dynamics; this is ground states only

export ground_state_preflight, print_preflight

"""
    ground_state_preflight(; interactions, c_dd=0.0, spinor_lhy=nothing,
                             method=:itp, dt=nothing, n_steps=nothing,
                             save_every=nothing, accuracy_claim=false) -> CheckResult

Refuse, or warn about, a ground-state setup that measurement has already shown to
be broken or misleading. Returns `:fail` rather than throwing so a caller can
report it alongside other checks; `passed(r)` is the green question.

`accuracy_claim = true` means the resulting state will back a published number
rather than a smoke test — it tightens the `method` advice, because ITP's error is
a property of the SCHEME and no tolerance removes it.

```julia
r = ground_state_preflight(; interactions=ip, c_dd=EU_c_dd,
                             spinor_lhy=:polar_contact, method=:itp,
                             dt=2e-3, n_steps=40000, save_every=200)
passed(r) || error(r.summary)
```
"""
function ground_state_preflight(; interactions::InteractionParams,
    c_dd::Real=0.0, spinor_lhy=nothing, method::Symbol=:itp,
    dt::Union{Nothing, Real}=nothing, n_steps::Union{Nothing, Integer}=nothing,
    save_every::Union{Nothing, Integer}=nothing, accuracy_claim::Bool=false)
    c0 = interactions[0]
    lhy = spinor_lhy === :none ? nothing : spinor_lhy
    fails = String[]
    warns = String[]

    # 1. c₀ ≤ 0 — an ATTRACTIVE condensate. Measured: every ITP arm returned NaN.
    #    Reached by `c1_ratio < −1/F²`, where `c₀ = c_total/(1 + F²·r)` changes
    #    sign; at r = −0.05, F = 6 that is c₀ = −5859 with c₁ = +293. The pole was
    #    documented in the config header I was reading at the time.
    if c0 <= 0
        push!(
            fails,
            "c₀ = $(round(c0; sigdigits=5)) ≤ 0 — the condensate is " *
            "ATTRACTIVE and ITP diverges (measured: NaN in every arm). If this came " *
            "from a c1_ratio, note c₀ = c_total/(1 + F²·r) changes sign at r = −1/F² " *
            "(−1/36 ≈ −0.0278 for F=6); production scans stay above it.",
        )
    end

    # 2. The LHY functional has to be valid AT THIS POINT, and three of the four
    #    choices are not, in different regimes.
    if lhy in (:full_bdg, :spatial) && c_dd != 0
        push!(
            fails,
            "spinor_lhy = :$(spinor_lhy) with c_dd = $(c_dd) ≠ 0 — full_bdg " *
            "linearises around a UNIFORM mean field that an active dipole makes " *
            "dynamically unstable at every c₁, q and density scanned (c_dd = 0 gives " *
            "exactly 0; 2.11 → 319, 211 → 4371). ε_LHY is scheme-dependent there. " *
            "Ask `lhy_mean_field_max_growth` for the number at your point.",
        )
    end
    if lhy === :polar_contact && c0 <= 0
        push!(
            fails,
            "spinor_lhy = :polar_contact needs σ₀ > 0, which c₀ ≤ 0 breaks; " *
            "the closed form refuses (and used to die inside `^`).",
        )
    end
    if lhy === nothing
        push!(
            warns,
            "spinor_lhy = :none is the SHIPPED DEFAULT — a config that omits " *
            "the `lhy:` block gets it — and it is not a neutral choice: it is a " *
            "different energy functional, not the same physics minus a correction.",
        )
    end

    # 3. `save_every` gates the convergence CHECK, not just output
    #    (`itp_loop.jl:160`). Setting it above `n_steps` leaves `tol`, `tol_drho`
    #    and `final_dE` never evaluated, and the run reports `conv=false`,
    #    `dE=NaN` for a state that relaxed fine — which reads as "ran out of
    #    steps" and invites raising the cap.
    if method === :itp && save_every !== nothing && n_steps !== nothing &&
        save_every > n_steps
        push!(
            fails,
            "save_every = $(save_every) > n_steps = $(n_steps): the ITP " *
            "convergence check fires on `step % save_every == 0`, so it would NEVER " *
            "run. The result would report conv=false and dE=NaN regardless of how " *
            "well it converged.",
        )
    end

    # 4. ITP's error is the SCHEME's, not a tolerance. GFDN (Bao & Du 2004) is a
    #    first-order splitting of the constrained flow, and its converged STATE
    #    carries O(dt): 2.4e-2 in density at dt = 2e-3, Eu F=6. L-BFGS has no dt
    #    and lands 3.2e-6 from the dt→0 limit.
    if method === :itp
        msg =
            "method = :itp carries an O(dt) error IN THE CONVERGED STATE — 2.4e-2 in " *
            "density at dt = 2e-3 (Eu F=6, first order, so 10× accuracy costs 10× " *
            "steps). L-BFGS has no dt and was measured 3.2e-6 from the dt→0 limit."
        if accuracy_claim
            push!(
                fails,
                msg * " This run is marked as backing an " *
                "accuracy claim; use method = :lbfgs, or state the dt error " *
                "alongside the result.",
            )
        else
            push!(warns, msg)
        end
    end

    details = Pair{Symbol, Any}[
        :c0 => c0, :c_dd => Float64(c_dd), :spinor_lhy => spinor_lhy,
        :method => method, :dt => dt, :accuracy_claim => accuracy_claim,
    ]
    isempty(fails) || return CheckResult(:fail, details, join(fails, "  ||  "))
    isempty(warns) && return CheckResult(:pass, details, "ground-state preflight: clear")
    # Warnings are a PASS with a message, not an `:indeterminate`: the setup runs
    # and its result means something, it just carries a caveat the caller has to
    # carry with it.
    CheckResult(
        :pass, details, "ground-state preflight: passes with caveats — " *
                        join(warns, "  ||  ")
    )
end

"""
    print_preflight(r::CheckResult; io = stdout)

Human-readable form, wrapped, with the not-covered list attached — because a
green preflight is the moment someone is most likely to read it as "everything
is checked".
"""
function print_preflight(r::CheckResult; io::IO=stdout)
    println(io, passed(r) ? "PREFLIGHT: ok" : "PREFLIGHT: REFUSED")
    for line in _wrap(r.summary, 76)
        println(io, "  ", line)
    end
    println(
        io,
        """
NOT covered: grid resolution/box, whether dt is STABLE (the limit was
bracketed at one point only), the trapped state's dynamical stability, and
anything about dynamics.""",
    )
    nothing
end
