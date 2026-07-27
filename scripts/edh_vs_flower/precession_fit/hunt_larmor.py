import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SD = sys.argv[1]
TUNIT_MS = 1000/691.15
F_LARMOR = 42.3

# --- complex k-shell amplitudes: best SNR, signed frequency ---
d = json.load(open(f"{SD}/omegak_baseline.json"))
t_w = np.array(d["times"]); t = (t_w - t_w[0]) * TUNIT_MS/1000.0
def shell(lab, s):
    a = d[lab][s]; return np.array(a["re"]) + 1j*np.array(a["im"])

def design(f):
    return np.column_stack([np.exp(2j*np.pi*f*t), np.exp(-2j*np.pi*f*t), np.ones(len(t))])

def fit1(a, fgrid):
    best = None
    for f in fgrid:
        M = design(f); c,*_ = np.linalg.lstsq(M, a, rcond=None)
        r = a - M@c; chi = np.real(np.vdot(r,r))
        if best is None or chi < best[0]: best = (chi, f, c)
    return best

fg = np.linspace(2, 90, 900)
print("=== residual power at the bare Larmor frequency, after removing the 25.5 Hz mode ===")
print(f"{'shell':>5} {'f1[Hz]':>7} {'|A(f1)|':>9} {'|A(42.3)|':>10} {'ratio 42/f1':>12}")
rows = []
for s in range(8):
    a = shell("amp_rad", s)
    if np.abs(a).mean() < 1e-6: continue
    chi, f1, c1 = fit1(a, fg)
    A1 = abs(c1[0]) + abs(c1[1])
    # remove the mode, then project the residual onto exp(+/- i 2pi 42.3 t)
    r = a - design(f1) @ c1
    M2 = design(F_LARMOR); c2,*_ = np.linalg.lstsq(M2, r, rcond=None)
    A2 = abs(c2[0]) + abs(c2[1])
    rows.append((s+1, f1, A1, A2, A2/A1))
    print(f"{s+1:5d} {f1:7.1f} {A1:9.3f} {A2:10.4f} {A2/A1:12.3f}")

# --- noise floor: project the residual onto many frequencies to see if 42.3 stands out ---
s_best = max(rows, key=lambda r: r[2])[0] - 1
a = shell("amp_rad", s_best)
chi, f1, c1 = fit1(a, fg)
r = a - design(f1) @ c1
scan_f = np.linspace(5, 120, 400); amp = []
for f in scan_f:
    M = design(f); c,*_ = np.linalg.lstsq(M, r, rcond=None)
    amp.append(abs(c[0]) + abs(c[1]))
amp = np.array(amp)
i42 = np.argmin(abs(scan_f - F_LARMOR))
print(f"\nstrongest shell k={s_best+1}: mode f1={f1:.1f} Hz")
print(f"  residual amplitude at 42.3 Hz : {amp[i42]:.4f}")
print(f"  residual median (noise floor)  : {np.median(amp):.4f}")
print(f"  residual max over 5-120 Hz     : {amp.max():.4f} at {scan_f[np.argmax(amp)]:.1f} Hz")
print(f"  -> 42.3 Hz is {amp[i42]/np.median(amp):.2f}x the noise floor")

fig, ax = plt.subplots(1, 2, figsize=(13, 5))
ax[0].plot(scan_f, amp, "-", color="#333", lw=1.6)
ax[0].axvline(F_LARMOR, color="c", ls="--", lw=1.8, label="bare Larmor 42.3 Hz")
ax[0].axvline(f1, color="green", ls=":", lw=1.8, label=f"removed mode {f1:.1f} Hz")
ax[0].axhline(np.median(amp), color="#999", ls="-.", lw=1, label="noise floor (median)")
ax[0].set_xlabel("frequency [Hz]"); ax[0].set_ylabel("residual projected amplitude")
ax[0].set_title(f"Is there a bare-Larmor component?\n(residual of k-shell {s_best+1} after removing the mode)", fontsize=10)
ax[0].legend(fontsize=8.5)

ks = [r[0] for r in rows]
ax[1].semilogy(ks, [r[2] for r in rows], "o-", color="#d84330", label="mode amplitude (25.5 Hz)")
ax[1].semilogy(ks, [r[3] for r in rows], "s-", color="#185fa5", label="42.3 Hz amplitude")
ax[1].set_xlabel("k shell"); ax[1].set_ylabel("amplitude")
ax[1].set_title("mode vs bare-Larmor content, per k-shell", fontsize=10)
ax[1].legend(fontsize=8.5)
fig.suptitle("Hunting the bare Larmor line: if the transverse spin freely precessed at 42.3 Hz, it would show here", fontsize=11)
fig.tight_layout(rect=[0,0,1,0.93])
fig.savefig(f"{SD}/larmor_hunt.png", dpi=130)
print("\nwrote larmor_hunt.png")
