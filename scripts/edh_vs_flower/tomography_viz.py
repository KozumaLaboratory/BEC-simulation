#!/usr/bin/env python3
"""Visualize the tilt-tomography ALGORITHM on our EdH rho(t).
F=6 ops -> R_y(b)=exp(-i b Fy) -> SG occupations P_m(b)=(R rho R†)_mm.
Panels: (A) reduced rho^(4) |.|+phase, (B) tilt-scan P_m(b) (the measurement),
(C) harmonic spectrum (rank k=|Δm|), (D) leakage to m<=-2 vs b (caveat 5a).
env: RHO, DIAG, OUT, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
RHO=os.environ["RHO"]; DG=os.environ.get("DIAG",""); OUT=os.environ.get("OUT","tomo.png"); FR=int(os.environ.get("FRAME","100"))
OMEGA=691.15; F=6; D=13; ms=np.arange(F,-F-1,-1)   # +6..-6 (index 0..12)
# spin operators (basis ordered m=+6..-6)
Fz=np.diag(ms.astype(float))
Fp=np.zeros((D,D))
for i in range(D):           # |m> at index i has m=ms[i]; F+|m>=sqrt(...)|m+1> (index i-1)
    m=ms[i]
    if m< F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fm=Fp.T; Fx=0.5*(Fp+Fm); Fy=(Fp-Fm)/(2j)
f=h5py.File(RHO,"r"); rho_all=f["rho_re"][...]+1j*f["rho_im"][...]   # (13,13,nf)
rho=rho_all[:,:,FR]
if DG and os.path.exists(DG):
    d=h5py.File(DG,"r"); tms=float(np.asarray(d["t"])[min(FR,len(d["t"])-1)])/OMEGA*1000
else: tms=FR
# indices for 4-level block m=-6,-5,-4,-3 = ms indices 12,11,10,9
blk=[list(ms).index(m) for m in [-6,-5,-4,-3]]
rho4=rho[np.ix_(blk,blk)]
# tilt scan
betas=np.linspace(0,2*np.pi,361)
Pm=np.zeros((D,len(betas)))
for j,b in enumerate(betas):
    R=expm(-1j*b*Fy); rp=R@rho@R.conj().T; Pm[:,j]=np.real(np.diag(rp))
fig=plt.figure(figsize=(15,9),constrained_layout=True)
gs=fig.add_gridspec(2,3)
# (A) rho4 magnitude
axA=fig.add_subplot(gs[0,0]); im=axA.imshow(np.abs(rho4),cmap="magma",vmin=0)
axA.set_xticks(range(4)); axA.set_yticks(range(4)); axA.set_xticklabels([-6,-5,-4,-3]); axA.set_yticklabels([-6,-5,-4,-3])
for i in range(4):
    for k in range(4):
        axA.text(k,i,f"{np.abs(rho4[i,k]):.2f}",ha="center",va="center",color="cyan",fontsize=8)
axA.set_title(r"$|\rho^{(4)}_{mm'}|$ (4-level block)"); axA.set_xlabel("m'"); axA.set_ylabel("m"); fig.colorbar(im,ax=axA,shrink=0.8)
# (A2) phase
axP=fig.add_subplot(gs[0,1]); imp=axP.imshow(np.angle(rho4),cmap="twilight",vmin=-np.pi,vmax=np.pi)
axP.set_xticks(range(4)); axP.set_yticks(range(4)); axP.set_xticklabels([-6,-5,-4,-3]); axP.set_yticklabels([-6,-5,-4,-3])
axP.set_title(r"$\arg\rho^{(4)}_{mm'}$"); fig.colorbar(imp,ax=axP,shrink=0.8,ticks=[-np.pi,0,np.pi])
# (B) tilt scan P_m(beta)
axB=fig.add_subplot(gs[0,2])
for m in [-6,-5,-4,-3,-2]:
    i=list(ms).index(m); axB.plot(np.degrees(betas),Pm[i],label=f"m={m}")
axB.axvline(90,ls=":",c="gray"); axB.set_xlabel(r"tilt angle $\beta$ [deg]"); axB.set_ylabel(r"$P_m(\beta)$ (SG occ.)")
axB.set_title(r"tilt-scan $R_y(\beta)$ → SG  (the measurement)"); axB.legend(fontsize=8)
# (C) harmonic spectrum of P_{-6}(beta) and P_{-5}
axC=fig.add_subplot(gs[1,0])
bb=np.linspace(0,2*np.pi,360,endpoint=False)
for m,col in [(-6,"C0"),(-5,"C1"),(-4,"C2")]:
    i=list(ms).index(m); P=np.interp(bb,betas,Pm[i]); ck=np.abs(np.fft.rfft(P))/len(bb)
    axC.plot(np.arange(len(ck))[:14],ck[:14],"o-",color=col,label=f"m={m}")
axC.set_xlabel(r"harmonic $k$ (↔ rank-$k$, $|\Delta m|=k$)"); axC.set_ylabel("amplitude")
axC.set_title("angular harmonics ↔ multipole rank"); axC.legend(fontsize=8); axC.set_yscale("log")
# (D) leakage to m<=-2 vs beta
axD=fig.add_subplot(gs[1,1])
leak=Pm[[list(ms).index(m) for m in range(-2,7)],:].sum(axis=0)  # m=-2..+6 = outside 4-block
axD.plot(np.degrees(betas),leak,"C3"); axD.set_xlabel(r"$\beta$ [deg]"); axD.set_ylabel(r"$\sum_{m\geq-2}P_m$ (leakage)")
axD.set_title("leakage out of 4-level block (caveat 5a)"); axD.axhline(0.01,ls=":",c="gray")
# (E) <Fz>(t) over dynamics
axE=fig.add_subplot(gs[1,2])
Fzt=np.array([np.real(np.trace(rho_all[:,:,k]@Fz)) for k in range(rho_all.shape[2])])
if DG and os.path.exists(DG):
    dt=np.asarray(d["t"]); tarr=dt[np.clip(np.arange(len(Fzt)),0,len(dt)-1)]/OMEGA*1000
else: tarr=np.arange(len(Fzt))
axE.plot(tarr,Fzt,"C4"); axE.axvline(tms,ls=":",c="r"); axE.set_xlabel("t [ms]"); axE.set_ylabel(r"$\langle F_z\rangle$")
axE.set_title(r"$\langle F_z\rangle(t)$ from $\rho$ (spin→orbital)")
fig.suptitle(f"Tilt-tomography algorithm on EdH ρ̄(t)   t={tms:.1f} ms   (F=6, 4-level block m=-6..-3)",fontsize=14)
fig.savefig(OUT,dpi=120); print(f"wrote {OUT}")
