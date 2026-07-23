import sys, csv, os, re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec

OUT = sys.argv[1]
ZETA3 = 1.2020569

# --- validated palette (dataviz reference, light surface) ---
SURFACE = "#fcfcfb"
INK      = "#0b0b0b"
INK2     = "#52514e"
GRID     = "#dedcd6"
C_LAB    = "#2a78d6"   # categorical slot 1 (baseline)
C_OPT    = "#eb6834"   # categorical slot 2 (optimized)

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE,
    "font.family": "DejaVu Sans", "font.size": 11,
    "axes.edgecolor": GRID, "axes.linewidth": 1.0,
    "axes.labelcolor": INK2, "text.color": INK,
    "xtick.color": INK2, "ytick.color": INK2,
    "axes.titlecolor": INK,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "grid.alpha": 0.7,
    "axes.spines.top": False, "axes.spines.right": False,
})

def load(name):
    with open(os.path.join(OUT, name)) as f:
        r = csv.reader(f); hdr = next(r)
        cols = {h: [] for h in hdr}
        for row in r:
            for h, v in zip(hdr, row): cols[h].append(float(v))
    return {h: np.array(v) for h, v in cols.items()}

tl, to = load("traj_lab.csv"), load("traj_opt.csv")
rl, ro = load("ramp_lab.csv"), load("ramp_opt.csv")
S = open(os.path.join(OUT, "summary.txt")).read()
g = lambda p: re.search(p, S).group(1)
labN, optN = float(g(r"LAB : .*N_BEC=([\d.eE+-]+)")), float(g(r"OPT : .*N_BEC=([\d.eE+-]+)"))
labG, optG = float(g(r"LAB :.*gamma_eff=([\d.-]+)")), float(g(r"OPT :.*gamma_eff=([\d.-]+)"))
factor = float(g(r"improvement factor = ([\d.]+)x"))
tbec_lab, tbec_opt = tl["t"][-1], to["t"][-1]

fig = plt.figure(figsize=(14.5, 8.4))
gs = gridspec.GridSpec(3, 3, height_ratios=[0.42, 1, 1], width_ratios=[1.35, 1, 1],
                       hspace=0.42, wspace=0.32,
                       left=0.065, right=0.975, top=0.99, bottom=0.075)

# ===== hero banner =====
hero = fig.add_subplot(gs[0, :]); hero.axis("off")
hero.text(0.0, 0.72, "Optimizing the ¹⁵¹Eu evaporation ramp",
          fontsize=19, fontweight="bold", color=INK, va="center")
hero.text(0.0, 0.20, "First-principles LRW truncated-Boltzmann model  ·  realizable monotone-decreasing FORT schedule",
          fontsize=11, color=INK2, va="center")
def stat(x, big, small, color):
    hero.text(x, 0.72, big, fontsize=26, fontweight="bold", color=color, va="center", ha="left")
    hero.text(x, 0.16, small, fontsize=10.5, color=INK2, va="center", ha="left")
stat(0.615, f"{factor:.1f}×", "more atoms\nin the BEC", C_OPT)
stat(0.755, f"{tbec_lab/tbec_opt:.1f}×", "faster to\nBEC onset", C_OPT)
stat(0.895, f"{optG:.1f}", "efficiency γ\n(lab 1.6)", INK)

# ===== HERO PLOT: efficiency PSD vs N (log-log) =====
ax = fig.add_subplot(gs[1:, 0])
ax.plot(tl["N"], tl["psd"], color=C_LAB, lw=2.4, solid_capstyle="round")
ax.plot(to["N"], to["psd"], color=C_OPT, lw=2.4, solid_capstyle="round")
ax.axhline(ZETA3, color=INK2, ls=(0, (2, 3)), lw=1.2)
ax.text(ax.get_xlim()[0], ZETA3, "  ζ(3) — BEC onset", color=INK2, fontsize=9.5,
        va="bottom", ha="left")
# BEC onset markers + direct labels
for N, col, name in [(labN, C_LAB, "lab"), (optN, C_OPT, "opt")]:
    ax.plot(N, ZETA3, "o", ms=10, color=col, mec=SURFACE, mew=1.8, zorder=5)
ax.set_xscale("log"); ax.set_yscale("log"); ax.invert_xaxis()
ax.set_xlabel("atom number  N   (evaporation runs → fewer)")
ax.set_ylabel("phase-space density  ρ")
ax.set_title("Evaporation efficiency: the optimized ramp reaches\nBEC with more atoms remaining",
             fontsize=12.5, loc="left", pad=8)
# annotate the gap at onset
ax.annotate("", xy=(optN, ZETA3), xytext=(labN, ZETA3),
            arrowprops=dict(arrowstyle="-|>", color=INK, lw=1.6,
                            connectionstyle="arc3,rad=-0.25"))
ax.text(np.sqrt(labN*optN), ZETA3*1.9, f"{factor:.1f}× more atoms",
        color=INK, fontsize=11, ha="center", fontweight="bold")
