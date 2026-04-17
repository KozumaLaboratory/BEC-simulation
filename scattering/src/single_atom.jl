"""
Single-atom |F, m_F⟩ basis construction and Hamiltonian matrix elements
for hyperfine (magnetic-dipole + electric-quadrupole) and Zeeman terms.

All quantum numbers stored as 2j integers. F = (2J, 2I) coupled angular
momentum takes integer values when 2J+2I is even, half-integer otherwise.
"""

"""
    SingleAtomBasis

Enumeration of |F, m_F⟩ basis states for a given atom.

# Fields
- `atom::AtomParams`
- `states::Vector{Tuple{Int,Int}}` : list of (2F, 2m_F) pairs
"""
struct SingleAtomBasis
    atom::AtomParams
    states::Vector{Tuple{Int,Int}}
end

Base.length(b::SingleAtomBasis) = length(b.states)

"""
    build_single_atom_basis(atom)

Enumerate all |F, m_F⟩ states with F = |J-I|..(J+I), m_F = -F..F.
Returned states are ordered first by F (ascending), then by m_F.
Dimension equals (2J+1)(2I+1).
"""
function build_single_atom_basis(atom::AtomParams)
    tI, tJ = atom.two_I, atom.two_J
    tF_min = abs(tJ - tI)
    tF_max = tJ + tI
    states = Tuple{Int,Int}[]
    for tF in tF_min:2:tF_max                  # step 2 in 2F = integer step in F
        for tmF in -tF:2:tF
            push!(states, (tF, tmF))
        end
    end
    @assert length(states) == (tJ + 1) * (tI + 1)
    SingleAtomBasis(atom, states)
end

"""
    hfs_energy(atom, two_F)

Diagonal hyperfine energy (magnetic dipole + electric quadrupole) for
a given F state in atomic units. From Ramsey (Molecular Beams, Ch. III):

  E_hfs(F) = (A/2) K
          + B · [3 K (K+1) - 4 I(I+1) J(J+1)] / [8 I (2I-1) J (2J-1)]

with K = F(F+1) - I(I+1) - J(J+1). The quadrupole term is omitted
whenever I < 1 or J < 1 (denominator vanishes).
"""
function hfs_energy(atom::AtomParams, tF::Int)
    tI, tJ = atom.two_I, atom.two_J
    F2  = tF * (tF + 2) / 4          # F(F+1) = (2F)(2F+2)/4
    I2  = tI * (tI + 2) / 4
    J2  = tJ * (tJ + 2) / 4
    K   = F2 - I2 - J2
    E   = 0.5 * atom.A_hfs * K
    if tI >= 2 && tJ >= 2 && atom.B_hfs != 0.0
        # denominator: 8 I(2I-1) J(2J-1), with I = tI/2 etc.
        # I(2I-1) = (tI/2)(tI-1); J(2J-1) = (tJ/2)(tJ-1)
        denom = 8 * (tI / 2) * (tI - 1) * (tJ / 2) * (tJ - 1)
        num   = 3 * K * (K + 1) - 4 * I2 * J2
        E    += atom.B_hfs * num / denom
    end
    E
end

"""
    hfs_hamiltonian(basis) → Diagonal matrix [E_h]

Hyperfine Hamiltonian in the |F, m_F⟩ basis (diagonal: independent of m_F).
"""
function hfs_hamiltonian(basis::SingleAtomBasis)
    d = length(basis)
    diag = zeros(Float64, d)
    @inbounds for (i, (tF, _)) in enumerate(basis.states)
        diag[i] = hfs_energy(basis.atom, tF)
    end
    Diagonal(diag)
end

