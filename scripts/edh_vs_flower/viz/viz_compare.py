#!/usr/bin/env python3
"""EdH-vs-Flower comparison figures from the Mermin-Ho diagnostic HDF5 files.

Consumes the two outputs of `mermin_ho_diagnostic.jl` (one EdH, one Flower)
and renders the paper-grade diagnostic pack described in
docs/research_notes/edh_vs_flower_theory.md:

  fig1  end-state spatial maps   2 rows (EdH/Flower) x 4 cols
          |eps_z| (Mermin-Ho residual) | Omega_z | omega_z | |j|
  fig2  time-series overlay      max|eps|, dens-weighted mean|eps|,
          Q_sk, Q_3D, <Fz>, |<F_perp>|  (EdH vs Flower)
  fig3  Mermin-Ho scatter        omega_z vs F*Omega_z per midplane pixel,
          end-state (Flower hugs y=x; EdH scatters at vortex cores)
  fig4  spin precession          <Fx>,<Fy> lab-frame trajectory in time

HDF5.jl writes column-major, so multi-dim datasets read back axis-reversed in
h5py (the commit-3fa84637 gotcha): we `.T` every >1-D array to recover the
Julia (nf, nx, ny) logical order.

Usage:
  python viz_compare.py <edh_diag.h5> <flower_diag.h5> <out_dir>
"""
import sys, os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def load(path):
    """Load a diagnostic h5; transpose multi-dim arrays to Julia logical order."""
    d = {}
    with h5py.File(path, "r") as f:
        for k in f.keys():
            a = f[k][()]
            d[k] = a.T if (np.ndim(a) > 1) else a
    return d


def _imshow(ax, M, title, cmap, vmax=None, symmetric=False):
    if symmetric:
        v = vmax if vmax is not None else np.nanmax(np.abs(M))
        im = ax.imshow(M.T, origin="lower", cmap=cmap, vmin=-v, vmax=v)
    else:
        im = ax.imshow(M.T, origin="lower", cmap=cmap, vmin=0,
                       vmax=vmax if vmax is not None else None)
    ax.set_title(title, fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
    plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)


def fig_spatial(edh, flo, out):
    """End-state z-midplane maps, EdH (top) vs Flower (bottom)."""
    fig, axes = plt.subplots(2, 4, figsize=(15, 7.5))
    rows = [("EdH (quench)", edh), ("Flower (smooth)", flo)]
    for r, (label, d) in enumerate(rows):
        eps = np.abs(d["eps_z_mid"][-1])
        Om  = d["berry_z_mid"][-1]
        om  = d["vort_z_mid"][-1]
        jm  = d["jmag_mid"][-1]
        _imshow(axes[r, 0], eps, f"{label}\n|$\\epsilon_z$| = |$\\omega_z - F\\Omega_z$|", "inferno")
        _imshow(axes[r, 1], Om,  "Berry curvature $\\Omega_z$", "RdBu_r", symmetric=True)
        _imshow(axes[r, 2], om,  "vorticity $\\omega_z=(\\nabla\\times v_s)_z$", "RdBu_r", symmetric=True)
        _imshow(axes[r, 3], jm,  "mass current $|j|$", "viridis")
    fig.suptitle("EdH vs Flower — end-state z-midplane diagnostics", fontsize=13)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    p = os.path.join(out, "edh_vs_flower_spatial.png")
    fig.savefig(p, dpi=160); plt.close(fig)
    print("wrote", p)


