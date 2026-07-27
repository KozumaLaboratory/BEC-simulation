#!/usr/bin/env python3
"""Plot the Eu box lever: ⟨n²⟩ vs box volume, vs the peaked harmonic profile.

A flat box holds uniform bulk density, so ⟨n²⟩ = (N/V)² is a free geometric
knob (slope -2 in V). At a matched footprint the uniform profile carries a
lower ⟨n²⟩ — hence lower 3-body loss rate — than the peaked harmonic condensate.

Usage: python3 eu_shape_box_lever_plot.py [eu_shape_box_lever.csv]

Provenance:
- shows: box <n^2> = (N/V)^2 geometric loss-rate lever vs the peaked harmonic profile at matched footprint (log-log, slope -2)
- referenced by: docs/guides/eu_shape_optimization.md
- supersedes: none
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_shape_box_lever.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
V = np.atleast_1d(d["V_phys_m3"])
n2 = np.atleast_1d(d["n2_phys_m6"])
nV2 = np.atleast_1d(d["nV2_ideal_m6"])

order = np.argsort(V)
V, n2, nV2 = V[order], n2[order], nV2[order]

# Harmonic ω=1 reference from the validation-gate CSV (TF footprint volume).
harm = None
vcsv = os.path.join(here, "eu_shape_validation.csv")
if os.path.exists(vcsv):
    dv = np.genfromtxt(vcsv, delimiter=",", names=True)
    i = int(np.argmin(np.abs(dv["omega"] - 1.0)))
    a_ho = 3.992e-7  # m (ω_ref = 2π·420 Hz)
    N = 1e4
    peak_psi2 = dv["peak_psi2"][i]        # |ψ|²_0 (norm-1)
    c0 = 4 * np.pi * (135 * 5.29177e-11 / a_ho) * N
    mu = c0 * peak_psi2                    # TF chem. potential (internal)
    R = np.sqrt(2 * mu)                    # TF radius (a_ho)
    V_harm = (4 / 3) * np.pi * R**3 * a_ho**3
    harm = (V_harm, dv["n2_phys_m6"][i])

# slope fit
m, b = np.polyfit(np.log(V), np.log(n2), 1)

fig, ax = plt.subplots(figsize=(6.6, 4.6))
xx = np.linspace(V.min() * 0.8, V.max() * 1.2, 100)
ax.loglog(*smooth(V, n2), "-", color="#1f6feb", lw=2.2, label="box GP ground state", zorder=3)
ax.loglog(V, nV2, "--", color="#8250df", lw=1.4, label=r"ideal uniform $(N/V)^2$")
if harm is not None:
    ax.loglog(harm[0], harm[1], "o", ms=13, color="#d1242f",
              label="harmonic ω=1 (peaked)", zorder=4)
    ax.annotate("same footprint,\nhigher ⟨n²⟩ (more loss)",
                xy=harm, xytext=(harm[0] * 1.9, harm[1] * 0.72),
                fontsize=8.5, color="#d1242f", va="top",
                arrowprops=dict(arrowstyle="->", color="#d1242f", lw=1.2))
ax.set_xlabel(r"cloud volume $V$ [m$^3$]")
ax.set_ylabel(r"$\langle n^2\rangle$ [m$^{-6}$]  (3-body loss rate $\propto$)")
ax.set_title(r"¹⁵¹Eu box lever: a flat box tunes $\langle n^2\rangle=(N/V)^2$ freely,"
             "\n"
             r"beating the peaked harmonic profile at matched footprint")
ax.legend(frameon=False, fontsize=9, loc="upper right")
ax.grid(True, which="both", alpha=0.25)
fig.tight_layout(rect=[0, 0, 1, 0.94])
out = os.path.join(here, "eu_shape_box_lever.png")
fig.savefig(out, dpi=150)
print("wrote", out)
