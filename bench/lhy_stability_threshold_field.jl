# The field at which the Eu m = −F mean field becomes dynamically STABLE.
#
# `bench/lhy_growth_vs_field.jl` (post-`7e6770c2`) shows `max Im ω` for the
# m = −F spinor falling to EXACTLY zero somewhere between 100 and 125 µG. That
# matters more than a table entry: above it there are no complex Bogoliubov
# branches, so `full_bdg`'s scheme dependence — the entire subject of #337 — is
# not merely small there but **absent**, and ε_LHY is a number rather than a
# convention.
#
# It also reverses a recorded verdict. `full_bdg_scheme_dependence_eu_f6.md`
# closed the field as an escape route, and this repo believed that. It was true
# of the pre-fix BdG, whose DDI normal block was the (identically zero) Hartree
# term rather than the exchange term.
#
# m = −F, not m = +F, because `p < 0` for a g_F > 0 atom on +Bz: the Zeeman
# ground state IS m = −F, and it is what an Eu run relaxes to (measured — the
# `m_plus_F` seed lands at Mz = −5.89 in `config_smoke.yaml`). The m = +F branch
# stays unstable at every field, which is the control that this is a real gap
# opening and not the probe going blind.
#
#   julia --project=. bench/lhy_stability_threshold_field.jl [c1_ratio]

using Printf
using SpinorBEC
using SpinorBEC: lhy_mean_field_max_growth, compute_quadratic_zeeman

include(joinpath(@__DIR__, "eu151_params.jl"))

const C1_RATIO = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 1 / 36
const F = 6
const D = 2F + 1
const N_PEAK = 3.7e-3

fm_minus() = (z = zeros(ComplexF64, D); z[D] = 1.0; z)
fm_plus() = (z = zeros(ComplexF64, D); z[1] = 1.0; z)

zee_at(B_ug) = begin
    p = linear_zeeman_p(Eu151, B_ug * 1e-10, EU_ω_ref)
    ZeemanParams(p, compute_quadratic_zeeman(Eu151; p_dimless=p, omega_ref=EU_ω_ref))
end

ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F)
growth(sp, B) = lhy_mean_field_max_growth(; F, spinor=sp, n0=N_PEAK,
    interactions=ip, zeeman=zee_at(B), c_dd=EU_c_dd)

println("="^84)
println("Eu-151 F=6 — where the m = −F mean field stops being dynamically unstable.")
println("c1_ratio = ", round(C1_RATIO; sigdigits=6), ",  n = ", N_PEAK)
println("="^84)
@printf("\n  %9s %12s %14s %14s\n", "B (µG)", "p", "m = −F", "m = +F (control)")
for b in 96.0:2.0:130.0
    @printf("  %9.1f %12.4g %14.5g %14.5g\n", b, zee_at(b).p, growth(fm_minus(), b),
        growth(fm_plus(), b))
    flush(stdout)
end

# Bisect to the resolution the statement is quoted at. A threshold read off a
# grid is a grid spacing, not a threshold.
function bisect_threshold(lo, hi; iters::Int=16)
    growth(fm_minus(), lo) > 0 || error("lo is already stable — widen the bracket")
    growth(fm_minus(), hi) == 0 || error("hi is not stable — widen the bracket")
    for _ in 1:iters
        mid = (lo + hi) / 2
        growth(fm_minus(), mid) > 0 ? (lo = mid) : (hi = mid)
    end
    ((lo + hi) / 2, hi - lo)
end
let (bstar, width) = bisect_threshold(96.0, 130.0)
    @printf("\n  threshold: B* = %.3f µG  (bracketed to %.4f µG)\n", bstar, width)
    @printf("  p(B*) = %.4f,  q(B*) = %.4g\n", zee_at(bstar).p, zee_at(bstar).q)
end
println("\n  Above B*, no Bogoliubov branch of the m = −F uniform mean field is complex,")
println("  so ε_LHY there carries NO scheme dependence at all — not a small one.")
println("  The campaign's own fields are 50–80 µG, i.e. below it by under 2×.")
