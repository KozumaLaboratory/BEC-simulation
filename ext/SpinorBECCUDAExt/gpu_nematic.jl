# GPU-native nematic (singlet-pair) interaction step
#
# Eliminates the _run_on_host! GPU↔CPU transfer by computing the nematic
# step directly on GPU using broadcast operations.
# Uses cached buffers to avoid per-call GPU memory allocations.

mutable struct GPUNematicCache
    A00::CuArray{ComplexF64,1}
    V_buf::CuArray{ComplexF64,1}
    absV::CuArray{Float64,1}
    ch::CuArray{Float64,1}
    sh::CuArray{Float64,1}
    phase::CuArray{ComplexF64,1}
    psi_tmp1::CuArray{ComplexF64,1}
    psi_tmp2::CuArray{ComplexF64,1}
end

const _GPU_NEMATIC_CACHE = Dict{UInt64,GPUNematicCache}()

function _get_gpu_nematic_cache(N::Int)
    key = hash(N)
    cache = get(_GPU_NEMATIC_CACHE, key, nothing)
    cache !== nothing && return cache::GPUNematicCache

    cache = GPUNematicCache(
        CUDA.zeros(ComplexF64, N),
        CUDA.zeros(ComplexF64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(ComplexF64, N),
        CUDA.zeros(ComplexF64, N),
        CUDA.zeros(ComplexF64, N),
    )
    _GPU_NEMATIC_CACHE[key] = cache
    cache
end

function SpinorBEC.apply_nematic_step!(
    psi::CuArray{ComplexF64},
    interactions::SpinorBEC.InteractionParams,
    F::Int,
    dt::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
)
    c2 = SpinorBEC.get_cn(interactions, 2)
    abs(c2) < 1e-30 && return nothing

    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    inv_sqrt_D = 1.0 / sqrt(Float64(D))
    mid = (D + 1) ÷ 2

    signs = Float64[iseven(F - (F - (c - 1))) ? 1.0 : -1.0 for c in 1:D]

    psi_2d = reshape(psi, N, D)
    cache = _get_gpu_nematic_cache(N)
    A00 = cache.A00
    V_buf = cache.V_buf
    absV = cache.absV
    ch = cache.ch
    sh = cache.sh
    phase = cache.phase
    psi_tmp1 = cache.psi_tmp1
    psi_tmp2 = cache.psi_tmp2

    # Compute A00 for all spatial points
    A00 .= 0
    for c in 1:D
        c_pair = D - c + 1
        s = signs[c]
        A00 .+= s .* view(psi_2d, :, c) .* view(psi_2d, :, c_pair)
    end
    A00 .*= inv_sqrt_D

    # V_base = c2 * A00 * inv_sqrt_D (stored in A00 to reuse buffer)
    A00 .*= c2 * inv_sqrt_D  # A00 is now V_base

    # Apply Bogoliubov rotation to each (m, -m) pair
    for c in 1:mid
        c_pair = D - c + 1
        s = signs[c]

        V_buf .= s .* A00
        absV .= abs.(V_buf)

        if imaginary_time
            ch .= cosh.(absV .* dt)
            sh .= sinh.(absV .* dt)
        else
            ch .= cos.(absV .* dt)
            sh .= sin.(absV .* dt)
        end

        phase .= V_buf ./ max.(absV, 1e-30)

        if c == c_pair
            psi_tmp1 .= view(psi_2d, :, c)
            if imaginary_time
                view(psi_2d, :, c) .= ch .* psi_tmp1 .- phase .* sh .* conj.(psi_tmp1)
            else
                view(psi_2d, :, c) .= ch .* psi_tmp1 .- im .* phase .* sh .* conj.(psi_tmp1)
            end
        else
            psi_tmp1 .= view(psi_2d, :, c)
            psi_tmp2 .= view(psi_2d, :, c_pair)
            if imaginary_time
                view(psi_2d, :, c) .= ch .* psi_tmp1 .- phase .* sh .* conj.(psi_tmp2)
                view(psi_2d, :, c_pair) .= ch .* psi_tmp2 .- phase .* sh .* conj.(psi_tmp1)
            else
                view(psi_2d, :, c) .= ch .* psi_tmp1 .- im .* phase .* sh .* conj.(psi_tmp2)
                view(psi_2d, :, c_pair) .= ch .* psi_tmp2 .- im .* phase .* sh .* conj.(psi_tmp1)
            end
        end
    end

    nothing
end
