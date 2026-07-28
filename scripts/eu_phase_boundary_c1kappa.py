#!/usr/bin/env python3
"""Smooth Kawaguchi-style c1×κ phase diagram: FIT the boundary, don't contour noise.

    python scripts/eu_phase_boundary_c1kappa.py b0.csv [b10.csv b60.csv ...] [out.png]

A numerical GS phase map is jagged for two reasons: (1) linear interpolation of a
coarse grid facets, and (2) metastability makes the per-cell order parameter jump
between neighbours. Contouring that directly reproduces the noise. Instead we:

  • color the background by mF (bounded, smooth) after a pure-numpy Gaussian blur;
  • extract the transition locus c1*(κ) — per κ row, the c1 where mF crosses 0.5 —
    and fit it with a low-order polynomial → ONE smooth boundary curve per panel.

The fit averages over cell-to-cell metastability noise, giving a clean curve even
from a moderate grid (the way mean-field phase boundaries are drawn).
"""
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

args = sys.argv[1:]
out = "eu_phase_boundary_c1kappa.png"
if args and args[-1].endswith(".png"):
    out, args = args[-1], args[:-1]
csvs = args
assert csvs, "need at least one slice CSV"


def load(csv):
    rows = [l.rstrip("\n").split(",") for l in open(csv)]
    h = {n: i for i, n in enumerate(rows[0])}
    d = rows[1:]
    col = lambda k: np.array([float(r[h[k]]) for r in d])
    B = col("B_uG")
    return dict(c1=col("c1_ratio"), kappa=col("kappa"), mF=col("mF"),
                B=(B[0] if len(B) else float("nan")))


def to_grid(x, y, v):
    xs, ys = np.unique(x), np.unique(y)
    Z = np.full((len(ys), len(xs)), np.nan)
    for a, b, val in zip(x, y, v):
        Z[np.where(ys == b)[0][0], np.where(xs == a)[0][0]] = val
    for i in range(Z.shape[0]):                       # fill row gaps along x
        m = np.isnan(Z[i])
        if m.any() and (~m).any():
            Z[i, m] = np.interp(np.flatnonzero(m), np.flatnonzero(~m), Z[i, ~m])
    return xs, ys, Z


def gauss_blur(Z, sigma=1.2):
    """separable pure-numpy Gaussian blur (reflect edges)."""
    r = max(1, int(3 * sigma))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    def blur1(A):
        P = np.pad(A, ((0, 0), (r, r)), mode="reflect")
        return np.stack([np.convolve(P[i], k, "valid") for i in range(A.shape[0])])
    return blur1(blur1(Z.astype(float)).T).T


def upsample(x, y, Z, f=10):
    xf = np.linspace(x[0], x[-1], len(x) * f)
    yf = np.linspace(y[0], y[-1], len(y) * f)
    Z1 = np.vstack([np.interp(xf, x, Z[i]) for i in range(Z.shape[0])])
    Zf = np.column_stack([np.interp(yf, y, Z1[:, j]) for j in range(Z1.shape[1])])
    return xf, yf, Zf


def boundary_curve(xs, ys, Z, level=0.5, deg=2):
    """c1* where mF crosses `level`, per κ row; polynomial fit c1*(κ)."""
    kk, cc = [], []
    for i, k in enumerate(ys):
        row = Z[i]
        s = row - level
        for j in range(len(xs) - 1):
            if s[j] == 0 or s[j] * s[j + 1] < 0:      # sign change → crossing
                t = s[j] / (s[j] - s[j + 1])
                cc.append(xs[j] + t * (xs[j + 1] - xs[j]))
                kk.append(k)
                break
    if len(kk) < 2:
        return None
    kk, cc = np.array(kk), np.array(cc)
    d = min(deg, len(kk) - 1)
    p = np.polyfit(kk, cc, d)
    yf = np.linspace(ys[0], ys[-1], 200)
    return yf, np.polyval(p, yf), kk, cc


slices = [load(c) for c in csvs]
fig, axes = plt.subplots(1, len(slices), figsize=(5.4 * len(slices), 5.0),
                         squeeze=False, sharey=True)
axes = axes[0]
for ax, s in zip(axes, slices):
    xs, ys, MF = to_grid(s["c1"], s["kappa"], s["mF"])
    MFb = gauss_blur(MF, sigma=1.0)
    xf, yf, MFf = upsample(xs, ys, MFb)
    cf = ax.contourf(xf, yf, MFf, levels=np.linspace(0, 1, 21), cmap="RdBu_r")
    bc = boundary_curve(xs, ys, MFb, level=0.5, deg=2)
    if bc is not None:
        yb, xb, ky, kx = bc
        ax.plot(xb, yb, color="k", lw=3.0, zorder=5)              # smooth fitted boundary
        ax.plot(kx, ky, "o", color="k", ms=4, alpha=0.5, zorder=6)  # raw crossings
    ax.axvline(0.0, color="0.3", ls="--", lw=1.0)
    ax.axhline(1.0, color="0.5", ls=":", lw=0.9)
    ax.set_xlim(xs[0], xs[-1]); ax.set_ylim(ys[0], ys[-1])
    ax.set_title(rf"$B = {s['B']:.0f}\,\mu$G")
    ax.set_xlabel(r"$c_1/c_0$  (FM $<0$ | AFM $>0$)")
axes[0].set_ylabel(r"$\kappa=\omega_z/\omega_r$  (cigar $<1$ | pancake $>1$)")
cb = fig.colorbar(cf, ax=axes, fraction=0.025, pad=0.01)
cb.set_label(r"magnetisation $|\langle F\rangle|/F$  (blue polar $\to$ red FM)")
fig.suptitle(r"$^{151}$Eu F=6 GS $c_1\times\kappa$: fitted FM$\leftrightarrow$polar "
             r"boundary (mF=0.5) over smoothed magnetisation", y=1.03)
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
