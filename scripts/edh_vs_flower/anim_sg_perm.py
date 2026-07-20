"""Normal (untilted) Stern-Gerlach absorption image, per m-component, over time.
Each panel = column density INTdy |psi_m|^2 in (x,z), for m = +6..-6 (SG separates
by m). Per-panel normalized (own max) with population fraction N_m/N annotated, so
even tiny components' spatial shape is visible. NEW psi13.  env: KEY, LABEL, FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"sg_perm_{KEY}.mp4"); LABEL=os.environ.get("LABEL",KEY); AHO=0.78
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; half=L/2*AHO; ext=[-half,half,-half,half]
mlist=list(range(6,-7,-1))                          # +6 .. -6
idxs=[int(np.where(ms==m)[0][0]) for m in mlist]
tmp=tempfile.mkdtemp(); print(f"[sg_perm] {nf} frames, {len(mlist)} m-panels")
for k in range(nf):
    p=ps[k]; Ntot=(np.abs(p)**2).sum()
    fig,axs=plt.subplots(1,13,figsize=(20,2.4)); fig.subplots_adjust(left=0.02,right=0.995,bottom=0.02,top=0.72,wspace=0.10)
    for a,m,ic in zip(axs,mlist,idxs):
        col=(np.abs(p[...,ic])**2).sum(1)              # INT dy -> (x,z)
        frac=100*(np.abs(p[...,ic])**2).sum()/Ntot
        # panels below 0.05% population: essentially empty -> show black (don't
        # self-normalize numerical noise into a fake pattern)
        if frac<0.05: col=np.zeros_like(col); vmax=1.0
        else: vmax=col.max()+1e-30
        a.imshow(col.T,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vmax,aspect="equal")
        a.set_title(f"m={m:+d}\n{frac:4.1f}%",fontsize=8); a.set_xticks([]); a.set_yticks([])
    fig.suptitle(f"{LABEL}: 通常SG（無傾斜）m分解カラム密度 ∫dy|ψ_m|²（各パネル自己規格化）　t={tms[k]:.0f} ms  B={Bg[k]*1e6:.0f}µG",fontsize=12,y=0.95)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
