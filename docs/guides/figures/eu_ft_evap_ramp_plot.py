#!/usr/bin/env python3
"""Evaporation FORT-ramp optimization (0-D): baseline euv3 ramp vs Bayesian-optimized.

Left: total FORT power vs time (the recipe). Right: temperature and atom-number
trajectories. The optimizer reshapes the power ramp to reach BEC onset with more
condensate. Linear axes.

Usage: python3 eu_ft_evap_ramp_plot.py [prefix]  (reads <prefix>_{baseline,optimal}.csv)
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
prefix = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_evap_ramp")
b = np.genfromtxt(prefix + "_baseline.csv", delimiter=",", names=True)
o = np.genfromtxt(prefix + "_optimal.csv", delimiter=",", names=True)

fig, (axP, axNT) = plt.subplots(1, 2, figsize=(11, 4.4))

axP.plot(b["t_s"], b["power_W"], "-", color="#8a8a8a", lw=2, label="baseline euv3 ramp")
axP.plot(o["t_s"], o["power_W"], "-", color="#1f6feb", lw=2.2, label="optimized ramp")
axP.set_xlabel("time [s]")
axP.set_ylabel("total FORT power [W]")
axP.set_title("the FORT power schedule (recipe)")
axP.legend(frameon=False, fontsize=9)
axP.grid(True, alpha=0.25)

axNT.plot(b["t_s"], b["T_uK"], "-", color="#8a8a8a", lw=1.8, label="T baseline")
axNT.plot(o["t_s"], o["T_uK"], "-", color="#d1242f", lw=2, label="T optimized")
axNT.set_xlabel("time [s]")
axNT.set_ylabel("temperature [µK]", color="#d1242f")
axNT.tick_params(axis="y", labelcolor="#d1242f")
axNT.set_title("cooling trajectory (T and N)")
axNT.grid(True, alpha=0.25)
axN = axNT.twinx()
axN.plot(b["t_s"], b["N"], "--", color="#999", lw=1.5, label="N baseline")
axN.plot(o["t_s"], o["N"], "--", color="#1f6feb", lw=1.8, label="N optimized")
axN.set_ylabel("atom number N", color="#1f6feb")
axN.tick_params(axis="y", labelcolor="#1f6feb")
axN.set_yscale("log")

l1, la1 = axNT.get_legend_handles_labels()
l2, la2 = axN.get_legend_handles_labels()
axNT.legend(l1 + l2, la1 + la2, frameon=False, fontsize=8, loc="upper right")

fig.suptitle("¹⁵¹Eu evaporation FORT-ramp optimization (0-D two-component model)", fontsize=11)
fig.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(here, "eu_ft_evap_ramp.png")
fig.savefig(out, dpi=150)
print("wrote", out)
