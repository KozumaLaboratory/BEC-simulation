#!/usr/bin/env python3
"""Q1: at ±16°, does the tilt DIRECTION matter?  Q2: does ADDING angles improve
precision (and for what)?  psi-free, ideal.
Panel A (field): reconstruct <F>(r) with ±16° about different DIRECTION sets.
Panel B (voxel): full-13 rho by ML vs #settings -> rank-1 <F> saturates fast,
but rank-2 nematic & full-rho keep improving as angles (dirs+magnitudes) are added.
env: PSI13, FRAME, OUTDIR"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); FR=int(os.environ.get("FRAME","100")); OD=os.environ.get("OUTDIR",".")
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
def Raxis(nx,ny,nz,beta): return expm(-1j*np.radians(beta)*(nx*Fx+ny*Fy+nz*Fz))
def Rphi(phi,beta): return Raxis(np.cos(np.radians(phi)),np.sin(np.radians(phi)),0,beta)  # in-plane axis at azimuth phi
P=h5py.File(PSI,"r")
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1); mask=n>0.04*n.max()
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
fxT,fyT,fzT=sd(Fx),sd(Fy),sd(Fz)
# ---------- Panel A: direction coverage at ±16° (4-level <F>) ----------
BLK=[list(ms).index(m) for m in (-6,-5,-4,-3)]
PRI=[("d",a,a) for a in BLK]+[(t,a,c) for (a,c) in [(BLK[0],BLK[1]),(BLK[1],BLK[2]),(BLK[2],BLK[3])] for t in ("re","im")]
def col_of(par):
    t,a,c=par; M=np.zeros((D,D),complex)
    if t=="d": M[a,a]=1
    elif t=="re": M[a,c]=1;M[c,a]=1
    else: M[a,c]=1j;M[c,a]=-1j
    return M
PM=[col_of(p) for p in PRI]
def recon_field(Rs):
    Mm=np.array([np.concatenate([np.real(np.diag(R@Pm@R.conj().T)) for R in Rs]) for Pm in PM]).T
    Minv=np.linalg.pinv(Mm)
    occ=np.concatenate([np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2 for R in Rs],axis=-1)
    rf=occ@Minv.T
    def Ff(Op):
        out=np.zeros(rf.shape[:3])
        for j,(t,a,c) in enumerate(PRI):
            if t=="d": out+=rf[...,j]*np.real(Op[a,a])
            elif t=="re": out+=rf[...,j]*2*np.real(Op[a,c])
            else: out+=rf[...,j]*(2*np.imag(Op[a,c]))
        return out
    return Ff(Fx),Ff(Fy),Ff(Fz)
ident=np.eye(D)
DIRSETS={
 "±16° about y ONLY\n(1 direction)":[ident,Rphi(90,16),Rphi(90,-16)],
 "±16° about y & x\n(2 directions)":[ident,Rphi(90,16),Rphi(90,-16),Rphi(0,16),Rphi(0,-16)],
 "±16° about 4 azimuths\n(0,45,90,135°)":[ident]+[Rphi(p,s) for p in (0,45,90,135) for s in (16,-16)],
}
em=lambda A,B: np.abs(A-B)[mask].max()
Ares={}
for name,Rs in DIRSETS.items():
    fx,fy,fz=recon_field(Rs); Ares[name]=(em(fx,fxT),em(fy,fyT),em(fz,fzT))
    print(f"[A] {name.splitlines()[0]:24s}: errFx={Ares[name][0]:.2e} errFy={Ares[name][1]:.2e} errFz={Ares[name][2]:.2e}")
# ---------- Panel B: full-13 rho by ML vs #settings (voxel) ----------
score=np.abs(psi[...,11])*np.abs(psi[...,12]); ix=np.unravel_index(np.argmax(score),score.shape)
zeta=psi[ix].copy(); zeta/=np.linalg.norm(zeta); rho_true=np.outer(zeta,zeta.conj())
Qnem=Fx@Fx-Fy@Fy   # a rank-2 nematic component
def ml_full(Rs):
    Pi=[]; fd=[]
    for R in Rs:
        occ=np.abs(R@zeta)**2
        for m in range(D):
            e=np.zeros(D); e[m]=1; Pi.append(R.conj().T@np.outer(e,e)@R); fd.append(occ[m])
    Pi=np.array(Pi); fd=np.array(fd); rho=np.eye(D,dtype=complex)/D
    for _ in range(400):
        p=np.maximum(np.array([np.real(np.trace(rho@Pim)) for Pim in Pi]),1e-12)
        Rop=np.tensordot(fd/p,Pi,axes=(0,0)); rho=Rop@rho@Rop; rho=(rho+rho.conj().T)/2; rho/=np.real(np.trace(rho))
    return rho
# schedule: start ±16 (y,x), then ADD directions+magnitudes toward informational completeness
SCHED=[("y",0)]
SCHED+=[("y",16),("x",16),("y",-16),("x",-16)]                      # senpai ±16
for b in [32,48,64,80]:
    SCHED+=[("y",b),("x",b),("xy",b)]                               # add magnitudes & 3rd dir
for b in [104,120,140,160]:
    SCHED+=[("y",b),("x",b),("xy",b)]
axmap={"y":(0,1,0),"x":(1,0,0),"xy":(1/np.sqrt(2),1/np.sqrt(2),0)}
def Rof(ax,b): nx,ny,nz=axmap[ax]; return Raxis(nx,ny,nz,b)
ks=list(range(1,len(SCHED)+1))
eF=[];eN=[];eR=[]
for k in ks:
    Rs=[Rof(*s) for s in SCHED[:k]]
    rho=ml_full(Rs)
    eF.append(abs(np.real(np.trace(rho@Fx))-np.real(zeta.conj()@Fx@zeta)))
    eN.append(abs(np.real(np.trace(rho@Qnem))-np.real(zeta.conj()@Qnem@zeta)))
    eR.append(np.abs(rho-rho_true).max())
print(f"[B] settings 5(±16) -> {len(SCHED)}: <F>err {eF[4]:.1e}->{eF[-1]:.1e}  nematic {eN[4]:.1e}->{eN[-1]:.1e}  fullrho {eR[4]:.1e}->{eR[-1]:.1e}")
# ---------- FIGURE ----------
fig,ax=plt.subplots(1,2,figsize=(13,5),constrained_layout=True)
names=list(Ares.keys()); xl=np.arange(len(names)); w=0.26
for i,(lb,c) in enumerate([("⟨Fx⟩","C0"),("⟨Fy⟩","C1"),("⟨Fz⟩","C2")]):
    ax[0].bar(xl+(i-1)*w,[Ares[nm][i] for nm in names],w,label=lb,color=c)
ax[0].set_yscale("log"); ax[0].set_xticks(xl); ax[0].set_xticklabels(names,fontsize=8)
ax[0].set_ylabel("max error vs truth"); ax[0].set_title("Q1: ±16° — does DIRECTION matter?\n(y-only misses ⟨Fy⟩; need ≥2 directions)"); ax[0].legend(fontsize=9); ax[0].grid(alpha=.3,axis="y")
ax[1].semilogy(ks,np.maximum(eF,1e-17),"o-",label="rank-1 ⟨F⟩ (texture)")
ax[1].semilogy(ks,np.maximum(eN,1e-17),"s-",label="rank-2 nematic ⟨Fx²−Fy²⟩")
ax[1].semilogy(ks,np.maximum(eR,1e-17),"^-",label="full ρ (all ranks)")
ax[1].axvline(5,ls=":",c="gray"); ax[1].text(5.2,1e-2,"±16° (5 settings)",rotation=90,fontsize=8,color="gray")
ax[1].set_xlabel("# settings (adding directions & magnitudes)"); ax[1].set_ylabel("reconstruction error")
ax[1].set_title("Q2: adding angles improves precision —\nrank-1 saturates fast; higher ranks keep improving"); ax[1].legend(fontsize=9); ax[1].grid(alpha=.3)
fig.suptitle("±16° direction coverage, and what adding measurement angles buys (ψ-free, EdH ideal)",fontsize=12)
fig.savefig(f"{OD}/add_angles_improve.png",dpi=130,bbox_inches="tight"); print("wrote add_angles_improve.png")
