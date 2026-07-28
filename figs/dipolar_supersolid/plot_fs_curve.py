#!/usr/bin/env python3
"""f_s(eps_dd) for the dipolar supersolid tube, vs Roccuzzo & Ancilotto 2019 Fig. 2.

Data: figs/dipolar_supersolid/fs_curve.csv, produced by relaxing BOTH the uniform
and the modulated branch to convergence at each eps_dd (166Er, N=6e4,
omega_perp=2pi*600 Hz, L=15.873 um, 160x32x32, dx=0.0992 um). The ground state is
whichever branch has the lower total energy.
"""
import pathlib

import matplotlib.pyplot as plt

# Result table, inlined: figs/**/*.csv is gitignored (raw data lives on
# TSUBAME; the repo keeps figures + code). These are the numbers quoted in
# docs/validation/superfluidity_knowledge_state.md, small enough to carry here
# so the figure stays reproducible from the repo alone.
HERE = pathlib.Path(__file__).parent

ROWS = [
    {'eps_dd': 1.2, 'fs_gs': 0.9999999999999986, 'contrast_gs': 0.0, 'E_gs': 5.114738019879857, 'E_unif': 5.114738019879857, 'E_mod': 5.114738019880953, 'fs_mod': 0.9999999999999999},
    {'eps_dd': 1.28, 'fs_gs': 1.0000000000000002, 'contrast_gs': 0.0, 'E_gs': 4.940171994789573, 'E_unif': 4.940171994789573, 'E_mod': 4.940171994788093, 'fs_mod': 1.0000000000000002},
    {'eps_dd': 1.34, 'fs_gs': 1.0000000000000009, 'contrast_gs': 0.0, 'E_gs': 4.809801110556026, 'E_unif': 4.809801110556026, 'E_mod': 4.809801110562185, 'fs_mod': 0.9999999999655321},
    {'eps_dd': 1.38, 'fs_gs': 1.0, 'contrast_gs': 0.0, 'E_gs': 4.721347685814519, 'E_unif': 4.721347685814519, 'E_mod': 4.721347766873318, 'fs_mod': 0.9999992816766634},
    {'eps_dd': 1.41, 'fs_gs': 1.0000000000000004, 'contrast_gs': 0.0, 'E_gs': 4.653368104822327, 'E_unif': 4.653368104822327, 'E_mod': 4.653448708586028, 'fs_mod': 0.9978144155716043},
    {'eps_dd': 1.44, 'fs_gs': 0.7330450297161005, 'contrast_gs': 0.6641675011323336, 'E_gs': 4.576487831288337, 'E_unif': 4.583380731625768, 'E_mod': 4.576487831288337, 'fs_mod': 0.7330450297161005},
    {'eps_dd': 1.48, 'fs_gs': 0.3088964931375516, 'contrast_gs': 0.9264329942795445, 'E_gs': 4.406142184771045, 'E_unif': 4.486051049763191, 'E_mod': 4.406142184771045, 'fs_mod': 0.3088964931375516},
    {'eps_dd': 1.53, 'fs_gs': 0.0892233311436914, 'contrast_gs': 0.9869501853722835, 'E_gs': 4.074116655251971, 'E_unif': 4.356828063513277, 'E_mod': 4.074116655251971, 'fs_mod': 0.0892233311436914},
    {'eps_dd': 1.58, 'fs_gs': 0.021855778538053965, 'contrast_gs': 0.9977983624790745, 'E_gs': 3.6095855459555466, 'E_unif': 4.219398307088166, 'E_mod': 3.6095855459555466, 'fs_mod': 0.021855778538053965},
    {'eps_dd': 1.65, 'fs_gs': 0.0023634683478377205, 'contrast_gs': 0.9998536447308183, 'E_gs': 2.7477279234469556, 'E_unif': 4.017250681409287, 'E_mod': 2.7477279234469556, 'fs_mod': 0.0023634683478377205},
]
eps = [float(r["eps_dd"]) for r in ROWS]
fs_gs = [float(r["fs_gs"]) for r in ROWS]
contrast = [float(r["contrast_gs"]) for r in ROWS]
dE = [float(r["E_mod"]) - float(r["E_unif"]) for r in ROWS]

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
