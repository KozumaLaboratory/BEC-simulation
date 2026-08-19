# Which named states are FREE of the LHY texture problem, and which are not.
#
# #337 criterion D. `ε_LHY` for a single-spinor table is exact when the cloud has
# one spinor SHAPE everywhere; only |⟨F⟩|/F matters, not its direction. So the
# question "does this claim need a better LHY?" reduces to "does this state have
# a spread in p = |⟨F⟩|/F?" — which is a property of the state and costs one
# `init_psi` call to answer.
#
# `_lhy_texture_spread` is the same function `make_workspace` uses to decide
# whether to warn, so this table is the warning's own criterion applied ahead of
# time rather than a second implementation of it.
#
#   julia --project=. bench/lhy_texture_polarisation.jl

using Printf
using SpinorBEC
using SpinorBEC: _lhy_texture_spread, _LHY_TEXTURE_WARN

const F = 6
const STATES = [
    :m_plus_F, :m_minus_F, :polar, :uniform,
    :flower, :chiral_spin_vortex, :polar_core_vortex, :radial_spin_vortex,
    :axial_spin_texture, :skyrmion, :spin_helix, :cyclic, :biaxial_nematic,
    :antiferromagnetic, :magnetic_domain, :domain_wall, :vortex_lattice,
]

grid = make_grid(GridConfig((32, 32, 64), (12.0, 12.0, 24.0)))
sys = SpinSystem(F)

println("="^96)
println("|⟨F⟩|/F across the cloud for each named seed — Eu F=6, 32×32×64.")
println("spread > ", _LHY_TEXTURE_WARN, " is where make_workspace warns that a ",
    "single-spinor LHY table is off.")
println("="^96)
@printf("\n  %-22s %10s %10s %10s   %s\n",
    "state", "spread", "peak p", "mean p", "single-spinor table")
for s in STATES
    psi = try
        init_psi(grid, sys; state=s)
    catch e
        @printf("  %-22s  unavailable: %s\n", s, sprint(showerror, e))
        continue
    end
    spread, peak_f, mean_f = _lhy_texture_spread(psi, F)
    verdict = spread <= 1e-6 ? "EXACT" :
              spread <= _LHY_TEXTURE_WARN ? "ok" : "NOT ok — needs :spatial"
    @printf("  %-22s %10.4f %10.4f %10.4f   %s\n", s, spread, peak_f, mean_f, verdict)
    flush(stdout)
end

println("\nNOTE. This is the SEED, not the converged ground state. A seed with")
println("spread 0 can relax into one with spread > 0, and the campaign's converged")
println("weak-field Eu states are measured at spread ≈ 0.9. Read this as the")
println("cheapest available screen, not as the final classification.")
