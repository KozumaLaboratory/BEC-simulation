#!/usr/bin/env python3
"""CSS-ness orthogonal-slice animation (smooth, full grid) for EdH/Flower.
s = |<F>|/(nF): pure local spinor s=1 <=> CSS (coherent spin state / max spin).
Three orthogonal slices through the density centroid, coloured by s (blue=CSS,
red=non-CSS), with in-plane <F>/atom arrows. Axes physical (x,y,z) via
transpose(3,2,1,0); z = B axis. Rows: EdH (top) / Flower (bottom, control).

env: GOTO_EDH, GOTO_FL, OUT(.mp4), VMIN=0.4, FPS=12, LABEL_EDH, LABEL_FL,
     FRAME_STRIDE=1, ARROW_STEP (0=auto)
"""
import os, numpy as np, h5py, shutil, subprocess
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

GOTO_EDH=os.environ["GOTO_EDH"]; GOTO_FL=os.environ.get("GOTO_FL","")
OUT=os.environ.get("OUT","css_slices.mp4"); VMIN=float(os.environ.get("VMIN","0.4"))
FPS=int(os.environ.get("FPS","12")); FSTR=int(os.environ.get("FRAME_STRIDE","1"))
LAB_E=os.environ.get("LABEL_EDH","EdH"); LAB_F=os.environ.get("LABEL_FL","Flower")
FRDIR=os.environ.get("FRAMES_DIR", os.path.splitext(OUT)[0]+"_frames"); os.makedirs(FRDIR,exist_ok=True)
CMAP=plt.cm.RdBu.copy(); CMAP.set_bad("white")

def load(fn):
    f=h5py.File(fn,"r"); T=lambda k: np.transpose(np.asarray(f[k]),(3,2,1,0))
    d=dict(F=float(f["meta/F"][()]), L=float(f["meta/L_box"][()]), t=f["t"][:],
           om=float(f["meta/omega_ref"][()]), B=f["B_gauss"][:]*1e6,
           fx=T("Fx_3d"), fy=T("Fy_3d"), fz=T("Fz_3d"), n=T("n_total_3d")); f.close(); return d

runs=[(load(GOTO_EDH),LAB_E)]
if GOTO_FL: runs.append((load(GOTO_FL),LAB_F))
L=runs[0][0]["L"]; Ng=runs[0][0]["n"].shape[1]; ext=[-L/2,L/2,-L/2,L/2]; c=Ng//2
NF=int(os.environ.get("N_FRAMES","120"))
tmax=min(d["t"][-1]/d["om"] for d,_ in runs); tmin=max(d["t"][0]/d["om"] for d,_ in runs)
tgrid=np.linspace(tmin,tmax,NF)[::FSTR]
idx=lambda d,tf: int(np.argmin(np.abs(d["t"]/d["om"]-tf)))
st=int(os.environ.get("ARROW_STEP","0")) or max(1,Ng//24)
AX,BX=np.meshgrid(np.linspace(-L/2,L/2,Ng,endpoint=False)[::st],
                  np.linspace(-L/2,L/2,Ng,endpoint=False)[::st],indexing="ij")
def per(a,nn): return np.divide(a,nn,out=np.zeros_like(a),where=nn>0.03*nn.max())

for fi,tf in enumerate(tgrid):
    fig,axes=plt.subplots(len(runs),3,figsize=(12.2,4.0*len(runs)),squeeze=False)
    tphys=tf*1e3
    for r,(d,lab) in enumerate(runs):
        it=idx(d,tf)
        n=d["n"][it]; nmax=n.max(); mag=np.sqrt(d["fx"][it]**2+d["fy"][it]**2+d["fz"][it]**2)
        s=np.full_like(n,np.nan); m=n>0.03*nmax; s[m]=mag[m]/(n[m]*d["F"])
        SX,SY,SZ=per(d["fx"][it],n),per(d["fy"][it],n),per(d["fz"][it],n)
        planes=[("z=0 (⊥B)",s[:,:,c].T,SX[:,:,c].T,SY[:,:,c].T,n[:,:,c].T,"x","y"),
                ("y=0 (∥B)",s[:,c,:].T,SX[:,c,:].T,SZ[:,c,:].T,n[:,c,:].T,"x","z (B)"),
                ("x=0 (∥B)",s[c,:,:].T,SY[c,:,:].T,SZ[c,:,:].T,n[c,:,:].T,"y","z (B)")]
        for ci,(ttl,s2,u2,v2,n2,xl,yl) in enumerate(planes):
            a=axes[r,ci]
            a.imshow(np.ma.masked_invalid(s2),origin="lower",extent=ext,cmap=CMAP,vmin=VMIN,vmax=1.0,
                     aspect="equal",interpolation="bilinear")
            msk=n2[::st,::st]>0.03*nmax
            a.quiver(AX,BX,np.where(msk,u2[::st,::st],0),np.where(msk,v2[::st,::st],0),
                     color="k",angles="xy",scale_units="xy",scale=6.0/(1.6*st*(L/Ng)),width=0.005,pivot="mid",alpha=0.8)
            a.set_xlabel(xl,fontsize=9); a.set_ylabel(yl,fontsize=9); a.set_xticks([]); a.set_yticks([])
            if r==0: a.set_title(ttl,fontsize=10)
        sw=np.average(s[m],weights=n[m])
        axes[r,0].text(-0.18,0.5,f"{lab}\nB={d['B'][it]:+.0f}µG  s̄={sw:.3f}",transform=axes[r,0].transAxes,
                       rotation=90,va="center",ha="center",fontsize=9,color="#2F4858")
    sm=plt.cm.ScalarMappable(cmap=CMAP,norm=plt.Normalize(VMIN,1.0))
    cax=fig.add_axes([0.34,0.03,0.34,0.015]); fig.colorbar(sm,cax=cax,orientation="horizontal").set_label(
        "CSS-ness s=|⟨F⟩|/(nF)   blue=CSS ←→ red=non-CSS   (arrows: in-plane ⟨F⟩/atom)",fontsize=9)
    fig.suptitle(f"EdH vs Flower — local coherent-spin-state map    t = {tphys:6.1f} ms",fontsize=12)
    fig.subplots_adjust(left=0.06,right=0.98,top=0.92,bottom=0.09,wspace=0.08,hspace=0.14)
    fig.savefig(f"{FRDIR}/f{fi:04d}.png",dpi=110); plt.close(fig)
    if fi%20==0: print("slice frame",fi,"t_ms=%.1f"%tphys)
print("frames ->",FRDIR)
if shutil.which("ffmpeg"):
    # mpeg4/-q:v is portable (TSUBAME's CUDA ffmpeg build has no libx264/-crf).
    subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-pattern_type","glob","-i",f"{FRDIR}/f*.png",
        "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2","-c:v","mpeg4","-q:v","3","-pix_fmt","yuv420p",OUT],check=False)
    print("wrote",OUT)
