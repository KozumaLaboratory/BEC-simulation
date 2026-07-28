#!/usr/bin/env python3
"""Real-space spin-DIRECTION texture montage of representative Eu GS cells.

    python scripts/eu_texture_montage.py <_picks_slices.jld2> [out.png]

_spin_expectation_fields returns the spin DENSITY F=n·f̂ (tiny per voxel), so we
plot the DIRECTION f̂=F/|F| inside the cloud. Top row per cell: mid-z (xy) plane
— arrows (f̂_x,f̂_y), color f̂_z. Bottom: mid-y (xz) plane. Flower = in-plane
circulation (∇·F≈0); uniform FM = all arrows parallel / all f̂_z=−1.
"""
import sys
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

f = h5py.File(sys.argv[1], "r")
out = sys.argv[2] if len(sys.argv) > 2 else "eu_texture_montage.png"
cells = sorted(f.keys(), key=lambda k: (float(f[k]["kappa"][()]), float(f[k]["B_uG"][()])))

def unit(fx, fy, fz, n):
    mag = np.sqrt(fx**2 + fy**2 + fz**2) + 1e-30
    inside = n > 0.1 * n.max()
    return fx / mag, fy / mag, fz / mag, inside

ncell = len(cells)
fig, axes = plt.subplots(2, ncell, figsize=(2.7 * ncell, 5.6), squeeze=False)
for j, key in enumerate(cells):
    g = f[key]
    B = float(g["B_uG"][()]); k = float(g["kappa"][()])
    # --- xy plane (top) ---
    fx, fy, fz, ins = unit(np.asarray(g["fx_xy"]).T, np.asarray(g["fy_xy"]).T,
                           np.asarray(g["fz_xy"]).T, np.asarray(g["n_xy"]).T)
    ax = axes[0][j]
    fzm = np.where(ins, fz, np.nan)
    ax.imshow(fzm, origin="lower", cmap="RdBu_r", vmin=-1, vmax=1)
    ny, nx = fz.shape
    st = max(1, nx // 16)
    xs, ys = np.meshgrid(np.arange(nx), np.arange(ny))
    s = ins & ((xs % st == 0) & (ys % st == 0))
    ax.quiver(xs[s], ys[s], fx[s], fy[s], color="k", angles="xy",
              scale=st * 1.3, scale_units="xy", width=0.006)
    ax.set_title(f"B={B:.0f} κ={k:.1f}", fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    if j == 0: ax.set_ylabel("xy (mid-z)", fontsize=9)
    # --- xz plane (bottom): arrows (f̂_x, f̂_z) show out-of-plane split ---
    fxz = np.asarray(g["fx_xz"]).T; fzz = np.asarray(g["fz_xz"]).T; nxz = np.asarray(g["n_xz"]).T
    magz = np.sqrt(fxz**2 + fzz**2) + 1e-30
    insz = nxz > 0.1 * nxz.max()
    fxu, fzu = fxz / magz, fzz / magz
    ax2 = axes[1][j]
    ax2.imshow(np.where(insz, fzu, np.nan), origin="lower", cmap="RdBu_r", vmin=-1, vmax=1)
    nz, nx2 = fzz.shape
    xs2, zs2 = np.meshgrid(np.arange(nx2), np.arange(nz))
    s2 = insz & ((xs2 % st == 0) & (zs2 % st == 0))
    ax2.quiver(xs2[s2], zs2[s2], fxu[s2], fzu[s2], color="k", angles="xy",
               scale=st * 1.3, scale_units="xy", width=0.006)
    ax2.set_xticks([]); ax2.set_yticks([])
    if j == 0: ax2.set_ylabel("xz (mid-y)", fontsize=9)

fig.suptitle(r"$^{151}$Eu F=6 GS spin DIRECTION $\hat F(r)$: arrows in-plane, "
             r"color $\hat F_z$ (−1 blue … +1 red). Flower=circulation; FM=parallel", y=1.02)
fig.tight_layout()
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
