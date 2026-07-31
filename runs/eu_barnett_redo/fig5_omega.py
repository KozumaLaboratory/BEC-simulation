#!/usr/bin/env python3
"""fig5: two independent physics, separated by the stir rate.

The stir rate controls how much orbital angular momentum can be injected — a
driven response with a sharp resonance. It does NOT control what fraction of that
angular momentum becomes spin, which is fixed by J_z conservation with the DDI as
the only spin–orbit channel once B = 0.

Prediction, recorded in the commit that added BR_OMEGA and before any of these
runs reported: the efficiency should be FLAT in Ω, and the injected L_z should
not be. Both held — injection varies ~10× across the scan while the efficiency
moves less than 0.3%.

That separation is what makes the 99% claim a statement about the mechanism
rather than about one operating point.

Usage: python3 runs/eu_barnett_redo/fig5_omega.py
"""
import pathlib
import re
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).parent
DATA = HERE / "data"
FIGS = HERE / "figures"
FIGS.mkdir(exist_ok=True)

T_STIR = 30.0

# ledger_plus_om040_prod_box42.csv -> 0.40 ; the Omega=0.74 point is the
# plain box42 run from the box series.
def collect():
    pts = []
    for p in sorted(DATA.glob("ledger_plus_om*_prod_box42.csv")):
        m = re.search(r"_om(\d+)_", p.name)
        if not m:
            continue
        digits = m.group(1)
        omega = float(digits[0] + "." + digits[1:])
        pts.append((omega, p))
    p74 = DATA / "ledger_plus_prod_box42.csv"
    if p74.exists():
        pts.append((0.74, p74))
    return sorted(pts)


rows = []
for omega, p in collect():
    d = np.genfromtxt(p, delimiter=",", names=True)
    i = int(np.argmax(d["t"] >= T_STIR))
    lz_inj = d["Lz"][i]                       # injected by the stir
    dfz = d["Fz"][-1] - d["Fz"][i]
    dlz = d["Lz"][-1] - d["Lz"][i]
    leak = abs(d["Jz"][-1] - d["Jz"][i])
    rows.append((omega, lz_inj, dfz, dlz, dfz / abs(dlz), leak))

if len(rows) < 2:
    raise SystemExit(f"need at least two Omega points, found {len(rows)}")

om = np.array([r[0] for r in rows])
inj = np.array([r[1] for r in rows])
eff = np.array([r[4] for r in rows])

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})
fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.8, 4.1))

a1.plot(om, inj, "o-", color="#1b6ca8", lw=1.9, ms=6)
a1.set_xlabel(r"$\Omega$  [$\omega_{\rm ref}$]")
a1.set_ylabel(r"$\langle L_z\rangle$ injected by the stir  [$\hbar$/atom]")
a1.set_title("How much can be injected:\na driven response, sharply resonant")

a2.plot(om, eff, "o-", color="#c0392b", lw=1.9, ms=6)
a2.axhline(1.0, color="k", lw=0.8, ls=":", alpha=0.6)
a2.set_ylim(0.90, 1.05)
a2.set_xlabel(r"$\Omega$  [$\omega_{\rm ref}$]")
a2.set_ylabel(r"$\Delta\langle F_z\rangle\,/\,|\Delta\langle L_z\rangle|$")
a2.set_title("What fraction becomes spin:\nflat — set by conservation, not by the drive")

fig.suptitle("The stir rate sets how much, not how efficiently", y=1.03)
fig.savefig(FIGS / "fig5_omega.png")
plt.close(fig)
print("wrote", FIGS / "fig5_omega.png")

print(f"\n{'Omega':>7} {'L_z inj':>9} {'dFz':>9} {'dLz':>9} {'efficiency':>11} {'leak':>8}")
for o, lz, f, l, e, k in rows:
    print(f"{o:7.2f} {lz:9.4f} {f:9.4f} {l:9.4f} {e:11.4f} {k:8.4f}")
print(f"\ninjection spread:  {inj.max()/inj.min():.1f}x")
print(f"efficiency spread: {100*(eff.max()/eff.min()-1):.2f}%")
