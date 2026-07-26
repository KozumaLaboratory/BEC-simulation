#!/usr/bin/env python3
"""Non-equilibrium evaluation of the evaporation duration knife-edge.

N_BEC vs ramp-duration scale with the finite-evaporation-rate penalty OFF
(quasi-static: fast ramps evaporate ideally → "shorter is always better", a bare
reachability knife-edge) and ON (fast ramps outrun evaporation → the exposed atoms
spill instead of evaporate → less cooling). Turning the physical penalty on converts
the knife-edge into a real interior optimum at a moderate duration. Linear axes.

Usage: python3 eu_ft_evap_noneq_plot.py [eu_ft_evap_noneq.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_evap_noneq.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
x = np.atleast_1d(d["duration_scale"])
off = np.atleast_1d(d["N_BEC_noneq_off"])
on = np.atleast_1d(d["N_BEC_noneq_on"])
o = np.argsort(x)
x, off, on = x[o], off[o], on[o]

fig, ax = plt.subplots(figsize=(7.0, 4.7))
# only plot where BEC is reached (N>0)
mo = off > 0
mn = on > 0
ax.plot(x[mo], off[mo], "-o", color="#8a8a8a", ms=6, lw=1.8,
        label="quasi-static (noneq off) — monotone → knife-edge")
ax.plot(x[mn], on[mn], "-o", color="#1f6feb", ms=7, lw=2,
        label="finite-rate penalty (noneq on) — physical")
if mn.any():
    i = np.argmax(on[mn])
    ax.plot(x[mn][i], on[mn][i], "*", color="#2da44e", ms=20, mec="white", mew=0.8,
            label=fr"physical optimum dur={x[mn][i]:.2f}")
ax.axvline(1.0, ls="--", color="#bbb", lw=1.2, label="baseline (=1)")
ax.set_xlabel(r"ramp-duration scale")
ax.set_ylabel(r"$N_\mathrm{BEC}$")
ax.set_title("¹⁵¹Eu evaporation duration: the non-equilibrium penalty turns the\n"
             "knife-edge into a real interior optimum (fast ramps spill, not evaporate)")
ax.legend(frameon=False, fontsize=8.5)
ax.grid(True, alpha=0.25)
ax.set_ylim(bottom=0)
fig.tight_layout()
out = os.path.join(here, "eu_ft_evap_noneq.png")
fig.savefig(out, dpi=150)
print("wrote", out)