ax.text(labN, ZETA3*0.62, f"lab\n{labN/1e5:.2f}×10⁵", color=INK, fontsize=10,
        ha="center", va="top")
ax.text(optN, ZETA3*0.62, f"opt\n{optN/1e5:.2f}×10⁵", color=INK, fontsize=10,
        ha="center", va="top", fontweight="bold")

# ===== TOP-RIGHT (span 2 cols): FORT power schedule =====
ax2 = fig.add_subplot(gs[1, 1:])
ax2.plot(rl["t"], rl["HFORT"], color=C_LAB, lw=2.2, solid_capstyle="round")
ax2.plot(rl["t"], rl["VFORT"], color=C_LAB, lw=1.6, ls=(0, (3, 2)))
ax2.plot(ro["t"], ro["HFORT"], color=C_OPT, lw=2.2, solid_capstyle="round")
ax2.plot(ro["t"], ro["VFORT"], color=C_OPT, lw=1.6, ls=(0, (3, 2)))
ax2.set_yscale("log"); ax2.set_xlabel("time  t  [s]"); ax2.set_ylabel("FORT power  [W]")
ax2.set_title("FORT power schedule — the optimum evaporates harder early",
              fontsize=12, loc="left", pad=6)
# highlight the "harder early" region
ax2.axvspan(0, 0.5, color=C_OPT, alpha=0.06, lw=0)
ax2.text(0.25, ax2.get_ylim()[0]*1.6, "steep early drop\n(peak collision rate)",
         color=C_OPT, fontsize=9, ha="center", va="bottom")
# direct labels
ax2.text(rl["t"][-1], rl["HFORT"][-1], "  lab", color=C_LAB, fontsize=10, va="center", fontweight="bold")
ax2.text(ro["t"][-1], ro["HFORT"][-1]*0.7, "  opt", color=C_OPT, fontsize=10, va="center", fontweight="bold")
ax2.plot([], [], color=INK2, lw=2.2, label="HFORT (solid)")
ax2.plot([], [], color=INK2, lw=1.6, ls=(0, (3, 2)), label="VFORT (dashed)")
ax2.legend(loc="upper right", frameon=False, fontsize=9)

# ===== BOTTOM-MID: temperature T(t) =====
ax3 = fig.add_subplot(gs[2, 1])
ax3.plot(tl["t"], tl["T"]*1e6, color=C_LAB, lw=2.2, solid_capstyle="round")
ax3.plot(to["t"], to["T"]*1e6, color=C_OPT, lw=2.2, solid_capstyle="round")
Tbec_lab, Tbec_opt = tl["T"][-1]*1e6, to["T"][-1]*1e6
ax3.plot(tbec_lab, Tbec_lab, "o", ms=9, color=C_LAB, mec=SURFACE, mew=1.6, zorder=5)
ax3.plot(tbec_opt, Tbec_opt, "o", ms=9, color=C_OPT, mec=SURFACE, mew=1.6, zorder=5)
ax3.set_yscale("log"); ax3.set_xlabel("time  t  [s]"); ax3.set_ylabel("temperature  T  [µK]")
ax3.set_title("temperature T(t) — cooled to BEC", fontsize=11.5, loc="left", pad=6)
ax3.text(tbec_opt, Tbec_opt*1.9, f"opt\n{Tbec_opt*1e3:.0f} nK @ {tbec_opt:.2f} s",
         color=C_OPT, fontsize=9, ha="center", va="bottom", fontweight="bold")
ax3.text(tbec_lab, Tbec_lab*1.35, f"lab\n{Tbec_lab*1e3:.0f} nK @ {tbec_lab:.2f} s",
         color=C_LAB, fontsize=9, ha="right", va="bottom")

# ===== BOTTOM-RIGHT: N(t) =====
ax4 = fig.add_subplot(gs[2, 2])
ax4.plot(tl["t"], tl["N"], color=C_LAB, lw=2.2, solid_capstyle="round")
ax4.plot(to["t"], to["N"], color=C_OPT, lw=2.2, solid_capstyle="round")
ax4.plot(tbec_lab, labN, "o", ms=9, color=C_LAB, mec=SURFACE, mew=1.6, zorder=5)
ax4.plot(tbec_opt, optN, "o", ms=9, color=C_OPT, mec=SURFACE, mew=1.6, zorder=5)
ax4.set_yscale("log"); ax4.set_xlabel("time  t  [s]"); ax4.set_ylabel("atom number  N")
ax4.set_title("atoms retained to onset", fontsize=11.5, loc="left", pad=6)
ax4.text(tbec_opt, optN*1.5, "opt", color=C_OPT, fontsize=9.5, ha="center", fontweight="bold")
ax4.text(tbec_lab*0.97, labN*1.5, "lab", color=C_LAB, fontsize=9.5, ha="right", va="bottom")

png = os.path.join(OUT, "evap_optimization_nice.png")
fig.savefig(png, dpi=140)
print("wrote", png)
