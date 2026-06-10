#!/usr/bin/env python3
"""
plot_B_sweep_imaging_diff.py — difference maps between +16° and −16° tilt imaging.

Takes the column-integrated images at θ = +16° and θ = −16° and computes
their difference:

  Δn_col(x,z)      = n_col(+16°) − n_col(−16°)
  ΔF_z'_col(x,z)   = ⟨F_z'(+16°)⟩_col − ⟨F_z'(−16°)⟩_col
                   = 2 sin(16°) · ⟨Fx⟩_col        (isolates in-plane Fx texture)

Also shows the sum (average) for comparison:

  ΣF_z'_col(x,z)   = [⟨F_z'(+16°)⟩_col + ⟨F_z'(−16°)⟩_col] / 2
                   = cos(16°) · ⟨Fz⟩_col           (isolates vertical Fz texture)

Layout per frame:
  Row 0  — Δn_col (density diff)  |  ΔF_z'_col + quiver  |  ⟨Fz⟩ vs Bz summary
  Row 1  — ΣF_z'_col (Fz proxy)  |  ΔF_z'_col / n_col normalised  |  (empty)

Bz sign fix: physical Bz = −code Bz.

Usage:
    python3 scripts/plot_B_sweep_imaging_diff.py [RUN_DIR] [PLOT_DIR]
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
PLOT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else RUN_DIR / "plots_imaging_diff"
PLOT_DIR.mkdir(parents=True, exist_ok=True)

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

THETA_PLUS  = +16.0
THETA_MINUS = -16.0
F_SPIN = 6
D      = 2 * F_SPIN + 1

# ── Spin matrices ──────────────────────────────────────────────────────────────
def _make_spin_matrices(F):
    Dv = 2 * F + 1
    m  = np.arange(F, -F - 1, -1, dtype=float)
    Fp = np.zeros((Dv, Dv), dtype=float)
    for i in range(Dv - 1):
        mi = m[i + 1]
        Fp[i, i + 1] = np.sqrt(F * (F + 1) - mi * (mi + 1))
    Fx = 0.5 * (Fp + Fp.T)
    return Fx, m

Fx_mat, m_vals = _make_spin_matrices(F_SPIN)

# ── Load ───────────────────────────────────────────────────────────────────────
def load_point(fpath, slice_only=False):
    with h5py.File(fpath, 'r') as f:
        scan_idx = int(f['scan_index'][()])
        Mz       = float(f['mz_actual'][()])
        box_su   = f['grid_box_size'][()]
        n_pts    = f['grid_n_points'][()]
        a_ho_um  = float(f['units/a_ho_m'][()]) * 1e6
        nx, ny, nz = int(n_pts[0]), int(n_pts[1]), int(n_pts[2])
        iy = ny // 2
        if slice_only:
            raw    = f['psi'][:, :, iy, :]
            psi_xz = raw['re'] + 1j * raw['im']
            psi_full = None
        else:
            raw      = f['psi'][()]
            psi_full = raw['re'] + 1j * raw['im']
            psi_xz   = psi_full[:, :, iy, :]
        box_um = box_su * a_ho_um
    return dict(
        psi_full=psi_full, psi_xz=psi_xz,
        scan_idx=scan_idx,
        Bz_muG=-BZ_TABLE.get(scan_idx, 0.0),
        Mz=Mz, box_um=box_um, nx=nx, ny=ny, nz=nz,
    )

# ── Column integral ────────────────────────────────────────────────────────────
def column_integrate(psi_full, theta_deg, n_thresh_frac=0.03):
    theta = np.radians(theta_deg)
    ct, st = np.cos(theta), np.sin(theta)
    D2, nz, ny, nx = psi_full.shape
    abs2  = np.abs(psi_full) ** 2
    n_3d  = abs2.sum(axis=0)
    Fz_3d = np.einsum('c,cijk->ijk', m_vals, abs2)
    psi_flat = psi_full.reshape(D2, nz * ny * nx)
    Fx_3d = (psi_flat.conj() * (Fx_mat @ psi_flat)).real.sum(axis=0).reshape(nz, ny, nx)
    Fzp_3d = ct * Fz_3d + st * Fx_3d
    n_col   = n_3d.sum(axis=1)
    Fzp_sum = Fzp_3d.sum(axis=1)
    Fx_sum  = Fx_3d.sum(axis=1)
    Fz_sum  = Fz_3d.sum(axis=1)
    n_max   = float(n_col.max()) if n_col.max() > 0 else 1.0
    thresh  = n_thresh_frac * n_max
    n_safe  = np.where(n_col > thresh, n_col, thresh)
    mask    = n_col < thresh
    Fzp_col = np.where(mask, 0.0, Fzp_sum / n_safe)
    Fx_col  = np.where(mask, 0.0, Fx_sum  / n_safe)
    Fz_col  = np.where(mask, 0.0, Fz_sum  / n_safe)
    return dict(n_col=n_col, Fzp_col=Fzp_col, Fx_col=Fx_col, Fz_col=Fz_col,
                Fzp_sum=Fzp_sum, Fx_sum=Fx_sum, n_safe=n_safe, mask=mask)

# ── Files ──────────────────────────────────────────────────────────────────────
files = sorted(glob.glob(str(RUN_DIR / "point_*.jld2")))
N = len(files)
print(f"Found {N} files in {RUN_DIR}")

print("Pass 1: collecting metadata …")
Bz_all = []; Mz_all = []
for fpath in files:
    d = load_point(fpath, slice_only=True)
    Bz_all.append(d['Bz_muG']); Mz_all.append(d['Mz'])

Bz_all = np.array(Bz_all); Mz_all = np.array(Mz_all)
order  = np.argsort(Bz_all)
files_sorted = [files[i] for i in order]
Bz_sorted    = Bz_all[order]
Mz_sorted    = Mz_all[order]

# Color limits hardcoded from prior sampling run (avoids expensive NFS pre-read)
# Values obtained from: Δn range: ±0.0000, ΔF_z': ±2.631, ΣF_z'/2: ±5.766
# n_col_max estimated from slice proxy in Pass 1 above
dn_abs_max   = 0.01        # density diff near zero; small non-zero to show any asymmetry
dFzp_abs_max = 2.631       # ≈ 2sin(16°)·|Fx|_max
sFzp_abs_max = 5.766       # ≈ cos(16°)·|Fz|_max
# n_col_max: center-slice density max × ny as proxy for column integral
_d_mid    = load_point(files_sorted[N//2], slice_only=True)
_ny_est   = _d_mid['ny']
_n_slice_max = float((np.abs(_d_mid['psi_xz'])**2).sum(axis=0).max())
n_col_max = max(_n_slice_max * _ny_est, 1e-6)

print(f"  Δn range: ±{dn_abs_max:.4f}  (hardcoded)")
print(f"  ΔF_z' range: ±{dFzp_abs_max:.3f}  (hardcoded)")
print(f"  ΣF_z'/2 range: ±{sFzp_abs_max:.3f}  (hardcoded)")
print(f"  n_col_max ≈ {n_col_max:.4f}  (from slice proxy)")

dn_norm   = mcolors.Normalize(-dn_abs_max,   dn_abs_max)
dFzp_norm = mcolors.Normalize(-dFzp_abs_max, dFzp_abs_max)
sFzp_norm = mcolors.Normalize(-sFzp_abs_max, sFzp_abs_max)
n_norm    = mcolors.Normalize(0, n_col_max)

# ── Dark theme ─────────────────────────────────────────────────────────────────
BG = '#0d0d1a'; BG2 = '#1a1a2e'; WHITE = 'white'

def _style_ax(ax):
    ax.set_facecolor(BG2)
    ax.tick_params(colors=WHITE, labelsize=8)
    ax.xaxis.label.set_color(WHITE); ax.yaxis.label.set_color(WHITE)
    ax.title.set_color(WHITE)
    for sp in ax.spines.values(): sp.set_edgecolor('#444466')

def _colorbar(fig, ax, im, label):
    cb = fig.colorbar(im, ax=ax, fraction=0.045, pad=0.03)
    cb.set_label(label, color=WHITE, fontsize=8)
    cb.ax.tick_params(colors=WHITE, labelsize=7)

def _norm_vec(u, v):
    return u / (np.hypot(u, v) + 1e-10), v / (np.hypot(u, v) + 1e-10)

kw_pcm  = dict(shading='auto', rasterized=True)
kw_quiv = dict(color='black', scale=12, width=0.006,
               headwidth=3, headlength=3.5, alpha=0.9)

# ── Pass 2: render ─────────────────────────────────────────────────────────────
print("Pass 2: rendering frames …")

for k, fpath in enumerate(files_sorted):
    d   = load_point(fpath, slice_only=False)
    Bz  = d['Bz_muG'];  Mz = d['Mz']
    nx  = d['nx'];  nz = d['nz']
    Lx, Ly, Lz = d['box_um']
    xs = np.linspace(-Lx/2, Lx/2, nx, endpoint=False)
    zs = np.linspace(-Lz/2, Lz/2, nz, endpoint=False)
    step = max(1, nx // 10);  sq = slice(None, None, step)

    cp = column_integrate(d['psi_full'], THETA_PLUS)
    cm = column_integrate(d['psi_full'], THETA_MINUS)

    # n_col is θ-independent (total atom density = Σ|ψ_c|², no θ dependence)
    # → Δn_col ≡ 0 by physics; use the common density as reference panel
    n_col  = 0.5 * (cp['n_col'] + cm['n_col'])               # same for both θ

    dFzp = cp['Fzp_col'] - cm['Fzp_col']   # ΔF_z' ≈ 2sin(θ)·⟨Fx⟩_col  (Fx proxy)
    sFzp = 0.5 * (cp['Fzp_col'] + cm['Fzp_col'])  # ΣF_z'/2 ≈ cos(θ)·⟨Fz⟩_col (Fz proxy)

    # quiver arrows for each panel
    # ΔF_z' panel: quiver shows the difference of (Fx,Fz) in lab frame
    dFx_q = cp['Fx_col'] - cm['Fx_col']
    dFz_q = cp['Fz_col'] - cm['Fz_col']
    # ΣF_z'/2 panel: quiver shows the average (Fx,Fz) in lab frame
    sFx_q = 0.5 * (cp['Fx_col'] + cm['Fx_col'])
    sFz_q = 0.5 * (cp['Fz_col'] + cm['Fz_col'])

    # ── Figure: 2×2 layout ───────────────────────────────────────────────────
    fig = plt.figure(figsize=(14, 11), facecolor=BG)
    gs_main = gridspec.GridSpec(
        2, 2, figure=fig,
        hspace=0.40, wspace=0.32,
        left=0.07, right=0.97, top=0.91, bottom=0.06,
    )
    fig.suptitle(
        fr"$^{{151}}$Eu F=6 — Difference/Sum Maps  (+16° vs −16°)   |   "
        fr"$B_z$ = {Bz:+.0f} μG   |   $\langle F_z\rangle$ = {Mz:.3f}",
        color=WHITE, fontsize=12, fontweight='bold',
    )

    Xq, Zq = np.meshgrid(xs[sq], zs[sq])

    # ── [0,0] Column density (θ-independent, reference) ───────────────────────
    ax00 = fig.add_subplot(gs_main[0, 0])
    _style_ax(ax00)
    im00 = ax00.pcolormesh(xs, zs, n_col, cmap='magma', norm=n_norm, **kw_pcm)
    _colorbar(fig, ax00, im00, r'$n_{\rm col}$')
    ax00.set_title(r'Column density  $n_{\rm col}(x,z)$' + '\n'
                   + r'(same for $\pm16°$ — $\theta$-independent)',
                   fontsize=9)
    ax00.set_xlabel('$x$ (μm)', fontsize=8);  ax00.set_ylabel('$z$ (μm)', fontsize=8)
    ax00.set_aspect('equal')

    # ── [0,1] ΔF_z'_col ≈ 2sin(16°)·⟨Fx⟩_col ────────────────────────────────
    ax01 = fig.add_subplot(gs_main[0, 1])
    _style_ax(ax01)
    im01 = ax01.pcolormesh(xs, zs, dFzp, cmap='RdBu_r', norm=dFzp_norm, **kw_pcm)
    _colorbar(fig, ax01, im01, r"$\Delta\langle F_{z'}\rangle_{\rm col}$")
    ux, uz = _norm_vec(dFx_q[sq, sq], dFz_q[sq, sq])
    ax01.quiver(Xq, Zq, ux, uz, **kw_quiv)
    ax01.set_title(
        r"DIFFERENCE  $\langle F_{z'}(+16°)\rangle - \langle F_{z'}(-16°)\rangle$" + '\n'
        + r"$\approx 2\sin16°\cdot\langle F_x\rangle_{\rm col}$  (in-plane $F_x$)",
        fontsize=8.5,
    )
    ax01.set_xlabel('$x$ (μm)', fontsize=8);  ax01.set_ylabel('$z$ (μm)', fontsize=8)
    ax01.set_aspect('equal')

    # ── [1,0] ΣF_z'/2 ≈ cos(16°)·⟨Fz⟩_col ──────────────────────────────────
    ax10 = fig.add_subplot(gs_main[1, 0])
    _style_ax(ax10)
    im10 = ax10.pcolormesh(xs, zs, sFzp, cmap='RdBu_r', norm=sFzp_norm, **kw_pcm)
    _colorbar(fig, ax10, im10, r"$\Sigma\langle F_{z'}\rangle_{\rm col}/2$")
    ux2, uz2 = _norm_vec(sFx_q[sq, sq], sFz_q[sq, sq])
    ax10.quiver(Xq, Zq, ux2, uz2, **kw_quiv)
    ax10.set_title(
        r"SUM  $[\langle F_{z'}(+16°)\rangle + \langle F_{z'}(-16°)\rangle]/2$" + '\n'
        + r"$\approx \cos16°\cdot\langle F_z\rangle_{\rm col}$  (vertical $F_z$)",
        fontsize=8.5,
    )
    ax10.set_xlabel('$x$ (μm)', fontsize=8);  ax10.set_ylabel('$z$ (μm)', fontsize=8)
    ax10.set_aspect('equal')

    # ── [1,1] ⟨Fz⟩ vs Bz summary ────────────────────────────────────────────
    ax11 = fig.add_subplot(gs_main[1, 1])
    _style_ax(ax11)
    ax11.scatter(Bz_sorted, Mz_sorted, s=18, color='#5588cc', alpha=0.7, zorder=2)
    ax11.scatter([Bz], [Mz], s=150, color='#ff5555', zorder=3, marker='*')
    ax11.axvline(0, color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax11.axhline(0, color='#888888', ls='--', lw=0.8, alpha=0.5)
    ax11.set_xlabel('$B_z$ (μG)', color=WHITE, fontsize=9)
    ax11.set_ylabel(r'$\langle F_z\rangle_{\rm vol}$', color=WHITE, fontsize=9)
    ax11.set_title(r'$\langle F_z\rangle$ vs $B_z$', color=WHITE, fontsize=10)
    ax11.set_xlim(Bz_sorted.min()-8, Bz_sorted.max()+8)
    ax11.set_ylim(Mz_sorted.min()-0.5, Mz_sorted.max()+0.5)
    ax11.grid(True, alpha=0.15, color=WHITE)

    out_png = PLOT_DIR / f"frame_{k + 1:03d}.png"
    # Always overwrite (layout changed)
    _ = None
    fig.savefig(out_png, dpi=110, bbox_inches='tight', facecolor=BG)
    plt.close(fig)
    print(f"  [{k+1:2d}/{N}]  Bz={Bz:+6.0f} μG  Mz={Mz:+.3f}  → {out_png.name}",
          flush=True)

print(f"\nAll {N} frames written to {PLOT_DIR}")

# ── GIF ────────────────────────────────────────────────────────────────────────
gif_path = PLOT_DIR / "B_sweep_imaging_diff.gif"
frames   = sorted(glob.glob(str(PLOT_DIR / "frame_*.png")))
try:
    import imageio.v3 as iio
    iio.imwrite(str(gif_path), [iio.imread(f) for f in frames], duration=250, loop=0)
    print(f"GIF (imageio v3): {gif_path}")
except Exception:
    try:
        import imageio as iio2
        with iio2.get_writer(str(gif_path), mode='I', duration=0.25, loop=0) as w:
            for f in frames: w.append_data(iio2.imread(f))
        print(f"GIF (imageio v2): {gif_path}")
    except Exception:
        from PIL import Image
        imgs = [Image.open(f).convert('RGBA') for f in frames]
        imgs[0].save(str(gif_path), save_all=True, append_images=imgs[1:],
                     duration=250, loop=0, optimize=False)
        print(f"GIF (PIL): {gif_path}")

print("Done!")
