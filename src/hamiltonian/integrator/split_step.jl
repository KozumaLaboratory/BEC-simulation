# --- Split-step dispatcher: top-level Strang/Yoshida + half-potential helpers ---
#
# The top-level `split_step!` Strang step + per-step potential dispatch (diag,
# spin-mixing, nematic, raman, DDI), time-dependent Zeeman/MG handling, and
# the ITP leapfrog "outer-potential" merged-boundary helpers. Low-level FFT
# shears live in split_step_kernels.jl; integrator-composition coefficients
# and Yoshida/Suzuki/ABA cores live in split_step_composers.jl.

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
    t = ws.state.t

    t_eval_1 = it ? 0.0 : t + dt / 4
    t_eval_2 = it ? 0.0 : t + 3dt / 4

    @timeit_debug TIMER "half_potential" _half_potential_step!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_1, t_start=it ? NaN : t
    )

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

    @timeit_debug TIMER "half_potential" _half_potential_step!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_2, t_start=it ? NaN : t + dt / 2
    )

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

    if !it && ws.absorbing_mask !== nothing
        @timeit_debug TIMER "absorbing" apply_absorbing_boundary!(
            ws.state.psi,
            ws.absorbing_mask,
            n_comp,
            N,
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

function _dispatch_diagonal_step!(
    ws::Workspace{N},
    ::Val{N},
    zeeman_diag::SVector{D, Float64},
    dt_frac,
    imaginary_time,
    ip::InteractionParams=ws.interactions,
) where {N, D}
    if ws.light_shift !== nothing && ws.light_shift.is_diagonal
        ls_amp = SVector{D, Float64}(ntuple(c -> ws.light_shift.eigvals[c], Val(D)))
        _diagonal_step_with_ls!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ip.c0,
            ws.lhy !== nothing ? ws.lhy : ip.c_lhy,
            dt_frac, ws.density_buf, imaginary_time,
            ls_amp, ws.light_shift.profile,
        )
    else
        _diagonal_step_svec!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ip.c0,
            ws.lhy !== nothing ? ws.lhy : ip.c_lhy,
            dt_frac, ws.density_buf, imaginary_time,
        )
    end
end

# --- Time-dependent helpers for split-step ---

function _apply_mg_to_V!(ws::Workspace{N}, t::Float64) where {N}
    ws.magnetic_gradient === nothing && return nothing
    mg = ws.magnetic_gradient
    grad = mg isa TimeDependentMagneticGradient ? evaluate(mg.gradient_wf, t) : mg.gradient
    ax = mg.axis;
    gF = mg.g_F
    @inbounds for I in CartesianIndices(size(ws.potential_values))
        ws.potential_values[I] += gF * grad * ws.grid.x[ax][I[ax]]
    end
    nothing
end

function _remove_mg_from_V!(ws::Workspace{N}, t::Float64) where {N}
    ws.magnetic_gradient === nothing && return nothing
    mg = ws.magnetic_gradient
    grad = mg isa TimeDependentMagneticGradient ? evaluate(mg.gradient_wf, t) : mg.gradient
    ax = mg.axis;
    gF = mg.g_F
    @inbounds for I in CartesianIndices(size(ws.potential_values))
        ws.potential_values[I] -= gF * grad * ws.grid.x[ax][I[ax]]
    end
    nothing
end

function _apply_transverse_zeeman_step!(
    ws::Workspace, t::Float64, dt_frac::Float64, ndim::Int, imaginary_time::Bool
)
    bx_lab, by_lab = transverse_b(ws.zeeman, t)
    (bx_lab == 0.0 && by_lab == 0.0) && return nothing
    # Optional spin rotating frame: rotate (Bx, By) into the RF coords;
    # when ω_R = ω_drive the transverse field becomes static in RF.
    omega_R = ws.sim_params.spin_rotating_frame_omega
    bx, by = if abs(omega_R) > 1e-30
        c = cos(omega_R * t);
        s = sin(omega_R * t)
        (bx_lab * c + by_lab * s, -bx_lab * s + by_lab * c)
    else
        (bx_lab, by_lab)
    end
    @timeit_debug TIMER "transverse_zeeman" apply_uniform_spin_rotation!(
        ws.state.psi, ws.spin_matrices, bx, by, 0.0, dt_frac, ndim;
        imaginary_time, scratch=ws.state.psi_scratch,
    )
    nothing
