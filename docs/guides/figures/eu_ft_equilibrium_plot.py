#!/usr/bin/env python3
"""Finite-T equilibrium condensate fraction: analytic (from atom+trap+N) vs SGPE.

ONE axes, the money comparison N₀/N vs T/T_c. The fixed-N equilibrium is analytic —
the quantum thermal cloud is bounded, N_th=ζ(3)(k_BT/ℏω̄)³=N(T/T_c)³, so
N₀/N=1−(T/T_c)³ (with μ(T)=μ_GP(N₀/N)^{2/5}, μ_GP=½ℏω̄(15N a_s/a_ho)^{2/5}=11.76).
The classical-field SGPE over-populates the thermal cloud (Rayleigh–Jeans: each
classical mode carries ~k_B T), so its N₀/N sits BELOW the analytic curve — a method
artefact, not physics. The condensate N₀ itself (not the fraction) is the robust
observable; the SGPE earns its keep in the DYNAMICS, not the equilibrium.

Overlays analytic curve + SGPE points on the same T/T_c axis (genuine single-plot
consolidation of the former analytic/SGPE 2-panel pair).

Usage: python3 eu_ft_equilibrium_plot.py [analytic.csv] [sgpe.csv]

Provenance:
- shows: condensate fraction N0/N vs T/Tc — analytic mu-pinned curve + ideal-Bose reference + SGPE points, single axes
- referenced by: docs/guides/eu_shape_finite_t.md
- supersedes: eu_ft_equilibrium_analytic_plot.py (its analytic curve is folded into this single-axes plot)
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
acsv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_equilibrium_analytic.csv")
scsv = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "eu_ft_equilibrium.csv")
a = np.genfromtxt(acsv, delimiter=",", names=True)
ar = a["T_over_Tc"]; an = a["N0_over_N"]
o = np.argsort(ar); ar, an = ar[o], an[o]

fig, ax = plt.subplots(figsize=(7.0, 4.7))
xx = np.linspace(0, 1, 200)
ax.plot(xx, 1 - xx**3, "--", color="#999", lw=1.6,
        label=r"ideal quantum $1-(T/T_c)^3$ (orientation)")
ax.plot(*smooth(ar, an), "-", color="#8250df", lw=2.4,
        label=r"analytic $N_0/N$ (atom+trap+$N$, $\mu$-pinned)")
if os.path.exists(scsv):
    s = np.genfromtxt(scsv, delimiter=",", names=True)
    ax.plot(np.atleast_1d(s["T_over_Tc"]), np.atleast_1d(s["N0_over_N"]),
            "o", color="#1f6feb", ms=8, mfc="white", mew=1.4,
            label=r"SGPE $N_0/N$ (classical field, RJ $\Rightarrow$ below)")
ax.annotate("SGPE below the analytic curve:\nclassical-field Rayleigh–Jeans\nover-populates the thermal cloud",
            xy=(0.52, 0.28), fontsize=8.5, color="#555", va="center")
ax.set_xlabel(r"$T/T_c$")
ax.set_ylabel(r"condensate fraction $N_0/N$")
ax.set_xlim(0, 1)
ax.set_ylim(0, 1.05)
ax.set_title("¹⁵¹Eu finite-T equilibrium: fraction is analytic; SGPE (RJ) sits below\n"
             "(V-T0: $N_0/N\\to1$ as $T\\to0$; equilibrium closed-form, SGPE for dynamics)")
ax.legend(frameon=False, fontsize=9, loc="upper right")
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, "eu_ft_equilibrium.png")
fig.savefig(out, dpi=150)
print("wrote", out)
