#!/usr/bin/env python3
"""rank-2 nematic DIRECTOR field (headless, pi-periodic) for EdH vs Flower:
in-plane director angle chi=0.5 atan2(2<Qxy>,<Qxx-Qyy>), drawn as line segments
colored by transverse nematic magnitude. Shows the quadrupolar texture.
env: EDH, FLOWER, OUT"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
EDH=os.environ.get("EDH","edh_v3_psi13.jld2"); FLW=os.environ.get("FLOWER","flower_v3_psi13.jld2"); OUT=os.environ.get("OUT","gallery_nematic_director.png")
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Qd=Fx@Fx-Fy@Fy; Qo=0.5*(Fx@Fy+Fy@Fx)
def load(fn):
    Pf=h5py.File(fn,"r"); L=float(Pf["meta/L_box"][()]); fr=np.asarray(Pf["psi_re_c01"]).shape[-1]-1
    psi=np.stack([np.transpose(np.asarray(Pf[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]+1j*np.transpose(np.asarray(Pf[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr] for c in range(1,14)],axis=-1)
    return psi,L
def director(psi,L):
    n=np.sum(np.abs(psi)**2,axis=-1); zc=int(np.argmax(n.sum(axis=(0,1))))
    sd=lambda Op: np.real(np.einsum("xym,mn,xyn->xy",np.conj(psi[:,:,zc]),Op,psi[:,:,zc]))
    nn=np.clip(n[:,:,zc],1e-12,None); m2=n[:,:,zc]>0.05*n[:,:,zc].max()
    qd=sd(Qd)/nn; qo=sd(Qo)/nn; chi=0.5*np.arctan2(2*qo,qd); mag=np.hypot(qd,2*qo)
    return chi,mag,m2,L
fig,ax=plt.subplots(1,2,figsize=(11,5.4),constrained_layout=True)
for j,(fn,nm) in enumerate([(EDH,"EdH (quench)"),(FLW,"Flower (adiabatic)")]):
    psi,L=load(fn); chi,mag,m2,L=director(psi,L); Ng=chi.shape[0]
    ax1d=np.linspace(-L/2,L/2,Ng); a=ax[j]; st=max(1,Ng//22); seglen=0.9*(ax1d[1]-ax1d[0])*st
    segs=[]; cols=[]
    vmax=np.nanmax(np.where(m2,mag,0))
    for ii in range(0,Ng,st):
        for jj in range(0,Ng,st):
            if not m2[ii,jj]: continue
            x0,y0=ax1d[ii],ax1d[jj]; c=chi[ii,jj]; dx=0.5*seglen*np.cos(c); dy=0.5*seglen*np.sin(c)
            segs.append([(x0-dx,y0-dy),(x0+dx,y0+dy)]); cols.append(mag[ii,jj])
    lc=LineCollection(segs,cmap="plasma",array=np.array(cols),linewidths=2)
    a.add_collection(lc); a.set_xlim(-L/2,L/2); a.set_ylim(-L/2,L/2); a.set_aspect("equal")
    a.set_title(f"{nm}\nrank-2 nematic director (headless), max|N⊥|={vmax:.1f}",fontsize=11); a.set_xticks([]);a.set_yticks([])
    fig.colorbar(lc,ax=a,shrink=0.8,label="|N⊥| nematic magnitude")
fig.suptitle("rank-2 nematic DIRECTOR texture: EdH (large, winding) vs Flower (small) — z=peak, final state",fontsize=12)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); print("wrote",OUT)
