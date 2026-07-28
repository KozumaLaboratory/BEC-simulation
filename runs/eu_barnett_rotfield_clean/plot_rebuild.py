"""Two-stage Barnett in the Jz-cleaner bigger box (TSUBAME box±10/n80) vs the
box-12 overflow artifact. Headline: the box-overflow leak had INVERTED the
physics — box-12 said "vortex AM lost, Fz=-0.44"; the clean box shows vortex
orbital AM CONVERTING to a real net axial magnetisation (Fz -> +2.08).

  A  quench Fz(t): box-12 (artifact) vs box-20 (clean) — the reversal
  B  box-20 quench: Lz drops + Fz rises = orbital->spin conversion
  C  box-20: |F| depolarises to ~axial + edge-fraction stays ~0 (box fix works)
  D  box-20 Jz(t): stir pumps it; quench has a residual drift (to close next)

Usage: python runs/eu_barnett_rotfield_clean/plot_rebuild.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")
RB = os.path.join(HERE, "rebuild_tsubame")

q20 = pd.read_csv(os.path.join(RB, "traj_quench.csv"))
s20 = pd.read_csv(os.path.join(RB, "traj_stir.csv"))
q12 = pd.read_csv(os.path.join(HERE, "traj_p2_quench_healthy_ddion.csv"))

fig = plt.figure(figsize=(14, 8.4))
gs = GridSpec(2, 2, figure=fig, hspace=0.34, wspace=0.26)

# A: the reversal
axA = fig.add_subplot(gs[0, 0]); fs.style_ax(axA, zeroline=True)
axA.plot(q12["t"], q12["Fz"], color=fs.OFF, lw=2.0, label="box±6 (overflow artifact)")
axA.plot(q20["t"], q20["Fz"], color=fs.NEG, lw=2.4, label="box±10 (clean)")
axA.axhline(2.08, color=fs.NEG, ls="--", lw=1.0, alpha=0.6)
axA.axhline(-0.44, color=fs.OFF, ls="--", lw=1.0, alpha=0.6)
axA.set_xlabel("t after quench"); axA.set_ylabel(r"$\langle F_z\rangle$ (net M$_z$)")
axA.set_title("A  the box artifact inverted the physics", loc="left")
axA.legend(fontsize=9)

# B: orbital->spin conversion (box-20)
axB = fig.add_subplot(gs[0, 1]); fs.style_ax(axB, zeroline=True)
axB.plot(q20["t"], q20["Lz"], color=fs.POS, lw=2.4, label=r"$L_z$ (orbital)")
axB.plot(q20["t"], q20["Fz"], color=fs.NEG, lw=2.4, label=r"$F_z$ (spin)")
axB.annotate("", xy=(45, 5.7), xytext=(45, 2.1),
             arrowprops=dict(arrowstyle="<->", color=fs.INK, lw=1.2))
axB.text(46, 3.9, "orbital→spin", fontsize=9, color=fs.INK)
axB.set_xlabel("t after quench"); axB.set_ylabel("angular momentum")
axB.set_title("B  vortex L$_z$ converts to spin F$_z$", loc="left")
axB.legend(fontsize=9)

# C: |F| + edge fraction
axC = fig.add_subplot(gs[1, 0]); fs.style_ax(axC)
axC.plot(q20["t"], q20["Fmag"], color="#444", lw=2.4, label=r"$|\langle F\rangle|$")
axC.plot(q20["t"], q20["Fz"], color=fs.NEG, lw=1.6, ls="--", label=r"$F_z$ (→ axial)")
axC.axhline(6.0, color="#d0d3db", lw=1.0, ls=":")
axC.set_xlabel("t after quench"); axC.set_ylabel(r"$|F|$")
axC.set_ylim(0, 6.3)
axCr = axC.twinx()
axCr.plot(q20["t"], q20["edge_frac"], color=fs.ACCENT, lw=1.6, alpha=0.8)
axCr.set_ylabel("edge fraction", color=fs.ACCENT); axCr.set_ylim(0, 0.05); axCr.grid(False)
axCr.axhline(0.03, color=fs.ACCENT, ls=":", lw=1.0, alpha=0.6)
axC.set_title("C  |F| →axial; edge~0 (box fix holds)", loc="left")
axC.legend(fontsize=9, loc="center right")

# D: Jz over full run (stir + quench)
axD = fig.add_subplot(gs[1, 1]); fs.style_ax(axD, zeroline=True)
axD.plot(s20["t"], s20["Jz"], color=fs.ZERO, lw=1.6, label="Jz (stir: field pumps)")
axD.plot(s20["t"].iloc[-1] + q20["t"], q20["Jz"], color=fs.INK, lw=2.4,
         label="Jz (quench)")
axD.plot(s20["t"].iloc[-1] + q20["t"], q20["Lz"], color=fs.POS, lw=1.2, alpha=0.6, label="Lz")
axD.plot(s20["t"].iloc[-1] + q20["t"], q20["Fz"], color=fs.NEG, lw=1.2, alpha=0.6, label="Fz")
axD.axvline(s20["t"].iloc[-1], color="#b8bcc8", lw=1.0, ls="--")
axD.text(s20["t"].iloc[-1] + 1, axD.get_ylim()[1] * 0.9, "quench", fontsize=8)
axD.set_xlabel("t (stir → quench)"); axD.set_ylabel(r"$J_z, L_z, F_z$")
axD.set_title("D  Jz: quench residual drift 11.1→7.8 (to close)", loc="left")
axD.legend(fontsize=8, ncol=2)

fig.suptitle("Two-stage Barnett in a Jz-cleaner box: vortex orbital→spin gives a "
             "REAL net M$_z$ (box±6 artifact overturned)", y=1.0)
out = os.path.join(FIG, "rebuild_boxfix.png")
fig.savefig(out, bbox_inches="tight")
print("wrote", out)
w = q20[q20["t"] >= 33]
print(f"box-20 quench: Fz {q20.Fz.iloc[0]:+.2f}->{w.Fz.mean():+.2f}, Lz {q20.Lz.iloc[0]:+.1f}->{q20.Lz.iloc[-1]:+.1f}, "
      f"Jz drift {q20.Jz.iloc[0]-q20.Jz.iloc[-1]:+.2f}, edge_max {q20.edge_frac.max():.4f}")
