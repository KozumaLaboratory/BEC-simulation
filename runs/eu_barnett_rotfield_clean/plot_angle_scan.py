#!/usr/bin/env python3
"""Cone-angle scan of the field-UP one-sided excitation: what tilt angle is best.

Single tilted field of fixed magnitude B (gamma*B=5.1) precessing about +z:
  B_par = B cos(theta) -> omega_L = 5.1 cos(theta) (= resonant Omega, the gap)
  B_perp = B sin(theta) -> drive Rabi rate Omega_R = 5.1 sin(theta)
Small theta: large gap (spontaneous relaxation frozen) + slow but very
selective resonant flip. Large theta: gap shrinks (relaxation returns, vortices
grow) + fast but poorly selective flip (counter-rotating no longer detuned).

Reads traj_cone_th{12,25,40,55}_{res,off}.csv from run_angle_scan.jl.
Metric of the resonant Rabi drive = the Fz swing max-min; selectivity =
resonant swing / off-resonant swing. Line-based (no heatmaps).
"""
import csv, os
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "cone_angle_scan")
THETAS = [12, 25, 40, 55]
GB = 5.1


def load(tag):
    p = os.path.join(HERE, f"traj_cone_{tag}.csv")
    if not os.path.exists(p):
        return None
    r = list(csv.DictReader(open(p)))
    return {k: np.array([float(x[k]) for x in r]) for k in ("t", "Fx", "Fy", "Fz", "Fmag", "Lz")}


def swing(d):
    return np.max(d["Fz"]) - np.min(d["Fz"])


def main():
    res = {th: load(f"th{th:02d}_res") for th in THETAS}
    off = {th: load(f"th{th:02d}_off") for th in THETAS}
    ths = [th for th in THETAS if res[th] is not None]
    if not ths:
        print("no cone runs yet")
        return

    sw_r = [swing(res[th]) for th in ths]
    sw_o = [swing(off[th]) if off[th] is not None else np.nan for th in ths]
    lz_r = [np.max(np.abs(res[th]["Lz"])) for th in ths]
    lz_o = [np.max(np.abs(off[th]["Lz"])) if off[th] is not None else np.nan for th in ths]
    sel = [r / o if (o and o == o and o > 1e-6) else np.nan for r, o in zip(sw_r, sw_o)]

    fig = plt.figure(figsize=(15.5, 4.8))
    gs = fig.add_gridspec(1, 3, wspace=0.42)

    # (a) resonant vs off-resonant excitation (Fz swing) vs theta
    axa = fig.add_subplot(gs[0, 0])
    axa.plot(ths, sw_r, "o-", color=fs.NEG, lw=2.3, ms=8, label=r"$+\Omega$ resonant (Rabi swing)")
    axa.plot(ths, sw_o, "s--", color=fs.POS, lw=2.0, ms=7, label=r"$-\Omega$ off-resonant")
    axa.set_xlabel(r"cone angle $\theta$ (deg)")
    axa.set_ylabel(r"$\langle F_z\rangle$ swing (max$-$min)")
    axa.set_title("(a) resonant flip vs off-resonant")
    axa.legend(fontsize=8.5); axa.grid(alpha=0.3)

    # (b) selectivity + vortices vs theta (twin axis)
    axb = fig.add_subplot(gs[0, 1])
    axb.plot(ths, sel, "D-", color="#5b5f6b", lw=2.3, ms=8, label="selectivity (res/off swing)")
    axb.set_xlabel(r"cone angle $\theta$ (deg)")
    axb.set_ylabel("selectivity (res / off)")
    axb.set_title(r"(b) one-sidedness $\downarrow$, vortices $\uparrow$ with $\theta$")
    axb.grid(alpha=0.3)
    axr = axb.twinx()
    axr.plot(ths, lz_r, "o-", color=fs.NEG, lw=1.8, ms=6, label=r"peak $|L_z|$ ($+\Omega$)")
    axr.plot(ths, lz_o, "s--", color=fs.POS, lw=1.8, ms=6, label=r"peak $|L_z|$ ($-\Omega$)")
    axr.set_ylabel(r"peak $|L_z|$ (vortices)")
    l1, la = axb.get_legend_handles_labels()
    l2, lb = axr.get_legend_handles_labels()
    axb.legend(l1 + l2, la + lb, fontsize=7.5, loc="lower left")

    # (c) resonant Fz(t), zoomed to the first few Rabi flops (faster at larger theta)
    axc = fig.add_subplot(gs[0, 2])
    cmap = plt.cm.viridis(np.linspace(0.15, 0.85, len(ths)))
    for th, c in zip(ths, cmap):
        d = res[th]
        m = d["t"] <= 8.0
        axc.plot(d["t"][m], d["Fz"][m], color=c, lw=2.0,
                 label=rf"$\theta$={th}° ($\Omega_R$={GB*np.sin(np.radians(th)):.1f})")
    axc.axhline(0, color="k", lw=0.6)
    axc.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axc.set_ylabel(r"$\langle F_z\rangle$ ($\hbar$/atom)")
    axc.set_title(r"(c) resonant flip is faster at larger $\theta$")
    axc.legend(fontsize=8, loc="lower right"); axc.grid(alpha=0.3)

    fig.suptitle(
        r"Best field tilt for field-UP chiral excitation ($^{151}$Eu $F$=6, $m$=+$F$ metastable, $\gamma B$=5.1)",
        fontsize=13, y=1.03)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")
    for th, r, o, s, l in zip(ths, sw_r, sw_o, sel, lz_r):
        print(f"  theta={th}: swing_res={r:.2f} swing_off={o:.2f} sel={s:.1f} peakLz_res={l:.2f}")


if __name__ == "__main__":
    main()
