"""Does LOCAL spin precession happen in parabolic EdH? — WITHOUT assuming the
precession axis is z. If the local effective field (external B_z z-hat + MDDI
self-field) is TILTED, the spin cones about that tilted axis n-hat and ALL of
Fx,Fy,Fz oscillate — so an Fz change is NOT evidence against precession.

Per representative voxel, track the per-atom spin s(t)=F(r,t)/n (|s|~6) over all
saved frames and test the CONE hypothesis about a fitted axis:
  n-hat  = normal of the best-fit plane of the s(t) trajectory (SVD)          [precession axis]
  planarity = 1 - sigma3/sigma2   (→1 if the path is planar, i.e. a real cone)
  s·n-hat  ≈ const?  (cone => constant projection on the axis)
  in-plane angle psi(t): monotone advance => precession; net turn & per-step jump
Voxels: largest time-max |f_perp| in 3D with density and mutual separation.
Uses NEW psi13 in resim/.  env: KEY, NSEL."""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); NSEL=int(os.environ.get("NSEL","4"))
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; ax=(np.arange(ng)-ng//2)*(L/ng)
S=np.zeros((nf,ng,ng,ng,3)); NN=np.zeros((nf,ng,ng,ng))
for k in range(nf):
    p=ps[k]
    S[k,...,0]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p))
    S[k,...,1]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p))
    S[k,...,2]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p)); NN[k]=(np.abs(p)**2).sum(-1)
nmax=NN.max(); fperp3=np.sqrt(S[...,0]**2+S[...,1]**2)               # (nf,x,y,z)
tmax_fp=fperp3.max(0); dens_ok=NN.max(0)>0.15*nmax                    # per-voxel time-max transverse + density gate
score=tmax_fp*dens_ok
# pick NSEL voxels: greedy max-score with a min separation (voxels)
sel=[]; sc=score.copy(); sep=4
for _ in range(NSEL):
    i=np.unravel_index(np.argmax(sc),sc.shape)
    if sc[i]<=0: break
    sel.append(i)
    ix,iy,iz=i
    sc[max(0,ix-sep):ix+sep+1,max(0,iy-sep):iy+sep+1,max(0,iz-sep):iz+sep+1]=0
print(f"[{KEY}] nf={nf} dt~{np.mean(np.diff(tms)):.2f}ms | selected {len(sel)} high-|f_perp| voxels:")
fig=plt.figure(figsize=(4.3*len(sel),10))
for j,(ix,iy,iz) in enumerate(sel):
    s=S[:,ix,iy,iz,:]/np.maximum(NN[:,ix,iy,iz][:,None],1e-9)          # per-atom spin (nf,3), |s|~6
    smag=np.linalg.norm(s,axis=1)
    c=s.mean(0); pdev=s-c                                             # center the path
    U,sig,Vt=np.linalg.svd(pdev,full_matrices=False); nhat=Vt[2]      # plane normal = precession axis
    if nhat[2]<0: nhat=-nhat                                          # orient roughly +z
    planarity=1-sig[2]/(sig[1]+1e-12)                                 # 1=planar path (cone), 0=not
    axis_proj=s@nhat                                                  # s·n-hat  (const if cone)
    tilt=np.rad2deg(np.arccos(np.clip(nhat[2]/np.linalg.norm(nhat),-1,1)))  # axis tilt from z
    # in-plane angle about n-hat
    e1=Vt[0]/np.linalg.norm(Vt[0]); e2=np.cross(nhat,e1)
    u=pdev@e1; v=pdev@e2; psi=np.unwrap(np.arctan2(v,u)); dpsi=np.diff(np.arctan2(v,u)); dpsi=(dpsi+np.pi)%(2*np.pi)-np.pi
    alias=np.mean(np.abs(dpsi)>0.8*np.pi); netdeg=np.rad2deg(psi[-1]-psi[0])
    print(f"  vox(x={ax[ix]:+.1f},y={ax[iy]:+.1f},z={ax[iz]:+.1f})aho |s|~{np.nanmedian(smag):.1f} |f⊥/n|max={ (fperp3[:,ix,iy,iz]/np.maximum(NN[:,ix,iy,iz],1e-9)).max():.2f}"
          f" | 軸傾き={tilt:.0f}° 平面性={planarity:.2f} s·n̂={axis_proj.mean():+.2f}±{axis_proj.std():.2f} 面内正味回転={netdeg:+.0f}° 大跳率={alias:.2f}")
    # row0: hodograph in the precession plane (u,v), time-colored
    a=fig.add_subplot(3,len(sel),j+1)
    pts=np.array([u,v]).T.reshape(-1,1,2); seg=np.concatenate([pts[:-1],pts[1:]],1)
    lc=LineCollection(seg,cmap="viridis",norm=plt.Normalize(tms.min(),tms.max())); lc.set_array(tms[:-1]); lc.set_linewidth(2); a.add_collection(lc)
    a.scatter(u[0],v[0],c="g",s=40,zorder=5); a.scatter(u[-1],v[-1],c="r",s=40,zorder=5)
    m=max(np.abs(np.r_[u,v]).max(),0.1)*1.15; a.set_xlim(-m,m); a.set_ylim(-m,m); a.set_aspect("equal"); a.axhline(0,color="0.85",lw=.6); a.axvline(0,color="0.85",lw=.6)
    a.set_title(f"vox({ax[ix]:+.0f},{ax[iy]:+.0f},{ax[iz]:+.0f})\nフィット歳差面内 (色=時刻)\n軸傾き{tilt:.0f}° 平面性{planarity:.2f}",fontsize=10)
    # row1: Fx,Fy,Fz per-atom vs t + s·n-hat
    a=fig.add_subplot(3,len(sel),len(sel)+j+1)
    a.plot(tms,s[:,0],label="Fx/n"); a.plot(tms,s[:,1],label="Fy/n"); a.plot(tms,s[:,2],label="Fz/n"); a.plot(tms,axis_proj,"k--",lw=2,label="s·n̂ (軸射影)")
    a.set_title("成分(規格化) と 軸射影 s·n̂"); a.set_xlabel("t(ms)"); a.set_ylim(-6.5,6.5); a.legend(fontsize=8,ncol=2); a.grid(alpha=.25)
    # row2: in-plane angle
    a=fig.add_subplot(3,len(sel),2*len(sel)+j+1)
    a.plot(tms,np.rad2deg(psi),color="#3a6ea5"); a.set_title(f"歳差面内角 ψ(t)\n正味{netdeg:+.0f}° 大跳率{alias:.2f}(>0.5=エイリアス)",fontsize=10); a.set_xlabel("t(ms)"); a.set_ylabel("ψ(deg)"); a.grid(alpha=.25)
fig.suptitle(f"{KEY} 局所スピン: 傾いた軸まわりのコーン(歳差)か? 軸n̂をフィットして判定 [dt~{np.mean(np.diff(tms)):.1f}ms]",fontsize=13,y=0.998)
fig.tight_layout(rect=[0,0,1,0.97]); out=f"local_precession_cone_{KEY}.png"; fig.savefig(out,dpi=115); print("wrote",out)
