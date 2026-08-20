#!/usr/bin/env python3
"""Figures for #334 — in-place nucleation of the weak-field ¹⁵¹Eu flower texture.

Three panels, one per thing the campaign established:

  1. the bifurcation in condensate fraction: ⟨F⊥⟩ on both branches against f, with
     f_sp (where the flower branch ends) and f_eq (where the energies cross) marked.
     This is the whole reason the question is not answered at f = 1.
  2. the branch separation in units of k_BT, which is what decides whether a
     fluctuation can choose. Extensive far from the bifurcation, of order 10 near it.
  3. the selection statistic against traversal rate, with binomial intervals — or,
     when the cells are all zero, the upper limits, which is what a negative result
     looks like when it is honest.

Reads the CSVs the drivers write; makes no numbers of its own beyond the binomial
interval. Run from the repo root with the run tree mirrored under figs/eu334/.

    python scripts/eu334/viz_eu334.py [--root figs/eu334] [--out docs/guides/figures]
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from viz_style import CAT, INK, INK2, INK3, read_tsv, use_style  # noqa: E402


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float, float]:
    """Wilson score interval — the one to use when k is 0 or n.

    A normal interval on 0/20 is [0, 0], which reads as "measured exactly zero"
    and is the failure this campaign's rejection criterion 6 is written against.
    Wilson gives [0, 0.161] there, which is the actual content of the measurement.
    """
    if n == 0:
        return (float("nan"),) * 3
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return p, max(0.0, c - h), min(1.0, c + h)


def branch_tables(root: Path, grid: str):
    """The branch table. Defaults to 32³ because it is the one that SPANS the
    endpoints: the 64³ walk covers f in [0.23, 0.52] and the T = 10 trajectories
    end at f = 0.60. Using the coarser table is not a compromise here — §5.4
    measured the two agreeing to 2e-5 relative in E, i.e. 1.8e-4 absolute against
    a branch separation of 5.8e-2 at f = 0.60, a factor 300."""
    d = root / f"bifurcation_k1.8_g{grid}"
    fl, po = d / "flower_down.csv", d / "polar_up.csv"
    if not (fl.exists() and po.exists()):
        return None
    # SORTED BY f. The flower walk runs DOWNWARD, so its CSV is in descending f,
    # and `np.interp` requires ascending `xp` — with descending it returns a
    # plausible number that is simply wrong. Here it read the f = 0.32 energy for
    # an f = 0.59 state and called every T = 10 endpoint "polarised", against the
    # "flower" the same arithmetic gives on sorted input. Nothing warns.
    def by_f(t):
        o = np.argsort(t["f"])
        return {k: (v[o] if v.shape == t["f"].shape else v) for k, v in t.items()}

    return by_f(read_tsv(fl)), by_f(read_tsv(po))


def flower_branch_mask(t) -> np.ndarray:
    """Cells still ON the flower branch.

    The walk keeps going after the branch ends — it falls onto the polarised one —
    so the rows below the spinodal are polarised-branch rows wearing the flower
    walk's filename. ⟨F⊥⟩ separates them by a factor 20, and using it here is not
    a fitted threshold: 1.0 sits between 0.13 and 3.5.
    """
    return t["fperp"] > 1.0


def panel_bifurcation(ax, a, b):
    m = flower_branch_mask(a)
    ax.plot(a["f"][m], a["fperp"][m], "o-", color=CAT[0], ms=4, label="flower branch")
    ax.plot(b["f"], b["fperp"], "s-", color=CAT[1], ms=4, label="polarised branch")
    # the flower walk's own rows below the spinodal, shown as what they are
    ax.plot(a["f"][~m], a["fperp"][~m], "o", color=INK3, ms=3, mfc="none",
            label="flower walk, after collapse")
    fsp = 0.5 * (a["f"][m].min() + a["f"][~m].max())
    ax.axvspan(a["f"][~m].max(), a["f"][m].min(), color=CAT[0], alpha=0.10, lw=0)
    ax.annotate(f"flower branch ends\n$f_{{sp}}$ = {fsp:.3f}\n$N_0^*$ ≈ {fsp*5e4:.0f}",
                xy=(fsp, 2.0), xytext=(fsp + 0.10, 1.4), color=INK,
                arrowprops=dict(arrowstyle="->", color=INK2, lw=0.9), fontsize=9)
    ax.set_xlabel("condensate fraction  $f = N_0/N$")
    ax.set_ylabel(r"$\langle F_\perp\rangle$")
    ax.set_title("A condensate is born polarised", loc="left")
    ax.legend(loc="upper left")
    ax.grid(True, alpha=0.6)


def panel_separation(ax, a, b, temps=(5.0, 10.0)):
    m = flower_branch_mask(a)
    f = a["f"][m]
    Ef = a["E_atom"][m]
    Ep = np.interp(f, b["f"], b["E_atom"])
    n0 = a["n_atoms"][m]
    dE = (Ep - Ef) * n0
    for i, T in enumerate(temps):
        ax.plot(f, dE / T, "o-", ms=4, color=CAT[i],
                label=rf"$T$ = {T:g} $\hbar\omega_{{ref}}$")
    ax.axhline(0.0, color=INK3, lw=0.8)
    ax.axhspan(-1, 1, color=INK3, alpha=0.15, lw=0)
    ax.set_yscale("symlog", linthresh=10)
    ax.set_xlabel("condensate fraction  $f = N_0/N$")
    ax.set_ylabel(r"$(E_{\rm polar}-E_{\rm flower})\,N_0\;/\;k_BT$")
    ax.set_title("The branches are within a fluctuation only near the bifurcation",
                 loc="left")
    ax.legend(loc="upper left")
    ax.grid(True, alpha=0.6)


def _assert_ascending(t, name: str) -> None:
    """np.interp fails SILENTLY on descending xp, so the ordering is asserted at
    the point of use rather than trusted from the reader."""
    if not np.all(np.diff(t["f"]) > 0):
        raise ValueError(f"{name} table is not ascending in f — np.interp would "
                         "return a plausible wrong number")


def assign(E: float, f: float, a, b) -> str:
    """Branch label from the relaxed energy, RECOMPUTED against the table.

    Deliberately not the label stored in the class CSV. That label was computed
    against whatever table the classifier ran with, and a table can be extended or
    re-measured afterwards — which is the whole reason the classify stage is
    separate from the trajectories. Reading the stored label back would freeze a
    verdict to a table nobody can see from here.

    `unread` is a refusal, not a verdict: outside the flower branch's own f range
    there is either no second basin (below it) or no reference (above it), and
    counting either as "not selected" would inflate a zero with cells the test
    could not be run on.
    """
    _assert_ascending(a, "flower")
    _assert_ascending(b, "polarised")
    m = flower_branch_mask(a)
    ff, fE = a["f"][m], a["E_atom"][m]
    if f < ff.min() or f > ff.max():
        return "unread"
    Ef = float(np.interp(f, ff, fE))
    Ep = float(np.interp(f, b["f"], b["E_atom"]))
    sep = abs(Ep - Ef)
    if E > max(Ef, Ep) + sep:
        return "excited"
    return "flower" if abs(E - Ef) <= abs(E - Ep) else "polarised"


def collect_selection(root: Path, a, b,
                      glob: str = "nucleate_k1.8_T*/class*/class_*.csv"):
    """(T, tau_ms) -> [n_flower, n_polar, n_excited, n_unread].

    Where an endpoint has both a plain and a `class_resid` classification, the
    residual-polished one WINS: it is the same state relaxed to |grad E| ~ 8e-6
    instead of stopping at max_steps, so its energy is a measurement rather than a
    bound. Keyed on (arm, file) so the two never both count.
    """
    best: dict[tuple[str, str], tuple] = {}
    for p in sorted(root.glob(glob)):
        t = read_tsv(p)
        if not t.get("E", np.array([])).size:
            continue
        arm = p.relative_to(root).parts[0]
        # `_matched` and `_long` share (T, tau) with a production cell but carry a
        # DIFFERENT µ target, so they are different measurements. Folding them in
        # would silently pool two designs under one row.
        if arm.endswith("_matched") or arm.endswith("_long"):
            continue
        key = (arm, str(t["file"][0]))
        rec = (float(t["T"][0]), float(t["tau_ms"][0]),
               float(t["E"][0]), float(t["f"][0]))
        if key not in best or "class_resid" in p.parts:
            best[key] = rec
    cells: dict[tuple[float, float], list[int]] = {}
    for (T, tau, E, f) in best.values():
        c = cells.setdefault((T, tau), [0, 0, 0, 0])
        c[{"flower": 0, "polarised": 1, "excited": 2}.get(assign(E, f, a, b), 3)] += 1
    return cells


def print_table(cells, want: int = 20) -> None:
    """The selection statistic, as text, with the cells that are SHORT named.

    A cell that did not finish its trajectories is printed with its own n rather
    than folded into the fraction — the pre-registered criterion says a partial
    cell says so instead of quoting the fraction it happened to get.
    """
    if not cells:
        print("no classified trajectories yet")
        return
    print(f"\n{'T':>6} {'tau[ms]':>9} {'n':>4} {'flower':>7} {'polar':>6} "
          f"{'excited':>8} {'p_flower':>9}  95% CI")
    for (T, tau) in sorted(cells):
        nf, npo, nex, nun = cells[(T, tau)]
        n = nf + npo + nex
        p, lo, hi = wilson(nf, n)
        short = "" if n >= want else f"  << SHORT of {want}"
        unread = "" if nun == 0 else f"  (+{nun} unread)"
        print(f"{T:>6.1f} {tau:>9.0f} {n:>4d} {nf:>7d} {npo:>6d} {nex:>8d} "
              f"{p:>9.3f}  [{lo:.3f}, {hi:.3f}]{short}{unread}")


def panel_selection(ax, cells):
    if not cells:
        ax.text(0.5, 0.5, "no classified trajectories yet", ha="center", va="center",
                color=INK2, transform=ax.transAxes)
        ax.set_axis_off()
        return
    temps = sorted({k[0] for k in cells})
    for i, T in enumerate(temps):
        taus = sorted(k[1] for k in cells if k[0] == T)
        xs, ps, los, his, ns = [], [], [], [], []
        for tau in taus:
            nf, npo, nex = cells[(T, tau)][:3]
            n = nf + npo + nex
            p, lo, hi = wilson(nf, n)
            xs.append(tau); ps.append(p); los.append(lo); his.append(hi); ns.append(n)
        xs = np.asarray(xs, float)
        # Clip at zero. A Wilson interval can land a hair outside [p_lo, p_hi] in
        # floating point when p saturates, and matplotlib rejects a negative yerr
        # outright — so the figure dies at the moment every cell reads 0 or 1,
        # which is exactly when it matters most.
        lo_err = np.clip(np.array(ps) - np.array(los), 0.0, None)
        hi_err = np.clip(np.array(his) - np.array(ps), 0.0, None)
        ax.errorbar(xs, ps, yerr=[lo_err, hi_err],
                    fmt="o-", ms=5, capsize=3, color=CAT[i],
                    label=rf"$T$ = {T:g} ($n$ = {min(ns)}–{max(ns)})")
        # Annotate the SATURATED cells with their count and one-sided limit —
        # "0/7, <0.35" and "7/7, >0.65" carry what the error bar alone cannot,
        # since a bar touching 0 or 1 is a bound and not a measurement.
        for x, p, lo, hi, n in zip(xs, ps, los, his, ns):
            if p == 0.0:
                ax.annotate(f"0/{n}\n<{hi:.2f}", xy=(x, 0), xytext=(x, 0.09),
                            ha="center", va="bottom", fontsize=8, color=CAT[i])
            elif p == 1.0:
                ax.annotate(f"{n}/{n}\n>{lo:.2f}", xy=(x, 1), xytext=(x, 0.91),
                            ha="center", va="top", fontsize=8, color=CAT[i])
    ax.set_xscale("log")
    ax.set_ylim(-0.08, 1.08)
    ax.set_xlabel("µ-ramp time τ [ms]  (traversal of the selection window)")
    ax.set_ylabel("flower selection fraction")
    ax.set_title("Reservoir temperature, not ramp rate, decides the texture",
                 loc="left")
    ax.legend(loc="center left")
    ax.grid(True, alpha=0.6)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="figs/eu334", type=Path)
    ap.add_argument("--out", default="docs/guides/figures", type=Path)
    ap.add_argument("--grid", default="32")
    args = ap.parse_args()
    use_style()

    tabs = branch_tables(args.root, args.grid)
    if tabs is None:
        print(f"no branch tables under {args.root}/bifurcation_k1.8_g{args.grid}",
              file=sys.stderr)
        return 1
    a, b = tabs
    args.out.mkdir(parents=True, exist_ok=True)

    fig, axes = plt.subplots(1, 2, figsize=(11.0, 4.2), constrained_layout=True)
    panel_bifurcation(axes[0], a, b)
    panel_separation(axes[1], a, b)
    p = args.out / "eu334_bifurcation.png"
    fig.savefig(p, dpi=200)
    print("wrote", p)

    cells = collect_selection(args.root, a, b)
    print_table(cells)
    fig2, ax2 = plt.subplots(figsize=(6.4, 4.2), constrained_layout=True)
    panel_selection(ax2, cells)
    p2 = args.out / "eu334_selection.png"
    fig2.savefig(p2, dpi=200)
    print("wrote", p2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
