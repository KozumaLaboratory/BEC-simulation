# Per-voxel batched eigvals of the spinor BdG-LHY local mass matrix.
#
# Phase C of the F=6 spinor LHY revision needs numerical eigvals at
# each voxel as a fallback when no closed-form expression is available.
# This file builds that GPU kernel.
#
# STATUS: standalone prototype. Not wired into the main solver yet.
# Include directly from a benchmark/test driver:
#
#     include(joinpath(@__DIR__, "src/hamiltonian/interactions/lhy_local.jl"))
#
# Promotion to a production module is a two-line change once the
# upstream Phase A formula stabilises:
#   1. add `include("hamiltonian/interactions/lhy_local.jl")` to
#      `src/SpinorBEC.jl`,
#   2. export the symbols.
#
# Reference pattern: `ext/SpinorBECCUDAExt/gpu_tensor.jl` already drives
# CUSOLVER.heevjBatched! for the tensor-channel exponential at D=13.
# That code keeps eigenvectors and gemms back; here we only need eigvals,
# so we ask `heevjBatched!` for 'N' (no vectors) and skip the rotation.

module LHYLocal

using LinearAlgebra: Hermitian, eigvals

# CUDA is optional — load lazily so the file is includable on CPU-only nodes
# (CI workers, laptops without nvidia-smi). The dispatch tables below grow a
# GPU branch only when `CUDA` is in the parent module's namespace.
const _HAS_CUDA = Ref(false)
function __init__()
    _HAS_CUDA[] =
        isdefined(parentmodule(@__MODULE__), :CUDA) ||
        Base.find_package("CUDA") !== nothing
end

# --- Cache ---------------------------------------------------------------

"""
    LHYLocalCache{A, T}(D, n_pts; backend)

Buffers for per-voxel LHY mass-matrix eigvals. Allocate once, reuse
across timesteps.

- `M_batch :: A {Complex{T}, 3}`, shape `(D, D, N)` — local Hermitian mass
  matrices, packed in upper-triangular form (heevjBatched! ignores the
  strict lower triangle when uplo='U').
- `eigvals :: AbstractMatrix{T}`, shape `(D, N)` — real eigvals output.

For F=6 (D=13) at 24³ (N=13824), the batch is 13×13×13824 complex = 19 MB
at F32 / 38 MB at F64.
"""
struct LHYLocalCache{A3, AE}
    M_batch::A3
    eigvals::AE
    D::Int
    n_pts::NTuple{3, Int}
end

n_voxels(c::LHYLocalCache) = prod(c.n_pts)

function _alloc_cache_cpu(::Type{T}, D::Int, n_pts) where {T}
    N = prod(n_pts)
    LHYLocalCache(
        Array{Complex{T}, 3}(undef, D, D, N),
        Array{T, 2}(undef, D, N),
        D,
        Tuple(n_pts),
    )
end

# --- Local mass-matrix construction --------------------------------------
#
# Placeholder Hessian: scalar contact only. The full F-spinor mass matrix
# adds c_1 (spin), c_dd (DDI), tensor channels, and an anomalous BdG block.
# Those plug in once the Phase A closed form lands.
#
# M_{αβ}(x) = c_0 (|ψ(x)|² δ_{αβ} + ψ_α*(x) ψ_β(x))
#
# which is a rank-(D+1) matrix at each voxel; eigvals are c_0|ψ|² with
# multiplicity D-1 plus 2c_0|ψ|² (one mode in the condensate direction).
# Useful as a sanity check: the eigvals path agrees with the analytical
# answer on this case.

"""
    build_local_M!(cache, psi, c_0)

Fill `cache.M_batch` from the condensate amplitude `psi`, sized
`(nx, ny, nz, D)`.
"""
function build_local_M!(
    cache::LHYLocalCache{<:Array{Complex{T}, 3}}, psi::Array{Complex{T}, 4}, c_0::Real
) where {T}
    D = cache.D
    N = n_voxels(cache)
    psi_2d = reshape(psi, N, D)
    M = cache.M_batch
    c0 = T(c_0)
    @inbounds for n in 1:N
        absq = zero(T)
        for c in 1:D
            absq += abs2(psi_2d[n, c])
        end
        for α in 1:D, β in α:D
            outer = conj(psi_2d[n, α]) * psi_2d[n, β]
            M[α, β, n] =
                α == β ? Complex{T}(c0 * (absq + real(outer)), c0 * imag(outer)) :
                c0 * outer
        end
    end
    cache
end

"""
    lhy_local_eigvals!(cache)

Diagonalise every voxel's `M_batch[:, :, n]` and write eigvals into
`cache.eigvals`. Returns the eigvals view (D, N).
"""
function lhy_local_eigvals!(cache::LHYLocalCache{<:Array})
    N = n_voxels(cache)
    @inbounds for n in 1:N
        # `eigvals(::Hermitian)` dispatches to the LAPACK SY routine; bare
        # `eigvals!` on the parent matrix would treat it as general and
        # return wrong (non-Hermitian) values for the lower-triangle
        # entries we never wrote.
        H = Hermitian(view(cache.M_batch,:,:,n), :U)
        cache.eigvals[:, n] .= eigvals(H)
    end
    cache.eigvals
