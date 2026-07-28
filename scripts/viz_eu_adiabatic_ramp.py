#!/usr/bin/env python3
"""Figures for the Eu adiabatic-passage protocol (scripts/eu_adiabatic_ramp_protocol.jl).

    python scripts/viz_eu_adiabatic_ramp.py [--data figs/eu_adiabatic_ramp]

Three deliverables:

  1. eu_adiabatic_hysteresis.png   ⟨F⊥⟩ vs B, both ramp directions, one facet per κ.
     The loop between the solid (rising B) and dashed (falling B) curves is the
     signature; the κ ≤ 0.9 facet is the control that must show none.
  2. eu_adiabatic_conversion.png   how far each leg converts vs ramp duration.
     Crossing out of the shaded band = a branch conversion; staying inside it =
     canting along a single branch.
  3. eu_adiabatic_sg_signal.png    the m_F distribution a Stern-Gerlach + TOF shot
     would return at the end of the slowest ramp — what the experiment actually reads.

Colour: τ is a MAGNITUDE, so it gets one hue stepped light→dark (ordinal ramp,
validated); ramp direction is carried by line style, never by hue. κ in fig 2/3 is
an identity, so it takes the first two categorical slots.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

from viz_style import (CAT, INK, INK2, INK3, SURFACE, TAU_RAMP, read_tsv,
                       use_style)

use_style()


def load_runs(data: Path) -> dict[float, dict]:
    """{κ: {"manifest": …, "legs": {(tag, τ): trajectory}}}"""
    runs: dict[float, dict] = {}
    for kdir in sorted(data.glob("k*")):
        man = kdir / "manifest.csv"
        if not man.is_file():
            continue
        kappa = float(kdir.name[1:])
        entry = {"manifest": read_tsv(man), "legs": {}, "pops": {}}
        for f in sorted(kdir.glob("*_tau*.csv")):
            if f.name.endswith("_pops.csv"):
                tag, tau = f.stem[:-5].split("_tau")
                entry["pops"][(tag, float(tau))] = read_tsv(f)
            else:
                tag, tau = f.stem.split("_tau")
                entry["legs"][(tag, float(tau))] = read_tsv(f)
        runs[kappa] = entry
    return runs


# A branch CONVERSION moves ⟨F⊥⟩ by ~2 (polarised 0.8 ↔ flower 2.5+); smooth
# canting along a single branch moves it by ≤ 1. So the span is the discriminator,
# and it needs no threshold to be plotted. A ratio like peak÷median|dF⊥/dB| is NOT:
# it divides by the typical slope, so a nearly flat curve with one small bump
# scores higher than a real conversion (κ=0.8 fall τ=434 ms scores 10.2 on a span
# of 0.76, above the genuine κ=1.8 conversion's 8.0 on a span of 2.92).
MIN_SPAN = 1.3          # ⟨F⊥⟩ change that only a branch conversion produces
MIN_LOCALISATION = 3.0  # peak ÷ mean |dF⊥/dB| — the feature must also be localised


def leg_conversion(leg: dict) -> tuple[float, float, float]:
    """(span, peak |dF⊥/dB|, field of that peak) along one leg.

    The two legs deliberately traverse DIFFERENT field ranges (each starts on the
    branch that is metastable in its own direction), so they probe the lower and
    the upper spinodal respectively. The jump field is reported only when the leg
    both converts (`span ≥ MIN_SPAN`) and does so in a localised way; otherwise
    the field is NaN and the span still carries the information."""
    order = np.argsort(leg["B_uG"])
    b, f = leg["B_uG"][order], leg["fperp"][order]
    if len(b) < 8 or b[-1] - b[0] <= 0:
        return math.nan, math.nan, math.nan
    span = float(f.max() - f.min())
    bs = np.linspace(b[0], b[-1], 400)
    d = np.abs(np.gradient(np.interp(bs, b, f), bs))
    # np.gradient is one-sided at the ends, which inflates the edge bins — a ramp
    # still evolving when it stops would otherwise report a "jump" at its own last
    # point. Only the interior can carry a resolved feature.
    edge = max(1, len(bs) // 25)
    d_in, bs_in = d[edge:-edge], bs[edge:-edge]
    peak = float(d_in.max())
    localised = d.mean() > 0 and peak / float(d.mean()) >= MIN_LOCALISATION
    b_jump = float(bs_in[int(np.argmax(d_in))]) \
        if (span >= MIN_SPAN and localised) else math.nan
    return span, peak, b_jump


def fig_hysteresis(runs: dict, out: Path,
                   b_eq_by_kappa: dict[float, float] | None = None) -> None:
    kappas = sorted(runs, reverse=True)
    # +1.7in for the legend, which sits OUTSIDE the last axes: the curves fill both
    # the upper-left (converted branch) and the right (metastable branch), so an
    # in-axes legend collides with data at some τ whatever corner it picks.
    fig, axes = plt.subplots(1, len(kappas),
                             figsize=(4.6 * len(kappas) + 1.7, 4.0), sharey=True)
    axes = np.atleast_1d(axes)
    b_eq_by_kappa = b_eq_by_kappa or {}
    taus = sorted({t for e in runs.values() for (_, t) in e["legs"]})
    colour = {t: TAU_RAMP[min(i, len(TAU_RAMP) - 1)]
              for i, t in enumerate(taus)}
    ms_per_tau = None

    for ax, kappa in zip(axes, kappas):
        entry = runs[kappa]
        man = entry["manifest"]
        if ms_per_tau is None and len(man["tau"]):
            ms_per_tau = man["tau_ms"][0] / man["tau"][0]
        for (tag, tau), leg in sorted(entry["legs"].items(), key=lambda kv: kv[0][1]):
            ax.plot(leg["B_uG"], leg["fperp"], color=colour[tau],
                    linestyle="-" if tag == "rise" else "--",
                    solid_capstyle="round", dash_capstyle="round")
        # Mark where each leg STARTS. The legs begin at different fields because
        # each is seeded from the converged branch that is metastable in its own
        # direction, and the library has no low-field flower state at κ = 1.8 — so
        # the horizontal break between them is missing data, not physics. The
        # VERTICAL offset at that seam is the physics: two branches coexisting at
        # the same field, separated by δ⟨F⊥⟩.
        seeds = {}
        for tag in ("rise", "fall"):
            legs = [(t, leg) for (g, t), leg in entry["legs"].items() if g == tag]
            if not legs:
                continue
            _, leg = legs[0]
            i = 0 if tag == "rise" else 0
            seeds[tag] = (float(leg["B_uG"][i]), float(leg["fperp"][i]))
            ax.plot(*seeds[tag], marker="D", markersize=9, color=INK2,
                    markeredgecolor=SURFACE, markeredgewidth=2.0, zorder=6)
        # Only meaningful when the two seeds sit at essentially the SAME field —
        # otherwise the vertical offset between them mixes the branch separation
        # with the field dependence along one branch.
        if len(seeds) == 2 and abs(seeds["rise"][0] - seeds["fall"][0]) <= 2.0:
            (b_r, f_r), (b_f, f_f) = seeds["rise"], seeds["fall"]
            gap = abs(f_r - f_f)
            b_mid = 0.5 * (b_r + b_f)
            ax.annotate("", xy=(b_mid, f_r), xytext=(b_mid, f_f),
                        arrowprops=dict(arrowstyle="<->", color=INK2, lw=1.2))
            ax.annotate(f"two branches at the same field\n"
                        f"$\\delta\\langle F_\\perp\\rangle$ = {gap:.2f}"
                        + ("  ⇒ bistable" if gap > 0.3 else "  ⇒ one branch"),
                        xy=(b_mid, 0.5 * (f_r + f_f)), xytext=(12, -6),
                        textcoords="offset points", ha="left", va="center",
                        color=INK2, fontsize=9)
        b_eq = b_eq_by_kappa.get(kappa)
        if b_eq is not None and math.isfinite(b_eq):
            ax.axvline(b_eq, color=INK3, lw=1.2, ls=":")
            ax.annotate(f"$B_{{eq}}$", xy=(b_eq, ax.get_ylim()[1]), xytext=(3, -12),
                        textcoords="offset points", color=INK2, fontsize=9)
        ax.grid(axis="both", alpha=0.9)
        ax.set_axisbelow(True)
        ax.set_xlabel("magnetic field  $B$  [µG]")
        order = "first-order side" if kappa >= 1.0 else "crossover control"
        ax.set_title(f"$\\kappa = {kappa:g}$  ({order})", color=INK)
    axes[0].set_ylabel(r"transverse magnetisation  $\langle F_\perp \rangle$")

    handles = [mpl.lines.Line2D([], [], color=colour[t], lw=2.0,
                                label=f"$\\tau$ = {t * (ms_per_tau or 1.447):.0f} ms")
               for t in taus]
    handles += [
        mpl.lines.Line2D([], [], color=INK2, lw=2.0, ls="-", label="$B$ rising"),
        mpl.lines.Line2D([], [], color=INK2, lw=2.0, ls="--", label="$B$ falling"),
    ]
    axes[-1].legend(handles=handles, loc="upper left", bbox_to_anchor=(1.02, 1.0))
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


def fig_conversion(runs: dict, out: Path) -> None:
    """How far each leg converts, vs ramp duration. Threshold-free: a branch
    conversion moves ⟨F⊥⟩ by ~2, canting along one branch by ≤ 1, so the curve
    crossing the shaded band IS the result. Runs with a resolved jump carry the
    field it happened at."""
    kappas = sorted(runs, reverse=True)
    fig, ax = plt.subplots(figsize=(6.6, 4.2))
    for i, kappa in enumerate(kappas):
        entry, man = runs[kappa], runs[kappa]["manifest"]
        taus = sorted({t for (_, t) in entry["legs"]})
        ms = [float(man["tau_ms"][np.argmin(np.abs(man["tau"] - t))]) for t in taus]
        c = CAT[i % len(CAT)]
        for tag, style in (("fall", "-"), ("rise", "--")):
            spans, jumps = [], []
            for t in taus:
                leg = entry["legs"].get((tag, t))
                s, _, bj = leg_conversion(leg) if leg is not None else (math.nan,) * 3
                spans.append(s)
                jumps.append(bj)
            ax.plot(ms, spans, color=c, linestyle=style, marker="o", markersize=8,
                    markeredgecolor=SURFACE, markeredgewidth=2.0,
                    label=f"$\\kappa$ = {kappa:g}, $B$ {'falling' if tag == 'fall' else 'rising'}")
            for x, y, bj in zip(ms, spans, jumps):
                if math.isfinite(bj):
                    ax.annotate(f"jump at {bj:.0f} µG", xy=(x, y), xytext=(-6, -14),
                                textcoords="offset points", ha="right",
                                color=INK2, fontsize=9)
    ax.axhspan(0, MIN_SPAN, color=INK3, alpha=0.08, linewidth=0)
    ax.annotate("canting along one branch", xy=(ax.get_xlim()[0], MIN_SPAN),
                xytext=(6, -13), textcoords="offset points", color=INK2, fontsize=9)
    ax.set_xscale("log")   # the axis IS the rate scan; τ spans decades
    ax.set_xlabel(r"ramp duration  $\tau$  [ms]")
    ax.set_ylabel(r"$\langle F_\perp \rangle$ change along the leg")
    ax.set_ylim(bottom=0)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    # long handles: solid vs dashed is the ramp direction here, and a short
    # handle with a marker on it reads as dashed either way
    ax.legend(loc="upper left", handlelength=3.2)
    ax.set_title("Only the oblate trap converts, and only when the ramp is slow",
                 color=INK)
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


def fig_sg_signal(runs: dict, out: Path) -> None:
    kappa = max(runs)
    entry = runs[kappa]
    taus = sorted({t for (tag, t) in entry["pops"] if tag == "rise"})
    if not taus:
        print("no population data — skipped SG figure")
        return
    tau = taus[-1]
    fig, ax = plt.subplots(figsize=(6.0, 3.8))
    labels = None
    width = 0.4
    for i, tag in enumerate(("rise", "fall")):
        pops = entry["pops"].get((tag, tau))
        if pops is None:
            continue
        ms = [k for k in pops if k.startswith("m")]
        labels = ms
        vals = [pops[k][-1] for k in ms]
        x = np.arange(len(ms)) + (i - 0.5) * (width + 0.02)
        ax.bar(x, vals, width=width, color=CAT[i],
               label="$B$ rising" if tag == "rise" else "$B$ falling")
    if labels:
        ax.set_xticks(np.arange(len(labels)))
        ax.set_xticklabels([l.replace("m", "$m_F$=") if l == labels[0] else l[1:]
                            for l in labels])
    ax.set_xlabel("Zeeman sublevel  $m_F$")
    ax.set_ylabel("fractional population")
    ax.grid(axis="y", alpha=0.9)
    ax.set_axisbelow(True)
    ax.legend(loc="best")
    ax.set_title(f"Predicted Stern-Gerlach readout, $\\kappa$ = {kappa:g}, "
                 f"end of the slowest ramp", color=INK)
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


def static_b_eq(window_dir: Path) -> dict[float, float]:
    """Energy-crossing field B_eq per κ from the static library analysis."""
    summ = window_dir / "window_summary.csv"
    if not summ.is_file():
        return {}
    t = read_tsv(summ)
    return {float(k): float(v) for k, v in zip(t["κ"], t["B_eq"])}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="figs/eu_adiabatic_ramp", type=Path)
    ap.add_argument("--window", default="figs/eu_adiabatic_window", type=Path)
    ap.add_argument("--out", default="figs", type=Path)
    a = ap.parse_args()

    runs = load_runs(a.data)
    if not runs:
        raise SystemExit(f"no runs under {a.data}")
    a.out.mkdir(parents=True, exist_ok=True)
    fig_hysteresis(runs, a.out / "eu_adiabatic_hysteresis.png",
                   static_b_eq(a.window))
    fig_conversion(runs, a.out / "eu_adiabatic_conversion.png")
    fig_sg_signal(runs, a.out / "eu_adiabatic_sg_signal.png")


if __name__ == "__main__":
    main()
