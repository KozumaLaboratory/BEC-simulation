#!/usr/bin/env python3
"""
plot_rtp_60uG.py
================
GIF for RTP @ B=60 μG starting from LBFGS-polished ground state.

Layout (3 rows × 5 cols, image rows oversized for readability):
  Row 1 (xy z=0):    n_{m=-6}, n_{m=-5}, n_{m=-4}, arg ψ_{m=-6}, F-field
  Row 2 (xz y=0):    n_{m=-6}, n_{m=-5}, n_{m=-4}, arg ψ_{m=-6}, F-field
  Row 3 (scalars):   populations bar (current)  |  E(t)  |  ‖ψ‖²(t)  |  HUD

Phases: HSV (rainbow). Spin arrows: same length, viridis color = |F_perp|.
Density panels share their own vmax per channel for cross-frame comparison.
Animation paced 70% of previous (fps=7 vs 10) for slower visual reading.
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib import colors as mcolors

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 9,
    "axes.linewidth": 0.8,
})

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5      = os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_60uG_dt0p001.h5"))
OUT_GIF = H5.replace(".h5", ".gif")

with h5py.File(H5, "r") as f:
    t    = f["t"][:]
    E    = f["E"][:]
    Nrm  = f["N"][:]
    Fz_t = f["Fz"][:]
    Mvals = f["meta/m_channels"][:]
    Lbox  = float(f["meta/L_box"][()])
    NX    = int(f["meta/NX"][()])
    B_g   = float(f["meta/B_gauss"][()])
    omega_ref = float(f["meta/omega_ref"][()])
    # axes reversed by h5py vs Julia
    n_xy  = np.transpose(f["n_m_xy"][:], (3, 2, 1, 0))   # (Nf, D, NX, NX)
    n_xz  = np.transpose(f["n_m_xz"][:], (3, 2, 1, 0))
    Fx_xy = f["Fx_xy"][:].transpose(2, 1, 0)             # (Nf, NX, NX)
    Fy_xy = f["Fy_xy"][:].transpose(2, 1, 0)
    Fz_xy = f["Fz_xy"][:].transpose(2, 1, 0)
    Fx_xz = f["Fx_xz"][:].transpose(2, 1, 0)
    Fy_xz = f["Fy_xz"][:].transpose(2, 1, 0)
    Fz_xz = f["Fz_xz"][:].transpose(2, 1, 0)
    arg_xy = f["arg_psi_m6_xy"][:].transpose(2, 1, 0)
    arg_xz = f["arg_psi_m6_xz"][:].transpose(2, 1, 0)

Nf = len(t)
# Internal time → ms
t_ms = t / omega_ref * 1000.0
print(f"loaded {Nf} snapshots, NX={NX}, L={Lbox}μm, B={B_g*1e6:.1f}μG, T={t_ms[-1]:.2f}ms")

def m_idx(m): return int(np.where(Mvals == m)[0][0])
# Display m channels (request: m = -6, -5, -4)
M_DISPLAY = (-6, -5, -4)
c_disp = [m_idx(m) for m in M_DISPLAY]

dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

# Per-channel vmax (global across all frames + both views)
vmax_per_m = []
for ci in c_disp:
    vmax = max(float(np.max(n_xy[:, ci])), float(np.max(n_xz[:, ci])), 1e-30)
    vmax_per_m.append(vmax)

Fperp_xy = np.sqrt(Fx_xy**2 + Fy_xy**2)
Fperp_xz = np.sqrt(Fx_xz**2 + Fz_xz**2)  # in xz the in-plane spin is (Fx, Fz)
Fperp_global_xy = float(np.max(Fperp_xy))
Fperp_global_xz = float(np.max(Fperp_xz))

# --- Figure: 3 rows × 5 cols, image rows oversized ---
fig = plt.figure(figsize=(26, 20))
gs = fig.add_gridspec(3, 5, height_ratios=[3.6, 3.6, 1.6],
                     hspace=0.34, wspace=0.34,
                     left=0.04, right=0.98, top=0.95, bottom=0.04)

# Row 1: xy
ax_xy = [fig.add_subplot(gs[0, j]) for j in range(5)]
# Row 2: xz
ax_xz = [fig.add_subplot(gs[1, j]) for j in range(5)]
# Row 3 scalars: populations | E(t) | N(t) | HUD (2 cols)
ax_pop = fig.add_subplot(gs[2, 0])
ax_E   = fig.add_subplot(gs[2, 1])
ax_N   = fig.add_subplot(gs[2, 2])
ax_sum = fig.add_subplot(gs[2, 3:5]); ax_sum.axis("off")

def setup_density(ax, vmax, title, ylab):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax, cmap="magma", aspect="equal",
                   interpolation="bilinear")
    ax.set_title(title, pad=4)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.tick_params(length=3)
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.ax.tick_params(labelsize=8, length=2)
    return im

def setup_phase(ax, title, ylab):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=-np.pi, vmax=np.pi, cmap="hsv",
                   aspect="equal", interpolation="bilinear")
    ax.set_title(title, pad=4)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.tick_params(length=3)
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02,
                      ticks=[-np.pi, 0, np.pi])
    cb.ax.set_yticklabels([r"$-\pi$", "0", r"$+\pi$"])
    cb.ax.tick_params(labelsize=8, length=2)
    return im

# Density panels (3 m channels × 2 views)
im_dens_xy = []
im_dens_xz = []
for col, (m, ci, vmax) in enumerate(zip(M_DISPLAY, c_disp, vmax_per_m)):
    im_dens_xy.append(setup_density(
        ax_xy[col], vmax, fr"$|\psi_{{m={m:+d}}}|^2$  (xy, z=0)", "y [μm]"))
    im_dens_xz.append(setup_density(
        ax_xz[col], vmax, fr"$|\psi_{{m={m:+d}}}|^2$  (xz, y=0)", "z [μm]"))

# Phase panels (col 3)
im_ph_xy = setup_phase(ax_xy[3], r"$\arg\psi_{m=-6}$  (xy, z=0)", "y [μm]")
im_ph_xz = setup_phase(ax_xz[3], r"$\arg\psi_{m=-6}$  (xz, y=0)", "z [μm]")

# Spin vector field panels (col 4)
SK = 2
Xa = xs[::SK]
mesh_X, mesh_Y = np.meshgrid(Xa, Xa, indexing="xy")

def setup_field(ax, title, ylab, vmax_perp, cb_label):
    ax.set_facecolor("#222")
    ax.set_title(title, pad=4)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_xlim(extent[0], extent[1]); ax.set_ylim(extent[2], extent[3])
    ax.set_aspect("equal")
    ax.tick_params(length=3, colors="white")
    for spine in ax.spines.values(): spine.set_color("white")
    Q = ax.quiver(mesh_X, mesh_Y,
                  np.zeros_like(mesh_X), np.zeros_like(mesh_X),
                  np.zeros_like(mesh_X),
                  cmap="viridis", norm=mcolors.Normalize(vmin=0, vmax=vmax_perp),
                  pivot="middle", scale=28, width=0.005,
                  headwidth=4, headlength=5, headaxislength=4.5)
    cb = plt.colorbar(Q, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(cb_label, fontsize=9)
    cb.ax.tick_params(labelsize=8, length=2)
    return Q

Q_xy = setup_field(ax_xy[4], r"spin field $\mathbf{F}_\perp$  (xy, z=0)", "y [μm]",
                   Fperp_global_xy, r"$|F_\perp|$")
Q_xz = setup_field(ax_xz[4], r"spin field $(F_x, F_z)$  (xz, y=0)", "z [μm]",
                   Fperp_global_xz, r"$\sqrt{F_x^2+F_z^2}$")

# --- Populations bar (current snapshot) ---
cmap_m = plt.get_cmap("turbo")
D_ch = len(Mvals)
m_axis = np.arange(D_ch)
bar_colors = [cmap_m(c / max(D_ch-1, 1)) for c in range(D_ch)]
# Slice integral with dx² factor → proper area integral
slice_int_xy = n_xy * (dx * dx)   # shape (Nf, D, NX, NX), per-cell area
pop_per_frame = slice_int_xy.sum(axis=(2, 3))  # (Nf, D), units of μm⁻¹ × μm² = μm⁻¹

pop_bars = ax_pop.bar(m_axis, np.zeros(D_ch), color=bar_colors,
                      edgecolor="black", linewidth=0.6)
ax_pop.set_xticks(m_axis)
ax_pop.set_xticklabels([f"{int(Mvals[c]):+d}" for c in range(D_ch)])
ax_pop.set_xlabel("m")
ax_pop.set_ylabel(r"$\int dx\,dy\, |\psi_m(z{=}0)|^2$  [μm⁻¹]")
ax_pop.set_title("populations  (current xy-slice area integral)")
pop_scale = float(np.max(pop_per_frame))
ax_pop.set_ylim(0, pop_scale * 1.1 + 1e-30)
ax_pop.grid(alpha=0.25, axis="y")

# --- Energy panel ---
ax_E.plot(t_ms, E, "k-", lw=1.5)
ax_E.set_xlabel("t [ms]"); ax_E.set_ylabel(r"$E$")
ax_E.set_title("energy")
ax_E.grid(alpha=0.25)
v_E = ax_E.axvline(t_ms[0], color="r", lw=1.0)
Erng = float(np.max(E) - np.min(E))
if Erng > 0:
    ax_E.set_ylim(float(np.min(E)) - 0.05*Erng, float(np.max(E)) + 0.05*Erng)

# --- Norm panel ---
ax_N.plot(t_ms, Nrm, "C0-", lw=1.5)
ax_N.set_xlabel("t [ms]"); ax_N.set_ylabel(r"$\|\psi\|^2$")
ax_N.set_title("norm conservation")
ax_N.grid(alpha=0.25)
v_N = ax_N.axvline(t_ms[0], color="r", lw=1.0)
Nrng = float(np.max(Nrm) - np.min(Nrm))
if Nrng < 1e-10:
    ax_N.set_ylim(1 - 1e-10, 1 + 1e-10)
else:
    ax_N.set_ylim(float(np.min(Nrm)) - 0.05*Nrng, float(np.max(Nrm)) + 0.05*Nrng)

# --- HUD ---
hud_lines = [
    ax_sum.text(0.04, 0.85, "", fontsize=16, weight="bold", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.62, "", fontsize=14, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.40, "", fontsize=14, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.18, "", fontsize=14, family="monospace", transform=ax_sum.transAxes),
]

suptitle = fig.suptitle(
    f"RTP @ B={B_g*1e6:.1f} μG  (LBFGS-polished ground state)  |  "
    f"$^{{151}}$Eu F=6, box={Lbox}μm/{NX}³, T_RTP={t_ms[-1]:.2f}ms",
    fontsize=15, y=0.985,
)

def update(k):
    # xy + xz densities
    for col, ci in enumerate(c_disp):
        im_dens_xy[col].set_data(n_xy[k, ci].T)
        im_dens_xz[col].set_data(n_xz[k, ci].T)
    # phases
    im_ph_xy.set_data(arg_xy[k].T)
    im_ph_xz.set_data(arg_xz[k].T)
    # spin field xy: arrow dir = unit(F_x, F_y), color = |F_perp|
    Ux = Fx_xy[k, ::SK, ::SK]; Vy = Fy_xy[k, ::SK, ::SK]
    mxy = np.sqrt(Ux**2 + Vy**2); s = np.where(mxy > 1e-12, mxy, 1.0)
    Q_xy.set_UVC(Ux/s, Vy/s, mxy)
    # spin field xz: in-plane = (F_x, F_z)
    Ux2 = Fx_xz[k, ::SK, ::SK]; Vz = Fz_xz[k, ::SK, ::SK]
    mxz = np.sqrt(Ux2**2 + Vz**2); s2 = np.where(mxz > 1e-12, mxz, 1.0)
    Q_xz.set_UVC(Ux2/s2, Vz/s2, mxz)
    # cursors
    v_E.set_xdata([t_ms[k], t_ms[k]])
    v_N.set_xdata([t_ms[k], t_ms[k]])
    # bars (per-m area integral at z=0 slice)
    for c, b in enumerate(pop_bars):
        b.set_height(pop_per_frame[k, c])
    # HUD
    hud_lines[0].set_text(f"t = {t_ms[k]:7.3f} ms   ({k+1}/{Nf})")
    hud_lines[1].set_text(f"E       = {E[k]:.7f}")
    hud_lines[2].set_text(f"‖ψ‖²    = {Nrm[k]:.10f}")
    hud_lines[3].set_text(f"⟨F_z⟩   = {Fz_t[k]:+.4f}   (per atom)")
    return ()

# Render: same frame count, slower fps (10 → 7 ≈ 70% speed)
stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1: frames.append(Nf - 1)
print(f"rendering {len(frames)} frames (stride={stride}) → {OUT_GIF}")
anim = FuncAnimation(fig, update, frames=frames, interval=140, blit=False)
anim.save(OUT_GIF, writer=PillowWriter(fps=7))
print("done.")
