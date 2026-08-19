# --- Split-step dispatcher: top-level Strang/Yoshida + half-potential helpers ---
#
# The top-level `split_step!` Strang step + per-step potential dispatch (diag,
# spin-mixing, singlet_pair, raman, DDI), time-dependent Zeeman/MG handling, and
# the ITP leapfrog "outer-potential" merged-boundary helpers. Low-level FFT
# kernels and shears live in split_step_kernels.jl; integrator-composition
# coefficients and Yoshida/Suzuki/ABA cores live in split_step_composers.jl.

export split_step!, split_step_midpoint!

# --- 2nd-order mean-field (midpoint) half-potential ---
#
# The plain `_half_potential_step!` evaluates each inner-V substep's mean field
# (Φ_DDI, c₀|ψ|², c₁⟨F⟩, c₂A₀₀, tensor h) at that substep's ENTRY ψ. With DDI
# active the central DDI substep's one-sided O(τ) mean-field error does NOT
# cancel, collapsing the Strang order from 2 to ~1 (measured: Eu F=6 + DDI
# drops to ~1.0-1.5; the c_dd=0 control stays 2.0). The midpoint predictor-
# corrector freezes the mean field at the half-step's TEMPORAL midpoint for all
# substeps, restoring 2nd order. A single Picard iteration (n_picard=1) is
# sufficient for 2nd order (n_picard≥2 is only needed for MPS-4/Y6 order
# recovery). See `bench/conv_order.jl`.
#
# `_half_potential!` is the dispatcher used by `split_step!` and the RTP
# leapfrog loop: midpoint when DDI is active (and the toggle is on), plain
# otherwise (already 2nd order, cheaper). Toggle off to reproduce the legacy
# 1st-order DDI path.
const MEANFIELD_MIDPOINT_ENABLED = Ref(true)

@inline function _half_potential!(
    ws::Workspace{N}, dt_half, n_comp, ndim, imaginary_time;
    t_eval::Float64=ws.state.t, t_start::Float64=NaN,
) where {N}
    # Midpoint is for REAL-TIME dynamics accuracy (Strang dt²-order). Imaginary
    # time is relaxation to a fixed point — its dt-order is irrelevant and the
    # non-norm-conserving predictor can overflow — so ITP keeps the plain path.
    if MEANFIELD_MIDPOINT_ENABLED[] && ws.ddi !== nothing && !imaginary_time
        _half_potential_step_midpoint!(
            ws, dt_half, n_comp, ndim, imaginary_time; t_eval, t_start, n_picard=1
        )
    else
        _half_potential_step!(
            ws, dt_half, n_comp, ndim, imaginary_time; t_eval, t_start
        )
    end
end

# Persistent midpoint scratch (one pair per (size, eltype, array-type)) so the
# predictor-corrector does not allocate `similar(psi)` every step — at 128³ F64
# that would churn ~1.7 GB/step through the GC. Buffers are reused across the
# two halves of a step (sequential, no aliasing); only the first is needed for
# n_picard=1, both for n_picard≥2.
const _MIDPOINT_SCRATCH = Dict{UInt64, Any}()

function _get_midpoint_scratch(psi::A) where {A <: AbstractArray}
    key = hash((size(psi), eltype(psi), nameof(typeof(psi).name.wrapper)))
    bufs = get(_MIDPOINT_SCRATCH, key, nothing)
    if bufs === nothing
        bufs = (similar(psi), similar(psi))
        _MIDPOINT_SCRATCH[key] = bufs
    end
    bufs::Tuple{A, A}
