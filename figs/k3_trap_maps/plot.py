#!/usr/bin/env python3
"""Issue #58 — comprehensive K₃ / trap-shaping maps. Renders the dense scans from
scripts/evaporation_k3_trap_maps.jl into one persuasive multi-panel figure."""
import csv
import os

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

HERE = os.path.dirname(os.path.abspath(__file__))
plt.rcParams.update({"font.size": 10, "axes.titlesize": 11, "figure.dpi": 130})


def grid(name):
    """Pivot a long (x,y,value) CSV into (xs, ys, Z[i,j])."""
    with open(os.path.join(HERE, name)) as f:
        rows = list(csv.reader(f))
    head, data = rows[0], rows[1:]
    xs = sorted(set(float(r[0]) for r in data))
    ys = sorted(set(float(r[1]) for r in data))
    xi = {v: i for i, v in enumerate(xs)}
    yi = {v: i for i, v in enumerate(ys)}
    Z = np.full((len(xs), len(ys)), np.nan)
    for r in data:
        Z[xi[float(r[0])], yi[float(r[1])]] = float(r[2])
    return np.array(xs), np.array(ys), Z, head


def cols(name):
    with open(os.path.join(HERE, name)) as f:
        r = list(csv.DictReader(f))
    return {k: np.array([float(x[k]) for x in r]) for k in r[0]}


fig = plt.figure(figsize=(17, 10))
gs = fig.add_gridspec(2, 3, hspace=0.32, wspace=0.30)

# === M1: clean held-BEC survival surface (the headline) ===
ax = fig.add_subplot(gs[0, 0])
xs, ys, Z, _ = grid("m1_clean_survival.csv")
pc = ax.pcolormesh(xs, ys, 100 * Z.T, cmap="magma", shading="auto", vmin=0, vmax=100)
cs = ax.contour(xs, ys, 100 * Z.T, levels=[10, 25, 50, 75], colors="w", linewidths=0.8)
ax.clabel(cs, fmt="%d%%", fontsize=8)
fig.colorbar(pc, ax=ax, label="1 s survival [%]")
ax.set_xlabel("trap ν̄ [Hz]  →  looser is left")
ax.set_ylabel("hold time [s]")
ax.set_title("(A) ★ held BEC survives K₃ far better when LOOSE\n(clean oracle: density↓ = loosen = less K₃ loss)")
ax.invert_xaxis()

# === M2: decompress-after-BEC N0_final(final ν̄, decompression τ) ===
ax = fig.add_subplot(gs[0, 1])
fs, taus, Z2, _ = grid("m2_decompress.csv")
nu = cols("m2_nu_axis.csv")
nu_of = dict(zip(nu["power_factor"], nu["final_nu_Hz"]))
nus = np.array([nu_of[f] for f in fs])
pc = ax.pcolormesh(nus, taus, Z2.T, cmap="viridis", shading="auto",
                   norm=LogNorm(vmin=np.nanmin(Z2), vmax=np.nanmax(Z2)))
fig.colorbar(pc, ax=ax, label="N₀ final (condensate)")
i, j = np.unravel_index(np.nanargmax(Z2), Z2.shape)
ax.plot(nus[i], taus[j], "r*", ms=16, label=f"best {Z2[i,j]:.0f} @ {nus[i]:.0f} Hz")
ax.set_xlabel("final trap ν̄ [Hz]  →  looser is left")
ax.set_ylabel("decompression duration τ [s]")
ax.set_title("(B) decompress AFTER forming the BEC\n(form-late seed → lower n₀)")
ax.legend(loc="upper right", fontsize=8)
ax.invert_xaxis()

# === M3: condensate K₃ lifetime over (ν̄ × N₀) ===
ax = fig.add_subplot(gs[0, 2])
nus3, N0s, Z3, _ = grid("m3_k3_lifetime.csv")
pc = ax.pcolormesh(nus3, N0s, Z3.T, cmap="RdYlGn", shading="auto",
                   norm=LogNorm(vmin=1e-3, vmax=np.nanmax(Z3)))
