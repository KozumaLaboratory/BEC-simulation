#!/usr/bin/env python3
"""Plot the reservoir-driven FORMATION SGPE check: the condensate forms dynamically as
the common reservoir (μ(t),T(t)) cools, with only the trap ω̄(t) differing between the
two protocols. Captures the formation-phase 3-body loss the post-formation A/B could not."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "docs/guides/figures"
N0_0D = {"ramp_only": 1.264e5, "unified": 1.610e5}   # 0-D final condensate targets


def load(name):
    rows = list(csv.DictReader(open(f"{D}/eu_sgpe_formation_{name}.csv")))
    return (np.array([float(r["t_ms"]) for r in rows]),
            np.array([float(r["N"]) for r in rows]),
            np.array([float(r["N0"]) for r in rows]))


t_ro, N_ro, N0_ro = load("ramp_only")
t_un, N_un, N0_un = load("unified")
gain = N0_un[-1] / N0_ro[-1]

fig, ax = plt.subplots(figsize=(8.4, 5.4))
for t, N, N0, c, lab in ((t_ro, N_ro, N0_ro, "#333333", "ramp-only ($m_\\omega\\!\\equiv\\!1$)"),
                         (t_un, N_un, N0_un, "#d62728", "unified ($m_\\omega(t)$, waist opened)")):
    ax.plot(t, N, "-", color=c, lw=1.0, alpha=0.35)
    ax.plot(t, N0, "-", color=c, lw=2.6, label=lab)
    ax.plot(t[-1], N0[-1], "o", color=c, ms=8)
for name, c, dy in (("ramp_only", "#333333", -0.06), ("unified", "#d62728", 0.05)):
    ax.axhline(N0_0D[name], color=c, ls=":", lw=1.2, alpha=0.6)
    ax.text(0.5, N0_0D[name] * (1 + dy), "0-D %s $N_0$=%.2e" % (name.replace("_", "-"), N0_0D[name]),
            color=c, fontsize=8.5, alpha=0.8)
ax.annotate("$N_0$=%.2e" % N0_un[-1], (t_un[-1], N0_un[-1]),
            (t_un[-1] * 0.6, N0_un[-1] * 1.07), color="#d62728", fontsize=10)
ax.annotate("$N_0$=%.2e" % N0_ro[-1], (t_ro[-1], N0_ro[-1]),
            (t_ro[-1] * 0.6, N0_ro[-1] * 0.82), color="#333333", fontsize=10)
dN_un = (N_un[-1] - N_un[0]) / N_un[0] * 100
ax.text(0.03, 0.04,
        "raw $N_0$ ratio %.1f× — UNRELIABLE\ncommon-$\\mu$ + looser trap draws atoms:\nunified total $N$ %+.0f%% (grew ⇒ unphysical\nfor evaporation). Direction only; the\nclean 3D number is the post-formation\nA/B, 1.28× (matches 0-D 1.27×)." % (gain, dN_un),
        transform=ax.transAxes, fontsize=8.8, va="bottom",
        bbox=dict(boxstyle="round", fc="#fff8e8", ec="#d9a300", alpha=0.95))
ax.set_xlabel("time  [ms]  (reservoir-driven formation window, common cooling)")
ax.set_ylabel("atom number   (thin = total $N$, thick = condensate $N_0$)")
ax.set_title("Reservoir-driven formation: grand-canonical artifact (diagnostic, NOT a result)", fontsize=11)
ax.legend(loc="upper right", fontsize=9.5)
ax.set_ylim(bottom=0)
fig.tight_layout()
import os
out = f"{D}/../../../figs/eu_evaporation_unified_smooth/eu_sgpe_formation_check.png" \
    if len(sys.argv) < 3 else sys.argv[2]
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
