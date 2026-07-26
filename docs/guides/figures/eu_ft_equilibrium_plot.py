#!/usr/bin/env python3
"""Finite-T validation V-key/V-mono: equilibrium condensate fraction vs T/T_c.

Stoof-SGPE condensate fraction f = N₀/N (phase-fixed ensemble) at thermal
equilibrium, against the ideal-Bose reference 1−(T/T_c)³. The SGPE sits below
the ideal curve — the physical signature of classical-field (Rayleigh-Jeans)
thermal over-occupation plus interactions — while reproducing f→1 as T→0 and
monotone melting toward T_c. Linear axes.

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
f = np.atleast_1d(d["f_sgpe"])
order = np.argsort(r)
r, f = r[order], f[order]
fid = np.atleast_1d(d["f_ideal"])[order]

fig, ax = plt.subplots(figsize=(6.4, 4.6))
xx = np.linspace(0, 1, 200)
ax.plot(xx, 1 - xx**3, "--", color="#d1242f", lw=1.8, label=r"ideal Bose $1-(T/T_c)^3$")
ax.plot(r, f, "-o", color="#1f6feb", ms=8, lw=1.7, label="Stoof-SGPE (ensemble)")
ax.axhline(0, color="k", lw=0.6)
ax.set_xlabel(r"$T/T_c$")
ax.set_ylabel(r"condensate fraction $N_0/N$")
ax.set_xlim(0, 1)
ax.set_ylim(-0.02, 1.05)
ax.set_title("¹⁵¹Eu finite-T equilibrium condensate fraction\n"
             r"V-key: $f\to1$ as $T\to0$;  V-mono: monotone melting")
ax.legend(frameon=False, fontsize=10)
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, "eu_ft_equilibrium.png")
fig.savefig(out, dpi=150)
print("wrote", out)
