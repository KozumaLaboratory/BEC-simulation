#!/usr/bin/env python3
# SHOWS: the dilute-but-not-too-dilute tension — N₀ vs constant m_ω (melt on the loose side, 3-body on the tight).
# DOC:   docs/guides/eu_evaporation_optimization.md ("Constraint 2 — the melt tension").
# REPLACES: nothing (current-best, complementary pedagogical figure).
"""Plot the tightness-axis tension for the Eu evaporation (m_ω sweep + representative
trajectories). Reads the CSVs emitted by eu_evaporation_omega_mult_tension.jl.

Left:  N₀(m_ω) with the T_c−T melt margin; the melt region (cf→0) shaded; peak marked.
Right: N(t), N₀(t) for loose / baseline / tight — the 2-3 point manual check."""
import sys, csv
import numpy as np
import matplotlib.pyplot as plt

OUT = sys.argv[1] if len(sys.argv) > 1 else "omega_mult_out"


def load(path):
    with open(f"{OUT}/{path}") as f:
        return list(csv.DictReader(f))


sw = load("omega_mult_sweep.csv")
mω = np.array([float(r["m_omega"]) for r in sw])
N0 = np.array([float(r["N0"]) for r in sw])
Tc = np.array([float(r["Tc_nK"]) for r in sw])
T = np.array([float(r["T_nK"]) for r in sw])
cf = np.array([float(r["cf"]) for r in sw])
margin = np.array([float(r["margin_nK"]) for r in sw])

fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(12.5, 5.0))

# ---- left: tension curve ----
melt = cf < 0.5
if melt.any():
    ax0.axvspan(mω[melt].min(), mω[melt].max(), color="#d62728", alpha=0.12, lw=0)
    ax0.text(mω[melt].mean(), 0.05 * N0.max(), "BEC melts\n$T_c\\!<\\!T$",
             ha="center", va="bottom", color="#b0201a", fontsize=9)
ax0.plot(mω, N0, "-", color="#1f77b4", lw=2.2, label="$N_0$ (final condensate)")
pk = int(np.argmax(N0))
ax0.plot(mω[pk], N0[pk], "o", color="#1f77b4", ms=9, zorder=5)
ax0.annotate(f"peak $N_0$={N0[pk]:.2e}\n$m_\\omega$={mω[pk]:.2f}",
             (mω[pk], N0[pk]), (mω[pk] + 0.25, N0[pk] * 0.78), fontsize=9,
             arrowprops=dict(arrowstyle="->", color="#1f77b4"))
ax0.axvline(1.0, color="0.5", ls=":", lw=1.3)
ax0.text(1.02, N0.max() * 0.96, "$m_\\omega\\!=\\!1$\n(power ramp)",
         fontsize=8.5, color="0.35", va="top")
ax0.annotate("tighter → 3-body loss ↑", (mω[-1], N0[-1]),
             (mω[-1] - 0.02, N0.max() * 0.42), fontsize=9, color="#555",
             ha="right", arrowprops=dict(arrowstyle="->", color="#888"))
ax0.set_xlabel("tightness multiplier  $m_\\omega$  (= waist axis, $\\bar\\omega_{\\rm eff}=m_\\omega\\bar\\omega_{\\rm ramp}$)")
ax0.set_ylabel("$N_0$  (BEC atom number)", color="#1f77b4")
ax0.tick_params(axis="y", colors="#1f77b4")
ax0.set_ylim(bottom=0)

axb = ax0.twinx()
axb.plot(mω, margin, "--", color="#2ca02c", lw=1.8, label="$T_c-T$ (melt margin)")
axb.axhline(0.0, color="#2ca02c", ls=":", lw=1.0, alpha=0.7)
axb.set_ylabel("$T_c - T$  [nK]  (melt margin)", color="#2ca02c")
axb.tick_params(axis="y", colors="#2ca02c")
ax0.set_title("Tightness axis: the dilute-but-not-too-dilute tension", fontsize=11)
l0, lab0 = ax0.get_legend_handles_labels()
l1, lab1 = axb.get_legend_handles_labels()
ax0.legend(l0 + l1, lab0 + lab1, loc="center right", fontsize=9, framealpha=0.9)

# ---- right: representative trajectories ----
tj = load("omega_mult_traj.csv")
colors = {"loose_0.6": "#d62728", "baseline_1.0": "#333333", "tight_1.6": "#1f77b4"}
labels = {"loose_0.6": "loose $m_\\omega$=0.6", "baseline_1.0": "baseline $m_\\omega$=1.0",
          "tight_1.6": "tight $m_\\omega$=1.6"}
for lab in ("loose_0.6", "baseline_1.0", "tight_1.6"):
    rows = [r for r in tj if r["label"] == lab]
    t = np.array([float(r["t_s"]) for r in rows])
    N0t = np.array([float(r["N0"]) for r in rows])
    Nt = np.array([float(r["N"]) for r in rows])
    ax1.plot(t, Nt, "-", color=colors[lab], lw=1.1, alpha=0.5)
    ax1.plot(t, N0t, "-", color=colors[lab], lw=2.2, label=labels[lab])
ax1.set_xlabel("time  [s]")
ax1.set_ylabel("atom number   (thin = total $N$, thick = condensate $N_0$)")
ax1.set_title("Representative trajectories", fontsize=11)
ax1.legend(loc="upper right", fontsize=9)
ax1.set_ylim(bottom=0)

fig.suptitle("Eu evaporation — independent tightness axis $m_\\omega(t)$ on the verified issue-#75 path",
             fontsize=12, y=1.00)
fig.tight_layout()
out = f"{OUT}/eu_evaporation_omega_mult_tension.png"
fig.savefig(out, dpi=140, bbox_inches="tight")
print("wrote", out)
