#!/usr/bin/env python3
"""Render a dynamics run as an mp4: density, vortices, spin, and their history.

Reads what the `vortex_density_movie` analyzer wrote (frames.jld2 +
manifest.json) and lays out four panels per frame:

  1. top view: column density n(x,y), looking ALONG the field axis
  2. SIDE view: column density n(x,z). This is the panel that shows the DDI
     magnetostriction — the top view integrates along the elongated axis and is
     a circular blob however prolate the cloud is (measured z/x = 1.42 on the Eu
     ground state, and completely invisible in panel 1).
  3. mid-plane TOTAL density with the mass-current vortices marked
     (o = +1, x = -1). A vortex core is a hole in the TOTAL density; if the
     markers are not sitting in holes, they are not cores.
  4. running history: vortex count and net charge vs time, with a cursor

Vortex count and net charge are plotted separately on purpose. A count that
climbs while the net stays 0 is pair production; a net that moves is
circulation actually entering the cloud. The grey dashed trace is the
per-component phase winding, kept visible precisely because it is NOT the
vortex count — on a spin-rotating state it runs an order of magnitude high.

  python scripts/viz_dynamics_movie.py <movie_dir> [out.mp4]

Env:
  FPS=30        frames per second (>= 30 keeps the motion readable)
  SECONDS=5     target duration; frames are resampled to FPS*SECONDS
  DPI=140
"""
import glob
import json
import os
import sys

import h5py
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter, FuncAnimation, PillowWriter

D = sys.argv[1] if len(sys.argv) > 1 else "movie"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(D, "dynamics.mp4")
FPS = int(os.environ.get("FPS", "30"))
SECONDS = float(os.environ.get("SECONDS", "5"))
DPI = int(os.environ.get("DPI", "140"))

with open(os.path.join(D, "manifest.json")) as fh:
    man = json.load(fh)
n_frames = int(man["n_frames"])
if n_frames == 0:
    sys.exit(f"{D}: manifest reports 0 frames — did the dynamics step set save_every?")

times = np.asarray(man["times"], dtype=float)
# THE vortex trace: circulation of the total mass current. `vortex_counts` is
# per-component phase winding, which during spin dynamics is mostly not
# vortices — it fires on the amplitude zeros a component develops while its
# population is rotated away. Both are plotted, labelled for what they are.
mcounts = np.asarray(man.get("mass_vortex_counts", man["vortex_counts"]), dtype=int)
mnetq = np.asarray(man.get("mass_net_charges", man["net_charges"]), dtype=int)
counts = np.asarray(man["vortex_counts"], dtype=int)
qerr = np.asarray(man.get("quantisation_error", np.zeros(len(times))), dtype=float)
# Circulations actually close to an integer. On a clean vortex |w - n| ~ 0.02;
# on disordered flow it saturates at 0.5 and the loose count means little.
mstrict = np.asarray(man.get("mass_vortex_counts_strict", mcounts), dtype=int)
has_mass = "mass_vortex_counts" in man
ext_x, ext_y = (float(v) for v in man["extent"])
side_ext = [float(v) for v in man.get("side_extent", man["extent"])]
has_side = "side_extent" in man

# Resample to the requested duration, so the movie is SECONDS long whatever the
# run saved: 400 snapshots should not become a 13-second movie, and 40 should
# not become a 1-second flicker. Deliberately NOT de-duplicated — dropping the
# repeats is what turns a short run back into a flicker. Repeats hold the frame;
# nothing is interpolated, and the time axis stays labelled either way.
n_target = max(1, int(round(FPS * SECONDS)))
sel = np.linspace(0, n_frames - 1, n_target).round().astype(int)
n_distinct = len(np.unique(sel))
if n_distinct < n_frames:
    print(f"note: {n_frames} snapshots subsampled to {n_distinct} — raise "
          f"SECONDS or lower FPS to show them all")
elif n_distinct < n_target:
    print(f"note: only {n_distinct} snapshots for {n_target} movie frames — "
          f"each is held ~{n_target / n_distinct:.1f}x. Lower `save.every` in "
          f"the config for genuinely smooth motion")

h5 = h5py.File(os.path.join(D, man["archive"]), "r")


def rd(prefix, i):
    return np.asarray(h5[f"{prefix}_{i + 1:05d}"])


