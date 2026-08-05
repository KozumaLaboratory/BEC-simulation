#!/usr/bin/env python3
"""The vortex-nucleation window of a Klaus magnetostirring run.

Shows ONE Omega over the time window where the physics is legible, rather than
the whole run. That window is not a preference — it is where the measurement
says the interesting thing happens. At Omega = 0.78:

    t      AR     L_z    roughness   TOF holes
    8.5   3.52   +12.6     0.055        0     <- ellipse at maximum stretch
   11.3   2.73   +14.1     0.138        2     <- vortices in, cloud still smooth
   14.1   2.08    +6.8     0.558        2     <- collapse; turbulent from here
   16.9   1.39    +2.9     0.693        0

Past t ~ 14 the cloud is rough (0.5-0.7 against 0.03 at the start) and nothing
is distinguishable in it, so a movie over the full run buries the one moment it
exists to show.

Panels: in-situ n(x,y) with the field direction, the TOF image where the cores
are actually visible, and the traces with a cursor.

  python .../viz_nucleation.py <archive.jld2> [out.mp4]

Env: FPS=30  SECONDS=8  TMAX=16  DPI=130  HOLE=0.25
"""
import os
import sys

import h5py
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter, FuncAnimation, PillowWriter

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else \
    "runs/eu_barnett_rotfield_clean/figures/fig_vortex_nucleation.mp4"
FPS = int(os.environ.get("FPS", "30"))
SECONDS = float(os.environ.get("SECONDS", "8"))
TMAX = float(os.environ.get("TMAX", "16"))
DPI = int(os.environ.get("DPI", "130"))
HOLE = float(os.environ.get("HOLE", "0.25"))

f = h5py.File(SRC, "r")
nf = int(np.asarray(f["n_frames"]))
t = np.asarray(f["times"])[:nf]
Om = float(np.asarray(f["Omega"]))
box = np.asarray(f["box"])
ar = np.asarray(f["AR"])[:nf]
lz = np.asarray(f["Lz"])[:nf]
tof_keys = np.array(sorted(int(k[4:]) for k in f.keys()
                           if k.startswith("tof_") and k[4:].isdigit()))

# NOTE ON ORIENTATION — do not add `.T`. JLD2 writes column-major and h5py reads
# row-major, so [ix, iy] arrives already transposed; transposing again swaps x
# and y, which maps theta -> 90 - theta and reverses the apparent rotation.
keep = np.where(t <= TMAX)[0]
n_target = max(1, int(round(FPS * SECONDS)))
sel = keep[np.linspace(0, len(keep) - 1, n_target).round().astype(int)]


def rough(a):
    lap = np.abs(4 * a[1:-1, 1:-1] - a[2:, 1:-1] - a[:-2, 1:-1]
                 - a[1:-1, 2:] - a[1:-1, :-2])
    c = a[1:-1, 1:-1] > 0.2 * a.max()
    return float(lap[c].mean() / a[1:-1, 1:-1][c].mean())


def _box_blur(a, k=5):
    pad = k // 2
    b = np.pad(a, pad, mode="edge")
    c = np.cumsum(np.cumsum(b, axis=0), axis=1)
    c = np.pad(c, ((1, 0), (1, 0)))
    n0, n1 = a.shape
    return (c[k:k + n0, k:k + n1] - c[0:n0, k:k + n1]
            - c[k:k + n0, 0:n1] + c[0:n0, 0:n1]) / (k * k)


def find_holes(img, frac):
    pk = img.max()
    if pk <= 0:
        return [], []
    sm = _box_blur(img, 5)
    depth = np.where((img < frac * sm) & (img > 0) & (sm > 0.15 * pk),
                     1.0 - img / np.maximum(sm, 1e-30), 0.0)
    ny, nx = img.shape
    ys, xs, d = [], [], depth.copy()
    for _ in range(30):
        i = int(d.argmax())
        if d.flat[i] <= 0:
            break
        r, c = divmod(i, nx)
        ys.append(r); xs.append(c)
        d[max(0, r - 3):r + 4, max(0, c - 3):c + 4] = 0.0
    return ys, xs


