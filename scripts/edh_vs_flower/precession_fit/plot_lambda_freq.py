import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

SD = sys.argv[1]
d = json.load(open(f"{SD}/lambda_Fz.json"))
TUNIT_MS = 1000/691.15
LAM = {"prolate_0.5":0.5, "sphere_1.0":1.0, "baseline_1.182":1.182, "oblate2_2.0":2.0}
COL = {"prolate_0.5":"#185fa5","sphere_1.0":"#666666","baseline_1.182":"#d84330","oblate2_2.0":"#a3286f"}

def model(t, A, T, phi, C, k):
    return (A)*np.sin(2*np.pi*t/T+phi) + C + k*t

def fit_freq(t, Fz):
    t = np.array(t); Fz = np.array(Fz)
    hold = t >= 24.0                      # hold phase (quench+parabola done by ~24 w^-1)
    th = t[hold]; yh = Fz[hold]
    th = th - th[0]
    best = None
    for T0 in [20, 26, 32]:
        for phi0 in np.linspace(0,2*np.pi,6,endpoint=False):
            try:
                p,_ = curve_fit(model, th, yh, p0=[0.3, T0, phi0, np.mean(yh), 0], maxfev=20000)
                r = yh-model(th,*p); ss=np.sum(r**2); r2=1-ss/np.sum((yh-yh.mean())**2)
                if (best is None or r2>best[1]) and 8<abs(p[1])<60:
                    best=(abs(p[1]), r2, abs(p[0]))
            except Exception: pass
    return best   # (period_w, r2, amp)

fig, ax = plt.subplots(1, 2, figsize=(14, 5.5))
# left: the Fz(t) hold traces
res = {}
for name, Fz in d.items():
    t = np.array(d[name]["t"]); yy = np.array(Fz["Fz"])
    ax[0].plot(t*TUNIT_MS, yy, "-", color=COL[name], lw=1.6, label=f"λ={LAM[name]}")
    f = fit_freq(t, Fz["Fz"])
    if f: res[name]=f
ax[0].set_xlabel("t [ms]"); ax[0].set_ylabel("⟨Fz⟩"); ax[0].legend(fontsize=9)
ax[0].set_title("⟨Fz⟩(t) for each trap shape λ", fontsize=11); ax[0].axhline(-6,color="k",ls=":",lw=0.6)

# right: mode frequency vs lambda
lams=[]; freqs=[]; cols=[]
for name,(Tw, r2, amp) in res.items():
    Tms = Tw*TUNIT_MS; fHz = 1000/Tms
    lams.append(LAM[name]); freqs.append(fHz); cols.append(COL[name])
    ax[1].annotate(f"{fHz:.0f} Hz\n({Tms:.0f} ms)\nR²={r2:.2f}", (LAM[name], fHz),
                   fontsize=8, ha="center", va="bottom", color=COL[name])
order=np.argsort(lams); lams=np.array(lams)[order]; freqs=np.array(freqs)[order]
ax[1].plot(lams, freqs, "o-", color="#222", ms=11, lw=1.5, zorder=3,
           markerfacecolor="none", markeredgewidth=2)
for l,f,c in zip(lams,freqs,np.array(cols)[order]):
    ax[1].plot(l,f,"o",color=c,ms=10,zorder=4)
ax[1].axhline(42.3, color="c", ls=":", lw=1.5, label="bare Larmor (42 Hz)")
ax[1].axvline(1.0, color="#bbb", ls="--", lw=1, label="sphere (λ=1)")
ax[1].set_xlabel("trap aspect ratio  λ = ω_z/ω⊥", fontsize=11)
ax[1].set_ylabel("mode frequency [Hz]", fontsize=11)
ax[1].set_title("MODE FREQ vs λ — does it flip sign through λ=1?\n(prolate blue-shift ↑ / oblate red-shift ↓ = magnetostatic mode)", fontsize=11)
ax[1].legend(fontsize=9); ax[1].set_xlim(0.3, 2.2)
fig.suptitle("λ-sweep (real sims): collective-mode frequency vs trap shape — the magnetostatic-mode sign-flip test", fontsize=12)
fig.tight_layout(rect=[0,0,1,0.95])
fig.savefig(f"{SD}/lambda_freq.png", dpi=130)
print("wrote lambda_freq.png")
for name,(Tw,r2,amp) in sorted(res.items(), key=lambda x: LAM[x[0]]):
    print(f"  λ={LAM[name]:.3f} {name:16s}: T={Tw*TUNIT_MS:.1f} ms ({1000/(Tw*TUNIT_MS):.1f} Hz)  R²={r2:.2f}  amp={amp:.3f}")
