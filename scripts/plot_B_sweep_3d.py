#!/usr/bin/env python3
"""
plot_B_sweep_3d.py — 3-D spin-texture GIF for the ±120 μG ¹⁵¹Eu F=6 B-sweep.

Visualisation:
  • 3-D quiver arrows showing (Fx, Fy, Fz) at sub-sampled grid points
    inside the BEC cloud (density > threshold).
  • Arrow colour: red for upward (Fz > 0), fading to white at Fz ≈ 0,
    blue for downward (Fz < 0).  No background planes.
  • Right panel: ⟨Fz⟩ vs Bz summary.

Needs only numpy + matplotlib (no skimage/scipy).
"""

import sys, os, glob
from pathlib import Path

import numpy as np
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401

# ── Paths ──────────────────────────────────────────────────────────────────────
# Override default run directory via the SPINORBEC_RUNS_ROOT environment variable,
# or pass RUN_DIR as the first positional argument.
#   On TSUBAME:  export SPINORBEC_RUNS_ROOT=/gs/bs/work/6/<account>/bec-runs
#   Locally:     defaults to  runs/  in the repository root
_RUNS_ROOT  = Path(os.environ.get("SPINORBEC_RUNS_ROOT", Path(__file__).parent.parent / "runs"))
_SURVEY_REL = "projectA_ground_state/survey_B_secular_false_pm120_v3"

RUN_DIR  = Path(sys.argv[1]) if len(sys.argv) > 1 else _RUNS_ROOT / _SURVEY_REL
PLOT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else RUN_DIR / "plots_3d"
PLOT_DIR.mkdir(parents=True, exist_ok=True)

# ── Bz lookup (scan_index 1-based → μG) ────────────────────────────────────────
BZ_TABLE = {
     1: -120,  2: -110,  3: -100,  4:  -90,  5:  -80,
     6:  -75,  7:  -70,  8:  -65,  9:  -60, 10:  -55,
    11:  -50, 12:  -45, 13:  -40, 14:  -35, 15:  -30,
    16:  -25, 17:  -20, 18:  -15, 19:  -10, 20:   -8,
    21:   -6, 22:   -4, 23:   -2, 24:    0, 25:    2,
    26:    4, 27:    6, 28:    8, 29:   10, 30:   15,
    31:   20, 32:   25, 33:   30, 34:   35, 35:   40,
    36:   45, 37:   50, 38:   55, 39:   60, 40:   65,
    41:   70, 42:   75, 43:   80, 44:   90, 45:  100,
    46:  110, 47:  120,
}

# ── Spin matrices F = 6 ────────────────────────────────────────────────────────
F_SPIN = 6

def _make_spin_matrices(F):
    D = 2 * F + 1
    m = np.arange(F, -F - 1, -1, dtype=float)
    Fz_mat = np.diag(m)
    Fp = np.zeros((D, D))
    for i in range(D - 1):
        mi = m[i + 1]
        Fp[i, i + 1] = np.sqrt(F * (F + 1) - mi * (mi + 1))
    Fm = Fp.T
    Fx_mat   = 0.5 * (Fp + Fm)
    Fy_im    = 0.5 * (Fp - Fm)   # Fy = -i * Fy_im
    return Fx_mat, Fy_im, Fz_mat

Fx_mat, Fy_im_mat, Fz_mat = _make_spin_matrices(F_SPIN)
m_diag = np.diag(Fz_mat)   # for fast Fz: sum_c m[c] |psi_c|^2

def spin_density_3d(psi):
    """
    psi: complex (D, nz, ny, nx)
    Returns n, Fx, Fy, Fz each of shape (nz, ny, nx).
    """
    n  = np.sum(np.abs(psi)**2, axis=0)
    # Fz: diagonal → fast
    Fz = np.einsum('c,cijk->ijk', m_diag, np.abs(psi)**2)
    # Fx, Fy via einsum (real matrix)
    pc = psi.conj()
    Fx = np.real(np.einsum('cijk,cd,dijk->ijk', pc, Fx_mat,  psi))
    Fy = np.einsum('cijk,cd,dijk->ijk',          pc, Fy_im_mat, psi).imag
    return n, Fx, Fy, Fz

def load_point_full(fpath):
    with h5py.File(fpath, 'r') as f:
        raw      = f['psi'][()]
        psi_full = raw['re'] + 1j * raw['im']   # (D, nz, ny, nx)
        scan_idx = int(f['scan_index'][()])
        Mz       = float(f['mz_actual'][()])
        box_su   = f['grid_box_size'][()]
        n_pts    = f['grid_n_points'][()]
        a_ho_um  = float(f['units/a_ho_m'][()]) * 1e6
    # Sign flip: Zeeman sign error in simulator → physical Bz = −code Bz
    return dict(
        psi_full=psi_full,
        scan_idx=scan_idx, Bz_muG=-BZ_TABLE.get(scan_idx, 0.0), Mz=Mz,
        box_um=box_su * a_ho_um,
        nx=int(n_pts[0]), ny=int(n_pts[1]), nz=int(n_pts[2]),
    )

