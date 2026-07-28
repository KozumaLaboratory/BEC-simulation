# Single-shot detectability threshold for the m=-5 Raman-homodyne readout.
#
# SNR_hom(N) = 2 sinθ √ε · N / √(sin²θ·N + σ_det²).  Invert SNR_hom = SNR_t for the
# minimum atom number N_min that makes the m=-5 signal visible in ONE observation:
#
#   a²N² - SNR_t²·sin²θ·N - SNR_t²·σ_det² = 0,   a = 2 sinθ √ε
#   ⇒ N_min = [SNR_t²·sin²θ + √(SNR_t⁴ sin⁴θ + 4 a² SNR_t² σ_det²)] / (2 a²)
#
#   HOMODYNE_OUT=figs/homodyne_m5_evap python scripts/homodyne_m5_threshold.py
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.environ.get("HOMODYNE_OUT", "figs/homodyne_m5_evap")

meta = {}
for line in open(f"{OUT}/meta.csv").read().splitlines()[1:]:
    k, v = line.split(",")
    meta[k] = float(v)
EPS, THETA, SIGDET = meta["eps"], meta["theta"], meta["sig_det"]

# euv3 endpoints (lab vs monotone-optimized) for reference lines
endpoints = {}
for row in open(f"{OUT}/ramp_compare.csv").read().splitlines()[1:]:
    lab, nf, nb, sn = row.split(",")
    endpoints[lab] = float(nf)


def n_min(snr_t, theta=THETA, eps=EPS, sigdet=SIGDET):
    s2 = np.sin(theta) ** 2
    a2 = 4.0 * s2 * eps                      # a² = (2 sinθ √ε)²
    disc = snr_t**4 * s2**2 + 4.0 * a2 * snr_t**2 * sigdet**2
    return (snr_t**2 * s2 + np.sqrt(disc)) / (2.0 * a2)


# --- console table ---
print(f"model: ε={EPS:g}  θ={THETA:g} rad  σ_det={SIGDET:g} atoms")
print(f"euv3 endpoints: lab N={endpoints.get('lab', float('nan')):.0f}  "
      f"optimized N={endpoints.get('optimized', float('nan')):.0f}\n")
print(f"{'criterion':<26}{'N_min (θ=0.15)':>16}{'N_min (θ=π/2, full)':>22}")
labels = {1: "marginal (SNR=1)", 2: "single-shot visible (SNR=2)",
          3: "clear (SNR=3)", 5: "high-confidence (SNR=5)"}
for s in (1, 2, 3, 5):
    print(f"{labels[s]:<26}{n_min(s):>16.0f}{n_min(s, theta=np.pi/2):>22.0f}")

# --- figure ---
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.6))
fig.suptitle("m=-5 single-shot detectability: minimum atom number to see it in one observation",
             fontsize=13, fontweight="bold")

# Panel 1: N_min vs SNR threshold, for several Raman pulse areas
snr = np.linspace(0.5, 6, 200)
thetas = [(0.10, "weak θ=0.10"), (THETA, f"default θ={THETA:g}"),
          (0.30, "θ=0.30"), (np.pi / 2, "full θ=π/2 (destructive)")]
colors = plt.cm.viridis(np.linspace(0.15, 0.85, len(thetas)))
for (th, lab), c in zip(thetas, colors):
    lw = 3.0 if abs(th - THETA) < 1e-9 else 1.8
    ax1.semilogy(snr, [n_min(s, theta=th) for s in snr], color=c, lw=lw, label=lab)
for nlab, nval, col in [("lab ramp", endpoints.get("lab"), "0.45"),
                        ("optimized ramp", endpoints.get("optimized"), "#d6336c")]:
    if nval:
        ax1.axhline(nval, color=col, lw=1.3, ls="--")
        ax1.text(5.9, nval, f" {nlab}\n {nval:.0f}", color=col, fontsize=8,
                 va="center", ha="right")
for s in (2, 3):
    ax1.axvline(s, color="0.7", lw=0.8, ls=":")
ax1.set_xlabel("required SNR (single-shot visibility criterion)")
ax1.set_ylabel("minimum atom number N_min")
ax1.set_title("N_min vs visibility criterion — stronger pulse lowers the bar", fontsize=11)
ax1.legend(loc="upper left", fontsize=9)
ax1.grid(alpha=0.25, which="both")

# Panel 2: N_min (single-shot visible, SNR=2) vs detection floor σ_det
sig = np.logspace(1, 3.3, 200)   # 10 .. ~2000 atoms
for (th, lab), c in zip(thetas, colors):
    lw = 3.0 if abs(th - THETA) < 1e-9 else 1.8
    ax2.loglog(sig, [n_min(2.0, theta=th, sigdet=sg) for sg in sig],
               color=c, lw=lw, label=lab)
ax2.axvline(SIGDET, color="0.5", lw=1.0, ls=":")
ax2.text(SIGDET, ax2.get_ylim()[0] * 1.5, f" σ_det={SIGDET:g}", fontsize=8, color="0.4")
if endpoints.get("lab"):
    ax2.axhline(endpoints["lab"], color="0.45", lw=1.2, ls="--")
    ax2.text(11, endpoints["lab"], " lab BEC", fontsize=8, color="0.45", va="bottom")
ax2.set_xlabel("detection floor σ_det [atoms]")
ax2.set_ylabel("N_min for single-shot visible (SNR=2)")
ax2.set_title("threshold vs detection noise (at SNR=2)", fontsize=11)
ax2.legend(loc="upper left", fontsize=9)
ax2.grid(alpha=0.25, which="both")

plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.savefig(f"{OUT}/threshold.png", dpi=130)
print(f"\nwrote {OUT}/threshold.png")
