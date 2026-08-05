#!/usr/bin/env python3
"""Complete ¹⁵¹Eu GS phase diagram on the c1 × κ plane, one panel per B slice.

    python scripts/eu_phase_diagram_c1kappa_mF.py out.png b0.csv [b10.csv b60.csv ...]

Each CSV has columns c1,kappa,B,seed,E,mF (both seeds per cell). The GROUND STATE
of a cell is the lower-energy seed; its rotation-invariant order parameter
mF = |⟨F⟩|/F (1 = ferromagnetic, 0 = polar/inert) is the phase-diagram field. Each
panel is a pcolormesh of GS mF over (c1, κ) with the mF=0.5 contour (the FM↔polar
first-order boundary) drawn on top, and c1=0 (FM/AFM contact) dashed.
"""
import sys, csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

out = sys.argv[1]
csvs = sys.argv[2:]

def _infer_B(path):
    # B is a fixed config value (not scanned), so it is not in the per-cell
    # override; read it from the slice filename (…b0…/b10…/b60… → µG).
    import re
    m = re.search(r"_b(\d+)_", path) or re.search(r"b(\d+)", path.split("/")[-1])
    return float(m.group(1)) if m else float("nan")

def load_gs(path):
    rows = list(csv.DictReader(open(path)))
    f = lambda r, k: float(r[k])
    # GS = min-energy seed per (c1, kappa)
    best = {}
    for r in rows:
        key = (round(f(r, "c1"), 6), round(f(r, "kappa"), 6))
        e = f(r, "E")
        if key not in best or e < best[key][0]:
            best[key] = (e, f(r, "mF"))
    c1s = sorted({k[0] for k in best})
    ks = sorted({k[1] for k in best})
    M = np.full((len(ks), len(c1s)), np.nan)
    for (c1, k), (_, mf) in best.items():
        M[ks.index(k), c1s.index(c1)] = mf
    return np.array(c1s), np.array(ks), M, _infer_B(path)

slices = [load_gs(c) for c in csvs]
n = len(slices)
fig, axes = plt.subplots(1, n, figsize=(4.6 * n, 4.2), squeeze=False, sharey=True)

def edges(v):
    v = np.asarray(v, float)
    if len(v) == 1:
        return np.array([v[0] - 0.5, v[0] + 0.5])
    m = (v[:-1] + v[1:]) / 2
    return np.concatenate([[v[0] - (m[0] - v[0])], m, [v[-1] + (v[-1] - m[-1])]])

for ax, (c1s, ks, M, B) in zip(axes[0], slices):
    pcm = ax.pcolormesh(edges(c1s), edges(ks), M, cmap="viridis",
                        vmin=0.0, vmax=1.0, shading="flat")
    # FM↔polar boundary + FM/AFM contact
    if M.shape[0] > 1 and M.shape[1] > 1:
        C1, K = np.meshgrid(c1s, ks)
        try:
            ax.contour(C1, K, M, levels=[0.5], colors="white", linewidths=2.0)
        except Exception:
            pass
    ax.axvline(0.0, color="0.85", ls="--", lw=1.2)
    ax.set_xlabel(r"$c_1/c_0$")
    ax.set_title(rf"$B = {B:.0f}\,\mu$G")
axes[0][0].set_ylabel(r"trap oblateness $\kappa = \omega_z$")
cb = fig.colorbar(pcm, ax=axes[0], fraction=0.046, pad=0.02)
cb.set_label(r"GS order parameter $m_F = |\langle F\rangle|/F$  (1=FM, 0=polar)")
fig.suptitle(r"$^{151}$Eu $F{=}6$ ground-state phase diagram: $c_1\times\kappa$ plane "
             r"(white = $m_F{=}0.5$ FM$\leftrightarrow$polar boundary)", y=1.02)
fig.savefig(out, dpi=150, bbox_inches="tight")
print("wrote", out)
for c1s, ks, M, B in slices:
    print(f"  B={B:.0f}µG: c1∈[{c1s.min():.3f},{c1s.max():.3f}] "
          f"κ∈[{ks.min():.2f},{ks.max():.2f}] cells={np.isfinite(M).sum()}/{M.size}")
