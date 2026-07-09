"""Poster panel: spin texture (xy plane, upper z-slice) FULL-SIM vs RECON(l=+1) vs ERROR.
Masked (density>5%), physical-length arrows=(Fx,Fy)/atom, colour=Fz. Minimal English
axis labels + slim colourbars; no plot title (added later in PPT). One PNG per phase.
env: PSI13, GOTO, T_MS, OUT, A_HO_UM, NR, LAM, ZPICK(l0; auto=upper strongest if unset)"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":1.0,
                     "xtick.labelsize":10,"ytick.labelsize":10})
from matplotlib.ticker import MaxNLocator
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; T_MS=float(os.environ.get("T_MS","140"))
OUT=os.environ.get("OUT","poster_spintex.png"); AHO=float(os.environ.get("A_HO_UM","0.78"))
NR=int(os.environ.get("NR","18")); LAM=float(os.environ.get("LAM","2e-3"))
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]; Ng=psi.shape[0]; ax=np.linspace(-L/2,L/2,Ng)
half=L/2*AHO; ext=[-half,half,-half,half]
Xg=ax[:,None]*np.ones((1,Ng)); Yg=np.ones((Ng,1))*ax[None,:]; RHO=np.hypot(Xg,Yg); PHI=np.arctan2(Yg,Xg)
r=np.linspace(0,L/2*1.02,NR); dr=r[1]-r[0]; pos=RHO/dr; j0=np.clip(np.floor(pos).astype(int),0,NR-2); frac=pos-j0
W=np.zeros((Ng,Ng,NR)); I,K=np.meshgrid(np.arange(Ng),np.arange(Ng),indexing="ij"); W[I,K,j0]+=1-frac; W[I,K,j0+1]+=frac
M_scl=W.sum(1); M_vec=(W*(Xg/np.clip(RHO,1e-9,None))[...,None]).sum(1)
def solve(M,c): A=M.T@M+LAM*np.trace(M.T@M)/NR*np.eye(NR); return np.linalg.solve(A,M.T@c)
def interp(p,rho): q=np.clip(rho/dr,0,NR-1-1e-6); j=np.floor(q).astype(int); f=q-j; return p[j]*(1-f)+p[j+1]*f
sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
n=np.sum(np.abs(psi)**2,-1); fxd,fyd,fzd=sd(FX),sd(FY),sd(FZ); nc=n.sum(1)
cfx=fxd.sum(1)/np.clip(nc,1e-30,None); cfy=fyd.sum(1)/np.clip(nc,1e-30,None); cfz=fzd.sum(1)/np.clip(nc,1e-30,None)
FxV,FyV,FzV=fxd/np.clip(n,1e-30,None),fyd/np.clip(n,1e-30,None),fzd/np.clip(n,1e-30,None)
def recon_z(z):
    w=nc[:,z]*np.hypot(cfx[:,z],cfy[:,z]); phi0=np.arctan2((cfy[:,z]*w).sum(),(cfx[:,z]*w).sum())
    g=(cfx[:,z]*np.cos(phi0)+cfy[:,z]*np.sin(phi0))*nc[:,z]
    nz=np.clip(interp(solve(M_scl,nc[:,z]),RHO),1e-30,None); a=interp(solve(M_vec,g),RHO)/nz; fz=interp(solve(M_scl,cfz[:,z]*nc[:,z]),RHO)/nz
    return np.clip(a*np.cos(PHI+phi0),-6,6),np.clip(a*np.sin(PHI+phi0),-6,6),np.clip(fz,-6,6)
# pick upper (z>peak) slice with strongest density-weighted transverse spin
zc=int(np.argmax(n.sum((0,1))))
if os.environ.get("ZPICK"): zsel=int(np.argmin(np.abs(ax-float(os.environ["ZPICK"]))))
else:
    cand=range(zc,min(zc+8,Ng)); sc=[(np.hypot(FxV[:,:,z],FyV[:,:,z])*n[:,:,z]).sum()/max(n[:,:,z].sum(),1e-30) for z in cand]
    zsel=list(cand)[int(np.argmax(sc))]
MF=float(os.environ.get("MASK_FRAC","0.02")); ST=int(os.environ.get("ST","2")); QSCALE=float(os.environ.get("QSCALE","42"))
ns=n[:,:,zsel]; m=ns>MF*ns.max()
FxT,FyT,FzT=FxV[:,:,zsel],FyV[:,:,zsel],FzV[:,:,zsel]; rX,rY,rZ=recon_z(zsel)
xx,yy=np.meshgrid(ax*AHO,ax*AHO,indexing="ij")
# tight axis limits from masked cloud extent (+margin) -> compact, texture fills panel
mi,mj=np.where(m); rad=(max(np.abs(ax[mi]).max(),np.abs(ax[mj]).max())*AHO+0.8)
lim=round(rad); tk=[t for t in (-8,-6,-4,-2,0,2,4,6,8) if abs(t)<=lim]
def tex(a2,fx,fy,fz):
    Sx=np.where(m,fx,np.nan);Sy=np.where(m,fy,np.nan);Sz=np.where(m,fz,np.nan)
    im=a2.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    a2.quiver(xx[::ST,::ST],yy[::ST,::ST],Sx[::ST,::ST],Sy[::ST,::ST],scale=QSCALE,width=0.007,pivot="mid")
    a2.set_xlim(-lim,lim); a2.set_ylim(-lim,lim); a2.set_xlabel("x (µm)",labelpad=1)
    a2.xaxis.set_major_locator(MaxNLocator(4,prune="both")); a2.set_yticks(tk); return im
# square panels (equal aspect, no internal white); vertical colourbars at far right
fig,axg=plt.subplots(1,3,figsize=(8.4,2.95)); fig.subplots_adjust(left=0.05,right=0.80,bottom=0.16,top=0.975,wspace=0.03)
im=tex(axg[0],FxT,FyT,FzT); tex(axg[1],rX,rY,rZ); axg[0].set_ylabel("y (µm)")
axg[1].set_yticklabels([]); axg[2].set_yticklabels([])
err=np.where(m,np.sqrt((rX-FxT)**2+(rY-FyT)**2+(rZ-FzT)**2),np.nan)
ie=axg[2].imshow(err.T,origin="lower",extent=ext,cmap="magma",vmin=0,aspect="equal")
axg[2].set_xlim(-lim,lim); axg[2].set_ylim(-lim,lim); axg[2].set_xlabel("x (µm)",labelpad=1)
axg[2].xaxis.set_major_locator(MaxNLocator(4,prune="both")); axg[2].set_yticks(tk)
p=axg[2].get_position()
def vcb(mp,x,lab,nt,ticks=None):
    cax=fig.add_axes([x,p.y0,0.017,p.height]); c=fig.colorbar(mp,cax=cax); c.set_label(lab,labelpad=2); c.ax.tick_params(labelsize=8)
    if ticks is not None: c.set_ticks(ticks)
    else: c.locator=MaxNLocator(nt); c.update_ticks()
    return c
vcb(im,p.x1+0.02,"Fz / atom",5,ticks=[-6,-3,0,3,6]); vcb(ie,p.x1+0.155,"|ΔF|",4)
fig.savefig(OUT,dpi=300,bbox_inches="tight",pad_inches=0.03); plt.close(fig)
print(f"wrote {OUT}  t={tms[k]:.0f}ms z={ax[zsel]*AHO:+.1f}µm (l0={ax[zsel]:+.1f})  |f_perp|(true)={(np.hypot(FxT,FyT)*ns).sum()/ns.sum():.2f}")
