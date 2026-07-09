#!/usr/bin/env python3
"""v7_EdH_Fable stage 4 — quantitative visualization suite (Fable finalize).

Spin-texture rendering (adopts the canonical paper-grade HSV encoding from
scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py, Sadler2006 /
Kawaguchi-Ueda2012 conventions):
  background colour = FULL 3-D spin direction of <F>(r)/atom
      hue  = azimuth phi_F = atan2(<Fy>,<Fx>)   (transverse winding = colour wheel)
      val  = 1 - 0.4 cos(theta_F)                (+z bright, -z dim)
      sat  = sin(theta_F)                        (in-plane content)
      alpha= density envelope (atoms present)    -> outside cloud fades out
  arrows = IN-PLANE spin projection, PHYSICAL length ∝ |s_inplane| per atom
      NO unit normalization (user rule 2026-07-02); |s|<DOT tiny -> drawn as dot.
      |s|=6 (maximal) spans ~2 arrow-grid cells.

Grid rule: compute == analysis == display (no floor, no mask on scalar maps;
the texture alpha is a visual density envelope only). Physical axes (l0, ms).

Figures (per selected frame N, + globals):
  v7_geometry.png             lab geometry (LOS=y, SG=z, spin-space tilt)
  v7_raw_montage_f{N}.png     the raw datum: protocol settings x visible m
  v7_column_texture_f{N}.png  MEASURED (x,z) plane: truth vs recon spin texture
  v7_crosssection_f{N}.png    z-slice (x,y) cross-sections: truth vs recon 3D
  v7_3d_recon_f{N}.png        3D estimate vs truth slices + y-mode budget table
  v7_epochs_summary.png       time-evolution story (HSV textures)
  v7_metrics.csv/.json        all numbers
env: RAW, RECON, TRUTH, OUTDIR
"""
import os, sys, json, csv
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import ms, VISIBLE_MS, metrics, env, F as FVAL

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors as mcolors
from matplotlib.gridspec import GridSpec

RAW = env("RAW", "sg_raw_v7.h5")
RECON = env("RECON", "recon_v7.h5")
TRUTH = env("TRUTH", "truth_v7.h5")
OUTDIR = env("OUTDIR", ".")
os.makedirs(OUTDIR, exist_ok=True)

Rw = h5py.File(RAW, "r"); Rc = h5py.File(RECON, "r"); Tr = h5py.File(TRUTH, "r")
FRAMES = list(np.asarray(Rw["frames_selected"]))
Ng = int(Rw["meta/Ng"][()]); L = float(Rw["meta/L_box"][()])
dx = float(Rw["meta/dx"][()])
EXT = [-L / 2, L / 2, -L / 2, L / 2]
ax1d = np.linspace(-L / 2, L / 2, Ng, endpoint=False)
t_ms_all = np.asarray(Rw["trace/t_ms"])
sperp_all = (np.asarray(Rw["trace/sperp_loc"]) if "sperp_loc" in Rw["trace"]
             else np.asarray(Rw["trace/sperp"]))
