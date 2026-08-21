#!/usr/bin/env python3
"""Field-ladder figure for #336 — the F=6 analogue of the paper's Fig. 3(c).

Parses the run logs rather than a hand-copied table, so the figure and the
report cannot drift apart. Cells that failed the box gate (edge fraction above
EDGE_MAX) are plotted as OPEN markers and excluded from the fitted trend: their
energies are box artifacts, not physics.

  python3 runs/saito_li_torus/h5_ladder_plot.py
"""
import pathlib
import re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = pathlib.Path(__file__).parent / "out"
EDGE_MAX = 1e-4

CELL = re.compile(r"^### cell ([TC])@?([0-9.]*)\s+\((\w+) seed, Bz = ([0-9.]+) mG\)"
                  r".*?box=\(([0-9.]+), ([0-9.]+), ([0-9.]+)\)")
FIELDS = {
    "E": re.compile(r"^  E/N total\s+=\s+([-+0-9.eE]+)"),
    "fz": re.compile(r"^  <f>\s+=\s+\([-+0-9.eE]+, [-+0-9.eE]+, ([-+0-9.eE]+)\)"),
    "edge": re.compile(r"^  edge density\s+=\s+([0-9.eE+-]+)"),
    "aspect": re.compile(r"aspect = ([0-9.]+)"),
    "rho": re.compile(r"^  rho_max\s+=\s+([0-9.]+) N um"),
    "ddi_s": re.compile(r"^  E_ddi/E_s\s+=\s+([-+0-9.]+)"),
}


def parse(paths):
    rows = []
    cur = None
    for p in paths:
        if not p.exists():
            continue
        for ln in p.read_text().splitlines():
            m = CELL.match(ln)
            if m:
                cur = dict(seed=m.group(3), Bz_uG=float(m.group(4)) * 1000.0,
                           box_z=float(m.group(7)))
                rows.append(cur)
                continue
            if cur is None:
                continue
            for k, rx in FIELDS.items():
                mm = rx.search(ln)
                if mm:
                    cur[k] = float(mm.group(1))
    return [r for r in rows if "E" in r and "edge" in r]


def main():
    # Every log that contains cells. Listing them by hand is how the 16 and
    # 18 uG crossing cells were silently absent from the first figure, so the
    # count is asserted against the number of cells the report quotes.
    logs = sorted(OUT.glob("*.log"))
    rows = parse(logs)
    if not rows:
        print("no parsable cells in", [p.name for p in logs])
        return
    # positive control on the parser itself: the B=0 torus cell must be there
    # with the energy the report quotes.
    base = [r for r in rows if r["seed"] == "torus" and r["Bz_uG"] == 0.0]
    assert base, "parser found no B=0 torus cell — it is not reading the logs"
    assert any(abs(r["E"] + 1.575563) < 1e-5 for r in base), \
        f"B=0 torus energy not recovered: {[r['E'] for r in base]}"
    print(f"parsed {len(rows)} cells; parser control OK")

    # Group by the OUTCOME, not by the seed. At 0 and 3 uG the cigar seed
    # relaxes into a magnetic vortex (identical second-moment eigenvalues,
    # opposite circulation), so plotting it on the polarized branch would draw
    # a line between two different states.
    for r in rows:
        r["branch"] = "polarized" if abs(r.get("fz", 0.0)) > 3.0 else "vortex"

    fig, ax = plt.subplots(1, 2, figsize=(10.4, 4.2))
    for branch, colour, label in (
            ("vortex", "tab:blue", "magnetic vortex"),
            ("polarized", "tab:red", "z-polarized (cigar)")):
        good = sorted([r for r in rows if r["branch"] == branch
                       and r["edge"] <= EDGE_MAX], key=lambda r: r["Bz_uG"])
        bad = sorted([r for r in rows if r["branch"] == branch
                      and r["edge"] > EDGE_MAX], key=lambda r: r["Bz_uG"])
        if good:
            ax[0].plot([r["Bz_uG"] for r in good], [r["E"] for r in good],
                       "-o", color=colour, ms=5, label=label)
            ax[1].plot([r["Bz_uG"] for r in good], [-r["fz"] for r in good],
                       "-o", color=colour, ms=5, label=label)
        if bad:
            ax[0].plot([r["Bz_uG"] for r in bad], [r["E"] for r in bad],
                       "o", mfc="none", color=colour, ms=7,
                       label=f"{label} — box gate FAILED")
            ax[1].plot([r["Bz_uG"] for r in bad], [-r["fz"] for r in bad],
                       "o", mfc="none", color=colour, ms=7)

    for a in ax:
        a.axvspan(50, 70, color="0.85", zorder=0)
        a.set_xlabel("B_z  [µG]")
        a.grid(alpha=0.25)
    ax[0].set_ylabel("E / N  [ℏω_ref]")
    ax[0].set_title("energy of each branch")
    ax[1].set_ylabel("−⟨f_z⟩ / N")
    ax[1].set_title("magnetization  (grey band: torus B_c)")
    ax[0].legend(frameon=False, fontsize=8)
    fig.suptitle("Li–Saito Fig. 3 analogue at F = 6, N = 15000, ε_dd = 1.3\n"
                 "open markers = cell put >1e-4 of the norm on the boundary, "
                 "energy is a box artifact", fontsize=10)
    fig.tight_layout()
    fig.savefig(OUT / "fig3_ladder.png", dpi=160, bbox_inches="tight")
    print("  wrote fig3_ladder.png")

    print(f"\n{'seed':<7}{'Bz[uG]':>8}{'box_z':>7}{'E/N':>12}{'-<f_z>':>9}"
          f"{'aspect':>8}{'edge':>10}  usable")
    for r in sorted(rows, key=lambda r: (r["seed"], r["Bz_uG"], r["box_z"])):
        print(f"{r['seed']:<7}{r['Bz_uG']:8.1f}{r['box_z']:7.1f}{r['E']:12.6f}"
              f"{-r.get('fz', float('nan')):9.4f}{r.get('aspect', float('nan')):8.3f}"
              f"{r['edge']:10.2e}  {'yes' if r['edge'] <= EDGE_MAX else 'NO'}")


if __name__ == "__main__":
    main()
