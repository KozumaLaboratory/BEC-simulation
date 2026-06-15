# Batched (across voxels) Euler 5-stage rotation via BLAS gemm.
# Used by the CPU-batched spin-mixing path where per-voxel phases differ
# but the V_Fy eigenmatrix is constant. Two variants: real-time (cis on
# the diagonal stage) and imaginary-time (exp with -F shift).

"""
    _apply_euler_5stage_batched_real!(P, W, conj_V, V_T, alpha, beta, theta, F, Val(D))

Apply the same 5-stage Euler rotation that `_apply_euler_spin_rotation`
implements per voxel, but batched across voxels via BLAS gemm. Caller
supplies pre-allocated buffers + per-voxel angles.

* `P` — (N_spatial, D) reshape of ψ, mutated in place
* `W` — (N_spatial, D) scratch buffer (same layout as P)
* `conj_V` — D×D constant `conj(Fy_eigvecs)` (= `transpose(Fy_eigvecs_adj)`)
* `V_T` — D×D constant `transpose(Fy_eigvecs)`
* `alpha, beta, theta` — N_spatial-length per-voxel rotation angles
* `F` — total spin (eltype matches ψ's real type)

Stage 1: Rz(-α) — phase recurrence over c
Stage 2: Ry(-β) — gemm `mul!(W, P, conj_V)` + phase + gemm `mul!(P, W, V_T)`
Stage 3: Dz(θ)  — phase recurrence over c (RTP: cis, ITP: exp variant)
Stage 4: Ry(+β) — gemm + phase + gemm (conj of stage 2 phases)
Stage 5: Rz(+α) — phase recurrence
"""
@inline function _apply_euler_5stage_batched_real!(
    P, W, conj_V, V_T, alpha, beta, theta, F::T, ::Val{D}
) where {T <: AbstractFloat, D}
    N_spatial = size(P, 1)
    # AtomSpecies.F is always integer in this codebase, so cis(F·angle)
    # = cis(angle)^F via integer power is materially faster than a second
    # cis() call (sincos shares cos/sin between cis(α) and cis(-α);
    # F-power then reuses the same complex). Measured 1.7× speedup on
    # each phase stage at D=13.
    F_int = Int(F)

    # Stage 1 — Rz(-α): P[i, c] *= cis((F - c + 1) · α[i])
    @inbounds for i in 1:N_spatial
        ai = alpha[i]
        sa, ca = sincos(ai)
        z_a = Complex{T}(ca, -sa)         # cis(-α) — Complex{T} keeps F32 workspaces F32
        phase = Complex{T}(ca, sa)^F_int  # cis(F·α) = cis(α)^F
        for c in 1:D
            P[i, c] *= phase
            phase *= z_a
        end
    end

    # Stage 2 — Ry(-β) = V · diag(exp(+iβλ)) · V†, λ_Fy = -F..F ascending
    mul!(W, P, conj_V)
    @inbounds for i in 1:N_spatial
        bi = beta[i]
        sb, cb = sincos(bi)
        z_b = Complex{T}(cb, sb)              # cis(β)
        phase = Complex{T}(cb, -sb)^F_int      # cis(-F·β) = cis(-β)^F
        for j in 1:D
            W[i, j] *= phase
            phase *= z_b
        end
    end
    mul!(P, W, V_T)

    # Stage 3 — Dz(θ): P[i, c] *= cis(-(F - c + 1) · θ[i])
    @inbounds for i in 1:N_spatial
        ti = theta[i]
        st, ct = sincos(ti)
        z_t = Complex{T}(ct, st)              # cis(θ)
        phase = Complex{T}(ct, -st)^F_int      # cis(-F·θ)
        for c in 1:D
            P[i, c] *= phase
            phase *= z_t
        end
    end

    # Stage 4 — Ry(+β) = conj of Stage 2 phases
    mul!(W, P, conj_V)
    @inbounds for i in 1:N_spatial
        bi = beta[i]
        sb, cb = sincos(bi)
        z_b = Complex{T}(cb, -sb)              # cis(-β)
        phase = Complex{T}(cb, sb)^F_int        # cis(F·β)
        for j in 1:D
            W[i, j] *= phase
            phase *= z_b
        end
    end
    mul!(P, W, V_T)

    # Stage 5 — Rz(+α)
    @inbounds for i in 1:N_spatial
        ai = alpha[i]
        sa, ca = sincos(ai)
        z_a = Complex{T}(ca, sa)               # cis(α)
        phase = Complex{T}(ca, -sa)^F_int       # cis(-F·α)
        for c in 1:D
            P[i, c] *= phase
            phase *= z_a
        end
    end
    nothing
