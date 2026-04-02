"""
Perform one Strang-split time step: V(dt/2) K(dt) V(dt/2).

Half potential step uses nested symmetric splitting:
    diag(dt/4) → SM(dt/4) → nematic(dt/4) → raman(dt/4) → DDI(dt/2)
              → raman(dt/4) → nematic(dt/4) → SM(dt/4) → diag(dt/4)

For imaginary time: replace i with 1 in exponentials, optionally renormalize.
"""
function split_step!(ws::Workspace{N}) where {N}
    dt = ws.sim_params.dt
    it = ws.sim_params.imaginary_time
    n_comp = ws.spin_matrices.system.n_components

    @timeit_debug TIMER "half_potential" _half_potential_step!(ws, dt / 2, n_comp, N, it)

    omega = ws.sim_params.rotating_frame_omega
    @timeit_debug TIMER "coriolis" _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        dt / 2,
        it,
        ws.coriolis_cache,
    )
    @timeit_debug TIMER "kinetic" apply_kinetic_step_batched!(
        ws.state.psi,
        ws.batched_kinetic,
    )
    @timeit_debug TIMER "coriolis" _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        dt / 2,
        it,
        ws.coriolis_cache,
    )

    @timeit_debug TIMER "half_potential" _half_potential_step!(ws, dt / 2, n_comp, N, it)

    if !it && ws.loss !== nothing
        @timeit_debug TIMER "loss" apply_loss_step!(
            ws.state.psi,
            ws.loss,
            ws.spin_matrices.system.F,
            dt,
            n_comp,
            N,
            ws.density_buf,
        )
    end

    ws.state.t += it ? 0.0 : dt
    ws.state.step += 1

    if it && ws.sim_params.normalize_every > 0
        if ws.state.step % ws.sim_params.normalize_every == 0
            _normalize_psi!(ws.state.psi, ws.grid, n_comp, N)
        end
    end

    nothing
end

"""
Symmetric inner splitting (all non-commuting operators symmetrized for 2nd-order accuracy):

    diag(dt/4) → SM(dt/4) → nematic/tensor(dt/4) → raman(dt/4) → DDI(dt/2)
              → raman(dt/4) → nematic/tensor(dt/4) → SM(dt/4) → diag(dt/4)

When tensor_cache is active, it handles ALL contact interactions (c₀ through c_{2F}),
so spin_mixing (c₁) and nematic (c₂) are skipped to avoid double-counting.

DDI is innermost (most expensive: 6 FFTs). Cheaper operators wrap symmetrically.
"""
function _half_potential_step!(
    ws::Workspace{N},
    dt_half,
    n_comp,
    ndim,
    imaginary_time,
) where {N}
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zeeman_diag = zeeman_diagonal(zee, ws.spin_matrices)

    @timeit_debug TIMER "diagonal" _diagonal_step_svec!(
        Val(N),
        ws.state.psi,
        ws.potential_values,
        zeeman_diag,
        ws.interactions.c0,
        ws.interactions.c_lhy,
        dt_half / 2,
        ws.density_buf,
        imaginary_time,
    )

    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi,
            ws.tensor_cache,
            ws.spin_matrices,
            dt_half / 2,
            ndim;
            imaginary_time,
        )
    else
        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi,
            ws.spin_matrices,
            ws.interactions.c1,
            dt_half / 2,
            ndim;
            imaginary_time,
        )

        @timeit_debug TIMER "nematic" apply_nematic_step!(
            ws.state.psi,
            ws.interactions,
            ws.spin_matrices.system.F,
            dt_half / 2,
            ndim;
            imaginary_time,
        )
    end

    if ws.raman !== nothing
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi,
            ws.spin_matrices,
            ws.raman,
            ws.grid,
            dt_half / 2;
            imaginary_time,
        )
    end

    if ws.ddi !== nothing
        if ws.ddi_padded !== nothing
            @timeit_debug TIMER "ddi" apply_ddi_step!(
                ws.state.psi,
                ws.spin_matrices,
                ws.ddi,
                ws.ddi_bufs,
                dt_half,
                ndim,
                ws.ddi_padded;
                imaginary_time,
            )
        else
            @timeit_debug TIMER "ddi" apply_ddi_step!(
                ws.state.psi,
                ws.spin_matrices,
                ws.ddi,
                ws.ddi_bufs,
                dt_half,
                ndim;
                imaginary_time,
            )
        end
    end

    if ws.raman !== nothing
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi,
            ws.spin_matrices,
            ws.raman,
            ws.grid,
            dt_half / 2;
            imaginary_time,
        )
    end

    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi,
            ws.tensor_cache,
            ws.spin_matrices,
            dt_half / 2,
            ndim;
            imaginary_time,
        )
    else
        @timeit_debug TIMER "nematic" apply_nematic_step!(
            ws.state.psi,
            ws.interactions,
            ws.spin_matrices.system.F,
            dt_half / 2,
            ndim;
            imaginary_time,
        )

        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi,
            ws.spin_matrices,
            ws.interactions.c1,
            dt_half / 2,
            ndim;
            imaginary_time,
        )
    end

    @timeit_debug TIMER "diagonal" _diagonal_step_svec!(
        Val(N),
        ws.state.psi,
        ws.potential_values,
        zeeman_diag,
        ws.interactions.c0,
        ws.interactions.c_lhy,
        dt_half / 2,
        ws.density_buf,
        imaginary_time,
    )
