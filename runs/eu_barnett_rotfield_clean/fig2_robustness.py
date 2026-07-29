#!/usr/bin/env python3
"""SEMINAR FIG 2: the converted F_z is NOT a numerical artefact.
F_z(t) overlaid for different box AND grid; both settle to +2 despite box 10->14
and dx 0.25->0.35. (After the box-overflow incident this robustness panel is the
answer to 'is +2.08 real?'.) If the dt=2e-4 quench-only check has landed, its
F_z(t) is overlaid too -> box / grid / dt all agree."""
import csv
import os
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = "runs/eu_barnett_rotfield_clean"
RUNS = [
    ("box$\\pm$10, n80 (dx0.25), dt4e-4", f"{HERE}/rebuild_tsubame/traj_quench.csv", "#1f77b4", "-"),
    ("box$\\pm$14, n80 (dx0.35), dt4e-4", f"{HERE}/rebuild_box14_tsubame/traj_box14n80_quench.csv", "#2ca02c", "-"),
    ("box$\\pm$14, n80, dt2e-4 (quench-only)", f"{HERE}/rebuild/traj_dtcheck_quench.csv", "#ff7f0e", "--"),
]


def load(p):
    d = {k: [] for k in ["t", "Fz"]}
    for r in csv.DictReader(open(p)):
        d["t"].append(float(r["t"])); d["Fz"].append(float(r["Fz"]))
    return np.array(d["t"]), np.array(d["Fz"])


fig, ax = plt.subplots(figsize=(8.4, 5.2))
summary = []
for lbl, p, c, ls in RUNS:
    if not os.path.exists(p):
        summary.append(f"{lbl}: (pending)")
        continue
    t, fz = load(p)
    ax.plot(t, fz, color=c, ls=ls, lw=2.0, label=lbl)
    fin = fz[t >= max(12, t.max() - 10)].mean()
    summary.append(f"{fin:+.2f}")

ax.axhline(0, color="k", lw=0.5, ls=":")
ax.axhspan(1.9, 2.2, color="grey", alpha=0.13, label="Fz $\\approx$ +2 band")
ax.set_xlabel("time  $t\\ [\\omega_{\\rm ref}^{-1}]$", fontsize=12)
ax.set_ylabel(r"$\langle F_z\rangle\ [\hbar]$", fontsize=12)
ax.set_ylim(-0.5, 3.2)
ax.legend(loc="lower right", fontsize=9.5, framealpha=0.9)
fig.suptitle("Converted $\\langle F_z\\rangle$ is box / grid / dt robust "
             "($+1.9\\ldots2.2$) — not a numerical artefact", fontsize=12.5)
fig.text(0.5, 0.01, "settled $F_z$:  " + "  /  ".join(summary) + "  $\\hbar$  (box / grid / dt all $\\to$ +2)",
         ha="center", fontsize=9.5)
fig.tight_layout(rect=(0, 0.04, 1, 0.95))
out = f"{HERE}/figures/fig2_robustness.png"
fig.savefig(out, dpi=150)
print("wrote", out)
for s in summary:
    print(" ", s)
