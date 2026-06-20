"""Plot mass current + vorticity + Mermin-Ho diagnostics from
mass_current_analysis.jl output. Issue #32.

Usage:  python3 plot_mass_current.py <h5_path> <output_dir>
"""
import sys
import os
import h5py
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm

if len(sys.argv) < 3:
    sys.exit("usage: plot_mass_current.py <h5_path> <output_dir>")

H5_PATH = sys.argv[1]
OUT_DIR = sys.argv[2]
os.makedirs(OUT_DIR, exist_ok=True)

print(f"[plot] reading {H5_PATH}")
with h5py.File(H5_PATH, "r") as f:
    if "mass_current" not in f:
        sys.exit("h5 has no mass_current/ group — run mass_current_analysis.jl first")
    mc = f["mass_current"]
    # HDF5.jl writes Julia column-major arrays; h5py reads them with axis
    # order reversed. Julia: (Nf, NVOL, NVOL, NVOL) → Python: (NVOL, NVOL,
    # NVOL, Nf). Transpose to canonical (Nf, NVOL, NVOL, NVOL).
    _rev = (3, 2, 1, 0)
    jx = mc["jx"][:].transpose(_rev)
    jy = mc["jy"][:].transpose(_rev)
    jz = mc["jz"][:].transpose(_rev)
    vx = mc["vx"][:].transpose(_rev)
    vy = mc["vy"][:].transpose(_rev)
    curl_v_z = mc["curl_v_z"][:].transpose(_rev)
    n_max     = mc["n_max"][:]
    j_mag_max = mc["j_mag_max"][:]
    circ      = mc["circulation_midz"][:]
    dx_sub    = float(mc["dx_sub"][()])
    t_psi  = f["t_psi"][:]
    B_psi  = f["B_gauss_psi"][:]
    omega_ref = float(f["meta/omega_ref"][()])
    NVOL = jx.shape[1]
    Nf_psi = jx.shape[0]

print(f"[plot] Nf_psi={Nf_psi}  NVOL={NVOL}  dx={dx_sub:.4f}")

t_ms = t_psi / omega_ref * 1000.0
B_uG = B_psi * 1e6
midz = NVOL // 2
xs = (np.arange(NVOL) - NVOL / 2) * dx_sub

# ============================================================================
# 1. Time-series scalars: |j|_max, n_max, total circulation
# ============================================================================
fig, axes = plt.subplots(1, 3, figsize=(14, 4))
axes[0].plot(t_ms, n_max, "C0", lw=1.8, marker="o", ms=4)
axes[0].set_xlabel("t (ms)"); axes[0].set_ylabel("max |ψ|² (internal)")
axes[0].set_title("Peak density")

axes[1].plot(t_ms, j_mag_max, "C1", lw=1.8, marker="o", ms=4)
axes[1].set_xlabel("t (ms)"); axes[1].set_ylabel("max |j| (internal)")
axes[1].set_title("Peak mass-current magnitude")

axes[2].plot(t_ms, circ, "C2", lw=1.8, marker="o", ms=4)
axes[2].axhline(0, color="k", lw=0.5)
axes[2].set_xlabel("t (ms)"); axes[2].set_ylabel("∫ ω_z dA  (z=mid)")
axes[2].set_title("Net circulation (midplane)")

for ax in axes:
    ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(f"{OUT_DIR}/mass_current_timeseries.png", dpi=130)
plt.close(fig)
print(f"  wrote mass_current_timeseries.png")


