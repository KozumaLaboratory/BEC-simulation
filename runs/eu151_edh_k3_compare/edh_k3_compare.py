#!/usr/bin/env python3
"""Render EdH × K_3 A/B comparison from `edh_k3_compare.csv`.

Four-panel comparison:
  (a) total norm vs t           — K_3 atom-number decay signature
  (b) peak density vs t         — K_3 collapse mitigation
  (c) F_z, L_z vs t             — EdH angular-momentum transfer (should
                                   match between branches at early time;
                                   K_3 is local so doesn't affect transfer
                                   until density spikes diverge)
  (d) F_z + L_z conservation    — EdH check (should be flat)
"""
import csv
import os
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "edh_k3_compare.csv")
BASE = os.path.join(HERE, "edh_k3_compare")

def load(csv_path):
    data = defaultdict(lambda: defaultdict(list))
    with open(csv_path) as f:
        for r in csv.DictReader(f):
            b = r["branch"]
            for k, v in r.items():
                if k in ("branch", "frame"): continue
                try:
                    data[b][k].append(float(v))
                except ValueError:
                    data[b][k].append(np.nan)
    return data

def main():
    data = load(CSV)
    branches = list(data.keys())
    colors = {"baseline_no_K3": "C0", "K3_dy_like": "C3"}

    fig, axes = plt.subplots(2, 2, figsize=(11, 7), sharex=True)

    for b in branches:
        d = data[b]
        t = np.array(d["t"])
        c = colors.get(b, "k")
        axes[0, 0].plot(t, d["norm"], "-", color=c, label=b, lw=1.5)
        axes[0, 1].plot(t, d["peak_density"], "-", color=c, label=b, lw=1.5)
        axes[1, 0].plot(t, d["Fz"], "-", color=c, label=f"{b} F_z", lw=1.5)
        if any(np.isfinite(d.get("Lz", [np.nan]))):
            axes[1, 0].plot(t, d["Lz"], "--", color=c, label=f"{b} L_z", lw=1.5)
        Fz = np.array(d["Fz"])
        Lz = np.array(d.get("Lz", np.full_like(Fz, np.nan)))
        if np.all(np.isfinite(Lz)):
            axes[1, 1].plot(t, Fz + Lz, "-", color=c, label=b, lw=1.5)

    axes[0, 0].set_ylabel("total norm")
    axes[0, 0].set_title("(a) atom-number conservation")
    axes[0, 0].grid(alpha=0.3); axes[0, 0].legend(fontsize=9)

    axes[0, 1].set_ylabel(r"max $n_{\rm tot}$ (a.u.)")
    axes[0, 1].set_title("(b) peak density")
    axes[0, 1].set_yscale("log")
    axes[0, 1].grid(alpha=0.3, which="both"); axes[0, 1].legend(fontsize=9)

    axes[1, 0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 0].set_ylabel(r"$\langle F_z \rangle$, $\langle L_z \rangle$")
    axes[1, 0].set_title("(c) EdH transfer: spin → orbital")
    axes[1, 0].grid(alpha=0.3); axes[1, 0].legend(fontsize=8)

    axes[1, 1].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 1].set_ylabel(r"$\langle F_z + L_z \rangle$")
    axes[1, 1].set_title("(d) total angular momentum (should be ≈ const)")
    axes[1, 1].grid(alpha=0.3); axes[1, 1].legend(fontsize=9)

    fig.suptitle(
        "Eu151 EdH × K_3 three-body loss (32³, phase 2 = 0.3 ω⁻¹ ≈ 0.43 ms)",
        fontsize=11)
    plt.tight_layout()
    plt.savefig(BASE + ".pdf", bbox_inches="tight")
    plt.savefig(BASE + ".png", bbox_inches="tight", dpi=180)
    plt.savefig(BASE + ".svg", bbox_inches="tight")
    print(f"Wrote {BASE}.{{pdf,png,svg}}")

if __name__ == "__main__":
    main()
