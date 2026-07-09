#!/usr/bin/env python3
"""Reconstruct the SPIN TEXTURE in the xz plane (column-integrated INT dy, side view)
from the SAME ±16° protocol (no-tilt + ±16 about y,x). Per (x,z) pixel:
  s^{(k)}(x,z)=sum_{m in V} m [INT dy n_m^{(k)}] / sum [INT dy n_m^{(k)}]
  <Fz>=s^{(0)}, <Fx>=-(s^{y+}-s^{y-})/(2 sin16), <Fy>=+(s^{x+}-s^{x-})/(2 sin16)
xz texture: arrows = in-plane (<Fx>,<Fz>), color = out-of-plane <Fy>.
Compare to column-averaged truth. 3 states. env: OUTDIR"""
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
    P=h5py.File(fn,"r"); L=float(P["meta/L_box"][()]); nf=np.asarray(P["psi_re_c01"]).shape[-1]; fr=fr if fr>=0 else nf+fr
    psi=np.stack([np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]+1j*np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr] for c in range(1,14)],axis=-1)
    return psi,L
def col_cen(psi,R):  # visible centroid on the INT dy (xz) images -> (x,z)
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
    ov=o[...,VIS].sum(axis=1)                     # INT dy -> (x,z,|V|)
    return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
def recon_xz(psi):
    fz=col_cen(psi,np.eye(D)); fx=-(col_cen(psi,Ry(+th))-col_cen(psi,Ry(-th)))/(2*s16); fy=+(col_cen(psi,Rx(+th))-col_cen(psi,Rx(-th)))/(2*s16)
    return fx,fy,fz
def truth_xz(psi):  # column-averaged (INT dy) truth per component
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    n=np.sum(np.abs(psi)**2,axis=-1); ncol=n.sum(axis=1)
    return (sd(Fx).sum(axis=1)/np.clip(ncol,1e-30,None), sd(Fy).sum(axis=1)/np.clip(ncol,1e-30,None), sd(Fz).sum(axis=1)/np.clip(ncol,1e-30,None), ncol)
TESTS=[("(1) 10mG GS (m=-6)","edh_v5_psi13.jld2",0),
       ("(2) EdH (t~26ms)","edh_v5_psi13.jld2",100),
       ("(3) Flower @120uG","flower_v3_psi13.jld2",-1)]
fig,ax=plt.subplots(3,3,figsize=(11.5,11),constrained_layout=True)
for r,(lab,fn,fr) in enumerate(TESTS):
    psi,L=loadframe(fn,fr); fxR,fyR,fzR=recon_xz(psi); fxT,fyT,fzT,ncol=truth_xz(psi)
    mcol=ncol>0.04*ncol.max()
    def corr(A,B): a=A[mcol];b=B[mcol]; return np.corrcoef(a,b)[0,1] if a.std()>1e-9 and b.std()>1e-9 else 1.0
    cx,cy,cz=corr(fxR,fxT),corr(fyR,fyT),corr(fzR,fzT)
    print(f"{lab} [xz]: corr(Fx,Fy,Fz)=({cx:+.3f},{cy:+.3f},{cz:+.3f})  maxerr=({np.abs(fxR-fxT)[mcol].max():.2f},{np.abs(fyR-fyT)[mcol].max():.2f},{np.abs(fzR-fzT)[mcol].max():.2f})")
    Ng=fzR.shape[0]; ext=[-L/2,L/2,-L/2,L/2]; ax1d=np.linspace(-L/2,L/2,Ng); xx,zz=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//14)
    def tex(a,fx,fy,fz,title):  # xz plane: arrows=(Fx,Fz) in-plane, color=Fy out-of-plane
        Sx=np.where(mcol,fx,np.nan); Sz=np.where(mcol,fz,np.nan); Sy=np.where(mcol,fy,np.nan); mg=np.hypot(Sx,Sz)
        im=a.imshow(Sy.T,origin="lower",extent=ext,cmap="PuOr_r",vmin=-3,vmax=3,aspect="equal")
        U=np.where(mg>1e-6,Sx/np.clip(mg,1e-9,None),np.nan); W=np.where(mg>1e-6,Sz/np.clip(mg,1e-9,None),np.nan)
        a.quiver(xx[::st,::st],zz[::st,::st],U[::st,::st],W[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=22,width=0.008,pivot="mid")
        a.set_title(title,fontsize=9); a.set_xlabel("x",fontsize=7); a.set_ylabel("z",fontsize=7); a.tick_params(labelsize=6); return im
    tex(ax[r,0],fxT,fyT,fzT,"TRUTH ⟨F⟩(x,z) col-avg\n"+lab)
    tex(ax[r,1],fxR,fyR,fzR,"reconstructed [±16°]")
    em=np.where(mcol,np.sqrt((fxR-fxT)**2+(fyR-fyT)**2+(fzR-fzT)**2),np.nan)
    im=ax[r,2].imshow(em.T,origin="lower",extent=ext,cmap="magma",aspect="equal"); ax[r,2].set_xticks([]);ax[r,2].set_yticks([])
    ax[r,2].set_title(f"|err|  corr=({cx:.2f},{cy:.2f},{cz:.2f})",fontsize=9); fig.colorbar(im,ax=ax[r,2],shrink=0.7)
fig.suptitle("xz-plane spin texture reconstruction (∫dy side view) via ±16° protocol — arrows=(⟨Fx⟩,⟨Fz⟩), color=⟨Fy⟩",fontsize=11)
fig.savefig(f"{OD}/edh_xz_texture_recon_3tests.png",dpi=125,bbox_inches="tight"); print("wrote edh_xz_texture_recon_3tests.png")
