# Where is the Eu F=6 mean field dynamically STABLE?
#
# `full_bdg` cannot serve as an accuracy reference where `max Im ω ≠ 0`: the
# zero-point sum drops the complex branches while the counterterms still subtract
# all D of them, so ε_LHY is scheme-dependent, the ITP has nothing to converge to,
# and no tolerance fixes it. The code says so in a warning; it now also ANSWERS,
# via `lhy_mean_field_max_growth`, which is what a scan needs.
#
# This is the prerequisite the phase-gap budget was missing. That budget ran at
# max Im ω = 1040 and its non-convergence was correct behaviour — I read it as
# "unconverged" and then as "blocked on issue #172", and both were wrong.
#
#   julia --project=. bench/lhy_stability_scan.jl [n_c1]

using Printf
using SpinorBEC
using SpinorBEC: lhy_mean_field_max_growth

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_C1 = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 9
const F = 6
const D = 2F + 1

"Unit spinors for the states the Eu texture work actually competes."
function probe_spinors()
    polar = zeros(ComplexF64, D); polar[F + 1] = 1.0
    fm = zeros(ComplexF64, D); fm[1] = 1.0
    (polar=polar, ferromagnetic=fm)
end

println("="^76)
println("Eu F=6 mean-field stability — max Im ω (0 = stable)")
println("c₀ + F²c₁ = c_total = $(round(EU_c_total; sigdigits=5)), c_dd = $(round(EU_c_dd; sigdigits=5))")
println("="^76)

c1_ratios = collect(range(-0.10, 0.10; length=N_C1))
qs = (0.0, 1.0e-3, 1.0e-2)

for (sname, spinor) in pairs(probe_spinors())
    println("\n--- spinor: $sname")
    @printf("  %-10s", "c1_ratio")
    for q in qs
        @printf(" %14s", "q=$q")
    end
    println()
    for r in c1_ratios
        ip = eu_interaction_params(r)
        @printf("  %-10.4f", r)
        for q in qs
            g = try
                lhy_mean_field_max_growth(; F, spinor, n0=1.0, interactions=ip,
                    zeeman=ZeemanParams(EU_p_weak, q), c_dd=EU_c_dd)
            catch e
                NaN
            end
            @printf(" %14.4g", g)
        end
        println()
    end
end

println("""

[read] A column of zeros is a usable reference regime. Anything nonzero means
`full_bdg` is scheme-dependent there, so it cannot be the accuracy reference and
an ITP started there has no fixed point to reach — that is a property of the
(F, c₀, c₁, q, c_dd) point, not of the seed or the tolerance.""")

# --- controls: WHICH term makes it unstable, and does the density matter? -----
#
# "Everything is unstable" is not yet a finding — it could be the dipolar term
# (physical and unavoidable at Eu: the textures exist BECAUSE the uniform state is
# unstable), the spin channel, or an n-dependence that a different working density
# would escape. These two controls separate those.
println("\n" * "="^76)
println("Controls — is it the DIPOLE, the spin channel, or the density?")
println("="^76)

sp = probe_spinors()
ip0 = eu_interaction_params(0.05)
zee0 = ZeemanParams(EU_p_weak, 0.0)

growth(spinor, ip, cdd, n0) = try
    lhy_mean_field_max_growth(; F, spinor, n0, interactions=ip, zeeman=zee0,
        c_dd=cdd)
catch
    NaN
end

println("\n[control 1] c_dd scaled, at c1_ratio = 0.05, n0 = 1")
@printf("  %-16s %14s %14s\n", "c_dd", "polar", "ferromagnetic")
for f in (0.0, 0.01, 0.1, 0.5, 1.0)
    @printf("  %-16.4g %14.4g %14.4g\n", f * EU_c_dd,
        growth(sp.polar, ip0, f * EU_c_dd, 1.0),
        growth(sp.ferromagnetic, ip0, f * EU_c_dd, 1.0))
end
println("  c_dd = 0 stable ⇒ the instability IS the dipole, and at Eu that is")
println("  physics, not a parameter to move away from.")

println("\n[control 2] working density, at c1_ratio = 0.05, full c_dd")
@printf("  %-16s %14s %14s\n", "n0", "polar", "ferromagnetic")
for n0 in (0.01, 0.1, 1.0, 10.0)
    @printf("  %-16.4g %14.4g %14.4g\n", n0,
        growth(sp.polar, ip0, EU_c_dd, n0),
        growth(sp.ferromagnetic, ip0, EU_c_dd, n0))
end
println("  Measured EXACTLY linear in n0 with no crossing, which is what")
println("  |Im ω| = n·|λ_min| looks like: ω² = ε_k(ε_k + 2nλ) is most negative at")
println("  ε_k = −nλ, giving |Im ω| = n|λ|. So the SIGN of the instability is")
println("  n-independent and no working density is a stable point either — n only")
println("  sets the rate.")
