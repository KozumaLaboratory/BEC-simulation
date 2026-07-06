#!/usr/bin/env python3
"""One-sided (chiral) excitation: co-rotating drive EXCITES, counter-rotating does NOT.

Start fully polarised at the top of the ladder (m=+F, <F_z>=+6) with a static
B_z bias (Larmor omega_L = 0.5). A transverse field rotating at Omega=omega_L
in the CO-rotating sense is resonant and drags the whole spin down the ladder
(spin excitation + EdH vortices); the COUNTER-rotating sense is detuned by
2*omega_L and barely moves it. No drive = stable reference.

Line-based (no density heatmaps). Reads traj_reson_{-0.50,+0.50,nodrive}.csv.
"""
import csv, os, sys
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "resonance_onesided")
F = 6

# resonant (co-rotating) = -0.50 here; off-resonant (counter) = +0.50
RES = "-0.50"
OFF = "+0.50"


def load(tag):
    p = os.path.join(HERE, f"traj_reson_{tag}.csv")
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in ("t", "Fx", "Fy", "Fz", "Fmag", "Lz")}


def main():
    res = load(RES)
    off = load(OFF)
    nod = load("nodrive")
    if res is None or off is None:
        print("missing resonance CSVs; run run_resonance_compare.jl first")
        sys.exit(1)

    C_RES = fs.NEG      # resonant, exciting -> bold warm
    C_OFF = fs.POS      # off-resonant -> cool
    C_NOD = fs.ZERO
    lab_res = r"$-\Omega$ co-rotating  (RESONANT)"
    lab_off = r"$+\Omega$ counter-rotating  (off-resonant)"
    lab_nod = r"no drive (reference)"

    fig = plt.figure(figsize=(15, 8.5))
    gs = fig.add_gridspec(2, 3, hspace=0.30, wspace=0.30)

    def draw(ax, key, ylab, title, hline=None):
        ax.plot(res["t"], res[key], color=C_RES, lw=2.6, label=lab_res)
        ax.plot(off["t"], off[key], color=C_OFF, lw=2.0, label=lab_off)
        if nod is not None:
            ax.plot(nod["t"], nod[key], color=C_NOD, lw=1.8, ls="--", label=lab_nod)
        if hline is not None:
            ax.axhline(hline, color="gray", lw=0.8, ls=":")
        ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
        ax.set_ylabel(ylab); ax.set_title(title)
        ax.legend(fontsize=8.5); ax.grid(alpha=0.3)

    # (a) F_z: the headline
    draw(fig.add_subplot(gs[0, 0]), "Fz", r"$\langle F_z\rangle$ ($\hbar$/atom)",
         r"(a) axial spin $\langle F_z\rangle$", hline=F)
    # (b) |F|: depolarisation
    draw(fig.add_subplot(gs[0, 1]), "Fmag", r"$|\langle \mathbf{F}\rangle|$ ($\hbar$/atom)",
         r"(b) depolarisation $|\langle \mathbf{F}\rangle|$", hline=F)
    # (c) L_z: vortices
    draw(fig.add_subplot(gs[0, 2]), "Lz", r"$\langle L_z\rangle$ ($\hbar$/atom)",
         r"(c) orbital AM $\langle L_z\rangle$ (vortices)")

    # (d) net excitation bar summary
    axd = fig.add_subplot(gs[1, 0])
    names = [r"$-\Omega$" + "\n(resonant)", r"$+\Omega$" + "\n(off-res)", "no\ndrive"]
    dFz = [res["Fz"][0] - np.min(res["Fz"]),
           off["Fz"][0] - np.min(off["Fz"]),
           (nod["Fz"][0] - np.min(nod["Fz"])) if nod is not None else 0.0]
    cols = [C_RES, C_OFF, C_NOD]
    b = axd.bar(names, dFz, color=cols, edgecolor="k", lw=0.8)
    for bi, v in zip(b, dFz):
        axd.text(bi.get_x() + bi.get_width() / 2, v + 0.08, f"{v:.2f}",
                 ha="center", fontsize=10)
    axd.set_ylabel(r"spin excitation  $\langle F_z\rangle_0-\min\langle F_z\rangle$")
    axd.set_title("(d) excitation is one-sided (chiral)")
    axd.grid(alpha=0.3, axis="y")

    # (e) transverse spin trajectory (resonant winds in, off-res stays put)
    axe = fig.add_subplot(gs[1, 1])
    axe.plot(res["Fx"], res["Fy"], color=C_RES, lw=1.8, label=lab_res)
    axe.plot(off["Fx"], off["Fy"], color=C_OFF, lw=1.8, label=lab_off)
    axe.plot(res["Fx"][0], res["Fy"][0], "o", color="k", ms=6, zorder=5)
    axe.set_aspect("equal")
    axe.axhline(0, color="k", lw=0.5); axe.axvline(0, color="k", lw=0.5)
    axe.set_xlabel(r"$\langle F_x\rangle$"); axe.set_ylabel(r"$\langle F_y\rangle$")
    axe.set_title("(e) transverse spin: resonant sense spirals in")
    axe.legend(fontsize=8.5); axe.grid(alpha=0.3)

    # (f) summary text
    axf = fig.add_subplot(gs[1, 2]); axf.axis("off")
    def stat(d):
        return (d["Fz"][0], np.min(d["Fz"]), d["Fmag"][0], np.min(d["Fmag"]),
                np.max(np.abs(d["Lz"])))
    r0, rmin, rm0, rmm, rlz = stat(res)
    o0, omin, om0, omm, olz = stat(off)
    txt = (
        f"Magnetic-resonance selection\n"
        f"(top state m=+{F}, static $B_z$, $\\omega_L$=0.5, unitary)\n\n"
        f"$-\\Omega$ CO-rotating (resonant):\n"
        f"  $\\langle F_z\\rangle$: {r0:.1f} -> {rmin:.1f}   ($\\Delta$={r0-rmin:.1f})\n"
        f"  $|F|$: {rm0:.1f} -> {rmm:.1f}   (depolarised)\n"
        f"  peak $|\\langle L_z\\rangle|$ = {rlz:.1f}  (vortices)\n\n"
        f"$+\\Omega$ COUNTER-rotating (off-res):\n"
        f"  $\\langle F_z\\rangle$: {o0:.1f} -> {omin:.1f}   ($\\Delta$={o0-omin:.1f})\n"
        f"  $|F|$: {om0:.1f} -> {omm:.1f}   (unchanged)\n"
        f"  peak $|\\langle L_z\\rangle|$ = {olz:.1f}  (none)\n\n"
        f"Selectivity $\\Delta F_z$ ratio: "
        f"{(r0-rmin)/max(o0-omin,1e-3):.0f}$\\times$\n\n"
        f"Reverse the field's rotation sense and the\n"
        f"SAME atoms either fully excite or stay frozen."
    )
    axf.text(0.0, 0.98, txt, va="top", ha="left", fontsize=10.5,
             family="monospace", transform=axf.transAxes)

    fig.suptitle(
        r"Chiral excitation: co-rotating drive excites, counter-rotating does not "
        r"($^{151}$Eu $F$=6 dipolar BEC, $\Omega=\omega_L$=0.5)",
        fontsize=14, y=0.99)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