ARROW_STRIDE = max(1, Ng // 12)      # ~12 arrows per side (readable, not dense)
DOT = 0.18                           # |s_inplane| below this -> dot, not arrow
ALL_METRICS = []

# ----------------------------------------------------------------- primitives
def per_atom(f, n):
    return np.divide(f, n, out=np.zeros_like(f), where=n > 0)

def hsv_rgba(sx, sy, sz, dens, F=FVAL):
    """Full 3-D spin direction -> RGBA (canonical). alpha = density envelope."""
    mag = np.sqrt(sx * sx + sy * sy + sz * sz) + 1e-30
    cos_t = np.clip(sz / mag, -1.0, 1.0)
    sin_t = np.sqrt(np.maximum(0.0, 1.0 - cos_t * cos_t))
    hue = (np.arctan2(sy, sx) + np.pi) / (2.0 * np.pi)
    val = np.clip(1.0 - 0.4 * cos_t, 0.4, 1.0)
    rgb = mcolors.hsv_to_rgb(np.stack([hue, np.clip(sin_t, 0, 1), val], axis=-1))
    dn = dens / (dens.max() + 1e-30)
    alpha = np.clip(dn ** 0.55, 0.0, 1.0)
    return np.concatenate([rgb, alpha[..., None]], axis=-1)

def spin_panel(ax, s_h, s_v, sx, sy, sz, dens, title, hlab, vlab):
    """HSV background (full 3-D direction) + physical in-plane arrows.
    s_h,s_v: in-plane per-atom components on the (H,V) grid. sx,sy,sz: full
    per-atom vector for colour. dens: 2-D density for the alpha envelope."""
    rgba = hsv_rgba(sx, sy, sz, dens)                       # (H,V,4)
    ax.imshow(np.transpose(rgba, (1, 0, 2)), origin="lower", extent=EXT,
              aspect="equal", interpolation="nearest")
    st = ARROW_STRIDE
    XX, YY = np.meshgrid(ax1d, ax1d, indexing="ij")
    sub = (slice(None, None, st), slice(None, None, st))
    X, Y, U, V = XX[sub], YY[sub], s_h[sub], s_v[sub]
    dmask = dens[sub] > 0.05 * dens.max()
    mag = np.hypot(U, V)
    arr = dmask & (mag >= DOT); dot = dmask & (mag < DOT)
    scale = FVAL / (2 * st * dx)
    ax.quiver(X[arr], Y[arr], U[arr], V[arr], color="k", alpha=0.9,
              angles="xy", scale_units="xy", scale=scale,
              width=0.006, headwidth=3.6, headlength=4, pivot="mid")
    ax.plot(X[dot], Y[dot], ".", ms=1.6, color="k", alpha=0.5)
    ax.set_title(title, fontsize=9)
    ax.set_xlabel(hlab, fontsize=8); ax.set_ylabel(vlab, fontsize=8)
    ax.tick_params(labelsize=7)

def imshow_xz(ax, img, **kw):
    return ax.imshow(img.T, origin="lower", extent=EXT, aspect="equal", **kw)

def color_wheel(ax):
    n = 100
    th = np.linspace(0, np.pi, n); ph = np.linspace(-np.pi, np.pi, 2 * n)
    PH, TH = np.meshgrid(ph, th)
    rgba = hsv_rgba(np.sin(TH) * np.cos(PH), np.sin(TH) * np.sin(PH),
                    np.cos(TH), np.ones_like(TH))
    ax.imshow(rgba[..., :3], origin="lower", extent=[-180, 180, 180, 0], aspect="auto")
    ax.set_xticks([-180, 0, 180]); ax.set_yticks([0, 90, 180])
    ax.set_xlabel(r"$\phi_F$ [deg] (hue)", fontsize=7)
    ax.set_ylabel(r"$\theta_F$ [deg]", fontsize=7)
    ax.set_title("spin direction\ncolour key", fontsize=8)
    ax.tick_params(labelsize=6)
    ax.text(0, 30, "+z", ha="center", fontsize=7, color="0.2")
    ax.text(0, 165, "$-$z", ha="center", fontsize=7, color="w")

def metrics_table(ax, header, rows):
    ax.axis("off")
    tab = ax.table(cellText=rows, colLabels=header, loc="center", cellLoc="center")
    tab.auto_set_font_size(False); tab.set_fontsize(7.5); tab.scale(1, 1.3)
    for (r, c), cell in tab.get_celld().items():
        cell.set_edgecolor("0.8")
        if r == 0:
            cell.set_facecolor("0.92"); cell.set_text_props(weight="bold")

# ================================================================ geometry fig
def fig_geometry():
    fig = plt.figure(figsize=(9, 6.5))
    ax = fig.add_subplot(111, projection="3d")
    u, v = np.mgrid[0:2 * np.pi:40j, 0:np.pi:20j]
    for r, al in ((1.0, 0.22), (0.6, 0.32)):
        ax.plot_surface(r * np.cos(u) * np.sin(v), r * np.sin(u) * np.sin(v),
                        0.8 * r * np.cos(v), color="steelblue", alpha=al, linewidth=0)
    ar = dict(arrow_length_ratio=0.12, linewidth=2.5)
    ax.quiver(0, -3.4, 0, 0, 2.0, 0, color="crimson", **ar)
    ax.text(0, -3.6, 0.3, "camera line of sight $\\hat y$\n(absorption image, $\\int dy$)",
            color="crimson", fontsize=9, ha="center")
    ax.quiver(0, 0, 1.4, 0, 0, 1.2, color="darkgreen", **ar)
    ax.text(0.1, 0, 2.9, "SG gradient $\\hat z$\n($m$ separates along $z$)",
            color="darkgreen", fontsize=9)
    xx, zz = np.meshgrid([-2, 2], [-2, 2])
    ax.plot_surface(xx, np.full_like(xx, 3.0), zz, alpha=0.13, color="gray")
    ax.text(0, 3.05, 2.2, "image plane $(x,z)$", fontsize=9, ha="center")
    ax.quiver(-2.6, 0, 0, 1.2, 0, 0, color="darkorange", **ar)
    ax.quiver(0, -0.2, -2.8, 0, 1.2, 0, color="purple", **ar)
    ax.text(-2.9, 0, -0.7, "tilt $\\hat x\\to\\langle F_y\\rangle$", color="darkorange", fontsize=8.5)
    ax.text(0.1, 0.9, -2.9, "tilt $\\hat y\\to\\langle F_x\\rangle$", color="purple", fontsize=8.5)
    ax.set_title("v7 geometry — quantization-axis tilt is a SPIN-space rotation;\n"
                 "the spatial line of sight $\\hat y$ never moves (no new info along $y$)",
                 fontsize=10.5)
    ax.set_xlim(-3, 3); ax.set_ylim(-3.6, 3.4); ax.set_zlim(-3, 3)
    ax.set_xlabel("x"); ax.set_ylabel("y"); ax.set_zlabel("z")
    ax.view_init(elev=18, azim=-55)
    fig.tight_layout()
    fig.savefig(os.path.join(OUTDIR, "v7_geometry.png"), dpi=150)
    plt.close(fig)

# ============================================================== raw montage fig
def protocol_settings():
    nm = [s.decode() for s in np.asarray(Rw["settings/name"])]
    axx = [s.decode() for s in np.asarray(Rw["settings/axis"])]
    ang = np.asarray(Rw["settings/angle_deg"])
    pp = [s.decode() for s in np.asarray(Rw["settings/purpose"])]
    return [(n, a, b) for n, a, b, p in zip(nm, axx, ang, pp) if p == "protocol"]

def fig_raw_montage(fr):
    g = Rw[f"frames/f{fr:04d}"]; t = float(g["t_ms"][()])
    proto = protocol_settings()
    names = [n for n, _, _ in proto]
    labels = ["no tilt" if a == "id" else f"$R_{a}({b:+.3g}^\\circ)$" for _, a, b in proto]
    nch = len(VISIBLE_MS)
    vmax = max(np.asarray(g[f"visible/{n}"]).max() for n in names)
    Ntot = np.asarray(g["sim_only_all13/id"]).sum() * dx * dx
    fig, axs = plt.subplots(len(names), nch + 1,
                            figsize=(2.1 * (nch + 1), 2.05 * len(names)),
                            constrained_layout=True)
    for i, (n, lab) in enumerate(zip(names, labels)):
        img = np.asarray(g[f"visible/{n}"])
        for j in range(nch):
            a = axs[i, j]
            im = imshow_xz(a, img[..., j], cmap="inferno", vmin=0, vmax=vmax)
            a.text(0.03, 0.97, f"{100 * img[..., j].sum() * dx * dx / Ntot:.1f}%",
                   transform=a.transAxes, color="w", fontsize=8, va="top")
            if i == 0: a.set_title(f"$m={VISIBLE_MS[j]}$", fontsize=10)
            if j == 0: a.set_ylabel(lab + "\nz [$\\ell_0$]", fontsize=8)
            a.tick_params(labelsize=6)
        a = axs[i, nch]; tot = img.sum(axis=-1)
        imshow_xz(a, tot, cmap="inferno", vmin=0, vmax=vmax)
        a.text(0.03, 0.97, f"{100 * tot.sum() * dx * dx / Ntot:.1f}%",
               transform=a.transAxes, color="w", fontsize=8, va="top")
        if i == 0: a.set_title("visible total", fontsize=9)
        a.tick_params(labelsize=6)
    fig.colorbar(im, ax=axs[:, -1], shrink=0.6, label="column density $N_m(x,z)$")
    fig.suptitle(f"THE RAW DATUM — tilted-SG absorption images, visible block $m=-6..-3$\n"
                 f"EdH t={t:.1f} ms, LOS=$\\hat y$, image = compute grid {Ng}$\\times${Ng}"
                 f"  (%% = channel fraction of ALL atoms)", fontsize=11)
    fig.savefig(os.path.join(OUTDIR, f"v7_raw_montage_f{fr:04d}.png"), dpi=140)
    plt.close(fig)

# ===================================================== column texture (measured)
def fig_column_texture(fr):
    tg = Tr[f"frames/f{fr:04d}"]; og = Rc[f"frames/f{fr:04d}"]
    t = float(tg["t_ms"][()])
    Ntru = np.asarray(tg["Ncol"])
    tru = {c: per_atom(np.asarray(tg[f"F{c}_col"]), Ntru) for c in "xyz"}
    truF = {c: np.asarray(tg[f"F{c}_col"]) for c in "xyz"}
    Nr = np.asarray(og["col/Ncol_vis"])
    recF = {c: np.asarray(og[f"col/f{c}_protocol_vis"]) for c in "xyz"}
    rec = {c: per_atom(recF[c], Nr) for c in "xyz"}
    mets = {c: metrics(recF[c], truF[c]) for c in "xyz"}
    m13 = {c: metrics(np.asarray(og[f"col/f{c}_protocol_all13"]), truF[c]) for c in "xyz"}
    for c in "xyz":
        ALL_METRICS.append(dict(frame=int(fr), t_ms=t, field=f"col_f{c}",
                                method="protocol_vis", **mets[c]))
        ALL_METRICS.append(dict(frame=int(fr), t_ms=t, field=f"col_f{c}",
                                method="protocol_all13", **m13[c]))
    polT = np.sqrt(sum(tru[c] ** 2 for c in "xyz")) / FVAL
    polR = np.sqrt(sum(rec[c] ** 2 for c in "xyz")) / FVAL

    fig = plt.figure(figsize=(14.5, 8.4))
    gs = GridSpec(2, 4, figure=fig, width_ratios=[1.15, 1, 1, 0.85],
                  hspace=0.28, wspace=0.32, left=0.05, right=0.97, top=0.9, bottom=0.08)
    for i, (lab, s, pol) in enumerate(
            [("TRUTH  (column-avg of full $\\psi$)", tru, polT),
             ("RECON  ($\\pm16^\\circ$ 5-setting, visible block $m{=}{-}6..{-}3$)", rec, polR)]):
        spin_panel(fig.add_subplot(gs[i, 0]), s["x"], s["z"], s["x"], s["y"], s["z"],
                   Ntru if i == 0 else Nr, lab, "x [$\\ell_0$]", "z [$\\ell_0$]")
        az = fig.add_subplot(gs[i, 1])
        imz = imshow_xz(az, s["y"], cmap="RdBu_r", vmin=-6, vmax=6)
        az.set_title("$\\langle F_y\\rangle$/atom (out-of-plane)", fontsize=9)
        az.tick_params(labelsize=7); fig.colorbar(imz, ax=az, shrink=0.82)
        ap = fig.add_subplot(gs[i, 2])
        imp = imshow_xz(ap, pol, cmap="viridis", vmin=0, vmax=1)
        ap.set_title("polarisation $|\\langle\\mathbf{F}\\rangle|/(F)$", fontsize=9)
        ap.tick_params(labelsize=7); fig.colorbar(imp, ax=ap, shrink=0.82)
    color_wheel(fig.add_subplot(gs[0, 3]))
    header = ["", "$F_x$", "$F_y$", "$F_z$"]
    trows = [["r (vis)"] + [f"{mets[c]['corr']:.3f}" for c in "xyz"],
             ["relL2 vis"] + [f"{mets[c]['rel_l2']:.3f}" for c in "xyz"],
             ["r (all13)"] + [f"{m13[c]['corr']:.3f}" for c in "xyz"]]
    metrics_table(fig.add_subplot(gs[1, 3]), header, trows)
    fig.suptitle(f"Column-integrated spin texture $\\langle\\mathbf{{F}}\\rangle(x,z)$: "
                 f"truth vs pixel-only reconstruction — EdH t={t:.1f} ms\n"
                 f"arrows: in-plane $(F_x,F_z)$ physical length; colour: full 3-D "
                 f"direction (wheel); this is the directly MEASURED plane",
                 fontsize=11.5)
    fig.savefig(os.path.join(OUTDIR, f"v7_column_texture_f{fr:04d}.png"), dpi=135)
    plt.close(fig)

# ================================================== z-slice cross sections (NEW)
def pick_zslices(n3d, k=5):
    prof = n3d.sum(axis=(0, 1))
    thr = 0.15 * prof.max()
    idx = np.where(prof > thr)[0]
    lo, hi = (idx[0], idx[-1]) if len(idx) else (0, Ng - 1)
    return [int(round(v)) for v in np.linspace(lo, hi, k)]

def fig_crosssection(fr):
    tg = Tr[f"frames/f{fr:04d}"]; og = Rc[f"frames/f{fr:04d}"]
    t = float(tg["t_ms"][()])
    n3 = np.asarray(tg["n_3d"])
    truF = {c: np.asarray(tg[f"f{c}_3d"]) for c in "xyz"}
    recF = {c: np.asarray(og[f"rec3d/f{c}_ansatz_vis"]) for c in "xyz"}
    zsl = pick_zslices(n3)
    k = len(zsl)
    fig = plt.figure(figsize=(2.7 * k + 1.4, 6.6))
    gs = GridSpec(2, k + 1, figure=fig, width_ratios=[1] * k + [0.5],
                  hspace=0.26, wspace=0.14, left=0.05, right=0.96, top=0.86, bottom=0.08)
    for zi, z0 in enumerate(zsl):
        nT = n3[:, :, z0]
        sT = {c: per_atom(truF[c][:, :, z0], nT) for c in "xyz"}
        # recon 3D estimate density envelope: use ansatz's own column->y spread of N
        nR = nT   # same cloud shape assumed; alpha only affects display
        sR = {c: per_atom(recF[c][:, :, z0], np.clip(nR, 1e-30, None)) for c in "xyz"}
        zval = ax1d[z0]
        spin_panel(fig.add_subplot(gs[0, zi]), sT["x"], sT["y"], sT["x"], sT["y"],
                   sT["z"], nT, f"z={zval:+.1f} $\\ell_0$", "x [$\\ell_0$]",
                   "y [$\\ell_0$]" if zi == 0 else "")
        spin_panel(fig.add_subplot(gs[1, zi]), sR["x"], sR["y"], sR["x"], sR["y"],
                   sR["z"], nR, "", "x [$\\ell_0$]", "y [$\\ell_0$]" if zi == 0 else "")
    fig.text(0.012, 0.66, "TRUTH\n(x,y) slice", fontsize=10, weight="bold", rotation=90, va="center")
    fig.text(0.012, 0.30, "RECON\nansatz 3-D", fontsize=10, weight="bold", rotation=90, va="center")
    color_wheel(fig.add_subplot(gs[:, k]))
    fig.suptitle(f"Spin-texture CROSS-SECTIONS (z-slices, in-plane $(F_x,F_y)$) — EdH t={t:.1f} ms\n"
                 f"top: true 3-D texture (azimuthal winding = hue cycle).  bottom: the "
                 f"single-LOS ansatz estimate.  Where they differ = the $y$ (line-of-sight) "
                 f"structure column imaging cannot see.", fontsize=10.5)
    fig.savefig(os.path.join(OUTDIR, f"v7_crosssection_f{fr:04d}.png"), dpi=135)
    plt.close(fig)

# ============================================================ 3D estimation fig
def fig_3d_recon(fr):
    tg = Tr[f"frames/f{fr:04d}"]; og = Rc[f"frames/f{fr:04d}"]
    t = float(tg["t_ms"][()]); yc = Ng // 2
    tru3 = {c: np.asarray(tg[f"f{c}_3d"]) for c in "xyz"}
    fig = plt.figure(figsize=(13.5, 11.2))
    gs = GridSpec(4, 4, figure=fig, height_ratios=[1, 1, 1, 0.5],
                  hspace=0.42, wspace=0.28, left=0.06, right=0.96, top=0.93, bottom=0.04)
    scale = np.abs(tru3["z"]).max() + 1e-30
    budget = []
    for i, c in enumerate("xyz"):
        tru = tru3[c]
        uni = np.asarray(og[f"rec3d/f{c}_uniform_vis"])
        ans = np.asarray(og[f"rec3d/f{c}_ansatz_vis"])
        m_uni = metrics(uni, tru); m_ans = metrics(ans, tru)
        Fk = np.fft.fft(tru, axis=1) / Ng
        p_tot = float(np.sum(np.abs(Fk) ** 2)); p_k0 = float(np.sum(np.abs(Fk[:, 0, :]) ** 2))
        floor = np.sqrt(max(0.0, 1 - p_k0 / max(p_tot, 1e-300)))
        budget.append([f"$F_{c}$", f"{100 * p_k0 / max(p_tot, 1e-300):.1f}%",
                       f"{floor:.3f}", f"{m_uni['rel_l2']:.3f}", f"{m_ans['rel_l2']:.3f}",
                       f"{m_ans['corr']:.3f}"])
        for m, lbl in ((m_uni, "uniform"), (m_ans, "ansatz")):
            ALL_METRICS.append(dict(frame=int(fr), t_ms=t, field=f"3d_f{c}", method=lbl, **m))
        vm = np.abs(tru[:, yc, :]).max() + 1e-30
        for j, (img, ttl, div) in enumerate([
                (tru[:, yc, :], f"truth $f_{c}$ ($y{{=}}0$)", True),
                (uni[:, yc, :], f"uniform  relL2={m_uni['rel_l2']:.2f}", True),
                (ans[:, yc, :], f"ansatz  relL2={m_ans['rel_l2']:.2f}", True),
                (np.abs(ans - tru)[:, yc, :] / scale, "|ansatz$-$truth|/max", False)]):
            a = fig.add_subplot(gs[i, j])
            im = (imshow_xz(a, img, cmap="RdBu_r", vmin=-vm, vmax=vm) if div
                  else imshow_xz(a, img, cmap="magma", vmin=0))
            a.set_title(ttl, fontsize=8.5); a.tick_params(labelsize=6.5)
            fig.colorbar(im, ax=a, shrink=0.8)
    axt = fig.add_subplot(gs[3, :])
    metrics_table(axt, ["", "$k_y{=}0$ content", "unrecoverable\nfloor (relL2)",
                        "uniform relL2", "ansatz relL2", "ansatz r"], budget)
    axt.set_title("y-mode budget: $k_y{=}0$ content is the ONLY part a single-LOS tilt scan "
                  "determines; the rest is null-space (prior-only). floor = irreducible relL2.",
                  fontsize=9)
    fig.suptitle(f"3-D estimation from single line-of-sight pixel data — EdH t={t:.1f} ms  "
                 f"(y=0 slices; recon = visible-block protocol)", fontsize=12)
    fig.savefig(os.path.join(OUTDIR, f"v7_3d_recon_f{fr:04d}.png"), dpi=130)
    plt.close(fig)

# ============================================================== epochs summary
def fig_epochs():
    nfrm = len(FRAMES)
    fig = plt.figure(figsize=(3.1 * nfrm, 10.8))
    gs = GridSpec(4, nfrm, figure=fig, height_ratios=[0.65, 1, 1, 1],
                  hspace=0.34, wspace=0.2, left=0.05, right=0.97, top=0.93, bottom=0.05)
    axt = fig.add_subplot(gs[0, :])
    axt.plot(t_ms_all, sperp_all, "-", color="crimson", lw=1.5)
    axt.set_ylabel(r"$\int|f_\perp|dV/N$", fontsize=9); axt.set_xlabel("t [ms]", fontsize=9)
    axt.grid(alpha=0.3)
    for fr in FRAMES:
        axt.axvline(t_ms_all[fr], color="0.5", ls="--", lw=0.8)
        axt.annotate(f"{t_ms_all[fr]:.0f}", (t_ms_all[fr], sperp_all[fr]),
                     fontsize=7, ha="center", va="bottom")
    axt.set_title("EdH transverse-spin transient (winding-proof measure) and the imaged epochs",
                  fontsize=10)
    for j, fr in enumerate(FRAMES):
        g = Rw[f"frames/f{fr:04d}"]; tg = Tr[f"frames/f{fr:04d}"]; og = Rc[f"frames/f{fr:04d}"]
        t = float(g["t_ms"][()])
        a = fig.add_subplot(gs[1, j])
        imshow_xz(a, np.asarray(g["visible/id"])[..., 0], cmap="inferno", vmin=0)
        a.set_title(f"raw $N_{{m=-6}}$   t={t:.1f} ms", fontsize=9); a.tick_params(labelsize=6)
        if j == 0: a.set_ylabel("z [$\\ell_0$]", fontsize=8)
        NT = np.asarray(tg["Ncol"]); NR = np.asarray(og["col/Ncol_vis"])
        sT = {c: per_atom(np.asarray(tg[f"F{c}_col"]), NT) for c in "xyz"}
        sR = {c: per_atom(np.asarray(og[f"col/f{c}_protocol_vis"]), NR) for c in "xyz"}
        spin_panel(fig.add_subplot(gs[2, j]), sT["x"], sT["z"], sT["x"], sT["y"], sT["z"],
                   NT, "truth texture" if j == 0 else "", "x [$\\ell_0$]",
                   "z [$\\ell_0$]" if j == 0 else "")
        spin_panel(fig.add_subplot(gs[3, j]), sR["x"], sR["z"], sR["x"], sR["y"], sR["z"],
                   NR, "recon (pixels, vis)" if j == 0 else "", "x [$\\ell_0$]",
                   "z [$\\ell_0$]" if j == 0 else "")
    fig.suptitle("v7 EdH — spin-texture dynamics reconstructed from synthetic experimental images  "
                 "(column $(x,z)$ plane; colour = 3-D spin direction)", fontsize=12.5)
    fig.savefig(os.path.join(OUTDIR, "v7_epochs_summary.png"), dpi=135)
    plt.close(fig)

# ================================================================== run all
fig_geometry()
for fr in FRAMES:
    fig_raw_montage(fr)
    fig_column_texture(fr)
    fig_crosssection(fr)
    fig_3d_recon(fr)
    print(f"[viz] frame f{fr:04d} figures done", flush=True)
fig_epochs()

with open(os.path.join(OUTDIR, "v7_metrics.json"), "w") as f:
    json.dump(ALL_METRICS, f, indent=1)
with open(os.path.join(OUTDIR, "v7_metrics.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(ALL_METRICS[0].keys()))
    w.writeheader(); w.writerows(ALL_METRICS)
print(f"[viz] wrote {len(ALL_METRICS)} metric rows and all figures to {OUTDIR}")
