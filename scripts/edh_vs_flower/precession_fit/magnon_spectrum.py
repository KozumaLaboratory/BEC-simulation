import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.signal import stft
from scipy.interpolate import interp1d

SD = sys.argv[1]
WREF = 691.15                       # rad/s
TUNIT_MS = 1000.0 / WREF            # 1 w^-1 in ms = 1.4469
HBAR = 1.0546e-34; MUB = 9.274e-24
GAMMA = 1.163 * MUB / HBAR          # gF muB / hbar  [rad/s/T]  (Eu)
def f_larmor_Hz(B_gauss):           # bare Larmor freq [Hz] at field B [Gauss]
    return GAMMA * (B_gauss * 1e-4) / (2 * np.pi)

cb = json.load(open(f"{SD}/pure_cbmeta.json"))
am = json.load(open(f"{SD}/angmom_meta.json"))
t_cb = np.array(cb["times"]); y_cb = np.array(cb["cb"])
t_am = np.array(am["times"]); Fz = np.array(am["Fz"]); Lz = np.array(am["Lz"])

# pure ramp B(t): parabola nodes (config) then hold at 26 uG (= 2.6e-5 Gauss)
ramp_t = np.array([0,5.625,11.25,16.875,22.5,28.125,33.75,39.375,45,50.625,56.25,
                   61.875,67.5,73.125,78.75,84.375,90.0])
ramp_B = np.array([0.01,0.0087922,0.0076623,0.0066104,0.0056364,0.0047403,0.0039221,
                   0.0031818,0.0025195,0.0019351,0.0014286,0.0010000,0.00064938,
                   0.00037665,0.00018184,6.496e-05,2.6e-05])   # Gauss
def B_of_t(t):
    return np.where(t <= 90.0, np.interp(t, ramp_t, ramp_B), 2.6e-5)

def resample(t, y, dt=0.5):
    tu = np.arange(t.min(), t.max(), dt)
    yu = interp1d(t, y, kind="cubic", fill_value="extrapolate")(tu)
    return tu, yu

def spectro(ax, t, y, label):
    tu, yu = resample(t, y)
    fs = 1.0 / (tu[1] - tu[0])                      # samples per w^-1
    yu = yu - yu.mean()
    f, tt, Z = stft(yu, fs=fs, nperseg=min(48, len(yu)//2), noverlap=None)
    P = np.abs(Z)
    f_Hz = f / TUNIT_MS * 1000.0                     # cycles per w^-1 -> Hz
    tt_ms = (tt + tu[0]) * TUNIT_MS
    im = ax.pcolormesh(tt_ms, f_Hz, P, shading="gouraud", cmap="magma")
    # overlay bare Larmor f_L(B(t))
    tov = np.linspace(tu.min(), tu.max(), 300)
    ax.plot(tov * TUNIT_MS, f_larmor_Hz(B_of_t(tov)), "c--", lw=1.6, label="bare Larmor f_L(B(t))")
    ax.axhline(1000/38.0, color="w", ls=":", lw=1.2, label="observed 38 ms (26 Hz)")
    ax.set_ylim(0, 90); ax.set_ylabel("frequency [Hz]"); ax.set_title(f"Gabor/STFT: {label}")
    ax.legend(fontsize=8, loc="upper right"); ax.set_xlabel("t [ms]")
    return im

def fft_hold(t, y, t0=90.0):
    m = t >= t0
    tu, yu = resample(t[m], y[m], dt=0.5)
    yu = (yu - yu.mean()) * np.hanning(len(yu))
    F = np.abs(np.fft.rfft(yu))
    fr = np.fft.rfftfreq(len(yu), d=0.5) / TUNIT_MS * 1000.0
    return fr, F

fig, axes = plt.subplots(2, 2, figsize=(15, 9))
spectro(axes[0][0], t_cb, y_cb, "checkerboard cb(t) ∝ ⟨Fx⟩")
spectro(axes[0][1], t_am, Fz, "⟨Fz⟩(t)  (m=−6 population)")
spectro(axes[1][0], t_am, Lz, "⟨Lz⟩(t)  (orbital)")

ax = axes[1][1]
for (t, y, lab, c) in [(t_cb, y_cb, "cb", "#d84330"), (t_am, Fz, "Fz", "#185fa5"), (t_am, Lz, "Lz", "#1d9e75")]:
    fr, F = fft_hold(t, y); F = F / F.max()
    ax.plot(fr, F, label=lab, color=c, lw=1.8)
ax.axvline(1000/38.0, color="k", ls=":", label="38 ms (26 Hz)")
ax.axvline(f_larmor_Hz(2.6e-5), color="c", ls="--", label=f"bare Larmor ({f_larmor_Hz(2.6e-5):.0f} Hz)")
ax.set_xlim(0, 90); ax.set_xlabel("frequency [Hz]"); ax.set_ylabel("power (norm)")
ax.set_title("hold-phase FFT — cb, Fz, Lz share one peak (the magnon)"); ax.legend(fontsize=9)

fig.suptitle("Magnon spectroscopy of the EdH signal — observed peak (~26 Hz) sits BELOW bare Larmor (~42 Hz): the DDI/interaction shift", fontsize=12)
fig.tight_layout(rect=[0, 0, 1, 0.96])
fig.savefig(f"{SD}/magnon_spectrum.png", dpi=125)
print("wrote magnon_spectrum.png")
for (t, y, lab) in [(t_cb, y_cb, "cb"), (t_am, Fz, "Fz"), (t_am, Lz, "Lz")]:
    fr, F = fft_hold(t, y); pk = fr[1:][np.argmax(F[1:])]
    print(f"  {lab}: hold FFT peak = {pk:.1f} Hz  (period {1000/pk:.1f} ms)")
print(f"  bare Larmor @26uG = {f_larmor_Hz(2.6e-5):.1f} Hz (period {1000/f_larmor_Hz(2.6e-5):.1f} ms)")
