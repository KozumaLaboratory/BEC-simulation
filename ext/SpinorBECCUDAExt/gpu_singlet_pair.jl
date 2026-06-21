# GPU-native S=0 spin-singlet pair interaction step (KU Eq. 48, c₂|A₀₀|²)
#
# Eliminates the _run_on_host! GPU↔CPU transfer by computing the
# singlet-pair step directly on GPU using broadcast operations.
# Uses cached buffers to avoid per-call GPU memory allocations.

mutable struct GPUSingletPairCache{T <: AbstractFloat}
    A00::CuArray{Complex{T}, 1}
    V_buf::CuArray{Complex{T}, 1}
    absV::CuArray{T, 1}
    ch::CuArray{T, 1}
    sh::CuArray{T, 1}
    phase::CuArray{Complex{T}, 1}
    psi_tmp1::CuArray{Complex{T}, 1}
    psi_tmp2::CuArray{Complex{T}, 1}
end

const _GPU_SINGLET_PAIR_CACHE = Dict{UInt64, Any}()

function _get_gpu_singlet_pair_cache(N::Int, ::Type{T}) where {T <: AbstractFloat}
    key = hash((N, T))
    cache = get(_GPU_SINGLET_PAIR_CACHE, key, nothing)
    cache !== nothing && return cache::GPUSingletPairCache{T}

    cache = GPUSingletPairCache{T}(
        CUDA.zeros(Complex{T}, N),
        CUDA.zeros(Complex{T}, N),
        CUDA.zeros(T, N),
        CUDA.zeros(T, N),
        CUDA.zeros(T, N),
        CUDA.zeros(Complex{T}, N),
        CUDA.zeros(Complex{T}, N),
        CUDA.zeros(Complex{T}, N),
    )
    _GPU_SINGLET_PAIR_CACHE[key] = cache
    cache
end

function SpinorBEC.apply_singlet_pair_step!(
    psi::CuArray{Complex{T}},
    interactions::SpinorBEC.InteractionParams,
    F::Int,
    dt::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
) where {T <: AbstractFloat}
    c2 = SpinorBEC.get_cn(interactions, 2)
    abs(c2) < 1e-30 && return nothing

    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    inv_sqrt_D = one(T) / sqrt(T(D))
    mid = (D + 1) ÷ 2
    c2_t = T(c2)
    dt_t = T(dt)

    signs = T[SpinorBEC.singlet_pair_sign(F, F - (c - 1)) for c in 1:D]

    psi_2d = reshape(psi, N, D)
    cache = _get_gpu_singlet_pair_cache(N, T)
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
    A00 .*= c2_t * inv_sqrt_D  # A00 is now V_base

    # Apply Bogoliubov rotation to each (m, -m) pair
    for c in 1:mid
        c_pair = D - c + 1
        s = signs[c]

        V_buf .= s .* A00
        absV .= abs.(V_buf)

        if imaginary_time
            ch .= cosh.(absV .* dt_t)
            sh .= sinh.(absV .* dt_t)
        else
            ch .= cos.(absV .* dt_t)
            sh .= sin.(absV .* dt_t)
        end

        phase .= V_buf ./ max.(absV, floatmin(T))

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
