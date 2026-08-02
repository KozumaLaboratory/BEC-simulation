# Render the Stern-Gerlach + TOF observation produced by eu_sg_tof.jl.
# Top: combined camera image (log scale, all 2F+1 clouds). Bottom: per-component
# column profiles, each labeled by m and individually integrable.
#   SG_OUT=figs/sg_tof python scripts/viz_sg_tof.py
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

OUT = os.environ.get("SG_OUT", "figs/sg_tof")
img = np.loadtxt(f"{OUT}/combined.csv", delimiter=",")          # (NXC, NY)
xc = np.loadtxt(f"{OUT}/xaxis.csv", delimiter=",")
pp = np.loadtxt(f"{OUT}/profiles_perm.csv", delimiter=",")
ms = np.loadtxt(f"{OUT}/m_values.csv", delimiter=",").astype(int)
xp, prof_perm = pp[:, 0], pp[:, 1:]
vmax = img.max()

fig = plt.figure(figsize=(13, 7))

ax0 = fig.add_subplot(2, 1, 1)
yext = img.shape[1] / 2 * (xc[1] - xc[0])
ax0.imshow(img.T, origin="lower", aspect="auto", cmap="inferno",
           extent=[xc[0], xc[-1], -yext, yext],
           norm=LogNorm(vmin=vmax * 1e-4, vmax=vmax))
ax0.set_title(f"SG+TOF combined image — {len(ms)} separated clouds (log scale)")
ax0.set_xlabel("x (SG separation axis)")
ax0.set_ylabel("y")

ax1 = fig.add_subplot(2, 1, 2)
cmap = plt.cm.turbo(np.linspace(0, 1, len(ms)))
for j, m in enumerate(ms):
    col = prof_perm[:, j]
    ax1.fill_between(xp, 0, col, color=cmap[j], alpha=0.55)
    ax1.plot(xp, col, color=cmap[j], lw=1.0)
    ax1.text(xp[np.argmax(col)], col.max() * 1.02, f"{m:+d}",
             ha="center", va="bottom", fontsize=8, color=cmap[j])
ax1.set_title("per-component column profiles — each cloud cleanly separated")
ax1.set_xlabel("x (SG separation axis)")
ax1.set_ylabel("column density")
ax1.grid(alpha=0.3)

plt.tight_layout()
plt.savefig(f"{OUT}/sg_tof.png", dpi=130)
print(f"wrote {OUT}/sg_tof.png")
