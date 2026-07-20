"""Decisive test: does the checkerboard oscillate at the SAME temporal rate as the
spin precession (ratio 1:1), NOT half (2:1)?  D_x's time-dependence is rank-1 in
phi_0(t) (cos phi_0 * A + sin phi_0 * B), so a fixed pixel reverses with period T.
Compare, from existing <F>(r,t):
  phi_0(t)   = arg sum_3D n f_perp e^{-i phi_xy}         (ell=1 winding / precession phase)
  Psi_cb(t)  = arg sum_{x,z} w D_x e^{-2i beta}          (checkerboard quadrupole phase, image plane)
Plot cumulative unwrapped phases; slope ratio d(Psi_cb)/d(phi_0) over the hold.
Prediction: ~1 (same rate).  env: KEY."""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); i6=int(np.where(ms==-6)[0][0]); B=16.0; Cp=np.abs(rot("x",B)[i6,i6])**2
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; axc=(np.arange(ng)-ng//2)*(L/ng)
X=axc[:,None,None]+0*axc[None,:,None]+0*axc[None,None,:]; Y=0*X+axc[None,:,None]; Z=0*X+axc[None,None,:]
phi_xy=np.arctan2(Y,X); rho=np.hypot(X,Y)
# image-plane azimuth (x,z)
Xi=axc[:,None]+0*axc[None,:]; Zi=0*axc[:,None]+axc[None,:]; beta=np.arctan2(Zi,Xi); ri=np.hypot(Xi,Zi); wimg=((ri>1.0)&(ri<6.5)).astype(float)
def m6c(p,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,p)[...,i6])**2).sum(1)
def Dx(p): return m6c(p,rot("x",B))-Cp*m6c(p,rot("id",0))
phi0=np.zeros(nf); Cco=np.zeros(nf); Psicb=np.zeros(nf); amp_cb=np.zeros(nf)
for k in range(nf):
    p=ps[k]; fx=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)); fy=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p))
    n=(np.abs(p)**2).sum(-1); fperp=fx+1j*fy
    z0=np.sum(n*fperp*np.exp(-1j*phi_xy)); phi0[k]=np.angle(z0); Cco[k]=np.abs(z0)/(np.sum(n*np.abs(fperp))+1e-30)
    D=Dx(p); zcb=np.sum(wimg*D*np.exp(-2j*beta)); Psicb[k]=np.angle(zcb); amp_cb[k]=np.abs(zcb)
phi0u=np.unwrap(phi0); Psiu=np.unwrap(Psicb)
hold=tms>=95
# slopes over hold (deg/ms) via linear fit
def slope(ph,tt):
    A=np.polyfit(tt,np.rad2deg(ph),1); return A[0]
sp=slope(phi0u[hold],tms[hold]); scb=slope(Psiu[hold],tms[hold])
print(f"[{KEY}] hold-window slopes (deg/ms):  d phi_0/dt = {sp:+.2f}   d Psi_cb/dt = {scb:+.2f}")
print(f"  ratio d(Psi_cb)/d(phi_0) = {scb/sp:+.2f}   (prediction ~+1 => same temporal rate = 1:1)")
print(f"  winding coherence C (hold mean) = {Cco[hold].mean():.3f}  (low => phi_0 is a noisy collective proxy)")
per_phi=abs(360/sp) if sp!=0 else np.nan; per_cb=abs(360/scb) if scb!=0 else np.nan
print(f"  implied periods: T(phi_0)={per_phi:.1f} ms   T(Psi_cb)={per_cb:.1f} ms   [ext Larmor 26uG = 23.6 ms]")
fig,ax=plt.subplots(2,1,figsize=(11,8))
a=ax[0]; a.plot(tms,np.rad2deg(phi0u-phi0u[0]),lw=2,label="巻き位相 φ₀(t) 積算 (スピン歳差)")
a.plot(tms,np.rad2deg(Psiu-Psiu[0]),"--",lw=2,label="市松四重極位相 Ψ_cb(t) 積算")
a.axvline(95,color="0.5",ls=":",lw=1); a.set_ylabel("積算位相 (deg)"); a.grid(alpha=.25); a.legend(fontsize=10)
a.set_title(f"{KEY}: 傾きが一致すれば市松の時間周波数=スピン周波数 (1:1)。比 dΨ_cb/dφ₀={scb/sp:+.2f}")
a=ax[1]; a.plot(tms,Cco,color="#4a9d5b",label="巻きコヒーレンス C(t)"); a.plot(tms,amp_cb/max(amp_cb.max(),1e-9),color="#3a6ea5",label="市松四重極振幅 (規格化)")
a.axvline(95,color="0.5",ls=":",lw=1); a.set_xlabel("時刻 t (ms)"); a.set_ylabel("量"); a.grid(alpha=.25); a.legend(fontsize=10)
a.set_title("φ₀ の信頼性チェック: C が小さいと巻き位相は脱位相した集団代理量")
fig.tight_layout(); fig.savefig(f"phase_rate_test_{KEY}.png",dpi=120); print("wrote",f"phase_rate_test_{KEY}.png")
