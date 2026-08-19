# --- Integrator compositions: Yoshida / Suzuki / Blanes-Moan / Omelyan ---
#
# Symplectic-composition coefficients (Yoshida 4th & 6th, Suzuki 4th,
# Blanes-Moan SRKN₆ᵇ, Omelyan PEFRL) and the three core composers used by
# split_step!: _strang_core!, _yoshida_core!, _aba_step!. Extracted from
# split_step.jl 2026-05-01.

# --- Integrator compositions (Yoshida, Suzuki, Blanes-Moan, Omelyan) ---

"""
Yoshida 4th-order triple-jump coefficients.
S₄(dt) = S₂(w₁·dt) ∘ S₂(w₀·dt) ∘ S₂(w₁·dt)  with w₀ + 2w₁ = 1.
"""
# NOT GENERALIZABLE: `_YOSHIDA_W0 < 0` — middle substep runs *backwards in time*.
# Reason: math
# Why: Yoshida's 4th-order triple-jump requires w_0 = 1 - 2 w_1 ≈ -1.7024 to
#   cancel the 3rd-order error term. All split-step operators (kinetic, V, DDI,
#   spin-mixing, tensor) are unitary and time-reversible, so negative dt is
#   well-defined — but MUST NOT be replaced with abs(w_0); doing so silently
#   demotes the integrator to 2nd order.
# See: Yoshida 1990 Phys. Lett. A 150, 262; `_yoshida_core!` below
# TWO orders per composition, because there are two ways to realise it and this
# repository uses BOTH.
#
#   `order`      — the ABA product `_aba_step!` builds: a[1] K, then alternating
#                  b[i] V and a[i+1] K. What `test_composer_order_conditions.jl`
#                  measured before 2026-08-07.
#   `jump_order` — the un-merged triple jump `_composition_midpoint_core!`
#                  builds: ∏ᵢ S₂(b[i]·dt) of complete symmetric midpoint cores.
#                  `_run_yoshida_adaptive!` takes THIS path whenever DDI is on,
#                  i.e. on every production Eu run.
#
# They are not the same number. Measured on the 8×8 spectral (K,V) stand-in:
#
#     composition           ABA    triple jump
#     yoshida4              4.00   3.99
#     suzuki4               4.00   4.00
#     omelyan_pefrl         4.00   2.00      <-- demoted
#     blanes_moan_srkn6b    4.00   2.00      <-- demoted
#     yoshida6              6.00   6.00
#
# The two RKN methods buy their extra order conditions from the a/b INTERLEAVING;
# their `b` alone is not a triple-jump weight list. Composing S₂ cores at those
# weights is a consistent 2nd-order method that costs 4 and 6 stages per step —
# four to six times plain Strang for the order plain Strang already gives. It ran
# silently: the order gate checked the ABA form only, and the DDI path never uses
# it. `_run_yoshida_adaptive!` now refuses the combination.

const _YOSHIDA_W1 = 1.0 / (2.0 - 2.0^(1 / 3))
const _YOSHIDA_W0 = 1.0 - 2.0 * _YOSHIDA_W1

const _COMP_YOSHIDA = let w1 = _YOSHIDA_W1, w0 = _YOSHIDA_W0, wm = (w1 + w0) / 2
    (a=(w1 / 2, wm, wm, w1 / 2), b=(w1, w0, w1), order=4, jump_order=4)
end

const _COMP_SUZUKI = let p = 1.0 / (4.0 - 4.0^(1 / 3)), q = 1.0 - 4.0 * p
    (a=(p / 2, p, (p + q) / 2, (q + p) / 2, p, p / 2), b=(p, p, q, p, p),
        order=4, jump_order=4)
end

