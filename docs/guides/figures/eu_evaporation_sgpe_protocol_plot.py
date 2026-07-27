#!/usr/bin/env python3
# SHOWS: 3D finite-T Stoof-SGPE verification of the WAIST mechanism (looser retains more N₀).
# DOC:   docs/guides/eu_evaporation_optimization.md ("3D verification (SGPE)").
# REPLACES: nothing (current-best 3D verification; harmonic trap ⇒ waist mechanism only, no gravity/Feshbach).
"""Plot the finite-T Stoof-SGPE verification of the 0-D unified evaporation optimum.
The two post-formation ω̄(t) protocols (ramp-only vs unified waist opening) run on the
SAME prepared finite-T condensate with real K₃ loss; unified's looser trap cuts 3-body
loss and retains more condensate — confirming the 0-D +27% in full 3D."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "docs/guides/figures"


def load(name):
    rows = list(csv.DictReader(open(f"{D}/eu_sgpe_protocol_{name}.csv")))
    return (np.array([float(r["t_ms"]) for r in rows]),
            np.array([float(r["N"]) for r in rows]),
            np.array([float(r["N0"]) for r in rows]))


t_ro, N_ro, N0_ro = load("ramp_only")
t_un, N_un, N0_un = load("unified")
gain = N0_un[-1] / N0_ro[-1]

fig, ax = plt.subplots(figsize=(8.2, 5.4))
ax.plot(t_ro, N_ro, "-", color="#333333", lw=1.1, alpha=0.4)
ax.plot(t_un, N_un, "-", color="#d62728", lw=1.1, alpha=0.4)
ax.plot(t_ro, N0_ro, "-", color="#333333", lw=2.6, label="ramp-only ($m_\\omega\\!\\equiv\\!1$)")
ax.plot(t_un, N0_un, "-", color="#d62728", lw=2.6, label="unified ($m_\\omega(t)$, waist opened)")
for t, N0, c in ((t_ro, N0_ro, "#333333"), (t_un, N0_un, "#d62728")):
    ax.plot(t[-1], N0[-1], "o", color=c, ms=8)
ax.annotate("$N_0$=%.2e" % N0_un[-1], (t_un[-1], N0_un[-1]),
            (t_un[-1] * 0.62, N0_un[-1] * 1.06), color="#d62728", fontsize=10)
ax.annotate("$N_0$=%.2e" % N0_ro[-1], (t_ro[-1], N0_ro[-1]),
            (t_ro[-1] * 0.62, N0_ro[-1] * 0.86), color="#333333", fontsize=10)
ax.text(0.03, 0.05,
        "SGPE $N_0$ gain = %.2f×\n(0-D predicted 1.27×)" % gain,
        transform=ax.transAxes, fontsize=11, va="bottom",
        bbox=dict(boxstyle="round", fc="#fff3f3", ec="#d62728", alpha=0.9))
ax.set_xlabel("time  [ms]  (post-formation closed ramp)")
ax.set_ylabel("atom number   (thin = total $N$, thick = condensate $N_0$)")
ax.set_title("Finite-T Stoof-SGPE check: waist axis retains more condensate (3D)", fontsize=11.5)
ax.legend(loc="upper right", fontsize=9.5)
ax.set_ylim(bottom=0)
fig.tight_layout()
out = f"{D}/../../../figs/eu_evaporation_unified_smooth/eu_sgpe_protocol_check.png" \
    if len(sys.argv) < 3 else sys.argv[2]
import os
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
