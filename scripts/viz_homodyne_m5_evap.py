# Render the m=-5 Raman-homodyne readout study produced by homodyne_m5_evap_readout.jl.
#
#   HOMODYNE_OUT=figs/homodyne_m5_evap python scripts/viz_homodyne_m5_evap.py
#
# Four panels:
#   A  homodyne vs direct readout: signal & SNR vs atom number N (the headline)
#   B  the readout riding the euv3 evaporation trajectory N(t), with BEC onset
#   C  optimization surface: homodyne SNR over (duration × final-power) ramp transform
#   D  lab ramp vs monotone-optimized ramp — atom number and homodyne SNR gain
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

OUT = os.environ.get("HOMODYNE_OUT", "figs/homodyne_m5_evap")

meta = {}
for line in open(f"{OUT}/meta.csv").read().splitlines()[1:]:
    k, v = line.split(",")
    meta[k] = float(v)
eps, theta, sig_det = meta["eps"], meta["theta"], meta["sig_det"]

A = np.loadtxt(f"{OUT}/signal_vs_N.csv", delimiter=",", skiprows=1)
N, s_hom, s_dir, snr_hom, snr_dir = A.T

B = np.loadtxt(f"{OUT}/ramp_trajectory.csv", delimiter=",", skiprows=1)
t, Nt, T_uK, psd, snr_hom_t, snr_dir_t = B.T

S = np.loadtxt(f"{OUT}/opt_surface.csv", delimiter=",", skiprows=1)
ax = np.loadtxt(f"{OUT}/opt_axes.csv", delimiter=",")
ds, fs = ax[0], ax[1]
nds, nfs = len(ds), len(fs)
snr_grid = S[:, 5].reshape(nds, nfs)
nbec_grid = S[:, 3].reshape(nds, nfs)

C = open(f"{OUT}/ramp_compare.csv").read().splitlines()[1:]
labels, Nfin, Nbec, snrc = [], [], [], []
for row in C:
    lab, nf, nb, sn = row.split(",")
    labels.append(lab); Nfin.append(float(nf)); Nbec.append(float(nb)); snrc.append(float(sn))

C_HOM, C_DIR = "#d6336c", "#1c7ed6"
fig = plt.figure(figsize=(15, 10))
fig.suptitle(
    f"m=-5 Raman-homodyne readout across the euv3 evaporation ramp "
    f"(ε={eps:g}, θ={theta:g} rad, σ_det={sig_det:g} atoms)",
    fontsize=14, fontweight="bold")

# --- Panel A: signal & SNR vs N ---
axA = fig.add_subplot(2, 2, 1)
axA.loglog(N, s_hom, color=C_HOM, lw=2.2, label="homodyne signal  2 sinθ√ε·N")
axA.loglog(N, s_dir, color=C_DIR, lw=2.2, ls="--", label="direct signal  εN")
axA.set_xlabel("atom number N (m=-6 reservoir)")
axA.set_ylabel("m=-5 readout signal [atoms]", color="0.2")
axA.grid(alpha=0.25, which="both")
axB2 = axA.twinx()
axB2.semilogx(N, snr_hom, color=C_HOM, lw=1.4, alpha=0.55)
axB2.semilogx(N, snr_dir, color=C_DIR, lw=1.4, alpha=0.55, ls="--")
axB2.set_ylabel("SNR  (faint lines)")
axB2.axhline(1.0, color="0.5", lw=0.8, ls=":")
# floor crossing for direct readout (SNR_dir = 1)
above = np.where(snr_dir >= 1.0)[0]
if len(above):
    Ncross = N[above[0]]
    axA.axvline(Ncross, color=C_DIR, lw=0.8, ls=":")
    axA.text(Ncross, s_dir.min() * 3, f"direct SNR=1\n@N={Ncross:.0f}",
             color=C_DIR, fontsize=8, ha="left")
adv = float(np.nanmedian(s_hom / s_dir))
axA.text(0.50, 0.06, f"homodyne / direct  ≈ ×{adv:.1f}\n(= 2 sinθ/√ε, amplitude gain)",
         transform=axA.transAxes, fontsize=9, color=C_HOM,
         bbox=dict(boxstyle="round", fc="white", ec=C_HOM, alpha=0.8))
axA.set_title("A  homodyne is linear in the m=-5 amplitude → readable at low N", fontsize=11)
axA.legend(loc="upper left", fontsize=9)

