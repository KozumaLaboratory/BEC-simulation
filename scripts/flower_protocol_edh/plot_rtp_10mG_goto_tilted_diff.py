#!/usr/bin/env python3
"""Goto tilted differential imaging GIF for the 10mG → 0 protocol run."""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib.colors import LinearSegmentedColormap

plt.rcParams.update({"font.size": 13, "axes.titlesize": 15})


def signed_cmap():
    return plt.get_cmap("RdBu_r")


def positive_cmap():
    return plt.get_cmap("viridis")


def build_fx(f_spin=6):
    m_vals = np.arange(f_spin, -f_spin - 1, -1, dtype=float)
    d = 2 * f_spin + 1
    fp = np.zeros((d, d), dtype=float)
    for i in range(d - 1):
        mi = m_vals[i + 1]
        fp[i, i + 1] = np.sqrt(f_spin * (f_spin + 1) - mi * (mi + 1))
    return 0.5 * (fp + fp.T)


def projection_correction(theta_deg, f_spin=6):
    fx = build_fx(f_spin)
    theta_rad = np.deg2rad(theta_deg)
    vals, vecs = np.linalg.eigh(fx)
    r_plus = (vecs * np.exp(1j * theta_rad * vals)) @ vecs.conj().T
    idx_m6 = 2 * f_spin
    return float(np.abs(r_plus[idx_m6, idx_m6]) ** 2)

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
i_0 = int(np.argmin(np.abs(theta_q - 0.0)))

cp_p = projection_correction(float(theta_q[i_p]))
cp_m = projection_correction(abs(float(theta_q[i_m])))
print(f"Cp(+16°)={cp_p:.6f}, Cp(-16°)={cp_m:.6f}")

dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

fig, axes = plt.subplots(1, 3, figsize=(21, 6.8), gridspec_kw={"wspace": 0.30})
ax_0, ax_m, ax_p = axes

def setup_density(ax, title, img, vmax_, show_ylabel=False):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax_, cmap=positive_cmap(), aspect="equal",
                   interpolation="bilinear")
    ax.set_title(title, pad=6)
    ax.set_xlabel("x [μm]"); ax.set_ylabel("z [μm]")
    if not show_ylabel:
        ax.set_ylabel("")
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$\int dy\,|\psi_{m=-6}|^2$ [μm⁻²]")
    im.set_data(img)
    return im


def setup_diff(ax, title, show_ylabel=False):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=-1, vmax=1, cmap=signed_cmap(), aspect="equal",
                   interpolation="bilinear")
    ax.set_title(title, pad=6)
    ax.set_xlabel("x [μm]"); ax.set_ylabel("z [μm]")
    if not show_ylabel:
        ax.set_ylabel("")
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$\Delta n_\mathrm{col}$ [μm⁻²]")
    return im

im_0 = setup_density(ax_0, fr"$\theta_q = {int(theta_q[i_0])}°$ reference", tilted[0, i_0], float(np.max(tilted[:, i_0])), show_ylabel=True)
im_m = setup_diff(ax_m, fr"$\Delta n^-_\mathrm{{col}}$  ({int(theta_q[i_m])}°)")
im_p = setup_diff(ax_p, fr"$\Delta n^+_\mathrm{{col}}$  ({int(theta_q[i_p])}°)")

txt = fig.text(0.5, 0.015, "", ha="center",
                fontsize=11, family="monospace", va="bottom",
                bbox=dict(facecolor="white", alpha=0.8, edgecolor="none",
                          boxstyle="round,pad=0.3"))

fig.suptitle(f"Goto tilted differential imaging  |  10 mG → 0 G protocol  |  "
             f"T_RTP={t_ms[-1]:.2f} ms", fontsize=15, y=0.97)

def update(k):
    ref = tilted[k, i_0]
    d_m = tilted[k, i_m] - cp_m * ref
    d_p = tilted[k, i_p] - cp_p * ref
    diff_scale = float(max(np.max(np.abs(d_m)), np.max(np.abs(d_p)), 1e-30))
    d_m = np.clip(d_m / diff_scale, -1.0, 1.0)
    d_p = np.clip(d_p / diff_scale, -1.0, 1.0)
    ref_vmax = float(max(np.max(ref), np.max(tilted[k, i_m]), np.max(tilted[k, i_p]), 1e-30))
    im_0.set_data(ref)
    im_0.set_clim(0, ref_vmax)
    im_m.set_data(d_m)
    im_p.set_data(d_p)
    L1m = float(np.abs((tilted[k, i_m] - cp_m * ref)).sum() * (dx * dx))
    L1p = float(np.abs((tilted[k, i_p] - cp_p * ref)).sum() * (dx * dx))
    B = B_g_t[k]
    B_str = f"{B*1e3:.3f} mG" if B*1e3 >= 0.1 else f"{B*1e6:.2f} μG"
    txt.set_text(f"t = {t_ms[k]:7.2f} ms ({k+1}/{Nf})   "
                 f"B = {B_str}\n"
                 f"‖Δn^-‖_L1 = {L1m:.3e}\n"
                 f"‖Δn^+‖_L1 = {L1p:.3e}")
    return ()

stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1: frames.append(Nf - 1)
print(f"rendering {len(frames)} frames → {OUT}")
anim = FuncAnimation(fig, update, frames=frames, interval=140, blit=False)
fig.subplots_adjust(left=0.04, right=0.995, bottom=0.08, top=0.92, wspace=0.28)
anim.save(OUT, writer=PillowWriter(fps=7))
print("done.")
