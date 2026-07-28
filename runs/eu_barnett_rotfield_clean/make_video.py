#!/usr/bin/env python3
"""Vortex-generation animation: +Omega / 0 / -Omega side by side.

Fixed layout (no shift), temporally interpolated for smoothness, high fps.
Density of the vortex-hosting component (dark = vortex core) + probability-
current streamlines (circulation = chirality) + fixed-width <L_z>,<F_z>
readout. Outputs an mp4 (pausable/scrubbable in any player / PowerPoint)
and an HTML wrapper with play/pause controls for presentations.
"""
import csv, os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, FFMpegWriter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "vortex_animation.mp4")
INTERP = 4      # temporal upsampling factor
FPS = 24
RUNS = [("vid_pos", r"$+\Omega$ (CCW)", "#4da3ff"),
        ("vid_zero", r"$\Omega=0$ (control)", "#bbbbbb"),
        ("vid_neg", r"$-\Omega$ (CW)", "#ff5b5b")]


def load_scalars(d):
    r = list(csv.DictReader(open(os.path.join(HERE, d, "scalars.csv"))))
    t = np.array([float(x["t"]) for x in r])
    Fz = np.array([float(x["Fz"]) for x in r])
    Lz = np.array([float(x["Lz"]) for x in r])
    return t, Fz, Lz


def load_stack(d, name, nf):
    a0 = np.loadtxt(os.path.join(HERE, d, f"f001_{name}.csv"), delimiter=",")
    stack = np.empty((nf,) + a0.shape)
    for i in range(nf):
        stack[i] = np.loadtxt(os.path.join(HERE, d, f"f{i+1:03d}_{name}.csv"), delimiter=",")
    return stack


def interp_stack(stack, factor):
    nf = stack.shape[0]
    src = np.arange(nf)
    dst = np.linspace(0, nf - 1, (nf - 1) * factor + 1)
    out = np.empty((len(dst),) + stack.shape[1:])
    for j, u in enumerate(dst):
        lo = int(np.floor(u)); hi = min(lo + 1, nf - 1); w = u - lo
        out[j] = (1 - w) * stack[lo] + w * stack[hi]
    return out, dst


def main():
    x = np.loadtxt(os.path.join(HERE, "vid_pos", "grid_x.csv"), delimiter=",")
    y = np.loadtxt(os.path.join(HERE, "vid_pos", "grid_y.csv"), delimiter=",")
    ext = [x.min(), x.max(), y.min(), y.max()]

    # Background = TOTAL column density (starts as the DDI-elongated
    # ellipse along the spin axis, then rotates/distorts as vortices form).
    data = {}
    nf = len(load_scalars("vid_pos")[0])
    for d, _, _ in RUNS:
        dens, _ = interp_stack(load_stack(d, "ncol", nf), INTERP)
        jx, _ = interp_stack(load_stack(d, "jx", nf), INTERP)
        jy, dst = interp_stack(load_stack(d, "jy", nf), INTERP)
        t, Fz, Lz = load_scalars(d)
        ti = np.interp(dst, np.arange(nf), t)
        Fzi = np.interp(dst, np.arange(nf), Fz)
        Lzi = np.interp(dst, np.arange(nf), Lz)
        data[d] = dict(host=dens, jx=jx, jy=jy, t=ti, Fz=Fzi, Lz=Lzi)
    NF = data["vid_pos"]["host"].shape[0]
    vmax = np.percentile(np.concatenate([data[d]["host"].ravel() for d, _, _ in RUNS]), 99.5)

    # --- FIXED layout: explicit axes rects, never re-laid-out ---
    fig = plt.figure(figsize=(13.5, 5.6))
    W, y0, h = 0.30, 0.06, 0.72
    lefts = [0.02, 0.35, 0.68]
    axes = [fig.add_axes([lefts[i], y0, W, h]) for i in range(3)]
    # fixed title text objects (updated content only)
    suptxt = fig.text(0.5, 0.965, "", ha="center", va="top", fontsize=13, family="monospace")
    fig.text(0.5, 0.915,
             r"total density (DDI-elongated ellipse, stretched along the spin) + current streamlines ($^{151}$Eu $F$=6)",
             ha="center", va="top", fontsize=10.5)
    headtxts, readtxts = [], []
    for i, (d, lbl, col) in enumerate(RUNS):
        cx = lefts[i] + W / 2
        fig.text(cx, 0.885, lbl, ha="center", va="top", fontsize=12, color=col, fontweight="bold")
        readtxts.append(fig.text(cx, 0.845, "", ha="center", va="top", fontsize=11,
                                 color=col, family="monospace"))

    def draw(fr):
        for ax, (d, lbl, col) in zip(axes, RUNS):
            ax.clear()
            D = data[d]
            ax.imshow(D["host"][fr].T, origin="lower", extent=ext, cmap="magma",
                      aspect="equal", vmin=0, vmax=vmax)
            ax.streamplot(x, y, D["jx"][fr].T, D["jy"][fr].T, color="cyan",
                          density=1.1, linewidth=0.7, arrowsize=0.9)
            ax.set_xlim(ext[0], ext[1]); ax.set_ylim(ext[2], ext[3])
            ax.set_xticks([]); ax.set_yticks([])
            for sp in ax.spines.values():
                sp.set_color(col); sp.set_linewidth(2.5)
        for (d, _, _), rt in zip(RUNS, readtxts):
            D = data[d]
            rt.set_text(f"Lz={D['Lz'][fr]:+5.2f}  Fz={D['Fz'][fr]:+5.2f}")
        suptxt.set_text(f"t = {data['vid_pos']['t'][fr]:5.1f} w_ref^-1")
        return []

    anim = FuncAnimation(fig, draw, frames=NF, blit=False)
    anim.save(OUT, writer=FFMpegWriter(fps=FPS, bitrate=4000,
              extra_args=["-pix_fmt", "yuv420p"]))
    print(f"wrote {OUT}  ({NF} frames @ {FPS} fps = {NF/FPS:.1f}s)")

    # HTML wrapper with play/pause + scrub controls for presentations
    html = os.path.join(HERE, "vortex_animation.html")
    with open(html, "w") as f:
        f.write(
            "<!doctype html><meta charset=utf-8>"
            "<title>Rotating-field vortex + Barnett</title>"
            "<body style='margin:0;background:#111;display:flex;justify-content:center'>"
            "<video src='vortex_animation.mp4' controls loop autoplay "
            "style='max-width:100vw;max-height:100vh'></video></body>")
    print(f"wrote {html} (play/pause/scrub in a browser)")


if __name__ == "__main__":
    main()
