"""Mass current (probability-density flux) j = sum_m Im(psi_m* grad psi_m) in the
x-y midplane (z=center) — the plane where EdH orbital circulation (L_z) lives.
Background = column? no, midplane density. Arrows = (j_x,j_y), global scale
(length ∝ |j|, tiny -> short). Prominent time readout so the period is eyeball-able.
NEW psi13 in resim/.  env: KEY, FPS, OUT, PLANE(xy|xz)."""
import os, sys, numpy as np, h5py, subprocess, tempfile
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); FPS=int(os.environ.get("FPS","10")); PLANE=os.environ.get("PLANE","xy")
OUT=os.environ.get("OUT",f"masscurrent_{PLANE}_{KEY}.mp4"); AHO=0.78
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms)); tms=tms[:nf]
ps=load_frames_bulk(P,list(range(nf))); ng=ps[0].shape[0]; c=ng//2
axu=(np.arange(ng)-ng//2)*(L/ng)*AHO   # um
k=2*np.pi*np.fft.fftfreq(ng,d=(L/ng)*AHO)  # 1/um
def current_plane(psi):
    # in-plane current in chosen midplane; density too
    if PLANE=="xy":
        sl=psi[:,:,c,:]; K1=k[:,None]; K2=k[None,:]                 # (x,y)
    else:
        sl=psi[:,c,:,:]; K1=k[:,None]; K2=k[None,:]                 # (x,z)
    n=(np.abs(sl)**2).sum(-1); j1=np.zeros((ng,ng)); j2=np.zeros((ng,ng))
    for m in range(sl.shape[-1]):
        q=sl[...,m]
        d1=np.fft.ifft2(1j*K1*np.fft.fft2(q)); d2=np.fft.ifft2(1j*K2*np.fft.fft2(q))
        j1+=np.imag(np.conj(q)*d1); j2+=np.imag(np.conj(q)*d2)
    return n,j1,j2
# precompute for global scales
Ns=[]; J1=[]; J2=[]
for f in ps: n,a,b=current_plane(f); Ns.append(n); J1.append(a); J2.append(b)
Ns=np.array(Ns); J1=np.array(J1); J2=np.array(J2)
jmax=np.percentile(np.sqrt(J1**2+J2**2),99.5)+1e-30; nmax=Ns.max()
st=2; idx=np.arange(0,ng,st); Xa,Ya=np.meshgrid(axu[idx],axu[idx],indexing="ij")
half=axu.max(); lab1,lab2=("x","y") if PLANE=="xy" else ("x","z")
tmp=tempfile.mkdtemp(); print(f"[jflow] {nf} frames plane={PLANE} jmax={jmax:.2g}")
for kk in range(nf):
    fig,a=plt.subplots(figsize=(7.2,6.8))
    a.imshow(Ns[kk].T,origin="lower",extent=[-half,half,-half,half],cmap="magma",vmin=0,vmax=nmax,aspect="equal")
    u=J1[kk][::st,::st]; v=J2[kk][::st,::st]
    a.quiver(Xa,Ya,u,v,color="cyan",scale=jmax*len(idx)*1.1,width=0.004,alpha=0.9)
    a.set_xlabel(f"{lab1} (μm)"); a.set_ylabel(f"{lab2} (μm)")
    a.set_title(f"{KEY} 確率密度流 j（{lab1}-{lab2}面, 中央)\n背景=密度, 矢印=流れ(長さ∝|j|)",fontsize=12)
    fig.text(0.5,0.945,f"t = {tms[kk]:6.1f} ms",ha="center",fontsize=19,fontweight="bold",family="monospace",color="cyan",
             bbox=dict(fc="black",alpha=0.5,pad=2))
    fig.subplots_adjust(top=0.87,bottom=0.10,left=0.12,right=0.97)
    fig.savefig(f"{tmp}/f{kk:04d}.png",dpi=115); plt.close(fig)
    if kk%20==0: print(f"  {kk}/{nf}")
subprocess.run(["ffmpeg","-y","-framerate",str(FPS),"-i",f"{tmp}/f%04d.png","-pix_fmt","yuv420p","-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2",OUT],check=True,capture_output=True)
print("wrote",OUT)
