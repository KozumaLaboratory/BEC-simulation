#!/usr/bin/env python3
"""Klaus magnetostirring as a movie: the DDI ellipse rotating, and vortices entering.

One row per stirring rate, columns:

  1. n(x,y) — the magnetostriction ellipse. The field is IN-PLANE, so the DDI
     elongation is in the plane being drawn and simply rotates. (It starts at
     AR = 1.45 before any stirring: that is the deformation, not the stir.)
     The instantaneous field direction is drawn as a short bar; the ellipse
     LAGGING it is the Klaus signature.
  2. TOF image — the expanded density, which is where a vortex core is actually
     visible. In situ the core is xi = 0.17 against dx = 0.25-0.75 and never
     resolves (measured core/peak 0.63, a dimple); after co-expanding-frame
     expansion to t_tof = 8 the same core reads 0.016, a black hole. Holes are
     detected HERE, at render time, so the criterion can be re-asked without
     re-running the physics.
  3. side view n(x,z) — the pancake trap, for shape context.
  4. history: AR, |lag|, L_z, vortex count, with a time cursor.

Vortices come from mass-current circulation on the TOTAL density. With the spin
locked to a rotating B the m components are continuously rotated into each
other, and per-component phase winding fires on that with no flow behind it.

  python runs/eu_barnett_rotfield_clean/viz_p1_movie.py [out.mp4]

Env: FPS=30  SECONDS=8  DPI=120  STRICT=0.25
"""
import os
import sys

import h5py
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter, FuncAnimation, PillowWriter

H = "runs/eu_barnett_rotfield_clean/rebuild_movie"
OUT = sys.argv[1] if len(sys.argv) > 1 else \
    "runs/eu_barnett_rotfield_clean/figures/fig_p1_klaus_movie.mp4"
FPS = int(os.environ.get("FPS", "30"))
SECONDS = float(os.environ.get("SECONDS", "8"))
DPI = int(os.environ.get("DPI", "120"))
STRICT = float(os.environ.get("STRICT", "0.25"))

TAGS = os.environ.get("TAGS", "O0p55,O0p65,O0p74,O0p85").split(",")
PREFIX = os.environ.get("PREFIX", "p1mov_tofscan_")
HOLE = float(os.environ.get("HOLE", "0.25"))   # hole if below this x local ring
arms = {}
for tag in TAGS:
    p = os.path.join(H, f"{PREFIX}{tag}.jld2")
    if not os.path.isfile(p):
        sys.exit(f"missing {p} — run run_p1_klaus_movie.jl first")
    arms[tag] = h5py.File(p, "r")

# Arms can differ in frame count and grid (they were produced by separate jobs
# at different resolutions), so align on TIME, not on frame index.
arm_t = {tag: np.asarray(arms[tag]["times"], dtype=float) for tag in TAGS}
t0 = max(a[0] for a in arm_t.values())
t1 = min(a[-1] for a in arm_t.values())
n_frames = max(int(np.asarray(arms[t]["n_frames"])) for t in TAGS)
times = np.linspace(t0, t1, n_frames)
# index of the nearest saved frame per arm, per movie time
near = {tag: np.abs(arm_t[tag][None, :] - times[:, None]).argmin(axis=1) for tag in TAGS}
tof_keys = {tag: np.array(sorted(int(k[4:]) for k in arms[tag].keys()
                                 if k.startswith("tof_") and k[4:].isdigit()))
            for tag in TAGS}
box = np.asarray(arms[TAGS[0]]["box"], dtype=float)
ext = [-box[0] / 2, box[0] / 2, -box[1] / 2, box[1] / 2]
ext_side = [-box[0] / 2, box[0] / 2, -box[2] / 2, box[2] / 2]


# NOTE ON ORIENTATION — do not add `.T` back.
# JLD2 writes column-major and h5py reads row-major, so an array Julia stored as
# [ix, iy] arrives here ALREADY transposed. Transposing again swaps x and y,
# which maps every angle theta -> 90 - theta and therefore REVERSES the apparent
# sense of rotation. That is exactly what it did: the cloud appeared to
# counter-rotate against the field bar while every number agreed, because the
# numbers came from Julia (correct axes) and only the picture was flipped.
# Verified by shape: side_ is [ix, iz] = (32, 16) in Julia and reads as (16, 32).


