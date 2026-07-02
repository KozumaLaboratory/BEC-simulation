#!/usr/bin/env python3
"""Issue #58 — dense K₃ / trap-shaping maps (4 directions). Renders the scans from
scripts/evaporation_k3_dense_maps.jl into one multi-panel figure."""
import csv
import os

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

HERE = os.path.dirname(os.path.abspath(__file__))
plt.rcParams.update({"font.size": 10, "axes.titlesize": 10.5, "figure.dpi": 130})


def grid(name):
    with open(os.path.join(HERE, name)) as f:
        rows = list(csv.reader(f))
    data = rows[1:]
    xs = sorted(set(float(r[0]) for r in data))
    ys = sorted(set(float(r[1]) for r in data))
    xi = {v: i for i, v in enumerate(xs)}
    yi = {v: i for i, v in enumerate(ys)}
    Z = np.full((len(xs), len(ys)), np.nan)
    for r in data:
        Z[xi[float(r[0])], yi[float(r[1])]] = float(r[2])
    return np.array(xs), np.array(ys), Z


def cols(name):
    with open(os.path.join(HERE, name)) as f:
        r = list(csv.DictReader(f))
    return {k: np.array([float(x[k]) for x in r]) for k in r[0]}


fig = plt.figure(figsize=(17, 15))
gs = fig.add_gridspec(3, 3, hspace=0.38, wspace=0.30)

# ============ DIRECTION 3 — condensation timing optimization ============
ax = fig.add_subplot(gs[0, 0])
sch = cols("d3_timing_schedule.csv")
conv = cols("d3_timing_convergence.csv")
w = 0.35
x = sch["breakpoint"]
ax.bar(x - w / 2, sch["H_base_W"] + sch["V_base_W"], w, label="baseline (H+V)", color="0.7")
ax.bar(x + w / 2, sch["H_opt_W"] + sch["V_opt_W"], w, label="timing-optimized", color="tab:red")
ax.set_xlabel("ramp breakpoint")
ax.set_ylabel("total FORT power [W]")
ax.set_title("(A) ★ condensation TIMING (~9×)\nkeep the trap TIGHTER longer, condense late")
ax.legend(fontsize=8)
axi = ax.inset_axes([0.5, 0.5, 0.45, 0.42])
axi.plot(conv["sweep"], conv["best_N0"], "o-", color="tab:red", ms=4)
axi.set_title("descent", fontsize=8)
axi.set_xlabel("sweep", fontsize=7)
axi.set_ylabel("N₀", fontsize=7)
axi.tick_params(labelsize=7)

# ============ DIRECTION 4 — 2-component N0_final lever combos ============
ax = fig.add_subplot(gs[0, 1])
ss, fs, Z = grid("d4_timing_decompress.csv")
pc = ax.pcolormesh(ss, fs, Z.T, cmap="viridis", shading="auto",
                   norm=LogNorm(vmin=max(np.nanmin(Z), 1), vmax=np.nanmax(Z)))
fig.colorbar(pc, ax=ax, label="N₀ final")
i, j = np.unravel_index(np.nanargmax(Z), Z.shape)
ax.plot(ss[i], fs[j], "r*", ms=16, label=f"best {Z[i,j]:.0f}")
ax.set_xlabel("timing strength  (0=baseline, 1=form-late)")
ax.set_ylabel("decompress factor  (1=no decompress)")
ax.set_title("(B) lever combo surface\n(a 1 s post-formation window)")
ax.legend(loc="lower left", fontsize=8)

ax = fig.add_subplot(gs[0, 2])
with open(os.path.join(HERE, "d4_k3_timing_decompress.csv")) as f:
    rows = list(csv.DictReader(f))
K3 = np.array([float(r["K3_m6_s"]) for r in rows])
sv = np.array([float(r["timing_strength"]) for r in rows])
fv = np.array([float(r["decompress_factor"]) for r in rows])
n0 = np.array([float(r["N0_final"]) for r in rows])
K3u = np.unique(K3)
# best N0 over (timing,decompress) at each K3, split by timing on/off
best_all = [n0[K3 == k].max() for k in K3u]
best_notime = [n0[(K3 == k) & (sv == sv.min())].max() for k in K3u]
ax.loglog(K3u, best_notime, "o-", label="baseline timing (best decompress)")
ax.loglog(K3u, best_all, "s-", color="tab:red", label="best timing + decompress")
ax.axvline(1.61e-40, color="k", ls=":", lw=1)
ax.text(1.61e-40, min(best_notime) * 1.3, " fit K₃", fontsize=8)
ax.set_xlabel("K₃ [m⁶/s]")
ax.set_ylabel("best N₀ final")
ax.set_title("(C) robustness of the combined lever\nacross the unknown Eu K₃")
ax.legend(fontsize=8)
ax.grid(True, which="both", alpha=0.3)

