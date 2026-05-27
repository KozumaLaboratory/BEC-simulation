#!/usr/bin/env python3
"""
make_klaus_omega_refine_figure.py — Fig K14: Ω refinement scan +
parabolic fit + Ω* estimate.

Reads runs/klaus_quench/summary.json, finds the 7 "refine" cells,
fits a parabola P(Ω) = a (Ω - Ω*)² + P_max, and reports Ω* with
uncertainty (parabolic-fit standard error).
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SUMMARY = ROOT / "runs" / "klaus_quench" / "summary.json"
OUT = ROOT / "docs" / "manuscript" / "figures" / "klaus_quench_fig_k14_omega_refine.png"

plt.rcParams.update({
    "font.size": 10, "axes.titlesize": 11, "axes.labelsize": 10,
    "legend.fontsize": 9, "savefig.dpi": 180,
})

if not SUMMARY.exists():
    print(f"FATAL: {SUMMARY} not found.", file=sys.stderr)
    sys.exit(1)
with open(SUMMARY) as f:
    data = json.load(f)

# Find refine cells.
refine_rows = []
for r in data["rows"]:
    if r["status"] != "OK":
        continue
    label = r["label"]
    if "refine" not in label or "delay2ms" not in label:
        continue
    refine_rows.append((r["omega"], r["max_P_54"]))

if len(refine_rows) < 3:
    print(f"Only {len(refine_rows)} refine cells available — need ≥3 for parabolic fit.")
    print("Skipping Fig K14 — re-run after batch completes.")
    sys.exit(0)

refine_rows.sort()
omegas = np.array([r[0] for r in refine_rows])
P_vals = np.array([r[1] for r in refine_rows])

# Quadratic fit: P = a Ω² + b Ω + c.
coefs = np.polyfit(omegas, P_vals, 2)
a, b, c = coefs
# Vertex: Ω* = -b / (2a), P_max = c - b²/(4a)
omega_star = -b / (2 * a)
P_max = c - b * b / (4 * a)
P_fit = np.polyval(coefs, omegas)
residuals = P_vals - P_fit
rss = np.sum(residuals ** 2)
n = len(omegas)
mse = rss / max(n - 3, 1)
# Approximate σ_Ω* from the fit covariance.
# Use polyfit's cov estimate.
coefs2, cov = np.polyfit(omegas, P_vals, 2, cov=True)
var_a = cov[0, 0]
var_b = cov[1, 1]
cov_ab = cov[0, 1]
# Propagate to Ω* = -b/(2a):
# δΩ* / δa = b / (2a²);  δΩ* / δb = -1/(2a)
da = b / (2 * a * a)
db = -1 / (2 * a)
sigma_omega_star = np.sqrt(
    da * da * var_a + db * db * var_b + 2 * da * db * cov_ab
)

print(f"Ω scan: {len(omegas)} points")
print(f"  data:  Ω = {omegas}, P = {P_vals}")
print(f"  fit:   P(Ω) = {a:+.3f} Ω² {b:+.3f} Ω {c:+.3f}")
print(f"  vertex: Ω* = {omega_star:+.4f} ± {sigma_omega_star:.4f}")
print(f"  P_max  = {P_max:.4f}")
print(f"  RSS    = {rss:.5e},  RMSE = {np.sqrt(mse):.4f}")

# Plot.
fig, ax = plt.subplots(figsize=(9, 5))
omegas_fine = np.linspace(omegas.min() - 0.05, omegas.max() + 0.05, 200)
P_fine = np.polyval(coefs, omegas_fine)

ax.plot(omegas_fine, P_fine, "-", color="gray", linewidth=1.4, alpha=0.7,
         label=f"parabolic fit  ({coefs[0]:+.2f} Ω² {coefs[1]:+.2f} Ω {coefs[2]:+.3f})")
ax.scatter(omegas, P_vals, color="#d62728", s=80, zorder=4,
            label="scan points")
# Annotate values.
for om, p in zip(omegas, P_vals):
    ax.annotate(f"{p:.3f}", (om, p), xytext=(0, 7),
                 textcoords="offset points", ha="center", fontsize=8)
# Vertex marker.
ax.axvline(omega_star, color="#1f77b4", linestyle="--", linewidth=1.4, alpha=0.7,
            label=f"Ω* = {omega_star:+.3f} ± {sigma_omega_star:.3f}")
ax.scatter([omega_star], [P_max], marker="x", s=120, color="#1f77b4",
            linewidths=2.5, zorder=5)
ax.annotate(f"P_max ≈ {P_max:.3f}",
             (omega_star, P_max), xytext=(15, -15),
             textcoords="offset points", fontsize=10, color="#1f77b4")

ax.set_xlabel(r"$\Omega / \omega_\perp$")
ax.set_ylabel(r"$\max_t (N_{-5} + N_{-4}) / N$")
ax.set_title(
    "Figure K14 — Ω refinement at B=2.6 nT, delay=2 ms, hold-only.\n"
    "Parabolic fit through 7 sampled points → operational optimum Ω*.",
)
ax.grid(True, alpha=0.3)
ax.legend(loc="best", fontsize=9)
fig.tight_layout()
fig.savefig(OUT)
plt.close(fig)
print(f"\nwrote {OUT}")
