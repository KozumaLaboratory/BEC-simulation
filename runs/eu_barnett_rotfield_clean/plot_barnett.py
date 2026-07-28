#!/usr/bin/env python3
"""Rotation-direction-controlled vortex + Barnett figure.

Reads trajectory CSVs (traj_O+X.csv / traj_O-X.csv) with columns
  Omega,frame,t,norm,Fz,Lz,Jz,peak,pop_m*,Lz_m*
and 2D field CSVs in snaps/ (O<+/-Om>_f<frame>_<field>.csv) written by
analyze_barnett.jl.

Produces headline figure showing:
  row 1: <L_z>(t), Delta<F_z>(t), EdH co-alignment  -- for +Om and -Om
  row 2: final-time vortex density + phase winding, +Om vs -Om (opposite)
"""
import csv
import glob
import os
import sys

import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RUN = sys.argv[1] if len(sys.argv) > 1 else HERE
SNAP = os.path.join(RUN, "snaps")
OUT = os.path.join(RUN, "figures", "barnett_direction")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

C_POS = "#1f77b4"   # +Omega  (CCW)
C_NEG = "#d62728"   # -Omega  (CW)


def load_traj(path):
    t, Fz, Lz, Jz, norm = [], [], [], [], []
    mcols = None
    pops = {}
    with open(path) as f:
        rd = csv.DictReader(f)
        mcols = [c for c in rd.fieldnames if c.startswith("pop_m")]
        for c in mcols:
            pops[c] = []
        for r in rd:
            t.append(float(r["t"])); Fz.append(float(r["Fz"]))
            Lz.append(float(r["Lz"])); Jz.append(float(r["Jz"]))
            norm.append(float(r["norm"]))
            for c in mcols:
                pops[c].append(float(r[c]))
    return dict(t=np.array(t), Fz=np.array(Fz), Lz=np.array(Lz),
                Jz=np.array(Jz), norm=np.array(norm),
                pops={k: np.array(v) for k, v in pops.items()})


def load_field(otag, frame, field):
    p = os.path.join(SNAP, f"O{otag}_f{frame}_{field}.csv")
    return np.loadtxt(p, delimiter=",") if os.path.exists(p) else None


def last_dump_frame(otag):
    fs = glob.glob(os.path.join(SNAP, f"O{otag}_f*_ntot2d.csv"))
    frames = sorted(int(os.path.basename(x).split("_f")[1].split("_")[0]) for x in fs)
    return frames[-1] if frames else None


def dominant_transferred_m(traj):
    """m component (other than the initial +F) that gained the most pop."""
    mcols = list(traj["pops"].keys())
    # initial peak = +F (pop_m<F>); pick max final pop among the rest
    finals = {c: traj["pops"][c][-1] for c in mcols}
    F = max(int(c.split("pop_m")[1]) for c in mcols)
    cand = {c: finals[c] for c in mcols if int(c.split("pop_m")[1]) != F}
    return int(max(cand, key=cand.get).split("pop_m")[1])


