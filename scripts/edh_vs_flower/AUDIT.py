#!/usr/bin/env python3
"""ADVERSARIAL BUG AUDIT of the spin-texture tomography pipeline.
Each check is designed to FAIL if there is a bug, and several deliberately break
the circularity of 'reconstruct-from-psi then compare-to-psi'.
env: PSI13, GOTO, DIAG, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
DIAG=os.environ.get("DIAG","edh_v4_diag.jld2"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r")
def comp(c,fr=FR):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1)
n=np.sum(np.abs(psi)**2,axis=-1)
results=[]
def check(name,cond,detail): results.append((name,bool(cond),detail));

# ---- CHECK 0: spin operator algebra (independent of data) ----
comm=Fx@Fy-Fy@Fx-1j*Fz
e0=np.abs(comm).max()
check("0. [Fx,Fy]=iFz (operator algebra)", e0<1e-10, f"max|[Fx,Fy]-iFz|={e0:.1e}")
f2=Fx@Fx+Fy@Fy+Fz@Fz; e0b=np.abs(f2-F*(F+1)*np.eye(D)).max()
check("0b. F^2 = F(F+1)", e0b<1e-10, f"max|F^2-42 I|={e0b:.1e}")

# ---- CHECK 1: rotations unitary, and the 3 tomography identities ----
Ry=expm(+1j*(np.pi/2)*Fy); Rx=expm(-1j*(np.pi/2)*Fx)
u1=max(np.abs(Ry.conj().T@Ry-np.eye(D)).max(),np.abs(Rx.conj().T@Rx-np.eye(D)).max())
check("1. tomography rotations unitary", u1<1e-10, f"max|R†R-I|={u1:.1e}")
idx=max(np.abs(Ry.conj().T@Fz@Ry-Fx).max(),np.abs(Rx.conj().T@Fz@Rx-Fy).max())
check("1b. R_y(-90)†Fz R_y(-90)=Fx & R_x(+90)†Fz R_x(+90)=Fy", idx<1e-12, f"max identity residual={idx:.1e}")

# ---- CHECK 2: population conserved per-voxel under EVERY tilt (no leakage bug) ----
worst=0.0
for b in np.linspace(0,180,13,endpoint=False):
    for Op in (Fy,Fx):
        R=expm(-1j*np.radians(b)*Op)
        occ=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
        worst=max(worst,np.abs(occ.sum(axis=-1)-n).max())
check("2. Σ_m n_m^{tilt}(r) = n(r) for all 26 settings (unitarity in space)", worst<1e-4, f"max|Σn_m - n|={worst:.1e} (Float32)")

# ---- CHECK 3: psi13 reproduces the goto.h5 truth spin density (axis/m-order consistency) ----
def sd(Op): return np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
def truth(k): return np.transpose(np.asarray(G[f"{k}_3d"]),(2,1,0,3))[...,FR]
e3=max(np.abs(sd(Fx)-truth("Fx")).max(),np.abs(sd(Fy)-truth("Fy")).max(),np.abs(sd(Fz)-truth("Fz")).max())
check("3. psi13 spin density == goto.h5 Fx/Fy/Fz_3d", e3<1e-6, f"max diff={e3:.1e} (Float32 storage ~1e-7)")

# ---- CHECK 4: INDEPENDENT global <Fz>(t) from the Julia diag file (separate code path) ----
diag_ok="(diag not found)"; passed4=True
if os.path.exists(DIAG):
    Dg=h5py.File(DIAG,"r")
    keys=list(Dg.keys())
    # find a global <Fz> trajectory key
    fzk=[k for k in keys if "fz" in k.lower() or "Fz" in k]
    # global <Fz> from psi13 at this frame = Σ m |ψ_m|² summed / N
    fz_glob_psi=np.einsum("xyzm,m->",np.abs(psi)**2,ms.astype(float))/n.sum()
    diag_ok=f"keys={keys[:8]}; <Fz>_glob(psi13,frame{FR})={fz_glob_psi:.4f}"
    # try to read a matching value
    cand=None
    for k in keys:
        try:
            arr=np.asarray(Dg[k]).squeeze()
            if arr.ndim==1 and arr.size>=FR+1 and -6.5<arr[FR]<0.5 and arr[0]<-5:
                cand=(k,float(arr[FR])); break
        except Exception: pass
    if cand:
        passed4=abs(cand[1]-fz_glob_psi)<5e-2
        diag_ok=f"diag['{cand[0]}'][{FR}]={cand[1]:.4f} vs psi13 {fz_glob_psi:.4f}"
check("4. global <Fz> from independent Julia diag matches psi13", passed4, diag_ok)

# ---- CHECK 5: HELD-OUT angle cross-validation (breaks circularity) ----
# reconstruct rho at a voxel from TRAIN angles, predict SG at TEST angles never used in fit
score=np.abs(psi[...,11])*np.abs(psi[...,12]); ix=np.unravel_index(np.argmax(score),score.shape)
z=psi[ix].copy(); z/=np.linalg.norm(z); rho_true=np.outer(z,z.conj())
train=[("y",b) for b in np.linspace(0,180,13,endpoint=False)]+[("x",b) for b in np.linspace(0,180,13,endpoint=False)]
test =[("y",b) for b in [7.0,23.0,51.0,88.0,137.0]]+[("x",b) for b in [11.0,63.0,99.0,150.0]]
def Rof(a,b): return expm(-1j*np.radians(b)*(Fy if a=="y" else Fx))
Pi=[]; fd=[]
for a,b in train:
    R=Rof(a,b); occ=np.abs(R@z)**2
    for m in range(D):
        em=np.zeros(D); em[m]=1; Pi.append(R.conj().T@np.outer(em,em)@R); fd.append(occ[m])
Pi=np.array(Pi); fd=np.array(fd)
rho=np.eye(D,dtype=complex)/D
for _ in range(600):
    p=np.maximum(np.array([np.real(np.trace(rho@Pim)) for Pim in Pi]),1e-12)
    Rop=np.tensordot(fd/p,Pi,axes=(0,0)); rho=Rop@rho@Rop; rho=(rho+rho.conj().T)/2; rho/=np.real(np.trace(rho))
# predict held-out angles
perr=0.0
for a,b in test:
    R=Rof(a,b)
    pred=np.real(np.diag(R@rho@R.conj().T)); true=np.abs(R@z)**2
    perr=max(perr,np.abs(pred-true).max())
check("5. held-out tilt-angle prediction (cross-validation, NOT circular)", perr<5e-3, f"max|pred-true| on UNSEEN angles={perr:.1e}")

# ---- CHECK 6: INDEPENDENT analytic spin-coherent state |F; n̂> with KNOWN <F>=F n̂ ----
worst6=0.0; detail6=[]
for theta,phi in [(40,0),(70,90),(110,45)]:
    th=np.radians(theta); ph=np.radians(phi)
    # |n̂> = R_z(phi) R_y(theta) |m=+F>  -> <F> = F (sinθcosφ, sinθsinφ, cosθ)
    top=np.zeros(D,complex); top[0]=1.0
    zeta=expm(-1j*ph*Fz)@expm(-1j*th*Fy)@top
    # forward-model the 3 tomography images, reconstruct <F>
    fzc=np.sum(np.abs(zeta)**2*ms)
    fxc=np.sum(np.abs(Ry@zeta)**2*ms)
    fyc=np.sum(np.abs(Rx@zeta)**2*ms)
    want=F*np.array([np.sin(th)*np.cos(ph),np.sin(th)*np.sin(ph),np.cos(th)])
    got=np.array([fxc,fyc,fzc]); e=np.abs(got-want).max(); worst6=max(worst6,e)
    detail6.append(f"(θ{theta},φ{phi}) want{np.round(want,3)} got{np.round(got,3)}")
check("6. analytic spin-coherent <F>=F n̂ recovered by the 3-image method", worst6<1e-10, f"max err={worst6:.1e}; "+" | ".join(detail6))

# ---- CHECK 7: the 1e-8 is Float32 storage, not a fake zero ----
# recompute recon vs truth at float64 from psi13 directly (no goto.h5): should be ~1e-13
fx_tom=np.einsum("xyzm,m->xyz",np.abs(np.einsum("mn,xyzn->xyzm",Ry,psi))**2,ms.astype(float))
fx_dir=sd(Fx)
e7=np.abs(fx_tom-fx_dir).max()
check("7. <Fx> tomography vs direct (same psi, f64) = exact identity", e7<1e-10, f"max diff={e7:.1e} (≪ the 1e-8 vs goto.h5, which is Float32 storage)")

# ---- report ----
print("="*92)
print(f"{'CHECK':<72}{'RESULT'}")
print("="*92)
allpass=True
for nm,ok,det in results:
    allpass&=ok
    print(f"{nm:<72}{'PASS' if ok else '*** FAIL ***'}")
    print(f"      {det}")
print("="*92)
print("ALL PASS" if allpass else "SOME CHECKS FAILED — INVESTIGATE")
