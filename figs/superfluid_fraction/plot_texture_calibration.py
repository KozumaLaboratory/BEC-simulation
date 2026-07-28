#!/usr/bin/env python3
"""How wrong the density-only f_s is as a function of spin-direction texture.

`superfluid_fraction` reduces a spinor to its total density, so it answers only
the mass-flow question. Measured on a 1D spin-1 GP: the true mass-flow f_s comes
from a symmetric second difference of E(±q) under a twist applied to all three
components (immune to any spin current), against the density-only Leggett value
on the same converged state.

Two families of texture:
  cone     B = (b_perp cos kx, b_perp sin kx, b_z) — b_perp/b_z tunes the cone
           half-angle, giving a continuous handle on small spreads
  winding  B = (B cos kx, B sin kx, 0) — the direction always covers the full
           circle, so the spread is pinned near 1 whatever the field strength

Data inlined: figs/**/*.csv is gitignored (raw data on TSUBAME, repo keeps
figures + code).
"""
import pathlib

import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).parent

# spread, density-only / true mass-flow f_s
CONE = [
    (0.0000, 1.000), (0.0002, 1.000), (0.0010, 1.001), (0.0039, 1.003),
    (0.0153, 1.010), (0.0573, 1.040), (0.1835, 1.161),
]
WINDING = [
    (0.7980, 19.914), (1.0000, 9.930), (1.0000, 4.475),
    (1.0000, 2.655), (1.0000, 1.639),
]
THRESHOLD = 0.05

fig, ax = plt.subplots(figsize=(6.2, 4.2))
ax.axvspan(1e-4, THRESHOLD, color="#eaf1f7", zorder=0)
ax.text(1.2e-3, 3.2, "silent\n(≤ 4 % error)", fontsize=8.5, color="#1f4e79", ha="center")

cs, cr = zip(*[(max(s, 1e-4), r) for s, r in CONE])
ax.plot(cs, cr, "o-", color="#1f4e79", lw=1.6, ms=5.5, label="cone texture")
ws, wr = zip(*WINDING)
ax.plot(ws, wr, "s", color="#c0504d", ms=7, label="full winding (spread pinned ≈ 1)")

ax.axhline(1.0, color="0.7", lw=0.8, ls=":")
ax.axvline(THRESHOLD, color="#c0504d", lw=1.2, ls="--")
ax.text(THRESHOLD * 1.18, 1.25, f"warn above {THRESHOLD}", fontsize=8.5, color="#c0504d")
ax.set_xscale("log")
ax.set_yscale("log")
ax.set_xlabel(r"spin-direction spread   $1 - |\langle \hat n\rangle|$")
ax.set_ylabel("density-only $f_s$  /  true mass-flow $f_s$")
ax.set_title(
    "The density-only superfluid fraction under spin texture\n"
    "exact for a uniform direction, up to 20× high once it winds",
    fontsize=10,
)
ax.legend(frameon=False, fontsize=9, loc="upper left", bbox_to_anchor=(0.0, 1.0))
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
out = HERE / "texture_calibration.png"
fig.savefig(out, dpi=180)
print(f"wrote {out}")
