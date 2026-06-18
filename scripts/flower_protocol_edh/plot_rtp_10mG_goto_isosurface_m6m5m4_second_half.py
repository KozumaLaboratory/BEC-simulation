#!/usr/bin/env python3
"""
RTP (Goto 10 mG protocol) — m = -6, -5, -4 3D isosurface time-lapse, second
half of the trajectory only.

Rationale: the first half (B from 10 mG ramping down) is dominated by the
m=-6 single-component ground state with little spinor dynamics; the
interesting Larmor + spin-rotation physics activates once |B| drops into
the spinor regime. So the figure crops to the latter half.

Threshold: per-component, per-frame iso = ISO_PEAK_RATIO * max(n_m(t)).
Defaults to 0.30. Component-local peaks are used because m=-5 / m=-4
densities are orders of magnitude smaller than m=-6 — a globally-shared
iso would render them as empty panels.

Env knobs:
  RTP_H5            input H5 (default = Tsubame canonical path)
  OUT_GIF           output GIF path
  ISO_PEAK_RATIO    iso fraction of per-component peak (default 0.30)
  FRAME_START_FRAC  first frame as fraction of total (default 0.5)
  FRAME_DURATION_MS GIF frame duration (default 120)
"""
import io
import os
from pathlib import Path

import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.gridspec import GridSpec
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from PIL import Image

H5_DEFAULT = "/gs/fs/tga-kozuma-kouhi/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto.h5"
H5 = Path(os.environ.get("RTP_H5", H5_DEFAULT))
OUT_GIF = Path(os.environ.get(
    "OUT_GIF",
    "runs/eu151_flower_protocol_edh/figures/goto_protocol_10mG/isosurface_peak30_m6m5m4_secondhalf.gif",
))
ISO_PEAK_RATIO = float(os.environ.get("ISO_PEAK_RATIO", "0.30"))
FRAME_START_FRAC = float(os.environ.get("FRAME_START_FRAC", "0.5"))
FRAME_DURATION_MS = int(os.environ.get("FRAME_DURATION_MS", "120"))

COMPONENTS = [
    (-6, "n_m6_3d", "arg_psi_m6_3d"),
    (-5, "n_m5_3d", "arg_psi_m5_3d"),
    (-4, "n_m4_3d", "arg_psi_m4_3d"),
]

TETS = [
    (0, 1, 3, 7), (0, 3, 2, 7), (0, 2, 6, 7),
    (0, 6, 4, 7), (0, 4, 5, 7), (0, 5, 1, 7),
]
TET_EDGES = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]


def load_dataset(path):
    with h5py.File(path, "r") as f:
        missing = [k for _, dk, pk in COMPONENTS for k in (dk, pk) if k not in f]
        if missing:
            raise RuntimeError(
                f"H5 missing {missing}; rerun goto_protocol_10mG.jl with "
                "STORED_3D_M=(-6,-5,-4)"
            )
        omega_ref = float(f["meta/omega_ref"][()])
        Lbox = float(f["meta/L_box"][()])
        NX = int(f["meta/NX"][()])
        vol_stride = int(f["meta/vol_stride"][()])
        t = f["t"][:]
        B = f["B_gauss"][:]
        loaded = {}
        for m, dk, pk in COMPONENTS:
            loaded[m] = (
                np.transpose(f[dk][:], (3, 2, 1, 0)),
                np.transpose(f[pk][:], (3, 2, 1, 0)),
            )
    return loaded, t, B, omega_ref, Lbox, NX, vol_stride


def interp_point(p0, p1, v0, v1, iso):
    if abs(v1 - v0) < 1e-15:
        return 0.5 * (p0 + p1), 0.5
    s = (iso - v0) / (v1 - v0)
    return p0 + s * (p1 - p0), s


def interp_phase(u0, u1, s):
    u = (1.0 - s) * u0 + s * u1
    return np.angle(u) if abs(u) > 1e-15 else np.angle(u0)


