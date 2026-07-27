"""Shared plot style + TSV reader for the Eu ramp figures.

The palette lives here rather than in each script so the validated values are
stated once. Both were checked with the data-viz validator on the light surface:

  ordinal τ ramp  #86b6ef #5598e7 #2a78d6 #1c5cab #0d366b  — single hue, monotone
                  lightness, light end 2.06:1 vs surface (ALL PASS, --ordinal)
  categorical     #2a78d6 #eb6834 #1baf7a                  — ALL PASS (--pairs all),
                  with one WARN: aqua is 2.74:1 on this surface, so any chart using
                  the third slot must direct-label rather than rely on colour alone

τ is a MAGNITUDE, so it gets the one-hue ordinal ramp; ramp direction is carried by
line style and identity (κ, leg) by the categorical slots. Never colour by rank.
"""
from __future__ import annotations

import csv
from pathlib import Path

import matplotlib as mpl
import numpy as np

TAU_RAMP = ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"]
CAT = ["#2a78d6", "#eb6834", "#1baf7a"]
INK, INK2, INK3 = "#0b0b0b", "#52514e", "#8a8983"
SURFACE = "#fcfcfb"

RC = {
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
    "font.size": 10, "axes.titlesize": 11, "axes.labelsize": 10,
    "text.color": INK, "axes.labelcolor": INK, "axes.edgecolor": INK3,
    "xtick.color": INK2, "ytick.color": INK2,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.linewidth": 0.8, "lines.linewidth": 2.0,
    "grid.color": "#e6e5e1", "grid.linewidth": 0.7,
    "legend.frameon": False, "legend.fontsize": 9,
}


def use_style() -> None:
    mpl.rcParams.update(RC)


def tau_colour(i: int) -> str:
    return TAU_RAMP[min(i, len(TAU_RAMP) - 1)]


def read_tsv(path: Path) -> dict[str, np.ndarray]:
    """writedlm output → column arrays (floats where parseable, else strings)."""
    with Path(path).open() as fh:
        rows = list(csv.reader(fh, delimiter="\t"))
    head, body = rows[0], rows[1:]
    out: dict[str, list] = {h: [] for h in head}
    for r in body:
        if len(r) < len(head):
            continue
        for h, v in zip(head, r):
            try:
                out[h].append(float(v))
            except ValueError:
                out[h].append(v)
    return {k: np.asarray(v) for k, v in out.items()}
