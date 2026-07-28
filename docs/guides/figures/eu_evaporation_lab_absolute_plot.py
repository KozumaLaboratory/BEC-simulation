#!/usr/bin/env python3
# SHOWS: type-C absolute-N validation — model N_BEC vs K₃ at the lab operating point vs measured.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Absolute-number validation (type-C)").
# REPLACES: nothing (current-best, complementary validation figure).
"""Type-C absolute-N validation: model N_BEC vs K₃ at the real lab operating point, against
the measured ¹⁵¹Eu BEC number. The model matches at the direct-measured K₃; K₃ is the
dominant absolute-N uncertainty."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "lababs_out"
rows = list(csv.DictReader(open(f"{D}/lab_absolute.csv")))
K3 = np.array([float(r["K3"]) for r in rows])
N = np.array([float(r["N_BEC"]) for r in rows])

fig, ax = plt.subplots(figsize=(8.2, 5.2))
ax.plot(K3 * 1e42, N, "-", color="#1f77b4", lw=2.6, label="0-D model $N_{\\rm BEC}$ (euv3 lab ramp)")
# measured band (thesis optimized 1.5e4)
ax.axhline(1.5e4, color="#2ca02c", ls="--", lw=1.8)
ax.text(3.2, 1.62e4, "lab measured (thesis) 1.5×10⁴", color="#2ca02c", fontsize=9.5)
# K3 markers
for k3, lab, c in ((4.6, "BEC-fit\n4.6e-42", "#7f7f7f"), (12.0, "direct (Fig 7.5)\n1.2e-41", "#d62728")):
    Nk = np.interp(k3, K3 * 1e42, N)
    ax.plot(k3, Nk, "o", color=c, ms=9, zorder=5)
    ax.annotate(lab, (k3, Nk), (k3 * 1.05, Nk * 1.25), fontsize=9, color=c,
                arrowprops=dict(arrowstyle="->", color=c))
ax.set_xlabel("three-body coefficient  $K_3$  [$10^{-42}$ m⁶/s]")
ax.set_ylabel("BEC atom number  $N_{\\rm BEC}$")
ax.set_title("Type-C: model vs measured Eu BEC number (corrected ⟨n²⟩=8/21)", fontsize=11)
ax.set_xscale("log")
ax.legend(loc="upper right", fontsize=9.5)
ax.set_ylim(bottom=0)
ax.text(0.03, 0.05,
        "With the corrected condensate moment ⟨n²⟩=8/21·n₀², $N_{\\rm BEC}$=1.5×10⁴\n"
        "crosses at $K_3$≈1.8×10⁻⁴¹; at the direct-measured $K_3$=1.2×10⁻⁴¹ the model\n"
        "gives 1.9×10⁴ (~26% over thesis) — order-1 agreement within the $K_3$ factor-2.6\n"
        "systematic (a formation-dynamics, not density, effect). The optimization GAIN\n"
        "is relative and $K_3$-independent, so it survives this shift.",
        transform=ax.transAxes, fontsize=8.0, va="bottom",
        bbox=dict(boxstyle="round", fc="#eef6ff", ec="#1f77b4", alpha=0.9))
fig.tight_layout()
import os
out = sys.argv[2] if len(sys.argv) > 2 else "figs/eu_evaporation_reopt/eu_evaporation_lab_absolute.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
