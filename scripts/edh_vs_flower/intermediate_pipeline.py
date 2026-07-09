"""Intermediate quantities of our pipeline (raw -> texture).
Row1: per-setting visible-block CENTROID s^(k)(x,z) for the 5 settings (id,Ry+-,Rx+-).
      s = sum_V m [INTdy n_m] / sum_V [INTdy n_m]  (V = m=-6..-3 visible block).
Row2: the extracted COLUMN spin vector from 5-setting finite differences:
      <Fz>=s^(0),  <Fx>=-(s^{y+}-s^{y-})/(2 sin b),  <Fy>=+(s^{x+}-s^{x-})/(2 sin b).
Masked by column density. env: PSI13, GOTO, T_MS, BETA_DEG, A_HO_UM, OUT"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":0.9,"xtick.labelsize":8,"ytick.labelsize":8})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; T_MS=float(os.environ.get("T_MS","140"))
B=float(os.environ.get("BETA_DEG","16")); s16=np.sin(np.radians(B)); AHO=float(os.environ.get("A_HO_UM","0.78")); OUT=os.environ.get("OUT","intermediate_pipeline.png")
ms_v=ms[VISIBLE_IDX].astype(float); clip6=lambda A:np.clip(A,-6,6)
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-T_MS)))
psi=load_frames_bulk(open_psi13(PSI13),[k])[0]; Ng=psi.shape[0]; half=L/2*AHO; ext=[-half,half,-half,half]
ncol=np.sum(np.abs(psi)**2,-1).sum(1); m=ncol>0.03*ncol.max()
def cen(R):                                            # visible-block centroid on INT dy
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,VISIBLE_IDX].sum(1)
    return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
s0=cen(rot("id",0)); syp=cen(rot("y",B)); sym=cen(rot("y",-B)); sxp=cen(rot("x",B)); sxm=cen(rot("x",-B))
Fz=s0; Fx=clip6(-(syp-sym)/(2*s16)); Fy=clip6(+(sxp-sxm)/(2*s16))
def show(a,D,cmap,vmin,vmax,title,cb=False):
    Dm=np.where(m,D,np.nan); im=a.imshow(Dm.T,origin="lower",extent=ext,cmap=cmap,vmin=vmin,vmax=vmax,aspect="equal")
    a.set_title(title,fontsize=10); a.set_xlim(-half,half); a.set_ylim(-half,half)
    a.xaxis.set_major_locator(MaxNLocator(3,prune="both")); a.yaxis.set_major_locator(MaxNLocator(3,prune="both")); return im
cents=[("s(0)  [id]",s0),("s(y+)",syp),("s(y-)",sym),("s(x+)",sxp),("s(x-)",sxm)]
cvs=np.concatenate([c[1][m] for c in cents]); cmin,cmax=np.percentile(cvs,2),np.percentile(cvs,98)
fig,axs=plt.subplots(2,5,figsize=(13.5,5.6)); fig.subplots_adjust(left=0.05,right=0.93,bottom=0.09,top=0.88,wspace=0.10,hspace=0.30)
for j,(lab,D) in enumerate(cents):
    im1=show(axs[0,j],D,"viridis",cmin,cmax,lab); axs[0,j].set_xlabel("x (µm)",fontsize=8)
    if j==0: axs[0,j].set_ylabel("z (µm)",fontsize=8)
comps=[("<Fx> = -(s(y+)-s(y-))/(2 sin b)",Fx),("<Fy> = +(s(x+)-s(x-))/(2 sin b)",Fy),("<Fz> = s(0)",Fz)]
for j,(lab,D) in enumerate(comps):
    im2=show(axs[1,j],D,"RdBu_r",-6,6,lab); axs[1,j].set_xlabel("x (µm)",fontsize=8)
    if j==0: axs[1,j].set_ylabel("z (µm)",fontsize=8)
for j in (3,4): axs[1,j].axis("off")
p=axs[0,4].get_position(); fig.colorbar(im1,cax=fig.add_axes([0.94,p.y0,0.012,p.height])).set_label("centroid s (visible block)",fontsize=9)
p2=axs[1,2].get_position(); fig.colorbar(im2,cax=fig.add_axes([0.62,p2.y0,0.012,p2.height])).set_label("<F> / atom (column)",fontsize=9)
fig.text(0.5,0.955,f"Intermediate quantities (t={tms[k]:.0f}ms):  5 centroids (top)  ->  5-setting finite differences  ->  column spin vector <F>(x,z) (bottom)",ha="center",fontsize=12)
fig.savefig(OUT,dpi=160,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
