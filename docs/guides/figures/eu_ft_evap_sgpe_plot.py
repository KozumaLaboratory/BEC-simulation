#!/usr/bin/env python3
"""Number-conserving evaporation SGPE: total N(t) and condensate N₀(t) as a hot
thermal cloud is evaporatively cooled to a BEC in a closed classical field.

Single axes (atom number vs time). The thermal cloud (gap N−N₀) is evaporated
away while the condensate N₀ holds ⇒ the condensate FRACTION rises to ≈1 —
textbook evaporative cooling, with atom number set only by the two physical loss
channels (evaporation + K₃), not a grand-canonical reservoir. Smooth curves.

Provenance:
- shows: closed-system evaporation SGPE — total N(t) (drops as the thermal cloud
  evaporates) and condensate N₀(t) (held), i.e. the number-conserving absolute-N₀
  arbiter for issue #75 (no grand-canonical pumping artifact)
- referenced by: current-best result, not yet in a guide (issue #75 Approach A)
- supersedes: the deleted reservoir-driven formation run eu_evaporation_sgpe_formation
  (grand-canonical pumping artifact)

Usage: python3 eu_ft_evap_sgpe_plot.py [eu_ft_evap_sgpe.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_evap_sgpe.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
t = np.atleast_1d(d["t_ms"])
N = np.atleast_1d(d["N"])
N0 = np.atleast_1d(d["N0"])
frac = np.atleast_1d(d["frac"])

fig, ax = plt.subplots(figsize=(7.0, 4.7))
ax.plot(*smooth(t, N), "-", color="#8a8a8a", lw=2.2, label=r"total $N$ (thermal + condensate)")
ax.plot(*smooth(t, N0), "-", color="#1f6feb", lw=2.4, label=r"condensate $N_0$ (bias-corrected)")
ax.fill_between(t, N0, N, color="#bf8700", alpha=0.12, label="thermal cloud (evaporated away)")
ax.annotate(fr"cond. fraction $\rightarrow$ {frac[-1]:.2f}",
            xy=(t[-1], N0[-1]), xytext=(t[len(t) // 3], max(N) * 0.6),
            fontsize=9.5, color="#1f6feb")
ax.set_xlabel("time [ms]")
ax.set_ylabel("atom number")
ax.set_ylim(bottom=0)
ax.set_title("¹⁵¹Eu number-conserving evaporation SGPE: evaporate the thermal cloud,\n"
             "keep the condensate (closed field, γ=0 — no grand-canonical pumping)")
ax.legend(frameon=False, fontsize=9, loc="upper right")
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, os.path.splitext(os.path.basename(csv))[0] + ".png")  # name from input CSV
fig.savefig(out, dpi=150)
print("wrote", out)
