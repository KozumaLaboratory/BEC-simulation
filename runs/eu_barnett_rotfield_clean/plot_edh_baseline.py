#!/usr/bin/env python3
"""Einstein-de Haas baseline figure: real vortices + real spin excitation.

Shows (from traj_edh_baseline.csv + snaps_edh/):
  (a) m-population cascade: m=+6 drains down the ladder (spin excitation)
  (b) J_z = <F_z> + <L_z> CONSERVED: spin AM -> orbital AM (the EdH proof)
  (c) vortex census (winding-based) vs time
  (d) late-time density with real vortex cores (holes) + phase winding
"""
import csv, os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "traj_edh_baseline.csv")
SNAP = os.path.join(HERE, "snaps_edh")
OUT = os.path.join(HERE, "edh_baseline")
OTAG = "+0.00"


def load():
    r = list(csv.DictReader(open(CSV)))
    t = np.array([float(x["t"]) for x in r])
    d = {k: np.array([float(x[k]) for x in r]) for k in
         ("Fz", "Lz", "Jz", "vtx_plus", "vtx_minus", "vtx_net", "core_contrast", "peak")}
    ms = sorted((int(k.split("pop_m")[1]) for k in r[0] if k.startswith("pop_m")), reverse=True)
    pops = {m: np.array([float(x[f"pop_m{m}"]) for x in r]) for m in ms}
    return t, d, pops, ms


def fld(frame, name):
    p = os.path.join(SNAP, f"O{OTAG}_f{frame}_{name}.csv")
    return np.loadtxt(p, delimiter=",") if os.path.exists(p) else None


def main():
    t, d, pops, ms = load()
    fig = plt.figure(figsize=(15, 9))
    gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.15], hspace=0.30, wspace=0.28)

    # (a) m-population cascade
    axa = fig.add_subplot(gs[0, 0])
    cmap = cm.get_cmap("coolwarm")
    for m in ms:
        axa.plot(t, pops[m], color=cmap((m + 6) / 12), lw=1.6,
                 label=f"m={m:+d}" if m in (6, 3, 0, -3, -6) else None)
    axa.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axa.set_ylabel("population $|\\psi_m|^2$")
    axa.set_title("(a) spin excitation: m-ladder cascade")
    axa.legend(fontsize=8, ncol=2); axa.grid(alpha=0.3)

    # (b) Jz conservation — the EdH proof
    axb = fig.add_subplot(gs[0, 1])
    axb.plot(t, d["Fz"], color="#d62728", lw=2.2, label=r"$\langle F_z\rangle$ (spin)")
    axb.plot(t, d["Lz"], color="#1f77b4", lw=2.2, label=r"$\langle L_z\rangle$ (orbital)")
    axb.plot(t, d["Jz"], color="k", lw=2.2, ls="--", label=r"$\langle J_z\rangle=F_z+L_z$")
    axb.axhline(6.0, color="gray", lw=0.8, ls=":")
    axb.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axb.set_ylabel("angular momentum ($\\hbar$/atom)")
    axb.set_title("(b) Einstein-de Haas: spin $\\to$ orbital, $J_z$ conserved")
    axb.legend(fontsize=9); axb.grid(alpha=0.3)

    # (c) vortex census
    axc = fig.add_subplot(gs[0, 2])
    axc.plot(t, d["vtx_plus"], color="#1f77b4", lw=1.8, label="+1 windings")
    axc.plot(t, d["vtx_minus"], color="#d62728", lw=1.8, label="-1 windings")
    axc.plot(t, d["vtx_net"], color="k", lw=2.0, ls="--", label="net")
    axc.set_xlabel(r"$t\ (\omega_{\rm ref}^{-1})$")
    axc.set_ylabel("quantized vortices (mid-z)")
    axc.set_title("(c) real vortices (winding census)")
    axc.legend(fontsize=8); axc.grid(alpha=0.3)

    # (d),(e): late-time density hole + phase winding
    x = np.loadtxt(os.path.join(SNAP, "grid_x.csv"), delimiter=",")
    y = np.loadtxt(os.path.join(SNAP, "grid_y.csv"), delimiter=",")
    ext = [x.min(), x.max(), y.min(), y.max()]
    # pick a transferred component with a strong vortex at late frame
    frame = 25
    # choose m component: largest pop among m<6 at late time from data
    late_pops = {m: pops[m][-1] for m in ms if m != 6}
    m_show = max(late_pops, key=late_pops.get)

    axd = fig.add_subplot(gs[1, 0])
    tot = fld(frame, "ntot2d")
    if tot is not None:
        im = axd.imshow(tot.T, origin="lower", extent=ext, cmap="magma", aspect="equal")
        plt.colorbar(im, ax=axd, fraction=0.046)
    axd.set_title(f"(d) total column density, $t$={t[-1]:.0f}\n(vortex cores = dark holes)")
    axd.set_xlabel("x"); axd.set_ylabel("y")

    axe = fig.add_subplot(gs[1, 1])
    dm = fld(frame, f"dens_m{m_show}")
    if dm is not None:
        im = axe.imshow(dm.T, origin="lower", extent=ext, cmap="magma", aspect="equal")
        plt.colorbar(im, ax=axe, fraction=0.046)
    axe.set_title(f"(e) transferred $|\\psi_{{m={m_show:+d}}}|^2$")
    axe.set_xlabel("x"); axe.set_ylabel("y")

    axf = fig.add_subplot(gs[1, 2])
    ph = fld(frame, f"phase_m{m_show}")
    if ph is not None:
        im = axf.imshow(ph.T, origin="lower", extent=ext, cmap="hsv", aspect="equal",
                        vmin=-np.pi, vmax=np.pi)
        plt.colorbar(im, ax=axf, fraction=0.046, label="phase")
    axf.set_title(f"(f) phase of $\\psi_{{m={m_show:+d}}}$ ($2\\pi$ winding = vortex)")
    axf.set_xlabel("x"); axf.set_ylabel("y")

    fig.suptitle(
        "Einstein-de Haas in $^{151}$Eu ($F$=6) dipolar BEC: field quench "
        "drives spin$\\to$orbital transfer (real vortices, no rotation yet)",
        fontsize=13, y=0.97)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")


if __name__ == "__main__":
    main()
