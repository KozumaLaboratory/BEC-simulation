"""MASS CURRENT + QUANTUM (order-parameter) PHASE + SPIN, xy slice, over time.
HONEST: mass current & wavefunction phase are NOT reconstructable from absorption
(density-only) -> shown from the TRUE spinor, labeled. Spin panel too (truth).
xy slice at z=peak. env: PSI13, GOTO, A_HO_UM, FPS, OUT, LABEL"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":0.9,"xtick.labelsize":8,"ytick.labelsize":8})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; AHO=float(os.environ.get("A_HO_UM","0.78"))
FPS=int(os.environ.get("FPS","12")); OUT=os.environ["OUT"]; LABEL=os.environ.get("LABEL","EdH")
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
psis=load_frames_bulk(P,list(range(nf))); Ng=psis.shape[1]; ax=np.linspace(-L/2,L/2,Ng); half=L/2*AHO; ext=[-half,half,-half,half]
dx=(ax[1]-ax[0])                       # grid spacing (l0)
i5=int(np.where(ms==-5)[0][0])
nlast=np.sum(np.abs(psis[-1])**2,-1); zc=int(np.argmax(nlast.sum((0,1))))
xx,yy=np.meshgrid(ax*AHO,ax*AHO,indexing="ij"); st=2
tmp=tempfile.mkdtemp()
# global scales
jmax=0;
for k in range(0,nf,4):
    ps=psis[k][:,:,zc,:]; jx=np.zeros((Ng,Ng)); jy=np.zeros((Ng,Ng))
    for c in range(13):
        gx=np.gradient(ps[...,c],dx,axis=0); gy=np.gradient(ps[...,c],dx,axis=1)
        jx+=np.imag(np.conj(ps[...,c])*gx); jy+=np.imag(np.conj(ps[...,c])*gy)
    jmax=max(jmax,np.hypot(jx,jy).max())
for k in range(nf):
    ps=psis[k][:,:,zc,:]; n=np.sum(np.abs(ps)**2,-1); m=n>0.05*n.max()
    sd=lambda Op:np.real(np.einsum("xym,mn,xyn->xy",np.conj(ps),Op,ps))
    Fx=sd(FX)/np.clip(n,1e-30,None); Fy=sd(FY)/np.clip(n,1e-30,None); Fz=sd(FZ)/np.clip(n,1e-30,None)
    jx=np.zeros((Ng,Ng)); jy=np.zeros((Ng,Ng))
    for c in range(13):
        gx=np.gradient(ps[...,c],dx,axis=0); gy=np.gradient(ps[...,c],dx,axis=1)
        jx+=np.imag(np.conj(ps[...,c])*gx); jy+=np.imag(np.conj(ps[...,c])*gy)
    ph5=np.angle(ps[...,i5])                       # order-parameter phase of m=-5 (vortex l=-1)
    fig,axs=plt.subplots(1,3,figsize=(13,4.6)); fig.subplots_adjust(left=0.06,right=0.99,bottom=0.10,top=0.84,wspace=0.16)
    # 1 mass current
    Jx=np.where(m,jx,np.nan); Jy=np.where(m,jy,np.nan); mg=np.hypot(Jx,Jy)
    im0=axs[0].imshow(mg.T,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=jmax,aspect="equal")
    axs[0].quiver(xx[::st,::st],yy[::st,::st],Jx[::st,::st],Jy[::st,::st],color="cyan",scale=jmax*18,width=0.006,pivot="mid")
    axs[0].set_title("mass current  j=Im(Σψ*∇ψ)\n[TRUTH — NOT from absorption]",fontsize=10)
    # 2 order-parameter phase (m=-5)
    im1=axs[1].imshow(np.where(m,ph5,np.nan).T,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal")
    axs[1].set_title("wavefn phase arg(ψ₋₅) [vortex]\n[TRUTH — needs interferometry]",fontsize=10)
    # 3 spin
    im2=axs[2].imshow(np.where(m,Fz,np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    axs[2].quiver(xx[::st,::st],yy[::st,::st],np.where(m,Fx,np.nan)[::st,::st],np.where(m,Fy,np.nan)[::st,::st],scale=42,width=0.006,pivot="mid")
    axs[2].set_title("spin (Fx,Fy)/atom, color Fz\n[TRUTH]",fontsize=10)
    for a in axs: a.set_xlabel("x (µm)"); a.set_xlim(-half,half);a.set_ylim(-half,half); a.xaxis.set_major_locator(MaxNLocator(4,prune="both")); a.yaxis.set_major_locator(MaxNLocator(4,prune="both"))
    axs[0].set_ylabel("y (µm)")
    fig.suptitle(f"{LABEL}  mass flow / quantum phase / spin (xy slice, z={ax[zc]*AHO:+.1f}µm)   t={tms[k]:.0f}ms",fontsize=12,y=0.97)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=125); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
