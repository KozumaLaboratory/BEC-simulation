#!/usr/bin/env python3
"""Plot the unified ramp + tightness-axis optimization result.
Left:  optimal tightness m_ω(t) and the resulting effective ω̄(t)/2π vs the power-ramp ω̄(t).
Right: condensate N₀(t) for ramp-only (m_ω≡1) vs unified (m_ω(t)) — the gain."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

OUT = sys.argv[1] if len(sys.argv) > 1 else "unified_out"


def load(path):
    with open(f"{OUT}/{path}") as f:
        return list(csv.DictReader(f))


sh = load("unified_shape.csv")
t = np.array([float(r["t_s"]) for r in sh])
mω = np.array([float(r["m_omega"]) for r in sh])
wr = np.array([float(r["omega_ramp_hz"]) for r in sh])
we = np.array([float(r["omega_eff_hz"]) for r in sh])

tj = load("unified_traj.csv")


def traj(which, key):
    rows = [r for r in tj if r["which"] == which]
    return (np.array([float(r["t_s"]) for r in rows]),
            np.array([float(r[key]) for r in rows]))


# time the condensate first appears in the unified run (BEC formation)
tu, N0u = traj("unified", "N0")
t_form = tu[np.argmax(N0u > 0)] if (N0u > 0).any() else tu[-1]

fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.5, 5.0))

# ---- left: the actionable knob m_ω(t) (the waist), with the resulting ω̄ on the twin axis ----
ax0.axhspan(0, 1.0, color="#9467bd", alpha=0.04, lw=0)
ax0.plot(t, mω, "-", color="#9467bd", lw=2.8, label="waist knob $m_\\omega(t)$  ($\\bar\\omega\\!\\propto\\!m_\\omega$)")
ax0.axhline(1.0, color="0.55", ls=":", lw=1.3)
ax0.text(0.05, 1.02, "$m_\\omega\\!=\\!1$: leave trap as-is (lab ramp)", fontsize=8.5, color="0.4")
ax0.axvline(t_form, color="#d62728", ls=":", lw=1.4)
ax0.text(t_form + 0.02, 0.12, "BEC forms\n($t$≈%.2f s)" % t_form, color="#d62728", fontsize=9)
# annotate the two regimes
ax0.annotate("hold ($\\approx$ lab)", (t[int(len(t) * 0.35)], mω[int(len(t) * 0.35)]),
             (t[int(len(t) * 0.2)], 0.6), fontsize=9, color="#9467bd",
             arrowprops=dict(arrowstyle="->", color="#9467bd"))
ax0.annotate("open the waist %.1f× beyond the ramp\n($m_\\omega$: 1→%.2f)  dilute → 3-body $\\propto\\bar\\omega^3$ ↓"
             % (1.0 / max(mω[-1], 1e-9), mω[-1]),
             (t[-1], mω[-1]), (t[int(len(t) * 0.42)], 0.30), fontsize=9, color="#1f77b4",
             arrowprops=dict(arrowstyle="->", color="#1f77b4"))
ax0.set_xlabel("time  [s]")
ax0.set_ylabel("waist tightness knob  $m_\\omega(t)$", color="#9467bd")
ax0.tick_params(axis="y", colors="#9467bd")
ax0.set_ylim(0, 1.25)
axw = ax0.twinx()
axw.plot(t, wr, "--", color="#bbbbbb", lw=1.6, label="power-ramp $\\bar\\omega/2\\pi$")
axw.plot(t, we, "-", color="#1f77b4", lw=1.8, label="effective $\\bar\\omega_{\\rm eff}/2\\pi$")
axw.set_ylabel("$\\bar\\omega/2\\pi$  [Hz]", color="#1f77b4")
axw.tick_params(axis="y", colors="#1f77b4")
axw.set_ylim(bottom=0)
ax0.set_title("The protocol change: hold the trap, then open the waist late", fontsize=11)
l0, la0 = ax0.get_legend_handles_labels()
l1, la1 = axw.get_legend_handles_labels()
ax0.legend(l0 + l1, la0 + la1, loc="upper right", fontsize=8.5, framealpha=0.9)

# ---- right: N₀(t) ramp-only vs unified ----
for which, col, lab in (("ramp_only", "#333333", "ramp-only ($m_\\omega\\!\\equiv\\!1$)"),
                        ("unified", "#d62728", "unified ($m_\\omega(t)$)")):
    tt, N0 = traj(which, "N0")
    _, Nt = traj(which, "N")
    ax1.plot(tt, Nt, "-", color=col, lw=1.0, alpha=0.4)
    ax1.plot(tt, N0, "-", color=col, lw=2.4, label=lab)
    ax1.plot(tt[-1], N0[-1], "o", color=col, ms=7)
    ax1.annotate(f"{N0[-1]:.2e}", (tt[-1], N0[-1]), (tt[-1] * 0.72, N0[-1]),
                 fontsize=9, color=col)
ax1.set_xlabel("time  [s]")
ax1.set_ylabel("atom number   (thin = total $N$, thick = condensate $N_0$)")
ax1.set_title("Condensate growth: ramp-only vs unified", fontsize=11)
ax1.legend(loc="upper left", fontsize=9)
ax1.set_ylim(bottom=0)

fig.suptitle("Eu evaporation — unified ramp + tightness-axis $m_\\omega(t)$ optimization (issue #75)",
             fontsize=12, y=1.00)
fig.tight_layout()
out = f"{OUT}/eu_evaporation_unified_optimization.png"
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
