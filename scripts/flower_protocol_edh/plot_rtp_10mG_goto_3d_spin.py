#!/usr/bin/env python3
"""
3-D spin texture animation — paper-grade rendering for the Goto RTP.

Encoding (matches Sadler 2006 / Vengalattore 2008 / Kawaguchi-Ueda 2012
review conventions for spinor BEC spin texture):

  arrow direction  : local unit ⟨F⟩(r) / |⟨F⟩(r)|
  arrow length     : polarisation fraction p = |⟨F⟩|/(F · n_total)
                     (0 = unpolarised, 1 = fully aligned at maximum F)
  arrow colour     : full 3-D direction encoded as HSV
                     hue        = azimuth φ_F = atan2(F_y, F_x)
                     saturation = sin(θ_F)   (in-plane content)
                     value      = 1 − 0.4·(F_z/F)  (vertical sign by lightness)
                     → +z up = bright/pale, −z down = dark, x/y arrows = saturated
  density envelope : translucent grey isosurface at 0.1 × per-frame peak
                     (gives the BEC shape without obscuring arrows)
  B(t) marker      : a separate small reference arrow showing the
                     current Zeeman direction (length log-scaled).

Density mask: per-frame peak (so arrows remain visible as the cloud
shrinks under K_3 loss). Set FPE_3D_SPIN_USE_ABS_THRESH=1 with
FPE_3D_SPIN_ABS_THRESH=... to switch to an absolute cut-off.

Playback: `FPE_DURATION_S` (default 20) sets the wall-clock duration
in seconds; combined with `FPE_FPS` (default 60) this duplicates data
frames so playback is smooth AND slow. Set FPE_DURATION_S=0 to render
one video frame per data frame (legacy behaviour).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors as mcolors
from matplotlib.animation import FuncAnimation
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401
from _anim_writer import save_via_png_dup

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.environ.get("RTP_H5") or os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_10mG_goto.h5"))
OUT_GIF = os.environ.get("OUT_GIF", H5.replace(".h5", "_3d_spin.mp4"))

F_VAL = float(os.environ.get("FPE_F", "6"))  # Eu
DENSITY_THRESH_REL = float(os.environ.get("FPE_3D_SPIN_THRESH", "0.10"))
USE_ABS_THRESH = bool(int(os.environ.get("FPE_3D_SPIN_USE_ABS_THRESH", "0")))
ABS_THRESH = float(os.environ.get("FPE_3D_SPIN_ABS_THRESH", "0.001"))
SHELL_PEAK_RATIO = float(os.environ.get("FPE_3D_SHELL_THRESH", "0.10"))
ARROW_STEP = int(os.environ.get("FPE_3D_ARROW_STEP", "2"))
ARROW_LENGTH_SCALE = float(os.environ.get("FPE_3D_ARROW_LENGTH", "1.8"))
FPS = int(os.environ.get("FPE_3D_FPS", os.environ.get("FPE_FPS", "60")))
DURATION_S = float(os.environ.get("FPE_DURATION_S", "20.0"))
INTERVAL_MS = int(os.environ.get("FPE_3D_INTERVAL_MS", str(max(1, int(round(1000 / FPS))))))

with h5py.File(H5, "r") as f:
    required = ("n_total_3d", "Fx_3d", "Fy_3d", "Fz_3d")
    missing = [k for k in required if k not in f]
    if missing:
        raise RuntimeError(
            "missing 3-D datasets in H5: "
            + ", ".join(missing)
            + " ; rerun goto_protocol_10mG.jl"
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


def direction_to_hsv_rgba(fx, fy, fz, polarisation):
    """Encode unit ⟨F̂⟩ direction as RGBA.
       hue   = (φ + π)/(2π)         azimuth → hue
       sat   = sin(θ)                in-plane content (0 at poles)
       val   = 0.5 + 0.5·max(cos θ, 0)·0.6 + 0.4·(1−|cos θ|)
               …simplified to a smooth two-side ramp:
               val = 1 − 0.4·cos θ   (−z dim, +z bright; transverse mid)
       alpha = polarisation (0..1) so unpolarised regions fade out.
    """
    fmag = np.sqrt(fx*fx + fy*fy + fz*fz) + 1e-30
    cos_t = fz / fmag
    sin_t = np.sqrt(np.maximum(0.0, 1.0 - cos_t * cos_t))
    phi = np.arctan2(fy, fx)
    hue = (phi + np.pi) / (2.0 * np.pi)
    sat = np.clip(sin_t, 0.0, 1.0)
    val = np.clip(1.0 - 0.4 * cos_t, 0.4, 1.0)
    hsv = np.stack([hue, sat, val], axis=-1)
    rgb = mcolors.hsv_to_rgb(hsv)
    alpha = np.clip(polarisation, 0.15, 1.0)  # floor so weak arrows still visible
    rgba = np.concatenate([rgb, alpha[..., None]], axis=-1)
    return rgba


def _make_color_sphere(ax_legend):
    """Mini 2-D 'spin colour wheel' showing the HSV mapping."""
    n = 80
    theta = np.linspace(0, np.pi, n)
    phi = np.linspace(-np.pi, np.pi, 2 * n)
    PHI, TH = np.meshgrid(phi, theta, indexing="xy")
    fx = np.sin(TH) * np.cos(PHI)
    fy = np.sin(TH) * np.sin(PHI)
    fz = np.cos(TH)
    rgba = direction_to_hsv_rgba(fx, fy, fz, np.ones_like(fx))
    rgb = rgba[..., :3]
    # Plot in az(φ) × polar(θ) rectangle
    ax_legend.imshow(rgb, origin="lower", extent=[-180, 180, 180, 0], aspect="auto")
    ax_legend.set_xticks([-180, -90, 0, 90, 180])
    ax_legend.set_yticks([0, 45, 90, 135, 180])
    ax_legend.set_xlabel(r"$\phi_F$ [deg]", fontsize=8)
    ax_legend.set_ylabel(r"$\theta_F$ [deg]", fontsize=8)
    ax_legend.tick_params(labelsize=7)
    ax_legend.set_title("spin direction colour", fontsize=8, pad=4)


BG = "white"
FG = "black"

fig = plt.figure(figsize=(15, 9), facecolor=BG)
ax3 = fig.add_axes([0.02, 0.04, 0.66, 0.92], projection="3d")
axB = fig.add_axes([0.73, 0.55, 0.24, 0.30])
axL = fig.add_axes([0.73, 0.12, 0.24, 0.24])

axB.set_facecolor("white")
axB.plot(t_ms, np.maximum(B_g_t, 1e-9) * 1e6, "C2-", lw=1.7)
axB.set_yscale("log")
axB.set_xlabel("t [ms]", color=FG, fontsize=9)
axB.set_ylabel("B [μG]", color=FG, fontsize=9)
axB.set_title("Goto B(t)", color=FG, fontsize=11)
axB.tick_params(colors=FG, labelsize=8)
for spine in axB.spines.values(): spine.set_color("black")
axB.grid(alpha=0.2, which="both")
vB = axB.axvline(t_ms[0], color="#ff5c5c", lw=1.2)

_make_color_sphere(axL)

hud = fig.text(0.73, 0.94, "", color=FG, fontsize=11, family="monospace")


def draw_frame(k):
    ax3.cla()
    ax3.set_facecolor(BG)

    nk = n_total_3d[k]
    n_peak_k = max(float(np.max(nk)), 1e-15)
    sample = np.zeros_like(nk, dtype=bool)
    sample[::ARROW_STEP, ::ARROW_STEP, ::ARROW_STEP] = True
    if USE_ABS_THRESH:
        mask = sample & (nk >= ABS_THRESH)
    else:
        mask = sample & (nk >= DENSITY_THRESH_REL * n_peak_k)

    fx_k = Fx_3d[k][mask]
    fy_k = Fy_3d[k][mask]
    fz_k = Fz_3d[k][mask]
    n_k_pts = nk[mask]
    fmag = np.sqrt(fx_k**2 + fy_k**2 + fz_k**2) + 1e-30

    # Polarisation fraction p = |F| / (F · n)
    polarisation = np.clip(fmag / (F_VAL * np.maximum(n_k_pts, 1e-12)), 0.0, 1.0)
    rgba = direction_to_hsv_rgba(fx_k, fy_k, fz_k, polarisation)

    # Unit direction for arrow vectors
    u = fx_k / fmag
    v = fy_k / fmag
    w = fz_k / fmag

    xq = X[mask]; yq = Y[mask]; zq = Z[mask]

    base_len = dx * ARROW_STEP * ARROW_LENGTH_SCALE
    # `quiver` doesn't allow per-arrow length in matplotlib's 3-D backend
    # without recomputing each vector, so we scale the components instead.
    for idx in range(len(xq)):
        L = base_len * polarisation[idx]
        if L < 1e-6:
            continue
        ax3.quiver(
            [xq[idx]], [yq[idx]], [zq[idx]],
            [u[idx] * L], [v[idx] * L], [w[idx] * L],
            color=tuple(rgba[idx]),
            linewidth=0.9,
            arrow_length_ratio=0.30,
            normalize=False,
        )

    # Translucent density isosurface envelope (proxy: low-saturation cloud of dots)
    shell_mask = sample & (nk >= SHELL_PEAK_RATIO * n_peak_k) & (~mask)
    if shell_mask.any():
        ax3.scatter(X[shell_mask], Y[shell_mask], Z[shell_mask],
                    color="#b0b0b0", s=2, alpha=0.10)

    # Reference: B(t) direction marker — z-axis aligned for Goto protocol (B || ±z).
    # Show even at tiny B by log-clamping the displayed length.
    B_sign = -1.0 if B_g_t[k] < 0 else 1.0
    B_disp_mag = 0.45 * Lbox * 0.5  # ~half the box
    ax3.quiver(
        [-Lbox * 0.45], [Lbox * 0.45], [-Lbox * 0.45],
        [0], [0], [B_sign * B_disp_mag],
        color="#ff3030", linewidth=2.2, arrow_length_ratio=0.20, normalize=False,
    )
    ax3.text(-Lbox * 0.45, Lbox * 0.45, -Lbox * 0.45 + B_sign * B_disp_mag * 1.05,
             "B", color="#ff3030", fontsize=10, ha="center", va="bottom")

    ax3.set_xlim(xs[0], xs[-1])
    ax3.set_ylim(xs[0], xs[-1])
    ax3.set_zlim(xs[0], xs[-1])
    ax3.set_box_aspect((1, 1, 1))
    ax3.view_init(elev=22, azim=235)
    ax3.set_xlabel("x [μm]", color=FG, labelpad=5)
    ax3.set_ylabel("y [μm]", color=FG, labelpad=5)
    ax3.set_zlabel("z [μm]", color=FG, labelpad=5)
    ax3.tick_params(colors=FG, labelsize=8)
    ax3.set_xticks(tick_pos); ax3.set_yticks(tick_pos); ax3.set_zticks(tick_pos)
    ax3.set_xticklabels(tick_lbl)
    ax3.set_yticklabels(tick_lbl)
    ax3.set_zticklabels(tick_lbl)
    for axis in (ax3.xaxis, ax3.yaxis, ax3.zaxis):
        axis.pane.fill = False
        axis.pane.set_edgecolor("black")
    ax3.grid(True, color="#dddddd", linewidth=0.4)

    B_mG = B_g_t[k] * 1e3
    b_label = f"{B_mG:.3f} mG" if abs(B_mG) >= 0.1 else f"{B_g_t[k] * 1e6:.2f} μG"
    ax3.set_title(
        r"$\langle\hat{F}(\mathbf{r})\rangle$ spin texture  —  arrow length $\propto p=|F|/(F\,n)$"
        + f"\n t = {t_ms[k]:7.2f} ms   B = {b_label}",
        color=FG, fontsize=12, pad=10,
    )

    vB.set_xdata([t_ms[k], t_ms[k]])
    n_arrows = int(mask.sum())
    p_med = float(np.median(polarisation)) if len(polarisation) else 0.0
    hud.set_text(
        f"frame {k+1:3d}/{Nf}\n"
        f"arrows  : {n_arrows}\n"
        f"p median: {p_med:.3f}"
    )


# Build data-frame index list; allow FPE_FRAME_STRIDE to thin.
data_stride = int(os.environ.get("FPE_FRAME_STRIDE", "1"))
data_frames = list(range(0, Nf, data_stride))
if data_frames[-1] != Nf - 1:
    data_frames.append(Nf - 1)

print(f"data frames: {len(data_frames)}  output fps: {FPS}  target duration: {DURATION_S:.1f}s  → {OUT_GIF}")

def draw_with_callback(idx):
    """Adapter: PNG-pipeline expects draw_fn(k) where k is the local index
    into the rendered sequence — translate to underlying data frame."""
    draw_frame(data_frames[idx])

save_via_png_dup(fig, draw_with_callback, len(data_frames), OUT_GIF,
                 fps=FPS, duration_s=DURATION_S)
print("done.")
