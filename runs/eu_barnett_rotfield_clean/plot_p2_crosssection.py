"""P2 net-M_z failure-mode diagnosis: z-odd cancellation vs depolarisation.

Reads the cross-section CSVs written by analyze_p2_fz_crosssection.jl and
renders one decisive figure:

  A  z-resolved column integral  int f_z dx dy  (on vs off) -> is it z-ODD?
  B  local |F| = |f|/n averaged per z-slice (on vs off) -> is spin depolarised?
  C  f_z(x,z) slice, DDI-off   (diverging, single-particle uniform tilt)
  D  f_z(x,z) slice, DDI-on    (diverging, z-odd texture if mode a)
  E  |F(x,z)| slice, DDI-on    (0..6; near 6 => mode a, well below => mode b)

Usage: python runs/eu_barnett_rotfield_clean/plot_p2_crosssection.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")


def load_z(tag):
    return pd.read_csv(os.path.join(FIG, f"p2_zprofile_{tag}.csv"))


def load_xz(tag):
    df = pd.read_csv(os.path.join(FIG, f"p2_fzxz_{tag}.csv"))
    xs = np.sort(df["x"].unique())
    zs = np.sort(df["z"].unique())
    piv = lambda col: df.pivot(index="z", columns="x", values=col).values
    return xs, zs, piv("fz"), piv("localF"), piv("n")


zon, zoff = load_z("on"), load_z("off")
xs, zs, fz_on, lf_on, n_on = load_xz("on")
_, _, fz_off, lf_off, n_off = load_xz("off")

fig = plt.figure(figsize=(13.5, 7.6))
gs = GridSpec(2, 3, figure=fig, height_ratios=[1.0, 1.15],
              hspace=0.42, wspace=0.30)

# --- A: z-resolved column f_z ---
axA = fig.add_subplot(gs[0, 0])
fs.style_ax(axA, zeroline=True)
axA.plot(zoff["z"], zoff["Fz_col"], color=fs.OFF, marker="o", ms=4,
         label="DDI off")
axA.plot(zon["z"], zon["Fz_col"], color=fs.NEG, marker="s", ms=4,
         label="DDI on")
axA.set_xlabel("z")
axA.set_ylabel(r"$\int f_z\,dx\,dy$  (column)")
axA.set_title("A  z-resolved axial spin", loc="left")
axA.legend()

# --- B: local |F| per z-slice ---
axB = fig.add_subplot(gs[0, 1])
fs.style_ax(axB)
axB.axhline(6.0, color="#b8bcc8", lw=1.0, ls="--", zorder=0)
axB.plot(zoff["z"], zoff["localF_slice"], color=fs.OFF, marker="o", ms=4,
         label="DDI off")
axB.plot(zon["z"], zon["localF_slice"], color=fs.NEG, marker="s", ms=4,
         label="DDI on")
axB.set_xlabel("z")
axB.set_ylabel(r"$\langle |F| \rangle = |f|/n$  (slice)")
axB.set_ylim(0, 6.4)
axB.set_title("B  local polarisation", loc="left")
axB.legend()

# --- verdict text panel ---
axV = fig.add_subplot(gs[0, 2])
axV.axis("off")
net_on = np.trapezoid(zon["Fz_col"], zon["z"])
absint_on = np.trapezoid(np.abs(zon["Fz_col"]), zon["z"])
cancel_on = 1.0 - abs(net_on) / absint_on if absint_on > 0 else 0.0
net_off = np.trapezoid(zoff["Fz_col"], zoff["z"])
absint_off = np.trapezoid(np.abs(zoff["Fz_col"]), zoff["z"])
cancel_off = 1.0 - abs(net_off) / absint_off if absint_off > 0 else 0.0
lf_on_bulk = np.average(zon["localF_slice"], weights=zon["N_col"])
lf_off_bulk = np.average(zoff["localF_slice"], weights=zoff["N_col"])
txt = (
    "Net-M$_z$ failure mode\n"
    "─────────────────\n"
    f"z-cancellation (on):  {cancel_on:5.2f}\n"
    f"z-cancellation (off): {cancel_off:5.2f}\n\n"
    f"local |F| (on):  {lf_on_bulk:4.2f}\n"
    f"local |F| (off): {lf_off_bulk:4.2f}\n\n"
    "(a) z-odd if cancel≈1 & |F|≈6\n"
    "(b) depol. if |F| « 6"
)
axV.text(0.02, 0.98, txt, va="top", ha="left", family="monospace",
         fontsize=10.5, color=fs.INK,
         bbox=dict(boxstyle="round,pad=0.6", fc="#f5f6fa", ec="#d5d8e0"))

# --- C/D: f_z(x,z) slices, shared diverging scale ---
vmax = np.nanmax(np.abs([fz_on, fz_off]))
ext = [xs.min(), xs.max(), zs.min(), zs.max()]


def heat(ax, data, cmap, vmin, vmax, title, color, cbar_label):
    im = ax.imshow(data, origin="lower", extent=ext, aspect="auto",
                   cmap=cmap, vmin=vmin, vmax=vmax)
    ax.set_title(title, loc="left")
    ax.set_xlabel("x"); ax.set_ylabel("z")
    for s in ax.spines.values():
        s.set_visible(True); s.set_color(color); s.set_linewidth(2.2)
    ax.grid(False)
    cb = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.03)
    cb.set_label(cbar_label, fontsize=9.5)
    return ax


axC = fig.add_subplot(gs[1, 0])
heat(axC, fz_off, "RdBu_r", -vmax, vmax, "C  $f_z(x,z)$  DDI off", fs.OFF,
     r"$f_z$")
axD = fig.add_subplot(gs[1, 1])
heat(axD, fz_on, "RdBu_r", -vmax, vmax, "D  $f_z(x,z)$  DDI on", fs.NEG,
     r"$f_z$")
axE = fig.add_subplot(gs[1, 2])
heat(axE, lf_on, "viridis", 0, 6, "E  $|F(x,z)|$  DDI on", fs.NEG,
     r"$|F|=|f|/n$")

fig.suptitle("P2 single-stage net-M$_z$: why the axial magnetisation vanishes "
             "(y=0 slice, end of stir)", y=0.99)
out = os.path.join(FIG, "p2_crosssection.png")
fig.savefig(out)
print("wrote", out)
print(f"cancel_on={cancel_on:.3f} cancel_off={cancel_off:.3f} "
      f"localF_on={lf_on_bulk:.2f} localF_off={lf_off_bulk:.2f}")
