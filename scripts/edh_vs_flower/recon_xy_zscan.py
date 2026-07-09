"""時刻固定で z を色々変えた xy面再構成 (ℓ=+1 prior) vs 真値.
各z面で: 列データ(その z の ncol,<F>col(x)) から Abel逆変換で a(ρ),n(ρ),fz(ρ) を復元し
 横スピンを f_perp=a e^{i(φ+φ0(z))} (ℓ=+1) として xy面を組む. 真の xy断面と比較.
矢印=物理長(Fx,Fy)/atom (規格化なし, truth/recon同一scale), 色=Fz. env: PSI13,GOTO,T_MS,OUT,NR,LAM"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13
from isoviz import setup_font
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
setup_font("ja")
PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
T_MS=float(os.environ.get("T_MS","188")); OUT=os.environ.get("OUT","recon_xy_zscan.png")
NR=int(os.environ.get("NR","18")); LAM=float(os.environ.get("LAM","2e-3")); LABEL=os.environ.get("LABEL","par_T90")
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); Bg=np.asarray(G["B_gauss"]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); k=int(np.argmin(np.abs(tms-T_MS)))
psi=load_frames_bulk(P,[k])[0]; Ng=psi.shape[0]; ax=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
Xg=ax[:,None]*np.ones((1,Ng)); Yg=np.ones((Ng,1))*ax[None,:]; RHO=np.hypot(Xg,Yg); PHI=np.arctan2(Yg,Xg)
r=np.linspace(0,L/2*1.02,NR); dr=r[1]-r[0]; pos=RHO/dr; j0=np.clip(np.floor(pos).astype(int),0,NR-2); frac=pos-j0
W=np.zeros((Ng,Ng,NR)); I,K=np.meshgrid(np.arange(Ng),np.arange(Ng),indexing="ij"); W[I,K,j0]+=1-frac; W[I,K,j0+1]+=frac
M_scl=W.sum(1); M_vec=(W*(Xg/np.clip(RHO,1e-9,None))[...,None]).sum(1)
def solve(M,c): A=M.T@M+LAM*np.trace(M.T@M)/NR*np.eye(NR); return np.linalg.solve(A,M.T@c)
def interp(p,rho): q=np.clip(rho/dr,0,NR-1-1e-6); j=np.floor(q).astype(int); f=q-j; return p[j]*(1-f)+p[j+1]*f
# ---- observables (columns per (x,z)) and truth 3D ----
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
n=np.sum(np.abs(psi)**2,-1); fxd,fyd,fzd=sd(FX),sd(FY),sd(FZ); nc=n.sum(1)
cfx=fxd.sum(1)/np.clip(nc,1e-30,None); cfy=fyd.sum(1)/np.clip(nc,1e-30,None); cfz=fzd.sum(1)/np.clip(nc,1e-30,None)
FxV=fxd/np.clip(n,1e-30,None); FyV=fyd/np.clip(n,1e-30,None); FzV=fzd/np.clip(n,1e-30,None)   # per-atom 3D
npk=n.max()
def recon_z(z):                        # ℓ=+1 xy reconstruction at slice z
    w=nc[:,z]*np.hypot(cfx[:,z],cfy[:,z]); phi0=np.arctan2((cfy[:,z]*w).sum(),(cfx[:,z]*w).sum())
    g=(cfx[:,z]*np.cos(phi0)+cfy[:,z]*np.sin(phi0))*nc[:,z]
    nz=np.clip(interp(solve(M_scl,nc[:,z]),RHO),1e-30,None); a=interp(solve(M_vec,g),RHO)/nz; fz=interp(solve(M_scl,cfz[:,z]*nc[:,z]),RHO)/nz
    return a*np.cos(PHI+phi0), a*np.sin(PHI+phi0), fz, phi0
# choose z slices spanning the cloud (density-weighted)
zprof=n.sum((0,1)); zc=int(np.argmax(zprof)); sig=np.where(zprof>0.05*zprof.max())[0]
zidx=np.linspace(sig[0], sig[-1], 5).round().astype(int)  # 雲のz全域を等間隔サンプル
xx,yy=np.meshgrid(ax,ax,indexing="ij")                  # 全計算グリッド点を描画 (間引きなし)
clip6=lambda A: np.clip(A,-6,6)                          # 物理境界 |<F>|<=F=6 (真空の0/0発散を除去)
def tex(a2,fx,fy,fz,dens,title):
    al=np.clip(dens/max(dens.max(),1e-30),0,1)**0.5      # 密度でα濃淡(ハードマスクなし・全グリッド)
    im=a2.imshow(fz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal",alpha=al.T)
    rgba=np.zeros((Ng,Ng,4)); rgba[...,3]=al             # 矢印も密度でα(物理長は保持・選択なし)
    a2.quiver(xx,yy,fx,fy,color=rgba.reshape(-1,4),scale=42,width=0.004,pivot="mid")
    a2.set_title(title,fontsize=9);a2.set_xlabel("x",fontsize=7);a2.set_ylabel("y",fontsize=7);a2.tick_params(labelsize=6);return im
def wcc(Rf,Tf,w):                                        # 密度重み相関 (全グリッド・選択なし)
    w=w/max(w.sum(),1e-30); ma=(w*Rf).sum(); mb=(w*Tf).sum()
    cov=(w*(Rf-ma)*(Tf-mb)).sum(); va=(w*(Rf-ma)**2).sum(); vb=(w*(Tf-mb)**2).sum()
    return cov/np.sqrt(va*vb) if va>1e-12 and vb>1e-12 else 1.0
def wmean(A,w): return (w*A).sum()/max(w.sum(),1e-30)
def wrel(Rf,Tf,w): return np.sqrt((w*(Rf-Tf)**2).sum()/max((w*Tf**2).sum(),1e-30))  # 密度重み相対誤差
fig,axg=plt.subplots(len(zidx),3,figsize=(11.5,3.4*len(zidx)),constrained_layout=True)
print(f"t={tms[k]:.0f}ms  B={Bg[k]*1e3:.1f}uG   z-scan (ℓ=+1, 全グリッド密度重み):")
for rr,z in enumerate(zidx):
    ns=n[:,:,z]; FxT,FyT,FzT=FxV[:,:,z],FyV[:,:,z],FzV[:,:,z]
    rX,rY,rZ,phi0=recon_z(z); rX,rY,rZ=clip6(rX),clip6(rY),clip6(rZ)
    cx,cy=wcc(rX,FxT,ns),wcc(rY,FyT,ns); rzErr=wrel(rZ,FzT,ns)
    perpT=wmean(np.hypot(FxT,FyT),ns); perpR=wmean(np.hypot(rX,rY),ns)
    tex(axg[rr,0],FxT,FyT,FzT,ns,f"真値 z={ax[z]:+.1f}l0\n|f_perp|(密度重み)={perpT:.2f}  占有{100*ns.sum()/n.sum():.0f}%")
    im=tex(axg[rr,1],rX,rY,rZ,ns,f"再構成 ℓ=+1\ncorr(Fx,Fy)=({cx:.2f},{cy:.2f}) Fz相対誤差={rzErr:.1%}  |f_perp|={perpR:.2f}")
    er=np.sqrt((rX-FxT)**2+(rY-FyT)**2+(rZ-FzT)**2)
    al=np.clip(ns/max(ns.max(),1e-30),0,1)**0.5
    ie=axg[rr,2].imshow(er.T,origin="lower",extent=ext,cmap="magma",aspect="equal",vmin=0,alpha=al.T); axg[rr,2].set_xticks([]);axg[rr,2].set_yticks([])
    axg[rr,2].set_title(f"|誤差|(α=密度)  振幅比 recon/真={perpR/max(perpT,1e-9):.2f}",fontsize=9); fig.colorbar(ie,ax=axg[rr,2],shrink=0.7)
    if rr==0: fig.colorbar(im,ax=axg[rr,1],shrink=0.7,label="Fz")
    print(f"  z={ax[z]:+.1f}l0 (占有{100*ns.sum()/n.sum():4.1f}%): corr(Fx,Fy)=({cx:+.2f},{cy:+.2f}) Fz相対誤差={rzErr:.1%}  |f_perp| 真={perpT:.2f} recon={perpR:.2f} 比={perpR/max(perpT,1e-9):.2f}")
fig.suptitle(f"{LABEL} t={tms[k]:.0f}ms — z を変えた xy面再構成 (ℓ=+1, 全計算グリッド・密度重み)  [矢印=(Fx,Fy)/atom 物理長, 色=Fz(α=密度)]  視線=y",fontsize=12)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
