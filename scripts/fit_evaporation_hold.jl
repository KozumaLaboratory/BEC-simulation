using SpinorBEC, DelimitedFiles
using SpinorBEC: evap_rhs, EvapParams, Units
const kB=Units.KB; const aB=5.29177e-11; const m=150.919857*1.66053906660e-27
function holdsim(U_uK, fbar, τ, N0, T0, tgrid)
  U=U_uK*1e-6*kB; ω̄=2π*fbar; p=EvapParams(; a_s=110*aB, tau_bg=τ, K3=0.0, evap_scale=1.0)
  N=N0; T=T0; ts=Float64[]; Ns=Float64[]; Ts=Float64[]
  dt=0.002; t=0.0; gi=1; push!(ts,0.0);push!(Ns,N);push!(Ts,T)
  while t<tgrid[end]+dt && N>1 && T>1e-9
    f(n,tt)=evap_rhs(n,tt,U,ω̄,p,m)
    k1=f(N,T);k2=f(N+dt/2*k1[1],T+dt/2*k1[2]);k3=f(N+dt/2*k2[1],T+dt/2*k2[2]);k4=f(N+dt*k3[1],T+dt*k3[2])
    N=max(N+dt/6*(k1[1]+2k2[1]+2k3[1]+k4[1]),1.0); T=max(T+dt/6*(k1[2]+2k2[2]+2k3[2]+k4[2]),1e-9); t+=dt
    if gi<=length(tgrid) && t>=tgrid[gi]; push!(ts,t);push!(Ns,N);push!(Ts,T); gi+=1; end
  end
  (ts,Ns,Ts)
end
function main()
  d=readdlm("/tmp/hold7w.csv", Char(44)); tD=Float64.(d[:,1]); TD=Float64.(d[:,2]); ND=Float64.(d[:,3])
  ok=findall(TD.>3.0); tg=tD[ok]; Tg=TD[ok]*1e-6; Ng=ND[ok]
  function chi2(U,f,τ)
    ts,Ns,Ts=holdsim(U,f,τ,ND[1],TD[1]*1e-6,tg)
    n=min(length(Ts),length(Tg))
    sum((log.(Ts[1:n]).-log.(Tg[1:n])).^2)+0.5*sum((log.(max.(Ns[1:n],1)).-log.(Ng[1:n])).^2)
  end
  best=Inf; bp=(0.,0.,0.)
  for U in 40:8:140, f in 15:12:160, τ in (15.,25.,40.,70.,120.)
    c=chi2(Float64(U),Float64(f),τ); if c<best; best=c; bp=(Float64(U),Float64(f),τ); end
  end
  U0,f0,τ0=bp
  for U in U0-6:2:U0+6, f in max(8.0,f0-10):3:f0+10, τ in (τ0*0.7,τ0*0.85,τ0,τ0*1.2,τ0*1.5)
    c=chi2(Float64(U),Float64(f),τ); if c<best; best=c; bp=(Float64(U),Float64(f),τ); end
  end
  U,f,τ=bp
  println("BEST FIT: depth=",round(U,sigdigits=3),"µK  ω̄/2π=",round(f,sigdigits=3),"Hz  τ_bg=",round(τ,sigdigits=3),"s (χ²=",round(best,sigdigits=3),")")
  println("  η_start@17.7µK=",round(U/17.7,sigdigits=3),"  η@11µK plateau=",round(U/11,sigdigits=3))
  ts,Ns,Ts=holdsim(U,f,τ,ND[1],TD[1]*1e-6,tg)
  writedlm("/tmp/fitresult.csv", hcat(ts,Ns,Ts.*1e6), Char(44))
  println("\nt     measT  modelT  measN      modelN")
  for i in 1:3:length(tg)
    j=findlast(x->x<=tg[i]+1e-9,ts)
    println(rpad(round(tg[i],digits=1),6),rpad(round(Tg[i]*1e6,sigdigits=3),7),rpad(round(Ts[j]*1e6,sigdigits=3),8),
            rpad(round(Int,Ng[i]),11),round(Int,Ns[j]))
  end
end
main()
