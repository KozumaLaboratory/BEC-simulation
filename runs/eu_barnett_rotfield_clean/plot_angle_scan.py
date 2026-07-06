#!/usr/bin/env python3
"""Cone-angle scan: how the one-sided (chiral) excitation depends on the
field's tilt angle theta, and what angle is best.

Single tilted field of fixed magnitude B (gamma*B=0.5) precessing about +z:
  B_par = B cos(theta) -> Larmor omega_L = 0.5 cos(theta) (= resonant Omega)
  B_perp = B sin(theta) -> drive Rabi rate Omega_R = 0.5 sin(theta)
Small theta = selective but slow; large theta = fast but the counter-rotating
term stops being detuned (selectivity ~ tan(theta)/2). The sweet spot balances
excitation within the metastable relaxation time against one-sidedness.

Reads traj_angle_{nodrive,th15_res,...,th35_off}.csv from run_angle_scan.jl.
Line-based (no heatmaps).
"""
import csv, os, re, math
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "angle_scan")
THETAS = [15, 25, 35, 45, 60]


def load(tag):
    p = os.path.join(HERE, f"traj_angle_{tag}.csv")
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in ("t", "Fx", "Fy", "Fz", "Fmag", "Lz")}


def metrics(d):
    return dict(dFz=d["Fz"][0] - np.min(d["Fz"]),
                pLz=np.max(np.abs(d["Lz"])),
                Fmin=np.min(d["Fmag"]))


def main():
    nod = load("nodrive")
    res = {th: load(f"th{th}_res") for th in THETAS}
    off35 = load("th35_off")
    res = {th: d for th, d in res.items() if d is not None}
    if not res:
        print("no resonant angle runs yet")
        return

    ths = sorted(res)
    dFz = [metrics(res[t])["dFz"] for t in ths]
    pLz = [metrics(res[t])["pLz"] for t in ths]
    base = metrics(nod)["dFz"] if nod is not None else 0.0
    net = [d - base for d in dFz]  # drive-induced excitation above relaxation

    fig = plt.figure(figsize=(15, 5.2))
    gs = fig.add_gridspec(1, 3, wspace=0.30)

    # (a) excitation vs theta
    axa = fig.add_subplot(gs[0, 0])
    axa.plot(ths, dFz, "o-", color=fs.NEG, lw=2.2, ms=8, label=r"spin exc. $\Delta\langle F_z\rangle$")
    axa.plot(ths, pLz, "s-", color=fs.POS, lw=2.2, ms=8, label=r"peak $|\langle L_z\rangle|$ (vortex)")
    if nod is not None:
        axa.axhline(base, color=fs.ZERO, ls="--", lw=1.6,
                    label=f"relaxation only (no drive) = {base:.2f}")
    iopt = int(np.argmax(net))
    axa.axvline(ths[iopt], color="gray", ls=":", lw=1)
    axa.annotate(f"peak drive-\ninduced\n$\\theta$≈{ths[iopt]}°", (ths[iopt], dFz[iopt]),
                 textcoords="offset points", xytext=(8, -6), fontsize=9)
    axa.set_xlabel(r"cone angle $\theta$ (deg)")
    axa.set_ylabel(r"amplitude ($\hbar$/atom)")
    axa.set_title("(a) excitation vs tilt angle")
    axa.legend(fontsize=8.5); axa.grid(alpha=0.3)

    # (b) selectivity: theory tan(theta)/2 off-resonant coupling ratio + measured point
    axb = fig.add_subplot(gs[0, 1])
    tt = np.linspace(5, 85, 200)
    sel = np.tan(np.radians(tt)) / 2.0   # Omega_R / (2 omega_L)
    axb.plot(tt, sel, color="#5b5f6b", lw=2,
             label=r"$\Omega_R/2\omega_L=\tan\theta/2$ (off-res coupling)")
    axb.axhline(1.0, color=fs.NEG, ls=":", lw=1.2, label="selectivity lost (=1)")
    if off35 is not None:
        r35 = metrics(res[35])["dFz"] if 35 in res else np.nan
        o35 = metrics(off35)["dFz"]
        axb.plot([35], [o35 / max(r35, 1e-6)], "D", color=fs.POS, ms=10, zorder=5,
                 label=f"measured off/res @35°={o35/max(r35,1e-6):.2f}")
    axb.set_xlabel(r"cone angle $\theta$ (deg)")
    axb.set_ylabel(r"counter-/co-rotating response")
    axb.set_title(r"(b) one-sidedness degrades as $\theta\to$90°")
    axb.set_ylim(0, 2); axb.legend(fontsize=8.5); axb.grid(alpha=0.3)

    # (c) time traces: relaxation vs resonant(optimum) vs off-resonant
    axc = fig.add_subplot(gs[0, 2])
    if nod is not None:
        axc.plot(nod["t"], nod["Fz"], color=fs.ZERO, lw=1.8, ls="--", label="no drive (relaxation)")
    topt = ths[iopt]
    axc.plot(res[topt]["t"], res[topt]["Fz"], color=fs.NEG, lw=2.4,
             label=rf"resonant $\theta$={topt}° (excites)")
    if off35 is not None:
        axc.plot(off35["t"], off35["Fz"], color=fs.POS, lw=2.0,
                 label=r"off-resonant $\theta$=35° (frozen)")
    axc.axhline(6, color="gray", lw=0.8, ls=":")
    axc.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axc.set_ylabel(r"$\langle F_z\rangle$ ($\hbar$/atom)")
    axc.set_title("(c) excitation vs metastable relaxation time")
    axc.legend(fontsize=8.5); axc.grid(alpha=0.3)

    fig.suptitle(
        r"Best field tilt angle for chiral excitation ($^{151}$Eu $F$=6, field UP, "
        r"$m$=+$F$ metastable, $\gamma B$=0.5)", fontsize=13, y=1.02)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf  (optimum theta ~ {ths[iopt]} deg)")


if __name__ == "__main__":
    main()