def fig_timeseries(edh, flo, out):
    """Scalar diagnostics vs time, EdH vs Flower overlaid."""
    fig, axes = plt.subplots(2, 3, figsize=(15, 8))
    def perp(d):
        return np.hypot(d["Fx_avg"], d["Fy_avg"])
    panels = [
        ("max$|\\epsilon_z|$ (Mermin-Ho residual)", lambda d: d["eps_absmax"], "log"),
        ("density-weighted mean$|\\epsilon_z|$",     lambda d: d["eps_wmean"],  "log"),
        ("skyrmion charge $Q_{sk}$ (midplane)",      lambda d: d["Q_sk"],       "linear"),
        ("hedgehog charge $Q_{3D}$",                 lambda d: d["Q_3D"],       "linear"),
        ("$\\langle F_z\\rangle$ (spin, EdH transfer)", lambda d: d["Fz_avg"],  "linear"),
        ("$|\\langle F_\\perp\\rangle|$ (precession amp)", perp,               "linear"),
    ]
    for ax, (title, fn, scale) in zip(axes.flat, panels):
        for label, d, c in (("EdH", edh, "#d62728"), ("Flower", flo, "#1f77b4")):
            y = fn(d)
            ax.plot(d["t"], y, "-o", ms=3, color=c, label=label)
        ax.set_title(title, fontsize=10)
        ax.set_xlabel("t [internal]")
        if scale == "log":
            ax.set_yscale("log")
        ax.grid(True, alpha=0.3); ax.legend(fontsize=8)
    fig.suptitle("EdH vs Flower — diagnostic time series", fontsize=13)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    p = os.path.join(out, "edh_vs_flower_timeseries.png")
    fig.savefig(p, dpi=160); plt.close(fig)
    print("wrote", p)


def fig_mermin_ho_scatter(edh, flo, out):
    """Per-pixel omega_z vs F*Omega_z at end state: y=x ⇒ Mermin-Ho holds."""
    F = float(np.atleast_1d(edh["F"])[0])
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.6))
    for ax, (label, d) in zip(axes, (("EdH (quench)", edh), ("Flower (smooth)", flo))):
        om = d["vort_z_mid"][-1].ravel()
        rhs = F * d["berry_z_mid"][-1].ravel()
        # weight/visualise by point density via hexbin
        lim = np.nanpercentile(np.abs(np.concatenate([om, rhs])), 99.5)
        lim = lim if lim > 0 else 1.0
        ax.hexbin(rhs, om, gridsize=60, cmap="magma", bins="log",
                  extent=(-lim, lim, -lim, lim))
        ax.plot([-lim, lim], [-lim, lim], "c--", lw=1.2, label="Mermin-Ho  $\\omega_z=F\\Omega_z$")
        ax.set_xlabel("$F\\,\\Omega_z$  (texture / Berry RHS)")
        ax.set_ylabel("$\\omega_z=(\\nabla\\times v_s)_z$  (LHS)")
        ax.set_title(label, fontsize=11)
        ax.set_xlim(-lim, lim); ax.set_ylim(-lim, lim)
        ax.set_aspect("equal"); ax.legend(fontsize=8, loc="upper left")
    fig.suptitle("Mermin-Ho relation, end-state midplane pixels", fontsize=13)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    p = os.path.join(out, "edh_vs_flower_mermin_ho_scatter.png")
    fig.savefig(p, dpi=160); plt.close(fig)
    print("wrote", p)


def fig_precession(edh, flo, out):
    """Lab-frame <Fx>,<Fy> trajectory (spin precession), time-coloured."""
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.6))
    for ax, (label, d) in zip(axes, (("EdH (quench)", edh), ("Flower (smooth)", flo))):
        x, y, t = d["Fx_avg"], d["Fy_avg"], d["t"]
        sc = ax.scatter(x, y, c=t, cmap="viridis", s=18)
        ax.plot(x, y, "-", color="gray", lw=0.6, alpha=0.6)
        ax.set_xlabel("$\\langle F_x\\rangle$"); ax.set_ylabel("$\\langle F_y\\rangle$")
        ax.set_title(label, fontsize=11); ax.set_aspect("equal")
        ax.grid(True, alpha=0.3)
        plt.colorbar(sc, ax=ax, label="t [internal]", fraction=0.046, pad=0.04)
    fig.suptitle("Transverse spin precession $\\langle F_\\perp\\rangle(t)$", fontsize=13)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    p = os.path.join(out, "edh_vs_flower_precession.png")
    fig.savefig(p, dpi=160); plt.close(fig)
    print("wrote", p)


def main():
    if len(sys.argv) < 4:
        sys.exit("usage: viz_compare.py <edh_diag.h5> <flower_diag.h5> <out_dir>")
    edh = load(sys.argv[1])
    flo = load(sys.argv[2])
    out = sys.argv[3]
    os.makedirs(out, exist_ok=True)
    fig_spatial(edh, flo, out)
    fig_timeseries(edh, flo, out)
    fig_mermin_ho_scatter(edh, flo, out)
    fig_precession(edh, flo, out)
    print("done →", out)


if __name__ == "__main__":
    main()
