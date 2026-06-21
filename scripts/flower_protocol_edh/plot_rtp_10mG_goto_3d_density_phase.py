#!/usr/bin/env python3
"""
3-D density/phase GIF for the Goto 10 mG RTP.

Visualisation:
  - faint gray total-density shell
  - phase-coloured m=-6 density shell
  - fixed oblique camera
  - B(t) trace panel for protocol context

This script expects the downsampled 3-D datasets written by
`goto_protocol_10mG.jl`:
  n_total_3d, n_m6_3d, arg_psi_m6_3d
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from _anim_writer import save_matplotlib_anim

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.environ.get("RTP_H5") or os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_10mG_goto.h5"))
OUT_GIF = os.environ.get("OUT_GIF", H5.replace(".h5", "_3d_density_phase.mp4"))

ISO_TOTAL = float(os.environ.get("FPE_3D_ISO_TOTAL", "0.10"))
ISO_M6 = float(os.environ.get("FPE_3D_ISO_M6", "0.12"))
FPS = int(os.environ.get("FPE_3D_FPS", os.environ.get("FPE_FPS", "12")))
INTERVAL_MS = int(os.environ.get("FPE_3D_INTERVAL_MS", str(max(1, int(round(1000 / FPS))))))

with h5py.File(H5, "r") as f:
    required = ("n_total_3d", "n_m6_3d", "arg_psi_m6_3d")
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
    n_m6_3d = np.transpose(f["n_m6_3d"][:], (3, 2, 1, 0))
    arg_m6_3d = np.transpose(f["arg_psi_m6_3d"][:], (3, 2, 1, 0))

Nf = len(t)
t_ms = t / omega_ref * 1000.0
Nv = n_total_3d.shape[1]
print(f"loaded {Nf} snapshots, 3-D grid={Nv}^3, stride={vol_stride}, T={t_ms[-1]:.2f}ms")

dx = Lbox / NX * vol_stride
tick_idx = np.linspace(0, Nv, 5)
tick_lbl = [f"{v:.1f}" for v in np.linspace(-Lbox / 2, Lbox / 2, 5)]

stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1:
    frames.append(Nf - 1)

n_total_max = float(np.max(n_total_3d))
n_m6_max = float(np.max(n_m6_3d))

BG = "#0b1020"
W = "white"

def shell_mask(mask):
    interior = np.zeros_like(mask, dtype=bool)
    interior[1:-1, 1:-1, 1:-1] = (
        mask[1:-1, 1:-1, 1:-1]
        & mask[:-2, 1:-1, 1:-1] & mask[2:, 1:-1, 1:-1]
        & mask[1:-1, :-2, 1:-1] & mask[1:-1, 2:, 1:-1]
        & mask[1:-1, 1:-1, :-2] & mask[1:-1, 1:-1, 2:]
    )
    return mask & ~interior

def phase_facecolors(phase, alpha=0.90):
    colors = plt.cm.hsv((phase + np.pi) / (2 * np.pi))
    colors[..., 3] = alpha
    return colors

fig = plt.figure(figsize=(15, 9), facecolor=BG)
ax3 = fig.add_axes([0.03, 0.05, 0.64, 0.90], projection="3d")
axB = fig.add_axes([0.73, 0.16, 0.23, 0.65])
axB.set_facecolor("#151b2f")
axB.plot(t_ms, np.maximum(B_g_t, 1e-9) * 1e6, "C2-", lw=1.7)
axB.set_yscale("log")
axB.set_xlabel("t [ms]", color=W)
axB.set_ylabel("B [μG]", color=W)
axB.set_title("Goto B(t)", color=W, fontsize=12)
axB.tick_params(colors=W, labelsize=9)
for spine in axB.spines.values():
    spine.set_color("#3b4264")
axB.grid(alpha=0.2, which="both", color=W)
vB = axB.axvline(t_ms[0], color="#ff5c5c", lw=1.2)
hud = fig.text(0.73, 0.87, "", color=W, fontsize=14, family="monospace")

def draw_frame(k):
    ax3.cla()
    ax3.set_facecolor(BG)
    total_shell = shell_mask(n_total_3d[k] >= ISO_TOTAL * n_total_max)
    m6_shell = shell_mask(n_m6_3d[k] >= ISO_M6 * n_m6_max)

    if np.any(total_shell):
        total_colors = np.zeros(total_shell.shape + (4,), dtype=float)
        total_colors[..., 0] = 0.72
        total_colors[..., 1] = 0.72
        total_colors[..., 2] = 0.78
        total_colors[..., 3] = 0.10
        ax3.voxels(total_shell, facecolors=total_colors, edgecolor=None, shade=True)

    if np.any(m6_shell):
        colors = phase_facecolors(arg_m6_3d[k], alpha=0.82)
        ax3.voxels(m6_shell, facecolors=colors, edgecolor=None, shade=False)

    ax3.set_xlim(0, Nv)
    ax3.set_ylim(0, Nv)
    ax3.set_zlim(0, Nv)
    ax3.set_box_aspect((1, 1, 1))
    ax3.view_init(elev=22, azim=232)
    ax3.set_xlabel("x [μm]", color=W, labelpad=5)
    ax3.set_ylabel("y [μm]", color=W, labelpad=5)
    ax3.set_zlabel("z [μm]", color=W, labelpad=5)
    ax3.tick_params(colors=W, labelsize=8)
    ax3.set_xticks(tick_idx)
    ax3.set_yticks(tick_idx)
    ax3.set_zticks(tick_idx)
    ax3.set_xticklabels(tick_lbl)
    ax3.set_yticklabels(tick_lbl)
    ax3.set_zticklabels(tick_lbl)
    for axis in (ax3.xaxis, ax3.yaxis, ax3.zaxis):
        axis.pane.fill = False
        axis.pane.set_edgecolor("#2a3352")
    ax3.grid(True, color="#1d2540", linewidth=0.4)
    B_mG = B_g_t[k] * 1e3
    b_label = f"{B_mG:.3f} mG" if B_mG >= 0.1 else f"{B_g_t[k] * 1e6:.2f} μG"
    ax3.set_title(
        r"$m=-6$ density isosurface colored by phase"
        + f"\n t = {t_ms[k]:7.2f} ms   B = {b_label}",
        color=W, fontsize=13, pad=12,
    )
    vB.set_xdata([t_ms[k], t_ms[k]])
    hud.set_text(f"frame = {k+1:3d}/{Nf}\niso(total) = {ISO_TOTAL:.2f} nmax\niso(m=-6) = {ISO_M6:.2f} nmax")

def update(frame_idx):
    draw_frame(frame_idx)
    return ()

print(f"rendering {len(frames)} frames → {OUT_GIF}")
anim = FuncAnimation(fig, update, frames=frames, interval=INTERVAL_MS, blit=False)
save_matplotlib_anim(anim, OUT_GIF, fps=FPS)
print("done.")
