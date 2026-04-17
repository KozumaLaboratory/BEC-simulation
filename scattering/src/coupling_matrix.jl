"""
Channel coupling matrix W(R) for coupled-channel scattering.

For a central Born-Oppenheimer potential V(R) that depends only on the
total electronic spin 𝒮, the matrix element in the symmetrized
hyperfine channel basis is

    ⟨ch_i | V(R) | ch_j⟩ = δ_{ℓ_i,ℓ_j} δ_{m_{ℓ_i},m_{ℓ_j}}
                            × Σ_𝒮 V_𝒮(R) · ⟨sym_i | P_𝒮 | sym_j⟩

where P_𝒮 is the projector onto the total-electronic-spin-𝒮 subspace
and |sym⟩ is the (1 ↔ 2) bosonic-symmetrized hyperfine state:

  distinct pair:   |sym⟩_ε = (|F₁m₁;F₂m₂⟩ + ε |F₂m₂;F₁m₁⟩) / √2,  ε = (-1)^ℓ
  identical pair:  |sym⟩   = |Fm;Fm⟩,   only ε = +1 (even ℓ) allowed

The 𝒮-projector is precomputed as an R-independent rank-4 object
Q[𝒮+1][i,j] ≡ ⟨sym_i|P_𝒮|sym_j⟩; W(R) is then a single linear combination.
"""

"""
    spin_projector_matrices(atom, channels) → Vector{Matrix{Float64}}

Precompute Q[𝒮+1][i,j] = ⟨sym_i | P_𝒮 | sym_j⟩ for 𝒮 = 0, 1, …, J (integer).
All channels are assumed to share the same conserved total projection
M_tot = m_{F₁} + m_{F₂} + m_ℓ. Returned vector has length J + 1 (for
Eu, 8 matrices indexed by 𝒮 = 0..7).
"""
function spin_projector_matrices(
    atom::AtomParams,
    channels::Vector{ScatteringChannel},
)
    tJ = atom.two_J
    n_S = tJ + 1
    n = length(channels)
    Q = [zeros(Float64, n, n) for _ in 1:n_S]
    n == 0 && return Q

    # Verify M_tot conservation and extract it (integer since m_F1+m_F2 integer
    # and m_ℓ integer → M_tot integer).
    function M_tot_of(c::ScatteringChannel)
        Int(div(c.state.tm1 + c.state.tm2, 2)) + c.m_ℓ
    end
    M_tot = M_tot_of(channels[1])
    for c in channels
        @assert M_tot_of(c) == M_tot "channels span more than one M_tot"
    end

    # Group by (ℓ, m_ℓ): V(R) is diagonal in partial wave.
    groups = Dict{Tuple{Int,Int},Vector{Int}}()
    for (i, c) in enumerate(channels)
        push!(get!(groups, (c.ℓ, c.m_ℓ), Int[]), i)
    end

    for ((ℓ, m_ℓ), idx) in groups
        ε = iseven(ℓ) ? 1 : -1
        M_F = M_tot - m_ℓ

        hf = build_two_atom_hyperfine_basis(atom, M_F)
        mol = build_two_atom_molecular_basis(atom, M_F)
        U = hyperfine_to_molecular_transform(atom, hf, mol)

        idx_of = Dict{NTuple{4,Int},Int}()
        for (k, h) in enumerate(hf)
            idx_of[(h.tF1, h.tm1, h.tF2, h.tm2)] = k
        end

        # Expansion of each symmetrized channel state into the product basis.
        S_local = [zeros(Float64, length(hf)) for _ in idx]
        for (li, ci) in enumerate(idx)
            c = channels[ci]
            st = c.state
            a = (st.tF1, st.tm1, st.tF2, st.tm2)
            b = (st.tF2, st.tm2, st.tF1, st.tm1)
            if st.identical
                S_local[li][idx_of[a]] = 1.0
            else
                S_local[li][idx_of[a]] = 1 / sqrt(2)
                S_local[li][idx_of[b]] = ε / sqrt(2)
            end
        end

        # For each 𝒮, project through the molecular-basis rows tagged 𝒮.
        for (s_idx, tS) in enumerate(0:2:(tJ + tJ))
            rows = findall(m -> m.two_S == tS, mol)
            isempty(rows) && continue
            US = @view U[rows, :]
            # Image of each symmetric state under U_𝒮
            V_S_rep = [US * S_local[li] for li in eachindex(idx)]
            for (li, ci) in enumerate(idx), (lj, cj) in enumerate(idx)
                Q[s_idx][ci, cj] = dot(V_S_rep[li], V_S_rep[lj])
            end
        end
    end

    Q
end

"""
    coupling_matrix(R, Q, septet, exch) → Matrix{Float64}

Evaluate W(R) = Σ_𝒮 V_𝒮(R) · Q[𝒮+1] for the Eu+Eu potential family.
`Q` is the output of `spin_projector_matrices`.
"""
function coupling_matrix(
    R::Real,
    Q::Vector{Matrix{Float64}},
    septet::EuEuPotentialParams,
    exch::EuEuExchangeParams,
)
    n = size(Q[1], 1)
    W = zeros(Float64, n, n)
    for (s_idx, QS) in enumerate(Q)
        S = s_idx - 1
        V_S = V_spin(septet, exch, S, R)
        @. W += V_S * QS
    end
    W
end

"""
    channel_thresholds(channels) → Vector{Float64}

Return the asymptotic channel energies E_threshold_i (already stored on
each channel). Convenience vector for building H(R) − E = W(R) + (ℓ(ℓ+1)/R² − k²) I.
"""
channel_thresholds(channels::Vector{ScatteringChannel}) =
    [c.E_threshold for c in channels]

"""
    centrifugal_vector(channels) → Vector{Int}

Per-channel centrifugal ℓ(ℓ+1) factor as integers.
"""
centrifugal_vector(channels::Vector{ScatteringChannel}) =
    [c.ℓ * (c.ℓ + 1) for c in channels]
