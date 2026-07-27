# Raman-homodyne interference of the GROUND-STATE m=-5 component (weak-field Eu+DDI).
#
# The converged weak-field Eu+DDI ground state is a DDI-textured spinor (NOT polarized
# m=-6): m=-6 ≈ 22%, m=-5 ≈ 3.3% (figs/truegs_conv, |∇E|=7.6e-6). The m=-5 population
# is the SIGNAL; m=-6 is the local-oscillator reservoir. A Raman pulse (area θ, Δm=+1)
# injects sinθ√(N₋₆) into m=-5, where it interferes with the existing √(N₋₅):
#
#   N_meas = sin²θ·N₋₆ + N₋₅ + 2 sinθ √(N₋₅ N₋₆) cos(k·x − φ)
#   N₋₅ = f₅·N,  N₋₆ = f₆·N   (f₅,f₆ from the ground-state spectrum)
#
# Visualizes the actual single-shot interferogram at the euv3 BEC atom number and the
# minimum N for single-shot visibility, using the real ground-state populations.
#
#   HOMODYNE_OUT=figs/homodyne_m5_evap python scripts/viz_homodyne_m5_gs.py
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.environ.get("HOMODYNE_OUT", "figs/homodyne_m5_evap")
GS = os.environ.get("GS_DIR", "figs/truegs_conv")     # converged GS (|∇E|=7.6e-6)

# ground-state m populations
ms, pops = [], []
for line in open(f"{GS}/populations.csv").read().splitlines():
    a, b = line.split()
    ms.append(float(a)); pops.append(float(b))
ms = np.array(ms); pops = np.array(pops)
f5 = float(pops[ms == -5][0])
f6 = float(pops[ms == -6][0])

meta = {}
for line in open(f"{OUT}/meta.csv").read().splitlines()[1:]:
    k, v = line.split(",")
    meta[k] = float(v)
THETA, SIGDET = meta["theta"], meta["sig_det"]

endpoints = {}
for row in open(f"{OUT}/ramp_compare.csv").read().splitlines()[1:]:
    lab, nf, nb, sn = row.split(",")
    endpoints[lab] = float(nf)
N_lab, N_opt = endpoints.get("lab", 6.5e4), endpoints.get("optimized", 1.1e5)

st = np.sin(THETA)
A = 2 * st * np.sqrt(f5 * f6)        # fringe coefficient: S_hom = A·N
C = st**2 * f6 + f5                  # carried m=-5 pedestal coefficient


def snr(N):
    return A * N / np.sqrt(C * N + SIGDET**2)


def n_min(snr_t):
    disc = snr_t**4 * C**2 + 4 * A**2 * snr_t**2 * SIGDET**2
    return (snr_t**2 * C + np.sqrt(disc)) / (2 * A**2)


print(f"ground state {GS}:  f5(m=-5)={f5:.4f}  f6(m=-6)={f6:.4f}")
print(f"homodyne θ={THETA:g}, σ_det={SIGDET:g}: SNR(lab N={N_lab:.0f})={snr(N_lab):.1f}, "
      f"SNR(opt N={N_opt:.0f})={snr(N_opt):.1f}")
for s in (1, 2, 3, 5):
    print(f"  N_min(SNR={s}) = {n_min(s):.0f}")

# --- imaging model for the single-shot interferogram ---
NPIX, R, LAMBDA, SIG_READ = 64, 18.0, 7.0, 1.0
x = np.arange(NPIX) - NPIX / 2 + 0.5
Xg, Yg = np.meshgrid(x, x)
tf = np.clip(1.0 - (Xg**2 + Yg**2) / R**2, 0.0, None)
tf /= tf.sum()
PED = st**2 * f6 + f5                       # pedestal fraction of total N
AMP = 2 * st * np.sqrt(f5 * f6)             # fringe amplitude fraction


def shot(N, seed):
    rng = np.random.default_rng(seed)
    fr = PED + AMP * np.cos(2 * np.pi * Xg / LAMBDA)
    lam = np.clip(N * tf * fr, 0.0, None)
    return rng.poisson(lam) + rng.normal(0, SIG_READ, lam.shape)


fig = plt.figure(figsize=(15, 9))
fig.suptitle(
    f"Ground-state m=-5 Raman-homodyne interference (weak-field Eu+DDI, B=10µG;  "
    f"f₅={f5:.1%}, f₆={f6:.1%}, θ={THETA:g})", fontsize=13, fontweight="bold")

