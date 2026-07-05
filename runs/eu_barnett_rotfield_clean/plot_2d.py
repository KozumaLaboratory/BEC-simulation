#!/usr/bin/env python3
"""2D optimization heatmap: peak vortex |<L_z>| and Barnett |<F_z>| over
(Omega, B). Marks the joint optimum.

Usage: plot_2d.py <summary_2d.csv>
"""
import csv, os, sys
import numpy as np
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "optimization_2d")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "summary_2d.csv")
    r = list(csv.DictReader(open(path)))
    Om = np.array(sorted(set(float(x["Omega"]) for x in r)))
    B = np.array(sorted(set(float(x["B"]) for x in r)))
    def grid(key):
        g = np.full((len(B), len(Om)), np.nan)
        for x in r:
            i = np.where(np.isclose(B, float(x["B"])))[0][0]
            j = np.where(np.isclose(Om, float(x["Omega"])))[0][0]
            g[i, j] = float(x[key])
        return g
    Lz = grid("peak_Lz"); Fz = grid("peak_Fz")

    fig, axes = plt.subplots(1, 2, figsize=(13, 5.2))
    for ax, g, ttl, cm in ((axes[0], Lz, "peak $|\\langle L_z\\rangle|$ (vortex)", "viridis"),
                           (axes[1], Fz, "peak $|\\langle F_z\\rangle|$ (Barnett)", "magma")):
        im = ax.imshow(g, origin="lower", aspect="auto", cmap=cm,
                       extent=[Om.min(), Om.max(), 0, len(B)])
        ax.set_yticks(np.arange(len(B)) + 0.5)
        ax.set_yticklabels([f"{b*1e5:.2g}" for b in B])
        ax.set_xlabel(r"rotation rate $\Omega\ (\omega_{\rm ref})$")
        ax.set_ylabel(r"rotating-field $B_\perp$ ($10^{-5}$ G)")
        ax.set_title(ttl)
        plt.colorbar(im, ax=ax, fraction=0.046, label=r"$\hbar$/atom")
        # mark optimum
        ij = np.unravel_index(np.nanargmax(g), g.shape)
        oo = Om[ij[1]]; ax.plot(oo, ij[0] + 0.5, "w*", ms=18, mec="k")
        ax.annotate(f"opt\n$\\Omega$={oo:.2f}\n$B$={B[ij[0]]*1e5:.2g}",
                    (oo, ij[0] + 0.5), color="w", fontsize=9, ha="center",
                    va="center", textcoords="offset points", xytext=(0, 26))

    fig.suptitle("2D optimization surface: rotating-field vortex + Barnett response "
                 "($^{151}$Eu $F$=6)", fontsize=13, y=1.00)
    fig.tight_layout()
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
