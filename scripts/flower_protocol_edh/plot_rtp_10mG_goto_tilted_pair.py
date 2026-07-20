#!/usr/bin/env python3
"""
plot_rtp_10mG_goto_tilted_pair.py
=================================
Static +16° / -16° tilted imaging for the final state of the Goto 10 mG run.

No delta panel. This is a single screenshot-style figure that shows the two
tilted projections side by side.
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


def positive_cmap():
    return plt.get_cmap("viridis")

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_10mG_goto.h5"))
OUT = os.path.join(ROOT, "rtp_10mG_goto_tilted_pair_16deg.png")

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
k = Nf - 1

dx = Lbox / NX
xs = -Lbox / 2 + dx * np.arange(NX) + dx / 2
extent = [xs[0] - dx / 2, xs[-1] + dx / 2, xs[0] - dx / 2, xs[-1] + dx / 2]

im_m = tilted[k, i_minus]
im_p = tilted[k, i_plus]
vmax = float(max(np.max(im_m), np.max(im_p), 1e-30))

fig, axes = plt.subplots(1, 2, figsize=(15, 6.5), gridspec_kw={"wspace": 0.25})
ax_m, ax_p = axes

def setup(ax, title):
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
    return im

im_m_pl = setup(ax_m, fr"$\theta_q = {int(theta_q[i_minus])}^\circ$")
im_p_pl = setup(ax_p, fr"$\theta_q = {int(theta_q[i_plus])}^\circ$")
im_m_pl.set_data(im_m)
im_p_pl.set_data(im_p)

B = B_g_t[k]
B_str = f"{B*1e3:.3f} mG" if B * 1e3 >= 0.1 else f"{B*1e6:.2f} μG"
fig.suptitle(
    f"Goto 10 mG protocol final snapshot | B = {B_str} | t = {t_ms[k]:.2f} ms",
    fontsize=16, y=0.98,
)

fig.tight_layout(rect=[0, 0, 1, 0.95])
fig.savefig(OUT, dpi=180)
print(f"wrote {OUT}")
