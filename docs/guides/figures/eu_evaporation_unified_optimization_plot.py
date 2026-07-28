#!/usr/bin/env python3
# SHOWS: the thorough 3-axis Eu evaporation optimum — the two post-formation control knobs
#        (waist m_ω(t), Feshbach a_s(t)) + the resulting condensate gain vs the ramp-only baseline.
# DOC:   docs/guides/eu_evaporation_optimization.md (current-best optimal-protocol figure).
# REPLACES: figs/eu_evaporation_unified/*, figs/eu_evaporation_unified_smooth/eu_evaporation_unified_optimization.*,
#           figs/eu_evaporation_reopt/eu_evaporation_unified_optimization.* (jagged 1.38× / monotone 1.27× / gravity 1.30×).
"""Left: the two actionable knobs m_ω(t) (waist, gravity-floored 0.6) and a_s(t) (Feshbach,
K₃∝a_s⁴, floor 0.25), both held ≈1 through formation then dropped. Right: condensate N₀(t),
ramp-only vs the joint optimum."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "joint_out"


def load(path):
    with open(f"{D}/{path}") as f:
        return list(csv.DictReader(f))


sh = load("unified_shape.csv")
t = np.array([float(r["t_s"]) for r in sh])
mw = np.array([float(r["m_omega"]) for r in sh])
asm = np.array([float(r["a_s_mult"]) for r in sh])
we = np.array([float(r["omega_eff_hz"]) for r in sh])
wr = np.array([float(r["omega_ramp_hz"]) for r in sh])

tj = load("unified_traj.csv")


def traj(which, key):
    rows = [r for r in tj if r["which"] == which]
    return (np.array([float(r["t_s"]) for r in rows]), np.array([float(r[key]) for r in rows]))


tu, N0u = traj("unified", "N0")
t_form = tu[np.argmax(N0u > 0)] if (N0u > 0).any() else tu[-1]

fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.8, 5.2))

# ---- left: the two knobs ----
ax0.axhline(1.0, color="0.6", ls=":", lw=1.2)
ax0.text(0.04, 1.02, "= 1: leave trap / $a_s$ as-is (lab)", fontsize=8.5, color="0.4")
ax0.plot(t, mw, "-", color="#9467bd", lw=2.8, label="waist  $m_\\omega(t)$  ($\\bar\\omega\\propto m_\\omega$)")
ax0.plot(t, asm, "-", color="#17becf", lw=2.8, label="Feshbach  $a_s(t)/a_s^0$  ($K_3\\propto a_s^4$)")
ax0.axvline(t_form, color="#d62728", ls=":", lw=1.4)
ax0.text(t_form + 0.02, 0.12, "BEC forms\n($t$≈%.2f s)" % t_form, color="#d62728", fontsize=9)
ax0.annotate("hold ≈ lab\n(need density +\ncollisions to form)", (t[int(len(t) * 0.4)], 1.0),
             (t[int(len(t) * 0.12)], 0.45), fontsize=8.5, color="0.35",
             arrowprops=dict(arrowstyle="->", color="0.5"))
ax0.annotate("then dump both:\n$m_\\omega$→0.60 (gravity floor)\n$a_s$→0.25 ($K_3$×%.3f)" % (asm[-1] ** 4),
             (t[-1], 0.3), (t[int(len(t) * 0.45)], 0.62), fontsize=8.5, color="#0a7",
             arrowprops=dict(arrowstyle="->", color="#0a7"))
ax0.set_xlabel("time  [s]")
ax0.set_ylabel("control knob  (× baseline)")
ax0.set_ylim(0, 1.25)
ax0.set_title("The protocol: hold through formation, then dump density + $K_3$", fontsize=11)
ax0.legend(loc="center left", fontsize=9, framealpha=0.9)

# ---- right: condensate gain ----
for which, c, lab in (("ramp_only", "#333333", "ramp-only baseline"),
                      ("unified", "#d62728", "3-axis optimum (waist + Feshbach)")):
    tt, N0 = traj(which, "N0")
    _, Nt = traj(which, "N")
    ax1.plot(tt, Nt, "-", color=c, lw=1.0, alpha=0.35)
    ax1.plot(tt, N0, "-", color=c, lw=2.6, label=lab)
    ax1.plot(tt[-1], N0[-1], "o", color=c, ms=8)
gain = traj("unified", "N0")[1][-1] / traj("ramp_only", "N0")[1][-1]
ax1.text(0.03, 0.05, "$N_0$ gain = %.2f×\n(0-D, gravity + melt + cf≥0.9 respected)" % gain,
         transform=ax1.transAxes, fontsize=11, va="bottom",
         bbox=dict(boxstyle="round", fc="#fff3f3", ec="#d62728", alpha=0.9))
ax1.set_xlabel("time  [s]")
ax1.set_ylabel("atom number  (thin = total $N$, thick = condensate $N_0$)")
ax1.set_title("Condensate: ramp-only vs 3-axis optimum", fontsize=11)
ax1.legend(loc="upper right", fontsize=9)
ax1.set_ylim(bottom=0)

fig.suptitle("Eu evaporation — thorough 3-axis optimum (power ramp + waist + Feshbach $a_s$)", fontsize=12, y=1.00)
fig.tight_layout()
import os
out = sys.argv[2] if len(sys.argv) > 2 else "figs/eu_evaporation_optimization/optimal_protocol.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
