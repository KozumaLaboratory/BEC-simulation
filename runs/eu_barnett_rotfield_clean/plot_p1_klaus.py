#!/usr/bin/env python3
"""P1 — Klaus magnetostriction-stirring reproduction in Eu (orbital bench).

Strong in-plane field (spin locked, scalar limit); the field is rotated at
Omega and the elongated (magnetostriction) cloud is stirred. Klaus signatures:
aspect ratio AR(t) grows then COLLAPSES at vortex entry; L_z / N_v jump; the
critical Omega_c ~ 0.7-0.75 w_perp. Reads traj_p1_O*.csv from run_p1_klaus.jl.

Feasibility hooks: the AR(Omega) curve + Omega_c set the delta-Omega sensitivity
(graph 2) and the go/no-go operating-point axis (graph 3); N_v(Omega_c) anchors
the "M_z turns on with vortices" identification in P2.
"""
import csv, os, glob, re
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "figures", "klaus_orbital")
os.makedirs(os.path.dirname(OUT), exist_ok=True)


def load():
    runs = {}
    for p in sorted(glob.glob(os.path.join(HERE, "traj_p1_O*.csv"))):
        m = re.search(r"traj_p1_O([0-9.]+)\.csv", p)
        Om = float(m.group(1))
        r = list(csv.DictReader(open(p)))
        if not r:
            continue
        runs[Om] = {k: np.array([float(x[k]) for x in r]) for k in r[0].keys()}
    return runs


def main():
    runs = load()
    if not runs:
        print("no P1 runs yet")
        return
    Oms = sorted(runs)
    cmap = plt.cm.viridis(np.linspace(0.12, 0.9, len(Oms)))

    fig = plt.figure(figsize=(15, 8.6))
    gs = fig.add_gridspec(2, 2, hspace=0.30, wspace=0.26)

    # (a) AR(t): growth -> collapse
    axa = fig.add_subplot(gs[0, 0])
    for Om, c in zip(Oms, cmap):
        d = runs[Om]
        axa.plot(d["t"], d["AR"], color=c, lw=2, label=rf"$\Omega$={Om:.2f}")
    axa.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); axa.set_ylabel("aspect ratio AR")
    axa.set_title("(a) AR(t): stir growth then vortex-entry collapse")
    axa.legend(fontsize=8, ncol=2); axa.grid(alpha=0.3)

    # (b) L_z(t): circulation
    axb = fig.add_subplot(gs[0, 1])
    for Om, c in zip(Oms, cmap):
        d = runs[Om]
        axb.plot(d["t"], d["Lz"], color=c, lw=2, label=rf"$\Omega$={Om:.2f}")
    axb.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); axb.set_ylabel(r"$\langle L_z\rangle$")
    axb.set_title("(b) circulation builds above threshold")
    axb.legend(fontsize=8, ncol=2); axb.grid(alpha=0.3)

    # (c) N_v(t): vortex count
    axc = fig.add_subplot(gs[1, 0])
    for Om, c in zip(Oms, cmap):
        d = runs[Om]
        if "Nv" in d:
            axc.plot(d["t"], d["Nv"], color=c, lw=1.8, label=rf"$\Omega$={Om:.2f}")
    axc.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$"); axc.set_ylabel(r"$N_v$ (vortex cores)")
    axc.set_title("(c) vortex count vs time")
    axc.legend(fontsize=8, ncol=2); axc.grid(alpha=0.3)

    # (d) Omega_c: threshold summary — late-time L_z, N_v, AR swing vs Omega
    axd = fig.add_subplot(gs[1, 1])
    def latemean(d, k, frac=0.5):
        a = d[k]; return np.mean(a[int(len(a) * frac):])
    lz = [latemean(runs[O], "Lz") for O in Oms]
    nv = [latemean(runs[O], "Nv") if "Nv" in runs[O] else np.nan for O in Oms]
    arsw = [np.max(runs[O]["AR"]) - np.min(runs[O]["AR"]) for O in Oms]
    axd.plot(Oms, lz, "o-", color=fs.POS, lw=2, ms=8, label=r"late $\langle L_z\rangle$")
    axd.plot(Oms, arsw, "^-", color=fs.ZERO, lw=2, ms=7, label="AR swing (max−min)")
    axd.set_xlabel(r"rotation rate $\Omega\ (\omega_\perp)$")
    axd.set_ylabel(r"late $\langle L_z\rangle$ / AR swing")
    axr = axd.twinx()
    axr.plot(Oms, nv, "s--", color=fs.NEG, lw=2, ms=7, label=r"late $N_v$")
    axr.set_ylabel(r"late $N_v$")
    axd.axvline(0.74, color="gray", ls=":", lw=1.2)
    axd.annotate(r"Klaus $\Omega_c\approx0.74$", (0.74, axd.get_ylim()[1]),
                 fontsize=9, ha="center", va="top")
    l1, la = axd.get_legend_handles_labels(); l2, lb = axr.get_legend_handles_labels()
    axd.legend(l1 + l2, la + lb, fontsize=8, loc="upper left")
    axd.set_title(r"(d) threshold $\Omega_c$: circulation + vortices turn on")
    axd.grid(alpha=0.3)

    fig.suptitle(
        r"P1 — Klaus magnetostriction stirring in $^{151}$Eu (scalar limit, orbital bench)",
        fontsize=14, y=0.98)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
