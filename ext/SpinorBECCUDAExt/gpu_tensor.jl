# GPU-native tensor interaction step.
#
# Two paths:
#   1. Diagonal-fast-path — when the off-diagonal part of the per-point
#      Hermitian h_{m,m'} is below `1e-6 / dt`, apply phases per
#      component on the GPU directly. Common for fully polarized GS.
#   2. Full eigen path — call `CUSOLVER.heevjBatched!` to diagonalise N
#      D×D Hermitian matrices on the GPU at once, multiply by
#      `exp(-iΛdt)` per eigenvalue, and rotate back via two strided
#      batched GEMMs. No GPU→CPU transfer; previously this fell through
#      to a per-point Threads.@threads CPU eigen loop with a full ψ
#      roundtrip in F32→F64→F32 — fast on tiny grids, catastrophic for
#      F=6 / 64³ where it dominates wall time.

function SpinorBEC.apply_tensor_interaction_step!(
    psi::CuArray{Complex{T}},
    cache::SpinorBEC.TensorInteractionCache,
    sm::SpinorBEC.SpinMatrices,
    dt::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {T <: AbstractFloat}
    D = cache.D
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    dt_t = T(dt)

    hf_entries = SpinorBEC._precompute_hf_entries(cache)

    coeff_groups = [Tuple{Int, Int, Int, Float64}[] for _ in 1:D, _ in 1:D]
    for e in hf_entries
        push!(coeff_groups[e.c_m, e.c_mp], (e.ch_idx, e.c_mu, e.c_nu, e.cg_prod))
    end

    psi_2d = reshape(psi, N, D)
    # Field source: psi_mf (frozen mean-field) when given, else psi (SMA).
    # Matches the CPU `psi_mf_eff` — exp(-i h dt) below still acts on
    # psi_2d; only the Hermitian field h is built from psi_mf_2d.
    psi_mf_2d = psi_mf === nothing ? psi_2d :
                reshape(psi_mf::CuArray{Complex{T}}, N, D)

    needed_pairs = Set{Tuple{Int, Int}}()
    for e in hf_entries
        push!(needed_pairs, (e.c_mu, e.c_nu))
    end

    rho = Dict{Tuple{Int, Int}, CuArray{Complex{T}, 1}}()
    for (mu, nu) in needed_pairs
        rho[(mu, nu)] = conj.(view(psi_mf_2d, :, mu)) .* view(psi_mf_2d, :, nu)
    end

    h_fields = Matrix{Union{Nothing, CuArray{Complex{T}, 1}}}(nothing, D, D)
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
        return nothing
    end

    # --- GPU batched eigen path ---
    # Pack h_fields into a (D, D, N) CuArray. cuSOLVER's heevj solver
    # ignores the strict lower triangle when uplo='U', so we only have
    # to write upper-triangular entries.
    H_batch = CUDA.zeros(Complex{T}, D, D, N)
    for m in 1:D, mp in m:D
        h_fields[m, mp] === nothing && continue
        @views H_batch[m, mp, :] .= h_fields[m, mp]
    end

    # heevjBatched! returns (eigenvalues::(D, N), eigenvectors::(D, D, N))
    W, V = CUDA.CUSOLVER.heevjBatched!('V', 'U', H_batch)

    # Per-eigenvalue phase exp(-i Λ dt) (or real exp for ITP)
    if imaginary_time
        phases = exp.(.-W .* dt_t)                  # (D, N) Real
    else
        phases = cis.(.-W .* dt_t)                  # (D, N) Complex
    end
    phases_c = Complex{T}.(phases)                   # unify type for gemm

    # ψ as (D, 1, N) so it slots into batched gemm
    psi_batch = CUDA.zeros(Complex{T}, D, 1, N)
    psi_T = transpose(psi_2d)                        # (D, N)
    @views psi_batch[:, 1, :] .= psi_T

    # Step 1: tmp = V† ψ — strided batched gemm with op='C' on V
    tmp_batch = CUDA.zeros(Complex{T}, D, 1, N)
    CUDA.CUBLAS.gemm_strided_batched!(
        'C', 'N', Complex{T}(1), V, psi_batch, Complex{T}(0), tmp_batch
    )

    # Step 2: tmp[d, 1, n] *= phases_c[d, n]
    tmp_2d = reshape(tmp_batch, D, N)
    tmp_2d .*= phases_c

    # Step 3: ψ_new = V tmp — batched gemm with op='N' on V
    out_batch = CUDA.zeros(Complex{T}, D, 1, N)
    CUDA.CUBLAS.gemm_strided_batched!(
        'N', 'N', Complex{T}(1), V, tmp_batch, Complex{T}(0), out_batch
    )

    # Write back to psi_2d ((N, D)) by transposing (D, N) → (N, D)
    out_2d = reshape(out_batch, D, N)
    psi_2d .= transpose(out_2d)

    nothing
end

# TensorTerm gradient face on GPU — CPU fallback. The anomalous tensor/c2
# gradient kernel (`apply_operator!`) is CPU-only for now; the cache
# metadata (g_values / cg_table / active_channels) is host-side, so we
# compute on the host and copy back. Correct result ⇒ GPU=CPU per-term
# parity holds honestly (a GPU kernel is a perf follow-on, not a
# correctness fix). ACCUMULATES, matching the CPU contract.
function SpinorBEC.apply_operator!(
    out::CuArray, term::SpinorBEC.TensorTerm, ws, psi::CuArray
)
    out_h = Array(out)
    SpinorBEC.apply_operator!(out_h, term, ws, Array(psi))
    copyto!(out, out_h)
    out
end
