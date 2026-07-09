#!/usr/bin/env python3
"""Time-resolved: reconstructed-from-observables EdH vs TRUE EdH, with live metrics.
Left = TRUE <F>(r), mid = recon 5-set ±16°, right-top = per-component correlation &
RMS vs t, right-bottom = global <Fz> and <Lz> (true vs recon-accessible) vs t.
env: PSI13, GOTO, OUT, DUR, FPS"""
import os, sys, numpy as np, h5py
from _floor import mask_from  # FPE_DENSITY_FLOOR (default 0 = full grid)
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
sys.path.insert(0,"/Users/mitsuki/Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/scripts/flower_protocol_edh")
from _anim_writer import save_matplotlib_anim, expanded_frame_indices
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
OUT=os.environ.get("OUT","edh_compare_anim.mp4"); DUR=float(os.environ.get("DUR","18")); FPS=int(os.environ.get("FPS","20"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
RE=[np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3)) for c in range(1,14)]
IM=[np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3)) for c in range(1,14)]
NT=np.transpose(np.asarray(P["n_total_3d"]),(2,1,0,3))
tarr=np.asarray(G["t"])/float(G["meta/omega_ref"][()])*1000; Barr=np.asarray(G["B_gauss"])
NF=NT.shape[-1]; Ng=NT.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//16)
# 5-set posture-B linear map
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
def Frec(rf,Op):
    out=np.zeros(rf.shape[:3])
    for j,(t,a,c) in enumerate(PRI):
        if t=="d": out+=rf[...,j]*np.real(Op[a,a])
        elif t=="re": out+=rf[...,j]*2*np.real(Op[a,c])
        else: out+=rf[...,j]*(2*np.imag(Op[a,c]))
    return out
def spinor(k): return np.stack([RE[c][...,k]+1j*IM[c][...,k] for c in range(13)],axis=-1)
def Lz_tot(psi):
    x=np.linspace(-L/2,L/2,Ng,endpoint=False); dx=x[1]-x[0]; kk=2*np.pi*np.fft.fftfreq(Ng,d=dx); X,Y=np.meshgrid(x,x,indexing="ij")
    lz=0.0; nrm=0.0
    for c in range(D):
        a=psi[...,c]
        day=np.fft.ifft(1j*kk[None,:,None]*np.fft.fft(a,axis=1),axis=1); dax=np.fft.ifft(1j*kk[:,None,None]*np.fft.fft(a,axis=0),axis=0)
        lz+=np.real(np.sum(np.conj(a)*(-1j)*(X[...,None]*day-Y[...,None]*dax))); nrm+=np.real(np.sum(np.abs(a)**2))
    return lz/nrm
# precompute
SLT=[]; SLR=[]; corr=np.zeros((NF,3)); rms=np.zeros((NF,3)); Fzt=np.zeros(NF); Lzt=np.zeros(NF)
for k in range(NF):
    psi=spinor(k); n=NT[...,k]; mask=mask_from(n)
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    fT=[sd(Fx),sd(Fy),sd(Fz)]
    rf=(np.concatenate([np.abs(psi.reshape(-1,D)@R.T)**2 for R in Rs],axis=1)@Minv.T).reshape(Ng,Ng,Ng,len(PRI))
    fR=[Frec(rf,Fx),Frec(rf,Fy),Frec(rf,Fz)]
    for i in range(3):
        a=fR[i][mask]; b=fT[i][mask]; rms[k,i]=np.sqrt(np.mean((a-b)**2))
        corr[k,i]=np.corrcoef(a,b)[0,1] if a.std()>1e-12 and b.std()>1e-12 else 1.0
    Fzt[k]=sd(Fz).sum()/n.sum(); Lzt[k]=Lz_tot(psi)
    sl=int(np.argmax(n.sum(axis=(0,1)))); nn=np.clip(n[:,:,sl],1e-12,None); m2=mask[:,:,sl]
    pa=lambda f: np.where(m2,f[:,:,sl]/nn,np.nan)
    SLT.append((pa(fT[0]),pa(fT[1]),pa(fT[2]))); SLR.append((pa(fR[0]),pa(fR[1]),pa(fR[2])))
print(f"precompute done. mean corr Fx/Fy/Fz = {corr.mean(0).round(3)}")
fig=plt.figure(figsize=(14,5.4)); gs=fig.add_gridspec(2,3,width_ratios=[1,1,1.15],hspace=0.42,wspace=0.26)
axT=fig.add_subplot(gs[:,0]); axR=fig.add_subplot(gs[:,1]); axM=fig.add_subplot(gs[0,2]); axG=fig.add_subplot(gs[1,2])
def tex(ax,S,title):
    ax.clear(); Sx,Sy,Sz=S
    im=ax.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    mg=np.hypot(Sx,Sy); U=np.where(mg>1e-6,Sx/mg,np.nan); V=np.where(mg>1e-6,Sy/mg,np.nan); sub=(slice(None,None,st),)*2
    ax.quiver(xx[sub],yy[sub],U[sub],V[sub],mg[sub],cmap="Greys",clim=(0,6),scale=24,width=0.007,headwidth=4,pivot="mid")
    ax.set_title(title,fontsize=10); ax.set_xticks([]);ax.set_yticks([]); return im
def draw(k):
    tex(axT,SLT[k],"TRUE ⟨F⟩(r)")
    tex(axR,SLR[k],"recon 5-set ±16° (from SG images)")
    axM.clear()
    for i,(lb,c) in enumerate([("Fx","C0"),("Fy","C1"),("Fz","C2")]):
        axM.plot(tarr[:k+1],corr[:k+1,i],c=c,label=f"corr {lb}")
    axM.set_ylim(0.7,1.005); axM.set_xlim(tarr[0],tarr[-1]); axM.axhline(1,ls=":",c="gray",lw=0.6)
    axM.set_ylabel("spatial correlation"); axM.legend(fontsize=7,ncol=3,loc="lower right"); axM.set_title("recon↔true agreement",fontsize=9); axM.grid(alpha=.3)
    axG.clear()
    axG.plot(tarr[:k+1],Fzt[:k+1],"C4",label="⟨Fz⟩ (all-ch)"); axG.plot(tarr[:k+1],Lzt[:k+1],"C3",label="⟨Lz⟩ (orbital)")
    axG.set_xlim(tarr[0],tarr[-1]); axG.set_ylim(-6.3,1.0); axG.axhline(0,c="k",lw=0.5)
    axG.set_xlabel("t [ms]"); axG.legend(fontsize=8,loc="center right"); axG.set_title("global: spin→orbital transfer",fontsize=9); axG.grid(alpha=.3)
    fig.suptitle(f"EdH reconstructed-from-observables vs TRUE   t={tarr[k]:.1f} ms  B={Barr[k]*1e3:.3f} mG   "
                 f"corr(Fx,Fy,Fz)=({corr[k,0]:.3f},{corr[k,1]:.3f},{corr[k,2]:.3f})",fontsize=11)
idx=expanded_frame_indices(NF,DUR,FPS)
anim=FuncAnimation(fig,draw,frames=idx,interval=1000/FPS)
save_matplotlib_anim(anim,OUT,fps=FPS)
print("wrote",OUT)
