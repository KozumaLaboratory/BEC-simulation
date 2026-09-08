#!/usr/bin/env python3
"""Animate the J_z ledger — the whole claim, as it happens.

WHAT THIS CAN AND CANNOT SHOW. The ledgers sample every 0.1 /omega_ref, so a full
run is 802 frames: a real animation (13 s at 60 fps, 54 s at 15 fps). The psi
FRAMES are a different story — only 8 per cell were ever written, at 273 MB each,
so a density/vortex movie cannot be made from what exists. See README.

Left panel: the ledger at box 47, the cleanest geometry (edge 2.4e-10). L_z falls,
F_z rises by the same amount, J_z stays flat once B = 0. Right panel: the +-Omega
pair at box 28, the only geometry where both arms were run — they are exact mirror
images, which is a symmetry rather than a measurement (ledger row
`barnett-sign-follows-rotation-is-a-symmetry`).

Usage:
  python3 runs/eu_barnett_redo/anim_ledger.py                 # 60 and 15 fps
  python3 runs/eu_barnett_redo/anim_ledger.py --fps=15        # one rate
  python3 runs/eu_barnett_redo/anim_ledger.py --stride=2      # halve the frames
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from ledger_io import DATA, T_STIR, mirror, verify

FIGS = DATA.parent / "figures"
FIGS.mkdir(exist_ok=True)

FPS = []
STRIDE = 1
for a in sys.argv[1:]:
    if a.startswith("--fps="):
        FPS.append(int(a.split("=", 1)[1]))
    elif a.startswith("--stride="):
        STRIDE = int(a.split("=", 1)[1])
if not FPS:
    FPS = [60, 15]

if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found — it is what turns the frames into a file")

led = verify("ledger_plus_prod_box47.csv", npts="(320, 320, 120)", cell="plus")
arm_p = verify("ledger_plus_prod_box28.csv", npts="(128, 128, 80)", cell="minus")
arm_m = mirror(verify("ledger_minus_prod_box28.csv", npts="(128, 128, 80)", cell="minus"))
# `mirror` flips the SIGNS of the minus arm, so the two curves should now lie on top
# of each other. Drawing them that way is the point: if they ever separate, the
# mirror is broken. (arm_p is read under cell="minus" because no box-28 `plus`
# leak_scan row was written — see data/PROVENANCE.md.)

N = min(len(led), len(arm_p), len(arm_m))
idx = list(range(0, N, STRIDE))
print(f"{N} samples, stride {STRIDE} -> {len(idx)} frames "
      f"({', '.join(f'{len(idx)/f:.1f} s at {f} fps' for f in FPS)})")

plt.rcParams.update({
    "font.size": 11, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 100, "axes.axisbelow": True,
})

# 1280x720 at dpi 100 -> even dimensions, which libx264 requires.
fig, (ax, ax2) = plt.subplots(1, 2, figsize=(12.8, 7.2))
fig.subplots_adjust(left=0.07, right=0.985, top=0.855, bottom=0.115, wspace=0.22)

t = led["t"]
for a in (ax, ax2):
    a.axvline(T_STIR, color="k", lw=0.9, ls="--", alpha=0.55)
    a.axhline(0.0, color="k", lw=0.7, alpha=0.4)
    a.set_xlim(t[0], t[N - 1])
    a.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")

lo = min(led["Lz"].min(), led["Fz"].min(), led["Jz"].min())
hi = max(led["Lz"].max(), led["Fz"].max(), led["Jz"].max())
pad = 0.08 * (hi - lo)
ax.set_ylim(lo - pad, hi + pad)
ax.set_ylabel(r"angular momentum  [$\hbar$/atom]")
ax.set_title("box 47: $L_z$ falls, $F_z$ rises, $J_z$ flat once $B=0$", fontsize=12)

lo2 = min(arm_p["Fz"].min(), arm_m["Fz"].min())
hi2 = max(arm_p["Fz"].max(), arm_m["Fz"].max())
pad2 = 0.12 * (hi2 - lo2)
ax2.set_ylim(lo2 - pad2, hi2 + pad2)
ax2.set_ylabel(r"$\langle F_z\rangle$  [$\hbar$/atom]")
ax2.set_title(r"box 28: $-\Omega$ arm sign-flipped onto $+\Omega$" "\n"
              "(they coincide — the mirror is a symmetry)", fontsize=12)

# Faint full traces as the target the drawing fills in.
for a, series in ((ax, (("Lz", "#1b6ca8"), ("Fz", "#c0392b"), ("Jz", "k"))),
                  (ax2, (("Fz", "#1b6ca8"),))):
    src = led if a is ax else arm_p
    for key, col in series:
        a.plot(src["t"][:N], src[key][:N], color=col, lw=1.0, alpha=0.16)
ax2.plot(arm_m["t"][:N], arm_m["Fz"][:N], color="#e08214", lw=1.0, alpha=0.16)

lines = {
    "Lz": ax.plot([], [], color="#1b6ca8", lw=2.4, label=r"$\langle L_z\rangle$  orbital")[0],
    "Fz": ax.plot([], [], color="#c0392b", lw=2.4, label=r"$\langle F_z\rangle$  spin")[0],
    "Jz": ax.plot([], [], color="k", lw=2.9, label=r"$J_z = \langle L_z\rangle+\langle F_z\rangle$")[0],
}
l_plus = ax2.plot([], [], color="#1b6ca8", lw=2.6, label=r"$+\Omega$  (measured)")[0]
l_minus = ax2.plot([], [], color="#e08214", lw=2.6, ls="--",
                   label=r"$-\Omega$, sign-flipped")[0]
dots = [ax.plot([], [], "o", ms=6, color=c)[0] for c in ("#1b6ca8", "#c0392b", "k")]
ax.legend(loc="upper left", framealpha=0.92)
ax2.legend(loc="upper left", framealpha=0.92)

banner = fig.text(0.5, 0.965, "", ha="center", fontsize=15, fontweight="bold")
# The running numbers go INSIDE the left axes: as a figure-level line they sat on
# top of the right panel's title, which is the sort of thing a still frame shows
# and a scrolling animation hides.
readout = ax.text(0.985, 0.30, "", transform=ax.transAxes, ha="right", va="bottom",
                  fontsize=10.5, family="monospace",
                  bbox=dict(boxstyle="round,pad=0.35", fc="white", ec="0.75", alpha=0.9))
fig.text(0.5, 0.022,
         "rotation-driven magnetisation, $^{151}$Eu $F=6$ — "
         r"stir at $\Omega=0.74$, then $B\to 0$",
         ha="center", fontsize=9, alpha=0.7)


def draw(k):
    s = slice(0, k + 1)
    for key, ln in lines.items():
        ln.set_data(t[s], led[key][s])
    for d, key in zip(dots, ("Lz", "Fz", "Jz")):
        d.set_data([t[k]], [led[key][k]])
    l_plus.set_data(arm_p["t"][s], arm_p["Fz"][s])
    l_minus.set_data(arm_m["t"][s], arm_m["Fz"][s])
    stage = "STIR — rotating field injects $L_z$" if t[k] < T_STIR \
        else r"QUENCH  $B=0$ — DDI converts $L_z \to \langle F_z\rangle$"
    banner.set_text(stage)
    readout.set_text(
        f"t    = {t[k]:6.1f}\n"
        f"L_z  = {led['Lz'][k]:+7.3f}\n"
        f"F_z  = {led['Fz'][k]:+7.3f}\n"
        f"J_z  = {led['Jz'][k]:+7.3f}\n"
        f"edge = {led['edge_frac'][k]:.1e}")


with tempfile.TemporaryDirectory() as d:
    for n, k in enumerate(idx):
        draw(k)
        fig.savefig(Path(d) / f"f{n:05d}.png")
        if n % 100 == 0:
            print(f"  rendered {n}/{len(idx)}", flush=True)
    plt.close(fig)
    for fps in FPS:
        out = FIGS / f"anim_ledger_{fps}fps.mp4"
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
               "-i", str(Path(d) / "f%05d.png"), "-c:v", "libx264",
               "-pix_fmt", "yuv420p", "-crf", "18", str(out)]
        subprocess.run(cmd, check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(idx)/fps:.1f} s at {fps} fps)")
