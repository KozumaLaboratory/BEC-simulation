import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from scipy.signal import ShortTimeFFT
from scipy.signal.windows import gaussian
from scipy.interpolate import interp1d

SD = sys.argv[1]
WREF = 691.15
TUNIT_MS = 1000.0 / WREF                       # 1 w^-1 = 1.4469 ms
HBAR = 1.0546e-34; MUB = 9.274e-24
GAMMA = 1.163 * MUB / HBAR
f_larmor_Hz = lambda Bg: GAMMA * (Bg * 1e-4) / (2 * np.pi)

cb = json.load(open(f"{SD}/pure_cbmeta.json")); am = json.load(open(f"{SD}/angmom_meta.json"))
t_cb = np.array(cb["times"]); y_cb = np.array(cb["cb"])
t_am = np.array(am["times"]); Fz = np.array(am["Fz"]); Lz = np.array(am["Lz"])

ramp_t = np.array([0,5.625,11.25,16.875,22.5,28.125,33.75,39.375,45,50.625,56.25,
                   61.875,67.5,73.125,78.75,84.375,90.0])
ramp_B = np.array([0.01,0.0087922,0.0076623,0.0066104,0.0056364,0.0047403,0.0039221,
                   0.0031818,0.0025195,0.0019351,0.0014286,0.0010000,0.00064938,
                   0.00037665,0.00018184,6.496e-05,2.6e-05])
B_of_t = lambda t: np.where(t <= 90.0, np.interp(t, ramp_t, ramp_B), 2.6e-5)

DT = 1.0                                         # resample to native hold spacing (1 w^-1), minimal
SIG_W = 12.0                                     # Gaussian window sigma in w^-1  (Δt)
# uncertainty (Gaussian, equality in Δt·Δf = 1/4π):
dt_ms = SIG_W * TUNIT_MS
df_Hz = 1.0 / (4 * np.pi * (SIG_W * TUNIT_MS / 1000.0))   # Hz
std_samp = SIG_W / DT
M = int(round(6 * std_samp)) | 1                 # window length ~6σ (odd)
win = gaussian(M, std=std_samp, sym=True)

def gabor(t, y):
    tu = np.arange(t.min(), t.max(), DT)
    yu = interp1d(t, y, kind="linear")(tu); yu = yu - yu.mean()
    fs = 1.0 / DT
    SFT = ShortTimeFFT(win, hop=2, fs=fs, scale_to="magnitude")
    Sx = np.abs(SFT.stft(yu))
    f_Hz = SFT.f / TUNIT_MS * 1000.0
    t_ms = (SFT.t(len(yu)) + tu[0]) * TUNIT_MS
    return t_ms, f_Hz, Sx

def panel(ax, t, y, label):
    tm, fH, S = gabor(t, y)
    # honest cells: pcolormesh flat (each quad = one Gabor bin, NO interpolation)
    dfb = fH[1] - fH[0]; dtb = tm[1] - tm[0]
    fe = np.concatenate([fH - dfb/2, [fH[-1] + dfb/2]])
    te = np.concatenate([tm - dtb/2, [tm[-1] + dtb/2]])
    ax.pcolormesh(te, fe, S, shading="flat", cmap="magma", edgecolors="none")
    tov = np.linspace(tm.min()/TUNIT_MS, tm.max()/TUNIT_MS, 300)
    ax.plot(tov * TUNIT_MS, f_larmor_Hz(B_of_t(tov)), "c--", lw=1.5, label="bare Larmor f_L(B(t))")
    ax.axhline(1000/38.0, color="w", ls=":", lw=1.1, label="fit 38 ms (26 Hz)")
    # explicit uncertainty resolution cell (Δt × Δf) drawn to scale, bottom-left
    x0, y0 = tm.min() + 0.06*(tm.max()-tm.min()), 70
    ax.add_patch(Rectangle((x0, y0), dt_ms, df_Hz, fill=False, ec="lime", lw=1.6))
    ax.text(x0 + dt_ms*1.1, y0 + df_Hz/2, f"Gabor cell\nΔt={dt_ms:.0f} ms × Δf={df_Hz:.1f} Hz\n(Δt·Δf=1/4π)",
            color="lime", fontsize=7.5, va="center")
    ax.set_ylim(0, 90); ax.set_xlabel("t [ms]"); ax.set_ylabel("f [Hz]")
    ax.set_title(f"Gabor (Gaussian window, honest cells): {label}", fontsize=10)
    ax.legend(fontsize=7.5, loc="upper right")

fig, ax = plt.subplots(2, 2, figsize=(15, 9))
panel(ax[0][0], t_cb, y_cb, "checkerboard cb(t) ∝ ⟨Fx⟩")
panel(ax[0][1], t_am, Fz, "⟨Fz⟩(t)")
panel(ax[1][0], t_am, Lz, "⟨Lz⟩(t)")
a = ax[1][1]
a.text(0.5, 0.5,
       f"Gabor time–frequency uncertainty\n\nGaussian window σ_t = {dt_ms:.0f} ms\n→ Δf = 1/(4π σ_t) = {df_Hz:.1f} Hz\n\n"
       f"signal is only ~{150*TUNIT_MS:.0f} ms long (~{150*TUNIT_MS/38:.1f} magnon periods)\n"
       f"→ frequency is fundamentally coarse.\n"
       f"cells shown are the TRUE resolution elements\n(no interpolation / smoothing).",
       ha="center", va="center", fontsize=11); a.axis("off")
fig.suptitle("EdH signal Gabor — honest uncertainty-limited grid (no gouraud smoothing)", fontsize=12)
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(f"{SD}/magnon_gabor.png", dpi=125)
print("wrote magnon_gabor.png  | Gabor cell Δt=%.0f ms  Δf=%.1f Hz  (M=%d samp)" % (dt_ms, df_Hz, M))
