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
    # Two realizations of exp(-i·c₁·dt·(⟨F⟩·F)) per voxel, selected by
    # `SPIN_TAYLOR_ENABLED[]`:
    #
    #   Taylor–Horner  the spinor stays in stack buffers for the whole
    #                  rotation, so ψ moves through cache twice and no
    #                  trigonometry is needed at all.
    #   Euler 5-stage  the exact reference the Taylor path is gated against:
    #                  per-voxel (α, β, θ) into the shared rotation cache, then
    #                  3 phase passes + 4 BLAS gemms over the (N_spatial, D)
    #                  reshape — ψ through cache ~18 times.
    N_spatial = prod(n_pts)
    F = T(sm.system.F)
    P = reshape(psi, N_spatial, D)
    c1_t = T(c1)
    dt_t = T(dt_frac)

    # The rotation axis and angle come from ⟨F⟩ of the mean-field source (Track
    # A1: `psi_mf` may be a midpoint estimate while `psi` is the state being
    # propagated). `_compute_spin_density!` already states that reduction — this
    # used to be a second, hand-written copy of it fused into an angle pre-pass.
    fx, fy, fz = _spin_field_scratch(T, n_pts)
    _compute_spin_density!(fx, fy, fz, psi_mf, sm, Val(D), ndim_from_n_pts(n_pts), n_pts)

    # `_apply_euler_spin_rotation` skips per-voxel when phi·dt < 1e-14; mirror
    # that at the call level so a polar / vacuum state (⟨F⟩ ≡ 0) pays only the
    # spin-density pass. Taylor would return ψ unchanged there, just not for
    # free.
    fmax = max(maximum(abs, fx), maximum(abs, fy), maximum(abs, fz))
    theta_max = abs(c1_t * dt_t) * fmax * F
    theta_max < T(1e-14) && return nothing

    if SPIN_TAYLOR_ENABLED[]
        # v = ⟨F⟩ raw, scale = c₁·dt — the same split the GPU spin-mixing
        # substep passes to the same operator.
        apply_spin_rotation_taylor!(
            P, fx, fy, fz, spin_tridiag_bands_cached(sm, T),
            c1_t * dt_t, Val(D); imaginary_time, F, src=nothing)
        return nothing
    end

    rc = _get_ddi_rotation_cache_cpu(psi, sm, ndim_from_n_pts(n_pts))
    alpha = rc.alpha
    beta = rc.beta
    theta = rc.theta
    one_t = one(T)
    _voxel_loop!(N_spatial) do k
        @inbounds begin
            px = c1_t * fx[k]
            py = c1_t * fy[k]
            pz = c1_t * fz[k]
            pm = sqrt(px * px + py * py + pz * pz)
            if pm < T(1e-100)
                alpha[k] = T(0)
                beta[k] = T(0)
                theta[k] = T(0)
            else
                alpha[k] = atan(py, px)
                cb = pz / pm
                cb = cb > one_t ? one_t : (cb < -one_t ? -one_t : cb)
                beta[k] = acos(cb)
                theta[k] = pm * dt_t
            end
        end
    end

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

    if f_mag < COUPLING_TOL
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
