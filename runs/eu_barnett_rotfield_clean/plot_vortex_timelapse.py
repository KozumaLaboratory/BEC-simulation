#!/usr/bin/env python3
"""Vortex-generation time-lapse: density + current streamlines, +Om vs -Om.

Shows the vortex-hosting component's density (dark = vortex core) with
probability-current streamlines (circulation sense = chirality) at
several times. Top row +Omega, bottom row -Omega -> opposite circulation.
"""
import os, glob
import numpy as np
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "vortex_timelapse")
FRAMES = [8, 15, 22, 29, 36]   # t ≈ 3.5, 7.5, 11, 14.5, 18


def load(snapdir, tag, frame, name):
    p = os.path.join(HERE, snapdir, f"O{tag}_f{frame}_{name}.csv")
    return np.loadtxt(p, delimiter=",") if os.path.exists(p) else None


def frame_time(snapdir, tag, frame):
    p = os.path.join(HERE, snapdir, f"O{tag}_f{frame}_meta.txt")
    if os.path.exists(p):
        for ln in open(p):
            if ln.startswith("t="):
                return float(ln.split("=")[1])
    return frame * 0.5


def main():
    x = np.loadtxt(os.path.join(HERE, "snaps_tv_pos", "grid_x.csv"), delimiter=",")
    y = np.loadtxt(os.path.join(HERE, "snaps_tv_pos", "grid_y.csv"), delimiter=",")
    X, Y = np.meshgrid(x, y)  # note: fields are [ix,iy], we plot .T

    fig, axes = plt.subplots(2, len(FRAMES), figsize=(3.0 * len(FRAMES), 6.2))
    rows = [("+0.50", "snaps_tv_pos", r"$+\Omega$ (CCW)", "#1f77b4"),
            ("-0.50", "snaps_tv_neg", r"$-\Omega$ (CW)", "#d62728")]

    for ri, (tag, snapdir, lbl, col) in enumerate(rows):
        for ci, fr in enumerate(FRAMES):
            ax = axes[ri, ci]
            dens = load(snapdir, tag, fr, "densvtx")
            jx = load(snapdir, tag, fr, "jx")
            jy = load(snapdir, tag, fr, "jy")
            t = frame_time(snapdir, tag, fr)
            if dens is not None:
                ax.imshow(dens.T, origin="lower", extent=[x.min(), x.max(), y.min(), y.max()],
                          cmap="magma", aspect="equal")
            if jx is not None and jy is not None:
                sp = max(1, len(x) // 24)
                spd = np.hypot(jx, jy)
                lw = 1.4 * (spd / (spd.max() + 1e-12)).T
                ax.streamplot(x, y, jx.T, jy.T, color="cyan", density=1.0,
                              linewidth=0.8, arrowsize=0.8)
            if ci == 0:
                ax.set_ylabel(lbl, fontsize=12, color=col, fontweight="bold")
            if ri == 0:
                ax.set_title(f"$t$={t:.1f}", fontsize=11)
            ax.set_xticks([]); ax.set_yticks([])
            for sp in ax.spines.values():
                sp.set_color(col); sp.set_linewidth(2)

    fig.suptitle("Vortex generation by a rotating magnetic field — density (vortex cores = dark) "
                 "+ current streamlines\n"
                 "$^{151}$Eu $F$=6, transverse $J_z{=}0$ start; circulation reverses with rotation direction",
                 fontsize=12, y=1.01)
    fig.tight_layout()
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
