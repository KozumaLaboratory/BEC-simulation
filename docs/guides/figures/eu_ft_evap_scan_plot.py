#!/usr/bin/env python3
"""Evaporation-ramp parameter landscapes: N_BEC vs each of the 3 ramp-transform
parameters (duration, final power, time-warp), holding the other two at the
widened-bounds optimum.

Shows whether N_BEC has a real physical peak (evaporation too short, or trap too
shallow → spilling) or keeps rising to the bound (a model limit that would need a
depth/spilling constraint). Dashed line = baseline (identity, param=1).

Usage: python3 eu_ft_evap_scan_plot.py [eu_ft_evap_ramp_scan.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_evap_ramp_scan.csv")
d = np.genfromtxt(csv, delimiter=",", names=True, dtype=None, encoding="utf-8")
params = ["duration", "final_power", "warp"]
titles = ["duration scale", "final-power scale", "time-warp γ"]

fig, axes = plt.subplots(1, 3, figsize=(12.5, 4.0))
for ax, pname, title in zip(axes, params, titles):
    m = d["param"] == pname
    v = d["value"][m]
    N = d["N_BEC"][m]
    reached = d["reached"][m].astype(str)
    order = np.argsort(v)
    v, N, reached = v[order], N[order], reached[order]
    ok = np.array([r.lower().startswith("t") for r in reached])
    if ok.sum() >= 2:
        ax.plot(*smooth(v[ok], N[ok]), "-", color="#1f6feb", lw=2.2, label="reached BEC")
    if (~ok).any():
        ax.plot(v[~ok], N[~ok], "x", color="#d1242f", ms=7, label="no BEC")
    ax.axvline(1.0, ls="--", color="#999", lw=1.2, label="baseline (=1)")
    if ok.any():
        im = np.argmax(N[ok])
        ax.plot(v[ok][im], N[ok][im], "*", color="#2da44e", ms=17, mec="white", mew=0.6)
    ax.set_xlabel(title)
    ax.set_ylabel(r"$N_\mathrm{BEC}$")
    ax.set_title(title)
    ax.legend(frameon=False, fontsize=8)
    ax.grid(True, alpha=0.25)

fig.suptitle("¹⁵¹Eu evaporation-ramp parameter landscapes (widened bounds; ★ = peak)",
             fontsize=11)
fig.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(here, "eu_ft_evap_scan.png")
fig.savefig(out, dpi=150)
print("wrote", out)
