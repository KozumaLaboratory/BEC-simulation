#!/usr/bin/env python3
"""Turn the L-BFGS A/B benchmark logs into a figure + CSV.

    python3 bench/plot_lbfgs_ab.py <dir-with-lbfgs_*_*.out> [-o out_prefix]

Reads `lbfgs_<revision>_<backend>.out` as written by bench/submit_lbfgs_bench.sh
and emits `<prefix>.csv` plus `<prefix>.png`: per-iteration wall time by cell,
one bar per revision, with the component breakdown stacked underneath.
"""

import argparse
import csv
import os
import re
from collections import OrderedDict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

CELL_RE = re.compile(r"^=== (.+?) ===\s*$")
TOTAL_RE = re.compile(r"^\s*per-iteration \(slope\):\s*([\d.eE+-]+) ms")
PART_RE = re.compile(r"^\s{4}(\S.*?)\s{2,}([\d.eE+-]+) ms\s*\(\s*([\d.eE+-]+)%\)")


def parse(path):
    """-> {cell: {"total": ms, "parts": OrderedDict(name -> ms)}}"""
    cells, cur = OrderedDict(), None
    with open(path) as fh:
        for line in fh:
            m = CELL_RE.match(line)
            if m:
                cur = m.group(1)
                cells[cur] = {"total": None, "parts": OrderedDict()}
                continue
            if cur is None:
                continue
            m = TOTAL_RE.match(line)
            if m:
                cells[cur]["total"] = float(m.group(1))
                continue
            m = PART_RE.match(line)
            if m:
                cells[cur]["parts"][m.group(1).strip()] = float(m.group(2))
    return cells


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("-o", "--out", default="lbfgs_ab")
    args = ap.parse_args()

    data = OrderedDict()  # (backend, revision) -> cells
    for d in args.dirs:
        for fn in sorted(os.listdir(d)):
            m = re.match(r"lbfgs_(.+)_(cpu|gpu)\.out$", fn)
            if m:
                data[(m.group(2), m.group(1))] = parse(os.path.join(d, fn))

    if not data:
        raise SystemExit("no lbfgs_<rev>_<backend>.out files found")

    revisions = list(OrderedDict.fromkeys(rev for _, rev in data))
    backends = list(OrderedDict.fromkeys(be for be, _ in data))

    with open(args.out + ".csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["backend", "revision", "cell", "component", "ms"])
        for (be, rev), cells in data.items():
            for cell, rec in cells.items():
                w.writerow([be, rev, cell, "per_iteration_total", rec["total"]])
                for name, ms in rec["parts"].items():
                    w.writerow([be, rev, cell, name, ms])

    fig, axes = plt.subplots(1, len(backends), figsize=(7 * len(backends), 5), squeeze=False)
    for ax, be in zip(axes[0], backends):
        cells = list(OrderedDict.fromkeys(
            c for (b, _), cc in data.items() if b == be for c in cc))
        x = range(len(cells))
        width = 0.8 / max(len(revisions), 1)
        for j, rev in enumerate(revisions):
            cc = data.get((be, rev), {})
            vals = [cc.get(c, {}).get("total") or 0.0 for c in cells]
            ax.bar([i + j * width for i in x], vals, width, label=rev)
            for i, v in enumerate(vals):
                base = data.get((be, revisions[0]), {}).get(cells[i], {}).get("total")
                if base and j > 0 and v:
                    ax.text(i + j * width, v, f"{base / v:.2f}×",
                            ha="center", va="bottom", fontsize=8)
        ax.set_xticks([i + width * (len(revisions) - 1) / 2 for i in x])
        ax.set_xticklabels(cells, rotation=20, ha="right", fontsize=8)
        ax.set_ylabel("wall time per L-BFGS iteration (ms)")
        ax.set_title(f"backend = {be}")
        ax.legend()
    fig.tight_layout()
    fig.savefig(args.out + ".png", dpi=150)
    print(f"wrote {args.out}.csv and {args.out}.png")


if __name__ == "__main__":
    main()
