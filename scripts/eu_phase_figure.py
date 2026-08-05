#!/usr/bin/env python3
"""Render the Eu F=6 (c1 × B × κ) ground-state phase diagram.

    python scripts/eu_phase_figure.py <run_dir>/phase_table.csv [out.png]

One column per c1 value; rows = {phase label, ⟨F_z⟩, Q6 icosahedral order,
seed energy gap (bistability)}. Phase regions are discrete; order-parameter
panels are continuous heatmaps over (B, κ) that expose boundaries as jumps.
"""
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm

csv = sys.argv[1] if len(sys.argv) > 1 else sys.exit("need phase_table.csv")
out = sys.argv[2] if len(sys.argv) > 2 else csv.rsplit("/", 1)[0] + "/phase_diagram.png"
df = pd.read_csv(csv)

c1s = sorted(df.c1_ratio.unique())
ncol = len(c1s)

def grid(sub, col):
    ks = np.sort(sub.kappa.unique())
    bs = np.sort(sub.B_uG.unique())
    Z = np.full((len(ks), len(bs)), np.nan)
    for _, r in sub.iterrows():
        Z[np.where(ks == r.kappa)[0][0], np.where(bs == r.B_uG)[0][0]] = r[col]
    return bs, ks, Z

# discrete phase palette
phases = sorted(df.phase.astype(str).unique())
pmap = {p: i for i, p in enumerate(phases)}
cmap = ListedColormap(plt.cm.tab10(np.linspace(0, 1, max(len(phases), 2))))

rows = [("phase", "phase"), ("Fz", r"$\langle F_z\rangle$"),
        ("spin_order", "spin order |⟨F⟩|/F"),
        ("q6_maj", r"$Q_6$ (icosahedral)"), ("E_gap_seeds", "seed gap (bistability)")]
fig, axes = plt.subplots(len(rows), ncol, figsize=(4.2 * ncol, 3.4 * len(rows)),
                         squeeze=False)

for j, c1 in enumerate(c1s):
    sub = df[df.c1_ratio == c1]
    for i, (col, title) in enumerate(rows):
        ax = axes[i][j]
        if col == "phase":
            bs, ks, Zp = grid(sub.assign(pi=sub.phase.astype(str).map(pmap)), "pi")
            im = ax.pcolormesh(bs, ks, Zp, cmap=cmap,
                               norm=BoundaryNorm(np.arange(-.5, len(phases)), cmap.N),
                               shading="nearest")
            if j == ncol - 1:
                cb = fig.colorbar(im, ax=ax, ticks=range(len(phases)))
                cb.ax.set_yticklabels(phases, fontsize=7)
        else:
            bs, ks, Z = grid(sub, col)
            cmap2 = "RdBu_r" if col == "Fz" else ("magma" if col == "q6" else "viridis")
            im = ax.pcolormesh(bs, ks, Z, cmap=cmap2, shading="nearest")
            fig.colorbar(im, ax=ax)
        if i == 0:
            ax.set_title(f"c1_ratio = {c1:+.4f}", fontsize=10)
        if j == 0:
            ax.set_ylabel(f"{title}\nκ = ω_z/ω_r", fontsize=9)
        if i == len(rows) - 1:
            ax.set_xlabel("B (µG)")
        ax.axvspan(40, 62, color="k", alpha=0.06)  # known transition band

fig.suptitle("¹⁵¹Eu F=6 ground-state phase diagram  (B × κ, per c₁)", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.98])
fig.savefig(out, dpi=140)
print("wrote", out)
