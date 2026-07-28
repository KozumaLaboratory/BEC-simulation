#!/usr/bin/env python3
"""Animate the pinned weak-field ¹⁵¹Eu+DDI ground state vs magnetic field.

Reads the per-frame CSVs from eu_bscan_pinned_continuation.jl and renders a
4-panel animation sweeping B from high to low field:
  1. density n(x,y)
  2. transverse-spin |F⊥| (colour) + spin DIRECTION as UNIT arrows (normalised,
     so they never overlap — length carries no info, only direction)
  3. F_z(x,y)
  4. m-population bar

Physics regimes (labelled per frame): the radial spin texture ("flower") lives
in the polarised regime B≳60 µG; below it the cloud depolarises and the pinned
transverse spin becomes uniform (NOT a flower).

  python scripts/viz_eu_bscan_animation.py [figs/eu_bscan_pin_tight] [out.mp4]
Env BMAX (µG, default 90) drops the trivial high-field tail above that value.
"""
import os
import sys
import glob
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, FFMpegWriter, PillowWriter

D = sys.argv[1] if len(sys.argv) > 1 else "figs/eu_bscan_pin_tight"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(D, "eu_bscan.mp4")
BMAX = float(os.environ.get("BMAX", "90"))
FLOWER_B = 58.0   # radial flower texture lives above ~this field

manifest = np.atleast_2d(
    np.loadtxt(os.path.join(D, "frames.csv"), delimiter="\t", skiprows=1))
all_frames = sorted(glob.glob(os.path.join(D, "frame_*")))
pairs = [(fr, row[1]) for fr, row in zip(all_frames, manifest) if row[1] <= BMAX + 1e-9]
if not pairs:
    sys.exit(f"no frames with B <= {BMAX} µG under {D}")
frames = [p[0] for p in pairs]
b_ug = np.array([p[1] for p in pairs])
print(f"{len(frames)} frames with B <= {BMAX} µG (of {len(all_frames)} computed)")


def load(fr, name):
    return np.loadtxt(os.path.join(fr, name), delimiter="\t")


dmax = max(load(fr, "density_xy.csv").max() for fr in frames)
fpmax = max(load(fr, "fperp_xy.csv").max() for fr in frames)
fzabs = max(np.abs(load(fr, "fz_xy.csv")).max() for fr in frames)

d0 = load(frames[0], "density_xy.csv")
N = d0.shape[0]
sk = max(1, N // 20)
idx = np.arange(0, N, sk)
GX, GY = np.meshgrid(idx, idx, indexing="ij")

fig, ax = plt.subplots(1, 4, figsize=(19, 5.0))


def regime(B):
    if B >= FLOWER_B:
        return "flower — radial spin texture", "#38b000"
    if B >= 24:
        return "transition — depolarising", "#f48c06"
    return "uniform pinned — depolarised", "#9d4edd"


def draw(i):
    for a in ax:
        a.clear()
    fr = frames[i]
    dens = load(fr, "density_xy.csv")
    fx, fy = load(fr, "fx_xy.csv"), load(fr, "fy_xy.csv")
    fz, fperp = load(fr, "fz_xy.csv"), load(fr, "fperp_xy.csv")
    pops = load(fr, "populations.csv")
    mask = dens > 0.08 * dmax
    mag = np.hypot(fx, fy)
    u = np.where(mask, fx / (mag + 1e-9), np.nan)
    v = np.where(mask, fy / (mag + 1e-9), np.nan)

    ax[0].imshow(dens.T, origin="lower", cmap="inferno", vmin=0, vmax=dmax)
    ax[0].set_title("density  n(x,y)")

    ax[1].imshow(fperp.T, origin="lower", cmap="magma", vmin=0, vmax=fpmax)
    ax[1].quiver(GX, GY, u[::sk, ::sk], v[::sk, ::sk],
                 color="cyan", scale=26, width=0.006, pivot="mid")
    ax[1].set_title("transverse spin |F⊥| + direction (unit arrows)")

    ax[2].imshow(fz.T, origin="lower", cmap="RdBu_r", vmin=-fzabs, vmax=fzabs)
    ax[2].set_title("F_z density  (blue = spin-down / polarised)")

    ax[3].bar(pops[:, 0], pops[:, 1], color="steelblue")
    ax[3].set_ylim(0, 1)
    ax[3].set_xlabel("m")
    ax[3].set_title("populations")

    for a in (ax[0], ax[1], ax[2]):
        a.set_xticks([])
        a.set_yticks([])

    label, colour = regime(b_ug[i])
    fig.suptitle(f"¹⁵¹Eu F=6 + DDI  pinned GS   B = {b_ug[i]:5.1f} µG    [{label}]",
                 fontsize=15, color=colour)
    return []


anim = FuncAnimation(fig, draw, frames=len(frames), blit=False)
fps = 10
try:
    if OUT.endswith(".gif"):
        raise RuntimeError("gif requested")
    anim.save(OUT, writer=FFMpegWriter(fps=fps, bitrate=4000))
    print(f"wrote {OUT}")
except Exception as e:
    OUT = os.path.splitext(OUT)[0] + ".gif"
    anim.save(OUT, writer=PillowWriter(fps=fps))
    print(f"ffmpeg unavailable ({e}); wrote {OUT}")
