# --- Multistart + constrained-Jz ground-state solvers ---

export find_ground_state_multistart

# `find_ground_state_multistart` (multiple initial states + energy minimum),
# `_normalize_psi_constrained!` (Mz-constrained renormalisation),
# `_rebuild_workspace_with_dt`, and `_find_ground_state_Jz` (rotating-frame
# bisection for target Jz).

"""
    find_ground_state_multistart(; initial_states, n_random, seed, kwargs...) → NamedTuple

Try multiple initial states and return the lowest-energy ground state.
All keyword arguments except `initial_states`, `n_random`, and `seed` are
forwarded to `find_ground_state`.

Returns `(workspace, converged, energy, initial_state, all_results)`.
"""
function find_ground_state_multistart(;
    initial_states::Vector{Symbol}=[:polar, :m_plus_F, :uniform, :antiferromagnetic],
    n_random::Int=3,
    seed::Int=42,
    grid,
    atom,
    interactions,
    kwargs...,
)
    results = NamedTuple[]

    for state in initial_states
        if state == :random
            for i in 1:n_random
                sys = SpinSystem(atom.F)
                psi0 = init_psi(grid, sys; state=:random, seed=seed + i)
                r = find_ground_state(;
                    grid,
                    atom,
                    interactions,
                    psi_init=psi0,
                    kwargs...,
                )
                push!(
                    results,
                    (
                        initial_state=:random,
                        idx=i,
                        workspace=r.workspace,
                        converged=r.converged,
                        energy=r.energy,
                        dE=r.dE,
                        dpsi=r.dpsi,
                    ),
                )
            end
        else
            r = find_ground_state(;
                grid,
                atom,
                interactions,
                initial_state=state,
                kwargs...,
            )
            push!(
                results,
                (
                    initial_state=state,
                    idx=0,
                    workspace=r.workspace,
                    converged=r.converged,
                    energy=r.energy,
                    dE=r.dE,
                    dpsi=r.dpsi,
                ),
            )
        end
    end

    best = argmin(r -> r.energy, results)
    (
        workspace=best.workspace,
        converged=best.converged,
        energy=best.energy,
        initial_state=best.initial_state,
        all_results=results,
    )
end

"""
Normalize psi while constraining magnetization ⟨Fz⟩ to target_Mz.

Applies exp(λ·m) weights to each component, then normalizes.
Uses Newton iteration to find λ such that Mz(λ) = target_Mz.
"""
function _normalize_psi_constrained!(psi, grid, n_components, ndim, target_Mz, F)
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), ndim)

    _normalize_psi!(psi, grid, n_components, ndim)

    lambda = 0.0
    for _iter in 1:20
        norms = Vector{Float64}(undef, n_components)
        for c in 1:n_components
            m = F - (c - 1)
            idx = _component_slice(ndim, n_pts, c)
            w = exp(lambda * m)
            norms[c] = sum(abs2, view(psi, idx...)) * dV * w^2
        end
        total = sum(norms)
        total < COUPLING_TOL && break

        Mz = sum((F - (c - 1)) * norms[c] for c in 1:n_components) / total
        abs(Mz - target_Mz) < 1e-12 && break

        dMz = 0.0
        for c in 1:n_components
            m = F - (c - 1)
            dMz += 2 * m * (m - Mz) * norms[c] / total
        end
        abs(dMz) < COUPLING_TOL && break

        lambda -= (Mz - target_Mz) / dMz
        lambda = clamp(lambda, -10.0, 10.0)
    end

    for c in 1:n_components
        m = F - (c - 1)
        w = exp(lambda * m)
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .*= w
    end

    _normalize_psi!(psi, grid, n_components, ndim)
    nothing
end

