# Per-voxel Euler angle Zeeman rotation. Used by the diagonal /
# spin-mixing CPU paths where each spatial point's spinor is rotated by
# its local (phi_x, phi_y, phi_z, dt).

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

    # Use sincos so cos/sin are shared between cis(±angle), and reuse
    # cis(angle)^F instead of a separate cis(F·angle) call (F always
    # integer here). 1 sincos + a few cmuls beats 2 cis on Float64.
    F_int = Int(F)
    sa, ca = sincos(alpha)
    sb, cb = sincos(beta)
    z_neg_alpha = ComplexF64(ca, -sa)
    z_alpha = ComplexF64(ca, sa)
    z_beta = ComplexF64(cb, sb)
    rz_phase = z_alpha^F_int                   # cis(F·α)
    ry_phase = ComplexF64(cb, -sb)^F_int        # cis(-F·β) = cis(-β)^F

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
            s += Vt_Fy[i, j] * v[j]
        end
        w[i] = phase * s
        phase *= z_beta
    end
    @inbounds for i in 1:D
        s = zero(ComplexF64)
        for j in 1:D
            s += V_Fy[i, j] * w[j]
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
        st, ct = sincos(theta)
        z_theta = ComplexF64(ct, st)
        dz_phase = ComplexF64(ct, -st)^F_int       # cis(-F·θ)
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
            s += Vt_Fy[i, j] * v[j]
        end
        w[i] = phase * s
        phase *= z_neg_beta
    end
    # Fused V·w output + Rz(α): exp(-imα) via conj recurrence.
    # `z_alpha` is already defined at the top (saves one `conj`).
    phase = conj(rz_phase)
    @inbounds for i in 1:D
        s = zero(ComplexF64)
        for j in 1:D
            s += V_Fy[i, j] * w[j]
        end
        v[i] = phase * s
        phase *= z_alpha
    end

    SVector(v)
end
