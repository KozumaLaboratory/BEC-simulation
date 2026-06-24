#!/usr/bin/env python3
"""2D phase map (B × λ) from recon.csv: per-cell GS phase + order parameters.

  python scripts/viz_phase_recon_2d.py [figs/phase_recon_2d]
"""
import sys
import os
import csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "figs/phase_recon_2d"

rows = []
with open(os.path.join(D, "recon.csv")) as fh:
    r = csv.reader(fh, delimiter="\t")
    next(r)
    for ln in r:
        rows.append(dict(lam=float(ln[0]), B=float(ln[1]), seed=ln[2], E=float(ln[3]),
                         grad=float(ln[4]), Fz=float(ln[5]), Fperp=float(ln[6]), phase=ln[7]))

lams = sorted(set(r["lam"] for r in rows))
Bs = sorted(set(r["B"] for r in rows))

# winner (lowest-E) per (lam, B)
win = {}
for lam in lams:
    for B in Bs:
        cell = [r for r in rows if r["lam"] == lam and r["B"] == B]
        if cell:
            win[(lam, B)] = min(cell, key=lambda r: r["E"])

phase_list = sorted(set(w["phase"] for w in win.values()))
pcode = {p: i for i, p in enumerate(phase_list)}

def grid_of(key):
    M = np.full((len(lams), len(Bs)), np.nan)
    for i, lam in enumerate(lams):
        for j, B in enumerate(Bs):
            if (lam, B) in win:
                w = win[(lam, B)]
                M[i, j] = pcode[w["phase"]] if key == "phase" else w[key]
    return M

ext = [min(Bs), max(Bs), min(lams), max(lams)]
fig, ax = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle("Eu F=6 + DDI — 2D reconnaissance phase map  (B × trap aspect ratio λ=ω_z/ω_⊥)",
             fontsize=13)

# 1. phase map
M = grid_of("phase")
im = ax[0, 0].imshow(M, origin="lower", extent=ext, aspect="auto", cmap="tab10",
                     vmin=0, vmax=max(9, len(phase_list)))
for i, lam in enumerate(lams):
    for j, B in enumerate(Bs):
        if (lam, B) in win:
            ax[0, 0].text(B, lam, win[(lam, B)]["phase"][:4], ha="center", va="center",
                          fontsize=7, color="white")
ax[0, 0].set_title("GS phase"); ax[0, 0].set_xlabel("B (µG)"); ax[0, 0].set_ylabel("λ = ω_z/ω_⊥")

# 2. ⟨F_z⟩
im = ax[0, 1].imshow(grid_of("Fz"), origin="lower", extent=ext, aspect="auto", cmap="RdBu_r")
ax[0, 1].set_title("⟨F_z⟩"); ax[0, 1].set_xlabel("B (µG)"); ax[0, 1].set_ylabel("λ")
plt.colorbar(im, ax=ax[0, 1], fraction=0.046)

# 3. |F_perp|
im = ax[1, 0].imshow(grid_of("Fperp"), origin="lower", extent=ext, aspect="auto", cmap="viridis")
ax[1, 0].set_title("|F⊥| (transverse texture)"); ax[1, 0].set_xlabel("B (µG)"); ax[1, 0].set_ylabel("λ")
plt.colorbar(im, ax=ax[1, 0], fraction=0.046)

# 4. convergence |gradE| (quality flag)
im = ax[1, 1].imshow(np.log10(grid_of("grad")), origin="lower", extent=ext, aspect="auto", cmap="magma_r")
ax[1, 1].set_title("log₁₀|∇E| (convergence quality)"); ax[1, 1].set_xlabel("B (µG)"); ax[1, 1].set_ylabel("λ")
plt.colorbar(im, ax=ax[1, 1], fraction=0.046)

plt.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(D, "phase_map_2d.png")
plt.savefig(out, dpi=130)
print("wrote", out, "| phases:", phase_list)
