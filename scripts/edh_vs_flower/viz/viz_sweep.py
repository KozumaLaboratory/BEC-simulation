#!/usr/bin/env python3
"""B-sweep ground-state landscape visualiser (viz suite script 3/3).

Consolidates the legacy plot_b_sweep* / energy-comparison family. Reads a set
of per-field ground-state caches (re-polished under the current scheme by
repolish_gs.jl) and renders:

  --view ebcurve   E(B) curve, colour-coded by LBFGS convergence tier, with a
                   Zeeman linear fit on the high-B (paramagnetic) branch and a
                   |∇E|(B) sub-panel.
  --view spatial   z-midplane m=−6 density across the B grid (one row of maps).
  --view all       both.

Each GS cache is a JLD2 with at least: psi, B_gauss, E, grad_norm (the format
written by repolish_gs.jl). h5py reads JLD2 directly. Files are discovered by
glob; B is read from each file (not the name) so ordering is robust.

Usage:
  python viz_sweep.py "<dir>/gs_*uG_repolished.jld2" --view all --out figures/
"""
import os, sys, glob, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

TIERS = [(5e-4, "target", "#2ca02c"), (1e-3, "tight", "#daa520"),
         (1e-2, "loose", "#ff7f0e"), (np.inf, "floor", "#d62728")]


def tier(g):
    for thr, name, col in TIERS:
        if g <= thr:
            return name, col
    return "floor", "#d62728"


def load_points(pattern):
    """Return sorted list of dicts {B_uG, E, grad, psi_path, key…} from caches."""
    pts = []
    for p in sorted(glob.glob(pattern)):
        try:
            with h5py.File(p, "r") as f:
                B = float(f["B_gauss"][()]) * 1e6 if "B_gauss" in f else np.nan   # Gauss→µG
                E = float(f["E"][()]) if "E" in f else np.nan
                g = float(f["grad_norm"][()]) if "grad_norm" in f else np.inf
                if not np.isfinite(g):
                    g = np.inf
            pts.append(dict(B=B, E=E, grad=g, path=p))
        except Exception as e:
            print(f"  skip {p}: {e}")
    pts.sort(key=lambda d: d["B"])
    return pts


def read_psi(path):
    with h5py.File(path, "r") as f:
        raw = f["psi"][()]                       # h5py (D,nz,ny,nx) compound
    psi = raw["re"].astype(float) + 1j * raw["im"].astype(float)
    return np.transpose(psi, (3, 2, 1, 0))       # (nx,ny,nz,D)


def fig_ebcurve(pts, out):
    Bs = np.array([p["B"] for p in pts]); Es = np.array([p["E"] for p in pts])
    Gs = np.array([p["grad"] for p in pts])
    fig, ax = plt.subplots(2, 1, figsize=(10, 8), sharex=True,
                           gridspec_kw=dict(height_ratios=[3, 1], hspace=0.05))
    for p in pts:
        _, col = tier(p["grad"])
        ax[0].scatter(p["B"], p["E"], c=col, s=70, zorder=3, edgecolors="k", linewidths=0.5)
    ax[0].plot(Bs, Es, color="lightgray", lw=0.6, alpha=0.5, zorder=1)
    hi = Bs >= 70
    if hi.sum() >= 2:
        sl, ic = np.polyfit(Bs[hi], Es[hi], 1)
        bf = np.linspace(Bs.min(), Bs.max(), 50)
        ax[0].plot(bf, sl * bf + ic, "--", color="grey", lw=1.2,
                   label=f"Zeeman fit (B≥70 µG): dE/dB={sl:+.4g}/µG")
    handles = [Line2D([0], [0], marker="o", color="w", markerfacecolor=c, markersize=9,
                      markeredgecolor="k", label=f"{n} (|∇|≤{t:g})")
               for t, n, c in TIERS[:-1]]
    handles.append(Line2D([0], [0], marker="o", color="w", markerfacecolor="#d62728",
                          markersize=9, markeredgecolor="k", label="floor (|∇|>1e-2)"))
    ax[0].legend(handles=handles, fontsize=9, loc="best")
    ax[0].set_ylabel("E [internal]"); ax[0].grid(alpha=0.3)
    ax[0].set_title("$^{151}$Eu b-sweep ground-state energy (re-polished, current scheme)")
    for p in pts:
        _, col = tier(p["grad"])
        ax[1].scatter(p["B"], p["grad"], c=col, s=50, zorder=3, edgecolors="k", linewidths=0.4)
    for t, _, c in TIERS[:-1]:
        ax[1].axhline(t, ls=":", lw=0.8, color=c, alpha=0.7)
    ax[1].set_yscale("log"); ax[1].set_xlabel("B [µG]"); ax[1].set_ylabel("|∇E|")
    ax[1].grid(which="both", alpha=0.25)
    fig.tight_layout()
    p = os.path.join(out, "b_sweep_energy_curve.png"); fig.savefig(p, dpi=160); plt.close(fig)
    print("wrote", p)


def fig_spatial(pts, out, F=6):
    n = len(pts); D = 2 * F + 1
    fig, axes = plt.subplots(1, n, figsize=(2.6 * n, 3.0))
    if n == 1:
        axes = [axes]
    for ax, p in zip(axes, pts):
        psi = read_psi(p["path"]); zc = psi.shape[2] // 2
        nm6 = np.abs(psi[:, :, zc, D - 1]) ** 2
        ax.imshow(nm6.T, origin="lower", cmap="inferno")
        ax.set_title(f"{p['B']:.0f} µG", fontsize=9); ax.set_xticks([]); ax.set_yticks([])
    fig.suptitle("b-sweep: m=−6 density (z-midplane)", fontsize=12)
    fig.tight_layout(rect=[0, 0, 1, 0.94])
    p = os.path.join(out, "b_sweep_spatial.png"); fig.savefig(p, dpi=150); plt.close(fig)
    print("wrote", p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pattern", help="glob of GS caches, e.g. 'dir/gs_*uG.jld2'")
    ap.add_argument("--view", default="all", choices=["ebcurve", "spatial", "all"])
    ap.add_argument("--out", default="figures")
    ap.add_argument("--F", type=int, default=6)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    pts = load_points(a.pattern)
    if not pts:
        sys.exit("no GS caches matched " + a.pattern)
    print(f"[sweep] {len(pts)} points, B ∈ [{pts[0]['B']:.0f}, {pts[-1]['B']:.0f}] µG")
    if a.view in ("ebcurve", "all"):
        fig_ebcurve(pts, a.out)
    if a.view in ("spatial", "all"):
        fig_spatial(pts, a.out, a.F)


if __name__ == "__main__":
    main()
