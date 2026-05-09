@inline function _component_slice(ndim::Int, n_pts::NTuple{N, Int}, c::Int) where {N}
    ntuple(N + 1) do d
        d <= N ? (1:n_pts[d]) : c
    end
end

@inline function _get_spinor(psi, I, n_comp)
    SVector{n_comp, ComplexF64}(ntuple(c -> psi[I, c], n_comp))
end

@inline function _get_spinor(psi, I, ::Val{D}) where {D}
    SVector{D, ComplexF64}(ntuple(c -> psi[I, c], Val(D)))
end

@inline function _set_spinor!(psi, I, spinor, n_comp)
    for c in 1:n_comp
        psi[I, c] = spinor[c]
    end
end

@inline function _set_spinor!(psi, I, spinor, ::Val{D}) where {D}
    for c in 1:D
        psi[I, c] = spinor[c]
    end
end

function _exp_i_hermitian(
    H::SMatrix{D, D, ComplexF64},
    dt::Float64,
    imaginary_time::Bool,
) where {D}
    eig = eigen(Hermitian(H))
    V = eig.vectors

    if imaginary_time
        expD = SVector{D, ComplexF64}(exp.(-eig.values .* dt))
    else
        expD = SVector{D, ComplexF64}(cis.(-eig.values .* dt))
    end

    V * Diagonal(expD) * V'
end

"""
Allocation-free matrix-vector product: result = V * x.
Uses ntuple to build SVector{D} without SMatrix temporaries.
Works with any AbstractMatrix (Matrix, Adjoint, SMatrix).
"""
@inline function _matvec(V::AbstractMatrix{ComplexF64}, x::SVector{D, ComplexF64}) where {D}
    SVector{D, ComplexF64}(
        ntuple(Val(D)) do i
            s = zero(ComplexF64)
            for j in 1:D
                @inbounds s += V[i, j] * x[j]
            end
            s
        end,
    )
end


"""
Apply exp(-i dt (phi·F)) via Euler angle decomposition.

Decomposes into Rz(α) Ry(β) Dz(θ) Ry(-β) Rz(-α) using spherical angles
of phi and precomputed Fy eigendecomposition.

Uses MVector scratch buffers to avoid intermediate SVector heap allocations
at large D (e.g. D=13 for Eu151). Only one SVector construction at the end.

Handles both real-time (Dz: cis) and imaginary-time (Dz: exp) propagation.
"""
@inline function _apply_euler_spin_rotation(
    spinor::SVector{D, ComplexF64},
    phi_x,
    phi_y,
    phi_z,
    dt,
    F,
    m_vals::SVector{D, Float64},
    V_Fy::AbstractMatrix{ComplexF64},
    Vt_Fy::AbstractMatrix{ComplexF64},
    λ_Fy::SVector{D, Float64},
    sm::SpinMatrices,
    imaginary_time::Bool,
) where {D}
    phi_mag = sqrt(phi_x^2 + phi_y^2 + phi_z^2)
    if phi_mag * abs(dt) < 1e-14
        return spinor
    end

    beta = acos(clamp(phi_z / phi_mag, -1.0, 1.0))
    alpha = atan(phi_y, phi_x)
    theta = phi_mag * dt

    v = MVector{D, ComplexF64}(undef)
    w = MVector{D, ComplexF64}(undef)

    z_neg_alpha = cis(-alpha)
    z_beta = cis(beta)

    rz_phase = cis(F * alpha)
    ry_phase = cis(-F * beta)

    # Rz(-α): exp(+imα) via recurrence
    phase = rz_phase
    @inbounds for c in 1:D
        v[c] = phase * spinor[c]
        phase *= z_neg_alpha
    end

    # Ry(-β) = V · diag(exp(+iβλ)) · Vt via recurrence.
    # Assumes λ_Fy = -F, -F+1, ..., F (ascending), guaranteed by eigen(Hermitian(...)).
    phase = ry_phase
    @inbounds for i in 1:D
        s = zero(ComplexF64)
        for j in 1:D
            ;
            s += Vt_Fy[i, j] * v[j];
        end
        w[i] = phase * s
        phase *= z_beta
    end
    @inbounds for i in 1:D
        s = zero(ComplexF64)
        for j in 1:D
            ;
            s += V_Fy[i, j] * w[j];
        end
        v[i] = s
    end

    # Dz(θ): RTP uses cis(-mθ), ITP uses exp(-mθ).
    # ITP applies a constant -F shift so the largest factor is exp(0)=1
    # (m=-F gets factor 1, m=+F gets exp(-2F·θ)). Without this shift the
    # m=-F component gets exp(+F·θ) and explodes (constant shift is removed
    # by the subsequent normalization step).
    if imaginary_time
        dz_r = exp(-2.0 * F * theta)
        dz_step = exp(theta)
        @inbounds for c in 1:D
            v[c] *= dz_r
            dz_r *= dz_step
        end
    else
        dz_phase = cis(-F * theta)
        z_theta = cis(theta)
        @inbounds for c in 1:D
            v[c] *= dz_phase
            dz_phase *= z_theta
        end
    end

    # Ry(β) = V · diag(exp(-iβλ)) · Vt — conj of Ry(-β) phases
    phase = conj(ry_phase)
    z_neg_beta = conj(z_beta)
    @inbounds for i in 1:D
        s = zero(ComplexF64)
        for j in 1:D
            ;
            s += Vt_Fy[i, j] * v[j];
        end
        w[i] = phase * s
        phase *= z_neg_beta
    end
    # Fused V·w output + Rz(α): exp(-imα) via conj recurrence
    phase = conj(rz_phase)
    z_alpha = conj(z_neg_alpha)
    @inbounds for i in 1:D
        s = zero(ComplexF64)
        for j in 1:D
            ;
            s += V_Fy[i, j] * w[j];
        end
        v[i] = phase * s
        phase *= z_alpha
    end

    SVector(v)
