"""ONE spin on the y=mid cross-section: its precession, drawn cleanly.
Left: |F|=6 sphere with the single spin vector s=F/n as a 3D arrow + fading trail
      + fitted precession axis (dashed). Right: s_x,s_y,s_z(t) with a moving marker.
Voxel = highest time-max |f_perp| ON the y=mid slice. NEW psi13.  env: KEY, FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT",f"single_spin_{KEY}.mp4")
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2; axl=(np.arange(ng)-ng//2)*(L/ng)
S=np.zeros((nf,ng,ng,ng,3)); NT=np.zeros((nf,ng,ng,ng))
for k in range(nf):
    p=ps[k]; S[k,...,0]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p));S[k,...,1]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p));S[k,...,2]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)); NT[k]=(np.abs(p)**2).sum(-1)
# best voxel ON the y=mid slice
tmax=np.sqrt(S[:,:,c,:,0]**2+S[:,:,c,:,1]**2).max(0)*(NT[:,:,c,:].max(0)>0.15*NT.max())
ix,iz=np.unravel_index(np.argmax(tmax),tmax.shape)
s=S[:,ix,c,iz,:]/np.maximum(NT[:,ix,c,iz][:,None],1e-9)     # (nf,3) per-atom spin
pdev=s-s.mean(0); _,_,Vt=np.linalg.svd(pdev,full_matrices=False); nhat=Vt[2]; nhat*= (1 if nhat[2]>=0 else -1)
tilt=np.rad2deg(np.arccos(np.clip(nhat[2],-1,1)))
print(f"[single] voxel (x={axl[ix]:+.1f},y=0,z={axl[iz]:+.1f}) aho | 軸傾き={tilt:.0f}° | |s|~{np.median(np.linalg.norm(s,axis=1)):.1f}")
u,v=np.mgrid[0:2*np.pi:24j,0:np.pi:16j]; R=6.0; sx=R*np.cos(u)*np.sin(v); sy=R*np.sin(u)*np.sin(v); sz=R*np.cos(v)
tmp=tempfile.mkdtemp()
for k in range(nf):
    fig=plt.figure(figsize=(12,5.8))
    a=fig.add_subplot(1,2,1,projection="3d")
    a.plot_wireframe(sx,sy,sz,color="0.85",lw=0.4); a.quiver(0,0,0,0,0,-6.5,color="0.6",lw=1,arrow_length_ratio=0.06); a.text(0,0,-7.3,"−z",color="0.4")
    a.plot([-6*nhat[0],6*nhat[0]],[-6*nhat[1],6*nhat[1]],[-6*nhat[2],6*nhat[2]],ls="--",color="green",lw=1.2,alpha=0.6)
    if k>1: a.plot(s[:k+1,0],s[:k+1,1],s[:k+1,2],color="#c02020",lw=1.8,alpha=0.9)
    a.quiver(0,0,0,s[k,0],s[k,1],s[k,2],color="#c02020",lw=3,arrow_length_ratio=0.12)
    a.set_xlim(-6,6);a.set_ylim(-6,6);a.set_zlim(-6,6);a.set_box_aspect((1,1,1)); a.view_init(elev=18,azim=-60+k*0.5)
    a.set_xlabel("Fx");a.set_ylabel("Fy");a.set_zlabel("Fz")
    a.set_title(f"単一スピンの歳差（球面 |F|=6）\n位置(x={axl[ix]:+.0f},z={axl[iz]:+.0f})ℓ₀, 軸傾き{tilt:.0f}°(緑点線)",fontsize=11)
    b=fig.add_subplot(1,2,2)
    b.plot(tms,s[:,0],label="Fx/n"); b.plot(tms,s[:,1],label="Fy/n"); b.plot(tms,s[:,2],label="Fz/n")
    b.axvline(tms[k],color="k",lw=1.4); b.axvline(130,color="0.6",ls=":",lw=1); b.text(131,5.6,"hold",fontsize=8,color="0.5")
    b.set_xlabel("時刻 t (ms)"); b.set_ylabel("スピン成分 (per-atom)"); b.set_ylim(-6.5,6.5); b.grid(alpha=.25); b.legend(fontsize=10,loc="lower left")
    b.set_title(f"成分の時間発展   t={tms[k]:.0f} ms  B={Bg[k]*1e6:.0f}µG",fontsize=11)
    fig.tight_layout(); fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
