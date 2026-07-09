"""Single-panel mp4: EdH parabolic (par_T90) x-tilt Goto difference imaging over time.
D_x = INTdy|[R_x(b) psi]_-6|^2 - Cp INTdy|psi_-6|^2.  FIXED colour scale (global max)
so the checkerboard growth AND sign inversion are faithful. env: PSI13,GOTO,BETA_DEG,FPS,OUT,LABEL"""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
plt.rcParams.update({"font.size":13,"font.family":"DejaVu Sans","axes.linewidth":1.1})
PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
B=float(os.environ.get("BETA_DEG","16")); AHO=0.78; FPS=int(os.environ.get("FPS","10")); OUT=os.environ.get("OUT","par_xtilt.mp4"); LABEL=os.environ.get("LABEL","EdH parabolic (par_T90)")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("x",B)[i6,i6])**2
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
with h5py.File(GOTO,"r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms)); ps=load_frames_bulk(P,list(range(nf)))
D=np.array([m6(ps[k],rot("x",B))-Cp*m6(ps[k],rot("id",0)) for k in range(nf)])
gmax=np.abs(D).max()+1e-30; Ng=D.shape[1]; half=L/2*AHO; ext=[-half,half,-half,half]
def xsym(d): return np.corrcoef(d.ravel(),d[::-1,:].ravel())[0,1]
# Larmor precession period T(t)=h/(g_F mu_B |B|).  g_F mu_B/h = 1.628 MHz/G
GYR=1.628e6                                   # Hz per Gauss
BDD=1.0e-4                                     # MDDI local field estimate ~100 uG (Gauss)
Tms_ext=1e3/(GYR*np.maximum(Bg[:nf],1e-9))     # ms, from external B(t)
Tms_tot=1e3/(GYR*np.sqrt(Bg[:nf]**2+BDD**2))   # ms, ext + MDDI floor
Tfloor=1e3/(GYR*BDD)                           # ~6.1 ms
tmp=tempfile.mkdtemp(); print(f"[anim] {nf} frames, gmax={gmax:.2g}")
for k in range(nf):
    fig,(a, b_)=plt.subplots(1,2,figsize=(10.6,5.0)); fig.subplots_adjust(left=0.07,right=0.99,bottom=0.13,top=0.86,wspace=0.32)
    im=a.imshow(D[k].T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-gmax,vmax=gmax,aspect="equal")
    a.set_xlabel("x (µm)"); a.set_ylabel("z (µm)"); a.xaxis.set_major_locator(MaxNLocator(5)); a.yaxis.set_major_locator(MaxNLocator(5))
    a.set_title(f"x-tilt {B:.0f}° difference (m=-6)\nt={tms[k]:.0f}ms   S={xsym(D[k]):+.2f}",fontsize=12)
    fig.colorbar(im,ax=a,fraction=0.046,pad=0.04).set_label("m=-6 difference (fixed)")
    b_.semilogy(tms[:nf],Tms_ext,color="#3a6ea5",label="T from ext. B(t)")
    b_.semilogy(tms[:nf],Tms_tot,color="#d1495b",label="T from √(B²+B_dd²), B_dd~100µG")
    b_.axhline(Tfloor,color="0.6",ls=":",label=f"MDDI floor ≈{Tfloor:.1f} ms")
    b_.axvline(tms[k],color="k",lw=1.2); b_.plot(tms[k],Tms_tot[k],"o",color="#d1495b",ms=8)
    b_.set_xlabel("t [ms]"); b_.set_ylabel("Larmor precession period T [ms]"); b_.set_ylim(0.03,60); b_.grid(alpha=0.25,which="both")
    b_.legend(fontsize=9,loc="upper left"); b_.set_title(f"spin precession period T(t)=h/(g_F μ_B|B|)\nnow: T≈{Tms_tot[k]:.1f} ms (|B|={np.sqrt(Bg[k]**2+BDD**2)*1e6:.0f}µG)",fontsize=11)
    fig.suptitle(f"{LABEL}",fontsize=13,y=0.965)
    fig.savefig(f"{tmp}/f{k:04d}.png",dpi=135); plt.close(fig)
    if k%20==0: print(f"  {k}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
