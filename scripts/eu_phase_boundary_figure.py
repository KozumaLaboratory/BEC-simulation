#!/usr/bin/env python3
"""Physical-Eu (c1=+1/36) cyclic↔FM boundary B_c(κ) with a drawn line.

    python scripts/eu_phase_boundary_figure.py <coarse.csv> <boundary.csv> [out.png]

Coarse cells give the region background; the fine boundary points (searched only
inside each κ's transition bracket) locate B_c(κ) as the cyclic→FM crossing per
κ, which is drawn as a line — the thing a blocky 8×5 grid cannot resolve.
"""
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

coarse_csv = sys.argv[1]
bnd_csv = sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else "phase_boundary.png"

co = pd.read_csv(coarse_csv)
bd = pd.read_csv(bnd_csv)

# physical-Eu column = largest c1
c1 = co.c1_ratio.max()
co = co[np.isclose(co.c1_ratio, c1)].copy()
bd = bd[np.isclose(bd.c1_ratio, c1)].copy()

def is_fm(phase):
    # cyclic → 0 (weak-field side); ferromagnetic / mixed → 1 (polarised side)
    return 0 if str(phase).startswith("cyclic") else 1

# B_c(κ): per κ, sort fine points by B, midpoint between last-cyclic and first-FM.
bcs = []
for k, sub in bd.groupby("kappa"):
    sub = sub.sort_values("B_uG")
    f = sub.assign(fm=sub.phase.map(is_fm))
    cyc = f[f.fm == 0].B_uG
    fm = f[f.fm == 1].B_uG
    if len(cyc) and len(fm) and cyc.max() < fm.min():
        bc = 0.5 * (cyc.max() + fm.min())
    elif len(fm) and not len(cyc):
        bc = fm.min()          # boundary at/below the probed window
    elif len(cyc) and not len(fm):
        bc = cyc.max()         # boundary at/above the probed window
    else:
        continue
    bcs.append((k, bc))
bcs.sort()

fig, ax = plt.subplots(figsize=(7, 5.5))

# coarse region background as colored cells
phases = sorted(set(co.phase.astype(str)) | set(bd.phase.astype(str)))
cmap = {p: plt.cm.Set2(i) for i, p in enumerate(phases)}
for _, r in co.iterrows():
    ax.add_patch(plt.Rectangle((r.B_uG - 6, r.kappa - 0.15), 12, 0.30,
                               color=cmap[str(r.phase)], alpha=0.35, lw=0))
# fine boundary points
for _, r in bd.iterrows():
    ax.scatter(r.B_uG, r.kappa, c=[cmap[str(r.phase)]], s=70,
               edgecolors="k", linewidths=0.6, zorder=3)
# B_c(κ) line
if bcs:
    ks = [k for k, _ in bcs]
    bb = [b for _, b in bcs]
    ax.plot(bb, ks, "-o", color="crimson", lw=2.4, ms=7, zorder=4,
            label=r"$B_c(\kappa)$ cyclic$\to$FM")

handles = [plt.Line2D([], [], marker="s", ls="", mfc=cmap[p], mec="k", ms=10,
                      label=p) for p in phases]
if bcs:
    handles.append(plt.Line2D([], [], color="crimson", lw=2.4, marker="o",
                              label=r"$B_c(\kappa)$"))
ax.legend(handles=handles, loc="upper left", framealpha=0.9)
ax.set_xlabel("B (µG)")
ax.set_ylabel(r"$\kappa=\omega_z/\omega_r$ (oblateness)")
ax.set_title(rf"$^{{151}}$Eu F=6 GS: cyclic$\to$FM boundary at $c_1={c1:.4f}$ (64³)")
ax.set_xlim(0, max(105, float(bd.B_uG.max()) + 12))
fig.tight_layout()
fig.savefig(out, dpi=150)
print("wrote", out)
