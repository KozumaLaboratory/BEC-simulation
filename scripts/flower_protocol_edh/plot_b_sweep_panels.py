#!/usr/bin/env python3
"""
plot_b_sweep_panels.py
======================
Emit each panel of the B-sweep visualization as a standalone GIF.

Output structure:
  b_sweep_panels/
    density_xy/{n_m-6, n_m-5, n_m-4}.gif
    density_xz/{n_m-6, n_m-5, n_m-4}.gif
    phase/{arg_psi_m-6_xy, arg_psi_m-6_xz}.gif
    spin/{F_perp_xy, F_xz}.gif
    scalars/{populations, energy_vs_B, Fz_vs_B}.gif
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
H5 = os.path.join(ROOT, "b_sweep.h5")
OUT_BASE = os.path.join(ROOT, "b_sweep_panels")

FPS = 1.5
INTERVAL_MS = 800

with h5py.File(H5, "r") as f:
    B_uG = f["B_uG"][:]
    E = f["E"][:]
    Fz_t = f["Fz"][:]
    Mvals = f["meta/m_channels"][:]
    Lbox = float(f["meta/L_box"][()])
    NX = int(f["meta/NX"][()])
    n_xy = np.transpose(f["n_m_xy"][:], (3, 2, 1, 0))
    n_xz = np.transpose(f["n_m_xz"][:], (3, 2, 1, 0))
    Fx_xy = f["Fx_xy"][:].transpose(2, 1, 0)
    Fy_xy = f["Fy_xy"][:].transpose(2, 1, 0)
    Fx_xz = f["Fx_xz"][:].transpose(2, 1, 0)
    Fz_xz = f["Fz_xz"][:].transpose(2, 1, 0)
    arg_xy = f["arg_psi_m6_xy"][:].transpose(2, 1, 0)
    arg_xz = f["arg_psi_m6_xz"][:].transpose(2, 1, 0)

order = np.argsort(B_uG)[::-1]
B_uG = B_uG[order]
E = E[order]
Fz_t = Fz_t[order]
n_xy = n_xy[order]
n_xz = n_xz[order]
Fx_xy = Fx_xy[order]
Fy_xy = Fy_xy[order]
Fx_xz = Fx_xz[order]
Fz_xz = Fz_xz[order]
arg_xy = arg_xy[order]
arg_xz = arg_xz[order]

Nb = len(B_uG)
print(f"loaded {Nb} B values (descending): {list(B_uG)} μG")

def m_idx(m):
    return int(np.where(Mvals == m)[0][0])

M_DISPLAY = (-6, -5, -4)
dx = Lbox / NX
xs = -Lbox/2 + dx * np.arange(NX) + dx/2
extent = [xs[0]-dx/2, xs[-1]+dx/2, xs[0]-dx/2, xs[-1]+dx/2]

def hud(k):
    return f"B = {int(B_uG[k]):+d} μG  ({k+1}/{Nb})"

def save_gif(fig, update_fn, outpath):
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    anim = FuncAnimation(fig, update_fn, frames=Nb,
                         interval=INTERVAL_MS, blit=False)
    anim.save(outpath, writer=PillowWriter(fps=FPS))
    plt.close(fig)
    print(f"  wrote {outpath}")

def hud_text(ax):
    return ax.text(0.02, 0.97, "", transform=ax.transAxes,
                   fontsize=12, family="monospace", va="top",
                   bbox=dict(facecolor="white", alpha=0.75, edgecolor="none",
                             boxstyle="round,pad=0.3"))

def make_density_gif(view, ci, m, vmax, outpath):
    arr = n_xy if view == "xy" else n_xz
    ylab = "y [μm]" if view == "xy" else "z [μm]"
    fig, ax = plt.subplots(figsize=(8, 7.5))
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=0, vmax=vmax, cmap="magma", aspect="equal",
                   interpolation="bilinear")
    ax.set_title(fr"$|\psi_{{m={m:+d}}}|^2$  ({view})", pad=8)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$|\psi_m|^2$")
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        im.set_data(arr[k, ci].T)
        txt.set_text(hud(k))
        return ()
    save_gif(fig, update, outpath)

for m in M_DISPLAY:
    ci = m_idx(m)
    vmax = max(float(np.max(n_xy[:, ci])), float(np.max(n_xz[:, ci])), 1e-30)
    make_density_gif("xy", ci, m, vmax,
        os.path.join(OUT_BASE, "density_xy", f"n_m{m:+d}.gif"))
    make_density_gif("xz", ci, m, vmax,
        os.path.join(OUT_BASE, "density_xz", f"n_m{m:+d}.gif"))

def make_phase_gif(view, arr, outpath):
    ylab = "y [μm]" if view == "xy" else "z [μm]"
    fig, ax = plt.subplots(figsize=(8, 7.5))
    im = ax.imshow(np.zeros((NX, NX)), extent=extent, origin="lower",
                   vmin=-np.pi, vmax=np.pi, cmap="hsv",
                   aspect="equal", interpolation="bilinear")
    ax.set_title(fr"$\arg\psi_{{m=-6}}$  ({view})", pad=8)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    cb = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.02,
                      ticks=[-np.pi, 0, np.pi])
    cb.ax.set_yticklabels([r"$-\pi$", "0", r"$+\pi$"])
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        im.set_data(arr[k].T)
        txt.set_text(hud(k))
        return ()
    save_gif(fig, update, outpath)

make_phase_gif("xy", arg_xy,
    os.path.join(OUT_BASE, "phase", "arg_psi_m-6_xy.gif"))
make_phase_gif("xz", arg_xz,
    os.path.join(OUT_BASE, "phase", "arg_psi_m-6_xz.gif"))

SK = 2
Xa = xs[::SK]
mesh_X, mesh_Y = np.meshgrid(Xa, Xa, indexing="xy")
Fperp_xy = np.sqrt(Fx_xy**2 + Fy_xy**2)
Fperp_xz = np.sqrt(Fx_xz**2 + Fz_xz**2)
v_xy = float(np.max(Fperp_xy))
v_xz = float(np.max(Fperp_xz))

def make_spin_gif(Ux_arr, Vy_arr, vmax_perp, title, ylab, outpath):
    fig, ax = plt.subplots(figsize=(8, 7.5))
    ax.set_facecolor("#1a1a1a")
    ax.set_title(title, pad=8)
    ax.set_xlabel("x [μm]")
    ax.set_ylabel(ylab)
    ax.set_xticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_yticks(np.linspace(-Lbox/2, Lbox/2, 5))
    ax.set_xlim(extent[0], extent[1])
    ax.set_ylim(extent[2], extent[3])
    ax.set_aspect("equal")
    ax.tick_params(colors="white", length=3)
    for spine in ax.spines.values():
        spine.set_color("white")
    Q = ax.quiver(mesh_X, mesh_Y,
                  np.zeros_like(mesh_X), np.zeros_like(mesh_X),
                  np.zeros_like(mesh_X),
                  cmap="viridis",
                  norm=mcolors.Normalize(vmin=0, vmax=vmax_perp),
                  pivot="middle", scale=24, width=0.005,
                  headwidth=4, headlength=5, headaxislength=4.5)
    cb = plt.colorbar(Q, ax=ax, fraction=0.046, pad=0.02)
    cb.set_label(r"$|F_\perp|$")
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        Ux = Ux_arr[k, ::SK, ::SK]
        Vy = Vy_arr[k, ::SK, ::SK]
        mag = np.sqrt(Ux**2 + Vy**2)
        scale = np.where(mag > 1e-12, mag, 1.0)
        Q.set_UVC(Ux/scale, Vy/scale, mag)
        txt.set_text(hud(k))
        return ()
    save_gif(fig, update, outpath)

make_spin_gif(Fx_xy, Fy_xy, v_xy,
    r"spin field $\mathbf{F}_\perp$  (xy)", "y [μm]",
    os.path.join(OUT_BASE, "spin", "F_perp_xy.gif"))
make_spin_gif(Fx_xz, Fz_xz, v_xz,
    r"spin field $(F_x, F_z)$  (xz)", "z [μm]",
    os.path.join(OUT_BASE, "spin", "F_xz.gif"))

cmap_m = plt.get_cmap("turbo")
D_ch = len(Mvals)
m_axis = np.arange(D_ch)
bar_colors = [cmap_m(c / max(D_ch-1, 1)) for c in range(D_ch)]
slice_int_xy = n_xy * (dx * dx)
pop_per_frame = slice_int_xy.sum(axis=(2, 3))
pop_scale = float(np.max(pop_per_frame))

def make_populations_gif(outpath):
    fig, ax = plt.subplots(figsize=(9, 6))
    bars = ax.bar(m_axis, np.zeros(D_ch), color=bar_colors,
                  edgecolor="black", linewidth=0.6)
    ax.set_xticks(m_axis)
    ax.set_xticklabels([f"{int(Mvals[c]):+d}" for c in range(D_ch)])
    ax.set_xlabel("m")
    ax.set_ylabel(r"$\int dx\,dy\,|\psi_m|^2$ [μm⁻¹]")
    ax.set_title("populations (xy-slice area integral)", pad=8)
    ax.set_ylim(0, pop_scale * 1.1 + 1e-30)
    ax.grid(alpha=0.25, axis="y")
    txt = hud_text(ax)
    plt.tight_layout()
    def update(k):
        for c, b in enumerate(bars):
            b.set_height(pop_per_frame[k, c])
        txt.set_text(hud(k))
        return ()
    save_gif(fig, update, outpath)

make_populations_gif(os.path.join(OUT_BASE, "scalars", "populations.gif"))

def make_scalar_gif(y, ylab, title, color, outpath):
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(B_uG, y, color=color, lw=1.6, marker="o")
    ax.set_xlabel("B [μG]")
    ax.set_ylabel(ylab)
    ax.set_title(title, pad=8)
    ax.grid(alpha=0.25)
    rng = float(np.max(y) - np.min(y))
    if rng > 0:
        ax.set_ylim(float(np.min(y)) - 0.05*rng, float(np.max(y)) + 0.05*rng)
    cursor = ax.axvline(B_uG[0], color="r", lw=1.0)
    marker = ax.plot([B_uG[0]], [y[0]], "ro", markersize=10, zorder=5)[0]
    txt = ax.text(0.02, 0.95, "", transform=ax.transAxes,
                  fontsize=12, family="monospace", va="top",
                  bbox=dict(facecolor="white", alpha=0.75, edgecolor="none",
                            boxstyle="round,pad=0.3"))
    plt.tight_layout()
    def update(k):
        cursor.set_xdata([B_uG[k], B_uG[k]])
        marker.set_data([B_uG[k]], [y[k]])
        txt.set_text(f"{hud(k)}   |   value = {y[k]:.8g}")
        return ()
    save_gif(fig, update, outpath)

make_scalar_gif(E, r"$E$", "energy vs B", "black",
    os.path.join(OUT_BASE, "scalars", "energy_vs_B.gif"))
make_scalar_gif(Fz_t, r"$\langle F_z\rangle$", r"$\langle F_z\rangle$ vs B", "C0",
    os.path.join(OUT_BASE, "scalars", "Fz_vs_B.gif"))

print(f"\nAll panel GIFs under: {OUT_BASE}")
