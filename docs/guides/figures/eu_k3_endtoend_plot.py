#!/usr/bin/env python3
# SHOWS: end-to-end K3 recovery precision vs ω̄-calibration error — the do-first chain, quantified.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — K3 end-to-end).
# REPLACES: nothing (new).
"""σ(K3)/K3 from fitting synthetic BEC-decay data, vs ω̄-calibration error, at a few shots/noise
settings. Recovery is unbiased; σ(K3) is statistical (~4%) when ω̄ is known to 1%, but ω̄-dominated
(~13%) when ω̄ is only 5% — the K3↔ω̄ degeneracy (K3∝ω̄^{-2.4}) made concrete."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "k3e2e"
rows = list(csv.DictReader(open(f"{D}/k3_endtoend.csv")))

fig, ax = plt.subplots(figsize=(7.8, 5.2))
configs = sorted(set((int(r["n_shots"]), float(r["noise"])) for r in rows))
markers = ["o", "s", "^", "D"]
COL = {(10, 0.03): "#1f77b4", (10, 0.05): "#9467bd", (20, 0.03): "#2ca02c", (20, 0.05): "#d62728"}
for i, (ns, nz) in enumerate(configs):
    pts = sorted([(float(r["omega_err"]) * 100, float(r["sigma_K3_pct"]))
                  for r in rows if int(r["n_shots"]) == ns and float(r["noise"]) == nz])
    x = [p[0] for p in pts]; y = [p[1] for p in pts]
    ax.plot(x, y, markers[i % 4] + "-", color=COL.get((ns, nz), "#333"), lw=2.2, ms=8,
            label=f"{ns} shots, {nz*100:.0f}% atom noise")
ax.axhline(20, color="0.6", ls=":", lw=1.5)
ax.text(4.7, 21, "campaign's conservative ±20%", color="0.4", fontsize=8.5, ha="right")
ax.set_xlabel("ω̄ calibration error  [%]")
ax.set_ylabel("recovered σ(K₃)/K₃  [%]")
ax.set_title("End-to-end K₃ recovery: ω̄ calibration is the limit (unbiased)", fontsize=11)
ax.legend(loc="upper left", fontsize=9)
ax.set_ylim(0, 24)
ax.text(0.97, 0.05,
        "K₃ recovered with ~0 bias in all cases. σ(K₃) ≈ 3-5% when ω̄ is known to 1%\n"
        "(the dipole-mode result), but climbs to ~13% at 5% ω̄ — because K₃∝ω̄^{-2.4}.\n"
        "So: measure ω̄ to 1% (cheap), then K₃ from BEC decay is a ~4% statistical number,\n"
        "well inside the campaign's conservative ±20% estimate.",
        transform=ax.transAxes, ha="right", va="bottom", fontsize=7.8,
        bbox=dict(boxstyle="round", fc="#eef6ff", ec="#1f77b4", alpha=0.9))
fig.tight_layout()
import os
out = sys.argv[2] if len(sys.argv) > 2 else "figs/eu_evaporation_optimization/k3_endtoend.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
