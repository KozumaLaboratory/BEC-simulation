#!/usr/bin/env python3
"""Senpai's recipe: ±16° only. Then add ONE more angle and check if precision
improves. psi-free, ideal. Reconstruct <F>(r) via the priority block (4 pop +
3 adjacent coherence = what ±16° y,x determines), compare to truth.
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
BLK=[list(ms).index(m) for m in (-6,-5,-4,-3)]
PRI=[("d",a,a) for a in BLK]+[(t,a,c) for (a,c) in [(BLK[0],BLK[1]),(BLK[1],BLK[2]),(BLK[2],BLK[3])] for t in ("re","im")]
def col_of(par):
    t,a,c=par; M=np.zeros((D,D),complex)
    if t=="d": M[a,a]=1
    elif t=="re": M[a,c]=1;M[c,a]=1
    else: M[a,c]=1j;M[c,a]=-1j
    return M
PM=[col_of(p) for p in PRI]
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n=np.sum(np.abs(psi)**2,axis=-1)
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
fxT,fyT,fzT=sd(Fx),sd(Fy),sd(Fz); mask=n>0.04*n.max()
def lab(settings): return [np.abs(np.einsum("mn,xyzn->xyzm",Rof(*s),psi))**2 for s in settings]
def reconstruct(settings, images):
    Rs=[Rof(*s) for s in settings]
    Mm=np.array([np.concatenate([np.real(np.diag(R@Pm@R.conj().T)) for R in Rs]) for Pm in PM]).T
    Minv=np.linalg.pinv(Mm); cond=np.linalg.cond(Mm)
    rf=np.concatenate(images,axis=-1)@Minv.T
    def Ff(Op):
        out=np.zeros(rf.shape[:3])
        for j,(t,a,c) in enumerate(PRI):
            if t=="d": out+=rf[...,j]*np.real(Op[a,a])
            elif t=="re": out+=rf[...,j]*2*np.real(Op[a,c])
            else: out+=rf[...,j]*(2*np.imag(Op[a,c]))
        return out
    return Ff(Fx),Ff(Fy),Ff(Fz),cond
def errs(fx,fy,fz):
    e=lambda A,B: (np.sqrt(np.mean((A-B)[mask]**2)), np.abs(A-B)[mask].max())
    return e(fx,fxT),e(fy,fyT),e(fz,fzT)
# ===== STEP 1: senpai ±16° only =====
BASE=[("y",0),("y",16),("y",-16),("x",16),("x",-16)]
imgB=lab(BASE); fxB,fyB,fzB,condB=reconstruct(BASE,imgB)
eB=errs(fxB,fyB,fzB)
print(f"±16° only ({len(BASE)} settings, cond={condB:.2f}):")
print(f"  ⟨Fx⟩ rms/max={eB[0][0]:.2e}/{eB[0][1]:.2e}  ⟨Fy⟩ {eB[1][0]:.2e}/{eB[1][1]:.2e}  ⟨Fz⟩ {eB[2][0]:.2e}/{eB[2][1]:.2e}")
# ===== STEP 2: add ONE angle, sweep candidates =====
cands=[("y",8),("y",32),("y",45),("y",60),("y",90),("xy",16),("xy",90)]
rows=[]
for ax,b in cands:
    S=BASE+[(ax,b)]; img=imgB+lab([(ax,b)]); fx,fy,fz,cond=reconstruct(S,img); e=errs(fx,fy,fz)
    maxe=max(e[0][1],e[1][1],e[2][1]); rmse=np.sqrt(np.mean([e[i][0]**2 for i in range(3)]))
    rows.append((f"+{ax}{int(b)}°",cond,rmse,maxe)); print(f"  +({ax},{b}°): cond={cond:.2f}  rms(all)={rmse:.2e}  max={maxe:.2e}")
baseMax=max(eB[0][1],eB[1][1],eB[2][1]); baseRms=np.sqrt(np.mean([eB[i][0]**2 for i in range(3)]))
# ===== FIG =====
ax1d=np.linspace(-L/2,L/2,n.shape[0]); ext=[-L/2,L/2,-L/2,L/2]
zc=int(np.argmax(n.sum(axis=(0,1)))); nn=np.clip(n[:,:,zc],1e-12,None); m2=mask[:,:,zc]
xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,n.shape[0]//14)
pa=lambda f: np.where(m2,f[:,:,zc]/nn,np.nan)
fig=plt.figure(figsize=(13.5,5)); gs=fig.add_gridspec(1,3,width_ratios=[1,1,1.25],wspace=0.25)
def tex(a,fx,fy,fz,title):
    Sz=pa(fz);Sx=pa(fx);Sy=pa(fy);mg=np.hypot(Sx,Sy)
    a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    U=np.where(mg>1e-6,Sx/mg,np.nan);V=np.where(mg>1e-6,Sy/mg,np.nan)
    a.quiver(xx[::st,::st],yy[::st,::st],U[::st,::st],V[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=22,width=0.008,pivot="mid")
    a.set_title(title,fontsize=10);a.set_xticks([]);a.set_yticks([])
tex(fig.add_subplot(gs[0,0]),fxT,fyT,fzT,"TRUTH ⟨F⟩(r)")
tex(fig.add_subplot(gs[0,1]),fxB,fyB,fzB,f"±16° only (5 settings)\nmax err={baseMax:.1e}, cond={condB:.2f}")
axb=fig.add_subplot(gs[0,2])
names=["±16°\nbase"]+[r[0] for r in rows]; mx=[baseMax]+[r[3] for r in rows]
xpos=np.arange(len(names)); cols=["C7"]+["C0" if mxx<baseMax else "C3" for mxx in mx[1:]]
axb.bar(xpos,mx,color=cols); axb.axhline(baseMax,ls=":",c="C7",label="±16° baseline")
axb.set_xticks(xpos); axb.set_xticklabels(names,fontsize=7.5,rotation=0); axb.set_yscale("log")
axb.set_ylabel("max ⟨F⟩ error vs truth"); axb.set_title("does adding ONE angle improve precision?"); axb.legend(fontsize=8); axb.grid(alpha=.3,axis="y")
fig.suptitle("Senpai's ±16° recipe, then +1 angle — ψ-free reconstruction (EdH, ideal)",fontsize=12)
fig.savefig(f"{OD}/senpai_pm16.png",dpi=130,bbox_inches="tight"); print("wrote senpai_pm16.png")
