#!/usr/bin/env python3
"""Finite-T shape result: condensate N₀(t) for HOLD vs DECOMPRESS vs BOX.

A finite-T state is prepared by Stoof-SGPE (bath on) in the tight trap, then the
trap shape is changed as a CLOSED system (bath off, K₃ loss on). The gas cools
adiabatically as it expands (T/T_c preserved), so expansion keeps the condensate
while cutting three-body loss — the finite-T confirmation of the T=0 shape levers.

Usage: python3 eu_ft_shape_plot.py [prefix]   (reads <prefix>_{hold,decompress,box}.csv)
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
prefix = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_shape")
colors = {"hold": "#d1242f", "decompress": "#1f6feb",
          "box_sudden": "#2da44e", "box_adiabatic": "#8250df"}
labels = {"hold": "hold", "decompress": "decompress",
          "box_sudden": "box (sudden)", "box_adiabatic": "box (adiabatic)"}

fig, (axN0, axN) = plt.subplots(1, 2, figsize=(10.5, 4.4))
finals = {}
for name in ("hold", "decompress", "box_sudden", "box_adiabatic"):
    path = f"{prefix}_{name}.csv"
    if not os.path.exists(path):
        continue
    d = np.genfromtxt(path, delimiter=",", names=True)
    t, N, N0 = d["t_ms"], d["N"], d["N0"]
    axN0.plot(*smooth(t, N0), "-", color=colors[name], ms=4, label=labels[name])
    axN.plot(*smooth(t, N), "-", color=colors[name], ms=4, label=labels[name])
    finals[name] = (N0[-1], N[-1])

axN0.set_xlabel("time [ms]")
axN0.set_ylabel(r"condensate $N_0$")
axN0.set_title("condensate number vs time")
axN0.legend(frameon=False, fontsize=9)
axN0.grid(True, alpha=0.25)

axN.set_xlabel("time [ms]")
axN.set_ylabel("total $N$")
axN.set_title("total atom number vs time")
axN.legend(frameon=False, fontsize=9)
axN.grid(True, alpha=0.25)

sub = "  ".join(f"{labels[k]}: N₀={v[0]:.0f}" for k, v in finals.items())
fig.suptitle("¹⁵¹Eu finite-T trap-shape trade-off (prep SGPE → closed ramp + K₃ loss)\n"
             "adiabaticity dominates: a SUDDEN box shatters the BEC, a gradual (adiabatic) box\n"
             "preserves it; gradual decompression is the robust winner.  " + sub, fontsize=9)
fig.tight_layout(rect=[0, 0, 1, 0.92])
out = prefix + ".png"
fig.savefig(out, dpi=150)
print("wrote", out)
