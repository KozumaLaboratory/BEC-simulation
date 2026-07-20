"""Show the two terms of the Goto x-tilt difference imaging BEFORE subtraction:
  minuend    M = INTdy |[R_x(theta) psi]_-6|^2      (tilted m=-6 column density)
  subtrahend S = Cp * INTdy |psi_-6|^2               (untilted m=-6 column density x Cp)
  difference D = M - S                               (the checkerboard)
3-panel mp4 over time so one can see which part oscillates. NEW psi13 in resim/.
env: KEY, FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
from matplotlib.ticker import MaxNLocator
KEY=os.environ.get("KEY","par_T90"); B=float(os.environ.get("BETA_DEG","16")); AHO=0.78
FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"diff_terms_{KEY}.mp4")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("x",B)[i6,i6])**2
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf)))
M=np.array([m6(ps[k],rot("x",B)) for k in range(nf)])          # minuend
Sb=np.array([Cp*m6(ps[k],rot("id",0)) for k in range(nf)])     # subtrahend
D=M-Sb
half=L/2*AHO; ext=[-half,half,-half,half]
vpos=max(M.max(),Sb.max()); gmax=np.abs(D).max()+1e-30
tmp=tempfile.mkdtemp(); print(f"[diff_terms] {nf} frames  vpos={vpos:.2g} gmax={gmax:.2g} Cp={Cp:.4f}")
for k in range(nf):
    fig,axs=plt.subplots(1,3,figsize=(15,5.0)); fig.subplots_adjust(left=0.05,right=0.93,bottom=0.12,top=0.80,wspace=0.33)
    for a,arr,ti,cm,vlo,vhi,cl in [
        (axs[0],M[k],f"引かれる側 M = ∫dy |[R_x(+{B:.0f}°)ψ]₋₆|²",   "viridis",0,vpos,"カラム密度"),
        (axs[1],Sb[k],f"引く側 S = Cp·∫dy |ψ₋₆|²   (Cp={Cp:.3f})", "viridis",0,vpos,"カラム密度"),
        (axs[2],D[k], "差分 D = M − S（市松）",                      "RdBu_r",-gmax,gmax,"m=−6 差分")]:
        im=a.imshow(arr.T,origin="lower",extent=ext,cmap=cm,vmin=vlo,vmax=vhi,aspect="equal")
        a.set_title(ti,fontsize=11); a.set_xlabel("x (μm)"); a.set_ylabel("z (μm)")
        a.xaxis.set_major_locator(MaxNLocator(5)); a.yaxis.set_major_locator(MaxNLocator(5))
        fig.colorbar(im,ax=a,fraction=0.046,pad=0.04).set_label(cl,fontsize=9)
    fig.suptitle(f"{KEY}: 後藤差分撮像の引き算前の2項と差分　t={tms[k]:.0f} ms",fontsize=14,y=0.95)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
