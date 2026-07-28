#!/usr/bin/env python3
"""Droplet count is the energy minimum, not just the noise-selected attractor.

Each point is a converged ITP run with the period imposed at L/n_d (166Er tube,
160x32x32). Roccuzzo & Ancilotto report 11 droplets at eps_dd = 1.45; the
reference itself says it cannot exclude a metastable state, so this scan checks
that 11 is the minimum in droplet NUMBER too. Repeating at eps_dd = 1.55 turns
it from a single check into a prediction: the preferred count DROPS as the
droplets become more isolated.
"""
import pathlib

import matplotlib.pyplot as plt

# Result table, inlined: figs/**/*.csv is gitignored (raw data lives on
# TSUBAME; the repo keeps figures + code). These are the numbers quoted in
# docs/validation/superfluidity_knowledge_state.md, small enough to carry here
# so the figure stays reproducible from the repo alone.
HERE = pathlib.Path(__file__).parent

ROWS = [
    {'eps_dd': 1.45, 'n_d': 8.0, 'd_um': 1.984, 'E': 4.558257, 'contrast': 0.4738, 'f_s': 0.87, 'peaks': 8.0, 'dE_vs_min': 0.01642400000000066},
    {'eps_dd': 1.45, 'n_d': 9.0, 'd_um': 1.764, 'E': 4.549723, 'contrast': 0.7202, 'f_s': 0.669, 'peaks': 9.0, 'dE_vs_min': 0.007890000000000619},
    {'eps_dd': 1.45, 'n_d': 10.0, 'd_um': 1.587, 'E': 4.543068, 'contrast': 0.7718, 'f_s': 0.5951, 'peaks': 10.0, 'dE_vs_min': 0.0012350000000003192},
    {'eps_dd': 1.45, 'n_d': 11.0, 'd_um': 1.443, 'E': 4.541833, 'contrast': 0.778, 'f_s': 0.5983, 'peaks': 11.0, 'dE_vs_min': 0.0},
    {'eps_dd': 1.45, 'n_d': 12.0, 'd_um': 1.323, 'E': 4.545121, 'contrast': 0.7397, 'f_s': 0.6484, 'peaks': 12.0, 'dE_vs_min': 0.0032880000000004017},
    {'eps_dd': 1.45, 'n_d': 13.0, 'd_um': 1.221, 'E': 4.550739, 'contrast': 0.6667, 'f_s': 0.7313, 'peaks': 13.0, 'dE_vs_min': 0.008906000000000525},
    {'eps_dd': 1.45, 'n_d': 14.0, 'd_um': 1.134, 'E': 4.556267, 'contrast': 0.5362, 'f_s': 0.8385, 'peaks': 14.0, 'dE_vs_min': 0.014434000000000502},
    {'eps_dd': 1.55, 'n_d': 8.0, 'd_um': 1.984, 'E': 3.891404, 'contrast': 0.9946, 'f_s': 0.0375, 'peaks': 8.0, 'dE_vs_min': 0.01622900000000005},
    {'eps_dd': 1.55, 'n_d': 9.0, 'd_um': 1.764, 'E': 3.875175, 'contrast': 0.9961, 'f_s': 0.0326, 'peaks': 9.0, 'dE_vs_min': 0.0},
    {'eps_dd': 1.55, 'n_d': 10.0, 'd_um': 1.587, 'E': 3.881457, 'contrast': 0.9949, 'f_s': 0.0386, 'peaks': 10.0, 'dE_vs_min': 0.006282000000000121},
    {'eps_dd': 1.55, 'n_d': 11.0, 'd_um': 1.443, 'E': 3.904118, 'contrast': 0.9935, 'f_s': 0.0519, 'peaks': 11.0, 'dE_vs_min': 0.02894299999999994},
    {'eps_dd': 1.55, 'n_d': 12.0, 'd_um': 1.323, 'E': 3.937981, 'contrast': 0.99, 'f_s': 0.0727, 'peaks': 12.0, 'dE_vs_min': 0.06280600000000014},
    {'eps_dd': 1.55, 'n_d': 13.0, 'd_um': 1.221, 'E': 3.979274, 'contrast': 0.9844, 'f_s': 0.1026, 'peaks': 13.0, 'dE_vs_min': 0.10409900000000016},
    {'eps_dd': 1.55, 'n_d': 14.0, 'd_um': 1.134, 'E': 4.02498, 'contrast': 0.9761, 'f_s': 0.1431, 'peaks': 14.0, 'dE_vs_min': 0.1498050000000002},
]
eps_values = sorted({r["eps_dd"] for r in ROWS})
COLOR = {1.45: "#1f4e79", 1.55: "#c0504d"}

fig, (ax, ax2) = plt.subplots(
    2, 1, figsize=(6.2, 5.8), sharex=True, gridspec_kw={"height_ratios": [3, 2]}
)

for eps in eps_values:
    sub = sorted((r for r in ROWS if r["eps_dd"] == eps), key=lambda r: r["n_d"])
    nd = [r["n_d"] for r in sub]
    dE = [r["dE_vs_min"] * 1e3 for r in sub]
    best = min(sub, key=lambda r: r["E"])
    c = COLOR.get(eps, "0.3")
    # Markers joined by lines: n_d is an integer and each point is its own run.
    ax.plot(nd, dE, "o-", color=c, lw=1.6, ms=5.5,
            label=rf"$\epsilon_{{dd}}$ = {eps:.2f}   (min $n_d$ = {int(best['n_d'])})")
    ax.plot([best["n_d"]], [0.0], "o", ms=13, mfc="none", mec=c, mew=2.2)
    ax2.plot(nd, [r["f_s"] for r in sub], "s-", color=c, lw=1.5, ms=4.5)

ax.axhline(0.0, color="0.75", lw=0.8, ls=":")
ax.set_ylabel(r"$E - E_{\min}$   [$10^{-3}\,\hbar\omega$]")
ax.legend(frameon=False, fontsize=9)
ax.set_title(
    r"Imposed droplet count vs energy ($^{166}$Er tube, $L = 15.873\ \mu$m)"
    "\n"
    r"paper: 11 droplets at $\epsilon_{dd} = 1.45$",
    fontsize=10,
)
ax2.set_xlabel(r"imposed droplet count $n_d$   ($d = L/n_d$)")
ax2.set_ylabel(r"$f_s$")
ax2.set_yscale("log")

for a in (ax, ax2):
    a.spines[["top", "right"]].set_visible(False)
    a.set_xticks(sorted({int(r["n_d"]) for r in ROWS}))
fig.tight_layout()
out = HERE / "period_scan.png"
fig.savefig(out, dpi=180)
print(f"wrote {out}")
