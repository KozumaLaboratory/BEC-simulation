"""x-y spin texture at SEVERAL z-slices (montage), over time. Shows how the ℓ=1
winding varies along the quantization axis z. Per-atom spin: arrows (s_x,s_y),
colour = s_z (RdBu_r, red=+z up / blue=-z down). Masked <5% peak. NEW psi13.
env: KEY, LABEL, ZOFF (comma voxel offsets from center), FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"spintex_xy_zslices_{KEY}.mp4"); LABEL=os.environ.get("LABEL",KEY); AHO=0.78
ZOFF=[int(x) for x in os.environ.get("ZOFF","-8,-4,0,4,8").split(",")]
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2
half=L/2*AHO; ext=[-half,half,-half,half]; ax=(np.arange(ng)-ng//2)*(L/ng)*AHO
zsl=[(c+o, ax[c+o]) for o in ZOFF]
def fields(p):
    return (np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)),
            np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p)),
            np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)),
            (np.abs(p)**2).sum(-1))
# precompute per-slice per-atom spins + global smax
DAT=[[] for _ in zsl]
for p in ps:
    fx,fy,fz,n=fields(p)
    for j,(iz,zz) in enumerate(zsl):
        nn=n[:,:,iz]; m=nn>0.05*n.max()
        DAT[j].append((np.where(m,fx[:,:,iz]/np.maximum(nn,1e-12),0),np.where(m,fy[:,:,iz]/np.maximum(nn,1e-12),0),np.where(m,fz[:,:,iz]/np.maximum(nn,1e-12),0)))
smax=0
for j in range(len(zsl)):
    for a,b,d in DAT[j]:
        sp=np.hypot(a,b);
        if (sp>0).any(): smax=max(smax,np.percentile(sp[sp>0],99))
smax+=1e-9; st=2; idx=np.arange(0,ng,st); XX,YY=np.meshgrid(ax[idx],ax[idx],indexing="ij")
tmp=tempfile.mkdtemp(); print(f"[xy_zslices] {nf} frames, z-slices {[round(z,1) for _,z in zsl]} μm, smax={smax:.2f}")
for k in range(nf):
    fig,axs=plt.subplots(1,len(zsl),figsize=(3.3*len(zsl),4.6)); fig.subplots_adjust(left=0.04,right=0.90,bottom=0.11,top=0.80,wspace=0.24)
    for a,(iz,zz),dz in zip(axs,zsl,[DAT[j][k] for j in range(len(zsl))]):
        sx,sy,sz=dz
        im=a.imshow(sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        a.quiver(XX,YY,sx[::st,::st],sy[::st,::st],color="k",scale=smax*len(idx)*1.1,width=0.006,alpha=0.9)
        a.set_title(f"z = {zz:+.1f} μm",fontsize=11); a.set_xlabel("x (μm)"); a.set_ylabel("y (μm)")
    fig.colorbar(im,ax=axs[-1],fraction=0.046,pad=0.04).set_label("s_z (赤=上/青=下)")
    fig.suptitle(f"{LABEL}\nx-y スピンテクスチャ 複数zスライス（面内矢印=(s_x,s_y)=ℓ=1巻き, 色=s_z）    t = {tms[k]:.0f} ms   B = {Bg[k]*1e6:.0f} μG",fontsize=11,y=0.985,va="top")
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
