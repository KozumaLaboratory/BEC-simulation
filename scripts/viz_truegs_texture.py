#!/usr/bin/env python3
"""Detailed spin-texture figure for the weak-field Eu+DDI true GS.

Reads the CSVs from scripts/eu_truegs_texture.jl and renders the orientation
field (azimuth Φ, polar Θ), spin-length, an xz cross-section (3D structure),
the transverse winding ℓ(r) and radial profiles.

  python scripts/viz_truegs_texture.py [figs/truegs]
"""
import sys
import os
import numpy as np
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "figs/truegs"

def load(name):
    return np.loadtxt(os.path.join(D, name), delimiter="\t")

x = load("tx_x.csv")
azim = load("tx_azim_xy.csv")
polar = load("tx_polar_xy.csv")
spinlen = load("tx_spinlen_xy.csv")
fperp = load("tx_fperp_xy.csv")
fx, fy, fz = load("tx_fx_xy.csv"), load("tx_fy_xy.csv"), load("tx_fz_xy.csv")
fx_xz, fz_xz = load("tx_fx_xz.csv"), load("tx_fz_xz.csv")
fperp_xz, spinlen_xz = load("tx_fperp_xz.csv"), load("tx_spinlen_xz.csv")
rings = load("tx_rings.csv")            # r, winding, fperp, fz
meta = {}
with open(os.path.join(D, "tx_meta.csv")) as fh:
    next(fh)
    for line in fh:
        p = line.strip().split("\t")
        if len(p) == 2:
            try:
                meta[p[0]] = float(p[1])
            except ValueError:
                meta[p[0]] = p[1]

ext = [x.min(), x.max(), x.min(), x.max()]
mask = fperp > 0.05 * fperp.max()
sk = max(1, azim.shape[0] // 18)
xx, yy = np.meshgrid(x, x, indexing="ij")

fig, ax = plt.subplots(2, 3, figsize=(16, 10))
fig.suptitle(
    "¹⁵¹Eu F=6 + DDI weak-field GS — spin-texture detail   "
    f"(winding ℓ_outer={meta.get('outer_winding',0):+.2f}, "
    f"skyrmion Q={meta.get('total_monopole_charge',0):+.2f}, "
    f"core |F|/F·n={meta.get('mean_spinlen_core',0):.2f})",
    fontsize=13,
)

# 1. azimuth Φ — winding of the transverse spin
im = ax[0, 0].imshow(np.where(mask.T, azim.T, np.nan), origin="lower", extent=ext,
                     cmap="hsv", vmin=-np.pi, vmax=np.pi)
ax[0, 0].quiver(xx[::sk, ::sk], yy[::sk, ::sk],
                np.where(mask, fx, 0)[::sk, ::sk], np.where(mask, fy, 0)[::sk, ::sk],
                color="k", scale_units="xy", pivot="mid", width=0.004)
ax[0, 0].set_title("azimuth Φ = atan2(Fy,Fx)  [winding]")
plt.colorbar(im, ax=ax[0, 0], fraction=0.046, label="rad")

# 2. polar Θ — tilt out of xy-plane
im = ax[0, 1].imshow(np.where(spinlen.T > 0.05, polar.T, np.nan), origin="lower",
                     extent=ext, cmap="coolwarm", vmin=0, vmax=np.pi)
ax[0, 1].set_title("polar Θ = acos(Fz/|F|)\n0=+z, π/2=in-plane, π=−z")
plt.colorbar(im, ax=ax[0, 1], fraction=0.046, label="rad")

# 3. spin-length fraction |F|/(F n)
im = ax[0, 2].imshow(spinlen.T, origin="lower", extent=ext, cmap="magma",
                     vmin=0, vmax=1)
ax[0, 2].set_title("spin-length |F|/(F·n)\n1=ferro, 0=unmagnetised")
plt.colorbar(im, ax=ax[0, 2], fraction=0.046)

# 4. xz cross-section — 3D structure (is it a line vortex along z?)
zext = [x.min(), x.max(), x.min(), x.max()]
im = ax[1, 0].imshow(fperp_xz.T, origin="lower", extent=zext, cmap="viridis")
mz = fperp_xz > 0.05 * fperp_xz.max()
ax[1, 0].quiver(xx[::sk, ::sk], yy[::sk, ::sk],
                np.where(mz, fx_xz, 0)[::sk, ::sk], np.where(mz, fz_xz, 0)[::sk, ::sk],
                color="white", scale_units="xy", pivot="mid", width=0.004)
ax[1, 0].set_title("xz cross-section: |F⊥| + (Fx,Fz)\n3D structure")
ax[1, 0].set_xlabel("x"); ax[1, 0].set_ylabel("z")
plt.colorbar(im, ax=ax[1, 0], fraction=0.046)

# 5. transverse winding ℓ(r)
ax[1, 1].axhline(0, color="gray", lw=0.5)
ax[1, 1].plot(rings[:, 0], rings[:, 1], "o-", color="darkgreen")
ax[1, 1].set_title("transverse winding ℓ(r) = ∮dΦ/2π")
ax[1, 1].set_xlabel("radius r"); ax[1, 1].set_ylabel("ℓ")
ax[1, 1].grid(alpha=0.3)

# 6. radial profiles
ax2 = ax[1, 2]
ax2.plot(rings[:, 0], rings[:, 2], "o-", color="purple", label="|F⊥|(r)")
ax2.plot(rings[:, 0], rings[:, 3], "s-", color="orange", label="Fz(r)")
ax2.axhline(0, color="gray", lw=0.5)
ax2.set_title("azimuthally-averaged radial profiles")
ax2.set_xlabel("radius r"); ax2.set_ylabel("spin")
ax2.legend(); ax2.grid(alpha=0.3)

for a in (ax[0, 0], ax[0, 1], ax[0, 2]):
    a.set_xlabel("x"); a.set_ylabel("y")

plt.tight_layout(rect=[0, 0, 1, 0.95])
out = os.path.join(D, "truegs_texture.png")
plt.savefig(out, dpi=130)
print("wrote", out)
