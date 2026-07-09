#!/usr/bin/env python3
"""EdH v4 (no loss, K3=0) vs v5 (realistic loss K3=2.1e-41): how does three-body
loss change the dynamics? Trajectories from diag (N_tot, Fz_avg, eps_wmean), and
final-frame spin texture + <Lz> from psi13.
env: OMEGA(=691.15)"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
OM=float(os.environ.get("OMEGA","691.15"))
def load_diag(fn):
    f=h5py.File(fn,"r"); g=lambda k: np.asarray(f[k])
    return dict(t=g("t")/OM*1000, N=g("N_tot"), Fz=g("Fz_avg"), eps=g("eps_wmean"),
                Fperp=np.hypot(g("Fx_avg"),g("Fy_avg")))
d4=load_diag("edh_v4_diag.jld2"); d5=load_diag("edh_v5_diag.jld2")
print("v4 (no loss): N_tot %.3f->%.3f  Fz %.3f->%.3f"%(d4["N"][0],d4["N"][-1],d4["Fz"][0],d4["Fz"][-1]))
print("v5 (loss):    N_tot %.3f->%.3f  Fz %.3f->%.3f"%(d5["N"][0],d5["N"][-1],d5["Fz"][0],d5["Fz"][-1]))
# spin ops + Lz from psi13 (final frame)
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
def final_texture(fn):
    P=h5py.File(fn,"r"); L=float(P["meta/L_box"][()]); fr=np.asarray(P["psi_re_c01"]).shape[-1]-1
    psi=np.stack([np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]+1j*np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr] for c in range(1,14)],axis=-1)
    n=np.sum(np.abs(psi)**2,axis=-1); zc=int(np.argmax(n.sum(axis=(0,1))))
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    nn=np.clip(n[:,:,zc],1e-30,None); m2=n[:,:,zc]>0.04*n[:,:,zc].max()
    Sz=np.where(m2,sd(Fz)[:,:,zc]/nn,np.nan); Sx=np.where(m2,sd(Fx)[:,:,zc]/nn,np.nan); Sy=np.where(m2,sd(Fy)[:,:,zc]/nn,np.nan)
    # Lz
    x=np.linspace(-L/2,L/2,n.shape[0],endpoint=False); dx=x[1]-x[0]; kk=2*np.pi*np.fft.fftfreq(n.shape[0],d=dx); X,Y=np.meshgrid(x,x,indexing="ij")
    lz=0.0; nr=0.0
    for c in range(D):
        a=psi[:,:,zc,c]; day=np.fft.ifft(1j*kk[None,:]*np.fft.fft(a,axis=1),axis=1); dax=np.fft.ifft(1j*kk[:,None]*np.fft.fft(a,axis=0),axis=0)
        lz+=np.real(np.sum(np.conj(a)*(-1j)*(X*day-Y*dax))); nr+=np.real(np.sum(np.abs(a)**2))
    return L,Sx,Sy,Sz,lz/nr,n[:,:,zc]
L4,Sx4,Sy4,Sz4,Lz4,n4=final_texture("edh_v4_psi13.jld2")
L5,Sx5,Sy5,Sz5,Lz5,n5=final_texture("edh_v5_psi13.jld2")
print("final <Lz>: v4=%.3f  v5=%.3f"%(Lz4,Lz5))
# ===== figure =====
fig=plt.figure(figsize=(14,8)); gs=fig.add_gridspec(2,3,height_ratios=[1,1.05],hspace=0.32,wspace=0.28)
ax=fig.add_subplot(gs[0,0]); ax.plot(d4["t"],d4["N"],"C0-",label="v4 (K3=0)"); ax.plot(d5["t"],d5["N"],"C3-",label="v5 (K3=2.1e-41)")
ax.set_xlabel("t [ms]"); ax.set_ylabel("N(t)/N(0)  atom number"); ax.set_title("three-body loss -> atom number decay"); ax.legend(); ax.grid(alpha=.3)
ax=fig.add_subplot(gs[0,1]); ax.plot(d4["t"],d4["Fz"],"C0-",label="v4"); ax.plot(d5["t"],d5["Fz"],"C3-",label="v5")
ax.set_xlabel("t [ms]"); ax.set_ylabel("⟨Fz⟩ (per atom)"); ax.set_title("<Fz>(t): spin tilt"); ax.legend(); ax.grid(alpha=.3)
ax=fig.add_subplot(gs[0,2]); ax.semilogy(d4["t"],np.maximum(d4["eps"],1e-7),"C0-",label="v4"); ax.semilogy(d5["t"],np.maximum(d5["eps"],1e-7),"C3-",label="v5")
ax.set_xlabel("t [ms]"); ax.set_ylabel("eps_wmean (Mermin-Ho)"); ax.set_title("adiabaticity residual"); ax.legend(); ax.grid(alpha=.3)
ext4=[-L4/2,L4/2,-L4/2,L4/2]; Ng=Sz4.shape[0]; ax1d=np.linspace(-L4/2,L4/2,Ng); xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij"); st=max(1,Ng//15)
def tex(a,Sx,Sy,Sz,title):
    im=a.imshow(Sz.T,origin="lower",extent=ext4,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    mg=np.hypot(Sx,Sy);U=np.where(mg>1e-6,Sx/mg,np.nan);V=np.where(mg>1e-6,Sy/mg,np.nan)
    a.quiver(xx[::st,::st],yy[::st,::st],U[::st,::st],V[::st,::st],mg[::st,::st],cmap="Greys",clim=(0,6),scale=22,width=0.008,pivot="mid")
    a.set_title(title,fontsize=10);a.set_xticks([]);a.set_yticks([]); return im
tex(fig.add_subplot(gs[1,0]),Sx4,Sy4,Sz4,f"v4 (K3=0) final texture\n⟨Lz⟩={Lz4:+.2f}")
tex(fig.add_subplot(gs[1,1]),Sx5,Sy5,Sz5,f"v5 (loss) final texture\n⟨Lz⟩={Lz5:+.2f}")
axt=fig.add_subplot(gs[1,2]); axt.axis("off")
axt.text(0.0,0.95,
  "EdH realistic loss K3=2.1e-41 effect\n\n"
  f"atoms N: v4 {d4['N'][-1]:.3f} → v5 {d5['N'][-1]:.3f}\n"
  f"<Fz> final: v4 {d4['Fz'][-1]:+.2f} / v5 {d5['Fz'][-1]:+.2f}\n"
  f"<Lz> final: v4 {Lz4:+.2f} / v5 {Lz5:+.2f}\n"
  f"eps final: v4 {d4['eps'][-1]:.3f} / v5 {d5['eps'][-1]:.3f}\n\n"
  "loss removes the dense core first ->\n"
  "cloud compactifies; how texture and\n"
  "spin->orbital transfer change.",
  transform=axt.transAxes,va="top",fontsize=10,family="monospace")
fig.suptitle("EdH: v4 (no loss K3=0) vs v5 (realistic loss K3=2.1e-41)",fontsize=13)
fig.savefig("v4_vs_v5_loss.png",dpi=125,bbox_inches="tight"); print("wrote v4_vs_v5_loss.png")
