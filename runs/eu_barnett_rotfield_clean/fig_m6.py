#!/usr/bin/env python3
"""Floor-rectification test: m=-6 axial + imprinted l=+1/-1/0 orbital vortex, quench B=0.
Does the vortex sign rectify at the F_z=-6 floor? Top: F_z(t). Middle: N_{-6} retention
(Stern-Gerlach). Bottom: N_{-5}+N_{-4} appearance. If anko's idea holds, one l keeps
F_z near -6 / N_{-6}~1 while the other moves up; the l=0 control shows the field-free
depolarisation baseline (how much moves up with NO vortex)."""
import csv
import os
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = "runs/eu_barnett_rotfield_clean"
RUNS = [
    ("ellp1", "$\\ell=+1$", "#1f77b4"),
    ("ellm1", "$\\ell=-1$", "#d62728"),
    ("ellp0", "$\\ell=0$ (control)", "#555555"),
]


def load(tag):
    p = f"{HERE}/rebuild/traj_m6_{tag}.csv"
    if not os.path.exists(p):
        return None
    d = {k: [] for k in ["t", "Fz", "Lz", "N_m6", "N_m5", "N_m4"]}
    for r in csv.DictReader(open(p)):
        for k in d:
            d[k].append(float(r[k]))
    return {k: np.array(v) for k, v in d.items()}


fig, ax = plt.subplots(3, 1, figsize=(8.6, 9.0), sharex=True,
                       gridspec_kw={"hspace": 0.12})
for tag, lbl, c in RUNS:
    d = load(tag)
    if d is None:
        continue
    ax[0].plot(d["t"], d["Fz"], color=c, lw=2.0, label=f"{lbl}: $F_z\\to${d['Fz'][-3:].mean():+.2f}")
    ax[1].plot(d["t"], d["N_m6"], color=c, lw=2.0, label=f"{lbl}: $N_{{-6}}\\to${d['N_m6'][-3:].mean():.2f}")
    ax[2].plot(d["t"], d["N_m5"] + d["N_m4"], color=c, lw=2.0, label=lbl)

ax[0].axhline(-6, color="k", lw=0.6, ls=":")
ax[0].set_ylabel(r"$\langle F_z\rangle\ [\hbar]$", fontsize=12)
ax[0].set_title("$F_z$ from the $-6$ floor (does the vortex sign rectify?)", fontsize=11.5)
ax[0].legend(fontsize=9.5, loc="lower right")

ax[1].set_ylabel(r"$N_{-6}/N$", fontsize=12)
ax[1].set_title("$m=-6$ retention (Stern–Gerlach)", fontsize=11.5)
ax[1].legend(fontsize=9.5, loc="upper right")

ax[2].set_ylabel(r"$(N_{-5}+N_{-4})/N$", fontsize=12)
ax[2].set_title("appearance of $m=-5,-4$ (the observable signal)", fontsize=11.5)
ax[2].set_xlabel("time  $t\\ [\\omega_{\\rm ref}^{-1}]$", fontsize=12)
ax[2].legend(fontsize=9.5, loc="upper left")

fig.suptitle("Floor-rectification test: $m=-6$ axial + $\\pm$vortex $\\to$ quench — $^{151}$Eu F=6",
             fontsize=12.5)
fig.tight_layout(rect=(0, 0, 1, 0.965))
out = f"{HERE}/figures/fig_m6_floor.png"
fig.savefig(out, dpi=150)
print("wrote", out)
for tag, lbl, _ in RUNS:
    d = load(tag)
    if d:
        print(f"  {lbl}: Fz_end={d['Fz'][-3:].mean():+.3f}  N_m6_end={d['N_m6'][-3:].mean():.3f}")
