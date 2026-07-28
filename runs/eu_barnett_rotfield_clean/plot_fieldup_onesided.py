#!/usr/bin/env python3
"""Field-UP one-sided excitation with a finite metastable relaxation time.

Start at the top of the ladder m=+F but now with the field applied UP (+z),
so m=+F is the METASTABLE EXCITED state. A large Zeeman gap (omega_L=5, well
above the DDI energy) Zeeman-suppresses the spontaneous m->m-1 relaxation, so
the metastable state has a long lifetime. A resonant CO-rotating drive
(Omega=+omega_L) still bridges the gap and flips the spin fast and fully;
the counter-rotating drive is detuned by 2*omega_L and does nothing beyond
the slow spontaneous relaxation.

Reads traj_{hi_nodrive,hi_+5,hi_-5}.csv from run_field_test.jl. No heatmaps.
"""
import csv, os
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "figures", "fieldup_onesided")
os.makedirs(os.path.dirname(OUT), exist_ok=True)


def load(tag):
    p = os.path.join(HERE, f"traj_{tag}.csv")
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in ("t", "Fx", "Fy", "Fz", "Fmag", "Lz")}


def main():
    res = load("hi_+5")     # resonant (co-rotating)
    off = load("hi_-5")     # off-resonant (counter-rotating)
    nod = load("hi_nodrive")
    if res is None:
        print("missing hi_ CSVs; run run_field_test.jl first")
        return

    C_RES, C_OFF, C_NOD = fs.NEG, fs.POS, fs.ZERO
    lab_res = r"$+\Omega$ co-rotating (RESONANT)"
    lab_off = r"$-\Omega$ counter-rotating (off-res)"
    lab_nod = "no drive (slow relaxation)"

    fig = plt.figure(figsize=(15, 4.8))
    gs = fig.add_gridspec(1, 3, wspace=0.28)

    def draw(ax, key, ylab, title, hl=None):
        ax.plot(res["t"], res[key], color=C_RES, lw=2.6, label=lab_res)
        ax.plot(off["t"], off[key], color=C_OFF, lw=2.0, label=lab_off)
        if nod is not None:
            ax.plot(nod["t"], nod[key], color=C_NOD, lw=1.8, ls="--", label=lab_nod)
        if hl is not None:
            ax.axhline(hl, color="gray", lw=0.8, ls=":")
        ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
        ax.set_ylabel(ylab); ax.set_title(title)
        ax.legend(fontsize=8.5); ax.grid(alpha=0.3)

    draw(fig.add_subplot(gs[0, 0]), "Fz", r"$\langle F_z\rangle$ ($\hbar$/atom)",
         r"(a) $\langle F_z\rangle$: only $+\Omega$ Rabi-flops", hl=0)
    draw(fig.add_subplot(gs[0, 1]), "Fmag", r"$|\langle \mathbf{F}\rangle|$ ($\hbar$/atom)",
         r"(b) $|\langle\mathbf{F}\rangle|$: resonant coherent, else depol.")
    draw(fig.add_subplot(gs[0, 2]), "Lz", r"$\langle L_z\rangle$ ($\hbar$/atom)",
         r"(c) $\langle L_z\rangle$: vortices in the relaxation channel")

    fig.suptitle(
        r"Field-UP one-sided excitation: metastable $m$=+$F$, large gap $\omega_L$=5 "
        r"(relaxation slowed; only resonant $+\Omega$ drives) — $^{151}$Eu $F$=6",
        fontsize=13, y=1.06)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
