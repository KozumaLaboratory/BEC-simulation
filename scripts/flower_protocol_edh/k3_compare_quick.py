"""Quantitative K_3 comparison: extract N(t), E(t), Fz(t), Mz(t) from
K_3=0 and K_3=1e-40 Goto RTP h5 outputs, plot overlays, save CSV."""
import h5py
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

FILES = {
    "K3=0":      "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto.h5",
    "K3=1e-40":  "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto_k3_1.0e-40.h5",
}

omega_ref = 691.1504  # to convert internal time → ms

data = {}
for label, path in FILES.items():
    with h5py.File(path, "r") as f:
        t_int = f["t"][:]
        data[label] = {
            "t_ms": t_int / omega_ref * 1000.0,
            "N":    f["N"][:],
            "E":    f["E"][:],
            "Fz":   f["Fz"][:],
            "Mz":   f["Mz"][:],
            "B_uG": f["B_gauss"][:] * 1e6,
        }
        print(f"[{label}] frames={len(t_int)}  t_end={t_int[-1]/omega_ref*1000:.1f} ms  "
              f"N0={f['N'][0]:.6f} → N_end={f['N'][-1]:.6f}  ΔN/N0={(f['N'][-1]-f['N'][0])/f['N'][0]*100:.2f}%")

# Side-by-side plots
fig, axes = plt.subplots(2, 2, figsize=(13, 8))

# 1. N(t) — the key loss diagnostic
ax = axes[0, 0]
for label, d in data.items():
    ax.plot(d["t_ms"], d["N"] / d["N"][0], label=label, lw=1.8)
ax.set_xlabel("t (ms)"); ax.set_ylabel("N(t) / N(0)")
ax.set_title("Total atom number (normalised)")
ax.grid(alpha=0.3); ax.legend()

# 2. E(t)
ax = axes[0, 1]
for label, d in data.items():
    ax.plot(d["t_ms"], d["E"], label=label, lw=1.8)
ax.set_xlabel("t (ms)"); ax.set_ylabel("E (internal)")
ax.set_title("Total energy")
ax.grid(alpha=0.3); ax.legend()

# 3. Fz(t)
ax = axes[1, 0]
for label, d in data.items():
    ax.plot(d["t_ms"], d["Fz"], label=label, lw=1.8)
ax.set_xlabel("t (ms)"); ax.set_ylabel("⟨F_z⟩")
ax.set_title("Spin polarisation")
ax.grid(alpha=0.3); ax.legend()

# 4. relative N difference
ax = axes[1, 1]
N0 = data["K3=0"]["N"] / data["K3=0"]["N"][0]
N1 = data["K3=1e-40"]["N"] / data["K3=1e-40"]["N"][0]
# Interpolate K3=1e-40 onto K3=0 time grid if lengths differ
if len(N0) == len(N1):
    diff = (N1 - N0) * 100
    ax.plot(data["K3=0"]["t_ms"], diff, "C2", lw=1.8)
    ax.set_xlabel("t (ms)"); ax.set_ylabel("(N_K3 − N_0) / N(0)  [%]")
    ax.set_title("Excess loss from K_3 = 1e-40")
    ax.axhline(0, color="k", lw=0.5)
    ax.grid(alpha=0.3)
else:
    ax.text(0.5, 0.5, f"frame count differs: {len(N0)} vs {len(N1)}",
            ha="center", va="center", transform=ax.transAxes)

fig.tight_layout()
out_png = "/tmp/compare_k3_quant.png"
fig.savefig(out_png, dpi=130)
print(f"\nwrote {out_png}")

# CSV: t_ms, N_K3_0, N_K3_1e40, E_K3_0, E_K3_1e40, Fz_K3_0, Fz_K3_1e40
import csv
out_csv = "/tmp/compare_k3_quant.csv"
n_frames = min(len(data["K3=0"]["t_ms"]), len(data["K3=1e-40"]["t_ms"]))
with open(out_csv, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["t_ms", "N_K3_0", "N_K3_1e40", "E_K3_0", "E_K3_1e40",
                "Fz_K3_0", "Fz_K3_1e40", "B_uG"])
    for i in range(n_frames):
        w.writerow([data["K3=0"]["t_ms"][i],
                    data["K3=0"]["N"][i],     data["K3=1e-40"]["N"][i],
                    data["K3=0"]["E"][i],     data["K3=1e-40"]["E"][i],
                    data["K3=0"]["Fz"][i],    data["K3=1e-40"]["Fz"][i],
                    data["K3=0"]["B_uG"][i]])
print(f"wrote {out_csv}")