end

"""ITP variant of `_apply_euler_5stage_batched_real!`. Same structure but
Stage 3 uses the real F_z eigenvalue weight `exp(-m·θ)` (recurrence in
`exp(θ)`). It must NOT add a per-voxel `(m+F)` overflow shift: θ ∝ |f(r)|
is spatially varying, so `exp(-F·θ(r))` is a density reweighting that
survives global normalization and biases the ITP fixed point. The
per-substep angle θ is tiny, so `exp(-m·θ)` cannot overflow (the real-time
path runs the same shift-free `cis(-m·θ)`)."""
@inline function _apply_euler_5stage_batched_imag!(
    P, W, conj_V, V_T, alpha, beta, theta, F::T, ::Val{D}
) where {T <: AbstractFloat, D}
    N_spatial = size(P, 1)
    F_int = Int(F)

    # Stage 1 — Rz(-α)
    @inbounds for i in 1:N_spatial
        ai = alpha[i]
        sa, ca = sincos(ai)
        z_a = Complex{T}(ca, -sa)
        phase = Complex{T}(ca, sa)^F_int
        for c in 1:D
            P[i, c] *= phase
            phase *= z_a
        end
    end

    # Stage 2 — Ry(-β)
    mul!(W, P, conj_V)
    @inbounds for i in 1:N_spatial
        bi = beta[i]
        sb, cb = sincos(bi)
        z_b = Complex{T}(cb, sb)
        phase = Complex{T}(cb, -sb)^F_int
        for j in 1:D
            W[i, j] *= phase
            phase *= z_b
        end
    end
    mul!(P, W, V_T)

    # Stage 3 — Dz(θ) imaginary time: weight component m by exp(-m·θ),
    # the F_z eigenvalue weight. The previous exp(-(m+F)·θ) form added a
    # per-voxel exp(-F·θ) overflow shift; since θ ∝ |f(r)| is spatially
    # varying, that factor is a density reweighting that survives global
    # normalization (only its spatial mean is removed) and biases the ITP
    # fixed point off the variational GP minimum. The real-time variant is
    # immune (there the same factor is an irrelevant global phase).
    @inbounds for i in 1:N_spatial
        ti = theta[i]
        dz_step = exp(ti)
        dz_r = exp(-F * ti)        # c=1 (m=+F): exp(-F·θ) = exp(-m·θ)
        for c in 1:D
            P[i, c] *= dz_r
            dz_r *= dz_step
        end
    end

    # Stage 4 — Ry(+β)
    mul!(W, P, conj_V)
    @inbounds for i in 1:N_spatial
        bi = beta[i]
        sb, cb = sincos(bi)
        z_b = Complex{T}(cb, -sb)
        phase = Complex{T}(cb, sb)^F_int
        for j in 1:D
            W[i, j] *= phase
            phase *= z_b
        end
    end
    mul!(P, W, V_T)

    # Stage 5 — Rz(+α)
    @inbounds for i in 1:N_spatial
        ai = alpha[i]
        sa, ca = sincos(ai)
        z_a = Complex{T}(ca, sa)
        phase = Complex{T}(ca, -sa)^F_int
        for c in 1:D
            P[i, c] *= phase
            phase *= z_a
        end
    end
    nothing
end
