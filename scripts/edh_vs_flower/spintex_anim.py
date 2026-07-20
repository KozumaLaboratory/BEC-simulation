#!/usr/bin/env python3
"""Spin-texture dynamics animation from goto.h5 (Fx/Fy/Fz/n 3D, all frames).
MODE=2d : (x,y) slice at z=peak, arrows=(<Fx>,<Fy>)/atom (physical length),
          colour=<Fz>/atom (RdBu_r, +-6). Shows the vortex winding over time.
MODE=3d : 3D quiver of <F>(r)/atom (subsampled, in-cloud), colour=HSV direction,
          on a translucent density envelope.
env: GOTO, OUT(.mp4), MODE, FPE_FPS, FPE_DURATION_S, ARROW_STEP
"""
import os,sys,numpy as np,h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,HERE); sys.path.insert(0,HERE+"/../flower_protocol_edh")
from isoviz import setup_font
import matplotlib;matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors as mcolors
from _anim_writer import save_via_png_dup
setup_font("ja")
def hsv_rgba(sx,sy,sz,dens,F=6.0):
    mag=np.sqrt(sx*sx+sy*sy+sz*sz)+1e-30;cos=np.clip(sz/mag,-1,1)
    hue=(np.arctan2(sy,sx)+np.pi)/(2*np.pi);sat=np.clip(np.sqrt(np.maximum(0,1-cos*cos)),0,1)
    val=np.clip(1-0.4*cos,0.4,1);rgb=mcolors.hsv_to_rgb(np.stack([hue,sat,val],-1))
    al=np.clip((dens/(dens.max()+1e-30))**0.5,0.15,1)
    return np.concatenate([rgb,al[...,None]],-1)
GOTO=os.environ.get("GOTO","goto.h5");OUT=os.environ.get("OUT","spintex.mp4");MODE=os.environ.get("MODE","2d")
FPS=int(os.environ.get("FPE_FPS","30"));DUR=float(os.environ.get("FPE_DURATION_S","16"));AST=int(os.environ.get("ARROW_STEP","0"))
f=h5py.File(GOTO,"r");T=lambda k:np.transpose(np.asarray(f[k]),(3,2,1,0))
n=T("n_total_3d");fx=T("Fx_3d");fy=T("Fy_3d");fz=T("Fz_3d")
t=np.asarray(f["t"]);om=float(f["meta/omega_ref"][()]);tms=t/om*1000
B=np.asarray(f["B_gauss"]) if "B_gauss" in f else np.zeros_like(t)
meta={k:np.asarray(f["meta"][k]).item() for k in f["meta"]}
L=float(meta["L_box"]);Ng=n.shape[1];ax=np.linspace(-L/2,L/2,Ng,endpoint=False);ext=[-L/2,L/2,-L/2,L/2]
nf=n.shape[0];XX,YY=np.meshgrid(ax,ax,indexing="ij")
zc=int(np.argmax(n[nf-1].sum(axis=(0,1))))
per=lambda a,d:np.divide(a,d,out=np.zeros_like(a),where=d>0.05*d.max())

if MODE=="2d":
    st=AST or max(1,Ng//16); fig=plt.figure(figsize=(6.4,5.6),facecolor="white")
    def draw(k):
        fig.clf();a=fig.add_subplot(111)
        N=n[k][:,:,zc]; sx=per(fx[k][:,:,zc],N);sy=per(fy[k][:,:,zc],N);sz=per(fz[k][:,:,zc],N)
        im=a.imshow(sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
        sub=(slice(None,None,st),)*2;msk=N[sub]>0.05*N.max()
        u=np.where(msk,sx[sub],0);v=np.where(msk,sy[sub],0)
        a.quiver(XX[sub],YY[sub],u,v,color="k",angles="xy",scale_units="xy",scale=6.0/(2*st*(L/Ng)),width=0.006,pivot="mid")
        a.set_title(f"スピンテクスチャ (z=0 断面)  t={tms[k]:.0f} ms  B={B[k]*1e6:.1f} µG\n矢印=(<Fx>,<Fy>)/atom  色=<Fz>/atom",fontsize=10)
        a.set_xlabel("x [ℓ₀]");a.set_ylabel("y [ℓ₀]")
        if k==0: fig.colorbar(im,ax=a,shrink=.85,label="<Fz>/atom")
    save_via_png_dup(fig,draw,nf,OUT,fps=FPS,duration_s=DUR,dpi=120)
else:
    from mpl_toolkits.mplot3d import Axes3D
    st=AST or max(1,Ng//14)
    xs=ax[::st];G0,G1,G2=np.meshgrid(xs,xs,xs,indexing="ij")
    fig=plt.figure(figsize=(7,6.4),facecolor="white")
    def draw(k):
        fig.clf();a=fig.add_subplot(111,projection="3d")
        N=n[k][::st,::st,::st];sx=per(fx[k][::st,::st,::st],N);sy=per(fy[k][::st,::st,::st],N);sz=per(fz[k][::st,::st,::st],N)
        msk=N>0.08*n[k].max()
        # colour = s_z sign only (red=+z up, blue=-z down); alpha by density
        cz=np.clip(sz/6.0,-1,1); rgb=plt.cm.RdBu_r((cz+1)/2)[...,:3]
        al=np.clip((N/(N.max()+1e-30))**0.5,0.2,1); rgba=np.concatenate([rgb,al[...,None]],-1)
        Ln=6.0;sc=(0.9*st*(L/Ng))/Ln
        a.quiver(G0[msk],G1[msk],G2[msk],sx[msk]*sc,sy[msk]*sc,sz[msk]*sc,
                 colors=rgba[msk],length=1.0,normalize=False,linewidth=1.5)
        for s in (a.set_xlim,a.set_ylim,a.set_zlim):s(-L/2,L/2)
        a.set_box_aspect((1,1,1));a.view_init(elev=20,azim=-60)
        a.set_xlabel("x [ℓ₀]");a.set_ylabel("y [ℓ₀]");a.set_zlabel("z [ℓ₀]")
        a.set_title(f"{os.environ.get('LABEL','3D スピンテクスチャ')} <F>(r)  t={tms[k]:.0f} ms  B={B[k]*1e6:.1f} µG\n色=s_z（赤=上向き +z / 青=下向き −z）",fontsize=10)
    save_via_png_dup(fig,draw,nf,OUT,fps=FPS,duration_s=DUR,dpi=115)
print(f"[spintex] wrote {OUT} (MODE={MODE}, {nf} frames)")
