#!/usr/bin/env python3
"""fig5: the stir rate sets HOW MUCH, not HOW EFFICIENTLY.

The injected L_z is a driven response and is resonant; the conversion efficiency
follows from J_z conservation with the DDI as the only spin-orbit channel once
B = 0, and neither of those references the drive. So the prediction, registered
before the scan: injection peaked, efficiency flat.

The earlier scan was three points at box 42 read from job logs, two of whose
ledgers are gone. This one is 12 points at Omega = 0.55 ... 1.20, ALL at box 35 —
one geometry, because a resonance curve assembled across two boxes is not one
curve. The stir output is already converged at box 35 (J_z at quench start
8.6904 / 8.7026 / 8.7052 at box 35 / 42 / 46.67, spread 0.17 %).

Refuses to report on a run that was killed mid-stir: `quench_slice` raises on a
ledger that never reached t = 30, so a truncated arm cannot enter the curve as a
low point. That is exactly how the previous scan's om040/095/120 files would have
read if plotted naively — their L_z at the last sample is not their injection.

Usage: python3 runs/eu_barnett_redo/fig5_omega_resonance.py [--min-points N]
"""
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from ledger_io import DATA, load, quench_slice

FIGS = DATA.parent / "figures"
FIGS.mkdir(exist_ok=True)

# TWO SCANS, AND THEY MUST NOT BE MIXED. `sudden90` is the published protocol —
# theta = 90, the field appearing already rotating, quench at t = 30. `adia35` is the
# thesis protocol — theta = 35 with a 5 + 5 adiabatic entry, so its quench is at
# t = 40. Slicing an adia35 ledger at 30 would take the last 10 units of the steady
# stage and call them the quench, which is why t_stir travels with the set.
#
# The 0.74 adiabatic point was submitted before the scan and carries the reference
# arm's tag (`_ad35_omp`) rather than `_ad35_om074`; the map below is where that
# irregularity is absorbed instead of being papered over with a glob.
SETS = {
    "sudden90": dict(
        t_stir=30.0,
        title=r"published protocol: $\theta=90^\circ$, sudden start",
        files={om: f"ledger_plus_om{int(round(om*100)):03d}_prod_box35.csv"
               for om in [0.55, 0.60, 0.65, 0.70, 0.74, 0.80, 0.85, 0.90, 0.95,
                          1.00, 1.10, 1.20]}),
    "adia35": dict(
        t_stir=40.0,
        title=r"thesis protocol: $\theta=35^\circ$, adiabatic entry",
        files={**{om: f"ledger_plus_ad35_om{int(round(om*100)):03d}_prod_box35.csv"
                  for om in [0.40, 0.55, 0.70, 0.80, 0.85, 0.90, 0.95, 1.00, 1.20]},
               0.74: "ledger_plus_ad35_omp_prod_box35.csv"}),
}
WHICH = "sudden90"
MIN_POINTS = 8
for a in sys.argv[1:]:
    if a.startswith("--min-points="):
        MIN_POINTS = int(a.split("=", 1)[1])
    elif a.startswith("--set="):
        WHICH = a.split("=", 1)[1]
if WHICH not in SETS:
    sys.exit(f"--set must be one of {sorted(SETS)}")
SPEC = SETS[WHICH]
OMEGAS = sorted(SPEC["files"])
T_QUENCH_START = SPEC["t_stir"]

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})

# THE EFFICIENCY IS ONLY READABLE WHERE THE LEDGER IS TIGHT. At B = 0 the ledger is
# exact, so 1 - eff == leak/|dLz| identically — and on the box-35 scan it does, to
# four decimals at every Omega. At Omega = 0.90 the leak is 0.352 of a 1.781 orbital
# loss, so "efficiency 0.80" there is a statement about the BOX at that injection and
# not about conversion. The injection itself is unaffected: it is read at the quench
# start, before any of that accumulates.
#
# So the two panels have different admission rules, and the figure says which points
# cleared which. A single "efficiency vs Omega" curve drawn over all of them would be
# reporting the leak as physics.
LEAK_GATE = 0.05
T_FULL = T_QUENCH_START + 50.0

rows, skipped = [], []
for om in OMEGAS:
    fn = SPEC["files"][om]
    try:
        d = load(fn)
        i, dfz, dlz, leak = quench_slice(d, t_stir=T_QUENCH_START)
        complete = d["t"][-1] >= T_FULL - 1e-9
        lr = abs(leak) / max(abs(dlz), 1e-12)
        rows.append(dict(om=om, inj=d["Lz"][i], jz=d["Jz"][i], dfz=dfz, dlz=dlz,
                         eff=dfz / abs(dlz), leak=leak, leak_ratio=lr,
                         edge=d["edge_frac"].max(), t_end=d["t"][-1],
                         complete=complete, eff_ok=complete and lr < LEAK_GATE))
    except (FileNotFoundError, ValueError) as e:
        skipped.append((om, fn, str(e).split("\n")[0][:90]))

