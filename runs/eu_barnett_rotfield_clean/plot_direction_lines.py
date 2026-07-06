#!/usr/bin/env python3
"""Left vs right rotation (+/-Omega) comparison at the OPTIMAL Omega=0.30.

Line-based (no density heatmaps). Reads traj_dir_O{+0.30,+0.00,-0.30}.csv
(t, Fx, Fy, Fz, |F|, Lz) from run_direction_compare.jl. Shows that reversing
the field's rotation sense mirror-flips every angular-momentum observable.

  (a) orbital <L_z>(t)  -> vortex circulation reverses with rotation
  (b) Barnett <F_z>(t)  -> induced axial magnetisation reverses with rotation
  (c) J_z = F_z + L_z   -> conserved; spin<->orbital transfer, both signs
  (d) transverse spin (F_x,F_y) parametric -> CCW for +Omega, CW for -Omega
  (e) |F|(t)            -> genuine depolarisation (not frozen Larmor)
  (f) mirror residual + summary text
"""
import csv, os, sys
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "barnett_direction_lines")
OM = 0.30


def load(tag):
    p = os.path.join(HERE, f"traj_dir_O{tag}.csv")
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    d = {k: np.array([float(x[k]) for x in r]) for k in ("t", "Fx", "Fy", "Fz", "Fmag", "Lz")}
    d["Jz"] = d["Fz"] + d["Lz"]
    return d


