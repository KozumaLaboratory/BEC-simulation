#!/usr/bin/env python3
"""Time-resolved spin texture, TRUTH vs ±16° RECONSTRUCTION, side by side, in a
chosen imaging plane. PLANE=xy (INT dz top view; color=<Fz>, arrows=(<Fx>,<Fy>))
or PLANE=xz (INT dy side view; color=<Fy>, arrows=(<Fx>,<Fz>)).
env: PSI13, GOTO, OUT(.mp4), DUR, FPS, TAG, PLANE"""
import os, sys, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
_here=os.path.dirname(os.path.abspath(__file__))
for _cand in [os.path.join(_here,"..","flower_protocol_edh"),
              "/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation/scripts/flower_protocol_edh",
              "/Users/mitsuki/Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/scripts/flower_protocol_edh"]:
    if os.path.exists(os.path.join(_cand,"_anim_writer.py")): sys.path.insert(0,_cand); break
from _anim_writer import save_via_png_dup
PSI=os.environ.get("PSI13","edh_v5_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v5_goto.h5")
OUT=os.environ.get("OUT","dyn.mp4"); DUR=float(os.environ.get("DUR","16")); FPS=int(os.environ.get("FPS","20"))
TAG=os.environ.get("TAG","v5"); PLANE=os.environ.get("PLANE","xy")
IAX=2 if PLANE=="xy" else 1              # integrate over z (xy) or y (xz)
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Ry=lambda b: expm(-1j*np.radians(b)*Fy); Rx=lambda b: expm(-1j*np.radians(b)*Fx)
VIS=[list(ms).index(m) for m in (-6,-5,-4,-3)]; ms_v=ms[VIS].astype(float); th=16.0; s16=np.sin(np.radians(th))
Rset={"0":np.eye(D),"y+":Ry(+th),"y-":Ry(-th),"x+":Rx(+th),"x-":Rx(-th)}
P=h5py.File(PSI,"r"); L=float(P["meta/L_box"][()]); G=h5py.File(GOTO,"r") if os.path.exists(GOTO) else None
RE=[np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3)) for c in range(1,14)]
IM=[np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3)) for c in range(1,14)]
NF=RE[0].shape[-1]; Ng=RE[0].shape[0]
tarr=(np.asarray(G["t"])/float(G["meta/omega_ref"][()])*1000) if G else np.arange(NF); Barr=(np.asarray(G["B_gauss"])) if G else np.zeros(NF)
if len(tarr)!=NF:
    tarr=np.interp(np.linspace(0,1,NF),np.linspace(0,1,len(tarr)),np.asarray(tarr,float)); Barr=np.interp(np.linspace(0,1,NF),np.linspace(0,1,len(Barr)),np.asarray(Barr,float))
ext=[-L/2,L/2,-L/2,L/2]; ax1d=np.linspace(-L/2,L/2,Ng); AA,BB=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//14)
def psi_at(fr): return np.stack([RE[c][...,fr]+1j*IM[c][...,fr] for c in range(13)],axis=-1)
def cen(psi,R):
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,VIS].sum(axis=IAX)
    return np.einsum("abm,m->ab",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
def recon(psi):
    fz=cen(psi,Rset["0"]); fx=-(cen(psi,Rset["y+"])-cen(psi,Rset["y-"]))/(2*s16); fy=+(cen(psi,Rset["x+"])-cen(psi,Rset["x-"]))/(2*s16); return fx,fy,fz
def truth(psi):
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi)); n=np.sum(np.abs(psi)**2,axis=-1); nc=n.sum(axis=IAX)
    return sd(Fx).sum(IAX)/np.clip(nc,1e-30,None), sd(Fy).sum(IAX)/np.clip(nc,1e-30,None), sd(Fz).sum(IAX)/np.clip(nc,1e-30,None), nc
# plane-specific display: in-plane arrows + out-of-plane color
if PLANE=="xy": inplane=lambda fx,fy,fz:(fx,fy); outp=lambda fx,fy,fz:fz; CMAP,CLIM,CLAB="RdBu_r",6,"⟨Fz⟩"; AX2="y"
else:            inplane=lambda fx,fy,fz:(fx,fz); outp=lambda fx,fy,fz:fy; CMAP,CLIM,CLAB="PuOr_r",3,"⟨Fy⟩"; AX2="z"
fig,ax=plt.subplots(1,2,figsize=(9.5,4.8),constrained_layout=True)
def tex(a,fx,fy,fz,mc,title):
    a.clear(); u,v=inplane(fx,fy,fz); c=outp(fx,fy,fz)
    U=np.where(mc,u,np.nan);V=np.where(mc,v,np.nan);C=np.where(mc,c,np.nan);mg=np.hypot(U,V)
    im=a.imshow(C.T,origin="lower",extent=ext,cmap=CMAP,vmin=-CLIM,vmax=CLIM,aspect="equal")
    Uu=np.where(mg>1e-6,U/np.clip(mg,1e-9,None),np.nan);Vv=np.where(mg>1e-6,V/np.clip(mg,1e-9,None),np.nan)
    a.quiver(AA[::st,::st],BB[::st,::st],Uu[::st,::st],Vv[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=22,width=0.008,pivot="mid")
    a.set_title(title,fontsize=10);a.set_xlabel("x [μm]",fontsize=8);a.set_ylabel(f"{AX2} [μm]",fontsize=8);a.tick_params(labelsize=7); return im
def draw(fr):
    psi=psi_at(fr); fxT,fyT,fzT,nc=truth(psi); fxR,fyR,fzR=recon(psi); mc=nc>0.04*nc.max()
    tex(ax[0],fxT,fyT,fzT,mc,f"TRUTH ⟨F⟩ ({PLANE})")
    tex(ax[1],fxR,fyR,fzR,mc,"reconstructed [±16°]")
    fig.suptitle(f"{PLANE} spin texture — {TAG}   t={tarr[fr]:.1f} ms  B={Barr[fr]*1e3:.3f} mG   color={CLAB} (out-of-plane)",fontsize=11)
save_via_png_dup(fig,draw,NF,OUT,fps=FPS,duration_s=DUR)
print(f"wrote {OUT} ({NF} frames, PLANE={PLANE})")