end

"""
Yoshida 4th-order triple-jump coefficients.
S₄(dt) = S₂(w₁·dt) ∘ S₂(w₀·dt) ∘ S₂(w₁·dt)  with w₀ + 2w₁ = 1.
"""
const _YOSHIDA_W1 = 1.0 / (2.0 - 2.0^(1 / 3))
const _YOSHIDA_W0 = 1.0 - 2.0 * _YOSHIDA_W1

"""
One Strang step with explicit dt (no sim_params dependency).
V(dt/2) K(dt) V(dt/2).
"""
function _strang_core!(ws::Workspace{N}, dt::Float64, n_comp::Int) where {N}
    omega = ws.sim_params.rotating_frame_omega
    _half_potential_step!(ws, dt / 2, n_comp, N, false)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, ws.coriolis_cache)
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, ws.coriolis_cache)
    _half_potential_step!(ws, dt / 2, n_comp, N, false)
    nothing
end

"""
One 4th-order Yoshida step with merged boundary V-steps: 4V + 3K stages.

w₀ < 0 causes reverse evolution in the middle substep.
All operators (kinetic, diagonal, DDI, spin-mixing, tensor) are unitary and time-reversible,
so negative dt is valid. Tensor step uses eigendecomposition: exp(-iHdt) with dt<0 is exact.
"""
function _yoshida_core!(ws::Workspace{N}, dt::Float64, n_comp::Int) where {N}
    w1 = _YOSHIDA_W1
    w0 = _YOSHIDA_W0
    wm = (w1 + w0) / 2
    omega = ws.sim_params.rotating_frame_omega

    _half_potential_step!(ws, w1 * dt / 2, n_comp, N, false)

    _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        w1 * dt / 2,
        false,
        ws.coriolis_cache,
    )
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        w1 * dt / 2,
        false,
        ws.coriolis_cache,
    )

    _half_potential_step!(ws, wm * dt, n_comp, N, false)

    _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        w0 * dt / 2,
        false,
        ws.coriolis_cache,
    )
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        w0 * dt / 2,
        false,
        ws.coriolis_cache,
    )

    _half_potential_step!(ws, wm * dt, n_comp, N, false)

    _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        w1 * dt / 2,
        false,
        ws.coriolis_cache,
    )
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(
        ws.state.psi,
        ws.grid,
        omega,
        w1 * dt / 2,
        false,
        ws.coriolis_cache,
    )

    _half_potential_step!(ws, w1 * dt / 2, n_comp, N, false)
    nothing