cs = ax.contour(nus3, N0s, Z3.T, levels=[1e-2, 0.1, 1.0, 10.0], colors="k", linewidths=0.7)
ax.clabel(cs, fmt=lambda v: f"{v:g}s", fontsize=8)
ax.set_yscale("log")
fig.colorbar(pc, ax=ax, label="condensate K₃ lifetime [s]")
ax.set_xlabel("trap ν̄ [Hz]  →  looser is left")
ax.set_ylabel("condensate N₀")
ax.set_title("(C) K₃ lifetime of a BEC — loosen for a\nlonger-lived condensate (1/(K₃⟨n²⟩))")
ax.invert_xaxis()

# === M4: K₃ robustness of the three levers ===
ax = fig.add_subplot(gs[1, 0])
m4 = cols("m4_k3_robustness.csv")
ax.loglog(m4["K3_m6_s"], m4["N0_baseline"], "o-", label="baseline lab ramp")
ax.loglog(m4["K3_m6_s"], m4["N0_timing"], "s-", label="form-late (timing)")
ax.loglog(m4["K3_m6_s"], m4["N0_decompress"], "^-", label="form-late + decompress")
ax.axvline(1.61e-40, color="k", ls=":", lw=1)
ax.text(1.61e-40, ax.get_ylim()[0] * 1.5, " fit K₃", fontsize=8)
ax.set_xlabel("K₃ [m⁶/s]  (lanthanide range)")
ax.set_ylabel("N₀ final (condensate)")
ax.set_title("(D) robustness across the unknown Eu K₃")
ax.legend(fontsize=8)
ax.grid(True, which="both", alpha=0.3)

# === M5: adiabatic tracking T/T_c through decompression ===
ax = fig.add_subplot(gs[1, 1])
for tau, c in zip((0.2, 1.0, 3.0), ("tab:red", "tab:orange", "tab:green")):
    d = cols(f"m5_tracking_tau{tau}.csv")
    ax.plot(d["t_s"], d["T_over_Tc"], "-", color=c, label=f"τ = {tau} s")
ax.axhline(1.0, color="k", ls="--", lw=1)
ax.text(0.02, 1.01, "T/T_c = 1 (condensate melts above)", fontsize=8, transform=ax.get_yaxis_transform())
ax.set_xlabel("time into decompression [s]")
ax.set_ylabel("T / T_c")
ax.set_title("(E) why the 0-D hold gain is muted:\nfaster decompress → T/T_c rises → melting")
ax.legend(fontsize=8)
ax.grid(True, alpha=0.3)

# === takeaway panel ===
ax = fig.add_subplot(gs[1, 2])
ax.axis("off")
ax.text(0.0, 1.0,
        "Issue #58 — does loosening the FORT cut K₃ loss?\n"
        "──────────────────────────────────────\n\n"
        "YES — lower density = looser trap = less K₃ loss.\n"
        "  (A) a held BEC survives ~148× better at 20 Hz\n"
        "      than 200 Hz, K₃ rate ∝ ω̄^2.4.\n\n"
        "The catch is the ω̄–T_c coupling:\n"
        "  • loosen during evaporation → T_c↓ → never\n"
        "    condenses (C, low-η_start band).\n"
        "  • loosen too fast → condensate melts (E).\n\n"
        "Recipe: form the BEC first (timing), THEN\n"
        "decompress slowly to lock it in (B, D).\n\n"
        "0-D model, K₃ = 1.6e-40 m⁶/s (1-param fit).\n"
        "Absolute N soft; the trade-offs are robust.",
        fontsize=10, va="top", family="monospace")

fig.suptitle("Issue #58: FORT trap shaping vs K₃ three-body loss — dense parameter maps (¹⁵¹Eu, 0-D 2-component model)",
             fontsize=13, y=0.99)
out = os.path.join(HERE, "k3_trap_maps.png")
fig.savefig(out, bbox_inches="tight")
print("wrote", out)
