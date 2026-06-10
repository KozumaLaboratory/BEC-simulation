#!/usr/bin/env python3
"""
plot_B_sweep.py — spin texture plots for the ±120 μG ¹⁵¹Eu F=6 B-sweep.

Each frame (PNG) shows:
  Row 0: x-z cross-section  — density | Fz+quiver(Fx,Fz) | |F|²/n
  Row 1: x-y cross-section  — density | Fz+quiver(Fx,Fy) | ⟨Fz⟩ vs Bz summary

Color scales are fixed across ALL frames so GIF transitions are smooth.
Frames are ordered by Bz (most negative → most positive).

Usage:
    python3 scripts/plot_B_sweep.py [RUN_DIR] [PLOT_DIR]

Defaults to the v3 survey directory.
"""

import sys, os, glob
from pathlib import Path

import numpy as np
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

# ── Paths ─────────────────────────────────────────────────────────────────────
# Override default run directory via the SPINORBEC_RUNS_ROOT environment variable,
# or pass RUN_DIR as the first positional argument.
#   On TSUBAME:  export SPINORBEC_RUNS_ROOT=/gs/bs/work/6/<account>/bec-runs
#   Locally:     defaults to  runs/  in the repository root
_RUNS_ROOT  = Path(os.environ.get("SPINORBEC_RUNS_ROOT", Path(__file__).parent.parent / "runs"))
_SURVEY_REL = "projectA_ground_state/survey_B_secular_false_pm120_v3"

RUN_DIR  = Path(sys.argv[1]) if len(sys.argv) > 1 else _RUNS_ROOT / _SURVEY_REL
PLOT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else RUN_DIR / "plots"
PLOT_DIR.mkdir(parents=True, exist_ok=True)

# ── Bz lookup: scan_index (1-based) → μG ─────────────────────────────────────
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

# ── Spin matrices F = 6 ───────────────────────────────────────────────────────
F_SPIN = 6
D = 2 * F_SPIN + 1  # 13 components

def _make_spin_matrices(F):
    D = 2 * F + 1
    m = np.arange(F, -F - 1, -1, dtype=float)  # m[0]=+F, m[D-1]=-F
    Fz = np.diag(m)
    # F+: (F+)_{i, i+1} = sqrt(F(F+1) - m[i+1]*(m[i+1]+1))
    Fp = np.zeros((D, D), dtype=float)
    for i in range(D - 1):
        mi = m[i + 1]
        Fp[i, i + 1] = np.sqrt(F * (F + 1) - mi * (mi + 1))
    Fm = Fp.T   # F- = (F+)^T  (all elements real here)
    Fx = 0.5 * (Fp + Fm)
    Fy_imag = 0.5 * (Fp - Fm)   # Fy = -i/2 (F+ - F-); stored as real part
    return Fx, Fy_imag, Fz

Fx_mat, Fy_imag_mat, Fz_mat = _make_spin_matrices(F_SPIN)

def spin_density_2d(psi2d):
    """
    psi2d: complex array (13, nA, nB) — spinor index first.
    Returns n, Fx, Fy, Fz  each of shape (nA, nB).

    <F_a>(i,j) = sum_{c,d} psi*_c(i,j)  (F_a)_{c,d}  psi_d(i,j)
    """
    n  = np.sum(np.abs(psi2d) ** 2, axis=0)
    pc = psi2d.conj()
    # Fz: Fz_mat is real diagonal
    Fz = np.einsum('cij,cd,dij->ij', pc, Fz_mat, psi2d).real
    # Fx: Fx_mat is real symmetric
    Fx = np.einsum('cij,cd,dij->ij', pc, Fx_mat, psi2d).real
    # Fy: Fy = -i * Fy_imag_mat  (Fy_imag_mat is real)
    # <Fy> = Re[ psi* · (-i Fy_imag) · psi ]
    #       = Re[ -i * einsum(pc, Fy_imag, psi) ]
    #       = Im[ einsum(pc, Fy_imag, psi) ]   (since Re(-iz)=Im(z))
    tmp = np.einsum('cij,cd,dij->ij', pc, Fy_imag_mat, psi2d)
    Fy = tmp.imag
    return n, Fx, Fy, Fz

