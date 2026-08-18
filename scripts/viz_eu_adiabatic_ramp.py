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


def _split_label(stem: str) -> tuple[str, str, float] | None:
    """`rise_tau100` / `fall_rate1.5` → (tag, kind, value).

    Two indexings coexist on purpose. `tau` was the original: one duration for
    both legs. `rate` is what a two-legged loop over ONE window needs, because at
    fixed τ a wider span is a faster ramp — so a τ-indexed comparison of legs that
    traverse different spans compares two different rates."""
    for kind in ("rate", "tau"):
        sep = "_" + kind
        if sep in stem:
            tag, val = stem.split(sep, 1)
            try:
                return tag, kind, float(val)
            except ValueError:
                return None
    return None


def load_runs(data: Path) -> dict[float, dict]:
    """{κ: {"manifest": …, "legs": {(tag, key): traj}, "pops": …, "index": kind}}

    `key` is the run's ordinal position on the rate axis — the rate in µG/ms when
    the scan was rate-indexed, else τ in ω_ref⁻¹. Both order slow-to-fast, so
    every figure can treat it as one axis."""
    runs: dict[float, dict] = {}
    for kdir in sorted(data.glob("k*")):
        # One manifest per leg: the legs are separate jobs writing into one dir,
        # and a shared file meant the last to finish deleted the other's rows.
        mans = sorted(kdir.glob("manifest*.csv"))
        if not mans:
            continue
        kappa = float(kdir.name[1:])
        merged: dict[str, list] = {}
        for m in mans:
            t = read_tsv(m)
            for k, v in t.items():
                merged.setdefault(k, []).extend(list(v))
        entry: dict = {"manifest": {k: np.asarray(v) for k, v in merged.items()},
                       "legs": {}, "pops": {}, "kinds": set(), "tau_ms": {}}
        for f in sorted(kdir.glob("*.csv")):
            if f.name == "manifest.csv":
                continue
            stem = f.stem[:-5] if f.name.endswith("_pops.csv") else f.stem
            parsed = _split_label(stem)
            if parsed is None:
                continue
            tag, kind, val = parsed
            entry["kinds"].add(kind)
            (entry["pops"] if f.name.endswith("_pops.csv")
             else entry["legs"])[(tag, val)] = read_tsv(f)
        # τ in ms per key, from the manifest, so the legend can quote a duration
        # even when the scan is indexed by rate.
        m = entry["manifest"]
        col = "rate_uG_per_ms" if "rate" in entry["kinds"] else "tau"
        if col in m and "tau_ms" in m:
            for v, ms in zip(m[col], m["tau_ms"]):
                entry["tau_ms"].setdefault(float(v), []).append(float(ms))
        entry["index"] = "rate" if "rate" in entry["kinds"] else "tau"
        runs[kappa] = entry
    return runs


def load_branches(d: Path | None) -> dict[float, list[dict]]:
    """Static branch continuations: {κ: [frames.csv table, …]}.

    These are the τ→∞ reference the ramps have to saturate to. Rows whose order
    parameter was still moving under a stronger polish are dropped — a cell that
    is not settled cannot mark where a branch ends."""
    out: dict[float, list[dict]] = {}
    if d is None or not d.is_dir():
        return out
    for f in sorted(d.glob("**/frames.csv")):
        t = read_tsv(f)
        if "B_uG" not in t or not len(t["B_uG"]):
            continue
        kappa = math.nan
        for part in f.parts:
            if part.startswith("branch_k"):
                try:
                    kappa = float(part.split("branch_k")[1].split("_")[0])
                except (IndexError, ValueError):
                    pass
        if not math.isfinite(kappa):
            continue
        keep = np.ones(len(t["B_uG"]), dtype=bool)
        if "dfperp_polish" in t:
            dfp = np.abs(np.asarray(t["dfperp_polish"], dtype=float))
            keep &= ~(dfp > UNSETTLED)
        t = {k: np.asarray(v)[keep] for k, v in t.items()}
        if len(t["B_uG"]):
            out.setdefault(kappa, []).append(t)
    return out