# Panel A: ground-state m spectrum
axA = fig.add_subplot(2, 2, 1)
colors = ["#adb5bd"] * len(ms)
colors[int(np.where(ms == -5)[0][0])] = "#d6336c"
colors[int(np.where(ms == -6)[0][0])] = "#1c7ed6"
axA.bar(ms, pops, color=colors, edgecolor="k", lw=0.4)
axA.set_xlabel("magnetic sublevel m")
axA.set_ylabel("population fraction")
axA.set_title("A  converged GS spectrum — DDI-textured, NOT polarized", fontsize=11)
axA.text(-5, f5, f" m=-5\n {f5:.1%}\n (signal)", color="#d6336c", fontsize=9, va="bottom")
axA.text(-6, f6, f"m=-6\n{f6:.1%}\n(LO)", color="#1c7ed6", fontsize=9, va="bottom", ha="center")
axA.text(0.97, 0.95, f"un-converged 32³ (|∇E|=0.009)\noverestimates m=-5 at 9.5%",
         transform=axA.transAxes, fontsize=7.5, ha="right", va="top", color="0.45",
         style="italic")

# Panel B: single-shot 2D interferogram at euv3 BEC N
axB = fig.add_subplot(2, 2, 2)
img = shot(N_lab, seed=7)
axB.imshow(img, origin="lower", cmap="inferno", extent=[x[0], x[-1], x[0], x[-1]])
axB.set_title(f"B  single-shot m=-5 interferogram @ euv3 BEC (N={N_lab:.0f})", fontsize=11)
axB.set_xticks([]); axB.set_yticks([])

# Panel C: column fringe profile at lab vs low N
axC = fig.add_subplot(2, 2, 3)
for N, tag, col in [(N_lab, f"euv3 BEC N={N_lab:.0f}", "#d6336c"),
                    (8e3, "N=8000", "#1c7ed6")]:
    prof = shot(N, seed=3).sum(axis=0)
    ideal = (N * tf).sum(axis=0) * (PED + AMP * np.cos(2 * np.pi * x / LAMBDA))
    axC.plot(x, prof, color=col, lw=0.9, marker="o", ms=2.5, alpha=0.6,
             label=f"{tag}  (SNR≈{snr(N):.1f})")
    axC.plot(x, ideal, color=col, lw=2.0)
axC.set_xlabel("x [px]  (fringe axis)")
axC.set_ylabel("m=-5 column density [atoms/col]")
axC.set_title("C  the interference signal: crisp at BEC N, noisy at low N", fontsize=11)
axC.legend(loc="upper right", fontsize=8)
axC.grid(alpha=0.25)

# Panel D: single-shot threshold with the real GS m=-5
axD = fig.add_subplot(2, 2, 4)
snr_axis = np.linspace(0.5, 8, 200)
axD.semilogy(snr_axis, [n_min(s) for s in snr_axis], color="#d6336c", lw=2.6,
             label=f"GS m=-5 (f₅={f5:.1%})")
# placeholder ε=1e-3 comparison
A0 = 2 * st * np.sqrt(1e-3)
C0 = st**2 + 1e-3
nmin0 = lambda s: (s**2 * C0 + np.sqrt(s**4 * C0**2 + 4 * A0**2 * s**2 * SIGDET**2)) / (2 * A0**2)
axD.semilogy(snr_axis, [nmin0(s) for s in snr_axis], color="0.6", lw=1.6, ls="--",
             label="placeholder ε=10⁻³")
for nlab, nval, c in [("lab BEC", N_lab, "0.3"), ("optimized", N_opt, "seagreen")]:
    axD.axhline(nval, color=c, lw=1.2, ls=":")
    axD.text(7.8, nval, f" {nlab} {nval:.0f}", color=c, fontsize=8, va="center", ha="right")
axD.axvline(2, color="0.7", lw=0.8, ls=":")
axD.set_xlabel("required SNR (single-shot criterion)")
axD.set_ylabel("minimum atom number N_min")
axD.set_title(f"D  with real GS m=-5, single-shot visible at N≳{n_min(2):.0f}", fontsize=11)
axD.legend(loc="lower right", fontsize=9)
axD.grid(alpha=0.25, which="both")

plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.savefig(f"{OUT}/homodyne_m5_gs.png", dpi=130)
print(f"\nwrote {OUT}/homodyne_m5_gs.png")
