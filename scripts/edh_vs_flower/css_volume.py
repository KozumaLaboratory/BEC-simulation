#!/usr/bin/env python3
"""3D CSS-ness volume animation (no slicing) for the EdH/Flower texture.

For a PURE local spinor  s(r)=|<F>|/(nF)=1  <=>  CSS (coherent spin state / max spin).
This renders, WITHOUT cutting the cloud into slices, the 3D SHAPE of the region that
has left the max-spin manifold:
  - translucent grey  = density envelope (isosurface n = ISO_N_FRAC * n_max), the cloud
  - solid red         = non-CSS shell   (isosurface s = S_THR): where EdH broke coherence
Axes are corrected to physical (x,y,z) via transpose(3,2,1,0);  z = B axis = vortex axis.
Side-by-side: EdH (GOTO_EDH) vs Flower (GOTO_FL).  Camera slowly rotates in azimuth.

env: GOTO_EDH, GOTO_FL, OUT(.mp4), S_THR=0.9, ISO_N_FRAC=0.08, FPS=15, SMOOTH=0.8,
     LABEL_EDH, LABEL_FL, FRAME_STRIDE=1
"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from skimage import measure
from scipy.ndimage import gaussian_filter

GOTO_EDH=os.environ["GOTO_EDH"]; GOTO_FL=os.environ.get("GOTO_FL","")
OUT=os.environ.get("OUT","css_volume.mp4")
S_THR=float(os.environ.get("S_THR","0.9"))
ISO_N=float(os.environ.get("ISO_N_FRAC","0.08"))
FPS=int(os.environ.get("FPS","15")); SMOOTH=float(os.environ.get("SMOOTH","0.8"))
LAB_E=os.environ.get("LABEL_EDH","EdH"); LAB_F=os.environ.get("LABEL_FL","Flower")
FSTR=int(os.environ.get("FRAME_STRIDE","1"))
FRDIR=os.environ.get("FRAMES_DIR", os.path.splitext(OUT)[0]+"_frames"); os.makedirs(FRDIR,exist_ok=True)

def load(fn):
    f=h5py.File(fn,"r")
    T=lambda k: np.transpose(np.asarray(f[k]),(3,2,1,0))  # -> (t,x,y,z)
    d=dict(F=float(f["meta/F"][()]), L=float(f["meta/L_box"][()]),
           t=f["t"][:], om=float(f["meta/omega_ref"][()]), B=f["B_gauss"][:]*1e6,
           fx=T("Fx_3d"), fy=T("Fy_3d"), fz=T("Fz_3d"), n=T("n_total_3d"))
    f.close(); return d

runs=[(load(GOTO_EDH),LAB_E)]
if GOTO_FL: runs.append((load(GOTO_FL),LAB_F))
L=runs[0][0]["L"]; Ng=runs[0][0]["n"].shape[1]; dx=L/Ng
# common PHYSICAL-time grid so a side-by-side stays time-synchronised even when the
# two runs saved at different cadences (nearest-time frame is picked per run).
NF=int(os.environ.get("N_FRAMES","120"))
tmax=min(d["t"][-1]/d["om"] for d,_ in runs); tmin=max(d["t"][0]/d["om"] for d,_ in runs)
tgrid=np.linspace(tmin,tmax,NF)[::FSTR]
idx=lambda d,tf: int(np.argmin(np.abs(d["t"]/d["om"]-tf)))
print("Ng",Ng,"NF",len(tgrid),"S_THR",S_THR,"tmax_ms",tmax)

def add_iso(ax, vol, level, color, alpha, dens_gate=None, gate_level=0.0):
    """marching-cubes isosurface of vol at `level`; optionally keep only where dens_gate>gate_level."""
    try:
        v=gaussian_filter(vol.astype(np.float64), SMOOTH) if SMOOTH>0 else vol.astype(np.float64)
        verts,faces,_,_=measure.marching_cubes(v, level=level)
    except Exception:
        return 0  # level outside data range = no such region (e.g. fully CSS) — expected
    if len(faces)==0: return 0
    # physical coords (center the box)
    P=verts*dx - L/2.0
    if dens_gate is not None:
        vi=np.clip(verts.astype(int),0,Ng-1)
        keepv=gaussian_filter(dens_gate.astype(np.float64),SMOOTH)[vi[:,0],vi[:,1],vi[:,2]]>gate_level
        fmask=keepv[faces].all(axis=1)
        faces=faces[fmask]
        if len(faces)==0: return 0
    mesh=Poly3DCollection(P[faces], alpha=alpha, facecolor=color, edgecolor="none")
    ax.add_collection3d(mesh); return len(faces)

for fi,tf in enumerate(tgrid):
    fig=plt.figure(figsize=(12.5,6.4))
    tphys=tf*1e3
    azim=-60+0.5*fi
    for j,(d,lab) in enumerate(runs):
        it=idx(d,tf)
        ax=fig.add_subplot(1,len(runs),j+1,projection="3d")
        n=d["n"][it]; nmax=n.max()
        mag=np.sqrt(d["fx"][it]**2+d["fy"][it]**2+d["fz"][it]**2)
        s=np.ones_like(n); m=n>0.03*nmax; s[m]=mag[m]/(n[m]*d["F"])  # s=1 outside cloud (no false shell)
        # density envelope (cloud), translucent
        add_iso(ax, n, ISO_N*nmax, "#7FA8C9", 0.13)
        # non-CSS shell: s below S_THR. s=1 outside the cloud already, so the
        # surface only wraps genuine non-CSS (no gate needed; the gate spuriously
        # removed the whole shell at the cloud boundary).
        nf=add_iso(ax, s, S_THR, "#C0392B", 0.55)
        # bulk-mean CSS for annotation
        sw=np.average(s[m],weights=n[m]); smin=s[m].min()
        Lh=L/2*0.8
        ax.set_xlim(-Lh,Lh); ax.set_ylim(-Lh,Lh); ax.set_zlim(-Lh,Lh)
        ax.set_box_aspect((1,1,1)); ax.view_init(elev=16,azim=azim)
        ax.set_xlabel("x"); ax.set_ylabel("y"); ax.set_zlabel("z  (B)")
        ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([])
        ax.set_title(f"{lab}\nB={d['B'][it]:+.0f} µG   bulk s={sw:.3f}   min s={smin:.2f}"
                     + ("" if nf else "   [no non-CSS]"), fontsize=10)
    fig.suptitle(f"EdH vs Flower — 3D shape of the NON-CSS region (red) inside the cloud (grey)\n"
                 f"red = |⟨F⟩|/(nF) < {S_THR}  (left the max-spin manifold)     t = {tphys:6.1f} ms",
                 fontsize=12)
    fig.subplots_adjust(left=0.02,right=0.98,top=0.88,bottom=0.03,wspace=0.05)
    fig.savefig(f"{FRDIR}/f{fi:04d}.png",dpi=100); plt.close(fig)
    if fi%10==0: print("frame",fi,"t_ms=%.1f"%tphys)
print("frames done ->",FRDIR)

# encode if ffmpeg available
import shutil,subprocess
if shutil.which("ffmpeg"):
    # mpeg4/-q:v is portable (TSUBAME's CUDA ffmpeg build has no libx264/-crf).
    cmd=["ffmpeg","-y","-framerate",str(FPS),"-pattern_type","glob","-i",f"{FRDIR}/f*.png",
         "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2","-c:v","mpeg4","-q:v","3","-pix_fmt","yuv420p",OUT]
    print("encoding:"," ".join(cmd)); subprocess.run(cmd,check=False)
    print("wrote",OUT)
else:
    print("ffmpeg not found; frames in",FRDIR)
