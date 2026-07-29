#!/usr/bin/env python3
"""fig4: what is converged and what is not.

The honest companion to figs 1-3. Two quantities behave differently as the grid
is refined at PRODUCTION stage lengths (stir = 30), and the difference is the
whole argument:

  * the conversion dF_z converges (+6.7%, then +0.6%)
  * the J_z leak falls steeply and then stalls (-57%, then -15%)

Those would be worrying together — a signal tracking its own error bar — and are
reassuring apart. The per-term torque budget explains why they separate: the
leak lives in the KINETIC term's failure to commute with L_z on a discrete
k-grid, which the quench keeps re-feeding at the Nyquist edge, while the
conversion is a bulk mean-field effect.

Usage: python3 runs/eu_barnett_redo/fig4_convergence.py
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

SERIES = [
    (0.219, "ledger_plus.csv"),
    (0.175, "ledger_plus_prod_dx175.csv"),
    (0.146, "ledger_plus_prod_dx146.csv"),
]
T_STIR = 30.0

plt.rcParams.update({
    "font.size": 10, "axes.grid": True, "grid.alpha": 0.25,
    "figure.dpi": 140, "savefig.bbox": "tight", "axes.axisbelow": True,
})

dx, conv, leak = [], [], []
for d, fn in SERIES:
    p = DATA / fn
    if not p.exists():
        continue
    a = np.genfromtxt(p, delimiter=",", names=True)
    i = int(np.argmax(a["t"] >= T_STIR))
    dx.append(d)
    conv.append(a["Fz"][-1] - a["Fz"][i])
    leak.append(abs(a["Jz"][-1] - a["Jz"][i]))

if len(dx) < 2:
    raise SystemExit("need at least two resolutions")

dx, conv, leak = np.array(dx), np.array(conv), np.array(leak)

fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.4, 4.0))

a1.plot(dx, conv, "o-", color="#1b6ca8", lw=1.9, ms=6)
for x, y in zip(dx, conv):
    a1.annotate(f"{y:.3f}", (x, y), textcoords="offset points", xytext=(0, 8),
                ha="center", fontsize=8)
a1.set_xlabel(r"$dx$  [$a_{\rm ho}$]")
a1.set_ylabel(r"$\Delta\langle F_z\rangle$  [$\hbar$/atom]")
a1.set_title("Conversion: converges")
a1.invert_xaxis()
a1.set_ylim(min(conv) - 0.12, max(conv) + 0.12)

a2.plot(dx, leak, "o-", color="#c0392b", lw=1.9, ms=6)
for x, y in zip(dx, leak):
    a2.annotate(f"{y:.3f}", (x, y), textcoords="offset points", xytext=(0, 8),
                ha="center", fontsize=8)
a2.set_xlabel(r"$dx$  [$a_{\rm ho}$]")
a2.set_ylabel(r"$|\Delta J_z|$  [$\hbar$/atom]")
a2.set_title("Ledger leak: falls, then stalls")
a2.invert_xaxis()
a2.set_ylim(0, max(leak) * 1.15)

fig.suptitle("Refining the grid separates the signal from its error\n"
             r"(production protocol, stir $=30$)", y=1.04)
fig.savefig(FIGS / "fig4_convergence.png")
plt.close(fig)
print("wrote", FIGS / "fig4_convergence.png")

print(f"\n{'dx':>7} {'conversion':>11} {'leak':>9} {'leak/conv':>10}")
for d, c, l in zip(dx, conv, leak):
    print(f"{d:7.3f} {c:11.4f} {l:9.4f} {100*l/abs(c):9.1f}%")
for i in range(1, len(dx)):
    print(f"  {dx[i-1]:.3f} -> {dx[i]:.3f}: conversion {100*(conv[i]/conv[i-1]-1):+.1f}%, "
          f"leak {100*(leak[i]/leak[i-1]-1):+.1f}%")
