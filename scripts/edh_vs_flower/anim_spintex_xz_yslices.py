"""Compare the x-z spin texture at y=0 vs y=finite (two slices side by side), dynamics.
Per-atom spin s=F/n: in-plane arrows (s_x,s_z), colour = s_y (out-of-plane/LOS).
Tests how the cross-section spin texture changes off the axis plane (finite y).
NEW psi13.  env: KEY, YOFF (voxel offset for the finite slice), FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); YOFF=int(os.environ.get("YOFF","4")); FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"spintex_xz_yslices_{KEY}.mp4"); AHO=0.78
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2
half=L/2*AHO; ext=[-half,half,-half,half]; ax=(np.arange(ng)-ng//2)*(L/ng)*AHO
yslices=[(c-YOFF,f"y = {ax[c-YOFF]:+.1f} μm"),(c,"y = 0"),(c+YOFF,f"y = {ax[c+YOFF]:+.1f} μm")]
def slice_fields(p,iy):
    fx=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p))[:,iy,:]; fy=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p))[:,iy,:]; fz=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p))[:,iy,:]; n=(np.abs(p)**2).sum(-1)[:,iy,:]
    m=n>0.05*n.max()
    return np.where(m,fx/np.maximum(n,1e-12),0),np.where(m,fy/np.maximum(n,1e-12),0),np.where(m,fz/np.maximum(n,1e-12),0)
# precompute for scales
DAT={iy:[] for iy,_ in yslices}
for p in ps:
    for iy,_ in yslices: DAT[iy].append(slice_fields(p,iy))
smax=0
for iy,_ in yslices:
    for sx,sy,sz in DAT[iy]: smax=max(smax,np.percentile(np.hypot(sx,sz)[np.hypot(sx,sz)>0] if (np.hypot(sx,sz)>0).any() else [0],99))
smax+=1e-9; st=2; idx=np.arange(0,ng,st); XX,ZZ=np.meshgrid(ax[idx],ax[idx],indexing="ij")
tmp=tempfile.mkdtemp(); print(f"[yslices] {nf} frames YOFF={YOFF} (y={ax[c+YOFF]:+.2f}µm) smax={smax:.2f}")
for k in range(nf):
    fig,axs=plt.subplots(1,4,figsize=(19.5,5.2)); fig.subplots_adjust(left=0.03,right=0.94,bottom=0.10,top=0.80,wspace=0.24)
    ssx=np.zeros((ng,ng)); ssy=np.zeros((ng,ng)); ssz=np.zeros((ng,ng))
    for a,(iy,lab) in zip(axs[:3],yslices):
        sx,sy,sz=DAT[iy][k]; ssx+=sx; ssy+=sy; ssz+=sz
        im=a.imshow(sy.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        a.quiver(XX,ZZ,sx[::st,::st],sz[::st,::st],color="k",scale=smax*len(idx)*1.1,width=0.005,alpha=0.9)
        a.set_title(f"{lab}\n面内=(s_x,s_z), 色=s_y",fontsize=11); a.set_xlabel("x (μm)"); a.set_ylabel("z (μm)")
    fig.colorbar(im,ax=axs[2],fraction=0.046,pad=0.04).set_label("s_y")
    a=axs[3]; gsum=max(np.abs(ssy).max(),1e-9)
    im2=a.imshow(ssy.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-gsum,vmax=gsum,aspect="equal")
    a.quiver(XX,ZZ,ssx[::st,::st],ssz[::st,::st],color="k",scale=smax*len(idx)*1.1,width=0.005,alpha=0.9)
    a.set_title("3スライスの和\n(±y の z-双極子が相殺→四重極が残る)",fontsize=11); a.set_xlabel("x (μm)"); a.set_ylabel("z (μm)")
    fig.colorbar(im2,ax=a,fraction=0.046,pad=0.04).set_label("Σ s_y")
    fig.suptitle(f"{KEY} EdH スピンテクスチャ x-z断面: y=−有限 / 0 / +有限 / 和　t={tms[k]:.0f} ms  B={Bg[k]*1e6:.0f}µG",fontsize=13,y=0.94)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
