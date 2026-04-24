# GPU-native tensor interaction step
#
# Eliminates the _run_on_host! GPU↔CPU transfer for tensor interactions.
# Pre-computes a D×D coefficient tensor on CPU, then uses CUBLAS for the
# mean-field matrix construction and eigendecomposition on CPU (after
# collecting per-point data via GPU batch operations).
#
# Strategy: for D=13, per-point eigen is expensive on GPU. Instead we use
# a hybrid approach:
#   1. Build the mean-field matrices using GPU broadcasts for the density
#      matrix ρ_{μν} = Σ_i ψ*_μ(i) ψ_ν(i), then
#   2. For the actual per-point matrix exponentiation, batch the work.
#
# For now, the practical approach is to use a CUDA kernel that processes
# points in parallel, each computing the D×D Hermitian h, diagonalizing,
# and applying exp(-i h dt).
#
# Since D=13 eigendecomposition in a CUDA kernel is impractical, we use
# the diagonal-fast-path optimization: if the off-diagonal part is small
# (common in many physical scenarios), apply only the diagonal phase.
# For the general case, we fall back to batched CPU processing with
# minimized transfer overhead.

function SpinorBEC.apply_tensor_interaction_step!(
    psi::CuArray{Complex{T}},
    cache::SpinorBEC.TensorInteractionCache,
    sm::SpinorBEC.SpinMatrices,
    dt::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {T<:AbstractFloat}
    D = cache.D
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    dt_t = T(dt)

    hf_entries = SpinorBEC._precompute_hf_entries(cache)

    coeff_groups = [Tuple{Int,Int,Int,Float64}[] for _ in 1:D, _ in 1:D]
    for e in hf_entries
        push!(coeff_groups[e.c_m, e.c_mp], (e.ch_idx, e.c_mu, e.c_nu, e.cg_prod))
    end

    psi_2d = reshape(psi, N, D)

    needed_pairs = Set{Tuple{Int,Int}}()
    for e in hf_entries
        push!(needed_pairs, (e.c_mu, e.c_nu))
    end

    rho = Dict{Tuple{Int,Int}, CuArray{Complex{T},1}}()
    for (mu, nu) in needed_pairs
        rho[(mu, nu)] = conj.(view(psi_2d, :, mu)) .* view(psi_2d, :, nu)
    end

    h_fields = Matrix{Union{Nothing, CuArray{Complex{T},1}}}(nothing, D, D)
    for m in 1:D, mp in 1:D
        isempty(coeff_groups[m, mp]) && continue
        h_mm = CUDA.zeros(Complex{T}, N)
        for (ch_idx, c_mu, c_nu, cg_prod) in coeff_groups[m, mp]
            coeff = T(cache.g_values[ch_idx] * cg_prod)
            h_mm .+= coeff .* rho[(c_mu, c_nu)]
        end
        h_fields[m, mp] = h_mm
    end

    empty!(rho)

    offdiag_max = zero(T)
    for m in 1:D, mp in 1:D
        m == mp && continue
        h_fields[m, mp] === nothing && continue
        offdiag_max = max(offdiag_max, T(maximum(abs, h_fields[m, mp])))
    end

    if offdiag_max * abs(dt_t) < T(1e-6)
        # Diagonal-only fast path (all on GPU, no transfer)
        for c in 1:D
            if h_fields[c, c] !== nothing
                if imaginary_time
                    view(psi_2d, :, c) .*= exp.(.-real.(h_fields[c, c]) .* dt_t)
                else
                    view(psi_2d, :, c) .*= cis.(.-real.(h_fields[c, c]) .* dt_t)
                end
            end
        end
    else
        # Full diagonalization needed — transfer to CPU (F64 for numerical
        # stability of the eigensolver), process, transfer back.
        psi_host = ComplexF64.(Array(psi))
        n_pts_tuple = ntuple(d -> size(psi, d), ndim)

        nthr = Threads.maxthreadid()
        spinor_bufs = [Vector{ComplexF64}(undef, D) for _ = 1:nthr]
        h_bufs = [Matrix{ComplexF64}(undef, D, D) for _ = 1:nthr]
        tmp_bufs = [Vector{ComplexF64}(undef, D) for _ = 1:nthr]

        Threads.@threads :static for I in CartesianIndices(n_pts_tuple)
            tid = Threads.threadid()
            @inbounds SpinorBEC._tensor_step_point!(
                psi_host, I, cache, hf_entries, dt, imaginary_time,
                spinor_bufs[tid], h_bufs[tid], tmp_bufs[tid],
            )
        end
        copyto!(psi, Complex{T}.(psi_host))
    end

    nothing
end