function _rebuild_workspace_with_dt(ws::Workspace{N}, new_dt::Float64) where {N}
    sp = SimParams(
        new_dt,
        ws.sim_params.n_steps,
        true,
        ws.sim_params.normalize_every,
        ws.sim_params.save_every,
        ws.sim_params.rotating_frame_omega,
        ws.sim_params.spin_rotating_frame_omega,
    )
    kinetic_phase = _to_device(
        ws.backend,
        prepare_kinetic_phase(ws.grid, new_dt; imaginary_time=true),
    )
    batched_kinetic = _make_batched_kinetic_cache(ws.state.psi, kinetic_phase, N, ws.backend)

    _rebuild_workspace(ws;
        sim_params=sp,
        kinetic_phase=kinetic_phase,
        batched_kinetic=batched_kinetic,
    )
end

# --- Constrained Jz ground state (bisection on rotating_frame_omega) ---

"""
Bisection on rotating_frame_omega to find ground state with target J_z.

rotating_frame_omega drives the Coriolis term −Ω·L_z, so a larger Ω
lowers the energy of higher-L_z states (vortex entry):
  J_z(Ω) is a non-decreasing function of Ω.
(Measured: J_z ≈ 0, 0, 24, 41 at Ω = 0.2, 0.5, 0.8, 1.1 for c₀=10 on a
32² trap.) The bracket update below relies on this monotonicity.
"""
function _find_ground_state_Jz(;
    grid,
    atom,
    interactions,
    zeeman,
    potential,
    dt,
    n_steps,
    tol,
    initial_state,
    psi_init,
    enable_ddi,
    c_dd,
    secular_ddi,
    ddi_trunc_radius::Float64=NaN,
    ddi_padding::Bool=false,
    ddi_pad_factor::Union{Real, NTuple}=2,
    adaptive_dt,
    dt_max,
    fft_flags,
    target_magnetization,
    target_Jz,
    Jz_tol,
    Jz_max_iter,
    Jz_omega_range,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
)
    omega_lo, omega_hi = Jz_omega_range
    prev_psi = psi_init

    best_result = nothing
    best_Jz = NaN
    best_omega = 0.0

    for iter in 1:Jz_max_iter
        omega_trial = (omega_lo + omega_hi) / 2.0
        r = find_ground_state(;
            grid,
            atom,
            interactions,
            zeeman,
            potential,
            dt,
            n_steps,
            tol,
            initial_state,
            psi_init=copy(prev_psi),
            enable_ddi,
            c_dd,
            secular_ddi,
            ddi_trunc_radius,
            ddi_padding,
            ddi_pad_factor,
            adaptive_dt,
            dt_max,
            fft_flags,
            target_magnetization,
            rotating_frame_omega=omega_trial,
            quasi_2d_ddi,
            l_z_ddi,
            quasi_2d,
            l_z,
            backend,
        )

        ws = r.workspace
        plans = ws.fft_plans
        sys = ws.spin_matrices.system
        Jz = total_angular_momentum(ws.state.psi, grid, plans, sys)

        if best_result === nothing || abs(Jz - target_Jz) < abs(best_Jz - target_Jz)
            best_result = r
            best_Jz = Jz
            best_omega = omega_trial
        end

        if abs(Jz - target_Jz) < Jz_tol
            return (
                workspace=r.workspace,
                converged=r.converged,
                energy=r.energy,
                dE=r.dE,
                dpsi=r.dpsi,
                Jz=Jz,
                omega=omega_trial,
            )
        end

        # J_z is non-decreasing in Ω, so J_z above target ⇒ lower the
        # ceiling (less Ω); below target ⇒ raise the floor (more Ω).
        if Jz > target_Jz
            omega_hi = omega_trial
        else
            omega_lo = omega_trial
        end

        prev_psi = copy(ws.state.psi)
    end

    (
        workspace=best_result.workspace,
        converged=false,
        energy=best_result.energy,
        dE=best_result.dE,
        dpsi=best_result.dpsi,
        Jz=best_Jz,
        omega=best_omega,
    )
end
