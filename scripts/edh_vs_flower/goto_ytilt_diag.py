"""Why does y-tilt look the SAME for EdH and Flower in Goto's difference imaging?
LOS = y (INT dy). Show, for FL and EdH: INTdy f_x, INTdy f_y, INTdy|psi_-5|^2 (the
symmetric population term), and the actual difference maps D_x (x-tilt), D_y (y-tilt).
D_x ~ -INTf_y + pop, D_y ~ +INTf_x + pop.  env: OUT"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, load_frames_bulk, open_psi13
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":10,"font.family":"DejaVu Sans","xtick.labelsize":7,"ytick.labelsize":7})
B=16.0; AHO=0.78; OUT=os.environ.get("OUT","goto_ytilt_diag.png")
i6=int(np.where(ms==-6)[0][0]); i5=int(np.where(ms==-5)[0][0]); Cp=np.abs(rot("y",B)[i6,i6])**2
def load(psi13,goto,tgt):
    with h5py.File(goto,"r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    tms=t/om*1000; k=int(np.argmin(np.abs(tms-tgt))); return load_frames_bulk(open_psi13(psi13),[k])[0], L, tms[k]
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
cases=[("Flower","flower120_psi13.jld2","flower120_goto.h5",260),("EdH","par_T90_psi13.jld2","par_T90_goto.h5",180)]
fig,axs=plt.subplots(2,5,figsize=(15,6.2)); fig.subplots_adjust(left=0.06,right=0.99,bottom=0.07,top=0.90,wspace=0.10,hspace=0.22)
titles=["∫dy f_x  (→ D_y, y-tilt)","∫dy f_y  (→ D_x, x-tilt)","∫dy |ψ₋₅|²  (symmetric pop.)","D_x  (x-tilt diff)","D_y  (y-tilt diff)"]
for ri,(lab,psi13,goto,tgt) in enumerate(cases):
    psi,L,tms=load(psi13,goto,tgt); Ng=psi.shape[0]; half=L/2*AHO; ext=[-half,half,-half,half]
    sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi)); n=np.sum(np.abs(psi)**2,-1); nc=n.sum(1); m=nc>0.03*nc.max()
    ifx=sd(FX).sum(1); ify=sd(FY).sum(1); pop5=(np.abs(psi[...,i5])**2).sum(1)
    u=m6(psi,rot("id",0)); Dx=m6(psi,rot("x",B))-Cp*u; Dy=m6(psi,rot("y",B))-Cp*u
    maps=[ifx,ify,pop5,Dx,Dy]; cmaps=["RdBu_r","RdBu_r","viridis","RdBu_r","RdBu_r"]
    for ci,(M,cm) in enumerate(zip(maps,cmaps)):
        Mm=np.where(m,M,np.nan); v=np.nanmax(np.abs(Mm))+1e-30
        if cm=="viridis": im=axs[ri,ci].imshow(Mm.T,origin="lower",extent=ext,cmap=cm,vmin=0,vmax=v,aspect="equal")
        else: im=axs[ri,ci].imshow(Mm.T,origin="lower",extent=ext,cmap=cm,vmin=-v,vmax=v,aspect="equal")
        if ri==0: axs[ri,ci].set_title(titles[ci],fontsize=10)
        axs[ri,ci].set_xlim(-half,half);axs[ri,ci].set_ylim(-half,half); axs[ri,ci].xaxis.set_major_locator(MaxNLocator(3,prune="both")); axs[ri,ci].yaxis.set_major_locator(MaxNLocator(3,prune="both"))
        if ci==0: axs[ri,ci].set_ylabel(f"{lab}\nt={tms:.0f}ms\nz(µm)",fontsize=9)
        if ri==1: axs[ri,ci].set_xlabel("x(µm)",fontsize=8)
fig.suptitle("Goto difference imaging (LOS=y): components behind x-tilt (D_x∝∫f_y) and y-tilt (D_y∝∫f_x)",fontsize=12,y=0.965)
fig.savefig(OUT,dpi=140,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)
