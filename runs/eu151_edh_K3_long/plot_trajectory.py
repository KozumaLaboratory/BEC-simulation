#!/usr/bin/env python3
"""Render EdH K_3 long-hold trajectory from `trajectory.csv`.

Six-panel diagnostic for the 14.5 ms (10 ω⁻¹) phase-2 hold:
  (a) total norm vs t                — K_3 + γ_dr atom-number decay
  (b) peak density vs t (log y)      — collapse signature (runaway = collapse)
  (c) ⟨F_z⟩ vs t                     — EdH spin transfer (drops from F)
  (d) population per m (linear)      — early-time spread
  (e) population per m (log y)       — sub-percent tail visibility
  (f) ΔN per m (loss vs initial m=F) — K_3 + γ_dr per-component breakdown

Convention: c1=m=+F, c13=m=-F (right-handed Spinor stack).
"""
import csv
import os
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "trajectory.csv")
OUT = os.path.join(HERE, "trajectory")

F_SPIN = 6  # Eu151
D = 2 * F_SPIN + 1


def load():
    rows = []
    with open(CSV) as f:
        for r in csv.DictReader(f):
            rows.append(r)
    t = np.array([float(r["t"]) for r in rows])
    norm = np.array([float(r["norm"]) for r in rows])
    peak = np.array([float(r["peak_density"]) for r in rows])
    Fz = np.array([float(r["Fz"]) for r in rows])
    pops = np.zeros((len(rows), D))
    for i, r in enumerate(rows):
        for c in range(1, D + 1):
            pops[i, c - 1] = float(r[f"pop_c{c}"])
    return t, norm, peak, Fz, pops


def m_label(c_idx):
    """Component index (1=top, D=bottom) → m label."""
    return f"m={F_SPIN - (c_idx - 1)}" if (F_SPIN - (c_idx - 1)) != 0 else "m=0"


def main():
    t, norm, peak, Fz, pops = load()
    print(f"loaded {len(t)} frames, t = {t[0]:.3f} → {t[-1]:.3f} ω⁻¹")

    fig, axes = plt.subplots(2, 3, figsize=(15, 8), sharex=True)

    # (a) total norm
    axes[0, 0].plot(t, norm, "-", color="C0", lw=1.5)
    axes[0, 0].set_ylabel("total norm")
    axes[0, 0].set_title("(a) atom-number conservation")
    axes[0, 0].grid(alpha=0.3)
    axes[0, 0].axhline(1.0, color="k", lw=0.5, ls=":")

    # (b) peak density log-y
    axes[0, 1].plot(t, peak, "-", color="C1", lw=1.5)
    axes[0, 1].set_ylabel(r"max $n_{\rm tot}$ (a.u.)")
    axes[0, 1].set_title("(b) peak density (collapse signature)")
    axes[0, 1].set_yscale("log")
    axes[0, 1].grid(alpha=0.3, which="both")

    # (c) Fz
    axes[0, 2].plot(t, Fz, "-", color="C2", lw=1.5)
    axes[0, 2].set_ylabel(r"$\langle F_z \rangle / N$")
    axes[0, 2].set_title("(c) EdH spin transfer: m=+F → lower m")
    axes[0, 2].grid(alpha=0.3)
    axes[0, 2].axhline(F_SPIN, color="k", lw=0.5, ls=":")

    # (d) populations linear
    cmap = plt.get_cmap("viridis")
    for c in range(1, D + 1):
        col = cmap((c - 1) / (D - 1))
        axes[1, 0].plot(t, pops[:, c - 1], "-", color=col, lw=1.2,
                        label=m_label(c) if c in (1, 2, 3, 4, 7, 10, 13) else None)
    axes[1, 0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 0].set_ylabel("population")
    axes[1, 0].set_title("(d) per-m populations (linear)")
    axes[1, 0].grid(alpha=0.3)
    axes[1, 0].legend(fontsize=8, ncol=2)

    # (e) populations log
    for c in range(1, D + 1):
        col = cmap((c - 1) / (D - 1))
        # avoid log(0)
        p = np.maximum(pops[:, c - 1], 1e-16)
        axes[1, 1].plot(t, p, "-", color=col, lw=1.2,
                        label=m_label(c) if c in (1, 2, 3, 4, 7, 10, 13) else None)
    axes[1, 1].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 1].set_ylabel("population (log)")
    axes[1, 1].set_title("(e) per-m populations (log)")
    axes[1, 1].set_yscale("log")
    axes[1, 1].grid(alpha=0.3, which="both")
    axes[1, 1].legend(fontsize=8, ncol=2)

    # (f) ΔN per m: pops[t] - pops[0] (signed)
    deltas = pops - pops[0]
    for c in range(1, D + 1):
        col = cmap((c - 1) / (D - 1))
        axes[1, 2].plot(t, deltas[:, c - 1], "-", color=col, lw=1.2,
                        label=m_label(c) if c in (1, 2, 3, 4, 7, 10, 13) else None)
    axes[1, 2].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 2].set_ylabel("Δ population (signed)")
    axes[1, 2].set_title("(f) Δpop relative to initial m=+F state")
    axes[1, 2].grid(alpha=0.3)
    axes[1, 2].axhline(0, color="k", lw=0.5)
    axes[1, 2].legend(fontsize=8, ncol=2)

    fig.suptitle(
        f"Eu151 EdH 32³ × K_3 long hold (phase 2 = 10 ω⁻¹ ≈ 14.5 ms)\n"
        f"K3 = 1e-41 m⁶/s (Dy-like) + γ_dr=0.02 + LHY scalar.  "
        f"Final norm = {norm[-1]:.4f}, peak n stable around {peak[-1]:.2e}",
        fontsize=11, y=1.00)
    plt.tight_layout()
    for ext in ("pdf", "png", "svg"):
        plt.savefig(f"{OUT}.{ext}", bbox_inches="tight", dpi=150 if ext == "png" else None)
    print(f"wrote {OUT}.{{pdf,png,svg}}")


if __name__ == "__main__":
    main()
