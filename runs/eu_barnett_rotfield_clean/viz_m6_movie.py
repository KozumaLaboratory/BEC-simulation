#!/usr/bin/env python3
"""fig_m6_spatial, animated — with a vortex indicator the m-panels cannot give.

Layout per frame (matching fig_m6_spatial.py): three rows for the l = +1, 0, -1
arms; columns are the total column density then m = -6 ... 0. Two additions:

  * the `total` panel and a new mid-plane panel carry the MASS-CURRENT vortices
    (o = +1, x = -1). The m-panel rings are NOT vortices — a spin texture whose
    direction varies with radius gives every m component a ring through the
    Wigner-d weighting, with or without any flow. Only the total density can
    answer the question, so only the total-density panels are marked.
  * a per-arm vortex count in each row label, and the raw circulation w of the
    marked defects in the suptitle. A discretised mass circulation is only
    approximately quantised; `STRICT` filters on |w - n|.

Colour scale: each panel is normalised by its own max over the WHOLE movie, not
per frame. Per-frame self-normalisation (which the static figure uses, correctly
for one time) would make a panel that empties out look unchanged.

  python runs/eu_barnett_rotfield_clean/viz_m6_movie.py [outfile.mp4]

Env: FPS=30  SECONDS=10  DPI=120  STRICT=0.25  SUF=lossy_
"""
import json
import os
import sys

import h5py
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter, FuncAnimation, PillowWriter

H = "runs/eu_barnett_rotfield_clean/rebuild_movie"
OUT = sys.argv[1] if len(sys.argv) > 1 else \
    "runs/eu_barnett_rotfield_clean/figures/fig_m6_spatial_movie.mp4"
FPS = int(os.environ.get("FPS", "30"))
SECONDS = float(os.environ.get("SECONDS", "10"))
DPI = int(os.environ.get("DPI", "120"))
STRICT = float(os.environ.get("STRICT", "0.25"))
SUF = os.environ.get("SUF", "lossy_")

ROWS = [("ellp1", r"$\ell=+1$", "l=+1"), ("ellp0", r"$\ell=0$", "l=0"),
        ("ellm1", r"$\ell=-1$", "l=-1")]
MS = [-6, -5, -4, -3, -2, -1, 0]
COLS = [("tot", "total")] + [(f"m{m}", f"$m={m}$") for m in MS] + [("nmid", "mid-plane total")]

arms = {}
for tag, _, _ in ROWS:
    p = os.path.join(H, f"m6mov_{SUF}{tag}.jld2")
    if not os.path.isfile(p):
        sys.exit(f"missing {p} — run run_m6_movie.jl first")
    arms[tag] = h5py.File(p, "r")

n_frames = min(int(np.asarray(arms[t]["n_frames"])) for t, _, _ in ROWS)
times = np.asarray(arms[ROWS[0][0]]["times"], dtype=float)[:n_frames]
box = np.asarray(arms[ROWS[0][0]]["box"], dtype=float)
ext = [-box[0] / 2, box[0] / 2, -box[1] / 2, box[1] / 2]


def rd(tag, name, i):
    return np.asarray(arms[tag][f"{name}_{i + 1:05d}"])


n_target = max(1, int(round(FPS * SECONDS)))
sel = np.linspace(0, n_frames - 1, n_target).round().astype(int)
if len(np.unique(sel)) < n_frames:
    print(f"note: {n_frames} frames subsampled to {len(np.unique(sel))}")

# Fixed per-panel scales over the whole movie (see module docstring).
probe = sel[:: max(1, len(sel) // 10)]
vmax = {(tag, comp): max(float(rd(tag, comp, i).max()) for i in probe) or 1.0
        for tag, _, _ in ROWS for comp, _ in COLS}

fig, ax = plt.subplots(3, len(COLS), figsize=(1.85 * len(COLS), 6.6))
ims, marks, titles = {}, {}, {}
for r, (tag, rl, plain) in enumerate(ROWS):
    for c, (comp, cl) in enumerate(COLS):
        a = ax[r, c]
        ims[(tag, comp)] = a.imshow(rd(tag, comp, sel[0]).T, origin="lower",
                                    extent=ext, cmap="magma", vmin=0,
                                    vmax=vmax[(tag, comp)])
        titles[(tag, comp)] = a.set_title("", fontsize=8.0)
        a.set_xticks([])
        a.set_yticks([])
        if comp in ("tot", "nmid"):
            (p,) = a.plot([], [], "o", mfc="none", mec="w", ms=8, mew=1.4)
            (n,) = a.plot([], [], "x", mec="cyan", ms=8, mew=1.4)
            marks[(tag, comp)] = (p, n)
    ax[r, 0].set_ylabel(rl, fontsize=11)
sup = fig.suptitle("", fontsize=10.5)


def draw(k):
    i = sel[k]
    parts = []
    for tag, rl, plain in ROWS:
        tot = rd(tag, "tot", i)
        tsum = tot.sum()
        for comp, cl in COLS:
            d = rd(tag, comp, i)
            ims[(tag, comp)].set_data(d.T)
            if comp == "tot":
                titles[(tag, comp)].set_text(f"{rl} total")
            elif comp == "nmid":
                titles[(tag, comp)].set_text("mid-plane total")
            else:
                titles[(tag, comp)].set_text(f"{cl} ({100 * d.sum() / tsum:.0f}%)")

        vx, vy, vq, vw = (rd(tag, s, i) for s in ("vx", "vy", "vq", "vw"))
        keep = np.abs(vw - vq) < STRICT if len(vq) else np.zeros(0, bool)
        nx, ny = tot.shape
        px = (vx / nx - 0.5) * box[0]
        py = (vy / ny - 0.5) * box[1]
        for comp in ("tot", "nmid"):
            p, n = marks[(tag, comp)]
            p.set_data(px[keep & (vq > 0)], py[keep & (vq > 0)])
            n.set_data(px[keep & (vq < 0)], py[keep & (vq < 0)])
        net = int(vq[keep].sum()) if keep.any() else 0
        parts.append(f"{plain}: {int(keep.sum())} vortices (net {net:+d})")
    sup.set_text(f"t = {times[i]:.2f}   per-$m$ column density (own max over the movie)"
                 f"   —   mass-current vortices, $|w-n|<{STRICT}$   |   "
                 + "   ".join(parts))
    return []


fig.tight_layout(rect=(0, 0, 1, 0.93))
ani = FuncAnimation(fig, draw, frames=len(sel), blit=False)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
try:
    ani.save(OUT, writer=FFMpegWriter(fps=FPS, bitrate=6000), dpi=DPI)
except (FileNotFoundError, RuntimeError):
    OUT = os.path.splitext(OUT)[0] + ".gif"
    print("ffmpeg unavailable — GIF fallback")
    ani.save(OUT, writer=PillowWriter(fps=FPS), dpi=DPI)
print(f"wrote {OUT}  ({len(sel)} frames @ {FPS} fps ≈ {len(sel) / FPS:.1f} s)")
