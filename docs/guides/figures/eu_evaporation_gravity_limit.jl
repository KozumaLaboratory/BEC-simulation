# Gravity limit on trap loosening for the ¹⁵¹Eu evaporation (issue #75). The waist-axis
# optimisation loosens ω̄ to cut three-body loss, but a FORT holds heavy Eu against gravity
# only while the trap is tight enough. This maps the REAL euv3 crossed-dipole trap depth WITH
# gravity (crossed_trap_depth includes it) vs the loosened mean frequency ω̄, and marks the
# floor where the gravity-reduced depth collapses — the hard cap on the m_ω waist axis.

using SpinorBEC
using Printf
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "grav_out"
mkpath(OUT)

alpha = 5.88e-37
wH = sqrt(26e-6 * 30e-6); wV = 47e-6
dirs = [(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)]
trap = euv3_evap_trap(; waists=[wH, wV, wV], alpha=alpha, directions=dirs)
trap_ng = euv3_evap_trap(; waists=[wH, wV, wV], alpha=alpha, directions=dirs, gravity_factor=0.0)
kB = SpinorBEC.Units.KB

# reliable branch: crossed_trap_depth is well-defined while the hODT sets the escape barrier
# (below ≈120 mW the barrier definition switches beams and the value is unphysical) — scan there.
open(joinpath(OUT, "gravity_limit.csv"), "w") do io
    println(io, "hODT_mW,wbar_Hz,U_grav_uK,U_nograv_uK")
    for P1_mW in range(500.0, 120.0; length=60)
        P = [P1_mW * 1e-3, 0.6 * P1_mW * 1e-3, 0.0]
        Ug, wg = trap_at(trap, P)
        Un, _ = trap_at(trap_ng, P)
        @printf(io, "%.3f,%.2f,%.5f,%.5f\n", P1_mW, wg / 2π, Ug / kB * 1e6, Un / kB * 1e6)
    end
end

# formation reference (ω̄≈180 Hz) and the m_ω=0.6 gravity floor (ω̄≈114 Hz)
for (lab, P1) in (("formation", 300.0), ("m_omega=0.6 floor", 120.0))
    Ug, wg = trap_at(trap, [P1 * 1e-3, 0.6 * P1 * 1e-3, 0.0])
    @printf("%-18s ω̄=%.0f Hz  U_grav/kB=%.3f µK\n", lab, wg / 2π, Ug / kB * 1e6)
end
println("CSV → ", joinpath(OUT, "gravity_limit.csv"))
