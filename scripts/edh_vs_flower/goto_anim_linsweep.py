"""Goto difference-imaging animation across the LINEAR ramp-speed sweep.
2 rows (x-tilt, y-tilt) x 5 cols (0.2, 2.9, 11.6, 43, 130 ms linear ramps).
m=-6 difference over time; each panel self-normalized (its own over-time max) so all
speeds are visible. Watch the checkerboard flip more for faster (non-adiabatic) ramps.
env: FPS, OUT"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":10,"font.family":"DejaVu Sans","xtick.labelsize":7,"ytick.labelsize":7})
B=16.0; AHO=0.78; FPS=int(os.environ.get("FPS","12")); OUT=os.environ.get("OUT","goto_linsweep.mp4")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("y",B)[i6,i6])**2
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
ramps=[("T0p14","0.2ms"),("T2","2.9ms"),("T8","11.6ms"),("T30","43ms"),("T90","130ms")]
DX={}; DY={}; TMS={}; L=18.0
for T,lab in ramps:
    print(f"[anim] loading {T} ...")
    with h5py.File(f"lin_{T}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    tms=t/om*1000; P=open_psi13(f"lin_{T}_psi13.jld2"); nf=min(psi13_nframes(P),len(tms)); ps=load_frames_bulk(P,list(range(nf)))
    DX[T]=np.array([m6(ps[k],rot("x",B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)])
    DY[T]=np.array([m6(ps[k],rot("y",B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)]); TMS[T]=tms[:nf]; del ps
Ng=DX["T0p14"].shape[1]; half=L/2*AHO; ext=[-half,half,-half,half]; nf=min(len(TMS[T]) for T,_ in ramps)
nx={T:np.abs(DX[T]).max()+1e-30 for T,_ in ramps}; ny={T:np.abs(DY[T]).max()+1e-30 for T,_ in ramps}
def xsym(D): return np.corrcoef(D.ravel(),D[::-1,:].ravel())[0,1]
tmp=tempfile.mkdtemp(); print(f"[anim] rendering {nf} frames")
for k in range(nf):
    fig,axs=plt.subplots(2,5,figsize=(16,6.4)); fig.subplots_adjust(left=0.05,right=0.99,bottom=0.07,top=0.88,wspace=0.08,hspace=0.14)
    for j,(T,lab) in enumerate(ramps):
        for ri,(D,nrm,tl) in enumerate([(DX[T][k]/nx[T],nx,"x-tilt"),(DY[T][k]/ny[T],ny,"y-tilt")]):
            im=axs[ri,j].imshow(D.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-1,vmax=1,aspect="equal")
            axs[ri,j].xaxis.set_major_locator(MaxNLocator(3,prune="both")); axs[ri,j].yaxis.set_major_locator(MaxNLocator(3,prune="both"))
            if ri==0: axs[ri,j].set_title(f"lin {lab}\nx-tilt t={TMS[T][k]:.0f}ms S={xsym(DX[T][k]):+.2f}",fontsize=9); axs[ri,j].set_xticklabels([])
            else: axs[ri,j].set_title(f"y-tilt S={xsym(DY[T][k]):+.2f}",fontsize=9); axs[ri,j].set_xlabel("x(µm)",fontsize=8)
            if j==0: axs[ri,j].set_ylabel(("x-tilt" if ri==0 else "y-tilt")+"\nz(µm)",fontsize=8)
    fig.suptitle("EdH LINEAR ramp-speed sweep — Goto difference imaging (m=-6). fast (left) -> slow (right). each panel self-normalized",fontsize=12,y=0.965)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
