# --- Multipole expansion observables ---
#
# Rank-k multipole order parameters O_k(r), per-q spectrum Q_kq(r), and
# density-weighted average ⟨O_k⟩. Used for phase classification beyond
# rank-2 nematic (KU §4-5 cyclic / icosahedral / Majorana fingerprints).

export multipole_order_parameters, multipole_q_spectrum, multipole_spectrum

"""
    multipole_order_parameters(psi, F, ndim; density_cutoff=1e-10,
                               include_odd_ranks=false) → Dict{Int,Array{Float64,N}}

Local multipole order parameters O_k(r) for spinor BEC ranks.

    O_k(r) = Σ_{q=-k}^{k} |Q_{kq}(r)|² / n(r)²

where `Q_{kq} = Σ_m CG(F,m;k,q|F,m+q) ψ*_{m+q} ψ_m`.

By default returns even ranks only (`k = 0, 2, 4, …, 2F`) — appropriate
for ⟨F·F⟩-class observables and for symmetry-protected zero parity.
Pass `include_odd_ranks=true` to additionally compute `k = 1, 3, 5, …`,
which carry independent information for F ≥ 3 spinor phases (KU
review §4-5: rank-3, 5 nematic features show up in Eu F=6 phase
classification beyond what rank-2 alone captures).

Returns `Dict{Int → Array}` mapping rank `k` to spatial `O_k(r)`.
"""
function multipole_order_parameters(
    psi::AbstractArray{<:Complex},
    F::Int,
    ndim::Int;
    density_cutoff::Float64=1e-10,
    include_odd_ranks::Bool=false,
)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    n_total = total_density(psi, ndim)

    rank_step = include_odd_ranks ? 1 : 2
    result = Dict{Int, Array{Float64, ndim}}()
    for k in 0:rank_step:2F
        O_k = zeros(Float64, n_pts)
        cg_pairs = Dict{Int, Vector{Tuple{Int, Int, Float64}}}()
        for q in (-k):k
            pairs = Tuple{Int, Int, Float64}[]
            for m in (-F):F
                mp = m + q
                abs(mp) > F && continue
                cg_val = clebsch_gordan(F, m, k, q, F, mp)
                abs(cg_val) < 1e-15 && continue
                push!(pairs, (F - m + 1, F - mp + 1, cg_val))
            end
            isempty(pairs) || (cg_pairs[q] = pairs)
        end

        @inbounds for I in CartesianIndices(n_pts)
            n_total[I] > density_cutoff || continue
            inv_n_sq = 1.0 / (n_total[I]^2)
            for q in (-k):k
                haskey(cg_pairs, q) || continue
                Qkq = zero(ComplexF64)
                for (c_m, c_mp, cg_val) in cg_pairs[q]
                    Qkq += cg_val * conj(psi[I, c_mp]) * psi[I, c_m]
                end
                O_k[I] += abs2(Qkq) * inv_n_sq
            end
        end
        result[k] = O_k
    end
    result
end