# --- Panel B: readout along the evaporation trajectory ---
axT = fig.add_subplot(2, 2, 2)
axT.semilogy(t, Nt, color="0.25", lw=2.2, label="N(t) atom number")
axT.set_xlabel("evaporation time t [s]")
axT.set_ylabel("atom number N(t)", color="0.25")
axT.grid(alpha=0.25, which="both")
axS = axT.twinx()
axS.plot(t, snr_hom_t, color=C_HOM, lw=2.0, label="homodyne SNR")
axS.plot(t, snr_dir_t, color=C_DIR, lw=2.0, ls="--", label="direct SNR")
axS.set_ylabel("m=-5 readout SNR")
axS.axhline(1.0, color="0.5", lw=0.9, ls=":")
axS.text(t[0], 1.0, " readable (SNR=1)", color="0.4", fontsize=8, va="bottom")
axS.annotate(f"homodyne {snr_hom_t[-1]:.1f}\ndirect {snr_dir_t[-1]:.2f} (buried)",
             xy=(t[-1], snr_hom_t[-1]), xytext=(t[-1] * 0.62, max(snr_hom_t) * 0.55),
             fontsize=8.5, color=C_HOM,
             arrowprops=dict(arrowstyle="->", color=C_HOM, lw=1.0))
if "t_BEC" in meta and meta["t_BEC"] > 0:
    axT.axvline(meta["t_BEC"], color="seagreen", lw=1.2, ls="-.")
    axT.text(meta["t_BEC"], Nt.max(), " BEC onset", color="seagreen",
             fontsize=8, va="top")
l1, lab1 = axT.get_legend_handles_labels()
l2, lab2 = axS.get_legend_handles_labels()
axT.legend(l1 + l2, lab1 + lab2, loc="lower left", fontsize=9)
axT.set_title("B  the readout rides the cooling trajectory in real time", fontsize=11)

# --- Panel C: optimization surface ---
axC = fig.add_subplot(2, 2, 3)
sg = np.ma.masked_invalid(snr_grid.T)
pcm = axC.pcolormesh(ds, fs, sg, shading="auto", cmap="magma")
fig.colorbar(pcm, ax=axC, label="homodyne SNR at ramp end")
# BEC-reached region contour
ng = np.ma.masked_invalid(nbec_grid.T)
if np.isfinite(nbec_grid).any():
    axC.contour(ds, fs, np.isfinite(nbec_grid.T).astype(float),
                levels=[0.5], colors="cyan", linewidths=1.2)
# mark the optimum
jmax = np.unravel_index(np.nanargmax(snr_grid), snr_grid.shape)
axC.plot(ds[jmax[0]], fs[jmax[1]], "*", color="white", ms=16,
         markeredgecolor="k", label="max SNR")
axC.plot(1.0, 1.0, "o", color="cyan", ms=8, markeredgecolor="k", label="lab ramp")
axC.set_xlabel("duration scale")
axC.set_ylabel("final-power scale")
axC.legend(loc="upper right", fontsize=8)
axC.set_title("C  ramp that maximizes N also maximizes m=-5 SNR (∝√N)", fontsize=11)

# --- Panel D: lab vs optimized ---
axD = fig.add_subplot(2, 2, 4)
x = np.arange(len(labels))
w = 0.38
nb_plot = [nb if np.isfinite(nb) else nf for nb, nf in zip(Nbec, Nfin)]
b1 = axD.bar(x - w / 2, nb_plot, w, color="0.45", label="N (BEC / final)")
axD.set_ylabel("atom number", color="0.3")
axD.set_yscale("log")
axDr = axD.twinx()
b2 = axDr.bar(x + w / 2, snrc, w, color=C_HOM, label="homodyne SNR")
axDr.set_ylabel("homodyne SNR", color=C_HOM)
axD.set_xticks(x)
axD.set_xticklabels(labels)
for xi, nb, sn in zip(x, nb_plot, snrc):
    axD.text(xi - w / 2, nb, f"{nb:.0f}", ha="center", va="bottom", fontsize=8)
    axDr.text(xi + w / 2, sn, f"{sn:.0f}", ha="center", va="bottom", fontsize=8, color=C_HOM)
gain = snrc[1] / snrc[0] if snrc[0] else float("nan")
axD.set_title(f"D  optimized ramp: ×{gain:.1f} m=-5 homodyne SNR", fontsize=11)

plt.tight_layout(rect=[0, 0, 1, 0.96])
plt.savefig(f"{OUT}/homodyne_m5_evap.png", dpi=130)
print(f"wrote {OUT}/homodyne_m5_evap.png")
