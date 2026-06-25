#!/usr/bin/env python3
"""2D (B × λ) heatmaps of the validated phase-fingerprint invariants per cell.

Reads fp_features.csv (from phase_fingerprint_map.jl) and renders |F|/F, spinor
coherence g, flux-closure ‖∇·F‖/‖∇F‖, and Jz on the (B, λ) grid. Under-converged
cells (|grad|>cutoff) are hatched, since their fingerprint is not yet a phase.

  python scripts/viz_fingerprint_map.py [figs/phase_recon_2d/fp_features.csv]
"""
import sys
import os
import csv
import numpy as np
import matplotlib.pyplot as plt

PATH = sys.argv[1] if len(sys.argv) > 1 else "figs/phase_recon_2d/fp_features.csv"
GRADMAX = float(os.environ.get("FV_GRADMAX", "1e-2"))

with open(PATH) as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))


def num(v):
    try:
        return float(v)
    except ValueError:
        return np.nan


lams = sorted({num(r["lambda"]) for r in rows})
Bs = sorted({num(r["B"]) for r in rows})
cell = {(num(r["lambda"]), num(r["B"])): r for r in rows}


def grid(field):
    M = np.full((len(lams), len(Bs)), np.nan)
    for i, lam in enumerate(lams):
        for j, B in enumerate(Bs):
            r = cell.get((lam, B))
            if r is not None:
                M[i, j] = num(r[field])
    return M


panels = [("mF", "|⟨F⟩|/F", "viridis"), ("coh", "coherence g", "magma"),
          ("fluxclosure", "flux-closure ‖∇·F‖/‖∇F‖", "RdYlGn_r"),
          ("Jz", "Jz = Lz+Fz", "coolwarm")]
fig, axes = plt.subplots(1, 4, figsize=(20, 4.6))
G = grid("grad")
for ax, (f, title, cmap) in zip(axes, panels):
    M = grid(f)
    im = ax.imshow(M, origin="lower", aspect="auto", cmap=cmap,
                   extent=[min(Bs), max(Bs), min(lams), max(lams)])
    ax.set_title(title)
    ax.set_xlabel("B (µG)")
    ax.set_ylabel("λ = ω_z/ω_⊥")
    fig.colorbar(im, ax=ax, fraction=0.046)
    # annotate value + hatch under-converged
    for i, lam in enumerate(lams):
        for j, B in enumerate(Bs):
            v = M[i, j]
            if np.isnan(v):
                continue
            uc = G[i, j] > GRADMAX
            ax.text(B, lam, f"{v:.2f}" + ("*" if uc else ""),
                    ha="center", va="center", fontsize=7,
                    color="white" if cmap in ("viridis", "magma") else "black")

fig.suptitle(f"Eu weak-field fingerprint map  ({os.path.dirname(PATH)})  "
             f"* = under-converged |grad|>{GRADMAX:g}", y=1.02)
fig.tight_layout()
out = os.path.join(os.path.dirname(PATH), "fingerprint_map.png")
fig.savefig(out, dpi=130, bbox_inches="tight")
print("wrote", out)
