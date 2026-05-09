export total_density, component_density, total_norm, magnetization
export spin_density_vector, singlet_pair_amplitude, pair_amplitude
export nematic_tensor_eigenvalues, biaxiality_parameter
export multipole_order_parameters, multipole_q_spectrum, multipole_spectrum
export structure_factor, modulation_contrast, pair_amplitude_spectrum

function total_density(psi::AbstractArray{<:Complex}, ndim::Int)
    n_comp = size(psi, ndim + 1)
    n_pts = ntuple(d -> size(psi, d), ndim)
    _total_density(psi, n_comp, ndim, n_pts)
end

function component_density(psi::AbstractArray{<:Complex}, ndim::Int, c::Int)
    n_pts = ntuple(d -> size(psi, d), ndim)
    idx = _component_slice(ndim, n_pts, c)
    abs2.(view(psi, idx...))
end

function total_norm(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    dV = cell_volume(grid)
    n = total_density(psi, N)
    sum(n) * dV
end

"""
Magnetization ⟨Fz⟩ = Σ_m m |ψ_m|² integrated over space.
"""
function magnetization(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    sys::SpinSystem,
) where {N}
    dV = cell_volume(grid)
    Mz = 0.0
    n_pts = ntuple(d -> size(psi, d), Val(N))
    for (c, m) in enumerate(sys.m_values)
        idx = _component_slice(N, n_pts, c)
        Mz += m * sum(abs2, view(psi, idx...)) * dV
    end
    Mz
end

"""
Local spin density vector (Fx, Fy, Fz) at each spatial point.
Returns a tuple of 3 arrays.
"""
function spin_density_vector(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    ndim::Int,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)

    fx = zeros(Float64, n_pts)
    fy = zeros(Float64, n_pts)
    fz = zeros(Float64, n_pts)

    _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), ndim, n_pts)

    (fx, fy, fz)
end

"""
Exploit spin matrix sparsity: Fz is diagonal, Fx/Fy are tridiagonal.

    Fz: ⟨ψ|Fz|ψ⟩ = Σ_c m_c |ψ_c|²
    Fx + iFy = ⟨ψ|F+|ψ⟩ = Σ_{c=2}^D f+(m_c) ψ*_{c-1} ψ_c

O(D) per point instead of O(D²).
"""
function _compute_spin_density!(fx, fy, fz, psi, sm, n_comp::Int, ndim, n_pts)
    _compute_spin_density!(fx, fy, fz, psi, sm, Val(n_comp), ndim, n_pts)
end

function _compute_spin_density!(fx, fy, fz, psi::Array, sm, ::Val{D}, ndim, n_pts) where {D}
    F = sm.system.F
    Ff1 = Float64(F * (F + 1))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = ntuple(c -> c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)), Val(D))

    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            fz_val = 0.0
            for c in 1:D
                fz_val += m_vals[c] * abs2(psi[I, c])
            end
            fz[I] = fz_val

            fxy_re = 0.0
            fxy_im = 0.0
            for c in 2:D
                prod = conj(psi[I, c - 1]) * psi[I, c]
                fxy_re += fp_coeffs[c] * real(prod)
                fxy_im += fp_coeffs[c] * imag(prod)
            end
            fx[I] = fxy_re
            fy[I] = fxy_im
        end
    end
end

function _compute_spin_density!(fx, fy, fz, psi::AbstractArray, sm, ::Val{D}, ndim, n_pts) where {D}
    F = sm.system.F
    Ff1 = Float64(F * (F + 1))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = ntuple(c -> c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)), Val(D))

    spatial_idx = ntuple(d -> 1:n_pts[d], ndim)
    fz_v = view(fz, spatial_idx...)
    fx_v = view(fx, spatial_idx...)
    fy_v = view(fy, spatial_idx...)

    psi1 = view(psi, _component_slice(ndim, n_pts, 1)...)
    @. fz_v = m_vals[1] * abs2(psi1)
    for c in 2:D
        psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
        @. fz_v += m_vals[c] * abs2(psi_c)
    end

    psi_p = view(psi, _component_slice(ndim, n_pts, 1)...)
    psi_c = view(psi, _component_slice(ndim, n_pts, 2)...)
    @. fx_v = fp_coeffs[2] * (real(psi_p) * real(psi_c) + imag(psi_p) * imag(psi_c))
    @. fy_v = fp_coeffs[2] * (real(psi_p) * imag(psi_c) - imag(psi_p) * real(psi_c))
    for c in 3:D
        psi_p = view(psi, _component_slice(ndim, n_pts, c - 1)...)
        psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
        @. fx_v += fp_coeffs[c] * (real(psi_p) * real(psi_c) + imag(psi_p) * imag(psi_c))
        @. fy_v += fp_coeffs[c] * (real(psi_p) * imag(psi_c) - imag(psi_p) * real(psi_c))
    end
