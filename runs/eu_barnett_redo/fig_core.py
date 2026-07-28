#!/usr/bin/env python3
"""Three figures for the decisive core. See README.md.

  fig1_ledger.png     L_z, F_z, J_z through stir + quench, with edge_frac.
  fig2_chirality.png  F_z(t) for minus / zero / plus.
  fig3_mechanism.png  plus vs plus_nodd — the DDI is what converts.

Usage: python3 runs/eu_barnett_redo/fig_core.py [--smoke]
"""
import sys
import pathlib
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).parent
DATA = HERE / "data"
FIGS = HERE / "figures"
FIGS.mkdir(exist_ok=True)

PREFIX = "smoke_" if "--smoke" in sys.argv else ""
T_STIR = 0.4 if PREFIX else 30.0

C = {"plus": "#1b6ca8", "minus": "#c0392b", "zero": "#7f8c8d", "plus_nodd": "#e08214"}

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})


def load(cell):
    p = DATA / f"ledger_{PREFIX}{cell}.csv"
    if not p.exists():
        return None
    return np.genfromtxt(p, delimiter=",", names=True)


def mark_quench(ax):
    ax.axvline(T_STIR, color="k", lw=0.8, ls="--", alpha=0.6)
    ax.annotate("quench  B$\\to$0", xy=(T_STIR, 1.0), xycoords=("data", "axes fraction"),
                xytext=(4, -12), textcoords="offset points", fontsize=8, alpha=0.75)


# --- fig 1: the ledger -------------------------------------------------------
d = load("plus")
if d is None:
    sys.exit(f"missing {DATA}/ledger_{PREFIX}plus.csv — run run_core.jl first")

fig, (ax, axe) = plt.subplots(2, 1, figsize=(7.0, 5.4), sharex=True,
                              gridspec_kw={"height_ratios": [3, 1]})
ax.plot(d["t"], d["Lz"], color="#1b6ca8", lw=1.8, label=r"$\langle L_z\rangle$  (orbital)")
ax.plot(d["t"], d["Fz"], color="#c0392b", lw=1.8, label=r"$\langle F_z\rangle$  (spin)")
ax.plot(d["t"], d["Jz"], color="k", lw=2.2, label=r"$J_z=\langle L_z\rangle+\langle F_z\rangle$")
mark_quench(ax)
ax.set_ylabel(r"angular momentum  [$\hbar$/atom]")
ax.legend(loc="best", framealpha=0.92)
ax.set_title(r"Orbital $\to$ spin conversion with a closed $J_z$ ledger"
             "\n" r"($B=0$ after the quench $\Rightarrow$ $J_z$ is exactly conserved)")

# Per axis, not just the max: the 2026-07-28 batch reported one number covering
# x and y only, and z — the tightest axis — was 400x larger and never seen.
for key, col, lab in (("edge_x", "#1b6ca8", "$x$"), ("edge_y", "#7f8c8d", "$y$"),
                      ("edge_z", "#c0392b", "$z$")):
    if key in (d.dtype.names or ()):
        axe.semilogy(d["t"], np.maximum(d[key], 1e-16), color=col, lw=1.3, label=lab)
if "edge_x" not in (d.dtype.names or ()):
    axe.semilogy(d["t"], np.maximum(d["edge_frac"], 1e-16), color="#555", lw=1.4)
axe.axhline(1e-6, color="k", lw=0.9, ls=":", label="target $10^{-6}$")
mark_quench(axe)
axe.set_ylabel("edge\nfraction", fontsize=9)
axe.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
axe.legend(fontsize=8, loc="best")
fig.savefig(FIGS / "fig1_ledger.png")
plt.close(fig)
print("wrote", FIGS / "fig1_ledger.png")

# --- fig 2: three-point chirality -------------------------------------------
fig, ax = plt.subplots(figsize=(7.0, 4.2))
got = False
for cell, lab in (("minus", r"$-\Omega$  (CW)"),
                  ("zero", r"$\Omega=0$  (static field)"),
                  ("plus", r"$+\Omega$  (CCW)")):
    dd = load(cell)
    if dd is None:
        continue
    got = True
    ax.plot(dd["t"], dd["Fz"], color=C[cell], lw=1.9, label=lab)
if not got:
    sys.exit("no chirality cells found")
ax.axhline(0.0, color="k", lw=0.7, alpha=0.5)
mark_quench(ax)
ax.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
ax.set_ylabel(r"$\langle F_z\rangle$  [$\hbar$/atom]")
ax.set_title("Axial magnetisation reverses with the sense of rotation\n"
             r"($\Omega=0$ is a field-on control: a static field exerts no torque)")
ax.legend(loc="best", framealpha=0.92)
fig.savefig(FIGS / "fig2_chirality.png")
plt.close(fig)
print("wrote", FIGS / "fig2_chirality.png")

# --- fig 3: mechanism (DDI on/off) ------------------------------------------
don, doff = load("plus"), load("plus_nodd")
if doff is None:
    print("skipping fig3 — plus_nodd not run")
else:
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.6, 4.0), sharex=True)
    for a, key, ttl in ((a1, "Lz", r"$\langle L_z\rangle$  (orbital)"),
                        (a2, "Fz", r"$\langle F_z\rangle$  (spin)")):
        a.plot(don["t"], don[key], color="#1b6ca8", lw=1.9, label="DDI on")
        a.plot(doff["t"], doff[key], color="#e08214", lw=1.9, ls="--", label="DDI off")
        a.axhline(0.0, color="k", lw=0.7, alpha=0.5)
        mark_quench(a)
        a.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
        a.set_title(ttl)
        a.legend(loc="best", framealpha=0.92)
    a1.set_ylabel(r"[$\hbar$/atom]")
    fig.suptitle("The DDI is the spin-orbit coupling: without it there is no conversion",
                 y=1.02)
    fig.savefig(FIGS / "fig3_mechanism.png")
    plt.close(fig)
    print("wrote", FIGS / "fig3_mechanism.png")

# --- numbers for the text ----------------------------------------------------
print("\n--- quench-stage summary (B = 0, J_z conserved) ---")
print(f"{'cell':>10} {'dFz':>9} {'dLz':>9} {'Jz leak':>9} {'leak/conv':>10} "
      f"{'edge x':>9} {'edge y':>9} {'edge z':>9}")
for cell in ("plus", "minus", "zero", "plus_nodd"):
    dd = load(cell)
    if dd is None:
        continue
    i = int(np.argmax(dd["t"] >= T_STIR))
    dfz = dd["Fz"][-1] - dd["Fz"][i]
    dlz = dd["Lz"][-1] - dd["Lz"][i]
    leak = abs(dd["Jz"][-1] - dd["Jz"][i])
    ratio = f"{100*leak/abs(dfz):8.1f}%" if abs(dfz) > 1e-3 else "       --"
    names = dd.dtype.names or ()
    edges = [f"{dd[k].max():9.2e}" if k in names else "       --"
             for k in ("edge_x", "edge_y", "edge_z")]
    print(f"{cell:>10} {dfz:+9.4f} {dlz:+9.4f} {leak:9.4f} {ratio:>10} " + " ".join(edges))