# Blanes & Moan (2002) SRKN₆ᵇ. The 6 counts STAGES, not order: this is a
# 6-stage FOURTH-order method, with a smaller error constant than Yoshida-4 at
# the same order. It was named `_COMP_BLANES_MOAN_S6` and documented as "the
# default 6th" until 2026-07-29, when the composer-order gate measured it at
# 4.00 — on a generic non-commuting pair, on the (kinetic, potential) split the
# propagator performs, and on a pair satisfying the RKN condition
# [B,[B,[B,A]]] = 0 exactly. `_COMP_YOSHIDA_S6` is the sixth-order one.
# Gated by test/hamiltonian/test_composer_order_conditions.jl.
const _COMP_BLANES_MOAN_SRKN6B = let
    a1 = 0.0792036964311957
    a2 = 0.353172906049774
    a3 = -0.0420650803577195
    a4 = 1.0 - 2.0 * (a1 + a2 + a3)
    b1 = 0.209515106613362
    b2 = -0.143851773179818
    b3 = 0.5 - b1 - b2
    (a=(a1, a2, a3, a4, a3, a2, a1), b=(b1, b2, b3, b3, b2, b1),
        order=4, jump_order=2)
end

const _COMP_OMELYAN_PEFRL = let
    xi = 0.1786178958448091
    lam = -0.2123418310626054
    chi = -0.06626458266981849
    a3 = 1.0 - 2.0 * (chi + xi)
    b1 = (1.0 - 2.0 * lam) / 2.0
    (a=(xi, chi, a3, chi, xi), b=(b1, lam, lam, b1), order=4, jump_order=2)
end

# Yoshida 6th-order (Yoshida 1990, "solution A"). 7-stage symplectic
# with 8 V-steps and 7 K-steps after merging adjacent same-operator
# substeps. THE sixth-order option — `_COMP_BLANES_MOAN_SRKN6B` is fourth
# order despite the 6 in its published name, so there is no cheaper 6th-order
# alternative here. Pick this when you need sub-1e-10 norm drift over very
# long evolution; at fourth order Blanes-Moan SRKN₆ᵇ has the smaller error
# constant and is cheaper per dt.
const _COMP_YOSHIDA_S6 = let
    # Yoshida (1990) Phys. Lett. A 150, 262. Solution A:
    w1 = -1.17767998417887
    w2 = 0.235573213359357
    w3 = 0.784513610477560
    w0 = 1.0 - 2.0 * (w1 + w2 + w3)
    # symmetric triple-jump in s2 ∘ s2 ∘ s2 form:
    bs = (w3, w2, w1, w0, w1, w2, w3)
    as_pairs = (w3 / 2, (w2 + w3) / 2, (w1 + w2) / 2, (w0 + w1) / 2,
        (w1 + w0) / 2, (w2 + w1) / 2, (w3 + w2) / 2, w3 / 2)
    (a=as_pairs, b=bs, order=6, jump_order=6)
end

function _resolve_composition(sym::Symbol)
    sym === :yoshida && return _COMP_YOSHIDA
    sym === :yoshida_s6 && return _COMP_YOSHIDA_S6
    sym === :suzuki && return _COMP_SUZUKI
    sym === :blanes_moan_srkn6b && return _COMP_BLANES_MOAN_SRKN6B
    sym === :omelyan_pefrl && return _COMP_OMELYAN_PEFRL
    throw(
        ArgumentError(
            "Unknown composition: $sym. Use :yoshida, :yoshida_s6, :suzuki, " *
            ":blanes_moan_srkn6b, or :omelyan_pefrl",
        ),
    )
end

"""
One Strang step with explicit dt (no sim_params dependency).
V(dt/2) K(dt) V(dt/2).
"""
function _strang_core!(
    ws::Workspace{N}, dt::Float64, n_comp::Int; t_base::Float64=ws.state.t
) where {N}
    omega = ws.sim_params.rotating_frame_omega
    _half_potential_step!(ws, dt / 2, n_comp, N, false; t_eval=t_base + dt / 4, t_start=t_base)
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)
    _update_batched_kinetic_phase!(
        ws.batched_kinetic, ws.grid.k_squared, dt, ws.sim_params.imaginary_time
    )
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)
    _half_potential_step!(
        ws, dt / 2, n_comp, N, false; t_eval=t_base + 3dt / 4, t_start=t_base + dt / 2
    )
    nothing
