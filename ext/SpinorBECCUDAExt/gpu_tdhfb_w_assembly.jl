# BdG W-matrix block assembly on GPU — Phase 5c piece 2/3.
#
# Per CPU code at `src/hamiltonian/tdhfb/strang_step.jl:225-231`:
#   W = [[U,        Δ       ],
#        [-conj(Δ), -conj(U) ]]   (block structure, 2D × 2D per voxel)
#
# GPU plan: single CUDA kernel per `_assemble_w_blocks!`. One thread per
# (r, c, v) entry; branch on which block it falls into.

function _kernel_assemble_w!(W, U, Delta, D::Int, twoD::Int, N_vox::Int)
    r = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    c = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    v = (CUDA.blockIdx().z - 1) * CUDA.blockDim().z + CUDA.threadIdx().z
    if r <= twoD && c <= twoD && v <= N_vox
        @inbounds begin
            if r <= D && c <= D
                W[r, c, v] = U[r, c, v]                         # top-left
            elseif r <= D && c > D
                W[r, c, v] = Delta[r, c - D, v]                 # top-right
            elseif r > D && c <= D
                W[r, c, v] = -conj(Delta[r - D, c, v])          # bottom-left
            else
                W[r, c, v] = -conj(U[r - D, c - D, v])          # bottom-right
            end
        end
    end
    return nothing
end

"""
    _assemble_w_blocks!(W, U, Delta) -> W

Assemble per-voxel BdG W matrix W[v] = [[U[v], Δ[v]]; [-Δ̄[v], -Ū[v]]]
from the contracted U and Δ arrays. `W` is `(2D, 2D, N_voxels)`; `U`,
`Delta` are `(D, D, N_voxels)`.
"""
function _assemble_w_blocks!(
    W::CuArray{TC, 3},
    U::CuArray{TC, 3},
    Delta::CuArray{TC, 3},
) where {TC <: Complex}
    twoD = size(W, 1)
    D = size(U, 1)
    @assert size(W, 2) == twoD && size(U, 2) == D
    @assert twoD == 2 * D "W must be 2D × 2D where U is D × D"
    N_vox = size(W, 3)
    @assert size(U, 3) == N_vox && size(Delta, 3) == N_vox

    threads_r = min(twoD, 8)
    threads_v = min(N_vox, 8)
    blocks_r = cld(twoD, threads_r)
    blocks_v = cld(N_vox, threads_v)
    CUDA.@cuda(
        threads=(threads_r, threads_r, threads_v),
        blocks=(blocks_r, blocks_r, blocks_v),
        _kernel_assemble_w!(W, U, Delta, D, twoD, N_vox),
    )
    W
end
