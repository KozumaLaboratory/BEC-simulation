# What ε_LHY actually depends on — the input to #337 criterion D.
#
# The claim this repo carries in `spatial.jl` and `make_workspace.jl` is that
# only the MAGNITUDE of ⟨F⟩ matters: rotating a spinor leaves ε_LHY invariant to
# machine precision for contact (it is an SO(3) scalar) and moves it 0.25 % under
# the DDI, while taking p = |⟨F⟩|/F from 1 to 0 moves it "~20 %". If that holds,
# every pure DIRECTION texture — flower, spin vortex, skyrmion, all p ≡ 1 — needs
# no LHY refinement at all, and the claims that do need one are exactly those
# comparing states of different |⟨F⟩|.
#
# Two of those three numbers are re-measured here rather than restated, because
# the third (the ~20 %) does not match what the campaign's own parameter point
# gives: ε(FM)/ε(polar) there is a factor 3.9, not 1.2.
#
#   julia --project=. bench/lhy_state_dependence.jl [c1_ratio]

using Printf
using LinearAlgebra: norm, exp, I
using SpinorBEC
using SpinorBEC: _lhy_bdg_energy_and_growth, spin_matrices

include(joinpath(@__DIR__, "eu151_params.jl"))

const C1_RATIO = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 1 / 36
const F = 6
const D = 2F + 1
const N_PEAK = 3.7e-3
const B_UG = 44.0
const ZEE = let B_T = B_UG * 1e-10
    p = linear_zeeman_p(Eu151, B_T, EU_ω_ref)
    ZeemanParams(p, SpinorBEC.compute_quadratic_zeeman(Eu151; p_dimless=p, omega_ref=EU_ω_ref))
end

ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F)
sm = spin_matrices(F)

eps_lhy(z; c_dd, zee=ZEE, ipar=ip) = first(_lhy_bdg_energy_and_growth(z, N_PEAK, F,
    ipar, zee, c_dd, nothing, nothing, nothing; rtol=1e-4)) / EU_N_atoms
growth(z; c_dd, zee=ZEE) = last(_lhy_bdg_energy_and_growth(z, N_PEAK, F, ip, zee,
    c_dd, nothing, nothing, nothing; rtol=1e-4))

"Euler rotation e^{-iαFz} e^{-iβFy} e^{-iγFz} applied to a spinor."
function rotate(z, α, β, γ)
    Fz = Matrix{ComplexF64}(sm.Fz)
    Fy = Matrix{ComplexF64}(sm.Fy)
    exp(-im * α * Fz) * exp(-im * β * Fy) * exp(-im * γ * Fz) * z
end

