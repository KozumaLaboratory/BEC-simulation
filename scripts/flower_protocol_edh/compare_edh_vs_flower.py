"""Side-by-side EdH vs Flower comparison from the two h5 outputs of Issue #32.

Reads mass_current group from both files, overlays:
- N(t), ⟨F_z⟩(t), peak |j|, skyrmion charge, ∫ω_z dA
- end-state |j|, vorticity, Berry curvature (Mermin-Ho RHS) maps
- Mermin-Ho diagnostic: |curl_v_z + (ℏF/m)·berry_z| residual

Usage: python3 compare_edh_vs_flower.py <flower_h5> <quench_h5> <output_dir>
"""
import sys, os
import h5py
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

if len(sys.argv) < 4:
    sys.exit("usage: compare_edh_vs_flower.py <flower_h5> <quench_h5> <output_dir>")

FILES = {"Flower (smooth)": sys.argv[1], "EdH (quench)": sys.argv[2]}
OUT = sys.argv[3]
os.makedirs(OUT, exist_ok=True)

_rev = (3, 2, 1, 0)


def load(path):
    f = h5py.File(path, "r")
    mc = f["mass_current"]
    return dict(
        t_psi  = f["t_psi"][:],
        B_psi  = f["B_gauss_psi"][:],
        N      = f["N"][:],
        Fz     = f["Fz"][:],
        t_full = f["t"][:],
        omega_ref = float(f["meta/omega_ref"][()]),
        jx = mc["jx"][:].transpose(_rev),
        jy = mc["jy"][:].transpose(_rev),
        vx = mc["vx"][:].transpose(_rev),
        vy = mc["vy"][:].transpose(_rev),
        curl_v_z = mc["curl_v_z"][:].transpose(_rev),
        berry_z  = mc["berry_z"][:].transpose(_rev) if "berry_z" in mc else None,
        n_max     = mc["n_max"][:],
        j_mag_max = mc["j_mag_max"][:],
        circ      = mc["circulation_midz"][:],
        Qsk       = mc["skyrmion_charge_midz"][:] if "skyrmion_charge_midz" in mc else None,
        dx_sub    = float(mc["dx_sub"][()]),
        h5        = f,
    )


data = {label: load(path) for label, path in FILES.items()}
NVOL = data["Flower (smooth)"]["jx"].shape[1]
midz = NVOL // 2
xs = (np.arange(NVOL) - NVOL / 2) * data["Flower (smooth)"]["dx_sub"]

# ============================================================================
# 1. Time-series overlay
# ============================================================================
fig, axes = plt.subplots(2, 3, figsize=(16, 8))
for label, d in data.items():
    t_ms_full = d["t_full"] / d["omega_ref"] * 1000
    t_ms_psi  = d["t_psi"]  / d["omega_ref"] * 1000

    axes[0, 0].plot(t_ms_full, d["N"], lw=1.8, label=label)
    axes[0, 1].plot(t_ms_full, d["Fz"], lw=1.8, label=label)
    axes[0, 2].plot(t_ms_psi, d["j_mag_max"], lw=1.8, marker="o", ms=3, label=label)
    axes[1, 0].plot(t_ms_psi, d["circ"], lw=1.8, marker="o", ms=3, label=label)
    if d["Qsk"] is not None:
        axes[1, 1].plot(t_ms_psi, d["Qsk"], lw=1.8, marker="o", ms=3, label=label)
    axes[1, 2].plot(t_ms_psi, d["n_max"], lw=1.8, marker="o", ms=3, label=label)

axes[0, 0].set_title("N(t)");            axes[0, 0].set_ylabel("N/N₀")
axes[0, 1].set_title("⟨F_z⟩(t)");        axes[0, 1].set_ylabel("⟨F_z⟩")
axes[0, 2].set_title("max |j|(t)");      axes[0, 2].set_ylabel("|j|_max")
axes[1, 0].set_title("∫ω_z dA  midplane"); axes[1, 0].set_ylabel("circulation")
axes[1, 1].set_title("Skyrmion charge Q_sk(t)"); axes[1, 1].set_ylabel("Q_sk")
axes[1, 2].set_title("Peak density n_max(t)"); axes[1, 2].set_ylabel("n_max")
for ax in axes.flat:
    ax.set_xlabel("t (ms)"); ax.grid(alpha=0.3); ax.legend()
fig.suptitle("EdH (quench) vs Flower (smooth) — time series  (K_3 = 1e-40, B_final = 63 µG)")
fig.tight_layout()
fig.savefig(f"{OUT}/timeseries_compare.png", dpi=130)
plt.close(fig)
print("[cmp] wrote timeseries_compare.png")

