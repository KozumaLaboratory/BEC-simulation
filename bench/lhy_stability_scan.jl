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