# A branch CONVERSION moves ⟨F⊥⟩ by ~2 (polarised 0.8 ↔ flower 2.5+); smooth
# canting along a single branch moves it by ≤ 1. So the span is the discriminator,
# and it needs no threshold to be plotted. A ratio like peak÷median|dF⊥/dB| is NOT:
# it divides by the typical slope, so a nearly flat curve with one small bump
# scores higher than a real conversion (κ=0.8 fall τ=434 ms scores 10.2 on a span
# of 0.76, above the genuine κ=1.8 conversion's 8.0 on a span of 2.92).
MIN_SPAN = 1.3          # ⟨F⊥⟩ change that only a branch conversion produces
MIN_LOCALISATION = 3.0  # peak ÷ mean |dF⊥/dB| — the feature must also be localised
UNSETTLED = 0.02        # ⟨F⊥⟩ movement under a stronger polish that disqualifies
# a static cell. |∇E| does not certify a minimum on this
# soft manifold: 3.6e-4 was once 0.59 off in ⟨F⊥⟩.


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


def slow_to_fast(keys, index: str) -> list[float]:
    """Keys ordered fast → slow, whichever axis indexes the scan.

    Colour is the ordinal τ ramp light→dark, and dark has to be the SLOW end: the
    slow ramps carry the verdict. A rate axis runs the other way from a duration
    axis, so the ordering is stated once here instead of at three call sites."""
    return sorted(keys, reverse=(index == "tau"))[::-1] if index == "rate" \
        else sorted(keys)


def key_label(entry: dict, key: float) -> str:
    ms = entry["tau_ms"].get(key)
    if ms:
        return f"$\\tau$ = {min(ms):.0f} ms"
    return (f"{key:g} µG/ms" if entry["index"] == "rate"
            else f"$\\tau$ = {key:g} $\\omega_{{ref}}^{{-1}}$")


