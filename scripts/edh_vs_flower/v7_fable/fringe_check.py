#!/usr/bin/env python3
"""v7_EdH_Fable — DO fringes appear in the ACTUAL observable? (column images)

The observable is fixed by the experiment: side imaging, LOS = lab y,
column integral int dy. So the fringe question must be asked on the SAME
quantity v7 uses everywhere:
    N_m^(R)(x,z) = int dy | [R psi]_m (r) |^2 .
Tilting the axis (R = e^{-i beta F_y}) mixes old components into the m=-6
channel; the mixed amplitude squared has an interference part
    int dy [ |sum_m' R_{-6,m'} psi_m'|^2  -  sum_m' |R_{-6,m'}|^2 |psi_m'|^2 ].
Whether this shows as spatial FRINGES in (x,z) depends on whether the relative
phase winds WITHIN the (x,z) image plane. Winding about the z-axis (EdH spin
vortex) lies partly along the LOS y, so int dy PARTIALLY cancels it — this
script measures how much survives, honestly, on the column observable.

Contrast: CONTROL frame (near-pure m=-6, no transverse structure) vs TEXTURE
frame (peak transient winding). Fringe metric = coeff. of variation of the
column image on an azimuthal ring in the (x,z) plane.

env: PSI13, GOTO, OUTDIR, FR_CONTROL (0), FR_TEXTURE (peak), TILTS (0,16,45,90)
"""
import os, sys
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import (D, ms, FX, FY, rot, open_psi13, psi13_nframes,
                       load_frames_bulk, frame_times_ms, grid_axes, env)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from scipy.ndimage import map_coordinates

PSI13 = env("PSI13", "edh_v6_psi13.jld2")
GOTO = env("GOTO", "goto.h5")
OUTDIR = env("OUTDIR", ".")
os.makedirs(OUTDIR, exist_ok=True)
TILTS = [float(x) for x in env("TILTS", "0,16,45,90").split(",")]

P = open_psi13(PSI13)
nf = psi13_nframes(P)
L, Ng, ax1d, dx = grid_axes(P)
t_ms, _ = frame_times_ms(GOTO, nf)
EXT = [-L / 2, L / 2, -L / 2, L / 2]
i6, i5 = list(ms).index(-6), list(ms).index(-5)

FR_C = int(env("FR_CONTROL", "0"))
if "FR_TEXTURE" in os.environ:
    FR_T = int(os.environ["FR_TEXTURE"])
else:
    best, FR_T = -1.0, nf - 1
    for fr in range(nf):
        c5 = np.abs(load_frames_bulk(P, [fr])[0][..., i5]) ** 2
        if c5.sum() > best: best, FR_T = float(c5.sum()), fr
print(f"[fringe] control fr={FR_C} (t={t_ms[FR_C]:.1f}ms)  texture fr={FR_T} (t={t_ms[FR_T]:.1f}ms)")

def m6_column(psi, beta):
    """Column images (int dy) of the m=-6 SG channel at tilt beta about y:
    returns (full observable, incoherent baseline, interference part), each (Nx,Nz)."""
    coef = rot("y", beta)[i6, :]                      # d_{-6,m'}(beta)
    amp = np.einsum("m,xyzm->xyz", coef, psi)         # [R psi]_{-6}(r)
    n_full = np.abs(amp) ** 2
    incoh = np.einsum("m,xyzm->xyz", np.abs(coef) ** 2, np.abs(psi) ** 2)
    col = lambda a: a.sum(axis=1) * dx                # int dy  -> (Nx,Nz)
    return col(n_full), col(incoh), col(n_full - incoh)

def ring(img_xz, cx, cz, r0, nθ=180):
    ang = np.linspace(0, 2 * np.pi, nθ, endpoint=False)
    xs = cx + r0 * np.cos(ang); zs = cz + r0 * np.sin(ang)
    return ang, map_coordinates(img_xz, [xs, zs], order=1, mode="nearest")

frames = [("CONTROL (near-pure $m{=}{-}6$)", FR_C), ("TEXTURE (peak winding)", FR_T)]
ncol = len(TILTS) + 2                                 # tilt column-images + interference + ring
fig = plt.figure(figsize=(2.85 * ncol, 6.8))
gs = GridSpec(2, ncol, figure=fig, hspace=0.3, wspace=0.34,
              left=0.05, right=0.98, top=0.87, bottom=0.09)
