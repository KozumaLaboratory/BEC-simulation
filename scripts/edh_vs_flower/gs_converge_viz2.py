#!/usr/bin/env python3
"""GS convergence — expanded: log-scale ALL metrics + xy/xz slices (density/spin/phase) anim."""
import os, subprocess, tempfile
import numpy as np, h5py
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

SCR=os.path.dirname(os.path.abspath(__file__))
f=h5py.File(os.path.join(SCR,"gs_trajectory.jld2"),"r")
E=np.asarray(f["energy"]); gn=np.asarray(f["grad_norm"]); Fz=np.asarray(f["Fz"]); Fp=np.asarray(f["Fperp"])
pr=f["populations"][()]
if getattr(pr,"dtype",None) is not None and pr.dtype.names and "parent" in pr.dtype.names:
    pops=np.asarray(f[pr["parent"]][()])
else: pops=np.asarray(f["populations"])
if pops.shape[0]==13: pops=pops.T
def g3(k):
    a=np.asarray(f[k]); return a if a.shape[-1]==len(E) else np.moveaxis(a,0,-1)
n_xy=g3("n_xy"); fx_xy=g3("fx_xy"); fy_xy=g3("fy_xy"); fz_xy=g3("fz_xy"); a6_xy=g3("arg6_xy")
n_xz=g3("n_xz"); fz_xz=g3("fz_xz"); a6_xz=g3("arg6_xz")
L=float(f["box"][()]); nrec=len(E); idx=np.arange(nrec)
is_itp=np.isnan(gn); nb=int(np.sum(is_itp))
mvals=np.arange(6,-7,-1); Einf=E[-1]
print(f"nrec={nrec} ITP={nb} LBFGS={nrec-nb} E:{E[0]:.3f}->{E[-1]:.4f} |g|f={gn[-1]:.2e} Fz:{Fz[0]:.3f}->{Fz[-1]:.4f} Fperp:{Fp[0]:.3f}->{Fp[-1]:.2e}")

# ---------- log-scale convergence (2x3) ----------
fig,ax=plt.subplots(2,3,figsize=(15,8),constrained_layout=True)
def mark(a): a.axvline(nb,color='r',ls='--',alpha=.5,lw=1)
ax[0,0].plot(idx,E,'C0-'); mark(ax[0,0]); ax[0,0].set_title("E (linear)"); ax[0,0].set_ylabel("E")
ax[0,1].semilogy(idx,np.clip(np.abs(E-Einf),1e-9,None),'C0-'); mark(ax[0,1]); ax[0,1].set_title(r"$|E-E_\infty|$ (log)")
ax[0,2].semilogy(idx[~is_itp],np.clip(gn[~is_itp],1e-9,None),'C1.-'); mark(ax[0,2]); ax[0,2].set_title(r"$|\nabla E|$ LBFGS (log)")
ax[1,0].semilogy(idx,np.clip(1-pops[:,12],1e-12,1),'C3-'); mark(ax[1,0]); ax[1,0].set_title(r"$1-P(m{=}-6)$ (log)")
ax[1,1].semilogy(idx,np.clip(np.abs(Fz+6),1e-12,None),'C2-'); mark(ax[1,1]); ax[1,1].set_title(r"$|\langle F_z\rangle+6|$ (log)")
ax[1,2].semilogy(idx,np.clip(Fp,1e-9,None),'C4-'); mark(ax[1,2]); ax[1,2].set_title(r"$\int|F_\perp|/\!\int n$ (log)")
for a in ax.flat: a.set_xlabel("record")
fig.suptitle(f"GS convergence (log): random→ITP({nb})→LBFGS({nrec-nb})  final |∇|={gn[-1]:.2e}, 1-P(-6)={1-pops[-1,12]:.1e}, |Fperp|={Fp[-1]:.1e}",fontsize=12)
fig.savefig(os.path.join(SCR,"gs_convergence_curves_log.png"),dpi=130); print("wrote gs_convergence_curves_log.png")

