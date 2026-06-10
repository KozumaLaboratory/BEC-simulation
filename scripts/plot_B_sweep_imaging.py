#!/usr/bin/env python3
"""
plot_B_sweep_imaging.py — column-integrated spin texture imaging simulation.

Simulates side-view (y-integrated) absorption imaging with a quantization axis
tilted at three angles θ = 0°, +16°, −16° from vertical (z-axis), reproducing
the 花型相図 (flower phase diagram) experimental observables.

Physics:
  Camera looks along y.  Image axes: x (horizontal), z (vertical).

  F_z'(r) = cos(θ)·Fz(r) + sin(θ)·Fx(r)   spin along tilted quantization axis z'
  n_col(x,z)       = ∫ n(x,y,z) dy           column density
  ⟨F_z'⟩_col(x,z)  = ∫ F_z'  dy / n_col      Stern-Gerlach measurable component
  Quiver arrows    : (⟨Fx⟩_col, ⟨Fz⟩_col)    lab-frame in-plane spin texture

Tilt convention:  θ > 0 tilts z' toward +x̂ (斜め上から view),
                  θ < 0 tilts z' toward −x̂ (斜め下から view).

Bz sign fix:  physical Bz = −code Bz
  (code uses H = −g_F μ_B B·F; standard H = +g_F μ_B B·F;
   so displayed axis is the physical lab field value).

Usage:
    python3 scripts/plot_B_sweep_imaging.py [RUN_DIR] [PLOT_DIR]
"""

import sys, os, glob
from pathlib import Path

import numpy as np
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import matplotlib.gridspec as gridspec

# ── Paths ──────────────────────────────────────────────────────────────────────
# Override default run directory via the SPINORBEC_RUNS_ROOT environment variable,
# or pass RUN_DIR as the first positional argument.
#   On TSUBAME:  export SPINORBEC_RUNS_ROOT=/gs/bs/work/6/<account>/bec-runs
#   Locally:     defaults to  runs/  in the repository root
_RUNS_ROOT  = Path(os.environ.get("SPINORBEC_RUNS_ROOT", Path(__file__).parent.parent / "runs"))
_SURVEY_REL = "projectA_ground_state/survey_B_secular_false_pm120_v3"

RUN_DIR  = Path(sys.argv[1]) if len(sys.argv) > 1 else _RUNS_ROOT / _SURVEY_REL
PLOT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else RUN_DIR / "plots_imaging"
PLOT_DIR.mkdir(parents=True, exist_ok=True)

# ── Bz lookup: scan_index (1-based) → code μG ─────────────────────────────────
# Physical Bz = −code Bz (sign fix applied in load_point)
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

THETAS_DEG = [0.0, +16.0, -16.0]   # tilt angles (degrees)

F_SPIN = 6
D      = 2 * F_SPIN + 1  # 13 spinor components

# ── Spin matrices F = 6 ────────────────────────────────────────────────────────
def _make_spin_matrices(F):
    Dv  = 2 * F + 1
    m   = np.arange(F, -F - 1, -1, dtype=float)   # m[0]=+F … m[D-1]=−F
    Fp  = np.zeros((Dv, Dv), dtype=float)
    for i in range(Dv - 1):
        mi = m[i + 1]
        Fp[i, i + 1] = np.sqrt(F * (F + 1) - mi * (mi + 1))
    Fm = Fp.T
    Fx = 0.5 * (Fp + Fm)
    return Fx, m   # Fx matrix; m[c] = magnetic quantum number for component c

Fx_mat, m_vals = _make_spin_matrices(F_SPIN)

# ── Load one scan point ────────────────────────────────────────────────────────
def load_point(fpath, slice_only=False):
    """
    slice_only=True: read only the y-centre x-z slice (fast pass 1 metadata).
    Returns dict: psi_full (D,nz,ny,nx), psi_xz (D,nz,nx), scan_idx, Bz_muG,
                  Mz, box_um (Lx,Ly,Lz in μm), nx, ny, nz, a_ho_um.
    """
    with h5py.File(fpath, 'r') as f:
        scan_idx = int(f['scan_index'][()])
        Mz       = float(f['mz_actual'][()])
        box_su   = f['grid_box_size'][()]
        n_pts    = f['grid_n_points'][()]
        a_ho_m   = float(f['units/a_ho_m'][()])
        a_ho_um  = a_ho_m * 1e6

        nx, ny, nz = int(n_pts[0]), int(n_pts[1]), int(n_pts[2])
        iy = ny // 2

        if slice_only:
            raw      = f['psi'][:, :, iy, :]        # (D, nz, nx) compound
            psi_xz   = raw['re'] + 1j * raw['im']
            psi_full = None
        else:
            raw      = f['psi'][()]                  # (D, nz, ny, nx) compound
            psi_full = raw['re'] + 1j * raw['im']
            psi_xz   = psi_full[:, :, iy, :]

        box_um = box_su * a_ho_um   # (Lx, Ly, Lz) in μm

    return dict(
        psi_full=psi_full, psi_xz=psi_xz,
        scan_idx=scan_idx,
        Bz_muG=-BZ_TABLE.get(scan_idx, 0.0),   # physical = −code
        Mz=Mz, box_um=box_um,
        nx=nx, ny=ny, nz=nz, a_ho_um=a_ho_um,
    )

