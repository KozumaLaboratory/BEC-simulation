# Fused Euler 5-stage rotation kernel.
#
# Replaces the broadcast-+-gemm chain in `apply_euler_5stage_fused!` with
# a single CUDA kernel that processes every spatial point in registers
# and reads the D×D Fy eigenvector matrices once into shared memory per
# block. For F=6 (D=13) on a 64³ F32 grid this collapses the 7
# kernel launches of the broadcast version (Step 1 phase, R_y(-β)
# matmul-+-diag-+-matmul, D_z phase, R_y(β) matmul-+-diag-+-matmul,
# Step 5 phase) into 1, eliminates the (N,D) tmp buffer round-trip
# through HBM, and folds the per-point phase factors into the matvec
# accumulation loops.
#
# Two layout assumptions:
#   - `psi_2d` is column-major with shape (N, D). Each row is a spinor.
#   - `V` is the Fy eigenvector matrix and `conj_V[c, j] = conj(V[c, j])`.
#     The transpose `V_T` isn't needed: `Σ_j tmp[j] * V_T[j, c] = Σ_j
#     tmp[j] * V[c, j]`.

using StaticArrays: MVector

@inline function _euler_5stage_kernel!(
    psi, α, β, θ, m_gpu, m_shift, λ_gpu, V, conj_V,
    ::Val{D}, ::Val{IT},
) where {D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    N = size(psi, 1)
    i > N && return nothing

    T = real(eltype(psi))
    CT = Complex{T}

    α_i = α[i, 1]
    β_i = β[i, 1]
    θ_i = θ[i, 1]

    # Load spinor into thread-local stack array.
    s = MVector{D, CT}(undef)
    @inbounds for c in 1:D
        s[c] = psi[i, c]
    end

    # --- Step 1: R_z(-α) → s_c *= cis(+m_c · α) ---
    @inbounds for c in 1:D
        s[c] *= cis(m_gpu[1, c] * α_i)
    end

    # --- Step 2: R_y(-β) = V · diag(cis(+βλ)) · conj(V)ᵀ ---
    # As row × matrix: s_new = (s · conj_V) ⊙ cis(βλ); s_final = s_new · V^T
    tmp = MVector{D, CT}(undef)
    @inbounds for j in 1:D
        acc = zero(CT)
        for c in 1:D
            acc += s[c] * conj_V[c, j]
        end
        tmp[j] = acc * cis(β_i * λ_gpu[1, j])
    end
    @inbounds for c in 1:D
        acc = zero(CT)
        for j in 1:D
            acc += tmp[j] * V[c, j]   # V_T[j, c] = V[c, j]
        end
        s[c] = acc
    end

    # --- Step 3: D_z(θ) ---
    if IT
        @inbounds for c in 1:D
            s[c] *= exp(-m_shift[1, c] * θ_i)
        end
    else
        @inbounds for c in 1:D
            s[c] *= cis(-m_gpu[1, c] * θ_i)
        end
    end

    # --- Step 4: R_y(β) (mirror of Step 2 with β → -β) ---
    @inbounds for j in 1:D
        acc = zero(CT)
        for c in 1:D
            acc += s[c] * conj_V[c, j]
        end
        tmp[j] = acc * cis(-β_i * λ_gpu[1, j])
    end
    @inbounds for c in 1:D
        acc = zero(CT)
        for j in 1:D
            acc += tmp[j] * V[c, j]
        end
        s[c] = acc
    end

    # --- Step 5: R_z(α) → s_c *= cis(-m_c · α) ---
    @inbounds for c in 1:D
        s[c] *= cis(-m_gpu[1, c] * α_i)
    end

    @inbounds for c in 1:D
        psi[i, c] = s[c]
    end
    return nothing
end

"""
    apply_euler_5stage_fused_kernel!(psi_2d, α, β, θ, m_gpu, m_shift, λ_gpu, V, conj_V; imaginary_time)

GPU-only single-launch fused replacement for the 7-launch broadcast-+-gemm
chain in `SpinorBEC.apply_euler_5stage_fused!`. `psi_2d` has shape
`(N, D)`; `α`, `β`, `θ` are `(N, 1)` per-point angles; `m_gpu`,
`m_shift`, `λ_gpu` are `(1, D)` row vectors; `V` and `conj_V` are the
D×D Fy eigenvector matrices (with `conj_V[c, j] = conj(V[c, j])`).
"""
function apply_euler_5stage_fused_kernel!(
    psi_2d::CuArray{Complex{T}, 2},
    α::CuArray{T, 2},
    β::CuArray{T, 2},
    θ::CuArray{T, 2},
    m_gpu::CuArray{T, 2},
    m_shift::CuArray{T, 2},
    λ_gpu::CuArray{T, 2},
    V::CuArray{Complex{T}, 2},
    conj_V::CuArray{Complex{T}, 2};
    imaginary_time::Bool=false,
) where {T <: AbstractFloat}
    N = size(psi_2d, 1)
    D = size(psi_2d, 2)
    threads = min(N, 256)
    blocks = cld(N, threads)
    CUDA.@cuda threads = threads blocks = blocks _euler_5stage_kernel!(
        psi_2d, α, β, θ, m_gpu, m_shift, λ_gpu, V, conj_V,
        Val(D), Val(imaginary_time),
    )
    nothing
end