# ── Gather files ───────────────────────────────────────────────────────────────
files = sorted(glob.glob(str(RUN_DIR / "point_*.jld2")))
N = len(files)
print(f"Found {N} files")

# ── Pass 1: Bz/Mz arrays + global n_max ──────────────────────────────────────
print("Pass 1: collecting metadata …")
Bz_all = []; Mz_all = []
n_max_all = 0.0; Fz_abs_max_all = 0.0

for fpath in files:
    with h5py.File(fpath, 'r') as f:
        sidx = int(f['scan_index'][()])
        Mz_  = float(f['mz_actual'][()])
        iy   = int(f['grid_n_points'][()][1]) // 2
        raw  = f['psi'][:, :, iy, :]
        psi_xz = raw['re'] + 1j * raw['im']
        n_xz = np.sum(np.abs(psi_xz)**2, axis=0)
        Fz_xz = np.einsum('c,cij->ij', m_diag, np.abs(psi_xz)**2)
    n_max_all      = max(n_max_all,      float(n_xz.max()))
    Fz_abs_max_all = max(Fz_abs_max_all, float(np.abs(Fz_xz).max()))
    Bz_all.append(-BZ_TABLE.get(sidx, 0.0));  Mz_all.append(Mz_)  # sign flip

Bz_all = np.array(Bz_all);  Mz_all = np.array(Mz_all)
order  = np.argsort(Bz_all)
files_sorted = [files[i] for i in order]
Bz_sorted    = Bz_all[order];  Mz_sorted = Mz_all[order]
print(f"  n_max={n_max_all:.4f}  |Fz|_max={Fz_abs_max_all:.3f}")

# Arrow colourmap: blue (Fz < 0) → white (Fz ≈ 0) → red (Fz > 0)
cmap_arrow = plt.cm.RdBu_r
arrow_norm  = mcolors.Normalize(-Fz_abs_max_all, Fz_abs_max_all)

# ── Dark theme ─────────────────────────────────────────────────────────────────
BG  = '#0d0d1a'
BG2 = '#1a1a2e'
W   = 'white'

# ── Pass 2: render frames ─────────────────────────────────────────────────────
print("Pass 2: rendering 3D frames …")