end

"""
Midpoint-mean-field Strang core: V_mid(dt/2) K(dt) V_mid(dt/2), where V_mid is
the implicit-midpoint half-potential (mean field frozen at the half-step
temporal midpoint via Picard). No t-advance / dissipation (the caller owns
those), so it composes cleanly. RTP only.

This is the TIME-SYMMETRIC 2nd-order base required for high-order composition
on the DDI lab path: composing this in the Yoshida/Suzuki/Blanes-Moan
triple-jump (`_composition_midpoint_core!`) recovers the nominal order, whereas
the plain `_strang_core!` (mean field at substep entry) collapses to ~1st order
under DDI. For TRUE 4th order the Picard iteration must converge the implicit
midpoint enough that the base is time-symmetric to the order the Richardson
cancellation needs: measured Y4 order vs n_picard (Eu F=6 + DDI, fine-reference
convergence) is np=1 → 3.85, np=2 → 3.8, **np=3 → 3.99** (`bench/conv_order4c.jl`).
The MERGED `_aba_step!` form caps at ~2.5 regardless of n_picard — V-merging
across substeps breaks the per-step time symmetry; un-merged full-step
composition is required.
"""
function _strang_midpoint_core!(
    ws::Workspace{N}, dt::Float64, n_comp::Int;
    t_base::Float64=ws.state.t, n_picard::Int=1,
) where {N}
    omega = ws.sim_params.rotating_frame_omega
    _half_potential_step_midpoint!(
        ws, dt / 2, n_comp, N, false; t_eval=t_base + dt / 4, t_start=t_base, n_picard
    )
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)
    _update_batched_kinetic_phase!(
        ws.batched_kinetic, ws.grid.k_squared, dt, ws.sim_params.imaginary_time
    )
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)
    _half_potential_step_midpoint!(
        ws, dt / 2, n_comp, N, false;
        t_eval=t_base + 3dt / 4, t_start=t_base + dt / 2, n_picard,
    )
    nothing
end

"""
High-order composition as a TRIPLE-JUMP of complete symmetric midpoint cores:
S(dt) = ∏ᵢ S₂_mid(bᵢ·dt) at the composition's S₂ weights `b` (which equal the
Yoshida/Suzuki/etc. sub-step sizes). Un-merged on purpose — merging adjacent
V-steps (as `_aba_step!` does) breaks the per-step time symmetry and caps the
order at ~2.5 on the DDI lab path. With the symmetric midpoint base this
delivers the composition's nominal order (4 for Yoshida-S4). No t-advance.
"""
function _composition_midpoint_core!(
    ws::Workspace{N}, dt::Float64, n_comp::Int, b::NTuple{Sk, Float64};
    t_base::Float64=ws.state.t, n_picard::Int=1,
) where {N, Sk}
    t = t_base
    for i in 1:Sk
        _strang_midpoint_core!(ws, b[i] * dt, n_comp; t_base=t, n_picard)
        t += b[i] * dt
    end
    nothing
end