# ============================================================================
# 2. End-state spatial maps: 2 rows (variants) × 4 cols (|j|, ω_z, berry_z, residual)
# ============================================================================
fig, axes = plt.subplots(2, 4, figsize=(20, 9))
for row, (label, d) in enumerate(data.items()):
    k = d["jx"].shape[0] - 1   # end frame
    jx_e = d["jx"][k, :, :, midz]; jy_e = d["jy"][k, :, :, midz]
    jm = np.hypot(jx_e, jy_e)
    vort = d["curl_v_z"][k, :, :, midz]
    berry = d["berry_z"][k, :, :, midz] if d["berry_z"] is not None else None
    # Mermin-Ho residual: in dimensionless internal units, RHS = ℏ F / m · Ω_z = F · Ω_z (since ℏ=m=1)
    if berry is not None:
        residual = vort + 6.0 * berry  # F=6
    else:
        residual = None

    ax = axes[row, 0]
    im = ax.imshow(jm.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
                   cmap="inferno")
    ax.set_title(f"{label}: |j_⊥|"); plt.colorbar(im, ax=ax)

    ax = axes[row, 1]
    vmax = np.percentile(np.abs(vort), 99) + 1e-15
    im = ax.imshow(vort.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
                   cmap="RdBu_r", vmin=-vmax, vmax=vmax)
    ax.set_title(f"{label}: (∇×v)_z (Mermin-Ho LHS)"); plt.colorbar(im, ax=ax)

    ax = axes[row, 2]
    if berry is not None:
        vmax_b = np.percentile(np.abs(berry), 99) + 1e-15
        im = ax.imshow(berry.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
                       cmap="RdBu_r", vmin=-vmax_b, vmax=vmax_b)
        ax.set_title(f"{label}: Ω_z (Mermin-Ho RHS / F)")
        plt.colorbar(im, ax=ax)
    else:
        ax.axis("off")
        ax.text(0.5, 0.5, "Berry curvature not saved\n(old h5)",
                ha="center", va="center", transform=ax.transAxes)

    ax = axes[row, 3]
    if residual is not None:
        vmax_r = np.percentile(np.abs(residual), 99) + 1e-15
        im = ax.imshow(residual.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
                       cmap="RdBu_r", vmin=-vmax_r, vmax=vmax_r)
        ax.set_title(f"{label}: ω_z + F·Ω_z  (Flower⇒0, EdH⇒≠0 at cores)")
        plt.colorbar(im, ax=ax)
    else:
        ax.axis("off")

fig.suptitle("End-state spatial maps — z-midplane",
             y=1.01)
fig.tight_layout()
fig.savefig(f"{OUT}/endstate_maps_compare.png", dpi=130, bbox_inches="tight")
plt.close(fig)
print("[cmp] wrote endstate_maps_compare.png")

# ============================================================================
# 3. Streamline comparison (final-time)
# ============================================================================
fig, axes = plt.subplots(1, 2, figsize=(13, 6))
for ax, (label, d) in zip(axes, data.items()):
    k = d["jx"].shape[0] - 1
    vx_e = d["vx"][k, :, :, midz]
    vy_e = d["vy"][k, :, :, midz]
    v_mag = np.hypot(vx_e, vy_e) + 1e-15
    ax.streamplot(xs, xs, vx_e.T, vy_e.T, color=v_mag.T, cmap="plasma", density=1.6,
                  linewidth=1.0)
    ax.set_xlim(xs[0], xs[-1]); ax.set_ylim(xs[0], xs[-1])
    ax.set_aspect("equal")
    ax.set_title(f"{label} — streamlines of v_⊥")
    ax.set_xlabel("x"); ax.set_ylabel("y")
fig.tight_layout()
fig.savefig(f"{OUT}/streamlines_compare.png", dpi=130)
plt.close(fig)
print("[cmp] wrote streamlines_compare.png")


# ============================================================================
# Numerical summary
# ============================================================================
print("\n=== EdH vs Flower numerical summary ===")
for label, d in data.items():
    k = d["jx"].shape[0] - 1
    n_end = d["N"][-1]
    fz_end = d["Fz"][-1]
    j_end = d["j_mag_max"][k]
    circ_end = d["circ"][k]
    qsk_end = d["Qsk"][k] if d["Qsk"] is not None else None
    print(f"  {label}:")
    print(f"    N_end          = {n_end:.4f}  (Δ = {(n_end-1)*100:+.2f}%)")
    print(f"    ⟨F_z⟩_end      = {fz_end:.4f}")
    print(f"    |j|_max end    = {j_end:.4e}")
    print(f"    ∫ω_z dA end   = {circ_end:.4e}")
    if qsk_end is not None:
        print(f"    Q_skyrmion end = {qsk_end:.4f}")

for d in data.values():
    d["h5"].close()
print("\n[cmp] done")
