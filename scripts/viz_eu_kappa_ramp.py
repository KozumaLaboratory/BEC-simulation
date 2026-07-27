#!/usr/bin/env python3
"""Figure for the Eu κ-ramp (trap-shaping) preparation protocol.

    python scripts/viz_eu_kappa_ramp.py [--data figs/eu_kappa_ramp/B020]

One graph carries the whole result, because the protocol is a round trip at fixed
field: plotting ⟨F⊥⟩ against κ traces the path out and back, so a single panel
shows all three things at once —

  tracking      does the state stay on the flower branch across κ_tc ≈ 0.95
  reversibility does the return leg close onto the start (open ⇒ a κ-axis loop)
  rate          one curve per ramp duration τ, light → dark

The two reference branches converged independently at (κ_end, B_hold) are drawn as
horizontal markers: they are what turns the endpoint from a number into "flower" or
"polarised".
"""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.lines as mlines
import matplotlib.pyplot as plt
import numpy as np

from viz_style import (CAT, INK, INK2, INK3, SURFACE, read_tsv, tau_colour,
                       use_style)


def fig_angular_momentum(data: Path, out: Path) -> None:
    """Why no ramp reaches the ground state: J_z is conserved and the target sits
    in a different sector.

    A trap deformation about z is axially symmetric, so J_z is a constant of the
    motion up to the tiny pin — and the flower ground state is 2.07 ħ away in J_z.
    L_z and S_z do move, trading exactly one unit (Einstein–de Haas), which is what
    the ramp CAN do inside its sector."""
    runs = [p for p in sorted(data.glob("kramp*_tau*.csv"))
            if not p.name.endswith("_pops.csv")]
    if not runs:
        raise SystemExit(f"no κ-ramp runs under {data}")
    ref = data / "reference_branches.csv"
    gs = None
    if ref.is_file():
        r = read_tsv(ref)
        for anchor, jz in zip(r["anchor"], r["Jz"]):
            if "flower" in str(anchor):
                gs = float(jz)

    use_style()
    fig, ax = plt.subplots(figsize=(6.8, 4.4))
    slowest = max(runs, key=lambda p: float(p.stem.split("_tau")[1]))

    # every other run, faintly, on J_z only — they all lie on top of each other,
    # which IS the point: neither rate nor shape moves the sector
    for p in runs:
        d = read_tsv(p)
        turn = int(np.argmax(d["kappa"]))
        ax.plot(d["kappa"][:turn + 1], d["Jz"][:turn + 1], color=CAT[0],
                lw=1.0, alpha=0.35)

    d = read_tsv(slowest)
    turn = int(np.argmax(d["kappa"]))
    k = d["kappa"][:turn + 1]
    for key, colour, label in (("Jz", CAT[0], r"$J_z = L_z + S_z$"),
                               ("Sz", CAT[2], r"$S_z$  (spin)"),
                               ("Lz", CAT[1], r"$L_z$  (orbital)")):
        y = d[key][:turn + 1]
        ax.plot(k, y, color=colour, lw=2.0)
        # direct labels: the aqua slot is below 3:1 on this surface, so the
        # palette's relief rule requires labels rather than legend colour alone
        ax.annotate(label, xy=(k[-1], y[-1]), xytext=(6, 0),
                    textcoords="offset points", va="center", color=colour,
                    fontsize=9, fontweight="medium")

    if gs is not None:
        ax.axhline(gs, color=INK3, lw=1.4, ls=":")
        ax.annotate(f"flower ground state, $J_z$ = {gs:.2f}",
                    xy=(k[0], gs), xytext=(4, 6), textcoords="offset points",
                    color=INK2, fontsize=9)
        ax.annotate("", xy=(1.25, gs), xytext=(1.25, float(d["Jz"][turn])),
                    arrowprops=dict(arrowstyle="<->", color=INK2, lw=1.2))
        ax.annotate(f"{abs(gs - float(d['Jz'][turn])):.2f} $\\hbar$ per atom\n"
                    "unreachable by any axially\nsymmetric ramp",
                    xy=(1.25, 0.5 * (gs + float(d["Jz"][turn]))), xytext=(8, 0),
                    textcoords="offset points", va="center", color=INK2, fontsize=9)

    ax.set_xlabel(r"trap oblateness  $\kappa = \omega_z / \omega_\perp$")
    ax.set_ylabel(r"angular momentum per atom  [$\hbar$]")
    ax.set_title("The obstruction is a selection rule, not a ramp rate", color=INK)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    ax.set_xlim(k[0] - 0.02, k[-1] + 0.22)
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="figs/eu_kappa_ramp/B020", type=Path)
    ap.add_argument("--out", default="figs/eu_kappa_ramp_preparation.png", type=Path)
    a = ap.parse_args()

    runs = sorted(a.data.glob("kramp_tau*.csv"))
    runs = [p for p in runs if not p.name.endswith("_pops.csv")]
    if not runs:
        raise SystemExit(f"no κ-ramp runs under {a.data}")
    man = read_tsv(a.data / "manifest.csv") if (a.data / "manifest.csv").is_file() else None

    use_style()
    # +1.8in for the legend outside the axes: the curves sweep the whole κ range
    # and the reference markers sit at the right edge, so an in-axes legend
    # collides with one or the other.
    fig, ax = plt.subplots(figsize=(8.2, 4.4))

    taus = sorted(float(p.stem.split("_tau")[1]) for p in runs)
    ms_per_tau = None
    if man is not None and len(man["tau"]):
        ms_per_tau = float(man["tau_ms"][0] / man["tau"][0])

    for i, tau in enumerate(taus):
        d = read_tsv(a.data / f"kramp_tau{tau:g}.csv")
        k, fp, t = d["kappa"], d["fperp"], d["t"]
        # split the outbound and return legs at the κ turning point
        turn = int(np.argmax(k))
        c = tau_colour(i)
        ax.plot(k[:turn + 1], fp[:turn + 1], color=c, solid_capstyle="round")
        if turn < len(k) - 1:
            ax.plot(k[turn:], fp[turn:], color=c, linestyle="--",
                    dash_capstyle="round")

    # reference branches at the endpoint κ
    ref_path = a.data / "reference_branches.csv"
    if ref_path.is_file():
        ref = read_tsv(ref_path)
        for anchor, fperp, kappa in zip(ref["anchor"], ref["fperp"], ref["kappa"]):
            colour = CAT[0] if "flower" in str(anchor) else CAT[1]
            ax.plot([kappa], [fperp], marker="D", markersize=9, color=colour,
                    markeredgecolor=SURFACE, markeredgewidth=2.0, zorder=5)
            ax.annotate(f"{anchor} GS", xy=(kappa, fperp), xytext=(-8, 0),
                        textcoords="offset points", ha="right", va="center",
                        color=INK2, fontsize=9)

    kappa_tc = 0.95
    ax.axvline(kappa_tc, color=INK3, lw=1.2, ls=":")
    ax.annotate(r"$\kappa_{tc} \approx 0.95$", xy=(kappa_tc, ax.get_ylim()[1]),
                xytext=(4, -12), textcoords="offset points", color=INK2, fontsize=9)

    handles = [mlines.Line2D([], [], color=tau_colour(i), lw=2.0,
                             label=f"$\\tau$ = {t * (ms_per_tau or 1.447):.0f} ms")
               for i, t in enumerate(taus)]
    handles += [
        mlines.Line2D([], [], color=INK2, lw=2.0, ls="-", label=r"$\kappa$ increasing"),
        mlines.Line2D([], [], color=INK2, lw=2.0, ls="--", label="return leg"),
    ]
    ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.02, 1.0),
              handlelength=3.2)

    b_hold = float(man["B_uG"][0]) if man is not None else float("nan")
    ax.set_xlabel(r"trap oblateness  $\kappa = \omega_z / \omega_\perp$")
    ax.set_ylabel(r"transverse magnetisation  $\langle F_\perp \rangle$")
    ax.set_title(f"Preparing the flower ground state by trap shaping at "
                 f"$B$ = {b_hold:.0f} µG", color=INK)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    fig.tight_layout()
    a.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(a.out, dpi=200)
    print(f"wrote {a.out}")

    fig_angular_momentum(a.data, a.out.with_name("eu_kappa_ramp_jz.png"))


if __name__ == "__main__":
    main()
