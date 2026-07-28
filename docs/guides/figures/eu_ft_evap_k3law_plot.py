#!/usr/bin/env python3
"""Arbiter: ab-initio 3D condensate three-body decay vs the 0-D attractor law.

A pure GP condensate decays under K₃ only (closed field, no evaporation). The 0-D
model predicts dN₀/dt = −γ N₀^{9/5} (⟨n²⟩=8/21 n₀², n₀∝N₀^{2/5}), whose solution is
N₀(t) = [N₀(0)^{−4/5} + (4/5)γt]^{−5/4}. Overlaying that closed form (γ fit from the
linear N₀^{−4/5}-vs-t relation) on the ab-initio SGPE N₀(t) tests whether the 3D
condensate loss follows the 0-D law — if it does, the 0-D ~2× systematic is the
formation DYNAMICS, not the static three-body loss. Single axes, smooth.

Provenance:
- shows: ab-initio SGPE condensate N₀(t) under K₃-only decay vs the 0-D N₀^{9/5}
  attractor closed form — the same-physics arbiter for the 0-D three-body law
- referenced by: current-best result, not yet in a guide (issue #75 Approach A)
- supersedes: none

Usage: python3 eu_ft_evap_k3law_plot.py [eu_ft_evap_k3law.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_evap_k3law.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
t = np.atleast_1d(d["t_ms"])
N0 = np.atleast_1d(d["N0"])
slope = float(np.atleast_1d(d["slope_fit"])[0]) if "slope_fit" in d.dtype.names else float("nan")

# 0-D attractor: N0^{-4/5} is linear in t with slope (4/5)γ. Fit γ, build the curve.
y = N0 ** (-0.8)
A = np.vstack([t, np.ones_like(t)]).T
m, b = np.linalg.lstsq(A, y, rcond=None)[0]
tt = np.linspace(t.min(), t.max(), 400)
N0_attr = (b + m * tt) ** (-1.25)   # [N0(0)^{-4/5} + (4/5)γ t]^{-5/4}

fig, ax = plt.subplots(figsize=(7.0, 4.7))
ax.plot(*smooth(t, N0), "-", color="#1f6feb", lw=2.4, label=r"ab-initio SGPE $N_0(t)$ (3D, $K_3$-only)")
ax.plot(tt, N0_attr, "--", color="#d1242f", lw=1.8,
        label=r"0-D attractor $[N_0(0)^{-4/5}+\frac{4}{5}\gamma t]^{-5/4}$")
ax.annotate(fr"ab-initio $-\dot N_0 \propto N_0^{{{slope:.2f}}}$" + "\n(0-D law: $N_0^{9/5}$, exp 1.80)",
            xy=(0.5, 0.2), xycoords="axes fraction", fontsize=10, color="#333")
ax.set_xlabel("time [ms]")
ax.set_ylabel(r"condensate $N_0$")
ax.set_title("¹⁵¹Eu arbiter: the ab-initio 3D condensate three-body decay follows\n"
             "the 0-D $N_0^{9/5}$ law ⇒ the 0-D ~2× systematic is formation dynamics")
ax.legend(frameon=False, fontsize=9)
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, os.path.splitext(os.path.basename(csv))[0] + ".png")
fig.savefig(out, dpi=150)
print("wrote", out)
