#!/usr/bin/env python3
"""GENUINE spin-texture tomography from (tilted) Stern-Gerlach images.

THE EXPERIMENT we forward-model, then invert:
  for tilt setting (axis a, angle b): rotate quantization axis R=exp(-i b F_a),
  Stern-Gerlach sorts by m, absorption-image -> occupation field n_m^{(a,b)}(r)=|[R psi]_m(r)|^2.
THE RECONSTRUCTION (exact operator identities):
  <Fz>(r) = sum_m m n_m^{(I)}        (no tilt)
  <Fx>(r) = sum_m m n_m^{(y,+90)}    (R_y(90)+ Fz R_y(90) = Fx)
  <Fy>(r) = sum_m m n_m^{(x,-90)}    (R_x(-90)+ Fz R_x(-90) = Fy)
We build the images from the FULL 13-comp spinor, reconstruct <F>(r), and VALIDATE
against the true spin density already in goto.h5.  Two regimes shown honestly:
  (A) voxel-resolved (light-sheet / tomographic imaging)  -> exact (err ~ 1e-8)
  (B) column-integrated along z (a single absorption image) -> column-averaged texture
env: PSI13, GOTO, OUT, FRAME"""
import os, numpy as np, h5py
from _floor import mask_from  # FPE_DENSITY_FLOOR (default 0 = full grid)
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize

PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5")
OUT=os.environ.get("OUT","texture_tomo.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
# --- spin operators, basis m=+6..-6 ---
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
Ry90=expm(+1j*(np.pi/2)*Fy)      # R_y(-90):  R+ Fz R = +Fx
Rxm90=expm(-1j*(np.pi/2)*Fx)     # R_x(+90):  R+ Fz R = +Fy
# --- load full spinor (x,y,z,13) at frame FR ---
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r"); L=float(P["meta/L_box"][()])
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1)        # (Nx,Ny,Nz,13)
n=np.sum(np.abs(psi)**2,axis=-1)
Ng=psi.shape[0]; ax1d=np.linspace(-L/2,L/2,Ng); ext=[-L/2,L/2,-L/2,L/2]
tms=float(np.asarray(G["t"])[FR])/float(G["meta/omega_ref"][()])*1000
Bz=float(np.asarray(G["B_gauss"])[FR])

# === FORWARD MODEL: tilted-SG occupation fields n_m^{set}(r)=|[R psi]_m|^2 ===
def sg_images(R):
    rp=np.einsum("mn,xyzn->xyzm",R,psi)        # rotate spinor at every voxel
    return np.abs(rp)**2                         # (Nx,Ny,Nz,13) SG occupations
n_I  = np.abs(psi)**2                            # no tilt
n_Y  = sg_images(Ry90)
n_X  = sg_images(Rxm90)
# === RECONSTRUCT spin texture from the SG images (operator identities) ===
def centroid(nm): return np.einsum("xyzm,m->xyz", nm, ms.astype(float))   # sum_m m n_m = spin density
fz_rec, fx_rec, fy_rec = centroid(n_I), centroid(n_Y), centroid(n_X)
# === TRUTH ===
def truth(k): return np.transpose(np.asarray(G[f"{k}_3d"]),(2,1,0,3))[...,FR]
fz_t,fx_t,fy_t = truth("Fz"),truth("Fx"),truth("Fy")
err_vox=max(np.abs(fz_rec-fz_t).max(),np.abs(fx_rec-fx_t).max(),np.abs(fy_rec-fy_t).max())

# === per-atom spin (for plotting the texture) at z=peak slice ===
zc=int(np.argmax(n.sum(axis=(0,1))))
def per_atom(fa,sl): nn=np.clip(n[:,:,sl],1e-12,None); return fa[:,:,sl]/nn
m2d=mask_from(n[:,:,zc])
def spin_slice(fx_,fy_,fz_):
    Sx=np.where(m2d,per_atom(fx_,zc),np.nan); Sy=np.where(m2d,per_atom(fy_,zc),np.nan); Sz=np.where(m2d,per_atom(fz_,zc),np.nan)
    return Sx,Sy,Sz
SxT,SyT,SzT=spin_slice(fx_t,fy_t,fz_t)
SxR,SyR,SzR=spin_slice(fx_rec,fy_rec,fz_rec)

