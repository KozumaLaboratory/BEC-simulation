#!/usr/bin/env python3
"""Quantitative spin-texture cross-sections, EdH vs Flower at a target time.
Per-particle spin s = <F>/n (bounded by F), NO arbitrary normalisation:
  - background = out-of-plane spin component, fixed physical clim [-F, +F]
  - in-plane arrows = real per-particle (s_a, s_b), common physical scale, reference arrow
  - density contour for the cloud outline
Planes: xy(z=mid)  xz(y=mid)  yz(x=mid).
env: TARGET_MS (default 200), OUT_PNG.
"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

SCR = os.path.dirname(os.path.abspath(__file__))
DIAG = os.path.join(os.path.expanduser("~"),
    "Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/"
    "runs/eu151_edh_vs_flower/figures/newscheme_8004024")
TARGET = float(os.environ.get("TARGET_MS", "200"))
OUT = os.environ.get("OUT_PNG", os.path.join(SCR, "fig_spintexture.png"))
OMEGA = 691.15

def load(sp, dg):
    s = h5py.File(os.path.join(SCR, sp), "r")
    d = h5py.File(os.path.join(DIAG, dg), "r")
    dt = np.asarray(d["t"]); nf = s["Fz_3d"].shape[-1]
    t_ms = dt[np.clip(np.arange(nf)*2, 0, len(dt)-1)] / OMEGA * 1000.0
    L = float(s["meta/L_box"][()])
    return s, t_ms, L

def spin_pp(s, fr, n_floor_frac=0.05):
    """per-particle spin sx,sy,sz = F/n masked where n small; plus density."""
    Fx = s["Fx_3d"][..., fr].astype(float); Fy = s["Fy_3d"][..., fr].astype(float)
    Fz = s["Fz_3d"][..., fr].astype(float); n = s["n_total_3d"][..., fr].astype(float)
    nf = n_floor_frac * n.max()
    safe = n > nf
    sx = np.where(safe, Fx/np.where(safe, n, 1), np.nan)
    sy = np.where(safe, Fy/np.where(safe, n, 1), np.nan)
    sz = np.where(safe, Fz/np.where(safe, n, 1), np.nan)
    return sx, sy, sz, n

edh = load("edh_spin3d.jld2", "edh_diag.jld2")
flo = load("flower_spin3d.jld2", "flower_diag.jld2")
F = 6.0

fig, axes = plt.subplots(2, 3, figsize=(15, 9.6), constrained_layout=True)
planes = ["xy (z=0)", "xz (y=0)", "yz (x=0)"]

for row, (s, t_ms, L) in enumerate([edh, flo]):
    Ng = s["Fz_3d"].shape[0]
    fr = int(np.argmin(np.abs(t_ms - TARGET)))
    sx, sy, sz, n = spin_pp(s, fr)
    zc = yc = xc = Ng // 2
    ax1d = np.linspace(-L/2, L/2, Ng)
    XX, YY = np.meshgrid(ax1d, ax1d, indexing="ij")
    ext = [-L/2, L/2, -L/2, L/2]
    # (out-of-plane bg, in-plane a, in-plane b, density-slice)
    cfg = [
        (sz[:, :, zc], sx[:, :, zc], sy[:, :, zc], n[:, :, zc], "x [μm]", "y [μm]", r"$s_z$"),
        (sy[:, yc, :], sx[:, yc, :], sz[:, yc, :], n[:, yc, :], "x [μm]", "z [μm]", r"$s_y$"),
        (sx[xc, :, :], sy[xc, :, :], sz[xc, :, :], n[xc, :, :], "y [μm]", "z [μm]", r"$s_x$"),
    ]
    for col, (bg, fa, fb, dens, xl, yl, bglab) in enumerate(cfg):
        ax = axes[row, col]
        im = ax.imshow(bg.T, origin="lower", extent=ext, cmap="RdBu_r",
                       vmin=-F, vmax=F, aspect="equal")
        sk = 1
        q = ax.quiver(XX[::sk, ::sk], YY[::sk, ::sk], fa[::sk, ::sk], fb[::sk, ::sk],
                      angles="xy", scale_units="xy", scale=F/1.2, width=0.005,
                      color="k", alpha=0.8)
        if row == 0 and col == 0:
            ax.quiverkey(q, 0.86, 1.04, F, r"$|s_\perp|=%g$" % F, labelpos="E",
                         coordinates="axes", fontproperties={"size": 9})
        ax.contour(XX, YY, dens, levels=[0.2*np.nanmax(dens), 0.6*np.nanmax(dens)],
                   colors="0.3", linewidths=0.6, alpha=0.6)
        ax.set_xlabel(xl); ax.set_ylabel(yl)
        leg = ["EdH (non-adiabatic)", "Flower (adiabatic)"][row]
        ax.set_title(f"{leg}   {planes[col]}\nbg = {bglab},  arrows = in-plane spin", fontsize=10)
        fig.colorbar(im, ax=ax, shrink=0.78, label=bglab + r"  (per particle, $\pm F$)")
    axes[row, 0].text(-0.32, 0.5, f"t = {t_ms[fr]:.0f} ms", transform=axes[row, 0].transAxes,
                      rotation=90, va="center", fontsize=12, fontweight="bold")

fig.suptitle(f"Spin-texture cross-sections  (per-particle spin $s=\\langle F\\rangle/n$, fixed scale ±{F:g})   target t≈{TARGET:.0f} ms",
             fontsize=13)
fig.savefig(OUT, dpi=120)
print("wrote", OUT, "| EdH fr t=%.0f, Flower fr t=%.0f" % (
    edh[1][np.argmin(np.abs(edh[1]-TARGET))], flo[1][np.argmin(np.abs(flo[1]-TARGET))]))
