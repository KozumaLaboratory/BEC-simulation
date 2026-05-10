"""Plot the backend × dtype × grid bench produced by backend_grid_scan.jl.

Usage:
    python3 scripts/bench/plot_backend_grid_scan.py [csv_path] [out_png]

Defaults: CSV from /tmp/bench_results.csv, PNG to /tmp/bench_plot.png.

Two panels:
  Left  — absolute time per `split_step_combined!` step, log-log
  Right — speedup vs CPU F64 baseline, log-log

Each line is one (backend, dtype) config across N ∈ {16, 24, 32, 48}.
The vertical dotted lines mark the auto-pick boundary used by
`make_workspace(; backend=nothing)` (see `recommend_backend_dtype`).
"""

import csv
import sys
from collections import defaultdict
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker

CSV = sys.argv[1] if len(sys.argv) > 1 else "/tmp/bench_results.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/bench_plot.png"

rows = []
with open(CSV) as f:
    for r in csv.DictReader(f):
        rows.append(
            {
                "N": int(r["N"]),
                "backend": r["backend"],
                "dtype": r["dtype"],
                "kernel": r["kernel"],
                "us": float(r["us"]),
            }
        )

configs = [
    ("cpu", "f64", "CPU F64", "tab:blue", "o-"),
    ("cpu", "f32", "CPU F32", "tab:cyan", "s-"),
    ("cuda", "f64", "GPU F64", "tab:red", "o-"),
    ("cuda", "f32", "GPU F32", "tab:orange", "s-"),
]

fig, axes = plt.subplots(1, 2, figsize=(14, 6), constrained_layout=True)

# Left panel — absolute timing
ax = axes[0]
for be, dt, label, color, style in configs:
    pts = sorted(
        [r for r in rows if r["backend"] == be and r["dtype"] == dt and r["kernel"] == "combined"],
        key=lambda r: r["N"],
    )
    if not pts:
        continue
    Ns = [r["N"] for r in pts]
    us = [r["us"] for r in pts]
    ax.plot(Ns, us, style, color=color, label=label, lw=2, ms=8)

ax.set_xscale("log", base=2)
ax.set_yscale("log")
Ns_all = sorted({r["N"] for r in rows})
ax.set_xticks(Ns_all)
ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax.set_xlabel("N (cubic grid edge)", fontsize=12)
ax.set_ylabel("Time per step [µs]", fontsize=12)
ax.set_title("split_step_combined! — Eu151 (D=13)", fontsize=13)
ax.grid(True, which="both", alpha=0.3)
ax.legend(fontsize=11, loc="upper left")

# Auto-pick boundary
ax.axvline(16, color="gray", linestyle=":", alpha=0.7)
ax.axvline(24, color="gray", linestyle=":", alpha=0.7)
ymax = ax.get_ylim()[1]
ax.text(20, ymax * 0.5, "CPU\nzone", ha="center", fontsize=10, color="gray")
ax.text(34, ymax * 0.5, "GPU\nzone", ha="center", fontsize=10, color="gray")

# Right panel — speedup vs CPU F64
ax = axes[1]
cpu_f64 = {
    r["N"]: r["us"]
    for r in rows
    if r["backend"] == "cpu" and r["dtype"] == "f64" and r["kernel"] == "combined"
}
for be, dt, label, color, style in configs:
    if (be, dt) == ("cpu", "f64"):
        continue
    pts = sorted(
        [r for r in rows if r["backend"] == be and r["dtype"] == dt and r["kernel"] == "combined"],
        key=lambda r: r["N"],
    )
    if not pts:
        continue
    Ns = [r["N"] for r in pts]
    speedup = [cpu_f64[r["N"]] / r["us"] for r in pts]
    ax.plot(Ns, speedup, style, color=color, label=label, lw=2, ms=8)

ax.axhline(1.0, color="black", linestyle="--", alpha=0.5)
ax.set_xscale("log", base=2)
ax.set_yscale("log")
ax.set_xticks(Ns_all)
ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax.set_xlabel("N (cubic grid edge)", fontsize=12)
ax.set_ylabel("Speedup vs CPU F64 (×)", fontsize=12)
ax.set_title("Speedup over CPU F64 baseline", fontsize=13)
ax.grid(True, which="both", alpha=0.3)
ax.legend(fontsize=11, loc="upper left")

# Annotate GPU F32 line with speedup numbers
gpu_f32 = sorted(
    [r for r in rows if r["backend"] == "cuda" and r["dtype"] == "f32" and r["kernel"] == "combined"],
    key=lambda r: r["N"],
)
for r in gpu_f32:
    s = cpu_f64[r["N"]] / r["us"]
    ax.annotate(
        f"{s:.1f}×",
        xy=(r["N"], s),
        xytext=(r["N"] * 1.05, s * 1.15),
        fontsize=10,
        color="tab:orange",
        fontweight="bold",
    )

fig.suptitle(
    "SpinorBEC: backend × dtype × grid size — Eu151 (D=13)",
    fontsize=14,
    y=1.04,
)
plt.savefig(OUT, dpi=120, bbox_inches="tight", facecolor="white")
print(f"Wrote {OUT}")
