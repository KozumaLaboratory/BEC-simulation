#!/usr/bin/env python3
"""Eu F=6 GS phase map on the c1 × κ plane, three B slices side by side.

    python scripts/eu_phase_contour_c1kappa.py b0.csv b10.csv b60.csv [out.png]

c1 is treated as an UNCERTAIN axis (FM c1<0 ↔ AFM c1>0) because Eu's spin
channels are unmeasured. Each panel (fixed B) shows the flux-closure order
parameter ‖∇·F‖/‖∇F‖ as smooth filled contours, with the two phase
boundaries overlaid:
  • white  mF = 0.5           local FM ↔ polar/inert (magnetisation collapse)
  • crimson fluxclosure = 0.5 flower (flux-closure) ↔ uniform FM
and a dashed vertical line at c1=0 (the FM/AFM contact boundary). Pure-numpy
separable bilinear upsampling makes the curves smooth from the coarse grid.
"""
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

args = sys.argv[1:]
out = "eu_phase_contour_c1kappa.png"
if args and args[-1].endswith(".png"):
    out = args[-1]; args = args[:-1]
csvs = args
assert csvs, "need at least one slice CSV"


def load(csv):
    rows = [l.rstrip("\n").split(",") for l in open(csv)]
    h = {name: i for i, name in enumerate(rows[0])}
    d = rows[1:]
    col = lambda k: np.array([float(r[h[k]]) for r in d])
    B = col("B_uG")
    return dict(c1=col("c1_ratio"), kappa=col("kappa"),
                fc=col("fluxclosure"), mF=col("mF"),
                B=(B[0] if len(B) else float("nan")))


def grid(x, y, v):
    xs, ys = np.unique(x), np.unique(y)
    Z = np.full((len(ys), len(xs)), np.nan)
    for a, b, val in zip(x, y, v):
        Z[np.where(ys == b)[0][0], np.where(xs == a)[0][0]] = val
    for i in range(Z.shape[0]):                      # fill gaps along x
        m = np.isnan(Z[i])
        if m.any() and (~m).any():
            Z[i, m] = np.interp(np.flatnonzero(m), np.flatnonzero(~m), Z[i, ~m])
    return xs, ys, Z


def upsample(x, y, Z, f=8):
    xf = np.linspace(x[0], x[-1], len(x) * f)
    yf = np.linspace(y[0], y[-1], len(y) * f)
    Z1 = np.vstack([np.interp(xf, x, Z[i]) for i in range(Z.shape[0])])
    Zf = np.column_stack([np.interp(yf, y, Z1[:, j]) for j in range(Z1.shape[1])])
    return xf, yf, Zf


slices = [load(c) for c in csvs]
fig, axes = plt.subplots(1, len(slices), figsize=(5.4 * len(slices), 5.0),
                         squeeze=False, sharey=True)
axes = axes[0]
for ax, s in zip(axes, slices):
    xs, ys, FC = grid(s["c1"], s["kappa"], s["fc"])
    _, _, MF = grid(s["c1"], s["kappa"], s["mF"])
    xf, yf, FCf = upsample(xs, ys, FC)
    _, _, MFf = upsample(xs, ys, MF)
    cf = ax.contourf(xf, yf, FCf, levels=np.linspace(0, 0.7, 15),
                     cmap="viridis", extend="max")
    ax.contour(xf, yf, MFf, levels=[0.5], colors="w", linewidths=2.4)      # FM↔polar
    ax.contour(xf, yf, FCf, levels=[0.5], colors="crimson", linewidths=2.4)  # flower↔FM
    ax.axvline(0.0, color="k", ls="--", lw=1.0, alpha=0.6)                  # FM/AFM contact
    ax.axhline(1.0, color="0.6", ls=":", lw=0.9)                           # isotropic κ=1
    ax.set_title(rf"$B = {s['B']:.0f}\,\mu$G")
    ax.set_xlabel(r"$c_1/c_0$  (FM $<0$ | AFM $>0$)")
axes[0].set_ylabel(r"$\kappa=\omega_z/\omega_r$  (cigar $<1$ | pancake $>1$)")
cb = fig.colorbar(cf, ax=axes, fraction=0.025, pad=0.01)
cb.set_label(r"flux-closure $\|\nabla\!\cdot\!F\|/\|\nabla F\|$  (flower low $\to$ FM high)")
fig.suptitle(r"$^{151}$Eu F=6 GS phase map on $c_1\times\kappa$ "
             r"(white: mF=0.5 FM/polar; crimson: flux-closure 0.5 flower/FM)", y=1.03)
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
