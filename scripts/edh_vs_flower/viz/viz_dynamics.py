#!/usr/bin/env python3
"""Consolidated single-run dynamics visualiser for the EdH/Flower RTP.

ONE script subsuming the ~20 legacy per-view plot scripts. Reads a bridge
cache (extract_observables.py output) and renders any of:

  --view slices   2-D xy/xz panels: component density, m=−6 phase, spin field
  --view spin3d   3-D ⟨F̂⟩ spin texture, HSV-direction-coloured quiver
                  (Sadler 2006 / Kawaguchi-Ueda 2012 convention; arrow
                  length ∝ polarisation p=|F|/(F·n))
  --view phase3d  3-D total-density shell + m=−6 phase-coloured shell
  --view tilted   tilted-imaging m=−6 column density at ±θ (experimental view)
  --view all      render every view

Output: a single-frame PNG (--frame N, default last) or an animation
(--anim out.mp4 / out.gif) via _anim_writer (smooth FPS decoupled from pace).

Usage:
  python viz_dynamics.py <cache.h5> --view spin3d --anim spin3d.mp4
  python viz_dynamics.py <cache.h5> --view slices --frame -1 --out slices.png
"""
import os, sys, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors as mcolors
import viz_io
from _anim_writer import save_via_png_dup

M_OFFSET = {-6: 0, -5: 1, -4: 2}        # index from the end (m=−6 is last comp)


def _mcol(D, m):
    return D - 1 + m + 6 if m <= 0 else None  # m=−6→D-1, −5→D-2, −4→D-3 (D=13)


# ───────────────────────── view: 2-D slices ──────────────────────────────
def draw_slices(fig, C, k, meta):
    fig.clf()
    D = int(meta["F"]) * 2 + 1
    m6 = D - 1
    axes = fig.subplots(3, 4)
    n_xy = C["n_m_xy"][k]; n_xz = C["n_m_xz"][k]
    panels = [
        (axes[0, 0], n_xy[m6], "n(m=−6) xy", "inferno", None),
        (axes[0, 1], C["arg_psi_m6_xy"][k], "arg ψ(m=−6) xy", "hsv", (-np.pi, np.pi)),
        (axes[0, 2], C["Fz_xy"][k], "F_z xy", "RdBu_r", "sym"),
        (axes[0, 3], np.hypot(C["Fx_xy"][k], C["Fy_xy"][k]), "|F_⊥| xy", "viridis", None),
        (axes[1, 0], n_xz[m6], "n(m=−6) xz", "inferno", None),
        (axes[1, 1], C["arg_psi_m6_xz"][k], "arg ψ(m=−6) xz", "hsv", (-np.pi, np.pi)),
        (axes[1, 2], C["Fz_xz"][k], "F_z xz", "RdBu_r", "sym"),
        (axes[1, 3], np.hypot(C["Fx_xz"][k], C["Fy_xz"][k]), "|F_⊥| xz", "viridis", None),
    ]
    for ax, M, title, cmap, rng in panels:
        if rng == "sym":
            v = np.max(np.abs(M)) or 1.0; kw = dict(vmin=-v, vmax=v)
        elif rng:
            kw = dict(vmin=rng[0], vmax=rng[1])
        else:
            kw = {}
        im = ax.imshow(M.T, origin="lower", cmap=cmap, **kw)
        ax.set_title(title, fontsize=8); ax.set_xticks([]); ax.set_yticks([])
        fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    # bottom row: scalar traces
    tms = viz_io.time_ms(C)[:len(C.get("E", []))] if "E" in C else None
    for ax in axes[2]:
        ax.remove()
    axs = fig.add_subplot(3, 1, 3)
    if "E" in C:
        axs.plot(tms, C["E"], "C0-", label="E")
        axs.axvline(tms[min(k, len(tms) - 1)], color="r", lw=1)
    axs.set_xlabel("t [ms]"); axs.set_ylabel("E"); axs.legend(fontsize=8); axs.grid(alpha=0.3)
    fig.suptitle(f"slices — frame {k+1}", fontsize=12)
    fig.tight_layout(rect=[0, 0, 1, 0.97])


