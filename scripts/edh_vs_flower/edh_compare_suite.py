#!/usr/bin/env python3
"""Does the OBSERVABLE-reconstructed EdH match the TRUE EdH? Dense comparison.
Two reconstructions from forward-modeled tilt-SG data:
  (E) EXACT 3-image (90deg)  -> rank-1 <F> exact (machine precision)
  (R) realistic 5-setting (identity + ±16deg y,x), posture-B linear inversion of
      the priority block -> what a minimal experiment gives
compared field-by-field and metric-by-metric to the TRUE spin texture.
Produces: fields (z=peak), fields (column ∫dz), metrics, per-m densities.
env: PSI13, GOTO, FRAME, OUTDIR"""
import os, numpy as np, h5py
from _floor import mask_from  # FPE_DENSITY_FLOOR (default 0 = full grid)
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
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1)
Ng=psi.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
tms=float(np.asarray(G["t"])[FR])/float(G["meta/omega_ref"][()])*1000; Bz=float(np.asarray(G["B_gauss"])[FR])
# ---- TRUE spin density ----
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
fxT,fyT,fzT=sd(Fx),sd(Fy),sd(Fz)
# ---- EXACT 3-image ----
Ry=expm(+1j*np.pi/2*Fy); Rx=expm(-1j*np.pi/2*Fx)
cen=lambda Nm: np.einsum("xyzm,m->xyz",Nm,ms.astype(float))
fzE=cen(np.abs(psi)**2); fxE=cen(np.abs(np.einsum("mn,xyzn->xyzm",Ry,psi))**2); fyE=cen(np.abs(np.einsum("mn,xyzn->xyzm",Rx,psi))**2)
# ---- realistic 5-setting ±16° posture-B linear (priority-10) ----
BLK=[list(ms).index(m) for m in (-6,-5,-4,-3)]
PRI=[("d",a,a) for a in BLK]+[(t,a,c) for (a,c) in [(BLK[0],BLK[1]),(BLK[1],BLK[2]),(BLK[2],BLK[3])] for t in ("re","im")]
def mat_of(r):
    M=np.zeros((D,D),complex)
    for v,(t,a,c) in zip(r,PRI):
        if t=="d": M[a,a]=v
        elif t=="re": M[a,c]+=v; M[c,a]+=v
        else: M[a,c]+=1j*v; M[c,a]-=1j*v
    return M
SPEC=[("y",0.0),("y",16.0),("y",-16.0),("x",16.0),("x",-16.0)]
Rs=[expm(-1j*np.radians(b)*(Fy if a=="y" else Fx)) for a,b in SPEC]
Mcols=[]
for j in range(len(PRI)):
    e=np.zeros(len(PRI)); e[j]=1; rho=mat_of(e)
    Mcols.append(np.array([np.real(np.diag(R@rho@R.conj().T)) for R in Rs]).reshape(-1))
M=np.array(Mcols).T; Minv=np.linalg.pinv(M)
flat=psi.reshape(-1,D); occ=np.concatenate([np.abs(flat@R.T)**2 for R in Rs],axis=1)
rf=(occ@Minv.T).reshape(Ng,Ng,Ng,len(PRI))
def Frec(Op):
    out=np.zeros((Ng,Ng,Ng))
    for j,(t,a,c) in enumerate(PRI):
        if t=="d": out+=rf[...,j]*np.real(Op[a,a])
        elif t=="re": out+=rf[...,j]*2*np.real(Op[a,c])
        else: out+=rf[...,j]*(2*np.imag(Op[a,c]))   # Tr(rho Op) im-param contribution = +2 Im(Op_ac)
    return out
fzR,fxR,fyR=Frec(Fz),Frec(Fx),Frec(Fy)

# ====== metrics ======
mask=mask_from(n)
def metrics(A,B):
    a=A[mask]; b=B[mask]
    rms=np.sqrt(np.mean((a-b)**2)); mx=np.abs(a-b).max()
    rel=np.linalg.norm(a-b)/max(np.linalg.norm(b),1e-30)
    r=np.corrcoef(a,b)[0,1] if a.std()>0 and b.std()>0 else 1.0
    return rms,mx,rel,r
labels=["⟨Fz⟩","⟨Fx⟩","⟨Fy⟩"]
TRU=[fzT,fxT,fyT]; EXA=[fzE,fxE,fyE]; REA=[fzR,fxR,fyR]
print(f"frame {FR}  t={tms:.1f}ms")
met={}
for lb,t,e,r in zip(labels,TRU,EXA,REA):
    me=metrics(e,t); mr=metrics(r,t); met[lb]=(me,mr)
    print(f"{lb}: exact(rms,max,relL2,corr)={tuple(round(x,4) for x in me)}  5set={tuple(round(x,4) for x in mr)}")

