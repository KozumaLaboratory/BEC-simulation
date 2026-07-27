#!/usr/bin/env python3
"""Cutoff-convergence study: condensate N₀ vs classical-field cutoff k_cut at
increasing grid resolution (higher k_max). If N₀(k_cut) flattens as the grid is
refined, the c-field cutoff dependence is a resolution artefact converging away; if
it persists the spread is the honest classical-field limit. Single axes, smooth.

Provenance:
- shows: condensate N₀ vs k_cut at grid_n = 64, 96 (TSUBAME) — the cutoff-convergence
  of the finite-T SGPE (honest classical-field limitation of the evaporation arbiter)
- referenced by: current-best result, not yet in a guide (issue #75 Approach A)
- supersedes: the earlier single-resolution 48³ kcut figure (consolidated away)

Usage: python3 eu_ft_cutoff_study_plot.py eu_ft_kcut_64.csv eu_ft_kcut_96.csv [...]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
csvs = sys.argv[1:] if len(sys.argv) > 1 else [
    os.path.join(here, "eu_ft_kcut_64.csv"), os.path.join(here, "eu_ft_kcut_96.csv")]
colors = ["#1f6feb", "#d1242f", "#2da44e", "#8250df"]

fig, ax = plt.subplots(figsize=(7.0, 4.7))
for i, csv in enumerate(csvs):
    if not os.path.exists(csv):
        continue
    d = np.genfromtxt(csv, delimiter=",", names=True)
    k = np.atleast_1d(d["k_cut"])
    N0 = np.atleast_1d(d["N0"])
    o = np.argsort(k)
    label = os.path.splitext(os.path.basename(csv))[0].replace("eu_ft_kcut_", "grid $")+"^3$"
    ax.plot(*smooth(k[o], N0[o]), "-", color=colors[i % len(colors)], lw=2.2, label=label)
ax.set_xlabel(r"classical-field cutoff $k_\mathrm{cut}$")
ax.set_ylabel(r"condensate $N_0$")
ax.set_title("¹⁵¹Eu finite-T SGPE cutoff convergence: does $N_0(k_\\mathrm{cut})$\n"
             "flatten as the grid is refined? (honest classical-field limit)")
ax.legend(frameon=False, fontsize=9)
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, "eu_ft_cutoff_study.png")
fig.savefig(out, dpi=150)
print("wrote", out)
