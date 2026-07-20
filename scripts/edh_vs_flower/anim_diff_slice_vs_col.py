"""Difference imaging D as a SLICE (y=mid plane, no integration) vs COLUMN (INT dy),
side by side over time, to test whether the LOS y-integration changes the reversal
period. D = |[R_x(16)psi]_-6|^2 - Cp|psi_-6|^2, evaluated at y=center (slice) and
summed over y (column). NEW psi13 in resim/.  env: KEY, FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
from matplotlib.ticker import MaxNLocator
KEY=os.environ.get("KEY","par_T90"); B=float(os.environ.get("BETA_DEG","16")); AHO=0.78
FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"diff_slice_vs_col_{KEY}.mp4")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("x",B)[i6,i6])**2
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2; half=L/2*AHO; ext=[-half,half,-half,half]
def rotm6(psi,R): return np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2   # (x,y,z)
Dsl=[]; Dco=[]
for p in ps:
    a=rotm6(p,rot("x",B)); b=Cp*rotm6(p,rot("id",0))
    Dsl.append(a[:,c,:]-b[:,c,:]); Dco.append(a.sum(1)-b.sum(1))
Dsl=np.array(Dsl); Dco=np.array(Dco); gs=np.abs(Dsl).max()+1e-30; gc=np.abs(Dco).max()+1e-30
def xsym(d): return np.corrcoef(d.ravel(),d[::-1,:].ravel())[0,1]
tmp=tempfile.mkdtemp(); print(f"[slice_vs_col] {nf} frames  gs={gs:.2g} gc={gc:.2g}")
for k in range(nf):
    fig,axs=plt.subplots(1,2,figsize=(10.4,5.2)); fig.subplots_adjust(left=0.06,right=0.99,bottom=0.10,top=0.80,wspace=0.30)
    for a,arr,g,ti in [(axs[0],Dsl[k],gs,"断面 D（y=中央スライス, 積分なし）"),(axs[1],Dco[k],gc,"カラム D（∫dy 積分＝吸収撮像相当）")]:
        im=a.imshow(arr.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-g,vmax=g,aspect="equal")
        a.set_title(f"{ti}\n左右対称度 S={xsym(arr):+.2f}",fontsize=11); a.set_xlabel("x (μm)"); a.set_ylabel("z (μm)")
        a.xaxis.set_major_locator(MaxNLocator(5)); a.yaxis.set_major_locator(MaxNLocator(5))
        fig.colorbar(im,ax=a,fraction=0.046,pad=0.04)
    fig.suptitle(f"{KEY} EdH: 差分撮像 断面 vs 積分　t={tms[k]:.0f} ms  B={Bg[k]*1e6:.0f}µG",fontsize=13,y=0.95)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
