# Single-shot m=-5 Raman-homodyne INTERFERENCE FRINGE vs atom number.
#
# The Raman beams carry an effective wavevector k_eff, so the LO injected from the
# m=-6 BEC (a_LO = sinθ √n · e^{ik·x}) interferes with the co-located m=-5 signal
# (a_s = √(εn) e^{iφ}) to produce SPATIAL fringes in the m=-5 column density:
#
#   n_{-5}(x) = (sin²θ+ε)·n(x)  +  2 sinθ √ε · n(x) · cos(k_eff·x − φ)
#               └── pedestal ──┘     └──── homodyne fringe (∝ n) ────┘
#
# We simulate ONE shot (per-pixel Poisson atom shot noise + read noise) at several
# atom numbers: the fringe amplitude rides on the BEC density, so it emerges from the
# single-shot noise only once N is large enough — that is the "visible in one shot"
# threshold, shown as the actual interferogram instead of an SNR number.
#
#   HOMODYNE_OUT=figs/homodyne_m5_evap python scripts/viz_homodyne_m5_fringe.py
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

endpoints = {}
for row in open(f"{OUT}/ramp_compare.csv").read().splitlines()[1:]:
    lab, nf, nb, sn = row.split(",")
    endpoints[lab] = float(nf)
N_lab = endpoints.get("lab", 6.5e4)
N_opt = endpoints.get("optimized", 1.1e5)

# --- imaging model ---
NPIX = 64
R = 18.0                      # Thomas-Fermi radius [px]
LAMBDA = 7.0                  # fringe period [px]  (~5 fringes across the cloud)
PHI0 = 0.0                    # signal relative phase
SIG_READ = 1.0               # per-pixel detection/read noise [atoms]
PED = np.sin(THETA) ** 2 + EPS              # pedestal fraction
AMP = 2 * np.sin(THETA) * np.sqrt(EPS)      # fringe-amplitude fraction
VIS = AMP / PED                             # intrinsic fringe visibility

x = np.arange(NPIX) - NPIX / 2 + 0.5
X, Y = np.meshgrid(x, x)
RR = X**2 + Y**2
tf = np.clip(1.0 - RR / R**2, 0.0, None)    # 2D Thomas-Fermi paraboloid
tf_norm = tf / tf.sum()                     # ∫ = 1


def m5_image(N, seed):
    rng = np.random.default_rng(seed)
    env = N * tf_norm                                   # m=-6 BEC column [atoms/px]
    fringe = PED + AMP * np.cos(2 * np.pi * X / LAMBDA - PHI0)
    lam = np.clip(env * fringe, 0.0, None)              # mean m=-5 counts/px
    shot = rng.poisson(lam).astype(float)
    return shot + rng.normal(0.0, SIG_READ, lam.shape), lam


Ns = [1.5e4, N_lab, N_opt, 3.0e5]
tags = ["low N", "lab BEC", "optimized", "high N"]

fig, axes = plt.subplots(2, 4, figsize=(16, 7.4),
                         gridspec_kw={"height_ratios": [1.25, 1]})
fig.suptitle(
    f"m=-5 Raman-homodyne interference fringe — single shot vs atom number "
    f"(θ={THETA:g}, ε={EPS:g}, intrinsic visibility {VIS:.0%})",
    fontsize=13, fontweight="bold")

for j, (N, tag) in enumerate(zip(Ns, tags)):
    img, lam = m5_image(N, seed=10 + j)

    # top: single-shot 2D m=-5 image
    axi = axes[0, j]
    vmax = max(lam.max() * 1.6, 1.0)
    axi.imshow(img, origin="lower", cmap="inferno", vmin=0, vmax=vmax,
               extent=[x[0], x[-1], x[0], x[-1]])
    axi.set_title(f"{tag}:  N = {N:.0f}", fontsize=11)
    axi.set_xticks([]); axi.set_yticks([])

    # bottom: column-integrated fringe (the measured interference signal)
    axp = axes[1, j]
    prof = img.sum(axis=0)                       # integrate y → 1D fringe [atoms/col]
    ideal = (N * tf_norm).sum(axis=0) * (PED + AMP * np.cos(2 * np.pi * x / LAMBDA - PHI0))
    axp.plot(x, prof, color="0.25", lw=1.0, marker="o", ms=2.5, label="single shot")
    axp.plot(x, ideal, color="#d6336c", lw=2.0, label="ideal fringe")
    # single-shot fringe-amplitude SNR over the cloud
    col_env = (N * tf_norm).sum(axis=0)
    mask = col_env > 0.05 * col_env.max()
    amp_col = AMP * col_env[mask]                                  # expected fringe amp
    noise_col = np.sqrt(np.clip(PED * col_env[mask], 0, None) + SIG_READ**2 * NPIX)
    snr_fr = np.sqrt(np.mean((amp_col / noise_col) ** 2))
    axp.text(0.03, 0.92, f"fringe SNR ≈ {snr_fr:.1f}", transform=axp.transAxes,
             fontsize=10, va="top",
             color=("seagreen" if snr_fr >= 2 else "firebrick"),
             bbox=dict(boxstyle="round", fc="white", alpha=0.8))
    axp.set_xlabel("x [px]  (fringe axis)")
    if j == 0:
        axp.set_ylabel("m=-5 column density\n[atoms / column]")
        axp.legend(loc="lower center", fontsize=8, ncol=2)
    axp.grid(alpha=0.25)

plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.savefig(f"{OUT}/homodyne_m5_fringe.png", dpi=130)
print(f"wrote {OUT}/homodyne_m5_fringe.png")
print(f"intrinsic visibility V = {VIS:.3f}  pedestal={PED:.4f}  amp={AMP:.4f}")
