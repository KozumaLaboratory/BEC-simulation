#!/usr/bin/env python3
"""Harmonic decompression optimization: final condensate N₀ vs (ω_final, ramp τ).

The experimentally available lever is lowering the ODT power (harmonic
decompression) — no box needed. This heatmap of the finite-T, closed-ramp
condensate N₀ over (how far to decompress ω_final, how fast τ) at the
0-D-calibrated BEC-formation conditions gives the ODT ramp recipe that keeps the
most BEC. The star marks the optimum; the HOLD (no-decompress) baseline is noted.

Usage: python3 eu_ft_decompress_opt_plot.py [eu_ft_decompress_opt.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_decompress_opt.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
of = np.atleast_1d(d["omega_final"])
tau = np.atleast_1d(d["tau_ms"])
N0 = np.atleast_1d(d["N0"])
N0_hold = float(np.atleast_1d(d["N0_hold"])[0])

ofs = np.unique(of)
taus = np.unique(tau)
Z = np.full((len(ofs), len(taus)), np.nan)
for k in range(len(N0)):
    i = np.where(ofs == of[k])[0][0]
    j = np.where(taus == tau[k])[0][0]
    Z[i, j] = N0[k]

imax = int(np.nanargmax(N0))

fig, ax = plt.subplots(figsize=(7.2, 5.0))
im = ax.imshow(Z / N0_hold, origin="lower", aspect="auto", cmap="viridis",
               extent=[taus.min() - 0.5, taus.max() + 0.5, 0, len(ofs)])
ax.set_yticks(np.arange(len(ofs)) + 0.5)
ax.set_yticklabels([f"{o:.2f}" for o in ofs])
ax.set_xticks(taus)
ax.set_xticklabels([f"{t:.0f}" for t in taus])
# annotate each cell with N0
for i in range(len(ofs)):
    for j in range(len(taus)):
        if not np.isnan(Z[i, j]):
            ax.text(taus[j], i + 0.5, f"{Z[i, j]:.0f}", ha="center", va="center",
                    color="white", fontsize=8)
# optimum star
oi = np.where(ofs == of[imax])[0][0]
ax.plot(tau[imax], oi + 0.5, "*", color="#ff3860", ms=22, mec="white", mew=1.0)
ax.set_xlabel(r"ramp duration $\tau$ [ms]  (0 = sudden)")
ax.set_ylabel(r"final trap $\omega_\mathrm{final}/\omega_\mathrm{form}$")
ax.set_title("¹⁵¹Eu harmonic decompression recipe (0-D-calibrated)\n"
             fr"final condensate $N_0$ (colour = $N_0/N_0^\mathrm{{hold}}$; "
             fr"HOLD={N0_hold:.0f}); ★ = optimum")
cb = fig.colorbar(im, ax=ax)
cb.set_label(r"$N_0 / N_0^\mathrm{hold}$")
fig.tight_layout()
out = os.path.join(here, "eu_ft_decompress_opt.png")
fig.savefig(out, dpi=150)
print("wrote", out, "| optimum omega_final=%.2f tau=%.0fms N0=%.0f" % (of[imax], tau[imax], N0[imax]))