for k, fpath in enumerate(files_sorted):
    d   = load_point_full(fpath)
    Bz  = d['Bz_muG'];  Mz = d['Mz']
    nx, ny, nz = d['nx'], d['ny'], d['nz']
    Lx, Ly, Lz = d['box_um']

    xs = np.linspace(-Lx/2, Lx/2, nx, endpoint=False)
    ys = np.linspace(-Ly/2, Ly/2, ny, endpoint=False)
    zs = np.linspace(-Lz/2, Lz/2, nz, endpoint=False)

    n_3d, Fx_3d, Fy_3d, Fz_3d = spin_density_3d(d['psi_full'])

    # ── Subsample grid for quiver: every step_q voxels ────────────────────
    step_q = 7      # ~9 arrows per axis → ~9³ = 729 candidate points
    iz_q = np.arange(step_q // 2, nz, step_q)
    iy_q = np.arange(step_q // 2, ny, step_q)
    ix_q = np.arange(step_q // 2, nx, step_q)
    IZ, IY, IX = np.meshgrid(iz_q, iy_q, ix_q, indexing='ij')

    n_q    = n_3d[IZ, IY, IX]
    thresh = 0.08 * n_max_all   # keep points with ≥ 8 % of peak density
    mask   = n_q > thresh

    xq  = xs[IX[mask]];  yq  = ys[IY[mask]];  zq  = zs[IZ[mask]]
    ufx = Fx_3d[IZ[mask], IY[mask], IX[mask]]
    ufy = Fy_3d[IZ[mask], IY[mask], IX[mask]]
    ufz = Fz_3d[IZ[mask], IY[mask], IX[mask]]

    # Normalise arrow direction vectors
    mag  = np.sqrt(ufx**2 + ufy**2 + ufz**2) + 1e-30
    ufx /= mag;  ufy /= mag;  ufz /= mag

    # Per-arrow colour from Fz (red=up, white=zero, blue=down)
    fz_raw = Fz_3d[IZ[mask], IY[mask], IX[mask]]
    n_raw  = np.maximum(n_q[mask], 1e-30)
    fz_per_atom = fz_raw / n_raw   # ⟨Fz⟩ per atom at each arrow site
    arrow_colors = cmap_arrow(arrow_norm(fz_per_atom))  # (Narrows, 4) RGBA

    arrow_len = Lx / nx * step_q * 0.65   # physical length per cell

    # ── Figure ─────────────────────────────────────────────────────────────
    fig = plt.figure(figsize=(15, 9), facecolor=BG)

    ax3 = fig.add_axes([0.03, 0.04, 0.62, 0.92], projection='3d')
    ax3.set_facecolor(BG)

    # Draw quiver arrows one colour at a time (matplotlib 3D quiver accepts
    # a single colour per call, so we group arrows by discrete colour bins)
    N_bins = 16
    fz_vals = fz_per_atom
    bins = np.linspace(fz_vals.min() - 1e-9, fz_vals.max() + 1e-9, N_bins + 1)
    bin_idx = np.digitize(fz_vals, bins) - 1
    bin_idx = np.clip(bin_idx, 0, N_bins - 1)

    bin_centers = 0.5 * (bins[:-1] + bins[1:])
    for b in range(N_bins):
        sel = bin_idx == b
        if not np.any(sel):
            continue
        col = cmap_arrow(arrow_norm(bin_centers[b]))
        ax3.quiver(
            xq[sel], yq[sel], zq[sel],
            ufx[sel], ufy[sel], ufz[sel],
            length=arrow_len, color=col,
            alpha=0.9, linewidth=0.9,
            arrow_length_ratio=0.35,
            normalize=False,
        )

    # Axes cosmetics
    lim = max(Lx, Ly, Lz) / 2 * 1.08
    ax3.set_xlim(-lim, lim);  ax3.set_ylim(-lim, lim);  ax3.set_zlim(-lim, lim)
    ax3.set_xlabel('x (μm)', color=W, labelpad=4, fontsize=9)
    ax3.set_ylabel('y (μm)', color=W, labelpad=4, fontsize=9)
    ax3.set_zlabel('z (μm)', color=W, labelpad=4, fontsize=9)
    ax3.tick_params(colors=W, labelsize=7)
    ax3.xaxis.pane.fill = False;  ax3.yaxis.pane.fill = False
    ax3.zaxis.pane.fill = False
    for pane in (ax3.xaxis.pane, ax3.yaxis.pane, ax3.zaxis.pane):
        pane.set_edgecolor('#2a2a44')
    ax3.grid(True, color='#222238', linewidth=0.4)
    ax3.view_init(elev=28, azim=225)
    ax3.set_title(
        fr"$^{{151}}$Eu  F=6  Ground State"
        fr"   $B_z$ = {Bz:+.0f} μG"
        fr"   $\langle F_z\rangle$ = {Mz:.3f}",
        color=W, fontsize=13, fontweight='bold', pad=10,
    )

    # ── Colorbar for arrow colours ─────────────────────────────────────────
    ax_cb = fig.add_axes([0.66, 0.14, 0.016, 0.62])
    sm = plt.cm.ScalarMappable(cmap=cmap_arrow, norm=arrow_norm)
    sm.set_array([])
    cb = fig.colorbar(sm, cax=ax_cb)
    cb.set_label(r'$\langle F_z\rangle / n$ (per atom)', color=W, fontsize=9)
    cb.ax.tick_params(colors=W, labelsize=8)

    # ── Right: ⟨Fz⟩ vs Bz summary ──────────────────────────────────────────
    ax_s = fig.add_axes([0.74, 0.14, 0.23, 0.62])
    ax_s.set_facecolor(BG2)
    ax_s.scatter(Bz_sorted, Mz_sorted, s=20, color='#5588cc', alpha=0.7,
                 zorder=2, label='all')
    ax_s.scatter([Bz], [Mz], s=130, color='#ff5555', zorder=3, label='current')
    ax_s.axvline(0, color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax_s.axhline(0, color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax_s.set_xlabel('$B_z$ (μG)',                      color=W, fontsize=9)
    ax_s.set_ylabel(r'$\langle F_z\rangle_{\rm vol}$', color=W, fontsize=9)
    ax_s.set_title(r'$\langle F_z\rangle$ vs $B_z$',  color=W, fontsize=10)
    ax_s.set_xlim(Bz_sorted.min()-8, Bz_sorted.max()+8)
    ax_s.set_ylim(Mz_sorted.min()-0.4, Mz_sorted.max()+0.4)
    ax_s.tick_params(colors=W, labelsize=8)
    for sp in ax_s.spines.values():
        sp.set_edgecolor('#444466')
    ax_s.grid(True, alpha=0.15, color=W)
    ax_s.legend(fontsize=7, facecolor=BG2, edgecolor='#555577', labelcolor=W)

    out_png = PLOT_DIR / f"frame_3d_{k+1:03d}.png"
    fig.savefig(out_png, dpi=110, bbox_inches='tight', facecolor=BG)
    plt.close(fig)
    print(f"  [{k+1:2d}/{N}]  Bz={Bz:+6.0f} μG  Mz={Mz:+.3f}  → {out_png.name}",
          flush=True)

print(f"\nAll {N} frames written to {PLOT_DIR}")

# ── Assemble GIF ──────────────────────────────────────────────────────────────
gif_path = PLOT_DIR / "B_sweep_3d_spin_texture.gif"
frames   = sorted(glob.glob(str(PLOT_DIR / "frame_3d_*.png")))

try:
    from PIL import Image
    imgs = [Image.open(f).convert('RGBA') for f in frames]
    imgs[0].save(str(gif_path), save_all=True, append_images=imgs[1:],
                 duration=300, loop=0, optimize=False)
    print(f"GIF (PIL): {gif_path}")
except Exception as e:
    import subprocess
    subprocess.run(['convert', '-delay', '30', '-loop', '0',
                   *frames, str(gif_path)], check=True)
    print(f"GIF (convert): {gif_path}")

print("Done!")
