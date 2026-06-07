# --- Split-step dispatcher: top-level Strang/Yoshida + half-potential helpers ---
#
# The top-level `split_step!` Strang step + per-step potential dispatch (diag,
# spin-mixing, singlet_pair, raman, DDI), time-dependent Zeeman/MG handling, and
# the ITP leapfrog "outer-potential" merged-boundary helpers. Low-level FFT
# kernels and shears live in split_step_kernels.jl; integrator-composition
# coefficients and Yoshida/Suzuki/ABA cores live in split_step_composers.jl.

export split_step!, split_step_midpoint!

"""
Perform one Strang-split time step: V(dt/2) K(dt) V(dt/2).

Half potential step uses nested symmetric splitting:
    diag(dt/4) → SM(dt/4) → singlet_pair(dt/4) → raman(dt/4) → DDI(dt/2)
              → raman(dt/4) → singlet_pair(dt/4) → SM(dt/4) → diag(dt/4)

For imaginary time: replace i with 1 in exponentials, optionally renormalize.
"""
function split_step!(ws::Workspace{N}) where {N}
    dt = ws.sim_params.dt
    it = ws.sim_params.imaginary_time
    n_comp = ws.spin_matrices.system.n_components
    t = ws.state.t

    t_eval_1 = it ? 0.0 : t + dt / 4
    t_eval_2 = it ? 0.0 : t + 3dt / 4

    if DEALIAS_2_3_ENABLED[]
        @timeit_debug TIMER "dealias" apply_orszag_2_3_filter!(
            ws.state.psi, ws.fft_plans, n_comp, N
        )
    end

    @timeit_debug TIMER "half_potential" _half_potential_step!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_1, t_start=it ? NaN : t
    )

    omega = ws.sim_params.rotating_frame_omega
    @timeit_debug TIMER "coriolis" apply_step!(
        CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws
    )
    @timeit_debug TIMER "kinetic" apply_step!(
        KineticTerm(), ws.state.psi, 0.0, false, ws
    )
    @timeit_debug TIMER "coriolis" apply_step!(
        CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws
    )

    @timeit_debug TIMER "half_potential" _half_potential_step!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_2, t_start=it ? NaN : t + dt / 2
    )

    it || apply_rt_dissipation!(ws, dt, n_comp, N)

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
    ip::InteractionParams=ws.interactions;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, D}
    if ws.light_shift !== nothing && ws.light_shift.is_diagonal
        ls_amp = SVector{D, Float64}(ntuple(c -> ws.light_shift.eigvals[c], Val(D)))
        _diagonal_step_with_ls!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ip[0],
            ws.lhy !== nothing ? ws.lhy : ip.c_lhy,
            dt_frac, ws.density_buf, imaginary_time,
            ls_amp, ws.light_shift.profile;
            psi_mf,
        )
    else
        _diagonal_step_svec!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ip[0],
            ws.lhy !== nothing ? ws.lhy : ip.c_lhy,
            dt_frac, ws.density_buf, imaginary_time;
            psi_mf,
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
    bx, by = if is_active(omega_R, ROTATION_TOL)
        c = cos(omega_R * t);
        s = sin(omega_R * t)
        (bx_lab * c + by_lab * s, -bx_lab * s + by_lab * c)
    else
        (bx_lab, by_lab)
    end
    # User-spec convention (`b_block_builders.jl:27`): H_Zeeman = -(g_F μ_B B · F).
    # `apply_uniform_spin_rotation!` applies `exp(-i·dt·(phi·F̂))` i.e. H = +phi·F̂.
    # To get the user-spec H = -bx·F_x - by·F_y, pass (-bx, -by) as phi.
    # Fixed 2026-06-04 after sign-inversion oracle. See
    # `mistake_transverse_zeeman_sign_inversion_2026_06_04`.
    @timeit_debug TIMER "transverse_zeeman" apply_uniform_spin_rotation!(
        ws.state.psi, ws.spin_matrices, -bx, -by, 0.0, dt_frac, ndim;
        imaginary_time, scratch=ws.state.psi_scratch,
    )
    nothing
end