def rd(tag, name, i):
    """`i` indexes MOVIE time; map it to this arm's own saved frame."""
    j = int(near[tag][i])
    return np.asarray(arms[tag][f"{name}_{j + 1:05d}"])


def scal(tag, name, i):
    return float(np.asarray(arms[tag][name])[int(near[tag][i])])


n_target = max(1, int(round(FPS * SECONDS)))
sel = np.linspace(0, n_frames - 1, n_target).round().astype(int)
if len(np.unique(sel)) < n_frames:
    print(f"note: {n_frames} frames subsampled to {len(np.unique(sel))}")

fig, ax = plt.subplots(3, 4, figsize=(15.0, 10.2))
fig.subplots_adjust(hspace=0.30, wspace=0.28, top=0.90, left=0.05, right=0.98)
ims, marks, fbar, cursors, titles = {}, {}, {}, {}, {}

for r, tag in enumerate(TAGS):
    Om = float(np.asarray(arms[tag]["Omega"]))
    t = arm_t[tag]
    ar = np.asarray(arms[tag]["AR"], dtype=float)
    lag = np.abs(np.asarray(arms[tag]["lag"], dtype=float))
    lz = np.asarray(arms[tag]["Lz"], dtype=float)
    nv = [int((np.abs(rd(tag, "vw", i) - rd(tag, "vq", i)) < STRICT).sum())
          for i in range(n_frames)]
    nvt = times

    a = ax[r, 0]
    ims[(tag, "col")] = a.imshow(rd(tag, "col", 0), origin="lower", extent=ext,
                                 cmap="magma", aspect="equal")
    titles[(tag, "col")] = a.set_title("", fontsize=9)
    a.set_xticks([]); a.set_yticks([])
    npix = np.asarray(arms[tag]["col_00001"]).shape[0]
    a.set_ylabel(f"$\\Omega = {Om:.2f}$\n({npix}$^2$ grid)", fontsize=11)
    (fbar[tag],) = a.plot([], [], "-", color="lime", lw=2.0)

    a = ax[r, 1]
    ims[(tag, "nmid")] = a.imshow(tof_of(tag, 0), origin="lower",
                                  cmap="viridis", aspect="equal")
    titles[(tag, "nmid")] = a.set_title("", fontsize=9)
    a.set_xticks([]); a.set_yticks([])
    (p,) = a.plot([], [], "o", mfc="none", mec="w", ms=15, mew=1.5)
    (n,) = a.plot([], [], "o", mfc="none", mec="cyan", ms=15, mew=1.5)
    marks[tag] = (p, n)

    a = ax[r, 2]
    ims[(tag, "side")] = a.imshow(rd(tag, "side", 0), origin="lower",
                                  extent=ext_side, cmap="magma", aspect="equal")
    titles[(tag, "side")] = a.set_title("", fontsize=9)
    a.set_xticks([]); a.set_yticks([])

    a = ax[r, 3]
    a.plot(t, ar, lw=1.6, color="crimson", label="aspect ratio")
    a.plot(t, lag, lw=1.4, color="darkorange", label="|lag| [rad]")
    a.plot(t, lz, lw=1.6, color="royalblue", label="$L_z$")
    a.plot(nvt, np.asarray(nv) / 10.0, lw=1.3, color="0.4", ls="--",
           label="vortices / 10")
    a.axhline(0, color="0.8", lw=0.7)
    cursors[tag] = a.axvline(t[0], color="k", lw=1.2)
    a.set_xlabel("t  [$1/\\omega_{ref}$]", fontsize=9)
    a.legend(fontsize=8, loc="upper right")
    a.set_title("Klaus signatures: AR grows then collapses; lag and $L_z$ rise",
                fontsize=9)

sup = fig.suptitle("", fontsize=12)


def tof_of(tag, i):
    """Nearest STORED TOF frame (they are written on a stride)."""
    j = int(near[tag][i]) + 1
    ks = tof_keys[tag]
    k = ks[np.abs(ks - j).argmin()]
    return np.asarray(arms[tag][f"tof_{k:05d}"])


