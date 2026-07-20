#!/usr/bin/env python3
"""
plot_b_sweep_tilted_pair.py
===========================
GIF for the LBFGS B-sweep showing only the +16° and -16° tilted projections.

No delta panel. The animation walks from high B to low B.
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
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
H5 = os.path.join(ROOT, "b_sweep.h5")
OUT = os.path.join(ROOT, "b_sweep_tilted_pair_16deg.gif")

with h5py.File(H5, "r") as f:
    B_uG = f["B_uG"][:]
    E = f["E"][:]
    Fz_t = f["Fz"][:]
    Mvals = f["meta/m_channels"][:]
    Lbox = float(f["meta/L_box"][()])
    NX = int(f["meta/NX"][()])
    theta_q = f["meta/theta_q_deg"][:]
    tilted = np.transpose(f["n_m6_tilted"][:], (3, 2, 1, 0))  # (Nb, Nθ, NZ, NX)

order = np.argsort(B_uG)[::-1]
B_uG = B_uG[order]
E = E[order]
Fz_t = Fz_t[order]
tilted = tilted[order]

Nb = len(B_uG)
i_plus = int(np.argmin(np.abs(theta_q - 16.0)))
i_minus = int(np.argmin(np.abs(theta_q + 16.0)))
print(f"loaded {Nb} B values (descending): {list(B_uG)} μG")

dx = Lbox / NX
xs = -Lbox / 2 + dx * np.arange(NX) + dx / 2
extent = [xs[0] - dx / 2, xs[-1] + dx / 2, xs[0] - dx / 2, xs[-1] + dx / 2]

vmax = float(max(np.max(tilted[:, i_minus]), np.max(tilted[:, i_plus]), 1e-30))

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

im_m = setup(ax_m, fr"$\theta_q = {int(theta_q[i_minus])}^\circ$")
im_p = setup(ax_p, fr"$\theta_q = {int(theta_q[i_plus])}^\circ$")

hud = fig.text(0.5, 0.02, "", ha="center", fontsize=13, family="monospace")

def update(k):
    im_m.set_data(tilted[k, i_minus])
    im_p.set_data(tilted[k, i_plus])
    B = B_uG[k]
    hud.set_text(f"B = {int(B):+d} μG   ({k+1}/{Nb})   E = {E[k]:.6f}   ⟨F_z⟩ = {Fz_t[k]:+.4f}")
    return ()

fig.suptitle("B-sweep tilted imaging: +16° / -16° pair", fontsize=16, y=0.98)
fig.tight_layout(rect=[0, 0.04, 1, 0.95])

print(f"rendering {Nb} frames → {OUT}")
anim = FuncAnimation(fig, update, frames=Nb, interval=800, blit=False)
anim.save(OUT, writer=PillowWriter(fps=1.5))
print("done.")
