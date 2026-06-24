#!/usr/bin/env python3
"""Issue #58 — FORT trap shaping vs K3 three-body loss. Reads the CSVs emitted by
scripts/evaporation_k3_trap_decompression.jl and renders a 4-panel summary."""
import csv
import os

import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    with open(os.path.join(HERE, name)) as f:
        rows = list(csv.DictReader(f))
    cols = {k: [float(r[k]) for r in rows] for k in rows[0]}
    return cols


fig, ax = plt.subplots(2, 2, figsize=(11, 8))

# (A) physics scaling: K3 rate vs nu (log-log)
d = load("physics_scaling.csv")
ax[0, 0].loglog(d["nu_bar_Hz"], d["k3_rate_per_s"], "o-", label="K₃ rate ∝ ω̄²·⁴")
ax[0, 0].loglog(d["nu_bar_Hz"], d["n0_TF_m3"], "s--", label="n₀ ∝ ω̄¹·²")
ax[0, 0].set_xlabel("trap ν̄ [Hz]")
ax[0, 0].set_ylabel("rate [1/s]  /  n₀ [m⁻³]")
ax[0, 0].set_title("(A) loosening cuts the instantaneous K₃ rate")
ax[0, 0].legend(fontsize=8)
ax[0, 0].grid(True, which="both", alpha=0.3)

# (B) loosening during evaporation barely moves N0_final
p = load("sweep_final_power.csv")
w = load("sweep_waist.csv")
ax[0, 1].plot(p["nu_final_Hz"], p["N0_final"], "o-", label="final-power scale")
ax[0, 1].plot(w["nu_final_Hz"], w["N0_final"], "s-", label="beam waist")
ax[0, 1].set_xlabel("final trap ν̄ [Hz]")
ax[0, 1].set_ylabel("N₀ final (condensate)")
ax[0, 1].set_title("(B) loosening during evaporation ≈ flat (T_c cancels)")
ax[0, 1].legend(fontsize=8)
ax[0, 1].grid(True, alpha=0.3)

# (C) timing: condensate trajectory baseline vs timing-optimized
b = load("timeseries_baseline.csv")
t = load("timeseries_timing_optimized.csv")
ax[1, 0].plot(b["t_s"], b["N0_condensate"], label="baseline (lab ramp)")
ax[1, 0].plot(t["t_s"], t["N0_condensate"], label="timing-optimized")
ax[1, 0].set_xlabel("t [s]")
ax[1, 0].set_ylabel("N₀ condensate")
ax[1, 0].set_title("(C) form BEC late → less K₃ exposure (~9×)")
ax[1, 0].legend(fontsize=8)
ax[1, 0].grid(True, alpha=0.3)

# (D) decompression during a BEC hold genuinely helps
h = load("sweep_hold_decompression.csv")
for hold in sorted(set(h["hold_s"])):
    xs = [h["decompress_factor"][i] for i in range(len(h["hold_s"])) if h["hold_s"][i] == hold]
    ys = [h["N0_final"][i] for i in range(len(h["hold_s"])) if h["hold_s"][i] == hold]
    order = sorted(range(len(xs)), key=lambda k: xs[k])
    ax[1, 1].plot([xs[k] for k in order], [ys[k] for k in order], "o-", label=f"hold {hold:.1f}s")
ax[1, 1].set_xlabel("decompression factor f  (lower = looser)")
ax[1, 1].set_ylabel("N₀ final (condensate)")
ax[1, 1].set_title("(D) decompress during the hold → +30–40%")
ax[1, 1].invert_xaxis()
ax[1, 1].legend(fontsize=8)
ax[1, 1].grid(True, alpha=0.3)

fig.suptitle("Issue #58: FORT trap shaping vs K₃ three-body loss (euv3, 0-D 2-component model)",
             fontsize=12)
fig.tight_layout(rect=[0, 0, 1, 0.97])
out = os.path.join(HERE, "k3_trap_summary.png")
fig.savefig(out, dpi=130)
print("wrote", out)
