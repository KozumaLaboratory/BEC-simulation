#!/usr/bin/env python3
"""2D cross-section spin texture animation (xy z=0, zx y=0) — real-time EdH dynamics.
per-particle spin s=<F>/n (clim ±F), up=red/down=blue background + in-plane real-scale arrows.
spin3d is h5py-reversed (z,y,x); transpose spatial axes to (x,y,z) first. env: SPIN3D,DIAG,OUT,LABEL"""
import os, subprocess, tempfile
import numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SPIN3D"]; DG=os.environ.get("DIAG",""); OUT=os.environ.get("OUT","spin_xsection.mp4"); LAB=os.environ.get("LABEL","EdH")
OMEGA=691.15; F=6.0
f=h5py.File(S,"r"); L=float(f["meta/L_box"][()])
def load3(k):  # h5py (z,y,x,nf) -> (x,y,z,nf)
    a=np.asarray(f[k]); return np.transpose(a,(2,1,0,3))
Fx=load3("Fx_3d"); Fy=load3("Fy_3d"); Fz=load3("Fz_3d"); n=load3("n_total_3d")
nf=Fx.shape[-1]; Ng=Fx.shape[0]; zc=yc=Ng//2
if DG and os.path.exists(DG):
    d=h5py.File(DG,"r"); dt=np.asarray(d["t"]); tms=dt[np.clip(np.arange(nf),0,len(dt)-1)]/OMEGA*1000
else: tms=np.linspace(0,40,nf)
ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]; X,Y=np.meshgrid(ax1d,ax1d,indexing="ij"); sk=2
def perpart(Fc,nn): nf2=0.05*nn.max(); safe=nn>nf2; return np.where(safe,Fc/np.where(safe,nn,1),np.nan)
tmp=tempfile.mkdtemp(); FPS=24; DUR=18; nout=FPS*DUR; sel=np.linspace(0,nf-1,nout).round().astype(int)
fig=plt.figure(figsize=(12,5.6))
for oi,k in enumerate(sel):
    fig.clf(); a0=fig.add_subplot(1,2,1); a1=fig.add_subplot(1,2,2)
    nn=n[:,:,zc,k]; sz=perpart(Fz[:,:,zc,k],nn); sx=perpart(Fx[:,:,zc,k],nn); sy=perpart(Fy[:,:,zc,k],nn)
    im=a0.imshow(sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-F,vmax=F,aspect="equal")
    a0.quiver(X[::sk,::sk],Y[::sk,::sk],sx[::sk,::sk],sy[::sk,::sk],angles="xy",scale_units="xy",scale=F/1.2,width=0.005,color="k",alpha=0.8)
    a0.set_title("XY (z=0): bg $s_z$ (↑red/↓blue), arrows $(s_x,s_y)$",fontsize=10); a0.set_xlabel("x [μm]"); a0.set_ylabel("y [μm]")
    nn2=n[:,yc,:,k]; sxz=perpart(Fx[:,yc,:,k],nn2); szz=perpart(Fz[:,yc,:,k],nn2); syz=perpart(Fy[:,yc,:,k],nn2)
    a1.imshow(syz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-F,vmax=F,aspect="equal")
    a1.quiver(X[::sk,::sk],Y[::sk,::sk],sxz[::sk,::sk],szz[::sk,::sk],angles="xy",scale_units="xy",scale=F/1.2,width=0.005,color="k",alpha=0.8)
    a1.set_title("ZX (y=0): bg $s_y$, arrows $(s_x,s_z)$",fontsize=10); a1.set_xlabel("x [μm]"); a1.set_ylabel("z [μm]")
    fig.colorbar(im,ax=[a0,a1],shrink=0.7,label=r"spin/particle ($\pm F$)")
    fig.suptitle(f"{LAB} spin-texture cross-sections   t = {tms[k]:.1f} ms",fontsize=12)
    fig.savefig(os.path.join(tmp,f"f_{oi:05d}.png"),dpi=100)
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",os.path.join(tmp,"f_%05d.png"),
    "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2","-c:v","libx264","-pix_fmt","yuv420p","-b:v","4500k",OUT],check=True)
print("wrote",OUT)
