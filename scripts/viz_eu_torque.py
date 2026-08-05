#!/usr/bin/env python3
"""Why neither route reaches the flower ground state — the whole argument in one plane.

    python scripts/viz_eu_torque.py [--data figs/eu_torque/k1.80_B020]

Every trajectory here lives at the SAME (κ = 1.8, B = 20 µG), so energies are
directly comparable. Plotted against J_z:

  the start          what a ramp can prepare: J_z = −3.15, already +0.32 above the GS
  the trajectories   a rotating transverse field DOES open the J_z sector — it moves
                     right — but it is a drive on a closed system, so it does work and
                     only ever moves UP
  the target         the flower ground state, bottom right

Nothing approaches the corner. A ramp cannot change J_z; a drive cannot lower E.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.lines as mlines
import matplotlib.pyplot as plt
import numpy as np

from viz_style import CAT, INK, INK2, INK3, SURFACE, read_tsv, use_style

E_GS = 10.731432          # flower ground state at (κ=1.8, B=20 µG), |∇E| ~ 9e-6
JZ_GS = -1.087258
E_POLAR = 10.864086       # the other converged branch there
JZ_POLAR = -1.258727


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="figs/eu_torque/k1.80_B020", type=Path)
    ap.add_argument("--out", default="figs/eu_torque_landscape.png", type=Path)
    a = ap.parse_args()

    runs = sorted(p for p in a.data.glob("torque_eps*_om*.csv")
                  if not p.name.endswith("_final.csv"))
    if not runs:
        raise SystemExit(f"no torque runs under {a.data}")
    man = read_tsv(a.data / "manifest.csv")
    best = int(np.argmax(man["dJz"]))
    best_name = f"torque_eps{man['eps'][best]:g}_om{man['omega'][best]:g}.csv"

    use_style()
    fig, ax = plt.subplots(figsize=(7.0, 4.6))

    # every cell, thin and neutral — that they all do the same thing IS the message
    for p in runs:
        d = read_tsv(p)
        ax.plot(d["Jz"], d["E"] - E_GS, color=INK3, lw=1.1, alpha=0.55)

    d = read_tsv(a.data / best_name)
    ax.plot(d["Jz"], d["E"] - E_GS, color=CAT[1], lw=2.4, solid_capstyle="round",
            zorder=4)
    # direction of travel
    i = len(d["Jz"]) // 2
    ax.annotate("", xy=(d["Jz"][i + 4], d["E"][i + 4] - E_GS),
                xytext=(d["Jz"][i], d["E"][i] - E_GS),
                arrowprops=dict(arrowstyle="-|>", color=CAT[1], lw=2.0), zorder=5)
    ax.annotate(f"strongest drive\n{man['eps_uG'][best]:.1f} µG at "
                f"{man['omega_hz'][best]:.0f} Hz",
                xy=(d["Jz"][-1], d["E"][-1] - E_GS), xytext=(-6, 10),
                textcoords="offset points", ha="right", color=CAT[1], fontsize=9)

    start = (d["Jz"][0], d["E"][0] - E_GS)
    ax.plot(*start, marker="o", markersize=10, color=CAT[0],
            markeredgecolor=SURFACE, markeredgewidth=2.0, zorder=6)
    ax.annotate("what a ramp can prepare", xy=start, xytext=(10, 6),
                textcoords="offset points", color=CAT[0], fontsize=9)

    ax.plot(JZ_GS, 0.0, marker="*", markersize=18, color=CAT[2],
            markeredgecolor=SURFACE, markeredgewidth=1.5, zorder=6)
    ax.annotate("flower ground state", xy=(JZ_GS, 0.0), xytext=(-8, 8),
                textcoords="offset points", ha="right", color=CAT[2], fontsize=9,
                fontweight="medium")
    ax.plot(JZ_POLAR, E_POLAR - E_GS, marker="D", markersize=8, color=INK2,
            markeredgecolor=SURFACE, markeredgewidth=1.5, zorder=6)
    ax.annotate("polarised branch", xy=(JZ_POLAR, E_POLAR - E_GS), xytext=(-8, -4),
                textcoords="offset points", ha="right", va="top", color=INK2,
                fontsize=9)

    ax.axhline(0.0, color=INK3, lw=0.8, ls=":")
    ax.set_xlabel(r"$J_z$ per atom  [$\hbar$]")
    ax.set_ylabel(r"energy above the ground state  $E - E_{GS}$")
    ax.set_title("A ramp cannot change $J_z$; a drive cannot lower $E$", color=INK)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    ax.set_ylim(bottom=-0.06)
    ax.legend(handles=[
        mlines.Line2D([], [], color=INK3, lw=1.1, label="other (ε, Ω) cells"),
    ], loc="upper left")
    fig.tight_layout()
    a.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(a.out, dpi=200)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
