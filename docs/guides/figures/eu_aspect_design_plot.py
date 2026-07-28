#!/usr/bin/env python3
# SHOWS: optimal aspect-ratio-scan design for extracting c1 despite DDI — the 2-parameter
#        Fisher σ(c1) from the (∂lnA/∂ln c1, ∂lnA/∂ln c_dd) response at each λ.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — c1-DDI separation).
# REPLACES: nothing (new; the quantitative design behind the c1_ddi_orthogonal demonstration).
"""Each trap aspect ratio λ gives a response row [∂lnA/∂ln c1, ∂lnA/∂ln c_dd] of the spin-mixing
amplitude (3D spinor-GP, DDI). Fisher = (1/σ_A²)·RᵀR over a chosen λ set; the marginal σ(c1)
(c_dd nuisance) = σ_A·sqrt([(RᵀR)⁻¹]_00). Single λ ⇒ c1↔c_dd degenerate (σ→∞); ≥2 λ with
different DDI response separate them. Left: response vectors. Right: σ(c1) for λ-subsets."""
import sys
import numpy as np
import matplotlib.pyplot as plt

# measured response rows (from eu_spinmix spin-mixing runs): λ, ∂lnA/∂ln c1, ∂lnA/∂ln c_dd
DATA = {0.5: (0.64245, 0.15798), 1.0: (0.90893, -0.08745), 2.0: (1.75080, -1.27423)}
SIGMA_A = 0.05  # per-measurement relative amplitude noise (5%)

lams = sorted(DATA)
R = np.array([DATA[l] for l in lams])  # rows [s_c1, s_cdd]


def marginal_sigma_c1(rows):
    rows = np.atleast_2d(rows)
    if rows.shape[0] < 2:
        return np.inf
    Fi = rows.T @ rows / SIGMA_A**2
    if abs(np.linalg.det(Fi)) < 1e-12:
        return np.inf
    return float(np.sqrt(np.linalg.inv(Fi)[0, 0]))


# subsets
from itertools import combinations
subsets = []
for r in (1, 2, 3):
    for c in combinations(range(len(lams)), r):
        rows = R[list(c)]
        subsets.append((tuple(lams[i] for i in c), marginal_sigma_c1(rows)))

fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.4, 5.2))

# left: response vectors in (∂c1, ∂cdd) plane
COL = {0.5: "#1f77b4", 1.0: "#9467bd", 2.0: "#d62728"}
for l in lams:
    s1, sd = DATA[l]
    ax0.annotate("", (s1, sd), (0, 0), arrowprops=dict(arrowstyle="->", color=COL[l], lw=2.4))
    ax0.annotate(f"λ={l}", (s1, sd), (s1 * 1.02, sd + 0.06), color=COL[l], fontsize=10)
ax0.axhline(0, color="0.7", lw=0.8); ax0.axvline(0, color="0.7", lw=0.8)
ax0.set_xlim(-0.2, 2.0); ax0.set_ylim(-1.5, 0.4)
ax0.set_xlabel("$\\partial\\ln A/\\partial\\ln c_1$  (contact response)")
ax0.set_ylabel("$\\partial\\ln A/\\partial\\ln c_{dd}$  (DDI response)")
ax0.set_title("Response vectors: DDI axis spreads with λ ⇒ separable", fontsize=11)
ax0.text(0.03, 0.55,
         "Different λ point in different directions in the (c1, c_dd) plane.\n"
         "A single λ can't tell a c1 change from a c_dd change (collinear\n"
         "= degenerate); two λ with different DDI response resolve both.",
         transform=ax0.transAxes, fontsize=8.0, va="bottom",
         bbox=dict(boxstyle="round", fc="#f6f0ff", ec="#9467bd", alpha=0.9))

# right: sigma(c1) for subsets
labels, vals = [], []
for names, s in subsets:
    labels.append("λ=" + ",".join(f"{n:g}" for n in names))
    vals.append(s * 100 if np.isfinite(s) else 1e3)
order = np.argsort(vals)
labels = [labels[i] for i in order]; vals = [vals[i] for i in order]
colors = ["#2ca02c" if "," in labels[i] and vals[i] < 100 else ("#d62728" if vals[i] >= 100 else "#9467bd")
          for i in range(len(vals))]
bars = ax1.barh(range(len(vals)), [min(v, 120) for v in vals], color=colors)
for i, v in enumerate(vals):
    ax1.text(min(v, 120) + 1, i, "∞ (degenerate)" if v >= 1e3 else f"{v:.1f}%",
             va="center", fontsize=9)
ax1.set_yticks(range(len(labels))); ax1.set_yticklabels(labels, fontsize=9)
ax1.set_xlabel("marginal $\\sigma(c_1)/c_1$  [%]  (c_dd nuisance, $\\sigma_A$=5%)")
ax1.set_title("$c_1$ precision by λ-subset: single-λ degenerate, pairs work", fontsize=11)
ax1.set_xlim(0, 135)
best = min((s for _, s in subsets if np.isfinite(s)), default=np.inf)
bestset = [n for n, s in subsets if s == best]
ax1.text(0.97, 0.05, f"best: {'λ='+','.join(f'{n:g}' for n in bestset[0])} → σ(c1)={best*100:.1f}%",
         transform=ax1.transAxes, ha="right", fontsize=9.5, color="#2ca02c",
         bbox=dict(boxstyle="round", fc="#f0fff0", ec="#2ca02c"))

fig.suptitle("Optimal aspect-ratio scan for extracting Eu $c_1$ from DDI-confounded spin-mixing", fontsize=12, y=1.00)
fig.tight_layout()
import os
out = sys.argv[1] if len(sys.argv) > 1 else "figs/eu_evaporation_optimization/aspect_design.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
# also print the numbers
print("=== marginal σ(c1)/c1 by subset (σ_A=5%) ===")
for names, s in sorted(subsets, key=lambda x: x[1]):
    print(f"  λ={','.join(f'{n:g}' for n in names):10s} → {'∞' if not np.isfinite(s) else f'{s*100:.1f}%'}")
