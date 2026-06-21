#!/usr/bin/env python3
"""
3-D spin GIF for the Goto 10 mG RTP.

Visualisation:
  - sparse 3-D quiver arrows from the downsampled spin field
  - arrow colour = local Fz / n_total
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.animation import FuncAnimation, PillowWriter
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.environ.get("RTP_H5") or os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_10mG_goto.h5"))
OUT_GIF = os.environ.get("OUT_GIF", H5.replace(".h5", "_3d_spin.gif"))

DENSITY_THRESH = float(os.environ.get("FPE_3D_SPIN_THRESH", "0.12"))
SHELL_THRESH = float(os.environ.get("FPE_3D_SHELL_THRESH", "0.10"))
ARROW_STEP = int(os.environ.get("FPE_3D_ARROW_STEP", "2"))
FPS = int(os.environ.get("FPE_3D_FPS", "7"))
INTERVAL_MS = int(os.environ.get("FPE_3D_INTERVAL_MS", "140"))

with h5py.File(H5, "r") as f:
    required = ("n_total_3d", "Fx_3d", "Fy_3d", "Fz_3d")
    missing = [k for k in required if k not in f]
    if missing:
        raise RuntimeError(
            "missing 3-D datasets in H5: "
            + ", ".join(missing)
            + " ; rerun goto_protocol_10mG.jl with the updated script"
        )
    t = f["t"][:]
    B_g_t = f["B_gauss"][:]
    omega_ref = float(f["meta/omega_ref"][()])
    Lbox = float(f["meta/L_box"][()])
    NX = int(f["meta/NX"][()])
    vol_stride = int(f["meta/vol_stride"][()])
    n_total_3d = np.transpose(f["n_total_3d"][:], (3, 2, 1, 0))
    Fx_3d = np.transpose(f["Fx_3d"][:], (3, 2, 1, 0))
    Fy_3d = np.transpose(f["Fy_3d"][:], (3, 2, 1, 0))
    Fz_3d = np.transpose(f["Fz_3d"][:], (3, 2, 1, 0))

Nf = len(t)
t_ms = t / omega_ref * 1000.0
Nv = n_total_3d.shape[1]
print(f"loaded {Nf} snapshots, 3-D grid={Nv}^3, stride={vol_stride}, T={t_ms[-1]:.2f}ms")

dx = Lbox / NX * vol_stride
xs = -Lbox / 2 + dx * np.arange(Nv) + dx / 2
X, Y, Z = np.meshgrid(xs, xs, xs, indexing="ij")
tick_lbl = [f"{v:.1f}" for v in np.linspace(-Lbox / 2, Lbox / 2, 5)]
tick_pos = np.linspace(xs[0], xs[-1], 5)

stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1:
    frames.append(Nf - 1)

n_total_max = float(np.max(n_total_3d))
fz_per_atom_absmax = float(np.max(np.abs(Fz_3d / np.maximum(n_total_3d, 1e-12))))

BG = "white"
FG = "black"
cmap_arrow = plt.cm.RdBu_r
arrow_norm = mcolors.Normalize(-fz_per_atom_absmax, fz_per_atom_absmax)

def shell_mask(mask):
    return mask

fig = plt.figure(figsize=(15, 9), facecolor=BG)
ax3 = fig.add_axes([0.03, 0.05, 0.64, 0.90], projection="3d")
axB = fig.add_axes([0.73, 0.16, 0.20, 0.65])
axB.set_facecolor("white")
axB.plot(t_ms, np.maximum(B_g_t, 1e-9) * 1e6, "C2-", lw=1.7)
axB.set_yscale("log")
axB.set_xlabel("t [ms]", color=FG)
axB.set_ylabel("B [μG]", color=FG)
axB.set_title("Goto B(t)", color=FG, fontsize=12)
axB.tick_params(colors=FG, labelsize=9)
for spine in axB.spines.values():
    spine.set_color("black")
axB.grid(alpha=0.2, which="both", color="black")
vB = axB.axvline(t_ms[0], color="#ff5c5c", lw=1.2)
ax_cb = fig.add_axes([0.94, 0.18, 0.015, 0.60])
sm = plt.cm.ScalarMappable(cmap=cmap_arrow, norm=arrow_norm)
sm.set_array([])
cb = fig.colorbar(sm, cax=ax_cb)
cb.set_label(r"$F_z / n$", color=FG, fontsize=9)
cb.ax.tick_params(colors=FG, labelsize=8)
cb.outline.set_edgecolor("black")
hud = fig.text(0.73, 0.87, "", color=FG, fontsize=13, family="monospace")

def draw_frame(k):
    ax3.cla()
    ax3.set_facecolor(BG)
    sample = np.zeros_like(n_total_3d[k], dtype=bool)
    sample[::ARROW_STEP, ::ARROW_STEP, ::ARROW_STEP] = True
    mask = sample & (n_total_3d[k] >= DENSITY_THRESH * n_total_max)
    xq = X[mask]
    yq = Y[mask]
    zq = Z[mask]
    u = Fx_3d[k][mask]
    v = Fy_3d[k][mask]
    w = Fz_3d[k][mask]
    mag = np.sqrt(u*u + v*v + w*w) + 1e-30
    u = u / mag
    v = v / mag
    w = w / mag
    fz_pa = Fz_3d[k][mask] / np.maximum(n_total_3d[k][mask], 1e-12)
    colors = cmap_arrow(arrow_norm(fz_pa))

    for idx in range(len(xq)):
        ax3.quiver(
            [xq[idx]], [yq[idx]], [zq[idx]],
            [u[idx]], [v[idx]], [w[idx]],
            length=dx * ARROW_STEP * 1.1,
            color=colors[idx],
            linewidth=0.8,
            arrow_length_ratio=0.35,
            normalize=False,
        )

    ax3.set_xlim(xs[0], xs[-1])
    ax3.set_ylim(xs[0], xs[-1])
    ax3.set_zlim(xs[0], xs[-1])
    ax3.set_box_aspect((1, 1, 1))
    ax3.view_init(elev=22, azim=235)
    ax3.set_xlabel("x [μm]", color=FG, labelpad=5)
    ax3.set_ylabel("y [μm]", color=FG, labelpad=5)
    ax3.set_zlabel("z [μm]", color=FG, labelpad=5)
    ax3.tick_params(colors=FG, labelsize=8)
    ax3.set_xticks(tick_pos)
    ax3.set_yticks(tick_pos)
    ax3.set_zticks(tick_pos)
    ax3.set_xticklabels(tick_lbl)
    ax3.set_yticklabels(tick_lbl)
    ax3.set_zticklabels(tick_lbl)
    for axis in (ax3.xaxis, ax3.yaxis, ax3.zaxis):
        axis.pane.fill = False
        axis.pane.set_edgecolor("black")
    ax3.grid(True, color="#dddddd", linewidth=0.4)
    B_mG = B_g_t[k] * 1e3
    b_label = f"{B_mG:.3f} mG" if B_mG >= 0.1 else f"{B_g_t[k] * 1e6:.2f} μG"
    ax3.set_title(
        r"3-D spin texture"
        + f"\n t = {t_ms[k]:7.2f} ms   B = {b_label}",
        color=FG, fontsize=13, pad=12,
    )
    vB.set_xdata([t_ms[k], t_ms[k]])
    hud.set_text(
        f"frame = {k+1:3d}/{Nf}\n"
        f"density cut = {DENSITY_THRESH:.2f} nmax\n"
        f"arrow step = {ARROW_STEP}"
    )

def update(frame_idx):
    draw_frame(frame_idx)
    return ()

print(f"rendering {len(frames)} frames → {OUT_GIF}")
anim = FuncAnimation(fig, update, frames=frames, interval=INTERVAL_MS, blit=False)
anim.save(OUT_GIF, writer=PillowWriter(fps=FPS))
print("done.")
