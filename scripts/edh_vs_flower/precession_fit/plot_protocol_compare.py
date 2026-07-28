"""Three comparison figures: field ramp, populations, and Fz/Lz dynamics,
for the pure quench (Matsui-style) vs quench+parabola protocols."""
import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator

SD, OUT = sys.argv[1], sys.argv[2]
TU = 1000/691.15                                   # 1 w^-1 in ms
d = json.load(open(f"{SD}/protocompare.json"))

ALL_RUNS = [("quench_only", "pure quench (5.8 ms)  — Matsui-style", "#d84330"),
            ("quench_par",  "quench + parabola (28.4 ms)",           "#185fa5"),
            ("gentle",      "gentle landing (130 ms)",               "#1d9e75")]
RUNS = [r for r in ALL_RUNS if r[0] in d]          # plot whatever was extracted
print("protocols present:", [r[0] for r in RUNS])

# --- field ramps, reconstructed from the configs ---
def B_quench_only(tw):                              # 10 mG -> 26 uG over 4 w^-1, then hold
    B0, Bh, TA = 0.01, 2.6e-5, 4.0
    return (B0 + (Bh-B0)*(tw/TA) if tw <= TA else Bh)*1e6      # -> uG
def B_quench_par(tw):                               # quench to 500 uG, parabola to 26, hold
    B0, Bq, Bh, TA, TB = 0.01, 5.0e-4, 2.6e-5, 4.0, 19.62
    if tw <= TA:     v = B0 + (Bq-B0)*(tw/TA)
    elif tw <= TA+TB: v = Bh + (Bq-Bh)*(1-(tw-TA)/TB)**2
    else:            v = Bh
    return v*1e6
def B_gentle(tw):                                   # single slow parabola over 90 w^-1
    B0, Bh, T = 0.01, 2.6e-5, 90.0
    v = Bh + (B0-Bh)*(1-min(tw, T)/T)**2
    return v*1e6
BFUN  = {"quench_only": B_quench_only, "quench_par": B_quench_par, "gentle": B_gentle}
THOLD = {"quench_only": 4.0*TU, "quench_par": 23.62*TU, "gentle": 90.0*TU}

# =========== FIGURE 1: B(t), linear scale ===========
fig, ax = plt.subplots(2, 1, figsize=(13, 8), sharex=True,
                       gridspec_kw={"height_ratios": [2, 1]})
TMAX_W = max(max(np.array(d[k]["times"])) for k, _, _ in RUNS)
tw = np.linspace(0, TMAX_W, 3000); tms = tw*TU
for key, lab, col in RUNS:
    ax[0].plot(tms, [BFUN[key](x) for x in tw], "-", color=col, lw=2.6, label=lab)
    ax[1].plot(tms, [BFUN[key](x) for x in tw], "-", color=col, lw=2.6, label=lab)
ax[0].axhline(26, color="#888", ls=":", lw=1.4)
ax[0].text(2, 26*1.06+300, "", fontsize=9)
ax[0].set_ylabel("B$_z$  [µG]", fontsize=13)
ax[0].set_title("① Magnetic-field ramp  B(t)  —  linear scale", fontsize=14)
ax[0].legend(fontsize=11); ax[0].grid(alpha=.3)
ax[1].set_ylim(0, 600); ax[1].axhline(26, color="#888", ls=":", lw=1.4)
ax[1].text(90, 40, "hold level 26 µG", fontsize=10, color="#666")
ax[1].set_ylabel("B$_z$  [µG]  (zoom)", fontsize=12); ax[1].set_xlabel("time [ms]", fontsize=13)
ax[1].grid(alpha=.3)
for a in ax:
    a.xaxis.set_major_locator(MultipleLocator(10)); a.xaxis.set_minor_locator(MultipleLocator(2))
fig.tight_layout(); fig.savefig(f"{OUT}/cmp1_field_ramp.png", dpi=130)
print("wrote cmp1_field_ramp.png")

