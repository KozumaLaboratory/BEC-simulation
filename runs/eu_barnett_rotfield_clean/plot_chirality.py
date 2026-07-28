#!/usr/bin/env python3
"""Chirality mirror: +Omega (headline, box+-10) vs -Omega (this run, same grid/dt).
Barnett is Omega-odd -> expect Fz(-Omega) ~ -Fz(+Omega). |F|(t) panel is the
chiral-depolarisation symmetry check (P2/P3: CW depolarised while CCW stayed
polarised -> if that leaks into the two-stage quench the |F| curves won't mirror).
"""
import csv
import sys
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = "runs/eu_barnett_rotfield_clean"
PLUS = f"{HERE}/rebuild_tsubame/traj_quench.csv"      # +Omega headline (Fz -> +2.16)
MINUS = f"{HERE}/rebuild/traj_chir_quench.csv"        # -Omega chirality (this run)


def load(path):
    t, fz, fperp, fmag, lz, jz = [], [], [], [], [], []
    with open(path) as f:
        for row in csv.DictReader(f):
            t.append(float(row["t"]))
            fz.append(float(row["Fz"]))
            fperp.append(float(row["Fperp"]))
            fmag.append(float(row["Fmag"]))
            lz.append(float(row["Lz"]))
            jz.append(float(row["Jz"]))
    return {k: np.array(v) for k, v in
            dict(t=t, Fz=fz, Fperp=fperp, Fmag=fmag, Lz=lz, Jz=jz).items()}


def tmean(d, key, t0=20.0):
    m = d["t"] >= t0
    return float(np.mean(d[key][m]))


p = load(PLUS)
m = load(MINUS)

fig, ax = plt.subplots(2, 2, figsize=(11, 8))
CP, CM = "#1f77b4", "#d62728"

# Fz — the chirality test
ax[0, 0].plot(p["t"], p["Fz"], color=CP, label="+$\\Omega$ (headline)")
ax[0, 0].plot(m["t"], m["Fz"], color=CM, label="$-\\Omega$ (this run)")
ax[0, 0].plot(m["t"], -m["Fz"], color=CM, ls=":", alpha=0.6,
              label="$-(-\\Omega)$ [mirror]")
ax[0, 0].axhline(0, color="k", lw=0.5)
ax[0, 0].set_title("$\\langle F_z\\rangle$ — Barnett (should flip sign)")
ax[0, 0].set_xlabel("t"); ax[0, 0].set_ylabel("$F_z$"); ax[0, 0].legend(fontsize=8)

# Lz
ax[0, 1].plot(p["t"], p["Lz"], color=CP, label="+$\\Omega$")
ax[0, 1].plot(m["t"], m["Lz"], color=CM, label="$-\\Omega$")
ax[0, 1].axhline(0, color="k", lw=0.5)
ax[0, 1].set_title("$\\langle L_z\\rangle$ — orbital (vortex)")
ax[0, 1].set_xlabel("t"); ax[0, 1].set_ylabel("$L_z$"); ax[0, 1].legend(fontsize=8)

# |F| — chiral-depolarisation symmetry check
ax[1, 0].plot(p["t"], p["Fmag"], color=CP, label="+$\\Omega$")
ax[1, 0].plot(m["t"], m["Fmag"], color=CM, label="$-\\Omega$")
ax[1, 0].set_title("$|F|$ — chiral-depolarisation symmetry (mirror?)")
ax[1, 0].set_xlabel("t"); ax[1, 0].set_ylabel("$|F|$"); ax[1, 0].legend(fontsize=8)

# Jz ledger
ax[1, 1].plot(p["t"], p["Jz"], color=CP, label="+$\\Omega$ $J_z$")
ax[1, 1].plot(m["t"], m["Jz"], color=CM, label="$-\\Omega$ $J_z$")
ax[1, 1].set_title("$J_z = L_z + F_z$ (residual ledger)")
ax[1, 1].set_xlabel("t"); ax[1, 1].set_ylabel("$J_z$"); ax[1, 1].legend(fontsize=8)

txt = (
    f"time-mean t>=20:\n"
    f"  Fz:  +O {tmean(p,'Fz'):+.3f}   -O {tmean(m,'Fz'):+.3f}   sum {tmean(p,'Fz')+tmean(m,'Fz'):+.3f}\n"
    f"  Lz:  +O {tmean(p,'Lz'):+.3f}   -O {tmean(m,'Lz'):+.3f}\n"
    f"  |F|: +O {tmean(p,'Fmag'):.3f}    -O {tmean(m,'Fmag'):.3f}   (asym {tmean(p,'Fmag')-tmean(m,'Fmag'):+.3f})"
)
fig.suptitle("Two-stage Barnett chirality: +$\\Omega$ vs $-\\Omega$ (box$\\pm$10, n80, same dt)",
             fontsize=12)
fig.text(0.5, 0.005, txt, ha="center", family="monospace", fontsize=9)
fig.tight_layout(rect=(0, 0.06, 1, 0.97))
out = f"{HERE}/figures/chirality.png"
fig.savefig(out, dpi=130)
print("wrote", out)
print(txt)
