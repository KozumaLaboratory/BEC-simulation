"""Column transverse spin <Fx>,<Fy>(x,z) reconstructed 3 ways from ABSORPTION DATA,
compared to truth, over time.  cols = TRUTH | our 5-angle (±16 visible centroid) |
Goto (m=-6 difference).  rows = <Fx>col, <Fy>col.  All from INT dy images (except
TRUTH which is the reference).  env: PSI13, GOTO, BETA_DEG, A_HO_UM, FPS, OUT, LABEL"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":0.9,"xtick.labelsize":8,"ytick.labelsize":8})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; B=float(os.environ.get("BETA_DEG","16")); s16=np.sin(np.radians(B)); thr=np.radians(B)
AHO=float(os.environ.get("A_HO_UM","0.78")); FPS=int(os.environ.get("FPS","12")); OUT=os.environ["OUT"]; LABEL=os.environ.get("LABEL","EdH")
ms_v=ms[VISIBLE_IDX].astype(float); i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("y",B)[i6,i6])**2; clip6=lambda A:np.clip(A,-6,6)
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
psis=load_frames_bulk(P,list(range(nf))); Ng=psis.shape[1]; ax=np.linspace(-L/2,L/2,Ng); half=L/2*AHO; ext=[-half,half,-half,half]
def cen(psi,R): o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,VISIBLE_IDX].sum(1); return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
tmp=tempfile.mkdtemp()
for k in range(nf):
    psi=psis[k]; n=np.sum(np.abs(psi)**2,-1); nc=n.sum(1); m=nc>0.03*nc.max()
    sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    fxT=sd(FX).sum(1)/np.clip(nc,1e-30,None); fyT=sd(FY).sum(1)/np.clip(nc,1e-30,None)   # truth column
    fxB=clip6(-(cen(psi,rot("y",B))-cen(psi,rot("y",-B)))/(2*s16)); fyB=clip6(+(cen(psi,rot("x",B))-cen(psi,rot("x",-B)))/(2*s16))  # 5-angle
    u=m6(psi,rot("id",0)); Dy=m6(psi,rot("y",B))-Cp*u; Dx=m6(psi,rot("x",B))-Cp*u
    fxG=clip6(Dy/np.clip(thr*nc,1e-30,None)); fyG=clip6(-Dx/np.clip(thr*nc,1e-30,None))    # Goto m=-6 diff
    fig,axs=plt.subplots(2,3,figsize=(11,7.2)); fig.subplots_adjust(left=0.08,right=0.92,bottom=0.07,top=0.88,wspace=0.10,hspace=0.16)
    dat=[[fxT,fxB,fxG],[fyT,fyB,fyG]]; rn=["<Fx> col","<Fy> col"]; cn=["TRUTH","our 5-angle (data)","Goto m=-6 diff (data)"]
    for ri in range(2):
        for ci in range(3):
            im=axs[ri,ci].imshow(np.where(m,dat[ri][ci],np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-3,vmax=3,aspect="equal")
            if ri==0: axs[ri,ci].set_title(cn[ci],fontsize=11)
            if ci==0: axs[ri,ci].set_ylabel(rn[ri]+"\nz (µm)",fontsize=10)
            if ri==1: axs[ri,ci].set_xlabel("x (µm)")
            axs[ri,ci].set_xlim(-half,half);axs[ri,ci].set_ylim(-half,half); axs[ri,ci].xaxis.set_major_locator(MaxNLocator(4,prune="both")); axs[ri,ci].yaxis.set_major_locator(MaxNLocator(4,prune="both"))
    fig.colorbar(im,cax=fig.add_axes([0.93,0.2,0.015,0.55])).set_label("<F> / atom")
    fig.suptitle(f"{LABEL}  column transverse spin: reconstruction from absorption vs truth   t={tms[k]:.0f}ms",fontsize=12,y=0.955)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=120); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
