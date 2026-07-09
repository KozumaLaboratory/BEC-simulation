#!/usr/bin/env python3
"""Validate the ±16° observation protocol on THREE states:
  (1) 10mG initial GS  -> should recover pure m=-6: <F>=(0,0,-6)
  (2) EdH dynamics (transient tilt)
  (3) Flower @120uG
Protocol (visible block V={-6,-5,-4,-3}, angle th=16deg):
  <Fz>(r) = sum_{m in V} m n_m^{(0)} / sum n_m^{(0)}                [no tilt]
  <Fx>(r) = -(s_y^{+th}-s_y^{-th})/(2 sin th)   s_y = R_y(±th) visible centroid
  <Fy>(r) = +(s_x^{+th}-s_x^{-th})/(2 sin th)   s_x = R_x(±th) visible centroid
Compare reconstructed <F> to truth Tr(rho F)/n.  env: OUTDIR"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
OD=os.environ.get("OUTDIR",".")
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Ry=lambda b: expm(-1j*np.radians(b)*Fy); Rx=lambda b: expm(-1j*np.radians(b)*Fx)
VIS=[list(ms).index(m) for m in (-6,-5,-4,-3)]; ms_v=ms[VIS].astype(float); th=16.0; s16=np.sin(np.radians(th))
def loadframe(fn,fr):
    P=h5py.File(fn,"r"); L=float(P["meta/L_box"][()]); nf=np.asarray(P["psi_re_c01"]).shape[-1]
    fr=fr if fr>=0 else nf+fr
    psi=np.stack([np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]+1j*np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr] for c in range(1,14)],axis=-1)
    return psi,L
def cenvis(psi,R):
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,VIS]; return np.einsum("xyzm,m->xyz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
def reconstruct(psi):
    n=np.sum(np.abs(psi)**2,axis=-1)
    fz=cenvis(psi,np.eye(D))
    fx=-(cenvis(psi,Ry(+th))-cenvis(psi,Ry(-th)))/(2*s16)
    fy=+(cenvis(psi,Rx(+th))-cenvis(psi,Rx(-th)))/(2*s16)
    return fx,fy,fz,n
def truth(psi,n):
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    return sd(Fx)/np.clip(n,1e-30,None),sd(Fy)/np.clip(n,1e-30,None),sd(Fz)/np.clip(n,1e-30,None)
TESTS=[("(1) 10mG GS (m=-6)","edh_v5_psi13.jld2",0),
       ("(2) EdH dynamics (t~26ms)","edh_v5_psi13.jld2",100),
       ("(3) Flower @120uG","flower_v3_psi13.jld2",-1)]
fig,ax=plt.subplots(3,3,figsize=(11.5,11),constrained_layout=True)
for r,(lab,fn,fr) in enumerate(TESTS):
    psi,L=loadframe(fn,fr); fxR,fyR,fzR,n=reconstruct(psi); fxT,fyT,fzT=truth(psi,n)
    mask=n>0.04*n.max(); zc=int(np.argmax(n.sum(axis=(0,1)))); nn=np.clip(n[:,:,zc],1e-30,None); m2=mask[:,:,zc]
    def corr(A,B): a=A[mask];b=B[mask]; return np.corrcoef(a,b)[0,1] if a.std()>1e-9 and b.std()>1e-9 else 1.0
    cx,cy,cz=corr(fxR,fxT),corr(fyR,fyT),corr(fzR,fzT)
    ez=np.abs(fzR-fzT)[mask].max(); ex=np.abs(fxR-fxT)[mask].max(); ey=np.abs(fyR-fyT)[mask].max()
    fzg=(fzT*n)[mask].sum()/n[mask].sum()
    print(f"{lab}: <Fz>_mean={fzg:+.3f}  corr(Fx,Fy,Fz)=({cx:+.3f},{cy:+.3f},{cz:+.3f})  maxerr(Fx,Fy,Fz)=({ex:.2f},{ey:.2f},{ez:.2f})")
    ext=[-L/2,L/2,-L/2,L/2]; Ng=n.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng); xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//14)
    def tex(a,fx,fy,fz,title):
        Sz=np.where(m2,fz[:,:,zc]/nn,np.nan);Sx=np.where(m2,fx[:,:,zc]/nn,np.nan);Sy=np.where(m2,fy[:,:,zc]/nn,np.nan);mg=np.hypot(Sx,Sy)
        im=a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        U=np.where(mg>1e-6,Sx/mg,np.nan);V=np.where(mg>1e-6,Sy/mg,np.nan)
        a.quiver(xx[::st,::st],yy[::st,::st],U[::st,::st],V[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=22,width=0.008,pivot="mid")
        a.set_title(title,fontsize=9);a.set_xticks([]);a.set_yticks([]); return im
    # tex uses per-atom fields; pass raw (divided inside)
    tex(ax[r,0],fxT,fyT,fzT,("TRUTH ⟨F⟩(r)\n"+lab))
    tex(ax[r,1],fxR,fyR,fzR,f"reconstructed [±16° protocol]")
    em=np.where(m2,np.sqrt((fxR-fxT)**2+(fyR-fyT)**2+(fzR-fzT)**2)[:,:,zc],np.nan)
    im=ax[r,2].imshow(em.T,origin="lower",extent=ext,cmap="magma",aspect="equal"); ax[r,2].set_xticks([]);ax[r,2].set_yticks([])
    ax[r,2].set_title(f"|err|  corr(Fx,Fy,Fz)=\n({cx:.2f},{cy:.2f},{cz:.2f})",fontsize=9); fig.colorbar(im,ax=ax[r,2],shrink=0.7)
fig.suptitle("±16° observation-protocol validation on 3 states (z=peak, visible block, ψ-free)",fontsize=12)
fig.savefig(f"{OD}/edh_protocol_validation_3tests.png",dpi=125,bbox_inches="tight"); print("wrote edh_protocol_validation_3tests.png")
