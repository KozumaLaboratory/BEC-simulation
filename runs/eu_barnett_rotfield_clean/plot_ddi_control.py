#!/usr/bin/env python3
"""DDI on/off control: is the spin response genuine EdH/Barnett or just
forced Larmor precession by the rotating drive?

  DDI OFF -> forced Larmor precession only: |F| stays ~F (coherent spin
            rotates), <L_z>=0 (no vortices).
  DDI ON  -> genuine excitation: |F| shrinks (depolarisation) AND
            <L_z> != 0 (orbital AM = vortices, EdH).
The <L_z> signal is impossible from uniform forced precession.
"""
import csv, os
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ddi_control")


def load(name):
    p = os.path.join(HERE, name)
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in r[0]}


def main():
    on = load("spinvec_ddi_on.csv")
    off = load("spinvec_ddi_off.csv")
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.6))

    def plot(ax, key, ttl, yl):
        if off is not None:
            ax.plot(off["t"], off[key], color=fs.OFF, lw=2.2, label="DDI OFF (forced Larmor)")
        if on is not None:
            ax.plot(on["t"], on[key], color=fs.POS, lw=2.2, label="DDI ON (genuine EdH)")
        ax.axhline(0, color="k", lw=0.5)
        ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); ax.set_ylabel(yl)
        ax.set_title(ttl); ax.legend(fontsize=9); ax.grid(alpha=0.3)

    plot(axes[0], "Fmag", r"(a) spin length $|\langle\mathbf{F}\rangle|$", r"$|\langle\mathbf{F}\rangle|$")
    axes[0].axhline(6, color="gray", ls=":", lw=1)
    axes[0].text(1, 6.05, "$F$=6 (fully polarised)", fontsize=8, color="gray")
    plot(axes[1], "Fz", r"(b) $\langle F_z\rangle$ (spin along rotation axis)", r"$\langle F_z\rangle$")
    plot(axes[2], "Lz", r"(c) $\langle L_z\rangle$ (vortices) — 0 without DDI", r"$\langle L_z\rangle$")

    fig.suptitle("Control: genuine EdH/Barnett vs forced Larmor precession "
                 "($^{151}$Eu $F$=6, transverse, $+\\Omega$)\n"
                 "DDI OFF keeps $|F|{=}6$ and $\\langle L_z\\rangle{=}0$ (spin just rotates); "
                 "DDI ON depolarises AND makes vortices",
                 fontsize=12, y=1.02)
    fig.tight_layout()
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
