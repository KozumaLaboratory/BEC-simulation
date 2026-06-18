#!/usr/bin/env python3
"""
Smooth 3-D isosurface rendering for the stored Goto RTP 3-D density volume.

The current H5 does not contain a 3-D m=-5 volume. This script therefore
defaults to the stored m=-6 3-D density (`n_m6_3d`) and renders two smooth
isosurfaces at 90% and 95% of the peak density.

Output:
  Desktop/goto_m6_isosurface_90_95.png
"""
import os
import numpy as np
import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
})

ROOT = os.environ.get("FPE_ROOT", "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
H5 = os.environ.get("GOTO_H5", os.path.join(ROOT, "rtp_10mG_goto.h5"))
OUT_PNG = os.environ.get(
    "OUT_PNG",
    os.path.join(os.path.expanduser("~/Desktop"), "goto_m6_isosurface_90_95.png"),
)
FIELD = os.environ.get("ISO_FIELD", "m6")  # "m6" or "total"


def load_volume(path):
    with h5py.File(path, "r") as f:
        omega_ref = float(f["meta/omega_ref"][()])
        Lbox = float(f["meta/L_box"][()])
        NX = int(f["meta/NX"][()])
        vol_stride = int(f["meta/vol_stride"][()])
        t = f["t"][:]
        B = f["B_gauss"][:] * 1e6
        if FIELD == "total":
            vol = np.transpose(f["n_total_3d"][:], (3, 2, 1, 0))
            label = r"$n_{\mathrm{total}}$"
        else:
            if "n_m6_3d" not in f:
                raise RuntimeError("n_m6_3d is missing from H5")
            vol = np.transpose(f["n_m6_3d"][:], (3, 2, 1, 0))
            label = r"$n_{m=-6}$"
    return vol, t, B, omega_ref, Lbox, NX, vol_stride, label


def interp_point(p0, p1, v0, v1, iso):
    if abs(v1 - v0) < 1e-15:
        return 0.5 * (p0 + p1)
    t = (iso - v0) / (v1 - v0)
    return p0 + t * (p1 - p0)


def sort_polygon(points):
    pts = np.asarray(points, dtype=float)
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
        return pts
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
    return pts[np.argsort(ang)]


TETS = [
    (0, 1, 3, 7),
    (0, 3, 2, 7),
    (0, 2, 6, 7),
    (0, 6, 4, 7),
    (0, 4, 5, 7),
    (0, 5, 1, 7),
]

CUBE = np.array([
    [0, 0, 0],
    [1, 0, 0],
    [0, 1, 0],
    [1, 1, 0],
    [0, 0, 1],
    [1, 0, 1],
    [0, 1, 1],
    [1, 1, 1],
], dtype=float)

TET_EDGES = [
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 2),
    (1, 3),
    (2, 3),
]


def marching_tetrahedra(vol3d, coords, iso):
    tris = []
    vals = []
    nx, ny, nz = vol3d.shape
    for i in range(nx - 1):
        for j in range(ny - 1):
            for k in range(nz - 1):
                cube_vals = np.array([
                    vol3d[i, j, k],
                    vol3d[i + 1, j, k],
                    vol3d[i, j + 1, k],
                    vol3d[i + 1, j + 1, k],
                    vol3d[i, j, k + 1],
                    vol3d[i + 1, j, k + 1],
                    vol3d[i, j + 1, k + 1],
                    vol3d[i + 1, j + 1, k + 1],
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
                for tet in TETS:
                    p = cube_pts[list(tet)]
                    v = cube_vals[list(tet)]
                    inside = v >= iso
                    if np.all(inside) or not np.any(inside):
                        continue
                    pts = []
                    for a, b in TET_EDGES:
                        va, vb = v[a], v[b]
                        if (va >= iso) == (vb >= iso):
                            continue
                        pts.append(interp_point(p[a], p[b], va, vb, iso))
                    if len(pts) < 3:
                        continue
                    pts = sort_polygon(pts)
                    if len(pts) == 3:
                        tris.append(pts)
                        vals.append(float(v.mean()))
                    else:
                        tris.append(np.array([pts[0], pts[1], pts[2]]))
                        tris.append(np.array([pts[0], pts[2], pts[3]]))
                        vals.extend([float(v.mean()), float(v.mean())])
    return tris, np.array(vals, dtype=float)


vol, t, B, omega_ref, Lbox, NX, vol_stride, label = load_volume(H5)
k = -1
v = vol[k]
dx = Lbox / NX * vol_stride
xs = -Lbox / 2 + dx * np.arange(v.shape[0]) + dx / 2
coords = np.empty(v.shape + (3,), dtype=float)
for i in range(v.shape[0]):
    for j in range(v.shape[1]):
        for k2 in range(v.shape[2]):
            coords[i, j, k2] = (xs[i], xs[j], xs[k2])

vmax = float(np.max(v))
isos = [0.90 * vmax, 0.95 * vmax]
colors = ["#1f77b4", "#d62728"]

fig = plt.figure(figsize=(14, 6), facecolor="white")
axes = [
    fig.add_subplot(1, 2, 1, projection="3d"),
    fig.add_subplot(1, 2, 2, projection="3d"),
]

for ax, iso, color, title in zip(axes, isos, colors, ["90% threshold", "95% threshold"]):
    tris, vals = marching_tetrahedra(v, coords, iso)
    ax.set_facecolor("white")
    if not tris:
        ax.text2D(0.15, 0.5, "No surface found", transform=ax.transAxes)
        continue
    tri_arr = np.asarray(tris, dtype=float)
    x = tri_arr[:, :, 0].reshape(-1)
    y = tri_arr[:, :, 1].reshape(-1)
    z = tri_arr[:, :, 2].reshape(-1)
    tri_idx = np.arange(len(tris) * 3).reshape(-1, 3)
    poly = ax.plot_trisurf(
        x, y, z,
        triangles=tri_idx,
        color=color,
        linewidth=0.12,
        antialiased=True,
        shade=True,
        alpha=0.95,
    )
    ax.set_xlim(-Lbox / 2, Lbox / 2)
    ax.set_ylim(-Lbox / 2, Lbox / 2)
    ax.set_zlim(-Lbox / 2, Lbox / 2)
    ax.set_box_aspect((1, 1, 1))
    ax.view_init(elev=24, azim=235)
    ax.set_title(f"{label}  |  {title}")
    ax.set_xlabel("x [μm]")
    ax.set_ylabel("y [μm]")
    ax.set_zlabel("z [μm]")
    ax.grid(False)

fig.suptitle(
    f"Goto final snapshot  |  B = {B[k]:.3f} μG  |  t = {t[k] / omega_ref * 1000.0:.2f} ms",
    fontsize=14,
)
fig.tight_layout(rect=[0, 0, 1, 0.94])
fig.savefig(OUT_PNG, dpi=220)
print(f"wrote {OUT_PNG}")
print(f"field={FIELD}  vmax={vmax:.6g}  iso90={isos[0]:.6g}  iso95={isos[1]:.6g}")
