#!/usr/bin/env python3
"""Issue #58 — FORT trap shaping vs K3 three-body loss. Reads the CSVs emitted by
scripts/evaporation_k3_trap_decompression.jl and renders the summary panels."""
import csv
import os

import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    with open(os.path.join(HERE, name)) as f:
        rows = list(csv.DictReader(f))
    return {k: [float(r[k]) for r in rows] for k in rows[0]}


fig, ax = plt.subplots(2, 3, figsize=(16, 8))

# (A) physics scaling: K3 rate vs nu (log-log)
d = load("physics_scaling.csv")
ax[0, 0].loglog(d["nu_bar_Hz"], d["k3_rate_per_s"], "o-", label="K₃ rate ∝ ω̄²·⁴")
ax[0, 0].loglog(d["nu_bar_Hz"], d["n0_TF_m3"], "s--", label="n₀ ∝ ω̄¹·²")
ax[0, 0].set_xlabel("trap ν̄ [Hz]")
ax[0, 0].set_ylabel("rate [1/s]  /  n₀ [m⁻³]")
ax[0, 0].set_title("(A) loosening cuts the instantaneous K₃ rate")
ax[0, 0].legend(fontsize=8)
ax[0, 0].grid(True, which="both", alpha=0.3)

# (B) CLEAN oracle: held condensate survival vs nu — the hypothesis, isolated (148×)
c = load("clean_condensate_survival.csv")
ax[0, 1].plot(c["nu_Hz"], [s * 100 for s in c["survival_fraction"]], "o-", color="crimson")
ax[0, 1].set_xlabel("trap ν̄ [Hz]  (lower = looser)")
ax[0, 1].set_ylabel("1 s survival of a held BEC [%]")
ax[0, 1].set_title("(B) ★ density↓ (loosen) ⇒ K₃ loss↓  — 148× isolated")
ax[0, 1].invert_xaxis()
ax[0, 1].grid(True, alpha=0.3)

# (C) loosening DURING evaporation barely moves N0_final (T_c confound)
p = load("sweep_final_power.csv")
w = load("sweep_waist.csv")
ax[0, 2].plot(p["nu_final_Hz"], p["N0_final"], "o-", label="final-power scale")
ax[0, 2].plot(w["nu_final_Hz"], w["N0_final"], "s-", label="beam waist")
ax[0, 2].set_xlabel("final trap ν̄ [Hz]")
ax[0, 2].set_ylabel("N₀ final (condensate)")
ax[0, 2].set_title("(C) loosen DURING evap ≈ flat (T_c starves inflow)")
ax[0, 2].legend(fontsize=8)
ax[0, 2].grid(True, alpha=0.3)

# (D) timing: condensate trajectory baseline vs timing-optimized
b = load("timeseries_baseline.csv")
t = load("timeseries_timing_optimized.csv")
ax[1, 0].plot(b["t_s"], b["N0_condensate"], label="baseline (lab ramp)")
ax[1, 0].plot(t["t_s"], t["N0_condensate"], label="timing-optimized")
ax[1, 0].set_xlabel("t [s]")
ax[1, 0].set_ylabel("N₀ condensate")
ax[1, 0].set_title("(D) form BEC late → less K₃ exposure (~9×)")
ax[1, 0].legend(fontsize=8)
ax[1, 0].grid(True, alpha=0.3)

# (E) decompression during a BEC hold
h = load("sweep_hold_decompression.csv")
for hold in sorted(set(h["hold_s"])):
    xs = [h["decompress_factor"][i] for i in range(len(h["hold_s"])) if h["hold_s"][i] == hold]
    ys = [h["N0_final"][i] for i in range(len(h["hold_s"])) if h["hold_s"][i] == hold]
    order = sorted(range(len(xs)), key=lambda k: xs[k])
    ax[1, 1].plot([xs[k] for k in order], [ys[k] for k in order], "o-", label=f"hold {hold:.1f}s")
ax[1, 1].set_xlabel("decompression factor f  (lower = looser)")
ax[1, 1].set_ylabel("N₀ final (condensate)")
ax[1, 1].set_title("(E) decompress in 0-D model: muted by melting")
ax[1, 1].invert_xaxis()
ax[1, 1].legend(fontsize=8)
ax[1, 1].grid(True, alpha=0.3)

ax[1, 2].axis("off")
ax[1, 2].text(0.02, 0.95,
              "Conclusion\n"
              "─────────\n"
              "• density↓ = loosen trap = K₃ loss↓ (B): CORRECT.\n"
              "• loosening DURING evaporation looks flat (C)\n"
              "  only because lower ω̄ ⇒ lower T_c ⇒ the\n"
              "  η-limited euv3 ramp barely condenses — a\n"
              "  T_c confound, not a K₃ effect.\n"
              "• realise the win: form the BEC (timing, D),\n"
              "  then decompress to lower n₀ (E). The 0-D\n"
              "  gain is muted by condensate→thermal melting\n"
              "  (imperfect adiabatic tracking) — model caveat.",
              fontsize=9, va="top", family="monospace")

fig.suptitle("Issue #58: FORT trap shaping vs K₃ three-body loss (euv3, 0-D 2-component model)",
             fontsize=12)
fig.tight_layout(rect=[0, 0, 1, 0.97])
out = os.path.join(HERE, "k3_trap_summary.png")
fig.savefig(out, dpi=130)
print("wrote", out)
