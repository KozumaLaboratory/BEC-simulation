"""FINAL: EdH parabolic (par_T90) Goto x-tilt difference imaging, +16° and −16°,
plus the Larmor precession period T(t). Japanese labels (japanize_matplotlib).
D_pm = INTdy|[R_x(±b) psi]_-6|^2 - Cp INTdy|psi_-6|^2 (tilted − untilted).
env: PSI13, GOTO, BETA_DEG, FPS, OUT"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":12,"axes.linewidth":1.0})
PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
B=float(os.environ.get("BETA_DEG","16")); AHO=0.78; FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT","par_xtilt_final.mp4")
LABEL=os.environ.get("LABEL","EdH 放物線ランプ (par_T90)")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("x",B)[i6,i6])**2
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
with h5py.File(GOTO,"r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms)); ps=load_frames_bulk(P,list(range(nf)))
Dp=np.array([m6(ps[k],rot("x",B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)])
Dm=np.array([m6(ps[k],rot("x",-B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)])
gmax=max(np.abs(Dp).max(),np.abs(Dm).max())+1e-30; Ng=Dp.shape[1]; half=L/2*AHO; ext=[-half,half,-half,half]
def xsym(d): return np.corrcoef(d.ravel(),d[::-1,:].ravel())[0,1]
GYR=1.628e6; BDD=1.0e-4
Text=1e3/(GYR*np.maximum(Bg[:nf],1e-9)); Ttot=1e3/(GYR*np.sqrt(Bg[:nf]**2+BDD**2)); Tfloor=1e3/(GYR*BDD)
tmp=tempfile.mkdtemp(); print(f"[final] {nf}フレーム, gmax={gmax:.2g}")
for k in range(nf):
    fig,axs=plt.subplots(1,2,figsize=(9.6,5.6),sharey=True); fig.subplots_adjust(left=0.08,right=0.88,bottom=0.11,top=0.74,wspace=0.06)
    for j,(a,D,ti) in enumerate([(axs[0],Dp[k],f"x軸 +{B:.0f}°傾け − 無傾斜"),(axs[1],Dm[k],f"x軸 −{B:.0f}°傾け − 無傾斜")]):
        im=a.imshow(D.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-gmax,vmax=gmax,aspect="equal")
        a.set_title(f"{ti}\n左右対称度 S={xsym(D):+.2f}",fontsize=12,pad=8); a.set_xlabel("x (μm)")
        if j==0: a.set_ylabel("z (μm)")
        a.xaxis.set_major_locator(MaxNLocator(5)); a.yaxis.set_major_locator(MaxNLocator(5))
    fig.colorbar(im,ax=axs[1],fraction=0.046,pad=0.04).set_label("m=−6 差分（固定スケール, 赤=多／青=少）")
    fig.suptitle(f"{LABEL}\n後藤差分撮像（傾け − 無傾斜）   t = {tms[k]:.0f} ms   B = {Bg[k]*1e6:.0f} μG",fontsize=11,y=0.985,va="top")
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=130); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
