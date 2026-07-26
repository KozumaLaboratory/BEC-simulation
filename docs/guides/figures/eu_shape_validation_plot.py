#!/usr/bin/env python3
"""Plot the Eu trap-shape validation gate: TF density moments vs trap ω̄.

Verifies n₀ ∝ ω̄^{6/5} and ⟨n²⟩ ∝ ω̄^{12/5} (the 3-body loss-rate scaling that
underlies the N₀ ∝ ω̄⁻³ attractor). Log-log axes: on a power law the fitted
slope IS the exponent, so log-log is the correct frame for this check.

Usage: python3 eu_shape_validation_plot.py [eu_shape_validation.csv]
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
csv = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "eu_shape_validation.csv")
d = np.genfromtxt(csv, delimiter=",", names=True)
omega = d["omega"]
n0 = d["n0_phys_m3"]
n2 = d["n2_phys_m6"]
edge = d["edge_frac"]

good = edge < 1e-3


def fit_slope(x, y):
    lx, ly = np.log(x), np.log(y)
    A = np.vstack([lx, np.ones_like(lx)]).T
    m, b = np.linalg.lstsq(A, ly, rcond=None)[0]
    return m, b


fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))
panels = [
    (axes[0], n0, 1.2, r"peak density $n_0$ [m$^{-3}$]", r"$n_0 \propto \bar\omega^{6/5}$"),
    (axes[1], n2, 2.4, r"$\langle n^2\rangle$ [m$^{-6}$]", r"$\langle n^2\rangle \propto \bar\omega^{12/5}$"),
]
for ax, y, theory, ylabel, title in panels:
    m, b = fit_slope(omega[good], y[good])
    xx = np.linspace(omega.min(), omega.max(), 100)
    ax.loglog(omega[good], y[good], "o", ms=8, color="#1f6feb", label="GP ground state", zorder=3)
    if (~good).any():
        ax.loglog(omega[~good], y[~good], "x", ms=8, color="#999", label="box-spill (excluded)", zorder=3)
    ax.loglog(xx, np.exp(b) * xx**m, "-", color="#1f6feb", lw=1.8,
              label=fr"fit slope ${m:.2f}$")
    # theory reference through the first good point
    x0, y0 = omega[good][0], y[good][0]
    ax.loglog(xx, y0 * (xx / x0)**theory, "--", color="#d1242f", lw=1.6,
              label=fr"theory slope ${theory:.2f}$")
    ax.set_xlabel(r"trap $\bar\omega\,/\,\omega_\mathrm{ref}$")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.legend(frameon=False, fontsize=9)
    ax.grid(True, which="both", alpha=0.25)

fig.suptitle(r"¹⁵¹Eu Thomas–Fermi density moments vs trap frequency "
             r"(fixed $N$) — looser trap $\Rightarrow$ lower density $\Rightarrow$ less 3-body loss",
             fontsize=11)
fig.tight_layout(rect=[0, 0, 1, 0.96])
out = os.path.join(here, "eu_shape_validation.png")
fig.savefig(out, dpi=150)
print("wrote", out)
