"""RAW observables of our method (BEFORE any reconstruction): the tilted-SG y-axis
absorption images. 5 settings (no-tilt, R_y+-16, R_x+-16) x visible block m=-6,-5,-4,-3.
Each cell = INT dy |[R psi]_m|^2 (x,z). This is literally what the camera records.
env: PSI13, GOTO, T_MS, BETA_DEG, A_HO_UM, OUT, PERCOL(1=normalize per m-column)"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":0.9,"xtick.labelsize":8,"ytick.labelsize":8})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; T_MS=float(os.environ.get("T_MS","140"))
B=float(os.environ.get("BETA_DEG","16")); AHO=float(os.environ.get("A_HO_UM","0.78")); OUT=os.environ.get("OUT","raw_montage.png")
PERCOL=int(os.environ.get("PERCOL","1"))
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]; Ng=psi.shape[0]; half=L/2*AHO; ext=[-half,half,-half,half]
SETTINGS=[("no tilt",rot("id",0)),(f"R_y +{B:.0f}",rot("y",B)),(f"R_y -{B:.0f}",rot("y",-B)),
          (f"R_x +{B:.0f}",rot("x",B)),(f"R_x -{B:.0f}",rot("x",-B))]
MS=[-6,-5,-4,-3]; idx=[int(np.where(ms==m)[0][0]) for m in MS]
# compute all column images
img=np.zeros((len(SETTINGS),len(MS),Ng,Ng))
for si,(_,R) in enumerate(SETTINGS):
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
    for mi,ii in enumerate(idx): img[si,mi]=o[...,ii].sum(1)          # INT dy -> (x,z)
vmax=img.max(0) if PERCOL else None                                   # per-m-column shared scale
fig,axs=plt.subplots(len(SETTINGS),len(MS),figsize=(1.9*len(MS)+0.6,1.9*len(SETTINGS)+0.5))
fig.subplots_adjust(left=0.11,right=0.98,bottom=0.06,top=0.90,wspace=0.06,hspace=0.06)
for si in range(len(SETTINGS)):
    for mi in range(len(MS)):
        a=axs[si,mi]; vm=vmax[mi].max() if PERCOL else img[si,mi].max()
        a.imshow(img[si,mi].T,origin="lower",extent=ext,cmap="viridis",vmin=0,vmax=vm+1e-30,aspect="equal")
        a.set_xlim(-half,half); a.set_ylim(-half,half)
        a.xaxis.set_major_locator(MaxNLocator(3,prune="both")); a.yaxis.set_major_locator(MaxNLocator(3,prune="both"))
        if si<len(SETTINGS)-1: a.set_xticklabels([])
        if mi>0: a.set_yticklabels([])
        if si==0: a.set_title(f"m = {MS[mi]}",fontsize=12)
        if mi==0: a.set_ylabel(SETTINGS[si][0]+"\nz (µm)",fontsize=9)
        if si==len(SETTINGS)-1: a.set_xlabel("x (µm)",fontsize=9)
fig.suptitle(f"RAW tilted-SG absorption images (INT dy)  —  t={tms[k]:.0f}ms   [before any reconstruction]",fontsize=12,y=0.97)
fig.savefig(OUT,dpi=170,bbox_inches="tight"); plt.close(fig)
print("wrote",OUT," (per-m-column shared scale)" if PERCOL else " (per-cell scale)")