polarisation(z) = begin
    zz = z ./ norm(z)
    fx = real(zz' * Matrix{ComplexF64}(sm.Fx) * zz)
    fy = real(zz' * Matrix{ComplexF64}(sm.Fy) * zz)
    fz = real(zz' * Matrix{ComplexF64}(sm.Fz) * zz)
    sqrt(fx^2 + fy^2 + fz^2) / F
end

fm() = (z = zeros(ComplexF64, D); z[1] = 1.0; z)
polar() = (z = zeros(ComplexF64, D); z[F + 1] = 1.0; z)

println("="^92)
println("ε_LHY state dependence — Eu F=6, c1_ratio = ", round(C1_RATIO; sigdigits=6),
    ", n = ", N_PEAK, ", B = ", B_UG, " µG")
println("="^92)

# ---------------------------------------------------------------------------
# 1. SO(3) invariance. Contact must be EXACT; the DDI picks a lab axis, so it
#    must not be. A test where both come out invariant would be measuring
#    nothing, so the c_dd = Eu column is the positive control for the c_dd = 0
#    column's null.
# ---------------------------------------------------------------------------
println("\n[1] rotating the FM spinor — contact is an SO(3) scalar, the DDI is not")
@printf("  %-26s %16s %16s\n", "(α, β, γ)", "ε contact", "ε with DDI")
const ZEE0 = ZeemanParams(0.0, 0.0)

function rotation_sweep(zee, tag)
    e0c = eps_lhy(fm(); c_dd=0.0, zee)
    e0d = eps_lhy(fm(); c_dd=EU_c_dd, zee)
    worst_c = 0.0
    worst_d = 0.0
    for (a, b, g) in ((0.0, 0.0, 0.0), (0.0, π / 6, 0.0), (0.0, π / 3, 0.0),
        (0.0, π / 2, 0.0), (0.7, 1.1, 0.3), (2.0, 2.5, 1.0))
        z = rotate(fm(), a, b, g)
        ec = eps_lhy(z; c_dd=0.0, zee)
        ed = eps_lhy(z; c_dd=EU_c_dd, zee)
        worst_c = max(worst_c, abs(ec - e0c) / abs(e0c))
        worst_d = max(worst_d, abs(ed - e0d) / abs(e0d))
        @printf("  %-8s (%.2f, %.2f, %.2f) %16.9g %16.9g\n", tag, a, b, g, ec, ed)
        flush(stdout)
    end
    (worst_c, worst_d)
end

# TWO Zeeman settings, because a rotation test at nonzero B is not a test of
# SO(3) invariance at all: the field picks the z axis, so tilting the spinor
# genuinely changes the Zeeman contribution to the BdG matrix. Running it at
# B = 0 first is what separates "the theory is an SO(3) scalar" from "this probe
# had a preferred axis in it".
let (wc, wd) = rotation_sweep(ZEE0, "B=0")
    @printf("\n  B = 0    max relative deviation: contact %.3e   DDI %.3e\n", wc, wd)
end
let (wc, wd) = rotation_sweep(ZEE, "B=44µG")
    @printf("  B = 44µG max relative deviation: contact %.3e   DDI %.3e\n", wc, wd)
end
@printf("  (p = |⟨F⟩|/F is %.6f for every row — a rotation cannot change it)\n",
    polarisation(rotate(fm(), 0.7, 1.1, 0.3)))

# ---------------------------------------------------------------------------
# 2. Magnitude dependence along a real one-parameter family. ζ(α) = cos α |+F⟩ +
#    sin α |0⟩ sweeps p from 1 to 0 through states that a trapped cloud actually
#    contains, rather than through an invented interpolation.
# ---------------------------------------------------------------------------
println("\n[2] ε_LHY vs p = |⟨F⟩|/F along ζ(α) = cos α |m=+F⟩ + sin α |m=0⟩")
@printf("  %-8s %10s %16s %16s %12s\n", "α/π", "p", "ε contact", "ε with DDI", "max Im ω")
function magnitude_sweep()
    for a in range(0.0, 0.5; length=11)
        z = zeros(ComplexF64, D)
        z[1] = cos(a * π)
        z[F + 1] = sin(a * π)
        z ./= norm(z)
        @printf("  %-8.3f %10.5f %16.9g %16.9g %12.4g\n",
            a, polarisation(z), eps_lhy(z; c_dd=0.0), eps_lhy(z; c_dd=EU_c_dd),
            growth(z; c_dd=EU_c_dd))
        flush(stdout)
    end
end
magnitude_sweep()

println("\n[3] the two endpoints, as ratios")
let ec1 = eps_lhy(fm(); c_dd=0.0), ec0 = eps_lhy(polar(); c_dd=0.0),
    ed1 = eps_lhy(fm(); c_dd=EU_c_dd), ed0 = eps_lhy(polar(); c_dd=EU_c_dd)

    @printf("  contact: ε(p=1)/ε(p=0) = %.4f   (%.4g vs %.4g)\n", ec1 / ec0, ec1, ec0)
    @printf("  with DDI: ε(p=1)/ε(p=0) = %.4f  (%.4g vs %.4g)\n", ed1 / ed0, ed1, ed0)
end


# ---------------------------------------------------------------------------
# 4. Where "~20 %" came from. The p-dependence is controlled entirely by the
#    SPREAD of g_S across channels, which is c1_ratio: at c1_ratio = 0 every
#    g_S equals c₀, both endpoints collapse to (c₀n)^(5/2), and the ratio is
#    exactly 1. So a number measured near c1_ratio = 0 says nothing about the
#    campaign's 1/36.
# ---------------------------------------------------------------------------
println("\n[4] ε(p=1)/ε(p=0) vs c1_ratio — the knob the magnitude dependence rides on")
@printf("  %-12s %14s %14s %12s\n", "c1_ratio", "ε(p=1)", "ε(p=0)", "ratio")
for r in (0.0, 0.001, 0.005, 0.01, 0.02, 1 / 36, 0.05, 0.1)
    ipr = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=r, F)
    e1 = eps_lhy(fm(); c_dd=EU_c_dd, zee=ZEE, ipar=ipr)
    e0 = eps_lhy(polar(); c_dd=EU_c_dd, zee=ZEE, ipar=ipr)
    @printf("  %-12.5f %14.6g %14.6g %12.4f\n", r, e1, e0, e1 / e0)
    flush(stdout)
end

println("\ndone.")
