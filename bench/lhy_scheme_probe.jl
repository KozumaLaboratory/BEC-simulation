# What ε_LHY does at the Eu F=6 parameter points the campaigns actually use.
#
# Issue #337 asks which scheme to adopt on a dynamically unstable dipolar spinor
# mean field. Before selecting one, this prints the numbers that decide whether
# the question is even live at each point: which branch is unstable, whether the
# DDI is what makes it so, and how far apart the candidate ε_LHY values are.
#
# CPU-only and seconds-cheap — it is a uniform-system probe, not a run.
#
#   julia --project=. bench/lhy_scheme_probe.jl

using Printf
using SpinorBEC
using SpinorBEC: lhy_energy_polar, lhy_energy_fm, lhy_energy_fm_dipolar,
    lhy_energy_polar_dipolar, epsilon_LHY_F6_Ih, build_polar_lhy_coefs,
    build_fm_lhy_coefs, lhy_mean_field_max_growth, _lhy_bdg_energy_and_growth,
    c_to_g, lima_pelster_Q5, ZETA_F6_IH

include(joinpath(@__DIR__, "eu151_params.jl"))

const F = 6
const D = 2F + 1
const N_PEAK = 3.7e-3          # peak |ψ|² of a converged 50k Eu cloud, 32×32×64
const ZEE0 = ZeemanParams(0.0, 0.0)

polar_spinor() = (z = zeros(ComplexF64, D); z[F + 1] = 1.0; z)
fm_spinor() = (z = zeros(ComplexF64, D); z[1] = 1.0; z)

safe(f) = try
    f()
catch e
    NaN
end

println("="^92)
println("Eu-151 F=6 LHY probe — ε_dd = $(round(EU_ε_dd; sigdigits=5)), ",
    "c_total = $(round(EU_c_total; sigdigits=6)), c_dd = $(round(EU_c_dd; sigdigits=6))")
println("n_peak used for ε: $(N_PEAK)")
println("="^92)

# ---------------------------------------------------------------------------
# 1. Is the Lima-Pelster angular integrand ever negative here? That is the ONLY
#    place the dipolar closed forms could acquire an imaginary part, and the
#    literature prescription (take the real part) is a no-op when it is not.
# ---------------------------------------------------------------------------
println("\n[1] Lima-Pelster bracket 1 + ε_dd(3cos²θ − 1) over θ")
lo = 1 - EU_ε_dd
hi = 1 + 2 * EU_ε_dd
@printf("  min = %.6f  (θ = π/2)     max = %.6f  (θ = 0)\n", lo, hi)
@printf("  Q5(ε_dd) = %.6f   Q5(0) = %.6f   ratio = %.4f\n",
    lima_pelster_Q5(EU_ε_dd), lima_pelster_Q5(0.0), lima_pelster_Q5(EU_ε_dd))
println("  bracket stays positive for ε_dd < 1 ⇒ Q5 is REAL and the real-part")
println("  prescription is vacuous in the density channel at this atom.")

# ---------------------------------------------------------------------------
# 2. Per c1_ratio: stability of each candidate reference state, DDI on and off,
#    and every closed form's ε at the same density.
# ---------------------------------------------------------------------------
const RATIOS = (-0.05, -0.01, 0.0, 0.01, 0.02, 0.026, 0.028, 0.030, 0.05, 0.10)

println("\n[2] max Im ω of the UNIFORM mean field at n = n_peak (0 = stable)")
@printf("  %-9s %12s %12s %12s %12s\n", "c1_ratio",
    "polar,ddi", "polar,c_dd=0", "FM,ddi", "FM,c_dd=0")
for r in RATIOS
    ip = eu_interaction_params(r)
    g(sp, cdd) = safe(() -> lhy_mean_field_max_growth(;
        F, spinor=sp, n0=N_PEAK, interactions=ip, zeeman=ZEE0, c_dd=cdd))
    @printf("  %-9.3f %12.4g %12.4g %12.4g %12.4g\n", r,
        g(polar_spinor(), EU_c_dd), g(polar_spinor(), 0.0),
        g(fm_spinor(), EU_c_dd), g(fm_spinor(), 0.0))
