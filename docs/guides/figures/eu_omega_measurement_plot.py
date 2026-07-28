#!/usr/bin/env python3
# SHOWS: dipole-mode ω̄ measurement precision vs number of imaging shots, for 3 COM-noise levels.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — do-first: ω̄ to 1%).
# REPLACES: nothing (new; the K3 density-calibration unblocker figure).
"""σ(ω̄)/ω̄ from a simulated dipole-mode measurement (displaced GS, COM oscillation fit) vs
shots, at 2/5/10% per-shot COM noise. The 1% target is reached from ~10 shots; 6 shots aliases."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "omega_full"
rows = list(csv.DictReader(open(f"{D}/omega_precision.csv")))
noises = sorted(set(float(r["com_noise_frac"]) for r in rows))
COL = {0.02: "#1f77b4", 0.05: "#9467bd", 0.10: "#d62728"}

fig, ax = plt.subplots(figsize=(7.8, 5.2))
for nz in noises:
    pts = sorted([(int(r["n_shots"]), float(r["sigma_omega_pct"])) for r in rows
                  if float(r["com_noise_frac"]) == nz])
    n = [p[0] for p in pts]; s = [p[1] for p in pts]
    ax.plot(n, s, "o-", color=COL.get(nz, "#333"), lw=2.4, ms=8,
            label=f"COM noise {nz*100:.0f}%")
ax.axhline(1.0, color="#2ca02c", ls="--", lw=1.8)
ax.text(28, 1.15, "1% target", color="#2ca02c", fontsize=10, ha="right")
ax.axvspan(5.5, 7, color="#d62728", alpha=0.10, lw=0)
ax.text(6.2, 6.0, "aliasing\n(<10 shots\n/3 periods)", color="#b0201a", fontsize=8.5, ha="center")
ax.set_xlabel("number of imaging shots (over 3 trap periods)")
ax.set_ylabel("σ(ω̄)/ω̄  [%]")
ax.set_yscale("log")
ax.set_title("Dipole-mode ω̄ measurement: 1% is easily reached (zero fit systematic)", fontsize=11)
ax.legend(loc="upper right", fontsize=9.5)
ax.text(0.03, 0.04,
        "Fit recovers ω̄ with 0% systematic. σ(ω̄)/ω̄ < 1% from ~10 shots even at 10% COM\n"
        "noise; ≥10 shots per 3 periods needed (6 aliases). This is the do-first lever: a 1%\n"
        "ω̄ turns the K3 density-calibration systematic (±20%) into a statistical one (~4%).",
        transform=ax.transAxes, fontsize=8.0, va="bottom",
        bbox=dict(boxstyle="round", fc="#eef6ff", ec="#1f77b4", alpha=0.9))
fig.tight_layout()
import os
out = sys.argv[2] if len(sys.argv) > 2 else "figs/eu_evaporation_optimization/omega_measurement.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
