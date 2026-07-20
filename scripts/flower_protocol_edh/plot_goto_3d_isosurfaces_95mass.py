#!/usr/bin/env python3
"""
Render 3-D isosurfaces for m=-6, -5, -4 from the Goto RTP HDF5 output.

The threshold is chosen by cumulative mass: the region {rho >= rho_iso}
contains the requested fraction of the component probability on the stored
downsampled grid. Phase arg(psi_m) is mapped to the isosurface color.

Expected datasets:
  n_m6_3d, n_m5_3d, n_m4_3d
  arg_psi_m6_3d, arg_psi_m5_3d, arg_psi_m4_3d
"""
import os
import numpy as np
import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

ROOT = os.environ.get("FPE_ROOT", "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.environ.get("GOTO_H5", os.path.join(ROOT, "rtp_10mG_goto.h5"))
OUT_PNG = os.environ.get(
    "OUT_PNG",
    os.path.join(ROOT, "goto_3d_isosurfaces_95mass_m6_m5_m4.png"),
)
MASS_FRACTION = float(os.environ.get("ISO_MASS_FRACTION", "0.95"))
SNAP_INDEX = int(os.environ.get("ISO_SNAP_INDEX", "-1"))

COMPONENTS = [
    (-6, "n_m6_3d", "arg_psi_m6_3d"),
    (-5, "n_m5_3d", "arg_psi_m5_3d"),
    (-4, "n_m4_3d", "arg_psi_m4_3d"),
]

TETS = [
    (0, 1, 3, 7),
    (0, 3, 2, 7),
    (0, 2, 6, 7),
    (0, 6, 4, 7),
    (0, 4, 5, 7),
    (0, 5, 1, 7),
]

TET_EDGES = [
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
]


def load_data(path):
    with h5py.File(path, "r") as f:
        missing = [
            key
            for _, dens_key, phase_key in COMPONENTS
            for key in (dens_key, phase_key)
            if key not in f
        ]
        if missing:
            raise RuntimeError(
                "missing 3-D datasets: "
                + ", ".join(missing)
                + " ; rerun goto_protocol_10mG.jl after the 3D-component export update"
            )
        omega_ref = float(f["meta/omega_ref"][()])
        Lbox = float(f["meta/L_box"][()])
        NX = int(f["meta/NX"][()])
        vol_stride = int(f["meta/vol_stride"][()])
        t = f["t"][:]
        B = f["B_gauss"][:]
        loaded = {}
        for m, dens_key, phase_key in COMPONENTS:
            dens = np.transpose(f[dens_key][:], (3, 2, 1, 0))
            phase = np.transpose(f[phase_key][:], (3, 2, 1, 0))
            loaded[m] = (dens, phase)
    return loaded, t, B, omega_ref, Lbox, NX, vol_stride


def cumulative_mass_isovalue(density, mass_fraction):
    flat = np.asarray(density, dtype=float).ravel()
    total = float(np.sum(flat))
    if total <= 0.0:
        return 0.0, 0.0
    order = np.argsort(flat)[::-1]
    sorted_flat = flat[order]
    cumulative = np.cumsum(sorted_flat)
    target = mass_fraction * total
    idx = int(np.searchsorted(cumulative, target, side="left"))
    idx = min(idx, len(sorted_flat) - 1)
    iso = float(sorted_flat[idx])
    enclosed = float(np.sum(flat[flat >= iso]) / total)
    return iso, enclosed


def interp_point(p0, p1, v0, v1, iso):
    if abs(v1 - v0) < 1e-15:
        return 0.5 * (p0 + p1), 0.5
    t = (iso - v0) / (v1 - v0)
    return p0 + t * (p1 - p0), t


def interp_phase(u0, u1, t):
    u = (1.0 - t) * u0 + t * u1
    if abs(u) < 1e-15:
        u = u0
    return np.angle(u)


def sort_polygon(points, phases):
    pts = np.asarray(points, dtype=float)
    phs = np.asarray(phases, dtype=float)
    c = pts.mean(axis=0)
    n = None
    for i in range(len(pts) - 2):
        v1 = pts[i + 1] - pts[0]
        v2 = pts[i + 2] - pts[0]
        cr = np.cross(v1, v2)
        if np.linalg.norm(cr) > 1e-12:
            n = cr / np.linalg.norm(cr)
            break
    if n is None:
        return pts, phs
    ref = pts[0] - c
    ref = ref - np.dot(ref, n) * n
    ref_norm = np.linalg.norm(ref)
    if ref_norm < 1e-12:
        ref = np.array([1.0, 0.0, 0.0])
        if abs(np.dot(ref, n)) > 0.9:
            ref = np.array([0.0, 1.0, 0.0])
        ref = ref - np.dot(ref, n) * n
        ref_norm = np.linalg.norm(ref)
    u = ref / ref_norm
    v = np.cross(n, u)
    ang = np.arctan2((pts - c) @ v, (pts - c) @ u)
    order = np.argsort(ang)
    return pts[order], phs[order]


def marching_tetrahedra(density, phase, coords, iso):
    tris = []
    tri_phase = []
    phase_u = np.exp(1j * phase)
    nx, ny, nz = density.shape
    for i in range(nx - 1):
        for j in range(ny - 1):
            for k in range(nz - 1):
                cube_vals = np.array([
                    density[i, j, k],
                    density[i + 1, j, k],
                    density[i, j + 1, k],
                    density[i + 1, j + 1, k],
                    density[i, j, k + 1],
                    density[i + 1, j, k + 1],
                    density[i, j + 1, k + 1],
                    density[i + 1, j + 1, k + 1],
                ], dtype=float)
                cube_pts = np.array([
                    coords[i, j, k],
                    coords[i + 1, j, k],
                    coords[i, j + 1, k],
                    coords[i + 1, j + 1, k],
                    coords[i, j, k + 1],
                    coords[i + 1, j, k + 1],
                    coords[i, j + 1, k + 1],
                    coords[i + 1, j + 1, k + 1],
                ], dtype=float)
                cube_u = np.array([
                    phase_u[i, j, k],
                    phase_u[i + 1, j, k],
                    phase_u[i, j + 1, k],
                    phase_u[i + 1, j + 1, k],
                    phase_u[i, j, k + 1],
                    phase_u[i + 1, j, k + 1],
                    phase_u[i, j + 1, k + 1],
                    phase_u[i + 1, j + 1, k + 1],
                ], dtype=complex)
                for tet in TETS:
                    p = cube_pts[list(tet)]
                    v = cube_vals[list(tet)]
                    u = cube_u[list(tet)]
                    inside = v >= iso
                    if np.all(inside) or not np.any(inside):
                        continue
                    pts = []
                    phs = []
                    for a, b in TET_EDGES:
                        va, vb = v[a], v[b]
                        if (va >= iso) == (vb >= iso):
                            continue
                        point, t = interp_point(p[a], p[b], va, vb, iso)
                        pts.append(point)
                        phs.append(interp_phase(u[a], u[b], t))
                    if len(pts) < 3:
                        continue
                    pts, phs = sort_polygon(pts, phs)
                    if len(pts) == 3:
                        tris.append(pts)
                        tri_phase.append(np.angle(np.mean(np.exp(1j * phs))))
                    else:
                        tris.append(np.array([pts[0], pts[1], pts[2]]))
                        tris.append(np.array([pts[0], pts[2], pts[3]]))
                        mean1 = np.angle(np.mean(np.exp(1j * np.array([phs[0], phs[1], phs[2]]))))
                        mean2 = np.angle(np.mean(np.exp(1j * np.array([phs[0], phs[2], phs[3]]))))
                        tri_phase.extend([mean1, mean2])
    return tris, np.asarray(tri_phase, dtype=float)


loaded, t, B, omega_ref, Lbox, NX, vol_stride = load_data(H5)
k = SNAP_INDEX

sample = next(iter(loaded.values()))[0][k]
dx = Lbox / NX * vol_stride
xs = -Lbox / 2 + dx * np.arange(sample.shape[0]) + dx / 2
coords = np.empty(sample.shape + (3,), dtype=float)
for i in range(sample.shape[0]):
    for j in range(sample.shape[1]):
        for kz in range(sample.shape[2]):
            coords[i, j, kz] = (xs[i], xs[j], xs[kz])

fig = plt.figure(figsize=(18, 6), facecolor="white")
gs = GridSpec(1, 4, figure=fig, width_ratios=[1.0, 1.0, 1.0, 0.055],
    left=0.035, right=0.96, bottom=0.16, top=0.84, wspace=0.16)
axes = [fig.add_subplot(gs[0, idx], projection="3d") for idx in range(3)]
cax = fig.add_subplot(gs[0, 3])
cmap = plt.cm.hsv
norm = plt.Normalize(vmin=-np.pi, vmax=np.pi)

summary_lines = []
for ax, (m, _, _) in zip(axes, COMPONENTS):
    density, phase = loaded[m]
    dens_k = density[k]
    phase_k = phase[k]
    iso, enclosed = cumulative_mass_isovalue(dens_k, MASS_FRACTION)
    tris, tri_phase = marching_tetrahedra(dens_k, phase_k, coords, iso)
    ax.set_facecolor("white")
    if tris:
        colors = cmap(norm(tri_phase))
        poly = Poly3DCollection(
            tris,
            facecolors=colors,
            edgecolors="none",
            linewidths=0.0,
            alpha=0.95,
        )
        ax.add_collection3d(poly)
    else:
        ax.text2D(0.18, 0.5, "No surface found", transform=ax.transAxes)
    ax.set_xlim(-Lbox / 2, Lbox / 2)
    ax.set_ylim(-Lbox / 2, Lbox / 2)
    ax.set_zlim(-Lbox / 2, Lbox / 2)
    ax.set_box_aspect((1, 1, 1))
    ax.view_init(elev=22, azim=232)
    ax.set_xlabel("x [μm]", labelpad=3)
    ax.set_ylabel("y [μm]", labelpad=3)
    ax.set_zlabel("z [μm]", labelpad=3)
    ax.tick_params(labelsize=8, pad=0)
    ax.set_title(f"m = {m}\n95% mass iso = {iso:.3e}", fontsize=11, pad=8)
    summary_lines.append(
        f"m={m}: iso={iso:.6e}, enclosed={100.0 * enclosed:.3f}%"
    )

sm = plt.cm.ScalarMappable(norm=norm, cmap=cmap)
sm.set_array([])
cbar = fig.colorbar(sm, cax=cax)
cbar.set_label(r"phase $\arg(\psi_m)$ [rad]")
cbar.ax.tick_params(labelsize=8)

fig.suptitle(
    "Goto protocol  |  95% mass isosurfaces  |  "
    f"B = {B[k] * 1e6:.3f} μG  |  t = {t[k] / omega_ref * 1000.0:.2f} ms",
    fontsize=15, y=0.93,
)
fig.text(
    0.035,
    0.055,
    "\n".join(summary_lines),
    fontsize=10.0,
    family="monospace",
    va="bottom",
    ha="left",
    bbox=dict(boxstyle="round,pad=0.35", facecolor="white", edgecolor="#aaaaaa", alpha=0.95),
)
fig.savefig(OUT_PNG, dpi=220)
print(f"wrote {OUT_PNG}")
for line in summary_lines:
    print(line)
