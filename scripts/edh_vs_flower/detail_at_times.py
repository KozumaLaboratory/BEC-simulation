"""Detailed multi-quantity look at T=136,159,176 ms (all in the 26uG hold) for
par_T90 EdH. Columns (imaging plane x-z, LOS=y):
 1 吸収撮像  INTdy n_total
 2 m=-6 カラム INTdy |psi_-6|^2
 3 位相 arg(psi_-6)  (y-mid slice)
 4 質量流 j (x,z; y-mid) arrows on density
 5 スピンテクスチャ INTdy f: colour=INTdy f_y (LOS/out-of-plane), arrows=(INTdy f_x, INTdy f_z)
 6 差分撮像 D 実測  = INTdy|[R_x(16)psi]_-6|^2 - Cp INTdy|psi_-6|^2
 7 D 理論主要項 = -theta INTdy f_y     (BUG CHECK: 6 vs 7 should match)
Rows = the 3 times. NEW psi13 in resim/.  env: KEY."""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
KEY=os.environ.get("KEY","par_T90"); TIMES=[136.0,159.0,176.0]; AHO=0.78
i6=int(np.where(ms==-6)[0][0]); B=16.0; th=np.deg2rad(B); Cp=np.abs(rot("x",B)[i6,i6])**2
with h5py.File(f"{KEY}_goto.h5","r") as G: t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000; P=open_psi13(os.path.join("resim",f"{KEY}_psi13.jld2")); nf=min(psi13_nframes(P),len(tms))
frames=[int(np.argmin(np.abs(tms-T))) for T in TIMES]; ps=load_frames_bulk(P,frames); ng=ps[0].shape[0]; c=ng//2
half=L/2*AHO; ext=[-half,half,-half,half]; ax=(np.arange(ng)-ng//2)*(L/ng)*AHO
k2=2*np.pi*np.fft.fftfreq(ng,d=(L/ng)*AHO)
def col(a): return a.sum(1)   # INT dy  (axis=1 is y) -> (x,z)
def m6c(p,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,p)[...,i6])**2).sum(1)
NC=7
fig,axs=plt.subplots(3,NC,figsize=(3.05*NC,10.2)); fig.subplots_adjust(left=0.03,right=0.98,bottom=0.05,top=0.90,wspace=0.30,hspace=0.28)
titles=["吸収撮像\n∫dy n","m=−6 カラム\n∫dy|ψ₋₆|²","位相 arg ψ₋₆\n(y中央)","質量流 j\n(x-z, y中央)","スピンテクスチャ\n色∫f_y,矢印(∫f_x,∫f_z)","差分撮像 D 実測","D 理論 −θ∫f_y (照合)"]
for r,(fk,T) in enumerate(zip(range(3),TIMES)):
    p=ps[fk]; n3=(np.abs(p)**2).sum(-1)
    fx=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p)); fy=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p)); fz=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p))
    absn=col(n3); n6=col(np.abs(p[...,i6])**2); ph=np.angle(p[:,c,:,i6])   # arg at y-mid
    # mass current x-z at y-mid
    sl=p[:,c,:,:]; jx=np.zeros((ng,ng)); jz=np.zeros((ng,ng)); K1=k2[:,None]; K2=k2[None,:]
    for m in range(13):
        q=sl[...,m]; dx=np.fft.ifft2(1j*K1*np.fft.fft2(q)); dz=np.fft.ifft2(1j*K2*np.fft.fft2(q)); jx+=np.imag(np.conj(q)*dx); jz+=np.imag(np.conj(q)*dz)
    dsl=(np.abs(sl)**2).sum(-1)
    cfx=col(fx); cfy=col(fy); cfz=col(fz)
    D=m6c(p,rot("x",B))-Cp*m6c(p,rot("id",0)); Dth=-th*cfy
    row=[("absn",absn,"magma"),("n6",n6,"magma"),("ph",ph,"twilight"),("j",dsl,"bone"),("stex",cfy,"RdBu_r"),("D",D,"RdBu_r"),("Dth",Dth,"RdBu_r")]
    for ci,(tag,arr,cm) in enumerate(row):
        a=axs[r,ci]
        if tag=="ph": im=a.imshow(arr.T,origin="lower",extent=ext,cmap=cm,vmin=-np.pi,vmax=np.pi,aspect="equal")
        elif tag in ("D","Dth"): g=np.abs(arr).max()+1e-30; im=a.imshow(arr.T,origin="lower",extent=ext,cmap=cm,vmin=-g,vmax=g,aspect="equal")
        elif tag=="stex":
            g=np.abs(arr).max()+1e-30; im=a.imshow(arr.T,origin="lower",extent=ext,cmap=cm,vmin=-g,vmax=g,aspect="equal")
            st=3; XX,ZZ=np.meshgrid(ax[::st],ax[::st],indexing="ij"); a.quiver(XX,ZZ,cfx[::st,::st],cfz[::st,::st],color="k",scale=np.abs(np.hypot(cfx,cfz)).max()*len(ax[::st])*1.2,width=0.006)
        elif tag=="j":
            im=a.imshow(dsl.T,origin="lower",extent=ext,cmap=cm,aspect="equal"); st=3; XX,ZZ=np.meshgrid(ax[::st],ax[::st],indexing="ij")
            a.quiver(XX,ZZ,jx[::st,::st],jz[::st,::st],color="cyan",scale=np.hypot(jx,jz).max()*len(ax[::st])*1.2,width=0.006)
        else: im=a.imshow(arr.T,origin="lower",extent=ext,cmap=cm,aspect="equal")
        if r==0: a.set_title(titles[ci],fontsize=10)
        if ci==0: a.set_ylabel(f"T={T:.0f}ms\nz(μm)",fontsize=10)
        a.set_xticks([]); a.set_yticks([])
    # per-row: correlation D vs D_theory (bug check)
    cc=np.corrcoef(D.ravel(),Dth.ravel())[0,1]
    axs[r,NC-1].set_xlabel(f"D と −θ∫f_y の相関={cc:+.3f}",fontsize=9)
fig.suptitle(f"{KEY} EdH（26µG hold）: T=136/159/176 ms の密度・位相・質量流・スピンテクスチャ・差分/吸収撮像\n（右2列: 実測D と 理論−θ∫f_y の一致＝差分撮像コードのバグ照合）",fontsize=13,y=0.975)
fig.savefig("detail_at_times.png",dpi=120); print("wrote detail_at_times.png")
for r,T in enumerate(TIMES):
    p=ps[r]; cfy=col(np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p)))
    D=m6c(p,rot("x",B))-Cp*m6c(p,rot("id",0)); Dth=-th*cfy
    print(f"T={T:.0f}ms frame{frames[r]}: B={Bg[frames[r]]*1e6:.1f}uG  corr(D,-θ∫f_y)={np.corrcoef(D.ravel(),Dth.ravel())[0,1]:+.4f}  D_range=±{np.abs(D).max():.4f} Dth_range=±{np.abs(Dth).max():.4f}  ratio={np.abs(D).max()/(np.abs(Dth).max()+1e-30):.2f}")