# ── Load one point file ───────────────────────────────────────────────────────
def load_point(fpath, slice_only=False):
    """
    slice_only=True: read only center slices + scalars (fast for first pass).
    Returns dict with keys: psi_xz, psi_xy, scan_idx, Bz_muG, Mz, box_um, nx.
    If slice_only=False also sets 'psi' (full 4D).
    """
    with h5py.File(fpath, 'r') as f:
        scan_idx = int(f['scan_index'][()])
        Mz       = float(f['mz_actual'][()])
        box_su   = f['grid_box_size'][()]   # simulation units (a_ho)
        n_pts    = f['grid_n_points'][()]   # [nx, ny, nz]
        a_ho_m   = float(f['units/a_ho_m'][()])  # meters
        a_ho_um  = a_ho_m * 1e6             # μm

        nx, ny, nz = int(n_pts[0]), int(n_pts[1]), int(n_pts[2])
        iy = ny // 2
        iz = nz // 2

        # psi stored as (D, nz, ny, nx) compound {re, im}
        # (Julia stores psi[x,y,z,c] column-major → numpy reads reversed)
        if slice_only:
            # x-z slice: psi[:, :, iy, :]  → (D, nz, nx)
            raw_xz = f['psi'][:, :, iy, :]
            psi_xz = raw_xz['re'] + 1j * raw_xz['im']
            psi_xy = None
            psi_full = None
        else:
            raw = f['psi'][()]
            psi_full = raw['re'] + 1j * raw['im']  # (D, nz, ny, nx)
            psi_xz = psi_full[:, :, iy, :]         # (D, nz, nx)
            psi_xy = psi_full[:, iz, :, :]          # (D, ny, nx)

        box_um = box_su * a_ho_um  # physical box (μm)

    # NOTE: The Zeeman Hamiltonian in the code has a sign error (H = -(g_F μ_B B·F)
    # instead of +(g_F μ_B B·F)).  The physical B field is therefore the NEGATIVE
    # of the value stored in the YAML / JLD2.  We flip the sign here so that the
    # displayed Bz axis matches real laboratory field values.
    return dict(
        psi_xz=psi_xz, psi_xy=psi_xy, psi_full=psi_full,
        scan_idx=scan_idx, Bz_muG=-BZ_TABLE.get(scan_idx, 0.0), Mz=Mz,
        box_um=box_um, nx=nx, ny=ny, nz=nz, a_ho_um=a_ho_um,
    )

# ── Gather all files ──────────────────────────────────────────────────────────
files = sorted(glob.glob(str(RUN_DIR / "point_*.jld2")))
N = len(files)
print(f"Found {N} files in {RUN_DIR}")

# ── First pass: color-scale limits + Bz/Mz arrays ────────────────────────────
print("Pass 1: collecting metadata + color limits …")
Bz_all = []; Mz_all = []; sidx_all = []
n_max_all = 0.0; Fz_abs_max = 0.0; F2_max_all = 0.0

for fpath in files:
    d = load_point(fpath, slice_only=True)
    n_xz, Fx_xz, Fy_xz, Fz_xz = spin_density_2d(d['psi_xz'])
    n_max_all   = max(n_max_all,   float(n_xz.max()))
    Fz_abs_max  = max(Fz_abs_max,  float(np.abs(Fz_xz).max()))
    Bz_all.append(d['Bz_muG']); Mz_all.append(d['Mz']); sidx_all.append(d['scan_idx'])

Bz_all = np.array(Bz_all)
Mz_all = np.array(Mz_all)
order  = np.argsort(Bz_all)
files_sorted = [files[i] for i in order]
Bz_sorted    = Bz_all[order]
Mz_sorted    = Mz_all[order]

print(f"  n_max={n_max_all:.4f}  |Fz|_max={Fz_abs_max:.3f}")
print(f"  Bz range: {Bz_sorted.min():.0f} → {Bz_sorted.max():.0f} μG")

# Fixed color norms (same for all frames)
n_norm  = mcolors.Normalize(0,             n_max_all)
Fz_norm = mcolors.Normalize(-Fz_abs_max,   Fz_abs_max)
F2_norm = mcolors.Normalize(0,             F_SPIN ** 2)

# ── Dark-theme plot helper ────────────────────────────────────────────────────
BG    = '#0d0d1a'
BG2   = '#1a1a2e'
WHITE = 'white'

def _style_ax(ax):
    ax.set_facecolor(BG2)
    ax.tick_params(colors=WHITE, labelsize=8)
    ax.xaxis.label.set_color(WHITE)
    ax.yaxis.label.set_color(WHITE)
    ax.title.set_color(WHITE)
    for sp in ax.spines.values():
        sp.set_edgecolor('#444466')

