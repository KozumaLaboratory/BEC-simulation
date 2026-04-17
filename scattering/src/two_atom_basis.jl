"""
Two-atom basis representations:

  Hyperfine (asymptotic) basis:
      |F₁ m₁; F₂ m₂⟩_sym = 𝒩 (|F₁m₁⟩|F₂m₂⟩ + ε |F₂m₂⟩|F₁m₁⟩)
  with ε = +1 for even ℓ, -1 for odd ℓ (identical-boson symmetry).

  Molecular (short-range) basis:
      |𝒮 M_𝒮; I₁ m_{I1}; I₂ m_{I2}⟩
  where 𝒮 = J₁ + J₂. The Born-Oppenheimer potentials V_𝒮(R) are
  diagonal in this basis.

Phase 1 defines only the data structures; the unitary transform between
them is Phase 2.
"""

"""
    TwoAtomHyperfineState

A symmetrized two-atom hyperfine state. States are stored with a
canonical ordering (tF1, tm1) ≤ (tF2, tm2) lexicographically. When the
pair is identical, only even ℓ couples to this state (odd ℓ vanishes
under antisymmetrization). The `identical` flag records this to make
downstream normalization explicit.
"""
struct TwoAtomHyperfineState
    tF1::Int; tm1::Int
    tF2::Int; tm2::Int
    identical::Bool     # true iff (tF1, tm1) == (tF2, tm2)
end

function TwoAtomHyperfineState(tF1::Int, tm1::Int, tF2::Int, tm2::Int)
    key1 = (tF1, tm1); key2 = (tF2, tm2)
    if key1 > key2
        tF1, tm1, tF2, tm2 = tF2, tm2, tF1, tm1
    end
    TwoAtomHyperfineState(tF1, tm1, tF2, tm2, (tF1, tm1) == (tF2, tm2))
end

"""
    TwoAtomMolecularState

Molecular-frame basis state: coupled electronic spin 𝒮 with projection
M_𝒮, plus uncoupled nuclear-spin projections.  Stored as 2j integers.
Phase 1 placeholder; Phase 2 uses it to diagonalize V_𝒮(R).
"""
struct TwoAtomMolecularState
    two_S::Int; two_MS::Int
    two_mI1::Int; two_mI2::Int
end
