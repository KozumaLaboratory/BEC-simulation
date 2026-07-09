"""Animate Goto's m=-6 difference-map discrimination over time (fine time steps).
2x2: cols=(Flower, EdH), rows=(x-tilt, y-tilt). Shows the EdH checkerboard emerging
while the Flower stays symmetric. Each panel normalized to its own over-time max.
env: EDH_PSI,EDH_GOTO, FL_PSI,FL_GOTO, THETA_DEG, A_HO_UM, FPS, OUT"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":1.0,"xtick.labelsize":9,"ytick.labelsize":9})
TH=float(os.environ.get("THETA_DEG","10")); AHO=float(os.environ.get("A_HO_UM","0.78"))
FPS=int(os.environ.get("FPS","12")); OUT=os.environ.get("OUT","reproduce_goto_anim.mp4")
i6=int(np.where(ms==-6)[0][0]); Rx=rot("x",TH); Ry=rot("y",TH); Cpx=np.abs(Rx[i6,i6])**2; Cpy=np.abs(Ry[i6,i6])**2
def meta(goto):
    with h5py.File(goto,"r") as G: return np.asarray(G["t"])/float(G["meta/omega_ref"][()])*1000.0, float(G["meta/L_box"][()])
FL_PSI=os.environ["FL_PSI"]; EDH_PSI=os.environ["EDH_PSI"]
tms_fl,L=meta(os.environ["FL_GOTO"]); tms_ed,_=meta(os.environ["EDH_GOTO"])
Pfl=open_psi13(FL_PSI); Ped=open_psi13(EDH_PSI); nf=min(psi13_nframes(Pfl),psi13_nframes(Ped),len(tms_fl),len(tms_ed))
print(f"[anim] {nf} frames, loading spinors ...")
psfl=load_frames_bulk(Pfl,list(range(nf))); psed=load_frames_bulk(Ped,list(range(nf)))
def dm(psi,R,Cp):
    u=(np.abs(psi[...,i6])**2).sum(1); tl=(np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1); return tl-Cp*u
def xsym(D): return np.corrcoef(D.ravel(),D[::-1,:].ravel())[0,1]
# precompute all difference maps + per-panel over-time max
panels=[("FL","x",psfl,Rx,Cpx,tms_fl),("EDH","x",psed,Rx,Cpx,tms_ed),
        ("FL","y",psfl,Ry,Cpy,tms_fl),("EDH","y",psed,Ry,Cpy,tms_ed)]
D=[[dm(ps[k],R,Cp) for k in range(nf)] for (_,_,ps,R,Cp,_) in panels]
norm=[max(np.max(np.abs(d)) for d in Dp)+1e-30 for Dp in D]
half=L/2*AHO; ext=[-half,half,-half,half]
tmp=tempfile.mkdtemp(); print("[anim] rendering frames ...")
for k in range(nf):
    fig,axs=plt.subplots(2,2,figsize=(7.2,7.1)); fig.subplots_adjust(left=0.10,right=0.87,bottom=0.07,top=0.90,wspace=0.08,hspace=0.14)
    order=[axs[0,0],axs[0,1],axs[1,0],axs[1,1]]
    for pi,((tag,axis,ps,R,Cp,tms),a) in enumerate(zip(panels,order)):
        Dn=D[pi][k]/norm[pi]; S=xsym(D[pi][k]); im=a.imshow(Dn.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-1,vmax=1,aspect="equal")
        a.set_title(f"{tag} {axis}-tilt  t={tms[k]:.0f}ms  S={S:+.2f}",fontsize=10)
        a.xaxis.set_major_locator(MaxNLocator(4,prune="both")); a.yaxis.set_major_locator(MaxNLocator(5))
    for a in (axs[1,0],axs[1,1]): a.set_xlabel("x (µm)")
    for a in (axs[0,0],axs[1,0]): a.set_ylabel("z (µm)")
    for a in (axs[0,0],axs[0,1]): a.set_xticklabels([])
    for a in (axs[0,1],axs[1,1]): a.set_yticklabels([])
    p=axs[0,1].get_position(); pb=axs[1,1].get_position()
    fig.colorbar(im,cax=fig.add_axes([0.89,pb.y0,0.02,p.y1-pb.y0])).set_label("m=-6 diff (norm)")
    fig.text(0.5,0.955,"Goto discrimination over time:  Flower stays symmetric,  EdH checkerboard emerges",ha="center",fontsize=11)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=130); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("[anim] wrote",OUT,f"({nf} frames @ {FPS}fps)")
