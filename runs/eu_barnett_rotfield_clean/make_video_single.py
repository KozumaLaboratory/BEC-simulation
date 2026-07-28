#!/usr/bin/env python3
"""Single-panel spinning-ellipse video (one run): total column density +
current streamlines, fixed layout, interpolated, high fps. mp4 + html.

Usage: make_video_single.py <data_dir> <out_basename>
  data_dir has f###_ncol.csv, f###_jx.csv, f###_jy.csv, scalars.csv, grid_*.
"""
import csv, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, FFMpegWriter

HERE = os.path.dirname(os.path.abspath(__file__))
D = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "vid_rotbasis")
OUT = os.path.join(HERE, sys.argv[2] if len(sys.argv) > 2 else "spinning_ellipse")
INTERP, FPS = 4, 24


def scalars(d):
    r = list(csv.DictReader(open(os.path.join(d, "scalars.csv"))))
    return (np.array([float(x["t"]) for x in r]),
            np.array([float(x["Fz"]) for x in r]),
            np.array([float(x["Lz"]) for x in r]))


def stack(d, name, nf):
    a0 = np.loadtxt(os.path.join(d, f"f001_{name}.csv"), delimiter=",")
    s = np.empty((nf,) + a0.shape)
    for i in range(nf):
        s[i] = np.loadtxt(os.path.join(d, f"f{i+1:03d}_{name}.csv"), delimiter=",")
    return s


def interp(s, k):
    nf = s.shape[0]; dst = np.linspace(0, nf - 1, (nf - 1) * k + 1)
    out = np.empty((len(dst),) + s.shape[1:])
    for j, u in enumerate(dst):
        lo = int(np.floor(u)); hi = min(lo + 1, nf - 1); w = u - lo
        out[j] = (1 - w) * s[lo] + w * s[hi]
    return out, dst


def main():
    x = np.loadtxt(os.path.join(D, "grid_x.csv"), delimiter=",")
    y = np.loadtxt(os.path.join(D, "grid_y.csv"), delimiter=",")
    ext = [x.min(), x.max(), y.min(), y.max()]
    t, Fz, Lz = scalars(D); nf = len(t)
    dens, _ = interp(stack(D, "ncol", nf), INTERP)
    jx, _ = interp(stack(D, "jx", nf), INTERP)
    jy, dst = interp(stack(D, "jy", nf), INTERP)
    ti = np.interp(dst, np.arange(nf), t)
    Lzi = np.interp(dst, np.arange(nf), Lz)
    Fzi = np.interp(dst, np.arange(nf), Fz)
    NF = dens.shape[0]; vmax = np.percentile(dens, 99.5)

    fig = plt.figure(figsize=(6.6, 6.8))
    ax = fig.add_axes([0.02, 0.02, 0.96, 0.86])
    suptxt = fig.text(0.5, 0.975, "", ha="center", va="top", fontsize=13, family="monospace")
    fig.text(0.5, 0.935,
             r"Rotating $B$-field: DDI-magnetostriction ellipse spins with the field $\to$ stirs $\to$ vortices",
             ha="center", va="top", fontsize=10.5)
    rd = fig.text(0.5, 0.905, "", ha="center", va="top", fontsize=11, family="monospace")

    def draw(fr):
        ax.clear()
        ax.imshow(dens[fr].T, origin="lower", extent=ext, cmap="magma", aspect="equal", vmin=0, vmax=vmax)
        ax.streamplot(x, y, jx[fr].T, jy[fr].T, color="cyan", density=1.2, linewidth=0.7, arrowsize=1.0)
        ax.set_xlim(ext[0], ext[1]); ax.set_ylim(ext[2], ext[3]); ax.set_xticks([]); ax.set_yticks([])
        suptxt.set_text(f"t = {ti[fr]:6.1f} w_ref^-1")
        rd.set_text(f"Lz={Lzi[fr]:+5.2f}   Fz={Fzi[fr]:+5.2f}")
        return []

    anim = FuncAnimation(fig, draw, frames=NF, blit=False)
    anim.save(f"{OUT}.mp4", writer=FFMpegWriter(fps=FPS, bitrate=4000, extra_args=["-pix_fmt", "yuv420p"]))
    with open(f"{OUT}.html", "w") as f:
        f.write("<!doctype html><meta charset=utf-8><body style='margin:0;background:#111;"
                "display:flex;justify-content:center'>"
                f"<video src='{os.path.basename(OUT)}.mp4' controls loop autoplay "
                "style='max-width:100vw;max-height:100vh'></video></body>")
    print(f"wrote {OUT}.mp4/html ({NF} frames @ {FPS}fps)")


if __name__ == "__main__":
    main()
