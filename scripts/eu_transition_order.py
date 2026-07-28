#!/usr/bin/env python3
"""Diagnose the FM↔polar transition ORDER from the two-seed branches.

    python scripts/eu_transition_order.py seed_full.csv [out.png]

For each (B, κ) we plot both branches vs c1:
  • top:  E(c1) for the FM seed (m_plus_F) and the polar seed — a clean CROSSING
          of two distinct branches ⇒ first-order; a single branch ⇒ continuous.
  • bottom: mF(c1) for each seed and for the GS (lower-E). A DISCONTINUOUS jump in
          the GS mF at the crossing ⇒ first-order; a smooth sweep through ⇒ continuous.
The energy crossing c1* (linear-interpolated) is marked; near it, if both seeds are
distinct and metastable, that is the coexistence region.
"""
import sys, csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

csv_path = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "eu_transition_order.png"

rows = list(csv.DictReader(open(csv_path)))
def f(r, k): return float(r[k])
Bs = sorted({round(f(r, "B_uG")) for r in rows})
Ks = sorted({round(f(r, "kappa"), 3) for r in rows})

fig, axes = plt.subplots(2, len(Bs) * len(Ks), figsize=(3.4 * len(Bs) * len(Ks), 6.2),
                         squeeze=False, sharex=True)
col = 0
for B in Bs:
    for K in Ks:
        sub = [r for r in rows if round(f(r, "B_uG")) == B and round(f(r, "kappa"), 3) == K]
        branch = {}
        for r in sub:
            branch.setdefault(r["seed"], []).append((f(r, "c1_ratio"), f(r, "E"), f(r, "mF")))
        aE, amF = axes[0][col], axes[1][col]
        c1_all = sorted({c for s in branch.values() for c, _, _ in s})
        EF = {c: e for c, e, _ in branch.get("stretched", [])}
        EP = {c: e for c, e, _ in branch.get("polar", [])}
        MF = {c: m for c, _, m in branch.get("stretched", [])}
        MP = {c: m for c, _, m in branch.get("polar", [])}
        cc = np.array(c1_all)
        ef = np.array([EF.get(c, np.nan) for c in cc])
        ep = np.array([EP.get(c, np.nan) for c in cc])
        aE.plot(cc, ef, "o-", color="crimson", ms=3, label="FM seed")
        aE.plot(cc, ep, "s-", color="royalblue", ms=3, label="polar seed")
        # GS mF (lower-E branch) + each branch
        gs = np.array([MF.get(c, np.nan) if EF.get(c, np.inf) <= EP.get(c, np.inf)
                       else MP.get(c, np.nan) for c in cc])
        amF.plot(cc, [MF.get(c, np.nan) for c in cc], "o-", color="crimson", ms=3, alpha=0.5)
        amF.plot(cc, [MP.get(c, np.nan) for c in cc], "s-", color="royalblue", ms=3, alpha=0.5)
        amF.plot(cc, gs, "k-", lw=2.2, label="GS mF")
        # energy crossing
        dE = ep - ef
        for j in range(len(cc) - 1):
            if np.isfinite(dE[j]) and np.isfinite(dE[j + 1]) and dE[j] * dE[j + 1] < 0:
                t = dE[j] / (dE[j] - dE[j + 1]); cstar = cc[j] + t * (cc[j + 1] - cc[j])
                for a in (aE, amF):
                    a.axvline(cstar, color="green", ls="--", lw=1.3)
                aE.text(cstar, np.nanmax(ef), f"{cstar:.3f}", color="green", fontsize=7, ha="center")
                break
        # FM-branch mF collapse = the PHYSICAL FM/polar boundary (spinodal). The
        # energy crossing above can be spurious when both seeds are already polar.
        mfm = np.array([MF.get(c, np.nan) for c in cc])
        for j in range(len(cc) - 1):
            if np.isfinite(mfm[j]) and np.isfinite(mfm[j + 1]) and mfm[j] > 0.4 and mfm[j + 1] < 0.1:
                ccol = cc[j + 1]
                for a in (aE, amF):
                    a.axvline(ccol, color="darkorange", ls="-", lw=1.6, alpha=0.8)
                amF.text(ccol, 0.55, rf"$c_1^*\approx{ccol:.4f}$", color="darkorange",
                         fontsize=7, ha="right", rotation=90, va="center")
                break
        aE.set_title(rf"$B={B}\mu$G, $\kappa={K}$", fontsize=9)
        aE.grid(alpha=0.3); amF.grid(alpha=0.3)
        amF.set_ylim(-0.05, 1.05); amF.set_xlabel(r"$c_1/c_0$")
        if col == 0:
            aE.set_ylabel("energy"); amF.set_ylabel("mF")
            aE.legend(fontsize=7); amF.legend(fontsize=7)
        col += 1
fig.suptitle(r"$^{151}$Eu FM$\leftrightarrow$polar transition order: two-seed branches. "
             r"Orange = FM-branch mF collapse (physical boundary); green = E-crossing "
             r"(spurious once both seeds polar). Sharp mF jump ⇒ first-order.", y=1.0)
fig.tight_layout()
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
