# Batched matrix-exp for TDHFB BdG step — Phase 5c core kernel.
#
# Implements `batched_expm_neg_i_dt!(M_batch, W_batch, dt)` computing
# `M[v] = exp(-i W[v] dt)` for each voxel v using a truncated Taylor series:
#
#   M ≈ Σ_{k=0}^{N_max} A^k / k!     where A = -i W dt.
#
# Taylor instead of Padé because:
#   (1) CUDA.jl has no batched LU solve for the Padé Q⁻¹ P stage.
#   (2) For typical TDHFB regime g·n·dt ~ 1e-3, ||A||_∞ < 0.05, so N=10
#       Taylor gives accuracy ~ 0.05^10 / 10! ≈ 2.7e-21 — well below F32 eps.
#   (3) N=14 covers ||A|| up to 0.5 with F32 accuracy.
#
# When future production dt regimes push ||A|| > 0.5, switch to Padé(13) +
# scaling-and-squaring per the design doc §4 — `cublasZgetrsBatched` is
# available for the Q⁻¹P stage. For Phase 5c smoke test, Taylor suffices.
#
# Implementation uses `CUBLAS.gemm_strided_batched!` for the matrix powers,
# which is the same hardware-tuned routine that backs all TDHFB GPU substeps.

"""
    batched_expm_neg_i_dt!(M_batch, W_batch, dt; n_taylor=14, A_scratch, A_tmp, P_tmp)

Compute `M[:,:,v] ← exp(-i W[:,:,v] · dt)` for all voxels `v ∈ 1:size(W_batch, 3)`
via truncated Taylor series. All arrays are `(D, D, N_voxels)` `CuArray`s.

Truncation: 14 terms — accurate to F32 precision (1e-7) for ‖A‖ < 0.5;
for the typical TDHFB regime (‖A‖ < 0.05), accuracy is ~1e-21 (F64).
"""
function batched_expm_neg_i_dt!(
    M_batch::CuArray{Complex{T}, 3},
    W_batch::CuArray{Complex{T}, 3},
    dt::Real;
    n_taylor::Int=14,
    A_scratch::CuArray{Complex{T}, 3},
    A_tmp::CuArray{Complex{T}, 3},
    P_tmp::CuArray{Complex{T}, 3},
) where {T <: AbstractFloat}
    D = size(W_batch, 1)
    @assert size(W_batch, 2) == D "W must be square per voxel"
    N_vox = size(W_batch, 3)
    @assert size(M_batch) == (D, D, N_vox) "M_batch shape mismatch"
    @assert size(A_scratch) == (D, D, N_vox) "A_scratch shape mismatch"
    @assert size(A_tmp) == (D, D, N_vox) "A_tmp shape mismatch"
    @assert size(P_tmp) == (D, D, N_vox) "P_tmp shape mismatch"

    # A = -i · dt · W
    dt_c = Complex{T}(0, -dt)
    @. A_scratch = dt_c * W_batch

    # Initialize M = I (broadcast identity into each batch entry)
    fill!(M_batch, zero(Complex{T}))
    _add_identity_to_batch!(M_batch, one(Complex{T}))

    # Initialize A_tmp = A (the running A^k term, starts at k=1).
    copyto!(A_tmp, A_scratch)
    inv_factorial = one(T)

    for k in 1:n_taylor
        inv_factorial /= T(k)
        # M += inv_factorial * A_tmp
        @. M_batch += Complex{T}(inv_factorial) * A_tmp

        # Advance A_tmp ← A_tmp · A_scratch (next power)
        # Use batched gemm: P_tmp = A_tmp · A_scratch
        k == n_taylor && break   # don't compute the next power if we're done
        CUDA.CUBLAS.gemm_strided_batched!(
            'N', 'N', one(Complex{T}), A_tmp, A_scratch, zero(Complex{T}), P_tmp
        )
        copyto!(A_tmp, P_tmp)
    end
    M_batch
end

# In-place identity addition: M[i, i, v] += val for all v.
# Implemented as a CUDA kernel because broadcast over the diagonal is awkward.
function _add_identity_to_batch!(M::CuArray{Complex{T}, 3}, val::Complex{T}) where {T}
    D = size(M, 1)
    N_vox = size(M, 3)
    function _kernel(M, val, D, N_vox)
        i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
        v = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
        if i <= D && v <= N_vox
            @inbounds M[i, i, v] += val
        end
        return nothing
    end
    threads_x = min(D, 32)
    threads_y = min(N_vox, 8)
    blocks_x = cld(D, threads_x)
    blocks_y = cld(N_vox, threads_y)
    CUDA.@cuda threads=(threads_x, threads_y) blocks=(blocks_x, blocks_y) _kernel(
        M, val, D, N_vox
    )
    M
end
