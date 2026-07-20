#!/usr/bin/env python3
"""
plot_rtp_10mG_goto_tilted_contrast.py
=====================================
Final-state tilted imaging for the Goto 10 mG protocol.

Shows the untilted 0° reference plus the +16° and -16° differential
images used in the thesis analysis:
  Δn^± = n_{m=-6}(±16°) - C_p(±16°) n_{m=-6}(0°)

The differential panels are normalized to [-1, 1] and use a standard
blue-white-red diverging scale:
  negative -> blue, 0 -> white, positive -> red.
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

plt.rcParams.update({
    "font.size": 13,
    "axes.titlesize": 15,
    "axes.labelsize": 13,
    "xtick.labelsize": 11,
    "ytick.labelsize": 11,
})


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
OUT = os.path.join(ROOT, "rtp_10mG_goto_tilted_contrast_16deg.png")

with h5py.File(H5, "r") as f:
    t = f["t"][:]
    omega_ref = float(f["meta/omega_ref"][()])
    Lbox = float(f["meta/L_box"][()])
    NX = int(f["meta/NX"][()])
    theta_q = f["meta/theta_q_deg"][:]
    B_g_t = f["B_gauss"][:]
    tilted = np.transpose(f["n_m6_tilted"][:], (3, 2, 1, 0))  # (Nf, Nθ, NZ, NX)

Nf = len(t)
t_ms = t / omega_ref * 1000.0
i_plus = int(np.argmin(np.abs(theta_q - 16.0)))
i_minus = int(np.argmin(np.abs(theta_q + 16.0)))
i_zero = int(np.argmin(np.abs(theta_q - 0.0)))
k = Nf - 1

theta_plus = float(theta_q[i_plus])
theta_minus = float(theta_q[i_minus])
cp_plus = projection_correction(theta_plus)
cp_minus = projection_correction(abs(theta_minus))

dx = Lbox / NX
xs = -Lbox / 2 + dx * np.arange(NX) + dx / 2
extent = [xs[0] - dx / 2, xs[-1] + dx / 2, xs[0] - dx / 2, xs[-1] + dx / 2]

ref_img = tilted[k, i_zero]
minus_img = tilted[k, i_minus]
plus_img = tilted[k, i_plus]
diff_minus = minus_img - cp_minus * ref_img
diff_plus = plus_img - cp_plus * ref_img
diff_scale = float(max(np.max(np.abs(diff_minus)), np.max(np.abs(diff_plus)), 1e-30))
diff_minus_norm = np.clip(diff_minus / diff_scale, -1.0, 1.0)
diff_plus_norm = np.clip(diff_plus / diff_scale, -1.0, 1.0)

fig, axes = plt.subplots(1, 3, figsize=(22, 7.5), gridspec_kw={"wspace": 0.25})
ax_r, ax_m, ax_p = axes

def setup_density(ax, title, img):
    vmax = float(max(np.max(ref_img), np.max(minus_img), np.max(plus_img), 1e-30))
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax, cmap=positive_cmap(),
                   aspect="equal", interpolation="bilinear")
    ax.set_title(title, pad=6)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel("z [μm]")
    ax.set_xticks(np.linspace(-Lbox / 2, Lbox / 2, 5))
    ax.set_yticks(np.linspace(-Lbox / 2, Lbox / 2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$\int dy\,|\psi_{m=-6}|^2$  [μm$^{-2}$]")
    im.set_data(img)
    return im

def setup_diff(ax, title, label):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=-1, vmax=1, cmap=signed_cmap(),
                   aspect="equal", interpolation="bilinear")
    ax.set_title(title, pad=6)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel("z [μm]")
    ax.set_xticks(np.linspace(-Lbox / 2, Lbox / 2, 5))
    ax.set_yticks(np.linspace(-Lbox / 2, Lbox / 2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(label)
    return im

im_r = setup_density(ax_r, fr"$\theta_q = {int(theta_q[i_zero])}^\circ$ reference", ref_img)
im_m = setup_diff(
    ax_m,
    fr"$\theta_q = {int(theta_q[i_minus])}^\circ$",
    r"$\Delta n^-_\mathrm{col} = n^{-\theta}_{m=-6} - C_p n^{(0)}_{m=-6}$",
)
im_p = setup_diff(
    ax_p,
    fr"$\theta_q = {int(theta_q[i_plus])}^\circ$",
    r"$\Delta n^+_\mathrm{col} = n^{+\theta}_{m=-6} - C_p n^{(0)}_{m=-6}$",
)
im_m.set_data(diff_minus_norm)
im_p.set_data(diff_plus_norm)

B = B_g_t[k]
B_str = f"{B*1e3:.3f} mG" if B * 1e3 >= 0.1 else f"{B*1e6:.2f} μG"
fig.suptitle(
    f"Goto 10 mG final snapshot | B = {B_str} | t = {t_ms[k]:.2f} ms | "
    f"Cp(±16°)={cp_plus:.4f}",
    fontsize=16, y=0.98,
)

fig.tight_layout(rect=[0, 0, 1, 0.95])
fig.savefig(OUT, dpi=180)
print(f"wrote {OUT}")
