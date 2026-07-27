#!/usr/bin/env python3
"""Figures for the Eu adiabatic-passage protocol (scripts/eu_adiabatic_ramp_protocol.jl).

    python scripts/viz_eu_adiabatic_ramp.py [--data figs/eu_adiabatic_ramp]

Three deliverables:

  1. eu_adiabatic_hysteresis.png   ⟨F⊥⟩ vs B, both ramp directions, one facet per κ.
     The loop between the solid (rising B) and dashed (falling B) curves is the
     signature; the κ ≤ 0.9 facet is the control that must show none.
  2. eu_adiabatic_loop_edges.png   the spinodal pair — the field at which ⟨F⊥⟩
     jumps on each leg — vs ramp duration. Saturating ⇒ bistability; closing onto
     B_eq ⇒ the loop was only dynamical lag; no jump at all ⇒ crossover.
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


def jump_field(leg: dict, sharpness: float = 3.0) -> tuple[float, float]:
    """Field at which ⟨F⊥⟩ changes fastest along one leg — the spinodal, where
    the metastable branch stops existing — and how sharp that feature is
    (max|dF⊥/dB| ÷ median|dF⊥/dB|).

    The two legs deliberately traverse DIFFERENT field ranges (each starts on the
    branch that is metastable in its own direction), so they probe the lower and
    upper spinodal respectively; the loop is the pair, not an overlap area.
    `sharpness ≤ 3` means no localised jump — a smooth crossover response — and
    returns NaN rather than the argmax of noise."""
    order = np.argsort(leg["B_uG"])
    b, f = leg["B_uG"][order], leg["fperp"][order]
    if len(b) < 8 or b[-1] - b[0] <= 0:
        return math.nan, math.nan
    bs = np.linspace(b[0], b[-1], 400)
    d = np.abs(np.gradient(np.interp(bs, b, f), bs))
    med = float(np.median(d))
    if med <= 0:
        return math.nan, math.nan
    sharp = float(d.max() / med)
    return (float(bs[int(np.argmax(d))]) if sharp > sharpness else math.nan), sharp


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


def fig_loop_edges(runs: dict, out: Path, b_eq: dict[float, float]) -> None:
    """Spinodal pair vs ramp duration: where the metastable branch actually gives
    way, going up and going down. The band between them is the loop the
    experiment would see — read the protocol straight off it."""
    kappas = sorted(runs, reverse=True)
    fig, axes = plt.subplots(1, len(kappas), figsize=(4.6 * len(kappas), 4.0),
                             sharey=False)
    axes = np.atleast_1d(axes)
    for ax, kappa in zip(axes, kappas):
        entry, man = runs[kappa], runs[kappa]["manifest"]
        taus = sorted({t for (_, t) in entry["legs"]})
        ms = [float(man["tau_ms"][np.argmin(np.abs(man["tau"] - t))]) for t in taus]
        series = {}
        for tag, label, c in (("rise", "$B$ rising", CAT[0]),
                              ("fall", "$B$ falling", CAT[1])):
            ys = [jump_field(entry["legs"][(tag, t)])[0]
                  if (tag, t) in entry["legs"] else math.nan for t in taus]
            series[tag] = np.asarray(ys, dtype=float)
            ax.plot(ms, ys, color=c, marker="o", markersize=8,
                    markeredgecolor=SURFACE, markeredgewidth=2.0, label=label)
        both = np.isfinite(series["rise"]) & np.isfinite(series["fall"])
        if both.any():
            ax.fill_between(np.asarray(ms)[both], series["fall"][both],
                            series["rise"][both], color=CAT[0], alpha=0.12,
                            linewidth=0)
        if not np.isfinite(series["rise"]).any() and not np.isfinite(series["fall"]).any():
            ax.text(0.5, 0.5, "no localised jump\non either leg\n(crossover)",
                    transform=ax.transAxes, ha="center", va="center",
                    color=INK2, fontsize=10)
        ref = b_eq.get(kappa)
        if ref is not None and math.isfinite(ref):
            ax.axhline(ref, color=INK3, lw=1.2, ls=":")
            ax.annotate(f"$B_{{eq}}$ = {ref:.1f} µG", xy=(ms[-1], ref),
                        xytext=(-4, 5), textcoords="offset points", ha="right",
                        color=INK2, fontsize=8)
        ax.set_xscale("log")   # the axis IS the rate scan; τ spans decades
        if ms:                 # explicit limits: a crossover facet has no finite y
            ax.set_xlim(min(ms) / 1.6, max(ms) * 1.6)
        ax.set_xlabel(r"ramp duration  $\tau$  [ms]")
        order = "first-order side" if kappa >= 1.0 else "crossover control"
        ax.set_title(f"$\\kappa = {kappa:g}$  ({order})", color=INK)
        ax.grid(alpha=0.9)
        ax.set_axisbelow(True)
        ax.legend(loc="best")
    axes[0].set_ylabel("field of the $\\langle F_\\perp \\rangle$ jump  [µG]")
    fig.suptitle("Loop edges vs ramp rate — saturating = bistable, "
                 "closing = dynamical lag", y=0.99, color=INK)
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
    fig_hysteresis(runs, a.out / "eu_adiabatic_hysteresis.png")
    fig_loop_edges(runs, a.out / "eu_adiabatic_loop_edges.png",
                   static_b_eq(a.window))
    fig_sg_signal(runs, a.out / "eu_adiabatic_sg_signal.png")


if __name__ == "__main__":
    main()