def fig_hysteresis(runs: dict, out: Path,
                   b_eq_by_kappa: dict[float, float] | None = None,
                   branches: dict[float, list[dict]] | None = None) -> None:
    kappas = sorted(runs, reverse=True)
    branches = branches or {}
    # +1.7in for the legend, which sits OUTSIDE the last axes: the curves fill both
    # the upper-left (converted branch) and the right (metastable branch), so an
    # in-axes legend collides with data at some τ whatever corner it picks.
    fig, axes = plt.subplots(1, len(kappas),
                             figsize=(4.6 * len(kappas) + 1.7, 4.0), sharey=True)
    axes = np.atleast_1d(axes)
    b_eq_by_kappa = b_eq_by_kappa or {}
    index = next(iter(runs.values()))["index"]
    keys = slow_to_fast({t for e in runs.values() for (_, t) in e["legs"]}, index)
    colour = {t: TAU_RAMP[min(i, len(TAU_RAMP) - 1)] for i, t in enumerate(keys)}

    for ax, kappa in zip(axes, kappas):
        entry = runs[kappa]
        # Static branches first, under the ramps: they are the τ→∞ target, and a
        # ramp curve that stops short of them is showing dynamical lag rather than
        # the spinodal.
        for t in branches.get(kappa, []):
            ax.plot(t["B_uG"], t["fperp"], color=INK3, lw=1.3, ls="-",
                    alpha=0.85, zorder=1)
            ax.plot(t["B_uG"], t["fperp"], color=INK3, marker="o", markersize=2.6,
                    lw=0, alpha=0.85, zorder=1)
        for (tag, key), leg in entry["legs"].items():
            ax.plot(leg["B_uG"], leg["fperp"], color=colour[key],
                    linestyle="-" if tag == "rise" else "--",
                    solid_capstyle="round", dash_capstyle="round", zorder=3)
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
            seeds[tag] = (float(leg["B_uG"][0]), float(leg["fperp"][0]))
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
        # The loop width at the SLOWEST rate, drawn between the two jump fields.
        # Only when both legs actually converted inside the window: a leg that ran
        # out of window gives a lower bound, and drawing a bound as a width is the
        # exact misreading this campaign exists to remove.
        slowest = keys[-1] if keys else None
        r_leg = entry["legs"].get(("rise", slowest))
        f_leg = entry["legs"].get(("fall", slowest))
        if r_leg is not None and f_leg is not None:
            _, _, b_r = leg_conversion(r_leg)
            _, _, b_f = leg_conversion(f_leg)
            if math.isfinite(b_r) and math.isfinite(b_f):
                y = ax.get_ylim()[0] + 0.06 * (ax.get_ylim()[1] - ax.get_ylim()[0])
                ax.annotate("", xy=(b_r, y), xytext=(b_f, y),
                            arrowprops=dict(arrowstyle="<->", color=INK, lw=1.4))
                ax.annotate(f"loop width {abs(b_r - b_f):.1f} µG\n"
                            f"({min(b_f, b_r):.0f} → {max(b_f, b_r):.0f} µG)",
                            xy=(0.5 * (b_r + b_f), y), xytext=(0, 8),
                            textcoords="offset points", ha="center", va="bottom",
                            color=INK, fontsize=9)
            else:
                open_side = "rising" if not math.isfinite(b_r) else "falling"
                ax.annotate(f"no loop width: the {open_side} leg did not convert\n"
                            f"inside the window — lower bound only",
                            xy=(0.5, 0.04), xycoords="axes fraction", ha="center",
                            va="bottom", color=INK2, fontsize=9)
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

    ref = next(iter(runs.values()))
    handles = [mpl.lines.Line2D([], [], color=colour[t], lw=2.0,
                                label=key_label(ref, t)) for t in keys]
    handles += [
        mpl.lines.Line2D([], [], color=INK2, lw=2.0, ls="-", label="$B$ rising"),
        mpl.lines.Line2D([], [], color=INK2, lw=2.0, ls="--", label="$B$ falling"),
    ]
    if branches:
        handles.append(mpl.lines.Line2D([], [], color=INK3, lw=1.3, marker="o",
                                        markersize=3,
                                        label=r"static branch ($\tau \to \infty$)"))
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
        entry = runs[kappa]
        keys = slow_to_fast({t for (_, t) in entry["legs"]}, entry["index"])
        # x axis is the ramp DURATION in ms whichever way the scan was indexed —
        # the physical quantity a reader compares against a trap period.
        ms = [min(entry["tau_ms"].get(t, [math.nan])) for t in keys]
        c = CAT[i % len(CAT)]
        for tag, style in (("fall", "-"), ("rise", "--")):
            spans, jumps = [], []
            for t in keys:
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
    keys = slow_to_fast({t for (tag, t) in entry["pops"] if tag == "rise"},
                        entry["index"])
    if not keys:
        print("no population data — skipped SG figure")
        return
    key = keys[-1]          # slowest
    fig, ax = plt.subplots(figsize=(6.0, 3.8))
    labels = None
    width = 0.4
    for i, tag in enumerate(("rise", "fall")):
        pops = entry["pops"].get((tag, key))
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


