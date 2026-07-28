#!/usr/bin/env python3
"""Smooth (Kawaguchi-style) order-parameter phase map from a dense (B×κ) grid.

    python scripts/eu_phase_contour.py <fingerprint_dense.csv> [out.png]

Draws the flux-closure order parameter ‖∇·F‖/‖∇F‖ (defines the flower phase:
low = flux-closure flower, ~0.577 = uniform FM) and |⟨F⟩|/F as smooth filled
contours over (B, κ), with the flower↔FM crossover as a bold contour curve —
the continuous analogue of Kawaguchi's mean-field phase boundaries. Pure-numpy
separable bilinear upsampling makes the curves smooth from a coarse grid.
"""
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

csv = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "eu_phase_contour.png"

rows = [l.rstrip("\n").split(",") for l in open(csv)]
h = {name: i for i, name in enumerate(rows[0])}
data = rows[1:]
c1 = np.array([float(r[h["c1_ratio"]]) for r in data])
sel = np.isclose(c1, c1.max())
B = np.array([float(r[h["B_uG"]]) for r in data])[sel]
K = np.array([float(r[h["kappa"]]) for r in data])[sel]
fc = np.array([float(r[h["fluxclosure"]]) for r in data])[sel]
mF = np.array([float(r[h["mF"]]) for r in data])[sel]

bs = np.unique(B); ks = np.unique(K)
def grid(v):
    Z = np.full((len(ks), len(bs)), np.nan)
    for b, k, val in zip(B, K, v):
        Z[np.where(ks == k)[0][0], np.where(bs == b)[0][0]] = val
    # fill any NaN by nearest along B (robustness to a few missing cells)
    for i in range(Z.shape[0]):
        m = np.isnan(Z[i])
        if m.any() and (~m).any():
            Z[i, m] = np.interp(np.flatnonzero(m), np.flatnonzero(~m), Z[i, ~m])
    return Z

def upsample(x, y, Z, fx=8, fy=8):
    """separable linear upsample of Z on grid (y,x) → smooth fine grid."""
    xf = np.linspace(x[0], x[-1], len(x) * fx)
    yf = np.linspace(y[0], y[-1], len(y) * fy)
    Z1 = np.vstack([np.interp(xf, x, Z[i]) for i in range(Z.shape[0])])   # along x
    Zf = np.column_stack([np.interp(yf, y, Z1[:, j]) for j in range(Z1.shape[1])])  # along y
    return xf, yf, Zf

FCg, MFg = grid(fc), grid(mF)
xf, yf, FCf = upsample(bs, ks, FCg)
_, _, MFf = upsample(bs, ks, MFg)

fig, axes = plt.subplots(1, 2, figsize=(13, 5.2))
# --- flux-closure ---
ax = axes[0]
cf = ax.contourf(xf, yf, FCf, levels=np.linspace(0, 0.7, 15), cmap="viridis", extend="max")
cs = ax.contour(xf, yf, FCf, levels=[0.15, 0.30, 0.45], colors="w", linewidths=1.1)
ax.clabel(cs, inline=True, fontsize=8, fmt="%.2f")
ax.contour(xf, yf, FCf, levels=[0.45], colors="crimson", linewidths=2.6)  # flower↔FM curve
fig.colorbar(cf, ax=ax, label=r"flux-closure $\|\nabla\!\cdot\!F\|/\|\nabla F\|$")
ax.set_title(r"flower (low, $\nabla\!\cdot\!F\approx0$) $\to$ uniform-FM crossover")
# --- |F| ---
ax2 = axes[1]
cf2 = ax2.contourf(xf, yf, MFf, levels=np.linspace(0, 1, 15), cmap="magma")
cs2 = ax2.contour(xf, yf, MFf, levels=[0.3, 0.5, 0.7, 0.9], colors="w", linewidths=1.0)
ax2.clabel(cs2, inline=True, fontsize=8, fmt="%.1f")
fig.colorbar(cf2, ax=ax2, label=r"$|\langle F\rangle|/F$")
ax2.set_title(r"magnetisation $|\langle F\rangle|/F$ (canting)")
for a in axes:
    a.set_xlabel("B (µG)"); a.set_ylabel(r"$\kappa=\omega_z/\omega_r$")
fig.suptitle(r"$^{151}$Eu F=6 GS: smooth order-parameter contours at $c_1=+1/36$ (32³ dense)", y=1.02)
fig.tight_layout()
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