def main():
    pos = load_traj(os.path.join(RUN, "traj_O+0.50.csv"))
    neg = load_traj(os.path.join(RUN, "traj_O-0.50.csv"))

    fig = plt.figure(figsize=(15, 9))
    gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.25], hspace=0.32, wspace=0.28)

    # (a) <L_z>(t)
    axa = fig.add_subplot(gs[0, 0])
    axa.plot(pos["t"], pos["Lz"], color=C_POS, lw=2, label=r"$+\Omega$ (CCW)")
    axa.plot(neg["t"], neg["Lz"], color=C_NEG, lw=2, label=r"$-\Omega$ (CW)")
    axa.axhline(0, color="k", lw=0.6)
    axa.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axa.set_ylabel(r"$\langle L_z\rangle\ (\hbar)$")
    axa.set_title("(a) orbital response = vortex generation")
    axa.legend(fontsize=9); axa.grid(alpha=0.3)

    # (b) Delta<F_z>(t)
    axb = fig.add_subplot(gs[0, 1])
    axb.plot(pos["t"], pos["Fz"] - pos["Fz"][0], color=C_POS, lw=2)
    axb.plot(neg["t"], neg["Fz"] - neg["Fz"][0], color=C_NEG, lw=2)
    axb.axhline(0, color="k", lw=0.6)
    axb.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axb.set_ylabel(r"$\Delta\langle F_z\rangle$")
    axb.set_title("(b) Barnett spin excitation")
    axb.grid(alpha=0.3)

    # (c) EdH co-alignment: Lz vs Delta Fz
    axc = fig.add_subplot(gs[0, 2])
    axc.plot(pos["Lz"], pos["Fz"] - pos["Fz"][0], color=C_POS, lw=1.5, marker="o", ms=2)
    axc.plot(neg["Lz"], neg["Fz"] - neg["Fz"][0], color=C_NEG, lw=1.5, marker="o", ms=2)
    axc.axhline(0, color="k", lw=0.5); axc.axvline(0, color="k", lw=0.5)
    axc.set_xlabel(r"$\langle L_z\rangle$")
    axc.set_ylabel(r"$\Delta\langle F_z\rangle$")
    axc.set_title("(c) EdH oracle: co-aligned")
    axc.grid(alpha=0.3)

    # row 2: vortex density + phase, +Om vs -Om
    for col, (otag, traj, tag, cc) in enumerate([
        ("+0.50", pos, r"$+\Omega$ (CCW)", C_POS),
        ("-0.50", neg, r"$-\Omega$ (CW)", C_NEG),
    ]):
        fr = last_dump_frame(otag)
        m = dominant_transferred_m(traj)
        ax = fig.add_subplot(gs[1, col])
        dens = load_field(otag, fr, f"dens_m{m}")
        phase = load_field(otag, fr, f"phase_m{m}")
        if dens is not None:
            ax.imshow(dens.T, origin="lower", cmap="magma", aspect="equal")
            if phase is not None:
                ax.contour(phase.T, levels=[-np.pi/2, 0, np.pi/2], colors="cyan",
                           linewidths=0.6, alpha=0.7)
        ax.set_title(f"{tag}: $|\\psi_{{m={m:+d}}}|^2$ (transferred)")
        ax.set_xticks([]); ax.set_yticks([])
        for sp in ax.spines.values():
            sp.set_color(cc); sp.set_linewidth(2.5)

    # (f) per-m final Lz bars (vortex charge per component)
    axf = fig.add_subplot(gs[1, 2])
    def final_lz_m(traj):
        cols = sorted([c for c in _lzm_cols(traj)],
                      key=lambda c: -int(c.split("Lz_m")[1]))
        return cols, [traj["_lzm"][c][-1] for c in cols]
    # reload Lz_m columns
    for traj, path in [(pos, "traj_O+0.50.csv"), (neg, "traj_O-0.50.csv")]:
        _attach_lzm(traj, os.path.join(RUN, path))
    cols_p, lz_p = final_lz_m(pos)
    cols_n, lz_n = final_lz_m(neg)
    ms = [int(c.split("Lz_m")[1]) for c in cols_p]
    x = np.arange(len(ms))
    axf.bar(x - 0.18, lz_p, 0.36, color=C_POS, label=r"$+\Omega$")
    axf.bar(x + 0.18, lz_n, 0.36, color=C_NEG, label=r"$-\Omega$")
    axf.axhline(0, color="k", lw=0.6)
    axf.set_xticks(x); axf.set_xticklabels([f"{m:+d}" for m in ms])
    axf.set_xlabel("m"); axf.set_ylabel(r"$\langle L_z\rangle_m$ (final)")
    axf.set_title("(f) per-m vortex charge (opposite sign)")
    axf.legend(fontsize=9); axf.grid(alpha=0.3, axis="y")

    fig.suptitle(
        "Rotating magnetic field -> quantum vortices + Barnett spin excitation "
        "(direction-controlled)\nEu-151 F=1 effective, trapped, full DDI, unitary",
        fontsize=12, y=0.98)
    for ext in ("png", "pdf", "svg"):
        fig.savefig(f"{OUT}.{ext}", bbox_inches="tight",
                    dpi=150 if ext == "png" else None)
    print(f"wrote {OUT}.png/pdf/svg")


def _lzm_cols(traj):
    return traj.get("_lzm", {}).keys()


def _attach_lzm(traj, path):
    with open(path) as f:
        rd = csv.DictReader(f)
        cols = [c for c in rd.fieldnames if c.startswith("Lz_m")]
        d = {c: [] for c in cols}
        for r in rd:
            for c in cols:
                d[c].append(float(r[c]))
    traj["_lzm"] = {c: np.array(v) for c, v in d.items()}


if __name__ == "__main__":
    main()
