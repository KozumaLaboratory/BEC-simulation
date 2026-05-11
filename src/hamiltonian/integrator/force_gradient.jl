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
Central finite difference with periodic wrap.

Computes |∇V_eff|² pointwise where V_eff(r) = V_trap(r) + c₀·n(r),
n = total density (sum of |ψ_α|² over components). Result stored in
`fgrad_buf` (real-valued, grid-shaped).

Per paper §IV: "The partial derivatives can be computed numerically
by use of finite differences or FFT. Since the FFT derivative converges
exponentially with grid size, the use of FFT derivative is preferable
when the system can be made periodic." We use central finite
differences here for simplicity; the periodic wrap matches the periodic
BC of the FFT kinetic step.
"""
function _compute_fgrad_squared!(
    fgrad_buf::Array{T, N},
    V_trap::Array{T, N},
    density_buf::Array{T, N},
    c0::Float64,
    dx::NTuple{N, T},
    n_pts::NTuple{N, Int},
) where {T <: AbstractFloat, N}
    c0_t = T(c0)
    inv_2dx = ntuple(d -> T(0.5) / dx[d], Val(N))
    @inbounds for I in CartesianIndices(n_pts)
        s = zero(T)
        for ax in 1:N
            i_p = I[ax] == n_pts[ax] ? 1 : I[ax] + 1
            i_m = I[ax] == 1 ? n_pts[ax] : I[ax] - 1
            Ip = CartesianIndex(ntuple(d -> d == ax ? i_p : I[d], Val(N)))
            Im = CartesianIndex(ntuple(d -> d == ax ? i_m : I[d], Val(N)))
            grad_V = (V_trap[Ip] - V_trap[Im]) * inv_2dx[ax]
            grad_n = (density_buf[Ip] - density_buf[Im]) * inv_2dx[ax]
            g = grad_V + c0_t * grad_n
            s += g * g
        end
        fgrad_buf[I] = s
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
    split_step_forcegrad!(ws::Workspace)

Track C v1 — Force-Gradient 4A step (Chin-Krotscheck 2005 eq. 6.8).

Diagonal-only subset of SpinorBEC. See module docstring for restrictions.

# Algorithm

5-stage ABA composition `V K Ṽ K V` with coefficients (1/6, 1/2, 2/3, 1/2, 1/6).
The middle Ṽ stage includes the force-gradient correction
`Ṽ = V + (dt²/48)|∇V|²` per paper eqs. 6.9-6.10. This is the "4A00"
variant: no Picard self-consistency. Order 4 holds cleanly for c₀ = 0
autonomous case; for c₀ ≠ 0 the mean-field time-dependence introduces
a sub-dominant error but the scheme still improves over Strang.

# Cost

5 V stages (each = 1 diagonal step kernel call) + 2 K stages (FFT-based).
Density computed once at the start of each outer step; |∇V_eff|² computed
once per outer step. Comparable to Yoshida-4 plain composition.
"""
function split_step_forcegrad!(ws::Workspace{N}) where {N}
    _assert_forcegrad_diagonal_only(ws)

    dt = ws.sim_params.dt
    it = ws.sim_params.imaginary_time
    n_comp = ws.spin_matrices.system.n_components
    D = n_comp

    # Allocate FG buffer (production: move to Workspace field).
    fgrad_buf = similar(ws.density_buf)

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

    # Compute n = Σ_c |ψ_c|² (MF source for 4A00 = ψ(0)).
    n_pts = ntuple(d -> size(ws.state.psi, d), Val(N))
    _total_density!(ws.density_buf, ws.state.psi, D, N, n_pts)

    # Compute |∇V_eff|² once (4A00 reuses ψ(0) MF for all V stages).
    _compute_fgrad_squared!(fgrad_buf, ws.potential_values, ws.density_buf,
        ws.interactions.c0, ws.grid.dx, n_pts)

    # Stage 1: V(dt/6) — no FG correction (outer stage).
    @timeit_debug TIMER "fgrad_V" _diagonal_step_forcegrad!(
        Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
        ws.interactions.c0, a_outer * dt, ws.density_buf, fgrad_buf, 0.0, it,
    )

    # Stage 2: K(dt/2) — phase updated for half-step duration.
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, b_K * dt)
    @timeit_debug TIMER "kinetic" apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)

    # Stage 3: Ṽ(2dt/3) — with FG correction.
    @timeit_debug TIMER "fgrad_Vtilde" _diagonal_step_forcegrad!(
        Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
        ws.interactions.c0, a_mid * dt, ws.density_buf, fgrad_buf, fg_coeff, it,
    )

    # Stage 4: K(dt/2) — phase still configured for b_K * dt from stage 2.
    @timeit_debug TIMER "kinetic" apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)

    # Stage 5: V(dt/6) — no FG correction (outer stage).
    @timeit_debug TIMER "fgrad_V" _diagonal_step_forcegrad!(
        Val(N), ws.state.psi, ws.potential_values, zeeman_diag,
        ws.interactions.c0, a_outer * dt, ws.density_buf, fgrad_buf, 0.0, it,
    )

    ws.state.t += it ? 0.0 : dt
    ws.state.step += 1

    if it && ws.sim_params.normalize_every > 0
        if ws.state.step % ws.sim_params.normalize_every == 0
            _normalize_psi!(ws.state.psi, ws.grid, n_comp, N)
        end
    end
    nothing
end
