#!/usr/bin/env python3
"""PRINCIPLE DEMONSTRATION (ideal, noiseless): can we reconstruct the spin
texture WITHOUT the wavefunction psi, using ONLY (tilted) Stern-Gerlach images?

Hard wall:
  STEP 1  lab_measure(psi, settings) -> image stack  {P_m^(k)(r)}  (the ONLY output)
  STEP 2  >>> del psi <<<                              (psi is physically gone)
  STEP 3  reconstruct(images, settings) -> <F>(r), rho4(r)   (cannot touch psi)
  STEP 4  compare to truth (truth computed BEFORE deletion, only for scoring)

Theory: P_m^(k)(r) = (R_k rho(r) R_k^dag)_mm is a LINEAR map rho -> populations.
No phase / no psi enters. Enough settings -> rho is determined -> <F>=Tr(rho F).
env: PSI13, GOTO, FRAME, OUT"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
FR=int(os.environ.get("FRAME","100")); OUT=os.environ.get("OUT","principle_demo.png")
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
def Rof(axis,beta):
    Op={"y":Fy,"x":Fx,"xy":(Fx+Fy)/np.sqrt(2)}[axis]; return expm(-1j*np.radians(beta)*Op)
# protocol: the tilt settings the experiment performs (known a priori, NOT psi)
SETTINGS={"I":("y",0.0),"Ry-90":("y",-90.0),"Rx+90":("x",90.0)}
SETTINGS_FULL={**{f"y{int(b)}":("y",b) for b in np.linspace(0,180,13,endpoint=False)},
               **{f"x{int(b)}":("x",b) for b in np.linspace(0,180,13,endpoint=False)},
               **{f"d{int(b)}":("xy",b) for b in np.linspace(0,180,13,endpoint=False)}}

# ================= STEP 1: THE LAB (uses psi, emits ONLY images) =================
def lab_measure(psi, settings):
    """Returns ONLY the SG population fields n_m^(k)(r)=|[R_k psi]_m|^2.
    No phases, no psi, no coherences leave this function."""
    imgs={}
    for k,(ax,b) in settings.items():
        R=Rof(ax,b); imgs[k]=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
    return imgs

# ================= STEP 3: RECONSTRUCTION (psi-free) =================
BLK=[list(ms).index(m) for m in (-6,-5,-4,-3)]
def _pbasis(pairs): return [("d",a,a) for a in BLK]+[(t,a,c) for (a,c) in pairs for t in ("re","im")]
def reconstruct_vector(images, settings):
    """<F>(r) from 3 SG images via the centroid identity. psi-free, exact."""
    cen=lambda key: np.einsum("xyzm,m->xyz", images[key], ms.astype(float))
    return cen("Ry-90"), cen("Rx+90"), cen("I")      # <Fx>,<Fy>,<Fz>
def reconstruct_rho4(images, settings):
    """full 4-level rho^(4)(r) by linear inversion of the populations. psi-free."""
    pairs=[(BLK[i],BLK[j]) for i in range(4) for j in range(i+1,4)]; ps=_pbasis(pairs)
    keys=list(settings.keys()); Rs=[Rof(*settings[k]) for k in keys]
    # measurement matrix M: params -> populations (all 13 channels x settings)
    cols=[]
    for j in range(len(ps)):
        e=np.zeros(len(ps)); M0=np.zeros((D,D),complex)
        t,a,c=ps[j]
        if t=="d": M0[a,a]=1
        elif t=="re": M0[a,c]=1; M0[c,a]=1
        else: M0[a,c]=1j; M0[c,a]=-1j
        cols.append(np.concatenate([np.real(np.diag(R@M0@R.conj().T)) for R in Rs]))
    M=np.array(cols).T; Minv=np.linalg.pinv(M)
    P=np.concatenate([images[k] for k in keys],axis=-1)   # (Nx,Ny,Nz, nset*13)
    rf=P@Minv.T                                            # (..., nparam)
    return rf, ps
def F_from_rho4(rf, ps, Op):
    out=np.zeros(rf.shape[:3])
    for j,(t,a,c) in enumerate(ps):
        if t=="d": out+=rf[...,j]*np.real(Op[a,a])
        elif t=="re": out+=rf[...,j]*2*np.real(Op[a,c])
        else: out+=rf[...,j]*(2*np.imag(Op[a,c]))
    return out

# ===================== DRIVER =====================
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1)
# truth (computed BEFORE psi is deleted; used only for scoring)
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
truth=(sd(Fx),sd(Fy),sd(Fz))
# STEP 1: lab emits images
imgs3=lab_measure(psi, SETTINGS)
imgsF=lab_measure(psi, SETTINGS_FULL)
# STEP 2: DESTROY psi — reconstruction below physically cannot use it
del psi
print("psi deleted. reconstruction now has access ONLY to {P_m^(k)(r)} + the protocol.")
# STEP 3: reconstruct (psi-free)
fxV,fyV,fzV = reconstruct_vector(imgs3, SETTINGS)                 # 3 images -> <F>
rf,ps = reconstruct_rho4(imgsF, SETTINGS_FULL)                    # 39 images -> rho4
fxR,fyR,fzR = (F_from_rho4(rf,ps,Fx),F_from_rho4(rf,ps,Fy),F_from_rho4(rf,ps,Fz))
# STEP 4: score vs truth
mask=n>0.04*n.max()
def err(A,B): return np.abs(A-B)[mask].max()
print("=== psi-FREE reconstruction vs truth (max abs error over cloud) ===")
print(f"  3-image vector:  <Fx> {err(fxV,truth[0]):.2e}  <Fy> {err(fyV,truth[1]):.2e}  <Fz> {err(fzV,truth[2]):.2e}")
print(f"  rho4 (39 imgs):  <Fx> {err(fxR,truth[0]):.2e}  <Fy> {err(fyR,truth[1]):.2e}  <Fz> {err(fzR,truth[2]):.2e}")
# also check a coherence recovered (off-diagonal) — provably not from psi
print(f"  (rho4 also yields coherences, e.g. |rho_-6,-5| field max = {np.max(np.hypot(rf[...,4],rf[...,5])[mask]):.3f})")

# figure: truth vs psi-free reconstruction
ax1d=np.linspace(-L/2,L/2,n.shape[0]); ext=[-L/2,L/2,-L/2,L/2]
zc=int(np.argmax(n.sum(axis=(0,1)))); nn=np.clip(n[:,:,zc],1e-12,None); m2=mask[:,:,zc]
xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,n.shape[0]//16)
pa=lambda f: np.where(m2,f[:,:,zc]/nn,np.nan)
fig,ax=plt.subplots(1,3,figsize=(13,4.6),constrained_layout=True)
def tex(a,fx,fy,fz,title):
    Sz=pa(fz); Sx=pa(fx); Sy=pa(fy); mg=np.hypot(Sx,Sy)
    im=a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    U=np.where(mg>1e-6,Sx/mg,np.nan); V=np.where(mg>1e-6,Sy/mg,np.nan); sub=(slice(None,None,st),)*2
    a.quiver(xx[sub],yy[sub],U[sub],V[sub],mg[sub],cmap="Greys",clim=(0,6),scale=24,width=0.007,headwidth=4,pivot="mid")
    a.set_title(title,fontsize=10); a.set_xticks([]);a.set_yticks([]); return im
tex(ax[0],*truth,"TRUE ⟨F⟩(r)  [from ψ, for scoring only]")
tex(ax[1],fxV,fyV,fzV,"reconstructed [3 SG images, ψ-free]")
em=np.where(m2,np.sqrt((fxV-truth[0])**2+(fyV-truth[1])**2+(fzV-truth[2])**2)[:,:,zc],np.nan)
im=ax[2].imshow(em.T,origin="lower",extent=ext,cmap="magma",aspect="equal"); ax[2].set_title(f"|error|  max={max(err(fxV,truth[0]),err(fyV,truth[1]),err(fzV,truth[2])):.1e}",fontsize=10)
ax[2].set_xticks([]);ax[2].set_yticks([]); fig.colorbar(im,ax=ax[2],shrink=0.75)
fig.suptitle("Principle: spin texture reconstructed from (tilted) Stern–Gerlach ONLY — ψ deleted before reconstruction",fontsize=12)
fig.savefig(OUT,dpi=130,bbox_inches="tight"); print("wrote",OUT)