"""
Symmetric inner splitting (all non-commuting operators symmetrized for 2nd-order accuracy):

    diag(dt/4) → SM(dt/4) → singlet_pair(dt/4) → tensor(dt/4) → transB(dt/4) → raman(dt/4) → DDI(dt/2)
              → raman(dt/4) → transB(dt/4) → tensor(dt/4) → singlet_pair(dt/4) → SM(dt/4) → diag(dt/4)

Additive dispatch: SM (c₁) and singlet_pair (c₂) always run (auto-skip when coupling ≈ 0).
Tensor cache, when active, handles only the residual channels (c₄, c₆, ...).
Scattering-lengths path: c₀=c₁=0 in ws_interactions, so SM/singlet_pair skip; tensor handles all.

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
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N}
    # Resolve time-dependent interactions (preserves c_lhy and the
    # higher-rank tensor couplings from the static params).
    ip = if ws.time_dep_interactions !== nothing
        td_ip = interactions_at(ws.time_dep_interactions, t_eval)
        merged = Dict{Int, Float64}(k => v for (k, v) in ws.interactions.c
                                               if k >= 2)
        merged[0] = td_ip[0]
        merged[1] = td_ip[1]
        InteractionParams(merged; c_lhy=ws.interactions.c_lhy)
    else
        ws.interactions
    end

    # Midpoint-evaluate the diagonal Zeeman when a `t_start` is supplied
    # and the field is time-dependent — preserves 2nd-order accuracy in the
    # symmetric Strang sandwich when the field has appreciable drift over
    # a single dt_half. Otherwise fall back to a single t_eval sample.
    zeeman_diag_fwd, zeeman_diag_bwd = if !isnan(t_start) && ws.zeeman isa TimeDependentZeeman
        zee_fwd = zeeman_at(ws.zeeman, t_start + dt_half / 4)
        zee_bwd = zeeman_at(ws.zeeman, t_start + 3 * dt_half / 4)
        (zeeman_diagonal(zee_fwd, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega),
            zeeman_diagonal(zee_bwd, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega),
        )
    else
        zd = zeeman_diagonal(
            zeeman_at(ws.zeeman, t_eval), ws.spin_matrices,
            ws.sim_params.spin_rotating_frame_omega,
        )
        (zd, zd)
    end
    gpu = _is_gpu(ws.state.psi)

    # Forward outer chain — shared with ITP via `_outer_operators_fwd!`.
    _outer_operators_fwd!(
        ws, dt_half / 2, ndim, imaginary_time;
        t_eval, ip, zeeman_diag=zeeman_diag_fwd, psi_mf, mg_active=true,
    )

    # Inner DDI(dt_half) — RTP only; ITP separates DDI for Strang-merge
    # at the loop boundary (see `_run_itp_loop!`).
    if ws.ddi !== nothing
        @timeit_debug TIMER "ddi" if gpu
            _apply_ddi_step_gpu!(ws, dt_half, ndim, imaginary_time; psi_mf)
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
                    imaginary_time, psi_mf,
                )
            else
                apply_ddi_step!(
                    ws.state.psi,
                    ws.spin_matrices,
                    ws.ddi,
                    ws.ddi_bufs,
                    dt_half,
                    ndim;
                    imaginary_time, psi_mf,
                )
            end
        end
    end

    # Backward outer chain — shared with ITP via `_outer_operators_bwd!`.
    _outer_operators_bwd!(
        ws, dt_half / 2, ndim, imaginary_time;
        t_eval, ip, zeeman_diag=zeeman_diag_bwd, psi_mf, mg_active=true,
    )
end

"""
Strang split-step that uses `_half_potential_step_midpoint!` for each V(dt/2).

Drop-in replacement for `split_step!`: same V K V outer structure, same time/step
accounting, but the V halves are symmetric to round-off. Lets MPS-4 / Yoshida-6
Richardson cancellation recover its nominal order on the lab path (gate test:
`scripts/bench/mps4_lab_diagnostic.jl` and the midpoint variant of it).

Costs ~1.5–2× a plain `split_step!` per call.

