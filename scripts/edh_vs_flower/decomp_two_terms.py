"""Split the new m=-6 channel into its m=-6-derived and m=-5-derived squared
terms plus their interference:
   ψ'_{-6} ⊃ c_{-6} + c_{-5},  c_a = R_{-6,a} ψ_a
   |c_{-6}|²   (m=-6-derived squared)
   |c_{-5}|²   (m=-5-derived squared)
   2Re(c_{-6} c_{-5}*)   (interference)
Shared ABSOLUTE iso level chosen to reveal the small m=-5 term; each panel is
annotated with peak (× full peak) and population so the true magnitudes stay
explicit. env: PSI13, GOTO, T_MS, AXIS, BETA_DEG, ISO_FRAC, OUT
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
BETA=float(os.environ.get("BETA_DEG","16"))
ISO=float(os.environ.get("ISO_FRAC","0.30"))          # fraction of the m=-5 term peak
OUT=os.environ.get("OUT","decomp_two_m6.png")
setup_font("ja")

with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()])
    meta={k:np.asarray(G["meta"][k]).item() for k in G["meta"]}
t_ms=t/om*1000.0; k=int(np.argmin(np.abs(t_ms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]
R=rot(AXIS,BETA); i6=int(np.where(ms==-6)[0][0])
def c(a):
    ia=int(np.where(ms==a)[0][0]); return R[i6,ia]*psi[...,ia]
c6=c(-6); c5=c(-5)
d6=np.abs(c6)**2; d5=np.abs(c5)**2; I=2*np.real(c6*np.conj(c5))
full=np.abs(np.einsum("n,xyzn->xyz", R[i6,:], psi))**2      # true full ψ'_-6
Lb=float(meta["L_box"]); NX=int(meta["NX"]); vs=int(meta.get("vol_stride",1))
dV=(Lb/NX*vs)**3; coords=_coords(full.shape,Lb,NX,vs)
fpk=full.max(); Nf=full.sum()*dV
lv=ISO*d5.max()                                            # shared absolute level (reveals m=-5)
print(f"[two] t={t_ms[k]:.1f}ms R_{AXIS}({BETA})  iso={lv:.3e} (={ISO:.0%} of |c-5|^2 peak, "
      f"= {lv/fpk:.3f} x full peak)")
for lab,d in [("|c-6|^2",d6),("|c-5|^2",d5)]:
    print(f"   {lab}: peak/full={d.max()/fpk:.3f}  pop={100*d.sum()*dV/Nf:.1f}%")
print(f"   interference |I|/full = {100*np.abs(I).sum()*dV/Nf:.1f}%  peak+={I.max()/fpk:+.2f} peak-={I.min()/fpk:+.2f} (x full peak)")

def surf(ax, field, color):
    tris,_=marching_tetrahedra(field, np.zeros_like(field), coords, lv)
    if tris: ax.add_collection3d(Poly3DCollection(tris,facecolors=color,edgecolors="none",alpha=0.9))
def setup(ax, title):
    for s in (ax.set_xlim,ax.set_ylim,ax.set_zlim): s(-Lb/2,Lb/2)
    ax.set_box_aspect((1,1,1)); ax.view_init(elev=22,azim=232)
    ax.set_xlabel("x",labelpad=1); ax.set_ylabel("y",labelpad=1); ax.set_zlabel("z",labelpad=1)
    ax.tick_params(labelsize=7,pad=0); ax.set_title(title,fontsize=11,pad=3)

fig=plt.figure(figsize=(4.7*4,6.2),facecolor="white")
gs=GridSpec(1,4,figure=fig,left=0.02,right=0.98,bottom=0.10,top=0.80,wspace=0.04)
ax=fig.add_subplot(gs[0,0],projection="3d"); surf(ax,full,"#7a7a7a")
setup(ax,f"full |ψ'(m=-6)|²\n占有 {100*Nf/Nf:.0f}% (=基準)")
ax=fig.add_subplot(gs[0,1],projection="3d"); surf(ax,d6,"#2ca6a4")
setup(ax,f"m=-6 由来の二乗 |c(-6)|²\nピーク比 {d6.max()/fpk:.2f}  占有 {100*d6.sum()*dV/Nf:.0f}%")
ax=fig.add_subplot(gs[0,2],projection="3d"); surf(ax,d5,"#e08e0b")
setup(ax,f"m=-5 由来の二乗 |c(-5)|²\nピーク比 {d5.max()/fpk:.3f}  占有 {100*d5.sum()*dV/Nf:.0f}%")
ax=fig.add_subplot(gs[0,3],projection="3d"); surf(ax,I,"#d1495b"); surf(ax,-I,"#3a6ea5")
setup(ax,f"干渉 2Re(c(-6)c(-5)*)\n|I|/full {100*np.abs(I).sum()*dV/Nf:.0f}%  赤=強め 青=弱め")
fig.suptitle(
    f"新 m=-6 チャンネルの内訳 — EdH(par_T90) を t={t_ms[k]:.0f} ms で R_{AXIS}({BETA:.0f}°) 傾けた後\n"
    f"|c(-6)+c(-5)|² = |c(-6)|² + |c(-5)|² + 2Re(c(-6)c(-5)*)   "
    f"等値面 = {ISO:.0%} × |c(-5)|²ピーク（小さい m=-5 を見せるため; |c(-6)|²は約25倍大きく飽和表示）",
    fontsize=12,y=0.97)
fig.text(0.02,0.02,"m=-5由来は小さい(ピーク比~0.04)が渦リング構造を持ち、それが m=-6塊と干渉して右端の赤青双極子=へこみを作る。",
         fontsize=9,color="0.35")
os.makedirs(os.path.dirname(os.path.abspath(OUT)) or ".",exist_ok=True)
fig.savefig(OUT,dpi=140); plt.close(fig); print(f"[two] wrote {OUT}")