def sort_polygon(points, phases):
    pts = np.asarray(points, dtype=float)
    phs = np.asarray(phases, dtype=float)
    c = pts.mean(axis=0)
    n = None
    for i in range(len(pts) - 2):
        cr = np.cross(pts[i + 1] - pts[0], pts[i + 2] - pts[0])
        if np.linalg.norm(cr) > 1e-12:
            n = cr / np.linalg.norm(cr)
            break
    if n is None:
        return pts, phs
    ref = pts[0] - c
    ref = ref - np.dot(ref, n) * n
    if np.linalg.norm(ref) < 1e-12:
        ref = np.array([1.0, 0.0, 0.0])
        if abs(np.dot(ref, n)) > 0.9:
            ref = np.array([0.0, 1.0, 0.0])
        ref = ref - np.dot(ref, n) * n
    u = ref / np.linalg.norm(ref)
    v = np.cross(n, u)
    ang = np.arctan2((pts - c) @ v, (pts - c) @ u)
    order = np.argsort(ang)
    return pts[order], phs[order]


def marching_tetrahedra(density, phase, coords, iso):
    tris, tri_phase = [], []
    phase_u = np.exp(1j * phase)
    nx, ny, nz = density.shape
    cube_offsets = [(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0),
                    (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)]
    for i in range(nx - 1):
        for j in range(ny - 1):
            for k in range(nz - 1):
                cv = np.array([density[i + dx, j + dy, k + dz]
                               for dx, dy, dz in cube_offsets], dtype=float)
                if np.all(cv < iso) or np.all(cv >= iso):
                    continue
                cp = np.array([coords[i + dx, j + dy, k + dz]
                               for dx, dy, dz in cube_offsets], dtype=float)
                cu = np.array([phase_u[i + dx, j + dy, k + dz]
                               for dx, dy, dz in cube_offsets], dtype=complex)
                for tet in TETS:
                    p = cp[list(tet)]; v = cv[list(tet)]; u = cu[list(tet)]
                    inside = v >= iso
                    if np.all(inside) or not np.any(inside):
                        continue
                    pts, phs = [], []
                    for a, b in TET_EDGES:
                        if (v[a] >= iso) == (v[b] >= iso):
                            continue
                        pt, s = interp_point(p[a], p[b], v[a], v[b], iso)
                        pts.append(pt)
                        phs.append(interp_phase(u[a], u[b], s))
                    if len(pts) < 3:
                        continue
                    pts, phs = sort_polygon(pts, phs)
                    if len(pts) == 3:
                        tris.append(pts)
                        tri_phase.append(np.angle(np.mean(np.exp(1j * phs))))
                    else:
                        tris.append(np.array([pts[0], pts[1], pts[2]]))
                        tris.append(np.array([pts[0], pts[2], pts[3]]))
                        tri_phase.append(np.angle(np.mean(np.exp(1j * np.array([phs[0], phs[1], phs[2]])))))
                        tri_phase.append(np.angle(np.mean(np.exp(1j * np.array([phs[0], phs[2], phs[3]])))))
    return tris, np.asarray(tri_phase, dtype=float)


def build_coords(shape, Lbox, NX, vol_stride):
    dx = Lbox / NX * vol_stride
    xs = -Lbox / 2 + dx * np.arange(shape[0]) + dx / 2
    g0, g1, g2 = np.meshgrid(xs, xs, xs, indexing="ij")
    return np.stack([g0, g1, g2], axis=-1)


