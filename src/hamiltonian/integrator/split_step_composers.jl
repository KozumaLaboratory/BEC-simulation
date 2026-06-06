# --- Integrator compositions: Yoshida / Suzuki / Blanes-Moan / Omelyan ---
#
# Symplectic-composition coefficients (Yoshida 4th & 6th, Suzuki 4th,
# Blanes-Moan S6, Omelyan PEFRL) and the three core composers used by
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
const _YOSHIDA_W1 = 1.0 / (2.0 - 2.0^(1 / 3))
const _YOSHIDA_W0 = 1.0 - 2.0 * _YOSHIDA_W1

const _COMP_YOSHIDA = let w1 = _YOSHIDA_W1, w0 = _YOSHIDA_W0, wm = (w1 + w0) / 2
    (a=(w1 / 2, wm, wm, w1 / 2), b=(w1, w0, w1))
end

const _COMP_SUZUKI = let p = 1.0 / (4.0 - 4.0^(1 / 3)), q = 1.0 - 4.0 * p
    (a=(p / 2, p, (p + q) / 2, (q + p) / 2, p, p / 2), b=(p, p, q, p, p))
end

const _COMP_BLANES_MOAN_S6 = let
    a1 = 0.0792036964311957
    a2 = 0.353172906049774
    a3 = -0.0420650803577195
    a4 = 1.0 - 2.0 * (a1 + a2 + a3)
    b1 = 0.209515106613362
    b2 = -0.143851773179818
    b3 = 0.5 - b1 - b2
    (a=(a1, a2, a3, a4, a3, a2, a1), b=(b1, b2, b3, b3, b2, b1))
end

const _COMP_OMELYAN_PEFRL = let
    xi = 0.1786178958448091
    lam = -0.2123418310626054
    chi = -0.06626458266981849
    a3 = 1.0 - 2.0 * (chi + xi)
    b1 = (1.0 - 2.0 * lam) / 2.0
    (a=(xi, chi, a3, chi, xi), b=(b1, lam, lam, b1))
end

# Yoshida 6th-order (Yoshida 1990, "solution A"). 7-stage symplectic
# with 8 V-steps and 7 K-steps after merging adjacent same-operator
# substeps. Lower error constant than Blanes-Moan S6 for some problems
# (notably when the perturbation spectrum has wide bandwidth) but more
# stages → ~15% slower per dt. Pick this when you need sub-1e-10 norm
# drift over very long evolution; Blanes-Moan S6 is the default 6th.
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
    (a=as_pairs, b=bs)
end

function _resolve_composition(sym::Symbol)
    sym === :yoshida && return _COMP_YOSHIDA
    sym === :yoshida_s6 && return _COMP_YOSHIDA_S6
    sym === :suzuki && return _COMP_SUZUKI
    sym === :blanes_moan_s6 && return _COMP_BLANES_MOAN_S6
    sym === :omelyan_pefrl && return _COMP_OMELYAN_PEFRL
    throw(
        ArgumentError(
            "Unknown composition: $sym. Use :yoshida, :yoshida_s6, :suzuki, " *
            ":blanes_moan_s6, or :omelyan_pefrl",
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
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt)
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)
    _half_potential_step!(
        ws, dt / 2, n_comp, N, false; t_eval=t_base + 3dt / 4, t_start=t_base + dt / 2
    )
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
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, w1 * dt / 2, false, ws)

    # V-step 2: merged boundary, covers [t_base + w1*dt/2, t_base + w1*dt/2 + wm*dt]
    t_v2 = t_base + w1 * dt / 2
    _half_potential_step!(ws, wm * dt, n_comp, N, false; t_eval=t_v2 + wm * dt / 2, t_start=t_v2)

    apply_step!(CoriolisTerm(omega), ws.state.psi, w0 * dt / 2, false, ws)
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, w0 * dt / 2, false, ws)

    # V-step 3: merged boundary, covers [t_base + (w1+w0)*dt/2 + wm*dt/2, ...]
    # = [t_base + dt - w1*dt/2 - wm*dt, t_base + dt - w1*dt/2]
    t_v3 = t_base + w1 * dt / 2 + wm * dt
    _half_potential_step!(ws, wm * dt, n_comp, N, false; t_eval=t_v3 + wm * dt / 2, t_start=t_v3)

    apply_step!(CoriolisTerm(omega), ws.state.psi, w1 * dt / 2, false, ws)
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
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
        _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, b[i] * dt)
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

