#!/usr/bin/env python3
"""FULL local density matrix rho(r) from a tilt-SCAN of SG images (the regime the
3-image vector method can't reach: coherences / higher multipoles).
At a representative voxel we take the TRUE local spinor zeta(r) (all 13 comps),
forward-model SG occupations P_m^k=|[R_k zeta]_m|^2 over a discrete tilt scan,
then constrained-ML reconstruct rho and validate vs the true rho=zeta zeta^dag.
env: PSI13, OUT, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); OUT=os.environ.get("OUT","rho_from_images.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j); Fx=0.5*(Fp+Fp.T)
P=h5py.File(PSI,"r")
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1)
n=np.sum(np.abs(psi)**2,axis=-1)
# representative voxel: vortex ring where m=-5 strong & m=-6 present (real coherence)
score=np.abs(psi[...,11])*np.abs(psi[...,12]); ix=np.unravel_index(np.argmax(score),score.shape)
zeta=psi[ix].copy(); zeta/=np.linalg.norm(zeta); rho_true=np.outer(zeta,zeta.conj())
# discrete tilt scan -> SG occupations (the data)
angs=np.linspace(0,180,25,endpoint=False)
settings=[("I",0.0)]+[("y",b) for b in angs[1:]]+[("x",b) for b in angs[1:]]
Rs=[(np.eye(D) if a=="I" else expm(-1j*np.radians(b)*(Fy if a=="y" else Fx))) for a,b in settings]
Pi=[]; fdata=[]
for R in Rs:
    occ=np.abs(R@zeta)**2                       # SG occupation = |[R zeta]_m|^2  (the measured image pixel)
    for m in range(D):
        em=np.zeros(D); em[m]=1; Pi.append(R.conj().T@np.outer(em,em)@R); fdata.append(occ[m])
Pi=np.array(Pi); fdata=np.array(fdata)
# constrained ML (RrhoR), rho>=0
rho=np.eye(D,dtype=complex)/D
for _ in range(400):
    p=np.maximum(np.array([np.real(np.trace(rho@Pim)) for Pim in Pi]),1e-12)
    Rop=np.tensordot(fdata/p,Pi,axes=(0,0)); rho=Rop@rho@Rop; rho=(rho+rho.conj().T)/2; rho/=np.real(np.trace(rho))
fid=np.real(zeta.conj()@rho@zeta)
blk=[12,11,10,9,8]; lab=[-6,-5,-4,-3,-2]
def bl(M): return M[np.ix_(blk,blk)]
err=np.max(np.abs(bl(rho_true)-bl(rho)))
print(f"fidelity(ML to true local state)={fid:.5f}  block max-err={err:.2e}  min-eig={np.linalg.eigvalsh(rho).min():.1e}")
fig,ax=plt.subplots(2,2,figsize=(10.5,9.2),constrained_layout=True)
def hm(a,M,t,ang=False):
    Mx=np.angle(M) if ang else np.abs(M)
    im=a.imshow(Mx,cmap=("twilight" if ang else "magma"),vmin=(-np.pi if ang else 0),vmax=(np.pi if ang else np.abs(bl(rho_true)).max()))
    a.set_xticks(range(len(blk)));a.set_yticks(range(len(blk)));a.set_xticklabels(lab);a.set_yticklabels(lab);a.set_title(t,fontsize=10)
    for i in range(len(blk)):
        for k in range(len(blk)): a.text(k,i,f"{Mx[i,k]:.2f}",ha="center",va="center",color=("w" if ang else "lime"),fontsize=7)
    fig.colorbar(im,ax=a,shrink=0.8)
hm(ax[0,0],bl(rho_true),r"TRUE $|\rho_{mm'}(r)|$ (local, from full ψ)")
hm(ax[0,1],bl(rho),f"ML from SG tilt-scan  |ρ|  (err={err:.1e})")
hm(ax[1,0],bl(rho_true),r"TRUE $\arg\rho$",ang=True)
hm(ax[1,1],bl(rho),r"ML $\arg\rho$",ang=True)
fig.suptitle(f"Full local ρ(r) from a tilt-SCAN of SG images — constrained ML, voxel {ix}\n"
             f"fidelity={fid:.5f}, ρ⪰0 (min-eig {np.linalg.eigvalsh(rho).min():.0e}).  "
             f"This recovers coherences (off-diagonals) the 3-image vector method cannot.",fontsize=11)
fig.savefig(OUT,dpi=125); print("wrote",OUT)
