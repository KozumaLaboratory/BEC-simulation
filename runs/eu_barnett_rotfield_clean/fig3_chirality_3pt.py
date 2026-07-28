#!/usr/bin/env python3
"""SEMINAR FIG 3 (definitive chirality): FULL protocol, box+-10/n80.
All three runs (+Omega / Omega=0 / -Omega) start from the SAME transverse ground
state (F_z=0, |F|=6). During the stir (t=0..30, field on) F_z stays ~0 for all;
only at the quench (t>30, B=0) do they diverge: +Omega->+2.10, Omega=0->0,
-Omega->-0.42. Identical start -> divergence set purely by rotation sense = the
mechanical-Barnett chirality. Bottom |F|(t): all start at 6, -Omega (CW) loses |F|
fastest (F=6 high-spin dipolar chiral depolarisation; absent in Dy-scalar/Saito-F1)."""
import csv
import os
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = "runs/eu_barnett_rotfield_clean"
STIR_DUR = 30.0  # stir duration -> quench time shifted by this
RUNS = {
    "+O": ("rebuild_tsubame/traj_stir.csv", "rebuild_tsubame/traj_quench.csv", "#1f77b4", r"$+\Omega$"),
    "0": ("rebuild/traj_omega0_stir.csv", "rebuild/traj_omega0_quench.csv", "#555555", r"$\Omega=0$ (control)"),
    "-O": ("rebuild/traj_chir_stir.csv", "rebuild/traj_chir_quench.csv", "#d62728", r"$-\Omega$"),
}


def load(p):
    d = {k: [] for k in ["t", "Fz", "Fmag"]}
    for r in csv.DictReader(open(p)):
        for k in d:
            d[k].append(float(r[k]))
    return {k: np.array(v) for k, v in d.items()}


def full(stir_p, quench_p):
    s = load(f"{HERE}/{stir_p}")
    q = load(f"{HERE}/{quench_p}")
    # prepend GS point (t=0, F_z=0, |F|=6); stir then quench (time-shifted)
    t = np.concatenate([[0.0], s["t"], q["t"] + STIR_DUR])
    fz = np.concatenate([[0.0], s["Fz"], q["Fz"]])
    fm = np.concatenate([[6.0], s["Fmag"], q["Fmag"]])
    return t, fz, fm


fig, (axF, axM) = plt.subplots(2, 1, figsize=(9.0, 7.2), sharex=True,
                               gridspec_kw={"height_ratios": [1.35, 1], "hspace": 0.1})
ends = []
for key, (sp, qp, c, lbl) in RUNS.items():
    if not (os.path.exists(f"{HERE}/{sp}") and os.path.exists(f"{HERE}/{qp}")):
        continue
    t, fz, fm = full(sp, qp)
    fend = np.mean(fz[t >= t.max() - 10])
    axF.plot(t, fz, color=c, lw=2.1, label=f"{lbl}: $F_z\\to${fend:+.2f}")
    if key in ("+O", "-O"):
        axM.plot(t, fm, color=c, lw=2.1, label=f"{lbl}: $|F|\\to${np.mean(fm[t>=t.max()-10]):.2f}")
    else:
        axM.plot(t, fm, color=c, lw=1.6, ls="--", alpha=0.7, label=f"{lbl}")
    ends.append((lbl, fend))

for ax in (axF, axM):
    ax.axvspan(0, STIR_DUR, color="gold", alpha=0.08)
    ax.axvline(STIR_DUR, color="k", lw=0.8, ls="--", alpha=0.6)
axF.text(15, 2.7, "stir\n(field on,\nvortex forms)", ha="center", va="top", fontsize=8.5, color="#886600")
axF.text(55, 2.7, "quench (B=0): orbital $\\to$ spin", ha="center", va="top", fontsize=9, color="#333")
axF.axhline(0, color="k", lw=0.6, ls=":")
axF.set_ylabel(r"$\langle F_z\rangle\ [\hbar]$", fontsize=12)
axF.set_ylim(-0.9, 3.0)
axF.legend(loc="center left", fontsize=10, framealpha=0.9)
axF.set_title("Same transverse start ($F_z{=}0$) $\\to$ divergence set by rotation sense", fontsize=11.5)

axM.set_ylabel(r"$|F|\ [\hbar]$", fontsize=12)
axM.set_xlabel("time  $t\\ [\\omega_{\\rm ref}^{-1}]$  (stir 0–30, quench 30–80)", fontsize=11.5)
axM.set_ylim(0, 6.3)
axM.legend(loc="upper right", fontsize=9.5, framealpha=0.9)
axM.set_title("All start $|F|{=}6$; among $\\pm\\Omega$ the $-\\Omega$ (CW) depolarises more (F=6 chiral); $\\Omega{=}0$ = no-field baseline", fontsize=9.5)

fig.suptitle("Two-stage mechanical Barnett is rotation-driven (chirality) — $^{151}$Eu F=6",
             fontsize=12.5)
fig.tight_layout(rect=(0, 0, 1, 0.96))
out = f"{HERE}/figures/fig3_chirality_3pt.png"
fig.savefig(out, dpi=150)
print("wrote", out)
for lbl, f in ends:
    print(f"  {lbl}: Fz_end={f:+.2f}")
