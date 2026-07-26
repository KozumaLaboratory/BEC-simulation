#!/usr/bin/env python3
"""Finite-T validation V-kcut: the condensate N₀ is independent of the UV cutoff.

The classical-field total/thermal population depends on where the classical
region is cut (k_cut) — that dependence is real and expected. The CONDENSATE N₀,
being an infrared (macroscopically-occupied lowest-mode) quantity, must NOT
depend on the UV cutoff. A flat N₀(k_cut) with a k_cut-scaling thermal cloud is
the direct evidence that the condensate observable is physical, not a
classical-field control-parameter artefact.

Usage: python3 eu_ft_kcut_plot.py [eu_ft_kcut.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_kcut.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
k = np.atleast_1d(d["k_cut"])
N0 = np.atleast_1d(d["N0"])
Nth = np.atleast_1d(d["N_thermal"])
order = np.argsort(k)
k, N0, Nth = k[order], N0[order], Nth[order]

N0_mean = N0.mean()
spread = (N0.max() - N0.min()) / N0_mean

fig, ax = plt.subplots(figsize=(6.6, 4.6))
ax.plot(k, N0, "-o", color="#1f6feb", ms=8, lw=1.7, label="condensate $N_0$ (IR)")
ax.plot(k, Nth, "-s", color="#bf8700", ms=7, lw=1.5, label="thermal cloud $N_{th}$ (UV, cutoff-dep.)")
ax.axhline(N0_mean, ls="--", color="#1f6feb", lw=1.0, alpha=0.6,
           label=fr"$\langle N_0\rangle$ (spread {100*spread:.1f}%)")
ax.set_xlabel(r"classical-field cutoff $k_\mathrm{cut}$")
ax.set_ylabel("atom number")
ax.set_title("¹⁵¹Eu finite-T V-kcut: condensate is cutoff-independent\n"
             r"$N_0$ flat while $N_{th}$ scales with $k_\mathrm{cut}$")
ax.legend(frameon=False, fontsize=9.5)
ax.grid(True, alpha=0.25)
ax.set_ylim(bottom=0)
fig.tight_layout()
out = os.path.join(here, "eu_ft_kcut.png")
fig.savefig(out, dpi=150)
print("wrote", out, "| N0 spread = %.1f%%" % (100 * spread))
