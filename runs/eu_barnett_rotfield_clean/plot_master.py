#!/usr/bin/env python3
"""MASTER figure: rotating field -> genuine EdH vortices (DDI-required),
direction-controlled, cleanly separated from trivial forced Larmor
precession.

Row 1 (mechanism, DDI on/off control):
  (a) <L_z>(t): vortices — 0 without DDI (forced precession makes none);
                +Om vs -Om opposite (direction control).
  (b) |<F>|(t): spin length — constant 6 without DDI (spin just rotates);
                DDI depolarises (genuine spin excitation).
  (c) <F_z>(t): forced Larmor precession (DDI-off) + DDI modification;
                +Om vs -Om mirror.
Row 2 (real-space, t=7.5): density + current streamlines
  (d) DDI OFF: round, smooth, no vortex.  (e) +Om: vortex (one chirality).
  (f) -Om: vortex (opposite chirality).
"""
import csv, os
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "figures", "master_figure")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
C_OFF, C_POS, C_NEG = fs.OFF, fs.POS, fs.NEG
FRAME = 15


def load(name):
    p = os.path.join(HERE, name)
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in r[0]}


def fld(snapdir, tag, name):
    p = os.path.join(HERE, snapdir, f"O{tag}_f{FRAME}_{name}.csv")
    return np.loadtxt(p, delimiter=",") if os.path.exists(p) else None


def main():
    off = load("spinvec_ddi_off.csv")
    onp = load("spinvec_ddi_on.csv")
    onn = load("spinvec_ddi_on_neg.csv")

    fig = plt.figure(figsize=(15, 9.2))
    gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.15], hspace=0.30, wspace=0.27)

    # (a) <L_z>
    ax = fig.add_subplot(gs[0, 0])
    ax.plot(off["t"], off["Lz"], color=C_OFF, lw=2.4, label="DDI OFF (forced Larmor)")
    ax.plot(onp["t"], onp["Lz"], color=C_POS, lw=2.4, label=r"DDI ON, $+\Omega$")
    ax.plot(onn["t"], onn["Lz"], color=C_NEG, lw=2.4, label=r"DDI ON, $-\Omega$")
    ax.axhline(0, color="k", lw=0.6)
    ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); ax.set_ylabel(r"$\langle L_z\rangle\ (\hbar/\mathrm{atom})$")
    ax.set_title("(a) vortices $\\langle L_z\\rangle$ \u2014 need DDI", fontsize=11.5)
    ax.legend(fontsize=8.5, loc="lower left"); ax.grid(alpha=0.3)
    ax.text(0.97, 0.06, "no DDI $\\Rightarrow$ no vortices", transform=ax.transAxes,
            ha="right", fontsize=9, color=C_OFF, style="italic")

    # (b) |F|
    ax = fig.add_subplot(gs[0, 1])
    ax.plot(off["t"], off["Fmag"], color=C_OFF, lw=2.4, label="DDI OFF")
    ax.plot(onp["t"], onp["Fmag"], color=C_POS, lw=2.4, label="DDI ON")
    ax.axhline(6, color="gray", ls=":", lw=1); ax.set_ylim(0, 6.5)
    ax.text(1, 6.12, "$F$=6 fully polarised", fontsize=8.5, color="gray")
    ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); ax.set_ylabel(r"$|\langle\mathbf{F}\rangle|$")
    ax.set_title("(b) spin length $|F|$ \u2014 DDI depolarises", fontsize=11.5)
    ax.legend(fontsize=9); ax.grid(alpha=0.3)
    ax.text(0.97, 0.10, "no DDI $\\Rightarrow$ spin only rotates", transform=ax.transAxes,
            ha="right", fontsize=9, color=C_OFF, style="italic")

    # (c) <F_z>
    ax = fig.add_subplot(gs[0, 2])
    ax.plot(off["t"], off["Fz"], color=C_OFF, lw=2.0, label="DDI OFF (forced Larmor)")
    ax.plot(onp["t"], onp["Fz"], color=C_POS, lw=2.4, label=r"DDI ON, $+\Omega$")
    ax.plot(onn["t"], onn["Fz"], color=C_NEG, lw=2.4, label=r"DDI ON, $-\Omega$")
    ax.axhline(0, color="k", lw=0.6)
    ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); ax.set_ylabel(r"$\langle F_z\rangle\ (\hbar/\mathrm{atom})$")
    ax.set_title("(c) $\\langle F_z\\rangle$ \u2014 Larmor + Barnett", fontsize=11.5)
    ax.legend(fontsize=8.5, loc="lower left"); ax.grid(alpha=0.3)

    # row 2: real-space density + streamlines
    x = np.loadtxt(os.path.join(HERE, "snaps_tv_pos", "grid_x.csv"), delimiter=",")
    ext = [x.min(), x.max(), x.min(), x.max()]
    panels = [("(d) DDI OFF — no vortex", "snaps_ddioff", "+0.50", C_OFF),
              (r"(e) DDI ON, $+\Omega$ — vortex (CCW)", "snaps_tv_pos", "+0.50", C_POS),
              (r"(f) DDI ON, $-\Omega$ — vortex (CW)", "snaps_tv_neg", "-0.50", C_NEG)]
    for col, (ttl, snapdir, tag, cc) in enumerate(panels):
        ax = fig.add_subplot(gs[1, col])
        dens = fld(snapdir, tag, "ntot2d")
        jx = fld(snapdir, tag, "jx"); jy = fld(snapdir, tag, "jy")
        if dens is not None:
            ax.imshow(dens.T, origin="lower", extent=ext, cmap="magma", aspect="equal")
        if jx is not None and jy is not None:
            ax.streamplot(x, x, jx.T, jy.T, color=fs.STREAM, density=1.1,
                          linewidth=0.7, arrowsize=1.0)
        ax.set_title(ttl, fontsize=11)
        ax.set_xlabel("x"); ax.set_ylabel("y")
        ax.set_xlim(ext[0], ext[1]); ax.set_ylim(ext[2], ext[3])
        for sp in ax.spines.values():
            sp.set_color(cc); sp.set_linewidth(3)

    fig.suptitle("Rotating magnetic field $\\to$ quantum vortices (Einstein–de Haas) + Barnett spin, "
                 "controlled by rotation direction\n"
                 "$^{151}$Eu $F$=6 dipolar BEC — vortices REQUIRE the DDI (zero without it); "
                 "the $\\langle F_z\\rangle$ swing alone is mostly forced Larmor precession",
                 fontsize=13, y=0.99)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
