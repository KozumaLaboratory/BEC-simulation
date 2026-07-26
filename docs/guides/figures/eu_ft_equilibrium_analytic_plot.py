#!/usr/bin/env python3
"""Analytic fixed-N Bose equilibrium (from atom+trap+N) vs the classical-field SGPE.

The equilibrium chemical potential and condensate/thermal split are set by the
atom + trap + N properties, no simulation needed: for a fixed-N 3D-harmonic Bose
gas T_c=ℏω̄(N/ζ(3))^{1/3}, N_th=ζ(3)(k_BT/ℏω̄)³=N(T/T_c)³ (BOUNDED), N_0=N[1−(T/T_c)³],
and μ(T)=μ_GP·(N_0/N)^{2/5} with μ_GP=½ℏω̄(15N a_s/a_ho)^{2/5}. The classical-field
SGPE over-populates the thermal cloud (Rayleigh–Jeans) and so over-depletes the
condensate — its role is the DYNAMICS, not the equilibrium.

Left: N_0 & N_th, analytic curves vs SGPE points. Right: μ(T) from atom properties.

Usage: python3 eu_ft_equilibrium_analytic_plot.py [analytic.csv] [sgpe.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from _smoothcurve import smooth

here = os.path.dirname(os.path.abspath(__file__))
acsv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_ft_equilibrium_analytic.csv")
scsv = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "eu_ft_equilibrium.csv")
a = np.genfromtxt(acsv, delimiter=",", names=True)
ar = a["T_over_Tc"]; aN0 = a["N0"]; aNth = a["N_thermal"]; amu = a["mu"]
o = np.argsort(ar); ar, aN0, aNth, amu = ar[o], aN0[o], aNth[o], amu[o]

s = None
if os.path.exists(scsv):
    s = np.genfromtxt(scsv, delimiter=",", names=True)

fig, (axN, axmu) = plt.subplots(1, 2, figsize=(11, 4.5))

# Left: condensate + thermal, analytic curves vs SGPE points
axN.plot(ar, aN0, "-", color="#1f6feb", lw=2, label=r"$N_0$ analytic $N[1-(T/T_c)^3]$")
axN.plot(ar, aNth, "-", color="#bf8700", lw=2, label=r"$N_{th}$ analytic $N(T/T_c)^3$ (bounded)")
axN.axhline(1e4, ls=":", color="k", alpha=0.4, lw=1.0, label=r"$N$")
if s is not None:
    axN.plot(s["T_over_Tc"], s["N0"], "o", color="#1f6feb", ms=7, mfc="white", label=r"$N_0$ SGPE")
    axN.plot(s["T_over_Tc"], s["N_thermal"], "s", color="#bf8700", ms=6, mfc="white",
             label=r"$N_{th}$ SGPE (RJ over-populated)")
axN.set_xlabel(r"$T/T_c$"); axN.set_ylabel("atom number")
axN.set_title("equilibrium from atom properties (lines)\nvs classical-field SGPE (open markers)")
axN.legend(frameon=False, fontsize=8.5); axN.grid(True, alpha=0.25)
axN.set_xlim(0, 1); axN.set_ylim(0, 2.7e4)

# Right: mu(T) from atom properties
axmu.plot(ar, amu, "-", color="#8250df", lw=2.2)
axmu.axhline(amu[0], ls=":", color="#8250df", alpha=0.5, lw=1.0)
axmu.annotate(r"$\mu_\mathrm{GP}=\frac{1}{2}\hbar\bar\omega(15N a_s/a_\mathrm{ho})^{2/5}$",
              xy=(0.05, amu[0]), xytext=(0.08, amu[0] * 0.72), fontsize=9, color="#8250df")
axmu.set_xlabel(r"$T/T_c$"); axmu.set_ylabel(r"$\mu(T)\ /\ \hbar\omega_\mathrm{ref}$")
axmu.set_title(r"chemical potential $\mu(T)=\mu_\mathrm{GP}(N_0/N)^{2/5}$"
               "\n(pinned by the condensate; from atom + trap + $N$)")
axmu.set_xlim(0, 1); axmu.set_ylim(0, amu[0] * 1.15); axmu.grid(True, alpha=0.25)

fig.suptitle("¹⁵¹Eu fixed-N equilibrium is analytic; the SGPE is for the dynamics", fontsize=11)
fig.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(here, "eu_ft_equilibrium_analytic.png")
fig.savefig(out, dpi=150)
print("wrote", out)
