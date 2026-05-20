#!/usr/bin/env python3
"""Render Klaus magnetostir × phi_omega scan from `trajectory.csv`.

Six-panel figure:
  (a) total norm vs t                     — atom-number conservation
  (b) ⟨F_z⟩ / F vs t                       — Klaus frozen-spinor check
  (c) ⟨L_z⟩ vs t                            — orbital-sector response
  (d) peak density vs t (sampled, log y)  — collapse signature
  (e) m=+F population vs t                — spin-population freezing
  (f) Lz_max vs phi_omega (summary)       — Berry-connection scaling

Color = phi_omega; lines colored by viridis(log(phi)).
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
    by_phi = defaultdict(list)
    with open(CSV) as f:
        for r in csv.DictReader(f):
            by_phi[float(r["phi"])].append(r)
    out = {}
    for phi, rows in by_phi.items():
        t = np.array([float(r["t"]) for r in rows])
        norm = np.array([float(r["norm"]) for r in rows])
        Fz = np.array([float(r["Fz"]) if r["Fz"] else np.nan for r in rows])
        Lz = np.array([float(r["Lz"]) if r["Lz"] else np.nan for r in rows])
        peak = np.array([float(r["peak"]) if r["peak"] != "nan" else np.nan for r in rows])
        pops = np.zeros((len(rows), D))
        for i, r in enumerate(rows):
            for c in range(1, D + 1):
                key = f"pop_c{c}"
                pops[i, c - 1] = float(r[key]) if key in r else 0.0
        out[phi] = dict(t=t, norm=norm, Fz=Fz, Lz=Lz, peak=peak, pops=pops)
    return out


def main():
    data = load()
    phis = sorted(data.keys())
    print(f"loaded {len(phis)} phis: {phis}")

    cmap = plt.get_cmap("viridis")
    log_phis = np.log10(np.array(phis))
    norm_log = (log_phis - log_phis.min()) / max(float(np.ptp(log_phis)), 1e-9)

    fig, axes = plt.subplots(2, 3, figsize=(15, 8), sharex=True)

    for k, phi in enumerate(phis):
        d = data[phi]
        col = cmap(norm_log[k])
        label = f"φ={phi:g}"
        axes[0, 0].plot(d["t"], d["norm"], "-", color=col, lw=1.2, label=label)
        axes[0, 1].plot(d["t"], d["Fz"], "-", color=col, lw=1.2, label=label)
        axes[0, 2].plot(d["t"], d["Lz"], "-", color=col, lw=1.2, label=label)
        # peak: only plot non-NaN sampled frames
        ok = np.isfinite(d["peak"])
        axes[1, 0].plot(d["t"][ok], d["peak"][ok], ".-", color=col, lw=0.8,
                        ms=2, label=label)
        # m=+F population (component index 1)
        axes[1, 1].plot(d["t"], d["pops"][:, 0], "-", color=col, lw=1.2, label=label)

    axes[0, 0].set_ylabel("total norm")
    axes[0, 0].set_title("(a) atom-number conservation")
    axes[0, 0].grid(alpha=0.3)
    axes[0, 0].axhline(1.0, color="k", lw=0.5, ls=":")
    axes[0, 0].legend(fontsize=7, ncol=2, loc="lower left")

    axes[0, 1].set_ylabel(r"$\langle F_z \rangle / N$")
    axes[0, 1].set_title("(b) frozen spinor (= F if Klaus regime)")
    axes[0, 1].axhline(F_SPIN, color="k", lw=0.5, ls=":")
    axes[0, 1].grid(alpha=0.3)

    axes[0, 2].set_ylabel(r"$\langle L_z \rangle$")
    axes[0, 2].set_title("(c) orbital response (Klaus signature)")
    axes[0, 2].axhline(0, color="k", lw=0.5)
    axes[0, 2].grid(alpha=0.3)

    axes[1, 0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 0].set_ylabel(r"max $n_{\rm tot}$ (a.u.)")
    axes[1, 0].set_title("(d) peak density (sampled)")
    axes[1, 0].set_yscale("log")
    axes[1, 0].grid(alpha=0.3, which="both")

    axes[1, 1].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 1].set_ylabel("m=+F pop")
    axes[1, 1].set_title("(e) m=+F population (Klaus freeze)")
    axes[1, 1].grid(alpha=0.3)
    axes[1, 1].axhline(1.0, color="k", lw=0.5, ls=":")

    # (f) Lz_max vs phi
    Lz_max = np.array([np.nanmax(np.abs(data[phi]["Lz"])) for phi in phis])
    axes[1, 2].loglog(phis, Lz_max, "o-", color="C3", lw=1.5)
    axes[1, 2].set_xlabel(r"$\varphi_\omega$ (dimless stir freq)")
    axes[1, 2].set_ylabel(r"max $|\langle L_z \rangle|$")
    axes[1, 2].set_title("(f) Lz scaling (slow stir = more Lz)")
    axes[1, 2].grid(alpha=0.3, which="both")

    fig.suptitle(
        f"Eu151 Klaus magnetostir × φ_ω scan (Eu physics on, 1 s steady stir, "
        f"32 × 32 × 16, integrator=yoshida4)\n"
        f"phi values: {', '.join(f'{p:g}' for p in phis)}",
        fontsize=10, y=1.00,
    )
    plt.tight_layout()
    for ext in ("pdf", "png", "svg"):
        plt.savefig(f"{OUT}.{ext}", bbox_inches="tight",
                    dpi=150 if ext == "png" else None)
    print(f"wrote {OUT}.{{pdf,png,svg}}")


if __name__ == "__main__":
    main()
