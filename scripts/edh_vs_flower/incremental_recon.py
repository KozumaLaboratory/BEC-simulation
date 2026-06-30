#!/usr/bin/env python3
"""Add tilt angles ONE AT A TIME and watch the psi-free reconstruction converge to
truth, checked by many indicators: xy slice, zx slice, spin texture, per-m, metrics.
Ideal (noiseless), psi-free: reconstruction sees ONLY the SG population fields.
env: PSI13, GOTO, FRAME, OUTDIR"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
FR=int(os.environ.get("FRAME","100")); OD=os.environ.get("OUTDIR",".")
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
def Rof(ax,b): return expm(-1j*np.radians(b)*({"y":Fy,"x":Fx,"xy":(Fx+Fy)/np.sqrt(2)}[ax]))
# incremental schedule: what an experimenter adds, in order
SCHED=[("y",0),("y",90),("x",90),("y",45),("x",45),("xy",90),("y",135),("x",135),
       ("xy",45),("y",30),("x",30),("xy",135),("y",60),("x",60),("y",120),("x",120),
       ("y",150),("x",150),("y",15),("x",15)]
BLK=[list(ms).index(m) for m in (-6,-5,-4,-3)]
pairs=[(BLK[i],BLK[j]) for i in range(4) for j in range(i+1,4)]
ps=[("d",a,a) for a in BLK]+[(t,a,c) for (a,c) in pairs for t in ("re","im")]
def col_of(par):
    t,a,c=par; M=np.zeros((D,D),complex)
    if t=="d": M[a,a]=1
    elif t=="re": M[a,c]=1;M[c,a]=1
    else: M[a,c]=1j;M[c,a]=-1j
    return M
PMATS=[col_of(p) for p in ps]
# ---- load + truth + lab images for all scheduled settings ----
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1)
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
fxT,fyT,fzT=sd(Fx),sd(Fy),sd(Fz)
Rs=[Rof(*s) for s in SCHED]
IMGS=[np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2 for R in Rs]   # lab populations
del psi   # psi-free from here
Ng=n.shape[0]; mask=n>0.04*n.max()
# ---- reconstruct rho^(4) from first k settings (psi-free, min-norm pinv) ----
def Mblock(kk):
    cols=[]
    for Pm in PMATS:
        cols.append(np.concatenate([np.real(np.diag(R@Pm@R.conj().T)) for R in Rs[:kk]]))
    return np.array(cols).T
def Ffield(rf,Op):
    out=np.zeros(rf.shape[:3])
    for j,(t,a,c) in enumerate(ps):
        if t=="d": out+=rf[...,j]*np.real(Op[a,a])
        elif t=="re": out+=rf[...,j]*2*np.real(Op[a,c])
        else: out+=rf[...,j]*(2*np.imag(Op[a,c]))
    return out
def reconstruct(kk):
    M=Mblock(kk); Minv=np.linalg.pinv(M)
    Pstack=np.concatenate([IMGS[i] for i in range(kk)],axis=-1)
    rf=Pstack@Minv.T
    return Ffield(rf,Fx),Ffield(rf,Fy),Ffield(rf,Fz),rf
def err(A,B): return np.abs(A-B)[mask].max()
def rms(A,B): return np.sqrt(np.mean((A-B)[mask]**2))
K=len(SCHED); eFx=np.zeros(K);eFy=np.zeros(K);eFz=np.zeros(K)
recons={}
for kk in range(1,K+1):
    fx,fy,fz,rf=reconstruct(kk); eFx[kk-1]=err(fx,fxT);eFy[kk-1]=err(fy,fyT);eFz[kk-1]=err(fz,fzT)
    if kk in (1,2,3,4,6,8,K): recons[kk]=(fx,fy,fz)
# full-13 EXACT centroid (no block truncation): <Fz> from identity, <Fx> from y90, <Fy> from x90
cen=lambda i: np.einsum("xyzm,m->xyz",IMGS[i],ms.astype(float))
def first_with(ax,b):
    for i,s in enumerate(SCHED):
        if s==(ax,b): return i
    return None
i_id,i_y90,i_x90=first_with("y",0),first_with("y",90),first_with("x",90)
exFx=np.full(K,err(0*fxT,fxT));exFy=np.full(K,err(0*fyT,fyT));exFz=np.full(K,1.0)
for kk in range(1,K+1):
    avail=set(range(kk))
    exFz[kk-1]=err(cen(i_id),fzT) if i_id in avail else 1.0
    exFx[kk-1]=err(-cen(i_y90),fxT) if i_y90 in avail else err(0*fxT,fxT)   # R_y(+90)->-Fx, so negate
    exFy[kk-1]=err(cen(i_x90),fyT) if i_x90 in avail else err(0*fyT,fyT)
print("k : setting added           errFx     errFy     errFz")
for kk in range(1,K+1):
    print(f"{kk:2d}: {str(SCHED[kk-1]):16s}   {eFx[kk-1]:.2e}  {eFy[kk-1]:.2e}  {eFz[kk-1]:.2e}")

# ===== FIG 1: convergence curves =====
fig,ax=plt.subplots(figsize=(8.6,5),constrained_layout=True)
kk=np.arange(1,K+1)
ax.semilogy(kk,np.maximum(eFx,1e-18),"o-",c="C0",label="⟨Fx⟩ — 4-level block"); ax.semilogy(kk,np.maximum(eFy,1e-18),"s-",c="C1",label="⟨Fy⟩ — 4-level block"); ax.semilogy(kk,np.maximum(eFz,1e-18),"^-",c="C2",label="⟨Fz⟩ — 4-level block")
ax.semilogy(kk,np.maximum(exFx,1e-18),"o--",c="C0",alpha=0.5,label="⟨Fx⟩ — full-13 centroid (exact)"); ax.semilogy(kk,np.maximum(exFy,1e-18),"s--",c="C1",alpha=0.5); ax.semilogy(kk,np.maximum(exFz,1e-18),"^--",c="C2",alpha=0.5)
ax.text(K*0.5,3e-3,"4-level block floor ≈ 2.5e-3\n(truncation: 12% leaks to m≤-2)",fontsize=8,color="gray")
ax.text(K*0.5,1e-14,"full-13 centroid → machine precision",fontsize=8,color="gray")
for kk0,lab in [(2,"+y90→⟨Fx⟩"),(3,"+x90→⟨Fy⟩"),(6,"+in-plane→remote coh")]:
    ax.axvline(kk0,ls=":",c="gray"); ax.text(kk0+0.1,1e-2,lab,rotation=90,fontsize=8,color="gray",va="bottom")
ax.set_xlabel("# tilt settings (added one at a time)"); ax.set_ylabel("max reconstruction error (vs truth)")
ax.set_title("psi-free reconstruction converges as angles are added (EdH, ideal)"); ax.legend(); ax.grid(alpha=.3)
ax.set_xticks(kk); ax.set_xticklabels([f"{i}\n{SCHED[i-1][0]}{int(SCHED[i-1][1])}" for i in kk],fontsize=6.5)
fig.savefig(f"{OD}/inc_convergence.png",dpi=130); plt.close(fig); print("wrote inc_convergence.png")

# ===== FIG 2: xy-slice texture grid (truth + selected k) =====
ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
zc=int(np.argmax(n.sum(axis=(0,1)))); nnz=np.clip(n[:,:,zc],1e-12,None); m2=mask[:,:,zc]
yc=Ng//2; nny=np.clip(n[:,yc,:],1e-12,None); m2zx=mask[:,yc,:]
xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//14)
def texpanel(a,fx,fy,fz,sl,axis,title):
    if axis=="xy": Sz=np.where(m2,fz[:,:,zc]/nnz,np.nan);Sx=np.where(m2,fx[:,:,zc]/nnz,np.nan);Sy=np.where(m2,fy[:,:,zc]/nnz,np.nan)
    else: Sz=np.where(m2zx,fz[:,yc,:]/nny,np.nan);Sx=np.where(m2zx,fx[:,yc,:]/nny,np.nan);Sy=np.where(m2zx,fz[:,yc,:]*0/nny,np.nan)  # zx uses Fx,Fz
    im=a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    if axis=="xy":
        mg=np.hypot(Sx,Sy);U=np.where(mg>1e-6,Sx/mg,np.nan);V=np.where(mg>1e-6,Sy/mg,np.nan)
        a.quiver(xx[::st,::st],yy[::st,::st],U[::st,::st],V[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=22,width=0.008,pivot="mid")
    a.set_title(title,fontsize=8.5);a.set_xticks([]);a.set_yticks([]); return im
ks=sorted(recons.keys()); cols=[("truth",None)]+[(f"k={k}",k) for k in ks]
fig,axg=plt.subplots(2,len(cols),figsize=(2.0*len(cols),4.4),constrained_layout=True)
for j,(lab,k) in enumerate(cols):
    fx,fy,fz=(fxT,fyT,fzT) if k is None else recons[k]
    texpanel(axg[0,j],fx,fy,fz,zc,"xy",("TRUTH " if k is None else "")+f"{lab}\n⟨F⟩ xy (z=peak)")
    texpanel(axg[1,j],fx,fy,fz,yc,"zx",f"⟨Fz⟩ zx (y=0)")
fig.suptitle("xy spin texture (top) and zx ⟨Fz⟩ (bottom): convergence as angles are added (ψ-free)",fontsize=11)
fig.savefig(f"{OD}/inc_texture_grid.png",dpi=125); plt.close(fig); print("wrote inc_texture_grid.png")

# ===== FIG 3: per-component field + error at k=1,3,6,full =====
fig,axg=plt.subplots(3,5,figsize=(13,7.6),constrained_layout=True)
showk=[1,3,6,K]; comps=[("⟨Fx⟩",fxT,0),("⟨Fy⟩",fyT,1),("⟨Fz⟩",fzT,2)]
for r,(lb,T,ci) in enumerate(comps):
    axg[r,0].imshow(np.where(m2,T[:,:,zc]/nnz,np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    axg[r,0].set_ylabel(lb,fontsize=12,fontweight="bold");axg[r,0].set_xticks([]);axg[r,0].set_yticks([])
    if r==0: axg[r,0].set_title("TRUTH",fontsize=9)
    for j,k in enumerate(showk):
        fx,fy,fz,_=reconstruct(k); R=[fx,fy,fz][ci]
        axg[r,j+1].imshow(np.where(m2,R[:,:,zc]/nnz,np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        axg[r,j+1].set_xticks([]);axg[r,j+1].set_yticks([])
        if r==0: axg[r,j+1].set_title(f"k={k}",fontsize=9)
fig.suptitle("Per-component ⟨Fx⟩,⟨Fy⟩,⟨Fz⟩ (z=peak, per atom): truth vs reconstruction at k=1,3,6,full",fontsize=11)
fig.savefig(f"{OD}/inc_per_component.png",dpi=120); plt.close(fig); print("wrote inc_per_component.png")
print("DONE")
