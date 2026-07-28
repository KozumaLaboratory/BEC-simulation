#!/usr/bin/env python3
# SHOWS: the real lab JS evaporation ramp (N₀, ω̄ vs t) — grounds the model in the actual apparatus sequence.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — real-ramp check).
# REPLACES: nothing (new; experiment-facing check).
"""The literal 2020-12 lab ramp (基底状態MOT_...js) run through the 0-D two-component model.
Left: the FORT power schedule + resulting ω̄(t). Right: N(t)/N₀(t) — where and how the BEC forms."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "jsramp"


def load(p):
    return list(csv.DictReader(open(f"{D}/{p}")))


rm = load("js_ramp.csv")
tr = load("js_traj.csv")
t_r = np.array([float(r["t_s"]) for r in rm])
hF = np.array([float(r["hFORT_W"]) for r in rm])
vF = np.array([float(r["vFORT_W"]) for r in rm])
wb = np.array([float(r["wbar_Hz"]) for r in rm])
t_t = np.array([float(r["t_s"]) for r in tr])
N = np.array([float(r["N"]) for r in tr])
N0 = np.array([float(r["N0"]) for r in tr])

fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.4, 5.0))

# left: FORT power schedule + ω̄
ax0.plot(t_r, hF, "-", color="#d62728", lw=2.2, label="hFORT [W]")
ax0.plot(t_r, vF, "-", color="#1f77b4", lw=2.2, label="vFORT [W]")
ax0.set_yscale("log")
ax0.set_xlabel("time  [s]")
ax0.set_ylabel("FORT beam power  [W]")
ax0.set_title("Real lab ramp (2020-12 JS sequence)", fontsize=11)
ax0.legend(loc="center left", fontsize=9)
axw = ax0.twinx()
axw.plot(t_r, wb, "--", color="#2ca02c", lw=1.8, label="$\\bar\\omega/2\\pi$ [Hz]")
axw.set_ylabel("$\\bar\\omega/2\\pi$  [Hz]", color="#2ca02c")
axw.tick_params(axis="y", colors="#2ca02c")
axw.legend(loc="upper right", fontsize=9)

# right: condensate formation
t_bec = t_t[np.argmax(N0 > 0)] if (N0 > 0).any() else t_t[-1]
ax1.plot(t_t, N, "-", color="#333333", lw=1.2, alpha=0.5, label="total $N$")
ax1.plot(t_t, N0, "-", color="#d62728", lw=2.6, label="condensate $N_0$")
ax1.axvline(t_bec, color="#d62728", ls=":", lw=1.4)
ax1.text(t_bec + 0.1, N.max() * 0.5, "BEC forms\n($t$≈%.1f s)" % t_bec, color="#d62728", fontsize=9)
ax1.plot(t_t[-1], N0[-1], "o", color="#d62728", ms=8)
ax1.annotate("$N_{\\rm BEC}$=%.1f×10³" % (N0[-1] / 1e3), (t_t[-1], N0[-1]),
             (t_t[-1] * 0.55, N0[-1] * 1.4), color="#d62728", fontsize=10)
ax1.set_xlabel("time  [s]")
ax1.set_ylabel("atom number")
ax1.set_yscale("log")
ax1.set_ylim(1e3, 2e6)
ax1.set_title("Condensate formation on the real ramp", fontsize=11)
ax1.legend(loc="upper right", fontsize=9)
ax1.text(0.03, 0.04,
         "0-D model on the LITERAL lab ramp (direct $K_3$=1.2×10⁻⁴¹): $N_{\\rm BEC}$≈7×10³,\n"
         "T≈110 nK, cf≈0.96, BEC forms late (~6.4 s). Consistent with the 2020-12 epoch\n"
         "(thesis first BEC 3×10³ → optimized 1.5×10⁴). The 3-axis shaping levers (waist +\n"
         "Feshbach, ~1.5×) sit ON TOP of this evaporation — they don't replace it.",
         transform=ax1.transAxes, fontsize=7.8, va="bottom",
         bbox=dict(boxstyle="round", fc="#fff3f3", ec="#d62728", alpha=0.9))

fig.suptitle("Real lab evaporation ramp through the 0-D model (experiment-facing check)", fontsize=12, y=1.00)
fig.tight_layout()
import os
out = sys.argv[2] if len(sys.argv) > 2 else "figs/eu_evaporation_optimization/js_lab_ramp.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