# Fixed colour scales across the movie: a per-frame autoscale makes a decaying
# cloud look constant and a growing excitation look like nothing happened.
probe = sel[:: max(1, len(sel) // 12)]
n_hi = max(float(rd("n_col", i).max()) for i in probe)
_mid_key = "n_mid" if has_side else "dens_mid"
_side_key = "n_side" if has_side else "n_col"
dm_hi = max(float(rd(_mid_key, i).max()) for i in probe)
sd_hi = max(float(rd(_side_key, i).max()) for i in probe)

fig, axes = plt.subplots(2, 2, figsize=(11.5, 8.6))
fig.subplots_adjust(hspace=0.30, wspace=0.34, top=0.90, left=0.07, right=0.97)
axn, axp, axd, axh = axes.flat
half = [-ext_x / 2, ext_x / 2, -ext_y / 2, ext_y / 2]

im_n = axn.imshow(rd("n_col", sel[0]).T, origin="lower", extent=half,
                  cmap="inferno", vmin=0, vmax=n_hi, aspect="equal")
axn.set_title("column density $n(x,y)$")
fig.colorbar(im_n, ax=axn, fraction=0.046)

side_half = [-side_ext[0] / 2, side_ext[0] / 2, -side_ext[1] / 2, side_ext[1] / 2]
im_p = axp.imshow(rd(_side_key, sel[0]).T, origin="lower", extent=side_half,
                  cmap="inferno", vmin=0, vmax=sd_hi, aspect="equal")
axp.set_title("side view $n(x,z)$ — the elongated axis")
axp.set_xlabel("x")
axp.set_ylabel("z")
fig.colorbar(im_p, ax=axp, fraction=0.046)

im_d = axd.imshow(rd(_mid_key, sel[0]).T, origin="lower", extent=half,
                  cmap="viridis", vmin=0, vmax=dm_hi, aspect="equal")
axd.set_title("mid-plane TOTAL density + vortex cores")
(vpos,) = axd.plot([], [], "o", mfc="none", mec="w", ms=11, mew=1.8)
(vneg,) = axd.plot([], [], "x", mec="cyan", ms=11, mew=1.8)
fig.colorbar(im_d, ax=axd, fraction=0.046)

axh.plot(times, mcounts, lw=1.4, color="crimson", alpha=0.45,
         label="mass circ. (all)")
axh.plot(times, mstrict, lw=2.0, color="crimson",
         label="mass circ., $|w-n|<0.25$")
axh.plot(times, mnetq, lw=1.7, color="darkorange", label="net charge")
if has_mass:
    axh.plot(times, counts, lw=1.0, color="0.55", ls="--",
             label="per-component winding\n(NOT vortices)")
axh.axhline(0, color="0.7", lw=0.8)
cursor = axh.axvline(times[sel[0]], color="crimson", lw=1.4)
axh.set_xlabel("t  [$1/\\omega_{ref}$]")
axh.set_ylabel("count")
axh.legend(loc="upper left", fontsize=9)
axh.set_title("defect history")

title = fig.suptitle("")


def pix_to_phys(px, py, shape):
    """Plaquette indices (1-based, half-offset) → physical coordinates."""
    nx, ny = shape
    return (px / nx - 0.5) * ext_x, (py / ny - 0.5) * ext_y


def draw(k):
    i = sel[k]
    im_n.set_data(rd("n_col", i).T)
    im_p.set_data(rd(_side_key, i).T)
    mid = rd(_mid_key, i)
    im_d.set_data(mid.T)

    pre = "mvortex" if has_mass else "vortex"
    vx, vy, vq = rd(f"{pre}_x", i), rd(f"{pre}_y", i), rd(f"{pre}_q", i)
    if len(vq):
        px, py = pix_to_phys(vx, vy, mid.shape)
        vpos.set_data(px[vq > 0], py[vq > 0])
        vneg.set_data(px[vq < 0], py[vq < 0])
    else:
        vpos.set_data([], [])
        vneg.set_data([], [])
    cursor.set_xdata([times[i], times[i]])
    extra = f"   |w-n|max = {qerr[i]:.2f}" if has_mass and mcounts[i] else ""
    title.set_text(f"t = {times[i]:.3f}   vortices = {mstrict[i]} "
                   f"(of {mcounts[i]} candidates)   "
                   f"net charge = {mnetq[i]:+d}{extra}")
    return im_n, im_p, im_d, vpos, vneg, cursor, title


ani = FuncAnimation(fig, draw, frames=len(sel), blit=False)
try:
    ani.save(OUT, writer=FFMpegWriter(fps=FPS, bitrate=4000), dpi=DPI)
except (FileNotFoundError, RuntimeError):
    OUT = os.path.splitext(OUT)[0] + ".gif"
    print("ffmpeg unavailable — falling back to GIF")
    ani.save(OUT, writer=PillowWriter(fps=FPS), dpi=DPI)
h5.close()
print(f"wrote {OUT}  ({len(sel)} frames @ {FPS} fps ≈ {len(sel) / FPS:.1f} s)")
