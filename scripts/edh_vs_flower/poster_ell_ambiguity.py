"""What if we did NOT know l=+1? Two DIFFERENT spin textures (l=+1 truth and its
y-mirror = l=-1, opposite circulation) that produce the IDENTICAL y-axis (INT dy)
observation. Demonstrates the degeneracy that axisymmetry/l=+1 resolves.
Rows: l=+1 (top), l=-1 (bottom). Cols: xy texture | y-column <Fx>(x,z) | y-column <Fz>(x,z).
Cols 2,3 are identical between rows -> indistinguishable from y-imaging.
env: PSI13, GOTO, T_MS, A_HO_UM, OUT"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import FX, FY, FZ, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":1.0,"xtick.labelsize":9,"ytick.labelsize":9})
PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
T_MS=float(os.environ.get("T_MS","140")); AHO=float(os.environ.get("A_HO_UM","0.78")); OUT=os.environ.get("OUT","poster_ell_ambiguity.png")
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-T_MS)))
psiA=load_frames_bulk(open_psi13(PSI13),[k])[0]              # l=+1 truth
psiB=psiA[:,::-1,:,:]                                        # y-mirror -> l=-1 (opposite winding), same |psi|^2
Ng=psiA.shape[0]; ax=np.linspace(-L/2,L/2,Ng); half=L/2*AHO; ext=[-half,half,-half,half]
def fields(psi):
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    n=np.sum(np.abs(psi)**2,-1); return sd(FX),sd(FY),sd(FZ),n
FxA,FyA,FzA,nA=fields(psiA); FxB,FyB,FzB,nB=fields(psiB)
def col(fx,fz,nn):                                          # y-integrated (x,z)
    nc=nn.sum(1); return fx.sum(1)/np.clip(nc,1e-30,None), fz.sum(1)/np.clip(nc,1e-30,None), nc
cFxA,cFzA,ncA=col(FxA,FzA,nA); cFxB,cFzB,ncB=col(FxB,FzB,nB)
print("y-column identical? corr(<Fx>col A,B)=%.5f  corr(<Fz>col)=%.5f  max|dn|=%.2e"%(
    np.corrcoef(cFxA.ravel(),cFxB.ravel())[0,1], np.corrcoef(cFzA.ravel(),cFzB.ravel())[0,1], np.abs(ncA-ncB).max()))
# xy slice at upper strong-transverse z
zc=int(np.argmax(nA.sum((0,1)))); cand=range(zc,min(zc+7,Ng))
zsel=list(cand)[int(np.argmax([ (np.hypot(FxA[:,:,z],FyA[:,:,z])*nA[:,:,z]).sum() for z in cand ]))]
xx,yy=np.meshgrid(ax*AHO,ax*AHO,indexing="ij"); xz_x,xz_z=np.meshgrid(ax*AHO,ax*AHO,indexing="ij")
def texxy(a,fx,fy,fz,ns):
    m=ns>0.05*ns.max(); Sx=np.where(m,fx/np.clip(ns,1e-30,None),np.nan); Sy=np.where(m,fy/np.clip(ns,1e-30,None),np.nan); Sz=np.where(m,fz/np.clip(ns,1e-30,None),np.nan)
    im=a.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    a.quiver(xx[::2,::2],yy[::2,::2],Sx[::2,::2],Sy[::2,::2],scale=42,width=0.008,pivot="mid")
    return im
def colmap(a,g,nc,cl,cmap):
    m=nc>0.05*nc.max(); im=a.imshow(np.where(m,g,np.nan).T,origin="lower",extent=ext,cmap=cmap,vmin=-cl,vmax=cl,aspect="equal"); return im
fig,axs=plt.subplots(2,3,figsize=(9.4,6.4)); fig.subplots_adjust(left=0.10,right=0.90,bottom=0.08,top=0.90,wspace=0.10,hspace=0.10)
clx=round(max(np.abs(cFxA).max(),1.0))
imz=texxy(axs[0,0],FxA[:,:,zsel],FyA[:,:,zsel],FzA[:,:,zsel],nA[:,:,zsel]); texxy(axs[1,0],FxB[:,:,zsel],FyB[:,:,zsel],FzB[:,:,zsel],nB[:,:,zsel])
imx=colmap(axs[0,1],cFxA,ncA,clx,"RdBu_r"); colmap(axs[1,1],cFxB,ncB,clx,"RdBu_r")
imfz=colmap(axs[0,2],cFzA,ncA,6,"RdBu_r"); colmap(axs[1,2],cFzB,ncB,6,"RdBu_r")
for a in axs.ravel(): a.set_xlim(-half,half); a.set_ylim(-half,half); a.xaxis.set_major_locator(MaxNLocator(4,prune="both")); a.yaxis.set_major_locator(MaxNLocator(5))
for a in axs[0,:]: a.set_xticklabels([])
axs[0,0].set_ylabel("l = +1  (truth)\n\ny (µm)"); axs[1,0].set_ylabel("l = -1  (y-mirror)\n\ny (µm)")
axs[1,0].set_xlabel("x (µm)")
for j in (1,2): axs[1,j].set_xlabel("x (µm)"); axs[0,j].set_ylabel(""); axs[1,j].set_ylabel("z (µm)")
axs[0,0].set_title("spin texture (xy)",fontsize=11); axs[0,1].set_title("y-integrated <Fx> (x,z)",fontsize=11); axs[0,2].set_title("y-integrated <Fz> (x,z)",fontsize=11)
fig.text(0.5,0.95,"different spin textures (opposite winding)   -->   IDENTICAL y-integrated (INT dy) observation",ha="center",fontsize=12)
fig.colorbar(imz,ax=axs[:,0],location="right",shrink=0.5,pad=0.02,aspect=30).set_label("Fz/atom")
fig.colorbar(imx,ax=axs[:,1],location="right",shrink=0.5,pad=0.02,aspect=30).set_label("<Fx>col")
fig.colorbar(imfz,ax=axs[:,2],location="right",shrink=0.5,pad=0.02,aspect=30).set_label("<Fz>col")
fig.savefig(OUT,dpi=200,bbox_inches="tight"); plt.close(fig); print("wrote",OUT," z=%.1fµm"%(ax[zsel]*AHO))
