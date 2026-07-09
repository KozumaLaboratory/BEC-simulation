#!/usr/bin/env python3
"""Close the loop: the tilted-SG column images ARE the input; reconstruct the
spin texture from them.  INPUT (left) = m-resolved SG absorption images n_m(x,y)
for the 3 tilt settings (no tilt / R_y(-90) / R_x(+90)).  OUTPUT (right) = the
column-averaged spin texture <F>(x,y) built ONLY from those images via the
centroid identity <F_a>=Sum_m m*N_m^{set}(x,y)/N(x,y), validated vs the
column-averaged truth.  env: PSI13, GOTO, OUT, FRAME"""
import os, numpy as np, h5py
from _floor import mask_from  # FPE_DENSITY_FLOOR (default 0 = full grid)
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
OUT=os.environ.get("OUT","sg_recon.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j); Fx=0.5*(Fp+Fp.T)
Ry=expm(+1j*(np.pi/2)*Fy); Rx=expm(-1j*(np.pi/2)*Fx)   # ->Fx, ->Fy
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1)
ax1d=np.linspace(-L/2,L/2,psi.shape[0]); ext=[-L/2,L/2,-L/2,L/2]
tms=float(np.asarray(G["t"])[FR])/float(G["meta/omega_ref"][()])*1000; Bz=float(np.asarray(G["B_gauss"])[FR])
col=lambda a:a.sum(axis=2)
# ----- INPUT: tilted-SG column images N_m^{set}(x,y) -----
def sg_col(R):
    rp=np.einsum("mn,xyzn->xyzm",R,psi); return col(np.abs(rp)**2)   # (x,y,13) column densities
SETS=[("no tilt",np.eye(D),"⟨Fz⟩"),("R_y(−90°)",Ry,"⟨Fx⟩"),("R_x(+90°)",Rx,"⟨Fy⟩")]
Nset=[sg_col(R) for _,R,_ in SETS]                                  # 3 x (x,y,13)
Ncol=col(np.sum(np.abs(psi)**2,axis=-1)); mcol=mask_from(Ncol)
# ----- OUTPUT: column-averaged spin texture from the images -----
def centroid(Nm): return np.einsum("xym,m->xy",Nm,ms.astype(float))
fz_r=centroid(Nset[0]); fx_r=centroid(Nset[1]); fy_r=centroid(Nset[2])
# truth (column-averaged)
def truth(k): return col(np.transpose(np.asarray(G[f"{k}_3d"]),(2,1,0,3))[...,FR])
fz_t,fx_t,fy_t=truth("Fz"),truth("Fx"),truth("Fy")
err=max(np.abs(fz_r-fz_t).max(),np.abs(fx_r-fx_t).max(),np.abs(fy_r-fy_t).max())
def pa(f): nn=np.clip(Ncol,1e-12,None); return np.where(mcol,f/nn,np.nan)
# ============ FIGURE ============
fig=plt.figure(figsize=(15.5,7.4)); gs=fig.add_gridspec(3,7,width_ratios=[1,1,1,0.25,1.25,1.25,1.25],hspace=0.12,wspace=0.12)
mshow=[(-6,12),(-5,11),(-4,10)]
for i,(m,c) in enumerate(mshow):
    for j,(lab,R,obs) in enumerate(SETS):
        a=fig.add_subplot(gs[i,j]); img=Nset[j][...,c]; vm=img.max() or 1
        a.imshow(img.T/vm,origin="lower",extent=ext,cmap="inferno",vmin=0,vmax=1,aspect="equal")
        a.set_xticks([]);a.set_yticks([])
        if i==0: a.set_title(f"{lab}\n→{obs}",fontsize=9)
        if j==0: a.set_ylabel(f"m={m}",fontsize=11,fontweight="bold")
fig.text(0.055,0.965,"INPUT: tilted-SG column images  n_m(x,y)",fontsize=11,fontweight="bold")
st=max(1,psi.shape[0]//15); xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); sub=(slice(None,None,st),)*2
def tex(ax,fxx,fyy,fzz,title):
    Sz=pa(fzz); Sx=pa(fxx); Sy=pa(fyy); mg=np.hypot(Sx,Sy)
    im=ax.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    U=np.where(mg>1e-6,Sx/mg,np.nan); V=np.where(mg>1e-6,Sy/mg,np.nan)
    ax.quiver(xx[sub],yy[sub],U[sub],V[sub],mg[sub],cmap="Greys",clim=(0,6),scale=24,width=0.007,headwidth=4,pivot="mid")
    ax.set_title(title,fontsize=10); ax.set_xticks([]);ax.set_yticks([]); return im
axR=fig.add_subplot(gs[0:2,4]); im=tex(axR,fx_r,fy_r,fz_r,"RECONSTRUCTED ⟨F⟩(x,y)\n(column-avg, from the images)")
axT=fig.add_subplot(gs[0:2,5]); tex(axT,fx_t,fy_t,fz_t,"TRUTH (column-avg ∫dz)")
axE=fig.add_subplot(gs[0:2,6])
em=np.where(mcol,np.sqrt((fx_r-fx_t)**2+(fy_r-fy_t)**2+(fz_r-fz_t)**2),np.nan)
ime=axE.imshow(em.T,origin="lower",extent=ext,cmap="magma",aspect="equal"); axE.set_xticks([]);axE.set_yticks([])
axE.set_title(f"|error|  max={err:.1e}",fontsize=10); fig.colorbar(ime,ax=axE,shrink=0.7)
cb=fig.colorbar(im,ax=[axR,axT],shrink=0.6,location="bottom",pad=0.04); cb.set_label("⟨Fz⟩ (per atom, col-avg); arrows=⟨Fx,Fy⟩ dir",fontsize=9)
axtxt=fig.add_subplot(gs[2,4:7]); axtxt.axis("off")
axtxt.text(0.0,0.9,
  "Reconstruction uses ONLY the SG images on the left:\n"
  "  ⟨F_a⟩(x,y) = Σ_m m · n_m^{set}(x,y) / Σ_m n_m  (centroid of the SG ladder).\n"
  "  no tilt→⟨Fz⟩,  R_y(−90°)→⟨Fx⟩,  R_x(+90°)→⟨Fy⟩.   Exact for the column-averaged texture\n"
  f"  (max error {err:.1e}).  z-dependent structure needs multi-angle / light-sheet imaging.",
  transform=axtxt.transAxes,va="top",fontsize=9.5,family="monospace")
fig.suptitle(f"Spin texture reconstructed FROM the tilted-SG images — EdH ¹⁵¹Eu, t={tms:.1f} ms, B={Bz*1e3:.3f} mG",fontsize=12.5)
fig.savefig(OUT,dpi=130,bbox_inches="tight"); print(f"wrote {OUT}  err={err:.2e}")
