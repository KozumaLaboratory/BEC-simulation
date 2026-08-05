#!/usr/bin/env python3
"""Two-panel deliverable for the robust ¹⁵¹Eu evaporation ramp.

A) BEC atom number vs common FORT-power / α calibration factor for the lab, the
   nominal-optimal, and the robust ramp — the cliff plot. The robust ramp stays high
   AND does not fall off the cliff when the calibration is low. (power ≡ α: depth ∝ αP.)
B) The H/V FORT power schedules of the three ramps.

Run scripts/eu_evaporation_robust_alpha.jl first to emit the CSVs.
"""
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

FIG = Path(__file__).resolve().parent.parent / "docs" / "guides" / "figures"

cliff = np.loadtxt(FIG / "eu_evap_robust_alpha_cliff.csv", delimiter=",")
ramps = np.loadtxt(FIG / "eu_evap_robust_alpha_ramps.csv", delimiter=",")

fac = cliff[:, 0]
lab, nom, rob = cliff[:, 1] / 1e4, cliff[:, 2] / 1e4, cliff[:, 3] / 1e4

fig, (axA, axB) = plt.subplots(1, 2, figsize=(11, 4.4))

# --- Panel A: the cliff ---
axA.plot(fac, lab, "-o", ms=3, color="0.5", label="lab ramp")
axA.plot(fac, nom, "-s", ms=3, color="tab:orange", label="nominal-optimal")
axA.plot(fac, rob, "-^", ms=3, color="tab:blue", label="robust (worst-case opt.)")
axA.axvline(1.0, ls=":", color="k", lw=0.8)
axA.axvspan(1 - 0.10, 1 + 0.10, color="tab:blue", alpha=0.08,
            label="±10% calibration band")
axA.set_xlabel("FORT-power / polarizability α  calibration factor")
axA.set_ylabel(r"BEC atom number  $N_{\rm BEC}\ (\times 10^4)$")
axA.set_title("A  Optimized AND robust to depth calibration")
axA.legend(fontsize=8, loc="upper left")
axA.grid(alpha=0.3)

# --- Panel B: the schedules ---
t = ramps[:, 0]
axB.plot(t, ramps[:, 1], color="0.5", lw=1.5, label="lab  H")
axB.plot(t, ramps[:, 2], color="0.5", lw=1.5, ls="--", label="lab  V")
axB.plot(t, ramps[:, 3], color="tab:orange", lw=1.5, label="nominal-opt  H")
axB.plot(t, ramps[:, 4], color="tab:orange", lw=1.5, ls="--", label="nominal-opt  V")
axB.plot(t, ramps[:, 5], color="tab:blue", lw=1.8, label="robust  H")
axB.plot(t, ramps[:, 6], color="tab:blue", lw=1.8, ls="--", label="robust  V")
axB.set_xlabel("time  (s)")
axB.set_ylabel("FORT power  (W)")
axB.set_yscale("log")
axB.set_title("B  Monotone ramp schedules")
axB.legend(fontsize=7, ncol=3, loc="upper right")
axB.grid(alpha=0.3, which="both")

fig.tight_layout()
out = FIG / "eu_evaporation_robust_alpha.png"
fig.savefig(out, dpi=150)
print("wrote", out)
