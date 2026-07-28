# sigma_delta_fm.jl
# ====================
# σ_m, δ_m coefficients for FM-phase BdG (ζ_α = δ_{α,+F}), any F.
#
# Structural difference from the polar phase:
#   - Polar:  δ_m non-zero for all m (anomalous pair m_tot = 0)
#   - FM:     δ_m non-zero ONLY at m = +F. The anomalous pair needs
#             m_tot = 2F, and α = β = +F is the only way to make it.
#   ⇒ every other mode is free (κ_m = 0) and cancels against its own
#     counterterm, so the FM contact LHY collapses to one mode:
#         ε_LHY^{FM,contact} = (8/15π²) (g_{2F} n)^(5/2)
#
# Verified independently, not assumed: that closed form agrees with
# `full_bdg` — which makes no ansatz — to ~1e-6 at every F from 1 to 8 and
# for two values of c₁ (see test/hamiltonian/test_lhy_polar.jl).
#
# Goldstone identities, algebraic in F:
#   σ_+F   = δ_+F = g_{2F}                  (U(1) phonon)
#   2σ_+(F-1) = σ_+F                        (F_- magnon, type-B, ω ∝ k²)
#
# This file used to ship a hand-entered F=6 table of sympy rationals and
# `error()` for every other F, on the stated grounds that runtime Clebsch-Gordan
# would be "10-100× slower per BdG eval". That reasoning did not apply: σ_m^FM
# is evaluated once per workspace build in `build_fm_lhy_coefs`, never inside a
# BdG loop — and in fact the FM energy never reads it at all, since the
# single-mode collapse leaves only δ_+F. So the F=6 restriction bought nothing
# and blocked F ≠ 6 outright. The table's 91 rationals now live in the test as
# the ORACLE for the closed form below, which reproduces every one of them to
# 5.8e-15.

export sigma_fm, delta_fm

"""
    sigma_fm(F::Int, m::Int, g_dict) -> Float64

FM-phase normal stiffness

    σ_m = Σ_S g_S |⟨S, m+F | F m; F F⟩|²

the pair-channel weight for scattering a magnon at `m` off the condensate at
`+F`. Any `F`; odd `S` never contributes (identical bosons), so only the even
channels present in `g_dict` are summed.
"""
function sigma_fm(F::Int, m::Int, g_dict)::Float64
    F >= 0 || throw(ArgumentError("F must be ≥ 0 (got $F)"))
    abs(m) <= F || throw(ArgumentError("|m| > F (got m=$m, F=$F)"))
    s = 0.0
    for S in 0:2:(2F)
        gS = get(g_dict, S, 0.0)
        gS == 0.0 && continue
        cg = clebsch_gordan(F, m, F, F, S, m + F)
        s += gS * cg * cg
    end
    s
end

"""
    delta_fm(F::Int, m::Int, g_dict) -> Float64

FM-phase anomalous stiffness. Non-zero only at `m = +F`, where `δ_+F = g_{2F}`:
the pair needs `m_tot = 2F`, which forces `S = 2F` and leaves the single
Clebsch-Gordan coefficient `⟨2F, 2F | F F; F F⟩ = 1`.
"""
@inline function delta_fm(F::Int, m::Int, g_dict)::Float64
    m == F || return 0.0
    get(g_dict, 2F, 0.0)
end