end

"""
Apply Coriolis step exp(iΩ·L_z·dt) via 3-shear FFT decomposition.

Implements the -Ω·L_z term from the rotating frame Hamiltonian H_rot = H - Ω·J_z.
L_z = x·p_y - y·p_x is the orbital angular momentum.

Real time: spatial rotation by angle Ω·dt.
Imaginary time: rotation by imaginary angle with real exponential shear factors
(stable for small Ωτ, renormalized each ITP step).
"""
function _apply_coriolis_step!(
    psi::AbstractArray{ComplexF64},
    grid::Grid{N},
    omega::Float64,
    dt::Float64,
    imaginary_time::Bool,
    cache::Union{Nothing,CoriolisCache} = nothing,
) where {N}
    N < 2 && return nothing
    abs(omega) < 1e-15 && return nothing

    theta = omega * dt

    if imaginary_time
        a_y = tanh(theta / 2)
        a_x = -sinh(theta)
    else
        a_y = tan(theta / 2)
        a_x = -sin(theta)
    end

    if cache !== nothing
        _apply_1d_shear_batch!(
            psi,
            grid.x[1],
            grid.k[2],
            2,
            1,
            a_y,
            imaginary_time,
            cache.fwd_dim2,
            cache.inv_dim2,
        )
        _apply_1d_shear_batch!(
            psi,
            grid.x[2],
            grid.k[1],
            1,
            2,
            a_x,
            imaginary_time,
            cache.fwd_dim1,
            cache.inv_dim1,
        )
        _apply_1d_shear_batch!(
            psi,
            grid.x[1],
            grid.k[2],
            2,
            1,
            a_y,
            imaginary_time,
            cache.fwd_dim2,
            cache.inv_dim2,
        )
    else
        _apply_1d_shear_batch!(psi, grid.x[1], grid.k[2], 2, 1, a_y, imaginary_time)
        _apply_1d_shear_batch!(psi, grid.x[2], grid.k[1], 1, 2, a_x, imaginary_time)
        _apply_1d_shear_batch!(psi, grid.x[1], grid.k[2], 2, 1, a_y, imaginary_time)
    end
    nothing
end

function _apply_1d_shear_batch!(
    psi::AbstractArray{ComplexF64},
    coord_vals::Vector{Float64},
    k_vals::Vector{Float64},
    fft_dim::Int,
    coord_dim::Int,
    factor::Float64,
    imaginary_time::Bool,
)
    abs(factor) < 1e-30 && return nothing

    psi_k = fft(psi, fft_dim)

    @inbounds for I in CartesianIndices(size(psi_k))
        arg = factor * coord_vals[I[coord_dim]] * k_vals[I[fft_dim]]
        psi_k[I] *= imaginary_time ? exp(arg) : cis(arg)
    end

    psi .= ifft(psi_k, fft_dim)
    nothing
end

function _apply_1d_shear_batch!(
    psi::AbstractArray{ComplexF64},
    coord_vals::Vector{Float64},
    k_vals::Vector{Float64},
    fft_dim::Int,
    coord_dim::Int,
    factor::Float64,
    imaginary_time::Bool,
    fwd_plan,
    inv_plan,
)
    abs(factor) < 1e-30 && return nothing

    fwd_plan * psi

    @inbounds for I in CartesianIndices(size(psi))
        arg = factor * coord_vals[I[coord_dim]] * k_vals[I[fft_dim]]
        psi[I] *= imaginary_time ? exp(arg) : cis(arg)
    end

    inv_plan * psi
    nothing
end

function _normalize_psi!(psi, grid, n_components, ndim)
    dV = cell_volume(grid)
    norm_sq = 0.0
    n_pts = ntuple(d -> size(psi, d), ndim)
    for c = 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        norm_sq += sum(abs2, view(psi, idx...)) * dV
    end
    psi ./= sqrt(norm_sq)
    nothing
end
