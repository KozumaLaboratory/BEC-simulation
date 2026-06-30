#!/usr/bin/env python3
"""T1: minimal tilt-setting count. Sweep N settings (equispaced R_y/R_x), constrained-ML
reconstruct the local rho, plot fidelity & block-error vs N. env: SPIN3D, OUT, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SPIN3D"]; OUT=os.environ.get("OUT","t1.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j); Fx=0.5*(Fp+Fp.T)
f=h5py.File(S,"r")
def psi(mk,ak): n=np.transpose(np.asarray(f[mk]),(2,1,0,3))[...,FR]; a=np.transpose(np.asarray(f[ak]),(2,1,0,3))[...,FR]; return np.sqrt(np.clip(n,0,None))*np.exp(1j*a)
p6=psi("n_m6_3d","arg_psi_m6_3d"); p5=psi("n_m5_3d","arg_psi_m5_3d"); p4=psi("n_m4_3d","arg_psi_m4_3d")
ix=np.unravel_index(np.argmax(np.abs(p5)*np.abs(p6)),p5.shape)
z=np.zeros(D,complex); z[12]=p6[ix]; z[11]=p5[ix]; z[10]=p4[ix]; z/=np.linalg.norm(z)
rho_true=np.outer(z,z.conj()); blk=[12,11,10,9]
def ml_recon(settings):
    Rs=[(np.eye(D) if a=="I" else expm(-1j*np.radians(b)*(Fy if a=="y" else Fx))) for a,b in settings]
    Pi=[]; fd=[]
    for R in Rs:
        rr=R@rho_true@R.conj().T
        for m in range(D):
            em=np.zeros(D); em[m]=1; Pi.append(R.conj().T@np.outer(em,em)@R); fd.append(np.real(rr[m,m]))
    Pi=np.array(Pi); fd=np.array(fd)
    rho=np.eye(D,dtype=complex)/D
    for _ in range(400):
        p=np.maximum(np.array([np.real(np.trace(rho@Pim)) for Pim in Pi]),1e-12)
        Rop=np.tensordot(fd/p,Pi,axes=(0,0)); rho=Rop@rho@Rop; rho=(rho+rho.conj().T)/2; rho/=np.real(np.trace(rho))
    fid=np.real(z.conj()@rho@z); err=np.max(np.abs(rho_true[np.ix_(blk,blk)]-rho[np.ix_(blk,blk)]))
    return fid,err
Ns=list(range(2,14)); fids=[]; errs=[]
for N in Ns:
    na=N//2; nb=N-na
    ay=np.linspace(0,180,na,endpoint=False); ax_=np.linspace(20,160,nb)
    sets=[("I",0.0)]+[("y",b) for b in ay[1:]]+[("y",ay[0]) if na>0 else None]+[("x",b) for b in ax_]
    sets=[s for s in sets if s is not None]
    fid,err=ml_recon(sets); fids.append(fid); errs.append(err)
    print(f"N={len(sets):2d}  fidelity={fid:.4f}  block_err={err:.2e}")
nmin=next((Ns[i] for i,fi in enumerate(fids) if fi>0.999), Ns[-1])
fig,ax=plt.subplots(1,2,figsize=(12,4.6),constrained_layout=True)
ax[0].plot(Ns,fids,"o-",c="C0"); ax[0].axhline(0.999,ls=":",c="r",label="0.999"); ax[0].axvline(nmin,ls=":",c="gray")
ax[0].set_xlabel("# tilt settings"); ax[0].set_ylabel("ML fidelity to true ρ"); ax[0].set_title(f"fidelity vs settings (min for >0.999 ≈ {nmin})"); ax[0].legend(); ax[0].grid(alpha=.3)
ax[1].semilogy(Ns,errs,"s-",c="C1"); ax[1].axvline(nmin,ls=":",c="gray")
ax[1].set_xlabel("# tilt settings"); ax[1].set_ylabel("block reconstruction error"); ax[1].set_title("error vs settings (log)"); ax[1].grid(alpha=.3)
fig.suptitle("T1: minimal discrete tilt-setting count (constrained ML, local ρ with coherences)",fontsize=12)
fig.savefig(OUT,dpi=120); print(f"wrote {OUT}  n_min(fid>0.999)={nmin}")
