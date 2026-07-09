#!/usr/bin/env python3
"""xy断面(z一定スライス)の再構成 vs 真値.

視線=y(∫dy)なので xy面は直接撮像できない(∫dyの零空間). そこで:
  観測(=y撮像で厳密に得られる列平均, 前スクリプトで機械精度を確認):
     ncol(x,z), <Fx>col(x,z), <Fy>col(x,z), <Fz>col(x,z)
  仮定: 軸対称 + 横スピンの方位巻き ℓ=1  ( f_perp = a(ρ,z) e^{i(φ+φ0)} )
  各z面で Abel 逆変換:
     ncol = A_scl · n(ρ),   <Fz>col*ncol = A_scl · (fz密度)(ρ),
     √(<Fx>col²+<Fy>col²)*ncol = A_vec · (a密度)(ρ)     [ x/ρ 重み ]
     φ0 = atan2(<Fy>col,<Fx>col)  (面内で密度重み平均)
  → 3D体を組み, z=zpeak の xy面を予測し, 真の xy面(完全スピノル)と比較.
env: PSI13, GOTO, OUT, NR, LAM
"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13
from isoviz import setup_font
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
setup_font("ja")

PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
OUT=os.environ.get("OUT","recon_xy_par.png"); NR=int(os.environ.get("NR","18")); LAM=float(os.environ.get("LAM","2e-3"))

with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); Bg=np.asarray(G["B_gauss"])
    meta={k:np.asarray(G["meta"][k]).item() for k in G["meta"]}
tms=t/om*1000.0; L=float(meta["L_box"]);
P=open_psi13(PSI13)
Ng=load_frames_bulk(P,[0])[0].shape[0]
ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]

# ---- Abel forward matrices (geometry identical for all z) ----
X=ax1d[:,None]*np.ones((1,Ng)); Y=np.ones((Ng,1))*ax1d[None,:]; RHO=np.hypot(X,Y)
rmax=L/2*1.02; r=np.linspace(0,rmax,NR); dr=r[1]-r[0]
pos=RHO/dr; j0=np.clip(np.floor(pos).astype(int),0,NR-2); frac=pos/1-j0
W=np.zeros((Ng,Ng,NR))
I,K=np.meshgrid(np.arange(Ng),np.arange(Ng),indexing="ij")
W[I,K,j0]+=(1-frac); W[I,K,j0+1]+=frac
M_scl=W.sum(axis=1)                                   # (Ng,NR)  column<-radial (scalar)
M_vec=(W*(X/np.clip(RHO,1e-9,None))[...,None]).sum(axis=1)   # x/ρ weighted
def solve(M,c):                                       # Tikhonov ridge
    A=M.T@M+LAM*np.trace(M.T@M)/NR*np.eye(NR); return np.linalg.solve(A,M.T@c)
def interp(prof,rho):                                 # radial profile -> (x,y)
    p=np.clip(rho/dr,0,NR-1-1e-6); j=np.floor(p).astype(int); f=p-j; return prof[j]*(1-f)+prof[j+1]*f

def truth_slice_and_col(psi):
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    n=np.sum(np.abs(psi)**2,axis=-1); fxd,fyd,fzd=sd(FX),sd(FY),sd(FZ)
    ncol=n.sum(1); colfx=fxd.sum(1)/np.clip(ncol,1e-30,None); colfy=fyd.sum(1)/np.clip(ncol,1e-30,None); colfz=fzd.sum(1)/np.clip(ncol,1e-30,None)
    zc=int(np.argmax(n.sum((0,1))))                   # z peak
    ns=n[:,:,zc]; Fx=fxd[:,:,zc]/np.clip(ns,1e-30,None); Fy=fyd[:,:,zc]/np.clip(ns,1e-30,None); Fz=fzd[:,:,zc]/np.clip(ns,1e-30,None)
    return (ncol,colfx,colfy,colfz),(ns,Fx,Fy,Fz,zc)

def recon_xy(col,zc):
    ncol,colfx,colfy,colfz=col
    # per-z Abel inversion
    nprof=np.zeros((Ng,NR)); fzprof=np.zeros((Ng,NR)); aprof=np.zeros((Ng,NR))
    # φ0 (density-weighted over the whole cloud)
    w=ncol*np.hypot(colfx,colfy); phi0=np.arctan2((colfy*w).sum(),(colfx*w).sum())
    g=(colfx*np.cos(phi0)+colfy*np.sin(phi0))*ncol    # 符号付き射影(x奇関数) — Abel の x/ρ重みと整合
    for z in range(Ng):
        nprof[z]=solve(M_scl,ncol[:,z]); fzprof[z]=solve(M_scl,colfz[:,z]*ncol[:,z]); aprof[z]=solve(M_vec,g[:,z])
    # reconstruct xy at z=zc
    nz=np.clip(interp(nprof[zc],RHO),0,None); az=interp(aprof[zc],RHO); fzz=interp(fzprof[zc],RHO)
    phi=np.arctan2(Ygrid,Xgrid)
    aperatom=az/np.clip(nz,1e-30,None); Fzp=fzz/np.clip(nz,1e-30,None)
    Fxp=aperatom*np.cos(phi+phi0); Fyp=aperatom*np.sin(phi+phi0)
    return nz,Fxp,Fyp,Fzp
Xgrid=ax1d[:,None]*np.ones((1,Ng)); Ygrid=np.ones((Ng,1))*ax1d[None,:]

REP=[int(np.argmin(np.abs(tms-x))) for x in (131,146,161,188)]
psis=load_frames_bulk(P,REP)
st=max(1,Ng//14); xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij")
fig,axg=plt.subplots(len(REP),4,figsize=(15,3.4*len(REP)),constrained_layout=True)
def tex(a,fx,fy,fz,mask,title):
    Sx=np.where(mask,fx,np.nan); Sy=np.where(mask,fy,np.nan); Sz=np.where(mask,fz,np.nan); mg=np.hypot(Sx,Sy)
    im=a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    a.quiver(xx[::st,::st],yy[::st,::st],Sx[::st,::st],Sy[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=42,width=0.008,pivot="mid")
    a.set_title(title,fontsize=9); a.set_xlabel("x [l0]",fontsize=7); a.set_ylabel("y [l0]",fontsize=7); a.tick_params(labelsize=6); return im
def metr(R,T,m):
    a=R[m]; b=T[m]; c=np.corrcoef(a,b)[0,1] if a.std()>1e-9 and b.std()>1e-9 else 1.0
    return c, np.linalg.norm(a-b)/max(np.linalg.norm(b),1e-30)
for rr,k in enumerate(REP):
    col,(ns,FxT,FyT,FzT,zc)=truth_slice_and_col(psis[rr])
    nR,FxR,FyR,FzR=recon_xy(col,zc); m=ns>0.05*ns.max()
    cx=metr(FxR,FxT,m); cy=metr(FyR,FyT,m); cz=metr(FzR,FzT,m)
    tex(axg[rr,0],FxT,FyT,FzT,m,f"真値 xy面 (z=zpeak)\nt={tms[k]:.0f}ms  B={Bg[k]*1e3:.1f}uG")
    im=tex(axg[rr,1],FxR,FyR,FzR,m,f"予測 [軸対称+ℓ=1]\ncorr(Fx,Fy,Fz)=({cx[0]:.2f},{cy[0]:.2f},{cz[0]:.2f})")
    er=np.where(m,np.sqrt((FxR-FxT)**2+(FyR-FyT)**2+(FzR-FzT)**2),np.nan)
    ie=axg[rr,2].imshow(er.T,origin="lower",extent=ext,cmap="magma",aspect="equal",vmin=0)
    axg[rr,2].set_title(f"|誤差ベクトル|\nrel-L2=({cx[1]:.2f},{cy[1]:.2f},{cz[1]:.2f})",fontsize=9); axg[rr,2].set_xticks([]);axg[rr,2].set_yticks([]); fig.colorbar(ie,ax=axg[rr,2],shrink=0.7)
    # residual = truth - axisym-avg(truth): the non-axisymmetric part that ℓ=1 assumption cannot see
    rho=RHO; nprofT=np.zeros(NR)
    axg[rr,3].axis("off")
    if rr==0: fig.colorbar(im,ax=axg[rr,1],shrink=0.7,label="Fz(面外)")
    print(f"t={tms[k]:6.1f}ms xy@zpeak: corr(Fx,Fy,Fz)=({cx[0]:.3f},{cy[0]:.3f},{cz[0]:.3f}) relL2=({cx[1]:.2f},{cy[1]:.2f},{cz[1]:.2f})")
fig.suptitle("par_T90: xy断面(z=zpeak)の予測 vs 真値  [矢印=(Fx,Fy)/atom, 色=Fz]  — y撮像は直接xyを撮れない→軸対称+ℓ=1で予測",fontsize=12)
# use last column for an explanatory note
axg[0,3].axis("on"); axg[0,3].set_xticks([]); axg[0,3].set_yticks([])
axg[0,3].text(0.02,0.5,"xy面は視線yに直交:\n∫dy で直接は撮れない\n(零空間).\n\n入力は列平均\nncol,<F>col(x,z)のみ.\n軸対称+ℓ=1渦を\n仮定してz軸周りに\n回して予測.\n\n→ 予測がどれだけ\n真のxy面に合うかが\nこの仮定の妥当性.",fontsize=8.5,va="center",transform=axg[0,3].transAxes)
for rr in range(1,len(REP)): axg[rr,3].remove()
fig.savefig(OUT,dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