# ============================================================================
# 2. Per-frame: quiver + vorticity at z-midplane
# ============================================================================
stride = max(1, NVOL // 14)
Xq, Yq = np.meshgrid(xs[::stride], xs[::stride], indexing="ij")

# Pick a few representative frames
frame_idx = list(range(0, Nf_psi, max(1, Nf_psi // 6)))
if frame_idx[-1] != Nf_psi - 1:
    frame_idx.append(Nf_psi - 1)

n_panels = len(frame_idx)
ncols = 3
nrows = (n_panels + ncols - 1) // ncols
fig, axes = plt.subplots(nrows, ncols, figsize=(5.4 * ncols, 4.6 * nrows), squeeze=False)
for n, k in enumerate(frame_idx):
    r, c = n // ncols, n % ncols
    ax = axes[r, c]
    vort_slice = curl_v_z[k, :, :, midz]
    vmax_v = np.percentile(np.abs(vort_slice), 99)
    if vmax_v == 0:
        vmax_v = 1e-10
    im = ax.imshow(vort_slice.T, origin="lower",
                   extent=[xs[0], xs[-1], xs[0], xs[-1]],
                   cmap="RdBu_r", vmin=-vmax_v, vmax=vmax_v)
    plt.colorbar(im, ax=ax, label="(∇×v)_z")
    jx_s = jx[k, ::stride, ::stride, midz]
    jy_s = jy[k, ::stride, ::stride, midz]
    j_mag_s = np.hypot(jx_s, jy_s)
    ax.quiver(Xq, Yq, jx_s, jy_s, j_mag_s, cmap="viridis", pivot="mid",
              scale=None, width=0.004)
    ax.set_title(f"t = {t_ms[k]:.1f} ms   B = {B_uG[k]:.2f} µG")
    ax.set_xlabel("x"); ax.set_ylabel("y")

# Hide empty axes
for n in range(n_panels, nrows * ncols):
    r, c = n // ncols, n % ncols
    axes[r, c].axis("off")

fig.suptitle("Mass current j (quiver) + vorticity (∇×v)_z (background)  — z-midplane slice", y=1.01)
fig.tight_layout()
fig.savefig(f"{OUT_DIR}/mass_current_quiver_panels.png", dpi=130, bbox_inches="tight")
plt.close(fig)
print(f"  wrote mass_current_quiver_panels.png")


# ============================================================================
# 3. End-state focused: 6-panel — j, |j|, ω_z, |v|, streamlines, n_total
# ============================================================================
k_end = Nf_psi - 1
fig, axes = plt.subplots(2, 3, figsize=(15, 9))

# (0,0) j_x at z-mid
ax = axes[0, 0]
jx_e = jx[k_end, :, :, midz]
vmax_j = np.percentile(np.abs(jx_e), 99) + 1e-12
im = ax.imshow(jx_e.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
               cmap="RdBu_r", vmin=-vmax_j, vmax=vmax_j)
ax.set_title("j_x (z=mid)"); plt.colorbar(im, ax=ax)

# (0,1) j_y at z-mid
ax = axes[0, 1]
jy_e = jy[k_end, :, :, midz]
vmax_j = np.percentile(np.abs(jy_e), 99) + 1e-12
im = ax.imshow(jy_e.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
               cmap="RdBu_r", vmin=-vmax_j, vmax=vmax_j)
ax.set_title("j_y (z=mid)"); plt.colorbar(im, ax=ax)

# (0,2) (∇×v)_z at z-mid
ax = axes[0, 2]
vort = curl_v_z[k_end, :, :, midz]
vmax_v = np.percentile(np.abs(vort), 99) + 1e-12
im = ax.imshow(vort.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
               cmap="RdBu_r", vmin=-vmax_v, vmax=vmax_v)
ax.set_title("(∇×v)_z (z=mid)"); plt.colorbar(im, ax=ax)

# (1,0) |j| magnitude
ax = axes[1, 0]
j_mag_e = np.sqrt(jx_e**2 + jy_e**2)
im = ax.imshow(j_mag_e.T, origin="lower", extent=[xs[0], xs[-1], xs[0], xs[-1]],
               cmap="inferno")
ax.set_title("|j_⊥| magnitude"); plt.colorbar(im, ax=ax)

# (1,1) streamlines of j (use velocity v which is normalized by n for cleaner streamlines)
ax = axes[1, 1]
vx_e = vx[k_end, :, :, midz]
vy_e = vy[k_end, :, :, midz]
# streamplot wants 1D X, Y arrays
X_str, Y_str = np.meshgrid(xs, xs, indexing="ij")
# normalize for better streamline visibility
v_mag = np.hypot(vx_e, vy_e) + 1e-15
ax.streamplot(xs, xs, vx_e.T, vy_e.T, color=v_mag.T, cmap="plasma", density=1.4,
              linewidth=1.0)
ax.set_xlim(xs[0], xs[-1]); ax.set_ylim(xs[0], xs[-1])
ax.set_aspect("equal")
ax.set_title("Streamlines of v_⊥")

# (1,2) circulation time series (smaller copy for context)
ax = axes[1, 2]
ax.plot(t_ms, circ, "C2", lw=1.8, marker="o", ms=4)
ax.axhline(0, color="k", lw=0.5)
ax.set_xlabel("t (ms)"); ax.set_ylabel("∫ ω_z dA")
ax.set_title("Circulation over time")
ax.grid(alpha=0.3)

fig.suptitle(f"End-state mass current — t = {t_ms[k_end]:.1f} ms, B = {B_uG[k_end]:.2f} µG")
fig.tight_layout()
fig.savefig(f"{OUT_DIR}/mass_current_endstate.png", dpi=130)
plt.close(fig)
print(f"  wrote mass_current_endstate.png")


print(f"[plot] done — outputs in {OUT_DIR}/")
