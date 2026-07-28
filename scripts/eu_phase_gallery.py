#!/usr/bin/env python3
"""Per-phase gallery: spin texture F̂(r) and mass current j(r), mid-z plane.

    python scripts/eu_phase_gallery.py <_repr_slices.jld2> [out.png]

Two rows per representative cell:
  top    — spin direction: arrows (f̂_x,f̂_y), color f̂_z (blue −1 … red +1)
  bottom — mass current: streamlines of (j_x,j_y), color |j| (circulation/flow)
Density contour on both. Lets each GS phase be read off directly.
"""
import sys
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

f = h5py.File(sys.argv[1], "r")
out = sys.argv[2] if len(sys.argv) > 2 else "eu_phase_gallery.png"
cells = sorted(f.keys(), key=lambda k: (float(f[k]["kappa"][()]), float(f[k]["B_uG"][()])))
nc = len(cells)

fig, axes = plt.subplots(2, nc, figsize=(3.3 * nc, 6.6), squeeze=False)
for j, key in enumerate(cells):
    g = f[key]
    B = float(g["B_uG"][()]); k = float(g["kappa"][()])
    n = np.asarray(g["n_xy"]).T
    inside = n > 0.1 * n.max()
    ny, nx = n.shape
    xs, ys = np.meshgrid(np.arange(nx), np.arange(ny))

    # --- spin texture ---
    fx = np.asarray(g["fx_xy"]).T; fy = np.asarray(g["fy_xy"]).T; fz = np.asarray(g["fz_xy"]).T
    mag = np.sqrt(fx**2 + fy**2 + fz**2) + 1e-30
    ax = axes[0][j]
    ax.imshow(np.where(inside, fz / mag, np.nan), origin="lower", cmap="RdBu_r", vmin=-1, vmax=1)
    st = max(1, nx // 16)
    s = inside & ((xs % st == 0) & (ys % st == 0))
    ax.quiver(xs[s], ys[s], (fx / mag)[s], (fy / mag)[s], color="k",
              angles="xy", scale=st * 1.3, scale_units="xy", width=0.006)
    ax.contour(n, levels=[0.2 * n.max()], colors="gray", linewidths=0.6)
    ax.set_title(f"B={B:.0f}µG  κ={k:.1f}", fontsize=10)
    ax.set_xticks([]); ax.set_yticks([])
    if j == 0: ax.set_ylabel("spin  F̂(r)", fontsize=11)

    # --- mass current ---
    jx = np.asarray(g["jx_xy"]).T; jy = np.asarray(g["jy_xy"]).T
    jmag = np.sqrt(jx**2 + jy**2)
    # physical noise floor: current per atom |j|/n ≪ this ⇒ no real flow. Below it
    # we do NOT plot j (it is machine-zero roundoff — avoids showing a checkerboard).
    jflow = jmag.max() / (n.max() + 1e-30)   # ~ peak superfluid speed
    ax2 = axes[1][j]
    if jflow < 1e-6:
        ax2.imshow(np.where(inside, 0.0, np.nan), origin="lower", cmap="viridis", vmin=0, vmax=1)
        ax2.text(nx / 2, ny / 2, r"$j\approx0$" + f"\n(|j|/n~{jflow:.0e})",
                 ha="center", va="center", fontsize=11, color="0.3")
        im = None
    else:
        jm = np.where(inside, jmag, np.nan)
        im = ax2.imshow(jm, origin="lower", cmap="viridis")
        jxs = np.where(inside, jx, 0.0); jys = np.where(inside, jy, 0.0)
        ax2.streamplot(np.arange(nx), np.arange(ny), jxs, jys, color="w",
                       density=1.0, linewidth=0.7, arrowsize=0.8)
    ax2.contour(n, levels=[0.2 * n.max()], colors="gray", linewidths=0.6)
    ax2.set_xticks([]); ax2.set_yticks([])
    if j == 0: ax2.set_ylabel("mass current  j(r)", fontsize=11)
    if im is not None:
        fig.colorbar(im, ax=ax2, shrink=0.7, label="|j|")

fig.suptitle(r"$^{151}$Eu F=6 GS phases: spin texture (top) & mass current (bottom), mid-z plane",
             y=1.01)
fig.tight_layout()
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