end

"""
Symmetric inner splitting (all non-commuting operators symmetrized for 2nd-order accuracy):

    diag(dt/4) → SM(dt/4) → nematic(dt/4) → tensor(dt/4) → transB(dt/4) → raman(dt/4) → DDI(dt/2)
              → raman(dt/4) → transB(dt/4) → tensor(dt/4) → nematic(dt/4) → SM(dt/4) → diag(dt/4)

Additive dispatch: SM (c₁) and nematic (c₂) always run (auto-skip when coupling ≈ 0).
Tensor cache, when active, handles only the residual channels (c₄, c₆, ...).
Scattering-lengths path: c₀=c₁=0 in ws_interactions, so SM/nematic skip; tensor handles all.

DDI is innermost (most expensive: 6 FFTs). Cheaper operators wrap symmetrically.
Time-dependent interactions (c₀, c₁) and magnetic gradient are resolved per half-step.
"""
function _half_potential_step!(
    ws::Workspace{N},
    dt_half,
    n_comp,
    ndim,
    imaginary_time;
    t_eval::Float64=ws.state.t,
    t_start::Float64=NaN,
) where {N}
    # Resolve time-dependent interactions (preserves c_lhy and c_extra from static params)
    ip = if ws.time_dep_interactions !== nothing
        td_ip = interactions_at(ws.time_dep_interactions, t_eval)
        InteractionParams(td_ip.c0, td_ip.c1, ws.interactions.c_lhy, ws.interactions.c_extra)
    else
        ws.interactions
    end

    zeeman_diag_fwd = if !isnan(t_start) && ws.zeeman isa TimeDependentZeeman
        zee_fwd = zeeman_at(ws.zeeman, t_start + dt_half / 4)
        zeeman_diagonal(zee_fwd, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    else
        zee = zeeman_at(ws.zeeman, t_eval)
        zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    end
    gpu = _is_gpu(ws.state.psi)

    _apply_mg_to_V!(ws, t_eval)
    @timeit_debug TIMER "diagonal" _dispatch_diagonal_step!(
        ws, Val(N), zeeman_diag_fwd, dt_half / 2, imaginary_time, ip
    )
    _remove_mg_from_V!(ws, t_eval)

    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        @timeit_debug TIMER "light_shift" apply_light_shift_step!(
            ws.state.psi, ws.light_shift, dt_half / 2, ndim; imaginary_time
        )
    end

    if abs(ip.c1) > 1e-30
        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, ip.c1, dt_half / 2, ndim; imaginary_time
        )
    end

    c2 = get_cn(ip, 2)
    if abs(c2) > 1e-30
        @timeit_debug TIMER "nematic" apply_singlet_pair_step!(
            ws.state.psi, ip, ws.spin_matrices.system.F, dt_half / 2, ndim; imaginary_time
        )
    end

    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, dt_half / 2, ndim; imaginary_time
        )
    end

    _apply_transverse_zeeman_step!(ws, t_eval, dt_half / 2, ndim, imaginary_time)

    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, t_eval)
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, dt_half / 2; imaginary_time
        )
    end

    if ws.ddi !== nothing
        @timeit_debug TIMER "ddi" if gpu
            _apply_ddi_step_gpu!(ws, dt_half, ndim, imaginary_time)
        else
            if ws.ddi_padded !== nothing
                apply_ddi_step!(
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
                apply_ddi_step!(
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
    end

    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, t_eval)
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, dt_half / 2; imaginary_time
        )
    end

    _apply_transverse_zeeman_step!(ws, t_eval, dt_half / 2, ndim, imaginary_time)

    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, dt_half / 2, ndim; imaginary_time
        )
    end

    if abs(c2) > 1e-30
        @timeit_debug TIMER "nematic" apply_singlet_pair_step!(
            ws.state.psi, ip, ws.spin_matrices.system.F, dt_half / 2, ndim; imaginary_time
        )
    end

    if abs(ip.c1) > 1e-30
        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, ip.c1, dt_half / 2, ndim; imaginary_time
        )
    end

    zeeman_diag_bwd = if !isnan(t_start) && ws.zeeman isa TimeDependentZeeman
        zee_bwd = zeeman_at(ws.zeeman, t_start + 3 * dt_half / 4)
        zeeman_diagonal(zee_bwd, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    else
        zeeman_diag_fwd
    end

    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        @timeit_debug TIMER "light_shift" apply_light_shift_step!(
            ws.state.psi, ws.light_shift, dt_half / 2, ndim; imaginary_time
        )
    end

    _apply_mg_to_V!(ws, t_eval)
    @timeit_debug TIMER "diagonal" _dispatch_diagonal_step!(
        ws, Val(N), zeeman_diag_bwd, dt_half / 2, imaginary_time, ip
    )
    _remove_mg_from_V!(ws, t_eval)
end

# --- ITP leapfrog helpers ---
# Split V(dt/2) into outer (diag+SM+nematic+tensor+raman) and inner (DDI).
# Outer part can be merged between adjacent steps; DDI stays at dt/2.

"""
Outer part of half-potential step: everything except DDI.
Forward direction: diag → SM → nematic → tensor → raman
"""
function _outer_potential_fwd!(ws::Workspace{N}, dt_outer, n_comp, ndim, imaginary_time) where {N}
    gpu = _is_gpu(ws.state.psi)
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zeeman_diag = zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)

    _dispatch_diagonal_step!(ws, Val(N), zeeman_diag, dt_outer, imaginary_time)

    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        apply_light_shift_step!(ws.state.psi, ws.light_shift, dt_outer, ndim; imaginary_time)
    end

    if abs(ws.interactions.c1) > 1e-30
        apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, ws.interactions.c1, dt_outer, ndim; imaginary_time
        )
    end

    c2 = get_cn(ws.interactions, 2)
    if abs(c2) > 1e-30
        apply_singlet_pair_step!(
            ws.state.psi, ws.interactions, ws.spin_matrices.system.F, dt_outer, ndim; imaginary_time
        )
    end

    if ws.tensor_cache !== nothing
        apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, dt_outer, ndim; imaginary_time
        )
    end

    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, ws.state.t)
        apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, dt_outer; imaginary_time
        )
    end
