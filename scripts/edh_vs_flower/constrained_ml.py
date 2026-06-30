#!/usr/bin/env python3
"""T4: constrained MAX-LIKELIHOOD tomography (RρR iteration, Hradil) — full 13-level,
guarantees ρ⪰0, Tr=1. Recovers the unobservable directions via positivity.
Compares ML vs naive-LSQ on the SAME discrete tilt data. env: SPIN3D, OUT, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SPIN3D"]; OUT=os.environ.get("OUT","ml.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j); Fx=0.5*(Fp+Fp.T)
# local test rho (pure, m=-6,-5,-4) from data
f=h5py.File(S,"r")
def psi(mk,ak): n=np.transpose(np.asarray(f[mk]),(2,1,0,3))[...,FR]; a=np.transpose(np.asarray(f[ak]),(2,1,0,3))[...,FR]; return np.sqrt(np.clip(n,0,None))*np.exp(1j*a)
p6=psi("n_m6_3d","arg_psi_m6_3d"); p5=psi("n_m5_3d","arg_psi_m5_3d"); p4=psi("n_m4_3d","arg_psi_m4_3d")
ix=np.unravel_index(np.argmax(np.abs(p5)*np.abs(p6)),p5.shape)
z=np.zeros(D,complex); z[12]=p6[ix]; z[11]=p5[ix]; z[10]=p4[ix]; z/=np.linalg.norm(z)
rho_true=np.outer(z,z.conj())
# discrete settings + POVM elements Pi_{k,m}=R_k† |m><m| R_k
angs=np.linspace(0,180,25,endpoint=False)
settings=[("I",0.0)]+[("y",b) for b in angs[1:]]+[("x",b) for b in angs[1:]]
Rs=[(np.eye(D) if a=="I" else expm(-1j*np.radians(b)*(Fy if a=="y" else Fx))) for a,b in settings]
Pi=[]; fdata=[]
for R in Rs:
    rr=R@rho_true@R.conj().T
    for m in range(D):
        em=np.zeros(D); em[m]=1; Pim=R.conj().T@np.outer(em,em)@R   # POVM element
        Pi.append(Pim); fdata.append(np.real(rr[m,m]))
Pi=np.array(Pi); fdata=np.array(fdata); fdata/=fdata.sum()/len(Rs)   # normalise per-setting (each setting sums to 1)
# --- RρR iterative ML (ρ⪰0 guaranteed) ---
rho=np.eye(D,dtype=complex)/D
for it in range(300):
    p=np.array([np.real(np.trace(rho@Pim)) for Pim in Pi]); p=np.maximum(p,1e-12)
    Rop=np.tensordot(fdata/p, Pi, axes=(0,0))
    rho=Rop@rho@Rop; rho=(rho+rho.conj().T)/2; rho/=np.real(np.trace(rho))
# naive LSQ full-13 for comparison (truncated SVD)
# (build M over full 13x13 Hermitian params)
def herm_params(D):
    ps=[("d",a,a) for a in range(D)]+[(t,a,c) for a in range(D) for c in range(a+1,D) for t in ("re","im")]
    return ps
ps=herm_params(D)
def rho_from(r):
    M=np.zeros((D,D),complex)
    for v,(t,a,c) in zip(r,ps):
        if t=="d": M[a,a]=v
        elif t=="re": M[a,c]+=v; M[c,a]+=v
        else: M[a,c]+=1j*v; M[c,a]-=1j*v
    return M
Mm=np.zeros((len(Rs)*D,len(ps)))
for j in range(len(ps)):
    r=np.zeros(len(ps)); r[j]=1
    Mm[:,j]=np.array([np.real(np.diag(R@rho_from(r)@R.conj().T)) for R in Rs]).reshape(-1)
U,sv,Vt=np.linalg.svd(Mm,full_matrices=False); tol=1e-3*sv[0]; svi=np.where(sv>tol,1/sv,0)
rho_lsq=rho_from((Vt.T*svi)@(U.T@(fdata.reshape(len(Rs),D)).reshape(-1)))
blk=[12,11,10,9]
def bl(M): return M[np.ix_(blk,blk)]
errML=np.max(np.abs(bl(rho_true)-bl(rho))); errLS=np.max(np.abs(bl(rho_true)-bl(rho_lsq)))
fid=np.real(z.conj()@rho@z)   # fidelity to true pure state
print(f"errML={errML:.2e}  errLSQ={errLS:.2e}  fidelity(ML)={fid:.4f}  min-eig(ML)={np.linalg.eigvalsh(rho).min():.2e}")
lab=[-6,-5,-4,-3]
fig,ax=plt.subplots(1,3,figsize=(14,4.6),constrained_layout=True)
def hm(a,M,t):
    im=a.imshow(np.abs(M),cmap="magma",vmin=0,vmax=np.abs(bl(rho_true)).max()); a.set_xticks(range(4));a.set_yticks(range(4));a.set_xticklabels(lab);a.set_yticklabels(lab);a.set_title(t,fontsize=11)
    for i in range(4):
        for k in range(4): a.text(k,i,f"{abs(M[i,k]):.2f}",ha="center",va="center",color="lime",fontsize=8)
    fig.colorbar(im,ax=a,shrink=0.8)
hm(ax[0],bl(rho_true),"TRUE |ρ|")
hm(ax[1],bl(rho_lsq),f"naive LSQ  (err={errLS:.2f})")
hm(ax[2],bl(rho),f"constrained ML (ρ⪰0)  (err={errML:.2e})")
fig.suptitle(f"T4: constrained ML vs naive LSQ — same {len(Rs)} discrete tilt settings.  ML fidelity={fid:.4f}, min-eig={np.linalg.eigvalsh(rho).min():.1e}",fontsize=12)
fig.savefig(OUT,dpi=120); print("wrote",OUT)
