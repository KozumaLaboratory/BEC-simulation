#!/usr/bin/env python3
# SHOWS: aspect ratio is an orthogonal lever separating c1 from DDI in Eu spin-mixing — the
#        DDI-induced shift of the spin-mixing amplitude varies ~12× across trap geometry.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — c1-DDI separation).
# REPLACES: nothing (new; closes the campaign's one flagged unverified gap).
"""3D spinor-GP spin-mixing (Eu F=6, DDI via k-space convolution) at three trap aspect ratios
λ=ωz/ωr. The DDI-induced fractional shift of the ⟨Fz²⟩ oscillation amplitude, (amp_on−amp_off)/
amp_off, changes from −4% (cigar) to −46% (pancake): DDI is geometry-dependent, contact c1 is
not, so a two-geometry fit separates them."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "c1ddi_full"
rows = list(csv.DictReader(open(f"{D}/c1_ddi_ortho.csv")))
lam = np.array([float(r["lambda"]) for r in rows])
shift = np.array([float(r["ddi_shift"]) for r in rows]) * 100

fig, ax = plt.subplots(figsize=(7.6, 5.2))
ax.plot(lam, shift, "o-", color="#9467bd", lw=2.6, ms=11)
for x, y in zip(lam, shift):
    ax.annotate(f"{y:.0f}%", (x, y), (x, y + 3.5), ha="center", fontsize=10, color="#6a3d9a")
labels = {0.5: "cigar\n(prolate)", 1.0: "isotropic", 2.0: "pancake\n(oblate)"}
for x in lam:
    ax.annotate(labels.get(x, ""), (x, shift[list(lam).index(x)]),
                (x, -52), ha="center", fontsize=8.5, color="0.4")
ax.axhline(0, color="0.7", ls=":", lw=1)
ax.set_xlabel("trap aspect ratio  $\\lambda=\\omega_z/\\omega_r$")
ax.set_ylabel("DDI-induced shift of spin-mixing amplitude  [%]")
ax.set_title("Aspect ratio separates $c_1$ from DDI in Eu spin-mixing (3D spinor-GP)", fontsize=11)
ax.set_ylim(-58, 8)
ax.text(0.03, 0.04,
        "DDI shift varies ~12× (−4%→−46%) across geometry, while contact $c_1$ is\n"
        "$\\lambda$-independent ⇒ a multi-geometry spin-mixing fit separates $c_1$ from $c_{dd}$.\n"
        "Closes the campaign's flagged gap: single-trace $c_1$ is DDI-confounded ($c_{dd}/c_1\\approx47$),\n"
        "but two aspect ratios give the orthogonal constraint needed to extract $c_1$.",
        transform=ax.transAxes, fontsize=8.0, va="bottom",
        bbox=dict(boxstyle="round", fc="#f6f0ff", ec="#9467bd", alpha=0.95))
fig.tight_layout()
import os
out = sys.argv[2] if len(sys.argv) > 2 else "figs/eu_evaporation_optimization/c1_ddi_orthogonal.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
