export apply_spin_mixing_step!

function apply_spin_mixing_step!(
    psi::AbstractArray{<:Complex, M},
    sm::SpinMatrices{D},
    c1::Float64,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {M, D}
    is_active(c1) || return nothing
    # Use `Val(M - 1)` (spatial dim count from psi's array dimensionality)
    # rather than `ntuple(f, ndim::Int)` so the resulting `n_pts` is a
    # type-stable `NTuple{M-1, Int}`. Without this, the inner
    # `_spin_mixing_loop!(psi::Array{...})` dispatch goes through dynamic
    # dispatch — caught when split_step jumped 1.9 → 5 ms after batched
    # spin_mixing landed.
    n_pts = ntuple(d -> size(psi, d), Val(M - 1))
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf
    _spin_mixing_loop!(psi, psi_mf_eff, sm, c1, dt_frac, Val(D), n_pts, imaginary_time)
    nothing
end

# NOT GENERALIZABLE: D=3 Rodrigues fast path is a deliberate perf specialisation.
# Reason: performance
# Why: at D=3 the 3×3 SMatrix Rodrigues exponential is ~2-3× faster than the
#   generic Euler/gemm batch (gemm setup cost exceeds the 3×3 matvec work).
#   Both paths return bit-identical results — keep BOTH. The dispatcher at
#   D == 3 in `_spin_mixing_loop!` below routes here; D ≠ 3 falls through.
# See: `_spin_mixing_loop!` (generic-D Euler path) below
"""
Spin-1 loop using Rodrigues' formula (allocation-free, machine-precision
unitarity). Faster than the batched-gemm path at D=3 since the gemm has
non-trivial setup cost relative to the tiny 3×3 matvec work.
"""
function _spin_mixing_rodrigues!(psi, psi_mf, sm, c1, dt_frac, n_pts, imaginary_time)
    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            spinor_mf = _get_spinor(psi_mf, I, Val(3))
            spinor_in = _get_spinor(psi, I, Val(3))
            new_spinor = _apply_rodrigues_rotation(
                spinor_mf, spinor_in, sm, c1, dt_frac, imaginary_time
            )
            _set_spinor!(psi, I, new_spinor, Val(3))
        end
    end
end

"""
Generic spin-F loop using Euler angle decomposition.
O(D) spin expectation via raising/lowering, O(D²) rotation via Euler angles.
Uses Matrix (not SMatrix) for V_Fy to avoid heap allocation at large D.
"""
function _spin_mixing_loop!(
    psi::Array{Complex{T}}, psi_mf::AbstractArray, sm, c1, dt_frac,
    ::Val{D}, n_pts, imaginary_time,
) where {T <: AbstractFloat, D}
    if D == 3
        return _spin_mixing_rodrigues!(psi, psi_mf, sm, c1, dt_frac, n_pts, imaginary_time)
    end
    # Same algorithm as the per-voxel scalar Euler decomposition, but the
    # two D×D matvecs (Stages 2 and 4) become single BLAS gemms over the
    # (N_spatial, D) reshape. Pre-pass computes per-voxel (α, β, θ) into
    # the shared rotation cache; the 5-stage core then runs gemm-batched.
    # Saves 30–35% on the per-step rotation cost (matched the DDI win).
    N_spatial = prod(n_pts)
    F = T(sm.system.F)
    fp_coeffs = fp_ladder_coeffs(T, sm.system.F, Val(D))

    rc = _get_ddi_rotation_cache_cpu(psi, sm, ndim_from_n_pts(n_pts))
    alpha = rc.alpha
    beta = rc.beta
    theta = rc.theta

    P = reshape(psi, N_spatial, D)
    Pmf = reshape(psi_mf, N_spatial, D)
    c1_t = T(c1)
    dt_t = T(dt_frac)

    # Pre-pass: for each voxel compute (α, β, θ) from local spinor.
    # Track max|θ| so we can skip the rotation entirely when the spin
    # density vanishes everywhere (polar GS, vacuum regions in scan
    # warm-ups, etc.) — that case used to early-return per voxel in the
    # scalar path. Without this guard the four BLAS gemms run on an
    # all-zero phase array, doing 5 ms of useless work on the bench's
    # polar workspace.
    # Track A1: read ⟨F⟩ from `Pmf` so the rotation operator is built
    # from the user-supplied mean-field source psi (typically a midpoint
    # estimate). Rotation is still applied to `P` (= state psi).
    # Threaded, like the identically-shaped DDI angle pre-pass
    # (`_ddi_compute_angles!`). It was serial only because it also carried the
    # `max θ` reduction in the loop variable; θ is written to the cache anyway,
    # so the guard below reads it back instead. At 32³ × D = 13 this pre-pass —
    # D abs2, D−1 complex products, an atan, an acos and a sqrt per voxel — was
    # the single largest serial region left in a CPU ITP step.
    _voxel_loop!(N_spatial) do k
        @inbounds begin
            fz_val = T(0)
            @simd for c in 1:D
                fz_val += T(F - (c - 1)) * abs2(Pmf[k, c])
            end
            fxy_re = T(0)
            fxy_im = T(0)
            @simd for c in 2:D
                pc_m1 = Pmf[k, c - 1]
                pc = Pmf[k, c]
                prod = conj(pc_m1) * pc
                coef = fp_coeffs[c]
                fxy_re += coef * real(prod)
                fxy_im += coef * imag(prod)
            end
            px = c1_t * fxy_re
            py = c1_t * fxy_im
            pz = c1_t * fz_val
            pm_sq = px * px + py * py + pz * pz
            pm = sqrt(pm_sq)
            if pm < T(1e-100)
                alpha[k] = T(0)
                beta[k] = T(0)
                theta[k] = T(0)
            else
                alpha[k] = atan(py, px)
                cb = pz / pm
                cb = cb > one(T) ? one(T) : (cb < -one(T) ? -one(T) : cb)
                beta[k] = acos(cb)
                theta[k] = pm * dt_t
            end
        end
    end

    # `_apply_euler_spin_rotation` skips per-voxel when phi·dt < 1e-14;
    # mirror that here at the call level so polar / vacuum states pay
    # only the pre-pass cost (~150 μs at 16³) instead of running four
    # gemms over a zero phase field. θ = |c₁⟨F⟩|·dt ≥ 0 everywhere, so
    # max θ² is (max θ)² — the same number the in-loop accumulator held.
    max_theta = maximum(theta)
    max_theta * max_theta < T(1e-28) && return nothing

    if imaginary_time
        _apply_euler_5stage_batched_imag!(P, rc.W, rc.conj_V, rc.V_T,
            alpha, beta, theta, F, Val(D))
    else
        _apply_euler_5stage_batched_real!(P, rc.W, rc.conj_V, rc.V_T,
            alpha, beta, theta, F, Val(D))
    end
    nothing
end

@inline ndim_from_n_pts(::NTuple{N}) where {N} = N

# Generic fallback (GPU / non-Array) — keeps the per-voxel scalar path.
function _spin_mixing_loop!(
    psi, psi_mf::AbstractArray, sm, c1, dt_frac, ::Val{D}, n_pts, imaginary_time
) where {D}
    F = sm.system.F
    m_vals = SVector{D, Float64}(ntuple(c -> F - (c - 1), Val(D)))
    m_vals_t = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = fp_ladder_coeffs(F, Val(D))

    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals

    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            spinor_mf = _get_spinor(psi_mf, I, Val(D))
            spinor_in = _get_spinor(psi, I, Val(D))

            fz_val = 0.0
            @simd for c in 1:D
                fz_val += m_vals_t[c] * abs2(spinor_mf[c])
            end
            fxy_re = 0.0
            fxy_im = 0.0
            @simd for c in 2:D
                prod = conj(spinor_mf[c - 1]) * spinor_mf[c]
                fxy_re += fp_coeffs[c] * real(prod)
                fxy_im += fp_coeffs[c] * imag(prod)
            end

            new_spinor = _apply_euler_spin_rotation(
                spinor_in,
                c1 * fxy_re,
                c1 * fxy_im,
                c1 * fz_val,
                dt_frac,
                F,
                m_vals,
                V_Fy,
                Vt_Fy,
                λ_Fy,
                sm,
                imaginary_time,
            )
            _set_spinor!(psi, I, new_spinor, Val(D))
        end
    end
end

"""
Spin-1 Rodrigues' formula: exp(-iθ(n̂·F)) = I - i sin(θ)(n̂·F) + (cos(θ)-1)(n̂·F)²

`spinor_mf` supplies the ⟨F⟩ that defines the rotation axis and angle; the
rotation is applied to `spinor_in`. For standard (frozen-MF) spin-mixing the
two arguments coincide (`spinor_mf === spinor_in`). For the Track A1 midpoint
predictor-corrector they differ: `spinor_mf` is the midpoint estimate, while
`spinor_in` is the state being propagated.
"""
function _apply_rodrigues_rotation(
    spinor_mf::SVector{3, ComplexF64},
    spinor_in::SVector{3, ComplexF64},
    sm::SpinMatrices{3},
    c1::Float64,
    dt_frac::Float64,
    imaginary_time::Bool,
)
    fx = real(dot(spinor_mf, sm.Fx * spinor_mf))
    fy = real(dot(spinor_mf, sm.Fy * spinor_mf))
    fz = real(dot(spinor_mf, sm.Fz * spinor_mf))

    f_mag = sqrt(fx^2 + fy^2 + fz^2)

    if f_mag < 1e-30
        return spinor_in
    end

    nF = (fx * sm.Fx + fy * sm.Fy + fz * sm.Fz) / f_mag
    nF2 = nF * nF
    θ = c1 * f_mag * dt_frac

    if imaginary_time
        U = SMatrix{3, 3, ComplexF64}(I) - sinh(θ) * nF + (cosh(θ) - 1) * nF2
    else
        U = SMatrix{3, 3, ComplexF64}(I) - 1im * sin(θ) * nF + (cos(θ) - 1) * nF2
    end
    U * spinor_in
end
