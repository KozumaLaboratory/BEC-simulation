#!/usr/bin/env python3
"""fig4: the absolute conversion does not converge — the efficiency does.

Replaces the earlier dx-convergence panel, which asked the wrong question.

ΔF_z is a TRANSIENT: it grows monotonically through the whole quench (0.27 → 1.06
over t = 40 → 80) and grows with the box (0.92 / 1.01 / 1.06 at box 35 / 42 /
46.7 with dx held at 7/48 exactly). Both dependences have the same cause — after
the quench the cloud expands freely, and a wider box and a longer window each let
the relaxation run further. Quoting a number for it means quoting the window.

The ratio is not a transient. ΔF_z / |ΔL_z| sits at 0.99 for every box and at
every time in the quench, because it asks a question that does not reference the
window at all: *of the orbital angular momentum that was lost, what fraction
became spin?* The answer is ~99%, and the missing 1% is exactly the J_z ledger
leak, which is itself below 1%.

Usage: python3 runs/eu_barnett_redo/fig4_efficiency.py
"""
import pathlib
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).parent
DATA = HERE / "data"
FIGS = HERE / "figures"
FIGS.mkdir(exist_ok=True)

T_STIR = 30.0
SERIES = [
    (35.0, "ledger_plus_prod_box35.csv", "#7f8c8d"),
    (42.0, "ledger_plus_prod_box42.csv", "#1b6ca8"),
    (46.67, "ledger_plus_prod_box47.csv", "#c0392b"),
]

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})

fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.8, 4.1))
rows = []

for box, fn, col in SERIES:
    p = DATA / fn
    if not p.exists():
        continue
    d = np.genfromtxt(p, delimiter=",", names=True)
    i = int(np.argmax(d["t"] >= T_STIR))
    m = d["t"] >= T_STIR
    t = d["t"][m]
    dfz = d["Fz"][m] - d["Fz"][i]
    dlz = d["Lz"][m] - d["Lz"][i]
    a1.plot(t, dfz, lw=1.9, color=col, label=rf"box ${box:g}$")
    good = np.abs(dlz) > 1e-3
    a2.plot(t[good], dfz[good] / np.abs(dlz[good]), lw=1.9, color=col,
            label=rf"box ${box:g}$")
    rows.append((box, dfz[-1], dlz[-1], dfz[-1] / abs(dlz[-1])))

a1.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
a1.set_ylabel(r"$\Delta\langle F_z\rangle$  since quench  [$\hbar$/atom]")
a1.set_title("Absolute conversion: a transient\n(still rising at the end of the window)")
a1.legend(loc="upper left", framealpha=0.92)

a2.axhline(1.0, color="k", lw=0.8, ls=":", alpha=0.6)
a2.set_ylim(0.90, 1.05)
a2.set_xlabel(r"$t$  [$1/\omega_{\rm ref}$]")
a2.set_ylabel(r"$\Delta\langle F_z\rangle\,/\,|\Delta\langle L_z\rangle|$")
a2.set_title("Efficiency: flat in time AND in box\n"
             r"$\simeq 0.99$ everywhere")
a2.legend(loc="lower right", framealpha=0.92)

fig.suptitle("Orbital angular momentum is not dissipated — it becomes spin",
             y=1.03)
fig.savefig(FIGS / "fig4_efficiency.png")
plt.close(fig)
print("wrote", FIGS / "fig4_efficiency.png")

print(f"\n{'box':>7} {'dFz':>9} {'dLz':>9} {'efficiency':>11}")
for b, f, l, e in rows:
    print(f"{b:7.2f} {f:9.4f} {l:9.4f} {e:11.4f}")
print("\nAbsolute conversion spread across boxes: "
      f"{100*(max(r[1] for r in rows)/min(r[1] for r in rows)-1):.0f}%")
print("Efficiency spread across boxes:           "
      f"{100*(max(r[3] for r in rows)/min(r[3] for r in rows)-1):.1f}%")