def fig_loop_width(runs: dict, out: Path,
                   static: dict[float, float] | None = None) -> None:
    """Loop width vs ramp rate — the figure that carries the verdict.

    Shrinking toward zero as the ramp slows is dynamical lag; saturating is
    bistability and the plateau IS the mean-field spinodal separation; nothing at
    any rate is a crossover. One ramp cannot distinguish these, which is why the
    deliverable is this curve and not a number from the slowest run."""
    static = static or {}
    kappas = sorted(runs, reverse=True)
    fig, ax = plt.subplots(figsize=(6.8, 4.2))
    drew = False
    for i, kappa in enumerate(kappas):
        entry = runs[kappa]
        keys = slow_to_fast({t for (_, t) in entry["legs"]}, entry["index"])
        xs, ws, bounds = [], [], []
        for t in keys:
            r_leg, f_leg = entry["legs"].get(("rise", t)), entry["legs"].get(("fall", t))
            if r_leg is None or f_leg is None:
                continue
            _, _, b_r = leg_conversion(r_leg)
            _, _, b_f = leg_conversion(f_leg)
            x = min(entry["tau_ms"].get(t, [math.nan]))
            xs.append(x)
            ws.append(abs(b_r - b_f) if (math.isfinite(b_r) and math.isfinite(b_f))
                      else math.nan)
            bounds.append(not (math.isfinite(b_r) and math.isfinite(b_f)))
        if not xs:
            continue
        drew = True
        c = CAT[i % len(CAT)]
        ax.plot(xs, ws, color=c, marker="o", markersize=8, markeredgecolor=SURFACE,
                markeredgewidth=2.0, label=f"$\\kappa$ = {kappa:g}")
        # An arm where a leg never converted has NO width. Draw it on the axis as a
        # distinct glyph rather than dropping it: a gap in a line reads as
        # "not run", and "ran and gave no closed loop" is a different statement.
        for x, isb in zip(xs, bounds):
            if isb:
                ax.plot([x], [0.0], marker="x", markersize=9, color=c, lw=0)
        s = static.get(kappa)
        if s is not None and math.isfinite(s):
            ax.axhline(s, color=c, lw=1.2, ls=":")
            ax.annotate(f"static spinodal separation, $\\kappa$={kappa:g}: {s:.0f} µG",
                        xy=(min(xs), s), xytext=(4, 4), textcoords="offset points",
                        color=c, fontsize=9)
    if not drew:
        print("no paired legs — skipped loop-width figure")
        plt.close(fig)
        return
    ax.plot([], [], marker="x", color=INK2, lw=0,
            label="one leg did not convert (no width)")
    ax.set_xscale("log")
    ax.set_xlabel(r"ramp duration  $\tau$  [ms]")
    ax.set_ylabel("hysteresis loop width  [µG]")
    ax.set_ylim(bottom=0)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    ax.legend(loc="best")
    ax.set_title("Loop width vs ramp rate: saturation is bistability, "
                 "decay to zero is lag", color=INK)
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


def static_spinodal_separation(branches: dict[float, list[dict]]) -> dict[float, float]:
    """Separation between the two branch endpoints per κ, from the static scans.

    Each continuation ends where its branch stops existing, so the two extreme
    fields at which the branches are still DISTINCT bound the loop. Returned only
    when two branches are present and actually separated in ⟨F⊥⟩ — one merged
    branch has no separation, which is what a crossover looks like statically."""
    out: dict[float, float] = {}
    for kappa, tables in branches.items():
        if len(tables) < 2:
            continue
        # Order by mean ⟨F⊥⟩: the flower branch is the high one.
        tables = sorted(tables, key=lambda t: float(np.mean(t["fperp"])))
        lo, hi = tables[0], tables[-1]
        # Fields where both branches exist AND differ by more than canting.
        common = [b for b in hi["B_uG"] if lo["B_uG"].min() <= b <= lo["B_uG"].max()]
        if not common:
            continue
        d = [abs(float(np.interp(b, np.sort(hi["B_uG"]),
                                 hi["fperp"][np.argsort(hi["B_uG"])]))
                 - float(np.interp(b, np.sort(lo["B_uG"]),
                                   lo["fperp"][np.argsort(lo["B_uG"])])))
             for b in common]
        sep = [b for b, dd in zip(common, d) if dd >= MIN_SPAN]
        if len(sep) >= 2:
            out[kappa] = max(sep) - min(sep)
    return out


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
    ap.add_argument("--branches", default=None, type=Path,
                    help="dir holding branch_k*/frames.csv from the static "
                         "continuations — the τ→∞ reference to overlay")
    ap.add_argument("--prefix", default="eu_adiabatic",
                    help="output filename prefix")
    ap.add_argument("--out", default="figs", type=Path)
    a = ap.parse_args()

    runs = load_runs(a.data)
    if not runs:
        raise SystemExit(f"no runs under {a.data}")
    branches = load_branches(a.branches)
    a.out.mkdir(parents=True, exist_ok=True)
    fig_hysteresis(runs, a.out / f"{a.prefix}_hysteresis.png",
                   static_b_eq(a.window), branches)
    fig_conversion(runs, a.out / f"{a.prefix}_conversion.png")
    fig_sg_signal(runs, a.out / f"{a.prefix}_sg_signal.png")
    fig_loop_width(runs, a.out / f"{a.prefix}_loop_width.png",
                   static_spinodal_separation(branches))


if __name__ == "__main__":
    main()
