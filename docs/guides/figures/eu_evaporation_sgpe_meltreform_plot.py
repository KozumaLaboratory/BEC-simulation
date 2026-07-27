#!/usr/bin/env python3
"""Melt-and-reform vs no-melt adiabatic dilution (closed post-formation SGPE).
Left:  the four ω̄(t) protocols. Right: condensate N₀(t) — does melting ever win?"""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "docs/guides/figures"
NAMES = ["ramp_only", "optimum", "melt_stay", "melt_reform"]
COL = {"ramp_only": "#7f7f7f", "optimum": "#1f77b4",
       "melt_stay": "#d62728", "melt_reform": "#9467bd"}
LAB = {"ramp_only": "ramp-only", "optimum": "optimum (no-melt, adiabatic)",
       "melt_stay": "melt & stay dilute", "melt_reform": "melt & reform (re-tighten)"}


def load(name):
    rows = list(csv.DictReader(open(f"{D}/eu_sgpe_meltreform_{name}.csv")))
    return (np.array([float(r["t_ms"]) for r in rows]),
            np.array([float(r["N"]) for r in rows]),
            np.array([float(r["N0"]) for r in rows]))


data = {n: load(n) for n in NAMES}
base = data["optimum"][2][-1]

fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.6, 5.2))

# left: reconstruct ω̄(τ) schedules from the melt-reform recipe constants
tref = data["optimum"][0]
tmax = tref[-1]
tau = np.clip((tref - tref[0]) / (tmax - tref[0]), 0, 1)
OM0, OLO, OHI, TD, TR = 0.876, 0.12, 0.35, 0.08, 0.70


def ramp_only_w(t):  # power-ramp: read from CSV proxy is hard; draw schematic from N later
    return None


ms = np.where(tau < TD, OM0 + (OLO - OM0) * (tau / TD), OLO)
mr = np.where(tau < TD, OM0 + (OLO - OM0) * (tau / TD),
              np.where(tau < TR, OLO, OLO + (OHI - OLO) * ((tau - TR) / (1 - TR))))
opt_w = np.interp(tau, [0, 1], [OM0, 0.131])   # schematic unified (0.876→0.131)
ax0.plot(tref, opt_w, "-", color=COL["optimum"], lw=2.6, label=LAB["optimum"])
ax0.plot(tref, ms, "-", color=COL["melt_stay"], lw=2.2, label=LAB["melt_stay"])
ax0.plot(tref, mr, "-", color=COL["melt_reform"], lw=2.2, label=LAB["melt_reform"])
ax0.set_xlabel("time  [ms]")
ax0.set_ylabel("trap tightness  $\\bar\\omega/\\bar\\omega_{\\rm form}$")
ax0.set_title("The four ω̄(t) schedules", fontsize=11)
ax0.legend(loc="upper right", fontsize=8.5)
ax0.set_ylim(bottom=0)

# right: N₀(t)
for n in NAMES:
    t, N, N0 = data[n]
    ax1.plot(t, N, "-", color=COL[n], lw=0.9, alpha=0.3)
    ax1.plot(t, N0, "-", color=COL[n], lw=2.4, label="%s: N₀=%.2e (%.2f×)" %
             (LAB[n], N0[-1], N0[-1] / base))
    ax1.plot(t[-1], N0[-1], "o", color=COL[n], ms=6)
ax1.text(0.03, 0.04,
         "post-formation: dump density FAST wins\n(less time dense ⇒ less 3-body ∝$n^2$);\nre-tightening ('reform') does NOT help.\nClosed model: no collisional re-thermalisation\n⇒ no 3! bunching penalty — real fast drop\nmust stay adiabatic; treat as upper bound.",
         transform=ax1.transAxes, fontsize=8.0, va="bottom",
         bbox=dict(boxstyle="round", fc="#fff8e8", ec="#d9a300", alpha=0.95))
ax1.set_xlabel("time  [ms]  (closed post-formation ramp)")
ax1.set_ylabel("condensate $N_0$   (thin = total $N$)")
ax1.set_title("Fast dilution vs gradual — and reform adds nothing", fontsize=11)
ax1.legend(loc="upper right", fontsize=8.2)
ax1.set_ylim(bottom=0)

fig.suptitle("Post-formation: dump density fast beats gradual; 'reform' is useless (closed SGPE, K₃)", fontsize=11.5, y=1.00)
fig.tight_layout()
import os
out = f"{D}/../../../figs/eu_evaporation_unified_smooth/eu_sgpe_meltreform.png" \
    if len(sys.argv) < 3 else sys.argv[2]
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
