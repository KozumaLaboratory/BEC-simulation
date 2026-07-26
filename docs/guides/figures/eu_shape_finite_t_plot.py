#!/usr/bin/env python3
"""Plot the finite-T shape trade-off: condensate N₀(t) and total N(t) for HOLD
vs DECOMPRESS under Stoof-SGPE at controlled T.

Linear axes (atom number over time). Reads two CSVs (hold, decompress) with
columns t_ms,N,N0.

Usage: python3 eu_shape_finite_t_plot.py hold.csv decompress.csv
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
hold_csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_shape_ft_hold.csv")
dec_csv = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "eu_shape_ft_decompress.csv")

h = np.genfromtxt(hold_csv, delimiter=",", names=True)
d = np.genfromtxt(dec_csv, delimiter=",", names=True)

fig, (axN, axf) = plt.subplots(1, 2, figsize=(10.5, 4.4))

axN.plot(h["t_ms"], h["N0"], "-o", color="#d1242f", ms=5, label="HOLD  condensate N₀")
axN.plot(d["t_ms"], d["N0"], "-o", color="#1f6feb", ms=5, label="DECOMPRESS  condensate N₀")
axN.plot(h["t_ms"], h["N"], "--", color="#d1242f", lw=1.2, alpha=0.6, label="HOLD  total N")
axN.plot(d["t_ms"], d["N"], "--", color="#1f6feb", lw=1.2, alpha=0.6, label="DECOMPRESS  total N")
axN.set_xlabel("time [ms]")
axN.set_ylabel("atom number")
axN.set_title("condensate N₀ and total N vs time")
axN.legend(frameon=False, fontsize=8.5)
axN.grid(True, alpha=0.25)

axf.plot(h["t_ms"], h["N0"] / np.maximum(h["N"], 1), "-o", color="#d1242f", ms=5, label="HOLD")
axf.plot(d["t_ms"], d["N0"] / np.maximum(d["N"], 1), "-o", color="#1f6feb", ms=5, label="DECOMPRESS")
axf.set_xlabel("time [ms]")
axf.set_ylabel(r"condensate fraction $N_0/N$")
axf.set_title(r"condensate fraction (T_c $\propto \bar\omega$ competes with loss)")
axf.legend(frameon=False, fontsize=9)
axf.grid(True, alpha=0.25)

fig.suptitle(r"¹⁵¹Eu finite-T trap-shape trade-off (Stoof-SGPE): "
             r"expansion cuts 3-body loss but lowers $T_c$", fontsize=11)
fig.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(here, "eu_shape_finite_t.png")
fig.savefig(out, dpi=150)
print("wrote", out)
