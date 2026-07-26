#!/usr/bin/env python3
"""The recipe in one figure: how to optimize the ¹⁵¹Eu BEC with the harmonic trap.

Two stages, one message — **moderate on both knobs**: push each lever hard and the
BEC breaks (evaporate too fast → it never condenses; decompress too far → it melts),
so the physical optimum of each is an interior sweet spot, not the extreme.

Left  (stage 1, evaporation): N_BEC vs ramp-duration scale, with the finite-rate
(non-equilibrium) penalty on — faster cuts three-body loss, but too fast spills
instead of evaporates and no BEC forms. Optimum ≈ 0.6×.
Right (stage 2, ODT decompression): condensate N₀ vs final trap ω_final — looser
cuts loss, but too loose drops T_c∝ω̄ and melts the BEC. Optimum ≈ 0.6.

Reads eu_ft_evap_noneq.csv and eu_ft_decompress_refine.csv.
Usage: python3 eu_ft_recipe_plot.py
"""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = os.path.dirname(os.path.abspath(__file__))
BLUE, GREEN, RED, GREY = "#1f6feb", "#2da44e", "#d1242f", "#8a8a8a"

# ---- stage 1: evaporation (physical, non-equilibrium curve) ----
e = np.genfromtxt(os.path.join(here, "eu_ft_evap_noneq.csv"), delimiter=",", names=True)
ex = e["duration_scale"]; ey = e["N_BEC_noneq_on"]
o = np.argsort(ex); ex, ey = ex[o], ey[o]
ok = ey > 0
fail_x = ex[~ok].max() if (~ok).any() else ex.min()
iopt_e = np.argmax(ey[ok]); eopt_x, eopt_y = ex[ok][iopt_e], ey[ok][iopt_e]

# ---- stage 2: decompression (refined curve) ----
d = np.genfromtxt(os.path.join(here, "eu_ft_decompress_refine.csv"), delimiter=",", names=True)
dx = d["omega_final"]; dy = d["N0"]; dhold = float(np.atleast_1d(d["N0_hold"])[0])
o = np.argsort(dx); dx, dy = dx[o], dy[o]
iopt_d = np.argmax(dy); dopt_x, dopt_y = dx[iopt_d], dy[iopt_d]

fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.2, 5.0))

# ---- panel 1 ----
a1.axvspan(ex.min() - 0.05, fail_x + 0.02, color=RED, alpha=0.08)
a1.text(fail_x - 0.02, ey[ok].min() * 0.3, "too fast:\nBEC never\nforms\n(spilling)",
        color=RED, fontsize=9, ha="right", va="center")
a1.plot(ex[ok], ey[ok], "-o", color=BLUE, ms=6, lw=2)
a1.plot(eopt_x, eopt_y, "*", color=GREEN, ms=24, mec="white", mew=1.0, zorder=5)
a1.annotate(f"sweet spot\n≈ {eopt_x:.1f}× duration", xy=(eopt_x, eopt_y),
            xytext=(eopt_x + 0.35, eopt_y * 0.82), fontsize=10, color=GREEN,
            arrowprops=dict(arrowstyle="->", color=GREEN, lw=1.4))
a1.annotate("", xy=(ex.max() * 0.98, ey[ok][-1]), xytext=(eopt_x + 0.15, eopt_y * 0.98),
            arrowprops=dict(arrowstyle="->", color=GREY, lw=1.2))
a1.text(1.15, ey[ok][-1] * 1.03, "too slow:\nmore 3-body loss", color=GREY, fontsize=9, va="bottom")
a1.set_xlabel("evaporation ramp-duration scale  (← faster)")
a1.set_ylabel(r"$N_\mathrm{BEC}$ at formation")
a1.set_title("① evaporate FASTER — but not too fast")
a1.grid(True, alpha=0.25); a1.set_ylim(bottom=0)

# ---- panel 2 ----
a2.axhline(dhold, ls="--", color=GREY, lw=1.4)
a2.text(dx.min(), dhold, "  no decompression (HOLD)", color=GREY, fontsize=9, va="bottom")
a2.axvspan(dx.min() - 0.02, 0.475, color=RED, alpha=0.08)
a2.text(0.46, dopt_y * 0.985, "too loose:\n$T_c\\propto\\bar\\omega$ drops,\nBEC melts",
        color=RED, fontsize=9, ha="right", va="top")
a2.plot(dx, dy, "-o", color=BLUE, ms=6, lw=2)
a2.plot(dopt_x, dopt_y, "*", color=GREEN, ms=24, mec="white", mew=1.0, zorder=5)
a2.annotate(fr"sweet spot $\omega_\mathrm{{final}}\approx{dopt_x:.1f}$"
            f"\n(+{100*(dopt_y/dhold-1):.0f}% vs HOLD)", xy=(dopt_x, dopt_y),
            xytext=(dopt_x + 0.02, dopt_y - (dopt_y - dhold) * 0.55), fontsize=10, color=GREEN,
            arrowprops=dict(arrowstyle="->", color=GREEN, lw=1.4))
a2.set_xlabel(r"final trap $\omega_\mathrm{final}/\omega_\mathrm{form}$  (← looser)")
a2.set_ylabel(r"condensate $N_0$")
a2.set_title("② decompress the ODT — but not too far")
a2.grid(True, alpha=0.25)

fig.suptitle("How to optimize the ¹⁵¹Eu BEC (harmonic trap only):  "
             "MODERATE on both knobs — pushed to the extreme, the BEC breaks",
             fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0, 0, 1, 0.94])
out = os.path.join(here, "eu_ft_recipe.png")
fig.savefig(out, dpi=150)
print("wrote", out)
