"""
Unitary transform between the two-atom hyperfine (asymptotic) product
basis and the molecular (short-range) basis.

Hyperfine product basis:
    |F₁ m₁; F₂ m₂⟩     (atoms uncoupled, within-atom F₁ = J₁ ⊕ I₁ coupled)

Molecular basis:
    |𝒮 M_𝒮; m_{I₁} m_{I₂}⟩   (electronic spins J₁⊕J₂ → 𝒮, nuclei uncoupled)

Both are labeled by the conserved total projection M_tot = m₁ + m₂ =
M_𝒮 + m_{I₁} + m_{I₂} at fixed M_tot. The transformation matrix is

    ⟨𝒮 M_𝒮; m_{I₁} m_{I₂} | F₁ m₁; F₂ m₂⟩ =
        Σ_{m_{J₁}, m_{J₂}} ⟨J₁ m_{J₁}; I₁ m_{I₁} | F₁ m₁⟩ ×
                           ⟨J₂ m_{J₂}; I₂ m_{I₂} | F₂ m₂⟩ ×
                           ⟨J₁ m_{J₁}; J₂ m_{J₂} | 𝒮 M_𝒮⟩

with m_{J_i} = m_i − m_{I_i} fixed by the first two Clebsch-Gordans and
M_𝒮 = m_{J₁} + m_{J₂} fixed by the third.

Symmetrization for identical bosons is layered on top in a separate step
(the hyperfine and molecular bases enumerated here are product bases —
no (1 ↔ 2) swap symmetry imposed yet).
"""

"""
    TwoAtomHyperfineProduct

Unsymmetrized product state |F₁ m₁; F₂ m₂⟩.  Half-integers stored as 2j.
"""
struct TwoAtomHyperfineProduct
    tF1::Int; tm1::Int
    tF2::Int; tm2::Int
end

"""
    TwoAtomMolecularProduct

Molecular basis state |𝒮 M_𝒮; m_{I₁} m_{I₂}⟩.
"""
struct TwoAtomMolecularProduct
    two_S::Int; two_MS::Int
    two_mI1::Int; two_mI2::Int
end

"""
    build_two_atom_hyperfine_basis(atom, M_tot) → Vector{TwoAtomHyperfineProduct}

Enumerate product states |F₁ m₁; F₂ m₂⟩ with m₁ + m₂ = M_tot, for two
identical atoms of the given species. Canonical ordering is lexicographic
by (tF1, tm1, tF2, tm2).
"""
function build_two_atom_hyperfine_basis(atom::AtomParams, M_tot::Integer)
    tI = atom.two_I; tJ = atom.two_J
    tM_tot = 2 * M_tot
    out = TwoAtomHyperfineProduct[]
    Fmin = abs(tJ - tI); Fmax = tJ + tI
    for tF1 in Fmin:2:Fmax, tm1 in -tF1:2:tF1
        tm2 = tM_tot - tm1
        for tF2 in Fmin:2:Fmax
            abs(tm2) > tF2 && continue
            push!(out, TwoAtomHyperfineProduct(tF1, tm1, tF2, tm2))
        end
    end
    out
end

"""
    build_two_atom_molecular_basis(atom, M_tot) → Vector{TwoAtomMolecularProduct}

Enumerate molecular basis states |𝒮 M_𝒮; m_{I₁} m_{I₂}⟩ with
M_𝒮 + m_{I₁} + m_{I₂} = M_tot. Identical-atom assumption: two_J, two_I
taken from `atom`.
"""
function build_two_atom_molecular_basis(atom::AtomParams, M_tot::Integer)
    tI = atom.two_I; tJ = atom.two_J
    tM_tot = 2 * M_tot
    S_max = tJ + tJ              # in 2S units, integer 𝒮 so tS steps by 2
    out = TwoAtomMolecularProduct[]
    for tS in 0:2:S_max, tMS in -tS:2:tS
        for tmI1 in -tI:2:tI
            tmI2 = tM_tot - tMS - tmI1
            abs(tmI2) > tI && continue
            push!(out, TwoAtomMolecularProduct(tS, tMS, tmI1, tmI2))
        end
    end
    out
end

"""
    hyperfine_to_molecular_transform(atom, hf_basis, mol_basis) → Matrix

Return `U` with `U[μ, α] = ⟨μ | α⟩` where `α` indexes `hf_basis` (columns)
and `μ` indexes `mol_basis` (rows). For complete bases at fixed M_tot, `U`
is unitary (up to enumeration completeness: both bases must span the same
M_tot block).
"""
function hyperfine_to_molecular_transform(
    atom::AtomParams,
    hf::Vector{TwoAtomHyperfineProduct},
    mol::Vector{TwoAtomMolecularProduct},
)
    tJ = atom.two_J; tI = atom.two_I
    row_of = Dict{NTuple{4,Int},Int}()
    for (r, m) in enumerate(mol)
        row_of[(m.two_S, m.two_MS, m.two_mI1, m.two_mI2)] = r
    end

    U = zeros(Float64, length(mol), length(hf))
    @inbounds for (col, h) in enumerate(hf)
        tF1 = h.tF1; tm1 = h.tm1; tF2 = h.tF2; tm2 = h.tm2
        # Enumerate (m_{I1}, m_{I2}); m_{J_i} = m_i - m_{I_i}, M_𝒮 = m_J1+m_J2.
        for tmI1 in -tI:2:tI
            tmJ1 = tm1 - tmI1
            abs(tmJ1) > tJ && continue
            cg1 = clebsch_gordan_2j(tJ, tmJ1, tI, tmI1, tF1, tm1)
            cg1 == 0.0 && continue
            for tmI2 in -tI:2:tI
                tmJ2 = tm2 - tmI2
                abs(tmJ2) > tJ && continue
                cg2 = clebsch_gordan_2j(tJ, tmJ2, tI, tmI2, tF2, tm2)
                cg2 == 0.0 && continue
                tMS = tmJ1 + tmJ2
                # Iterate 𝒮; CG gives m_J1 + m_J2 = M_𝒮 implicitly
                for tS in abs(tJ - tJ):2:(tJ + tJ)
                    abs(tMS) > tS && continue
                    cg3 = clebsch_gordan_2j(tJ, tmJ1, tJ, tmJ2, tS, tMS)
                    cg3 == 0.0 && continue
                    key = (tS, tMS, tmI1, tmI2)
                    r = get(row_of, key, 0)
                    r == 0 && continue
                    U[r, col] += cg1 * cg2 * cg3
                end
            end
        end
    end
    U
end
