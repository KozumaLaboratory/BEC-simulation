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
#   * whether `dt` is STABLE. Measured across the production c₀ range and
#     `c₀·dt < const` does NOT hold — the two bracketed points differ 4.7× and
#     four of six are unbounded by the ladder — so there is no rule to refuse on.
#     What the measurement DID settle is why: at fixed c₀, making the physical
#     combination `c₀ + F²c₁` seven times larger left the limit unchanged (1.0e-3
#     both ways), so the limit is set by SUBSTEP MAGNITUDE, not by the interaction.
#     Near the `−1/F²` pole c₀ is large only because c₀ and c₁ blow up while
#     cancelling, and there LOWERING dt refines an ill-conditioned splitting rather
#     than improving the physics. That is a warning below.
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

    # 1. c₀ ≤ 0 is an ATTRACTIVE condensate. That is legitimate physics — bright
    #    solitons, quantum droplets — and a droplet stabilised by an LHY term has
    #    a real ground state, so this REFUSES only the combination that was
    #    actually measured to blow up: attractive with NO stabilising term. With
    #    an LHY present it warns instead.
    #
    #    A first version refused c₀ ≤ 0 outright, on one measurement at
    #    `lhy = none`. Generalising "attractive + no LHY diverges" to "attractive
    #    diverges" would have blocked droplet work on evidence that says nothing
    #    about it.
    #
    #    How it is reached by accident: `c₀ = c_total/(1 + F²·r)` changes sign at
    #    `r = −1/F²`, and PAST the pole c₁ flips POSITIVE — so "c₀ < 0 with
    #    c₁ < 0" is unreachable through `c1_ratio`, and a negative c₁ (the whole
    #    range `r ∈ (−1/F², 0)`, which is what production scans) never trips this.
    if c0 <= 0 && lhy === nothing
        push!(
            fails,
            "c₀ = $(round(c0; sigdigits=5)) ≤ 0 with no LHY — an ATTRACTIVE " *
            "condensate and nothing to arrest the collapse; measured NaN in every ITP " *
            "arm. An attractive point with an LHY term is a droplet and is allowed. If " *
            "this came from a c1_ratio, c₀ = c_total/(1 + F²·r) changes sign at " *
            "r = −1/F² (−1/36 ≈ −0.0278 for F=6) and c₁ turns POSITIVE past it, so this " *
            "is very likely not the point you meant.",
        )
    elseif c0 <= 0
        push!(
            warns,
            "c₀ = $(round(c0; sigdigits=5)) ≤ 0 — attractive. Legitimate with an " *
            "LHY term (this is the droplet regime), but the ITP stability limit and the " *
            "dt error were both measured at c₀ > 0 and neither transfers.",
        )
    end

    # 1b. NEAR the pole c₀ is large without the PHYSICS being large, and that is a
    #     numerical trap rather than a strong interaction: `c₀ + F²c₁` is what the
    #     scattering data fixes, while c₀ and c₁ blow up individually and cancel.
    #     Measured — at fixed c₀ = 34465, making the combination 7× larger left the
    #     ITP dt limit at 1.0e-3 either way, so the limit tracks the SUBSTEP.
    #     Lowering dt there refines a stiff splitting; it does not buy physics.
    c1 = get_cn(interactions, 1)
    if c0 > 0 && c1 != 0
        combo = c0 + 36 * c1              # F=6, the constraint this project uses
        # 0.5, ANCHORED ON THE LADDER rather than picked as a round number. The
        # measured dt limits against `|c₀+36c₁| / c₀`:
        #
        #     13.6 %  →  1.0e-3      (the most limited point)
        #     46   %  →  1.6e-2      (≥4× below the unbounded rows)
        #     82   %  →  ≥6.4e-2     (unbounded by the ladder)
        #
        # So the degradation is already material at 46 % and absent by 82 %. A
        # threshold of 0.3 was interpolated between the first two and flagged
        # nothing at 46 %, where the limit is demonstrably reduced.
        if abs(combo) < 0.5 * c0
            push!(
                warns,
                "c₀ = $(round(c0; sigdigits=5)) is large mainly by CANCELLATION: " *
                "c₀ + 36c₁ = $(round(combo; sigdigits=5)), i.e. " *
                "$(round(100 * abs(combo) / c0; sigdigits=2))% of c₀. Near the −1/F² pole the " *
                "substeps are individually huge while the physics is not, and the ITP dt " *
                "limit tracks the SUBSTEP (measured: 7× the physical combination at fixed " *
                "c₀ left the limit at 1.0e-3 either way). Lowering dt refines an " *
                "ill-conditioned splitting rather than improving the answer — prefer a " *
                "dt-free solver here.",
            )
        end
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
