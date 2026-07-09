"""ℓ(巻き数)を外部priorとして足した xy面再構成. 同じ列データ(ncol,<F>col)から
 a(ρ,z),φ0 を復元し, 横スピンを f_perp=a e^{i(ℓφ+φ0)} と置いて ℓ=+1 と ℓ=-1 の両方を組む.
 (両者は y撮像では完全縮退=同一列データ. 区別は物理prior ℓ のみ.)
 真の巻き数を arg(f_perp) の周回積分で独立に測り, どちらが正しいか & 正しいℓでの精度を出す.
env: PSI13, GOTO, OUT, NR, LAM"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13
from isoviz import setup_font
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
setup_font("ja")
PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
OUT=os.environ.get("OUT","recon_xy_ell.png"); NR=int(os.environ.get("NR","18")); LAM=float(os.environ.get("LAM","2e-3"))
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); Bg=np.asarray(G["B_gauss"]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); Ng=load_frames_bulk(P,[0])[0].shape[0]
ax=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
Xg=ax[:,None]*np.ones((1,Ng)); Yg=np.ones((Ng,1))*ax[None,:]; RHO=np.hypot(Xg,Yg); PHI=np.arctan2(Yg,Xg)
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
def recon(col, ell):
    nc,cfx,cfy,cfz,zc=col
    w=nc*np.hypot(cfx,cfy); phi0=np.arctan2((cfy*w).sum(),(cfx*w).sum())
    g=(cfx*np.cos(phi0)+cfy*np.sin(phi0))*nc            # 符号付き射影(x奇関数) — Abel の x/ρ重みと整合
    npr=solve(M_scl,nc[:,zc]); fzpr=solve(M_scl,cfz[:,zc]*nc[:,zc]); apr=solve(M_vec,g[:,zc])
    nz=np.clip(interp(npr,RHO),1e-30,None); a=interp(apr,RHO)/nz; fz=interp(fzpr,RHO)/nz
    return a*np.cos(ell*PHI+phi0), a*np.sin(ell*PHI+phi0), fz
def true_winding(FxT,FyT,ns):                       # circulation of arg(f_perp), avg over radii
    th=np.linspace(0,2*np.pi,72,endpoint=False); ells=[]
    for fr in (0.25,0.35,0.45):
        R0=fr*L/2; xs=R0*np.cos(th); ys=R0*np.sin(th)
        ix=np.clip(np.round((xs+L/2)/L*(Ng-1)).astype(int),0,Ng-1); iy=np.clip(np.round((ys+L/2)/L*(Ng-1)).astype(int),0,Ng-1)
        vals=np.arctan2(FyT[ix,iy],FxT[ix,iy])
        ph=np.unwrap(np.concatenate([vals,vals[:1]]))   # close the loop
        ells.append((ph[-1]-ph[0])/(2*np.pi))
    return np.mean(ells)
def cc(Rf,Tf,w):                                       # 密度重み相関(全グリッド・選択なし)
    w=w/max(w.sum(),1e-30); ma=(w*Rf).sum(); mb=(w*Tf).sum()
    cov=(w*(Rf-ma)*(Tf-mb)).sum(); va=(w*(Rf-ma)**2).sum(); vb=(w*(Tf-mb)**2).sum()
    return cov/np.sqrt(va*vb) if va>1e-12 and vb>1e-12 else 1.0
clip6=lambda A: np.clip(A,-6,6)
REP_MS=[float(x) for x in os.environ.get("REP_MS","131,161,188").split(",")]
REP=[int(np.argmin(np.abs(tms-x))) for x in REP_MS]; psis=load_frames_bulk(P,REP)
xx,yy=np.meshgrid(ax,ax,indexing="ij")                 # 全グリッド点を描画
def tex(a2,fx,fy,fz,dens,title):
    al=np.clip(dens/max(dens.max(),1e-30),0,1)**0.5
    im=a2.imshow(fz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal",alpha=al.T)
    rgba=np.zeros((Ng,Ng,4)); rgba[...,3]=al
    a2.quiver(xx,yy,fx,fy,color=rgba.reshape(-1,4),scale=42,width=0.004,pivot="mid")
    a2.set_title(title,fontsize=9);a2.set_xlabel("x",fontsize=7);a2.set_ylabel("y",fontsize=7);a2.tick_params(labelsize=6);return im
fig,axg=plt.subplots(len(REP),3,figsize=(11.5,3.5*len(REP)),constrained_layout=True)
for rr,k in enumerate(REP):
    col,(ns,FxT,FyT,FzT)=col_and_truth(psis[rr])
    pX,pY,pZ=map(clip6,recon(col,+1)); mX,mY,mZ=map(clip6,recon(col,-1)); ell_true=true_winding(FxT,FyT,ns)
    cp=(cc(pX,FxT,ns),cc(pY,FyT,ns)); cm=(cc(mX,FxT,ns),cc(mY,FyT,ns))
    tex(axg[rr,0],FxT,FyT,FzT,ns,f"真値 xy面  t={tms[k]:.0f}ms\n真の巻き数 ℓ_true≈{ell_true:+.1f}")
    tex(axg[rr,1],pX,pY,pZ,ns,f"prior ℓ=+1\ncorr(Fx,Fy)=({cp[0]:+.2f},{cp[1]:+.2f})")
    im=tex(axg[rr,2],mX,mY,mZ,ns,f"prior ℓ=-1\ncorr(Fx,Fy)=({cm[0]:+.2f},{cm[1]:+.2f})")
    if rr==0: fig.colorbar(im,ax=axg[rr,2],shrink=0.7,label="Fz")
    best="ℓ=+1" if (cp[0]+cp[1])>(cm[0]+cm[1]) else "ℓ=-1"
    print(f"t={tms[k]:.0f}ms  ℓ_true≈{ell_true:+.2f}  ℓ=+1:corr(Fx,Fy)=({cp[0]:+.2f},{cp[1]:+.2f})  ℓ=-1:({cm[0]:+.2f},{cm[1]:+.2f})  -> best {best}")
fig.suptitle("ℓを物理priorとして足した xy面再構成 — 同じ列データから ℓ=+1/-1 を両方 (y撮像では縮退, priorで選ぶ)  [矢印=(Fx,Fy), 色=Fz]",fontsize=11)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
