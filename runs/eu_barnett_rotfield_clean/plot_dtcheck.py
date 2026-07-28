#!/usr/bin/env python3
"""dt-convergence of the residual Jz (box+-14/n80): dt=4e-4 vs dt=2e-4.
If Jz(t) is ~dt-independent -> the residual is NOT time-discretisation (it is the
spatial-grid texture of the decaying vortices) -> numeric, finer dx would reduce
it -> efficiency ~ pure conversion. If dt-dependent -> time-discretisation, still
numeric. Either way: not physical dissipation. Fz(t) should be dt-robust (the
conversion headline must not move)."""
import csv
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = "runs/eu_barnett_rotfield_clean"
DT4 = f"{HERE}/rebuild_box14_tsubame/traj_box14n80_quench.csv"   # dt=4e-4 reference
DT2 = f"{HERE}/rebuild/traj_dtcheck_quench.csv"                  # dt=2e-4 (this run)


def load(p):
    d = {k: [] for k in ["t", "Fz", "Fmag", "Lz", "Jz", "edge_frac"]}
    for r in csv.DictReader(open(p)):
        for k in d:
            d[k].append(float(r[k]))
    return {k: np.array(v) for k, v in d.items()}


a = load(DT4)
b = load(DT2)


def tm(d, k, t0=12.0):
    m = d["t"] >= t0
    return float(np.mean(d[k][m]))


fig, ax = plt.subplots(1, 3, figsize=(14, 4.5))
C4, C2 = "#1f77b4", "#ff7f0e"

ax[0].plot(a["t"], a["Jz"], C4, label="dt=4e-4")
ax[0].plot(b["t"], b["Jz"], C2, label="dt=2e-4")
ax[0].axhline(0, color="k", lw=0.5)
ax[0].set_title("residual $J_z=L_z+F_z$  (dt-convergence)")
ax[0].set_xlabel("t"); ax[0].set_ylabel("$J_z$"); ax[0].legend()

ax[1].plot(a["t"], a["Fz"], C4, label="dt=4e-4")
ax[1].plot(b["t"], b["Fz"], C2, label="dt=2e-4")
ax[1].axhline(0, color="k", lw=0.5)
ax[1].set_title("$F_z$ conversion (must be dt-robust)")
ax[1].set_xlabel("t"); ax[1].set_ylabel("$F_z$"); ax[1].legend()

ax[2].plot(a["t"], a["Lz"], C4, label="dt=4e-4")
ax[2].plot(b["t"], b["Lz"], C2, label="dt=2e-4")
ax[2].set_title("$L_z$ orbital")
ax[2].set_xlabel("t"); ax[2].set_ylabel("$L_z$"); ax[2].legend()

txt = (
    f"time-mean t>=12:   Jz: dt4 {tm(a,'Jz'):+.3f}  dt2 {tm(b,'Jz'):+.3f}  (dJz {tm(a,'Jz')-tm(b,'Jz'):+.3f})   "
    f"|   Fz: dt4 {tm(a,'Fz'):+.3f}  dt2 {tm(b,'Fz'):+.3f}  (dFz {tm(a,'Fz')-tm(b,'Fz'):+.3f})   "
    f"|   Lz: dt4 {tm(a,'Lz'):+.3f}  dt2 {tm(b,'Lz'):+.3f}"
)
fig.suptitle("Residual-$J_z$ dt-convergence (box$\\pm$14, n80, +$\\Omega$)  —  numeric vs physical-dissipation",
             fontsize=12)
fig.text(0.5, 0.01, txt, ha="center", family="monospace", fontsize=8.5)
fig.tight_layout(rect=(0, 0.06, 1, 0.95))
out = f"{HERE}/figures/dtcheck.png"
fig.savefig(out, dpi=130)
print("wrote", out)
print(txt)
