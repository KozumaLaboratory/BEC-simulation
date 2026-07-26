#!/usr/bin/env python3
"""Finite-T equilibrium: condensate N₀ and thermal N_th vs T/T_c.

The PHYSICAL observable is the condensate number N₀ (infrared, cutoff-robust —
see the k_cut panel). The thermal cloud N_th is a classical-field (Rayleigh–Jeans)
quantity: each classical mode carries ~k_B T rather than the Bose occupation, so
it over-populates relative to a quantum gas and the fraction N₀/N_tot falls below
the quantum 1−(T/T_c)³. That quantum curve is drawn only for orientation, NOT as a
fit — the condensate N₀, not the fraction, is what the classical field gets right.

Usage: python3 eu_ft_equilibrium_plot.py [eu_ft_equilibrium.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_equilibrium.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
r = np.atleast_1d(d["T_over_Tc"])
N0 = np.atleast_1d(d["N0"])
Nth = np.atleast_1d(d["N_thermal"])
n0n = np.atleast_1d(d["N0_over_N"])
order = np.argsort(r)
r, N0, Nth, n0n = r[order], N0[order], Nth[order], n0n[order]

fig, (axN, axf) = plt.subplots(1, 2, figsize=(10.5, 4.4))

axN.plot(r, N0, "-o", color="#1f6feb", ms=7, label=r"condensate $N_0$ (physical, IR)")
axN.plot(r, Nth, "-s", color="#bf8700", ms=6, label=r"thermal $N_{th}$ (classical-field, RJ)")
axN.axhline(1e4, ls=":", color="#1f6feb", alpha=0.5, lw=1.0, label=r"$N$")
axN.set_xlabel(r"$T/T_c$")
axN.set_ylabel("atom number")
axN.set_title(r"condensate melts (V-mono); thermal is Rayleigh–Jeans")
axN.legend(frameon=False, fontsize=8.5)
axN.grid(True, alpha=0.25)
axN.set_ylim(bottom=0)

xx = np.linspace(0, 1, 200)
axf.plot(xx, 1 - xx**3, "--", color="#999", lw=1.5, label=r"quantum $1-(T/T_c)^3$ (orientation)")
axf.plot(r, n0n, "-o", color="#1f6feb", ms=7, label=r"$N_0/N$ (SGPE)")
axf.set_xlabel(r"$T/T_c$")
axf.set_ylabel(r"$N_0/N$")
axf.set_xlim(0, 1)
axf.set_ylim(0, 1.05)
axf.set_title(r"V-T0: $N_0/N\to1$ as $T\to0$")
axf.legend(frameon=False, fontsize=9)
axf.grid(True, alpha=0.25)

fig.suptitle("¹⁵¹Eu finite-T equilibrium (Stoof-SGPE, HOLD trap)", fontsize=11)
fig.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(here, "eu_ft_equilibrium.png")
fig.savefig(out, dpi=150)
print("wrote", out)