# ---------- expanded animation: xy & xz, density/spin/phase + populations ----------
ext=[-L/2,L/2,-L/2,L/2]
nmax=max(n_xy.max(),n_xz.max()); fzmax=max(np.abs(fz_xy).max(),np.abs(fz_xz).max())+1e-30
N=n_xy.shape[0]; xs=np.linspace(-L/2,L/2,N); X,Y=np.meshgrid(xs,xs,indexing="ij"); sk=4
def maskphase(a,n): return np.ma.array(a,mask=n<0.05*nmax)
tmp=tempfile.mkdtemp(); FPS=20; DUR=16; nout=FPS*DUR
sel=np.linspace(0,nrec-1,nout).round().astype(int)
figA=plt.figure(figsize=(15,9))
for oi,k in enumerate(sel):
    figA.clf(); gs=GridSpec(3,3,figure=figA,height_ratios=[1,1,0.5])
    # row1 xy
    a=figA.add_subplot(gs[0,0]); a.imshow(n_xy[:,:,k].T,origin="lower",extent=ext,cmap="viridis",vmin=0,vmax=nmax,aspect="equal"); a.set_title("density xy (z=0)",fontsize=10); a.set_ylabel("y [μm]")
    a=figA.add_subplot(gs[0,1]); a.imshow(fz_xy[:,:,k].T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-fzmax,vmax=fzmax,aspect="equal")
    u=fx_xy[:,:,k]; v=fy_xy[:,:,k]; m=n_xy[:,:,k]>0.1*nmax
    a.quiver(X[::sk,::sk],Y[::sk,::sk],np.where(m,u,np.nan)[::sk,::sk],np.where(m,v,np.nan)[::sk,::sk],color="k",scale=fzmax*20,width=0.005)
    a.set_title(r"spin xy: $f_z$ bg + $(f_x,f_y)$",fontsize=10)
    a=figA.add_subplot(gs[0,2]); a.imshow(maskphase(a6_xy[:,:,k],n_xy[:,:,k]).T,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal"); a.set_title(r"phase $\arg\psi_{-6}$ xy",fontsize=10)
    # row2 xz
    a=figA.add_subplot(gs[1,0]); a.imshow(n_xz[:,:,k].T,origin="lower",extent=ext,cmap="viridis",vmin=0,vmax=nmax,aspect="equal"); a.set_title("density xz (y=0)",fontsize=10); a.set_xlabel("x [μm]"); a.set_ylabel("z [μm]")
    a=figA.add_subplot(gs[1,1]); a.imshow(fz_xz[:,:,k].T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-fzmax,vmax=fzmax,aspect="equal"); a.set_title(r"spin xz: $f_z$",fontsize=10); a.set_xlabel("x [μm]")
    a=figA.add_subplot(gs[1,2]); a.imshow(maskphase(a6_xz[:,:,k],n_xz[:,:,k]).T,origin="lower",extent=ext,cmap="hsv",vmin=-np.pi,vmax=np.pi,aspect="equal"); a.set_title(r"phase $\arg\psi_{-6}$ xz",fontsize=10); a.set_xlabel("x [μm]")
    # row3 populations
    a=figA.add_subplot(gs[2,:]); a.bar(mvals,pops[k],color=["C3" if mm==-6 else "C0" for mm in mvals]); a.set_ylim(0,1.05); a.set_title("populations",fontsize=10); a.set_xlabel("m"); a.set_xticks(mvals)
    ph="ITP" if is_itp[k] else "LBFGS"; gt=f" |∇|={gn[k]:.2e}" if not is_itp[k] else ""
    figA.suptitle(f"{ph}  E={E[k]:.4f}  ⟨Fz⟩={Fz[k]:+.4f}  P(-6)={pops[k,12]:.5f}{gt}",fontsize=12,family="monospace")
    figA.savefig(os.path.join(tmp,f"f_{oi:05d}.png"),dpi=92)
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",os.path.join(tmp,"f_%05d.png"),
    "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2","-c:v","libx264","-pix_fmt","yuv420p","-b:v","5000k",
    os.path.join(SCR,"gs_convergence_xyz.mp4")],check=True)
print("wrote gs_convergence_xyz.mp4")