# =========== FIGURE 2: populations ===========
fig, ax = plt.subplots(len(RUNS), 1, figsize=(14, 4.6*len(RUNS)), sharex=True)
ax = np.atleast_1d(ax)
cmap = plt.cm.turbo(np.linspace(0.05, 0.95, 7))
for r, (key, lab, col) in enumerate(RUNS):
    t = np.array(d[key]["times"])*TU
    P = np.array(d[key]["pops"]); n = min(len(t), len(P)); t, P = t[:n], P[:n]
    for i, m in enumerate(range(-6, 1)):
        c = 6-m
        if P[:, c].max() < 5e-3: continue
        ax[r].plot(t, P[:, c], "-o", ms=3, lw=1.9, color=cmap[i], label=f"m = {m:+d}")
    ax[r].axvspan(THOLD[key], t.max(), color="#ffe9a8", alpha=.35, zorder=0)
    ax[r].set_ylabel("population", fontsize=13)
    ax[r].set_title(f"{lab}", fontsize=13, color=col)
    ax[r].legend(fontsize=10, ncol=7, loc="upper center"); ax[r].grid(alpha=.3)
    ax[r].set_ylim(-0.03, 1.05)
    ax[r].xaxis.set_major_locator(MultipleLocator(10)); ax[r].xaxis.set_minor_locator(MultipleLocator(2))
ax[-1].set_xlabel("time [ms]", fontsize=13)
fig.suptitle("② Stern–Gerlach populations P$_m$(t)  —  the transfer is NOT a monotonic decay:\n"
             "m = −6 recovers and re-depletes periodically, and the whole ladder follows",
             fontsize=14)
fig.tight_layout(rect=[0,0,1,0.94]); fig.savefig(f"{OUT}/cmp2_populations.png", dpi=130)
print("wrote cmp2_populations.png")

# =========== FIGURE 3: Fz and Lz ===========
fig, ax = plt.subplots(3, 1, figsize=(14, 12), sharex=True)
for key, lab, col in RUNS:
    # per-atom Fz and Lz share one convention -> Jz = Fz + Lz is like-for-like
    tL = np.array(d[key]["t_Lz"])*TU
    Lz = np.array(d[key]["Lz"]); Fz = np.array(d[key]["Fz_pa"])
    n = min(len(tL), len(Lz), len(Fz)); tL, Lz, Fz = tL[:n], Lz[:n], Fz[:n]
    ax[0].plot(tL, Fz, "-o", ms=3, lw=2.0, color=col, label=lab)
    ax[1].plot(tL, Lz, "-o", ms=3, lw=2.0, color=col, label=lab)
    ax[2].plot(tL, Fz+Lz, "-o", ms=3, lw=2.0, color=col, label=f"{lab}:  J$_z$ = F$_z$+L$_z$")
ax[0].set_ylabel("⟨F$_z$⟩ per atom  (spin)", fontsize=13)
ax[0].set_title("③ Spin and orbital angular momentum — both oscillate, J$_z$ is conserved", fontsize=14)
ax[1].set_ylabel("⟨L$_z$⟩ per atom  (orbital)", fontsize=13)
ax[2].set_ylabel("⟨J$_z$⟩ per atom", fontsize=13); ax[2].set_xlabel("time [ms]", fontsize=13)
ax[2].axhline(-6, color="#888", ls=":", lw=1.4)
for a in ax:
    a.grid(alpha=.3); a.legend(fontsize=10)
    a.xaxis.set_major_locator(MultipleLocator(10)); a.xaxis.set_minor_locator(MultipleLocator(2))
fig.tight_layout(); fig.savefig(f"{OUT}/cmp3_Fz_Lz.png", dpi=130)
print("wrote cmp3_Fz_Lz.png")

# --- model-free periods for the record ---
def periods(t, y):
    y = y - np.polyval(np.polyfit(t, y, 2), t)
    ext = [(t[i], y[i] > y[i-1]) for i in range(1, len(y)-1) if (y[i]-y[i-1])*(y[i+1]-y[i]) < 0]
    mx = [e[0] for e in ext if e[1]]; mn = [e[0] for e in ext if not e[1]]
    return np.diff(mx), np.diff(mn)
print("\nmodel-free extremum spacings in the hold [ms]:")
for key, lab, _ in RUNS:
    t = np.array(d[key]["t_Lz"])*TU; Fz = np.array(d[key]["Fz_pa"])
    n = min(len(t), len(Fz)); t, Fz = t[:n], Fz[:n]
    h = t >= THOLD[key]
    dmx, dmn = periods(t[h], Fz[h])
    print(f"  {lab:28s} Fz  max-to-max {np.round(dmx,1)}   min-to-min {np.round(dmn,1)}")