summary = {}
for row, (lab, fr) in enumerate(frames):
    psi = load_frames_bulk(P, [fr])[0]
    ncol_dens = (np.abs(psi) ** 2).sum(axis=(1, 3)) * dx     # column density (Nx,Nz)
    ci, cj = np.unravel_index(np.argmax(ncol_dens), ncol_dens.shape)
    cx, cz = float(ci), float(cj)
    line = ncol_dens[int(cx):, int(cz)]
    r0 = max(3.0, float(np.argmax(line < 0.5 * ncol_dens.max()))
             if np.any(line < 0.5 * ncol_dens.max()) else Ng * 0.2)
    vmax = m6_column(psi, 0.0)[0].max()
    vis = {}
    for k, b in enumerate(TILTS):
        full, _, _ = m6_column(psi, b)
        a = fig.add_subplot(gs[row, k])
        a.imshow(full.T, origin="lower", extent=EXT, cmap="inferno", vmin=0, vmax=vmax)
        a.set_title(f"$\\int dy\\, n_{{-6}}^{{R_y({b:.0f}^\\circ)}}$", fontsize=9)
        a.set_xlabel("x [$\\ell_0$]", fontsize=8)
        if k == 0: a.set_ylabel(lab + "\nz [$\\ell_0$]", fontsize=8.5)
        a.tick_params(labelsize=6)
        vis[b] = float(ring(full, cx, cz, r0)[1].std()
                       / (ring(full, cx, cz, r0)[1].mean() + 1e-30))
    # isolated interference (int dy of the cross terms) at max tilt
    _, _, intf = m6_column(psi, TILTS[-1])
    ai = fig.add_subplot(gs[row, len(TILTS)])
    vlim = np.abs(intf).max() + 1e-30
    imi = ai.imshow(intf.T, origin="lower", extent=EXT, cmap="RdBu_r", vmin=-vlim, vmax=vlim)
    ai.set_title(f"interference part\n$\\int dy\\,(n_{{-6}}^{{{TILTS[-1]:.0f}^\\circ}}-$incoh$)$", fontsize=8.5)
    ai.set_xlabel("x [$\\ell_0$]", fontsize=8); ai.tick_params(labelsize=6)
    fig.colorbar(imi, ax=ai, shrink=0.8)
    # azimuthal ring profiles (x,z plane) on the column observable
    ar = fig.add_subplot(gs[row, len(TILTS) + 1])
    for b in TILTS:
        ang, v = ring(m6_column(psi, b)[0], cx, cz, r0)
        ar.plot(np.degrees(ang), v / (v.mean() + 1e-30), lw=1.3, label=f"{b:.0f}$^\\circ$")
    ar.set_title("ring on column image\n$\\int dy\\,n_{-6}(\\theta)$/mean", fontsize=8.5)
    ar.set_xlabel("azimuth in $(x,z)$ [deg]", fontsize=8); ar.set_xticks([0, 180, 360])
    ar.tick_params(labelsize=6); ar.legend(fontsize=6.5, title="tilt", title_fontsize=6.5)
    ar.grid(alpha=0.3)
    ar.text(0.02, 0.02, "fringe CV@" + f"{TILTS[-1]:.0f}$^\\circ$={vis[TILTS[-1]]:.2f}",
            transform=ar.transAxes, fontsize=7.5, va="bottom",
            bbox=dict(fc="w", alpha=0.7, ec="0.7"))
    summary[lab] = vis

fig.suptitle("Do fringes appear in the ACTUAL observable ($\\int dy$ column image, LOS=$\\hat y$)? "
             "— real 96³ EdH data, $m{=}{-}6$ channel\n"
             "column integration along the line of sight partially cancels winding about $z$; "
             "this is what the side camera truly records", fontsize=10.5)
out = os.path.join(OUTDIR, "v7_fringe_check.png")
fig.savefig(out, dpi=140); plt.close(fig)
print("[fringe] column-image fringe visibility (CV on x-z ring):")
for lab, vis in summary.items():
    print(f"  {lab}: " + ", ".join(f"{b:.0f}deg={cv:.3f}" for b, cv in vis.items()))
print(f"[fringe] wrote {out}")