# ── Column-integrated spin densities ──────────────────────────────────────────
def column_integrate(psi_full, theta_deg, n_thresh_frac=0.03):
    """
    psi_full : (D, nz, ny, nx) complex array
    theta_deg: tilt angle of quantization axis (z → x rotation, degrees)

    Returns dict with (nz, nx) 2D arrays:
        n_col   — column density ∫n dy
        Fzp_col — ⟨F_z'⟩_col  (spin along tilted axis, normalised by n_col)
        Fx_col  — ⟨Fx⟩_col     (lab-frame x spin, for quiver)
        Fz_col  — ⟨Fz⟩_col     (lab-frame z spin, for quiver)
        mask    — True where density < threshold
    """
    theta = np.radians(theta_deg)
    ct, st = np.cos(theta), np.sin(theta)

    D2, nz, ny, nx = psi_full.shape
    N_pts = nz * ny * nx

    abs2  = np.abs(psi_full) ** 2            # (D, nz, ny, nx) — |ψ_c|²
    n_3d  = abs2.sum(axis=0)                 # (nz, ny, nx)

    # Fz_3d: diagonal spin operator — Fz = Σ_c m_c |ψ_c|²
    Fz_3d = np.einsum('c,cijk->ijk', m_vals, abs2)   # (nz, ny, nx)

    # Fx_3d: off-diagonal — use fast matmul approach
    # Fx_3d[i,j,k] = Re[ ψ†[i,j,k]  Fx  ψ[i,j,k] ]
    psi_flat  = psi_full.reshape(D2, N_pts)          # (D, N_pts)
    Fx_psi    = Fx_mat @ psi_flat                    # (D, N_pts)  real @ complex
    Fx_3d = (psi_flat.conj() * Fx_psi).real.sum(axis=0).reshape(nz, ny, nx)

    # Tilted spin component along z'
    Fzp_3d = ct * Fz_3d + st * Fx_3d                # (nz, ny, nx)

    # Column integrate along y (axis 1 of nz,ny,nx)
    n_col    = n_3d.sum(axis=1)     # (nz, nx)
    Fzp_sum  = Fzp_3d.sum(axis=1)
    Fx_sum   = Fx_3d.sum(axis=1)
    Fz_sum   = Fz_3d.sum(axis=1)

    # Normalise — guard edges with near-zero density
    n_max  = float(n_col.max()) if n_col.max() > 0 else 1.0
    thresh = n_thresh_frac * n_max
    n_safe = np.where(n_col > thresh, n_col, thresh)
    mask   = n_col < thresh

    Fzp_col = np.where(mask, 0.0, Fzp_sum / n_safe)
    Fx_col  = np.where(mask, 0.0, Fx_sum  / n_safe)
    Fz_col  = np.where(mask, 0.0, Fz_sum  / n_safe)

    return dict(n_col=n_col, Fzp_col=Fzp_col, Fx_col=Fx_col, Fz_col=Fz_col, mask=mask)

# ── Gather files ───────────────────────────────────────────────────────────────
files = sorted(glob.glob(str(RUN_DIR / "point_*.jld2")))
N = len(files)
print(f"Found {N} files in {RUN_DIR}")

# ── Pass 1: metadata + representative color limits ─────────────────────────────
print("Pass 1: collecting metadata …")
Bz_all = []; Mz_all = []
n_col_max_all = 0.0

for fpath in files:
    d = load_point(fpath, slice_only=True)
    # Estimate column density from slice (proxy)
    n_est = np.sum(np.abs(d['psi_xz'])**2, axis=0)
    n_col_max_all = max(n_col_max_all, float(n_est.max()))
    Bz_all.append(d['Bz_muG'])
    Mz_all.append(d['Mz'])

