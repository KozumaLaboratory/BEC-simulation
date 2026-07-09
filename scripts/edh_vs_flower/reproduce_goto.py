"""Reproduce Goto's discrimination method on OUR full-dynamics sim results.
For m=-6 (lowest Zeeman): D(x,z) = INTdy|[R_a(theta) psi]_-6|^2 - C_p * INTdy|psi_-6|^2,
with C_p=|<-6|R_a(theta)|-6>|^2 (cancels the tilt-projection population change).
Flower -> left-right (x-mirror) SYMMETRIC ; EdH -> checkerboard (ANTI-symmetric).
2x2 panels: rows = tilt axis (x,y), cols = (Flower, EdH). Prints x-mirror symmetry S.
env: EDH_PSI,EDH_GOTO,EDH_TMS, FL_PSI,FL_GOTO,FL_TMS, THETA_DEG, A_HO_UM, OUT"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":1.0,"xtick.labelsize":9,"ytick.labelsize":9})
TH=float(os.environ.get("THETA_DEG","10")); AHO=float(os.environ.get("A_HO_UM","0.78")); OUT=os.environ.get("OUT","reproduce_goto.png")
i6=int(np.where(ms==-6)[0][0])
def load(psi_e,goto_e,tms_e,tdef):
    with h5py.File(os.environ[goto_e],"r") as G:
        t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    tms=t/om*1000.0; k=int(np.argmin(np.abs(tms-float(os.environ.get(tms_e,tdef)))))
    return load_frames_bulk(open_psi13(os.environ[psi_e]),[k])[0], L, tms[k]
def diffmap(psi,axis):
    R=rot(axis,TH); Cp=np.abs(R[i6,i6])**2
    u=(np.abs(psi[...,i6])**2).sum(1)                       # untilted m=-6, INT dy -> (x,z)
    tl=(np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)  # tilted m=-6
    D=tl-Cp*u; return D/np.max(np.abs(D)+1e-30)             # normalized signed difference
def xsym(D):                                                # left-right (x-mirror) correlation
    a=D.ravel(); b=D[::-1,:].ravel(); return np.corrcoef(a,b)[0,1]
cases=[("FL","FL_PSI","FL_GOTO","FL_TMS","260"),("EDH","EDH_PSI","EDH_GOTO","EDH_TMS","140")]
fig,axs=plt.subplots(2,2,figsize=(7.4,7.2)); fig.subplots_adjust(left=0.11,right=0.87,bottom=0.08,top=0.90,wspace=0.08,hspace=0.14)
print(f"theta={TH}deg  m=-6 difference-map x-mirror symmetry S (flower~+1 symmetric, EdH~-1 checkerboard):")
for col,(tag,pe,ge,te,td) in enumerate(cases):
    psi,L,tms=load(pe,ge,te,td); half=L/2*AHO; ext=[-half,half,-half,half]
    for row,axis in enumerate(("x","y")):
        D=diffmap(psi,axis); S=xsym(D)
        im=axs[row,col].imshow(D.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-1,vmax=1,aspect="equal")
        axs[row,col].set_title(f"{tag}  {axis}-tilt {TH:.0f}°   S={S:+.2f}",fontsize=10)
        axs[row,col].xaxis.set_major_locator(MaxNLocator(4,prune="both")); axs[row,col].yaxis.set_major_locator(MaxNLocator(5))
        print(f"  {tag:3} {axis}-tilt: S = {S:+.3f}")
for a in axs[1,:]: a.set_xlabel("x (µm)")
for a in axs[:,0]: a.set_ylabel("z (µm)")
for a in axs[0,:]: a.set_xticklabels([])
for a in axs[:,1]: a.set_yticklabels([])
p=axs[0,1].get_position(); pb=axs[1,1].get_position()
cb=fig.colorbar(im,cax=fig.add_axes([0.89,pb.y0,0.02,p.y1-pb.y0])); cb.set_label("m=-6 difference (normalized)")
fig.text(0.5,0.955,"Goto discrimination reproduced on full-dynamics sim:  Flower = L-R symmetric,  EdH = checkerboard",ha="center",fontsize=11)
fig.savefig(OUT,dpi=200,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
