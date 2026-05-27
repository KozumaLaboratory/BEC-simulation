#!/usr/bin/env python3
"""
plot_trajectory.py — produce a 2×2 figure from this dir's trajectory.json:
  (a) N(t)/N(0) for each cell (loss curve vs Matsui reference)
  (b) Fz(t)/N(t) for each cell (spin transfer)
  (c) N_m(t)/N(t) for selected m components (cascade morphology)
  (d) peak_density(t) (collapse / stability check)

Adapted from runs/eu151_edh_K3_long/plot_trajectory.py.
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA = HERE / "trajectory.json"
OUT = HERE / "trajectory.png"

if not DATA.exists():
    print(f"FATAL: {DATA} not found.  Run extract_trajectory.jl first.")
    sys.exit(1)
with open(DATA) as f:
    data = json.load(f)

CELL_COLORS = {
    "lossfree":      "#1f77b4",   # blue
    "K3_calibrated": "#d62728",   # red
}

plt.rcParams.update({
    "font.size": 9, "axes.titlesize": 10, "axes.labelsize": 9,
    "legend.fontsize": 8, "savefig.dpi": 180,
})

fig, axes = plt.subplots(2, 2, figsize=(12, 8))

# --- (a) N(t)/N(0) ---
ax = axes[0, 0]
for cell, d in data.items():
    color = CELL_COLORS.get(cell, "gray")
    ax.plot(d["t_ms"], d["N_over_N0"], "-", label=cell, color=color, linewidth=1.8)
ax.axhline(0.6, color="black", linestyle="--", linewidth=1.0, alpha=0.6,
           label="Matsui exp. ≈ 0.6")
ax.set_xlabel("t [ms]"); ax.set_ylabel("N(t) / N(0)")
ax.set_title("(a) Atom number — K3 calibration vs loss-free reference")
ax.grid(True, alpha=0.3)
ax.legend(loc="best", fontsize=8)
ax.set_xlim(0, 40); ax.set_ylim(0, 1.05)

# --- (b) Fz(t)/N(t) ---
ax = axes[0, 1]
for cell, d in data.items():
    color = CELL_COLORS.get(cell, "gray")
    ax.plot(d["t_ms"], d["Fz_per_N"], "-", label=cell, color=color, linewidth=1.8)
ax.axhline(-6.0, color="gray", linestyle=":", linewidth=0.8, alpha=0.5,
           label="initial m=−F")
ax.set_xlabel("t [ms]"); ax.set_ylabel(r"$\langle F_z\rangle / N$")
ax.set_title("(b) Spin polarisation drift — EdH transfer")
ax.grid(True, alpha=0.3)
ax.legend(loc="best", fontsize=8)
ax.set_xlim(0, 40)

# --- (c) component populations N_m(t)/N(t) (m = -6, -5, -4, -3, 0) ---
ax = axes[1, 0]
m_select = [-6, -5, -4, -3, 0]
m_colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"]
# Use the K3_calibrated cell if present, else first.
prim = "K3_calibrated" if "K3_calibrated" in data else next(iter(data))
d = data[prim]
for m, color in zip(m_select, m_colors):
    key = f"m_{m}"
    if key in d["N_m_t"]:
        ax.plot(d["t_ms"], d["N_m_t"][key], "-", color=color,
                 label=f"m={m}", linewidth=1.6)
ax.set_xlabel("t [ms]"); ax.set_ylabel(r"$N_m / N$")
ax.set_title(f"(c) m-component cascade — {prim}")
ax.grid(True, alpha=0.3)
ax.legend(loc="best", fontsize=8, ncol=2)
ax.set_xlim(0, 40); ax.set_ylim(0, 1.05)

# --- (d) peak density ---
ax = axes[1, 1]
for cell, d in data.items():
    color = CELL_COLORS.get(cell, "gray")
    if d.get("peak_t"):
        # peak_t indices vs t_ms indices may not align if save_every differs;
        # truncate to common length.
        n = min(len(d["peak_t"]), len(d["t_ms"]))
        ax.plot(d["t_ms"][:n], d["peak_t"][:n], "-", label=cell,
                 color=color, linewidth=1.8)
ax.set_xlabel("t [ms]"); ax.set_ylabel("peak density [a_ho⁻³]")
ax.set_title("(d) Peak density — stability check")
ax.grid(True, alpha=0.3)
ax.legend(loc="best", fontsize=8)
ax.set_xlim(0, 40)

fig.suptitle(
    "eu151_edh_v2 — Matsui-aligned canonical EdH (K_3 = 2.1×10⁻⁴⁰ m⁶/s calibrated to Matsui ~40% loss)",
    y=1.00, fontsize=11,
)
fig.tight_layout()
fig.savefig(OUT)
plt.close(fig)
print(f"wrote {OUT}")
