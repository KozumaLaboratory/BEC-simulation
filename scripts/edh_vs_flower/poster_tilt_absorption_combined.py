"""Combine the 4 tilted (R_y16) y-axis absorption images into ONE figure:
 [EdH m=-6][EdH m=-5][Flower m=-6][Flower m=-5], 1x4, SHARED z-axis (left only),
 x label on every panel, no title, no colorbar. Column density INT dy |[R psi]_m|^2.
env: EDH_PSI, EDH_GOTO, EDH_TMS, FL_PSI, FL_GOTO, FL_TMS, AXIS, BETA_DEG, A_HO_UM, CMAP, OUT"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":12,"font.family":"DejaVu Sans","axes.linewidth":1.0,"xtick.labelsize":10,"ytick.labelsize":10})
AXIS=os.environ.get("AXIS","y"); BETA=float(os.environ.get("BETA_DEG","16"))
AHO=float(os.environ.get("A_HO_UM","0.78")); CMAP=os.environ.get("CMAP","viridis"); OUT=os.environ.get("OUT","poster_tilt_absorption.png")
cases=[("EDH_PSI","EDH_GOTO","EDH_TMS","140",-6),("EDH_PSI","EDH_GOTO","EDH_TMS","140",-5),
       ("FL_PSI","FL_GOTO","FL_TMS","260",-6),("FL_PSI","FL_GOTO","FL_TMS","260",-5)]
def colimg(psi,goto,tms_env,tdef,mval):
    with h5py.File(os.environ[goto],"r") as G:
        t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-float(os.environ.get(tms_env,tdef)))))
    p=load_frames_bulk(open_psi13(os.environ[psi]),[k])[0]
    R=rot(AXIS,BETA); pp=np.einsum("mn,xyzn->xyzm",R,p)
    im3=int(np.where(ms==mval)[0][0]); col=(np.abs(pp[...,im3])**2).sum(axis=1)   # INT dy
    return col, L
fig,axs=plt.subplots(1,4,figsize=(10.4,2.95),sharey=True)
fig.subplots_adjust(left=0.06,right=0.995,bottom=0.19,top=0.985,wspace=0.05)
for ax,(psi,goto,tenv,tdef,mval) in zip(axs,cases):
    col,L=colimg(psi,goto,tenv,tdef,mval); half=L/2*AHO; ext=[-half,half,-half,half]
    ax.imshow(col.T,origin="lower",extent=ext,cmap=CMAP,aspect="equal")
    ax.set_xlabel("x (µm)",labelpad=1); ax.set_xlim(-half,half); ax.set_ylim(-half,half)
    ax.xaxis.set_major_locator(MaxNLocator(4,prune="both")); ax.yaxis.set_major_locator(MaxNLocator(5))
axs[0].set_ylabel("z (µm)")
fig.savefig(OUT,dpi=300,bbox_inches="tight",pad_inches=0.03); plt.close(fig)
print("wrote",OUT," order: EdH m-6 | EdH m-5 | Flower m-6 | Flower m-5")
