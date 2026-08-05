import json
import numpy as np
from scipy.optimize import curve_fit

TIME_UNIT_MS = 1.4468639224480937

def load(path):
    with open(path) as f:
        return json.load(f)

pure_cb = load("pure_cbmeta.json")
q500_cb = load("q500_cbmeta.json")
pure_am = load("angmom_meta.json")
q500_am = load("angmom_meta_q500.json")

# hold-phase windows (post-ramp), in omega^-1 units
HOLD = {
    "pure": (90.0, 148.0),
    "q500": (24.0, 80.0),
}

def hold_mask(times, lo, hi):
    t = np.array(times)
    return (t >= lo) & (t <= hi), t

def sinusoid(t, A, T, phi, C, k):
    # damped/growing sinusoid: amplitude drifts linearly with slope k (honest about non-stationarity)
    return (A + k * (t - t[0])) * np.sin(2 * np.pi * t / T + phi) + C

def fft_period_guess(t, y, band_ms=(12, 60)):
    # uniform-sampling FFT peak restricted to a physically sane period band
    dt = np.median(np.diff(t))
    n = len(t)
    yz = y - np.mean(y)
    freq = np.fft.rfftfreq(n, d=dt)  # cycles per omega^-1
    amp = np.abs(np.fft.rfft(yz))
    with np.errstate(divide="ignore"):
        period_omega = 1.0 / freq
    period_ms = period_omega * TIME_UNIT_MS
    lo, hi = band_ms
    band = (period_ms >= lo) & (period_ms <= hi) & np.isfinite(period_ms)
    if not np.any(band):
        return None
    idx = np.where(band)[0][np.argmax(amp[band])]
    return period_omega[idx]

def fit_one(name, t, y):
    T0 = fft_period_guess(t, y)
    if T0 is None:
        T0 = 27.0
    A0 = (np.max(y) - np.min(y)) / 2
    C0 = np.mean(y)
    best = None
    for phi0 in np.linspace(0, 2 * np.pi, 8, endpoint=False):
        try:
            p0 = [A0, T0, phi0, C0, 0.0]
            popt, pcov = curve_fit(sinusoid, t, y, p0=p0, maxfev=20000)
            resid = y - sinusoid(t, *popt)
            ss_res = np.sum(resid**2)
            ss_tot = np.sum((y - np.mean(y)) ** 2)
            r2 = 1 - ss_res / ss_tot
            if best is None or r2 > best[-1]:
                perr = np.sqrt(np.diag(pcov)) if np.all(np.isfinite(pcov)) else np.full(5, np.nan)
                best = (popt, perr, r2)
        except Exception:
            continue
    if best is None:
        print(f"{name}: FIT FAILED, FFT-only guess T={T0*TIME_UNIT_MS:.2f} ms")
        return
    popt, perr, r2 = best
    A, T, phi, C, k = popt
    T_ms = T * TIME_UNIT_MS
    T_ms_err = perr[1] * TIME_UNIT_MS
    print(f"{name:16s}  T = {T_ms:6.2f} +/- {T_ms_err:5.2f} ms   "
          f"(FFT guess {T0*TIME_UNIT_MS:5.2f} ms)   R^2={r2:.3f}   "
          f"amplitude-drift k={k:+.4f}/omega^-1  n_pts={len(t)}")

print("=== pure parabola (hold t in [90,148] omega^-1, n=59 pts, dt=1) ===")
m, t = hold_mask(pure_cb["times"], *HOLD["pure"])
fit_one("cb(t)", t[m], np.array(pure_cb["cb"])[m])
m2, t2 = hold_mask(pure_am["times"], *HOLD["pure"])
fit_one("Fz(t)", t2[m2], np.array(pure_am["Fz"])[m2])
fit_one("Lz(t)", t2[m2], np.array(pure_am["Lz"])[m2])

print()
print("=== quench500+parabola (hold t in [24,80] omega^-1, n=57 pts, dt=1) ===")
m, t = hold_mask(q500_cb["times"], *HOLD["q500"])
fit_one("cb(t)", t[m], np.array(q500_cb["cb"])[m])
m2, t2 = hold_mask(q500_am["times"], *HOLD["q500"])
fit_one("Fz(t)", t2[m2], np.array(q500_am["Fz"])[m2])
fit_one("Lz(t)", t2[m2], np.array(q500_am["Lz"])[m2])

print()
print(f"reference: bare Larmor @26uG ~ 24 ms;  Matsui et al. m=-6 recovery peak = 22 ms")
