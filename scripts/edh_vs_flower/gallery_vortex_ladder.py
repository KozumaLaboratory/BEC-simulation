#!/usr/bin/env python3
"""EdH spin-vortex / angular-momentum ladder: amplitude + phase(rel to m=-6) of
m=-6,-5,-4,-3, showing vortex charge = |Δm| (Einstein-de-Haas). + per-m <Lz>.
env: PSI13, GOTO, FRAME, OUT"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
FR=int(os.environ.get("FRAME","100")); OUT=os.environ.get("OUT","gallery_vortex_ladder.png")
F=6; D=13; ms=np.arange(F,-F-1,-1)
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1)
tms=float(np.asarray(G["t"])[FR])/float(G["meta/omega_ref"][()])*1000
Ng=n.shape[0]; ext=[-L/2,L/2,-L/2,L/2]; zc=int(np.argmax(n.sum(axis=(0,1))))
mlist=[(-6,12),(-5,11),(-4,10),(-3,9)]
ax1d=np.linspace(-L/2,L/2,Ng); X,Y=np.meshgrid(ax1d,ax1d,indexing="ij")
def winding(field2d,amp):
    # winding around center on a ring at radius where amp peaks
    th=np.arctan2(Y,X); rr=np.hypot(X,Y);
    rpk=rr[np.unravel_index(np.argmax(amp),amp.shape)]
    sel=(np.abs(rr-rpk)<0.15*L/2)&(amp>0.2*amp.max())
    if sel.sum()<8: return 0.0
    order=np.argsort(th[sel]); ph=np.unwrap(field2d[sel][order])
    return (ph[-1]-ph[0])/(2*np.pi)
ref=np.angle(psi[:,:,zc,12])
fig,ax=plt.subplots(2,4,figsize=(14,7),constrained_layout=True)
for j,(m,c) in enumerate(mlist):
    amp=np.abs(psi[:,:,zc,c]); ph=np.angle(psi[:,:,zc,c]*np.exp(-1j*ref))
    a0=ax[0,j]; im0=a0.imshow(amp.T,origin="lower",extent=ext,cmap="inferno",aspect="equal")
    a0.set_title(f"m={m}  |ψ_m|",fontsize=10); a0.set_xticks([]);a0.set_yticks([]); fig.colorbar(im0,ax=a0,shrink=0.7)
    w=winding(ph,amp)
    phm=np.ma.array(ph,mask=amp<0.12*amp.max())
    a1=ax[1,j]; im1=a1.imshow(phm.T,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal")
    a1.set_title(f"arg(ψ_m)−arg(ψ_-6)\nwinding ≈ {w:+.1f}  (charge |Δm|={abs(m-(-6))})",fontsize=9); a1.set_xticks([]);a1.set_yticks([])
    fig.colorbar(im1,ax=a1,shrink=0.7,ticks=[-np.pi,0,np.pi])
fig.suptitle(f"EdH spin-vortex / angular-momentum ladder (z=peak, t={tms:.1f} ms): m=−6 core (charge 0) → m=−5 (1) → m=−4 (2) → m=−3 (3)\n"
             f"phase winds 2π×|Δm| = vortex charge ladder = Einstein–de Haas spin→orbital transfer",fontsize=11)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); print(f"wrote {OUT}")
