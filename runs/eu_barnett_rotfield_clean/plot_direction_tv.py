#!/usr/bin/env python3
"""Direction-dependence figure: rotating field +Omega vs 0 vs -Omega.

Compares traj_tv_O{+0.50,+0.00,-0.50}.csv:
  (a) <L_z>(t) — orbital / vortex response, +Om vs -Om
  (b) <F_z>(t) — Barnett spin response
  (c) <J_z>(t) — rotating field pumps angular momentum (not conserved)
  (d) net vortex winding chirality +Om vs -Om
  (e,f) late-time transferred-component density (holes) +Om vs -Om
"""
import csv, os, glob
import numpy as np
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "barnett_direction_transverse")
C = {"+0.50": "#1f77b4", "+0.00": "#555555", "-0.50": "#d62728"}
LB = {"+0.50": r"$+\Omega$ (CCW)", "+0.00": r"$\Omega=0$", "-0.50": r"$-\Omega$ (CW)"}


def load(tag):
    p = os.path.join(HERE, f"traj_tv_O{tag}.csv")
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in
            ("t", "Fz", "Lz", "Jz", "vtx_net", "vtx_plus", "vtx_minus", "core_contrast")}


def snapfld(snapdir, name):
    fs = sorted(glob.glob(os.path.join(HERE, snapdir, f"*_{name}.csv")))
    return np.loadtxt(fs[-1], delimiter=",") if fs else None


def main():
    D = {tag: load(tag) for tag in ("+0.50", "+0.00", "-0.50")}
    fig = plt.figure(figsize=(15, 9))
    gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.1], hspace=0.30, wspace=0.28)

    axa = fig.add_subplot(gs[0, 0])
    axb = fig.add_subplot(gs[0, 1])
    axc = fig.add_subplot(gs[0, 2])
    for tag, d in D.items():
        if d is None:
            continue
        axa.plot(d["t"], d["Lz"], color=C[tag], lw=2, label=LB[tag])
        axb.plot(d["t"], d["Fz"], color=C[tag], lw=2, label=LB[tag])
        axc.plot(d["t"], d["Jz"], color=C[tag], lw=2, label=LB[tag])
    for ax, ttl, yl in ((axa, "(a) orbital $\\langle L_z\\rangle$ = vortex response", r"$\langle L_z\rangle$"),
                        (axb, "(b) Barnett spin $\\langle F_z\\rangle$", r"$\langle F_z\rangle$"),
                        (axc, "(c) $\\langle J_z\\rangle$ (field pumps AM)", r"$\langle J_z\rangle$")):
        ax.axhline(0, color="k", lw=0.5); ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
        ax.set_ylabel(yl); ax.set_title(ttl); ax.legend(fontsize=8); ax.grid(alpha=0.3)

    # (d) net vortex winding
    axd = fig.add_subplot(gs[1, 0])
    for tag, d in D.items():
        if d is None:
            continue
        axd.plot(d["t"], d["vtx_net"], color=C[tag], lw=1.8, label=LB[tag])
    axd.axhline(0, color="k", lw=0.5); axd.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axd.set_ylabel("net winding (mid-z)"); axd.set_title("(d) vortex chirality vs rotation")
    axd.legend(fontsize=8); axd.grid(alpha=0.3)

    # (e,f) late-time transferred density +Om vs -Om
    for col, tag, snapdir in ((1, "+0.50", "snaps_tv_pos"), (2, "-0.50", "snaps_tv_neg")):
        ax = fig.add_subplot(gs[1, col])
        tot = snapfld(snapdir, "ntot2d")
        if tot is not None:
            ax.imshow(tot.T, origin="lower", cmap="magma", aspect="equal")
        ax.set_title(f"{LB[tag]}: total density (late)")
        ax.set_xticks([]); ax.set_yticks([])
        for sp in ax.spines.values():
            sp.set_color(C[tag]); sp.set_linewidth(2.5)

    fig.suptitle("Rotating magnetic field: direction-dependent vortex + Barnett spin response "
                 "($^{151}$Eu $F$=6, unitary)", fontsize=13, y=0.97)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