def _box_blur(a, k=5):
    """Uniform filter, numpy only (scipy is not installed here)."""
    pad = k // 2
    b = np.pad(a, pad, mode="edge")
    c = np.cumsum(np.cumsum(b, axis=0), axis=1)
    c = np.pad(c, ((1, 0), (1, 0)))
    n0, n1 = a.shape
    out = (c[k:k + n0, k:k + n1] - c[0:n0, k:k + n1]
           - c[k:k + n0, 0:n1] + c[0:n0, 0:n1])
    return out / (k * k)


def find_holes(img, frac):
    """Local minima sitting well below their surroundings, inside the cloud.

    Done at render time rather than in the driver so the criterion stays
    adjustable without re-running the physics. Greedy peak-picking with
    suppression rather than connected components — no scipy here.
    """
    pk = img.max()
    if pk <= 0:
        return [], []
    smooth = _box_blur(img, 5)
    depth = np.where((img < frac * smooth) & (img > 0) & (smooth > 0.15 * pk),
                     1.0 - img / np.maximum(smooth, 1e-30), 0.0)
    ny, nx = img.shape
    ys, xs = [], []
    d = depth.copy()
    for _ in range(40):
        i = int(d.argmax())
        if d.flat[i] <= 0:
            break
        r, c = divmod(i, nx)
        ys.append((r / ny - 0.5) * 2)
        xs.append((c / nx - 0.5) * 2)
        d[max(0, r - 3):r + 4, max(0, c - 3):c + 4] = 0.0
    return ys, xs


def phys(v, npix, L):
    return (v / npix - 0.5) * L


def draw(k):
    i = sel[k]
    for tag in TAGS:
        Om = float(np.asarray(arms[tag]["Omega"]))
        col = rd(tag, "col", i)
        ims[(tag, "col")].set_data(col)
        ims[(tag, "col")].set_clim(0, max(col.max(), 1e-30))
        arv = scal(tag, "AR", i)
        titles[(tag, "col")].set_text(f"$n(x,y)$  AR = {arv:.2f}")
        # instantaneous field direction (pi-periodic bar through the centre)
        fa = Om * times[i]
        L = box[0] * 0.42
        fbar[tag].set_data([-L * np.cos(fa), L * np.cos(fa)],
                           [-L * np.sin(fa), L * np.sin(fa)])

        tof = tof_of(tag, i)
        ims[(tag, "nmid")].set_data(tof)
        ims[(tag, "nmid")].set_clim(0, max(tof.max(), 1e-30))
        hy, hx = find_holes(tof, HOLE)
        p, n = marks[tag]
        p.set_data(hx, hy)
        n.set_data([], [])
        titles[(tag, "nmid")].set_text(
            f"TOF (t={float(np.asarray(arms[tag]['tof_t'])):.0f}) — {len(hx)} holes")

        side = rd(tag, "side", i)
        ims[(tag, "side")].set_data(side)
        ims[(tag, "side")].set_clim(0, max(side.max(), 1e-30))
        titles[(tag, "side")].set_text("side view $n(x,z)$")
        cursors[tag].set_xdata([times[i], times[i]])
    sup.set_text(f"Klaus magnetostirring — rotating in-plane B drags the DDI "
                 f"ellipse; vortices enter above $\\Omega_c \\approx 0.7$   |   "
                 f"t = {times[i]:.2f}   (green bar = field direction)")
    return []


ani = FuncAnimation(fig, draw, frames=len(sel), blit=False)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
try:
    ani.save(OUT, writer=FFMpegWriter(fps=FPS, bitrate=6000), dpi=DPI)
except (FileNotFoundError, RuntimeError):
    OUT = os.path.splitext(OUT)[0] + ".gif"
    print("ffmpeg unavailable — GIF fallback")
    ani.save(OUT, writer=PillowWriter(fps=FPS), dpi=DPI)
print(f"wrote {OUT}  ({len(sel)} frames @ {FPS} fps ≈ {len(sel) / FPS:.1f} s)")
