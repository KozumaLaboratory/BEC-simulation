#!/usr/bin/env python3
"""
RTP (Goto 10 mG protocol) — m = -6 3D isosurface time-lapse.

Threshold strategy: per-frame iso = ISO_PEAK_RATIO * max(n_m6_3d).  Defaults
to 0.30 (much stricter than the 95%-mass scheme used elsewhere) so that the
fine structure of the m=-6 cloud — anisotropy, surface modulation — survives
the rendering instead of being masked by the bulk.

Single-process, multi-frame: loops over all snapshots in the H5 internally
and assembles the GIF in one Python invocation (no subprocess fan-out).

Inputs (env-overridable):
  RTP_H5            path to rtp_10mG_goto.h5
  OUT_GIF           output GIF path
  ISO_PEAK_RATIO    iso threshold as fraction of per-frame peak (default 0.30)
  MAX_FRAMES        cap (0 = all frames; default 0)
  FRAME_DURATION_MS GIF frame duration (default 120)
"""
import io
import os
from pathlib import Path

import h5py
import matplotlib

matplotlib.use("Agg")
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.gridspec import GridSpec
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from PIL import Image
from _anim_writer import save_pil_frames

H5_DEFAULT = "/gs/fs/tga-kozuma-kouhi/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto.h5"
H5 = Path(os.environ.get("RTP_H5", H5_DEFAULT))
OUT_GIF = Path(os.environ.get(
    "OUT_GIF",
    "runs/eu151_flower_protocol_edh/figures/goto_protocol_10mG/isosurface_peak30_m6.mp4",
))
ISO_PEAK_RATIO = float(os.environ.get("ISO_PEAK_RATIO", "0.30"))
MAX_FRAMES = int(os.environ.get("MAX_FRAMES", "0"))
FRAME_DURATION_MS = int(os.environ.get("FRAME_DURATION_MS", "33"))
FPS = int(os.environ.get("FPE_FPS", str(max(1, int(round(1000 / FRAME_DURATION_MS))))))

TETS = [
    (0, 1, 3, 7), (0, 3, 2, 7), (0, 2, 6, 7),
    (0, 6, 4, 7), (0, 4, 5, 7), (0, 5, 1, 7),
]
TET_EDGES = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]


def load_dataset(path):
    with h5py.File(path, "r") as f:
        for key in ("n_m6_3d", "arg_psi_m6_3d"):
            if key not in f:
                raise RuntimeError(f"H5 missing {key}; rerun RTP")
        omega_ref = float(f["meta/omega_ref"][()])
        Lbox = float(f["meta/L_box"][()])
        NX = int(f["meta/NX"][()])
        vol_stride = int(f["meta/vol_stride"][()])
        t = f["t"][:]
        B = f["B_gauss"][:]
        # HDF5.jl writes column-major Julia (Nf, NVOL, NVOL, NVOL) as
        # h5py shape (NVOL, NVOL, NVOL, Nf). Reverse all axes → (Nf, ix, iy, iz).
        dens = np.transpose(f["n_m6_3d"][:], (3, 2, 1, 0))
        phase = np.transpose(f["arg_psi_m6_3d"][:], (3, 2, 1, 0))
    return dens, phase, t, B, omega_ref, Lbox, NX, vol_stride


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
    coords = np.stack([g0, g1, g2], axis=-1)
    return coords, xs


def render_frame(dens_k, phase_k, coords, Lbox, t_ms, B_uG, peak, iso):
    fig = plt.figure(figsize=(7.5, 7.0), facecolor="white")
    gs = GridSpec(1, 2, figure=fig, width_ratios=[1.0, 0.045],
                  left=0.04, right=0.93, bottom=0.10, top=0.88, wspace=0.04)
    ax = fig.add_subplot(gs[0, 0], projection="3d")
    cax = fig.add_subplot(gs[0, 1])
    cmap = plt.cm.hsv
    norm = plt.Normalize(vmin=-np.pi, vmax=np.pi)

    tris, tri_phase = marching_tetrahedra(dens_k, phase_k, coords, iso)
    if tris:
        poly = Poly3DCollection(tris, facecolors=cmap(norm(tri_phase)),
                                edgecolors="none", linewidths=0.0, alpha=0.95)
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

    sm = plt.cm.ScalarMappable(norm=norm, cmap=cmap)
    sm.set_array([])
    cbar = fig.colorbar(sm, cax=cax)
    cbar.set_label(r"phase $\arg(\psi_{-6})$ [rad]")
    cbar.ax.tick_params(labelsize=8)

    fig.suptitle(
        f"Goto 10 mG  |  m = -6 isosurface  |  iso = {ISO_PEAK_RATIO:.0%} × peak  |  "
        f"B = {B_uG:.2f} μG  |  t = {t_ms:.2f} ms",
        fontsize=12, y=0.95,
    )
    fig.text(0.04, 0.02,
             f"peak={peak:.3e}   iso={iso:.3e}",
             fontsize=9.0, family="monospace",
             bbox=dict(boxstyle="round,pad=0.30", facecolor="white",
                       edgecolor="#aaaaaa", alpha=0.95))

    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=140)
    plt.close(fig)
    buf.seek(0)
    return Image.open(buf).convert("P", palette=Image.Palette.ADAPTIVE)


def main():
    print(f"loading {H5}")
    dens, phase, t, B, omega_ref, Lbox, NX, vol_stride = load_dataset(H5)
    n_frames = dens.shape[0]
    if MAX_FRAMES > 0:
        n_frames = min(n_frames, MAX_FRAMES)
    print(f"frames: {n_frames}  shape: {dens.shape[1:]}  iso = {ISO_PEAK_RATIO:.0%} × peak")

    coords, _ = build_coords(dens.shape[1:], Lbox, NX, vol_stride)
    frames = []
    for k in range(n_frames):
        dk = dens[k]; pk = phase[k]
        peak = float(dk.max())
        iso = ISO_PEAK_RATIO * peak
        t_ms = float(t[k]) / omega_ref * 1000.0
        B_uG = float(B[k]) * 1e6
        img = render_frame(dk, pk, coords, Lbox, t_ms, B_uG, peak, iso)
        frames.append(img)
        if k % 10 == 0 or k == n_frames - 1:
            print(f"  frame {k + 1:3d}/{n_frames}  t={t_ms:7.3f} ms  B={B_uG:+8.3f} μG  peak={peak:.3e}")

    OUT_GIF.parent.mkdir(parents=True, exist_ok=True)
    save_pil_frames(frames, OUT_GIF, fps=FPS, duration_ms=FRAME_DURATION_MS)
    print(f"wrote {OUT_GIF}")


if __name__ == "__main__":
    main()
