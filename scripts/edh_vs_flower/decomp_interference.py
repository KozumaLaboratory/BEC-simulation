#!/usr/bin/env python3
"""Decompose the ROTATED m=-6 density into incoherent + interference parts.

After R=exp(-i β F_a):  ψ'_{-6} = Σ_{m'} R_{-6,m'} ψ_{m'}  (coherent mix).
  full        = |ψ'_{-6}|²
  incoherent  = Σ_{m'} |R_{-6,m'}|² |ψ_{m'}|²      (NO cross terms)
  interference= full − incoherent = 2 Σ_{m'<m''} Re(R R* ψ ψ*)   (signed)
Renders full / incoherent / interference(±) isosurfaces side by side so the
m=-6 dent can be attributed to interference. (Full 3D, no line-of-sight ∫dy.)

env: PSI13, GOTO, T_MS, AXIS, BETA_DEG, ISO_FRAC, OUT
"""
import os, sys
import numpy as np
import h5py
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "v7_fable")); sys.path.insert(0, HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import isoviz
from isoviz import marching_tetrahedra, _coords, setup_font
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
T_MS=float(os.environ.get("T_MS","148")); AXIS=os.environ.get("AXIS","y")
BETA=float(os.environ.get("BETA_DEG","16")); ISO_FRAC=float(os.environ.get("ISO_FRAC","0.05"))
OUT=os.environ.get("OUT","decomp_m6.png")
setup_font("ja")

with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()])
    meta={k:np.asarray(G["meta"][k]).item() for k in G["meta"]}
t_ms=t/om*1000.0; k=int(np.argmin(np.abs(t_ms-T_MS)))
P=open_psi13(PSI13); psi=load_frames_bulk(P,[k])[0]           # (x,y,z,13)
R=rot(AXIS,BETA); i6=int(np.where(ms==-6)[0][0])
row=R[i6,:]
psip6=np.einsum("n,xyzn->xyz", row, psi)                       # ψ'_{-6}
full=np.abs(psip6)**2
incoh=np.einsum("n,xyzn->xyz", np.abs(row)**2, np.abs(psi)**2)
interf=full-incoh                                              # signed

Lb=float(meta["L_box"]); NX=int(meta["NX"]); vs=int(meta.get("vol_stride",1))
dV=(Lb/NX*vs)**3; coords=_coords(full.shape,Lb,NX,vs)
Nf=full.sum()*dV; Ni=incoh.sum()*dV; Iint=interf.sum()*dV
frac_abs=100*np.abs(interf).sum()*dV/Nf
gpk=full.max(); iso=ISO_FRAC*gpk; iso_i=ISO_FRAC*gpk
print(f"[decomp] t={t_ms[k]:.1f}ms R_{AXIS}({BETA})  N'_-6={Nf:.4g} incoh={Ni:.4g} "
      f"interf_int={Iint:+.3g} | |interf|/full={frac_abs:.1f}%  "
      f"max+={interf.max()/gpk:+.2f} max-={interf.min()/gpk:+.2f} (x full peak)")

def surf(ax, field, iso_lv, color):
    tris,_=marching_tetrahedra(field, np.zeros_like(field), coords, iso_lv)
    if tris:
        ax.add_collection3d(Poly3DCollection(tris, facecolors=color,
                            edgecolors="none", alpha=0.9))
def setup(ax, title):
    for s in (ax.set_xlim,ax.set_ylim,ax.set_zlim): s(-Lb/2,Lb/2)
    ax.set_box_aspect((1,1,1)); ax.view_init(elev=22,azim=232)
    ax.set_xlabel("x [ℓ₀]",labelpad=2); ax.set_ylabel("y [ℓ₀]",labelpad=2)
    ax.set_zlabel("z [ℓ₀]",labelpad=2); ax.tick_params(labelsize=8,pad=0)
    ax.set_title(title, fontsize=12, pad=4)

fig=plt.figure(figsize=(17,6.4), facecolor="white")
gs=GridSpec(1,3,figure=fig,left=0.02,right=0.98,bottom=0.10,top=0.80,wspace=0.05)
a0=fig.add_subplot(gs[0,0],projection="3d"); surf(a0,full,iso,"#2ca6a4")
setup(a0,f"full  |ψ'₋₆|²\n(実際に見えているもの・占有 {100*Nf/ (full.sum()*dV):.0f}%相当)")
a1=fig.add_subplot(gs[0,1],projection="3d"); surf(a1,incoh,iso,"#2ca6a4")
setup(a1,"非可干渉部  Σ|R|²|ψₘ|²\n(干渉を消した場合＝滑らかな重ね合わせ)")
a2=fig.add_subplot(gs[0,2],projection="3d")
surf(a2,interf,iso_i,"#d1495b"); surf(a2,-interf,iso_i,"#3a6ea5")
setup(a2,"干渉部  full − 非可干渉\n赤=強め合い / 青=弱め合い(へこみ)")
fig.suptitle(
    f"回転後 m=−6 密度の干渉分解 — EdH(par_T90) を t={t_ms[k]:.0f} ms で $R_{AXIS}$({BETA:.0f}°) 傾けた後\n"
    f"等値面レベル = {ISO_FRAC:.0%} × full ピーク    "
    f"干渉が動かす密度 ∫|干渉|dV / ∫full dV = {frac_abs:.0f}%    "
    f"（フル3D・視線積分なし; ℓ₀=a_ho≈0.78µm）", fontsize=13, y=0.97)
fig.text(0.02,0.02,"full と 非可干渉 の形の差＝干渉の効果。右パネルの青(弱め合い)が m=−6 のへこみを作る。",
         fontsize=9, color="0.35")
os.makedirs(os.path.dirname(os.path.abspath(OUT)) or ".", exist_ok=True)
fig.savefig(OUT, dpi=140); plt.close(fig)
print(f"[decomp] wrote {OUT}")
