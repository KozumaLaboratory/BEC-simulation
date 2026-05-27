# Canonical polyhedral inert-state spinors for spin-F BEC (Paper #3 §V).
#
# Single source of truth for the ζ vectors of Paper #3 "Universal Structure
# Theorem for LHY Corrections" §V.A through §V.G. Reused by:
#
#   - `phase_classification.jl` (DEFAULT_PHASE_REFERENCES — analytic
#     feature values for nearest-neighbour classification)
#   - `majorana.jl` (`_make_F8_octa_A1_stars`, `_make_F10_dodec_stars`,
#     `_make_F12_Ih_A_stars` — pairwise-distance spectrum lookups)
#   - `scripts/cli.jl figure --paper paper3 --fig 6` (FIG-7 rendering)
#
# Component order: index k corresponds to m = F-k+1, so index 1 is m=+F
# and index 2F+1 is m=-F. F=0 component lives at index F+1.
#
# F=6 I_h canonical state lives in `IcosahedralMod.ZETA_F6_IH`
# (`src/hamiltonian/interactions/lhy/icosahedral.jl`) — the function
# `canonical_polyhedral_spinor(6)` delegates there so all callers go
# through one accessor.

export ZETA_F2_TD_CYCLIC, ZETA_F3_O_A2, ZETA_F4_OH_A1
export ZETA_F8_OH_A1, ZETA_F10_IH_DODEC, ZETA_F12_IH_A
export canonical_polyhedral_spinor, canonical_polyhedral_point_group

# §V.A  F=2  T_d cyclic: ζ = (1, 0, i√2, 0, 1) / 2
const ZETA_F2_TD_CYCLIC = ComplexF64[1.0, 0.0, im * sqrt(2.0), 0.0, 1.0] ./ 2.0

# §V.B  F=3  O:A_2 octahedral sign rep:
#   ζ = (|+2⟩ − |−2⟩) / √2
const ZETA_F3_O_A2 = begin
    z = zeros(ComplexF64, 7)
    z[2] = 1.0 / sqrt(2.0)      # m=+2
    z[6] = -1.0 / sqrt(2.0)     # m=-2
    z
end

# §V.C  F=4  O:A_1 cube:
#   ζ = √(5/24)|+4⟩ + √(7/12)|0⟩ + √(5/24)|−4⟩
const ZETA_F4_OH_A1 = begin
    z = zeros(ComplexF64, 9)
    z[1] = sqrt(5 / 24)         # m=+4
    z[5] = sqrt(7 / 12)         # m=0
    z[9] = sqrt(5 / 24)         # m=-4
    z
end

# §V.E  F=8  O:A_1 cube-like octahedral:
#   ζ = √390/48 (|+8⟩+|−8⟩) + √42/24 (|+4⟩+|−4⟩) + √33/8 |0⟩
const ZETA_F8_OH_A1 = begin
    z = zeros(ComplexF64, 17)
    z[1] = sqrt(390) / 48      # m=+8
    z[5] = sqrt(42) / 24       # m=+4
    z[9] = sqrt(33) / 8        # m=0
    z[13] = sqrt(42) / 24       # m=-4
    z[17] = sqrt(390) / 48      # m=-8
    z
end

# §V.F  F=10  I:A dodecahedral:
#   ζ = √561/75(|+10⟩+|−10⟩) + √209/25(|+5⟩−|−5⟩) + √741/75|0⟩
const ZETA_F10_IH_DODEC = begin
    z = zeros(ComplexF64, 21)
    z[1] = sqrt(561) / 75      # m=+10
    z[6] = sqrt(209) / 25      # m=+5
    z[11] = sqrt(741) / 75      # m=0
    z[16] = -sqrt(209) / 25     # m=-5
    z[21] = sqrt(561) / 75      # m=-10
    z
end

