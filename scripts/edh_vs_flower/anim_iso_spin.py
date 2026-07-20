"""iso_par_T90 style (density isosurface) + ~4 local spin arrows precessing on top.
Reuses isoviz.marching_tetrahedra / _coords for the SAME isosurface look. The total
density is drawn as a translucent cloud; 4 representative local spins s=F/n (|s|~6)
are 3D arrows at their voxel positions, tracing precession over time (with fading
trail). NEW psi13 in resim/.  env: KEY, NSEL, ISO_FRAC, FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import isoviz
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); NSEL=int(os.environ.get("NSEL","4")); ISO=float(os.environ.get("ISO_FRAC","0.12"))
FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"iso_spin_{KEY}.mp4")
with h5py.File(f"{KEY}_goto.h5","r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
    NX=int(G["meta/NX"][()]); vs=int(np.asarray(G["meta/vol_stride"]).item())
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]
coords=isoviz._coords((ng,ng,ng),L,NX,vs); axl=coords[:,0,0,0]  # ℓ₀ axis
# fields
S=np.zeros((nf,ng,ng,ng,3)); NT=np.zeros((nf,ng,ng,ng))
for k in range(nf):
    p=ps[k]; S[k,...,0]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)); S[k,...,1]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p)); S[k,...,2]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)); NT[k]=(np.abs(p)**2).sum(-1)
# pick NSEL representative voxels (high time-max |f_perp|, spread over z halves)
tmax=np.sqrt(S[...,0]**2+S[...,1]**2).max(0)*(NT.max(0)>0.15*NT.max()); zc=ng//2; sep=4; sel=[]
for zlo,zhi,cnt in [(0,zc,max(1,NSEL//2)),(zc,ng,NSEL-max(1,NSEL//2))]:
    scv=tmax.copy(); scv[:,:,:zlo]=0; scv[:,:,zhi:]=0
    for _ in range(cnt):
        i=np.unravel_index(np.argmax(scv),scv.shape)
        if scv[i]<=0: break
        sel.append(i); ix,iy,iz=i; scv[max(0,ix-sep):ix+sep+1,max(0,iy-sep):iy+sep+1,max(0,iz-sep):iz+sep+1]=0
cols=plt.cm.tab10(np.arange(len(sel)))
pos=[np.array([axl[ix],axl[iy],axl[iz]]) for (ix,iy,iz) in sel]        # ℓ₀
svec=[S[:,ix,iy,iz,:]/np.maximum(NT[:,ix,iy,iz][:,None],1e-9) for (ix,iy,iz) in sel]  # (nf,3), |s|~6
ARR=2.2/6.0                                                            # arrow length: |s|=6 -> 2.2 ℓ₀
gpk=float(max(NT[k].max() for k in range(nf))); iso_abs=ISO*gpk
zeros=np.zeros((ng,ng,ng))
print(f"[iso_spin] {nf} frames, {len(sel)} spins, iso_abs={iso_abs:.3e}")
tmp=tempfile.mkdtemp()
for k in range(nf):
    fig=plt.figure(figsize=(8.2,7.6),facecolor="white"); a=fig.add_subplot(111,projection="3d")
    # translucent total-density cloud (uniform colour)
    if NT[k].max()>=iso_abs:
        tris,_=isoviz.marching_tetrahedra(NT[k],zeros,coords,iso_abs)
        if tris: a.add_collection3d(Poly3DCollection(tris,facecolors="#7aa8d0",edgecolors="none",alpha=0.13))
    # spin arrows + fading trails
    for j,(p0,s) in enumerate(zip(pos,svec)):
        a.scatter(*p0,color=cols[j],s=25)
        a.quiver(p0[0],p0[1],p0[2], s[k,0]*ARR,s[k,1]*ARR,s[k,2]*ARR, color=cols[j],lw=2.6,arrow_length_ratio=0.18)
        if k>1:  # trail of the tip
            tip=p0[None,:]+s[:k+1]*ARR; a.plot(tip[:,0],tip[:,1],tip[:,2],color=cols[j],lw=1.1,alpha=0.8)
    for setter in (a.set_xlim,a.set_ylim,a.set_zlim): setter(-L/2,L/2)
    a.set_box_aspect((1,1,1)); a.view_init(elev=22, azim=232+k*0.4)
    a.set_xlabel("x [ℓ₀]"); a.set_ylabel("y [ℓ₀]"); a.set_zlabel("z [ℓ₀]"); a.tick_params(labelsize=8)
    a.set_title(f"{KEY} EdH: 密度雲（半透明）＋局所スピン{len(sel)}本の3D歳差",fontsize=13)
    fig.text(0.5,0.94,f"t = {tms[k]:6.1f} ms",ha="center",fontsize=18,fontweight="bold",family="monospace",color="#c02020")
    fig.subplots_adjust(top=0.90,bottom=0.06,left=0.04,right=0.98)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
