#!/usr/bin/env python3
"""Three figures for the decisive core. See README.md and data/PROVENANCE.md.

  fig1_ledger.png     L_z, F_z, J_z through stir + quench, with edge_frac.
  fig2_chirality.png  F_z(t) for -Omega / 0 / +Omega.
  fig3_mechanism.png  DDI on vs off — the DDI is what converts.

WHICH CELLS EXIST (audit 2026-08-25). The four-cell set was never run at one
production geometry:

  box 47 (best, edge 2.4e-10) : plus only            -> fig1
  box 42                      : plus, time series OVERWRITTEN by an Omega-scan job
  box 35                      : minus, zero, plus_nodd  -> fig2, fig3
  box 28 (contaminated, 68 %  : all four, and the only geometry where both arms
          leak/conv)            were run -> `--set=box28`, for the mirror check only

So in the production set the `+Omega` curve is drawn as the **xz-reflection image**
of the measured `-Omega` arm and labelled that way. It is not a second measurement:
where both arms were run they agree bit-for-bit after the flip, because the
reflection is a symmetry of the setup and of the cubic grid. What the figure earns
is the Omega = 0 line and the DDI-off line, which could have come out otherwise.

An earlier version of this script skipped any cell whose file was missing and drew
whatever was left. Every input here is required; a missing one raises.

Usage:
  python3 runs/eu_barnett_redo/fig_core.py               # production set
  python3 runs/eu_barnett_redo/fig_core.py --set=box28   # the one-geometry set
"""
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from ledger_io import DATA, T_STIR, mirror, quench_slice, verify

FIGS = DATA.parent / "figures"
FIGS.mkdir(exist_ok=True)

# (file, grid, cell-in-leak_scan, mirror?)
SETS = {
    "prod": {
        "ledger": ("ledger_plus_prod_box47.csv", "(320, 320, 120)", "plus", False),
        "minus": ("ledger_minus_prod_box35.csv", "(240, 240, 120)", "minus", False),
        "zero": ("ledger_zero_prod_box35.csv", "(240, 240, 120)", "zero", False),
        "plus": ("ledger_minus_prod_box35.csv", "(240, 240, 120)", "minus", True),
        "plus_nodd": ("ledger_plus_nodd_prod_box35.csv", "(240, 240, 120)", "plus_nodd", False),
        "note": "ledger: box 47; chirality/mechanism: box 35 ($+\\Omega$ = mirror image)",
    },
    "box28": {
        "ledger": ("ledger_plus_prod_box28.csv", "(128, 128, 80)", "minus", False),
        "minus": ("ledger_minus_prod_box28.csv", "(128, 128, 80)", "minus", False),
        "zero": ("ledger_zero_prod_box28.csv", "(128, 128, 80)", "zero", False),
        "plus": ("ledger_plus_prod_box28.csv", "(128, 128, 80)", "minus", False),
        "plus_nodd": ("ledger_plus_nodd_prod_box28.csv", "(128, 128, 80)", "plus_nodd", False),
        "note": "box 28 — CONTAMINATED (leak 68 % of the conversion); both arms measured",
    },
}
WHICH = "prod"
for a in sys.argv[1:]:
    if a.startswith("--set="):
        WHICH = a.split("=", 1)[1]
if WHICH not in SETS:
    sys.exit(f"--set must be one of {sorted(SETS)}")
SET = SETS[WHICH]
NOTE = SET["note"]

C = {"plus": "#1b6ca8", "minus": "#c0392b", "zero": "#7f8c8d", "plus_nodd": "#e08214"}

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})


def get(key):
    fn, npts, cell, do_mirror = SET[key]
    d = verify(fn, npts=npts, cell=cell)
    return mirror(d) if do_mirror else d


def mark_quench(ax):
    ax.axvline(T_STIR, color="k", lw=0.8, ls="--", alpha=0.6)
    ax.annotate("quench  B$\\to$0", xy=(T_STIR, 1.0), xycoords=("data", "axes fraction"),
                xytext=(4, -12), textcoords="offset points", fontsize=8, alpha=0.75)


