# Absolute-N validation vs the lab (type-C): does the 0-D two-component model reproduce the
# MEASURED ¹⁵¹Eu BEC atom number at the ACTUAL lab operating point (euv3 researched ramp +
# measured loading N=1.4e6, T₀=50 µK)? The dominant absolute-N uncertainty is the three-body
# coefficient K₃, so we sweep it and mark the direct-measured value against the thesis number.

using SpinorBEC
using Printf
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "lababs_out"
mkpath(OUT)

trap = euv3_evap_trap()
ramp = SpinorBEC.euv3_evaporation_ramp()
kB = SpinorBEC.Units.KB
cf(r) = r.N0_final / max(r.N[end], 1)

# K₃ ∈ [BEC-fit 4.6e-42 … direct 1.2e-41 … 2.6e-41], the researched Eu range (Miyazawa thesis:
# direct three-body Fig 7.5 ⇒ ~1.2e-41 atoms-lost; BEC-fit ⇒ ~4.6e-42; ~2.6× systematic).
open(joinpath(OUT, "lab_absolute.csv"), "w") do io
    println(io, "K3,N_BEC,T_nK,cf")
    for K3 in 10 .^ range(log10(3e-42), log10(4e-41); length=40)
        p = EvapParams(; a_s=135 * BOHR, tau_bg=15.0, K3=K3, heating_rate=0.05)
        r = run_evaporation_bec(trap, ramp, p; N0=1.4e6, T0=50e-6)
        @printf(io, "%.5e,%.5e,%.3f,%.4f\n", K3, r.N0_final, r.T_final * 1e9, cf(r))
    end
end
p = EvapParams(; a_s=135 * BOHR, tau_bg=15.0, K3=1.2e-41, heating_rate=0.05)
r = run_evaporation_bec(trap, ramp, p; N0=1.4e6, T0=50e-6)
@printf("direct K₃=1.2e-41: model N_BEC=%.3e  (lab thesis measured 1.5e4)\n", r.N0_final)
println("CSV → ", joinpath(OUT, "lab_absolute.csv"))