"""
    multipole_q_spectrum(psi, F, k, ndim; density_cutoff=1e-10,
                         sort_descending=true) → Array{Float64,N+1}

Per-(q) breakdown of the rank-`k` multipole amplitude at every grid point:

    Q_{kq}(r) = Σ_m CG(F,m;k,q|F,m+q) ψ*_{m+q} ψ_m
    s[r, i]   = |Q_{kq}(r)|² / n(r)²

Returns an `(spatial..., 2k+1)` array. With `sort_descending=true` (the
default) the q-axis is sorted by amplitude at each spatial point, which
makes the result a rotation-invariant fingerprint suitable for phase
classification (uniaxial vs biaxial vs cyclic vs Majorana-symmetric
states all leave a distinct sorted signature). With
`sort_descending=false` the q-axis is the raw `q = −k, …, +k` index, so
the output retains the spherical-tensor decomposition.

For F=6 the meaningful ranks are k = 2 (rank-2 nematic), k = 3
(odd-rank, KU §5 cyclic-class fingerprint), k = 4 (Majorana
icosahedral), and k = 5 (residual chiral component). Sum over q gives
the rank-k order parameter `O_k(r)` returned by
`multipole_order_parameters`.
"""
function multipole_q_spectrum(
    psi::AbstractArray{<:Complex},
    F::Int,
    k::Int,
    ndim::Int;
    density_cutoff::Float64=1e-10,
    sort_descending::Bool=true,
)
    0 <= k <= 2F || throw(ArgumentError("rank k must be in 0..2F, got $k"))
    n_pts = ntuple(d -> size(psi, d), ndim)
    n_total = total_density(psi, ndim)
    n_components = 2k + 1

    cg_pairs_per_q = Dict{Int, Vector{Tuple{Int, Int, Float64}}}()
    for q in (-k):k
        pairs = Tuple{Int, Int, Float64}[]
        for m in (-F):F
            mp = m + q
            abs(mp) > F && continue
            cg_val = clebsch_gordan(F, m, k, q, F, mp)
            abs(cg_val) < 1e-15 && continue
            push!(pairs, (F - m + 1, F - mp + 1, cg_val))
        end
        isempty(pairs) || (cg_pairs_per_q[q] = pairs)
    end

    out_shape = (n_pts..., n_components)
    spectrum = zeros(Float64, out_shape)
    amps = zeros(Float64, n_components)

    @inbounds for I in CartesianIndices(n_pts)
        n_total[I] > density_cutoff || continue
        inv_n_sq = 1.0 / (n_total[I]^2)
        fill!(amps, 0.0)
        for q in (-k):k
            haskey(cg_pairs_per_q, q) || continue
            Qkq = zero(ComplexF64)
            for (c_m, c_mp, cg_val) in cg_pairs_per_q[q]
                Qkq += cg_val * conj(psi[I, c_mp]) * psi[I, c_m]
            end
            amps[q + k + 1] = abs2(Qkq) * inv_n_sq
        end
        sort_descending && sort!(amps; rev=true)
        for q_idx in 1:n_components
            spectrum[I, q_idx] = amps[q_idx]
        end
    end
    spectrum
end

"""
    multipole_spectrum(psi, F, grid; density_cutoff=1e-10,
                       include_odd_ranks=false) → Dict{Int,Float64}

Density-weighted average of each multipole order parameter.
Returns Dict mapping rank k to ⟨O_k⟩ = ∫ O_k(r) n²(r) dV / ∫ n²(r) dV.

`include_odd_ranks=true` adds k = 1, 3, 5, … to the returned dict (see
`multipole_order_parameters` for the F=6 motivation).
"""
function multipole_spectrum(
    psi::AbstractArray{<:Complex},
    F::Int,
    grid::Grid{N};
    density_cutoff::Float64=1e-10,
    include_odd_ranks::Bool=false,
) where {N}
    ops = multipole_order_parameters(psi, F, N; density_cutoff, include_odd_ranks)
    n_total = total_density(psi, N)
    dV = cell_volume(grid)
    # Cache `n_total[i]^2` once into a reusable buffer so the per-rank
    # spectrum loop reduces against it without re-squaring or
    # re-allocating `n_total .^ 2` for each operator.
    n_sq = similar(n_total)
    w_sum = 0.0
    @inbounds for i in eachindex(n_total)
        sq = n_total[i]^2
        n_sq[i] = sq
        w_sum += sq
    end
    w_sum *= dV
    w_sum < 1e-30 && return Dict{Int, Float64}(k => 0.0 for k in keys(ops))

    out = Dict{Int, Float64}()
    for (k, O_k) in ops
        # `sum(O_k .* n_sq)` previously materialised an n_pts-shape temp
        # per rank — with up to 2F+1 ranks at Eu151 this added up.
        s = 0.0
        @inbounds for i in eachindex(O_k, n_sq)
            s += O_k[i] * n_sq[i]
        end
        out[k] = s * dV / w_sum
    end
    out
end
