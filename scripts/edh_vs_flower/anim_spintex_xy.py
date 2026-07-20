"""Spin-texture dynamics in the x-y plane (z=mid slice) — the plane where the ℓ=1
transverse winding lives. Per-atom spin s=F/n: in-plane arrows (s_x,s_y), colour =
s_z (out-of-plane = quantization axis; ≈-6 when polarized, rises as EdH depolarizes).
Masked where density<5% peak.  NEW psi13.  env: KEY, FPS, OUT, LABEL."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"spintex_xy_{KEY}.mp4"); AHO=0.78
LABEL=os.environ.get("LABEL",KEY)
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2
half=L/2*AHO; ext=[-half,half,-half,half]; ax=(np.arange(ng)-ng//2)*(L/ng)*AHO
def slice_f(p):
    fx=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p))[:,:,c]; fy=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p))[:,:,c]; fz=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p))[:,:,c]; n=(np.abs(p)**2).sum(-1)[:,:,c]
    m=n>0.05*n.max()
    return np.where(m,fx/np.maximum(n,1e-12),0),np.where(m,fy/np.maximum(n,1e-12),0),np.where(m,fz/np.maximum(n,1e-12),0)
SX=[];SY=[];SZ=[]
for p in ps: a,b,d=slice_f(p); SX.append(a);SY.append(b);SZ.append(d)
SX=np.array(SX);SY=np.array(SY);SZ=np.array(SZ)
sperp=np.hypot(SX,SY); smax=np.percentile(sperp[sperp>0],99)+1e-9
st=2; idx=np.arange(0,ng,st); XX,YY=np.meshgrid(ax[idx],ax[idx],indexing="ij")
tmp=tempfile.mkdtemp(); print(f"[spintex_xy] {nf} frames smax_perp={smax:.2f}")
for k in range(nf):
    fig,a=plt.subplots(figsize=(7.0,6.6))
    im=a.imshow(SZ[k].T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    cb=fig.colorbar(im,ax=a,fraction=0.046,pad=0.04); cb.set_label("面外スピン s_z = F_z/n （量子化軸, −6=分極）")
    a.quiver(XX,YY,SX[k][::st,::st],SY[k][::st,::st],color="k",scale=smax*len(idx)*1.1,width=0.005,alpha=0.9)
    a.set_xlabel("x (μm)"); a.set_ylabel("y (μm)")
    a.set_title(f"{LABEL} スピンテクスチャ x-y面（z中央スライス）\n面内矢印=(s_x,s_y)＝ℓ=1巻き, 色=s_z",fontsize=12)
    fig.text(0.5,0.945,f"t = {tms[k]:6.1f} ms   B={Bg[k]*1e6:.0f}µG",ha="center",fontsize=15,fontweight="bold",family="monospace",color="#222")
    fig.subplots_adjust(top=0.86,bottom=0.09,left=0.11,right=0.98)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
