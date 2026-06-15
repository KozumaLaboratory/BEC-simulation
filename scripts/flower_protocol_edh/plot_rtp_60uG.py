#!/usr/bin/env python3
"""
plot_rtp_60uG.py
================
GIF for RTP @ B=60 μG starting from ITP-converged ψ.

Layout (4 rows × 5 cols):
  Row 1 (xy z=0):    n_{+6}, n_{0}, n_{-6}, arg ψ_{-6}, F-field
  Row 2 (xz y=0):    n_{+6}, n_{0}, n_{-6}, arg ψ_{-6}, F-field
  Row 3 (tilted col-density, y-integrated):
                     θ=-16°, θ=0°, θ=+16°, E(t), ‖ψ‖²(t)
  Row 4: populations bar (current) + HUD text

All phases use HSV (rainbow). Arrows: same length, color = |F_⊥|, density = NX/2.
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
    "font.size": 10,
    "axes.titlesize": 11,
    "axes.labelsize": 10,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 8,
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
    Mz   = f["Mz"][:]
    Fz_t = f["Fz"][:]
    Mvals = f["meta/m_channels"][:]
    Lbox  = float(f["meta/L_box"][()])
    NX    = int(f["meta/NX"][()])
    B_g   = float(f["meta/B_gauss"][()])
    omega_ref = float(f["meta/omega_ref"][()])
    theta_q = f["meta/theta_q_deg"][:]
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
    tilted = np.transpose(f["n_m6_tilted"][:], (3, 2, 1, 0))  # (Nf, Ntheta, NZ, NX)

Nf = len(t)
# Convert internal time → ms (t_ms = t_internal / ω_ref · 1000)
t_ms = t / omega_ref * 1000.0
print(f"loaded {Nf} snapshots, NX={NX}, L={Lbox}μm, B={B_g*1e6:.1f}μG, T={t_ms[-1]:.2f}ms")

def m_idx(m): return int(np.where(Mvals == m)[0][0])
c_plus = m_idx(+6); c_zero = m_idx(0); c_minus = m_idx(-6)

dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

# Global vmaxes
vmax_plus  = float(max(np.max(n_xy[:, c_plus]),  np.max(n_xz[:, c_plus])))
vmax_zero  = float(max(np.max(n_xy[:, c_zero]),  np.max(n_xz[:, c_zero]), 1e-30))
vmax_minus = float(max(np.max(n_xy[:, c_minus]), np.max(n_xz[:, c_minus])))
vmax_tilt  = float(np.max(tilted))
Fp_xy = np.sqrt(Fx_xy**2 + Fy_xy**2); Fp_xy_max = float(np.max(Fp_xy))
Fp_xz = np.sqrt(Fx_xz**2 + Fz_xz**2); Fp_xz_max = float(np.max(Fp_xz))

fig = plt.figure(figsize=(24, 18))
gs = fig.add_gridspec(4, 5, height_ratios=[3.0, 3.0, 2.8, 1.4],
                     hspace=0.42, wspace=0.40,
                     left=0.04, right=0.98, top=0.94, bottom=0.05)

# Row 1: xy
ax_pp_xy = fig.add_subplot(gs[0, 0])
ax_p0_xy = fig.add_subplot(gs[0, 1])
ax_pm_xy = fig.add_subplot(gs[0, 2])
ax_ph_xy = fig.add_subplot(gs[0, 3])
ax_F_xy  = fig.add_subplot(gs[0, 4])

# Row 2: xz
ax_pp_xz = fig.add_subplot(gs[1, 0])
ax_p0_xz = fig.add_subplot(gs[1, 1])
ax_pm_xz = fig.add_subplot(gs[1, 2])
ax_ph_xz = fig.add_subplot(gs[1, 3])
ax_F_xz  = fig.add_subplot(gs[1, 4])

# Row 3: tilted + small scalar plots
ax_tm = fig.add_subplot(gs[2, 0])
ax_t0 = fig.add_subplot(gs[2, 1])
ax_tp = fig.add_subplot(gs[2, 2])
ax_E  = fig.add_subplot(gs[2, 3])
ax_N  = fig.add_subplot(gs[2, 4])

# Row 4: bar chart + HUD
ax_pop = fig.add_subplot(gs[3, 0:3])
ax_sum = fig.add_subplot(gs[3, 3:5]); ax_sum.axis("off")

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

im_pp_xy = setup_density(ax_pp_xy, vmax_plus,  r"$|\psi_{m=+6}|^2$  (xy, z=0)", "y [μm]")
im_p0_xy = setup_density(ax_p0_xy, vmax_zero,  r"$|\psi_{m=0}|^2$  (xy, z=0)",  "y [μm]")
im_pm_xy = setup_density(ax_pm_xy, vmax_minus, r"$|\psi_{m=-6}|^2$  (xy, z=0)", "y [μm]")
im_pp_xz = setup_density(ax_pp_xz, vmax_plus,  r"$|\psi_{m=+6}|^2$  (xz, y=0)", "z [μm]")
im_p0_xz = setup_density(ax_p0_xz, vmax_zero,  r"$|\psi_{m=0}|^2$  (xz, y=0)",  "z [μm]")
im_pm_xz = setup_density(ax_pm_xz, vmax_minus, r"$|\psi_{m=-6}|^2$  (xz, y=0)", "z [μm]")

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

im_ph_xy = setup_phase(ax_ph_xy, r"$\arg\psi_{m=-6}$  (xy, z=0)", "y [μm]")
im_ph_xz = setup_phase(ax_ph_xz, r"$\arg\psi_{m=-6}$  (xz, y=0)", "z [μm]")

# Spin arrow panels
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
                  pivot="middle", scale=30, width=0.005,
                  headwidth=4, headlength=5, headaxislength=4.5)
    cb = plt.colorbar(Q, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(cb_label, fontsize=8)
    cb.ax.tick_params(labelsize=8, length=2)
    return Q

Q_xy = setup_field(ax_F_xy, r"spin field $\mathbf{F}_\perp$  (xy)", "y [μm]",
                   Fp_xy_max, r"$|F_\perp|$")
Q_xz = setup_field(ax_F_xz, r"spin field $(F_x, F_z)$  (xz)", "z [μm]",
                   Fp_xz_max, r"$\sqrt{F_x^2+F_z^2}$")

# Tilted column-density panels: y-integrated |ψ_{m=-6}|² post-rotation
# axes: (x, z) — z vertical, x horizontal
def setup_tilt(ax, title):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax_tilt, cmap="inferno", aspect="equal",
                   interpolation="bilinear")
    ax.set_title(title, pad=4)
    ax.set_xlabel("x [μm]"); ax.set_ylabel("z [μm]")
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.tick_params(length=3)
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.ax.tick_params(labelsize=8, length=2)
    return im

im_tm = setup_tilt(ax_tm, fr"$\int dy\, |\psi_{{m=-6}}|^2$  @ $\theta_q={int(theta_q[0])}°$")
im_t0 = setup_tilt(ax_t0, fr"$\int dy\, |\psi_{{m=-6}}|^2$  @ $\theta_q={int(theta_q[1])}°$")
im_tp = setup_tilt(ax_tp, fr"$\int dy\, |\psi_{{m=-6}}|^2$  @ $\theta_q={int(theta_q[2])}°$")

# Conservation panels
ax_E.plot(t_ms, E, "k-", lw=1.5)
ax_E.set_xlabel("t [ms]"); ax_E.set_ylabel("E")
ax_E.set_title("energy")
ax_E.grid(alpha=0.25)
v_E = ax_E.axvline(t_ms[0], color="r", lw=1.0)
# y-tight bounded by [min, max] with small pad to show drift
Erng = float(np.max(E) - np.min(E))
if Erng > 0:
    ax_E.set_ylim(float(np.min(E)) - 0.05*Erng, float(np.max(E)) + 0.05*Erng)

ax_N.plot(t_ms, Nrm, "C0-", lw=1.5)
ax_N.set_xlabel("t [ms]"); ax_N.set_ylabel(r"$\|\psi\|^2$")
ax_N.set_title("norm conservation")
ax_N.grid(alpha=0.25)
v_N = ax_N.axvline(t_ms[0], color="r", lw=1.0)
# Y range tight around 1.0 to make drift visible
Nrng = float(np.max(Nrm) - np.min(Nrm))
if Nrng < 1e-10:
    ax_N.set_ylim(1 - 1e-10, 1 + 1e-10)
else:
    ax_N.set_ylim(float(np.min(Nrm)) - 0.05*Nrng, float(np.max(Nrm)) + 0.05*Nrng)

# Population bar
cmap_m = plt.get_cmap("turbo")
D_ch = len(Mvals)
m_axis = np.arange(D_ch)
bar_colors = [cmap_m(c / max(D_ch-1, 1)) for c in range(D_ch)]
n_m_per_frame = (n_xy.sum(axis=(2, 3)) + n_xz.sum(axis=(2, 3))) / 2  # rough per-frame pop trace, used only for y-axis scale
pop_bars = ax_pop.bar(m_axis, np.zeros(D_ch), color=bar_colors,
                      edgecolor="black", linewidth=0.6)
ax_pop.set_xticks(m_axis)
ax_pop.set_xticklabels([f"{int(Mvals[c]):+d}" for c in range(D_ch)])
ax_pop.set_xlabel("m")
ax_pop.set_ylabel(r"$\int|\psi_m(x,y,z{=}0)|^2 dA$  (z=0 slice integral)")
ax_pop.set_title("populations  (current snapshot, xy-slice integral)")
pop_scale = float(np.max(n_xy.sum(axis=(2,3))))
ax_pop.set_ylim(0, pop_scale * 1.1 + 1e-30)
ax_pop.grid(alpha=0.25, axis="y")

# HUD
hud_lines = [
    ax_sum.text(0.04, 0.85, "", fontsize=14, weight="bold", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.65, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.45, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.25, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.05, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
]

suptitle = fig.suptitle(
    f"RTP @ B={B_g*1e6:.1f} μG  (constant hold from ITP ground state)  |  "
    f"$^{{151}}$Eu F=6, box={Lbox}μm/{NX}³, T_RTP={t_ms[-1]:.1f}ms",
    fontsize=14, y=0.985,
)

def update(k):
    im_pp_xy.set_data(n_xy[k, c_plus].T)
    im_p0_xy.set_data(n_xy[k, c_zero].T)
    im_pm_xy.set_data(n_xy[k, c_minus].T)
    im_ph_xy.set_data(arg_xy[k].T)

    im_pp_xz.set_data(n_xz[k, c_plus].T)
    im_p0_xz.set_data(n_xz[k, c_zero].T)
    im_pm_xz.set_data(n_xz[k, c_minus].T)
    im_ph_xz.set_data(arg_xz[k].T)

    Ux = Fx_xy[k, ::SK, ::SK]; Vy = Fy_xy[k, ::SK, ::SK]
    mxy = np.sqrt(Ux**2 + Vy**2); s = np.where(mxy > 1e-12, mxy, 1.0)
    Q_xy.set_UVC(Ux/s, Vy/s, mxy)
    Ux2 = Fx_xz[k, ::SK, ::SK]; Vz = Fz_xz[k, ::SK, ::SK]
    mxz = np.sqrt(Ux2**2 + Vz**2); s2 = np.where(mxz > 1e-12, mxz, 1.0)
    Q_xz.set_UVC(Ux2/s2, Vz/s2, mxz)

    # tilted: shape (Nf, Ntheta, NZ, NX). imshow expects (rows=z, cols=x)
    im_tm.set_data(tilted[k, 0])
    im_t0.set_data(tilted[k, 1])
    im_tp.set_data(tilted[k, 2])

    v_E.set_xdata([t_ms[k], t_ms[k]])
    v_N.set_xdata([t_ms[k], t_ms[k]])

    # populations from xy slice integral as rough proxy
    pop_now = n_xy[k].sum(axis=(1, 2))
    for c, b in enumerate(pop_bars):
        b.set_height(pop_now[c])

    hud_lines[0].set_text(f"t = {t_ms[k]:7.3f} ms   ({k+1}/{Nf})")
    hud_lines[1].set_text(f"E       = {E[k]:.6f}")
    hud_lines[2].set_text(f"‖ψ‖²    = {Nrm[k]:.10f}")
    hud_lines[3].set_text(f"M_z     = {Mz[k]:+.6f}")
    hud_lines[4].set_text(f"⟨F_z⟩/atom = {Fz_t[k]:+.4f}")
    return ()

# Cap frames at ~200 for GIF size
stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1: frames.append(Nf - 1)
print(f"rendering {len(frames)} frames (stride={stride}) → {OUT_GIF}")
anim = FuncAnimation(fig, update, frames=frames, interval=80, blit=False)
anim.save(OUT_GIF, writer=PillowWriter(fps=10))
print("done.")
