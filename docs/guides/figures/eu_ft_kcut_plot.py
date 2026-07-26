#!/usr/bin/env python3
"""Finite-T cutoff sensitivity: condensate N₀ and thermal N_th vs the classical
cutoff k_cut.

Honest reading of a genuine classical-field limitation: BOTH the condensate and
the thermal cloud depend on where the classical/quantum boundary k_cut is drawn —
the classical (Rayleigh–Jeans) field over-populates the sparsely-occupied high
modes, so pushing k_cut past the physical boundary ε(k_cut)−μ≈T inflates the
thermal cloud and depletes the condensate. Over k_cut∈[4.6,8.0] the thermal grows
~127% while the condensate drops ~26%: the condensate is the MORE robust of the
two, but it is NOT cutoff-free. Absolute numbers must be quoted at the physical
cutoff (dashed line); only comparisons at FIXED k_cut (e.g. the shape panel) are
cutoff-independent.

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

# physical cutoff: eps(k)-mu ~ T  =>  k = sqrt(2(mu+T)), mu=11.93, T=10.13
k_phys = np.sqrt(2 * (11.93 + 10.13))
d0 = (N0.max() - N0.min()) / N0.mean()
dth = (Nth.max() - Nth.min()) / Nth.mean()

fig, ax = plt.subplots(figsize=(6.8, 4.6))
ax.plot(k, N0, "-o", color="#1f6feb", ms=8, lw=1.7,
        label=fr"condensate $N_0$  (spread {100*d0:.0f}%)")
ax.plot(k, Nth, "-s", color="#bf8700", ms=7, lw=1.5,
        label=fr"thermal $N_{{th}}$  (spread {100*dth:.0f}%)")
ax.axvline(k_phys, ls="--", color="#57606a", lw=1.4,
           label=fr"physical cutoff $\varepsilon-\mu\!\approx\!T$ ($k_\mathrm{{cut}}\!=\!{k_phys:.1f}$)")
ax.set_xlabel(r"classical-field cutoff $k_\mathrm{cut}$")
ax.set_ylabel("atom number")
ax.set_title("¹⁵¹Eu finite-T cutoff sensitivity (Stoof-SGPE, T/T_c=0.5)\n"
             r"condensate is less cutoff-sensitive than the thermal cloud")
ax.legend(frameon=False, fontsize=9)
ax.grid(True, alpha=0.25)
ax.set_ylim(bottom=0)
fig.tight_layout()
out = os.path.join(here, "eu_ft_kcut.png")
fig.savefig(out, dpi=150)
print("wrote", out, "| N0 spread %.0f%%, Nth spread %.0f%%" % (100 * d0, 100 * dth))
