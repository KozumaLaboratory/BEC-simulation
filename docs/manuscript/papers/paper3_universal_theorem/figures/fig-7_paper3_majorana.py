#!/usr/bin/env python3
"""Paper #3 FIG-7 renderer: polyhedral inert state Majorana configurations.

Reads `fig-7_paper3_majorana.csv` (one row per Majorana star — produced by
`scripts/cli.jl figure --paper paper3 --fig 6` via SpinorBEC.majorana_stars)
and renders a grid of Bloch spheres covering Paper #3 §V.A through §V.G.

Near-coincident stars are clustered (tol 0.05) so multiplicity-2 cases
(F=8 cube-octa, F=12 I:A) show one bold marker per geometric vertex with
size scaled by multiplicity.

Outputs:
    fig-7_paper3_majorana.pdf
    fig-7_paper3_majorana.svg
    fig-7_paper3_majorana.png
"""
import csv
import itertools
import os
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401  (3D projection register)


HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "fig-7_paper3_majorana.csv")
BASE = os.path.join(HERE, "fig-7_paper3_majorana")


def load_panels(csv_path):
    panels = defaultdict(lambda: {"F": None, "label": None, "ref": None,
                                  "x": [], "y": [], "z": []})
    with open(csv_path) as f:
        for r in csv.DictReader(f):
            p = int(r["panel_idx"])
            panels[p]["F"] = int(r["F"])
            panels[p]["label"] = r["label"]
            panels[p]["ref"] = r["ref"]
            panels[p]["x"].append(float(r["x"]))
            panels[p]["y"].append(float(r["y"]))
            panels[p]["z"].append(float(r["z"]))
    return [panels[k] for k in sorted(panels.keys())]


def cluster_stars(pts, tol=0.05):
    """Group near-coincident stars. Returns list of (centroid, multiplicity)."""
    clusters = []
    for p in pts:
        pa = np.array(p, dtype=float)
        for c in clusters:
            if np.linalg.norm(pa - c["centroid"]) < tol:
                c["centroid"] = (c["centroid"] * c["n"] + pa) / (c["n"] + 1)
                c["n"] += 1
                break
        else:
            clusters.append({"centroid": pa, "n": 1})
    return [(c["centroid"], c["n"]) for c in clusters]


def draw_bloch(ax, xs, ys, zs, *, edge_tol=0.06, cluster_tol=0.05):
    u = np.linspace(0, 2 * np.pi, 48)
    v = np.linspace(0, np.pi, 24)
    xu = np.outer(np.cos(u), np.sin(v))
    yu = np.outer(np.sin(u), np.sin(v))
    zu = np.outer(np.ones_like(u), np.cos(v))
    ax.plot_surface(xu, yu, zu, alpha=0.08, color="lightgray", linewidth=0)

    pts = list(zip(xs, ys, zs))
    clusters = cluster_stars(pts, tol=cluster_tol)
    centroids = np.array([c[0] for c in clusters])
    mults = [c[1] for c in clusters]

    n = len(centroids)
    if n >= 2:
        dists = []
        for i, j in itertools.combinations(range(n), 2):
            d = float(np.linalg.norm(centroids[i] - centroids[j]))
            dists.append((d, i, j))
        min_d = min(d for d, *_ in dists)
        for d, i, j in dists:
            if abs(d - min_d) < edge_tol:
                ax.plot(
                    [centroids[i][0], centroids[j][0]],
                    [centroids[i][1], centroids[j][1]],
                    [centroids[i][2], centroids[j][2]],
                    "-", color="black", lw=0.6, alpha=0.45,
                )

    sizes = [42 + 28 * (m - 1) for m in mults]
    ax.scatter(centroids[:, 0], centroids[:, 1], centroids[:, 2],
               s=sizes, color="C3", edgecolor="black",
               linewidths=0.6, zorder=10, depthshade=True)


def main():
    panels = load_panels(CSV)
    n_panels = len(panels)
    n_cols = 4
    n_rows = int(np.ceil(n_panels / n_cols))

    fig = plt.figure(figsize=(3.1 * n_cols, 3.4 * n_rows))
    for k, panel in enumerate(panels):
        ax = fig.add_subplot(n_rows, n_cols, k + 1, projection="3d")
        draw_bloch(ax, panel["x"], panel["y"], panel["z"])
        clusters = cluster_stars(list(zip(panel["x"], panel["y"], panel["z"])))
        n_geo = len(clusters)
        n_stars = len(panel["x"])
        if n_stars == n_geo:
            mult_note = f"{n_stars} stars"
        elif n_stars % n_geo == 0:
            mult_note = f"{n_stars} stars = {n_geo} × mult. {n_stars // n_geo}"
        else:
            # Mixed multiplicity (e.g. some 1×, some 2×).
            mult_note = f"{n_stars} stars on {n_geo} sites (mixed mult.)"
        title = f"{panel['label']}\n{panel['ref']} — {mult_note}"
        ax.set_title(title, fontsize=9, pad=4)
        ax.set_box_aspect((1, 1, 1))
        ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([])
        ax.set_xlim(-1.1, 1.1)
        ax.set_ylim(-1.1, 1.1)
        ax.set_zlim(-1.1, 1.1)
        ax.view_init(elev=18, azim=24)

    fig.suptitle(
        "Polyhedral inert state Majorana configurations (Paper #3 §V)",
        fontsize=11, y=0.995,
    )
    plt.tight_layout(rect=(0, 0, 1, 0.97))
    plt.savefig(BASE + ".pdf", bbox_inches="tight")
    plt.savefig(BASE + ".svg", bbox_inches="tight")
    plt.savefig(BASE + ".png", bbox_inches="tight", dpi=200)
    print(f"Wrote {BASE}.{{pdf,svg,png}}")


if __name__ == "__main__":
    main()