"""
    _Jz_matrix_element(atom, tF1, tF2, tm) [dimensionless, units of ℏ]

⟨F1, m | J_z | F2, m⟩ via decomposition in |J m_J; I m_I⟩:

  ⟨F1 m | J_z | F2 m⟩ = Σ_{m_J} m_J × C(J m_J; I m-m_J | F1 m)
                                       × C(J m_J; I m-m_J | F2 m)
"""
function _Jz_matrix_element(atom::AtomParams, tF1::Int, tF2::Int, tm::Int)
    tJ, tI = atom.two_J, atom.two_I
    s = 0.0
    # m_J runs over -J..J; in 2j, tmJ = -tJ, -tJ+2, ..., tJ
    for tmJ in -tJ:2:tJ
        tmI = tm - tmJ
        abs(tmI) > tI && continue
        cg1 = clebsch_gordan_2j(tJ, tmJ, tI, tmI, tF1, tm)
        cg2 = clebsch_gordan_2j(tJ, tmJ, tI, tmI, tF2, tm)
        s += (tmJ / 2) * cg1 * cg2
    end
    s
end

"""
    _Iz_matrix_element(atom, tF1, tF2, tm) [dimensionless, units of ℏ]

Analogous to `_Jz_matrix_element`, for the nuclear spin I_z.
"""
function _Iz_matrix_element(atom::AtomParams, tF1::Int, tF2::Int, tm::Int)
    tJ, tI = atom.two_J, atom.two_I
    s = 0.0
    for tmJ in -tJ:2:tJ
        tmI = tm - tmJ
        abs(tmI) > tI && continue
        cg1 = clebsch_gordan_2j(tJ, tmJ, tI, tmI, tF1, tm)
        cg2 = clebsch_gordan_2j(tJ, tmJ, tI, tmI, tF2, tm)
        s += (tmI / 2) * cg1 * cg2
    end
    s
end

"""
    _Jplus_matrix_element(atom, tF1, tm1, tF2, tm2)

⟨F1 m1 | J_+ | F2 m2⟩ in units of ℏ, via decomposition in |J m_J; I m_I⟩.
Nonzero only if m1 = m2 + 1.
"""
function _Jplus_matrix_element(
    atom::AtomParams,
    tF1::Int,
    tm1::Int,
    tF2::Int,
    tm2::Int,
)
    (tm1 - tm2) == 2 || return 0.0
    tJ, tI = atom.two_J, atom.two_I
    s = 0.0
    for tmJ2 in -tJ:2:tJ
        tmI = tm2 - tmJ2
        abs(tmI) > tI && continue
        tmJ1 = tmJ2 + 2
        abs(tmJ1) > tJ && continue
        Jv = tJ / 2; mJ2 = tmJ2 / 2
        jp = sqrt(Jv * (Jv + 1) - mJ2 * (mJ2 + 1))
        cg1 = clebsch_gordan_2j(tJ, tmJ1, tI, tmI, tF1, tm1)
        cg2 = clebsch_gordan_2j(tJ, tmJ2, tI, tmI, tF2, tm2)
        s += jp * cg1 * cg2
    end
    s
end

"""
    _Iplus_matrix_element(atom, tF1, tm1, tF2, tm2)

⟨F1 m1 | I_+ | F2 m2⟩ in units of ℏ. Nonzero only if m1 = m2 + 1.
"""
function _Iplus_matrix_element(
    atom::AtomParams,
    tF1::Int,
    tm1::Int,
    tF2::Int,
    tm2::Int,
)
    (tm1 - tm2) == 2 || return 0.0
    tJ, tI = atom.two_J, atom.two_I
    s = 0.0
    for tmJ in -tJ:2:tJ
        tmI2 = tm2 - tmJ
        abs(tmI2) > tI && continue
        tmI1 = tmI2 + 2
        abs(tmI1) > tI && continue
        Iv = tI / 2; mI2 = tmI2 / 2
        ip = sqrt(Iv * (Iv + 1) - mI2 * (mI2 + 1))
        cg1 = clebsch_gordan_2j(tJ, tmJ, tI, tmI1, tF1, tm1)
        cg2 = clebsch_gordan_2j(tJ, tmJ, tI, tmI2, tF2, tm2)
        s += ip * cg1 * cg2
    end
    s
end

"""
    Jplus_matrix(basis) → Matrix{Float64}

Matrix of J_+ in the |F, m_F⟩ basis (ℏ=1). Entries have `m1 = m2 + 1`.
"""
function Jplus_matrix(basis::SingleAtomBasis)
    d = length(basis)
    M = zeros(Float64, d, d)
    @inbounds for (j, (tF2, tm2)) in enumerate(basis.states),
                (i, (tF1, tm1)) in enumerate(basis.states)
        M[i, j] = _Jplus_matrix_element(basis.atom, tF1, tm1, tF2, tm2)
    end
    M
