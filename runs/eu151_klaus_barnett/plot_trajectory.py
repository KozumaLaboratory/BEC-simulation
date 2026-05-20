#!/usr/bin/env python3
"""Render Barnett spin-pumping demo from `trajectory.csv`.

Klaus magnetostir setup (rotating_basis, p=26700, tilt 35°, 1 s steady
stir) PLUS K3 + γ_dr loss block. Hypothesis: rotation injects orbital
angular momentum, dissipation drains it into the spin sector via DDI
exchange. ⟨F_z⟩ should drift away from F=6 in a sign-tied way to ±phi.

Six-panel figure for ±phi pair:
  (a) total norm vs t      — atom-number decay (loss is on)
  (b) ⟨F_z⟩ vs t           — Barnett pumping signature
  (c) ⟨L_z⟩ vs t           — orbital response (sign-flipped between ±)
  (d) peak n vs t (log y)  — collapse / stabilisation
  (e) m=+F population vs t — spinor unfreezing
  (f) ΔF_z = F_z(+φ) - F_z(-φ) — the headline antisymmetry plot
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
        peak = np.array([float(r["peak"]) if r["peak"] != "nan" else np.nan
                         for r in rows])
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

    # ±phi color: blue for negative, red for positive, neutral for 0
    def color(phi):
        if phi > 0:
            return "C3"
        if phi < 0:
            return "C0"
        return "k"

    fig, axes = plt.subplots(2, 3, figsize=(15, 8), sharex=True)

    for phi in phis:
        d = data[phi]
        col = color(phi)
        label = f"$\\varphi$={phi:+g}"
        axes[0, 0].plot(d["t"], d["norm"], "-", color=col, lw=1.2, label=label)
        axes[0, 1].plot(d["t"], d["Fz"], "-", color=col, lw=1.2, label=label)
        axes[0, 2].plot(d["t"], d["Lz"], "-", color=col, lw=1.2, label=label)
        ok = np.isfinite(d["peak"])
        axes[1, 0].plot(d["t"][ok], d["peak"][ok], ".-", color=col, lw=0.8,
                        ms=2, label=label)
        axes[1, 1].plot(d["t"], d["pops"][:, 0], "-", color=col, lw=1.2,
                        label=label)

    axes[0, 0].set_ylabel("total norm")
    axes[0, 0].set_title("(a) atom-number decay (K3 + γ_dr)")
    axes[0, 0].axhline(1.0, color="k", lw=0.5, ls=":")
    axes[0, 0].grid(alpha=0.3)
    axes[0, 0].legend(fontsize=8)

    axes[0, 1].set_ylabel(r"$\langle F_z \rangle$")
    axes[0, 1].set_title("(b) Barnett pumping signature")
    axes[0, 1].axhline(F_SPIN, color="k", lw=0.5, ls=":", label="F=6 (frozen)")
    axes[0, 1].grid(alpha=0.3)

    axes[0, 2].set_ylabel(r"$\langle L_z \rangle$")
    axes[0, 2].set_title("(c) orbital response (sign-flipped ±φ)")
    axes[0, 2].axhline(0, color="k", lw=0.5)
    axes[0, 2].grid(alpha=0.3)

    axes[1, 0].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 0].set_ylabel(r"max $n_{\rm tot}$ (a.u.)")
    axes[1, 0].set_title("(d) peak density (sampled)")
    axes[1, 0].set_yscale("log")
    axes[1, 0].grid(alpha=0.3, which="both")

    axes[1, 1].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 1].set_ylabel("m=+F pop")
    axes[1, 1].set_title("(e) m=+F population (spinor unfreezing)")
    axes[1, 1].axhline(1.0, color="k", lw=0.5, ls=":")
    axes[1, 1].grid(alpha=0.3)

    # (f) headline: ΔFz between ±φ pair (interpolate to common time grid)
    pos_phi = next((p for p in phis if p > 0), None)
    neg_phi = next((p for p in phis if p < 0), None)
    if pos_phi is not None and neg_phi is not None:
        d_pos = data[pos_phi]
        d_neg = data[neg_phi]
        t_common = np.intersect1d(d_pos["t"], d_neg["t"])
        if len(t_common) > 10:
            Fz_pos = np.interp(t_common, d_pos["t"], d_pos["Fz"])
            Fz_neg = np.interp(t_common, d_neg["t"], d_neg["Fz"])
            dFz = Fz_pos - Fz_neg
            axes[1, 2].plot(t_common, dFz, "-", color="C2", lw=1.5,
                            label=f"⟨F_z⟩(+φ) - ⟨F_z⟩(-φ)")
            axes[1, 2].axhline(0, color="k", lw=0.5)
            axes[1, 2].set_ylabel(r"$\Delta\langle F_z \rangle$")
        else:
            axes[1, 2].text(0.5, 0.5, "(no common t between ±φ)",
                            transform=axes[1, 2].transAxes, ha="center")
    else:
        axes[1, 2].text(0.5, 0.5, "(±φ pair not yet complete)",
                        transform=axes[1, 2].transAxes, ha="center")
    axes[1, 2].set_xlabel(r"$t$ ($\omega_{\rm ref}^{-1}$)")
    axes[1, 2].set_title("(f) Barnett antisymmetry — headline")
    axes[1, 2].grid(alpha=0.3)
    axes[1, 2].legend(fontsize=8)

    fig.suptitle(
        "Eu151 Klaus magnetostir × ±φ × K3 + γ_dr — Barnett spin-pumping demo\n"
        f"phis: {', '.join(f'{p:+g}' for p in phis)} (rotating_basis + loss, "
        f"32 × 32 × 16, yoshida4)",
        fontsize=10, y=1.00,
    )
    plt.tight_layout()
    for ext in ("pdf", "png", "svg"):
        plt.savefig(f"{OUT}.{ext}", bbox_inches="tight",
                    dpi=150 if ext == "png" else None)
    print(f"wrote {OUT}.{{pdf,png,svg}}")


if __name__ == "__main__":
    main()