end

# --- GPU specialisations -------------------------------------------------
#
# Only loaded when CUDA is in scope. Identical algorithm via batched
# broadcasts + `CUSOLVER.heevjBatched!`.

"""
    enable_gpu!(CUDAmod)

Register CUDA-backed methods of `_alloc_cache_cpu`, `build_local_M!`,
`lhy_local_eigvals!`. Pass `CUDA` so this module doesn't depend on CUDA
loading at compile time.
"""
function enable_gpu!(CUDAmod::Module)
    @eval begin
        function _alloc_cache_gpu(::Type{T}, D::Int, n_pts) where {T}
            N = prod(n_pts)
            LHYLocalCache(
                $(CUDAmod).CUDA.zeros(Complex{T}, D, D, N),
                $(CUDAmod).CUDA.zeros(T, D, N),
                D,
                Tuple(n_pts),
            )
        end

        function build_local_M!(
            cache::LHYLocalCache{<:$(CUDAmod).CuArray{Complex{T}, 3}},
            psi::$(CUDAmod).CuArray{Complex{T}, 4},
            c_0::Real,
        ) where {T}
            D = cache.D
            N = n_voxels(cache)
            c0 = T(c_0)
            psi_2d = reshape(psi, N, D)
            # |ψ|²[n] — broadcast then reduce along components
            absq = vec(sum(abs2.(psi_2d), dims=2))           # (N,)
            # outer[α, β, n] = ψ*[n, α] · ψ[n, β]
            psi_T = transpose(psi_2d)                           # (D, N)
            psiL = reshape(conj.(psi_T), D, 1, N)
            psiR = reshape(psi_T, 1, D, N)
            cache.M_batch .= c0 .* psiL .* psiR
            # Add c_0 |ψ|² to the diagonal (D × N broadcast then index-add)
            for d in 1:D
                @views cache.M_batch[d, d, :] .+= c0 .* absq
            end
            cache
        end

        function lhy_local_eigvals!(cache::LHYLocalCache{<:$(CUDAmod).CuArray})
            # heevjBatched!('N', ...) returns just W (D, N); the 'V' form
            # additionally returns V (D, D, N). The matrix is overwritten
            # in place; rebuild from `psi` next step.
            W = $(CUDAmod).CUDA.CUSOLVER.heevjBatched!('N', 'U', cache.M_batch)
            cache.eigvals .= W
            cache.eigvals
        end
    end
    nothing
end

# --- Top-level allocator -------------------------------------------------

"""
    alloc_cache(::Type{T}, D, n_pts; gpu=false)

Convenience constructor. Set `gpu=true` after `enable_gpu!(CUDA)` to get a
CUDA-backed cache.
"""
function alloc_cache(::Type{T}, D::Int, n_pts; gpu::Bool=false) where {T}
    gpu ? _alloc_cache_gpu(T, D, n_pts) : _alloc_cache_cpu(T, D, n_pts)
end

# --- Benchmark driver ----------------------------------------------------

"""
    bench(D=13, n_pts=(24,24,24); T=Float64, gpu=false, repeats=10)

Time `build_local_M!` + `lhy_local_eigvals!` over `repeats` iterations on
random F-spinor data. Reports min / median ms per step.
"""
function bench(D::Int=13, n_pts=(24, 24, 24);
    T::Type=Float64, gpu::Bool=false, repeats::Int=10)
    cache = alloc_cache(T, D, n_pts; gpu)
    nx, ny, nz = n_pts
    if gpu
        # Caller registered CUDA via enable_gpu!; reach the same module here.
        CUDAmod = parentmodule(typeof(cache.M_batch))
        psi = CUDAmod.CUDA.randn(Complex{T}, nx, ny, nz, D)
        # Warm up JIT + CUSOLVER plan
        build_local_M!(cache, psi, 1.0)
        lhy_local_eigvals!(cache)
        CUDAmod.CUDA.synchronize()
    else
        psi = randn(Complex{T}, nx, ny, nz, D)
        build_local_M!(cache, psi, 1.0)
        lhy_local_eigvals!(cache)
    end

    times_ms = Vector{Float64}(undef, repeats)
    for r in 1:repeats
        if gpu
            CUDAmod = parentmodule(typeof(cache.M_batch))
            CUDAmod.CUDA.synchronize()
            t0 = time_ns()
            build_local_M!(cache, psi, 1.0)
            lhy_local_eigvals!(cache)
            CUDAmod.CUDA.synchronize()
            times_ms[r] = (time_ns() - t0) / 1e6
        else
            t0 = time_ns()
            build_local_M!(cache, psi, 1.0)
            lhy_local_eigvals!(cache)
            times_ms[r] = (time_ns() - t0) / 1e6
        end
    end
    sort!(times_ms)
    (
        min_ms=times_ms[1],
        median_ms=times_ms[(repeats + 1) ÷ 2],
        max_ms=times_ms[end],
        n_voxels=prod(n_pts),
        D=D,
        backend=gpu ? :gpu : :cpu,
        eltype=T,
    )
end

end # module LHYLocal