# ============ DIRECTION 1 — densified existing maps ============
ax = fig.add_subplot(gs[1, 0])
xs, ys, Z = grid("d1_clean_survival.csv")
pc = ax.pcolormesh(xs, ys, 100 * Z.T, cmap="magma", shading="auto", vmin=0, vmax=100)
cs = ax.contour(xs, ys, 100 * Z.T, levels=[10, 25, 50, 75, 90], colors="w", linewidths=0.7)
ax.clabel(cs, fmt="%d%%", fontsize=7)
fig.colorbar(pc, ax=ax, label="1 s survival [%]")
ax.set_xlabel("trap ν̄ [Hz]")
ax.set_ylabel("hold time [s]")
ax.set_title("(D) clean oracle (dense): loosen ⇒ K₃ loss↓")
ax.invert_xaxis()

ax = fig.add_subplot(gs[1, 1])
xs, ys, Z = grid("d1_k3_lifetime.csv")
pc = ax.pcolormesh(xs, ys, Z.T, cmap="RdYlGn", shading="auto",
                   norm=LogNorm(vmin=1e-3, vmax=np.nanmax(Z)))
cs = ax.contour(xs, ys, Z.T, levels=[1e-2, 0.1, 1.0, 10.0], colors="k", linewidths=0.6)
ax.clabel(cs, fmt=lambda v: f"{v:g}s", fontsize=7)
ax.set_yscale("log")
fig.colorbar(pc, ax=ax, label="condensate K₃ lifetime [s]")
ax.set_xlabel("trap ν̄ [Hz]")
ax.set_ylabel("condensate N₀")
ax.set_title("(E) K₃ lifetime 1/(K₃⟨n²⟩) (dense, N₀→1e7)")
ax.invert_xaxis()

ax = fig.add_subplot(gs[1, 2])
fs, taus, Z = grid("d1_decompress.csv")
nu = cols("d1_decompress_nu_axis.csv")
nu_of = dict(zip(nu["power_factor"], nu["final_nu_Hz"]))
nus = np.array([nu_of[f] for f in fs])
pc = ax.pcolormesh(nus, taus, Z.T, cmap="viridis", shading="auto",
                   norm=LogNorm(vmin=max(np.nanmin(Z), 1), vmax=np.nanmax(Z)))
fig.colorbar(pc, ax=ax, label="N₀ final")
i, j = np.unravel_index(np.nanargmax(Z), Z.shape)
ax.plot(nus[i], taus[j], "r*", ms=14, label=f"best {Z[i,j]:.0f}")
ax.set_xlabel("final trap ν̄ [Hz]")
ax.set_ylabel("decompression τ [s]")
ax.set_title("(F) decompress-after-BEC (dense)")
ax.legend(loc="upper right", fontsize=8)
ax.invert_xaxis()

# ============ DIRECTION 2 — new axes ============
ax = fig.add_subplot(gs[2, 0])
d = cols("d2_eta_start_1d.csv")
ax.plot(d["eta_start"], d["N0_baseline"], "o-", label="baseline ramp")
ax.plot(d["eta_start"], d["N0_timing"], "s-", color="tab:red", label="form-late (timing)")
ax.set_yscale("log")
ax.set_xlabel("η_start = U₀/(k_B T₀)")
ax.set_ylabel("N₀ final")
ax.set_title("(G) new axis: initial η dependence\n(euv3 is η-limited — barely condenses)")
ax.legend(fontsize=8)
ax.grid(True, which="both", alpha=0.3)

ax = fig.add_subplot(gs[2, 1])
xs, ys, Z = grid("d2_eta_k3.csv")
ea = cols("d2_eta_k3_axis.csv")
eta_of = dict(zip(ea["T0_uK"], ea["eta_start"]))
etas = np.array([eta_of[t] for t in xs])
pc = ax.pcolormesh(etas, ys, Z.T, cmap="viridis", shading="auto",
                   norm=LogNorm(vmin=max(np.nanmin(Z), 1), vmax=np.nanmax(Z)))
ax.set_yscale("log")
fig.colorbar(pc, ax=ax, label="N₀ final")
ax.axhline(1.61e-40, color="w", ls=":", lw=1)
ax.set_xlabel("η_start")
ax.set_ylabel("K₃ [m⁶/s]")
ax.set_title("(H) new axis: η_start × K₃\n(formation-limited vs K₃-limited regimes)")

ax = fig.add_subplot(gs[2, 2])
for tau, c in zip((0.2, 1.0, 3.0), ("tab:red", "tab:orange", "tab:green")):
    d = cols(f"d2_adiabatic_tau{tau}.csv")
    ax.plot(d["t_s"], d["T_K"] * 1e6, "-", color=c, label=f"model T, τ={tau}s")
    ax.plot(d["t_s"], d["T_ideal_K"] * 1e6, "--", color=c, lw=1, alpha=0.7)
ax.set_xlabel("time into decompression [s]")
ax.set_ylabel("T [µK]   (— model, -- ideal ∝ ω̄)")
ax.set_title("(I) new axis: adiabatic model fidelity\n(gap = spurious melting, muted 0-D gain)")
ax.legend(fontsize=7)
ax.grid(True, alpha=0.3)

fig.suptitle("Issue #58: dense K₃ / trap-shaping data — timing (A) + lever combos (B,C) + "
             "densified maps (D–F) + new axes (G–I)  [¹⁵¹Eu, 0-D 2-component]",
             fontsize=13, y=0.995)
out = os.path.join(HERE, "k3_dense_maps.png")
fig.savefig(out, bbox_inches="tight")
print("wrote", out)