The optional `dt` keyword overrides `ws.sim_params.dt` for THIS step only —
useful for adaptive controllers (`adaptive_step!`) and composition schemes
(Y4-mid, Y6-mid, MPS-{4,6,8}) that vary dt per substep. When `dt` is given,
`ws.batched_kinetic.kinetic_phase_bc` is updated to match — subsequent calls
must either pass `dt` again or rely on the always-update-on-entry semantics.
"""
function split_step_midpoint!(ws::Workspace{N}; dt::Float64=ws.sim_params.dt) where {N}
    it = ws.sim_params.imaginary_time
    n_comp = ws.spin_matrices.system.n_components
    t = ws.state.t

    t_eval_1 = it ? 0.0 : t + dt / 4
    t_eval_2 = it ? 0.0 : t + 3dt / 4

    if DEALIAS_2_3_ENABLED[]
        @timeit_debug TIMER "dealias" apply_orszag_2_3_filter!(
            ws.state.psi, ws.fft_plans, n_comp, N
        )
    end

    @timeit_debug TIMER "half_potential_mid" _half_potential_step_midpoint!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_1, t_start=it ? NaN : t
    )

    omega = ws.sim_params.rotating_frame_omega
    @timeit_debug TIMER "coriolis" apply_step!(
        CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws
    )
    # Always-update-on-entry semantics: the batched kinetic phase cache is
    # synced to the dt passed in. Costs O(N^ndim) elementwise cis per call.
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt)
    @timeit_debug TIMER "kinetic" apply_step!(
        KineticTerm(), ws.state.psi, 0.0, false, ws
    )
    @timeit_debug TIMER "coriolis" apply_step!(
        CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws
    )

    @timeit_debug TIMER "half_potential_mid" _half_potential_step_midpoint!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_2, t_start=it ? NaN : t + dt / 2
    )

    it || apply_rt_dissipation!(ws, dt, n_comp, N)

    ws.state.t += it ? 0.0 : dt
    ws.state.step += 1

    if it && ws.sim_params.normalize_every > 0
        if ws.state.step % ws.sim_params.normalize_every == 0
            _normalize_psi!(ws.state.psi, ws.grid, n_comp, N)
        end
    end
    nothing
end

# --- Track A1: predictor-corrector midpoint V step ---
#
# The plain `_half_potential_step!` builds the V step as a nested Strang
#   diag · SM · nem · tensor · transB · raman · DDI · raman · transB · tensor · nem · SM · diag
# in which each substep evaluates the mean field (Φ_DDI, c1⟨F⟩, c2 A₀₀, c4+ tensor h)
# at substep ENTRY. The two SM substeps therefore see DIFFERENT ψ values flanking
# the central DDI substep, breaking time-reversal symmetry of the inner Strang.
# The resulting τ² even-power local error survives MPS-4's odd-only Richardson
# cancellation and collapses MPS-4/Y6 to order ~1 on the lab path
# (verified by `scripts/bench/mps4_lab_diagnostic.jl` and
# `test/hamiltonian/test_integrator_order_meanfield.jl`).
#
# `_half_potential_step_midpoint!` symmetrises the V step via a one-pass
# predictor-corrector:
#   1. Predictor: advance a scratch copy of ψ by dt_half/2 using the inner
#      Strang with MF FROZEN at the entry ψ. This gives a midpoint estimate
#      ψ_mid ≈ ψ(t_eval).
#   2. Corrector: advance the real ψ by dt_half using the inner Strang with
#      MF FROZEN at ψ_mid (same MF for every substep — left-right symmetric).
# Cost: ~1.5× a plain V step (predictor at dt/2 of dt_half + corrector at dt_half).
# The predictor's accuracy only needs to be O(dt²) for the corrector to
# achieve a fully symmetric V step, so frozen-MF Strang half-step suffices.
#
# Allocation note: this implementation calls `similar(psi)` per invocation
# to obtain the midpoint buffer. For production tuning move to a dedicated
# Workspace field; for Phase-0 validation per-call alloc is acceptable.
# Transverse Zeeman / Raman currently use `ws.state.psi_scratch` as an
# intermediate; they remain compatible with the midpoint variant because the
# midpoint buffer is allocated separately from `psi_scratch`.

function _half_potential_step_midpoint!(
    ws::Workspace{N},
    dt_half,
    n_comp,
    ndim,
    imaginary_time;
    t_eval::Float64=ws.state.t,
    t_start::Float64=NaN,
    n_picard::Int=2,
) where {N}
    # Single-iteration predictor-corrector achieves O(τ²) accuracy for ψ_mid,
    # but the V-step is then only **approximately** time-reversal symmetric:
    # ψ_mid depends on ψ_orig (forward) vs ψ_after (backward) and these aren't
    # equal at finite τ, leaving an O(τ²) residual in S(τ)·S(-τ) − I. MPS-4's
    # Richardson coefficients (-1/3, 4/3) cancel only the odd-power local-error
    # expansion of a truly symmetric V step, so the residual τ² breaks order
    # recovery (verified: 1-step Picard left MPS-4 lab-path at order ~1 even
    # though absolute error improved 4×).
    #
    # Picard iteration drives ψ_mid toward the implicit-midpoint fixed point.
    # n_picard=2 lifts the time-reversal residual to O(τ⁴), which is sufficient
    # for MPS-4 order recovery. Cost: `n_picard × half-V-step + full V-step`.
    psi_orig = ws.state.psi
    psi_mid_prev = similar(psi_orig)
    psi_mid_curr = similar(psi_orig)

    # Iteration 1: predictor with frozen MF = ψ_orig.
    copyto!(psi_mid_curr, psi_orig)
    ws.state.psi = psi_mid_curr
    try
        _half_potential_step!(
            ws, dt_half / 2, n_comp, ndim, imaginary_time;
            t_eval=t_eval, t_start=t_start, psi_mf=psi_orig,
        )
    finally
        ws.state.psi = psi_orig
    end

    # Refining Picard iterations: MF = previous midpoint estimate.
    for _ in 2:n_picard
        copyto!(psi_mid_prev, psi_mid_curr)
        copyto!(psi_mid_curr, psi_orig)
        ws.state.psi = psi_mid_curr
        try
            _half_potential_step!(
                ws, dt_half / 2, n_comp, ndim, imaginary_time;
                t_eval=t_eval, t_start=t_start, psi_mf=psi_mid_prev,
            )
        finally
            ws.state.psi = psi_orig
        end
    end

    # Corrector with refined midpoint as MF.
    _half_potential_step!(
        ws, dt_half, n_comp, ndim, imaginary_time;
        t_eval=t_eval, t_start=t_start, psi_mf=psi_mid_curr,
    )
    nothing
end

# --- Outer-operator chain: single source of truth ---
#
# The V(dt/2) potential half-step decomposes into an "outer" operator chain
# (everything except DDI) and an "inner" DDI step. Both ITP (which separates
# DDI explicitly to enable Strang-merge at the loop boundary) and RTP (which
# folds DDI inside the half-potential) traverse the SAME outer operator
# order; they only differ in where DDI is called.
#
# This file defines that operator order ONCE in `_outer_operators_fwd!` /
# `_outer_operators_bwd!`. Both `_outer_potential_{fwd,bwd}!` (ITP) and
# `_half_potential_step!` (RTP) delegate to these helpers. Adding a new
# operator → both paths pick it up automatically.
#
# Canonical order (forward):
#   diag → light_shift_offdiag → spin_mixing → singlet_pair → tensor → transverse_zeeman → raman
# Backward direction reverses this for the symmetric Strang sandwich.
#
# History: pre-2026-06-02 ITP and RTP had divergent chains — RTP added the
# transverse Zeeman step but ITP did not, silently dropping bx_wf/by_wf in
# ground-state finding. See
# `mistake_frame_transformation_half_term_silent_cancellation` for context;
# the regression test in `test/integrator/test_outer_operator_equivalence.jl`
# pins ITP and RTP to identical output for the non-DDI chain.

"""
    _outer_operators_fwd!(ws, dt_outer, ndim, imaginary_time; t_eval, ip,
                          zeeman_diag, psi_mf, mg_active)

