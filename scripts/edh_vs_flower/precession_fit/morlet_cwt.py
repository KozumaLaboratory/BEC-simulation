import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from scipy.interpolate import interp1d

SD = sys.argv[1]
WREF = 691.15; TUNIT_MS = 1000.0 / WREF
HBAR = 1.0546e-34; MUB = 9.274e-24; GAMMA = 1.163 * MUB / HBAR
f_larmor_Hz = lambda Bg: GAMMA * (Bg * 1e-4) / (2 * np.pi)

cb = json.load(open(f"{SD}/pure_cbmeta.json")); am = json.load(open(f"{SD}/angmom_meta.json"))
t_cb = np.array(cb["times"]); y_cb = np.array(cb["cb"])
t_am = np.array(am["times"]); Fz = np.array(am["Fz"]); Lz = np.array(am["Lz"])
ramp_t = np.array([0,5.625,11.25,16.875,22.5,28.125,33.75,39.375,45,50.625,56.25,61.875,67.5,73.125,78.75,84.375,90.0])
ramp_B = np.array([0.01,0.0087922,0.0076623,0.0066104,0.0056364,0.0047403,0.0039221,0.0031818,0.0025195,0.0019351,0.0014286,0.0010000,0.00064938,0.00037665,0.00018184,6.496e-05,2.6e-05])
B_of_t = lambda t: np.where(t <= 90.0, np.interp(t, ramp_t, ramp_B), 2.6e-5)

W0 = 6.0
FF = (4 * np.pi) / (W0 + np.sqrt(2 + W0**2))     # Fourier factor: period = FF * scale

def cwt_morlet(x, dt_s, freqs_hz):
    x = np.asarray(x, float); x = x - x.mean()
    n = len(x); X = np.fft.fft(x)
    omega = 2 * np.pi * np.fft.fftfreq(n, d=dt_s)
    scales = 1.0 / (FF * freqs_hz)
    W = np.empty((len(freqs_hz), n), complex)
    for i, s in enumerate(scales):
        norm = np.sqrt(2 * np.pi * s / dt_s)
        psi = (np.pi**-0.25) * norm * np.exp(-0.5 * (s * omega - W0)**2) * (omega > 0)
        W[i] = np.fft.ifft(X * np.conj(psi))
    return W, scales

def resample(t, y, dt=1.0):
    tu = np.arange(t.min(), t.max(), dt)
    return tu, interp1d(t, y, kind="linear")(tu)

freqs = np.linspace(2, 90, 45)                           # Hz, LINEAR (like Gabor)
dt_ms = 1.0 * TUNIT_MS                                    # 1 w^-1 grid
dt_s = dt_ms / 1000.0

def panel(ax, t, y, label):
    tu, yu = resample(t, y, dt=1.0)
    tms = tu * TUNIT_MS
    W, scales = cwt_morlet(yu, dt_s, freqs)
    P = np.abs(W)**2
    im = ax.pcolormesh(tms, freqs, P, shading="nearest", cmap="magma",
                       vmin=0, vmax=P.max())              # LINEAR color, no log
    ax.set_ylim(2, 90)                                    # LINEAR freq axis
    # cone of influence: boundary line only (no big white fill)
    edge = np.minimum(tms - tms[0], tms[-1] - tms) / 1000.0
    with np.errstate(divide="ignore"):
        f_coi = np.sqrt(2) / (FF * edge)
    ax.plot(tms, np.clip(f_coi, 2, 90), color="white", lw=1.1, ls="--", label="cone of influence")
    tov = np.linspace(tu.min(), tu.max(), 300)
    ax.plot(tov * TUNIT_MS, f_larmor_Hz(B_of_t(tov)), "c--", lw=1.5, label="bare Larmor")
    ax.axhline(26.3, color="lime", ls=":", lw=1.2, label="fit 38 ms (26 Hz)")
    ax.set_xlabel("t [ms]"); ax.set_ylabel("frequency [Hz]")
    ax.set_title(f"Morlet CWT scalogram: {label}", fontsize=10)
    ax.legend(fontsize=7.5, loc="upper right")
    return im

fig, ax = plt.subplots(2, 2, figsize=(15, 9))
im = panel(ax[0][0], t_cb, y_cb, "checkerboard cb(t) ∝ ⟨Fx⟩")
panel(ax[0][1], t_am, Fz, "⟨Fz⟩(t)")
panel(ax[1][0], t_am, Lz, "⟨Lz⟩(t)")
a = ax[1][1]; a.axis("off")
a.text(0.5, 0.55,
       "Continuous Wavelet Transform (Morlet, ω₀=6)\n— MULTI-RESOLUTION, unlike fixed-window Gabor —\n\n"
       "• high f → fine TIME resolution\n• low f → fine FREQUENCY resolution\n"
       "  (resolution adapts per scale)\n\n"
       "white dashed = cone of influence\n(below it near edges = unreliable)\n\n"
       "LINEAR frequency axis + LINEAR color\n(no log, no smoothing — like the Gabor)",
       ha="center", va="center", fontsize=10.5)
fig.colorbar(im, ax=ax.ravel().tolist(), fraction=0.02, pad=0.02, label="|W|² (linear)")
fig.suptitle("EdH signal — Morlet wavelet scalogram (multi-resolution, honest cone-of-influence)", fontsize=12)
fig.savefig(f"{SD}/morlet_cwt.png", dpi=125, bbox_inches="tight")
print("wrote morlet_cwt.png  | Fourier factor=%.3f  (period=%.3f*scale)" % (FF, FF))
# ridge frequency (max power) in the reliable hold region for each signal
for (t, y, lab) in [(t_cb, y_cb, "cb"), (t_am, Fz, "Fz"), (t_am, Lz, "Lz")]:
    tu, yu = resample(t, y); W, sc = cwt_morlet(yu, dt_s, freqs); P = np.abs(W)**2
    hold = (tu >= 100) & (tu <= 145)
    ridge = freqs[np.argmax(P[:, hold].mean(axis=1))]
    print(f"  {lab}: hold ridge freq = {ridge:.1f} Hz (period {1000/ridge:.1f} ms)")