# ====== FIG 1: fields at z=peak ======
zc=int(np.argmax(n.sum(axis=(0,1)))); nn=np.clip(n[:,:,zc],1e-12,None); m2=mask[:,:,zc]
def pa(f): return np.where(m2,f[:,:,zc]/nn,np.nan)
def panel(fig,gs,i,lb,T,E,R):
    cols=[("TRUE",pa(T)),("recon exact 3-img",pa(E)),("recon 5-set ±16°",pa(R)),("|err| 5-set",np.where(m2,np.abs(R-T)[:,:,zc],np.nan))]
    for j,(ttl,im) in enumerate(cols):
        ax=fig.add_subplot(gs[i,j])
        if j<3: h=ax.imshow(im.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        else: h=ax.imshow(im.T,origin="lower",extent=ext,cmap="magma",aspect="equal"); fig.colorbar(h,ax=ax,shrink=0.7)
        if i==0: ax.set_title(ttl,fontsize=10)
        if j==0: ax.set_ylabel(lb,fontsize=12,fontweight="bold")
        ax.set_xticks([]);ax.set_yticks([])
fig=plt.figure(figsize=(13,9.5)); gs=fig.add_gridspec(3,4,hspace=0.08,wspace=0.12)
for i,(lb,T,E,R) in enumerate(zip(labels,TRU,EXA,REA)): panel(fig,gs,i,lb,T,E,R)
fig.suptitle(f"EdH: reconstructed-from-observables vs TRUE — per-atom spin, z=peak slice  (t={tms:.1f} ms, B={Bz*1e3:.3f} mG)",fontsize=12)
fig.savefig(f"{OD}/cmp_fields_zpeak.png",dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote cmp_fields_zpeak.png")

# ====== FIG 2: column-integrated (∫dz, what the camera sees) ======
col=lambda a:a.sum(axis=2); nc=col(n); mc=mask_from(nc); nnc=np.clip(nc,1e-12,None)
def pac(f): return np.where(mc,col(f)/nnc,np.nan)
fig=plt.figure(figsize=(13,9.5)); gs=fig.add_gridspec(3,4,hspace=0.08,wspace=0.12)
for i,(lb,T,E,R) in enumerate(zip(labels,TRU,EXA,REA)):
    cols=[("TRUE",pac(T)),("exact 3-img",pac(E)),("5-set ±16°",pac(R)),("|err| 5-set",np.where(mc,np.abs(col(R)-col(T))/nnc,np.nan))]
    for j,(ttl,im) in enumerate(cols):
        ax=fig.add_subplot(gs[i,j])
        if j<3: ax.imshow(im.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        else: h=ax.imshow(im.T,origin="lower",extent=ext,cmap="magma",aspect="equal"); fig.colorbar(h,ax=ax,shrink=0.7)
        if i==0: ax.set_title(ttl,fontsize=10)
        if j==0: ax.set_ylabel(lb,fontsize=12,fontweight="bold")
        ax.set_xticks([]);ax.set_yticks([])
fig.suptitle(f"EdH: column-integrated (∫dz, absorption-image) spin — reconstructed vs TRUE  (t={tms:.1f} ms)",fontsize=12)
fig.savefig(f"{OD}/cmp_fields_column.png",dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote cmp_fields_column.png")

# ====== FIG 3: metrics ======
fig,ax=plt.subplots(1,3,figsize=(14,4.4),constrained_layout=True)
xl=np.arange(3); w=0.35
for k,(nm,idx) in enumerate([("RMS error",0),("max error",1),("relative L2",2)]):
    ax[k].bar(xl-w/2,[met[l][0][idx] for l in labels],w,label="exact 3-img",color="C0")
    ax[k].bar(xl+w/2,[met[l][1][idx] for l in labels],w,label="5-set ±16°",color="C3")
    ax[k].set_xticks(xl); ax[k].set_xticklabels(labels); ax[k].set_title(nm); ax[k].set_yscale("log"); ax[k].grid(alpha=.3,axis="y")
    if k==0: ax[k].legend()
fig.suptitle("EdH reconstruction agreement metrics (vs TRUE spin density, over the cloud)",fontsize=12)
fig.savefig(f"{OD}/cmp_metrics.png",dpi=130,bbox_inches="tight"); plt.close(fig); print("wrote cmp_metrics.png")

# ====== FIG 4: per-m densities (the raw SG ladder, true) z=peak + column ======
fig,ax=plt.subplots(2,7,figsize=(15,4.6),constrained_layout=True)
for j,(m,c) in enumerate([(mm,list(ms).index(mm)) for mm in range(-6,1)]):
    dm=np.abs(psi[...,c])**2
    a0=ax[0,j]; im=a0.imshow((dm[:,:,zc]/max(dm[:,:,zc].max(),1e-30)).T,origin="lower",extent=ext,cmap="inferno",vmin=0,vmax=1,aspect="equal")
    a0.set_title(f"m={m}\nP={dm.sum()/n.sum()*100:.1f}%",fontsize=9); a0.set_xticks([]);a0.set_yticks([])
    a1=ax[1,j]; a1.imshow((col(dm)/max(col(dm).max(),1e-30)).T,origin="lower",extent=ext,cmap="inferno",vmin=0,vmax=1,aspect="equal"); a1.set_xticks([]);a1.set_yticks([])
    if j==0: a0.set_ylabel("z=peak",fontsize=10); a1.set_ylabel("∫dz",fontsize=10)
fig.suptitle(f"EdH per-m densities n_m(r)=|ψ_m|² (the directly-imaged no-tilt SG ladder)  t={tms:.1f} ms",fontsize=12)
fig.savefig(f"{OD}/cmp_per_m_density.png",dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote cmp_per_m_density.png")
print("DONE")
