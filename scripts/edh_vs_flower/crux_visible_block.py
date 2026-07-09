#!/usr/bin/env python3
"""THE CRUX: under the experimental visibility constraint (only m=-6,-5,-4,-3 seen),
does the spin-texture reconstruction still work? Compare estimators of <Fx>(r):
  (A) full-ladder centroid @ R_y(-90)   = EXACT <Fx>  (needs ALL 13 sublevels)
  (B) visible-block centroid @ R_y(-90) = exact method but RESTRICTED to visible (biased)
  (C) visible-block centroid @ R_y(+16) single small tilt (naive)
  (D) visible-block +/-16 DIFFERENTIAL  (s_+ - s_-)/(-2 sin16) = the HYBRID
vs TRUE <Fx>=Tr(rho Fx)/n. Also reports visible-block population fraction vs tilt.
env: PSI13, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Ry=lambda b: expm(-1j*np.radians(b)*Fy); Rx=lambda b: expm(-1j*np.radians(b)*Fx)
VIS=[list(ms).index(m) for m in (-6,-5,-4,-3)]; ms_v=ms[VIS].astype(float)
P=h5py.File(PSI,"r")
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1); mask=n>0.04*n.max()
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
fxT=sd(Fx)/np.clip(n,1e-30,None)            # TRUE <Fx> per atom
# SG occupation field for a rotation
def occ(R): return np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2   # (x,y,z,13)
def cen_all(R): o=occ(R); return np.einsum("xyzm,m->xyz",o,ms.astype(float))/np.clip(n,1e-30,None)
def cen_vis(R):
    o=occ(R); ov=o[...,VIS]; Nv=np.clip(ov.sum(-1),1e-30,None)
    return np.einsum("xyzm,m->xyz",ov,ms_v)/Nv, ov.sum(-1)   # visible centroid + visible density
th=16.0
# (A) full-ladder exact
A=cen_all(Ry(-90))
# (B) visible-block at -90 (exact method, restricted)
B,_=cen_vis(Ry(-90))
# (C) visible-block single +16
C,_=cen_vis(Ry(+th))
# (D) visible-block +/-16 differential
sp,_=cen_vis(Ry(+th)); sm,_=cen_vis(Ry(-th))
Dest=-(sp-sm)/(2*np.sin(np.radians(th)))    # hybrid estimate of <Fx>
def met(est,lbl):
    a=est[mask]; b=fxT[mask]
    rms=np.sqrt(np.mean((a-b)**2)); r=np.corrcoef(a,b)[0,1] if a.std()>0 else 1
    print(f"  {lbl:48s} RMS={rms:.3e}  corr={r:+.4f}")
print(f"=== <Fx> estimators vs TRUE (EdH frame {FR}, visible block = m=-6,-5,-4,-3) ===")
met(A,"(A) full-ladder centroid @ R_y(-90)  [needs all 13]")
met(B,"(B) VISIBLE-block centroid @ R_y(-90) [exact-but-truncated]")
met(C,"(C) VISIBLE-block single +16 (naive)")
met(Dest,"(D) VISIBLE-block +/-16 DIFFERENTIAL (hybrid)")
# visible-block population fraction vs tilt
print("=== visible-block population fraction (how much of the cloud stays in m=-6..-3) ===")
for b in [0,16,30,45,60,90]:
    o=occ(Ry(b)); frac=o[...,VIS].sum()/o.sum()
    print(f"  tilt R_y({b:3d} deg): visible fraction = {frac*100:5.1f}%")
