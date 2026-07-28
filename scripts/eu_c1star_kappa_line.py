#!/usr/bin/env python3
"""c1*(κ) first-order FM->polar line at B=0 and its weakening with trap geometry.

    python scripts/eu_c1star_kappa_line.py out.png csv_k1 csv_kOthers...

Left: FM-branch order parameter mF=|<F>|/F vs c1 for each κ, drawn as a LINE through
the computed points (not scatter); the genuine discontinuity at c1* is shown as-is
(no smoothing over the jump). c1* = midpoint of the collapse interval, marked.
Right: the money plots — c1*(κ) (rising) and the order-parameter jump Δm_F(κ)
(shrinking ⇒ first-order weakens toward a tricritical point as the trap gets oblate).
Markers appear ONLY at the measured c1*(κ) points.
"""
import sys, csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

out = sys.argv[1]
csvs = sys.argv[2:]

# gather FM-seed mF(c1) per κ across all provided CSVs
byk = {}
for path in csvs:
    for r in csv.DictReader(open(path)):
        if r["seed"] != "stretched":
            continue
        K = round(float(r["kappa"]), 3)
        byk.setdefault(K, {})[float(r["c1_ratio"])] = float(r["mF"])

Ks = sorted(byk)
colors = {0.5: "royalblue", 1.0: "seagreen", 1.5: "crimson",
          2.0: "darkorange", 2.5: "purple"}

def cstar_and_jump(mf):
    cc = sorted(mf)
    for j in range(len(cc) - 1):
        if mf[cc[j]] > 0.4 and mf[cc[j + 1]] < 0.1:
            return 0.5 * (cc[j] + cc[j + 1]), mf[cc[j]]   # midpoint, pre-jump mF
    return np.nan, np.nan

stars = {}
fig, (axL, axR) = plt.subplots(1, 2, figsize=(11, 4.2))

for K in Ks:
    mf = byk[K]
    cc = np.array(sorted(mf))
    yy = np.array([mf[c] for c in cc])
    col = colors.get(K, "gray")
    axL.plot(cc, yy, "-", color=col, lw=2.0, label=rf"$\kappa={K}$")   # line, no per-point markers
    cst, jump = cstar_and_jump(mf)
    stars[K] = (cst, jump)
    if np.isfinite(cst):
        axL.axvline(cst, color=col, ls=":", lw=1.1, alpha=0.7)

axL.set_xlabel(r"$c_1/c_0$"); axL.set_ylabel(r"FM order parameter $m_F=|\langle F\rangle|/F$")
axL.set_ylim(-0.03, 1.03); axL.grid(alpha=0.3); axL.legend(fontsize=9, title="trap $\\omega_z$")
axL.set_title(r"$B=0$: sharp $m_F$ jump at $c_1^*(\kappa)$ (first-order)")

kk = np.array([K for K in Ks if np.isfinite(stars[K][0])])
cs = np.array([stars[K][0] for K in kk])
jm = np.array([stars[K][1] for K in kk])
axR.plot(kk, cs, "-o", color="black", lw=1.8, ms=7, label=r"$c_1^*(\kappa)$")
axR.set_xlabel(r"trap oblateness $\kappa=\omega_z$"); axR.set_ylabel(r"$c_1^*$ (transition)", color="black")
axR.grid(alpha=0.3)
axR2 = axR.twinx()
axR2.plot(kk, jm, "-s", color="darkorange", lw=1.8, ms=7, label=r"jump $\Delta m_F$")
axR2.set_ylabel(r"order-param jump $\Delta m_F$ at $c_1^*$", color="darkorange")
axR2.set_ylim(0, 1.0)
axR.set_title(r"$c_1^*$ rises + saturates; jump stays finite $\sim$0.6 (1st-order, no tricritical)")
l1, la1 = axR.get_legend_handles_labels(); l2, la2 = axR2.get_legend_handles_labels()
axR.legend(l1 + l2, la1 + la2, fontsize=9, loc="center right")

fig.suptitle(r"$^{151}$Eu FM$\to$polar $c_1$-driven transition at $B=0$: first-order line vs trap geometry", y=1.02)
fig.tight_layout()
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
for K in Ks:
    print(f"  κ={K}: c1*={stars[K][0]:.4f}  jump Δm_F={stars[K][1]:.3f}")
