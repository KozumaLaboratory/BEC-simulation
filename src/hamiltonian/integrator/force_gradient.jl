# --- Track C: Chin-Krotscheck 2005 Force-Gradient 4A V step ---
#
# Forward fourth-order factorization of e^{-iτH} for the GPE, following
# Chin & Krotscheck, Phys. Rev. E 72, 036705 (2005) (arXiv:cond-mat/0504270).
# Phase -1 derivation in docs/integrator_track_c_derivation.md.
#
# Algorithm 4A (paper eq. 6.8):
#
#     ψ(dt) = e^{-i·(dt/6)·V(dt)} · e^{-i·(dt/2)·T} · e^{-i·(2dt/3)·Ṽ(dt/2)}
#             · e^{-i·(dt/2)·T} · e^{-i·(dt/6)·V(0)} · ψ(0)
#
# Modified middle V (paper eq. 6.9):
#
#     Ṽ = V + (dt²/48) [V, [T, V]]    where    [V,[T,V]] = |∇V|²   (eq. 6.10)
#
# This implementation is the paper's "4A00" variant — no Picard
# self-consistency on V(0)/V(dt) (uses ψ(0) MF throughout). For
# autonomous V (V_trap only, c₀ = 0) this gives clean 4th order. For
# c₀ ≠ 0, the time-dependent factorization rule (paper §IV eqs 4.5-4.8)
# requires self-consistency for full 4th-order recovery; 4A00 still
# improves over Strang.
#
# # Scope (v1, this commit)
#
# Diagonal-only subset of SpinorBEC: c₁ = 0, no DDI, no spin-mixing,
# no tensor cache, no transverse Zeeman, no Raman / light shift /
# magnetic gradient. Constant ZeemanParams(p, q) allowed. The
# _assert_forcegrad_diagonal_only! guard panics if these constraints
# are violated to prevent silent incorrect results.
#
# Extensions (c₁, DDI, etc.) require additional Phase -1 derivation;
# see Step 5 of docs/integrator_track_c_derivation.md.

export split_step_forcegrad!

function _assert_forcegrad_diagonal_only(ws::Workspace)
    ws.ddi === nothing ||
        error("split_step_forcegrad!: DDI not supported in v1 (diagonal-only). " *
              "See docs/integrator_track_c_derivation.md Step 5.")
    ws.tensor_cache === nothing ||
        error("split_step_forcegrad!: tensor_cache not supported in v1.")
    abs(ws.interactions.c1) < 1e-30 ||
        error("split_step_forcegrad!: c₁ ≠ 0 (spin-mixing) not supported in v1.")
    abs(get_cn(ws.interactions, 2)) < 1e-30 ||
        error("split_step_forcegrad!: c₂ ≠ 0 (nematic singlet pair) not supported in v1.")
    ws.raman === nothing ||
        error("split_step_forcegrad!: Raman not supported in v1.")
    ws.light_shift === nothing ||
        error("split_step_forcegrad!: light_shift not supported in v1.")
    ws.magnetic_gradient === nothing ||
        error("split_step_forcegrad!: magnetic_gradient not supported in v1.")
    bx_lab, by_lab = transverse_b(ws.zeeman, 0.0)
    abs(bx_lab) + abs(by_lab) < 1e-30 ||
        error("split_step_forcegrad!: transverse Zeeman not supported in v1.")
    !(ws.zeeman isa TimeDependentZeeman) ||
        error("split_step_forcegrad!: TimeDependentZeeman not supported in v1.")
    ws.time_dep_interactions === nothing ||
        error("split_step_forcegrad!: time_dep_interactions not supported in v1.")
    ws.lhy === nothing ||
        error("split_step_forcegrad!: scalar LHY not supported in v1.")
    nothing
end

