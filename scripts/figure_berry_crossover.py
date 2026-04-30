#!/usr/bin/env python3
"""
Berry crossover scan thesis figure.

Fetches the aggregated scan summary from the SpinorBEC dashboard
(/api/scan_group/berry_crossover_scan) and renders a 4-panel figure:

  (a) m=+F population (init / final) vs p (log scale)
  (b) Lz time-evolution — final and extremes — vs p
  (c) Fz drift Δ⟨F_z⟩ = F_z_final − F_z_init vs p
  (d) Larmor phase per integrator step vs p, with regime bands

Output: figs/berry_crossover.{pdf,png}

Usage:
  # dashboard must be running at localhost:8765
  python3 scripts/figure_berry_crossover.py
  python3 scripts/figure_berry_crossover.py --port 9000
  python3 scripts/figure_berry_crossover.py --scan another_scan_name
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def fetch_scan(host: str, port: int, scan: str) -> dict:
    url = f"http://{host}:{port}/api/scan_group/{scan}"
    with urllib.request.urlopen(url, timeout=10) as r:
        return json.loads(r.read())


def regime_color(phase: float) -> str:
    if phase < 1.0:
        return "#7fb9a6"  # safe / spinor-active
    if phase < 100.0:
        return "#c8a76b"  # marginal
    if phase < 300.0:
        return "#c97064"  # stiff
    return "#9a3a3a"  # danger / Klaus-frozen


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--scan", default="berry_crossover_scan")
    ap.add_argument("--out", default="figs/berry_crossover")
    args = ap.parse_args()

    data = fetch_scan(args.host, args.port, args.scan)
    runs = sorted(data["runs"], key=lambda r: r["value"])

    p = np.array([r["value"] for r in runs])
    m_init = np.array([r["m_top_init"] for r in runs])
    m_final = np.array([r["m_top_final"] for r in runs])
    Lz_min = np.array([r["Lz_min"] for r in runs])
    Lz_max = np.array([r["Lz_max"] for r in runs])
    Lz_final = np.array([r["Lz_final"] for r in runs])
    Fz_init = np.array([r["Fz_init"] for r in runs])
    Fz_final = np.array([r["Fz_final"] for r in runs])
    larmor = np.array([r["larmor_phase_per_step"] for r in runs])

    plt.rcParams.update({
        "font.family": "serif",
        "font.size": 10,
        "axes.linewidth": 0.7,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "xtick.direction": "in",
        "ytick.direction": "in",
        "xtick.major.width": 0.7,
        "ytick.major.width": 0.7,
        "legend.frameon": False,
    })

    fig, axes = plt.subplots(2, 2, figsize=(7.2, 5.8), constrained_layout=True)

    # (a) m=+F population
    ax = axes[0, 0]
    ax.plot(p, m_init, "o-", color="#5c6370", lw=1.2, ms=5,
            label=r"$N_{m=+F}$ (initial)", mfc="white")
    ax.plot(p, m_final, "o-", color="#c97064", lw=1.4, ms=5,
            label=r"$N_{m=+F}$ (final, after 500 ms stir)")
    ax.set_xscale("log")
    ax.set_xlabel(r"Zeeman strength $p$ (dimensionless)")
    ax.set_ylabel(r"$N_{m=+F}\,/\,N$")
    ax.set_ylim(0.45, 1.05)
    ax.legend(loc="lower right", fontsize=8)
    ax.set_title("(a) spinor unfreezing", loc="left", fontsize=10, weight="bold")
    ax.grid(alpha=0.2, ls=":")

    # (b) Lz vs p
    ax = axes[0, 1]
    ax.fill_between(p, Lz_min, Lz_max, color="#7fb9a6", alpha=0.3,
                    label=r"$[\,L_{z,\mathrm{min}},\,L_{z,\mathrm{max}}\,]$")
    ax.plot(p, Lz_max, "v-", color="#3a7a6a", lw=1.2, ms=4, mfc="white",
            label=r"$L_{z,\mathrm{max}}$")
    ax.plot(p, Lz_min, "^-", color="#3a7a6a", lw=1.2, ms=4, mfc="white",
            label=r"$L_{z,\mathrm{min}}$")
    ax.plot(p, Lz_final, "o-", color="#0e0f12", lw=1.4, ms=4,
            label=r"$L_z$(500 ms)")
    ax.axhline(0, color="black", lw=0.4, alpha=0.3)
    ax.set_xscale("log")
    ax.set_xlabel(r"Zeeman strength $p$")
    ax.set_ylabel(r"$\langle L_z \rangle$")
    ax.legend(loc="upper right", fontsize=8)
    ax.set_title("(b) orbital response", loc="left", fontsize=10, weight="bold")
    ax.grid(alpha=0.2, ls=":")

    # (c) Fz drift
    ax = axes[1, 0]
    ax.plot(p, Fz_final - Fz_init, "o-", color="#9a3a3a", lw=1.4, ms=5)
    ax.axhline(0, color="black", lw=0.4, alpha=0.3)
    ax.set_xscale("log")
    ax.set_xlabel(r"Zeeman strength $p$")
    ax.set_ylabel(r"$\Delta\langle F_z \rangle$")
    ax.set_title("(c) longitudinal spin drift", loc="left", fontsize=10, weight="bold")
    ax.grid(alpha=0.2, ls=":")

    # (d) Larmor phase per step
    ax = axes[1, 1]
    for x, y in zip(p, larmor):
        ax.bar(x, y, width=x * 0.35, color=regime_color(y),
               edgecolor="#0e0f12", lw=0.5, alpha=0.85)
    # Regime bands
    ymin, ymax = 0.05, max(larmor) * 2
    for thr, label in zip([1, 100, 300], ["safe", "marginal", "stiff"]):
        if ymin <= thr <= ymax:
            ax.axhline(thr, ls="--", color="#5c6370", lw=0.5, alpha=0.6)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel(r"Zeeman strength $p$")
    ax.set_ylabel(r"$p\!\cdot\!F\!\cdot\!\Delta t$ (rad / step)")
    ax.set_ylim(ymin, ymax)
    ax.set_title("(d) Larmor regime", loc="left", fontsize=10, weight="bold")
    ax.grid(alpha=0.2, ls=":", which="both")

    fig.suptitle(
        r"Berry crossover: ${}^{151}$Eu (F=6) magnetostir at varying $p$"
        r"  —  500 ms stir, $\phi_\omega = 4.524$  ($N=$"
        f"{len(runs)} pts)",
        fontsize=10.5,
        y=1.02,
    )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(f"{out}.pdf", bbox_inches="tight")
    fig.savefig(f"{out}.png", dpi=160, bbox_inches="tight")
    print(f"wrote {out}.pdf and {out}.png", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
