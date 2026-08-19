# Does the campaign's ACTUAL magnetic field remove the LHY instability?
#
# `docs/validation/full_bdg_scheme_dependence_eu_f6.md` dismisses the field as
# an escape route with a table reading "50 µG ⇒ p = −7.40e-05, q = 3.23e-16".
# Those numbers are wrong by 1e4 and 1e8 respectively: `linear_zeeman_p` takes
# TESLA, the campaign YAML writes `4.4e-5 Gauss` = 4.4e-9 T, and `cli.jl inspect`
# on that config resolves p = −0.651, q = +2.50e-08. So the escape route was
# closed on a field 10⁴ times weaker than the one the campaign runs at.
#
# That matters because a linear Zeeman term is not a spectator in the uniform
# BdG problem: it enters the branch energies as `diag(z) − μ`, which gaps every
# component away from the condensed one. Whether that gap beats the dipolar
# spin-channel instability is a measurement, and this is it.
#
#   julia --project=. bench/lhy_growth_vs_field.jl [c1_ratio]

using Printf
using SpinorBEC
using SpinorBEC: lhy_mean_field_max_growth, _lhy_bdg_energy_and_growth, c_to_g,
    compute_quadratic_zeeman

include(joinpath(@__DIR__, "eu151_params.jl"))

const C1_RATIO = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 1 / 36
const F = 6
const D = 2F + 1
const N_PEAK = 3.7e-3

polar_spinor() = (z = zeros(ComplexF64, D); z[F + 1] = 1.0; z)
fm_spinor() = (z = zeros(ComplexF64, D); z[1] = 1.0; z)          # m = +F
fm_minus_spinor() = (z = zeros(ComplexF64, D); z[D] = 1.0; z)    # m = −F

# Fields in µG. The campaign's boundary bracket at κ=1 is 42–46 µG
# (runs/eu_gs_phase_c1_B_kappa/config_boundary_64.yaml); the texture B-scan runs
# 50–80 µG.
const B_UG = (0.0, 1.0, 5.0, 10.0, 20.0, 44.0, 50.0, 60.0, 80.0, 100.0,
    # Extended 2026-08-19 after the corrected BdG (`7e6770c2`) showed the m = −F
    # branch reaching EXACTLY zero growth somewhere between 100 and 500 µG. The
    # pre-fix code had it unstable at every field, and that is what the
    # "the field is not an escape route" reading rested on. Locating the
    # threshold is the whole point of the extension, so the grid is dense there.
    125.0, 150.0, 175.0, 200.0, 225.0, 250.0, 300.0, 400.0, 500.0, 1000.0)

zee_at(B_ug) = begin
    B_T = B_ug * 1e-10                 # µG → Gauss (1e-6) → Tesla (1e-4)
    p = linear_zeeman_p(Eu151, B_T, EU_ω_ref)
    q = compute_quadratic_zeeman(Eu151; p_dimless=p, omega_ref=EU_ω_ref)
    ZeemanParams(p, q)
end

ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F)

println("="^100)
println("Eu-151 F=6 — max Im ω of the uniform mean field vs the REAL field.  ",
    "c1_ratio = ", round(C1_RATIO; sigdigits=6), ", n = ", N_PEAK)
println("="^100)
@printf("\n  %8s %11s %11s %13s %13s %13s\n",
    "B (µG)", "p", "q", "FM m=+F", "FM m=−F", "polar m=0")
for b in B_UG
    z = zee_at(b)
    g(sp) = try
        lhy_mean_field_max_growth(; F, spinor=sp, n0=N_PEAK, interactions=ip,
            zeeman=z, c_dd=EU_c_dd)
    catch e
        NaN
    end
    @printf("  %8.1f %11.4g %11.4g %13.5g %13.5g %13.5g\n",
        b, z.p, z.q, g(fm_spinor()), g(fm_minus_spinor()), g(polar_spinor()))
    flush(stdout)
end

println("\n[control] the same table with the DDI switched off — every entry must be 0,")
println("which is what says the growth above is dipolar and not an artefact of the probe.")
@printf("\n  %8s %13s %13s %13s\n", "B (µG)", "FM m=+F", "FM m=−F", "polar m=0")
for b in (0.0, 44.0, 100.0)
    z = zee_at(b)
    g(sp) = try
        lhy_mean_field_max_growth(; F, spinor=sp, n0=N_PEAK, interactions=ip,
            zeeman=z, c_dd=0.0)
    catch
        NaN
    end
    @printf("  %8.1f %13.5g %13.5g %13.5g\n",
        b, g(fm_spinor()), g(fm_minus_spinor()), g(polar_spinor()))
end

println("\n[ε_LHY] at the campaign field, where the growth is zero the value is a")
println("well-defined number rather than a scheme choice.")
@printf("\n  %8s %15s %15s %15s\n", "B (µG)", "ε(FM +F)", "ε(FM −F)", "ε(polar)")
for b in (0.0, 44.0, 60.0, 100.0)
    z = zee_at(b)
    e(sp) = try
        first(_lhy_bdg_energy_and_growth(sp, N_PEAK, F, ip, z, EU_c_dd,
            nothing, nothing, nothing; rtol=1e-4)) / EU_N_atoms
    catch
        NaN
    end
    @printf("  %8.1f %15.6g %15.6g %15.6g\n",
        b, e(fm_spinor()), e(fm_minus_spinor()), e(polar_spinor()))
    flush(stdout)
end

println("\ndone.")