# ──────────────────────── view: 3-D spin texture ─────────────────────────
def draw_spin3d(fig, C, k, meta, arrow_step=1, dens_rel=0.10, length_scale=1.8):
    fig.clf()
    F = float(meta["F"]); L = float(meta["L_box"])
    nk = C["n_total_3d"][k]; fx = C["Fx_3d"][k]; fy = C["Fy_3d"][k]; fz = C["Fz_3d"][k]
    nv = nk.shape[0]
    xs = np.linspace(-L / 2, L / 2, nv)
    X, Y, Z = np.meshgrid(xs, xs, xs, indexing="ij")
    samp = np.zeros_like(nk, bool); samp[::arrow_step, ::arrow_step, ::arrow_step] = True
    peak = max(float(nk.max()), 1e-15)
    mask = samp & (nk >= dens_rel * peak)
    fxm, fym, fzm, nm = fx[mask], fy[mask], fz[mask], nk[mask]
    fmag = np.sqrt(fxm**2 + fym**2 + fzm**2) + 1e-30
    pol = np.clip(fmag / (F * np.maximum(nm, 1e-12)), 0.0, 1.0)
    rgba = viz_io.direction_to_hsv_rgba(fxm, fym, fzm, pol)
    u, v, w = fxm / fmag, fym / fmag, fzm / fmag
    xq, yq, zq = X[mask], Y[mask], Z[mask]
    ax = fig.add_axes([0.02, 0.04, 0.72, 0.92], projection="3d")
    base = (xs[1] - xs[0]) * arrow_step * length_scale
    for i in range(len(xq)):
        Lr = base * pol[i]
        if Lr < 1e-6:
            continue
        ax.quiver([xq[i]], [yq[i]], [zq[i]], [u[i] * Lr], [v[i] * Lr], [w[i] * Lr],
                  color=tuple(rgba[i]), linewidth=0.9, arrow_length_ratio=0.30, normalize=False)
    shell = samp & (nk >= dens_rel * peak) & (~mask)
    if shell.any():
        ax.scatter(X[shell], Y[shell], Z[shell], color="#b0b0b0", s=2, alpha=0.10)
    ax.set_xlim(xs[0], xs[-1]); ax.set_ylim(xs[0], xs[-1]); ax.set_zlim(xs[0], xs[-1])
    ax.set_xlabel("x [μm]"); ax.set_ylabel("y [μm]"); ax.set_zlabel("z [μm]")
    ax.set_title(r"$\langle F(r)\rangle$ spin texture  (arrow length $\propto p=|F|/(Fn)$)"
                 + f"\nframe {k+1},  arrows {int(mask.sum())},  p_med={np.median(pol) if len(pol) else 0:.3f}",
                 fontsize=11)
    # HSV legend (φ × θ rectangle)
    axL = fig.add_axes([0.78, 0.12, 0.20, 0.22])
    th = np.linspace(0, np.pi, 80); ph = np.linspace(-np.pi, np.pi, 160)
    PH, TH = np.meshgrid(ph, th)
    rgbl = viz_io.direction_to_hsv_rgba(np.sin(TH) * np.cos(PH), np.sin(TH) * np.sin(PH),
                                        np.cos(TH), np.ones_like(TH))[..., :3]
    axL.imshow(rgbl, origin="lower", extent=[-180, 180, 180, 0], aspect="auto")
    axL.set_xlabel(r"$\phi_F$", fontsize=8); axL.set_ylabel(r"$\theta_F$", fontsize=8)
    axL.set_title("spin colour", fontsize=8); axL.tick_params(labelsize=7)


