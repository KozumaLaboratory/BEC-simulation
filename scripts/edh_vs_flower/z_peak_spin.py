#!/usr/bin/env python3
"""xy spin texture at z = -zpeak, 0, +zpeak (not just z=0).
spin3d h5py (z,y,x,nf) -> transpose (x,y,z,nf). per-particle s=F/n, up=red/down=blue + arrows.
env: SPIN3D, DIAG, OUT, FRAME, LABEL"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
S=os.environ["SPIN3D"]; DG=os.environ.get("DIAG",""); OUT=os.environ.get("OUT","zpeak.png")
FR=int(os.environ.get("FRAME","60")); LAB=os.environ.get("LABEL","EdH"); F=6.0; OMEGA=691.15
f=h5py.File(S,"r"); L=float(f["meta/L_box"][()])
tr=lambda k: np.transpose(np.asarray(f[k]),(2,1,0,3))   # ->(x,y,z,nf)
Fx=tr("Fx_3d")[...,FR]; Fy=tr("Fy_3d")[...,FR]; Fz=tr("Fz_3d")[...,FR]; n=tr("n_total_3d")[...,FR]
nm5=tr("n_m5_3d")[...,FR]
Ng=n.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng)
# z-profile of m=-5 (lives at z=±peak due to node at z=0) -> find peak z
zprof=nm5.sum(axis=(0,1)); zc=Ng//2
zp_idx=int(np.argmax(zprof)); zpk=ax1d[zp_idx]
# symmetric partner
zlist=[(Ng-1-zp_idx if zp_idx<zc else 2*zc-zp_idx, "z=-zpeak"),(zc,"z=0"),(zp_idx,"z=+zpeak")]
zlist=sorted(set([(max(0,min(Ng-1,i)),lab) for i,lab in zlist]), key=lambda t:t[0])
if DG and os.path.exists(DG):
    d=h5py.File(DG,"r"); tms=float(np.asarray(d["t"])[min(FR,len(d["t"])-1)])/OMEGA*1000
else: tms=FR
ext=[-L/2,L/2,-L/2,L/2]; X,Y=np.meshgrid(ax1d,ax1d,indexing="ij"); sk=2
def pp(Fc,nn): m=nn>0.05*nn.max(); return np.where(m,Fc/np.where(m,nn,1),np.nan)
fig,ax=plt.subplots(1,3,figsize=(15,5.2),constrained_layout=True)
for j,(iz,lab) in enumerate(zlist):
    nn=n[:,:,iz]; sz=pp(Fz[:,:,iz],nn); sx=pp(Fx[:,:,iz],nn); sy=pp(Fy[:,:,iz],nn)
    im=ax[j].imshow(sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-F,vmax=F,aspect="equal")
    ax[j].quiver(X[::sk,::sk],Y[::sk,::sk],sx[::sk,::sk],sy[::sk,::sk],angles="xy",scale_units="xy",scale=F/1.2,width=0.005,color="k",alpha=0.85)
    ax[j].set_title(f"{lab}  (z={ax1d[iz]:+.1f}μm)",fontsize=11); ax[j].set_xlabel("x [μm]"); ax[j].set_ylabel("y [μm]")
fig.colorbar(im,ax=list(ax),shrink=0.7,label=r"$s_z$/particle (↑red ↓blue, ±F)")
fig.suptitle(f"{LAB} — xy spin texture at z=0 and z=±peak   t={tms:.1f} ms  (zpeak≈{abs(zpk):.1f}μm)",fontsize=13)
fig.savefig(OUT,dpi=120); print(f"wrote {OUT}  zpeak idx={zp_idx} z={zpk:.2f}  zlist={[z for z,_ in zlist]}")
