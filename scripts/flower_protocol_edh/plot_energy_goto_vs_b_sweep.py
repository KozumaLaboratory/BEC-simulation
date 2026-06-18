#!/usr/bin/env python3
"""
Compare Goto RTP and LBFGS B-sweep energies over the shared high-B window.

Left panel:
  Goto RTP energy E(t) with the shared B window highlighted.

Right panel:
  Relative energy change ΔE(B) = E(B) - E(65 μG) for
  - the B-sweep waypoint ground states
  - the Goto RTP trajectory restricted to the overlapping B interval

The shared interval is tiny for the current data set:
  B ∈ [min(B_goto), 65 μG] ≈ [63.964, 65] μG
"""
import os
import numpy as np
import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "axes.linewidth": 0.8,
})

ROOT = os.environ.get("FPE_ROOT", "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
GOTO_H5 = os.environ.get("GOTO_H5", os.path.join(ROOT, "rtp_10mG_goto.h5"))
BSWEEP_H5 = os.environ.get("BSWEEP_H5", os.path.join(ROOT, "b_sweep.h5"))
OUT_PNG = os.environ.get("OUT_PNG", os.path.join(ROOT, "goto_vs_b_sweep_energy_compare.png"))


def _load_goto(path):
    with h5py.File(path, "r") as f:
        t = f["t"][:]
        E = f["E"][:]
        B_uG = f["B_gauss"][:] * 1e6
        omega_ref = float(f["meta/omega_ref"][()])
    order = np.argsort(B_uG)
    return t[order], E[order], B_uG[order], E[order], omega_ref


def _load_b_sweep(path):
    with h5py.File(path, "r") as f:
        B_uG = f["B_uG"][:]
        E = f["E"][:]
    order = np.argsort(B_uG)[::-1]
    return B_uG[order], E[order]


t_sorted, E_goto, B_goto_asc, E_goto_asc, omega_ref = _load_goto(GOTO_H5)
B_sweep, E_sweep = _load_b_sweep(BSWEEP_H5)
t_ms = t_sorted / omega_ref * 1000.0

B_hi = float(min(np.max(B_goto_asc), np.max(B_sweep)))
B_lo = float(max(np.min(B_goto_asc), np.min(B_sweep)))
if not (B_lo < B_hi):
    raise RuntimeError(f"no B overlap between Goto and B-sweep: [{B_lo}, {B_hi}]")

# Reference energy at the common high-B endpoint, B = 65 μG.
B_ref = float(np.max(B_sweep))
E_ref_sweep = float(E_sweep[np.argmax(B_sweep)])
E_ref_goto = float(np.interp(B_ref, B_goto_asc, E_goto_asc))

# Goto curve on the shared interval.
B_grid = np.linspace(B_lo, B_ref, 256)
E_goto_grid = np.interp(B_grid, B_goto_asc, E_goto_asc)
DE_goto_grid = E_goto_grid - E_ref_goto
DE_sweep = E_sweep - E_ref_sweep

# Time of the common endpoint in the RTP trajectory.
t_ref = float(np.interp(B_ref, B_goto_asc, t_ms))
t_lo = float(np.interp(B_lo, B_goto_asc, t_ms))

print(f"Goto H5   : {GOTO_H5}")
print(f"B-sweep H5: {BSWEEP_H5}")
print(f"Shared B  : [{B_lo:.6f}, {B_hi:.6f}] μG")
print(f"Goto endpoint at 65 μG: t={t_ref:.2f} ms, E={E_ref_goto:.6f}")
print(f"Overlap width: {B_ref - B_lo:.6f} μG")

fig = plt.figure(figsize=(14.5, 6.8))
gs = fig.add_gridspec(1, 2, width_ratios=[1.05, 1.15], wspace=0.26,
                      left=0.06, right=0.98, top=0.90, bottom=0.12)

ax_t = fig.add_subplot(gs[0, 0])
ax_b = fig.add_subplot(gs[0, 1])

# Left: Goto energy vs time with the overlap tail highlighted.
ax_t.plot(t_ms, E_goto, color="black", lw=1.6, label="Goto RTP")
ax_t.axvspan(t_lo, t_ref, color="#ffcc99", alpha=0.35, lw=0)
ax_t.axvline(t_ref, color="#cc5500", lw=1.2, ls="--")
ax_t.set_xlabel("t [ms]")
ax_t.set_ylabel("E")
ax_t.set_title("Goto RTP: continuous E(t)")
ax_t.grid(alpha=0.25)
ax_t.text(
    0.03, 0.04,
    f"shared B window\n[{B_lo:.3f}, {B_ref:.0f}] μG\nΔB = {B_ref - B_lo:.3f} μG",
    transform=ax_t.transAxes,
    fontsize=10,
    va="bottom",
    ha="left",
    bbox=dict(boxstyle="round,pad=0.25", facecolor="white", edgecolor="#bbbbbb", alpha=0.92),
)

# Right: relative energy change vs B.
ax_b.plot(B_sweep, DE_sweep, "o-", color="black", lw=1.6, markersize=5,
          label="B-sweep waypoints")
ax_b.plot(B_grid, DE_goto_grid, color="#d62728", lw=2.0,
          label="Goto RTP (interpolated in shared window)")
ax_b.scatter([B_ref], [0.0], s=40, color="#d62728", zorder=5)
ax_b.set_xlabel("B [μG]")
ax_b.set_ylabel(r"$\Delta E = E(B) - E(65\,\mu\mathrm{G})$")
ax_b.set_title("Relative energy change vs B")
ax_b.grid(alpha=0.25)
ax_b.legend(frameon=False, loc="upper left")
ax_b.invert_xaxis()

# Zoom inset on the shared interval.
ax_in = inset_axes(ax_b, width="42%", height="42%", loc="lower left", borderpad=1.2)
ax_in.plot(B_sweep, DE_sweep, "o-", color="black", lw=1.1, markersize=4)
ax_in.plot(B_grid, DE_goto_grid, color="#d62728", lw=1.5)
ax_in.set_xlim(B_ref + 0.05, B_lo - 0.02)
ax_in.set_ylim(min(np.min(DE_goto_grid), np.min(DE_sweep)) - 0.05,
               max(np.max(DE_goto_grid), np.max(DE_sweep)) + 0.05)
ax_in.invert_xaxis()
ax_in.grid(alpha=0.20)
ax_in.set_title("shared window", fontsize=9)
ax_in.tick_params(labelsize=8)

fig.suptitle(
    "Goto RTP vs LBFGS B-sweep energy evolution",
    fontsize=14, y=0.97,
)

fig.savefig(OUT_PNG, dpi=220)
print(f"wrote {OUT_PNG}")
