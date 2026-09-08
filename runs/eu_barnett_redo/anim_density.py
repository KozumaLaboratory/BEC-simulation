#!/usr/bin/env python3
"""Animate the cloud itself: column density and column magnetisation.

Reads `data/colmaps_<tag>.jld2`, written when `run_core.jl` runs with
`BR_COLFRAMES=1`. JLD2 is HDF5, so h5py opens it directly; Julia's `(nx, ny, nt)`
arrives as `(nt, ny, nx)`, which is what `imshow` wants row-wise.

WHY THESE MAPS AND NOT psi. A full psi frame is 273 MB at production size, so the
8 frames the study keeps are half a second of video and cannot be more. The
z-integrated maps are 230 kB each, so the ledger's own cadence (every 0.1
/omega_ref) gives ~800 frames — 13 s at 60 fps.

COLOUR SCALES ARE FIXED ACROSS THE MOVIE, deliberately. A per-frame autoscale
makes a cloud that is spreading look stationary, which is the opposite of what
the animation is for. The density scale is the global max; the magnetisation
scale is symmetric about zero so that sign is readable as colour.

Usage:
  python3 runs/eu_barnett_redo/anim_density.py --tag=_movie_prod_box35
  python3 runs/eu_barnett_redo/anim_density.py --tag=... --fps=15 --stride=2
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from ledger_io import DATA, load

FIGS = DATA.parent / "figures"
FIGS.mkdir(exist_ok=True)

TAG = "_movie_prod_box35"
FPS, STRIDE = [], 1
for a in sys.argv[1:]:
    if a.startswith("--tag="):
        TAG = a.split("=", 1)[1]
    elif a.startswith("--fps="):
        FPS.append(int(a.split("=", 1)[1]))
    elif a.startswith("--stride="):
        STRIDE = int(a.split("=", 1)[1])
if not FPS:
    FPS = [60, 15]
if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found — it is what turns the frames into a file")

src = DATA / f"colmaps_plus{TAG}.jld2"
if not src.exists():
    sys.exit(f"{src} is missing. It is written only by a run with BR_COLFRAMES=1; "
             "the production cells were run without it and cannot be animated.")

with h5py.File(src, "r") as f:
    t = np.array(f["t"])
    n_col = np.array(f["n_col"])       # (nt, ny, nx)
    fz_col = np.array(f["fz_col"])
    x = np.array(f["x"])
    y = np.array(f["y"]) if "y" in f else x
    t_stir = float(f["t_stir"][()])
    omega = float(f["omega"][()])

# The ledger for the SAME run, so the cursor panel is that trajectory and not a
# different cell's. Optional: the movie stands without it.
led = None
try:
    led = load(f"ledger_plus{TAG}.csv")
except FileNotFoundError as e:
    print("no matching ledger, drawing without the trace panel:", str(e)[:80])

idx = list(range(0, len(t), STRIDE))
print(f"{len(t)} frames, stride {STRIDE} -> {len(idx)} "
      f"({', '.join(f'{len(idx)/f:.1f} s at {f} fps' for f in FPS)})")

# CROP TO WHERE THE CLOUD IS. The box is sized by edge density (1e-6 at the wall), so
# most of the frame is empty and the interesting structure ends up a quarter of the
# panel. The window is taken from the data — the smallest symmetric box holding
# 99.9 % of the column density at the LAST frame, which is the most expanded one, so
# nothing that appears later is cropped out — rather than hand-set.
def crop_halfwidth(frac=0.999):
    tot = n_col[-1].sum()
    for r in range(1, min(len(x), len(y)) // 2):
        sl = np.s_[len(y) // 2 - r:len(y) // 2 + r, len(x) // 2 - r:len(x) // 2 + r]
        if n_col[-1][sl].sum() >= frac * tot:
            return max(abs(x[len(x) // 2 - r]), abs(y[len(y) // 2 - r]))
    return max(abs(x[0]), abs(y[0]))

R = crop_halfwidth()
ext = [-R, R, -R, R]
ix = np.abs(x) <= R
iy = np.abs(y) <= R
n_col = n_col[:, iy][:, :, ix]
fz_col = fz_col[:, iy][:, :, ix]
print(f"cropped to +-{R:.2f} a_ho (99.9 % of the final column density), "
      f"{n_col.shape[2]}x{n_col.shape[1]} cells shown")
# Scale into readable units and say so in the titles. The colorbar's own offset text
# ("1e-4") is drawn above the bar and landed on top of the panel title.
N_SCALE, F_SCALE = 1e4, 1e3
n_col = n_col * N_SCALE
fz_col = fz_col * F_SCALE
nmax = float(n_col.max())
fmax = float(np.abs(fz_col).max())

plt.rcParams.update({"font.size": 11, "figure.dpi": 100})
ncols = 3 if led is not None else 2
fig, axes = plt.subplots(1, ncols, figsize=(12.8, 7.2),
                         gridspec_kw={"width_ratios": [1, 1, 1.15][:ncols]})
fig.subplots_adjust(left=0.065, right=0.965, top=0.855, bottom=0.11, wspace=0.42)
a_n, a_f = axes[0], axes[1]

im_n = a_n.imshow(n_col[0], origin="lower", extent=ext, cmap="magma",
                  vmin=0.0, vmax=nmax, aspect="equal")
a_n.set_title(r"column density  $\int n\,dz$   [$10^{-4}$]")
im_f = a_f.imshow(fz_col[0], origin="lower", extent=ext, cmap="RdBu_r",
                  vmin=-fmax, vmax=fmax, aspect="equal")
a_f.set_title(r"column magnetisation  $\int f_z\,dz$   [$10^{-3}$]")
for a in (a_n, a_f):
    a.set_xlabel(r"$x$  [$a_{\rm ho}$]")
a_n.set_ylabel(r"$y$  [$a_{\rm ho}$]")
cb_n = fig.colorbar(im_n, ax=a_n, fraction=0.046, pad=0.02)
cb_f = fig.colorbar(im_f, ax=a_f, fraction=0.046, pad=0.02)
for cb in (cb_n, cb_f):
    cb.ax.tick_params(labelsize=8)
    cb.formatter.set_useOffset(False)
    cb.update_ticks()

if led is not None:
    a_t = axes[2]
    a_t.plot(led["t"], led["Lz"], color="#1b6ca8", lw=1.0, alpha=0.25)
    a_t.plot(led["t"], led["Fz"], color="#c0392b", lw=1.0, alpha=0.25)
    a_t.plot(led["t"], led["Jz"], color="k", lw=1.0, alpha=0.25)
    l_lz, = a_t.plot([], [], color="#1b6ca8", lw=2.2, label=r"$\langle L_z\rangle$")
    l_fz, = a_t.plot([], [], color="#c0392b", lw=2.2, label=r"$\langle F_z\rangle$")
    l_jz, = a_t.plot([], [], color="k", lw=2.6, label=r"$J_z$")
    a_t.axvline(t_stir, color="k", lw=0.9, ls="--", alpha=0.55)
    a_t.axhline(0.0, color="k", lw=0.7, alpha=0.4)
    a_t.set_xlim(led["t"][0], led["t"][-1])
    a_t.grid(alpha=0.25)
    a_t.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
    a_t.set_ylabel(r"angular momentum  [$\hbar$/atom]")
    a_t.set_title("the ledger, same run")
    a_t.legend(loc="upper left", framealpha=0.92)

banner = fig.text(0.5, 0.955, "", ha="center", fontsize=15, fontweight="bold")
fig.text(0.5, 0.022,
         rf"$^{{151}}$Eu $F=6$, rotating field at $\Omega={omega:g}$, then $B\to 0$ — "
         "colour scales fixed across the movie",
         ha="center", fontsize=9, alpha=0.7)


def draw(k):
    im_n.set_data(n_col[k])
    im_f.set_data(fz_col[k])
    stage = "STIR — rotating field injects $L_z$" if t[k] < t_stir \
        else r"QUENCH  $B=0$ — DDI converts $L_z \to \langle F_z\rangle$"
    banner.set_text(f"{stage}          $t = {t[k]:.1f}$")
    if led is not None:
        j = int(np.searchsorted(led["t"], t[k], side="right"))
        s = slice(0, max(j, 1))
        l_lz.set_data(led["t"][s], led["Lz"][s])
        l_fz.set_data(led["t"][s], led["Fz"][s])
        l_jz.set_data(led["t"][s], led["Jz"][s])


with tempfile.TemporaryDirectory() as d:
    for n, k in enumerate(idx):
        draw(k)
        fig.savefig(Path(d) / f"f{n:05d}.png")
        if n % 100 == 0:
            print(f"  rendered {n}/{len(idx)}", flush=True)
    plt.close(fig)
    for fps in FPS:
        # ★出力名に TAG を入れる。入れていなかったので、別の走行の動画が同じ
        # 名前になり、fps が一致すると **黙って上書き**していた（2026-09-08 に
        # 30 mG を --fps=20 で描いて気づいた ── 15 fps を選んでいたら 08-26 の
        # box35 を消していた）。この repo で同型の事故が既に 1 件ある。
        out = FIGS / f"anim_density{TAG}_{fps}fps.mp4"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
                        "-i", str(Path(d) / "f%05d.png"), "-c:v", "libx264",
                        "-pix_fmt", "yuv420p", "-crf", "18", str(out)], check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(idx)/fps:.1f} s at {fps} fps)")
