#!/usr/bin/env python3
"""Plot the EdH ramp-rate sweep: how EdH signatures depend on descent dB/dt.

Reads the per-ramp *_diag.jld2 (Mermin-Ho diagnostic, incl. orbital <Lz>) and
overlays the time series + a summary of peak signatures vs descent duration.
env: SWEEP (dir with *_diag.jld2), OUTDIR
"""
import os, glob, re
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SWEEP = os.environ.get("SWEEP", ".")
OUTDIR = os.environ.get("OUTDIR", SWEEP)
os.makedirs(OUTDIR, exist_ok=True)
OMEGA = 691.15                      # internal unit 1 = 1000/OMEGA ms = 1.447 ms

def load(path):
    d = {}
    with h5py.File(path, "r") as f:
        for k in ("t", "eps_wmean", "eps_absmax", "Lz_avg", "Fx_avg", "Fy_avg",
                  "Fz_avg", "N_tot", "Q_sk", "jmag_max"):
            if k in f:
                d[k] = np.asarray(f[k])
    d["t_ms"] = d["t"] * 1000.0 / OMEGA
    return d

def descent_T(tag):
    m = re.search(r"T([0-9p]+)", tag)
    return float(m.group(1).replace("p", ".")) if m else np.nan

files = sorted(glob.glob(os.path.join(SWEEP, "*_diag.jld2")))
runs = []
for p in files:
    tag = os.path.basename(p).replace("_diag.jld2", "")
    d = load(p); d["tag"] = tag; d["T"] = descent_T(tag)
    d["shape"] = "parabola" if "par" in tag else "linear"
    runs.append(d)
runs.sort(key=lambda r: (r["shape"], r["T"]))
print(f"[plot] {len(runs)} ramps: " + ", ".join(r["tag"] for r in runs))

cmap = plt.cm.viridis
def color(r):
    Ts = [x["T"] for x in runs if x["shape"] == "linear"]
    lo, hi = np.log10(min(Ts)), np.log10(max(Ts))
    if r["shape"] == "parabola":
        return "crimson"
    return cmap((np.log10(r["T"]) - lo) / (hi - lo + 1e-9))

def lab(r):
    T_ms = r["T"] * 1000.0 / OMEGA
    return f"{r['shape'][:3]} T={r['T']:g} ({T_ms:.0f} ms)"

# ---- time-series overlays + summary ----
fig = plt.figure(figsize=(15, 9))
gs = fig.add_gridspec(2, 3, hspace=0.3, wspace=0.28)

def ts_panel(ax, key, ylabel, title, absval=False):
    for r in runs:
        if key not in r: continue
        y = np.abs(r[key]) if absval else r[key]
        ax.plot(r["t_ms"], y, "-", color=color(r), lw=1.6,
                label=lab(r), ls="--" if r["shape"] == "parabola" else "-")
    ax.set_xlabel("t [ms]", fontsize=9); ax.set_ylabel(ylabel, fontsize=9)
    ax.set_title(title, fontsize=10); ax.grid(alpha=0.3)

ax = fig.add_subplot(gs[0, 0])
ts_panel(ax, "eps_wmean", r"$\langle|\epsilon_z|\rangle_n$",
         "Mermin-Ho residual (adiabaticity breakdown)")
ax.legend(fontsize=6.5, ncol=1)
ts_panel(fig.add_subplot(gs[0, 1]), "Lz_avg", r"$\langle L_z\rangle$",
         "orbital angular momentum (spin$\\to$orbital = EdH)")
axp = fig.add_subplot(gs[0, 2])
for r in runs:
    sp = np.hypot(r["Fx_avg"], r["Fy_avg"]) / np.clip(r["N_tot"], 1e-30, None)
    axp.plot(r["t_ms"], sp, color=color(r), lw=1.6, label=lab(r),
             ls="--" if r["shape"] == "parabola" else "-")
axp.set_xlabel("t [ms]", fontsize=9); axp.set_ylabel(r"$|\langle F_\perp\rangle|/N$", fontsize=9)
axp.set_title("transverse spin per atom", fontsize=10); axp.grid(alpha=0.3)
ts_panel(fig.add_subplot(gs[1, 0]), "Fz_avg", r"$\langle F_z\rangle$", "longitudinal spin")
ts_panel(fig.add_subplot(gs[1, 1]), "Q_sk", r"$Q_{sk}$", "skyrmion charge (z-midplane)")

# summary: peak EdH signatures vs descent duration
axs = fig.add_subplot(gs[1, 2])
lin = [r for r in runs if r["shape"] == "linear"]
par = [r for r in runs if r["shape"] == "parabola"]
Tms = [r["T"] * 1000 / OMEGA for r in lin]
eps_final = [r["eps_wmean"][-1] for r in lin]
lz_peak = [np.abs(r["Lz_avg"]).max() for r in lin]
axs.plot(Tms, eps_final, "o-", color="navy", label=r"final $\langle|\epsilon|\rangle_n$")
axs.set_xscale("log"); axs.set_xlabel("descent time [ms]", fontsize=9)
axs.set_ylabel(r"final Mermin-Ho residual", fontsize=9, color="navy")
axs.tick_params(axis="y", labelcolor="navy")
axs2 = axs.twinx()
axs2.plot(Tms, lz_peak, "s--", color="darkorange", label=r"peak $|\langle L_z\rangle|$")
axs2.set_ylabel(r"peak $|\langle L_z\rangle|$", fontsize=9, color="darkorange")
axs2.tick_params(axis="y", labelcolor="darkorange")
for r in par:
    axs.axhline(r["eps_wmean"][-1], color="crimson", ls=":", lw=1,
                label="parabola (final $\\epsilon$)")
axs.set_title("EdH strength vs descent rate\n(fast quench $\\to$ gentle)", fontsize=10)
axs.legend(fontsize=7, loc="upper right")

fig.suptitle("EdH magnetic-field ramp-rate sweep — quench vs gentle vs parabolic "
             "(descent + 40-internal observation, no long hold; 64³)", fontsize=13)
out = os.path.join(OUTDIR, "ramp_sweep_summary.png")
fig.savefig(out, dpi=140, bbox_inches="tight"); plt.close(fig)
print(f"[plot] wrote {out}")
# also dump a compact numeric table
print(f"{'ramp':16s} {'T_ms':>7s} {'eps_final':>10s} {'|Lz|peak':>9s} {'Fz_final':>9s}")
for r in runs:
    print(f"{r['tag']:16s} {r['T']*1000/OMEGA:7.1f} {r['eps_wmean'][-1]:10.4f} "
          f"{np.abs(r['Lz_avg']).max():9.4f} {r['Fz_avg'][-1]/r['N_tot'][-1]:9.3f}")
