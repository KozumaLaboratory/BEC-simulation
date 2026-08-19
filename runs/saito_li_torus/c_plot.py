#!/usr/bin/env python3
"""Figures for issue #336 (Li & Saito, arXiv:2402.18885) from the CSVs that
`c_figures.jl` emits.

  fig1d.png   density on z=0 and y=0 with the magnetization arrows — the layout
              of the paper's Fig. 1(a),(d) third panel
  fig2a.png   rho(r, z=0): eGPE (solid) against the paper's variational ansatz
              (dashed), which is exactly how the paper's Fig. 2(a) is drawn
  conv.png    the grid / box convergence arms on one axis

Linear axes, smooth curves for simulation output, markers only where a point
was actually measured.

  python3 runs/saito_li_torus/c_plot.py [cellname ...]
"""
import sys
import pathlib
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = pathlib.Path(__file__).parent / "out"


def load_map(path):
    """CSV written by c_figures.jl: header comment, then a row of column
    coords, then rows of (row-coord, values...)."""
    with open(path) as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    cols = np.array([float(v) for v in lines[0].split(",")[1:]])
    rows, vals = [], []
    for ln in lines[1:]:
        parts = ln.strip().split(",")
        rows.append(float(parts[0]))
        vals.append([float(v) for v in parts[1:]])
    return np.array(rows), cols, np.array(vals)


def load_profile(name):
    d = np.genfromtxt(OUT / f"profile_{name}.csv", delimiter=",", names=True)
    ok = np.isfinite(d["rho_N_um3"])
    return d["r_um"][ok], d["rho_N_um3"][ok]


def fig1d(name):
    xr, yc, rz = load_map(OUT / f"slice_z0_{name}.csv")
    xr2, zc, ry = load_map(OUT / f"slice_y0_{name}.csv")
    sp = np.genfromtxt(OUT / f"spin_z0_{name}.csv", delimiter=",", names=True)

    fig, ax = plt.subplots(1, 2, figsize=(9.2, 4.0),
                           gridspec_kw=dict(width_ratios=[1, 1]))
    im0 = ax[0].pcolormesh(yc, xr, rz, shading="auto", cmap="viridis")
    # magnetization arrows, scaled by local density so the empty core is quiet
    w = sp["rho_N_um3"] > 0.05 * sp["rho_N_um3"].max()
    ax[0].quiver(sp["y_um"][w], sp["x_um"][w], sp["fy"][w], sp["fx"][w],
                 color="w", scale=None, width=0.004, pivot="mid")
    ax[0].set_xlabel("y  [µm]")
    ax[0].set_ylabel("x  [µm]")
    ax[0].set_title(f"ρ and f on z = 0   ({name})")
    ax[0].set_aspect("equal")
    fig.colorbar(im0, ax=ax[0], label="ρ  [N µm⁻³]")

    # paper's lower panels of Fig. 1(d) are x horizontal, z vertical
    im1 = ax[1].pcolormesh(xr2, zc, ry.T, shading="auto", cmap="viridis")
    ax[1].set_xlabel("x  [µm]")
    ax[1].set_ylabel("z  [µm]")
    ax[1].set_title("ρ on y = 0")
    ax[1].set_aspect("equal")
    fig.colorbar(im1, ax=ax[1], label="ρ  [N µm⁻³]")
    fig.suptitle("Li–Saito Fig. 1(d) third panel:  F=6, N=15000, ε_dd=1.3",
                 y=1.00)
    fig.tight_layout()
    fig.savefig(OUT / f"fig1d_{name}.png", dpi=160, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote fig1d_{name}.png")


def fig2a(names):
    v = np.genfromtxt(OUT / "variational.csv", delimiter=",", names=True)
    fig, ax = plt.subplots(figsize=(6.0, 4.2))
    ax.plot(v["r_um"], v["rho_N_um3"], "--", color="0.35", lw=1.6,
            label="variational (paper Eqs. 2–3)")
    for n in names:
        r, rho = load_profile(n)
        ax.plot(r, rho, "-", lw=1.8, label=f"eGPE  {n}")
    ax.set_xlabel("r  [µm]")
    ax.set_ylabel("ρ(r, z = 0)  [N µm⁻³]")
    ax.set_title("Li–Saito Fig. 2(a):  F = 6, N = 15000, ε_dd = 1.3")
    ax.set_xlim(0, 2.2)
    ax.set_ylim(bottom=0)
    ax.legend(frameon=False)
    ax.grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(OUT / "fig2a.png", dpi=160)
    plt.close(fig)
    print("  wrote fig2a.png")


def conv(names):
    if len(names) < 2:
        return
    fig, ax = plt.subplots(figsize=(6.0, 4.2))
    for n in names:
        r, rho = load_profile(n)
        ax.plot(r, rho, lw=1.6, label=n)
    ax.set_xlabel("r  [µm]")
    ax.set_ylabel("ρ(r, z = 0)  [N µm⁻³]")
    ax.set_title("grid / box convergence of the torus profile")
    ax.set_xlim(0, 2.2)
    ax.set_ylim(bottom=0)
    ax.legend(frameon=False)
    ax.grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(OUT / "conv.png", dpi=160)
    plt.close(fig)
    print("  wrote conv.png")


def main():
    names = sys.argv[1:]
    if not names:
        names = sorted(p.name[len("profile_"):-len(".csv")]
                       for p in OUT.glob("profile_*.csv"))
    if not names:
        print(f"no profile_*.csv in {OUT} — run c_figures.jl first")
        return
    print("plotting:", ", ".join(names))
    for n in names:
        if (OUT / f"slice_z0_{n}.csv").exists():
            fig1d(n)
    fig2a(names)
    conv(names)


if __name__ == "__main__":
    main()
