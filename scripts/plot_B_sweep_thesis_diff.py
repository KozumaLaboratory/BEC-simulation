#!/usr/bin/env python3
"""
plot_B_sweep_thesis_diff.py — Thesis differential imaging method (Goto 2026, §3.1.3).

Implements the quantization-axis tilt method for discriminating flower phase
from EdH effect in a ¹⁵¹Eu F=6 spinor BEC.

PHYSICS:
  For each spatial point r, state |φ(r)⟩ = Σ_c ψ_c(r)|m=F−c⟩.
  Tilt quantization axis by ±θ around Xc:  apply R̂(x̂, ∓θ) = exp(±iθ F̂x) to ψ(r).
  Extract m=−6 population in the rotated frame, column-integrate, subtract reference.

  Δn⁺_col(x,z) = ∫[|(R(+θ)ψ)[12]|² − Cp |ψ[12]|²] dy      (+θ tilt)
  Δn⁻_col(x,z) = ∫[|(R(−θ)ψ)[12]|² − Cp |ψ[12]|²] dy      (−θ tilt)

  Cp = |⟨−6|R(+θ)|−6⟩|² = |R(+θ)[12,12]|²   (projection correction factor)

DISCRIMINATOR:
  • Flower phase  →  Δn⁺_col ≈ Δn⁻_col        (same sign, left-right SYMMETRIC)
  • EdH effect    →  Δn⁺_col ≈ −Δn⁻_col       (opposite sign, CHECKERBOARD,
                                                  sign flips with θ→−θ)

Additional panel: (Δn⁺ + Δn⁻)/2 ≈ flower component (EdH cancels)
                  (Δn⁺ − Δn⁻)/2 ≈ EdH component   (flower cancels)

Usage:
    python3 scripts/plot_B_sweep_thesis_diff.py [RUN_DIR] [PLOT_DIR]
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
PLOT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else RUN_DIR / "plots_thesis_diff"
PLOT_DIR.mkdir(parents=True, exist_ok=True)

# ── Physics parameters ─────────────────────────────────────────────────────────
F_SPIN    = 6
D         = 2 * F_SPIN + 1      # 13 spinor components
IDX_M6    = D - 1                # index of m=−6 component (= 12)
THETA_DEG = 16.0                 # tilt angle (experimentally calibrated: ±16°)

# Bz lookup: scan_index (1-based) → code μG; physical = −code
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

# ── Build F=6 spin matrices ────────────────────────────────────────────────────
#   Convention: component index c ↔ m = F − c
#   ⟹  m[0]=+6  m[1]=+5  ...  m[12]=−6   (IDX_M6 = 12)
m_vals = np.arange(F_SPIN, -F_SPIN - 1, -1, dtype=float)   # shape (13,)

def _build_fx():
    """Build F̂x = (F̂+ + F̂−)/2 for F=6 (13×13, dimensionless ℏ=1)."""
    Fp = np.zeros((D, D), dtype=float)
    for i in range(D - 1):
        mi = m_vals[i + 1]                          # m of source state
        Fp[i, i + 1] = np.sqrt(F_SPIN * (F_SPIN + 1) - mi * (mi + 1))
    Fm = Fp.T
    return 0.5 * (Fp + Fm)

FX = _build_fx()   # (13, 13) real symmetric matrix, ℏ=1 units

# ── Rotation matrices R(±θ) and correction factor Cp ──────────────────────────
#   Quantization axis tilt +θ around x̂:  apply R̂(x̂, −θ) = exp(+iθ F̂x)  [thesis §3.2.6]
#   Quantization axis tilt −θ around x̂:  apply R̂(x̂, +θ) = exp(−iθ F̂x)
#   FX is real symmetric → diagonalize with eigh, then exp eigenvalues analytically.
theta_rad = np.deg2rad(THETA_DEG)

def _matrix_exp_fx(sign):
    """Compute exp(sign * i * theta_rad * FX) via eigendecomposition (no scipy)."""
    vals, vecs = np.linalg.eigh(FX)          # FX real symmetric → real eigenvalues
    return (vecs * np.exp(sign * 1j * theta_rad * vals)) @ vecs.conj().T

R_PLUS  = _matrix_exp_fx(+1)   # for +θ quantization axis tilt
R_MINUS = _matrix_exp_fx(-1)   # for −θ quantization axis tilt

# Correction factor: projection of |-6⟩ onto |-6⟩ in rotated frame
Cp = float(np.abs(R_PLUS[IDX_M6, IDX_M6]) ** 2)   # symmetric: same for ±θ

print(f"θ = ±{THETA_DEG}°   Cp = {Cp:.6f}  (= cos^{2*F_SPIN}(θ/2) ≈ {np.cos(theta_rad/2)**(2*F_SPIN):.6f})")

# ── Load one scan point ────────────────────────────────────────────────────────
def load_point(fpath, slice_only=False):
    with h5py.File(fpath, 'r') as f:
        scan_idx = int(f['scan_index'][()])
        Mz       = float(f['mz_actual'][()])
        box_su   = f['grid_box_size'][()]
        n_pts    = f['grid_n_points'][()]
        a_ho_m   = float(f['units/a_ho_m'][()])

        nx, ny, nz = int(n_pts[0]), int(n_pts[1]), int(n_pts[2])
        a_ho_um = a_ho_m * 1e6
        iy = ny // 2

        if slice_only:
            raw      = f['psi'][:, :, iy, :]
            psi_xz   = raw['re'] + 1j * raw['im']
            psi_full = None
        else:
            raw      = f['psi'][()]
            psi_full = raw['re'] + 1j * raw['im']   # (D, nz, ny, nx) complex
            psi_xz   = psi_full[:, :, iy, :]

        box_um = box_su * a_ho_um   # (Lx, Ly, Lz) in μm

    return dict(
        psi_full=psi_full, psi_xz=psi_xz,
        scan_idx=scan_idx,
        Bz_muG=-BZ_TABLE.get(scan_idx, 0.0),
        Mz=Mz, box_um=box_um,
        nx=nx, ny=ny, nz=nz,
    )

# ── Core differential imaging computation ─────────────────────────────────────
def compute_diff_images(psi_full):
    """
    Thesis §3.1.3 differential imaging for all five output quantities.

    psi_full : (D, nz, ny, nx) complex  — full spinor wavefunction

    Returns dict of (nz, nx) 2D arrays (all column-integrated along y):
        n_col      : total column density
        n_m6_col   : m=−6 column density (untilted reference)
        diff_plus  : Δn⁺_col = ∫[|(R₊ψ)_{m=-6}|² − Cp|ψ_{m=-6}|²] dy
        diff_minus : Δn⁻_col = ∫[|(R₋ψ)_{m=-6}|² − Cp|ψ_{m=-6}|²] dy
        sum_col    : (Δn⁺ + Δn⁻)/2  ≈ flower phase signature
        dif_col    : (Δn⁺ − Δn⁻)/2  ≈ EdH signature
    """
    _, nz, ny, nx = psi_full.shape
    N_pts = nz * ny * nx

    # Flatten spatial dims for rotation matmul
    psi_flat = psi_full.reshape(D, N_pts)               # (13, N)

    # Apply rotation matrices
    psi_plus_flat  = R_PLUS  @ psi_flat                 # (13, N)  complex matmul
    psi_minus_flat = R_MINUS @ psi_flat                 # (13, N)

    # m=−6 (index 12) densities in each frame
    n_m6_3d    = (np.abs(psi_flat[IDX_M6])**2).reshape(nz, ny, nx)
    n_plus_3d  = (np.abs(psi_plus_flat[IDX_M6])**2).reshape(nz, ny, nx)
    n_minus_3d = (np.abs(psi_minus_flat[IDX_M6])**2).reshape(nz, ny, nx)

    # Total density
    n_3d = (np.abs(psi_flat)**2).sum(axis=0).reshape(nz, ny, nx)

    # Differences (before column integration)
    delta_plus_3d  = n_plus_3d  - Cp * n_m6_3d
    delta_minus_3d = n_minus_3d - Cp * n_m6_3d

    # Column integrate along y (axis 1 of nz,ny,nx layout)
    n_col      = n_3d.sum(axis=1)
    n_m6_col   = n_m6_3d.sum(axis=1)
    diff_plus  = delta_plus_3d.sum(axis=1)
    diff_minus = delta_minus_3d.sum(axis=1)
    sum_col    = 0.5 * (diff_plus + diff_minus)
    dif_col    = 0.5 * (diff_plus - diff_minus)

    return dict(
        n_col=n_col, n_m6_col=n_m6_col,
        diff_plus=diff_plus, diff_minus=diff_minus,
        sum_col=sum_col, dif_col=dif_col,
    )

# ── Gather and sort files ──────────────────────────────────────────────────────
files = sorted(glob.glob(str(RUN_DIR / "point_*.jld2")))
N = len(files)
print(f"Found {N} files in {RUN_DIR}")
if N == 0:
    raise RuntimeError(f"No point_*.jld2 files in {RUN_DIR}")

print("Pass 1: reading metadata …")
Bz_all = []; Mz_all = []
for fpath in files:
    d = load_point(fpath, slice_only=True)
    Bz_all.append(d['Bz_muG'])
    Mz_all.append(d['Mz'])

Bz_all = np.array(Bz_all)
Mz_all = np.array(Mz_all)
order        = np.argsort(Bz_all)
files_sorted = [files[i] for i in order]
Bz_sorted    = Bz_all[order]
Mz_sorted    = Mz_all[order]

# ── Pass 1b: determine color scales from sample points ────────────────────────
print("  Sampling color limits …")
sample_idxs = sorted(set([0, N//4, N//2, 3*N//4, N-1]))
n_col_max  = 0.0
diff_abs_max = 0.0

for si in sample_idxs:
    ds = load_point(files_sorted[si], slice_only=False)
    ci = compute_diff_images(ds['psi_full'])
    n_col_max   = max(n_col_max,  float(ci['n_col'].max()))
    diff_abs_max = max(diff_abs_max,
                       float(np.abs(ci['diff_plus']).max()),
                       float(np.abs(ci['diff_minus']).max()))

print(f"  Bz range: {Bz_sorted.min():.0f} → {Bz_sorted.max():.0f} μG")
print(f"  n_col_max  ≈ {n_col_max:.4e}")
print(f"  diff scale ≈ {diff_abs_max:.4e}")

n_norm   = mcolors.Normalize(0, n_col_max)
diff_lim = diff_abs_max * 1.05   # slight headroom

# ── Dark-theme helpers ─────────────────────────────────────────────────────────
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

def _cb(fig, ax, im, label):
    cb = fig.colorbar(im, ax=ax, fraction=0.045, pad=0.03)
    cb.set_label(label, color=WHITE, fontsize=7)
    cb.ax.tick_params(colors=WHITE, labelsize=6)
    return cb

kw_pcm = dict(shading='auto', rasterized=True)

# ── Pass 2: render frames ──────────────────────────────────────────────────────
print("Pass 2: rendering frames …")

for k, fpath in enumerate(files_sorted):
    d   = load_point(fpath, slice_only=False)
    Bz  = d['Bz_muG'];  Mz = d['Mz']
    nx  = d['nx'];  nz = d['nz']
    Lx, Ly, Lz = d['box_um']

    xs = np.linspace(-Lx/2, Lx/2, nx, endpoint=False)
    zs = np.linspace(-Lz/2, Lz/2, nz, endpoint=False)

    ci = compute_diff_images(d['psi_full'])

    # Scalar discriminators: asymmetry index
    # A > 0 → diff_plus and diff_minus same sign → flower-like
    # A < 0 → opposite sign → EdH-like
    same_sign = np.sum(ci['diff_plus'] * ci['diff_minus'])
    total_sq  = np.sqrt(np.sum(ci['diff_plus']**2) * np.sum(ci['diff_minus']**2)) + 1e-30
    asym_idx  = float(same_sign / total_sq)  # ∈ [−1, +1]; +1=flower, −1=EdH

    # ── Figure layout ──────────────────────────────────────────────────────────
    # Row 0: [n_col] [Δn⁺] [Δn⁻]     | summary (spans both rows)
    # Row 1: [m=-6 density] [(Δn⁺+Δn⁻)/2] [(Δn⁺−Δn⁻)/2] |
    fig = plt.figure(figsize=(18, 11), facecolor=BG)
    gs = gridspec.GridSpec(
        2, 4,
        figure=fig,
        width_ratios=[1, 1, 1, 0.65],
        hspace=0.42, wspace=0.30,
        left=0.05, right=0.97, top=0.91, bottom=0.06,
    )

    # Determine symmetry verdict
    if   asym_idx >  0.3:  verdict = '→ FLOWER phase'       ; vcol = '#55ff99'
    elif asym_idx < -0.3:  verdict = '→ EdH effect'         ; vcol = '#ff8855'
    else:                  verdict = '→ mixed / transitional'; vcol = '#ffff55'

    fig.suptitle(
        fr"$^{{151}}$Eu F=6  Thesis Differential Imaging   |   "
        fr"$B_z$ = {Bz:+.0f} μG   |   "
        fr"$\langle F_z\rangle$ = {Mz:.3f}   |   "
        fr"asym = {asym_idx:+.3f}  {verdict}",
        color=WHITE, fontsize=11, fontweight='bold',
    )

    # ── Summary panel (right, spans 2 rows) ───────────────────────────────────
    ax_s = fig.add_subplot(gs[:, 3])
    _style_ax(ax_s)
    ax_s.scatter(Bz_sorted, Mz_sorted, s=14, color='#5588cc', alpha=0.7, zorder=2)
    ax_s.scatter([Bz], [Mz], s=140, color='#ff5555', zorder=3, marker='*')
    ax_s.axvline(0, color='#888', ls='--', lw=0.7, alpha=0.5)
    ax_s.axhline(0, color='#888', ls='--', lw=0.7, alpha=0.5)
    ax_s.set_xlabel('$B_z$ (μG)', color=WHITE, fontsize=8)
    ax_s.set_ylabel(r'$\langle F_z\rangle$', color=WHITE, fontsize=8)
    ax_s.set_title(r'$\langle F_z\rangle$ vs $B_z$', color=WHITE, fontsize=9)
    ax_s.set_xlim(Bz_sorted.min()-8, Bz_sorted.max()+8)
    ax_s.set_ylim(Mz_sorted.min()-0.3, Mz_sorted.max()+0.3)
    ax_s.grid(True, alpha=0.15, color=WHITE)

    # ── Row 0 ─────────────────────────────────────────────────────────────────

    # [0,0] Total column density
    ax00 = fig.add_subplot(gs[0, 0])
    _style_ax(ax00)
    im00 = ax00.pcolormesh(xs, zs, ci['n_col'], cmap='magma', norm=n_norm, **kw_pcm)
    _cb(fig, ax00, im00, r'$\int n\,dy$')
    ax00.set_title(r'$n_\mathrm{col}(x,z)$  total density', fontsize=9)
    ax00.set_xlabel('x (μm)', fontsize=8); ax00.set_ylabel('z (μm)', fontsize=8)
    ax00.set_aspect('equal')

    # [0,1] Δn⁺_col  (+θ tilt)
    ax01 = fig.add_subplot(gs[0, 1])
    _style_ax(ax01)
    im01 = ax01.pcolormesh(xs, zs, ci['diff_plus'],
                           cmap='RdBu_r',
                           norm=mcolors.Normalize(-diff_lim, diff_lim), **kw_pcm)
    _cb(fig, ax01, im01, r'$\Delta n^+_\mathrm{col}$')
    ax01.set_title(
        fr'$\Delta n^+_\mathrm{{col}}$ (+{THETA_DEG:.0f}° tilt)' + '\n'
        r'$n^{+\theta}_{m=-6} - C_p\,n^{(0)}_{m=-6}$', fontsize=8.5)
    ax01.set_xlabel('x (μm)', fontsize=8); ax01.set_ylabel('z (μm)', fontsize=8)
    ax01.set_aspect('equal')

    # [0,2] Δn⁻_col  (−θ tilt)
    ax02 = fig.add_subplot(gs[0, 2])
    _style_ax(ax02)
    im02 = ax02.pcolormesh(xs, zs, ci['diff_minus'],
                           cmap='RdBu_r',
                           norm=mcolors.Normalize(-diff_lim, diff_lim), **kw_pcm)
    _cb(fig, ax02, im02, r'$\Delta n^-_\mathrm{col}$')
    ax02.set_title(
        fr'$\Delta n^-_\mathrm{{col}}$ (−{THETA_DEG:.0f}° tilt)' + '\n'
        r'$n^{-\theta}_{m=-6} - C_p\,n^{(0)}_{m=-6}$', fontsize=8.5)
    ax02.set_xlabel('x (μm)', fontsize=8); ax02.set_ylabel('z (μm)', fontsize=8)
    ax02.set_aspect('equal')

    # ── Row 1 ─────────────────────────────────────────────────────────────────

    # [1,0] m=−6 column density (reference, untilted)
    ax10 = fig.add_subplot(gs[1, 0])
    _style_ax(ax10)
    n_m6_norm = mcolors.Normalize(0, ci['n_m6_col'].max() or 1)
    im10 = ax10.pcolormesh(xs, zs, ci['n_m6_col'], cmap='viridis', norm=n_m6_norm, **kw_pcm)
    _cb(fig, ax10, im10, r'$\int|ψ_{-6}|^2 dy$')
    ax10.set_title(r'$n_{m=-6}$ untilted  (reference)', fontsize=9)
    ax10.set_xlabel('x (μm)', fontsize=8); ax10.set_ylabel('z (μm)', fontsize=8)
    ax10.set_aspect('equal')

    # [1,1] (Δn⁺ + Δn⁻)/2  → flower signature (EdH cancels)
    ax11 = fig.add_subplot(gs[1, 1])
    _style_ax(ax11)
    sum_lim = float(np.abs(ci['sum_col']).max()) or diff_lim * 0.5
    im11 = ax11.pcolormesh(xs, zs, ci['sum_col'],
                           cmap='RdBu_r',
                           norm=mcolors.Normalize(-sum_lim, sum_lim), **kw_pcm)
    _cb(fig, ax11, im11, r'$(\Delta n^++\Delta n^-)/2$')
    ax11.set_title(
        r'$(\Delta n^+ + \Delta n^-)/2$' + '\n'
        r'≈ flower signature  (EdH cancels)', fontsize=8.5,
        color='#55ff99')
    ax11.set_xlabel('x (μm)', fontsize=8); ax11.set_ylabel('z (μm)', fontsize=8)
    ax11.set_aspect('equal')

    # [1,2] (Δn⁺ − Δn⁻)/2  → EdH signature (flower cancels)
    ax12 = fig.add_subplot(gs[1, 2])
    _style_ax(ax12)
    dif_lim2 = float(np.abs(ci['dif_col']).max()) or diff_lim * 0.5
    im12 = ax12.pcolormesh(xs, zs, ci['dif_col'],
                           cmap='RdBu_r',
                           norm=mcolors.Normalize(-dif_lim2, dif_lim2), **kw_pcm)
    _cb(fig, ax12, im12, r'$(\Delta n^+-\Delta n^-)/2$')
    ax12.set_title(
        r'$(\Delta n^+ - \Delta n^-)/2$' + '\n'
        r'≈ EdH signature  (flower cancels)', fontsize=8.5,
        color='#ff8855')
    ax12.set_xlabel('x (μm)', fontsize=8); ax12.set_ylabel('z (μm)', fontsize=8)
    ax12.set_aspect('equal')

    # Asymmetry annotation
    verdict_text = (
        f"asym = {asym_idx:+.3f}\n"
        f"+1 = pure flower  −1 = pure EdH"
    )
    fig.text(0.01, 0.01, verdict_text, color=vcol, fontsize=8,
             transform=fig.transFigure, va='bottom')

    out_png = PLOT_DIR / f"frame_{k+1:03d}.png"
    fig.savefig(out_png, dpi=100, bbox_inches='tight', facecolor=BG)
    plt.close(fig)
    print(f"  [{k+1:2d}/{N}]  Bz={Bz:+6.0f} μG  Mz={Mz:+.3f}  asym={asym_idx:+.3f}  → {out_png.name}",
          flush=True)

print(f"\nAll {N} frames written to {PLOT_DIR}")

# ── Assemble GIF ───────────────────────────────────────────────────────────────
gif_path = PLOT_DIR / "B_sweep_thesis_diff.gif"
frames_list = sorted(glob.glob(str(PLOT_DIR / "frame_*.png")))

try:
    import imageio.v3 as iio
    imgs = [iio.imread(f) for f in frames_list]
    iio.imwrite(str(gif_path), imgs, duration=280, loop=0)
    print(f"GIF (imageio v3): {gif_path}")
except Exception:
    try:
        import imageio as iio2
        with iio2.get_writer(str(gif_path), mode='I', duration=0.28, loop=0) as w:
            for f in frames_list:
                w.append_data(iio2.imread(f))
        print(f"GIF (imageio v2): {gif_path}")
    except Exception:
        from PIL import Image
        imgs_pil = [Image.open(f).convert('RGBA') for f in frames_list]
        imgs_pil[0].save(str(gif_path), save_all=True, append_images=imgs_pil[1:],
                         duration=280, loop=0, optimize=False)
        print(f"GIF (PIL): {gif_path}")

print("Done!")
