#!/usr/bin/env python3
"""Refined harmonic decompression: condensate N₀ vs final trap ω_final (fast ramp).

A fine ω_final sweep at τ=0 pins the interior optimum of the finite-T trade-off:
loosening the trap cuts three-body loss, but over-loosening drops T_c ∝ ω̄ and melts
the condensate. Peak = the ODT decompression target that keeps the most BEC.
Linear axes.

Usage: python3 eu_ft_decompress_refine_plot.py [eu_ft_decompress_refine.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_decompress_refine.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
of = np.atleast_1d(d["omega_final"])
N0 = np.atleast_1d(d["N0"])
N0_hold = float(np.atleast_1d(d["N0_hold"])[0])
o = np.argsort(of)
of, N0 = of[o], N0[o]
imax = int(np.argmax(N0))

fig, ax = plt.subplots(figsize=(6.8, 4.6))
ax.plot(*smooth(of, N0), "-", color="#1f6feb", lw=2.2, label="decompress (fast, τ→0)")
ax.axhline(N0_hold, ls="--", color="#d1242f", lw=1.5, label=f"HOLD (no decompress) = {N0_hold:.0f}")
ax.plot(of[imax], N0[imax], "*", color="#2da44e", ms=20, mec="white", mew=0.8,
        label=fr"optimum $\omega_\mathrm{{final}}$={of[imax]:.2f}  (+{100*(N0[imax]/N0_hold-1):.0f}%)")
ax.set_xlabel(r"final trap $\omega_\mathrm{final}\,/\,\omega_\mathrm{form}$")
ax.set_ylabel(r"final condensate $N_0$")
ax.set_title("¹⁵¹Eu harmonic decompression — refined optimum (0-D-calibrated)\n"
             r"loosen to cut loss, but over-loosening melts the BEC ($T_c\propto\bar\omega$)")
ax.legend(frameon=False, fontsize=9.5)
ax.grid(True, alpha=0.25)
fig.tight_layout()
out = os.path.join(here, "eu_ft_decompress_refine.png")
fig.savefig(out, dpi=150)
print("wrote", out, "| optimum omega_final=%.2f N0=%.0f (+%.0f%%)" % (
    of[imax], N0[imax], 100 * (N0[imax] / N0_hold - 1)))
