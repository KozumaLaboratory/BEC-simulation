# --- Pair amplitudes (singlet, channel S/M, integrated spectrum) ---
#
# Two-body pair amplitude observables: singlet A_00, general A_SM, and
# integrated channel weights. CG-coefficient based.

export singlet_pair_amplitude, pair_amplitude, pair_amplitude_spectrum

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
            s += singlet_pair_sign(F, m) * psi[I, c] * psi[I, c_pair]
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