# A curve is not a curve at three points, and a scan that silently drops arms
# reports the reach of its own file glob. Both are named, and too few points is a
# refusal rather than a thinner figure.
if skipped:
    print(f"NOT USABLE ({len(skipped)} of {len(OMEGAS)}):")
    for om, fn, why in skipped:
        print(f"  Omega={om:4.2f}  {fn}\n      {why}")
if len(rows) < MIN_POINTS:
    sys.exit(f"only {len(rows)} usable points of {len(OMEGAS)} (need {MIN_POINTS}); "
             "refusing to draw a resonance curve. Re-run the missing arms or lower "
             "--min-points deliberately.")

om = np.array([r["om"] for r in rows])
inj = np.array([r["inj"] for r in rows])
clean = [r for r in rows if r["eff_ok"]]
dirty = [r for r in rows if r["complete"] and not r["eff_ok"]]

fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.8, 4.1))
a1.plot(om, inj, "o-", lw=1.8, ms=5, color="#1b6ca8")
a1.set_xlabel(r"stir rate  $\Omega$  [$\omega_{\rm ref}$]")
a1.set_ylabel(r"injected $\langle L_z\rangle$ at the quench  [$\hbar$/atom]")
a1.set_title(f"Injection: a driven response, and resonant\n({len(rows)} points, read at "
             f"the quench start)")

if clean:
    a2.plot([r["om"] for r in clean], [r["eff"] for r in clean], "o-", lw=1.8, ms=5,
            color="#c0392b", label=rf"leak $<$ {100*LEAK_GATE:g} % of $|\Delta L_z|$")
if dirty:
    a2.plot([r["om"] for r in dirty], [r["eff"] for r in dirty], "x", ms=8,
            color="#7f8c8d",
            label="leak-dominated — this is the box,\nnot the conversion")
a2.axhline(1.0, color="k", lw=0.8, ls=":", alpha=0.6)
a2.set_ylim(0.75, 1.03)
a2.set_xlabel(r"stir rate  $\Omega$  [$\omega_{\rm ref}$]")
a2.set_ylabel(r"$\Delta\langle F_z\rangle\,/\,|\Delta\langle L_z\rangle|$")
a2.set_title("Efficiency: only where the ledger is tight\n"
             r"($1-\mathrm{eff} \equiv \mathrm{leak}/|\Delta L_z|$ exactly)")
a2.legend(loc="lower left", fontsize=8, framealpha=0.92)
fig.suptitle("The stir rate sets how much, not how efficiently — box 35, one geometry\n"
             + SPEC["title"], y=1.06)
fig.text(0.5, -0.02, f"{len(rows)} points at box 35 (240x240x120), dx = 7/48, dt = 1e-3, quench at t = {T_QUENCH_START:g}",
         ha="center", fontsize=8, alpha=0.75)
out_png = FIGS / f"fig5_omega_resonance_{WHICH}.png"
fig.savefig(out_png)
plt.close(fig)
print("wrote", out_png)

print(f"\n{'Omega':>6} {'injected Lz':>12} {'dFz':>8} {'dLz':>9} {'efficiency':>11} "
      f"{'leak/|dLz|':>10} {'edge':>10}  status")
for r in rows:
    st = "ok" if r["eff_ok"] else ("LEAK-DOMINATED" if r["complete"] else "incomplete")
    eff = f"{r['eff']:11.4f}" if r["eff_ok"] else f"{'('+format(r['eff'],'.4f')+')':>11}"
    print(f"{r['om']:6.2f} {r['inj']:12.4f} {r['dfz']:8.4f} {r['dlz']:9.4f} {eff} "
          f"{r['leak_ratio']:10.4f} {r['edge']:10.2e}  {st}")
print(f"\nefficiency admitted at {len(clean)} of {len(rows)} points "
      f"(gate: leak < {100*LEAK_GATE:g} % of |dLz|, and the run finished)")

i_pk = int(np.argmax(inj))
print(f"\ninjection peak at Omega = {om[i_pk]:.2f}  ({inj[i_pk]:.3f}), "
      f"spanning {inj.min():.3f} - {inj.max():.3f}, a factor {inj.max()/max(inj.min(),1e-9):.1f}")
if i_pk in (0, len(om) - 1):
    print("  WARNING: the peak sits on the edge of the scanned range — that is not a "
          "resolved maximum, it is a range that does not contain one.")
if clean:
    e = np.array([r["eff"] for r in clean])
    print(f"efficiency spread over ADMITTED points: {e.min():.4f} - {e.max():.4f} "
          f"({100*(e.max()/e.min()-1):.2f} %)")
else:
    print("efficiency: no point cleared the leak gate — this box cannot answer it here")
