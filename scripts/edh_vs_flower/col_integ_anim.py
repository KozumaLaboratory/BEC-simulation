#!/usr/bin/env python3
"""Animate column-integrated per-m density (TOP ∫dz, SIDE ∫dy) over time = EdH dynamics.
slices.jld2: col_z (D,ny,nx,nf), col_y (D,nz,nx,nf). env: SLICES, DIAG, OUT, LABEL"""
import os, subprocess, tempfile
import numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SLICES"]; DG=os.environ.get("DIAG",""); OUT=os.environ.get("OUT","col_anim.mp4"); LAB=os.environ.get("LABEL","EdH")
OMEGA=691.15; L=18.0
f=h5py.File(S,"r"); mch=f["m_channels"][()]
colz=np.asarray(f["col_z"]); coly=np.asarray(f["col_y"])   # (D,a,b,nf)
nf=colz.shape[-1]; ext=[-L/2,L/2,-L/2,L/2]
mlist=[-6,-5,-4,-3]; cidx=[int(np.where(mch==m)[0][0]) for m in mlist]
# fixed per-(m,view) vmax over all frames (so growth/rings are visible at stable scale)
vz=[colz[c].max() for c in cidx]; vy=[coly[c].max() for c in cidx]
if DG and os.path.exists(DG):
    d=h5py.File(DG,"r"); dt=np.asarray(d["t"]); tms=dt[np.clip(np.arange(nf),0,len(dt)-1)]/OMEGA*1000
else: tms=np.linspace(0,40,nf)
tmp=tempfile.mkdtemp(); FPS=20; DUR=18; nout=FPS*DUR; sel=np.linspace(0,nf-1,nout).round().astype(int)
fig=plt.figure(figsize=(6.5,12))
for oi,k in enumerate(sel):
    fig.clf(); axs=fig.subplots(4,2)
    for r,(m,c) in enumerate(zip(mlist,cidx)):
        axs[r,0].imshow(colz[c,:,:,k],origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vz[r],aspect="equal")
        axs[r,1].imshow(coly[c,:,:,k],origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vy[r],aspect="equal")
        axs[r,0].set_ylabel(f"m={m}",fontsize=12,fontweight="bold")
        for cc in range(2): axs[r,cc].set_xticks([]); axs[r,cc].set_yticks([])
    axs[0,0].set_title(r"TOP $\int dz$ (xy)",fontsize=11); axs[0,1].set_title(r"SIDE $\int dy$ (xz)",fontsize=11)
    fig.suptitle(f"{LAB} column-integrated per-m   t = {tms[k]:.1f} ms",fontsize=12)
    fig.tight_layout(rect=[0,0,1,0.97])
    fig.savefig(os.path.join(tmp,f"f_{oi:05d}.png"),dpi=100)
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",os.path.join(tmp,"f_%05d.png"),
    "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2","-c:v","libx264","-pix_fmt","yuv420p","-b:v","4000k",OUT],check=True)
print("wrote",OUT)
