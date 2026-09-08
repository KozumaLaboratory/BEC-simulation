#!/usr/bin/env python3
"""fig4: the absolute conversion does not converge — the efficiency does.

ΔF_z is a TRANSIENT: it grows monotonically through the whole quench and grows with
the box (0.924 / 1.013 / 1.061 at xy half-box 35 / 42 / 46.67, dx held at 7/48
exactly). Both dependences have one cause — after the quench the cloud expands
freely, so a wider box and a longer window each let the relaxation run further.
Quoting a number for it means quoting the window.

The ratio is not a transient. ΔF_z / |ΔL_z| sits at 0.99 for every box and at every
time in the quench, because it asks a question that does not reference the window:
*of the orbital angular momentum that was lost, what fraction became spin?*

TWO SERIES, NOT THREE, AND THAT IS THE HONEST PICTURE (audit 2026-08-25):

* box 35 is the `minus` cell — there is no box-35 `plus` run and there never was.
  The ratio is even under the mirror, so this costs nothing; the figure says so.
* box 42's time series was **overwritten** by an Omega-scan job that resolved to the
  same output name. Only its `leak_scan` summary line survives, so it enters as a
  single endpoint marker rather than a curve. Drawing it as a curve is what the
  previous version of this script did, silently, from the wrong run.

Every input is required. A missing or mismatched file raises — see ledger_io.py.

Usage: python3 runs/eu_barnett_redo/fig4_efficiency.py
"""
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from ledger_io import DATA, T_STIR, mirror, quench_slice, scan_rows, verify

FIGS = DATA.parent / "figures"
FIGS.mkdir(exist_ok=True)

# (xy half-box, file, grid, cell, mirror?) — every one of these must load.
SERIES = [
    (35.0, "ledger_minus_prod_box35.csv", "(240, 240, 120)", "minus", True, "#7f8c8d"),
    (46.67, "ledger_plus_prod_box47.csv", "(320, 320, 120)", "plus", False, "#c0392b"),
]
# Summary-only points: (xy half-box, grid, cell, conv, leak) read from leak_scan.
SUMMARY_ONLY = [(42.0, "(288, 288, 120)", "plus", 1.013251, 0.008564)]

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})

fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.8, 4.1))
rows = []

for box, fn, npts, cell, do_mirror, col in SERIES:
    d = verify(fn, npts=npts, cell=cell)
    if do_mirror:
        d = mirror(d)
    i, dfz_end, dlz_end, leak = quench_slice(d)
    m = d["t"] >= T_STIR
    t = d["t"][m]
    dfz = d["Fz"][m] - d["Fz"][i]
    dlz = d["Lz"][m] - d["Lz"][i]
    lab = rf"box ${box:g}$" + (" (mirror image)" if do_mirror else "")
    a1.plot(t, dfz, lw=1.9, color=col, label=lab)
    good = np.abs(dlz) > 1e-3
    a2.plot(t[good], dfz[good] / np.abs(dlz[good]), lw=1.9, color=col, label=lab)
    rows.append((box, dfz_end, dlz_end, dfz_end / abs(dlz_end), leak, fn))

# The summary-only point is cross-checked too: its numbers must be present in a
# leak_scan row, so a typo here cannot invent an agreement.
for box, npts, cell, conv, leak in SUMMARY_ONLY:
    hit = [r for r in scan_rows("leak_scan_prod.csv")
           if r["cell"] == cell and r["npts"].replace(" ", "") == npts.replace(" ", "")
           and abs(float(r["conv"]) - conv) < 1e-6 and abs(float(r["leak"]) - leak) < 1e-6]
    if not hit:
        raise LookupError(f"box {box}: no leak_scan row with conv={conv} leak={leak}")
    dlz = abs(float(hit[0]["dLz"]))
    eff = conv / dlz
    a1.plot([80.0], [conv], marker="D", ms=6, color="#1b6ca8", ls="none",
            label=rf"box ${box:g}$ (summary only)")
    a2.plot([80.0], [eff], marker="D", ms=6, color="#1b6ca8", ls="none",
            label=rf"box ${box:g}$ (summary only)")
    rows.append((box, conv, -dlz, eff, leak, "leak_scan_prod.csv"))

a1.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
a1.set_ylabel(r"$|\Delta\langle F_z\rangle|$  since quench  [$\hbar$/atom]")
a1.set_title("Absolute conversion: a transient\n(still rising at the end of the window)")
a1.legend(loc="upper left", framealpha=0.92, fontsize=9)

a2.axhline(1.0, color="k", lw=0.8, ls=":", alpha=0.6)
a2.set_ylim(0.90, 1.05)
a2.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
a2.set_ylabel(r"$\Delta\langle F_z\rangle\,/\,|\Delta\langle L_z\rangle|$")
a2.set_title("Efficiency: flat in time AND in box\n" r"$\simeq 0.99$ everywhere")
a2.legend(loc="lower right", framealpha=0.92, fontsize=9)

fig.suptitle("Orbital angular momentum is not dissipated — it becomes spin", y=1.03)
fig.savefig(FIGS / "fig4_efficiency.png")
plt.close(fig)
print("wrote", FIGS / "fig4_efficiency.png")

print(f"\n{'box':>7} {'dFz':>9} {'dLz':>9} {'efficiency':>11} {'leak':>9}  source")
for b, f, l, e, k, src in sorted(rows):
    print(f"{b:7.2f} {f:9.4f} {l:9.4f} {e:11.4f} {k:9.4f}  {src}")
effs = [r[3] for r in rows]
convs = [abs(r[1]) for r in rows]
print(f"\nAbsolute conversion spread across boxes: {100*(max(convs)/min(convs)-1):.0f}%")
print(f"Efficiency spread across boxes:           {100*(max(effs)/min(effs)-1):.1f}%")
print(f"Series with a full time series: {len(SERIES)} of {len(SERIES)+len(SUMMARY_ONLY)}")
