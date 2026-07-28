#!/usr/bin/env python3
"""Honest c1×κ phase map: show the RAW per-cell data, mark data quality, and put
the boundary where the physics defines it — NOT a smoothed fit over unexamined noise.

    python scripts/eu_phase_honest.py b0:prodB0.csv:seedB0.csv b10:... [out.png]
    (each arg = LABEL:prod_csv:seed_csv ; prod has mF, seed has both seeds' E+grad)

Per cell we show:
  • mF(GS) as a pcolormesh — NO interpolation, NO smoothing (each block = one solve);
  • hatch on cells that are UNDER-CONVERGED (max seed grad_norm > 1e-4) — flagged,
    not hidden;
  • the energy-crossing boundary E_FM = E_polar (sign flip of E_polar−E_FM between
    adjacent c1) as markers — the thermodynamically-correct first-order line;
  • cells where both seeds converge to the SAME state (|ΔE|/|E|<1e-6) marked '=' —
    a UNIQUE ground state (no bistability there).

This makes the transition band, its resolution limit, and its convergence quality
legible instead of painting a clean curve over them.
"""
import sys, csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

args = sys.argv[1:]
out = "eu_phase_honest.png"
if args and args[-1].endswith(".png"):
    out, args = args[-1], args[:-1]

GRAD_BAD = 1e-4          # under-converged threshold
DEGEN = 1e-6            # |ΔE|/|E| below this ⇒ seeds are the same state


def load(prod_csv, seed_csv):
    mF = {}
    for r in csv.DictReader(open(prod_csv)):
        mF[(round(float(r["c1_ratio"]), 6), round(float(r["kappa"]), 4))] = float(r["mF"])
    seeds = {}
    B = np.nan
    for r in csv.DictReader(open(seed_csv)):
        key = (round(float(r["c1_ratio"]), 6), round(float(r["kappa"]), 4))
        seeds.setdefault(key, {})[r["seed"]] = (float(r["E"]), float(r["grad_norm"]))
        B = float(r["B_uG"])
    return mF, seeds, B


def panel(ax, prod_csv, seed_csv):
    mF, seeds, B = load(prod_csv, seed_csv)
    keys = set(mF) | set(seeds)
    c1s = np.array(sorted({c for c, k in keys}))
    ks = np.array(sorted({k for c, k in keys}))
    MF = np.full((len(ks), len(c1s)), np.nan)
    BAD = np.zeros_like(MF, bool)
    dE = np.full_like(MF, np.nan)      # E_polar - E_FM
    same = np.zeros_like(MF, bool)
    for (c, k), v in mF.items():
        MF[np.where(ks == k)[0][0], np.where(c1s == c)[0][0]] = v
    for (c, k), d in seeds.items():
        i, j = np.where(ks == k)[0][0], np.where(c1s == c)[0][0]
        g = max((d.get(s, (np.nan, np.nan))[1] for s in d), default=np.nan)
        BAD[i, j] = np.isfinite(g) and g > GRAD_BAD
        if "stretched" in d and "polar" in d:
            ef, ep = d["stretched"][0], d["polar"][0]
            dE[i, j] = ep - ef
            if abs(ep - ef) < DEGEN * max(abs(ef), 1e-12):
                same[i, j] = True
    # mesh edges for pcolormesh (cell-centred data)
    def edges(a):
        a = np.asarray(a, float); m = (a[:-1] + a[1:]) / 2
        return np.concatenate([[a[0] - (m[0] - a[0])], m, [a[-1] + (a[-1] - m[-1])]])
    Xe, Ye = np.meshgrid(edges(c1s), edges(ks))
    pc = ax.pcolormesh(Xe, Ye, MF, cmap="RdBu_r", vmin=0, vmax=1, shading="flat")
    # under-converged cells: hatch overlay
    bi, bj = np.where(BAD)
    ax.scatter(c1s[bj], ks[bi], marker="x", s=45, c="k", lw=1.4, zorder=6,
               label=f"under-converged (grad>{GRAD_BAD:g})")
    # unique-GS cells (seeds identical): small dots
    si, sj = np.where(same)
    ax.scatter(c1s[sj], ks[si], marker=".", s=8, c="0.3", zorder=5)
    # energy-crossing boundary: per κ row, c1 where dE changes sign
    xb, yb = [], []
    for i in range(len(ks)):
        row = dE[i]
        for j in range(len(c1s) - 1):
            a, b = row[j], row[j + 1]
            if np.isfinite(a) and np.isfinite(b) and a * b < 0:
                t = a / (a - b)
                xb.append(c1s[j] + t * (c1s[j + 1] - c1s[j])); yb.append(ks[i])
    ax.scatter(xb, yb, marker="D", s=26, facecolor="lime", edgecolor="k",
               lw=0.6, zorder=7, label=r"$E_{FM}=E_{polar}$ crossing")
    ax.axvline(0.0, color="0.3", ls="--", lw=1.0)
    ax.set_title(rf"$B={B:.0f}\,\mu$G")
    ax.set_xlabel(r"$c_1/c_0$")
    return pc


specs = [a.split(":") for a in args]
fig, axes = plt.subplots(1, len(specs), figsize=(5.6 * len(specs), 5.0),
                         squeeze=False, sharey=True)
axes = axes[0]
pc = None
for ax, (_, pcsv, scsv) in zip(axes, specs):
    pc = panel(ax, pcsv, scsv)
axes[0].set_ylabel(r"$\kappa=\omega_z/\omega_r$  (cigar $<1$ | pancake $>1$)")
axes[-1].legend(loc="upper left", fontsize=7, framealpha=0.9)
cb = fig.colorbar(pc, ax=axes, fraction=0.025, pad=0.01)
cb.set_label(r"$m_F=|\langle F\rangle|/F$  (raw per-cell; blue polar $\to$ red FM)")
fig.suptitle(r"$^{151}$Eu F=6 GS $c_1\times\kappa$ — RAW cells + quality flags "
             r"+ energy-crossing boundary (no smoothing)", y=1.03)
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
