"""LOCAL spin vector TIP trajectory over time (the essence of precession, per user's
idea): at a few fixed positions r0, the spin vector S=(Fx,Fy,Fz)/atom is a point in
spin space; its tip moves over time = precession. TRUTH (solid) vs our 5-angle
reconstruction from absorption (dashed), on the |F|=6 sphere. env: PSI13,GOTO,BETA_DEG,A_HO_UM,FPS,OUT,LABEL"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; B=float(os.environ.get("BETA_DEG","16")); s16=np.sin(np.radians(B))
AHO=float(os.environ.get("A_HO_UM","0.78")); FPS=int(os.environ.get("FPS","12")); OUT=os.environ["OUT"]; LABEL=os.environ.get("LABEL","EdH")
ms_v=ms[VISIBLE_IDX].astype(float); NR=18; LAM=2e-3; clip6=lambda A:np.clip(A,-6,6)
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
psis=load_frames_bulk(P,list(range(nf))); Ng=psis.shape[1]; ax=np.linspace(-L/2,L/2,Ng)
Xg=ax[:,None]*np.ones((1,Ng)); Yg=np.ones((Ng,1))*ax[None,:]; RHO=np.hypot(Xg,Yg); PHI=np.arctan2(Yg,Xg)
r=np.linspace(0,L/2*1.02,NR); dr=r[1]-r[0]; pos=RHO/dr; j0=np.clip(np.floor(pos).astype(int),0,NR-2); frac=pos-j0
W=np.zeros((Ng,Ng,NR)); I,K=np.meshgrid(np.arange(Ng),np.arange(Ng),indexing="ij"); W[I,K,j0]+=1-frac; W[I,K,j0+1]+=frac
M_scl=W.sum(1); M_vec=(W*(Xg/np.clip(RHO,1e-9,None))[...,None]).sum(1)
solve=lambda M,c:np.linalg.solve(M.T@M+LAM*np.trace(M.T@M)/NR*np.eye(NR),M.T@c)
def interp(p,rho): q=np.clip(rho/dr,0,NR-1-1e-6); jj=np.floor(q).astype(int); f=q-jj; return p[jj]*(1-f)+p[jj+1]*f
def cen(psi,Rm): o=np.abs(np.einsum("mn,xyzn->xyzm",Rm,psi))**2; ov=o[...,VISIBLE_IDX].sum(1); return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
nlast=np.sum(np.abs(psis[-1])**2,-1); zc=int(np.argmax(nlast.sum((0,1))))
gi=lambda um:int(np.argmin(np.abs(ax*AHO-um)))
pts=[("A(+x)",gi(2.5),gi(0.0)),("B(+y)",gi(0.0),gi(2.5)),("C(+x+y)",gi(1.8),gi(1.8))]
cols=["#d1495b","#2ca6a4","#c8a415"]
ST=np.zeros((len(pts),nf,3)); SR=np.zeros((len(pts),nf,3))    # truth / recon spin at r0
for k in range(nf):
    psi=psis[k]; n=np.sum(np.abs(psi)**2,-1); nc=n.sum(1)
    sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    fx3,fy3,fz3=sd(FX),sd(FY),sd(FZ)
    # our 5-angle reconstruction (axisym+l=1) at z=zc from ±16 column
    cfz=cen(psi,rot("id",0)); cfx=-(cen(psi,rot("y",B))-cen(psi,rot("y",-B)))/(2*s16); cfy=+(cen(psi,rot("x",B))-cen(psi,rot("x",-B)))/(2*s16)
    w=nc[:,zc]*np.hypot(cfx[:,zc],cfy[:,zc]); phi0=np.arctan2((cfy[:,zc]*w).sum(),(cfx[:,zc]*w).sum())
    g=(cfx[:,zc]*np.cos(phi0)+cfy[:,zc]*np.sin(phi0))*nc[:,zc]
    nz=np.clip(interp(solve(M_scl,nc[:,zc]),RHO),1e-30,None); a=interp(solve(M_vec,g),RHO)/nz; fzr=interp(solve(M_scl,cfz[:,zc]*nc[:,zc]),RHO)/nz
    rX=clip6(a*np.cos(PHI+phi0)); rY=clip6(a*np.sin(PHI+phi0)); rZ=clip6(fzr)
    for pi,(_,ix,iy) in enumerate(pts):
        nn=max(n[ix,iy,zc],1e-30); ST[pi,k]=[fx3[ix,iy,zc]/nn,fy3[ix,iy,zc]/nn,fz3[ix,iy,zc]/nn]
        SR[pi,k]=[rX[ix,iy],rY[ix,iy],rZ[ix,iy]]
    if k%20==0: print(f"  {k}/{nf}")
# sphere wireframe
u=np.linspace(0,2*np.pi,40); v=np.linspace(0,np.pi,20); sx=6*np.outer(np.cos(u),np.sin(v)); sy=6*np.outer(np.sin(u),np.sin(v)); sz=6*np.outer(np.ones_like(u),np.cos(v))
tmp=tempfile.mkdtemp()
for k in range(nf):
    fig=plt.figure(figsize=(7.2,6.6)); a3=fig.add_subplot(111,projection="3d")
    a3.plot_wireframe(sx,sy,sz,color="0.85",lw=0.4)
    for pi,(lab,_,_) in enumerate(pts):
        a3.plot(ST[pi,:k+1,0],ST[pi,:k+1,1],ST[pi,:k+1,2],color=cols[pi],lw=1.6,label=f"{lab} truth")
        a3.plot(SR[pi,:k+1,0],SR[pi,:k+1,1],SR[pi,:k+1,2],color=cols[pi],lw=1.2,ls="--")
        a3.scatter(*ST[pi,k],color=cols[pi],s=45); a3.scatter(*SR[pi,k],color=cols[pi],s=45,marker="^",edgecolor="k",lw=0.4)
    a3.set_xlim(-6,6);a3.set_ylim(-6,6);a3.set_zlim(-6,6); a3.set_xlabel("Fx");a3.set_ylabel("Fy");a3.set_zlabel("Fz")
    a3.view_init(elev=18,azim=-60); a3.set_title(f"{LABEL} local spin tip on |F|=6 sphere  t={tms[k]:.0f}ms\nsolid=truth  dashed/▲=our recon (from absorption)",fontsize=11)
    a3.legend(fontsize=8,loc="upper left")
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=125); plt.close(fig)
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
