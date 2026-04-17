"""
Single-atom basis transformation between the coupled |F, m_F⟩ basis and
the uncoupled |J m_J; I m_I⟩ basis.

For an atom with two_J, two_I:
    |F, m_F⟩ = Σ_{m_J, m_I} ⟨J m_J; I m_I | F m_F⟩ |J m_J; I m_I⟩
The transform is unitary when both bases are enumerated exhaustively
((2J+1)(2I+1) states on each side).
"""

"""
    build_uncoupled_basis(atom) → Vector{Tuple{Int,Int}}

Enumerate |J m_J; I m_I⟩ states as (2m_J, 2m_I) tuples, ordered
lexicographically by (m_J descending, m_I descending). Length = (2J+1)(2I+1).
"""
function build_uncoupled_basis(atom::AtomParams)
    tJ, tI = atom.two_J, atom.two_I
    out = Tuple{Int,Int}[]
    for tmJ in tJ:-2:-tJ
        for tmI in tI:-2:-tI
            push!(out, (tmJ, tmI))
        end
    end
    out
end

"""
    basis_transform_F_to_JI(basis) → Matrix

Transformation matrix `U` such that `|F, m_F⟩_i = Σ_j U[j, i] |J m_J; I m_I⟩_j`,
i.e. columns of U are coefficients of coupled states in the uncoupled basis.

Rows are indexed by the uncoupled basis from `build_uncoupled_basis(atom)`;
columns follow the ordering of `basis.states`.
"""
function basis_transform_F_to_JI(basis::SingleAtomBasis)
    atom = basis.atom
    tJ, tI = atom.two_J, atom.two_I
    uncoupled = build_uncoupled_basis(atom)
    n = length(basis)
    @assert n == length(uncoupled)

    # Lookup (tmJ, tmI) → row index
    row_of = Dict{Tuple{Int,Int},Int}()
    for (r, s) in enumerate(uncoupled)
        row_of[s] = r
    end

    U = zeros(Float64, n, n)
    @inbounds for (col, (tF, tmF)) in enumerate(basis.states)
        for tmJ in -tJ:2:tJ
            tmI = tmF - tmJ
            abs(tmI) > tI && continue
            cg = clebsch_gordan_2j(tJ, tmJ, tI, tmI, tF, tmF)
            cg == 0.0 && continue
            U[row_of[(tmJ, tmI)], col] = cg
        end
    end
    U
end
