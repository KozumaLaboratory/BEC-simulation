"""Identify the CAUSE of the Goto checkerboard red<->blue oscillation:
spin precession vs macroscopic orbital (L_z / mass current) change.

For par_T90 (clean EdH) and quench, over all frames compute & overlay:
  c_D(t)  : SIGNED projection of the x-tilt difference image D_x onto a fixed
            quadrupole template (its sign = red/blue; sign flips = inversion)
  <Fz>(t) : spin projection (nutation)
  phi0(t) : transverse-spin winding orientation (ℓ=+1 precession angle)
  |f_perp|: transverse spin magnitude
  <Lz>(t) : orbital angular momentum (FFT derivative)  [macroscopic/mass-current]
Then report the dominant timescale of c_D and which quantity it tracks.
Uses NEW (fixed-Hamiltonian) psi13 in resim/. env: none."""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
i6=int(np.where(ms==-6)[0][0]); B=16.0; Cp=np.abs(rot("x",B)[i6,i6])**2; mvals=ms.astype(float)
RUNS=[("par_T90","par_T90 EdH (放物線)","par_T90_goto.h5"),("quench","quench (急冷)","quench_goto.h5")]
def m6col(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
def Dx(psi): return m6col(psi,rot("x",B))-Cp*m6col(psi,rot("id",0))
def spin_fields(psi):
    fx=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),FX,psi))
    fy=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),FY,psi))
    fz=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),FZ,psi)); return fx,fy,fz
def Lz_expect(psi,box):
    ng=psi.shape[0]; ax=(np.arange(ng)-ng//2)*(box/ng)
    X=ax[:,None,None]; Y=ax[None,:,None]; k=2*np.pi*np.fft.fftfreq(ng,d=box/ng)
    KX=k[:,None,None]; KY=k[None,:,None]; N=(np.abs(psi)**2).sum(); tot=0.0
    for c in range(psi.shape[-1]):
        p=psi[...,c]
        dpx=np.fft.ifft(1j*KX*np.fft.fft(p,axis=0),axis=0)
        dpy=np.fft.ifft(1j*KY*np.fft.fft(p,axis=1),axis=1)
        Lzp=-1j*(X*dpy-Y*dpx)
        tot+=np.real(np.sum(np.conj(p)*Lzp))
    return tot/N
def phi0_azim(psi,box):  # orientation of transverse-spin ℓ=+1 winding in (x,y)
    ng=psi.shape[0]; ax=(np.arange(ng)-ng//2)*(box/ng); X=ax[:,None,None]; Y=ax[None,:,None]
    fx,fy,fz=spin_fields(psi); n=(np.abs(psi)**2).sum(-1); PHI=np.arctan2(Y,X)+0*fz
    fperp=fx+1j*fy; z=np.sum(n*fperp*np.exp(-1j*PHI)); C=np.abs(z)/(np.sum(n*np.abs(fperp))+1e-30)
    fpm=np.sum(np.abs(fperp))/ (n.sum()+1e-30)
    return np.angle(z), C, fpm
fig,axs=plt.subplots(2,1,figsize=(12,10),sharex=False)
for r,(key,lab,goto) in enumerate(RUNS):
    with h5py.File(goto,"r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{key}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms))
    ps=load_frames_bulk(P,list(range(nf))); tms=tms[:nf]
    Dref=Dx(ps[-1]); T=Dref/(np.linalg.norm(Dref)+1e-30)   # fixed template = final-frame pattern
    cD=np.zeros(nf); Fz=np.zeros(nf); phi0=np.zeros(nf); Cco=np.zeros(nf); fperp=np.zeros(nf); Lz=np.zeros(nf)
    for k in range(nf):
        p=ps[k]; cD[k]=np.sum(Dx(p)*T); n=(np.abs(p)**2); Fz[k]=(mvals*(n.sum((0,1,2))/n.sum())).sum()
        phi0[k],Cco[k],fperp[k]=phi0_azim(p,L); Lz[k]=Lz_expect(p,L)
    # sign-change (inversion) count & mean period of cD
    sgn=np.sign(cD); flips=np.where(np.diff(sgn)!=0)[0]
    Tinv=np.mean(np.diff(tms[flips]))*2 if len(flips)>1 else np.nan  # full period ~ 2x half-period
    a=axs[r]; a.axhline(0,color="0.7",lw=.8)
    a.plot(tms,cD/np.abs(cD).max(),"k-",lw=2.2,label="市松符号 c_D(t) (規格化)")
    a.plot(tms,Fz/6,color="#d1495b",lw=1.6,label="⟨Fz⟩/6 (スピン射影・章動)")
    a.plot(tms,fperp/max(fperp.max(),1e-9),color="#e08e0b",lw=1.4,ls=":",label="|f⊥| (横スピン, 規格化)")
    a.plot(tms,Lz/max(np.abs(Lz).max(),1e-9),color="#3a6ea5",lw=1.8,label="⟨Lz⟩ (軌道角運動量, 規格化)")
    a.plot(tms,phi0/np.pi,color="#4a9d5b",lw=1.2,ls="--",label="φ₀/π (横スピン歳差角)")
    ttl=f"{lab}: 市松反転 {len(flips)}回, 平均反転周期≈{Tinv:.0f} ms" if not np.isnan(Tinv) else f"{lab}: 市松符号反転なし"
    a.set_title(ttl); a.set_xlabel("時刻 t (ms)"); a.set_ylabel("規格化量"); a.legend(fontsize=9,ncol=2,loc="lower left"); a.grid(alpha=.25)
    print(f"[{key}] frames={nf} dt~{np.mean(np.diff(tms)):.2f}ms | cD sign flips={len(flips)} @tms={np.round(tms[flips],0) if len(flips) else '[]'} | mean inv period≈{Tinv:.1f}ms")
    print(f"        <Fz>: {Fz[0]:.2f}->{Fz[-1]:.2f}  |f⊥|max={fperp.max():.3f}  <Lz>: {Lz[0]:+.3f}->{Lz[-1]:+.3f} (|max|={np.abs(Lz).max():.3f})  coherence C mean={Cco.mean():.3f}")
fig.suptitle("市松反転の起源: スピン歳差(⟨Fz⟩/φ₀) vs 軌道(⟨Lz⟩) — c_D の反転周期がどれと一致するか",fontsize=14,y=0.995)
fig.tight_layout(rect=[0,0,1,0.98]); fig.savefig("checkerboard_origin.png",dpi=120); print("\nwrote checkerboard_origin.png")
