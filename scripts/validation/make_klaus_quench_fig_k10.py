#!/usr/bin/env python3
"""
make_klaus_quench_fig_k10.py — mechanism figure.

Reads docs/manuscript/figures_data/klaus_quench_mode_extract.json (produced
by klaus_quench_mode_extract.jl) and composes Fig K10: per-component z=0
density slice + phase texture, with winding-number annotation, for the
four representative cells (Ω=0 baseline / Ω=-0.5 matched / Ω=+0.5
mismatched / m=+F mirror).

Story: each spin-flip into m_init ∓ k carries k quanta of orbital angular
momentum (winding number ±k), set by Jz conservation.  Sustained rotation
H − Ω L_z shifts the energy of these orbital modes by ΔE = −Ω · ℓ ℏ; the
"matched" chirality (Ω · ℓ < 0) lowers the mode energy and enhances
population transfer.
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "docs" / "manuscript" / "figures_data" / "klaus_quench_mode_extract.json"
OUT = ROOT / "docs" / "manuscript" / "figures" / "klaus_quench_fig_k10_mechanism.png"

plt.rcParams.update({
    "font.size": 9,
    "axes.titlesize": 10,
    "axes.labelsize": 9,
    "legend.fontsize": 8,
    "savefig.dpi": 180,
})

if not DATA.exists():
    print(f"FATAL: {DATA} not found.", file=sys.stderr)
    sys.exit(1)
with open(DATA) as f:
    data = json.load(f)


CELLS_ORDER = [
    "Ω = 0 baseline (m=−F)",
    "Ω = −0.5 keep_rot matched",
    "Ω = +0.5 mismatched (weak)",
    "Ω = +0.5 keep_rot, m=+F mirror",
]

n_rows = len(CELLS_ORDER)
n_cols = 3  # m_init, m_init∓1, m_init∓2

fig, axes = plt.subplots(n_rows, n_cols, figsize=(11, 3.0 * n_rows),
                          squeeze=False)

for ri, label in enumerate(CELLS_ORDER):
    cell = data.get(label)
    if cell is None:
        for ci in range(n_cols):
            axes[ri, ci].text(0.5, 0.5, f"missing\n{label}",
                              ha="center", va="center")
            axes[ri, ci].axis("off")
        continue
    sign = cell["init_m_sign"]
    m_init = cell["m_init"]
    m_list = [m_init, m_init - sign * 1, m_init - sign * 2]
    box = cell["box"]
    extent = (-box / 2, box / 2, -box / 2, box / 2)
    n_grid = cell["n_grid"]

    # Color scale: per-column shared so visual contrast is fair.
    col_vmax = []
    for ci, m in enumerate(m_list):
        row_data = cell[f"m_{m}"]
        dens = np.array(row_data["density"])
        col_vmax.append(float(dens.max()))

    for ci, m in enumerate(m_list):
        ax = axes[ri, ci]
        row_data = cell[f"m_{m}"]
        dens = np.array(row_data["density"])
        # Show density (viridis); overlay phase as contour where density >
        # 5% of column max.
        ax.imshow(dens.T, origin="lower", extent=extent, cmap="viridis",
                   vmin=0, vmax=col_vmax[ci] if col_vmax[ci] > 0 else 1e-30)
        # Annotate winding + population.
        w = row_data["winding_number"]
        pop = cell["N_per_m_normalised"].get(f"m_{m}", 0.0)
        # Title format per column: m label.
        if ri == 0:
            if m == m_init:
                ax.set_title(f"m = {m:+d}  (carrier)")
            elif abs(m - m_init) == 1:
                ax.set_title(f"m = {m:+d}  (m_init ∓ 1)")
            else:
                ax.set_title(f"m = {m:+d}  (m_init ∓ 2)")
        # Overlay winding label.
        winding_color = "white"
        ax.text(0.04, 0.92, f"winding = {w:+.1f}", transform=ax.transAxes,
                fontsize=9, color=winding_color,
                bbox=dict(facecolor="black", alpha=0.55, edgecolor="none",
                          pad=2))
        ax.text(0.04, 0.06, f"N_m / N = {pop:.3f}", transform=ax.transAxes,
                fontsize=8, color=winding_color,
                bbox=dict(facecolor="black", alpha=0.55, edgecolor="none",
                          pad=2))
        # Phase contours overlay.
        ph = np.array(row_data["phase"])
        mask = dens > 0.05 * (col_vmax[ci] + 1e-30)
        # Plot phase as quiver-style arrow heads:  show cos(ph), sin(ph) where mask.
        xs = np.linspace(-box / 2, box / 2, n_grid)
        ys = np.linspace(-box / 2, box / 2, n_grid)
        XX, YY = np.meshgrid(xs, ys, indexing="ij")
        if mask.any():
            # Subsample for clarity.
            stride = 4
            Xc = XX[::stride, ::stride]
            Yc = YY[::stride, ::stride]
            Pc = ph[::stride, ::stride]
            Mc = mask[::stride, ::stride]
            U = np.cos(Pc); V = np.sin(Pc)
            U = np.where(Mc, U, np.nan)
            V = np.where(Mc, V, np.nan)
            ax.quiver(Xc, Yc, U, V, color="orange", width=0.005,
                      headwidth=3, headlength=4, alpha=0.85)

        if ci == 0:
            ax.set_ylabel(label, fontsize=8.5, rotation=90, ha="center",
                          labelpad=8)
        ax.set_xticks([]); ax.set_yticks([])
        ax.set_aspect("equal")

fig.suptitle(
    "Figure K10 — Mechanism: orbital winding accompanies the spin-flip cascade\n"
    "Density (z=0, post-hold) + phase (orange arrows) for m=m_init, m_init∓1, m_init∓2.\n"
    "Winding number is set by Jz conservation (carrier=0, m∓1=±1, m∓2=±2); rotation reshapes mode energies via ΔE = −Ω·ℓ.",
    y=1.005, fontsize=11,
)
fig.tight_layout()
fig.savefig(OUT, bbox_inches="tight")
plt.close(fig)
print(f"wrote {OUT}")
