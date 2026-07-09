#!/usr/bin/env python3
"""「xとyは対等 → yもxと同じ分布」仮定での xy面再構成を2通り試して真値と比較.
 (a) extrude : per-atom スピンは y に依らず, 列平均 <F>col(x,z) を全yに広げる (最も素朴).
 (b) axisym  : x<->y 交換対称 = 軸対称. 列データを Abel 逆変換し ρ で回す (仮定の厳密版).
どちらも入力は y撮像で得られる列平均 ncol,<F>col(x,z) のみ. z=zpeak の xy面で比較.
env: PSI13, GOTO, OUT, NR, LAM"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13
from isoviz import setup_font
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
setup_font("ja")
PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
OUT=os.environ.get("OUT","recon_xy_assume.png"); NR=int(os.environ.get("NR","18")); LAM=float(os.environ.get("LAM","2e-3"))
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); Bg=np.asarray(G["B_gauss"]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); Ng=load_frames_bulk(P,[0])[0].shape[0]
ax=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
Xg=ax[:,None]*np.ones((1,Ng)); Yg=np.ones((Ng,1))*ax[None,:]; RHO=np.hypot(Xg,Yg)
# Abel matrices
r=np.linspace(0,L/2*1.02,NR); dr=r[1]-r[0]; pos=RHO/dr; j0=np.clip(np.floor(pos).astype(int),0,NR-2); frac=pos-j0
W=np.zeros((Ng,Ng,NR)); I,K=np.meshgrid(np.arange(Ng),np.arange(Ng),indexing="ij")
W[I,K,j0]+=1-frac; W[I,K,j0+1]+=frac
M_scl=W.sum(1); M_vec=(W*(Xg/np.clip(RHO,1e-9,None))[...,None]).sum(1)
def solve(M,c): A=M.T@M+LAM*np.trace(M.T@M)/NR*np.eye(NR); return np.linalg.solve(A,M.T@c)
def interp(p,rho): q=np.clip(rho/dr,0,NR-1-1e-6); j=np.floor(q).astype(int); f=q-j; return p[j]*(1-f)+p[j+1]*f
def col_and_truth(psi):
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    n=np.sum(np.abs(psi)**2,-1); fxd,fyd,fzd=sd(FX),sd(FY),sd(FZ); nc=n.sum(1)
    cfx=fxd.sum(1)/np.clip(nc,1e-30,None); cfy=fyd.sum(1)/np.clip(nc,1e-30,None); cfz=fzd.sum(1)/np.clip(nc,1e-30,None)
    zc=int(np.argmax(n.sum((0,1)))); ns=n[:,:,zc]
    return (nc,cfx,cfy,cfz,zc),(ns,fxd[:,:,zc]/np.clip(ns,1e-30,None),fyd[:,:,zc]/np.clip(ns,1e-30,None),fzd[:,:,zc]/np.clip(ns,1e-30,None))
def rec_extrude(col):
    nc,cfx,cfy,cfz,zc=col
    return np.broadcast_to(cfx[:,zc][:,None],(Ng,Ng)),np.broadcast_to(cfy[:,zc][:,None],(Ng,Ng)),np.broadcast_to(cfz[:,zc][:,None],(Ng,Ng))
def rec_axisym(col):
    nc,cfx,cfy,cfz,zc=col
    w=nc*np.hypot(cfx,cfy); phi0=np.arctan2((cfy*w).sum(),(cfx*w).sum())
    g=(cfx*np.cos(phi0)+cfy*np.sin(phi0))*nc            # 符号付き射影(x奇関数)
    npr=solve(M_scl,nc[:,zc]); fzpr=solve(M_scl,cfz[:,zc]*nc[:,zc]); apr=solve(M_vec,g[:,zc])
    nz=np.clip(interp(npr,RHO),1e-30,None); az=interp(apr,RHO)/nz; fz=interp(fzpr,RHO)/nz; phi=np.arctan2(Yg,Xg)
    return az*np.cos(phi+phi0),az*np.sin(phi+phi0),fz
REP=[int(np.argmin(np.abs(tms-x))) for x in (131,161,188)]; psis=load_frames_bulk(P,REP)
st=max(1,Ng//14); xx,yy=np.meshgrid(ax,ax,indexing="ij")
def tex(a,fx,fy,fz,m,title):
    Sx=np.where(m,fx,np.nan);Sy=np.where(m,fy,np.nan);Sz=np.where(m,fz,np.nan);mg=np.hypot(Sx,Sy)
    im=a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    a.quiver(xx[::st,::st],yy[::st,::st],Sx[::st,::st],Sy[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=42,width=0.008,pivot="mid")
    a.set_title(title,fontsize=9);a.set_xlabel("x",fontsize=7);a.set_ylabel("y",fontsize=7);a.tick_params(labelsize=6);return im
def cc(R,T,m):
    a=R[m];b=T[m];return np.corrcoef(a,b)[0,1] if a.std()>1e-9 and b.std()>1e-9 else 1.0
fig,ax2=plt.subplots(len(REP),3,figsize=(11.5,3.5*len(REP)),constrained_layout=True)
for rr,k in enumerate(REP):
    col,(ns,FxT,FyT,FzT)=col_and_truth(psis[rr]); m=ns>0.05*ns.max()
    exX,exY,exZ=rec_extrude(col); axX,axY,axZ=rec_axisym(col)
    tex(ax2[rr,0],FxT,FyT,FzT,m,f"真値 xy面  t={tms[k]:.0f}ms")
    tex(ax2[rr,1],exX,exY,exZ,m,f"(a)extrude: yに依らず列値\ncorr(Fx,Fy,Fz)=({cc(exX,FxT,m):.2f},{cc(exY,FyT,m):.2f},{cc(exZ,FzT,m):.2f})")
    im=tex(ax2[rr,2],axX,axY,axZ,m,f"(b)x<->y対等=軸対称\ncorr(Fx,Fy,Fz)=({cc(axX,FxT,m):.2f},{cc(axY,FyT,m):.2f},{cc(axZ,FzT,m):.2f})")
    if rr==0: fig.colorbar(im,ax=ax2[rr,2],shrink=0.7,label="Fz")
    print(f"t={tms[k]:.0f}ms  extrude corr(Fx,Fy,Fz)=({cc(exX,FxT,m):+.2f},{cc(exY,FyT,m):+.2f},{cc(exZ,FzT,m):+.2f})  axisym=({cc(axX,FxT,m):+.2f},{cc(axY,FyT,m):+.2f},{cc(axZ,FzT,m):+.2f})")
fig.suptitle("『yもxと同じ分布』仮定の xy面再構成 (入力=列平均のみ)  [矢印=(Fx,Fy)/atom, 色=Fz]",fontsize=12)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
