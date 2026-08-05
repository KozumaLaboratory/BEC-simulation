# Type-C validation: does the calibrated model reproduce the thesis's MEASURED
# BEC-transition data (Miyazawa 2021, Fig 7.2)?  We run the thesis evaporation ramp and
# sweep the final hODT power (as the thesis did — "different final hODT power"), giving a
# model (N_total, T) curve; the measured points should fall on it. Done for K₃=1e-42 and
# 1e-41 to show which matches (issue #75).

using SpinorBEC
using Printf
const BOHR=5.29177210903e-11
const OUT=length(ARGS)>=1 ? ARGS[1] : "val_out"; mkpath(OUT)
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
# thesis ramp; the thesis imaged at "different final hODT power" = stopping the ramp at
# different points. We TRUNCATE the ramp at end-time t_end (warm=early → cold=late).
tt=[0.0,1.0,2.0,3.0,4.0,5.0,6.0,6.7,7.4]
Hb=[10.0,5.0,3.0,2.0,1.2,0.7,0.35,0.18,0.10]; Vb=[0.15,1.2,2.5,3.5,4.5,5.5,6.0,3.0,1.30]
full=FortRamp(tt,permutedims(hcat(Hb,Vb,zeros(9))))
function truncate_ramp(tend)
    ks=findall(<=(tend),tt); k=isempty(ks) ? 1 : ks[end]
    times=vcat(tt[1:k],tend); pw=full.powers_W[:,1:k]
    pend=fort_power_at(full,Float64(tend))
    FortRamp(times, hcat(pw, reshape(pend,3,1)))
end
cf(r)=r.N0_final/max(r.N[end],1)

tends=range(2.2,7.4;length=60)                            # stop the ramp early (warm) → late (cold)
open(joinpath(OUT,"validation.csv"),"w") do io
    println(io,"K3,tend,N_total,T,N0,cf")
    for K3 in (1e-42,1e-41)
        p=EvapParams(; a_s=a_s, tau_bg=15.0, K3=K3, heating_rate=0.05)
        for te in tends
            r=run_evaporation_bec(trap,truncate_ramp(te),p; N0=N0,T0=T0)
            @printf(io,"%.1e,%.3f,%.5e,%.3f,%.5e,%.4f\n",K3,te,r.N[end],r.T_final*1e9,r.N0_final,cf(r))
        end
    end
end
# measured thesis points (Fig 7.2): (T nK, N_total)
println("measured (Fig 7.2): (470nK, 2.2e4) thermal, (270nK, 1.1e4) bimodal, pure BEC 3e3")
println("wrote validation.csv")
