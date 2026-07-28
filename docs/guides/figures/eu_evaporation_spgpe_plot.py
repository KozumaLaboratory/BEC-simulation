#!/usr/bin/env python3
"""Second-scale SPGPE evaporation of 151Eu — the figure.

Reads figs/eu_evaporation_optimization/eu_evap_spgpe.csv (written by
eu_evaporation_spgpe.jl) and draws ONE figure with two stacked panels sharing the
time axis:

  top    condensate N0(t): the SPGPE c-field vs the 0-D quasi-static model.
         The gap between them is the finite growth-rate LAG — the thing the
         0-D model structurally cannot produce.
  bottom the reservoir that drove it, T(t) and mu(t) in internal units, so the
         ramp is visible as a ramp rather than asserted.

Curves are smooth lines (simulation output), never scatter; markers only mark
the BEC onset of the 0-D model.

Provenance:
- shows: figs/eu_evaporation_optimization/eu_evap_spgpe.png
- data: eu_evap_spgpe.csv from docs/guides/figures/eu_evaporation_spgpe.jl
"""
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "..", "..", "..", "figs", "eu_evaporation_optimization")
CSV = os.path.join(FIGDIR, "eu_evap_spgpe.csv")
OUT = os.path.join(FIGDIR, "eu_evap_spgpe.png")


def main(csv=CSV, out=OUT):
    if not os.path.exists(csv):
        sys.exit(f"missing {csv} — run docs/guides/figures/eu_evaporation_spgpe.jl first")
    d = np.genfromtxt(csv, delimiter=",", names=True)

    t = d["t_s"]
    fig, (ax, ax2) = plt.subplots(
        2, 1, figsize=(7.2, 6.4), sharex=True,
        gridspec_kw={"height_ratios": [2.0, 1.0], "hspace": 0.08},
    )

    ax.plot(t, d["N0_spgpe"], lw=2.2, color="#1f4e9c",
            label="SPGPE c-field (growth + energy damping)")
    ax.plot(t, d["N0_0d"], lw=1.8, ls="--", color="#c0392b",
            label="0-D quasi-static model")
    ax.plot(t, d["N_C_spgpe"], lw=1.2, color="#7f8c8d", alpha=0.8,
            label="SPGPE classical region $N_C$")

    onset = np.flatnonzero(d["N0_0d"] > 0)
    if onset.size:
        ax.axvline(t[onset[0]], color="#c0392b", lw=0.9, ls=":", alpha=0.7)
        ax.plot([t[onset[0]]], [0.0], marker="v", ms=7, color="#c0392b",
                clip_on=False, zorder=5)
        ax.annotate("0-D BEC onset", xy=(t[onset[0]], 0),
                    xytext=(6, 18), textcoords="offset points",
                    fontsize=9, color="#c0392b")

    ax.set_ylabel("condensate atoms $N_0$")
    ax.legend(frameon=False, fontsize=9, loc="upper left")
    ax.set_title(
        f"$^{{151}}$Eu evaporation over {t[-1] - t[0]:.2f} s of REAL ramp time\n"
        "full SPGPE, reservoir $(T(t),\\mu(t))$ from the 0-D model",
        fontsize=11)
    ax.grid(alpha=0.25)

    ax2.plot(t, d["T_internal"], lw=2.0, color="#e67e22", label=r"$k_BT/\hbar\omega_{ref}$")
    ax2.set_ylabel("reservoir $T$", color="#e67e22")
    ax2.tick_params(axis="y", labelcolor="#e67e22")
    ax2.grid(alpha=0.25)

    ax3 = ax2.twinx()
    ax3.plot(t, d["mu_internal"], lw=2.0, color="#16a085", label=r"$\mu/\hbar\omega_{ref}$")
    ax3.axhline(0.0, color="#16a085", lw=0.8, ls=":", alpha=0.6)
    ax3.set_ylabel(r"reservoir $\mu$", color="#16a085")
    ax3.tick_params(axis="y", labelcolor="#16a085")

    ax2.set_xlabel("laboratory time [s]")

    fig.savefig(out, dpi=170, bbox_inches="tight")
    print(f"wrote {out}")

    # A number worth printing next to the figure.
    final_ratio = d["N0_spgpe"][-1] / max(d["N0_0d"][-1], 1e-30)
    print(f"final N0: SPGPE {d['N0_spgpe'][-1]:.4g}  0-D {d['N0_0d'][-1]:.4g}  "
          f"ratio {final_ratio:.3f}")


if __name__ == "__main__":
    main(*(sys.argv[1:] or []))