Bz_all  = np.array(Bz_all)
Mz_all  = np.array(Mz_all)
order   = np.argsort(Bz_all)
files_sorted = [files[i] for i in order]
Bz_sorted    = Bz_all[order]
Mz_sorted    = Mz_all[order]

# Refine n_col_max from a few representative full files
print("  Refining color limits from sample files …")
sample_idxs = sorted(set([0, N//4, N//2, 3*N//4, N-1]))
for si in sample_idxs:
    ds = load_point(files_sorted[si], slice_only=False)
    ci = column_integrate(ds['psi_full'], 0.0)  # θ=0 sufficient for n_col scale
    n_col_max_all = max(n_col_max_all, float(ci['n_col'].max()))

print(f"  Bz range: {Bz_sorted.min():.0f} → {Bz_sorted.max():.0f} μG")
print(f"  n_col_max ≈ {n_col_max_all:.4f}")
print(f"  ⟨F_z'⟩_col color scale fixed at [−{F_SPIN}, +{F_SPIN}]")

# Fixed color normalizations
n_col_norm = mcolors.Normalize(0, n_col_max_all)
Fzp_norm   = mcolors.Normalize(-F_SPIN, F_SPIN)   # ±6, fixed for all frames

# ── Dark theme helpers ─────────────────────────────────────────────────────────
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

def _norm_vec(u, v):
    mag = np.hypot(u, v) + 1e-10
    return u / mag, v / mag

# ── Row labels and descriptors ─────────────────────────────────────────────────
THETA_LABELS = {
     0.0: r'$\theta = 0°$',
    +16.0: r'$\theta = +16°$',
    -16.0: r'$\theta = -16°$',
}
THETA_DESC = {
     0.0: 'quantization axis vertical',
    +16.0: 'z\' tilted +16° toward +x  (斜め上から)',
    -16.0: 'z\' tilted −16° toward +x  (斜め下から)',
}

kw_pcm  = dict(shading='auto', rasterized=True)
kw_quiv = dict(color='black', scale=12, width=0.006,
               headwidth=3, headlength=3.5, alpha=0.9)

# ── Pass 2: render frames ──────────────────────────────────────────────────────
print("Pass 2: rendering frames …")

for k, fpath in enumerate(files_sorted):
    d   = load_point(fpath, slice_only=False)
    Bz  = d['Bz_muG'];  Mz = d['Mz']
    nx  = d['nx'];  ny = d['ny'];  nz = d['nz']
    Lx, Ly, Lz = d['box_um']

    xs = np.linspace(-Lx/2, Lx/2, nx, endpoint=False)
    zs = np.linspace(-Lz/2, Lz/2, nz, endpoint=False)

    step = max(1, nx // 10)
    sq   = slice(None, None, step)

    # Compute column integrals for all three tilt angles
    ci_list = [column_integrate(d['psi_full'], t) for t in THETAS_DEG]

    # ── Figure: 3 rows × 3 cols (col2 spans all rows as summary) ────────────
    fig = plt.figure(figsize=(17, 14), facecolor=BG)
    gs_main = gridspec.GridSpec(
        3, 3,
        figure=fig,
        width_ratios=[1, 1, 0.72],
        hspace=0.42, wspace=0.32,
        left=0.06, right=0.97, top=0.92, bottom=0.05,
    )

    fig.suptitle(
        fr"$^{{151}}$Eu F=6 — Column-Integrated Imaging (camera along $y$)   |   "
        fr"$B_z$ = {Bz:+.0f} μG   |   "
        fr"$\langle F_z\rangle$ = {Mz:.3f}",
        color=WHITE, fontsize=12, fontweight='bold',
    )

    # Summary panel — spans all 3 rows in col 2
    ax_sum = fig.add_subplot(gs_main[0:3, 2])
    _style_ax(ax_sum)
    ax_sum.scatter(Bz_sorted, Mz_sorted, s=18, color='#5588cc', alpha=0.7,
                   zorder=2, label='all points')
    ax_sum.scatter([Bz], [Mz], s=150, color='#ff5555', zorder=3,
                   label='current', marker='*')
    ax_sum.axvline(0, color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax_sum.axhline(0, color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax_sum.set_xlabel('$B_z$ (μG)', color=WHITE, fontsize=9)
    ax_sum.set_ylabel(r'$\langle F_z\rangle_{\rm vol}$', color=WHITE, fontsize=9)
    ax_sum.set_title(r'$\langle F_z\rangle$ vs $B_z$', color=WHITE, fontsize=10)
    ax_sum.set_xlim(Bz_sorted.min() - 8, Bz_sorted.max() + 8)
    ax_sum.set_ylim(Mz_sorted.min() - 0.5, Mz_sorted.max() + 0.5)
    ax_sum.grid(True, alpha=0.15, color=WHITE)
    ax_sum.legend(fontsize=7, facecolor=BG2, edgecolor='#555577',
                  labelcolor=WHITE, markerscale=1.2)

    # Three rows — one per tilt angle
    for row, (theta, ci) in enumerate(zip(THETAS_DEG, ci_list)):
        n_col   = ci['n_col']    # (nz, nx)
        Fzp_col = ci['Fzp_col']
        Fx_col  = ci['Fx_col']
        Fz_col  = ci['Fz_col']

        # ── [row, 0]: column density ─────────────────────────────────────────
        ax0 = fig.add_subplot(gs_main[row, 0])
        _style_ax(ax0)
        im0 = ax0.pcolormesh(xs, zs, n_col,
                             cmap='magma', norm=n_col_norm, **kw_pcm)
        _colorbar(fig, ax0, im0, r'$\int n\,dy$')
        ax0.set_title(
            THETA_LABELS[theta] + '\n' + r'Column density $\int n\,dy$',
            fontsize=9,
        )
        ax0.set_xlabel('$x$ (μm)', fontsize=8)
        ax0.set_ylabel('$z$ (μm)', fontsize=8)
        ax0.set_aspect('equal')
        # Small annotation
        ax0.text(0.02, 0.97, THETA_DESC[theta],
                 transform=ax0.transAxes, color='#aaaacc', fontsize=6.5,
                 va='top', ha='left')

        # ── [row, 1]: ⟨F_z'⟩_col + quiver ──────────────────────────────────
        ax1 = fig.add_subplot(gs_main[row, 1])
        _style_ax(ax1)
        im1 = ax1.pcolormesh(xs, zs, Fzp_col,
                             cmap='RdBu_r', norm=Fzp_norm, **kw_pcm)
        _colorbar(fig, ax1, im1, r"$\langle F_{z'}\rangle_{\rm col}$")
        # Quiver: lab-frame (Fx_col, Fz_col) arrows
        ux, uz = _norm_vec(Fx_col[sq, sq], Fz_col[sq, sq])
        Xq, Zq = np.meshgrid(xs[sq], zs[sq])
        ax1.quiver(Xq, Zq, ux, uz, **kw_quiv)
        ax1.set_title(
            r"$\langle F_{z'}\rangle_{\rm col}(x,z)$" + '\n'
            + r'+ $(F_x,F_z)$ texture (lab frame)',
            fontsize=9,
        )
        ax1.set_xlabel('$x$ (μm)', fontsize=8)
        ax1.set_ylabel('$z$ (μm)', fontsize=8)
        ax1.set_aspect('equal')

    out_png = PLOT_DIR / f"frame_{k + 1:03d}.png"
    fig.savefig(out_png, dpi=110, bbox_inches='tight', facecolor=BG)
    plt.close(fig)
    print(f"  [{k+1:2d}/{N}]  Bz={Bz:+6.0f} μG  Mz={Mz:+.3f}  → {out_png.name}",
          flush=True)

print(f"\nAll {N} frames written to {PLOT_DIR}")

# ── Assemble GIF ───────────────────────────────────────────────────────────────
gif_path = PLOT_DIR / "B_sweep_imaging.gif"
frames   = sorted(glob.glob(str(PLOT_DIR / "frame_*.png")))

try:
    import imageio.v3 as iio
    imgs = [iio.imread(f) for f in frames]
    iio.imwrite(str(gif_path), imgs, duration=250, loop=0)
    print(f"GIF (imageio v3): {gif_path}")
except Exception:
    try:
        import imageio as iio2
        with iio2.get_writer(str(gif_path), mode='I', duration=0.25, loop=0) as w:
            for f in frames:
                w.append_data(iio2.imread(f))
        print(f"GIF (imageio v2): {gif_path}")
    except Exception:
        from PIL import Image
        imgs = [Image.open(f).convert('RGBA') for f in frames]
        imgs[0].save(str(gif_path), save_all=True, append_images=imgs[1:],
                     duration=250, loop=0, optimize=False)
        print(f"GIF (PIL): {gif_path}")

print("Done!")