end

println("\n[3] ε_LHY at n = n_peak — closed forms vs full_bdg (per unit volume, N=1)")
@printf("  %-9s %11s %11s %11s %11s %11s %11s\n", "c1_ratio",
    "polar_cont", "fm_cont", "fm_dipol", "icosa", "bdg(polar)", "bdg(FM)")
for r in RATIOS
    ip = eu_interaction_params(r)
    gd = c_to_g(F, ip)
    g2F = get(gd, 2F, 0.0)
    eps_dd_fm = abs(g2F) > 1e-12 ? abs(EU_c_dd) * F^2 / (3 * abs(g2F)) : 0.0
    pc = safe(() -> lhy_energy_polar(N_PEAK, F, gd))
    fc = safe(() -> lhy_energy_fm(N_PEAK, build_fm_lhy_coefs(F, gd)))
    fd = safe(() -> lhy_energy_fm_dipolar(N_PEAK, build_fm_lhy_coefs(F, gd), eps_dd_fm))
    ic = safe(() -> epsilon_LHY_F6_Ih(N_PEAK, gd))
    bp = safe(() -> first(_lhy_bdg_energy_and_growth(polar_spinor(), N_PEAK, F, ip,
        ZEE0, EU_c_dd, nothing, nothing, nothing; rtol=1e-4)))
    bf = safe(() -> first(_lhy_bdg_energy_and_growth(fm_spinor(), N_PEAK, F, ip,
        ZEE0, EU_c_dd, nothing, nothing, nothing; rtol=1e-4)))
    @printf("  %-9.3f %11.4g %11.4g %11.4g %11.4g %11.4g %11.4g\n",
        r, pc, fc, fd, ic, bp, bf)
end

# ---------------------------------------------------------------------------
# 4. The quantity a first-order phase boundary actually feels: the DIFFERENCE
#    of ε_LHY between the two competing states, against the mean-field energy
#    difference per unit density. If Δε_LHY vanishes where ΔE_mf does, the
#    boundary is protected at leading order.
# ---------------------------------------------------------------------------
println("\n[4] Δε_LHY = ε(FM) − ε(polar) at n = n_peak, each in its OWN valid closed form")
@printf("  %-9s %13s %13s %13s\n", "c1_ratio", "ε_FM(dipolar)", "ε_polar", "Δε/ε_FM")
for r in RATIOS
    ip = eu_interaction_params(r)
    gd = c_to_g(F, ip)
    g2F = get(gd, 2F, 0.0)
    eps_dd_fm = abs(g2F) > 1e-12 ? abs(EU_c_dd) * F^2 / (3 * abs(g2F)) : 0.0
    fd = safe(() -> lhy_energy_fm_dipolar(N_PEAK, build_fm_lhy_coefs(F, gd), eps_dd_fm))
    pc = safe(() -> lhy_energy_polar(N_PEAK, F, gd))
    @printf("  %-9.3f %13.5g %13.5g %13.4g\n", r, fd, pc, (fd - pc) / fd)
end

# ---------------------------------------------------------------------------
# 5. Where the instability lives: which k and which branch. Contact vs DDI.
# ---------------------------------------------------------------------------
println("\n[5] growth vs c_dd at the campaign point c1_ratio = 0.028 (FM and polar)")
let ip = eu_interaction_params(0.028)
    @printf("  %-14s %14s %14s\n", "c_dd/c_dd_Eu", "polar", "FM")
    for f in (0.0, 0.1, 0.25, 0.5, 1.0, 2.0)
        gp = safe(() -> lhy_mean_field_max_growth(; F, spinor=polar_spinor(), n0=N_PEAK,
            interactions=ip, zeeman=ZEE0, c_dd=f * EU_c_dd))
        gf = safe(() -> lhy_mean_field_max_growth(; F, spinor=fm_spinor(), n0=N_PEAK,
            interactions=ip, zeeman=ZEE0, c_dd=f * EU_c_dd))
        @printf("  %-14.2f %14.5g %14.5g\n", f, gp, gf)
    end
end

println("\ndone.")
