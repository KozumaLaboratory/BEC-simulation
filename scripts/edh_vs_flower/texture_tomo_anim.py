#!/usr/bin/env python3
"""Time-resolved spin-texture tomography from tilted-SG 'video'.
Each frame: forward-model 3 SG images (no tilt / R_y(-90) / R_x(+90)) from the
full spinor, reconstruct <F>(r) by the centroid identities, validate vs the true
spin density. Left=TRUE, middle=RECON, right=running max-error + <Fz>(t).
env: PSI13, GOTO, OUT(.mp4), DUR, FPS"""
import os, sys, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
sys.path.insert(0,"/Users/mitsuki/Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/scripts/flower_protocol_edh")
from _anim_writer import save_matplotlib_anim, expanded_frame_indices

PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
OUT=os.environ.get("OUT","texture_tomo_anim.mp4"); DUR=float(os.environ.get("DUR","36")); FPS=int(os.environ.get("FPS","20"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Ry=expm(+1j*(np.pi/2)*Fy); Rx=expm(-1j*(np.pi/2)*Fx)   # ->Fx, ->Fy
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
# preload (x,y,z,nf) per component (float32)
RE=[np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3)) for c in range(1,14)]
IM=[np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3)) for c in range(1,14)]
NT=np.transpose(np.asarray(P["n_total_3d"]),(2,1,0,3))
FXt=np.transpose(np.asarray(G["Fx_3d"]),(2,1,0,3)); FYt=np.transpose(np.asarray(G["Fy_3d"]),(2,1,0,3)); FZt=np.transpose(np.asarray(G["Fz_3d"]),(2,1,0,3))
tarr=np.asarray(G["t"])/float(G["meta/omega_ref"][()])*1000; Barr=np.asarray(G["B_gauss"])
NF=NT.shape[-1]; Ng=NT.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//20)

def spinor(FR): return np.stack([RE[c][...,FR]+1j*IM[c][...,FR] for c in range(13)],axis=-1)
def recon(FR):
    psi=spinor(FR); n=NT[...,FR]
    cz=np.einsum("xyzm,m->xyz",np.abs(psi)**2,ms.astype(float))
    py=np.einsum("mn,xyzn->xyzm",Ry,psi); cx=np.einsum("xyzm,m->xyz",np.abs(py)**2,ms.astype(float))
    px=np.einsum("mn,xyzn->xyzm",Rx,psi); cy=np.einsum("xyzm,m->xyz",np.abs(px)**2,ms.astype(float))
    return cx,cy,cz,n
# precompute per-frame z=peak slices (recon + truth), running error, global Fz(t)
def per_atom(fa,n,sl,m): nn=np.clip(n[:,:,sl],1e-12,None); return np.where(m,fa[:,:,sl]/nn,np.nan)
SLR=[]; SLT=[]; maxerr=np.zeros(NF); Fzg=np.zeros(NF)
for k in range(NF):
    cx,cy,cz,n=recon(k)
    maxerr[k]=max(np.abs(cx-FXt[...,k]).max(),np.abs(cy-FYt[...,k]).max(),np.abs(cz-FZt[...,k]).max())
    Fzg[k]=cz.sum()/n.sum()
    sl=int(np.argmax(n.sum(axis=(0,1)))); m=n[:,:,sl]>0.04*n[:,:,sl].max()
    SLR.append((per_atom(cx,n,sl,m),per_atom(cy,n,sl,m),per_atom(cz,n,sl,m)))
    SLT.append((per_atom(FXt[...,k],n,sl,m),per_atom(FYt[...,k],n,sl,m),per_atom(FZt[...,k],n,sl,m)))
print(f"max-over-all-frames reconstruction error = {maxerr.max():.2e}")

fig=plt.figure(figsize=(13.5,5.0)); gs=fig.add_gridspec(1,3,width_ratios=[1,1,0.85],wspace=0.28)
axT=fig.add_subplot(gs[0,0]); axR=fig.add_subplot(gs[0,1]); axE=fig.add_subplot(gs[0,2])
def draw_tex(ax,Sx,Sy,Sz,title):
    ax.clear()
    im=ax.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    ax.quiver(xx[::st,::st],yy[::st,::st],Sx[::st,::st],Sy[::st,::st],color="k",scale=22,width=0.005,pivot="mid")
    ax.set_title(title,fontsize=10); ax.set_xticks([]); ax.set_yticks([]); return im
im0=draw_tex(axT,*SLR[0],"_")
from matplotlib.cm import ScalarMappable; from matplotlib.colors import Normalize
cb=fig.colorbar(ScalarMappable(Normalize(-6,6),"RdBu_r"),ax=[axT,axR],shrink=0.8,pad=0.02); cb.set_label("⟨Fz⟩ (per atom); arrows=⟨Fx,Fy⟩")
def draw(FR):
    draw_tex(axR,*SLT[FR],"from full ψ (ground truth)")
    draw_tex(axT,*SLR[FR],"RECONSTRUCTED from 3 SG images")
    axE.clear()
    axE.semilogy(tarr[:FR+1],np.maximum(maxerr[:FR+1],1e-12),"C3",lw=1.4)
    axE.axhline(1e-6,ls=":",c="gray"); axE.set_ylim(1e-12,1e-1)
    axE.set_xlim(tarr[0],tarr[-1]); axE.set_xlabel("t [ms]"); axE.set_ylabel("max recon error",color="C3")
    axE.set_title("validation: recon vs truth",fontsize=10)
    a2=axE.twinx(); a2.plot(tarr[:FR+1],Fzg[:FR+1],"C0",lw=1.4); a2.set_ylabel("⟨Fz⟩ global",color="C0"); a2.set_ylim(-6.2,0.5)
    fig.suptitle(f"Spin-texture tomography from tilted-SG video — EdH ¹⁵¹Eu   t={tarr[FR]:.1f} ms   B={Barr[FR]*1e3:.3f} mG   recon err={maxerr[FR]:.1e}",fontsize=12)
idx=expanded_frame_indices(NF,DUR,FPS)
anim=FuncAnimation(fig,draw,frames=idx,interval=1000/FPS)
save_matplotlib_anim(anim,OUT,fps=FPS)
print(f"wrote {OUT}  ({NF} data frames, {len(idx)} video frames)")
