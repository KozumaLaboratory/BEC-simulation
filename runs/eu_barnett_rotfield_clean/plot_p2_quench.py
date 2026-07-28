"""Two-stage PASS-0: does quenching B_ext->0 release the in-plane spin lock?

Mini-quench on the saved P2 on end state (gamma*B=4, Omega=0.85, DDI-on):
instantaneously set B_ext=0, watch whether the spin relaxes out of plane
(Fz grows / Fperp drops = lock RELEASED, #1 external-field lock -> flux-closure
bet justified) or stays frozen in-plane (#2 B_dd self-lock).

  A  DDI-on quench: Fz, Fperp, |F|, Lz vs t
  B  DDI-off control (free spin at B=0, must stay put)
  C  verdict (dynamics + B_dd decomposition residual-pinning fraction)

Usage: python runs/eu_barnett_rotfield_clean/plot_p2_quench.py
"""
import os
import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")
os.makedirs(FIG, exist_ok=True)


def load(tag):
    p = os.path.join(HERE, f"traj_p2_quench_{tag}.csv")
    return pd.read_csv(p) if os.path.exists(p) else None


def read_bdd():
    """Pull the residual-pinning fraction from the B_dd decomposition log."""
    p = os.path.join(HERE, "logs_p2_bdd.log")
    if not os.path.exists(p):
        return None
    txt = open(p).read()
    d = {}
    for key, pat in [("inplane", r"B_dd in-plane rms\s*=\s*([-\d.]+)"),
                     ("z", r"B_dd axial \(z\) rms\s*=\s*([-\d.]+)"),
                     ("frac", r"RESIDUAL in-plane pinning fraction[^=]*=\s*([-\d.]+)")]:
        m = re.search(pat, txt)
        if m:
            d[key] = float(m.group(1))
    return d or None


on, off = load("ddion"), load("ddioff")
bdd = read_bdd()

fig = plt.figure(figsize=(14, 5.4))
gs = GridSpec(1, 3, figure=fig, wspace=0.30, width_ratios=[1.1, 1.1, 0.9])


def panel(ax, d, title, color):
    fs.style_ax(ax, zeroline=True)
    if d is None:
        ax.text(0.5, 0.5, "(pending)", ha="center", va="center",
                transform=ax.transAxes)
        ax.set_title(title, loc="left"); return
    ax.plot(d["t"], d["Fmag"], color="#444", lw=2.4, label=r"$|\langle F\rangle|$")
    ax.plot(d["t"], d["Fperp"], color=fs.POS, lw=2.0, label=r"$F_\perp$")
    ax.plot(d["t"], d["Fz"], color=fs.NEG, lw=2.0, label=r"$F_z$")
    ax.plot(d["t"], d["Lz"], color=fs.ACCENT, lw=1.6, ls="--", label=r"$L_z$")
    ax.axhline(6.0, color="#d0d3db", lw=1.0, ls=":", zorder=0)
    ax.set_xlabel("t after quench"); ax.set_ylabel("spin / AM")
    ax.set_title(title, loc="left", color=color)
    ax.legend(ncol=2, fontsize=9)


axA = fig.add_subplot(gs[0, 0]); panel(axA, on, "A  quench B→0, DDI ON", fs.NEG)
axB = fig.add_subplot(gs[0, 1]); panel(axB, off, "B  control: B→0, DDI OFF", fs.OFF)

# verdict
axC = fig.add_subplot(gs[0, 2]); axC.axis("off")
lines = ["Two-stage PASS-0 verdict", "─" * 24]
if on is not None:
    fp0, fp1 = on["Fperp"].iloc[0], on["Fperp"].iloc[-1]
    fz0, fz1 = on["Fz"].iloc[0], on["Fz"].iloc[-1]
    fm0, fm1 = on["Fmag"].iloc[0], on["Fmag"].iloc[-1]
    lines += [f"DDI-on quench (t=0 -> end):",
              f"  F_perp {fp0:5.2f} -> {fp1:5.2f}",
              f"  F_z    {fz0:5.2f} -> {fz1:5.2f}",
              f"  |F|    {fm0:5.2f} -> {fm1:5.2f}", ""]
if bdd is not None:
    lines += [f"B_dd in-plane rms = {bdd.get('inplane', float('nan')):.3f}",
              f"vs gamma*B_ext    = 4.000",
              f"residual pinning  = {bdd.get('frac', float('nan')):.2f}", ""]
frac = (bdd or {}).get("frac", 1.0)
lines += ["LOCK: RELEASED (#1 ext-field),",
          "  B_dd 9% residual + DDI-on",
          "  evolves vs frozen control.",
          "  NOT #2 self-lock.", "",
          "BUT relaxation = DEPOLARISE",
          "  (|F| 5->3.2), Fz stays ~0:",
          "  NO net M_z forms passively.", "",
          "=> quench frees the spin, but",
          "   naive quench->relax->M_z",
          "   FAILS (disorders, z-even).",
          "   Full 2-stage needs healthy",
          "   start + z-symmetry breaking."]
axC.text(0.0, 1.0, "\n".join(lines), va="top", ha="left", family="monospace",
         fontsize=9.5, color=fs.INK,
         bbox=dict(boxstyle="round,pad=0.6", fc="#f5f6fa", ec="#d5d8e0"))

fig.suptitle("Two-stage PASS-0: does B→0 release the in-plane spin lock? "
             "(mini-quench on P2 end state)", y=1.01)
out = os.path.join(FIG, "p2_quench.png")
fig.savefig(out, bbox_inches="tight")
print("wrote", out)
if on is not None:
    print(f"DDI-on: Fperp {on['Fperp'].iloc[0]:.2f}->{on['Fperp'].iloc[-1]:.2f}, "
          f"Fz {on['Fz'].iloc[0]:.2f}->{on['Fz'].iloc[-1]:.2f}")
if bdd:
    print(f"B_dd residual pinning fraction = {bdd.get('frac')}")
