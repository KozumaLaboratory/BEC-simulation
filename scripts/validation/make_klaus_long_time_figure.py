#!/usr/bin/env python3
"""
make_klaus_long_time_figure.py — Fig K13: long-time vortex-nucleation
result (Prasad timescale probe).

3 cells:
  Ω=-0.5 keep_rot t=100 ω⊥⁻¹  ≈ 145 ms
  Ω=-0.5 keep_rot t=350 ω⊥⁻¹  ≈ 510 ms
  Ω=0 baseline   t=350 ω⊥⁻¹  ≈ 510 ms

Shows:
  (a) P_exc(t) trajectory for the 3 cells (spin cascade growth)
  (b) z=0 total-density slice at end of hold for the 3 cells with
      detected vortices marked
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import h5py  # using h5py to read JLD2 — has limited support, may not work for streamed groups

# Fall back: just read pre-extracted JSON or use Julia for slice extraction.
# For this figure, we'll use a Julia-side extractor → JSON, then plot.

OUT = Path(__file__).resolve().parents[2] / "docs" / "manuscript" / "figures" / "klaus_quench_fig_k13_long_time_vortex.png"
DATA = Path(__file__).resolve().parents[2] / "docs" / "manuscript" / "figures_data" / "klaus_long_time_extract.json"

if not DATA.exists():
    print(f"FATAL: {DATA} not found — run klaus_long_time_extract.jl first.", file=sys.stderr)
    sys.exit(1)
with open(DATA) as f:
    data = json.load(f)

CELLS = [
    ("Ω = -0.5 keep_rot,  t = 100/ω⊥ (~145 ms)",   "t100"),
    ("Ω = -0.5 keep_rot,  t = 350/ω⊥ (~510 ms)",   "t350_rot"),
    ("Ω = 0 baseline,     t = 350/ω⊥ (~510 ms)",   "t350_base"),
]

plt.rcParams.update({
    "font.size": 9, "axes.titlesize": 10, "axes.labelsize": 9,
    "legend.fontsize": 8, "savefig.dpi": 180,
})

fig = plt.figure(figsize=(14.5, 7.5))
gs = fig.add_gridspec(2, 3, height_ratios=[1.0, 1.3], hspace=0.4, wspace=0.30)

# Row 1: P_exc(t) overlay
ax_traj = fig.add_subplot(gs[0, :])
colors = ["#d62728", "#9467bd", "#1f77b4"]
for (label, key), color in zip(CELLS, colors):
    cell = data[key]
    t_ms = cell["t_ms"]
    P_exc = cell["P_exc_t"]
    ax_traj.plot(t_ms, P_exc, "-", color=color, label=label, linewidth=1.8)
ax_traj.set_xlabel("t [ms]")
ax_traj.set_ylabel(r"$P_{\rm exc}(t) = 1 - N_{-6}(t)/N(t)$")
ax_traj.set_title(
    "(a) Spin-cascade trajectory: rotation drives complete depletion of m=−6 by t ≈ 100 ω⊥⁻¹\n"
    "    no rotation → only 24% excitation"
)
ax_traj.grid(True, alpha=0.3)
ax_traj.legend(loc="lower right", fontsize=8)
ax_traj.set_xlim(0, 520)
ax_traj.set_ylim(0, 1.05)

# Row 2: z=0 total density at end for each cell
for ci, (label, key) in enumerate(CELLS):
    ax = fig.add_subplot(gs[1, ci])
    cell = data[key]
    box = cell["box"]
    extent = (-box / 2, box / 2, -box / 2, box / 2)
    dens = np.array(cell["density_total_end"])
    im = ax.imshow(dens.T, origin="lower", extent=extent, cmap="viridis",
                    vmin=0)
    # Mark detected vortices as +/- markers.
    vortex_xs = cell.get("vortex_positions_xs", [])
    vortex_ys = cell.get("vortex_positions_ys", [])
    vortex_ss = cell.get("vortex_signs", [])
    for vx, vy, vs in zip(vortex_xs, vortex_ys, vortex_ss):
        marker = "+" if vs > 0 else "_"
        col = "red" if vs > 0 else "cyan"
        ax.plot([vx], [vy], marker, color=col, markersize=10, markeredgewidth=2)
    np_count = sum(1 for s in vortex_ss if s > 0)
    nm_count = sum(1 for s in vortex_ss if s < 0)
    ax.set_title(label, fontsize=9)
    ax.set_xlabel("x [a_ho]"); ax.set_ylabel("y [a_ho]")
    ax.set_aspect("equal")
    fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02)
    ax.text(0.04, 0.96, f"vortices: +{np_count} / −{nm_count}",
             transform=ax.transAxes, fontsize=9, color="white",
             bbox=dict(facecolor="black", alpha=0.7, edgecolor="none", pad=2),
             ha="left", va="top")

fig.suptitle(
    "Figure K13 — Klaus-I long-time vortex-nucleation probe (Prasad timescale).\n"
    "Top: spin cascade trajectory shows rotation drives ~97% of atoms out of m=−6 by t ~100/ω⊥.\n"
    "Bottom: total-density z=0 slice at end of hold; rotation produces ~24 vortices; baseline shows zero.",
    y=0.995, fontsize=11,
)
fig.savefig(OUT, bbox_inches="tight")
plt.close(fig)
print(f"wrote {OUT}")
