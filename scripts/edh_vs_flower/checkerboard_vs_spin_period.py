"""Is the Goto checkerboard period HALF the spin precession period?
Vector spin <F> (rank-1, e^{i phi}) precesses with period T; the difference image
D=|[R psi]_-6|^2-... is an INTENSITY (rank-2) readout -> its quadrupole (e^{2i phi})
oscillates at 2x -> checkerboard period T/2. Measure both from par_T90 (new psi13):
  - spin transverse phase phi_spin(t) at a representative voxel  (period T_spin)
  - collective transverse <F_perp> direction (period)
  - checkerboard c_D(t) via fixed template, AND its quadrupole phase theta_cb(t)
Report periods & the T_spin / T_cb ratio.  env: KEY."""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); i6=int(np.where(ms==-6)[0][0]); B=16.0; Cp=np.abs(rot("x",B)[i6,i6])**2
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; axc=(np.arange(ng)-ng//2)*(L/ng)
def m6c(p,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,p)[...,i6])**2).sum(1)
def Dx(p): return m6c(p,rot("x",B))-Cp*m6c(p,rot("id",0))
# fields
S=np.zeros((nf,ng,ng,ng,3)); NN=np.zeros((nf,ng,ng,ng)); Dall=np.zeros((nf,ng,ng))
for k in range(nf):
    p=ps[k]; S[k,...,0]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)); S[k,...,1]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p)); S[k,...,2]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)); NN[k]=(np.abs(p)**2).sum(-1); Dall[k]=Dx(p)
# representative voxel = max time-max |f_perp|
tmax=np.sqrt(S[...,0]**2+S[...,1]**2).max(0)*(NN.max(0)>0.15*NN.max()); ix,iy,iz=np.unravel_index(np.argmax(tmax),tmax.shape)
fx=S[:,ix,iy,iz,0]; fy=S[:,ix,iy,iz,1]
phi_spin=np.unwrap(np.arctan2(fy,fx))
# collective transverse
Fxc=S[...,0].sum((1,2,3)); Fyc=S[...,1].sum((1,2,3)); phi_col=np.unwrap(np.arctan2(Fyc,Fxc))
# checkerboard: fixed template signed amp + quadrupole phase (project onto D and its 90deg-rotated self)
Tpl=Dall[-1]/(np.linalg.norm(Dall[-1])+1e-30)
cD=np.array([np.sum(Dall[k]*Tpl) for k in range(nf)])
# quadrupole phase: in the imaging (x,z) plane, fit D ~ A cos(2*(alpha - theta)); use 2D azimuth
Xg=axc[:,None]+0*axc[None,:]; Zg=0*axc[:,None]+axc[None,:]; al=np.arctan2(Zg,Xg); r=np.hypot(Xg,Zg)
c2=np.cos(2*al); s2=np.sin(2*al); w=(r>1.0)&(r<6.0)
pc=np.array([np.sum(Dall[k]*c2*w) for k in range(nf)]); psn=np.array([np.sum(Dall[k]*s2*w) for k in range(nf)])
theta_cb=0.5*np.unwrap(2*np.arctan2(psn,pc))/1.0   # quadrupole orientation (period pi in orientation)
def halfcross_period(x,tt):  # mean spacing between sign changes *2 = period
    x=x-np.mean(x); zc=np.where(np.diff(np.sign(x))!=0)[0]
    return (2*np.mean(np.diff(tt[zc]))) if len(zc)>1 else np.nan
# restrict to hold (t>=90ms) where oscillation is developed
hold=tms>=90
Tspin=halfcross_period(fy[hold],tms[hold]); Tcb=halfcross_period(cD[hold],tms[hold])
# net phase advance rates over hold
def rate(ph,tt):
    return np.rad2deg((ph[-1]-ph[0])/(tt[-1]-tt[0]))  # deg/ms
print(f"[{KEY}] representative voxel (x={axc[ix]:+.1f},y={axc[iy]:+.1f},z={axc[iz]:+.1f}) aho")
print(f"  spin transverse f_y zero-cross period (hold): {Tspin:.1f} ms")
print(f"  checkerboard c_D zero-cross period (hold):     {Tcb:.1f} ms")
print(f"  ratio T_spin/T_cb = {Tspin/Tcb:.2f}   (expect ~2 if intensity/quadrupole)")
print(f"  phase rates (deg/ms) hold: phi_spin={rate(phi_spin[hold],tms[hold]):+.2f}  phi_col={rate(phi_col[hold],tms[hold]):+.2f}  theta_cb(quad)={rate(theta_cb[hold],tms[hold]):+.2f}")
print(f"  external Larmor @26uG = 23.6 ms ; half = 11.8 ms")
# figure
fig,ax=plt.subplots(2,1,figsize=(11,8),sharex=True)
a=ax[0]; a.plot(tms,fx/np.abs(fx).max(),label="Fx (代表ボクセル)"); a.plot(tms,fy/np.abs(fy).max(),label="Fy (代表ボクセル)")
a.plot(tms,cD/np.abs(cD).max(),"k-",lw=2,label="市松符号 c_D")
a.axvline(90,color="0.5",ls="--",lw=1); a.axhline(0,color="0.85"); a.set_ylabel("規格化"); a.legend(fontsize=9,ncol=3); a.grid(alpha=.25)
a.set_title(f"{KEY}: スピン横成分 vs 市松符号  (hold: T_spin≈{Tspin:.0f}ms, T_cb≈{Tcb:.0f}ms, 比={Tspin/Tcb:.1f})")
a=ax[1]; a.plot(tms,np.rad2deg(phi_spin-phi_spin[0]),label="スピン歳差位相 φ_spin (積算)")
a.plot(tms,2*np.rad2deg(theta_cb-theta_cb[0]),"--",label="市松の 2×四重極位相 (積算)")
a.axvline(90,color="0.5",ls="--",lw=1); a.set_xlabel("時刻 t (ms)"); a.set_ylabel("積算位相 (deg)"); a.legend(fontsize=10); a.grid(alpha=.25)
a.set_title("スピン歳差位相 φ_spin と 市松四重極位相×2 が重なれば「市松は2×周波数」")
fig.tight_layout(); fig.savefig(f"checkerboard_vs_spin_{KEY}.png",dpi=120); print("wrote",f"checkerboard_vs_spin_{KEY}.png")
