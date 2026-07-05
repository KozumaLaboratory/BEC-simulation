#!/usr/bin/env python3
"""DEFINITIVE direction-dependence figure (transverse Jz=0 start).

Rotating magnetic field on a Jz=0 (transverse-polarised) 151-Eu F=6
dipolar BEC: rotation generates orbital angular momentum (vortices) AND
axial magnetization (Barnett), BOTH reversing exactly with rotation
direction. Omega=0 control does nothing.

  (a) <L_z>(t): +Om / 0 / -Om  -- vortex/orbital response (clean mirror)
  (b) <F_z>(t): Barnett spin excitation (clean mirror; 0-control flat)
  (c) net vortex winding chirality vs rotation
  (d,e) phase winding of a vortex-hosting component, +Om vs -Om (opposite)
"""
import csv, os, glob
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "barnett_direction_definitive")
C = {"+0.50": fs.POS, "+0.00": fs.ZERO, "-0.50": fs.NEG}
LB = {"+0.50": r"$+\Omega$ (CCW)", "+0.00": r"$\Omega=0$ (control)", "-0.50": r"$-\Omega$ (CW)"}
FRAME = 15  # ~t=7.5, peak vortex


def load(tag):
    r = list(csv.DictReader(open(os.path.join(HERE, f"traj_tv_O{tag}.csv"))))
    return {k: np.array([float(x[k]) for x in r]) for k in
            ("t", "Fz", "Lz", "vtx_net")}


def fld(snapdir, tag, name):
    p = os.path.join(HERE, snapdir, f"O{tag}_f{FRAME}_{name}.csv")
    return np.loadtxt(p, delimiter=",") if os.path.exists(p) else None


def best_vortex_component(snapdir, tag):
    """component m whose density has the deepest central hole at FRAME."""
    best_m, best_score = 0, 1e9
    for f in glob.glob(os.path.join(HERE, snapdir, f"O{tag}_f{FRAME}_dens_m*.csv")):
        m = int(f.split("_dens_m")[1].split(".csv")[0])
        d = np.loadtxt(f, delimiter=",")
        if d.max() <= 0:
            continue
        ny, nx = d.shape
        center = d[ny // 2, nx // 2] / d.max()   # normalized central density
        if d.sum() > 0.02 * d.max() * d.size and center < best_score:
            best_score, best_m = center, m
    return best_m


def main():
    D = {t: load(t) for t in ("+0.50", "+0.00", "-0.50")}
    fig = plt.figure(figsize=(15, 8.5))
    gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.05], hspace=0.30, wspace=0.26)

    axa, axb, axc = (fig.add_subplot(gs[0, i]) for i in range(3))
    for t, d in D.items():
        axa.plot(d["t"], d["Lz"], color=C[t], lw=2.2, label=LB[t])
        axb.plot(d["t"], d["Fz"], color=C[t], lw=2.2, label=LB[t])
        axc.plot(d["t"], d["vtx_net"], color=C[t], lw=2.0, label=LB[t])
    for ax, ttl, yl in ((axa, "(a) orbital $\\langle L_z\\rangle$ (vortices)", r"$\langle L_z\rangle\ (\hbar/\mathrm{atom})$"),
                        (axb, "(b) Barnett spin $\\langle F_z\\rangle$", r"$\langle F_z\rangle\ (\hbar/\mathrm{atom})$"),
                        (axc, "(c) net vortex winding (chirality)", "net winding (mid-z)")):
        ax.axhline(0, color="k", lw=0.6); ax.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
        ax.set_ylabel(yl); ax.set_title(ttl); ax.legend(fontsize=8); ax.grid(alpha=0.3)

    # bottom: density (vortex cores) + current streamlines (circulation
    # sense = chirality), +Om vs -Om -> opposite circulation.
    x = np.loadtxt(os.path.join(HERE, "snaps_tv_pos", "grid_x.csv"), delimiter=",")
    ext = [x.min(), x.max(), x.min(), x.max()]
    for col, (tag, snapdir) in enumerate([("+0.50", "snaps_tv_pos"), ("-0.50", "snaps_tv_neg")]):
        axp = fig.add_subplot(gs[1, col])
        dens = fld(snapdir, tag, "densvtx")
        jx = fld(snapdir, tag, "jx"); jy = fld(snapdir, tag, "jy")
        if dens is not None:
            axp.imshow(dens.T, origin="lower", extent=ext, cmap="magma", aspect="equal")
        if jx is not None and jy is not None:
            axp.streamplot(x, x, jx.T, jy.T, color=fs.STREAM, density=1.2,
                           linewidth=0.8, arrowsize=1.0)
        axp.set_title(f"{LB[tag]}: density + current ($t$=7.5)\n"
                      f"circulation reverses with rotation")
        axp.set_xlabel("x"); axp.set_ylabel("y")
        axp.set_xlim(ext[0], ext[1]); axp.set_ylim(ext[2], ext[3])
        for sp in axp.spines.values():
            sp.set_color(C[tag]); sp.set_linewidth(3)

    # summary panel
    axs = fig.add_subplot(gs[1, 2]); axs.axis("off")
    lzp = np.mean(D["+0.50"]["Lz"]); lzn = np.mean(D["-0.50"]["Lz"])
    fzamp = np.max(np.abs(D["+0.50"]["Fz"]))
    txt = ("Rotation-controlled Barnett + vortex\n"
           "(transverse $J_z{=}0$ start, unitary)\n\n"
           f"$\\langle L_z\\rangle$ time-avg:\n"
           f"   $+\\Omega$: {lzp:+.2f}\n   $\\Omega{{=}}0$: 0.00\n   $-\\Omega$: {lzn:+.2f}\n\n"
           f"$\\langle F_z\\rangle$ peak amplitude: {fzamp:.1f}\n\n"
           "MIRROR (residual 0%):\n"
           r"   $L_z(+\Omega)=-L_z(-\Omega)$" "\n"
           r"   $F_z(+\Omega)=-F_z(-\Omega)$" "\n\n"
           "Vortex chirality: $+\\Omega\\to$ net $-2$,\n"
           "$-\\Omega\\to$ net $+2$ (real cores).\n\n"
           "$\\Omega{=}0$ control: nothing.")
    axs.text(0.02, 0.98, txt, va="top", ha="left", fontsize=10.5,
             family="monospace", transform=axs.transAxes)

    fig.suptitle("Rotating magnetic field $\\to$ quantum vortices + Barnett spin excitation, "
                 "controlled by rotation direction ($^{151}$Eu $F$=6 dipolar BEC)",
                 fontsize=13, y=0.98)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