# ────────────────────── view: 3-D density + phase shells ──────────────────
def draw_phase3d(fig, C, k, meta, iso_total=0.10, iso_m6=0.12):
    fig.clf()
    L = float(meta["L_box"])
    nt = C["n_total_3d"][k]; nm6 = C["n_m6_3d"][k]; ar = C["arg_psi_m6_3d"][k]
    nv = nt.shape[0]; xs = np.linspace(-L / 2, L / 2, nv)
    X, Y, Z = np.meshgrid(xs, xs, xs, indexing="ij")
    ax = fig.add_axes([0.02, 0.04, 0.94, 0.92], projection="3d")
    pt = max(float(nt.max()), 1e-15); pm = max(float(nm6.max()), 1e-15)
    sh_t = nt >= iso_total * pt
    ax.scatter(X[sh_t], Y[sh_t], Z[sh_t], color="#cccccc", s=3, alpha=0.06)
    sh_m = nm6 >= iso_m6 * pm
    if sh_m.any():
        cols = mcolors.hsv_to_rgb(np.stack([(ar[sh_m] + np.pi) / (2 * np.pi),
                                            np.ones(sh_m.sum()), np.ones(sh_m.sum())], -1))
        ax.scatter(X[sh_m], Y[sh_m], Z[sh_m], c=cols, s=6, alpha=0.5)
    ax.set_xlim(xs[0], xs[-1]); ax.set_ylim(xs[0], xs[-1]); ax.set_zlim(xs[0], xs[-1])
    ax.set_title(f"total density shell + m=−6 phase shell — frame {k+1}", fontsize=11)


# ───────────────────────── view: tilted imaging ──────────────────────────
def draw_tilted(fig, C, k, meta):
    fig.clf()
    tilt = list(np.atleast_1d(meta["theta_q_deg"]))
    nt = len(tilt); col = C["n_m6_tilted"][k]   # (nt, nz, nx)
    axes = fig.subplots(1, nt)
    if nt == 1:
        axes = [axes]
    for i, (ax, th) in enumerate(zip(axes, tilt)):
        im = ax.imshow(col[i], origin="lower", cmap="inferno", aspect="auto")
        ax.set_title(f"θ = {float(th):+.0f}°", fontsize=10); ax.set_xticks([]); ax.set_yticks([])
        fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    fig.suptitle(f"tilted m=−6 column density — frame {k+1}", fontsize=12)
    fig.tight_layout(rect=[0, 0, 1, 0.95])


VIEWS = {"slices": (draw_slices, (15, 9)), "spin3d": (draw_spin3d, (15, 9)),
         "phase3d": (draw_phase3d, (10, 9)), "tilted": (draw_tilted, (14, 5))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cache")
    ap.add_argument("--view", default="spin3d", choices=list(VIEWS) + ["all"])
    ap.add_argument("--frame", type=int, default=-1, help="snapshot frame (default last)")
    ap.add_argument("--anim", default="", help="output mp4/gif (animation over all frames)")
    ap.add_argument("--out", default="", help="output png (single frame)")
    ap.add_argument("--fps", type=int, default=int(os.environ.get("FPE_FPS", "30")))
    ap.add_argument("--duration", type=float, default=float(os.environ.get("FPE_DURATION_S", "12")))
    ap.add_argument("--stride", type=int, default=1)
    a = ap.parse_args()

    C = viz_io.load_cache(a.cache)
    meta = C["meta"]
    nf = C["n_total_3d"].shape[0]
    views = list(VIEWS) if a.view == "all" else [a.view]

    for view in views:
        drawfn, figsize = VIEWS[view]
        fig = plt.figure(figsize=figsize)
        if a.anim:
            out = a.anim if a.view != "all" else a.anim.replace(".", f"_{view}.", 1)
            idx = viz_io.frame_indices(nf, a.stride)
            print(f"[{view}] {len(idx)} frames → {out}")
            save_via_png_dup(fig, lambda i, dfn=drawfn, ix=idx: dfn(fig, C, ix[i], meta),
                             len(idx), out, fps=a.fps, duration_s=a.duration)
        else:
            k = a.frame % nf
            drawfn(fig, C, k, meta)
            out = a.out or f"{view}_frame{k}.png"
            if a.view == "all":
                out = (a.out or "dynamics.png").replace(".", f"_{view}.", 1)
            fig.savefig(out, dpi=150, bbox_inches="tight")
            print(f"[{view}] frame {k} → {out}")
        plt.close(fig)


if __name__ == "__main__":
    main()
