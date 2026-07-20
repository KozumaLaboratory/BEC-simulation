#!/usr/bin/env python3
"""
plot_rtp_60uG_tilted_diff.py
============================
Differential imaging at ±16° tilted axis (Goto experimental convention).

Loads `n_m6_tilted` (shape Nf×3×NZ×NX) for θ_q ∈ {-16°, 0°, +16°} from the
existing RTP h5, computes  Δn = n[θ=+16°] − n[θ=-16°]  per frame, and
emits a single GIF showing the diff as a time series.

A Flower-symmetric state gives Δn ≈ 0 (left/right tilted projections are
equal). An asymmetric / vortex state gives non-zero Δn — the sign / spatial
pattern of Δn is the experimental discriminator.
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

plt.rcParams.update({
    "font.size": 13,
    "axes.titlesize": 15,
    "axes.labelsize": 13,
    "xtick.labelsize": 11,
    "ytick.labelsize": 11,
})

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_60uG_dt0p001.h5"))
OUT = os.path.join(ROOT, "rtp_60uG_tilted_diff_16deg.gif")

with h5py.File(H5, "r") as f:
    t       = f["t"][:]
    omega_ref = float(f["meta/omega_ref"][()])
    Lbox    = float(f["meta/L_box"][()])
    NX      = int(f["meta/NX"][()])
    B_g     = float(f["meta/B_gauss"][()])
    theta_q = f["meta/theta_q_deg"][:]
    # Julia (Nf, Nθ, NZ, NX) → Python (NX, NZ, Nθ, Nf), transpose back
    tilted  = np.transpose(f["n_m6_tilted"][:], (3, 2, 1, 0))  # (Nf, Nθ, NZ, NX)

Nf = len(t)
t_ms = t / omega_ref * 1000.0

# Identify +16° and -16° indices
i_plus  = int(np.argmin(np.abs(theta_q - 16.0)))
i_minus = int(np.argmin(np.abs(theta_q + 16.0)))
print(f"loaded {Nf} snapshots; θ_q={list(theta_q)}; +16°@idx={i_plus}, -16°@idx={i_minus}")

# Differential imaging: Δn(x, z) = n[+16°] − n[−16°]
# Shape (Nf, NZ, NX)
diff = tilted[:, i_plus] - tilted[:, i_minus]
vmax = float(np.max(np.abs(diff)))
print(f"Δn range: [{diff.min():.3e}, {diff.max():.3e}],  |Δn|_max = {vmax:.3e}")

# Sum / Reference (left-right symmetric component) for context
sum_lr = tilted[:, i_plus] + tilted[:, i_minus]
sum_vmax = float(np.max(sum_lr))

# Spatial extent
dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

# 1×3 figure: |−16°| | |+16°| | diff
fig, axes = plt.subplots(1, 3, figsize=(22, 7.5),
                         gridspec_kw={"wspace": 0.30})
ax_m, ax_p, ax_d = axes

def setup_density_panel(ax, vmax_, title):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax_, cmap="inferno", aspect="equal",
                   interpolation="bilinear")
    ax.set_title(title, pad=6)
    ax.set_xlabel("x [μm]"); ax.set_ylabel("z [μm]")
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$\int dy\,|\psi_{m=-6}|^2$  [μm⁻²]")
    return im

im_m = setup_density_panel(ax_m, sum_vmax * 0.5,
    fr"$\theta_q = {int(theta_q[i_minus])}°$")
im_p = setup_density_panel(ax_p, sum_vmax * 0.5,
    fr"$\theta_q = {int(theta_q[i_plus])}°$")

# Diff panel: diverging colormap centered at 0
im_d = ax_d.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=-vmax, vmax=+vmax, cmap="RdBu_r", aspect="equal",
                   interpolation="bilinear")
ax_d.set_title(fr"$\Delta n = n(+16°) - n(-16°)$", pad=6)
ax_d.set_xlabel("x [μm]"); ax_d.set_ylabel("z [μm]")
ax_d.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
ax_d.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
cb_d = plt.colorbar(im_d, ax=ax_d, fraction=0.046, pad=0.02)
cb_d.set_label(r"$\Delta n$  [μm⁻²]")

# HUD top-left of diff panel
txt = ax_d.text(0.02, 0.97, "", transform=ax_d.transAxes,
                fontsize=12, family="monospace", va="top",
                bbox=dict(facecolor="white", alpha=0.8, edgecolor="none",
                          boxstyle="round,pad=0.3"))

suptitle = fig.suptitle(
    f"Goto ±16° differential imaging  |  B={B_g*1e6:.1f} μG  "
    f"(constant LBFGS-polished GS hold)  |  T_RTP={t_ms[-1]:.2f} ms",
    fontsize=16, y=0.98)

def update(k):
    im_m.set_data(tilted[k, i_minus])
    im_p.set_data(tilted[k, i_plus])
    im_d.set_data(diff[k])
    L1 = float(np.abs(diff[k]).sum() * (dx * dx))
    txt.set_text(f"t = {t_ms[k]:6.3f} ms ({k+1}/{Nf})\n"
                 f"‖Δn‖_L1 = {L1:.3e}\n"
                 f"max|Δn|  = {float(np.abs(diff[k]).max()):.3e}")
    return ()

stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1: frames.append(Nf - 1)
print(f"rendering {len(frames)} frames → {OUT}")
anim = FuncAnimation(fig, update, frames=frames, interval=140, blit=False)
anim.save(OUT, writer=PillowWriter(fps=7))
print("done.")