# --- fig 1: the ledger -------------------------------------------------------
d = get("ledger")
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

names = d.dtype.names or ()
for key, col, lab in (("edge_x", "#1b6ca8", "$x$"), ("edge_y", "#7f8c8d", "$y$"),
                      ("edge_z", "#c0392b", "$z$")):
    if key in names:
        axe.semilogy(d["t"], np.maximum(d[key], 1e-16), color=col, lw=1.3, label=lab)
if "edge_x" not in names:
    axe.semilogy(d["t"], np.maximum(d["edge_frac"], 1e-16), color="#555", lw=1.4,
                 label="edge (single column)")
axe.axhline(1e-6, color="k", lw=0.9, ls=":", label="target $10^{-6}$")
mark_quench(axe)
axe.set_ylabel("edge\nfraction", fontsize=9)
axe.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
axe.legend(fontsize=8, loc="best")
fig.text(0.5, -0.02, NOTE, ha="center", fontsize=8, alpha=0.75)
fig.savefig(FIGS / "fig1_ledger.png")
plt.close(fig)
print("wrote", FIGS / "fig1_ledger.png")

# --- fig 2: three-point chirality -------------------------------------------
fig, ax = plt.subplots(figsize=(7.0, 4.2))
labels = {"minus": r"$-\Omega$  (CW, measured)",
          "zero": r"$\Omega=0$  (static field, measured)",
          "plus": r"$+\Omega$  (CCW)"}
if SET["plus"][3]:
    labels["plus"] = r"$+\Omega$  (CCW, mirror image of $-\Omega$)"
for cell in ("minus", "zero", "plus"):
    dd = get(cell)
    ax.plot(dd["t"], dd["Fz"], color=C[cell], lw=1.9, label=labels[cell],
            ls="--" if (cell == "plus" and SET["plus"][3]) else "-")
ax.axhline(0.0, color="k", lw=0.7, alpha=0.5)
mark_quench(ax)
ax.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
ax.set_ylabel(r"$\langle F_z\rangle$  [$\hbar$/atom]")
ax.set_title("Axial magnetisation follows the sense of rotation\n"
             r"($\Omega=0$ is a field-on control: a static field exerts no torque)")
ax.legend(loc="best", framealpha=0.92)
fig.text(0.5, -0.03, NOTE, ha="center", fontsize=8, alpha=0.75)
fig.savefig(FIGS / "fig2_chirality.png")
plt.close(fig)
print("wrote", FIGS / "fig2_chirality.png")

# --- fig 3: mechanism (DDI on/off) ------------------------------------------
don, doff = get("plus"), get("plus_nodd")
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
fig.text(0.5, -0.03, NOTE, ha="center", fontsize=8, alpha=0.75)
fig.savefig(FIGS / "fig3_mechanism.png")
plt.close(fig)
print("wrote", FIGS / "fig3_mechanism.png")

# --- numbers for the text ----------------------------------------------------
print(f"\n--- quench-stage summary ({WHICH} set: {NOTE}) ---")
print(f"{'cell':>10} {'dFz':>9} {'dLz':>9} {'Jz leak':>9} {'leak/conv':>10} "
      f"{'edge x':>9} {'edge y':>9} {'edge z':>9}")
for cell in ("ledger", "plus", "minus", "zero", "plus_nodd"):
    dd = get(cell)
    _, dfz, dlz, leak = quench_slice(dd)
    ratio = f"{100*abs(leak)/abs(dfz):8.1f}%" if abs(dfz) > 1e-3 else "       --"
    nm = dd.dtype.names or ()
    edges = [f"{dd[k].max():9.2e}" if k in nm else "       --"
             for k in ("edge_x", "edge_y", "edge_z")]
    print(f"{cell:>10} {dfz:+9.4f} {dlz:+9.4f} {abs(leak):9.4f} {ratio:>10} " + " ".join(edges))
