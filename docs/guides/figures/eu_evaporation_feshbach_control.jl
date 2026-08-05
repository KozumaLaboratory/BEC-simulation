# EXPLORATORY (does not overwrite any existing result): can Feshbach tuning of the
# s-wave scattering length a_s during evaporation increase the BEC number? (issue #75)
#
# Physics: three-body loss ∝ a_s⁴ and the elastic (evaporation) rate ∝ a_s². Near BEC the
# gas is dense so 3-body (∝a⁴) dominates → lowering a_s there (via the 1.3 G Feshbach
# resonance the thesis observed) should cut the loss that destroys the dense BEC. We model
# a two-stage a_s schedule (a_s = 135 a_B early → a_low after t_switch) by CHAINING the
# two-component model across the switch (state (N,T) carried over; K₃ = K₃_ref·(a_s/135)⁴).
# Caveat: a_s(B) for Eu is unmeasured — this is a parametric PREDICTION, not a calibrated result.

using SpinorBEC
using Printf
const BOHR=5.29177210903e-11
const OUT=length(ARGS)>=1 ? ARGS[1] : "fesh_out"; mkpath(OUT)
alpha=5.88e-37; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
const AS0=135.0; const K3REF=1e-41    # central a_s [a_B] and K₃ at that a_s
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
cf(r)=r.N0_final/max(r.N[end],1)
# base ramp = the K3=1e-41 operating point (fast evaporation)
bt=[0.000,0.096,0.284,0.537,0.844,1.199,1.597,1.899,2.220]
bH=[10.0,10.0,5.1685,4.5331,3.2624,2.2357,1.5006,0.4715,0.0200]
bV=[6.0,0.2751,0.2751,0.2751,0.2751,0.2751,0.2751,0.2751,0.0500]
full=FortRamp(bt, permutedims(hcat(bH,bV,zeros(9))))
tend=bt[end]

# a FortRamp covering [ta,tb] (absolute times), with breakpoints of `full` inside + endpoints
function sub_ramp(ta,tb)
    inside=[t for t in bt if ta<t<tb]
    times=vcat(ta,inside,tb)
    pw=hcat([fort_power_at(full,Float64(t)) for t in times]...)
    FortRamp(times, pw)
end
pars(a_s_aB)=EvapParams(; a_s=a_s_aB*BOHR, tau_bg=15.0,
    K3=K3REF*(a_s_aB/AS0)^4, heating_rate=0.05)   # K₃ ∝ a_s⁴

# run with a two-stage a_s schedule: a_s=AS0 on [0,tsw], a_s=alow on [tsw,tend]
function run_2stage(alow, tsw)
    r1=run_evaporation_bec(trap, sub_ramp(0.0,tsw), pars(AS0); N0=N0, T0=T0)
    N1=r1.N[end]; T1=r1.T[end]
    r2=run_evaporation_bec(trap, sub_ramp(tsw,tend), pars(alow); N0=N1, T0=T1)
    r2
end

# baseline: constant a_s=135 over the whole ramp (chained the same way, tsw=tend → no switch)
rbase=run_evaporation_bec(trap, full, pars(AS0); N0=N0, T0=T0)
@printf("baseline (a_s=135, K3=1e-41): N0=%.3e T=%.0fnK cf=%.3f\n",rbase.N0_final,rbase.T_final*1e9,cf(rbase))

# 2-D scan: final-stage a_s (a_low) × switch time
alows=collect(range(135.0,30.0;length=22))      # lower a_s in the final stage
tsws =collect(range(0.3,2.15;length=20))         # when to switch (s)
open(joinpath(OUT,"feshbach.csv"),"w") do io
    println(io,"alow,tsw,N0,T,cf")
    for a in alows, ts in tsws
        r=run_2stage(a,ts)
        @printf(io,"%.1f,%.3f,%.5e,%.3f,%.4f\n",a,ts,r.N0_final,r.T_final*1e9,cf(r))
    end
end
# best over the scan (pure BEC only)
best=(-1.0,0.0,0.0,0.0)
for a in alows, ts in tsws
    r=run_2stage(a,ts); cf(r)>=0.90 && r.N0_final>best[1] && (global best=(r.N0_final,a,ts,r.T_final*1e9))
end
@printf("BEST 2-stage: N0=%.3e (a_low=%.0f a_B, switch=%.2fs, T=%.0fnK) — vs baseline %.3e (%.1fx)\n",
    best[1],best[2],best[3],best[4],rbase.N0_final,best[1]/rbase.N0_final)
open(joinpath(OUT,"summary.txt"),"w") do io
    @printf(io,"Feshbach a_s-control (EXPLORATORY; a_s(B) unmeasured). K3=K3ref*(a_s/135)^4.\n")
    @printf(io,"baseline a_s=135: N0=%.3e @ %.0fnK\n",rbase.N0_final,rbase.T_final*1e9)
    @printf(io,"best 2-stage    : N0=%.3e @ %.0fnK  (a_low=%.0f a_B, switch t=%.2fs) = %.2fx baseline\n",
        best[1],best[4],best[2],best[3],best[1]/rbase.N0_final)
end
println(read(joinpath(OUT,"summary.txt"),String))
