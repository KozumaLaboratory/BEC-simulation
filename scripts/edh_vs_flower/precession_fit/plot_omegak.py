import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SD = sys.argv[1]
d = json.load(open(f"{SD}/omegak_baseline.json"))
t = np.array(d["times"]); KMAX = d["kmax"]; box = d["box"]
TUNIT_MS = 1000/691.15
dt_w = np.median(np.diff(t))            # sampling in omega_ref^-1
dt_ms = dt_w * TUNIT_MS

def series(lab, s):
    a = d[lab][s]
    return np.array(a["re"]) + 1j*np.array(a["im"])

def tfft(x):
    """time-FFT of a complex shell amplitude; return (freq_Hz, power) for positive freqs."""
    x = x - x.mean()
    w = np.hanning(len(x))
    X = np.fft.fftshift(np.fft.fft(x*w))
    f = np.fft.fftshift(np.fft.fftfreq(len(x), d=dt_ms/1000.0))   # Hz (signed: complex signal)
    return f, np.abs(X)

# physical k: shell index s corresponds to |k| = s * 2pi/box  (in 1/a_ho); convert to 1/um
AHO_UM = 0.780287
kphys = lambda s: s * 2*np.pi/box / AHO_UM     # 1/um

fig, ax = plt.subplots(1, 3, figsize=(16, 5.2))

# --- panel 1: spectra of each shell (radial) ---
peaks = {"rad": [], "par": [], "perp": []}
for s in range(KMAX):
    f, P = tfft(series("amp_rad", s))
    m = f > 0
    if P[m].size:
        pk = f[m][np.argmax(P[m])]
        peaks["rad"].append(pk)
    ax[0].plot(f, P/max(P.max(),1e-30) + s*0.6, lw=1.2, label=f"k={s+1}")
ax[0].set_xlim(-80, 80); ax[0].set_xlabel("frequency [Hz]  (signed: complex field)")
ax[0].set_ylabel("power (offset per k-shell)")
ax[0].set_title("time-FFT of each k-shell\n(radial |k| shells, stacked)", fontsize=10)
ax[0].legend(fontsize=7, ncol=2)

# --- panel 2: dispersion omega(k) ---
for lab, col, mk in [("amp_rad","#333","o"), ("amp_par","#185fa5","^"), ("amp_perp","#d84330","s")]:
    fs = []
    for s in range(KMAX):
        f, P = tfft(series(lab, s))
        m = f > 0
        fs.append(f[m][np.argmax(P[m])] if P[m].size else np.nan)
    ks = [kphys(s+1) for s in range(KMAX)]
    ax[1].plot(ks, fs, mk+"-", color=col, ms=7, lw=1.4,
               label={"amp_rad":"all directions","amp_par":"k ∥ M (z)","amp_perp":"k ⊥ M (xy)"}[lab])
ax[1].axhline(42.3, color="c", ls=":", lw=1.5, label="bare Larmor 42 Hz")
ax[1].axhline(26.3, color="green", ls=":", lw=1.5, label="scalar mode 26 Hz")
ax[1].set_xlabel("wavevector |k|  [1/μm]"); ax[1].set_ylabel("peak frequency [Hz]")
ax[1].set_title("DISPERSION ω(k)\nflat ⇒ uniform oscillation · rising ⇒ magnon", fontsize=10)
ax[1].legend(fontsize=8)

# --- panel 3: full 2D map (k vs freq) ---
M = []
for s in range(KMAX):
    f, P = tfft(series("amp_rad", s))
    M.append(P/max(P.max(),1e-30))
M = np.array(M)
f_axis = tfft(series("amp_rad",0))[0]
ks = [kphys(s+1) for s in range(KMAX)]
im = ax[2].pcolormesh(f_axis, ks, M, shading="nearest", cmap="magma")
ax[2].axvline(42.3, color="c", ls=":", lw=1.3); ax[2].axvline(26.3, color="lime", ls=":", lw=1.3)
ax[2].set_xlim(-80, 80); ax[2].set_xlabel("frequency [Hz]"); ax[2].set_ylabel("|k| [1/μm]")
ax[2].set_title("spectral map: power(k, ω)", fontsize=10)
plt.colorbar(im, ax=ax[2], fraction=0.046)

fig.suptitle(f"Magnon dispersion test — transverse spin field, 64³ baseline hold "
             f"(Δf ≈ ±{1000/(len(t)*dt_ms):.1f} Hz from {len(t)*dt_ms:.0f} ms record)", fontsize=12)
fig.tight_layout(rect=[0,0,1,0.94])
fig.savefig(f"{SD}/omegak_dispersion.png", dpi=130)
print("wrote omegak_dispersion.png")
print(f"record length {len(t)*dt_ms:.0f} ms, dt={dt_ms:.2f} ms, Δf≈{1000/(len(t)*dt_ms):.1f} Hz")
for lab in ["amp_rad","amp_par","amp_perp"]:
    fs=[]
    for s in range(KMAX):
        f,P = tfft(series(lab,s)); m=f>0
        fs.append(round(float(f[m][np.argmax(P[m])]),1) if P[m].size else None)
    print(f"  {lab:9s} peak freq per shell (k=1..{KMAX}): {fs}")
