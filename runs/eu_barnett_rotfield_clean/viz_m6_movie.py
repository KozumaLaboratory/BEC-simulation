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

Colour scale: each panel is self-normalised PER FRAME, exactly as
fig_m6_spatial.py does. This is not a cosmetic choice. Fixing vmax over the
whole movie instead pushes the late frames — which have lost ~37% of their atoms
to K3 — into the bottom of the colormap, and the vortex core stops being
visible: on the l=-1 arm at t=50 the core sits at 10% of peak, which reads as a
hole against a per-frame scale and as uniform dark against a movie-wide one. The
structure is the whole point, so it wins.
Absolute scale is not lost: each panel's own max is printed, so decay is still
readable. `NORM=movie` restores the fixed-scale behaviour.

  python runs/eu_barnett_rotfield_clean/viz_m6_movie.py [outfile.mp4]

Env: FPS=30  SECONDS=10  DPI=120  STRICT=0.25  SUF=lossy_  NORM=frame|movie
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
NORM = os.environ.get("NORM", "frame")

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


# NOTE ON ORIENTATION — do not add `.T` back.
# JLD2 writes column-major and h5py reads row-major, so an array Julia stored as
# [ix, iy] arrives here ALREADY transposed. Transposing again swaps x and y,
# which maps every angle theta -> 90 - theta and therefore REVERSES the apparent
# sense of rotation. That is exactly what it did: the cloud appeared to
# counter-rotate against the field bar while every number agreed, because the
# numbers came from Julia (correct axes) and only the picture was flipped.
# Verified by shape: side_ is [ix, iz] = (32, 16) in Julia and reads as (16, 32).


def rd(tag, name, i):
    return np.asarray(arms[tag][f"{name}_{i + 1:05d}"])


n_target = max(1, int(round(FPS * SECONDS)))
sel = np.linspace(0, n_frames - 1, n_target).round().astype(int)
if len(np.unique(sel)) < n_frames:
    print(f"note: {n_frames} frames subsampled to {len(np.unique(sel))}")

# Only used when NORM=movie (see module docstring).
probe = sel[:: max(1, len(sel) // 10)]
vmax = {(tag, comp): max(float(rd(tag, comp, i).max()) for i in probe) or 1.0
        for tag, _, _ in ROWS for comp, _ in COLS}

fig, ax = plt.subplots(3, len(COLS), figsize=(1.85 * len(COLS), 6.6))
ims, marks, titles = {}, {}, {}
for r, (tag, rl, plain) in enumerate(ROWS):
    for c, (comp, cl) in enumerate(COLS):
        a = ax[r, c]
        ims[(tag, comp)] = a.imshow(rd(tag, comp, sel[0]), origin="lower",
                                    extent=ext, cmap="magma", vmin=0,
                                    vmax=vmax[(tag, comp)])
        titles[(tag, comp)] = a.set_title("", fontsize=8.0)
        a.set_xticks([])
        a.set_yticks([])
        if comp in ("tot", "nmid"):
            # RING the core, do not cover it. An `x` drawn on the defect sits
            # exactly on top of the density hole it is pointing at — the core
            # is ~2 cells across and the marker hid it completely. Open circles
            # wider than the core, sign by colour: white +1, cyan -1.
            (p,) = a.plot([], [], "o", mfc="none", mec="w", ms=17, mew=1.5)
            (n,) = a.plot([], [], "o", mfc="none", mec="cyan", ms=17, mew=1.5)
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
            ims[(tag, comp)].set_data(d)
            if NORM == "frame":
                hi = float(d.max())
                ims[(tag, comp)].set_clim(0.0, hi if hi > 0 else 1.0)
            if comp == "tot":
                titles[(tag, comp)].set_text(f"{rl} total (max {d.max():.3g})")
            elif comp == "nmid":
                titles[(tag, comp)].set_text(f"mid-plane total (max {d.max():.3g})")
            else:
                titles[(tag, comp)].set_text(f"{cl} ({100 * d.sum() / tsum:.0f}%)")

        vx, vy, vq, vw = (rd(tag, s, i) for s in ("vx", "vy", "vq", "vw"))
        keep = np.abs(vw - vq) < STRICT if len(vq) else np.zeros(0, bool)
        # `tot` reads as [iy, ix]: Julia's x index maps to COLUMNS.
        ny, nx = tot.shape
        px = (vx / nx - 0.5) * box[0]
        py = (vy / ny - 0.5) * box[1]
        for comp in ("tot", "nmid"):
            p, n = marks[(tag, comp)]
            p.set_data(px[keep & (vq > 0)], py[keep & (vq > 0)])
            n.set_data(px[keep & (vq < 0)], py[keep & (vq < 0)])
        net = int(vq[keep].sum()) if keep.any() else 0
        parts.append(f"{plain}: {int(keep.sum())} vortices (net {net:+d})")
    scale = "self-normalised per frame" if NORM == "frame" else "fixed over the movie"
    sup.set_text(f"t = {times[i]:.2f}   per-$m$ column density ({scale})"
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
