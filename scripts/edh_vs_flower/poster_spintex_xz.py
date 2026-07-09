"""Poster panel: xz-plane column spin texture FULL-SIM vs RECON(tilted-SG +-16 visible
block) vs ERROR. In-plane arrows=(<Fx>,<Fz>) column-averaged (INT dy), colour=<Fy>
(line-of-sight y = depth): far (-y) blue, near (+y) red (RdBu_r). Masked, physical-length
arrows, compact square panels, minimal English labels, no plot title.
env: PSI13, GOTO, T_MS, OUT, A_HO_UM, MASK_FRAC, ST, QSCALE, FYCLIM"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":1.0,"xtick.labelsize":10,"ytick.labelsize":10})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; T_MS=float(os.environ.get("T_MS","140"))
OUT=os.environ.get("OUT","poster_spintex_xz.png"); AHO=float(os.environ.get("A_HO_UM","0.78"))
MF=float(os.environ.get("MASK_FRAC","0.02")); ST=int(os.environ.get("ST","2")); QSCALE=float(os.environ.get("QSCALE","60"))
TH=16.0; s16=np.sin(np.radians(TH)); ms_v=ms[VISIBLE_IDX].astype(float); clip6=lambda A:np.clip(A,-6,6)
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]; Ng=psi.shape[0]; ax=np.linspace(-L/2,L/2,Ng)
half=L/2*AHO; ext=[-half,half,-half,half]
def col_cen(R):
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,VISIBLE_IDX].sum(1)
    return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
fzR=col_cen(rot("id",0)); fxR=-(col_cen(rot("y",TH))-col_cen(rot("y",-TH)))/(2*s16); fyR=+(col_cen(rot("x",TH))-col_cen(rot("x",-TH)))/(2*s16)
fxR,fyR,fzR=map(clip6,(fxR,fyR,fzR))
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
ncol=np.sum(np.abs(psi)**2,-1).sum(1)
fxT=sd(FX).sum(1)/np.clip(ncol,1e-30,None); fyT=sd(FY).sum(1)/np.clip(ncol,1e-30,None); fzT=sd(FZ).sum(1)/np.clip(ncol,1e-30,None)
m=ncol>MF*ncol.max()
cl=float(os.environ.get("FYCLIM", str(max(1.0,round(np.abs(fyT[m]).max()))) ))
mi,mj=np.where(m); lim=round(max(np.abs(ax[mi]).max(),np.abs(ax[mj]).max())*AHO+0.8)
xx,zz=np.meshgrid(ax*AHO,ax*AHO,indexing="ij")
def tex(a2,fx,fy,fz):
    Sx=np.where(m,fx,np.nan);Sz=np.where(m,fz,np.nan);Sy=np.where(m,fy,np.nan)
    im=a2.imshow(Sy.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-cl,vmax=cl,aspect="equal")
    a2.quiver(xx[::ST,::ST],zz[::ST,::ST],Sx[::ST,::ST],Sz[::ST,::ST],scale=QSCALE,width=0.007,pivot="mid")
    a2.set_xlim(-lim,lim); a2.set_ylim(-lim,lim); a2.set_xlabel("x (µm)",labelpad=1)
    a2.xaxis.set_major_locator(MaxNLocator(4,prune="both")); a2.yaxis.set_major_locator(MaxNLocator(5)); return im
fig,axg=plt.subplots(1,3,figsize=(8.4,2.95)); fig.subplots_adjust(left=0.05,right=0.80,bottom=0.16,top=0.975,wspace=0.03)
im=tex(axg[0],fxT,fyT,fzT); tex(axg[1],fxR,fyR,fzR); axg[0].set_ylabel("z (µm)"); axg[1].set_yticklabels([]); axg[2].set_yticklabels([])
err=np.where(m,np.sqrt((fxR-fxT)**2+(fyR-fyT)**2+(fzR-fzT)**2),np.nan)
ie=axg[2].imshow(err.T,origin="lower",extent=ext,cmap="magma",vmin=0,aspect="equal")
axg[2].set_xlim(-lim,lim); axg[2].set_ylim(-lim,lim); axg[2].set_xlabel("x (µm)",labelpad=1)
axg[2].xaxis.set_major_locator(MaxNLocator(4,prune="both")); axg[2].yaxis.set_major_locator(MaxNLocator(5))
p=axg[2].get_position()                                 # vertical colourbars at far right, matched to panel height
def vcb(mp,x,lab,nt):
    cax=fig.add_axes([x,p.y0,0.017,p.height]); c=fig.colorbar(mp,cax=cax); c.set_label(lab,labelpad=2)
    c.ax.tick_params(labelsize=8); c.locator=MaxNLocator(nt); c.update_ticks(); return c
vcb(im,p.x1+0.02,"Fy / atom",5); vcb(ie,p.x1+0.155,"|ΔF|",4)
fig.savefig(OUT,dpi=300,bbox_inches="tight",pad_inches=0.03); plt.close(fig)
print(f"wrote {OUT}  t={tms[k]:.0f}ms  Fyclim=±{cl:.0f}  |Fy_col|max={np.abs(fyT[m]).max():.2f}")
