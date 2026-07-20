#!/usr/bin/env python3
"""
plot_rtp_60uG_panels.py
=======================
Emits each panel of the RTP visualization as a STANDALONE GIF, organised
into category subfolders. Same data + colour conventions as the combined
plot_rtp_60uG.py — just split so each can be reused / inspected separately.

Output structure:
  rtp_60uG_panels/
    density_xy/{n_m-6, n_m-5, n_m-4}.gif
    density_xz/{n_m-6, n_m-5, n_m-4}.gif
    phase/{arg_psi_m6_xy, arg_psi_m6_xz}.gif
    spin/{F_xy, F_xz}.gif
    scalars/{populations, energy, norm}.gif
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
    "font.size": 13,
    "axes.titlesize": 15,
    "axes.labelsize": 13,
    "xtick.labelsize": 11,
    "ytick.labelsize": 11,
    "legend.fontsize": 11,
    "axes.linewidth": 1.0,
})

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.path.join(ROOT, os.environ.get("RTP_H5_NAME", "rtp_60uG_dt0p001.h5"))
OUT_BASE = os.path.join(ROOT, "rtp_60uG_panels")

# Slower playback (≈70% of fps=10 → fps=7); same frame count
FPS = 7
INTERVAL_MS = 140

# ---------------------------------------------------------------------------
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
    n_xy  = np.transpose(f["n_m_xy"][:], (3, 2, 1, 0))   # (Nf, D, NX, NX)
    n_xz  = np.transpose(f["n_m_xz"][:], (3, 2, 1, 0))
    Fx_xy = f["Fx_xy"][:].transpose(2, 1, 0)
    Fy_xy = f["Fy_xy"][:].transpose(2, 1, 0)
    Fz_xy = f["Fz_xy"][:].transpose(2, 1, 0)
    Fx_xz = f["Fx_xz"][:].transpose(2, 1, 0)
    Fy_xz = f["Fy_xz"][:].transpose(2, 1, 0)
    Fz_xz = f["Fz_xz"][:].transpose(2, 1, 0)
    arg_xy = f["arg_psi_m6_xy"][:].transpose(2, 1, 0)
    arg_xz = f["arg_psi_m6_xz"][:].transpose(2, 1, 0)

Nf = len(t)
t_ms = t / omega_ref * 1000.0
print(f"loaded {Nf} snapshots, NX={NX}, L={Lbox}μm, B={B_g*1e6:.1f}μG, T={t_ms[-1]:.2f}ms")

def m_idx(m): return int(np.where(Mvals == m)[0][0])
M_DISPLAY = (-6, -5, -4)

dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

stride = max(1, Nf // 200)
frames = list(range(0, Nf, stride))
if frames[-1] != Nf - 1: frames.append(Nf - 1)

def hud(t_ms_val, k):
    return f"t = {t_ms_val:6.3f} ms  ({k+1}/{Nf})"

def save_gif(fig, update_fn, outpath):
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    anim = FuncAnimation(fig, update_fn, frames=frames,
                         interval=INTERVAL_MS, blit=False)
    anim.save(outpath, writer=PillowWriter(fps=FPS))
    plt.close(fig)
    print(f"  wrote {outpath}")

def hud_text(ax):
    return ax.text(0.02, 0.97, "", transform=ax.transAxes,
                   fontsize=12, family="monospace", va="top",
                   bbox=dict(facecolor="white", alpha=0.75, edgecolor="none",
                             boxstyle="round,pad=0.3"))

# ===========================================================================
# 1. Density panels  (m=-6,-5,-4)  ×  (xy, y=z=0)
# ===========================================================================
def make_density_gif(view, ci, m, vmax, outpath):
    arr = n_xy if view == "xy" else n_xz
    ylab = "y [μm]" if view == "xy" else "z [μm]"
    slice_label = "z=0" if view == "xy" else "y=0"
    fig, ax = plt.subplots(figsize=(8, 7.5))
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax, cmap="magma", aspect="equal",
                   interpolation="bilinear")
    ax.set_title(fr"$|\psi_{{m={m:+d}}}|^2$  ({view}, {slice_label})  |  "
                 fr"B={B_g*1e6:.1f} μG", pad=8)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$|\psi_m|^2$  [μm⁻³]")
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        im.set_data(arr[k, ci].T)
        txt.set_text(hud(t_ms[k], k))
        return ()
    save_gif(fig, update, outpath)

for m in M_DISPLAY:
    ci = m_idx(m)
    vmax = max(float(np.max(n_xy[:, ci])), float(np.max(n_xz[:, ci])), 1e-30)
    make_density_gif("xy", ci, m, vmax,
        os.path.join(OUT_BASE, "density_xy", f"n_m{m:+d}.gif"))
    make_density_gif("xz", ci, m, vmax,
        os.path.join(OUT_BASE, "density_xz", f"n_m{m:+d}.gif"))

# ===========================================================================
# 2. Phase panels  (arg ψ_{m=-6})  ×  (xy, xz)
# ===========================================================================
def make_phase_gif(view, arr, outpath):
    ylab = "y [μm]" if view == "xy" else "z [μm]"
    slice_label = "z=0" if view == "xy" else "y=0"
    fig, ax = plt.subplots(figsize=(8, 7.5))
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=-np.pi, vmax=np.pi, cmap="hsv",
                   aspect="equal", interpolation="bilinear")
    ax.set_title(fr"$\arg\psi_{{m=-6}}$  ({view}, {slice_label})  |  "
                 fr"B={B_g*1e6:.1f} μG", pad=8)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02,
                      ticks=[-np.pi, 0, np.pi])
    cb.ax.set_yticklabels([r"$-\pi$", "0", r"$+\pi$"])
    cb.set_label("phase [rad]")
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        im.set_data(arr[k].T)
        txt.set_text(hud(t_ms[k], k))
        return ()
    save_gif(fig, update, outpath)

make_phase_gif("xy", arg_xy,
    os.path.join(OUT_BASE, "phase", "arg_psi_m-6_xy.gif"))
make_phase_gif("xz", arg_xz,
    os.path.join(OUT_BASE, "phase", "arg_psi_m-6_xz.gif"))

# ===========================================================================
# 3. Spin vector field  (F_perp in xy ; in-plane (F_x, F_z) in xz)
# ===========================================================================
SK = 2
Xa = xs[::SK]
mesh_X, mesh_Y = np.meshgrid(Xa, Xa, indexing="xy")
Fperp_xy = np.sqrt(Fx_xy**2 + Fy_xy**2);   v_xy = float(np.max(Fperp_xy))
Fperp_xz = np.sqrt(Fx_xz**2 + Fz_xz**2);   v_xz = float(np.max(Fperp_xz))

def make_spin_gif(view, Ux_arr, Vy_arr, vmax_perp, title, cb_label, ylab, outpath):
    fig, ax = plt.subplots(figsize=(8, 7.5))
    ax.set_facecolor("#1a1a1a")
    ax.set_title(title + fr"  |  B={B_g*1e6:.1f} μG", pad=8)
    ax.set_xlabel("x [μm]"); ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_xlim(extent[0], extent[1]); ax.set_ylim(extent[2], extent[3])
    ax.set_aspect("equal")
    ax.tick_params(colors="white", length=3)
    for spine in ax.spines.values(): spine.set_color("white")
    Q = ax.quiver(mesh_X, mesh_Y,
                  np.zeros_like(mesh_X), np.zeros_like(mesh_X),
                  np.zeros_like(mesh_X),
                  cmap="viridis", norm=mcolors.Normalize(vmin=0, vmax=vmax_perp),
                  pivot="middle", scale=24, width=0.005,
                  headwidth=4, headlength=5, headaxislength=4.5)
    cb = plt.colorbar(Q, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(cb_label)
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        Ux = Ux_arr[k, ::SK, ::SK]; Vy = Vy_arr[k, ::SK, ::SK]
        m = np.sqrt(Ux**2 + Vy**2); s = np.where(m > 1e-12, m, 1.0)
        Q.set_UVC(Ux/s, Vy/s, m)
        txt.set_text(hud(t_ms[k], k))
        return ()
    save_gif(fig, update, outpath)

make_spin_gif("xy", Fx_xy, Fy_xy, v_xy,
    r"spin field $\mathbf{F}_\perp$  (xy, z=0)",
    r"$|F_\perp|$  [ℏ]", "y [μm]",
    os.path.join(OUT_BASE, "spin", "F_perp_xy.gif"))
make_spin_gif("xz", Fx_xz, Fz_xz, v_xz,
    r"spin field $(F_x, F_z)$  (xz, y=0)",
    r"$\sqrt{F_x^2 + F_z^2}$  [ℏ]", "z [μm]",
    os.path.join(OUT_BASE, "spin", "F_xz.gif"))

# ===========================================================================
# 4. Scalars: populations bar, E(t), N(t)
# ===========================================================================
cmap_m = plt.get_cmap("turbo")
D_ch = len(Mvals)
m_axis = np.arange(D_ch)
bar_colors = [cmap_m(c / max(D_ch-1, 1)) for c in range(D_ch)]
slice_int_xy = n_xy * (dx * dx)
pop_per_frame = slice_int_xy.sum(axis=(2, 3))   # (Nf, D), units μm⁻¹
pop_scale = float(np.max(pop_per_frame))

def make_populations_gif(outpath):
    fig, ax = plt.subplots(figsize=(9, 6))
    bars = ax.bar(m_axis, np.zeros(D_ch), color=bar_colors,
                  edgecolor="black", linewidth=0.6)
    ax.set_xticks(m_axis)
    ax.set_xticklabels([f"{int(Mvals[c]):+d}" for c in range(D_ch)])
    ax.set_xlabel("m"); ax.set_ylabel(r"$\int dx\,dy\, |\psi_m(z{=}0)|^2$  [μm⁻¹]")
    ax.set_title(fr"populations (xy-slice area integral) | B={B_g*1e6:.1f} μG", pad=8)
    ax.set_ylim(0, pop_scale * 1.1 + 1e-30)
    ax.grid(alpha=0.25, axis="y")
    txt = ax.text(0.02, 0.97, "", transform=ax.transAxes,
                  fontsize=12, family="monospace", va="top",
                  bbox=dict(facecolor="white", alpha=0.75, edgecolor="none",
                            boxstyle="round,pad=0.3"))
    plt.tight_layout()
    def update(k):
        for c, b in enumerate(bars): b.set_height(pop_per_frame[k, c])
        txt.set_text(hud(t_ms[k], k))
        return ()
    save_gif(fig, update, outpath)

make_populations_gif(os.path.join(OUT_BASE, "scalars", "populations.gif"))

def make_scalar_gif(y, ylab, title, color, outpath, tight_ylim=False):
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(t_ms, y, color=color, lw=1.6)
    ax.set_xlabel("t [ms]"); ax.set_ylabel(ylab)
    ax.set_title(title + fr" | B={B_g*1e6:.1f} μG", pad=8)
    ax.grid(alpha=0.25)
    rng = float(np.max(y) - np.min(y))
    if tight_ylim and rng < 1e-10:
        ax.set_ylim(1 - 1e-10, 1 + 1e-10)
    elif rng > 0:
        ax.set_ylim(float(np.min(y)) - 0.05*rng, float(np.max(y)) + 0.05*rng)
    cursor = ax.axvline(t_ms[0], color="r", lw=1.0)
    txt = ax.text(0.02, 0.95, "", transform=ax.transAxes,
                  fontsize=12, family="monospace", va="top",
                  bbox=dict(facecolor="white", alpha=0.75, edgecolor="none",
                            boxstyle="round,pad=0.3"))
    plt.tight_layout()
    def update(k):
        cursor.set_xdata([t_ms[k], t_ms[k]])
        txt.set_text(f"{hud(t_ms[k], k)}   |   value = {y[k]:.8g}")
        return ()
    save_gif(fig, update, outpath)

make_scalar_gif(E, r"$E$", "total energy", "black",
    os.path.join(OUT_BASE, "scalars", "energy.gif"))
make_scalar_gif(Nrm, r"$\|\psi\|^2$", "norm conservation", "C0",
    os.path.join(OUT_BASE, "scalars", "norm.gif"), tight_ylim=True)

print(f"\nAll panel GIFs under: {OUT_BASE}")