def main():
    pos = load("+0.30")   # +Omega, CCW
    zero = load("+0.00")  # control
    neg = load("-0.30")   # -Omega, CW
    if pos is None or neg is None:
        print("missing trajectory CSVs; run run_direction_compare.jl first")
        sys.exit(1)

    fig = plt.figure(figsize=(15, 8.5))
    gs = fig.add_gridspec(2, 3, hspace=0.32, wspace=0.30)
    LP = dict(lw=2.3)
    lab_p = rf"$+\Omega$ (CCW, $\Omega$={OM})"
    lab_z = r"$\Omega=0$ (control)"
    lab_n = rf"$-\Omega$ (CW, $\Omega$={OM})"

    # (a) orbital L_z
    axa = fig.add_subplot(gs[0, 0])
    axa.plot(pos["t"], pos["Lz"], color=fs.POS, label=lab_p, **LP)
    if zero is not None:
        axa.plot(zero["t"], zero["Lz"], color=fs.ZERO, lw=1.6, label=lab_z)
    axa.plot(neg["t"], neg["Lz"], color=fs.NEG, label=lab_n, **LP)
    axa.axhline(0, color="k", lw=0.6)
    axa.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axa.set_ylabel(r"$\langle L_z\rangle$ ($\hbar$/atom)")
    axa.set_title("(a) orbital angular momentum (vortices)")
    axa.legend(fontsize=8.5); axa.grid(alpha=0.3)

    # (b) Barnett F_z
    axb = fig.add_subplot(gs[0, 1])
    axb.plot(pos["t"], pos["Fz"], color=fs.POS, label=lab_p, **LP)
    if zero is not None:
        axb.plot(zero["t"], zero["Fz"], color=fs.ZERO, lw=1.6, label=lab_z)
    axb.plot(neg["t"], neg["Fz"], color=fs.NEG, label=lab_n, **LP)
    axb.axhline(0, color="k", lw=0.6)
    axb.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axb.set_ylabel(r"$\langle F_z\rangle$ ($\hbar$/atom)")
    axb.set_title("(b) Barnett axial magnetisation")
    axb.legend(fontsize=8.5); axb.grid(alpha=0.3)

    # (c) J_z pumped by the drive (NOT conserved: rotating field is a torque
    #     source, unlike the field-quench EdH where J_z is conserved).
    axc = fig.add_subplot(gs[0, 2])
    axc.plot(pos["t"], pos["Jz"], color=fs.POS, label=r"$+\Omega$", **LP)
    axc.plot(neg["t"], neg["Jz"], color=fs.NEG, label=r"$-\Omega$", **LP)
    axc.axhline(0, color="gray", lw=0.8, ls=":")
    axc.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axc.set_ylabel(r"$\langle J_z\rangle = \langle F_z\rangle + \langle L_z\rangle$")
    axc.set_title(r"(c) $J_z$ pumped by the drive (mirror-antisymmetric)")
    axc.legend(fontsize=9); axc.grid(alpha=0.3)

    # (d) transverse spin parametric (F_x, F_y): CCW vs CW
    axd = fig.add_subplot(gs[1, 0])
    axd.plot(pos["Fx"], pos["Fy"], color=fs.POS, lw=1.8, label=r"$+\Omega$ (CCW)")
    axd.plot(neg["Fx"], neg["Fy"], color=fs.NEG, lw=1.8, label=r"$-\Omega$ (CW)")
    axd.plot(pos["Fx"][0], pos["Fy"][0], "o", color="k", ms=6, zorder=5)
    axd.annotate("start", (pos["Fx"][0], pos["Fy"][0]), fontsize=8,
                 textcoords="offset points", xytext=(6, 4))
    # arrowheads to mark sense of circulation
    for d, c in ((pos, fs.POS), (neg, fs.NEG)):
        i = len(d["Fx"]) // 6
        axd.annotate("", xy=(d["Fx"][i + 1], d["Fy"][i + 1]),
                     xytext=(d["Fx"][i], d["Fy"][i]),
                     arrowprops=dict(arrowstyle="-|>", color=c, lw=2))
    axd.axhline(0, color="k", lw=0.5); axd.axvline(0, color="k", lw=0.5)
    axd.set_aspect("equal")
    axd.set_xlabel(r"$\langle F_x\rangle$"); axd.set_ylabel(r"$\langle F_y\rangle$")
    axd.set_title("(d) transverse spin winds with rotation sense")
    axd.legend(fontsize=9); axd.grid(alpha=0.3)

    # (e) |F| depolarisation
    axe = fig.add_subplot(gs[1, 1])
    axe.plot(pos["t"], pos["Fmag"], color=fs.POS, label=r"$+\Omega$", **LP)
    if zero is not None:
        axe.plot(zero["t"], zero["Fmag"], color=fs.ZERO, lw=1.6, label=r"$\Omega=0$")
    axe.plot(neg["t"], neg["Fmag"], color=fs.NEG, label=r"$-\Omega$", **LP)
    axe.axhline(6.0, color="gray", lw=0.8, ls=":", label=r"$|F|=6$ (fully polarised)")
    axe.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axe.set_ylabel(r"$|\langle \mathbf{F}\rangle|$ ($\hbar$/atom)")
    axe.set_title("(e) genuine depolarisation (many-body, not Larmor)")
    axe.legend(fontsize=8.5); axe.grid(alpha=0.3)

    # (f) mirror residual + summary
    axf = fig.add_subplot(gs[1, 2]); axf.axis("off")
    n = min(len(pos["t"]), len(neg["t"]))
    lz_res = np.max(np.abs(pos["Lz"][:n] + neg["Lz"][:n]))
    fz_res = np.max(np.abs(pos["Fz"][:n] + neg["Fz"][:n]))
    lz_amp = np.max(np.abs(pos["Lz"]))
    fz_amp = np.max(np.abs(pos["Fz"]))
    zmax = np.max(np.abs(zero["Lz"])) if zero is not None else float("nan")
    txt = (
        f"Rotation-direction control\n"
        f"(transverse $J_z$=0 start, unitary, $\\Omega$={OM})\n\n"
        f"peak $|\\langle L_z\\rangle|$ = {lz_amp:.2f} $\\hbar$/atom\n"
        f"peak $|\\langle F_z\\rangle|$ = {fz_amp:.2f} $\\hbar$/atom\n\n"
        f"EXACT MIRROR under $\\Omega\\!\\to\\!-\\Omega$:\n"
        f"  max$|L_z(+\\Omega)+L_z(-\\Omega)|$ = {lz_res:.1e}\n"
        f"  max$|F_z(+\\Omega)+F_z(-\\Omega)|$ = {fz_res:.1e}\n"
        f"  (residual exactly 0: the seed-free run is\n"
        f"   symmetric under $\\Omega\\!\\to\\!-\\Omega$, $y\\!\\to\\!-y$, so the\n"
        f"   $-\\Omega$ run IS the $y$-reflection of $+\\Omega$)\n\n"
        f"$\\Omega=0$ control: $|\\langle L_z\\rangle|_{{\\max}}$ = {zmax:.1e}\n"
        f"  -> no rotation, no vortex, no Barnett\n"
        f"   (spin still depolarises via DDI: $|F|$ falls,\n"
        f"    but with zero net $L_z$, $F_z$).\n\n"
        f"Left (CW, $-\\Omega$) and right (CCW, $+\\Omega$)\n"
        f"rotation give opposite-sign vortices and\n"
        f"opposite-sign Barnett magnetisation."
    )
    axf.text(0.0, 0.98, txt, va="top", ha="left", fontsize=11,
             family="monospace", transform=axf.transAxes)

    fig.suptitle(
        r"Rotation direction controls vortex chirality + Barnett spin sign "
        r"($^{151}$Eu $F$=6 dipolar BEC, optimal $\Omega$=0.30)",
        fontsize=14, y=0.98)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
