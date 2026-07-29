import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

SD, OUT = sys.argv[1], sys.argv[2]
TU = 1000/691.15
d = json.load(open(f"{SD}/protocompare.json"))
RUNS = [("quench_only", "pure quench (5.8 ms)",   "#d84330", 4.0),
        ("quench_par",  "quench+parabola (28.4 ms)", "#185fa5", 23.62),
        ("gentle",      "gentle landing (130 ms)",  "#1d9e75", 90.0)]

def model(t, A, T, phi, C, k):
    return A*np.sin(2*np.pi*t/T + phi) + C + k*t

rows = []
fig, ax = plt.subplots(1, 2, figsize=(14, 5.6))
for key, lab, col, thold_w in RUNS:
    t = np.array(d[key]["t_Lz"])*TU
    Fz = np.array(d[key]["Fz_pa"])
    n = min(len(t), len(Fz)); t, Fz = t[:n], Fz[:n]
    h = t >= thold_w*TU
    th, yh = t[h]-t[h][0], Fz[h]
    # amplitude: peak-to-peak of the detrended hold signal
    det = yh - np.polyval(np.polyfit(th, yh, 2), th)
    ptp = det.max() - det.min()
    best = None
    for T0 in (25, 32, 39, 46):
        for p0 in np.linspace(0, 2*np.pi, 6, endpoint=False):
            try:
                p, _ = curve_fit(model, th, yh, p0=[0.3, T0, p0, yh.mean(), 0], maxfev=40000)
                r = yh - model(th, *p); r2 = 1 - np.sum(r**2)/np.sum((yh-yh.mean())**2)
                if 15 < abs(p[1]) < 70 and (best is None or r2 > best[1]):
                    best = (abs(p[1]), r2, 2*abs(p[0]))
            except Exception:
                pass
    T, r2, amp2A = best
    rows.append((lab, col, ptp, T, r2))
    print(f"{lab:28s} amp(p-p)={ptp:.3f}  T_fit={T:.1f} ms ({1000/T:.1f} Hz)  R²={r2:.2f}")
    ax[0].plot(th, yh, "-", color=col, lw=1.8, label=f"{lab}   T={T:.1f} ms")

ax[0].set_xlabel("time since hold start [ms]"); ax[0].set_ylabel("⟨F$_z$⟩ per atom")
ax[0].set_title("hold-phase ⟨F$_z$⟩ for the three landing speeds", fontsize=11)
ax[0].legend(fontsize=9); ax[0].grid(alpha=.3)

A = np.array([r[2] for r in rows]); T = np.array([r[3] for r in rows])
for lab, col, a, tt, r2 in rows:
    ax[1].scatter([a], [1000/tt], s=150, color=col, zorder=5, label=f"{lab}")
ax[1].axhline(42.3, color="c", ls=":", lw=2, label="bare Larmor 42.3 Hz")
ax[1].set_xlabel("oscillation amplitude  (peak-to-peak ⟨F$_z$⟩)")
ax[1].set_ylabel("frequency [Hz]")
ax[1].set_title("frequency vs amplitude — NO clean trend from these 3 points\n(the two fast landings have nearly equal amplitude but differ by 4 Hz)", fontsize=10.5)
ax[1].legend(fontsize=8.5); ax[1].grid(alpha=.3); ax[1].set_xlim(0, max(A)*1.15); ax[1].set_ylim(20, 45)
fig.suptitle("Three landing speeds — all land 26–30 Hz, well below the bare Larmor 42.3 Hz.\nThe red-shift is robust and protocol-independent; an amplitude law is NOT established.",
             fontsize=12)
fig.tight_layout(rect=[0,0,1,0.93])
fig.savefig(f"{OUT}/cmp4_amplitude_vs_frequency.png", dpi=130)
print("wrote cmp4_amplitude_vs_frequency.png")