Forward half of the V(dt/2) outer operator chain. Applied at time `t_eval`
(default `ws.state.t`), with operator interactions `ip` (default
`ws.interactions`). Pass `zeeman_diag` to inject a pre-computed diagonal
(e.g. midpoint-evaluated `TimeDependentZeeman`); otherwise resolved from
`ws.zeeman` at `t_eval`. `psi_mf` plumbs the Picard-midpoint state into
operators that consume it. `mg_active=true` wraps the diag step in
magnetic-gradient apply/remove (RTP only).
"""
function _outer_operators_fwd!(
    ws::Workspace{N}, dt_outer, ndim, imaginary_time;
    t_eval::Float64=ws.state.t,
    ip::InteractionParams=ws.interactions,
    zeeman_diag=nothing,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
    mg_active::Bool=false,
) where {N}
    zd = if zeeman_diag === nothing
        begin
            zee = zeeman_at(ws.zeeman, t_eval)
            zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
        end
    else
        zeeman_diag
    end

    mg_active && _apply_mg_to_V!(ws, t_eval)
    @timeit_debug TIMER "diagonal" _dispatch_diagonal_step!(
        ws, Val(N), zd, dt_outer, imaginary_time, ip; psi_mf
    )
    mg_active && _remove_mg_from_V!(ws, t_eval)

    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        @timeit_debug TIMER "light_shift" apply_light_shift_step!(
            ws.state.psi, ws.light_shift, dt_outer, ndim; imaginary_time
        )
    end

    if is_active(ip[1])
        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, ip[1], dt_outer, ndim; imaginary_time, psi_mf
        )
    end

    c2 = get_cn(ip, 2)
    if is_active(c2)
        @timeit_debug TIMER "singlet_pair" apply_singlet_pair_step!(
            ws.state.psi, ip, ws.spin_matrices.system.F, dt_outer, ndim; imaginary_time, psi_mf
        )
    end

    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, dt_outer, ndim;
            imaginary_time, psi_mf,
        )
    end

    _apply_transverse_zeeman_step!(ws, t_eval, dt_outer, ndim, imaginary_time)

    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, t_eval)
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, dt_outer; imaginary_time
        )
    end
    nothing
end

"""
    _outer_operators_bwd!(ws, dt_outer, ndim, imaginary_time; t_eval, ip,
                          zeeman_diag, psi_mf, mg_active)

