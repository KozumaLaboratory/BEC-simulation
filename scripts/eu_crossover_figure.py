#!/usr/bin/env python3
"""Physical-Eu flower → uniform-FM canting crossover (fingerprint order params).

    python scripts/eu_crossover_figure.py <fingerprint_table.csv> [out.png]

At physical Eu (c1=+1/36) the weak-field GS is the FLOWER (flux-closure,
∇·F≈0) phase — locally magnetised (mF>0) with a divergence-free texture — and
increasing B CANTS it continuously toward uniform ferromagnetic. So the honest
order parameter is the flux-closure metric ‖∇·F‖/‖∇F‖ (≈0 flower → 0.577 uniform),
NOT a discrete phase label. Three (B×κ) heatmaps: flux-closure, mF, coherence.
"""
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

csv = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "eu_crossover.png"
df = pd.read_csv(csv)
df = df[np.isclose(df.c1_ratio, df.c1_ratio.max())].copy()

ks = np.sort(df.kappa.unique())
bs = np.sort(df.B_uG.unique())

def grid(col):
    Z = np.full((len(ks), len(bs)), np.nan)
    for _, r in df.iterrows():
        Z[np.where(ks == r.kappa)[0][0], np.where(bs == r.B_uG)[0][0]] = r[col]
    return Z

panels = [("fluxclosure", r"flux-closure $\|\nabla\!\cdot\!F\|/\|\nabla F\|$", "viridis", (0, 0.6)),
          ("mF", r"bulk magnetisation $|\langle F\rangle|/F$", "magma", (0, 1)),
          ("coh", "spinor coherence $g$", "cividis", (0, 1))]
fig, axes = plt.subplots(1, 3, figsize=(15, 4.4))
for ax, (col, title, cmap, (vmin, vmax)) in zip(axes, panels):
    Z = grid(col)
    im = ax.pcolormesh(bs, ks, Z, cmap=cmap, vmin=vmin, vmax=vmax, shading="nearest")
    fig.colorbar(im, ax=ax)
    if col == "fluxclosure":
        # 0.577 = uniform-spin density-gradient baseline; below ⇒ flux-closed
        cs = ax.contour(bs, ks, Z, levels=[0.15, 0.30, 0.45], colors="w", linewidths=1.2)
        ax.clabel(cs, inline=True, fontsize=8, fmt="%.2f")
    ax.set_xlabel("B (µG)")
    ax.set_ylabel(r"$\kappa=\omega_z/\omega_r$")
    ax.set_title(title)
fig.suptitle(r"$^{151}$Eu F=6 GS: flower $\to$ uniform-FM canting crossover "
             r"(c$_1$=+1/36, 64³) — continuous, not a phase transition", y=1.02)
fig.tight_layout()
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