def render_frame(loaded, coords, Lbox, t_ms, B_uG, k):
    fig = plt.figure(figsize=(18, 6.5), facecolor="white")
    gs = GridSpec(1, 4, figure=fig, width_ratios=[1.0, 1.0, 1.0, 0.045],
                  left=0.03, right=0.96, bottom=0.12, top=0.86, wspace=0.10)
    axes = [fig.add_subplot(gs[0, i], projection="3d") for i in range(3)]
    cax = fig.add_subplot(gs[0, 3])
    cmap = plt.cm.hsv
    norm = plt.Normalize(vmin=-np.pi, vmax=np.pi)

    summary = []
    for ax, (m, _, _) in zip(axes, COMPONENTS):
        dens_k = loaded[m][0][k]
        phase_k = loaded[m][1][k]
        peak = float(dens_k.max())
        iso = ISO_PEAK_RATIO * peak
        tris, tri_phase = marching_tetrahedra(dens_k, phase_k, coords, iso)
        if tris:
            poly = Poly3DCollection(
                tris, facecolors=cmap(norm(tri_phase)),
                edgecolors="none", linewidths=0.0, alpha=0.95,
            )
            ax.add_collection3d(poly)
        else:
            ax.text2D(0.30, 0.5, "No surface", transform=ax.transAxes)
        ax.set_xlim(-Lbox / 2, Lbox / 2)
        ax.set_ylim(-Lbox / 2, Lbox / 2)
        ax.set_zlim(-Lbox / 2, Lbox / 2)
        ax.set_box_aspect((1, 1, 1))
        ax.view_init(elev=22, azim=232)
        ax.set_xlabel("x [μm]", labelpad=3)
        ax.set_ylabel("y [μm]", labelpad=3)
        ax.set_zlabel("z [μm]", labelpad=3)
        ax.tick_params(labelsize=8, pad=0)
        ax.set_title(f"m = {m}\npeak = {peak:.3e}   iso = {iso:.3e}",
                     fontsize=11, pad=6)
        summary.append(f"m={m}: peak={peak:.3e} iso={iso:.3e}")

    sm = plt.cm.ScalarMappable(norm=norm, cmap=cmap)
    sm.set_array([])
    cbar = fig.colorbar(sm, cax=cax)
    cbar.set_label(r"phase $\arg(\psi_m)$ [rad]")
    cbar.ax.tick_params(labelsize=8)

    fig.suptitle(
        f"Goto 10 mG  |  m = -6,-5,-4 isosurfaces  |  "
        f"iso = {ISO_PEAK_RATIO:.0%} × per-component peak  |  "
        f"B = {B_uG:.2f} μG  |  t = {t_ms:.2f} ms",
        fontsize=14, y=0.95,
    )
    fig.text(0.03, 0.02, "   ".join(summary),
             fontsize=9.0, family="monospace",
             bbox=dict(boxstyle="round,pad=0.30", facecolor="white",
                       edgecolor="#aaaaaa", alpha=0.95))

    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=130)
    plt.close(fig)
    buf.seek(0)
    return Image.open(buf).convert("P", palette=Image.Palette.ADAPTIVE)


def main():
    print(f"loading {H5}")
    loaded, t, B, omega_ref, Lbox, NX, vol_stride = load_dataset(H5)
    n_total = next(iter(loaded.values()))[0].shape[0]
    k0 = int(round(FRAME_START_FRAC * n_total))
    frame_ids = list(range(k0, n_total))
    coords = build_coords(loaded[-6][0].shape[1:], Lbox, NX, vol_stride)
    print(f"second half: frames {k0}..{n_total - 1} ({len(frame_ids)} frames)  "
          f"iso = {ISO_PEAK_RATIO:.0%} × per-component peak")

    frames = []
    for n, k in enumerate(frame_ids, 1):
        t_ms = float(t[k]) / omega_ref * 1000.0
        B_uG = float(B[k]) * 1e6
        frames.append(render_frame(loaded, coords, Lbox, t_ms, B_uG, k))
        if n % 10 == 0 or n == len(frame_ids):
            print(f"  frame {n:3d}/{len(frame_ids)}  k={k:3d}  "
                  f"t={t_ms:7.3f} ms  B={B_uG:+8.3f} μG")

    OUT_GIF.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        OUT_GIF, save_all=True, append_images=frames[1:],
        duration=FRAME_DURATION_MS, loop=0,
    )
    print(f"wrote {OUT_GIF}")


if __name__ == "__main__":
    main()
