#!/usr/bin/env python3
"""CORRECT per-m cross-sections from FULL 64^3 slices.jld2 (native Julia order).
h5py reads Julia (nf,nx,ny,D) as (D,ny,nx,nf): n_xy[c,:,:,fr]=(y,x) XY(z=0);
n_xz[c,:,:,fr]=(z,x) XZ(y=0). NO subsample, NO axis confusion.
env: SLICES, OUT_PNG, FRAME (frame index), LABEL, MS (time label optional)"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SLICES"]; OUT=os.environ.get("OUT_PNG","per_m2.png")
FR=int(os.environ.get("FRAME","70")); LAB=os.environ.get("LABEL","EdH"); MS=os.environ.get("MS","")
L=18.0
f=h5py.File(S,"r"); mch=f["m_channels"][()]
nxy=np.asarray(f["n_xy"]); nxz=np.asarray(f["n_xz"])      # (D,ny,nx,nf),(D,nz,nx,nf)
axy=np.asarray(f["arg_xy"]); axz=np.asarray(f["arg_xz"])
ext=[-L/2,L/2,-L/2,L/2]
mlist=[-6,-5,-4,-3]
fig,ax=plt.subplots(len(mlist),4,figsize=(15,3.4*len(mlist)),constrained_layout=True)
for r,m in enumerate(mlist):
    c=int(np.where(mch==m)[0][0])
    nxy_c=nxy[c,:,:,FR]; nxz_c=nxz[c,:,:,FR]; axy_c=axy[c,:,:,FR]; axz_c=axz[c,:,:,FR]
    vmax=max(nxy_c.max(),nxz_c.max())+1e-30
    im0=ax[r,0].imshow(nxy_c,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vmax,aspect="equal")
    im1=ax[r,1].imshow(nxz_c,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vmax,aspect="equal")
    mxy=np.ma.array(axy_c,mask=nxy_c<0.05*vmax); mxz=np.ma.array(axz_c,mask=nxz_c<0.05*vmax)
    ax[r,2].imshow(mxy,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal")
    ax[r,3].imshow(mxz,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal")
    ax[r,0].set_ylabel(f"m = {m}",fontsize=13,fontweight="bold")
    fig.colorbar(im0,ax=ax[r,0],shrink=0.8); fig.colorbar(im1,ax=ax[r,1],shrink=0.8)
    for cc in range(4): ax[r,cc].set_xticks([]); ax[r,cc].set_yticks([])
ax[0,0].set_title(r"$|\psi_m|^2$  XY (z=0)"); ax[0,1].set_title(r"$|\psi_m|^2$  XZ (y=0)")
ax[0,2].set_title(r"$\arg\psi_m$  XY"); ax[0,3].set_title(r"$\arg\psi_m$  XZ")
fig.suptitle(f"{LAB} — per-m cross-sections (FULL 64³, correct axes)  frame {FR} {MS}",fontsize=13)
fig.savefig(OUT,dpi=120); print(f"wrote {OUT}")
PYEOF=0