"""
FFT spectral derivative.

Computes |∇V_eff|² pointwise where V_eff(r) = V_trap(r) + c₀·n(r),
n = total density (sum of |ψ_α|² over components). Result stored in
`fgrad_buf` (real-valued, grid-shaped).

Per paper §IV: "The partial derivatives can be computed numerically
by use of finite differences or FFT. Since the FFT derivative converges
exponentially with grid size, the use of FFT derivative is preferable
when the system can be made periodic." This v2 implementation uses
in-place complex FFT for spectral accuracy.

`V_complex_buf` and `grad_complex_buf` are working buffers (allocated
by caller; same shape as density_buf). `plan_fft!` / `plan_ifft!` are
FFTW plans bound to `V_complex_buf`.
"""
function _compute_fgrad_squared!(
    fgrad_buf::Array{T, N},
    V_trap::Array{T, N},
    density_buf::Array{T, N},
    c0::Float64,
    grid::Grid{N, T},
    n_pts::NTuple{N, Int},
    V_complex_buf::Array{Complex{T}, N},
    grad_complex_buf::Array{Complex{T}, N},
    plan_fft!,
    plan_ifft!,
) where {T <: AbstractFloat, N}
    c0_t = T(c0)
    # Form V_eff = V_trap + c0 * density (as complex for in-place FFT)
    @inbounds for I in CartesianIndices(n_pts)
        V_complex_buf[I] = Complex{T}(V_trap[I] + c0_t * density_buf[I], zero(T))
    end
    plan_fft! * V_complex_buf  # in-place forward FFT
    # V_complex_buf now holds F[V_eff] (preserved across axis loop)

    fill!(fgrad_buf, zero(T))
    for ax in 1:N
        k_vec = grid.k[ax]
        @inbounds for I in CartesianIndices(n_pts)
            grad_complex_buf[I] = im * Complex{T}(k_vec[I[ax]]) * V_complex_buf[I]
        end
        plan_ifft! * grad_complex_buf  # in-place inverse FFT
        @inbounds for I in CartesianIndices(n_pts)
            g = real(grad_complex_buf[I])
            fgrad_buf[I] += g * g
        end
    end
    nothing
end

"""
Diagonal step with optional force-gradient correction.

`fg_coeff = 0` → regular diagonal step (no FG correction).
`fg_coeff > 0` → adds `fg_coeff * fgrad_buf[I]` to the effective
potential per voxel. For 4A, `fg_coeff = dt_outer² / 48` only at the
middle stage; outer stages pass `fg_coeff = 0`.

Splits real/imaginary time into separate inner methods (same Bool
dispatch trick as `_diagonal_step_svec!` to avoid closure allocation).
"""
function _diagonal_step_forcegrad!(
    ::Val{N},
    psi::Array,
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    dt_stage,
    density_buf,
    fgrad_buf,
    fg_coeff,
    imaginary_time,
) where {N, D}
    if imaginary_time
        _diagonal_step_forcegrad_imag!(Val(N), psi, V_trap, zeeman_diag, c0,
            dt_stage, density_buf, fgrad_buf, fg_coeff)
    else
        _diagonal_step_forcegrad_real!(Val(N), psi, V_trap, zeeman_diag, c0,
            dt_stage, density_buf, fgrad_buf, fg_coeff)
    end
end

