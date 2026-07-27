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

from viz_style import CAT, INK, INK2, INK3, SURFACE, read_tsv, tau_colour, use_style


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
    fig, ax = plt.subplots(figsize=(6.4, 4.4))

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
    ax.legend(handles=handles, loc="best")

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


if __name__ == "__main__":
    main()
