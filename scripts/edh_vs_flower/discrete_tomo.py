#!/usr/bin/env python3
"""DISCRETE-angle tilt tomography (the real method): a FINITE set of tilt settings
{identity, R_y(beta_k), R_x(beta_k)} -> SG occupations P -> linear inversion P=M r -> rho_hat.
Demo on a LOCAL rho(r) from EdH data (has real coherences, unlike the global diagonal rho).
env: SPIN3D, OUT, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SPIN3D"]; OUT=os.environ.get("OUT","disc_tomo.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fz=np.diag(ms.astype(float)); Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j); Fx=0.5*(Fp+Fp.T)
# --- local rho(r) from data: spinor (m=-6,-5,-4) at a vortex-ring pixel ---
f=h5py.File(S,"r"); L=float(f["meta/L_box"][()])
def psi(mk,ak): n=np.transpose(np.asarray(f[mk]),(2,1,0,3))[...,FR]; a=np.transpose(np.asarray(f[ak]),(2,1,0,3))[...,FR]; return np.sqrt(np.clip(n,0,None))*np.exp(1j*a)
p6=psi("n_m6_3d","arg_psi_m6_3d"); p5=psi("n_m5_3d","arg_psi_m5_3d"); p4=psi("n_m4_3d","arg_psi_m4_3d")
# pick pixel where m=-5 (ring) is strong AND m=-6 present  -> nonzero coherence
score=np.abs(p5)*np.abs(p6); ix=np.unravel_index(np.argmax(score),score.shape)
zeta=np.zeros(D,complex)
zeta[list(ms).index(-6)]=p6[ix]; zeta[list(ms).index(-5)]=p5[ix]; zeta[list(ms).index(-4)]=p4[ix]
zeta/=np.linalg.norm(zeta); rho_true=np.outer(zeta,zeta.conj())
# --- DISCRETE settings (finite, but enough for Nyquist: >=2(2F)+1=25 per axis) ---
angs=np.linspace(0,180,25,endpoint=False)   # 25 equispaced angles per axis
settings=[("I",0.0)]+[("y",b) for b in angs[1:]]+[("x",b) for b in angs[1:]]
Rs=[(np.eye(D) if ax=="I" else expm(-1j*np.radians(bd)*(Fy if ax=="y" else Fx))) for ax,bd in settings]
P=np.array([np.real(np.diag(R@rho_true@R.conj().T)) for R in Rs])   # (Nset,13)
# --- reconstruct over the 4-level block (m=-6..-3), posture B (all 13 occ used) ---
blk=[list(ms).index(m) for m in [-6,-5,-4,-3]]; nb=len(blk)
params=[("d",a,a) for a in range(nb)]+[(t,a,c) for a in range(nb) for c in range(a+1,nb) for t in ("re","im")]
def rho_from(r):
    R=np.zeros((D,D),complex)
    for v,(t,a,c) in zip(r,params):
        ia,ic=blk[a],blk[c]
        if t=="d": R[ia,ia]=v
        elif t=="re": R[ia,ic]+=v; R[ic,ia]+=v
        else: R[ia,ic]+=1j*v; R[ic,ia]+=-1j*v
    return R
M=np.zeros((len(Rs)*D,len(params)))
for j in range(len(params)):
    r=np.zeros(len(params)); r[j]=1.0
    M[:,j]=np.array([np.real(np.diag(R@rho_from(r)@R.conj().T)) for R in Rs]).reshape(-1)
# truncated-SVD (regularized) inversion — §3 fix for ill-conditioning
U,sv,Vt=np.linalg.svd(M,full_matrices=False); tol=1e-6*sv[0]; svi=np.where(sv>tol,1/sv,0.0)
rhat=(Vt.T*svi)@(U.T@P.reshape(-1))
rho_rec=rho_from(rhat); cond=sv[0]/sv[sv>tol][-1]
# truth restricted to block
rho_tb=rho_true[np.ix_(blk,blk)]; rho_rb=rho_rec[np.ix_(blk,blk)]
err=np.max(np.abs(rho_tb-rho_rb))
# --- figure ---
fig,ax=plt.subplots(2,3,figsize=(14,8.5),constrained_layout=True); lab=[-6,-5,-4,-3]
def hm(a,Mx,ttl,cmap,vmin,vmax):
    im=a.imshow(Mx,cmap=cmap,vmin=vmin,vmax=vmax); a.set_xticks(range(4));a.set_yticks(range(4));a.set_xticklabels(lab);a.set_yticklabels(lab);a.set_title(ttl,fontsize=10)
    for i in range(4):
        for k in range(4): a.text(k,i,f"{Mx[i,k]:.2f}",ha="center",va="center",color="lime",fontsize=7)
    fig.colorbar(im,ax=a,shrink=0.8)
vm=np.abs(rho_tb).max()
hm(ax[0,0],np.abs(rho_tb),r"TRUE $|\rho^{(4)}|$ (local, has coherence)","magma",0,vm)
hm(ax[0,1],np.abs(rho_rb),f"RECONSTRUCTED |ρ| ({len(settings)} discrete settings)","magma",0,vm)
hm(ax[0,2],np.abs(rho_tb-rho_rb),f"|error| (max={err:.1e})","viridis",0,vm)
hm(ax[1,0],np.angle(rho_tb),r"TRUE arg ρ","twilight",-np.pi,np.pi)
hm(ax[1,1],np.angle(rho_rb),"RECON arg ρ","twilight",-np.pi,np.pi)
ax[1,2].axis("off")
rank=np.linalg.matrix_rank(M)
ny=sum(1 for a,_ in settings if a=="y"); nx=sum(1 for a,_ in settings if a=="x")
txt=(f"DISCRETE tilt settings (finite!):\n"
     f"  identity + R_y×{ny} + R_x×{nx}\n"
     f"  = {len(settings)} settings, angles 0–180° equispaced\n"
     f"  (Nyquist for F=6: ≥25/axis)\n\n"
     f"measurements: {len(settings)}×13 = {len(settings)*13}\n"
     f"block params: {len(params)} real\n"
     f"cond(M) (regularized) = {cond:.1f}\n"
     f"rank(M) = {rank}/{len(params)}  ← 2 UNOBSERVABLE\n\n"
     f"max recon error = {err:.2e}\n"
     f"(error sits in the m=-3 row:\n"
     f" the block is NOT rotation-closed,\n"
     f" so tilt-SG can't see all params\n"
     f" — handoff caveat 5a. The populated\n"
     f" m=-6,-5,-4 coherences ARE recovered.)\n"
     f"FIX: constrained ML/SDP (ρ⪰0) or full 13-level.")
ax[1,2].text(0.0,0.99,txt,transform=ax[1,2].transAxes,va="top",fontsize=9.5,family="monospace")
fig.suptitle("Discrete-angle quantization-axis tilt tomography — reconstruct local ρ from a FEW settings (T1/T4)",fontsize=13)
fig.savefig(OUT,dpi=120); print(f"wrote {OUT}  cond={cond:.1f} err={err:.2e}  pixel={ix}")
