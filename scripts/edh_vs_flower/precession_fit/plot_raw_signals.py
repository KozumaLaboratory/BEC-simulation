import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator

SD = sys.argv[1]
TU = 1000/691.15     # 1 w^-1 in ms

cbP = json.load(open(f"{SD}/pure_cbmeta.json"));  amP = json.load(open(f"{SD}/angmom_meta.json"))
cbQ = json.load(open(f"{SD}/q500_cbmeta.json"));  amQ = json.load(open(f"{SD}/angmom_meta_q500.json"))

def ms(x): return np.array(x)*TU

sets = [
    ("pure parabola",  ms(cbP["times"]), np.array(cbP["cb"]), ms(amP["times"]),
     np.array(amP["Fz"]), np.array(amP["Lz"]), 90*TU),
    ("quench+parabola", ms(cbQ["times"]), np.array(cbQ["cb"]), ms(amQ["times"]),
     np.array(amQ["Fz"]), np.array(amQ["Lz"]), 24*TU),
]

fig, axes = plt.subplots(3, 2, figsize=(17, 12), sharex="col")
for col, (name, tcb, cb, tam, Fz, Lz, thold) in enumerate(sets):
    for row, (t, y, lab, col_) in enumerate([
            (tcb, cb, "cb(t)   checkerboard", "#d84330"),
            (tam, Fz, "⟨Fz⟩(t)", "#185fa5"),
            (tam, Lz, "⟨Lz⟩(t)", "#1d9e75")]):
        ax = axes[row][col]
        ax.plot(t, y, "-o", color=col_, ms=3.4, lw=1.3, mfc="white", mew=0.9)
        ax.axvspan(thold, t.max(), color="#ffe9a8", alpha=0.35, zorder=0)
        ax.axhline(np.mean(y[t >= thold]), color="#888", ls="--", lw=1,
                   label=f"hold mean = {np.mean(y[t>=thold]):+.3f}")
        ax.grid(which="major", axis="x", color="#999", lw=0.8, alpha=0.6)
        ax.grid(which="minor", axis="x", color="#ccc", lw=0.5, alpha=0.6)
        ax.grid(which="major", axis="y", color="#ddd", lw=0.5)
        ax.xaxis.set_major_locator(MultipleLocator(25))
        ax.xaxis.set_minor_locator(MultipleLocator(5))
        ax.set_ylabel(lab, fontsize=11)
        ax.legend(fontsize=8, loc="upper left")
        if row == 0:
            ax.set_title(f"{name}   (yellow = hold at 26 µG; major grid 25 ms, minor 5 ms)", fontsize=11)
        if row == 2:
            ax.set_xlabel("time [ms]", fontsize=11)
fig.suptitle("RAW SIGNALS — no fitting, no smoothing. Every marker is a saved frame. Read the period off the grid.",
             fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.96])
fig.savefig(f"{SD}/raw_signals.png", dpi=130)
print("wrote raw_signals.png")

# --- printed table of the hold-phase samples so the numbers can be checked directly ---
print("\n=== pure parabola, HOLD phase raw samples (t in ms) ===")
t = ms(cbP["times"]); cb = np.array(cbP["cb"]); m = t >= 90*TU
ta = ms(amP["times"]); Fz = np.array(amP["Fz"]); ma = ta >= 90*TU
print("   t[ms]     cb        Fz")
for i in np.where(m)[0]:
    j = np.argmin(abs(ta - t[i]))
    print(f"  {t[i]:7.1f}  {cb[i]:+7.3f}  {Fz[j]:+8.4f}")
