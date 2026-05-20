#!/usr/bin/env python3
"""Render Barnett spin-pumping demo from `trajectory.csv`.

Setup: weak Bz (2.6 nT, p~0.69, non-secular regime) + Klaus-style tilted
rotating B at Ω = ±0.5 dimless + DDI + K3 + γ_dr + LHY scalar (spinor
path, 32³ grid, 30 ω⁻¹).

KEY OBSERVATION (May 15, 2026): Strong rotation-direction asymmetry in
⟨F_z⟩ — +Ω preserves spin polarization, -Ω relaxes the spin across all
m components (Barnett pumping toward -F). ΔFz/N ≈ 4.6 at t=30 ω⁻¹.

Six-panel figure:
  (a) total norm vs t
  (b) ⟨F_z⟩/N vs t — headline Barnett pumping
  (c) ⟨L_z⟩ vs t (if available)
  (d) peak n vs t
  (e) m population ladder at t_end
  (f) ΔF_z/N = F_z(+Ω) - F_z(-Ω) vs t
"""
import csv
import os
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "trajectory.csv")
OUT = os.path.join(HERE, "trajectory")

F_SPIN = 6
D = 2 * F_SPIN + 1


def load():
    by_o = defaultdict(list)
    with open(CSV) as f:
        for r in csv.DictReader(f):
            by_o[float(r["Omega"])].append(r)
    out = {}
    for omega, rows in by_o.items():
        t = np.array([float(r["t"]) for r in rows])
        norm = np.array([float(r["norm"]) for r in rows])
        Fz = np.array([float(r["Fz"]) if r["Fz"] else np.nan for r in rows])
        Lz = np.array([float(r["Lz"]) if r["Lz"] else np.nan for r in rows])
        peak = np.array([float(r["peak"]) if r["peak"] != "nan" else np.nan
                         for r in rows])
        pops = np.zeros((len(rows), D))
        for i, r in enumerate(rows):
            for c in range(1, D + 1):
                key = f"pop_c{c}"
                pops[i, c - 1] = float(r[key]) if key in r else 0.0
        out[omega] = dict(t=t, norm=norm, Fz=Fz, Lz=Lz, peak=peak, pops=pops)
    return out


def main():
    data = load()
    omegas = sorted(data.keys())
    pos = next((o for o in omegas if o > 0), None)
    neg = next((o for o in omegas if o < 0), None)
    print(f"loaded omegas: {omegas}")

    fig, axes = plt.subplots(2, 3, figsize=(15, 8))

    for omega in omegas:
        d = data[omega]
        col = "C3" if omega > 0 else "C0"
        label = f"$\\Omega$={omega:+g}"
        axes[0, 0].plot(d["t"], d["norm"], "-", color=col, lw=1.4, label=label)
        Fz_norm = np.where(d["norm"] > 0, d["Fz"] / d["norm"], np.nan)
        axes[0, 1].plot(d["t"], Fz_norm, "-", color=col, lw=1.4, label=label)
        if not all(np.isnan(d["Lz"])):
            axes[0, 2].plot(d["t"], d["Lz"], "-", color=col, lw=1.4, label=label)
        ok = np.isfinite(d["peak"])
        axes[1, 0].plot(d["t"][ok], d["peak"][ok], ".-", color=col, lw=0.8,
                        ms=3, label=label)

    axes[0, 0].set_ylabel("total norm")
    axes[0, 0].set_title("(a) atom-number decay")
    axes[0, 0].axhline(1.0, color="k", lw=0.5, ls=":")
    axes[0, 0].grid(alpha=0.3)
    axes[0, 0].legend(fontsize=9)
    axes[0, 0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")

    axes[0, 1].set_ylabel(r"$\langle F_z \rangle / N$")
    axes[0, 1].set_title("(b) Barnett pumping — headline")
    axes[0, 1].axhline(F_SPIN, color="gray", lw=0.5, ls=":", label="m=+F start")
    axes[0, 1].axhline(0, color="gray", lw=0.5, ls=":", label="$F_z=0$")
    axes[0, 1].axhline(-F_SPIN, color="gray", lw=0.5, ls=":")
    axes[0, 1].grid(alpha=0.3)
    axes[0, 1].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")

    axes[0, 2].set_ylabel(r"$\langle L_z \rangle$")
    axes[0, 2].set_title("(c) orbital response")
    axes[0, 2].grid(alpha=0.3)
    axes[0, 2].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")

    axes[1, 0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 0].set_ylabel(r"max $n_{\rm tot}$")
    axes[1, 0].set_title("(d) peak density")
    axes[1, 0].grid(alpha=0.3)

    # (e) Population ladder at end
    m_vals = list(range(F_SPIN, -F_SPIN - 1, -1))
    x_idx = np.arange(D)
    width = 0.35
    for k, omega in enumerate(omegas):
        col = "C3" if omega > 0 else "C0"
        pops_end = data[omega]["pops"][-1, :]
        offset = -width / 2 if omega > 0 else width / 2
        axes[1, 1].bar(x_idx + offset, pops_end, width=width, color=col,
                       label=f"$\\Omega$={omega:+g}", alpha=0.85)
    axes[1, 1].set_xticks(x_idx)
    axes[1, 1].set_xticklabels([f"{m:+d}" for m in m_vals], fontsize=8)
    axes[1, 1].set_xlabel(r"$m_F$")
    axes[1, 1].set_ylabel(r"population at $t_{\rm end}$")
    axes[1, 1].set_title("(e) spin distribution at end — Barnett pumping")
    axes[1, 1].axvline(0, color="k", lw=0.3)  # m=+6 marker
    axes[1, 1].grid(alpha=0.3, axis="y")
    axes[1, 1].legend(fontsize=9)

    # (f) ΔF_z/N(t) headline
    if pos is not None and neg is not None:
        t_p = data[pos]["t"]
        t_n = data[neg]["t"]
        t_common = np.intersect1d(t_p, t_n)
        if len(t_common) > 5:
            Fz_p_norm = np.interp(t_common, t_p,
                                  data[pos]["Fz"] / data[pos]["norm"])
            Fz_n_norm = np.interp(t_common, t_n,
                                  data[neg]["Fz"] / data[neg]["norm"])
            dFz = Fz_p_norm - Fz_n_norm
            axes[1, 2].plot(t_common, dFz, "-", color="C2", lw=2.0,
                            label=r"$\langle F_z\rangle(+\Omega) - \langle F_z\rangle(-\Omega)$ /N")
            axes[1, 2].axhline(0, color="k", lw=0.5)
    axes[1, 2].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 2].set_ylabel(r"$\Delta\langle F_z\rangle / N$")
    axes[1, 2].set_title("(f) sign-asymmetry — Barnett antisymmetry")
    axes[1, 2].grid(alpha=0.3)
    axes[1, 2].legend(fontsize=9)

    fig.suptitle(
        "Eu151 Barnett spin pumping — weak Bz (2.6 nT, non-secular) × Klaus stir × ±Ω + DDI + K3 + γ_dr\n"
        f"32³ grid, 30 ω⁻¹ (~43 ms), Ω = ±0.5 (adiabatic, T_stir ≈ 12.6 ω⁻¹ vs T_Larmor ≈ 9 ω⁻¹)",
        fontsize=10, y=1.00,
    )
    plt.tight_layout()
    for ext in ("pdf", "png", "svg"):
        plt.savefig(f"{OUT}.{ext}", bbox_inches="tight",
                    dpi=150 if ext == "png" else None)
    print(f"wrote {OUT}.{{pdf,png,svg}}")


if __name__ == "__main__":
    main()
