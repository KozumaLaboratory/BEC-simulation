#!/usr/bin/env python3
"""The z = 0 density + magnetization map of the lowest Fig. 5 cell.

The per-droplet circulation came out at |C| <= 0.74 with minima near 0.02,
where a magnetic vortex gives 1. That is either a wrong state or a wrong
segmentation, and the map decides which: the paper's Fig. 5(b) shows arrows
circulating around each droplet, so if ours does too the segmentation is at
fault, and if it does not the state is.

  python3 runs/saito_li_torus/h13_fig5_map.py
"""
import pathlib
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = pathlib.Path(__file__).parent / "out"


def main():
    maps = sorted(OUT.glob("fig5_*_map.csv"))
    if not maps:
        print(f"no fig5_*_map.csv in {OUT} — run h10_fig5_emit.jl first")
        return
    # lowest energy: read it from the paired line file's header
    best, bestE = None, None
    for m in maps:
        line = m.with_name(m.name.replace("_map.csv", "_line.csv"))
        if not line.exists():
            continue
        hdr = line.read_text().splitlines()[0]
        E = float(hdr.split("E=")[1].split()[0])
        if bestE is None or E < bestE:
            best, bestE = m, E
    if best is None:
        print("no paired line/map files")
        return
    d = np.genfromtxt(best, delimiter=",", names=True)
    xs = np.unique(d["x_um"])
    ys = np.unique(d["y_um"])
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    R = np.zeros_like(X)
    FX = np.zeros_like(X)
    FY = np.zeros_like(X)
    xi = {v: i for i, v in enumerate(xs)}
    yi = {v: i for i, v in enumerate(ys)}
    for row in d:
        i, j = xi[row["x_um"]], yi[row["y_um"]]
        R[i, j], FX[i, j], FY[i, j] = row["rho"], row["fx"], row["fy"]

    fig, ax = plt.subplots(figsize=(11.0, 3.2))
    im = ax.pcolormesh(X, Y, R, shading="auto", cmap="Greens")
    w = R > 0.06 * R.max()
    ax.quiver(X[w], Y[w], FX[w], FY[w], color="tab:purple", pivot="mid",
              width=0.002, scale=None)
    ax.set_xlabel("x  [µm]")
    ax.set_ylabel("y  [µm]")
    ax.set_aspect("equal")
    ax.set_title(f"Fig. 5(b) analogue — {best.stem.replace('fig5_','').replace('_map','')}"
                 f",  E/N = {bestE:.4f}")
    fig.colorbar(im, ax=ax, label="ρ  (internal)")
    fig.tight_layout()
    fig.savefig(OUT / "fig5_map.png", dpi=160)
    print(f"  wrote fig5_map.png   ({best.name}, E = {bestE:.6f})")
    print(f"  cloud spans x = {xs[R.max(axis=1) > 0.05*R.max()].min():.2f} .. "
          f"{xs[R.max(axis=1) > 0.05*R.max()].max():.2f} um")


if __name__ == "__main__":
    main()
