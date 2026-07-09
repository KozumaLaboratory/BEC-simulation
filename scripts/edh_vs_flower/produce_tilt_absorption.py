"""Poster/paper-level absorption images: quantization axis tilted (R=exp(-i b F_a)),
then y-axis (line-of-sight) absorption imaging = column density INT dy |[R psi]_m|^2
for a single m channel, in the (x,z) plane. Minimal: pixels + axes + English axis
labels only (no title, no colorbar, no annotation). One PNG per (phase, m).
env: PSI13, GOTO, T_MS, AXIS, BETA_DEG, M_LIST, OUT_PREFIX, A_HO_UM, CMAP"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"font.size":18,"font.family":"DejaVu Sans","axes.linewidth":1.2,
                     "xtick.major.size":6,"ytick.major.size":6,"xtick.direction":"out","ytick.direction":"out"})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; T_MS=float(os.environ.get("T_MS","188"))
AXIS=os.environ.get("AXIS","y"); BETA=float(os.environ.get("BETA_DEG","16"))
M_LIST=[int(x) for x in os.environ.get("M_LIST","-6,-5").split(",")]
OUTP=os.environ.get("OUT_PREFIX","edh_tilt"); AHO=float(os.environ.get("A_HO_UM","0.78")); CMAP=os.environ.get("CMAP","viridis")

with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]
R=rot(AXIS,BETA); psip=np.einsum("mn,xyzn->xyzm",R,psi)     # tilted spinor
Ng=psi.shape[0]; half=L/2*AHO; ext=[-half,half,-half,half]  # (x,z) in micrometers
for m in M_LIST:
    im3=int(np.where(ms==m)[0][0])
    col=(np.abs(psip[...,im3])**2).sum(axis=1)               # INT dy -> (x,z) absorption image
    fig,ax=plt.subplots(figsize=(4.4,4.4))
    ax.imshow(col.T,origin="lower",extent=ext,cmap=CMAP,aspect="equal")
    ax.set_xlabel("x (µm)"); ax.set_ylabel("z (µm)")
    ax.set_xticks([-8,-4,0,4,8]); ax.set_yticks([-8,-4,0,4,8])
    fig.tight_layout()
    fn=f"{OUTP}_m{m}.png"; fig.savefig(fn,dpi=300,bbox_inches="tight"); plt.close(fig)
    print(f"wrote {fn}  (t={tms[k]:.0f}ms, R_{AXIS}({BETA:.0f}deg), sum={col.sum():.3g})")
