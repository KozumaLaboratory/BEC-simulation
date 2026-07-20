"""Spin-texture dynamics in the x-z plane (y=mid slice) for par_T90 EdH.
Per-atom spin s=F/n (|s|~6):  in-plane arrows (s_x, s_z), colour = s_y (out-of-plane
= line-of-sight component, divergent). Masked where density < 5% of peak. Arrow
length ∝ in-plane spin magnitude (no unit normalization; tiny -> short).
NEW psi13 in resim/.  env: KEY, FPS, OUT, MODE(slice|col)."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); FPS=int(os.environ.get("FPS","10")); MODE=os.environ.get("MODE","slice")
OUT=os.environ.get("OUT",f"spintex_xz_{KEY}.mp4"); AHO=0.78
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2
half=L/2*AHO; ext=[-half,half,-half,half]; ax=(np.arange(ng)-ng//2)*(L/ng)*AHO
def fields(p):
    fx=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)); fy=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p)); fz=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)); n=(np.abs(p)**2).sum(-1)
    if MODE=="col":                                   # column integral INT dy
        return fx.sum(1),fy.sum(1),fz.sum(1),n.sum(1)
    return fx[:,c,:],fy[:,c,:],fz[:,c,:],n[:,c,:]     # y-mid slice
# precompute per-atom spin (masked) and global scales
SX=[];SY=[];SZ=[];NN=[]
for p in ps:
    fx,fy,fz,n=fields(p); nmask=n>0.05*n.max()
    sx=np.where(nmask,fx/np.maximum(n,1e-12),0.0); sy=np.where(nmask,fy/np.maximum(n,1e-12),0.0); sz=np.where(nmask,fz/np.maximum(n,1e-12),0.0)
    SX.append(sx);SY.append(sy);SZ.append(sz);NN.append(n)
SX=np.array(SX);SY=np.array(SY);SZ=np.array(SZ);NN=np.array(NN)
sperp=np.hypot(SX,SZ); smax=np.percentile(sperp[sperp>0],99)+1e-9; sy_max=6.0
st=2; idx=np.arange(0,ng,st); XX,ZZ=np.meshgrid(ax[idx],ax[idx],indexing="ij")
tmp=tempfile.mkdtemp(); print(f"[spintex_xz] {nf} frames MODE={MODE} smax_perp={smax:.2f}")
for k in range(nf):
    fig,a=plt.subplots(figsize=(7.0,6.6))
    im=a.imshow(SY[k].T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-sy_max,vmax=sy_max,aspect="equal")
    cb=fig.colorbar(im,ax=a,fraction=0.046,pad=0.04); cb.set_label("面外スピン s_y = F_y/n （視線方向）")
    u=SX[k][::st,::st]; v=SZ[k][::st,::st]
    a.quiver(XX,ZZ,u,v,color="k",scale=smax*len(idx)*1.1,width=0.005,alpha=0.9)
    a.set_xlabel("x (μm)"); a.set_ylabel("z (μm)")
    a.set_title(f"スピンテクスチャ x-z面（{'カラム∫dy' if MODE=='col' else 'y中央スライス'}）: 面内矢印=(s_x,s_z), 色=s_y(面外)",fontsize=10,pad=6)
    fig.suptitle(f"{os.environ.get('LABEL',KEY)}\nt = {tms[k]:.0f} ms    B = {Bg[k]*1e6:.0f} μG",fontsize=12,y=0.995,va="top")
    fig.subplots_adjust(top=0.83,bottom=0.09,left=0.10,right=0.86)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
