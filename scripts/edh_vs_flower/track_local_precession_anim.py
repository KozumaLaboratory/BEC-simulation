"""3D animation: representative local spins s(r_i,t)=F/n (|s|~6) tracing cones on
the |F|=6 sphere in the parabolic EdH run. Shows the tilted precession axis n-hat
(fit per voxel) and the moving arrow + fading trail. Confirms visually that each
local spin precesses about a TILTED axis (so lab Fz oscillates). NEW psi13.
env: KEY, NSEL, FPS, OUT."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); NSEL=int(os.environ.get("NSEL","8")); FPS=int(os.environ.get("FPS","10"))
OUT=os.environ.get("OUT",f"local_precession_3d_{KEY}.mp4")
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; axc=(np.arange(ng)-ng//2)*(L/ng)
S=np.zeros((nf,ng,ng,ng,3)); NN=np.zeros((nf,ng,ng,ng))
for k in range(nf):
    p=ps[k]
    S[k,...,0]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)); S[k,...,1]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p))
    S[k,...,2]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)); NN[k]=(np.abs(p)**2).sum(-1)
tmax_fp=np.sqrt(S[...,0]**2+S[...,1]**2).max(0); score=tmax_fp*(NN.max(0)>0.15*NN.max())
zc=ng//2; sep=3; sel=[]
# span z: pick NSEL/2 voxels from the LOWER half (z<zc) and NSEL/2 from the UPPER half (z>zc),
# each the highest time-max |f_perp| with a minimum spatial separation.
for zlo,zhi,cnt in [(0,zc,NSEL//2),(zc,ng,NSEL-NSEL//2)]:
    sc=score.copy(); sc[:,:,:zlo]=0; sc[:,:,zhi:]=0
    for _ in range(cnt):
        i=np.unravel_index(np.argmax(sc),sc.shape)
        if sc[i]<=0: break
        sel.append(i); ix,iy,iz=i; sc[max(0,ix-sep):ix+sep+1,max(0,iy-sep):iy+sep+1,max(0,iz-sep):iz+sep+1]=0
traj=[]; axes=[]
for (ix,iy,iz) in sel:
    s=S[:,ix,iy,iz,:]/np.maximum(NN[:,ix,iy,iz][:,None],1e-9); traj.append(s)
    pdev=s-s.mean(0); _,_,Vt=np.linalg.svd(pdev,full_matrices=False); n=Vt[2]; n=n*np.sign(n[2] if n[2]!=0 else 1); axes.append(n)
cols=plt.cm.tab10(np.arange(len(sel)))
print(f"[sel] {len(sel)} voxels (aho units), lower-half then upper-half:")
for (ix,iy,iz) in sel: print(f"   (x={axc[ix]:+.1f}, y={axc[iy]:+.1f}, z={axc[iz]:+.1f})  {'下側' if iz<ng//2 else '上側'}")
# sphere mesh
u,v=np.mgrid[0:2*np.pi:24j,0:np.pi:16j]; R=6.0; sx=R*np.cos(u)*np.sin(v); sy=R*np.sin(u)*np.sin(v); sz=R*np.cos(v)
tmp=tempfile.mkdtemp(); print(f"[anim] {nf} frames, {len(sel)} voxels")
for k in range(nf):
    fig=plt.figure(figsize=(7,6.6)); a=fig.add_subplot(111,projection="3d")
    a.plot_wireframe(sx,sy,sz,color="0.85",lw=0.4,rstride=1,cstride=1)
    for ax_,lab,col in [((1,0,0),"","0.6"),((0,1,0),"","0.6")]: pass
    a.quiver(0,0,0,0,0,-6.6,color="0.5",lw=1,arrow_length_ratio=0.06); a.text(0,0,-7.4,"−z (B軸)",color="0.4",fontsize=9)
    for j,(s,n) in enumerate(zip(traj,axes)):
        # tilted precession axis (dashed, through origin)
        a.plot([-6*n[0],6*n[0]],[-6*n[1],6*n[1]],[-6*n[2],6*n[2]],ls="--",color=cols[j],lw=1,alpha=0.5)
        # fading trail up to k
        if k>0: a.plot(s[:k+1,0],s[:k+1,1],s[:k+1,2],color=cols[j],lw=1.6,alpha=0.85)
        # current arrow
        a.quiver(0,0,0,s[k,0],s[k,1],s[k,2],color=cols[j],lw=2.4,arrow_length_ratio=0.12)
    tilt=np.rad2deg(np.arccos(np.clip(np.mean([n[2] for n in axes]),-1,1)))
    a.set_xlim(-6,6); a.set_ylim(-6,6); a.set_zlim(-6,6); a.set_box_aspect((1,1,1))
    a.set_xlabel("Fx"); a.set_ylabel("Fy"); a.set_zlabel("Fz"); a.view_init(elev=18, azim=-60+k*0.4)
    a.set_title(f"{KEY} 局所スピン歳差（傾いた軸まわりのコーン, 上下8点）  軸傾き≈{tilt:.0f}°",fontsize=11)
    # prominent time readout (top-right corner, clear of the title)
    fig.text(0.97,0.955,f"t = {tms[k]:6.1f} ms",ha="right",va="top",fontsize=19,fontweight="bold",family="monospace",color="#c02020")
    # time progress bar (0 -> end), mark ramp-end 90ms
    b=fig.add_axes([0.12,0.045,0.76,0.03]); b.set_xlim(tms[0],tms[-1]); b.set_ylim(0,1); b.set_yticks([])
    b.axvspan(tms[0],tms[k],color="#c02020",alpha=0.35); b.axvline(tms[k],color="#c02020",lw=2)
    if tms[-1]>90: b.axvline(90,color="0.4",ls="--",lw=1); b.text(90,1.15,"ランプ終了",fontsize=8,ha="center",color="0.4")
    b.set_xlabel("時刻 t (ms)",fontsize=9)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=115); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
