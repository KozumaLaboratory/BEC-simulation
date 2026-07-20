#!/usr/bin/env python3
"""
Goto RTP final-state m=-5 views.

Panels:
  1) top view   : xy slice
  2) side view  : xz slice
  3) oblique 3D : the two slices mounted on orthogonal planes

This is a confirmation image for the "donut-like" structure question.
The H5 does not store a full 3-D m=-5 volume, so the oblique panel is a
3-D visualisation built from the stored xy/xz cuts.
"""
import os
import numpy as np
import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401

plt.rcParams.update({
    "font.size": 12,
    "axes.titlesize": 13,
    "axes.labelsize": 12,
    "xtick.labelsize": 10,
    "ytick.labelsize": 10,
    "axes.linewidth": 0.8,
})

ROOT = os.environ.get("FPE_ROOT", "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.environ.get("GOTO_H5", os.path.join(ROOT, "rtp_10mG_goto.h5"))
OUT_PNG = os.environ.get("OUT_PNG", os.path.join(ROOT, "m5_goto_views.png"))

with h5py.File(H5, "r") as f:
    m_channels = f["meta/m_channels"][:]
    ci = int(np.where(m_channels == -5)[0][0])
    Lbox = float(f["meta/L_box"][()])
    NX = int(f["meta/NX"][()])
    omega_ref = float(f["meta/omega_ref"][()])
    t = f["t"][:]
    B = f["B_gauss"][:] * 1e6
    n_xy = np.transpose(f["n_m_xy"][:], (3, 2, 1, 0))
    n_xz = np.transpose(f["n_m_xz"][:], (3, 2, 1, 0))

k = -1
im_xy = n_xy[k, ci].T
im_xz = n_xz[k, ci].T

dx = Lbox / NX
xs = -Lbox / 2 + dx * np.arange(NX) + dx / 2
extent = [xs[0] - dx / 2, xs[-1] + dx / 2, xs[0] - dx / 2, xs[-1] + dx / 2]

center = NX // 2
xx, yy = np.meshgrid(np.arange(NX), np.arange(NX), indexing="xy")
rr = np.sqrt((xx - center) ** 2 + (yy - center) ** 2)

def ring_stats(im):
    c = float(im[center, center])
    mx = float(np.max(im))
    ann = im[(rr >= 4) & (rr <= 10)]
    ann_mean = float(np.mean(ann))
    return c, mx, ann_mean

stats_xy = ring_stats(im_xy)
stats_xz = ring_stats(im_xz)
vmax = max(float(np.max(im_xy)), float(np.max(im_xz)), 1e-30)

fig = plt.figure(figsize=(16, 5.4), constrained_layout=True)
gs = fig.add_gridspec(1, 3, width_ratios=[1.0, 1.0, 1.35])

ax_top = fig.add_subplot(gs[0, 0])
ax_side = fig.add_subplot(gs[0, 1])
ax_3d = fig.add_subplot(gs[0, 2], projection="3d")

def show_2d(ax, im, title, ylab):
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
    ax.set_title(title)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox / 2, Lbox / 2, 5))
    ax.set_yticks(np.linspace(-Lbox / 2, Lbox / 2, 5))
    cb = plt.colorbar(m, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$|\psi_{m=-5}|^2$")

show_2d(ax_top, im_xy, "Top view: xy slice", "y [μm]")
show_2d(ax_side, im_xz, "Side view: xz slice", "z [μm]")

# Oblique 3D panel: place the xy slice on z=0 and the xz slice on y=0.
X, Y = np.meshgrid(xs, xs, indexing="xy")
X2, Z2 = np.meshgrid(xs, xs, indexing="xy")
Z0 = np.zeros_like(X)
Y0 = np.zeros_like(X2)

norm = plt.Normalize(vmin=0, vmax=vmax)
cmap = plt.cm.magma
fc_xy = cmap(norm(im_xy))
fc_xz = cmap(norm(im_xz))
fc_xy[..., 3] = 0.88
fc_xz[..., 3] = 0.72

ax_3d.plot_surface(X, Y, Z0, facecolors=fc_xy, rstride=1, cstride=1,
                   shade=False, linewidth=0, antialiased=False)
ax_3d.plot_surface(X2, Y0, Z2, facecolors=fc_xz,
                   rstride=1, cstride=1, shade=False, linewidth=0, antialiased=False)

ax_3d.set_xlim(-Lbox / 2, Lbox / 2)
ax_3d.set_ylim(-Lbox / 2, Lbox / 2)
ax_3d.set_zlim(-Lbox / 2, Lbox / 2)
ax_3d.view_init(elev=24, azim=230)
ax_3d.set_box_aspect((1, 1, 1))
ax_3d.set_xlabel("x [μm]", labelpad=6)
ax_3d.set_ylabel("y [μm]", labelpad=6)
ax_3d.set_zlabel("z [μm]", labelpad=6)
ax_3d.set_title("Oblique 3D view from xy/xz cuts", pad=10)
ax_3d.grid(False)

B_str = f"{B[k]:.3f} μG"
t_ms = t[k] / omega_ref * 1000.0
fig.suptitle(f"Goto final snapshot  |  B = {B_str}  |  t = {t_ms:.2f} ms", fontsize=15)

summary = (
    f"xy center/max={stats_xy[0]/stats_xy[1]:.4f}, ann/center={stats_xy[2]/stats_xy[0]:.1f}\n"
    f"xz center/max={stats_xz[0]/stats_xz[1]:.4f}, ann/center={stats_xz[2]/stats_xz[0]:.1f}"
)
fig.text(
    0.015,
    0.02,
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
