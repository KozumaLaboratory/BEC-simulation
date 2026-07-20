#!/usr/bin/env python3
"""E(B) curve from the b_sweep_all polished caches.

Plots the LBFGS-converged ground-state energy across the 25 B-grid points,
colour-coded by precision tier:
  - target (|grad| ≤ 5e-4)  → green dots, research-grade
  - tight  (|grad| ≤ 1e-3)  → yellow dots
  - floor  (|grad| > 1e-3)  → red dots (LBFGS numerical floor)

A linear fit through the high-B Zeeman-dominated region (B ≥ 70 μG) extracts
the slope dE/dB.

Reads `lbfgs_<B>uG_final_psi.jld2` (best across final / polish slots).
"""
import os, math, h5py
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
OUT_DIR_LOCAL = os.environ.get("OUT_DIR_LOCAL",
    "runs/eu151_flower_protocol_edh/figures/b_sweep_pm60uG")
OUT_PNG = os.path.join(OUT_DIR_LOCAL, "b_sweep_energy_curve.png")
OUT_CSV = os.path.join(OUT_DIR_LOCAL, "b_sweep_energy_curve.csv")

B_LIST = [-10, 0, 10, 20, 30, 40,
          50, 52, 54, 55, 56, 58, 60, 62, 64, 65, 66, 68, 70,
          80, 90, 100, 120, 150, 200]


def best(b):
    """Return (E, grad_norm) from best of final/polish cache."""
    candidates = []
    for tag in ("final", "polish"):
        p = os.path.join(ROOT, f"lbfgs_{b}uG_{tag}_psi.jld2")
        if not os.path.exists(p):
            continue
        try:
            with h5py.File(p, "r") as f:
                E = float(f["E"][()])
                g = float(f["grad_norm"][()]) if "grad_norm" in f else float("inf")
                if math.isnan(g):
                    g = float("inf")
                candidates.append((g, E))
        except Exception:
            continue
    if not candidates:
        return None, None
    g, E = min(candidates)
    return E, g


def tier(g):
    if g <= 5e-4:
        return "target", "#2ca02c"   # green
    if g <= 1e-3:
        return "tight",  "#daa520"   # gold/yellow
    if g <= 1e-2:
        return "loose",  "#ff7f0e"   # orange
    return "floor", "#d62728"        # red


# Collect
rows = []
for b in B_LIST:
    E, g = best(b)
    if E is None:
        continue
    label, colour = tier(g)
    rows.append((b, E, g, label, colour))

Bs = np.array([r[0] for r in rows])
Es = np.array([r[1] for r in rows])
Gs = np.array([r[2] for r in rows])

# CSV dump
os.makedirs(OUT_DIR_LOCAL, exist_ok=True)
with open(OUT_CSV, "w") as f:
    f.write("B_uG,E,grad_norm,tier\n")
    for b, E, g, label, _ in rows:
        f.write(f"{b},{E:.10f},{g:.6e},{label}\n")

# Linear fit on high-B (B ≥ 70)
hi_mask = Bs >= 70
slope, intercept = np.polyfit(Bs[hi_mask], Es[hi_mask], 1)
B_fit = np.linspace(60, 210, 50)
E_fit = slope * B_fit + intercept

fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True,
                        gridspec_kw=dict(height_ratios=[3, 1], hspace=0.05))

# (top) E(B) with colour-coded tier
ax = axes[0]
for b, E, g, label, colour in rows:
    ax.scatter(b, E, c=colour, s=70, zorder=3, edgecolors="black", linewidths=0.5)
ax.plot(B_fit, E_fit, color="grey", linestyle="--", alpha=0.6, lw=1.2,
        label=f"Zeeman linear fit (B≥70 μG): dE/dB = {slope:.5f}/μG")
# Connect all points
ax.plot(Bs, Es, color="lightgray", lw=0.6, alpha=0.5, zorder=1)

# Tier legend (single point per tier)
from matplotlib.lines import Line2D
legend_handles = [
    Line2D([0], [0], marker="o", color="w", markerfacecolor="#2ca02c",
           markersize=10, markeredgecolor="black", label="target (|∇|≤5e-4)"),
    Line2D([0], [0], marker="o", color="w", markerfacecolor="#daa520",
           markersize=10, markeredgecolor="black", label="tight  (|∇|≤1e-3)"),
    Line2D([0], [0], marker="o", color="w", markerfacecolor="#ff7f0e",
           markersize=10, markeredgecolor="black", label="loose  (|∇|≤1e-2)"),
    Line2D([0], [0], marker="o", color="w", markerfacecolor="#d62728",
           markersize=10, markeredgecolor="black", label="floor  (|∇|>1e-2)"),
    Line2D([0], [0], color="grey", lw=1.2, ls="--",
           label=f"Zeeman fit (B≥70): dE/dB={slope:+.4f}/μG"),
]
ax.legend(handles=legend_handles, loc="upper right", fontsize=9, framealpha=0.95)
ax.set_ylabel(r"$E$  [internal units]", fontsize=12)
ax.set_title("$^{151}$Eu spinor BEC — ground-state E(B) from b_sweep_all polish",
             fontsize=13, pad=8)
ax.grid(True, alpha=0.3)

# (bottom) |grad| precision per B
ax2 = axes[1]
for b, _, g, label, colour in rows:
    ax2.scatter(b, g, c=colour, s=50, zorder=3, edgecolors="black", linewidths=0.4)
ax2.axhline(5e-4, color="#2ca02c", ls=":", lw=0.8, alpha=0.7, label="target 5e-4")
ax2.axhline(1e-3, color="#daa520", ls=":", lw=0.8, alpha=0.7, label="1e-3")
ax2.axhline(1e-2, color="#ff7f0e", ls=":", lw=0.8, alpha=0.7, label="1e-2")
ax2.set_yscale("log")
ax2.set_ylim(1e-4, 1)
ax2.set_xlabel(r"$B$  [μG]", fontsize=12)
ax2.set_ylabel(r"$|\nabla E|$", fontsize=11)
ax2.grid(True, which="both", alpha=0.25)
ax2.legend(loc="upper right", fontsize=8)

fig.tight_layout()
fig.savefig(OUT_PNG, dpi=170)
print(f"wrote {OUT_PNG}")
print(f"wrote {OUT_CSV}")
print(f"\nlinear fit  (B ≥ 70 μG):  E = {slope:+.6f} B + {intercept:+.4f}")
print(f"  slope = {slope:+.6f} per μG")

# Summary
print(f"\nTier counts:")
for t in ("target", "tight", "loose", "floor"):
    n = sum(1 for r in rows if r[3] == t)
    print(f"  {t:>6}: {n:>2d} points")