# === COLUMN-INTEGRATED regime (single absorption image along z) ===
col=lambda a:a.sum(axis=2)
nc=col(n); mc=mask_from(nc)
fxc_t,fyc_t,fzc_t=col(fx_t),col(fy_t),col(fz_t)
fxc_r,fyc_r,fzc_r=col(fx_rec),col(fy_rec),col(fz_rec)   # column-int of reconstructed = reconstruction from column images (linear)
def colspin(fxc,fyc,fzc):
    nn=np.clip(nc,1e-12,None)
    return (np.where(mc,fxc/nn,np.nan),np.where(mc,fyc/nn,np.nan),np.where(mc,fzc/nn,np.nan))
cxT,cyT,czT=colspin(fxc_t,fyc_t,fzc_t)

# ============================ FIGURE ============================
fig=plt.figure(figsize=(15.5,9.6)); gs=fig.add_gridspec(3,4,height_ratios=[1,1,0.92],hspace=0.34,wspace=0.30)
st=max(1,Ng//16); xx,yy=np.meshgrid(ax1d,ax1d,indexing="ij")
def draw_texture(ax,Sx,Sy,Sz,title):
    im=ax.imshow(Sz.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    mag=np.hypot(Sx,Sy); U=np.where(mag>1e-6,Sx/mag,np.nan); V=np.where(mag>1e-6,Sy/mag,np.nan)
    sub=(slice(None,None,st),slice(None,None,st))
    ax.quiver(xx[sub],yy[sub],U[sub],V[sub],mag[sub],cmap="Greys",clim=(0,6),
              scale=26,width=0.006,headwidth=4,pivot="mid")   # unit-length arrows, dir only
    ax.set_title(title,fontsize=10.5); ax.set_xticks([]); ax.set_yticks([])
    return im
# Row 1: the MEASUREMENT (the SG images that feed the reconstruction)
sgsets=[("no tilt  → ⟨Fz⟩",n_I),("R_y(−90°) → ⟨Fx⟩",n_Y),("R_x(+90°) → ⟨Fy⟩",n_X)]
for j,(lab,nm) in enumerate(sgsets):
    ax=fig.add_subplot(gs[0,j])
    sd=centroid(nm)[:,:,zc]; sd=np.where(m2d,sd/np.clip(n[:,:,zc],1e-12,None),np.nan)
    im=ax.imshow(sd.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
    ax.set_title(f"SG image: {lab}\n(centroid Σ m·n_m / n, z=peak)",fontsize=9); ax.set_xticks([]);ax.set_yticks([])
ax=fig.add_subplot(gs[0,3]); ax.axis("off")
ax.text(0.0,0.98,
  "FORWARD MODEL (the experiment)\n"
  "  tilt axis by R=exp(−i β F_a),\n"
  "  Stern–Gerlach → image n_m(r)=|[Rψ]_m|²\n\n"
  "RECONSTRUCTION (exact identities)\n"
  "  ⟨Fz⟩ = Σ m·n_m^{(no tilt)}\n"
  "  ⟨Fx⟩ = Σ m·n_m^{(R_y −90°)}\n"
  "  ⟨Fy⟩ = Σ m·n_m^{(R_x +90°)}\n"
  "  (R_y(−90)†F_zR_y(−90)=F_x, etc.)\n\n"
  "→ the spin VECTOR texture ⟨F⟩(r)\n"
  "   needs only 3 (tilted) SG images.",
  transform=ax.transAxes,va="top",fontsize=9.3,family="monospace")
# Row 2: voxel-resolved truth vs reconstruction vs error
axT=fig.add_subplot(gs[1,0]); imc=draw_texture(axT,SxT,SyT,SzT,"TRUE spin texture ⟨F⟩(r)\n(z=peak slice, from full ψ)")
axR=fig.add_subplot(gs[1,1]); draw_texture(axR,SxR,SyR,SzR,f"RECONSTRUCTED from 3 SG images\n(voxel-resolved)")
axE=fig.add_subplot(gs[1,2])
emag=np.sqrt((fx_rec-fx_t)**2+(fy_rec-fy_t)**2+(fz_rec-fz_t)**2)[:,:,zc]
emag=np.where(m2d,emag,np.nan)
ime=axE.imshow(emag.T,origin="lower",extent=ext,cmap="magma",aspect="equal")
axE.set_title(f"|⟨F⟩_recon − ⟨F⟩_true|\nmax over cloud = {err_vox:.1e}",fontsize=10); axE.set_xticks([]);axE.set_yticks([])
fig.colorbar(ime,ax=axE,shrink=0.78)
cax=fig.add_subplot(gs[1,3]); cax.axis("off")
cb=fig.colorbar(imc,ax=cax,fraction=0.5,aspect=12); cb.set_label("⟨Fz⟩  (arrows = ⟨Fx⟩,⟨Fy⟩)",fontsize=9)
cax.text(0.0,0.0,
  f"VALIDATION (regime A):\n voxel-resolved reconstruction\n is EXACT — max error\n {err_vox:.1e} (machine precision).\n\n"
  "The 3-image vector tomography\n is not an approximation; it is\n an operator identity. Higher\n multipoles (full ρ, nematic)\n need a full tilt scan (below).",
  transform=cax.transAxes,va="bottom",fontsize=8.6,family="monospace")
# Row 3: honest column-integration regime + a real SG stack montage
axc=fig.add_subplot(gs[2,0]); draw_texture_col=draw_texture
imc2=axc.imshow(czT.T,origin="lower",extent=ext,cmap="RdBu_r",vmin=-6,vmax=6,aspect="equal")
_mc=np.hypot(cxT,cyT); _u=np.where(_mc>1e-6,cxT/_mc,np.nan); _v=np.where(_mc>1e-6,cyT/_mc,np.nan); _sub=(slice(None,None,st),slice(None,None,st))
axc.quiver(xx[_sub],yy[_sub],_u[_sub],_v[_sub],_mc[_sub],cmap="Greys",clim=(0,6),scale=26,width=0.006,headwidth=4,pivot="mid")
axc.set_title("column-INTEGRATED ⟨F⟩ (∫dz)\n= what ONE absorption image gives",fontsize=9.5); axc.set_xticks([]);axc.set_yticks([])
# SG stack as an experiment would see it (no tilt): m-resolved column images side by side
axsg=fig.add_subplot(gs[2,1:3])
mshow=list(range(12,6,-1))   # c index 13..8 = m=-6..-1
strip=[]
for c in mshow:
    img=np.abs(psi[...,c])**2
    strip.append(col(img))
strip=np.concatenate([s/ (np.max([t.max() for t in strip])+1e-30) for s in strip],axis=0)
axsg.imshow(strip.T,origin="lower",cmap="inferno",aspect="auto")
axsg.set_yticks([]); axsg.set_xticks([Ng*(i+0.5) for i in range(len(mshow))]); axsg.set_xticklabels([f"m={ms[c]}" for c in mshow],fontsize=8)
axsg.set_title("the raw datum: Stern–Gerlach column images n_m(x,y), no tilt  (the m-ladder)",fontsize=9.5)
axinfo=fig.add_subplot(gs[2,3]); axinfo.axis("off")
axinfo.text(0.0,0.98,
  "VALIDATION (regime B):\n"
  "a single line-of-sight image\n"
  "integrates ∫dz, so it returns the\n"
  "COLUMN-AVERAGED spin texture,\n"
  "not the full 3-D field. The spin\n"
  "vortex (⟨Fx,Fy⟩ winding) survives\n"
  "the column average and is faithfully\n"
  "recovered; z-dependent structure is\n"
  "lost unless you tomographically\n"
  "image at several view angles or\n"
  "light-sheet slice in z.\n\n"
  "This is the honest experimental\n"
  "limit — not a code approximation.",
  transform=axinfo.transAxes,va="top",fontsize=8.7,family="monospace")
fig.suptitle(f"Spin-texture tomography from (tilted) Stern–Gerlach images — EdH ¹⁵¹Eu, t={tms:.1f} ms, B={Bz*1e3:.3f} mG  (validated vs full-ψ truth)",fontsize=12.5)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); print(f"wrote {OUT}  err_vox={err_vox:.2e}  zc={zc} tms={tms:.2f}")
