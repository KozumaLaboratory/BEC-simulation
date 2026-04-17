"""
Magnetic dipole-dipole interaction (DDI) between two atomic magnetic
moments.

Operator (atomic units, ℏ = 1, μ_B_au = 1/2, α = fine-structure constant):

    V_dd(R, r̂) = α² g_J² μ_B² / R³ · [J₁·J₂ − 3(J₁·r̂)(J₂·r̂)]
              = −√6 α² g_J² μ_B² / R³ · Σ_q (−1)^q [J₁⊗J₂]²_q C²_{−q}(r̂)

For Eu (⁸S_{7/2}, L = 0), J coincides with the electron spin S so the
molecular total electronic spin 𝒮 = J₁ + J₂ is the good quantum number
the BO potentials diagonalize.  DDI connects states differing in 𝒮 by
up to 2, and couples partial waves with Δℓ = 0, ±2.

The channel-basis matrix element for identical bosons with
|sym⟩ = (|α⟩ + ε |α swap⟩)/√2, ε = (−1)^ℓ, is

    W_dd[i, j](R) = (prefactor / R³)
                     · Σ_q (−1)^q
                       · ⟨sym_i | [J₁⊗J₂]²_q | sym_j⟩
                       · ⟨ℓ_i m_{ℓ,i} | C²_{−q}(r̂) | ℓ_j m_{ℓ,j}⟩

with `prefactor = −√6 α² g_J² μ_B²`.  The spin factor is built via the
hyperfine → molecular transform `U` (see `two_atom_transform.jl`) and
the reduced matrix element in the molecular basis,

    ⟨𝒮' M' | [J₁⊗J₂]²_q | 𝒮 M⟩ =
        ⟨𝒮 M; 2 q | 𝒮' M'⟩ · √((2𝒮+1)(2𝒮'+1)·5) ·
        9j{J J 𝒮; J J 𝒮'; 1 1 2} · J(J+1)(2J+1)

and is diagonal in the uncoupled nuclear spins (m_{I₁}, m_{I₂}).
"""

# Fine-structure constant (CODATA 2018): α = 7.2973525693e-3
const _FINE_STRUCTURE = 7.2973525693e-3

"""
    ddi_prefactor(atom) → Float64

Numerical prefactor of V_dd, −√6 α² g_J² μ_B²_au, in E_h·a_0³ units. The
full central DDI contribution to the channel coupling matrix is
`ddi_prefactor(atom) * ddi_angular_matrix(atom, channels) / R³`.
"""
function ddi_prefactor(atom::AtomParams)
    α2 = _FINE_STRUCTURE^2
    -sqrt(6) * α2 * atom.g_J^2 * MU_B_AU^2
end

# Reduced matrix element ⟨(JJ)𝒮' || [J⊗J]² || (JJ)𝒮⟩.
# 9j layout: {J J 𝒮; J J 𝒮'; 1 1 2}.
function _red_me_JJ2(tJ::Int, tS::Int, tSp::Int)
    w9 = wigner_9j_2j(tJ, tJ, tS, tJ, tJ, tSp, 2, 2, 4)
    Jv = tJ / 2
    JJfac = Jv * (Jv + 1) * (tJ + 1)      # J(J+1)(2J+1) = ⟨J||J||J⟩²
    sqrt((tS + 1) * (tSp + 1) * 5) * w9 * JJfac
end

# Spatial matrix element ⟨ℓ_i m_i | C²_{−q} | ℓ_j m_j⟩.
function _spatial_C2_me(ℓi::Int, m_i::Int, ℓj::Int, m_j::Int, q::Int)
    (m_j - q) == m_i || return 0.0
    g00 = wigner_3j_2j(2ℓi, 4, 2ℓj, 0, 0, 0)
    g00 == 0.0 && return 0.0
    g3j = wigner_3j_2j(2ℓi, 4, 2ℓj, -2m_i, -2q, 2m_j)
    g3j == 0.0 && return 0.0
    phase = iseven(m_i) ? 1.0 : -1.0
    phase * sqrt((2ℓi + 1) * (2ℓj + 1)) * g3j * g00
end