"""
One 4th-order Yoshida step with merged boundary V-steps: 4V + 3K stages.

w₀ < 0 causes reverse evolution in the middle substep.
All operators (kinetic, diagonal, DDI, spin-mixing, tensor) are unitary and time-reversible,
so negative dt is valid. Tensor step uses eigendecomposition: exp(-iHdt) with dt<0 is exact.
"""
function _yoshida_core!(
    ws::Workspace{N}, dt::Float64, n_comp::Int; t_base::Float64=ws.state.t
) where {N}
    w1 = _YOSHIDA_W1
    w0 = _YOSHIDA_W0
    wm = (w1 + w0) / 2
    omega = ws.sim_params.rotating_frame_omega

    # V-step 1: covers [t_base, t_base + w1*dt/2], midpoint at t_base + w1*dt/4
    _half_potential_step!(
        ws, w1 * dt / 2, n_comp, N, false; t_eval=t_base + w1 * dt / 4, t_start=t_base
    )

    apply_step!(CoriolisTerm(omega), ws.state.psi, w1 * dt / 2, false, ws)
    _update_batched_kinetic_phase!(
        ws.batched_kinetic, ws.grid.k_squared, w1 * dt, ws.sim_params.imaginary_time
    )
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, w1 * dt / 2, false, ws)

    # V-step 2: merged boundary, covers [t_base + w1*dt/2, t_base + w1*dt/2 + wm*dt]
    t_v2 = t_base + w1 * dt / 2
    _half_potential_step!(ws, wm * dt, n_comp, N, false; t_eval=t_v2 + wm * dt / 2, t_start=t_v2)

    apply_step!(CoriolisTerm(omega), ws.state.psi, w0 * dt / 2, false, ws)
    _update_batched_kinetic_phase!(
        ws.batched_kinetic, ws.grid.k_squared, w0 * dt, ws.sim_params.imaginary_time
    )
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, w0 * dt / 2, false, ws)

    # V-step 3: merged boundary, covers [t_base + (w1+w0)*dt/2 + wm*dt/2, ...]
    # = [t_base + dt - w1*dt/2 - wm*dt, t_base + dt - w1*dt/2]
    t_v3 = t_base + w1 * dt / 2 + wm * dt
    _half_potential_step!(ws, wm * dt, n_comp, N, false; t_eval=t_v3 + wm * dt / 2, t_start=t_v3)

    apply_step!(CoriolisTerm(omega), ws.state.psi, w1 * dt / 2, false, ws)
    _update_batched_kinetic_phase!(
        ws.batched_kinetic, ws.grid.k_squared, w1 * dt, ws.sim_params.imaginary_time
    )
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, w1 * dt / 2, false, ws)

    # V-step 4: covers [t_base + dt - w1*dt/2, t_base + dt], midpoint at t_base + dt - w1*dt/4
    _half_potential_step!(
        ws,
        w1 * dt / 2,
        n_comp,
        N,
        false;
        t_eval=t_base + dt - w1 * dt / 4,
        t_start=t_base + dt - w1 * dt / 2,
    )
    nothing
end

"""
Generalized ABA composition step with independent V/K weight tuples.

V(a₁dt) · K(b₁dt) · V(a₂dt) · K(b₂dt) · ... · K(bₛdt) · V(aₛ₊₁dt)

Specializes on (Sv, Sk) type parameters → loop unrolled at compile time.
Supports both Strang-derived (Yoshida, Suzuki) and optimized (independent a,b) methods.
"""
function _aba_step!(
    ws::Workspace{N}, dt::Float64, n_comp::Int,
    a::NTuple{Sv, Float64}, b::NTuple{Sk, Float64};
    t_base::Float64=ws.state.t,
) where {N, Sv, Sk}
    omega = ws.sim_params.rotating_frame_omega

    t_cur = 0.0
    _half_potential_step!(
        ws,
        a[1] * dt,
        n_comp,
        N,
        false;
        t_eval=t_base + t_cur + a[1] * dt / 2,
        t_start=t_base + t_cur,
    )
    t_cur += a[1] * dt

    for i in 1:Sk
        apply_step!(CoriolisTerm(omega), ws.state.psi, b[i] * dt / 2, false, ws)
        _update_batched_kinetic_phase!(
            ws.batched_kinetic, ws.grid.k_squared, b[i] * dt, ws.sim_params.imaginary_time
        )
        apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
        apply_step!(CoriolisTerm(omega), ws.state.psi, b[i] * dt / 2, false, ws)

        _half_potential_step!(
            ws,
            a[i + 1] * dt,
            n_comp,
            N,
            false;
            t_eval=t_base + t_cur + a[i + 1] * dt / 2,
            t_start=t_base + t_cur,
        )
        t_cur += a[i + 1] * dt
    end
    nothing
end
