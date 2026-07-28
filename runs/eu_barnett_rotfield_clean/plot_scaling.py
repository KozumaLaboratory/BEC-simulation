#!/usr/bin/env python3
"""Optimization scaling graphs: vortex + Barnett response vs rotation Omega
and vs rotating-field amplitude B.

Reads summary CSVs (param,peak_Lz,peak_Fz,meanabs_Lz,peak_vtx) produced by
summarize_runs.jl. Two panels: vs Omega, vs B. Marks the optimum.

Usage: plot_scaling.py <omega_summary.csv> <field_summary.csv>
"""
import csv, os, sys
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "figures", "optimization_scaling")
os.makedirs(os.path.dirname(OUT), exist_ok=True)


def load(path):
    r = list(csv.DictReader(open(path)))
    cols = list(r[0].keys())
    d = {k: np.array([float(x[k]) for x in r]) for k in cols}
    if "param" not in d:            # bz-sweep uses "Bz" as the axis column
        d["param"] = d[cols[0]]
    return d


def main():
    om = load(sys.argv[1]) if len(sys.argv) > 1 and os.path.exists(sys.argv[1]) else None
    field = load(sys.argv[2]) if len(sys.argv) > 2 and os.path.exists(sys.argv[2]) else None
    bz = load(sys.argv[3]) if len(sys.argv) > 3 and os.path.exists(sys.argv[3]) else None

    ncol = 3 if bz is not None else 2
    fig, axes = plt.subplots(1, ncol, figsize=(6.5 * ncol / 1.5, 5))
    axes = np.atleast_1d(axes)

    if om is not None:
        ax = axes[0]
        o = om["param"]
        ax.plot(o, om["peak_Lz"], "o-", color=fs.POS, lw=2, ms=7, label=r"peak $|\langle L_z\rangle|$ (vortex)")
        ax.plot(o, om["peak_Fz"], "s-", color=fs.NEG, lw=2, ms=7, label=r"peak $|\langle F_z\rangle|$ (Barnett)")
        iopt = int(np.argmax(om["peak_Lz"]))
        ax.axvline(o[iopt], color="gray", ls=":", lw=1)
        ax.annotate(f"opt $\\Omega$≈{o[iopt]:.2f}", (o[iopt], om['peak_Lz'][iopt]),
                    textcoords="offset points", xytext=(6, 8), fontsize=10)
        ax.set_xlabel(r"rotation rate $\Omega\ (\omega_{\rm ref})$")
        ax.set_ylabel(r"peak amplitude ($\hbar$/atom)")
        ax.set_title("(a) vs rotation strength $\\Omega$")
        ax.legend(fontsize=9); ax.grid(alpha=0.3)

    if field is not None:
        ax = axes[1]
        b = field["param"] * 1e5  # -> units of 1e-5 G
        ax.plot(b, field["peak_Lz"], "o-", color=fs.POS, lw=2, ms=7, label=r"peak $|\langle L_z\rangle|$ (vortex)")
        ax.plot(b, field["peak_Fz"], "s-", color=fs.NEG, lw=2, ms=7, label=r"peak $|\langle F_z\rangle|$ (Barnett)")
        iopt = int(np.argmax(field["peak_Lz"]))
        ax.axvline(b[iopt], color="gray", ls=":", lw=1)
        ax.annotate(f"opt $B$≈{b[iopt]:.1f}", (b[iopt], field['peak_Lz'][iopt]),
                    textcoords="offset points", xytext=(6, 8), fontsize=10)
        ax.set_xscale("log")
        ax.set_xlabel(r"rotating-field amplitude $B_\perp$ ($10^{-5}$ G)")
        ax.set_ylabel(r"peak amplitude ($\hbar$/atom)")
        ax.set_title("(b) vs rotating-field $B_\\perp$ ($\\Omega$=0.5)")
        ax.legend(fontsize=9); ax.grid(alpha=0.3, which="both")

    if bz is not None:
        ax = axes[2]
        b = bz["param"] * 1e5
        ax.plot(b, bz["peak_Lz"], "o-", color=fs.POS, lw=2, ms=7, label=r"peak $|\langle L_z\rangle|$ (vortex)")
        ax.plot(b, bz["peak_Fz"], "s-", color=fs.NEG, lw=2, ms=7, label=r"peak $|\langle F_z\rangle|$ (Barnett)")
        iopt = int(np.argmax(bz["peak_Lz"]))
        ax.axvline(b[iopt], color="gray", ls=":", lw=1)
        ax.set_xlabel(r"static bias $B_z$ ($10^{-5}$ G)")
        ax.set_ylabel(r"peak amplitude ($\hbar$/atom)")
        ax.set_title("(c) vs static bias $B_z$ ($\\Omega$=0.5, $B_\\perp$=2.13)")
        ax.legend(fontsize=9); ax.grid(alpha=0.3)

    fig.suptitle("Optimizing rotating-field vortex + Barnett response ($^{151}$Eu $F$=6, transverse start)",
                 fontsize=13, y=1.00)
    fig.tight_layout()
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
