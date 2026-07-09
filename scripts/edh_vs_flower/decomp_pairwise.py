#!/usr/bin/env python3
"""Pairwise interference decomposition of the ROTATED m=-6 density.

New m=-6 channel after R=exp(-i β F_a):  ψ'_{-6} = Σ_a c_a,  c_a = R_{-6,a} ψ_a.
  full        = |ψ'_{-6}|² = Σ_a|c_a|²  +  Σ_{a<b} 2Re(c_a c_b*)
  incoherent  = Σ_a |c_a|²
  I_{ab}      = 2 Re(c_a c_b*)          <- interference of old-a with old-b
Ranks pairs by ∫|I_ab|dV and renders the dominant ones (esp. old m=-6 × m=-5)
as ±isosurfaces (red=constructive, blue=destructive) so each pair's share of
the m=-6 dent is visible. Full 3D, no line-of-sight ∫dy.
env: PSI13, GOTO, T_MS, AXIS, BETA_DEG, ISO_FRAC, N_PAIRS, OLD_MS, OUT
"""
import os, sys
import numpy as np
import h5py
HERE=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13
from isoviz import marching_tetrahedra, _coords, setup_font
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
T_MS=float(os.environ.get("T_MS","148")); AXIS=os.environ.get("AXIS","y")
BETA=float(os.environ.get("BETA_DEG","16")); ISO=float(os.environ.get("ISO_FRAC","0.05"))
NP=int(os.environ.get("N_PAIRS","3")); OUT=os.environ.get("OUT","decomp_pair_m6.png")
OLD=tuple(int(x) for x in os.environ.get("OLD_MS","-6,-5,-4,-3,-2").split(","))
setup_font("ja")

with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()])
    meta={k:np.asarray(G["meta"][k]).item() for k in G["meta"]}
t_ms=t/om*1000.0; k=int(np.argmin(np.abs(t_ms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]
R=rot(AXIS,BETA); i6=int(np.where(ms==-6)[0][0])
c={a: R[i6, int(np.where(ms==a)[0][0])]*psi[..., int(np.where(ms==a)[0][0])] for a in OLD}
psip=sum(c.values()); full=np.abs(psip)**2
incoh=sum(np.abs(v)**2 for v in c.values())
Lb=float(meta["L_box"]); NX=int(meta["NX"]); vs=int(meta.get("vol_stride",1))
dV=(Lb/NX*vs)**3; coords=_coords(full.shape,Lb,NX,vs); gpk=full.max(); lv=ISO*gpk
Nf=full.sum()*dV
pairs=[]
for ia,a in enumerate(OLD):
    for b in OLD[ia+1:]:
        I=2*np.real(c[a]*np.conj(c[b]))
        pairs.append(((a,b), I, np.abs(I).sum()*dV/Nf))
pairs.sort(key=lambda p:-p[2])
print(f"[pair] t={t_ms[k]:.1f}ms R_{AXIS}({BETA})  N'_-6={Nf:.4g}  pair |I|/full :")
for (a,b),_,fr in pairs: print(f"   ({a:+d},{b:+d}): {100*fr:5.1f}%")

def surf(ax, field, color, lev_):
    tris,_=marching_tetrahedra(field, np.zeros_like(field), coords, lev_)
    if tris: ax.add_collection3d(Poly3DCollection(tris,facecolors=color,edgecolors="none",alpha=0.9))
def setup(ax, title):
    for s in (ax.set_xlim,ax.set_ylim,ax.set_zlim): s(-Lb/2,Lb/2)
    ax.set_box_aspect((1,1,1)); ax.view_init(elev=22,azim=232)
    ax.set_xlabel("x",labelpad=1); ax.set_ylabel("y",labelpad=1); ax.set_zlabel("z",labelpad=1)
    ax.tick_params(labelsize=7,pad=0); ax.set_title(title,fontsize=11,pad=3)

ncol=2+min(NP,len(pairs))
fig=plt.figure(figsize=(4.6*ncol,6.2),facecolor="white")
gs=GridSpec(1,ncol,figure=fig,left=0.02,right=0.98,bottom=0.10,top=0.80,wspace=0.04)
surf(fig.add_subplot(gs[0,0],projection="3d") or plt.gca(),full,"#2ca6a4",lv)
a0=fig.axes[-1]; setup(a0,"full |ψ'(m=-6)|²\n（実際に見えているもの）")
a1=fig.add_subplot(gs[0,1],projection="3d"); surf(a1,incoh,"#2ca6a4",lv)
setup(a1,"非可干渉 Σ|c_a|²\n（干渉なし＝滑らか）")
for j,((a,b),I,fr) in enumerate(pairs[:NP]):
    ax=fig.add_subplot(gs[0,2+j],projection="3d")
    surf(ax,I,"#d1495b",lv); surf(ax,-I,"#3a6ea5",lv)
    setup(ax,f"干渉 (旧m={a} × 旧m={b})\n|I|/full={100*fr:.0f}%  赤=強め 青=弱め")
fig.suptitle(
    f"回転後 m=-6 の干渉をペア分解 — EdH(par_T90) を t={t_ms[k]:.0f} ms で R_{AXIS}({BETA:.0f}°) 傾けた後\n"
    f"c_a = R(-6,a)·ψ_a,  I(a,b)=2Re(c_a c_b*)   等値面 {ISO:.0%}×fullピーク   （フル3D・視線積分なし）",
    fontsize=12,y=0.97)
fig.text(0.02,0.02,"旧m=-6(塊)×旧m=-5(渦リング)のペア干渉が m=-6 のへこみの主因かを確認できる（青=弱め合い=へこみ）。",
         fontsize=9,color="0.35")
os.makedirs(os.path.dirname(os.path.abspath(OUT)) or ".",exist_ok=True)
fig.savefig(OUT,dpi=140); plt.close(fig); print(f"[pair] wrote {OUT}")