end

"""
Singlet pair amplitude A₀₀(r) = Σ_m (-1)^{F-m} ψ_m(r) ψ_{-m}(r) / √(2F+1).

Returns Array{ComplexF64,N} over spatial points. Non-zero only for integer F.
For F=1: A₀₀ = (ψ₊₁ψ₋₁ - ψ₀ψ₀ + ψ₋₁ψ₊₁) / √3 = (2ψ₊₁ψ₋₁ - ψ₀²) / √3.
"""
function singlet_pair_amplitude(psi::AbstractArray{<:Complex}, F::Int, ndim::Int)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    A = zeros(ComplexF64, n_pts)
    inv_sqrt_D = 1.0 / sqrt(Float64(D))

    @inbounds for I in CartesianIndices(n_pts)
        s = zero(ComplexF64)
        for c in 1:D
            m = F - (c - 1)
            c_pair = D - c + 1
            sign = iseven(F - m) ? 1.0 : -1.0
            s += sign * psi[I, c] * psi[I, c_pair]
        end
        A[I] = s * inv_sqrt_D
    end
    A
end

"""
    pair_amplitude(psi, F, S, M, ndim, cg_table) → Array{ComplexF64,N}

Pair amplitude A_{SM}(r) = Σ_{m1} CG(F,m1;F,M-m1|S,M) ψ_{m1}(r) ψ_{M-m1}(r).
"""
function pair_amplitude(
    psi::AbstractArray{<:Complex},
    F::Int,
    S::Int,
    M::Int,
    ndim::Int,
    cg_table::Dict{NTuple{4, Int}, Float64},
)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    A = zeros(ComplexF64, n_pts)

    pairs = Tuple{Int, Int, Float64}[]
    for m1 in (-F):F
        m2 = M - m1
        abs(m2) > F && continue
        cg = get(cg_table, (S, M, m1, m2), 0.0)
        abs(cg) < 1e-15 && continue
        c1 = F - m1 + 1
        c2 = F - m2 + 1
        push!(pairs, (c1, c2, cg))
    end

    @inbounds for I in CartesianIndices(n_pts)
        s = zero(ComplexF64)
        for (c1, c2, cg) in pairs
            s += cg * psi[I, c1] * psi[I, c2]
        end
        A[I] = s
    end
    A
end

