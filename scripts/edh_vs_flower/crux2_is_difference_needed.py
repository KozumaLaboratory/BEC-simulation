#!/usr/bin/env python3
"""Is the DIFFERENCE really necessary, and is +/-theta special vs tilted-minus-untilted?
All on the VISIBLE block {-6,-5,-4,-3}, EdH. Estimators of <Fx>(r):
  (C)  single +16, NO subtraction: -s_+/sin16            (ignores <Fz>)
  (E)  tilted - scaled untilted:   -(s_+ - cos16 s_0)/sin16
  (D)  +/-16 differential:         -(s_+ - s_-)/(2 sin16)
Also: can two single tilts identify the DOMINANT transverse direction?
And: is the truncation bias b(theta) even in theta (=> +/-theta cancels it)?
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
fxT=sd(Fx)/np.clip(n,1e-30,None); fyT=sd(Fy)/np.clip(n,1e-30,None); fzT=sd(Fz)/np.clip(n,1e-30,None)
def cen_vis(R):
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,VIS]; Nv=np.clip(ov.sum(-1),1e-30,None)
    return np.einsum("xyzm,m->xyz",ov,ms_v)/Nv
th=16.0; s16=np.sin(np.radians(th)); c16=np.cos(np.radians(th))
s0=cen_vis(np.eye(D)); sp=cen_vis(Ry(+th)); sm=cen_vis(Ry(-th))
C =-sp/s16                       # single +16, no subtraction
E =-(sp-c16*s0)/s16              # tilted - scaled untilted
Dd=-(sp-sm)/(2*s16)              # +/-16 differential
def met(est,lbl):
    a=est[mask]; b=fxT[mask]; rms=np.sqrt(np.mean((a-b)**2)); r=np.corrcoef(a,b)[0,1] if a.std()>0 else 1
    print(f"  {lbl:46s} RMS={rms:.3f}  corr={r:+.4f}")
print(f"=== <Fx> from VISIBLE block, EdH frame {FR} ===")
met(C,"(C) single +16, NO subtraction")
met(E,"(E) tilted - scaled untilted  [a difference]")
met(Dd,"(D) +/-16 differential        [a difference]")
# Is the truncation bias even in theta? b(theta) = s_vis(theta) - true projection
proj=lambda th_: c16*fzT - np.sin(np.radians(th_))*fxT if False else None
def bias(th_):
    s=cen_vis(Ry(th_)); true=np.cos(np.radians(th_))*fzT-np.sin(np.radians(th_))*fxT
    return (s-true)
bp=bias(+th)[mask]; bm=bias(-th)[mask]
print(f"=== truncation bias b(theta): is it EVEN in theta? (then +/-theta cancels it) ===")
print(f"  corr(b(+16),b(-16)) = {np.corrcoef(bp,bm)[0,1]:+.4f}   (even => ~+1)")
print(f"  ||b(+16)-b(-16)|| / ||b(+16)+b(-16)|| = {np.linalg.norm(bp-bm)/max(np.linalg.norm(bp+bm),1e-30):.3f}  (small => mostly even)")
# Dominant transverse direction from two single tilts (+16 y and +16 x), referenced to untilted
sxp=cen_vis(Rx(+th))
Fx_est=-(sp - c16*s0)/s16; Fy_est=+(sxp - c16*s0)/s16    # need untilted reference
# can we tell which dominates, per pixel, vs truth?
dom_est=np.where(np.abs(Fx_est)>np.abs(Fy_est),0,1)[mask]
dom_true=np.where(np.abs(fxT)>np.abs(fyT),0,1)[mask]
print(f"=== two single tilts (+16y,+16x) + untilted ref: dominant transverse direction ===")
print(f"  pixel agreement (|Fx|>|Fy| vs truth) = {(dom_est==dom_true).mean()*100:.1f}%")
print(f"  <Fy> via (E-type) corr to truth = {np.corrcoef(Fy_est[mask],fyT[mask])[0,1]:+.4f}")
