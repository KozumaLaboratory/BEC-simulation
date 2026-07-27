#!/usr/bin/env python3
"""Figures for the Eu adiabatic-passage protocol (scripts/eu_adiabatic_ramp_protocol.jl).

    python scripts/viz_eu_adiabatic_ramp.py [--data figs/eu_adiabatic_ramp]

Three deliverables:

  1. eu_adiabatic_hysteresis.png   ⟨F⊥⟩ vs B, both ramp directions, one facet per κ.
     The loop between the solid (rising B) and dashed (falling B) curves is the
     signature; the κ ≤ 0.9 facet is the control that must show none.
  2. eu_adiabatic_loop_width.png   mean branch separation ⟨|Δ⟨F⊥⟩|⟩ vs ramp
     duration. Saturating ⇒ bistability; decaying to zero ⇒ the loop was only
     dynamical lag. The static (τ → ∞) δ⟨F⊥⟩ from the GS library is the target line.
  3. eu_adiabatic_sg_signal.png    the m_F distribution a Stern-Gerlach + TOF shot
     would return at the end of the slowest ramp — what the experiment actually reads.

Colour: τ is a MAGNITUDE, so it gets one hue stepped light→dark (ordinal ramp,
validated); ramp direction is carried by line style, never by hue. κ in fig 2/3 is
an identity, so it takes the first two categorical slots.
"""
from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np

# --- palette (validated: ordinal blue ramp, categorical slots 1–2) ------------
TAU_RAMP = ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"]
CAT = ["#2a78d6", "#eb6834"]
INK, INK2, INK3 = "#0b0b0b", "#52514e", "#8a8983"
SURFACE = "#fcfcfb"

mpl.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
    "font.size": 10, "axes.titlesize": 11, "axes.labelsize": 10,
    "text.color": INK, "axes.labelcolor": INK, "axes.edgecolor": INK3,
    "xtick.color": INK2, "ytick.color": INK2,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.linewidth": 0.8, "lines.linewidth": 2.0,
    "grid.color": "#e6e5e1", "grid.linewidth": 0.7,
    "legend.frameon": False, "legend.fontsize": 9,
})


def read_tsv(path: Path) -> dict[str, np.ndarray]:
    with path.open() as fh:
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


def branch_separation(rise: dict, fall: dict) -> tuple[float, float, float]:
    """Mean |Δ⟨F⊥⟩| between the two legs over their OVERLAPPING field range,
    plus that range. Threshold-free stand-in for the loop area: identically zero
    for a crossover, finite while two branches coexist."""
    b_lo = max(rise["B_uG"].min(), fall["B_uG"].min())
    b_hi = min(rise["B_uG"].max(), fall["B_uG"].max())
    if not (b_hi > b_lo):
        return math.nan, math.nan, math.nan
    bs = np.linspace(b_lo, b_hi, 200)

    def interp(leg):
        order = np.argsort(leg["B_uG"])
        return np.interp(bs, leg["B_uG"][order], leg["fperp"][order])

    return float(np.mean(np.abs(interp(rise) - interp(fall)))), b_lo, b_hi


def fig_hysteresis(runs: dict, out: Path) -> None:
    kappas = sorted(runs, reverse=True)
    fig, axes = plt.subplots(1, len(kappas), figsize=(4.6 * len(kappas), 4.0),
                             sharey=True)
    axes = np.atleast_1d(axes)
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
    axes[-1].legend(handles=handles, loc="best", ncol=1)
    fig.suptitle("Adiabatic passage through the weak-field $^{151}$Eu transition",
                 y=0.99, color=INK)
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


def fig_loop_width(runs: dict, out: Path, static_ref: dict[float, float]) -> None:
    fig, ax = plt.subplots(figsize=(5.4, 4.0))
    for i, kappa in enumerate(sorted(runs, reverse=True)):
        entry = runs[kappa]
        taus, seps = [], []
        for tau in sorted({t for (_, t) in entry["legs"]}):
            rise, fall = entry["legs"].get(("rise", tau)), entry["legs"].get(("fall", tau))
            if rise is None or fall is None:
                continue
            sep, *_ = branch_separation(rise, fall)
            man = entry["manifest"]
            ms = man["tau_ms"][np.argmin(np.abs(man["tau"] - tau))]
            taus.append(ms)
            seps.append(sep)
        if not taus:
            continue
        c = CAT[i % len(CAT)]
        ax.plot(taus, seps, color=c, marker="o", markersize=8,
                markeredgecolor=SURFACE, markeredgewidth=2.0,
                label=f"$\\kappa = {kappa:g}$")
        ref = static_ref.get(kappa)
        if ref is not None:
            ax.axhline(ref, color=c, lw=1.2, ls=":", alpha=0.8)
            ax.annotate(f"static $\\delta\\langle F_\\perp\\rangle$ = {ref:.2f}",
                        xy=(taus[-1], ref), xytext=(-4, 5),
                        textcoords="offset points", ha="right",
                        color=INK2, fontsize=8)
    ax.set_xscale("log")   # ramp durations span decades; the axis IS the rate scan
    ax.set_xlabel(r"ramp duration  $\tau$  [ms]")
    ax.set_ylabel(r"mean branch separation  $\langle |\Delta \langle F_\perp\rangle| \rangle$")
    ax.set_ylim(bottom=0)
    ax.grid(alpha=0.9)
    ax.set_axisbelow(True)
    ax.legend(loc="best")
    ax.set_title("Saturating = bistable; decaying = dynamical lag", color=INK)
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


def static_separation(window_dir: Path) -> dict[float, float]:
    """δ⟨F⊥⟩ at the energy crossing from the static library analysis, if present."""
    summ = window_dir / "window_summary.csv"
    if not summ.is_file():
        return {}
    t = read_tsv(summ)
    return {float(k): float(v) for k, v in zip(t["κ"], t["dfperp_max"])}


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
    fig_hysteresis(runs, a.out / "eu_adiabatic_hysteresis.png")
    fig_loop_width(runs, a.out / "eu_adiabatic_loop_width.png",
                   static_separation(a.window))
    fig_sg_signal(runs, a.out / "eu_adiabatic_sg_signal.png")


if __name__ == "__main__":
    main()
