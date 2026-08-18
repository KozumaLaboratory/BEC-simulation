#!/usr/bin/env python3
# SHOWS: no K3 inside the universal van-der-Waals band reproduces the measured Eu BEC
#        endpoint, at either T0 anchor — and the shipped defaults' eta_start is 2.07,
#        below the eta_min = 4 floor.
# DOC:   docs/guides/evaporation_model.md ("Robustness — the optimum is near a cliff");
#        issue #75.
# REPLACES: nothing (new — the band-exclusion result).
"""The endpoint gap is a model deficiency, not a parameter to tune: reaching the measured
N_BEC = 5.02e4 needs K3 ~ 2.5x above the top of the band Eu's three-body rate is allowed
to occupy, at both the shipped T0 = 50 uK and the 2023-epoch T0 = 18 uK."""
import sys
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "k3_band_out"

INK = "#1f2328"
C50 = "#2f6fb2"
C18 = "#c8542a"
plt.rcParams.update({
    "font.size": 9, "axes.labelsize": 9.5, "axes.titlesize": 10,
    "axes.edgecolor": INK, "axes.labelcolor": INK, "text.color": INK,
    "xtick.color": INK, "ytick.color": INK, "axes.grid": True,
    "grid.color": "#e5e7eb", "grid.linewidth": 0.7, "axes.axisbelow": True,
    "figure.dpi": 150, "savefig.dpi": 150, "legend.frameon": False,
})

MEAS = 5.02e4
sweep = list(csv.DictReader(open(f"{D}/k3_sweep.csv")))
anchors = list(csv.DictReader(open(f"{D}/k3_anchors.csv")))
cross = {int(r["T0_uK"]): float(r["K3_crossing_m6_per_s"])
         for r in csv.DictReader(open(f"{D}/k3_crossings.csv"))}

fig, ax = plt.subplots(1, 2, figsize=(11.0, 3.9))

# --- left: the sweep ---
a = ax[0]
a.axvspan(1e-42, 1e-40, color="#a7f3d0", alpha=0.35, zorder=0)
for T0, col, lbl in ((50, C50, "$T_0=50\\,\\mu$K  (shipped)"),
                     (18, C18, "$T_0=18\\,\\mu$K  (2023 epoch)")):
    xs = [float(r["K3_m6_per_s"]) for r in sweep
          if int(r["T0_uK"]) == T0 and int(r["reached_bec"]) == 1]
    ys = [float(r["N_BEC"]) for r in sweep
          if int(r["T0_uK"]) == T0 and int(r["reached_bec"]) == 1]
    a.plot(xs, ys, color=col, lw=2.0, label=lbl)
    if T0 in cross:
        a.plot([cross[T0]], [MEAS], "o", ms=6, color=col, zorder=5)
a.axhline(MEAS, color=INK, lw=1.4, ls="--")
a.text(3.0e-40, MEAS * 1.3, "measured  $5.02\\times10^4$",
       fontsize=8.5, color=INK, ha="right")
a.text(1e-41, 1.15e6, "universal van-der-Waals band  $C\\in[0,67]$",
       ha="center", fontsize=8, color="#065f46")
a.text(4.2e-40, 1.6e5, "crossings\n$\\approx2.5$–$2.7\\times10^{-40}$",
       fontsize=7.5, color="#b91c1c", ha="right", va="bottom")
a.set_xscale("log")
a.set_yscale("log")
a.set_xlabel("three-body coefficient  $K_3$  [m$^6$/s]")
a.set_ylabel("predicted  $N_{BEC}$")
a.set_title("No $K_3$ in the ab-initio band reproduces the measurement")
a.legend(loc="lower left", fontsize=8, bbox_to_anchor=(0.0, 0.08))

# --- right: the anchor combinations ---
a = ax[1]
labels = [r["label"] for r in anchors]
ratios = [float(r["ratio_to_measured"]) for r in anchors]
etas = [float(r["eta_start"]) for r in anchors]
cols = [C50, C18, "#d97706", "#7c3aed"]
y = list(range(len(labels)))
a.barh(y, ratios, color=cols, height=0.55)
a.axvline(1.0, color=INK, lw=1.4, ls="--")
for i, (rr, et) in enumerate(zip(ratios, etas)):
    a.text(rr * 1.06, i, f"{rr:.2f}×   $\\eta_{{start}}$={et:.2f}", va="center",
           # amber, not green: eta_start > 4 here is reached only by pairing the
           # 2023 T0 with the 2022 trap, which is epoch-mixing (see the guide).
           fontsize=8.5, color="#b91c1c" if et < 4 else "#92400e")
a.set_yticks(y)
a.set_yticklabels(labels, fontsize=8.5)
a.invert_yaxis()
a.set_xscale("log")
a.set_xlim(0.7, 40)
a.set_xlabel("$N_{BEC}$ / measured   (1.0 = agreement)")
a.set_title("Red $\\eta_{start}$ is below the $\\eta_{min}=4$ floor")
a.grid(axis="y", visible=False)

fig.suptitle("Only the MIXED-epoch row lifts $\\eta_{start}$; see the guide",
             y=1.03, fontsize=11, fontweight="bold")
fig.tight_layout()
fig.savefig(f"{D}/eu_evap_k3_band_exclusion.png", bbox_inches="tight", facecolor="white")
print(f"wrote {D}/eu_evap_k3_band_exclusion.png")