def tof_at(i):
    k = tof_keys[np.abs(tof_keys - (i + 1)).argmin()]
    return np.asarray(f[f"tof_{k:05d}"])


roughs = np.array([rough(np.asarray(f[f"nmid_{i + 1:05d}"])) for i in keep])
holes = [len(find_holes(tof_at(i), HOLE)[0]) for i in keep]

fig = plt.figure(figsize=(13.5, 5.4))
gs = fig.add_gridspec(1, 3, width_ratios=[1, 1, 1.35], wspace=0.28)
a0, a1, a2 = (fig.add_subplot(gs[0]), fig.add_subplot(gs[1]), fig.add_subplot(gs[2]))
ext = [-box[0] / 2, box[0] / 2, -box[1] / 2, box[1] / 2]

im0 = a0.imshow(np.asarray(f["col_00001"]), origin="lower", extent=ext, cmap="magma")
(fbar,) = a0.plot([], [], "-", color="lime", lw=2.2)
a0.set_xticks([]); a0.set_yticks([])
t0 = a0.set_title("", fontsize=10)

im1 = a1.imshow(tof_at(0), origin="lower", cmap="viridis")
(hmark,) = a1.plot([], [], "o", mfc="none", mec="w", ms=16, mew=1.8)
a1.set_xticks([]); a1.set_yticks([])
t1 = a1.set_title("", fontsize=10)

a2.plot(t[keep], ar[keep], color="crimson", lw=1.8, label="aspect ratio")
a2.plot(t[keep], lz[keep] / 5.0, color="royalblue", lw=1.8, label="$L_z$ / 5")
a2.plot(t[keep], roughs, color="0.35", lw=1.6, ls="--", label="roughness")
a2.plot(t[keep], np.array(holes) / 2.0, color="darkorange", lw=1.6,
        label="TOF holes / 2")
a2.axhspan(0, 0.3, color="green", alpha=0.06)
a2.text(t[keep][1], 0.05, "cloud still smooth", fontsize=8, color="green")
cur = a2.axvline(t[sel[0]], color="k", lw=1.2)
a2.set_xlabel("t  [$1/\\omega_{ref}$]")
a2.legend(fontsize=9, loc="upper left")
a2.set_title("stretch, then vortices, then collapse", fontsize=10)
sup = fig.suptitle("", fontsize=12)


def draw(k):
    i = sel[k]
    col = np.asarray(f[f"col_{i + 1:05d}"])
    im0.set_data(col); im0.set_clim(0, max(col.max(), 1e-30))
    fa = Om * t[i]; L = box[0] * 0.42
    fbar.set_data([-L * np.cos(fa), L * np.cos(fa)],
                  [-L * np.sin(fa), L * np.sin(fa)])
    t0.set_text(f"in situ $n(x,y)$   AR = {ar[i]:.2f}")

    tof = tof_at(i)
    im1.set_data(tof); im1.set_clim(0, max(tof.max(), 1e-30))
    ys, xs = find_holes(tof, HOLE)
    hmark.set_data(xs, ys)
    t1.set_text(f"TOF image — {len(xs)} vortex core(s)")
    cur.set_xdata([t[i], t[i]])
    j = int(np.abs(np.asarray(keep) - i).argmin())
    sup.set_text(f"Klaus magnetostirring, $\\Omega$ = {Om:.2f}   |   t = {t[i]:.1f}"
                 f"   |   roughness {roughs[j]:.2f}"
                 f"   (green bar = field direction)")
    return []


ani = FuncAnimation(fig, draw, frames=len(sel), blit=False)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
try:
    ani.save(OUT, writer=FFMpegWriter(fps=FPS, bitrate=6000), dpi=DPI)
except (FileNotFoundError, RuntimeError):
    OUT = os.path.splitext(OUT)[0] + ".gif"
    ani.save(OUT, writer=PillowWriter(fps=FPS), dpi=DPI)
print(f"wrote {OUT}  ({len(sel)} frames @ {FPS} fps = {len(sel)/FPS:.1f} s, t <= {TMAX})")
