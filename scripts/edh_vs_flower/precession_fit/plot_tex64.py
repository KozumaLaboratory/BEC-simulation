import json, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SD = sys.argv[1]
d = json.load(open(f"{SD}/tex64_baseline.json"))
nx, nz = d["nx"], d["nz"]; box = d["box"]; AHO = 0.780287
t = np.array(d["times"]); Fz = np.array(d["Fz_t"])
kmid = np.array(d["kmid"]); Sperp = np.array(d["Sperp"])   # (nframes, nk)
peak = np.array(d["peakratio"]); nd = np.array(d["ndefect"])
TUNIT = 1000/691.15

fig = plt.figure(figsize=(16, 9))
# --- top: texture slices ---
sl = sorted([k for k in d["slices"] if k.startswith("fx_xz")], key=lambda s: int(s.split("_")[-1]))
ext = [-box/2*AHO, box/2*AHO, -box/2*AHO, box/2*AHO]
for j, key in enumerate(sl):
    fr = int(key.split("_")[-1])
    M = np.array(d["slices"][key]).reshape(nz, nx)
    v = np.percentile(np.abs(M), 99)
    ax = fig.add_subplot(2, len(sl), j+1)
    ax.imshow(M, origin="lower", extent=ext, cmap="RdBu_r", vmin=-v, vmax=v, aspect="equal")
    tf = d["slices"].get(f"t_{fr}", fr)
    ax.set_title(f"⟨Fx⟩(x,z)  t={tf*TUNIT:.0f} ms", fontsize=10)
    ax.set_xticks([]); ax.set_yticks([])
    if j == 0: ax.set_ylabel("z", fontsize=9)

# --- bottom-left: S_perp(k) spectrum, several times ---
ax = fig.add_subplot(2, 3, 4)
for i in range(0, len(t), 12):
    ax.semilogy(kmid, Sperp[i]/Sperp[i].max(), lw=1.3, label=f"{t[i]*TUNIT:.0f} ms")
ax.set_xlabel("|k|  [grid units]"); ax.set_ylabel("S⊥(k) (norm)")
ax.set_title("transverse-spin spatial spectrum S⊥(k)\n(single peak=mode / broad=turbulent)", fontsize=10)
ax.legend(fontsize=7); ax.set_ylim(1e-3, 2)

# --- bottom-mid: defects + peakratio ---
ax = fig.add_subplot(2, 3, 5)
ax.plot(t*TUNIT, nd, "o-", color="#d84330", ms=3, label="defect count (mid-z)")
ax.set_xlabel("t [ms]"); ax.set_ylabel("defect count", color="#d84330")
ax.tick_params(axis="y", labelcolor="#d84330")
ax2 = ax.twinx(); ax2.plot(t*TUNIT, peak, "s-", color="#185fa5", ms=3, label="S⊥ peak/mean")
ax2.set_ylabel("S⊥ peak/mean", color="#185fa5"); ax2.tick_params(axis="y", labelcolor="#185fa5")
ax.set_title("defect count & spectral peakedness vs time", fontsize=10)

# --- bottom-right: Fz(t) ---
ax = fig.add_subplot(2, 3, 6)
ax.plot(t*TUNIT, Fz, "o-", color="#1d9e75", ms=3)
ax.set_xlabel("t [ms]"); ax.set_ylabel("⟨Fz⟩"); ax.set_title("⟨Fz⟩(t) (hold)", fontsize=10)
ax.axhline(-6, color="k", ls=":", lw=0.7)

fig.suptitle("Baseline (c1=1/36 = real Eu) 64³ texture diagnostics — clean collective mode vs spin turbulence?", fontsize=13)
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(f"{SD}/tex64_baseline.png", dpi=120)
print("wrote tex64_baseline.png")
# summary stats
print(f"peakratio mean={peak.mean():.1f} (±{peak.std():.1f})  defect mean={nd.mean():.0f}")
# spectrum peak location
kpk = kmid[np.argmax(Sperp.mean(axis=0))]
print(f"S_perp peak at |k|≈{kpk:.1f}  (feature size ~{2*np.pi/(kpk/box*2*np.pi)*AHO if kpk>0 else 0:.1f} um)")
# fraction of spectral power beyond the peak (broadness)
mean_spec = Sperp.mean(axis=0); mean_spec/=mean_spec.sum()
cum = np.cumsum(mean_spec)
k50 = kmid[np.searchsorted(cum, 0.5)]; k90 = kmid[np.searchsorted(cum, 0.9)]
print(f"spectral median k50={k50:.1f}, k90={k90:.1f}  (broad spread => turbulent)")
