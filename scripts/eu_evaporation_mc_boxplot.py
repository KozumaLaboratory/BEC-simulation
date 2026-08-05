#!/usr/bin/env python3
"""Box-and-whisker of the ¹⁵¹Eu BEC atom number under random operational errors.

At each operational-error level ε (1σ, applied simultaneously to power/α, beam imbalance, T₀, N₀)
we Monte-Carlo NDRAW realizations and box-plot the resulting N_BEC for the optimum ramp (and the
lab ramp for reference). Individual draws are overlaid as jittered points. Shows the true
shot-to-shot spread, not just the worst case.

Run scripts/eu_evaporation_mc_boxplot.jl first to emit the CSV.
"""
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

FIG = Path(__file__).resolve().parent.parent / "docs" / "guides" / "figures"
d = np.loadtxt(FIG / "eu_evap_mc_boxplot.csv", delimiter=",", skiprows=1, ndmin=2)
eps_all = d[:, 0]
lab_all = d[:, 1] / 1e4
opt_all = d[:, 2] / 1e4
levels = np.unique(eps_all)

opt_by = [opt_all[eps_all == e] for e in levels]
lab_by = [lab_all[eps_all == e] for e in levels]
lab_med = np.median(lab_by[0])

fig, ax = plt.subplots(figsize=(9.5, 5.2))
pos = np.arange(len(levels))
w = 0.34

def box(data, positions, color, label):
    bp = ax.boxplot(data, positions=positions, widths=w, patch_artist=True,
                    whis=(5, 95), showfliers=False, manage_ticks=False)
    for b in bp["boxes"]:
        b.set(facecolor=color, alpha=0.35, edgecolor=color)
    for k in ("whiskers", "caps", "medians"):
        for x in bp[k]:
            x.set(color=color, linewidth=1.5 if k == "medians" else 1.0)
    bp["boxes"][0].set_label(label)
    return bp

box(opt_by, pos - w / 1.7, "tab:blue", "optimum ramp")
box(lab_by, pos + w / 1.7, "0.5", "lab ramp")

# jittered individual draws (the "many points")
rng = np.random.default_rng(0)
for i, (o, l) in enumerate(zip(opt_by, lab_by)):
    ax.scatter(pos[i] - w / 1.7 + rng.uniform(-0.06, 0.06, o.size), o,
               s=4, color="tab:blue", alpha=0.15, zorder=1)
    ax.scatter(pos[i] + w / 1.7 + rng.uniform(-0.06, 0.06, l.size), l,
               s=4, color="0.4", alpha=0.15, zorder=1)

ax.axhline(lab_med, color="0.5", ls=":", lw=1.2, label="lab ramp median (ε=0)")
ax.set_xticks(pos)
ax.set_xticklabels([f"{int(e)}" for e in levels])
ax.set_xlabel("operational-error level  ε  (% 1σ, all axes: power/α · imbalance · T₀ · N₀)")
ax.set_ylabel(r"BEC atom number  $N_{\rm BEC}\ (\times 10^4)$")
ax.set_title("BEC atom-number spread under random operational errors (box: 25–75%, whisker: 5–95%)")
ax.set_ylim(bottom=0)
ax.legend(fontsize=9, loc="lower left")
ax.grid(alpha=0.3, axis="y")

fig.tight_layout()
out = FIG / "eu_evaporation_mc_boxplot.png"
fig.savefig(out, dpi=150)
print("wrote", out)
