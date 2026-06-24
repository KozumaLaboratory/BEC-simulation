#!/usr/bin/env python3
"""Phase-1 reconnaissance map: read recon.csv / recon_pops.csv and show where the
ground-state phase changes across the parameter range (= candidate boundaries).

  python scripts/viz_phase_recon.py [figs/phase_recon]
"""
import sys
import os
import csv
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "figs/phase_recon"

rows = []
with open(os.path.join(D, "recon.csv")) as fh:
    r = csv.reader(fh, delimiter="\t")
    next(r)
    for line in r:
        rows.append(dict(B=float(line[0]), seed=line[1], E=float(line[2]),
                         grad=float(line[3]), Fz=float(line[4]),
                         Fperp=float(line[5]), phase=line[6]))

Bs = sorted(set(r["B"] for r in rows))
seeds = sorted(set(r["seed"] for r in rows))

# winners = lowest-E per B
win = {}
for B in Bs:
    cell = [r for r in rows if r["B"] == B]
    win[B] = min(cell, key=lambda r: r["E"])

# populations heatmap
pop_rows = []
with open(os.path.join(D, "recon_pops.csv")) as fh:
    r = csv.reader(fh, delimiter="\t")
    hdr = next(r)
    for line in r:
        pop_rows.append((float(line[0]), line[1], [float(v) for v in line[2:]]))
mlabels = hdr[2:]
# winner populations per B
winpop = {}
for B in Bs:
    ws = win[B]["seed"]
    for (b, s, p) in pop_rows:
        if b == B and s == ws:
            winpop[B] = p

fig, ax = plt.subplots(2, 2, figsize=(14, 9))
fig.suptitle("Phase-1 reconnaissance — multi-seed-from-scratch (unbiased). "
             "Phase / order-parameter changes between cells ⇒ a boundary lives there.",
             fontsize=12)

# 1. E vs B per seed + winner envelope
for s in seeds:
    pts = sorted([(r["B"], r["E"]) for r in rows if r["seed"] == s])
    ax[0, 0].plot([p[0] for p in pts], [p[1] for p in pts], "o-", alpha=0.5, label=s)
ax[0, 0].plot(Bs, [win[B]["E"] for B in Bs], "k*-", ms=12, lw=2, label="GS (min)")
ax[0, 0].set_xlabel("B (µG)"); ax[0, 0].set_ylabel("energy")
ax[0, 0].set_title("E(B) per seed + GS envelope\n(seed crossings = transitions)")
ax[0, 0].legend(fontsize=8); ax[0, 0].grid(alpha=0.3)

# 2. order parameters of the winner vs B
ax2 = ax[0, 1]
ax2.plot(Bs, [win[B]["Fz"] for B in Bs], "o-", color="crimson", label="⟨F_z⟩")
ax2.plot(Bs, [win[B]["Fperp"] for B in Bs], "s-", color="navy", label="|F⊥|")
ax2.axhline(0, color="gray", lw=0.5)
ax2.set_xlabel("B (µG)"); ax2.set_ylabel("order parameter")
ax2.set_title("GS order parameters vs B\n(jump/kink = boundary)")
ax2.legend(); ax2.grid(alpha=0.3)

# 3. phase label of the winner vs B
phases = [win[B]["phase"] for B in Bs]
uniq = sorted(set(phases))
cmap = {p: i for i, p in enumerate(uniq)}
ax[1, 0].scatter(Bs, [cmap[p] for p in phases], c=[cmap[p] for p in phases],
                 cmap="tab10", s=120)
for B, p in zip(Bs, phases):
    ax[1, 0].annotate(p, (B, cmap[p]), fontsize=8, ha="center", va="bottom")
ax[1, 0].set_yticks(range(len(uniq))); ax[1, 0].set_yticklabels(uniq)
ax[1, 0].set_xlabel("B (µG)"); ax[1, 0].set_title("GS phase label vs B")
ax[1, 0].grid(alpha=0.3)

# 4. winner m-populations heatmap (B × m)
M = np.array([winpop[B] for B in Bs])     # (nB, 2F+1)
im = ax[1, 1].imshow(M.T, origin="lower", aspect="auto", cmap="viridis",
                     extent=[min(Bs), max(Bs), -0.5, M.shape[1] - 0.5])
ax[1, 1].set_yticks(range(len(mlabels))); ax[1, 1].set_yticklabels(mlabels, fontsize=7)
ax[1, 1].set_xlabel("B (µG)"); ax[1, 1].set_title("GS m-populations vs B")
plt.colorbar(im, ax=ax[1, 1], fraction=0.046)

plt.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(D, "phase_recon_map.png")
plt.savefig(out, dpi=130)
print("wrote", out)
