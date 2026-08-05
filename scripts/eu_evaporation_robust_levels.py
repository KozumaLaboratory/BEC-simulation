#!/usr/bin/env python3
"""Robust ¹⁵¹Eu evaporation optimum vs the operational-error level ε ∈ {0,1,5,10}%.

A) BEC atom number RELATIVE TO THE LAB RAMP (guaranteed worst-case + nominal) vs ε — the
   optimum is 3.2–3.5× the lab ramp and the guaranteed floor erodes only mildly with ε.
B) The optimal H/V FORT power schedule (identical at every ε) vs the lab ramp.

Run scripts/eu_evaporation_robust_levels.jl first to emit the CSVs.
"""
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

FIG = Path(__file__).resolve().parent.parent / "docs" / "guides" / "figures"

lv = np.loadtxt(FIG / "eu_evap_robust_levels.csv", delimiter=",", skiprows=1, ndmin=2)
rm = np.loadtxt(FIG / "eu_evap_robust_levels_ramps.csv", delimiter=",")

eps = lv[:, 0]                       # %
nom = lv[:, 1]
worst = lv[:, 2]
lab = worst[0] / lv[0, 3]            # recover lab N_BEC from the ratio column
nom_r = nom / lab
worst_r = worst / lab

fig, (axA, axB) = plt.subplots(1, 2, figsize=(11, 4.4))

# --- Panel A: atom number relative to the lab ramp ---
axA.axhline(1.0, color="0.5", lw=1.4, label="lab ramp (baseline)")
axA.plot(eps, nom_r, "--o", color="tab:orange", label="optimum, nominal")
axA.plot(eps, worst_r, "-^", color="tab:blue", lw=2, label="optimum, guaranteed (worst-case)")
axA.fill_between(eps, 1.0, worst_r, color="tab:blue", alpha=0.10)
for x, y in zip(eps, worst_r):
    axA.annotate(f"{y:.2f}×", (x, y), textcoords="offset points", xytext=(0, -14),
                 ha="center", fontsize=8, color="tab:blue")
axA.set_xlabel("operational-error level  ε  (%)   — applied to power/α, imbalance, T₀, N₀")
axA.set_ylabel(r"$N_{\rm BEC}$ / lab ramp")
axA.set_title("A  Guaranteed atom-number gain vs error budget")
axA.set_ylim(0, 4)
axA.set_xticks(eps)
axA.legend(fontsize=8.5, loc="center left")
axA.grid(alpha=0.3)

# --- Panel B: the (ε-invariant) optimal schedule vs lab ---
t = rm[:, 0]
axB.plot(t, rm[:, 1], color="0.5", lw=1.8, label="lab  H")
axB.plot(t, rm[:, 2], color="0.5", lw=1.5, ls="--", label="lab  V")
# all four ε optima coincide → plot the ε=0 curve once, note the invariance
axB.plot(t, rm[:, 3], color="tab:blue", lw=2.2, label="optimum  H  (ε=0…10%, identical)")
axB.plot(t, rm[:, 4], color="tab:blue", lw=1.8, ls="--", label="optimum  V")
axB.set_xlabel("time  (s)")
axB.set_ylabel("FORT power  (W)")
axB.set_yscale("log")
axB.set_title("B  Optimal schedule — unchanged by ε")
axB.legend(fontsize=8, loc="lower left")
axB.grid(alpha=0.3, which="both")
axB.annotate("crash early\n(evaporate while dense)", (0.35, 0.12),
             fontsize=8, color="tab:blue", ha="center")

fig.tight_layout()
out = FIG / "eu_evaporation_robust_levels.png"
fig.savefig(out, dpi=150)
print("wrote", out)
