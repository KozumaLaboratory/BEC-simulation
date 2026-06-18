#!/usr/bin/env python3
"""
Compare the m=-5 density channel for Goto RTP and LBFGS B-sweep.

This is a static inspection figure aimed at the "donut-like" question:
  - does the m=-5 density have a central hole?
  - is it stronger in xy or xz?

Panels:
  row 1: Goto final snapshot
  row 2: B-sweep at B=65 μG
  col 1: xy slice
  col 2: xz slice

The figure also prints simple ringness diagnostics:
  center / max and annulus_mean / center.
"""
import os
import numpy as np
import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams.update({
    "font.size": 12,
    "axes.titlesize": 13,
    "axes.labelsize": 12,
    "xtick.labelsize": 10,
    "ytick.labelsize": 10,
    "axes.linewidth": 0.8,
})

ROOT = os.environ.get("FPE_ROOT", "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
GOTO_H5 = os.environ.get("GOTO_H5", os.path.join(ROOT, "rtp_10mG_goto.h5"))
BSWEEP_H5 = os.environ.get("BSWEEP_H5", os.path.join(ROOT, "b_sweep.h5"))
OUT_PNG = os.environ.get("OUT_PNG", os.path.join(ROOT, "m5_density_compare.png"))


def load_channel(path, final_only=True, B_target=65.0):
    with h5py.File(path, "r") as f:
        m_channels = f["meta/m_channels"][:]
        ci = int(np.where(m_channels == -5)[0][0])
        Lbox = float(f["meta/L_box"][()])
        NX = int(f["meta/NX"][()])
        dx = Lbox / NX
        xs = -Lbox / 2 + dx * np.arange(NX) + dx / 2
        extent = [xs[0] - dx / 2, xs[-1] + dx / 2, xs[0] - dx / 2, xs[-1] + dx / 2]

        n_xy = np.transpose(f["n_m_xy"][:], (3, 2, 1, 0))
        n_xz = np.transpose(f["n_m_xz"][:], (3, 2, 1, 0))

        if "B_uG" in f:
            B = f["B_uG"][:]
            order = np.argsort(B)[::-1]
            B = B[order]
            n_xy = n_xy[order]
            n_xz = n_xz[order]
            if final_only:
                k = int(np.where(B == B_target)[0][0])
            else:
                k = 0
            label = f"B = {B[k]:.0f} μG"
        else:
            k = -1
            label = "final RTP snapshot"

        im_xy = n_xy[k, ci].T
        im_xz = n_xz[k, ci].T
        return dict(extent=extent, NX=NX, im_xy=im_xy, im_xz=im_xz, label=label)


def ring_stats(im):
    nx = im.shape[0]
    cx = nx // 2
    center = float(im[cx, cx])
    maxv = float(np.max(im))
    xx, yy = np.meshgrid(np.arange(nx), np.arange(nx), indexing="xy")
    rr = np.sqrt((xx - cx) ** 2 + (yy - cx) ** 2)
    ann = im[(rr >= 4) & (rr <= 10)]
    ann_mean = float(np.mean(ann))
    return center, maxv, ann_mean


goto = load_channel(GOTO_H5, final_only=True)
sweep = load_channel(BSWEEP_H5, final_only=True, B_target=65.0)

vmax = max(
    float(np.max(goto["im_xy"])),
    float(np.max(goto["im_xz"])),
    float(np.max(sweep["im_xy"])),
    float(np.max(sweep["im_xz"])),
)

fig, axes = plt.subplots(2, 2, figsize=(12.5, 11.0), constrained_layout=True)
items = [
    (axes[0, 0], goto["im_xy"], goto["extent"], "Goto final", "xy"),
    (axes[0, 1], goto["im_xz"], goto["extent"], "Goto final", "xz"),
    (axes[1, 0], sweep["im_xy"], sweep["extent"], "B-sweep @ 65 μG", "xy"),
    (axes[1, 1], sweep["im_xz"], sweep["extent"], "B-sweep @ 65 μG", "xz"),
]

for ax, im, extent, row_label, view in items:
    m = ax.imshow(
        im,
        extent=extent,
        origin="lower",
        vmin=0,
        vmax=vmax,
        cmap="magma",
        aspect="equal",
        interpolation="bilinear",
    )
    ax.set_title(f"{row_label}  |  m=-5  ({view})")
    ax.set_xlabel("x [μm]")
    ax.set_ylabel("y [μm]" if view == "xy" else "z [μm]")
    ax.set_xticks(np.linspace(extent[0], extent[1], 5))
    ax.set_yticks(np.linspace(extent[2], extent[3], 5))
    cb = plt.colorbar(m, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$|\psi_{m=-5}|^2$")

stats = {
    "goto_xy": ring_stats(goto["im_xy"]),
    "goto_xz": ring_stats(goto["im_xz"]),
    "sweep_xy": ring_stats(sweep["im_xy"]),
    "sweep_xz": ring_stats(sweep["im_xz"]),
}

summary = (
    f"Goto xy: center/max={stats['goto_xy'][0]/stats['goto_xy'][1]:.4f}, "
    f"ann/center={stats['goto_xy'][2]/stats['goto_xy'][0]:.1f}\n"
    f"Goto xz: center/max={stats['goto_xz'][0]/stats['goto_xz'][1]:.4f}, "
    f"ann/center={stats['goto_xz'][2]/stats['goto_xz'][0]:.1f}\n"
    f"Sweep xy: center/max={stats['sweep_xy'][0]/stats['sweep_xy'][1]:.4f}, "
    f"ann/center={stats['sweep_xy'][2]/stats['sweep_xy'][0]:.1f}\n"
    f"Sweep xz: center/max={stats['sweep_xz'][0]/stats['sweep_xz'][1]:.4f}, "
    f"ann/center={stats['sweep_xz'][2]/stats['sweep_xz'][0]:.1f}"
)

fig.suptitle("m=-5 density: donut-like structure check", fontsize=15)
fig.text(
    0.015,
    0.01,
    summary,
    fontsize=10.5,
    family="monospace",
    va="bottom",
    ha="left",
    bbox=dict(boxstyle="round,pad=0.35", facecolor="white", edgecolor="#aaaaaa", alpha=0.95),
)

fig.savefig(OUT_PNG, dpi=200)
print(f"wrote {OUT_PNG}")
print(summary)
