#!/usr/bin/env python3
"""EdH vs Flower across many observables (z=peak): <Fz>, |F_perp|, local Lz density,
rank-2 nematic magnitude. Ground truth from full psi (matched v3 pair).
env: EDH, FLOWER, OUT"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
EDH=os.environ.get("EDH","edh_v3_psi13.jld2"); FLW=os.environ.get("FLOWER","flower_v3_psi13.jld2")
OUT=os.environ.get("OUT","gallery_compare_obs.png")
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Qxx=Fx@Fx-Fy@Fy; Qxy=0.5*(Fx@Fy+Fy@Fx); Qzz=Fz@Fz-(F*(F+1)/3)*np.eye(D)
def load(fn):
    Pf=h5py.File(fn,"r"); L=float(Pf["meta/L_box"][()]); nf=np.asarray(Pf["psi_re_c01"]).shape[-1]; fr=nf-1
    def comp(c):
        re=np.transpose(np.asarray(Pf[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]
        im=np.transpose(np.asarray(Pf[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr]
        return re+1j*im
    psi=np.stack([comp(c) for c in range(1,14)],axis=-1); return psi,L,fr
def obs(psi,L):
    n=np.sum(np.abs(psi)**2,axis=-1); zc=int(np.argmax(n.sum(axis=(0,1))))
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    fx,fy,fz=sd(Fx),sd(Fy),sd(Fz)
    nn=np.clip(n[:,:,zc],1e-12,None); m2=n[:,:,zc]>0.04*n[:,:,zc].max()
    Fzp=np.where(m2,fz[:,:,zc]/nn,np.nan)
    Fperp=np.where(m2,np.hypot(fx,fy)[:,:,zc]/nn,np.nan)
    # local Lz density (orbital): Im(psi* (x dy - y dx) psi) summed over m
    Ng=psi.shape[0]; x=np.linspace(-L/2,L/2,Ng,endpoint=False); dx=x[1]-x[0]; k=2*np.pi*np.fft.fftfreq(Ng,d=dx); Xg,Yg=np.meshgrid(x,x,indexing="ij")
    lz=np.zeros((Ng,Ng))
    for c in range(D):
        a=psi[:,:,zc,c]
        day=np.fft.ifft(1j*k[None,:]*np.fft.fft(a,axis=1),axis=1); dax=np.fft.ifft(1j*k[:,None]*np.fft.fft(a,axis=0),axis=0)
        lz+=np.real(np.conj(a)*(-1j)*(Xg*day-Yg*dax))
    Lzp=np.where(m2,lz,np.nan)
    nem=np.where(m2,(np.sqrt(sd(Qxx)**2+(2*sd(Qxy))**2)[:,:,zc])/nn,np.nan)  # in-plane nematic magnitude
    return dict(L=L,Fz=Fzp,Fperp=Fperp,Lz=Lzp,nem=nem,
                Lz_tot=lz.sum()/n[:,:,zc].sum(),Fz_tot=np.nansum(fz)/n.sum())
psiE,LE,frE=load(EDH); psiF,LF,frF=load(FLW)
oE=obs(psiE,LE); oF=obs(psiF,LF)
rows=[("⟨Fz⟩ (per atom)","Fz","RdBu_r",(-6,6)),
      ("|⟨F⊥⟩| transverse spin","Fperp","viridis",(0,4)),
      ("local Lz density (orbital)","Lz","seismic",None),
      ("rank-2 nematic |N⊥|","nem","magma",None)]
fig,ax=plt.subplots(4,2,figsize=(7.6,13.2),constrained_layout=True)
for r,(title,key,cmap,clim) in enumerate(rows):
    for cI,(o,nm) in enumerate([(oE,"EdH"),(oF,"Flower")]):
        ext=[-o["L"]/2,o["L"]/2,-o["L"]/2,o["L"]/2]; a=ax[r,cI]; img=o[key]
        vlim=clim if clim else (-np.nanmax(np.abs(img)),np.nanmax(np.abs(img))) if cmap=="seismic" else (0,np.nanmax(img))
        im=a.imshow(img.T,origin="lower",extent=ext,cmap=cmap,vmin=vlim[0],vmax=vlim[1],aspect="equal")
        a.set_xticks([]);a.set_yticks([])
        if r==0: a.set_title(nm,fontsize=12,fontweight="bold")
        if cI==0: a.set_ylabel(title,fontsize=10)
        fig.colorbar(im,ax=a,shrink=0.7)
fig.suptitle(f"EdH vs Flower — spin observables (z=peak, final state)\n"
             f"EdH: ⟨Lz⟩={oE['Lz_tot']:+.2f}, ⟨Fz⟩={oE['Fz_tot']:+.2f}   Flower: ⟨Lz⟩={oF['Lz_tot']:+.2f}, ⟨Fz⟩={oF['Fz_tot']:+.2f}",fontsize=11)
fig.savefig(OUT,dpi=120,bbox_inches="tight"); print(f"wrote {OUT}")
