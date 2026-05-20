#!/usr/bin/env python3
"""Barnett-precursor figure from `trajectory.csv`.

Klaus regime (Bz=1G, p=26700, full Eu mean-field, no loss block) freezes
the spin sector by construction: <F_z> = 6.0 and m=+F population = 1.0
throughout the 1 s steady stir, all phi_omega values. So this run cannot
exhibit Barnett spin pumping directly.

What it CAN show is the upstream half of the Barnett story: rotating B
injects orbital angular momentum into the cloud (Berry connection in
the rotating-basis frame), which would relax into the spin sector via
DDI exchange if a dissipation channel were present.

3-panel figure:
  (a) <L_z>(t) for each phi -- orbital response builds with stir rate
  (b) <F_z>(t) overlay     -- frozen spinor (no relaxation in this run)
  (c) RMS |L_z| vs phi      -- amplitude scaling
"""
import csv
import os
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "trajectory.csv")
OUT = os.path.join(HERE, "barnett_precursor")

F_SPIN = 6


def load():
    by_phi = defaultdict(list)
    with open(CSV) as f:
        for r in csv.DictReader(f):
            by_phi[float(r["phi"])].append(r)
    out = {}
    for phi, rows in by_phi.items():
        t = np.array([float(r["t"]) for r in rows])
        Fz = np.array([float(r["Fz"]) if r["Fz"] else np.nan for r in rows])
        Lz = np.array([float(r["Lz"]) if r["Lz"] else np.nan for r in rows])
        out[phi] = dict(t=t, Fz=Fz, Lz=Lz)
    return out


def main():
    data = load()
    phis = sorted(data.keys())
    print(f"loaded {len(phis)} phis: {phis}")

    cmap = plt.get_cmap("viridis")
    log_phis = np.log10(np.array(phis))
    norm_log = (log_phis - log_phis.min()) / max(float(np.ptp(log_phis)), 1e-9)

    fig, axes = plt.subplots(1, 3, figsize=(15, 4.2))

    # (a) Lz(t)
    for k, phi in enumerate(phis):
        d = data[phi]
        col = cmap(norm_log[k])
        axes[0].plot(d["t"], d["Lz"], "-", color=col, lw=1.0,
                     label=f"$\\varphi$={phi:g}")
    axes[0].axhline(0, color="k", lw=0.5)
    axes[0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[0].set_ylabel(r"$\langle L_z \rangle$")
    axes[0].set_title("(a) orbital angular momentum (Berry connection)")
    axes[0].grid(alpha=0.3)
    axes[0].legend(fontsize=8, ncol=2, loc="upper right")

    # (b) Fz(t)
    for k, phi in enumerate(phis):
        d = data[phi]
        col = cmap(norm_log[k])
        axes[1].plot(d["t"], d["Fz"], "-", color=col, lw=1.0)
    axes[1].axhline(F_SPIN, color="k", lw=0.6, ls=":",
                    label=r"$F=6$ (frozen)")
    axes[1].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1].set_ylabel(r"$\langle F_z \rangle$")
    axes[1].set_title("(b) spin sector frozen (no loss channel)")
    axes[1].set_ylim(F_SPIN - 0.05, F_SPIN + 0.05)
    axes[1].grid(alpha=0.3)
    axes[1].legend(fontsize=8, loc="upper right")

    # (c) RMS amplitude vs phi -- skip the spinup window where Lz is
    # transient (t < 22 ω⁻¹ covers tilt 6.28 + spinup 15.71)
    Lz_rms = []
    Lz_max = []
    for phi in phis:
        d = data[phi]
        ok = d["t"] > 22.0
        Lz = d["Lz"][ok]
        Lz = Lz[np.isfinite(Lz)]
        Lz_rms.append(float(np.sqrt(np.mean(Lz ** 2))))
        Lz_max.append(float(np.nanmax(np.abs(d["Lz"]))))
    axes[2].loglog(phis, Lz_rms, "o-", color="C0", lw=1.5, ms=6,
                   label="RMS (steady stir window)")
    axes[2].loglog(phis, Lz_max, "s--", color="C3", lw=1.0, ms=5,
                   alpha=0.7, label="peak (full trajectory)")
    axes[2].set_xlabel(r"$\varphi_\omega$ (dimless stir freq)")
    axes[2].set_ylabel(r"$\langle L_z \rangle$ amplitude")
    axes[2].set_title("(c) orbital response scaling")
    axes[2].grid(alpha=0.3, which="both")
    axes[2].legend(fontsize=8)

    fig.suptitle(
        "Eu151 Klaus magnetostir -- Barnett precursor "
        "(orbital response without spin relaxation)\n"
        f"p=26700 (Bz=1G), full Eu MF, "
        f"phis: {', '.join(f'{p:g}' for p in phis)} "
        f"-- spin frozen by construction, awaiting K3+gamma_dr to drain into F",
        fontsize=10, y=1.02,
    )
    plt.tight_layout()
    for ext in ("pdf", "png", "svg"):
        plt.savefig(f"{OUT}.{ext}", bbox_inches="tight",
                    dpi=150 if ext == "png" else None)
    print(f"wrote {OUT}.{{pdf,png,svg}}")


if __name__ == "__main__":
    main()