# §V.G  F=12  I:A icosahedral (C_5^z-invariant). Support m ∈ {±10, ±5, 0}.
# Decimal coefficients suffice for pairwise-distance spectrum (tol = 0.15);
# rational form is available at higher precision in
# `docs/manuscript/papers/paper3_universal_theorem/F12_verification_result.md`.
const ZETA_F12_IH_A = begin
    z = zeros(ComplexF64, 25)
    z[3] = 0.4871              # m=+10 (index = F + 1 − m = 13 − 10 = 3)
    z[8] = -0.3024             # m=+5
    z[13] = 0.5853              # m=0
    z[18] = 0.3024              # m=-5
    z[23] = 0.4871              # m=-10
    z ./= sqrt(sum(abs2, z))
    z
end

# NOT GENERALIZABLE: canonical inert spinors exist only for F ∈ {2,3,4,6,8,10,12}.
# Reason: math
# Why: F=1 has no polyhedral inert state (only polar/FM). F=5 has an algebraic
#   obstruction proved in test/manuscript/test_f_systematic_lemma1_predictions.jl.
#   F=7,9,11 not covered by Paper #3 §V — no symmetric rank-(F) invariant known.
#   This is a structural absence in the manuscript, not an unfilled TODO.
# See: docs/manuscript/papers/paper3_universal_theorem/f5_f7_verification_result.md
"""
    canonical_polyhedral_spinor(F::Int) → Vector{ComplexF64}

Return the canonical Paper #3 §V inert-state spinor for spin-F.

| F  | Section | Point group | Constant                  |
|----|---------|-------------|---------------------------|
| 2  | §V.A    | T_d         | `ZETA_F2_TD_CYCLIC`       |
| 3  | §V.B    | O (A_2)     | `ZETA_F3_O_A2`            |
| 4  | §V.C    | O_h (A_1)   | `ZETA_F4_OH_A1`           |
| 6  | §V.D    | I_h         | `IcosahedralMod.ZETA_F6_IH` |
| 8  | §V.E    | O_h (A_1)   | `ZETA_F8_OH_A1`           |
| 10 | §V.F    | I_h         | `ZETA_F10_IH_DODEC`       |
| 12 | §V.G    | I_h (A)     | `ZETA_F12_IH_A`           |

Errors for F values without a canonical inert state defined in Paper #3
(currently F=1, F=5, F=7, F=9, F=11 — F=5 has an algebraic obstruction
documented in `test/manuscript/test_f_systematic_lemma1_predictions.jl`).
"""
function canonical_polyhedral_spinor(F::Int)
    if F == 2
        return ZETA_F2_TD_CYCLIC
    elseif F == 3
        return ZETA_F3_O_A2
    elseif F == 4
        return ZETA_F4_OH_A1
    elseif F == 6
        return IcosahedralMod.ZETA_F6_IH
    elseif F == 8
        return ZETA_F8_OH_A1
    elseif F == 10
        return ZETA_F10_IH_DODEC
    elseif F == 12
        return ZETA_F12_IH_A
    else
        throw(
            ArgumentError(
                "no canonical polyhedral inert state defined for F=$F " *
                "(known: F=2,3,4,6,8,10,12 per Paper #3 §V)",
            ),
        )
    end
end

const POINT_GROUP_BY_F = Dict{Int, Symbol}(
    2 => :T_d,
    3 => :O_h,
    4 => :O_h,
    6 => :I_h,
    8 => :O_h,
    10 => :I_h,
    12 => :I_h,
)

"""
    canonical_polyhedral_point_group(F::Int) → Symbol

Point-group symmetry of the canonical inert state at spin-F.
Returns `:T_d`, `:O_h`, or `:I_h`. Mirrors the table in
[`canonical_polyhedral_spinor`](@ref).
"""
function canonical_polyhedral_point_group(F::Int)
    pg = get(POINT_GROUP_BY_F, F, nothing)
    pg === nothing && throw(
        ArgumentError(
            "no canonical polyhedral inert state defined for F=$F " *
            "(known: $(sort(collect(keys(POINT_GROUP_BY_F)))))",
        ),
    )
    pg
end
