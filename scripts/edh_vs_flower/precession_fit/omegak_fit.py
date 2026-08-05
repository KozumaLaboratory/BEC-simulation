import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SD = sys.argv[1]
d = json.load(open(f"{SD}/omegak_baseline.json"))
t_w = np.array(d["times"]); KMAX = d["kmax"]; box = d["box"]
TUNIT_MS = 1000/691.15
t = (t_w - t_w[0]) * TUNIT_MS / 1000.0        # seconds
AHO_UM = 0.780287
kphys = lambda s: s * 2*np.pi/box / AHO_UM     # 1/um

def series(lab, s):
    a = d[lab][s]
    return np.array(a["re"]) + 1j*np.array(a["im"])

def fit_freq(a, fgrid):
    """Fit  a(t) = P e^{+i2pi f t} + Q e^{-i2pi f t} + C  (linear in P,Q,C for fixed f).
    Scan f, pick least-squares minimum. Returns (f, |P|, |Q|, resid_norm, chi2 curve)."""
    N = len(a); best = None; chi = np.empty(len(fgrid))
    for i, f in enumerate(fgrid):
        M = np.column_stack([np.exp(2j*np.pi*f*t), np.exp(-2j*np.pi*f*t), np.ones(N)])
        coef, *_ = np.linalg.lstsq(M, a, rcond=None)
        r = a - M @ coef
        chi[i] = np.real(np.vdot(r, r))
        if best is None or chi[i] < best[0]:
            best = (chi[i], f, abs(coef[0]), abs(coef[1]), np.sqrt(chi[i]/N))
    return best[1], best[2], best[3], best[4], chi

def bootstrap_sigma(a, f0, nboot=120):
    """Residual bootstrap for the frequency uncertainty."""
    N = len(a)
    M = np.column_stack([np.exp(2j*np.pi*f0*t), np.exp(-2j*np.pi*f0*t), np.ones(N)])
    coef, *_ = np.linalg.lstsq(M, a, rcond=None)
    fit = M @ coef; res = a - fit
    fg = np.linspace(max(f0-15, 1), f0+15, 400)
    out = []
    rng = np.random.default_rng(0)
    for _ in range(nboot):
        ab = fit + res[rng.integers(0, N, N)]
        f, *_ = fit_freq(ab, fg)
        out.append(f)
    return float(np.std(out))

fgrid = np.linspace(2, 90, 900)
results = {}
print(f"record {t[-1]*1000:.0f} ms, N={len(t)}, FFT bin = {1/t[-1]:.1f} Hz")
print(f"{'shell':>5} {'k[1/um]':>8} | {'f_fit[Hz]':>10} {'sigma':>6} | {'|P|(+rot)':>10} {'|Q|(-rot)':>10} {'rot.frac':>8}")
for lab in ["amp_rad", "amp_par", "amp_perp"]:
    fs, sg, ks, rot = [], [], [], []
    print(f"--- {lab} ---")
    for s in range(KMAX):
        a = series(lab, s)
        if np.abs(a).mean() < 1e-6:
            fs.append(np.nan); sg.append(np.nan); ks.append(kphys(s+1)); rot.append(np.nan); continue
        f, P, Q, rn, _ = fit_freq(a, fgrid)
        sig = bootstrap_sigma(a, f)
        rf = (P - Q)/(P + Q) if (P+Q) > 0 else np.nan
        fs.append(f); sg.append(sig); ks.append(kphys(s+1)); rot.append(rf)
        print(f"{s+1:5d} {kphys(s+1):8.2f} | {f:10.1f} {sig:6.1f} | {P:10.3f} {Q:10.3f} {rf:+8.2f}")
    results[lab] = (np.array(ks), np.array(fs), np.array(sg), np.array(rot))

fig, ax = plt.subplots(1, 2, figsize=(14, 5.5))
cols = {"amp_rad": "#333333", "amp_par": "#185fa5", "amp_perp": "#d84330"}
labs = {"amp_rad": "all directions", "amp_par": "k ∥ M (z)", "amp_perp": "k ⊥ M (xy)"}
mks = {"amp_rad": "o", "amp_par": "^", "amp_perp": "s"}
for lab in results:
    ks, fs, sg, rot = results[lab]
    ax[0].errorbar(ks, fs, yerr=sg, fmt=mks[lab]+"-", color=cols[lab], ms=7, lw=1.4,
                   capsize=3, label=labs[lab])
    ax[1].plot(ks, rot, mks[lab]+"-", color=cols[lab], ms=7, lw=1.4, label=labs[lab])
ax[0].axhline(42.3, color="c", ls=":", lw=1.5, label="bare Larmor 42 Hz")
ax[0].axhline(26.3, color="green", ls=":", lw=1.5, label="scalar cb(t) fit 26 Hz")
ax[0].set_xlabel("wavevector |k|  [1/μm]"); ax[0].set_ylabel("fitted frequency [Hz]")
ax[0].set_title("ω(k) by least-squares sinusoid fit (not FFT bins)\nflat ⇒ no dispersion · rising ⇒ magnon", fontsize=11)
ax[0].legend(fontsize=8.5); ax[0].set_ylim(0, 70)
ax[1].axhline(0, color="k", lw=0.8)
ax[1].set_xlabel("wavevector |k|  [1/μm]"); ax[1].set_ylabel("rotation fraction  (|P|−|Q|)/(|P|+|Q|)")
ax[1].set_title("rotation vs linear oscillation per k\n±1 = pure precession · 0 = pure linear oscillation", fontsize=11)
ax[1].set_ylim(-1.05, 1.05); ax[1].legend(fontsize=8.5)
fig.suptitle("Per-k-shell sinusoid fitting — beats the 11.7 Hz FFT bin without new simulations", fontsize=12)
fig.tight_layout(rect=[0,0,1,0.93])
fig.savefig(f"{SD}/omegak_fit.png", dpi=130)
print("\nwrote omegak_fit.png")