end

"""
Outer part of half-potential step, backward direction: raman → tensor → nematic → SM → diag
"""
function _outer_potential_bwd!(ws::Workspace{N}, dt_outer, n_comp, ndim, imaginary_time) where {N}
    gpu = _is_gpu(ws.state.psi)

    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, ws.state.t)
        apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, dt_outer; imaginary_time
        )
    end

    if ws.tensor_cache !== nothing
        apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, dt_outer, ndim; imaginary_time
        )
    end

    c2 = get_cn(ws.interactions, 2)
    if abs(c2) > 1e-30
        apply_singlet_pair_step!(
            ws.state.psi, ws.interactions, ws.spin_matrices.system.F, dt_outer, ndim; imaginary_time
        )
    end

    if abs(ws.interactions.c1) > 1e-30
        apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, ws.interactions.c1, dt_outer, ndim; imaginary_time
        )
    end

    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        apply_light_shift_step!(ws.state.psi, ws.light_shift, dt_outer, ndim; imaginary_time)
    end

    zee = zeeman_at(ws.zeeman, ws.state.t)
    zeeman_diag = zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    _dispatch_diagonal_step!(ws, Val(N), zeeman_diag, dt_outer, imaginary_time)
end

"""
DDI-only step (inner part of half-potential).
"""
function _ddi_step!(ws::Workspace{N}, dt_ddi, ndim, imaginary_time) where {N}
    ws.ddi === nothing && return nothing
    gpu = _is_gpu(ws.state.psi)
    if gpu
        _apply_ddi_step_gpu!(ws, dt_ddi, ndim, imaginary_time)
    else
        if ws.ddi_padded !== nothing
            apply_ddi_step!(
                ws.state.psi,
                ws.spin_matrices,
                ws.ddi,
                ws.ddi_bufs,
                dt_ddi,
                ndim,
                ws.ddi_padded;
                imaginary_time,
            )
        else
            apply_ddi_step!(
                ws.state.psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt_ddi, ndim; imaginary_time
            )
        end
    end
end

function _normalize_psi!(psi, grid, n_components, ndim)
    dV = cell_volume(grid)
    norm_sq = sum(abs2, psi) * dV
    psi ./= sqrt(norm_sq)
    nothing
end
