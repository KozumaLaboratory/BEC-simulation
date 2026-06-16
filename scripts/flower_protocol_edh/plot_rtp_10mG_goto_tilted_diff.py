#!/usr/bin/env python3
"""Goto ±16° differential imaging GIF for the 10mG → 0 protocol run."""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter

plt.rcParams.update({"font.size": 13, "axes.titlesize": 15})

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_10mG_goto.h5"))
OUT = os.path.join(ROOT, "rtp_10mG_goto_tilted_diff_16deg.gif")

with h5py.File(H5, "r") as f:
    t        = f["t"][:]
    omega_ref = float(f["meta/omega_ref"][()])
    Lbox     = float(f["meta/L_box"][()])
    NX       = int(f["meta/NX"][()])
    theta_q  = f["meta/theta_q_deg"][:]
    B_g_t    = f["B_gauss"][:]
    tilted   = np.transpose(f["n_m6_tilted"][:], (3, 2, 1, 0))   # (Nf, Nθ, NZ, NX)

Nf = len(t)
t_ms = t / omega_ref * 1000.0
i_p = int(np.argmin(np.abs(theta_q - 16.0)))
i_m = int(np.argmin(np.abs(theta_q + 16.0)))

diff = tilted[:, i_p] - tilted[:, i_m]
sum_lr = tilted[:, i_p] + tilted[:, i_m]
vmax = float(np.max(np.abs(diff)))
sum_vmax = float(np.max(sum_lr))
print(f"|Δn|_max={vmax:.3e}, sum_max={sum_vmax:.3e}")

dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

fig, axes = plt.subplots(1, 3, figsize=(22, 7.5), gridspec_kw={"wspace": 0.30})
ax_m, ax_p, ax_d = axes

def setup(ax, vmax_, title, cmap, cb_label, diverging=False):
    if diverging:
        im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                       vmin=-vmax_, vmax=vmax_, cmap=cmap, aspect="equal",
                       interpolation="bilinear")
    else:
        im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                       vmin=0, vmax=vmax_, cmap=cmap, aspect="equal",
                       interpolation="bilinear")
    ax.set_title(title, pad=6)
    ax.set_xlabel("x [μm]"); ax.set_ylabel("z [μm]")
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(cb_label)
    return im

im_m = setup(ax_m, sum_vmax * 0.5, fr"$\theta_q = {int(theta_q[i_m])}°$",
             "inferno", r"$\int dy\,|\psi_{m=-6}|^2$ [μm⁻²]")
im_p = setup(ax_p, sum_vmax * 0.5, fr"$\theta_q = {int(theta_q[i_p])}°$",
             "inferno", r"$\int dy\,|\psi_{m=-6}|^2$ [μm⁻²]")
im_d = setup(ax_d, vmax, r"$\Delta n = n(+16°) - n(-16°)$",
             "RdBu_r", r"$\Delta n$ [μm⁻²]", diverging=True)

txt = ax_d.text(0.02, 0.97, "", transform=ax_d.transAxes,
                fontsize=12, family="monospace", va="top",
                bbox=dict(facecolor="white", alpha=0.8, edgecolor="none",
                          boxstyle="round,pad=0.3"))

fig.suptitle(f"Goto ±16° differential imaging  |  10 mG → 0 G protocol  |  "
             f"T_RTP={t_ms[-1]:.2f} ms", fontsize=15, y=0.97)

def update(k):
    im_m.set_data(tilted[k, i_m])
    im_p.set_data(tilted[k, i_p])
    im_d.set_data(diff[k])
    L1 = float(np.abs(diff[k]).sum() * (dx * dx))
    B = B_g_t[k]
    B_str = f"{B*1e3:.3f} mG" if B*1e3 >= 0.1 else f"{B*1e6:.2f} μG"
    txt.set_text(f"t = {t_ms[k]:7.2f} ms ({k+1}/{Nf})\n"
                 f"B = {B_str}\n"
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
