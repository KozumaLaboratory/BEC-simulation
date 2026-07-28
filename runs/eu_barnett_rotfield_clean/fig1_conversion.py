#!/usr/bin/env python3
"""SEMINAR FIG 1 (headline): mechanical Barnett orbital->spin conversion.
Two-stage quench (box+-10/n80, +Omega). Vortex orbital AM L_z is released and a
real net axial spin magnetisation F_z rises in the SAME time window -> direct
visualisation of orbital -> spin conversion (Saito mechanism, in a trap)."""
import csv
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = "runs/eu_barnett_rotfield_clean"
SRC = f"{HERE}/rebuild_tsubame/traj_quench.csv"   # box+-10/n80 +Omega headline

d = {k: [] for k in ["t", "Fz", "Fmag", "Lz", "Jz", "edge_frac"]}
for r in csv.DictReader(open(SRC)):
    for k in d:
        d[k].append(float(r[k]))
d = {k: np.array(v) for k, v in d.items()}

fig, (axL, axF) = plt.subplots(2, 1, figsize=(8.4, 6.4), sharex=True,
                               gridspec_kw={"height_ratios": [1, 1], "hspace": 0.08})
CL, CF = "#1f77b4", "#d62728"

axL.plot(d["t"], d["Lz"], color=CL, lw=2.3)
axL.set_ylabel(r"$\langle L_z\rangle\ [\hbar]$", color=CL, fontsize=12)
axL.tick_params(axis="y", labelcolor=CL)
axL.set_ylim(0, 12)
axL.annotate(f"vortex orbital AM released\n{d['Lz'][0]:.1f} $\\to$ {d['Lz'][-1]:.1f}",
             xy=(50, d["Lz"][-1]), xytext=(28, 9.3), color=CL, fontsize=11, ha="left")
axL.axhline(0, color="k", lw=0.4, ls=":")

axF.plot(d["t"], d["Fz"], color=CF, lw=2.3)
axF.set_ylabel(r"$\langle F_z\rangle\ [\hbar]$", color=CF, fontsize=12)
axF.tick_params(axis="y", labelcolor=CF)
axF.set_ylim(-0.4, 3.4)
axF.axhline(0, color="k", lw=0.4, ls=":")
axF.set_xlabel("time  $t\\ [\\omega_{\\rm ref}^{-1}]$", fontsize=12)
axF.annotate(f"axial spin magnetisation appears\n{d['Fz'][0]:.2f} $\\to$ +{d['Fz'][-5:].mean():.2f}"
             f"  ($F_z/|F|={d['Fz'][-5:].mean()/d['Fmag'][-5:].mean():.2f}$, fully axial)",
             xy=(50, d["Fz"][-1]), xytext=(20, 0.65), color=CF, fontsize=11, ha="left")

fig.suptitle("Mechanical Barnett effect in a trapped $^{151}$Eu spinor-dipolar BEC\n"
             "vortex orbital angular momentum $\\to$ axial spin magnetisation (same time window)",
             fontsize=12.5)
fig.tight_layout(rect=(0, 0, 1, 0.93))
out = f"{HERE}/figures/fig1_conversion.png"
fig.savefig(out, dpi=150)
print("wrote", out)
print(f"Lz {d['Lz'][0]:.2f}->{d['Lz'][-1]:.2f}   Fz {d['Fz'][0]:.2f}->{d['Fz'][-5:].mean():.2f}   "
      f"Fz/|F| end = {d['Fz'][-5:].mean()/d['Fmag'][-5:].mean():.2f} (axiality)   edge_end {d['edge_frac'][-1]:.3f}")
