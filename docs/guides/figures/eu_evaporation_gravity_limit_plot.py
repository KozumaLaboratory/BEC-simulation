#!/usr/bin/env python3
# SHOWS: gravity floor on the waist axis — real euv3 trap depth with/without gravity vs loosening.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Constraint 1 — gravity caps the waist").
# REPLACES: nothing (current-best, complementary constraint figure).
"""Gravity limit on trap loosening for the Eu evaporation. The real euv3 crossed-dipole
trap depth WITH gravity collapses as ω̄ is loosened — capping the waist axis at m_ω≈0.6."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "grav_out"
rows = list(csv.DictReader(open(f"{D}/gravity_limit.csv")))
w = np.array([float(r["wbar_Hz"]) for r in rows])
Ug = np.array([float(r["U_grav_uK"]) for r in rows])
Un = np.array([float(r["U_nograv_uK"]) for r in rows])

fig, ax = plt.subplots(figsize=(8.4, 5.4))
ax.plot(w, Un, "--", color="#7f7f7f", lw=2.0, label="trap depth, NO gravity")
ax.plot(w, Ug, "-", color="#d62728", lw=2.6, label="trap depth WITH gravity (real)")
ax.fill_between(w, 0, Ug, where=(w <= 120), color="#d62728", alpha=0.12, lw=0)
# formation + floor markers
ax.axvline(180, color="#1f77b4", ls=":", lw=1.4)
ax.text(182, Un.max() * 0.9, "formation\nω̄≈180 Hz ($m_\\omega$=1)", color="#1f77b4", fontsize=9)
ax.axvline(114, color="#d62728", ls=":", lw=1.4)
ax.text(116, Un.max() * 0.55, "gravity floor\nω̄≈114 Hz ($m_\\omega$≈0.6)\nU→0.6 µK", color="#b0201a", fontsize=9)
ax.annotate("gravity removes\n65–87% of the depth\nas you loosen",
            (139, 1.07), (150, 5.5), fontsize=9, color="#d62728",
            arrowprops=dict(arrowstyle="->", color="#d62728"))
ax.text(105, 0.15, "spill:\ndepth\ncollapses", color="#b0201a", fontsize=8.5, ha="right")
ax.set_xlabel("mean trap frequency  $\\bar\\omega/2\\pi$  [Hz]  (loosening ← )")
ax.set_ylabel("trap depth  $U/k_B$  [µK]")
ax.set_title("Gravity caps the waist axis: real euv3 trap depth vs loosening", fontsize=11.5)
ax.legend(loc="upper left", fontsize=10)
ax.set_ylim(bottom=0)
ax.invert_xaxis()   # loosening to the right
fig.tight_layout()
import os
out = f"{D}/../../../figs/eu_evaporation_reopt/eu_evaporation_gravity_limit.png" \
    if len(sys.argv) < 3 else sys.argv[2]
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
