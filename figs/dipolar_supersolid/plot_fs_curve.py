#!/usr/bin/env python3
"""f_s(eps_dd) for the dipolar supersolid tube, vs Roccuzzo & Ancilotto 2019 Fig. 2.

Data: figs/dipolar_supersolid/fs_curve.csv, produced by relaxing BOTH the uniform
and the modulated branch to convergence at each eps_dd (166Er, N=6e4,
omega_perp=2pi*600 Hz, L=15.873 um, 160x32x32, dx=0.0992 um). The ground state is
whichever branch has the lower total energy.
"""
import csv
import pathlib

import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).parent
rows = list(csv.DictReader((HERE / "fs_curve.csv").open()))
eps = [float(r["eps_dd"]) for r in rows]
fs_gs = [float(r["fs_gs"]) for r in rows]
contrast = [float(r["contrast_gs"]) for r in rows]
dE = [float(r["E_mod"]) - float(r["E_unif"]) for r in rows]

fig, (ax, ax2) = plt.subplots(
    2, 1, figsize=(6.2, 6.4), sharex=True, gridspec_kw={"height_ratios": [2, 1]}
)

# Ground-state f_s. Smooth curve (simulation), with the transition marked.
ax.plot(eps, fs_gs, "-", color="#1f4e79", lw=2.0, label=r"$f_s$ (ground state)")
ax.plot(eps, contrast, "--", color="#c0504d", lw=1.6, label="density contrast")
# The transition is bracketed, not resolved: mark the bracket, not a point.
ax.axvspan(1.41, 1.44, color="0.85", zorder=0)
ax.text(1.425, 0.52, "transition\n(bracketed)", ha="center", va="center", fontsize=8.5)
ax.axhline(1.0, color="0.7", lw=0.8, ls=":")
ax.set_ylabel(r"$f_s$   /   contrast")
ax.set_ylim(-0.04, 1.08)
ax.legend(frameon=False, loc="center left", fontsize=9)
ax.set_title(
    r"Dipolar supersolid in a periodic tube ($^{166}$Er, $N=6\times10^4$)"
    "\n"
    r"paper: transition at $\epsilon_{dd}\approx1.40$, $f_s$ jumps then $\to0$",
    fontsize=10,
)

# Which branch wins. Sign of dE is the statement; log scale for the magnitude.
ax2.axhline(0.0, color="0.7", lw=0.8)
ax2.plot(eps, dE, "-", color="#4f6228", lw=1.8)
# Below ~1e-6 the modulated seed has relaxed onto the uniform state to
# round-off, so that band is numerically zero, not a small energy difference.
ax2.set_yscale("symlog", linthresh=1e-6)
ax2.set_yticks([-1e0, -1e-2, 0, 1e-2])
ax2.set_xlabel(r"$\epsilon_{dd} = a_{dd}/a_s$")
ax2.set_ylabel(r"$E_{\rm mod}-E_{\rm unif}$")
ax2.axvspan(1.41, 1.44, color="0.85", zorder=0)
ax2.text(1.215, 2e-4, "uniform lower", fontsize=8.5, color="0.35")
ax2.text(1.50, -3e-1, "modulated lower", fontsize=8.5, color="0.35")

for a in (ax, ax2):
    a.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
out = HERE / "fs_curve.png"
fig.savefig(out, dpi=180)
print(f"wrote {out}")
