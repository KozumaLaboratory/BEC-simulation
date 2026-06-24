#!/usr/bin/env python3
"""Multi-panel figure of the weak-field Eu+DDI true (symmetry-broken) ground state.

Reads the CSVs dumped by scripts/eu_truegs_figure_data.jl and renders density,
transverse-spin texture, F_z, phase, m-populations and energy decomposition.

  python scripts/viz_truegs.py [figs/truegs]
"""
import sys
import os
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "figs/truegs"

def load(name):
    return np.loadtxt(os.path.join(D, name), delimiter="\t")

x = load("x.csv")
dens = load("density_xy.csv")
fx, fy, fz = load("fx_xy.csv"), load("fy_xy.csv"), load("fz_xy.csv")
fperp = load("fperp_xy.csv")
phase = load("phase_xy.csv")
pops = load("populations.csv")          # cols: m, population
meta = {}
with open(os.path.join(D, "meta.csv")) as fh:
    next(fh)
    for line in fh:
        parts = line.strip().split("\t")
        if len(parts) == 2:
            try:
                meta[parts[0]] = float(parts[1])
            except ValueError:
                meta[parts[0]] = parts[1]

ext = [x.min(), x.max(), x.min(), x.max()]   # imshow extent (x,y)

fig, ax = plt.subplots(2, 3, figsize=(15, 9.5))
fig.suptitle(
    "¹⁵¹Eu F=6 + DDI — weak-field true (symmetry-broken) ground state\n"
    f"grid={int(meta.get('grid',0))}³  B={meta.get('B_uG','?')} µG  "
    f"pin b_x={meta.get('eps_bx','?'):.0e}  "
    f"E={meta.get('E_total',0):.4f}  |∇E|={meta.get('grad_norm',0):.1e}",
    fontsize=13,
)

# 1. density (the "flower")
im = ax[0, 0].imshow(dens.T, origin="lower", extent=ext, cmap="inferno")
ax[0, 0].set_title("density  n(x,y)  [z-midplane]")
plt.colorbar(im, ax=ax[0, 0], fraction=0.046)

# 2. transverse spin texture |F_perp| + (Fx,Fy) quiver — the broken symmetry
im = ax[0, 1].imshow(fperp.T, origin="lower", extent=ext, cmap="viridis")
sk = max(1, dens.shape[0] // 16)
xx, yy = np.meshgrid(x, x, indexing="ij")
m = dens > 0.05 * dens.max()
ax[0, 1].quiver(xx[::sk, ::sk], yy[::sk, ::sk],
                np.where(m, fx, 0)[::sk, ::sk], np.where(m, fy, 0)[::sk, ::sk],
                color="white", scale_units="xy", pivot="mid")
ax[0, 1].set_title("transverse spin |F⊥| + (Fx,Fy)\n← spontaneously broken U(1)")
plt.colorbar(im, ax=ax[0, 1], fraction=0.046)

# 3. F_z
im = ax[0, 2].imshow(fz.T, origin="lower", extent=ext, cmap="RdBu_r",
                     vmin=-np.abs(fz).max(), vmax=np.abs(fz).max())
ax[0, 2].set_title("longitudinal spin  F_z(x,y)")
plt.colorbar(im, ax=ax[0, 2], fraction=0.046)

# 4. phase of dominant component (winding / vortex structure)
im = ax[1, 0].imshow(np.where(dens.T > 0.02 * dens.max(), phase.T, np.nan),
                     origin="lower", extent=ext, cmap="twilight",
                     vmin=-np.pi, vmax=np.pi)
ax[1, 0].set_title("phase arg(ψ) dominant comp")
plt.colorbar(im, ax=ax[1, 0], fraction=0.046, label="rad")

# 5. m-populations
mm, pp = pops[:, 0].astype(int), pops[:, 1]
ax[1, 1].bar(mm, pp, color="steelblue")
ax[1, 1].set_title("component populations  |c_m|²")
ax[1, 1].set_xlabel("m"); ax[1, 1].set_ylabel("fraction")
ax[1, 1].set_yscale("log"); ax[1, 1].set_ylim(1e-5, 1)

# 6. energy decomposition
ek = [(k[2:], v) for k, v in meta.items()
      if k.startswith("E_") and k != "E_total"]
ek = [(k, v) for k, v in ek if abs(v) > 1e-9]
ek.sort(key=lambda kv: -abs(kv[1]))
labels = [k for k, _ in ek]; vals = [v for _, v in ek]
ax[1, 2].barh(range(len(vals)), vals, color="indianred")
ax[1, 2].set_yticks(range(len(vals))); ax[1, 2].set_yticklabels(labels)
ax[1, 2].set_title(f"energy decomposition  (total {meta.get('E_total',0):.3f})")
ax[1, 2].invert_yaxis(); ax[1, 2].axvline(0, color="k", lw=0.5)

for a in (ax[0, 0], ax[0, 1], ax[0, 2], ax[1, 0]):
    a.set_xlabel("x"); a.set_ylabel("y")

plt.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(D, "truegs_summary.png")
plt.savefig(out, dpi=130)
print("wrote", out)