end

"""
    apply_euler_5stage_fused!(P, W, α_col, β_col, θ_col,
                               m_row, m_shift_row, λ_row,
                               V_T, conj_V; imaginary_time=false)

Whole-array Euler 5-stage rotation `R_z(α) R_y(β) D_z(θ) R_y(-β) R_z(-α)`
applied across an `(N, D)` per-point spinor field `P` using the fused
broadcast pattern `(N, 1) .* (1, D)`. Matches the per-point CPU
`_apply_euler_spin_rotation` exactly (Step 1 = `cis(+m·α)`, Step 5 =
`cis(-m·α)`); GPU paths previously each rolled their own copy of this
sequence with subtle sign drift (caught 2026-04-26 in the GPU
spin_mixing / raman audits).

Arguments
=========
- `P` : `(N, D)` spinor field, mutated in place to hold the rotated state.
- `W` : same shape as `P`, scratch buffer for V†ψ.
- `α_col, β_col, θ_col` : `(N, 1)` per-point rotation angles.
- `m_row` : `(1, D)` magnetic quantum numbers `[F, F-1, …, -F]`.
- `m_shift_row` : `(1, D)`, equals `m_row .- F`. Used for the imaginary-time
  branch's overflow-safe diagonal step.
- `λ_row` : `(1, D)` ascending Fy eigenvalues `[-F, -F+1, …, F]`.
- `V_T, conj_V` : Fy eigenvector matrix and its conjugate, in the
  layout that backs the existing `mul!(W, P, conj_V)` / `mul!(P, W, V_T)`
  call sites (so this works for both CPU `Matrix` and GPU `CuArray`
  backings — the `mul!` dispatches to cuBLAS for `CuArray`).

The fused pattern collapses 5D per-call broadcasts (D phases × 5 steps,
each previously a per-column kernel launch on GPU) into 5 single
launches, regardless of D. For F=6 that's a 13× reduction in launches
on the rotation block.
"""
@inline function apply_euler_5stage_fused!(
    P, W,
    α_col, β_col, θ_col,
    m_row, m_shift_row, λ_row,
    V_T, conj_V;
    imaginary_time::Bool=false,
    cis_PD=nothing,
)
    # `cis_PD` (size of P, Complex) is a pre-allocated scratch for the
    # phase factor `cis(...)` so the broadcasts stay in-place — required
    # for any future CUDA Graph capture, since per-call `cis.(...)`
    # would allocate a fresh CuArray each invocation and invalidate the
    # captured argument pointer. When nothing is supplied (legacy CPU
    # fallback / one-shot calls) we let Julia allocate, matching prior
    # behaviour.
    if cis_PD === nothing
        P .*= cis.(m_row .* α_col)
        mul!(W, P, conj_V)
        W .*= cis.(β_col .* λ_row)
        mul!(P, W, V_T)
        if imaginary_time
            P .*= exp.(.-m_shift_row .* θ_col)
        else
            P .*= cis.(.-m_row .* θ_col)
        end
        mul!(W, P, conj_V)
        W .*= cis.(.-β_col .* λ_row)
        mul!(P, W, V_T)
        P .*= cis.(.-m_row .* α_col)
    else
        # Step 1: R_z(-α) via in-place cis scratch
        @. cis_PD = cis(m_row * α_col)
        @. P *= cis_PD
        # Step 2: R_y(-β) via Vt
        mul!(W, P, conj_V)
        @. cis_PD = cis(β_col * λ_row)         # reuse same scratch on W (same shape)
        @. W *= cis_PD
        mul!(P, W, V_T)
        # Step 3: D_z(θ)
        if imaginary_time
            @. cis_PD = exp(-m_shift_row * θ_col)
        else
            @. cis_PD = cis(-m_row * θ_col)
        end
        @. P *= cis_PD
        # Step 4: R_y(β)
        mul!(W, P, conj_V)
        @. cis_PD = cis(-β_col * λ_row)
        @. W *= cis_PD
        mul!(P, W, V_T)
        # Step 5: R_z(α)
        @. cis_PD = cis(-m_row * α_col)
        @. P *= cis_PD
    end
    nothing
end