function _diagonal_step_forcegrad_real!(
    ::Val{N}, psi::Array, V_trap, zeeman_diag::SVector{D, Float64},
    c0, dt_stage, density_buf, fgrad_buf, fg_coeff,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    zee_dt = SVector{D, Float64}(ntuple(c -> zeeman_diag[c] * dt_stage, Val(D)))
    zee_cis = SVector{D, ComplexF64}(ntuple(c -> cis(-zee_dt[c]), Val(D)))
    @inbounds for I in CartesianIndices(n_pts)
        n = density_buf[I]
        fg = fgrad_buf[I]
        V_int = c0 * n + fg_coeff * fg
        cis_base = cis(-(V_trap[I] + V_int) * dt_stage)
        for c in 1:D
            psi[I, c] *= cis_base * zee_cis[c]
        end
    end
    nothing
end

function _diagonal_step_forcegrad_imag!(
    ::Val{N}, psi::Array, V_trap, zeeman_diag::SVector{D, Float64},
    c0, dt_stage, density_buf, fgrad_buf, fg_coeff,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    zee_shift = minimum(zeeman_diag)
    zee_dt = SVector{D, Float64}(ntuple(c -> (zeeman_diag[c] - zee_shift) * dt_stage, Val(D)))
    zee_exp = SVector{D, Float64}(ntuple(c -> exp(-zee_dt[c]), Val(D)))
    @inbounds for I in CartesianIndices(n_pts)
        n = density_buf[I]
        fg = fgrad_buf[I]
        V_int = c0 * n + fg_coeff * fg
        exp_base = exp(-(V_trap[I] + V_int) * dt_stage)
        for c in 1:D
            psi[I, c] *= exp_base * zee_exp[c]
        end
    end
    nothing
end

"""
    split_step_forcegrad!(ws::Workspace; midpoint=true, endpoint=true, n_picard=1)

Track C v3 — Force-Gradient 4A step (Chin-Krotscheck 2005 eq. 6.8) with
optional Picard fixed-point iteration on MFs.

Diagonal-only subset of SpinorBEC. See module docstring for restrictions.

# Algorithm

5-stage ABA composition `V K Ṽ K V` with coefficients (1/6, 1/2, 2/3, 1/2, 1/6).
The middle Ṽ stage includes the force-gradient correction
`Ṽ = V + (dt²/48)|∇V|²` per paper eqs. 6.9-6.10.

# Self-consistency hierarchy

* `n_picard=1, midpoint=false, endpoint=false` → 4A00: all V stages use
  ψ(0) MF. Autonomous order 4, nonlinear order 1.
* `n_picard=1, midpoint=true, endpoint=true` → partial 4AWW with Strang
  predictors for ψ(dt/2) and ψ(dt) MFs. Autonomous ≈ order 4, nonlinear
  order ~3 (predictors are O(dt²) accurate).
* `n_picard≥2` → Picard iteration: after each 4A run, update endpoint MF
  from the current ψ and midpoint MF from (ψ(0)+ψ_current)/2 state-average.
  Each iteration improves MF accuracy by one order; n_picard=3 should
  reach nominal order 4.

FFT spectral derivative used for ∇V_eff (paper §IV recommendation).

# Cost

Per outer step:
* `n_picard=1, defaults`: 11 V + 4 K (1 Strang half-step + 1 Strang full
  step predictors + 1 4A composition)
* `n_picard=k ≥ 2`: 11 V + 4 K + (k-1) × (5 V + 2 K + 2 MF re-evals)
"""
function split_step_forcegrad!(ws::Workspace{N};
        midpoint::Bool=true, endpoint::Bool=true, n_picard::Int=1) where {N}
    _assert_forcegrad_diagonal_only(ws)

    dt = ws.sim_params.dt
    it = ws.sim_params.imaginary_time
    n_comp = ws.spin_matrices.system.n_components
    D = n_comp

    # Allocate buffers (production: move to Workspace fields).
    fgrad_buf_0 = similar(ws.density_buf)
    fgrad_buf_mid = similar(ws.density_buf)
    fgrad_buf_end = similar(ws.density_buf)
    density_mid = similar(ws.density_buf)
    density_end = similar(ws.density_buf)
    psi_mid = similar(ws.state.psi)
    psi_end = similar(ws.state.psi)
    psi_init = similar(ws.state.psi)
    copyto!(psi_init, ws.state.psi)  # Save ψ(0) for Picard iteration restarts.

    n_pts = ntuple(d -> size(ws.state.psi, d), Val(N))
    V_complex_buf = Array{ComplexF64}(undef, n_pts...)
    grad_complex_buf = Array{ComplexF64}(undef, n_pts...)
    plan_fft! = FFTW.plan_fft!(V_complex_buf)
    plan_ifft! = FFTW.plan_ifft!(V_complex_buf)

    # 4A coefficients (paper eq. 6.8)
    a_outer = 1 / 6                    # outer V stages
    a_mid = 2 / 3                      # middle Ṽ stage
    b_K = 1 / 2                        # each K stage
    # τ²/48 from paper eq. 6.9 is the IMAGINARY-TIME convention. For real
    # time the τ → it substitution gives (iΔt)²/48 = −Δt²/48, flipping
    # the sign of the gradient correction.
    fg_coeff = it ? (dt^2 / 48) : (-dt^2 / 48)

    # Constant Zeeman only (guard ensures non-time-dependent).
    zee = zeeman_at(ws.zeeman, 0.0)
    zeeman_diag = zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)

    # MF from ψ(0): density + |∇V|²
    _total_density!(ws.density_buf, ws.state.psi, D, N, n_pts)
    _compute_fgrad_squared!(fgrad_buf_0, ws.potential_values, ws.density_buf,
        ws.interactions.c0, ws.grid, n_pts, V_complex_buf, grad_complex_buf,
        plan_fft!, plan_ifft!)

    # Midpoint MF (v2): estimate ψ(dt/2) via Strang half-step on a copy.
    if midpoint
        copyto!(psi_mid, ws.state.psi)
        _strang_substep_on_copy!(psi_mid, ws, dt / 2, fgrad_buf_0, zeeman_diag, it)
        _total_density!(density_mid, psi_mid, D, N, n_pts)
        _compute_fgrad_squared!(fgrad_buf_mid, ws.potential_values, density_mid,
            ws.interactions.c0, ws.grid, n_pts, V_complex_buf, grad_complex_buf,
            plan_fft!, plan_ifft!)
    end

    # Endpoint MF: estimate ψ(dt) via Strang full step on another copy.
    if endpoint
        copyto!(psi_end, ws.state.psi)
        _strang_substep_on_copy!(psi_end, ws, dt, fgrad_buf_0, zeeman_diag, it)
        _total_density!(density_end, psi_end, D, N, n_pts)
        _compute_fgrad_squared!(fgrad_buf_end, ws.potential_values, density_end,
            ws.interactions.c0, ws.grid, n_pts, V_complex_buf, grad_complex_buf,
            plan_fft!, plan_ifft!)
    end

    # Set kinetic phase once (b_K * dt is the same for all K stages of all Picard iters).
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, b_K * dt)

    # Picard iteration on MFs. Each iter restarts ψ from ψ(0), runs full 4A
    # with current MFs, then (if not last iter) updates endpoint MF from
    # the result and midpoint MF from the state-average (ψ(0) + ψ_after)/2.
    density_for_mid = midpoint ? density_mid : ws.density_buf
    fgrad_for_mid = midpoint ? fgrad_buf_mid : fgrad_buf_0
    density_for_end = endpoint ? density_end : ws.density_buf
    fgrad_for_end = endpoint ? fgrad_buf_end : fgrad_buf_0

    for picard_iter in 1:n_picard
        # Restart ψ from ψ(0) for this Picard iteration.
        if picard_iter > 1
            copyto!(ws.state.psi, psi_init)
        end

        # Stage 1: V(dt/6) — MF from ψ(0) (always — entry state is exact).
        @timeit_debug TIMER "fgrad_V" _diagonal_step_forcegrad!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ws.interactions.c0, a_outer * dt, ws.density_buf, fgrad_buf_0, 0.0, it,
        )

        # Stage 2: K(dt/2)
        @timeit_debug TIMER "kinetic" apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)

        # Stage 3: Ṽ(2dt/3) — midpoint MF + FG correction.
        @timeit_debug TIMER "fgrad_Vtilde" _diagonal_step_forcegrad!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ws.interactions.c0, a_mid * dt, density_for_mid, fgrad_for_mid, fg_coeff, it,
        )

        # Stage 4: K(dt/2)
        @timeit_debug TIMER "kinetic" apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)

        # Stage 5: V(dt/6) — endpoint MF.
        @timeit_debug TIMER "fgrad_V" _diagonal_step_forcegrad!(
            Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
            ws.interactions.c0, a_outer * dt, density_for_end, fgrad_for_end, 0.0, it,
        )

        # Picard MF update: refine endpoint MF only from current ψ_after.
        # NOTE: state-averaged midpoint update `(ψ(0)+ψ_after)/2` is intentionally
        # NOT used here. State-averaging introduces the cos(Hτ/2) = 1 - (Hτ)²/8 + ...
        # even-power-in-τ bias documented in docs/integrator_ch3_plan.md §3.3.2
        # (AVF state-averaging negative result). Empirically confirmed at
        # commit 390f474 v3 bench: state-avg midpoint update degraded
        # ForceGrad p=2 from order 2.92 (p=1, Strang predictor) to order 2.00.
        # Proper midpoint Picard would re-run Strang half-step with updated
        # endpoint MF instead of state-averaging — deferred to v3.1+.
        if picard_iter < n_picard && endpoint
            _total_density!(density_end, ws.state.psi, D, N, n_pts)
            _compute_fgrad_squared!(fgrad_buf_end, ws.potential_values, density_end,
                ws.interactions.c0, ws.grid, n_pts, V_complex_buf, grad_complex_buf,
                plan_fft!, plan_ifft!)
        end
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
Strang predictor: advance `psi_buf` (a copy of ψ(0)) by `target_dt` via
V(target_dt/2) K(target_dt) V(target_dt/2) with frozen ψ(0) MF.