end

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
            ws.state.psi, ws.fft_plans, n_comp, N, ws.grid.config.box_size
        )
    end

    @timeit_debug TIMER "half_potential" _half_potential!(
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

    @timeit_debug TIMER "half_potential" _half_potential!(
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

# Diagonal Zeeman SVector at time `t`. Uniform arm: -bz(t)·m + q(t)·m² (with the
# rotating-frame p_eff shift). Spatial arms carry their full diagonal in the
# per-voxel spatial step, so the uniform diagonal here is zero (spatial +
# rotating frame is rejected, so ω_R = 0 ⇒ ZeemanParams(0,0) is exactly zero).
#
# Fast-path / proper-compute split (memory: feedback_fast_path_proper_compute):
# B∥ẑ (no transverse) folds the FULL diagonal `-bz·m + q·m²` into the cheap
# per-component spatial phase here — `q F_z²` is exactly the field-axis form
# `q(b̂·F)²` when b̂=ẑ. A TILTED field (bx≠0||by≠0) with NO spin rotating frame
# instead applies the WHOLE Zeeman (linear + field-axis q(b̂·F)²) as one
# eigen-exact matrix in `_apply_transverse_zeeman_step!`, so we fold NOTHING
# here in that case (returning a zero diagonal). The spin-rotating-frame path
# (ω_R≠0) keeps the legacy diagonal-q + linear-transverse split.
@inline function _resolve_zeeman_diag(ws, t::Float64)
    ωR = ws.sim_params.spin_rotating_frame_omega
    is_uniform(ws.zeeman) || return zeeman_diagonal(ZeemanParams(0.0, 0.0), ws.spin_matrices, ωR)
    bx, by = transverse_b(ws.zeeman, t)
    # A transverse/tilted field is applied WHOLE by `_apply_transverse_zeeman_step!`
    # (the field-axis quadratic AND the RF inertial p_eff = p − ω_R, via the same
    # ZeemanTerm the registry builds), so carry NOTHING diagonal here — both ω_R = 0
    # and ω_R ≠ 0. Folding a lab-z q or p here would double-count and, in the RF,
    # desync the propagator from the operator/energy faces (App. A defect-5).
    (bx != 0.0 || by != 0.0) &&
        return zeeman_diagonal(ZeemanParams(0.0, 0.0), ws.spin_matrices, 0.0)
    zeeman_diagonal(zeeman_at(ws.zeeman, t), ws.spin_matrices, ωR)
end

# Zeeman step taken when a transverse field is present. The WHOLE Zeeman operator
# `H = -(b·F) + q(b̂·F)²` is applied as one eigen-exact D×D matrix exp via
# `_zeeman_propagator`, built from the SAME `ZeemanTerm` the registry constructs
# (`build_h_terms_registry`) — so the propagator, the gradient face
# (`apply_operator!`) and the energy face are one declaration. The field-axis
# quadratic and the spin-rotating-frame correction (rotate (Bx,By) into RF coords,
# p_eff = p − ω_R) are folded into that single term.
#
# Pre-2026-06-21 the ω_R ≠ 0 branch instead applied only the rotated transverse
# LINEAR step and left a lab-z `q F_z²` in the diagonal fold — i.e. the RF
# propagator carried lab-z q while the operator/energy faces (unified by b3881a23)
# carried field-axis q. That desync was App. A defect-5's surviving half: the
# one-step strang generator plateaued at ~5.5e-2 vs the dumb RHS. Unifying on the
# registry term closes it.
function _apply_transverse_zeeman_step!(
    ws::Workspace, t::Float64, dt_frac::Float64, ndim::Int, imaginary_time::Bool
)
    bx_lab, by_lab = transverse_b(ws.zeeman, t)
    (bx_lab == 0.0 && by_lab == 0.0) && return nothing
    zp = zeeman_at(ws.zeeman, t)   # ZeemanParams(p(t), q(t)); p ≡ bz
    omega_R = ws.sim_params.spin_rotating_frame_omega
    bx, by, p_eff = bx_lab, by_lab, zp.p
    if is_active(omega_R, ROTATION_TOL)
        # Spin rotating frame: rotate (Bx,By) into RF coords and shift p_eff,
        # exactly as the registry builds the RF ZeemanTerm.
        c = cos(omega_R * t)
        s = sin(omega_R * t)
        bx = bx_lab * c + by_lab * s
        by = -bx_lab * s + by_lab * c
        p_eff = zp.p - omega_R
    end
    term = ZeemanTerm(bx, by, p_eff, zp.q)
    P = _zeeman_propagator(ws.spin_matrices, term, dt_frac, imaginary_time)
    @timeit_debug TIMER "transverse_zeeman" _apply_rotation_to_spin_axis!(
        ws.state.psi, P, ndim; scratch=ws.state.psi_scratch
    )
    return nothing
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
    psi_in::Union{Nothing, AbstractArray}=nothing,
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
    zeeman_diag_fwd, zeeman_diag_bwd =
        if !isnan(t_start) && is_uniform(ws.zeeman) && _has_time_dependence(ws.zeeman)
            (_resolve_zeeman_diag(ws, t_start + dt_half / 4),
                _resolve_zeeman_diag(ws, t_start + 3 * dt_half / 4))
        else
            zd = _resolve_zeeman_diag(ws, t_eval)
            (zd, zd)
        end
    gpu = _is_gpu(ws.state.psi)

    # `diag · SM · DDI · SM · diag` is the WHOLE half-step whenever nothing else
    # is active, and it then fits in one pass over ψ — bit-identical, not a
    # different splitting. See spin_chain.jl; `_spin_chain_reason` is the list
    # of everything that would otherwise be silently dropped.
    if _spin_chain_reason(ws, ip, psi_mf) === nothing &&
        _spin_chain_available(ws.state.psi, ws)
        @timeit_debug TIMER "spin_chain" _apply_spin_chain!(
            ws.state.psi, ws, dt_half, ndim, imaginary_time, ip, psi_mf,
            zeeman_diag_fwd, zeeman_diag_bwd,
            psi_in === nothing ? ws.state.psi : psi_in,
        )
        return nothing
    end

    # `psi_in` is an out-of-place REQUEST, and only the fused path above can
    # honour it — the operator-by-operator chain below is in-place throughout.
    # Materialising it here keeps the request a pure performance detail: callers
    # get identical values either way, and a substep that makes the fused path
    # ineligible degrades to the copy it would have paid anyway.
    if psi_in !== nothing && psi_in !== ws.state.psi
        copyto!(ws.state.psi, psi_in)
    end

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
            ws.state.psi, ws.fft_plans, n_comp, N, ws.grid.config.box_size
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
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt, it)
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
# Allocation note: midpoint buffers come from `_get_midpoint_scratch` (a
# persistent per-(size,eltype,array-type) cache) so the hot loop does not
# allocate `similar(psi)` every step.
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
    psi_mid_prev, psi_mid_curr = _get_midpoint_scratch(psi_orig)

    # Every Picard iterate starts from ψ_orig, so each one used to open with a
    # full-ψ `copyto!(psi_mid_curr, psi_orig)`. `psi_in` hands that copy to the
    # step itself: the fused kernel already reads each (voxel, component) exactly
    # once before writing it, so reading ψ_orig and writing psi_mid_curr costs
    # nothing over reading and writing one array — and the copy disappears rather
    # than moving. At 128³ D=13 F64 one copy is 436 MB read + 436 MB written; a
    # plain `split_step!` (n_picard = 1, set in `_half_potential!`) took two per
    # step, `split_step_midpoint!` and the MPS/Yoshida composers (n_picard = 2)
    # take four.
    #
    # Iteration 1: predictor with frozen MF = ψ_orig.
    ws.state.psi = psi_mid_curr
    try
        _half_potential_step!(
            ws, dt_half / 2, n_comp, ndim, imaginary_time;
            t_eval=t_eval, t_start=t_start, psi_mf=psi_orig, psi_in=psi_orig,
        )
    finally
        ws.state.psi = psi_orig
    end

    # Refining Picard iterations: MF = previous midpoint estimate.
    for _ in 2:n_picard
        # This iteration's frozen mean field is the previous iterate, which is
        # sitting in `psi_mid_curr`; this iteration must not write over it. Trade
        # the two scratch roles so the write lands in the other buffer.
        psi_mid_prev, psi_mid_curr = psi_mid_curr, psi_mid_prev
        ws.state.psi = psi_mid_curr
        try
            _half_potential_step!(
                ws, dt_half / 2, n_comp, ndim, imaginary_time;
                t_eval=t_eval, t_start=t_start, psi_mf=psi_mid_prev,
                psi_in=psi_orig,
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
# The canonical order is `OUTER_CHAIN`, twenty lines below. There is no prose
# copy of it in this file any more, and there must not be one again: the comment
# that used to sit here listed seven of the nine substeps from 2026-06-02 until
# 2026-08-05 (it omitted `spatial_lhy_spin` and `spatial_zeeman`), CLAUDE.md
# copied the short list from here, and both were corrected twice from each other
# rather than from the code.
#
# `_outer_operators_fwd!` and `_outer_operators_bwd!` were ALSO two hand-written
# copies of that order, one reversed, so adding a substep meant editing the list
# in three places and getting the reversal right by eye. They are now both
# derived from `OUTER_CHAIN` by `_run_outer_chain!`, which makes the Strang
# symmetry a property of the code rather than of the author's care.
#
# What is NOT derived, deliberately: this chain is not the HamTerm registry
# unrolled. The `:diagonal` substep FUSES trap + diagonal Zeeman + c₀ density +
# LHY into one per-voxel kernel (one transcendental instead of D), which is the
# reason it is fast, and `magnetic_gradient` rides it by mutating V around the
# call. `test_outer_chain_registry_mapping.jl` is what keeps that fusion honest:
# it pins the substep → registry-term map and fails if a term ends up in no
# substep at all.
#
# History: pre-2026-06-02 ITP and RTP had divergent chains — RTP added the
# transverse Zeeman step but ITP did not, silently dropping bx_wf/by_wf in
# ground-state finding. See
# `mistake_frame_transformation_half_term_silent_cancellation` for context;
# a dedicated regression test (there was one under `test/hamiltonian/`; it was
# cited at the wrong path by the commit that created it, ran in no tier, and
# was deleted by `e3151c9a`. **No live gate pins ITP/RTP outer-chain
# equivalence today** — the per-term registry gates cover each operator, not
# the claim that both callers issue the same sequence.)
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
# Arbitrary B(r) spatial Zeeman step (CPU-only; gated off when inactive, and
# make_workspace forbids spatial_zeeman on a GPU backend so ws.state.psi is a
# host Array whenever this fires). Time-independent field in v1.
@inline function _apply_spatial_zeeman_step!(ws, t_eval, dt, imaginary_time)
    is_uniform(ws.zeeman) && return nothing
    # The general B(r,t) arm is stored abstractly in the shared Workspace
    # (`ZeemanField{<:SpatioTemporalProfiles{N}}`) so the closures don't leak into
    # the 23-param Workspace specialisation. Route through a @noinline barrier so
    # this one per-step call is a runtime dispatch that recovers the CONCRETE arm —
    # after which `field_arrays_at` → `_materialise_general!` → the per-voxel `f(…)`
    # closure call is monomorphic (allocation-free). Inlining here would instead bind
    # the barrier to the abstract bound and box every voxel call (~1.8 MB/step).
    _spatial_zeeman_step_barrier!(ws.state.psi, ws.zeeman, ws.spin_matrices, t_eval, dt,
        imaginary_time)
    nothing
end

@noinline function _spatial_zeeman_step_barrier!(
    psi, zf::ZeemanField, spin_matrices, t_eval, dt, imaginary_time)
    apply_spatial_zeeman_step!(
        psi, field_arrays_at(zf, t_eval)..., spin_matrices, dt, imaginary_time)
    nothing
end

"""
    OUTER_CHAIN

The V(dt/2) outer operator order, forward, declared ONCE. `_outer_operators_fwd!`
runs it as written and `_outer_operators_bwd!` runs `reverse(OUTER_CHAIN)`, so the
Strang sandwich is symmetric by construction.

Adding a substep means: add a symbol here, add its `_outer_substep!` method, and
classify it in `OUTER_CHAIN_TERMS`. Nothing else in this file, and no prose list
anywhere, needs to change — which is the point. Three separate hand-maintained
copies of this order (two function bodies and a comment) rotted between
2026-06-02 and 2026-08-05.
"""
const OUTER_CHAIN = (
    :diagonal,
    :light_shift_offdiag,
    :spin_mixing,
    :spatial_lhy_spin,
    :singlet_pair,
    :tensor,
    :transverse_zeeman,
    :spatial_zeeman,
    :raman,
)

"""
    OUTER_CHAIN_TERMS

Which `H_TERMS_CANONICAL_ORDER` slots each substep propagates.

This is the map the fusion makes non-obvious: `:diagonal` carries FOUR terms in
one per-voxel kernel, and `magnetic_gradient` rides it by mutating `V` around
the call rather than as a substep of its own. Written down so that
`test_outer_chain_registry_mapping.jl` can check the map is total — every
registry term is propagated by some substep, by the K half-step, by the inner
DDI step, or by the real-time epilogue, and none is propagated by nothing.
"""
const OUTER_CHAIN_TERMS = (
    diagonal=(:trap, :zeeman, :density_c0, :lhy, :magnetic_gradient),
    light_shift_offdiag=(:light_shift,),
    spin_mixing=(:spin_c1,),
    spatial_lhy_spin=(:lhy,),
    singlet_pair=(:tensor,),
    tensor=(:tensor,),
    transverse_zeeman=(:zeeman,),
    spatial_zeeman=(:spatial_zeeman,),
    raman=(:raman,),
)

"""
Registry slots propagated OUTSIDE the outer chain, with where. Each is a claim a
test can check, not a note — `:loss` in particular was dead on every RTP driver
for a month (`test_path_coverage.jl` invariant A exists because of it).
"""
const OUTER_CHAIN_EXTERNAL_TERMS = (
    kinetic="the K(dt) half-step of the Strang sandwich",
    coriolis="the Coriolis 3-shear either side of K(dt)",
    ddi="the inner DDI step, between the fwd and bwd outer halves",
    loss="the real-time dissipative epilogue (`apply_rt_dissipation!`)",
)

"""
Everything one traversal of the outer chain needs, as ONE concrete value.

Parameterised on the argument types rather than typed abstractly: this is passed
through an unrolled recursion, and an `Any` field here would widen every substep
call. It does not reach `make_workspace`, so it is outside the Workspace
specialisation blast radius (CLAUDE.md commitment 8).
"""
struct OuterChainCtx{IP, ZD, PM}
    dt::Float64
    ndim::Int
    imaginary_time::Bool
    t_eval::Float64
    ip::IP
    zd::ZD
    psi_mf::PM
    mg_active::Bool
end

# Unrolled traversal. Recursion on a Tuple rather than `for op in chain` so the
# specialisation is guaranteed rather than dependent on const-prop, the same
# reason `build_h_terms_registry` returns an NTuple.
@inline _run_outer_chain!(::Tuple{}, ::Workspace, ::OuterChainCtx) = nothing
@inline function _run_outer_chain!(chain::Tuple, ws::Workspace, c::OuterChainCtx)
    _outer_substep!(Val(first(chain)), ws, c)
    _run_outer_chain!(Base.tail(chain), ws, c)
end

# --- the substeps themselves; each gates itself, exactly as before ---

@inline function _outer_substep!(::Val{:diagonal}, ws::Workspace{N}, c) where {N}
    c.mg_active && _apply_mg_to_V!(ws, c.t_eval)
    @timeit_debug TIMER "diagonal" _dispatch_diagonal_step!(
        ws, Val(N), c.zd, c.dt, c.imaginary_time, c.ip; psi_mf=c.psi_mf
    )
    c.mg_active && _remove_mg_from_V!(ws, c.t_eval)
    nothing
end

@inline function _outer_substep!(::Val{:light_shift_offdiag}, ws::Workspace, c)
    if ws.light_shift !== nothing && !ws.light_shift.is_diagonal
        @timeit_debug TIMER "light_shift" apply_light_shift_step!(
            ws.state.psi, ws.light_shift, c.dt, c.ndim; imaginary_time=c.imaginary_time
        )
    end
    nothing
end

@inline function _outer_substep!(::Val{:spin_mixing}, ws::Workspace, c)
    if is_active(c.ip[1])
        @timeit_debug TIMER "spin_mixing" apply_spin_mixing_step!(
            ws.state.psi, ws.spin_matrices, c.ip[1], c.dt, c.ndim;
            imaginary_time=c.imaginary_time, psi_mf=c.psi_mf,
        )
    end
    nothing
end

# The spin half of a spatially-varying LHY (issue #131). No-op for every other
# LHY — `_lhy_needs_spin` is a compile-time trait, so nothing else pays for it.
@inline function _outer_substep!(::Val{:spatial_lhy_spin}, ws::Workspace, c)
    if _lhy_needs_spin(ws.lhy)
        @timeit_debug TIMER "spatial_lhy_spin" apply_spatial_lhy_spin_step!(
            ws.state.psi, ws.lhy, ws.spin_matrices, c.dt, c.ndim;
            imaginary_time=c.imaginary_time, psi_mf=c.psi_mf,
        )
    end
    nothing
end

@inline function _outer_substep!(::Val{:singlet_pair}, ws::Workspace, c)
    if is_active(get_cn(c.ip, 2))
        @timeit_debug TIMER "singlet_pair" apply_singlet_pair_step!(
            ws.state.psi, c.ip, ws.spin_matrices.system.F, c.dt, c.ndim;
            imaginary_time=c.imaginary_time, psi_mf=c.psi_mf,
        )
    end
    nothing
end

@inline function _outer_substep!(::Val{:tensor}, ws::Workspace, c)
    if ws.tensor_cache !== nothing
        @timeit_debug TIMER "tensor" apply_tensor_interaction_step!(
            ws.state.psi, ws.tensor_cache, ws.spin_matrices, c.dt, c.ndim;
            imaginary_time=c.imaginary_time, psi_mf=c.psi_mf,
        )
    end
    nothing
end

@inline _outer_substep!(::Val{:transverse_zeeman}, ws::Workspace, c) =
    _apply_transverse_zeeman_step!(ws, c.t_eval, c.dt, c.ndim, c.imaginary_time)

@inline _outer_substep!(::Val{:spatial_zeeman}, ws::Workspace, c) =
    _apply_spatial_zeeman_step!(ws, c.t_eval, c.dt, c.imaginary_time)

@inline function _outer_substep!(::Val{:raman}, ws::Workspace, c)
    if ws.raman !== nothing
        raman_now = raman_at(ws.raman, c.t_eval)
        @timeit_debug TIMER "raman" apply_raman_step!(
            ws.state.psi, ws.spin_matrices, raman_now, ws.grid, c.dt;
            imaginary_time=c.imaginary_time,
        )
    end
    nothing
end

@inline function _outer_chain_ctx(
    ws::Workspace, dt_outer, ndim, imaginary_time, t_eval, ip, zeeman_diag, psi_mf, mg_active
)
    zd = zeeman_diag === nothing ? _resolve_zeeman_diag(ws, t_eval) : zeeman_diag
    OuterChainCtx(
        Float64(dt_outer), Int(ndim), imaginary_time, t_eval, ip, zd, psi_mf, mg_active
    )
end

function _outer_operators_fwd!(
    ws::Workspace{N}, dt_outer, ndim, imaginary_time;
    t_eval::Float64=ws.state.t,
    ip::InteractionParams=ws.interactions,
    zeeman_diag=nothing,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
    mg_active::Bool=false,
) where {N}
    c = _outer_chain_ctx(
        ws, dt_outer, ndim, imaginary_time, t_eval, ip, zeeman_diag, psi_mf, mg_active)
    _run_outer_chain!(OUTER_CHAIN, ws, c)
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
    c = _outer_chain_ctx(
        ws, dt_outer, ndim, imaginary_time, t_eval, ip, zeeman_diag, psi_mf, mg_active)
    # `reverse` of a Tuple is a compile-time constant, so this unrolls to the
    # mirrored sequence with no runtime cost — and cannot drift from the forward
    # one, which is the whole reason the chain is a value.
    _run_outer_chain!(reverse(OUTER_CHAIN), ws, c)
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
