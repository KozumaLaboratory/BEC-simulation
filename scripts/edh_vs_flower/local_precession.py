"""LOCAL precession (the essence): the spin vector S(r0,t) at FIXED positions r0,
tracked over time. Larmor: transverse (Fx,Fy) rotates around the local field.
Plots theta(t)=atan2(Fy,Fx) and the (Fx,Fy) hodograph at a few r0, plus |B_ext|.
env: PSI13, GOTO, A_HO_UM, OUT, LABEL"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; AHO=float(os.environ.get("A_HO_UM","0.78"))
OUT=os.environ.get("OUT","local_precession.png"); LABEL=os.environ.get("LABEL","EdH")
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
Ng=load_frames_bulk(P,[0])[0].shape[0]; ax=np.linspace(-L/2,L/2,Ng)
def gi(um): return int(np.argmin(np.abs(ax*AHO-um)))
zc=gi(0.0)
# fixed positions r0 (on z~0 plane): radius ~2.5um in 3 azimuths + one at +z
R=2.5
pts=[("(+x, y=0, z=0)",gi(R),gi(0.0),zc),("(x=0, +y, z=0)",gi(0.0),gi(R),zc),
     ("(+x, +y, z=0)",gi(R/np.sqrt(2)),gi(R/np.sqrt(2)),zc),("(+x, y=0, +z)",gi(R),gi(0.0),gi(2.0))]
Fx=np.zeros((len(pts),nf)); Fy=Fx.copy(); Fz=Fx.copy()
CH=40
for a in range(0,nf,CH):
    fr=list(range(a,min(a+CH,nf))); ps=load_frames_bulk(P,fr)
    for j,k in enumerate(fr):
        psi=ps[j]; n=np.sum(np.abs(psi)**2,-1)
        sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
        fx3,fy3,fz3=sd(FX),sd(FY),sd(FZ)
        for pi,(_,ix,iy,iz) in enumerate(pts):
            nn=max(n[ix,iy,iz],1e-30); Fx[pi,k]=fx3[ix,iy,iz]/nn; Fy[pi,k]=fy3[ix,iy,iz]/nn; Fz[pi,k]=fz3[ix,iy,iz]/nn
    print(f"[loc] {min(a+CH,nf)}/{nf}")
fig,axs=plt.subplots(1,3,figsize=(15,4.4),constrained_layout=True)
cols=plt.cm.viridis(np.linspace(0,0.85,len(pts)))
for pi,(lab,_,_,_) in enumerate(pts):
    th=np.degrees(np.unwrap(np.arctan2(Fy[pi],Fx[pi])))
    perp=np.hypot(Fx[pi],Fy[pi]); good=perp>0.15*perp.max()
    axs[0].plot(tms[good],th[good]-th[good][0],color=cols[pi],label=lab)
    axs[1].plot(Fx[pi],Fy[pi],color=cols[pi],label=lab); axs[1].plot(Fx[pi][good][-1],Fy[pi][good][-1],"o",color=cols[pi])
    axs[2].plot(tms,perp,color=cols[pi],label=lab)
axs[0].set_xlabel("t [ms]"); axs[0].set_ylabel("local transverse angle θ(t)−θ₀ [deg]"); axs[0].set_title(f"{LABEL}: LOCAL spin precession θ(r0,t)"); axs[0].legend(fontsize=8); axs[0].grid(alpha=0.25)
axs[1].set_xlabel("Fx / atom"); axs[1].set_ylabel("Fy / atom"); axs[1].set_title("transverse hodograph (Fx,Fy)(t)"); axs[1].set_aspect("equal"); axs[1].grid(alpha=0.25); axs[1].axhline(0,color="0.8",lw=0.6); axs[1].axvline(0,color="0.8",lw=0.6)
axs[2].set_xlabel("t [ms]"); axs[2].set_ylabel("|f_perp| / atom"); axs[2].set_title("local transverse magnitude"); axs[2].legend(fontsize=8); axs[2].grid(alpha=0.25)
fig.savefig(OUT,dpi=150,bbox_inches="tight"); plt.close(fig)
# console: local precession rate at each point over its good window
print(f"=== {LABEL} 局所歳差レート (θの回転) ===")
for pi,(lab,_,_,_) in enumerate(pts):
    th=np.degrees(np.unwrap(np.arctan2(Fy[pi],Fx[pi]))); perp=np.hypot(Fx[pi],Fy[pi]); g=np.where(perp>0.15*perp.max())[0]
    if len(g)>2:
        rate=(th[g[-1]]-th[g[0]])/(tms[g[-1]]-tms[g[0]])
        print(f"  {lab}: dθ/dt={rate:+.1f} deg/ms = {rate/360*1000:+.0f} Hz  (窓 {tms[g[0]]:.0f}-{tms[g[-1]]:.0f}ms, |f⊥|max={perp.max():.2f})")
print("wrote",OUT)
