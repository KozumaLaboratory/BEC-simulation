#!/usr/bin/env python3
"""Plot the Eu decompression ramp-rate optimization.

Surviving condensate N vs ramp duration τ (ω: 1 → ω_final over τ, then hold).
An interior maximum is the physical optimum of min ∫γ dt: too slow spends time
at high density; too fast excites a breathing mode that overshoots density.
Linear axes (the shape of the trade-off, not a power law); raw points shown.

Usage: python3 eu_shape_ramp_opt_plot.py [eu_shape_ramp_opt.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_shape_ramp_opt.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
tau = np.atleast_1d(d["tau_ms"])
N = np.atleast_1d(d["surviving_N"])
hold_N = float(np.atleast_1d(d["hold_N"])[0])

order = np.argsort(tau)
tau, N = tau[order], N[order]
imax = int(np.argmax(N))

fig, ax = plt.subplots(figsize=(6.4, 4.4))
ax.plot(tau, N, "-o", color="#1f6feb", ms=7, lw=1.6, label="decompress ω:1→ω_f", zorder=3)
ax.axhline(hold_N, ls="--", color="#d1242f", lw=1.5, label="HOLD (no decompress)")
ax.plot(tau[imax], N[imax], "*", color="#2da44e", ms=18,
        label=fr"optimum τ={tau[imax]:.0f} ms", zorder=4)
ax.set_xlabel(r"ramp duration $\tau$ [ms]")
ax.set_ylabel("surviving condensate $N$")
ax.set_title(r"¹⁵¹Eu decompression ramp-rate optimization"
             "\n"
             r"argmax$_\tau N$ = min $\int\gamma\,dt$ subject to breathing")
ax.legend(frameon=False, fontsize=9)
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, "eu_shape_ramp_opt.png")
fig.savefig(out, dpi=150)
print("wrote", out)
