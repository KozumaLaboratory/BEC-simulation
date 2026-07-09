"""End-to-end pipeline animation from SIMULATED ABSORPTION DATA ONLY.
STAGE in {raw, mid, xz, xy}. Everything after the raw absorption images is computed
from those images alone (visible-block centroids -> finite differences -> Abel+l=+1);
the true spinor is used ONLY to forward-model the tilted-SG images (= the 'camera').
env: PSI13, GOTO, STAGE, BETA_DEG, A_HO_UM, FPS, NR, LAM, OUT"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":11,"font.family":"DejaVu Sans","axes.linewidth":0.9,"xtick.labelsize":8,"ytick.labelsize":8})
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; STAGE=os.environ.get("STAGE","raw")
B=float(os.environ.get("BETA_DEG","16")); s16=np.sin(np.radians(B)); AHO=float(os.environ.get("A_HO_UM","0.78"))
FPS=int(os.environ.get("FPS","12")); NR=int(os.environ.get("NR","18")); LAM=float(os.environ.get("LAM","2e-3")); OUT=os.environ["OUT"]
ms_v=ms[VISIBLE_IDX].astype(float); clip6=lambda A:np.clip(A,-6,6)
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
print(f"[{STAGE}] loading {nf} frames ..."); psis=load_frames_bulk(P,list(range(nf))); Ng=psis.shape[1]
ax=np.linspace(-L/2,L/2,Ng); half=L/2*AHO; ext=[-half,half,-half,half]
Xg=ax[:,None]*np.ones((1,Ng)); Yg=np.ones((Ng,1))*ax[None,:]; RHO=np.hypot(Xg,Yg); PHI=np.arctan2(Yg,Xg)
r=np.linspace(0,L/2*1.02,NR); dr=r[1]-r[0]; pos=RHO/dr; j0=np.clip(np.floor(pos).astype(int),0,NR-2); frac=pos-j0
W=np.zeros((Ng,Ng,NR)); I,K=np.meshgrid(np.arange(Ng),np.arange(Ng),indexing="ij"); W[I,K,j0]+=1-frac; W[I,K,j0+1]+=frac
M_scl=W.sum(1); M_vec=(W*(Xg/np.clip(RHO,1e-9,None))[...,None]).sum(1)
solve=lambda M,c:np.linalg.solve(M.T@M+LAM*np.trace(M.T@M)/NR*np.eye(NR),M.T@c)
def interp(p,rho): q=np.clip(rho/dr,0,NR-1-1e-6); j=np.floor(q).astype(int); f=q-j; return p[j]*(1-f)+p[j+1]*f
MS=[-6,-5,-4,-3]; idx=[int(np.where(ms==m)[0][0]) for m in MS]
SET=[("id",rot("id",0)),(f"Ry+{B:.0f}",rot("y",B)),(f"Ry-{B:.0f}",rot("y",-B)),(f"Rx+{B:.0f}",rot("x",B)),(f"Rx-{B:.0f}",rot("x",-B))]
# fixed z-slice (upper, strongest transverse over the run) for xz/xy stages
def perp_of(psi): return np.hypot(np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),FX,psi)),np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),FY,psi)))
nlast=np.sum(np.abs(psis[-1])**2,-1); zc=int(np.argmax(nlast.sum((0,1)))); pl=perp_of(psis[-1])
zsel=zc+int(np.argmax([ (pl[:,:,z]*nlast[:,:,z]).sum() for z in range(zc,min(zc+7,Ng)) ]))
def raw_imgs(psi):
    out={}
    for lab,R in SET:
        o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
        out[lab]=[o[...,ii].sum(1) for ii in idx]      # per-m INT dy (x,z)
    return out
def centroid(imgs,lab):
    ov=np.stack(imgs[lab],-1); return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
def col_from_imgs(imgs):                                # column <F> from ABSORPTION IMAGES only
    s0=centroid(imgs,"id"); syp=centroid(imgs,f"Ry+{B:.0f}"); sym=centroid(imgs,f"Ry-{B:.0f}"); sxp=centroid(imgs,f"Rx+{B:.0f}"); sxm=centroid(imgs,f"Rx-{B:.0f}")
    return clip6(-(syp-sym)/(2*s16)), clip6(+(sxp-sxm)/(2*s16)), s0, (s0,syp,sym,sxp,sxm)
def truth_fields(psi):
    sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi)); n=np.sum(np.abs(psi)**2,-1); return sd(FX),sd(FY),sd(FZ),n
def recon_xy(cfx,cfy,cfz,ncol,z):                       # axisym + l=+1 at slice z, from column data
    w=ncol[:,z]*np.hypot(cfx[:,z],cfy[:,z]); phi0=np.arctan2((cfy[:,z]*w).sum(),(cfx[:,z]*w).sum())
    g=(cfx[:,z]*np.cos(phi0)+cfy[:,z]*np.sin(phi0))*ncol[:,z]
    nz=np.clip(interp(solve(M_scl,ncol[:,z]),RHO),1e-30,None); a=interp(solve(M_vec,g),RHO)/nz; fz=interp(solve(M_scl,cfz[:,z]*ncol[:,z]),RHO)/nz
    return clip6(a*np.cos(PHI+phi0)),clip6(a*np.sin(PHI+phi0)),clip6(fz)
xx,zz=np.meshgrid(ax*AHO,ax*AHO,indexing="ij")
def arrows(a,fx,fy,mask,sc,al=None):
    Sx=np.where(mask,fx,np.nan);Sy=np.where(mask,fy,np.nan)
    a.quiver(xx[::2,::2],zz[::2,::2],Sx[::2,::2],Sy[::2,::2],scale=sc,width=0.006,pivot="mid")
tmp=tempfile.mkdtemp(); print(f"[{STAGE}] rendering ...")
def savef(fig,k): fig.savefig(f"{tmp}/f{k:04d}.png",dpi=140); plt.close(fig)
for k in range(nf):
    psi=psis[k]; imgs=raw_imgs(psi)
    if STAGE=="raw":
        vmax=[max(imgs[l][mi].max() for l,_ in SET) for mi in range(4)]
        fig,axs=plt.subplots(5,4,figsize=(8.2,9.6)); fig.subplots_adjust(left=0.10,right=0.98,bottom=0.05,top=0.92,wspace=0.06,hspace=0.06)
        for si,(lab,_) in enumerate(SET):
            for mi in range(4):
                axs[si,mi].imshow(imgs[lab][mi].T,origin="lower",extent=ext,cmap="viridis",vmin=0,vmax=vmax[mi]+1e-30,aspect="equal")
                axs[si,mi].set_xlim(-half,half);axs[si,mi].set_ylim(-half,half)
                axs[si,mi].xaxis.set_major_locator(MaxNLocator(3,prune="both"));axs[si,mi].yaxis.set_major_locator(MaxNLocator(3,prune="both"))
                if si<4: axs[si,mi].set_xticklabels([])
                if mi>0: axs[si,mi].set_yticklabels([])
                if si==0: axs[si,mi].set_title(f"m={MS[mi]}",fontsize=11)
                if mi==0: axs[si,mi].set_ylabel(lab+"\nz(µm)",fontsize=8)
                if si==4: axs[si,mi].set_xlabel("x(µm)",fontsize=8)
        fig.suptitle(f"Stage1 RAW absorption (INT dy)  t={tms[k]:.0f}ms",fontsize=12,y=0.955); savef(fig,k)
    elif STAGE=="mid":
        Fx,Fy,Fz,cents=col_from_imgs(imgs); ncol=np.sum(np.abs(psi)**2,-1).sum(1); m=ncol>0.03*ncol.max()
        labs=["s(0)","s(y+)","s(y-)","s(x+)","s(x-)"]; cvs=np.concatenate([c[m] for c in cents]); cmn,cmx=np.percentile(cvs,2),np.percentile(cvs,98)
        fig,axs=plt.subplots(2,5,figsize=(13.5,5.6)); fig.subplots_adjust(left=0.05,right=0.93,bottom=0.09,top=0.86,wspace=0.10,hspace=0.32)
        for j,(lb,D) in enumerate(zip(labs,cents)):
            im1=axs[0,j].imshow(np.where(m,D,np.nan).T,origin="lower",extent=ext,cmap="viridis",vmin=cmn,vmax=cmx,aspect="equal"); axs[0,j].set_title(lb,fontsize=10); axs[0,j].set_xlabel("x(µm)",fontsize=8)
            axs[0,j].xaxis.set_major_locator(MaxNLocator(3,prune="both"));axs[0,j].yaxis.set_major_locator(MaxNLocator(3,prune="both"))
            if j==0: axs[0,j].set_ylabel("z(µm)",fontsize=8)
        for j,(lb,D) in enumerate([("<Fx>",Fx),("<Fy>",Fy),("<Fz>",Fz)]):
            im2=axs[1,j].imshow(np.where(m,D,np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal"); axs[1,j].set_title(lb,fontsize=11); axs[1,j].set_xlabel("x(µm)",fontsize=8)
            axs[1,j].xaxis.set_major_locator(MaxNLocator(3,prune="both"));axs[1,j].yaxis.set_major_locator(MaxNLocator(3,prune="both"))
            if j==0: axs[1,j].set_ylabel("z(µm)",fontsize=8)
        for j in (3,4): axs[1,j].axis("off")
        fig.suptitle(f"Stage2 centroids -> finite-diff column <F>(x,z)   t={tms[k]:.0f}ms",fontsize=12,y=0.95); savef(fig,k)
    elif STAGE=="xz":
        Fx,Fy,Fz,_=col_from_imgs(imgs); fxT,fyT,fzT,n3=truth_fields(psi); ncol=n3.sum(1)
        cfxT=fxT.sum(1)/np.clip(ncol,1e-30,None); cfyT=fyT.sum(1)/np.clip(ncol,1e-30,None); cfzT=fzT.sum(1)/np.clip(ncol,1e-30,None)
        m=ncol>0.03*ncol.max()
        fig,axg=plt.subplots(1,2,figsize=(7.0,3.7)); fig.subplots_adjust(left=0.09,right=0.86,bottom=0.15,top=0.86,wspace=0.06)
        for a,(fx,fy,fz,ti) in zip(axg,[(cfxT,cfyT,cfzT,"truth column"),(Fx,Fy,Fz,"recon (±16 data)")]):
            im=a.imshow(np.where(m,fy,np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-2,vmax=2,aspect="equal")
            arrows(a,np.where(m,fx,np.nan),np.where(m,fz,np.nan),m,60); a.set_title(ti,fontsize=10); a.set_xlabel("x(µm)"); a.set_xlim(-half,half);a.set_ylim(-half,half)
            a.xaxis.set_major_locator(MaxNLocator(4,prune="both"));a.yaxis.set_major_locator(MaxNLocator(5))
        axg[0].set_ylabel("z(µm)"); axg[1].set_yticklabels([])
        p=axg[1].get_position(); fig.colorbar(im,cax=fig.add_axes([0.88,p.y0,0.02,p.height])).set_label("<Fy> (color)",fontsize=9)
        fig.suptitle(f"Stage3 xz column texture [arrows=(<Fx>,<Fz>)]   t={tms[k]:.0f}ms",fontsize=11,y=0.96); savef(fig,k)
    elif STAGE=="xy":
        Fx,Fy,Fz,_=col_from_imgs(imgs); fxT,fyT,fzT,n3=truth_fields(psi); ncol=n3.sum(1)
        rX,rY,rZ=recon_xy(Fx,Fy,Fz,ncol,zsel); ns=n3[:,:,zsel]; m=ns>0.05*ns.max()
        FxT=fxT[:,:,zsel]/np.clip(ns,1e-30,None); FyT=fyT[:,:,zsel]/np.clip(ns,1e-30,None); FzT=fzT[:,:,zsel]/np.clip(ns,1e-30,None)
        xy_x,xy_y=np.meshgrid(ax*AHO,ax*AHO,indexing="ij")
        fig,axg=plt.subplots(1,2,figsize=(7.0,3.9)); fig.subplots_adjust(left=0.09,right=0.86,bottom=0.14,top=0.84,wspace=0.06)
        for a,(fx,fy,fz,ti) in zip(axg,[(FxT,FyT,FzT,"truth xy slice"),(rX,rY,rZ,"recon (±16 + axisym + l=1)")]):
            im=a.imshow(np.where(m,fz,np.nan).T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
            a.quiver(xy_x[::2,::2],xy_y[::2,::2],np.where(m,fx,np.nan)[::2,::2],np.where(m,fy,np.nan)[::2,::2],scale=42,width=0.006,pivot="mid")
            a.set_title(ti,fontsize=10); a.set_xlabel("x(µm)"); a.set_xlim(-half,half);a.set_ylim(-half,half)
            a.xaxis.set_major_locator(MaxNLocator(4,prune="both"));a.yaxis.set_major_locator(MaxNLocator(5))
        axg[0].set_ylabel("y(µm)"); axg[1].set_yticklabels([])
        p=axg[1].get_position(); fig.colorbar(im,cax=fig.add_axes([0.88,p.y0,0.02,p.height])).set_label("Fz (color)",fontsize=9)
        fig.suptitle(f"Stage4 xy texture (z={ax[zsel]*AHO:+.1f}µm) [arrows=(Fx,Fy)]   t={tms[k]:.0f}ms",fontsize=11,y=0.95); savef(fig,k)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print(f"[{STAGE}] wrote {OUT} ({nf} frames @ {FPS}fps)")
