using SpinorBEC, DelimitedFiles
using SpinorBEC: euv3_evap_trap, EvapParams, run_evaporation, FortRamp, Units, trap_at
kB=Units.KB; aB=5.29177e-11; α=5.88e-37
hold=FortRamp([0.0,10.0],[7.0 7.0;0.0 0.0;0.0 0.0])
p=EvapParams(; a_s=110*aB, tau_bg=36.0, K3=0.0, evap_scale=1.0)
M=zeros(0,5)
for wμm in 20.0:2.0:56.0
  tr=euv3_evap_trap(; alpha=α, waists=[wμm*1e-6,42e-6,42e-6], gravity_factor=1.0)
  r=run_evaporation(tr, hold, p; N0=3.5e6, T0=18e-6, dt=0.004, save_every=40)
  i8=findfirst(>=(8.0), r.eta); t8=i8===nothing ? 10.0 : r.t[i8]
  global M=vcat(M, [wμm r.eta[1] t8 r.N[end]/3.5e6 r.eta[end]])
end
writedlm("/tmp/waistscan.csv", M, Char(44)); println("wrote")
