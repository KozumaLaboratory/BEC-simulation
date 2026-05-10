"""Plot the ITP trace CSV produced by `scripts/bench/itp_profile.jl`.

Usage:
    python3 scripts/bench/plot_itp_profile.py [csv_path] [out_png]

Defaults: CSV from /tmp/itp_profile_trace.csv, PNG to /tmp/itp_profile.png

Three-panel plot:
  Left   — log(dE) vs iter: clean line ⇒ integrator-limited; plateau ⇒
           landscape-limited
  Middle — dt vs iter: at ceiling ⇒ stability/accuracy bound; flux ⇒
           ITP has headroom
  Right  — Mz drift vs iter: monotone drift signals mean-field +
           Mz-non-conserving DDI; hard pinning would show 0 drift
"""

import csv
import sys
from collections import defaultdict
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

CSV = sys.argv[1] if len(sys.argv) > 1 else "/tmp/itp_profile_trace.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/itp_profile.png"

cols = defaultdict(list)
with open(CSV) as f:
    for r in csv.DictReader(f):
        for k, v in r.items():
            try:
                cols[k].append(float(v))
            except ValueError:
                cols[k].append(v)

fig, axes = plt.subplots(1, 3, figsize=(15, 4.5), constrained_layout=True)

# Panel 1: log(dE), log(dpsi) vs iter
ax = axes[0]
ax.semilogy(cols["iter"][1:], cols["dE"][1:], "o-", color="tab:blue", lw=1.5, label="|ΔE|")
ax.semilogy(
    cols["iter"][1:], cols["dpsi"][1:], "s-", color="tab:orange", lw=1.5, label="‖Δψ‖/‖ψ‖"
)
ax.set_xlabel("iteration")
ax.set_ylabel("convergence proxy (log)")
ax.set_title("Decay rate — clean line ⇒ integrator-limited")
ax.legend()
ax.grid(True, which="both", alpha=0.3)

# Panel 2: dt vs iter
ax = axes[1]
ax.plot(cols["iter"], cols["dt"], "o-", color="tab:green", lw=1.5)
ax.set_xlabel("iteration")
ax.set_ylabel("dt")
ax.set_title("dt history — at ceiling ⇒ stability/accuracy bound")
ax.grid(True, alpha=0.3)

# Panel 3: Mz drift
ax = axes[2]
Mz0 = cols["Mz"][0] if cols["Mz"] else 0.0
ax.plot(cols["iter"], [m - Mz0 for m in cols["Mz"]], "o-", color="tab:red", lw=1.5)
ax.set_xlabel("iteration")
ax.set_ylabel("M_z(iter) − M_z(0)")
ax.set_title("Magnetization drift")
ax.grid(True, alpha=0.3)

fig.suptitle("ITP profile — " + CSV.split("/")[-1], fontsize=13, y=1.04)
plt.savefig(OUT, dpi=120, bbox_inches="tight", facecolor="white")
print(f"Wrote {OUT}")
