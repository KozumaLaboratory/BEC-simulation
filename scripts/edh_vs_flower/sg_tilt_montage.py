#!/usr/bin/env python3
"""The RAW EXPERIMENTAL INPUT to spin tomography:
  EdH state psi(r)  -- apply rotation R(beta)=exp(-i beta F_y) (= tilt the
  quantization axis by beta) -- Stern-Gerlach -- absorption image.
For each tilt angle we show the column-integrated SG density profile
  n_m^{(beta)}(x,y) = INT dz |[R(beta) psi]_m(r)|^2   for m=-6,-5,-4.
Rows = m, columns = tilt angle. These images are the tomography input.
env: PSI13, GOTO, OUT, FRAME, AXIS(y/x), ANGLES(comma deg)"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
OUT=os.environ.get("OUT","sg_tilt_montage.png"); FR=int(os.environ.get("FRAME","100"))
AXIS=os.environ.get("AXIS","y")
# default: 13 equispaced angles over [0,180) = 2F+1 multipole ranks (spacing 180/13≈13.8°)
_NA=int(os.environ.get("N_ANGLES","13"))
ANGS=[float(a) for a in os.environ["ANGLES"].split(",")] if os.environ.get("ANGLES") else list(np.linspace(0,180,_NA,endpoint=False))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j); Fx=0.5*(Fp+Fp.T); Fop=Fy if AXIS=="y" else Fx
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1)   # (x,y,z,13)
ntot=np.sum(np.abs(psi)**2)
tms=float(np.asarray(G["t"])[FR])/float(G["meta/omega_ref"][()])*1000
Bz=float(np.asarray(G["B_gauss"])[FR])
ax1d=np.linspace(-L/2,L/2,psi.shape[0]); ext=[-L/2,L/2,-L/2,L/2]
mrows=[(-6,12),(-5,11),(-4,10)]   # (m, c-index)
# forward-model: rotate spinor, SG-resolve, column-integrate along z
cols=[]
for b in ANGS:
    R=expm(-1j*np.radians(b)*Fop)
    rp=np.einsum("mn,xyzn->xyzm",R,psi)
    occ=np.abs(rp)**2
    col_imgs={}; pops={}
    for m,c in mrows:
        col_imgs[m]=occ[...,c].sum(axis=2)         # INT dz  (absorption image)
        pops[m]=occ[...,c].sum()/ntot              # population fraction P_m(beta)
    cols.append((b,col_imgs,pops))
nC=len(ANGS); nR=len(mrows)
fig,ax=plt.subplots(nR,nC,figsize=(1.85*nC+0.6,1.95*nR+1.1),constrained_layout=True)
if nR==1: ax=ax[None,:]
for j,(b,imgs,pops) in enumerate(cols):
    for i,(m,c) in enumerate(mrows):
        a=ax[i,j]; img=imgs[m]; vmax=img.max() if img.max()>0 else 1.0
        a.imshow(img.T/vmax,origin="lower",extent=ext,cmap="inferno",vmin=0,vmax=1,aspect="equal")
        a.set_xticks([]); a.set_yticks([])
        a.text(0.04,0.93,f"P={pops[m]*100:.2f}%",transform=a.transAxes,color="cyan",fontsize=8,va="top")
        if i==0: a.set_title(f"β = {b:.0f}°",fontsize=11,fontweight="bold")
        if j==0: a.set_ylabel(f"m = {m}",fontsize=12,fontweight="bold")
fig.suptitle(
  f"Raw tomography input: tilt quantization axis by R_{AXIS}(β)=exp(−iβF_{AXIS}), then Stern–Gerlach.\n"
  f"Column-integrated SG density n_m^(β)(x,y)=∫dz |[R(β)ψ]_m|²  —  EdH ¹⁵¹Eu, t={tms:.1f} ms, B={Bz*1e3:.3f} mG  "
  f"(each panel self-normalized; P = population fraction)",fontsize=12)
fig.savefig(OUT,dpi=130); print(f"wrote {OUT}  angles={ANGS} axis={AXIS}")