Used to estimate ψ(dt/2) (target_dt = dt/2) for the middle Ṽ stage and
ψ(dt) (target_dt = dt) for the final V stage of 4AWW.

The 2nd-order Strang local error gives O(target_dt³) accuracy on the
predicted state; this is O(dt²) for the midpoint estimate and O(dt²)
for the endpoint estimate, sufficient for partial 4AWW behavior.
Picard convergence to the true 4th-order fixed point would require
iterating the full 4A composition with updated MFs — deferred.
"""
function _strang_substep_on_copy!(
    psi_buf::AbstractArray,
    ws::Workspace{N},
    target_dt::Float64,
    fgrad_buf_0::AbstractArray,
    zeeman_diag,
    it::Bool,
) where {N}
    psi_orig = ws.state.psi
    ws.state.psi = psi_buf
    try
        _diagonal_step_forcegrad!(Val(N), psi_buf, ws.potential_values, zeeman_diag,
            ws.interactions.c0, target_dt / 2, ws.density_buf, fgrad_buf_0, 0.0, it)
        _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, target_dt)
        apply_kinetic_step_batched!(psi_buf, ws.batched_kinetic)
        _diagonal_step_forcegrad!(Val(N), psi_buf, ws.potential_values, zeeman_diag,
            ws.interactions.c0, target_dt / 2, ws.density_buf, fgrad_buf_0, 0.0, it)
    finally
        ws.state.psi = psi_orig
    end
    nothing
end