end

"""
    Iplus_matrix(basis) → Matrix{Float64}

Matrix of I_+ in the |F, m_F⟩ basis (ℏ=1).
"""
function Iplus_matrix(basis::SingleAtomBasis)
    d = length(basis)
    M = zeros(Float64, d, d)
    @inbounds for (j, (tF2, tm2)) in enumerate(basis.states),
                (i, (tF1, tm1)) in enumerate(basis.states)
        M[i, j] = _Iplus_matrix_element(basis.atom, tF1, tm1, tF2, tm2)
    end
    M
end

"""
    Jz_matrix(basis) → Matrix{Float64}

Matrix of J_z in the |F, m_F⟩ basis (ℏ=1), diagonal in m_F but coupling
different F at the same m_F.
"""
function Jz_matrix(basis::SingleAtomBasis)
    d = length(basis)
    M = zeros(Float64, d, d)
    @inbounds for (j, (tF2, tm2)) in enumerate(basis.states),
                (i, (tF1, tm1)) in enumerate(basis.states)
        tm1 != tm2 && continue
        M[i, j] = _Jz_matrix_element(basis.atom, tF1, tF2, tm1)
    end
    M
end

"""
    Iz_matrix(basis) → Matrix{Float64}

Matrix of I_z in the |F, m_F⟩ basis (ℏ=1).
"""
function Iz_matrix(basis::SingleAtomBasis)
    d = length(basis)
    M = zeros(Float64, d, d)
    @inbounds for (j, (tF2, tm2)) in enumerate(basis.states),
                (i, (tF1, tm1)) in enumerate(basis.states)
        tm1 != tm2 && continue
        M[i, j] = _Iz_matrix_element(basis.atom, tF1, tF2, tm1)
    end
    M
end

"""
    zeeman_hamiltonian(basis, B_tesla) → Matrix [E_h]

Zeeman Hamiltonian in the |F, m_F⟩ basis for a magnetic field `B_tesla`
along +z:

    H_Z = g_J μ_B B J_z − g_I μ_N B I_z

Sign convention: g_I > 0 means μ_I ∥ I (Ramsey), so the nuclear term
has a minus sign relative to the electronic term.

Diagonal in m_F; couples different F at the same m_F (Paschen–Back regime).
"""
function zeeman_hamiltonian(basis::SingleAtomBasis, B_tesla::Real)
    atom = basis.atom
    d = length(basis)
    H = zeros(Float64, d, d)

    # μ · B in atomic units; B expressed in SI (T), converted to E_h via μ_B[J/T]/E_h.
    #   E_Z_el = g_J μ_B B m_J  →  in a.u. = g_J × (μ_B[J/T] B / E_h) × m_J
    #   same for nuclear with μ_N.
    E_mu_B_au = (_muB_JT * B_tesla) / _Eh_J     # μ_B B in E_h
    E_mu_N_au = (_muN_JT * B_tesla) / _Eh_J     # μ_N B in E_h

    @inbounds for (i, (tF1, tm1)) in enumerate(basis.states)
        for (j, (tF2, tm2)) in enumerate(basis.states)
            tm1 != tm2 && continue
            Jz = _Jz_matrix_element(atom, tF1, tF2, tm1)
            Iz = _Iz_matrix_element(atom, tF1, tF2, tm1)
            H[i, j] = atom.g_J * E_mu_B_au * Jz - atom.g_I * E_mu_N_au * Iz
        end
    end
    H
end

"""
    single_atom_hamiltonian(basis, B_tesla) → Matrix [E_h]

Full single-atom Hamiltonian H_hfs + H_Z in the |F, m_F⟩ basis.
"""
function single_atom_hamiltonian(basis::SingleAtomBasis, B_tesla::Real)
    H = zeeman_hamiltonian(basis, B_tesla)
    Hhfs = hfs_hamiltonian(basis)
    @inbounds for i in 1:length(basis)
        H[i, i] += Hhfs.diag[i]
    end
    H
end