"""
    ddi_angular_matrix(atom, channels) → Matrix{Float64}

R-independent spin × spatial part of the dipole-dipole coupling, i.e. the
matrix `M` such that

    W_dd(R) = ddi_prefactor(atom) · M / R³.

`M[i, j]` contains the full sum over q of (−1)^q ⟨sym_i|[J⊗J]²_q|sym_j⟩
times the spatial Racah tensor matrix element `⟨ℓ_i m_{ℓ,i}|C²_{−q}|ℓ_j
m_{ℓ,j}⟩`. Result is real symmetric.
"""
function ddi_angular_matrix(
    atom::AtomParams,
    channels::Vector{ScatteringChannel},
)
    n = length(channels)
    n == 0 && return zeros(Float64, 0, 0)
    tJ = atom.two_J

    # Conserved total projection check
    M_tot_of(c) = Int(div(c.state.tm1 + c.state.tm2, 2)) + c.m_ℓ
    M_tot = M_tot_of(channels[1])
    for c in channels
        @assert M_tot_of(c) == M_tot "channels span more than one M_tot"
    end

    # Per-channel hyperfine M_F and group channels by it.
    M_F_of(c) = (c.state.tm1 + c.state.tm2) ÷ 2

    M_F_groups = Dict{Int,Vector{Int}}()
    for (i, c) in enumerate(channels)
        push!(get!(M_F_groups, M_F_of(c), Int[]), i)
    end

    # For each M_F value, precompute hf/molecular bases and transform,
    # then expand every channel's symmetric spin state into the molecular
    # basis of its M_F block.
    mol_bases = Dict{Int,Vector{TwoAtomMolecularProduct}}()
    v_mol = Vector{Vector{Float64}}(undef, n)

    for (M_F, idx) in M_F_groups
        hf = build_two_atom_hyperfine_basis(atom, M_F)
        mol = build_two_atom_molecular_basis(atom, M_F)
        U = hyperfine_to_molecular_transform(atom, hf, mol)
        mol_bases[M_F] = mol

        idx_of = Dict{NTuple{4,Int},Int}()
        for (k, h) in enumerate(hf)
            idx_of[(h.tF1, h.tm1, h.tF2, h.tm2)] = k
        end

        for ci in idx
            c = channels[ci]
            ℓ = c.ℓ
            ε = iseven(ℓ) ? 1 : -1
            st = c.state
            a_key = (st.tF1, st.tm1, st.tF2, st.tm2)
            b_key = (st.tF2, st.tm2, st.tF1, st.tm1)
            vec = zeros(Float64, length(hf))
            if st.identical
                vec[idx_of[a_key]] = 1.0
            else
                vec[idx_of[a_key]] = 1 / sqrt(2)
                vec[idx_of[b_key]] = ε / sqrt(2)
            end
            v_mol[ci] = U * vec
        end
    end

    # Precompute the molecular-basis spin kernel K[(M_F_i, M_F_j)] such that
    #   ⟨sym_i | [J⊗J]²_q | sym_j⟩ = v_mol[i]ᵀ · K[(M_F_i, M_F_j)] · v_mol[j]
    # with q = M_F_i − M_F_j. Only (M_F_i, M_F_j) pairs with |q| ≤ 2 contribute.
    spin_kernel = Dict{NTuple{2,Int},Matrix{Float64}}()
    for (M_F_i, _) in M_F_groups, (M_F_j, _) in M_F_groups
        q = M_F_i - M_F_j
        abs(q) > 2 && continue
        mol_i = mol_bases[M_F_i]
        mol_j = mol_bases[M_F_j]
        K = zeros(Float64, length(mol_i), length(mol_j))
        @inbounds for ai in eachindex(mol_i)
            ma = mol_i[ai]
            tS_a = ma.two_S; tMS_a = ma.two_MS
            inv_sqrt_a = 1 / sqrt(tS_a + 1)
            for bj in eachindex(mol_j)
                mb = mol_j[bj]
                ma.two_mI1 == mb.two_mI1 || continue
                ma.two_mI2 == mb.two_mI2 || continue
                cg = clebsch_gordan_2j(mb.two_S, mb.two_MS, 4, 2q, tS_a, tMS_a)
                cg == 0.0 && continue
                red = _red_me_JJ2(tJ, tS_a, mb.two_S)
                red == 0.0 && continue
                K[ai, bj] = cg * red * inv_sqrt_a
            end
        end
        spin_kernel[(M_F_i, M_F_j)] = K
    end

    M = zeros(Float64, n, n)
    for i in 1:n, j in 1:n
        M_F_i = M_F_of(channels[i])
        M_F_j = M_F_of(channels[j])
        q = M_F_i - M_F_j                       # [J⊗J]²_q raises M_F by q
        abs(q) > 2 && continue

        ℓi = channels[i].ℓ; mli = channels[i].m_ℓ
        ℓj = channels[j].ℓ; mlj = channels[j].m_ℓ
        s_me = _spatial_C2_me(ℓi, mli, ℓj, mlj, q)
        s_me == 0.0 && continue

        K = spin_kernel[(M_F_i, M_F_j)]
        spin_me = dot(v_mol[i], K, v_mol[j])

        phase_q = iseven(q) ? 1.0 : -1.0
        M[i, j] += phase_q * spin_me * s_me
    end
    M
end

"""
    ddi_matrix(atom, channels) → Matrix{Float64}

Full R-independent DDI contribution: `W_dd(R) = ddi_matrix(...) / R³`
with result in E_h·a_0³. Convenience wrapper combining
`ddi_prefactor(atom) * ddi_angular_matrix(atom, channels)`.
"""
function ddi_matrix(atom::AtomParams, channels::Vector{ScatteringChannel})
    ddi_prefactor(atom) .* ddi_angular_matrix(atom, channels)
end
