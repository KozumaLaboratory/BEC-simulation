#!/usr/bin/env python3
"""
plot_itp_trace.py
=================
Polished GIF for ITP imaginary-time trace at B=60μG.

Layout (4 rows × 5 cols):
  Row 1 (xy slices @ z=0):  n_{m=+6}  n_{m=0}  n_{m=-6}  arg ψ_{-6}  F_xy field
  Row 2 (xz slices @ y=0):  n_{m=+6}  n_{m=0}  n_{m=-6}  arg ψ_{-6}  F_xz field
  Row 3 (scalars):          populations(τ)         E(τ)          conv(τ)
  Row 4 (scalars):          ⟨F_z⟩, |F_⊥|(τ)         ⟨L_z⟩(τ)       — running cursor on all

Spin arrows: COLOR encodes magnitude |F_perp| (not size). All arrows same length.
            Density: every 2 cells (NX/2 = 32 arrows per axis at NX=64).
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
from matplotlib import colors as mcolors

# --- Style ---
plt.rcParams.update({
    "font.size": 10,
    "axes.titlesize": 11,
    "axes.labelsize": 10,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 8,
    "axes.linewidth": 0.8,
    "xtick.direction": "out",
    "ytick.direction": "out",
})

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.path.join(ROOT, "itp_trace_60uG.h5")
OUT_GIF = os.path.join(ROOT, "itp_trace_60uG.gif")

# --- Load ---
with h5py.File(H5, "r") as f:
    step = f["step"][:]
    tau  = f["tau"][:]
    E    = f["E"][:]
    drho = f["drho"][:]
    dpsi = f["dpsi"][:]
    Fz_t = f["Fz"][:]
    Fp_t = f["F_perp"][:]
    Lz_t = f["Lz"][:]
    n_m  = f["n_m"][:]                                            # (Nf, D)
    n_xy = np.transpose(f["n_m_xy"][:],  (3, 2, 1, 0))            # (Nf, D, NX, NX)
    n_xz = np.transpose(f["n_m_xz"][:],  (3, 2, 1, 0))            # (Nf, D, NX, NX)
    Fx_xy = f["Fx_xy"][:].transpose(2, 1, 0)
    Fy_xy = f["Fy_xy"][:].transpose(2, 1, 0)
    Fz_xy = f["Fz_xy"][:].transpose(2, 1, 0)
    Fx_xz = f["Fx_xz"][:].transpose(2, 1, 0)
    Fy_xz = f["Fy_xz"][:].transpose(2, 1, 0)
    Fz_xz = f["Fz_xz"][:].transpose(2, 1, 0)
    arg_xy = f["arg_psi_m6_xy"][:].transpose(2, 1, 0)
    arg_xz = f["arg_psi_m6_xz"][:].transpose(2, 1, 0)
    Lbox  = float(f["meta/L_box"][()])
    NX    = int(f["meta/NX"][()])
    Mvals = f["meta/m_channels"][:]
    B_g   = float(f["meta/B_gauss"][()])

Nf = len(step)
print(f"loaded {Nf} snapshots, NX={NX}, L={Lbox}μm, B={B_g*1e6:.1f}μG")

def m_idx(m): return int(np.where(Mvals == m)[0][0])
c_plus = m_idx(+6); c_zero = m_idx(0); c_minus = m_idx(-6)

dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

# --- vmaxes (global so frames are comparable) ---
vmax_plus  = max(np.max(n_xy[:, c_plus]),  np.max(n_xz[:, c_plus]),  1e-30)
vmax_zero  = max(np.max(n_xy[:, c_zero]),  np.max(n_xz[:, c_zero]),  1e-30)
vmax_minus = max(np.max(n_xy[:, c_minus]), np.max(n_xz[:, c_minus]), 1e-30)
Fperp_xy = np.sqrt(Fx_xy**2 + Fy_xy**2)
Fperp_xz = np.sqrt(Fx_xz**2 + Fz_xz**2)   # in xz the in-plane spin is (Fx, Fz)
Fperp_global_xy = float(np.max(Fperp_xy))
Fperp_global_xz = float(np.max(Fperp_xz))

# --- Figure ---
fig = plt.figure(figsize=(24, 18), constrained_layout=False)
gs = fig.add_gridspec(4, 5,
                     height_ratios=[3.2, 3.2, 1.6, 1.6],
                     hspace=0.40, wspace=0.40,
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

# Row 3
ax_pop = fig.add_subplot(gs[2, 0:2])
ax_E   = fig.add_subplot(gs[2, 2])
ax_dr  = fig.add_subplot(gs[2, 3:5])

# Row 4
ax_F   = fig.add_subplot(gs[3, 0:2])
ax_L   = fig.add_subplot(gs[3, 2])
ax_sum = fig.add_subplot(gs[3, 3:5]); ax_sum.axis("off")

# --- Density panels (xy + xz pairs) ---
def setup_density(ax, vmax, title, ylab):
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax, cmap="magma", aspect="equal",
                   interpolation="bilinear")
    ax.set_title(title, pad=4)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.tick_params(length=3)
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.ax.tick_params(labelsize=8, length=2)
    return im

im_pp_xy = setup_density(ax_pp_xy, vmax_plus,  r"$|\psi_{m=+6}|^2$  (z=0)", "y [μm]")
im_p0_xy = setup_density(ax_p0_xy, vmax_zero,  r"$|\psi_{m=0}|^2$  (z=0)",  "y [μm]")
im_pm_xy = setup_density(ax_pm_xy, vmax_minus, r"$|\psi_{m=-6}|^2$  (z=0)", "y [μm]")
im_pp_xz = setup_density(ax_pp_xz, vmax_plus,  r"$|\psi_{m=+6}|^2$  (y=0)", "z [μm]")
im_p0_xz = setup_density(ax_p0_xz, vmax_zero,  r"$|\psi_{m=0}|^2$  (y=0)",  "z [μm]")
im_pm_xz = setup_density(ax_pm_xz, vmax_minus, r"$|\psi_{m=-6}|^2$  (y=0)", "z [μm]")

# --- Phase panels (cyclic) ---
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

im_ph_xy = setup_phase(ax_ph_xy, r"$\arg\psi_{m=-6}$  (z=0)", "y [μm]")
im_ph_xz = setup_phase(ax_ph_xz, r"$\arg\psi_{m=-6}$  (y=0)", "z [μm]")

# --- Spin vector field panels: arrow direction only, color = |F_perp| ---
SK = 2                  # every 2 cells → 32×32 arrows at NX=64
Xa = xs[::SK]
mesh_X, mesh_Y = np.meshgrid(Xa, Xa, indexing="xy")

def setup_field(ax, title, ylab, vmax_perp, axis2_label):
    ax.set_facecolor("#222")
    ax.set_title(title, pad=4)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_xlim(extent[0], extent[1]); ax.set_ylim(extent[2], extent[3])
    ax.set_aspect("equal")
    ax.tick_params(length=3, colors="white", which="both")
    for spine in ax.spines.values():
        spine.set_color("white")
    Q = ax.quiver(mesh_X, mesh_Y,
                  np.zeros_like(mesh_X), np.zeros_like(mesh_X),
                  np.zeros_like(mesh_X),                  # color array
                  cmap="viridis", norm=mcolors.Normalize(vmin=0, vmax=vmax_perp),
                  pivot="middle", scale=30, width=0.005,
                  headwidth=4, headlength=5, headaxislength=4.5)
    cb = plt.colorbar(Q, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(axis2_label, fontsize=8)
    cb.ax.tick_params(labelsize=8, length=2)
    return Q

Q_xy = setup_field(ax_F_xy, r"spin field $\mathbf{F}_\perp$  (z=0)", "y [μm]",
                   Fperp_global_xy, r"$|F_\perp|$")
Q_xz = setup_field(ax_F_xz, r"spin field $(F_x,F_z)$  (y=0)", "z [μm]",
                   Fperp_global_xz, r"$\sqrt{F_x^2+F_z^2}$")

# --- Scalar time-series ---
# Populations: bar chart of CURRENT snapshot (no time axis).
cmap_m = plt.get_cmap("turbo")
D_ch = n_m.shape[1]
m_axis = np.arange(D_ch)
bar_colors = [cmap_m(c / max(D_ch-1, 1)) for c in range(D_ch)]
pop_bars = ax_pop.bar(m_axis, np.zeros(D_ch), color=bar_colors,
                      edgecolor="black", linewidth=0.6)
pop_max = float(np.max(n_m))
ax_pop.set_xticks(m_axis)
ax_pop.set_xticklabels([f"{int(Mvals[c]):+d}" for c in range(D_ch)])
ax_pop.set_xlabel("m")
ax_pop.set_ylabel(r"$n_m$  (population)")
ax_pop.set_title("populations  (current snapshot)")
ax_pop.set_ylim(0, pop_max * 1.1)
ax_pop.grid(alpha=0.25, axis="y")
v_pop = None  # no time cursor in bar chart

ax_E.plot(tau, E, "k-", lw=1.6)
ax_E.set_xlabel(r"$\tau$"); ax_E.set_ylabel(r"$E$")
ax_E.set_title("total energy")
ax_E.grid(alpha=0.25)
v_E = ax_E.axvline(tau[0], color="r", lw=1.0)

ax_dr.plot(tau[1:], drho[1:], "C0-", lw=1.6, label=r"$\delta\rho/\rho_{\max}$")
ax_dr.plot(tau[1:], dpsi[1:], "C3--", lw=1.4, label=r"$\delta\psi/|\psi|_{\max}$")
ax_dr.set_xlabel(r"$\tau$"); ax_dr.set_ylabel("convergence metric")
ax_dr.set_title("convergence")
ax_dr.grid(alpha=0.25)
ax_dr.legend(loc="upper right")
v_dr = ax_dr.axvline(tau[0], color="k", lw=1.0, alpha=0.7)

ax_F.plot(tau, Fz_t, "C0-", lw=1.6, label=r"$\langle F_z\rangle$")
ax_F.plot(tau, Fp_t, "C3-", lw=1.4, label=r"$|F_\perp|$")
ax_F.axhline(0,    color="k",   lw=0.5, alpha=0.5)
ax_F.axhline(-6.0, color="C0", lw=0.5, alpha=0.4, linestyle=":")
ax_F.set_xlabel(r"$\tau$"); ax_F.set_ylabel("spin")
ax_F.set_title("spin expectation")
ax_F.grid(alpha=0.25); ax_F.legend(loc="upper right")
v_F = ax_F.axvline(tau[0], color="k", lw=1.0, alpha=0.7)

ax_L.plot(tau, Lz_t, "C2-", lw=1.6)
ax_L.axhline(0, color="k", lw=0.5, alpha=0.5)
ax_L.set_xlabel(r"$\tau$"); ax_L.set_ylabel(r"$\langle L_z\rangle$")
ax_L.set_title("angular momentum")
ax_L.grid(alpha=0.25)
v_L = ax_L.axvline(tau[0], color="k", lw=1.0, alpha=0.7)

# --- Insets: zoom of last 30% τ-range with auto y-limits ---
ZOOM_FRAC = 0.30
zoom_start = tau[-1] - ZOOM_FRAC * (tau[-1] - tau[0])
mask = tau >= zoom_start
mask_dr = (tau[1:] >= zoom_start)

def _auto_ylim(vals):
    v = np.asarray(vals)
    lo, hi = float(np.min(v)), float(np.max(v))
    if hi - lo < 1e-15:
        pad = max(1e-9, abs(hi) * 1e-6)
        return lo - pad, hi + pad
    pad = 0.1 * (hi - lo)
    return lo - pad, hi + pad

def _add_inset(parent, x, y, color, lw=1.4, ls="-"):
    ins = parent.inset_axes([0.55, 0.55, 0.42, 0.40])
    ins.plot(x, y, color=color, lw=lw, linestyle=ls)
    ins.set_xlim(x[0], x[-1])
    ins.set_ylim(*_auto_ylim(y))
    ins.tick_params(labelsize=7, length=2, pad=1)
    ins.grid(alpha=0.25)
    ins.patch.set_alpha(0.85)
    for s in ins.spines.values():
        s.set_linewidth(0.6); s.set_alpha(0.6)
    ins.set_title(f"zoom: last {int(ZOOM_FRAC*100)}%", fontsize=7, pad=2)
    return ins

ins_E  = _add_inset(ax_E,  tau[mask], E[mask], "k")
v_E_ins  = ins_E.axvline(tau[0], color="r", lw=0.8, alpha=0.8)

ins_dr = ax_dr.inset_axes([0.55, 0.55, 0.42, 0.40])
ins_dr.plot(tau[1:][mask_dr], drho[1:][mask_dr], "C0-", lw=1.4)
ins_dr.plot(tau[1:][mask_dr], dpsi[1:][mask_dr], "C3--", lw=1.2)
ins_dr.set_xlim(tau[1:][mask_dr][0], tau[1:][mask_dr][-1])
ins_dr.set_ylim(*_auto_ylim(np.concatenate([drho[1:][mask_dr], dpsi[1:][mask_dr]])))
ins_dr.tick_params(labelsize=7, length=2, pad=1)
ins_dr.grid(alpha=0.25)
ins_dr.patch.set_alpha(0.85)
for s in ins_dr.spines.values(): s.set_linewidth(0.6); s.set_alpha(0.6)
ins_dr.set_title(f"zoom: last {int(ZOOM_FRAC*100)}%", fontsize=7, pad=2)
v_dr_ins = ins_dr.axvline(tau[0], color="k", lw=0.8, alpha=0.8)

ins_F = ax_F.inset_axes([0.55, 0.10, 0.42, 0.40])
ins_F.plot(tau[mask], Fz_t[mask], "C0-", lw=1.4)
ins_F.plot(tau[mask], Fp_t[mask], "C3-", lw=1.2)
ins_F.set_xlim(tau[mask][0], tau[mask][-1])
ins_F.set_ylim(*_auto_ylim(np.concatenate([Fz_t[mask], Fp_t[mask]])))
ins_F.tick_params(labelsize=7, length=2, pad=1)
ins_F.grid(alpha=0.25)
ins_F.patch.set_alpha(0.85)
for s in ins_F.spines.values(): s.set_linewidth(0.6); s.set_alpha(0.6)
ins_F.set_title(f"zoom: last {int(ZOOM_FRAC*100)}%", fontsize=7, pad=2)
v_F_ins = ins_F.axvline(tau[0], color="k", lw=0.8, alpha=0.8)

ins_L = _add_inset(ax_L, tau[mask], Lz_t[mask], "C2")
v_L_ins = ins_L.axvline(tau[0], color="k", lw=0.8, alpha=0.8)

# --- Live HUD text in the empty subplot ---
hud_lines = [
    ax_sum.text(0.04, 0.85, "", fontsize=14, weight="bold", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.65, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.45, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.25, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
    ax_sum.text(0.04, 0.05, "", fontsize=12, family="monospace", transform=ax_sum.transAxes),
]

suptitle = fig.suptitle(
    f"ITP imaginary-time trace  |  $^{{151}}$Eu, F=6, B={B_g*1e6:.1f} μG, "
    f"box={Lbox}μm/{NX}³, dt={(tau[1]-tau[0])/(step[1]-step[0]):.4f}",
    fontsize=14, y=0.985,
)

# --- Update callback ---
def update(k):
    # Row 1 (xy)
    im_pp_xy.set_data(n_xy[k, c_plus].T)
    im_p0_xy.set_data(n_xy[k, c_zero].T)
    im_pm_xy.set_data(n_xy[k, c_minus].T)
    im_ph_xy.set_data(arg_xy[k].T)
    # Row 2 (xz)
    im_pp_xz.set_data(n_xz[k, c_plus].T)
    im_p0_xz.set_data(n_xz[k, c_zero].T)
    im_pm_xz.set_data(n_xz[k, c_minus].T)
    im_ph_xz.set_data(arg_xz[k].T)
    # Spin field xy: arrow dir = unit(F_x, F_y), color = |F_perp|
    Ux = Fx_xy[k, ::SK, ::SK]
    Vy = Fy_xy[k, ::SK, ::SK]
    mag_xy = np.sqrt(Ux**2 + Vy**2)
    safe = np.where(mag_xy > 1e-12, mag_xy, 1.0)
    Q_xy.set_UVC(Ux / safe, Vy / safe, mag_xy)
    # Spin field xz: in-plane = (F_x, F_z)
    Ux2 = Fx_xz[k, ::SK, ::SK]
    Vz  = Fz_xz[k, ::SK, ::SK]
    mag_xz = np.sqrt(Ux2**2 + Vz**2)
    safe2 = np.where(mag_xz > 1e-12, mag_xz, 1.0)
    Q_xz.set_UVC(Ux2 / safe2, Vz / safe2, mag_xz)
    # Population bars (current snapshot)
    for c, b in enumerate(pop_bars):
        b.set_height(n_m[k, c])
    # Cursors (main + inset)
    for v in (v_E, v_dr, v_F, v_L,
              v_E_ins, v_dr_ins, v_F_ins, v_L_ins):
        v.set_xdata([tau[k], tau[k]])
    # HUD
    hud_lines[0].set_text(f"step {step[k]:6d} / {step[-1]}")
    hud_lines[1].set_text(f"τ        = {tau[k]:7.3f}")
    hud_lines[2].set_text(f"E        = {E[k]:.6f}")
    hud_lines[3].set_text(f"⟨F_z⟩   = {Fz_t[k]:+.4f}     |F_⊥| = {Fp_t[k]:.4f}")
    hud_lines[4].set_text(f"δρ/ρ_max = {drho[k]:.2e}   δψ/|ψ|max = {dpsi[k]:.2e}")
    return ()

# --- Render (subsample frames for speed: max ~200 frames) ---
stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1:
    frames.append(Nf - 1)
print(f"rendering {len(frames)} frames (stride={stride}) → {OUT_GIF}")

anim = FuncAnimation(fig, update, frames=frames, interval=80, blit=False)
anim.save(OUT_GIF, writer=PillowWriter(fps=10))
print("done.")
