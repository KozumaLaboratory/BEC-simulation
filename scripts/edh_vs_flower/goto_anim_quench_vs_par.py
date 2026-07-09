"""Goto difference-imaging animation: EdH parabolic (clean) vs EdH quench.
2x2: rows = x-tilt, y-tilt ; cols = par_T90 (parabolic), QUENCH (exp 0.2ms).
m=-6 difference D = |[R psi]_-6|^2_INTdy - Cp |psi_-6|^2_INTdy.  COMMON colour scale
across all 4 panels (global max), so amplitude is directly comparable. env: FPS, OUT"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":1.0,"xtick.labelsize":8,"ytick.labelsize":8})
B=float(os.environ.get("BETA_DEG","16")); AHO=0.78; FPS=int(os.environ.get("FPS","12")); OUT=os.environ.get("OUT","goto_quench_vs_par.mp4")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("y",B)[i6,i6])**2
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
def loadset(psi13,goto):
    with h5py.File(goto,"r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    tms=t/om*1000; P=open_psi13(psi13); nf=min(psi13_nframes(P),len(tms)); ps=load_frames_bulk(P,list(range(nf)))
    Dx=np.array([m6(ps[k],rot("x",B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)])
    Dy=np.array([m6(ps[k],rot("y",B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)])
    return tms[:nf], Dx, Dy, L
print("[anim] loading par_T90 ..."); tP,DxP,DyP,L=loadset("par_T90_psi13.jld2","par_T90_goto.h5")
print("[anim] loading quench ..."); tQ,DxQ,DyQ,_=loadset("quench_psi13.jld2","quench_goto.h5")
Ng=DxP.shape[1]; half=L/2*AHO; ext=[-half,half,-half,half]
gmax=max(np.abs(DxP).max(),np.abs(DyP).max(),np.abs(DxQ).max(),np.abs(DyQ).max())+1e-30
nf=min(len(tP),len(tQ))
def xsym(D): return np.corrcoef(D.ravel(),D[::-1,:].ravel())[0,1]
tmp=tempfile.mkdtemp(); print(f"[anim] {nf} frames, gmax={gmax:.2g}")
for k in range(nf):
    fig,axs=plt.subplots(2,2,figsize=(7.4,7.3)); fig.subplots_adjust(left=0.10,right=0.87,bottom=0.06,top=0.90,wspace=0.08,hspace=0.16)
    panels=[(axs[0,0],DxP[k],f"par x-tilt  t={tP[k]:.0f}ms  S={xsym(DxP[k]):+.2f}"),
            (axs[0,1],DxQ[k],f"QUENCH x-tilt  t={tQ[k]:.0f}ms  S={xsym(DxQ[k]):+.2f}"),
            (axs[1,0],DyP[k],f"par y-tilt  S={xsym(DyP[k]):+.2f}"),
            (axs[1,1],DyQ[k],f"QUENCH y-tilt  S={xsym(DyQ[k]):+.2f}")]
    for a,D,ti in panels:
        im=a.imshow(D.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-gmax,vmax=gmax,aspect="equal")
        a.set_title(ti,fontsize=9.5); a.xaxis.set_major_locator(MaxNLocator(4,prune="both")); a.yaxis.set_major_locator(MaxNLocator(4,prune="both"))
    for a in (axs[1,0],axs[1,1]): a.set_xlabel("x (µm)")
    for a in (axs[0,0],axs[1,0]): a.set_ylabel("z (µm)")
    for a in (axs[0,0],axs[0,1]): a.set_xticklabels([])
    for a in (axs[0,1],axs[1,1]): a.set_yticklabels([])
    p=axs[0,1].get_position(); pb=axs[1,1].get_position()
    fig.colorbar(im,cax=fig.add_axes([0.89,pb.y0,0.02,p.y1-pb.y0])).set_label("m=-6 difference (common scale)")
    fig.text(0.5,0.955,"Goto difference imaging: CLEAN parabolic (left) vs QUENCH (right)  [common colour scale]",ha="center",fontsize=11)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=130); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
