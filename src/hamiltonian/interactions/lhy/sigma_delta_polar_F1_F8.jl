# sigma_delta_polar_F1_F8.jl
# =========================
# Auto-generated from sympy Clebsch-Gordan computation (50-digit precision
# cast to Float64). σ_m, δ_m coefficients for polar-phase BdG, F=1..8.
#
# Usage (after `include` into PolarContactLHY module):
#   σ_m(F, m) = Σ (S, coef) ∈ SIGMA_TABLE[F][m+1]: coef × g_S
#   δ_m(F, m) = Σ (S, coef) ∈ DELTA_TABLE[F][m+1]: coef × g_S
#
# Goldstone identities (verified S-by-S in sympy):
#   σ_0(F) ≡ δ_0(F)             for all F ∈ {1,...,8}
#   2σ_1(F) - σ_0(F) ≡ δ_1(F)    for all F ∈ {1,...,8}
#
# 723-line monolith split into 3 sub-files (2026-05-11 refactor):
#
#   sigma_delta_polar_F1_F8/sigma_table.jl  — SIGMA_TABLE Dict literal
#                                              (F=1..8, ~300 lines)
#   sigma_delta_polar_F1_F8/delta_table.jl  — DELTA_TABLE Dict literal
#                                              (F=1..8, ~380 lines)
#   sigma_delta_polar_F1_F8/accessors.jl    — sigma_polar(F,m,g_dict),
#                                              delta_polar(F,m,g_dict)
#                                              lookup wrappers
#
# Include order matters: accessors reference SIGMA_TABLE / DELTA_TABLE
# so the table files must come first.

include("sigma_delta_polar_F1_F8/sigma_table.jl")
include("sigma_delta_polar_F1_F8/delta_table.jl")
include("sigma_delta_polar_F1_F8/accessors.jl")