def _colorbar(fig, ax, im, label):
    cb = fig.colorbar(im, ax=ax, fraction=0.045, pad=0.03)
    cb.set_label(label, color=WHITE, fontsize=8)
    cb.ax.tick_params(colors=WHITE, labelsize=7)

# ── Second pass: render one PNG per Bz point ──────────────────────────────────
print("Pass 2: rendering frames …")

for k, fpath in enumerate(files_sorted):
    d = load_point(fpath, slice_only=False)
    Bz  = d['Bz_muG'];  Mz = d['Mz']
    nx  = d['nx'];  ny = d['ny'];  nz = d['nz']
    Lx, Ly, Lz = d['box_um']   # physical box in μm

    xs = np.linspace(-Lx/2, Lx/2, nx, endpoint=False)
    ys = np.linspace(-Ly/2, Ly/2, ny, endpoint=False)
    zs = np.linspace(-Lz/2, Lz/2, nz, endpoint=False)

    # psi_xz: (D, nz, nx);  psi_xy: (D, ny, nx)
    n_xz, Fx_xz, Fy_xz, Fz_xz = spin_density_2d(d['psi_xz'])
    n_xy, Fx_xy, Fy_xy, Fz_xy  = spin_density_2d(d['psi_xy'])
    # |F|²/n² — dimensionless spin magnitude (= F² for fully polarised state).
    # Mask below 3 % of peak to avoid edge blow-up from near-zero density.
    n_safe = np.maximum(n_xz, 0.03 * n_max_all)
    F2_xz  = (Fx_xz**2 + Fy_xz**2 + Fz_xz**2) / n_safe**2
    F2_xz[n_xz < 0.03 * n_max_all] = 0.0

    # Quiver subsample: ~10×10 arrows
    step = max(1, nx // 10)
    sq   = slice(None, None, step)

    def _norm_vec(u, v):
        mag = np.hypot(u, v) + 1e-10
        return u / mag, v / mag

    # ── Figure ──────────────────────────────────────────────────────────────
    fig, axes = plt.subplots(2, 3, figsize=(16, 10), facecolor=BG)
    fig.suptitle(
        fr"$^{{151}}$Eu  F=6  Ground State   |   "
        fr"$B_z$ = {Bz:+.0f} μG   |   "
        fr"$\langle F_z\rangle$ = {Mz:.3f}",
        color=WHITE, fontsize=14, fontweight='bold', y=0.98,
    )

    for ax in axes.flat:
        _style_ax(ax)

    kw_pcm = dict(shading='auto', rasterized=True)
    kw_quiv = dict(color='black', scale=16, width=0.006,
                   headwidth=3, headlength=3.5, alpha=0.9)

    # ── [0,0] x-z density ───────────────────────────────────────────────────
    ax = axes[0, 0]
    im = ax.pcolormesh(xs, zs, n_xz, cmap='magma',  norm=n_norm,  **kw_pcm)
    _colorbar(fig, ax, im, r'$n$')
    ax.set_title('Density  $n(x,z)$',  fontsize=10)
    ax.set_xlabel('$x$ (μm)');  ax.set_ylabel('$z$ (μm)')
    ax.set_aspect('equal')

    # ── [0,1] x-z  Fz + quiver (Fx, Fz) ────────────────────────────────────
    ax = axes[0, 1]
    im = ax.pcolormesh(xs, zs, Fz_xz, cmap='RdBu_r', norm=Fz_norm, **kw_pcm)
    _colorbar(fig, ax, im, r'$\langle F_z\rangle$')
    ux, uz = _norm_vec(Fx_xz[sq, sq], Fz_xz[sq, sq])
    Xq, Zq = np.meshgrid(xs[sq], zs[sq])
    ax.quiver(Xq, Zq, ux, uz, **kw_quiv)
    ax.set_title(r'$\langle F_z\rangle(x,z)$  +  $(F_x,F_z)$ texture', fontsize=10)
    ax.set_xlabel('$x$ (μm)');  ax.set_ylabel('$z$ (μm)')
    ax.set_aspect('equal')

    # ── [0,2] x-z |F|²/n ────────────────────────────────────────────────────
    ax = axes[0, 2]
    im = ax.pcolormesh(xs, zs, F2_xz, cmap='viridis', norm=F2_norm, **kw_pcm)
    _colorbar(fig, ax, im, r'$|\mathbf{F}|^2/n$')
    ax.set_title(r'Spin magnitude  $|\mathbf{F}|^2/n(x,z)$', fontsize=10)
    ax.set_xlabel('$x$ (μm)');  ax.set_ylabel('$z$ (μm)')
    ax.set_aspect('equal')

    # ── [1,0] x-y density ───────────────────────────────────────────────────
    ax = axes[1, 0]
    im = ax.pcolormesh(xs, ys, n_xy, cmap='magma',  norm=n_norm,  **kw_pcm)
    _colorbar(fig, ax, im, r'$n$')
    ax.set_title('Density  $n(x,y)$', fontsize=10)
    ax.set_xlabel('$x$ (μm)');  ax.set_ylabel('$y$ (μm)')
    ax.set_aspect('equal')

    # ── [1,1] x-y  Fz + quiver (Fx, Fy) ────────────────────────────────────
    ax = axes[1, 1]
    im = ax.pcolormesh(xs, ys, Fz_xy, cmap='RdBu_r', norm=Fz_norm, **kw_pcm)
    _colorbar(fig, ax, im, r'$\langle F_z\rangle$')
    ux2, uy2 = _norm_vec(Fx_xy[sq, sq], Fy_xy[sq, sq])
    Xq2, Yq2 = np.meshgrid(xs[sq], ys[sq])
    ax.quiver(Xq2, Yq2, ux2, uy2, **kw_quiv)
    ax.set_title(r'$\langle F_z\rangle(x,y)$  +  $(F_x,F_y)$ texture', fontsize=10)
    ax.set_xlabel('$x$ (μm)');  ax.set_ylabel('$y$ (μm)')
    ax.set_aspect('equal')

    # ── [1,2] ⟨Fz⟩ vs Bz sweep summary ─────────────────────────────────────
    ax = axes[1, 2]
    ax.set_facecolor(BG2)
    ax.scatter(Bz_sorted, Mz_sorted, s=18, color='#5588cc', alpha=0.7,
               zorder=2, label='all points')
    ax.scatter([Bz], [Mz], s=120, color='#ff5555', zorder=3, label='current')
    ax.axvline(0,  color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax.axhline(0,  color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax.set_xlabel('$B_z$ (μG)',                   color=WHITE)
    ax.set_ylabel(r'$\langle F_z\rangle_{\rm vol}$', color=WHITE)
    ax.set_title(r'$\langle F_z\rangle$ vs $B_z$', color=WHITE, fontsize=10)
    ax.set_xlim(Bz_sorted.min() - 8, Bz_sorted.max() + 8)
    ax.set_ylim(Mz_sorted.min() - 0.4, Mz_sorted.max() + 0.4)
    ax.grid(True, alpha=0.15, color=WHITE)
    ax.legend(fontsize=8, facecolor=BG2, edgecolor='#555577',
              labelcolor=WHITE, markerscale=1.2)

    plt.tight_layout(rect=[0, 0, 1, 0.96])
    out_png = PLOT_DIR / f"frame_{k + 1:03d}.png"
    fig.savefig(out_png, dpi=110, bbox_inches='tight', facecolor=BG)
    plt.close(fig)
    print(f"  [{k+1:2d}/{N}]  Bz={Bz:+6.0f} μG  Mz={Mz:+.3f}  → {out_png.name}",
          flush=True)

print(f"\nAll {N} frames written to {PLOT_DIR}")

# ── Assemble GIF ──────────────────────────────────────────────────────────────
gif_path = PLOT_DIR / "B_sweep_spin_texture.gif"
frames   = sorted(glob.glob(str(PLOT_DIR / "frame_*.png")))

try:
    import imageio.v3 as iio
    imgs = [iio.imread(f) for f in frames]
    iio.imwrite(str(gif_path), imgs, duration=250, loop=0)   # 250 ms/frame
    print(f"GIF (imageio v3): {gif_path}")
except Exception as e1:
    try:
        import imageio as iio2
        with iio2.get_writer(str(gif_path), mode='I', duration=0.25, loop=0) as w:
            for f in frames:
                w.append_data(iio2.imread(f))
        print(f"GIF (imageio v2): {gif_path}")
    except Exception as e2:
        try:
            from PIL import Image
            imgs = [Image.open(f).convert('RGBA') for f in frames]
            imgs[0].save(str(gif_path), save_all=True, append_images=imgs[1:],
                         duration=250, loop=0, optimize=False)
            print(f"GIF (PIL): {gif_path}")
        except Exception as e3:
            import subprocess
            subprocess.run(['convert', '-delay', '25', '-loop', '0',
                           *frames, str(gif_path)], check=True)
            print(f"GIF (ImageMagick convert): {gif_path}")

print("Done!")
