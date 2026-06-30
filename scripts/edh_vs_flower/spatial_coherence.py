#!/usr/bin/env python3
"""Spatially-resolved coherence ρ_mn(r)=ψ_m ψ_n*/n (xy at z=peak). The LOCAL coherence
is nonzero with azimuthal phase winding (=vortex charge |Δm|); its global integral
∫ρ_mn dr cancels → that's why whole-cloud ρ̄ is diagonal. env: SPIN3D, OUT, FRAME"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SPIN3D"]; OUT=os.environ.get("OUT","spatial.png"); FR=int(os.environ.get("FRAME","100"))
f=h5py.File(S,"r"); L=float(f["meta/L_box"][()])
def psi(mk,ak): n=np.transpose(np.asarray(f[mk]),(2,1,0,3))[...,FR]; a=np.transpose(np.asarray(f[ak]),(2,1,0,3))[...,FR]; return np.sqrt(np.clip(n,0,None))*np.exp(1j*a)
p6=psi("n_m6_3d","arg_psi_m6_3d"); p5=psi("n_m5_3d","arg_psi_m5_3d"); p4=psi("n_m4_3d","arg_psi_m4_3d")
ntot=np.transpose(np.asarray(f["n_total_3d"]),(2,1,0,3))[...,FR]
Ng=p6.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
zp=int(np.argmax(p5.sum(axis=(0,1))))   # z where m=-5 peaks
def coh(pa,pb):
    c=pa[:,:,zp]*np.conj(pb[:,:,zp])/np.clip(ntot[:,:,zp],1e-12,None); return c
pairs=[("-6,-5",p6,p5,1),("-5,-4",p5,p4,1),("-6,-4",p6,p4,2)]
fig,ax=plt.subplots(3,2,figsize=(9,12.5),constrained_layout=True)
for r,(lab,pa,pb,dm) in enumerate(pairs):
    c=coh(pa,pb); amp=np.abs(c); ph=np.ma.array(np.angle(c),mask=amp<0.05*amp.max())
    glob=np.abs(np.sum(pa[:,:,zp]*np.conj(pb[:,:,zp])))   # global (this slice) coherence after cancellation
    locsum=np.sum(np.abs(pa[:,:,zp])*np.abs(pb[:,:,zp]))
    im0=ax[r,0].imshow(amp.T,origin="lower",extent=ext,cmap="magma",aspect="equal")
    im1=ax[r,1].imshow(ph.T,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal")
    ax[r,0].set_ylabel(f"ρ[{lab}]",fontsize=12,fontweight="bold")
    ax[r,0].set_title(r"$|\rho_{mn}(r)|$  (local coherence)",fontsize=10)
    ax[r,1].set_title(rf"$\arg\rho_{{mn}}(r)$  → winds $2\pi\times{dm}$ (vortex charge {dm})",fontsize=10)
    fig.colorbar(im0,ax=ax[r,0],shrink=0.8); fig.colorbar(im1,ax=ax[r,1],shrink=0.8,ticks=[-np.pi,0,np.pi])
    ax[r,0].text(0.02,0.02,f"|∫ρ dr|/∫|..|={glob/locsum:.3f}\n(global cancels)",transform=ax[r,0].transAxes,color="cyan",fontsize=8,va="bottom")
    for cc in range(2): ax[r,cc].set_xticks([]); ax[r,cc].set_yticks([])
fig.suptitle(f"Spatially-resolved coherence ρ_mn(r) at z=+peak (z={ax1d[zp]:+.1f}μm)\nLOCAL coherence nonzero + winds {{|Δm|}}×2π → global integral cancels (whole-cloud ρ̄ diagonal)",fontsize=12)
fig.savefig(OUT,dpi=120); print(f"wrote {OUT}  zp={zp}")
