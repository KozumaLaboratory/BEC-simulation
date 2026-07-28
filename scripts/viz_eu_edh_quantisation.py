#!/usr/bin/env python3
"""Is the trap-shaping spin→orbital transfer quantised? — one graph, one answer.

    python scripts/viz_eu_edh_quantisation.py [--data figs/eu_kappa_scan]

⟨L_z⟩ acquired by the ramp rises smoothly and without steps as the endpoint
oblateness κ_1 grows, while the part of it carried by quantised vortices,
Σ_m n_m ℓ_m, stays identically zero. J_z is flat throughout — the trap is axially
symmetric, so the whole transfer happens inside one sector.

Read together: the angular momentum is smooth circulation (a rotating texture),
not vortices, and the "exactly 1 ħ" seen at κ_1 = 1.8 was a coincidence of that
particular span.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from viz_style import CAT, INK, INK2, INK3, SURFACE, read_tsv, use_style


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="figs/eu_kappa_scan", type=Path)
    ap.add_argument("--out", default="figs/eu_edh_quantisation.png", type=Path)
    a = ap.parse_args()

    d = read_tsv(a.data / "edh_quantisation.csv")
    k = d["kappa_1"]
    order = np.argsort(k)
    k = k[order]

    use_style()
    fig, ax = plt.subplots(figsize=(6.8, 4.4))

    for key, colour, label in (
        ("Lz", CAT[1], r"$\langle L_z \rangle$  acquired"),
        ("Lz_quantised", CAT[0], r"$\sum_m n_m \ell_m$  carried by vortices"),
        ("Jz", CAT[2], r"$J_z$  (conserved)"),
    ):
        y = d[key][order]
        ax.plot(k, y, color=colour, marker="o", markersize=8,
                markeredgecolor=SURFACE, markeredgewidth=2.0)
        # direct labels: the third slot is below 3:1 on this surface, so the
        # palette's relief rule requires labels rather than colour alone
        ax.annotate(label, xy=(k[-1], y[-1]), xytext=(8, 0),
                    textcoords="offset points", va="center", color=colour,
                    fontsize=9, fontweight="medium")

    ax.axhline(0.0, color=INK3, lw=0.8)
    # a staircase would sit on these; the data does not
    for step in (-1.0, -2.0):
        ax.axhline(step, color=INK3, lw=0.8, ls=":", alpha=0.7)
    ax.annotate("integer steps a quantised\ntransfer would sit on",
                xy=(k[0], -1.0), xytext=(6, -26), textcoords="offset points",
                color=INK2, fontsize=9)

    ax.set_xlabel(r"ramp endpoint oblateness  $\kappa_1$   (from $\kappa_0 = 0.8$)")
    ax.set_ylabel(r"angular momentum per atom  [$\hbar$]")
    ax.set_title("Trap shaping converts spin to orbital — smoothly, not in quanta",
                 color=INK)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    ax.set_xlim(k[0] - 0.05, k[-1] + 0.55)
    fig.tight_layout()
    a.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(a.out, dpi=200)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