"""
    nematic_tensor_eigenvalues(psi, sm, ndim; density_cutoff=1e-10)

Compute eigenvalues of the traceless nematic tensor at each grid point.

The rank-2 nematic tensor is N_{ab} = ⟨(F_a F_b + F_b F_a)/2⟩/n - F(F+1)/3 δ_{ab}.
Returns three N-dim arrays (lambda1, lambda2, lambda3) sorted lambda1 >= lambda2 >= lambda3.
"""
function nematic_tensor_eigenvalues(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    ndim::Int;
    density_cutoff::Float64=1e-10,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    F = sm.system.F
    shift = F * (F + 1) / 3.0

    Fx = Matrix{ComplexF64}(sm.Fx)
    Fy = Matrix{ComplexF64}(sm.Fy)
    Fz = Matrix{ComplexF64}(sm.Fz)
    F_mats = (Fx, Fy, Fz)

    sym_prods = Matrix{ComplexF64}[]
    for a in 1:3
        for b in a:3
            push!(sym_prods, (F_mats[a] * F_mats[b] + F_mats[b] * F_mats[a]) / 2)
        end
    end

    l1 = zeros(Float64, n_pts)
    l2 = zeros(Float64, n_pts)
    l3 = zeros(Float64, n_pts)

    @inbounds for I in CartesianIndices(n_pts)
        n_local = sum(c -> abs2(psi[I, c]), 1:D)
        if n_local < density_cutoff
            continue
        end
        inv_n = 1.0 / n_local

        nab = zeros(Float64, 3, 3)
        idx = 0
        for a in 1:3
            for b in a:3
                idx += 1
                val = 0.0
                for j in 1:D
                    for k in 1:D
                        val += real(conj(psi[I, j]) * sym_prods[idx][j, k] * psi[I, k])
                    end
                end
                val = val * inv_n - (a == b ? shift : 0.0)
                nab[a, b] = val
                nab[b, a] = val
            end
        end

        evals = eigvals(Symmetric(nab))
        l1[I] = evals[3]
        l2[I] = evals[2]
        l3[I] = evals[1]
    end

    (l1, l2, l3)
end

"""
    biaxiality_parameter(lambda1, lambda2, lambda3)

Biaxiality parameter β = (λ₂ - λ₃) / (λ₁ - λ₃ + ε).
0 = uniaxial, 1 = maximally biaxial.
"""
function biaxiality_parameter(lambda1, lambda2, lambda3)
    @. (lambda2 - lambda3) / (lambda1 - lambda3 + eps(Float64))
end

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

"""
    structure_factor(psi, grid) → Array{Float64,N}

Static structure factor S(k) = |δn(k)|² / N_grid from density fluctuations.
Useful for detecting supersolid/modulated phases.
"""
function structure_factor(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    n = total_density(psi, N)
    n_mean = sum(n) / prod(size(n))
    delta_n = n .- n_mean
    delta_n_k = FFTW.fft(delta_n)
    abs2.(delta_n_k) ./ prod(size(n))
end

"""
    modulation_contrast(psi, ndim) → Float64

Density modulation contrast (n_max - n_min) / (n_max + n_min).
Returns 0 for uniform density, approaches 1 for strong modulation.
"""
function modulation_contrast(psi::AbstractArray{<:Complex}, ndim::Int)
    n = total_density(psi, ndim)
    n_max = maximum(n)
    n_min = minimum(n)
    (n_max - n_min) / (n_max + n_min + eps(Float64))
end

"""
    pair_amplitude_spectrum(psi, F, grid) → NamedTuple

Integrated pair amplitude spectrum over all even-S channels.

Returns `(amplitudes, channel_weights)` where:
- `amplitudes::Dict{Tuple{Int,Int}, Float64}`: (S,M) => ∫|A_{SM}(r)|² dV
- `channel_weights::Dict{Int, Float64}`: S => Σ_M ∫|A_{SM}|² dV
"""
function pair_amplitude_spectrum(
    psi::AbstractArray{<:Complex},
    F::Int,
    grid::Grid{N},
) where {N}
    cg = precompute_cg_array(F)
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))

    amplitudes = Dict{Tuple{Int, Int}, Float64}()
    channel_weights = Dict{Int, Float64}()

    for S in 0:2:(2F)
        w = 0.0
        for M in (-S):S
            A = _pair_amplitude_fast(psi, F, S, M, N, n_pts, cg)
            val = sum(abs2, A) * dV
            amplitudes[(S, M)] = val
            w += val
        end
        channel_weights[S] = w
    end

    (amplitudes=amplitudes, channel_weights=channel_weights)
end

function _pair_amplitude_fast(
    psi,
    F::Int,
    S::Int,
    M::Int,
    ndim::Int,
    n_pts,
    cg::CGArrayTable,
)
    D = 2F + 1
    A = zeros(ComplexF64, n_pts)

    pairs = Tuple{Int, Int, Float64}[]
    for m1 in (-F):F
        m2 = M - m1
        abs(m2) > F && continue
        cg_val = cg_lookup(cg, S, M, m1)
        abs(cg_val) < 1e-15 && continue
        push!(pairs, (F - m1 + 1, F - m2 + 1, cg_val))
    end

    @inbounds for I in CartesianIndices(n_pts)
        s = zero(ComplexF64)
        for (c1, c2, cg_val) in pairs
            s += cg_val * psi[I, c1] * psi[I, c2]
        end
        A[I] = s
    end
    A
end