Backward (reversed-order) half of the V(dt/2) outer operator chain. Kwargs
match `_outer_operators_fwd!`. The pair fwd-then-bwd is a Strang sandwich
around the inner DDI step (RTP path) or a pair of half-V's separated by an
explicit DDI call (ITP path).
"""
function _outer_operators_bwd!(
    ws::Workspace{N}, dt_outer, ndim, imaginary_time;
    t_eval::Float64=ws.state.t,
    ip::InteractionParams=ws.interactions,
    zeeman_diag=nothing,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
    mg_active::Bool=false,
) where {N}
    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, t_eval)
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, dt_outer; imaginary_time
        )
    end

    _apply_transverse_zeeman_step!(ws, t_eval, dt_outer, ndim, imaginary_time)

    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, dt_outer, ndim;
            imaginary_time, psi_mf,
        )
    end

    c2 = get_cn(ip, 2)
    if is_active(c2)
        @timeit_debug TIMER "singlet_pair" apply_singlet_pair_step!(
            ws.state.psi, ip, ws.spin_matrices.system.F, dt_outer, ndim; imaginary_time, psi_mf
        )
    end

    if is_active(ip[1])
        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, ip[1], dt_outer, ndim; imaginary_time, psi_mf
        )
    end

    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        @timeit_debug TIMER "light_shift" apply_light_shift_step!(
            ws.state.psi, ws.light_shift, dt_outer, ndim; imaginary_time
        )
    end

    zd = if zeeman_diag === nothing
        begin
            zee = zeeman_at(ws.zeeman, t_eval)
            zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
        end
    else
        zeeman_diag
    end

    mg_active && _apply_mg_to_V!(ws, t_eval)
    @timeit_debug TIMER "diagonal" _dispatch_diagonal_step!(
        ws, Val(N), zd, dt_outer, imaginary_time, ip; psi_mf
    )
    mg_active && _remove_mg_from_V!(ws, t_eval)
    nothing
end

# --- ITP leapfrog wrappers ---
# Split V(dt/2) into outer (everything except DDI) and inner DDI step. Outer
# part can be merged between adjacent steps; DDI stays at dt/2.

"""
Outer part of half-potential step: everything except DDI.
Forward direction; delegates to the shared `_outer_operators_fwd!` helper.
"""
function _outer_potential_fwd!(ws::Workspace{N}, dt_outer, n_comp, ndim, imaginary_time) where {N}
    # mg_active=true (defect-6 fix, 2026-06-06): the ITP/RTP chain
    # unification (21c97f92) left the ITP wrappers at the default
    # mg_active=false with no recorded rationale — ground states of
    # MagneticGradient-active configs were found WITHOUT the tilt
    # while the LBFGS gradient included it (ITP and LBFGS optimized
    # different Hamiltonians). No runs/ config was affected (latent).
    _outer_operators_fwd!(ws, dt_outer, ndim, imaginary_time; mg_active=true)
end

"""
Outer part of half-potential step, backward direction; delegates to
`_outer_operators_bwd!`.
"""
function _outer_potential_bwd!(ws::Workspace{N}, dt_outer, n_comp, ndim, imaginary_time) where {N}
    # mg_active=true — see _outer_potential_fwd! (defect-6 fix).
    _outer_operators_bwd!(ws, dt_outer, ndim, imaginary_time; mg_active=true)
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
