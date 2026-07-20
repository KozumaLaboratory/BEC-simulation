"""K_3 vs no-K_3 analysis: (1) high-density cutoff diagnostics +
(2) Flower-vs-EdH spin texture characterisation.

Inputs: rtp_10mG_goto.h5 (K3=0) and rtp_10mG_goto_k3_1.0e-40.h5
Outputs to /tmp/k3_flower/
"""
import os
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm, TwoSlopeNorm

OUT = "/tmp/k3_flower"
os.makedirs(OUT, exist_ok=True)

FILES = {
    "K3=0":     "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto.h5",
    "K3=1e-40": "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto_k3_1.0e-40.h5",
}

omega_ref = 691.1504


def load(label):
    f = h5py.File(FILES[label], "r")
    t_full = f["t"][:] / omega_ref * 1000.0
    n3d_arr  = f["n_total_3d"]
    n3d_shape = n3d_arr.shape
    # n3d shape might be (Nf, NX, NX, NX) OR (NX, NX, NX, Nf); pick the one where the
    # largest axis (time) sits.
    Nf_3d = n3d_shape[-1] if n3d_shape[-1] > n3d_shape[0] else n3d_shape[0]
    Fxy_shape = f["Fx_xy"].shape  # observed: (NX, NX, Nf)
    Nf_xy = Fxy_shape[-1]
    NX_xy = Fxy_shape[0]
    # 3D snapshots are sub-sampled — map them to t indices
    if "meta" in f and "vol_sample_indices" in f["meta"]:
        vol_idx = f["meta/vol_sample_indices"][:].astype(int) - 1  # Julia 1-based
        vol_idx = np.clip(vol_idx, 0, len(t_full) - 1)
        t_3d = t_full[vol_idx]
    else:
        t_3d = np.linspace(t_full[0], t_full[-1], Nf_3d)
    # xy slices: assume same cadence as t_full; if not, sub-sample
    if Nf_xy == len(t_full):
        t_xy = t_full
    else:
        t_xy = np.linspace(t_full[0], t_full[-1], Nf_xy)
    out = dict(
        t_ms   = t_full, t_3d = t_3d, t_xy = t_xy,
        N      = f["N"][:],
        n3d    = n3d_arr,
        Fx3d   = f["Fx_3d"], Fy3d = f["Fy_3d"], Fz3d = f["Fz_3d"],
        Fx_xy  = f["Fx_xy"], Fy_xy = f["Fy_xy"], Fz_xy = f["Fz_xy"],
        n_xy   = f["n_m_xy"],
        h5     = f,
    )
    out["nframes"]    = Nf_3d
    out["nframes_xy"] = Nf_xy
    out["NX"]    = n3d_shape[1]   # 3D grid (often coarser via vol_stride)
    out["NX_xy"] = NX_xy          # xy slice grid (full NX)
    return out


print("[load] reading h5 ...")
data = {label: load(label) for label in FILES}
NX = data["K3=0"]["NX"]
print(f"[load] NX={NX}  frames K3=0:{data['K3=0']['nframes']}  K3=1e-40:{data['K3=1e-40']['nframes']}")


# ============================================================================
# Part 1: High-density cutoff diagnostics
# ============================================================================

print("\n[part1] high-density cutoff ...")

# 1A. n_max(t) and ∫n² dV(t)
nmax = {}; n2int = {}; n3int = {}
for label, d in data.items():
    Nf = d["nframes"]
    nmax[label]  = np.empty(Nf)
    n2int[label] = np.empty(Nf)
    n3int[label] = np.empty(Nf)
    # n3d shape: (NX, NX, NX, Nf) — sub-sample every ~8 frames for speed
    step = max(1, Nf // 32)
    sample_idx = list(range(0, Nf, step))
    if sample_idx[-1] != Nf - 1:
        sample_idx.append(Nf - 1)
    sample_idx = np.array(sample_idx)
    nmax[label]  = np.empty(len(sample_idx))
    n2int[label] = np.empty(len(sample_idx))
    n3int[label] = np.empty(len(sample_idx))
    for k, i in enumerate(sample_idx):
        ntot = d["n3d"][:, :, :, i]
        nmax[label][k]  = ntot.max()
        n2int[label][k] = (ntot**2).sum()
        n3int[label][k] = (ntot**3).sum()
    d["sample_idx"] = sample_idx
    d["t_3d_sampled"] = d["t_3d"][sample_idx] if len(d["t_3d"]) >= sample_idx.max()+1 else np.linspace(0, d["t_ms"][-1], len(sample_idx))

fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for label, d in data.items():
    axes[0].plot(d["t_3d_sampled"], nmax[label],  label=label, lw=1.8, marker="o", ms=3)
    axes[1].plot(d["t_3d_sampled"], n2int[label], label=label, lw=1.8, marker="o", ms=3)
    axes[2].plot(d["t_3d_sampled"], n3int[label], label=label, lw=1.8, marker="o", ms=3)
axes[0].set_ylabel("max |ψ|²  (internal)"); axes[0].set_title("Peak density n_max(t)")
axes[1].set_ylabel("Σ n² · ΔV  (∝ ⟨n⟩ N)");  axes[1].set_title("Density concentration ∫n² dV")
axes[2].set_ylabel("Σ n³ · ΔV  (∝ −dN/dt)"); axes[2].set_title("Loss integrand ∫n³ dV")
for ax in axes:
    ax.set_xlabel("t (ms)"); ax.grid(alpha=0.3); ax.legend()
    ax.set_yscale("log")
fig.suptitle("High-density diagnostics — K_3 visibly caps peak / shrinks concentration")
fig.tight_layout()
fig.savefig(f"{OUT}/density_diagnostics.png", dpi=130)
plt.close(fig)
print(f"  wrote {OUT}/density_diagnostics.png")

# 1B. Density histogram at three times (early / mid / end)
N_sampled = len(data["K3=0"]["sample_idx"])
hist_idx = [0, N_sampled // 2, N_sampled - 1]
fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for ax, hi in zip(axes, hist_idx):
    nmax_here = max(nmax["K3=0"][hi], nmax["K3=1e-40"][hi])
    nmax_here = max(nmax_here, 1e-5)
    bins = np.logspace(-8, np.log10(nmax_here * 1.1), 80)
    for label, d in data.items():
        ti = d["sample_idx"][hi]
        ntot = d["n3d"][:, :, :, ti].ravel()
        ntot = ntot[ntot > 1e-10]
        ax.hist(ntot, bins=bins, alpha=0.5, label=label,
                weights=ntot, density=False)
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.set_xlabel("|ψ|²  (internal)"); ax.set_ylabel("mass-weighted count")
    ax.set_title(f"t = {data['K3=0']['t_3d_sampled'][hi]:.1f} ms")
    ax.grid(alpha=0.3); ax.legend()
fig.suptitle("Density distribution P(n) — K_3 carves the high-n tail")
fig.tight_layout()
fig.savefig(f"{OUT}/density_histogram.png", dpi=130)
plt.close(fig)
print(f"  wrote {OUT}/density_histogram.png")

# 1C. xy mid-z slice of n_total at end time, shared colormap
NX_3d = data["K3=0"]["NX"]
mid_z = NX_3d // 2
end = data["K3=0"]["nframes"] - 1
slice_K3_0  = data["K3=0"]["n3d"][:, :, mid_z, end]
slice_K3_e  = data["K3=1e-40"]["n3d"][:, :, mid_z, end]
vmax_shared = max(slice_K3_0.max(), slice_K3_e.max())
fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))
for ax, (label, d), sl in zip(axes, data.items(), [slice_K3_0, slice_K3_e]):
    im = ax.imshow(sl.T, origin="lower",
                   vmin=0, vmax=vmax_shared, cmap="inferno")
    ax.set_title(f"{label}   t = {d['t_ms'][end]:.1f} ms")
    plt.colorbar(im, ax=ax, label="|ψ|²")
fig.suptitle("End-state density (z = NX/2 slice, SHARED colour scale)")
fig.tight_layout()
fig.savefig(f"{OUT}/density_slice_endstate.png", dpi=130)
plt.close(fig)
print(f"  wrote {OUT}/density_slice_endstate.png")


# ============================================================================
# Part 2: Flower-vs-EdH spin texture
# ============================================================================

print("\n[part2] spin texture / flower vs EdH ...")


def spin_texture_panel(label, ti, save_path):
    """6-panel: F_z map, |F_⊥|, arg(F_+) flower-phase, quiver, n_total bg, divergence."""
    d = data[label]
    # h5 shape: (NX, NX, Nf) — time on last axis
    Fx = d["Fx_xy"][:, :, ti]
    Fy = d["Fy_xy"][:, :, ti]
    Fz = d["Fz_xy"][:, :, ti]
    # n_m_xy shape: (NX, NX, 13, Nf) → sum over m axis
    nslice = d["n_xy"][:, :, :, ti].sum(axis=2)
    Fperp_mag   = np.hypot(Fx, Fy)
    Fperp_phase = np.arctan2(Fy, Fx)        # azimuthal angle of transverse spin

    # Divergence of F in xy plane (∂F_x/∂x + ∂F_y/∂y); F_z slope along z is missing here
    # — informative only as a 2D proxy. Real flux closure needs full 3D divergence.
    dFx_dx = np.gradient(Fx, axis=0)
    dFy_dy = np.gradient(Fy, axis=1)
    divF_2d = dFx_dx + dFy_dy

    fig, axes = plt.subplots(2, 3, figsize=(15, 9))
    NXh = Fx.shape[0]
    extent = [-NXh/2, NXh/2, -NXh/2, NXh/2]

    ax = axes[0, 0]
    im = ax.imshow(Fz, origin="lower", extent=extent, cmap="RdBu_r",
                   norm=TwoSlopeNorm(vcenter=0, vmin=-6, vmax=6))
    ax.set_title("⟨F_z⟩(x,y)  — z-polarisation"); plt.colorbar(im, ax=ax)

    ax = axes[0, 1]
    im = ax.imshow(Fperp_mag, origin="lower", extent=extent, cmap="viridis")
    ax.set_title("|F_⊥|(x,y)  — transverse-spin amplitude"); plt.colorbar(im, ax=ax)

    ax = axes[0, 2]
    im = ax.imshow(Fperp_phase, origin="lower", extent=extent, cmap="twilight",
                   vmin=-np.pi, vmax=np.pi)
    ax.set_title("arg(F_x + i F_y)  — flower-petal phase"); plt.colorbar(im, ax=ax)

    ax = axes[1, 0]
    # quiver of (F_x, F_y) on top of |F_⊥| background, sub-sample
    stride = max(1, NXh // 18)
    xs = np.arange(NXh) - NXh/2
    Xq, Yq = np.meshgrid(xs[::stride], xs[::stride], indexing="ij")
    Fx_s = Fx[::stride, ::stride]
    Fy_s = Fy[::stride, ::stride]
    Fperp_s = Fperp_mag[::stride, ::stride]
    ax.imshow(Fperp_mag, origin="lower", extent=extent, cmap="Greys", alpha=0.55)
    ax.quiver(Xq, Yq, Fx_s, Fy_s, Fperp_s, cmap="plasma", pivot="mid")
    ax.set_title("(F_x, F_y) quiver on |F_⊥|")
    ax.set_xlim(extent[0], extent[1]); ax.set_ylim(extent[2], extent[3])

    ax = axes[1, 1]
    im = ax.imshow(nslice, origin="lower", extent=extent, cmap="inferno")
    ax.set_title("n_total(x,y)"); plt.colorbar(im, ax=ax)

    ax = axes[1, 2]
    vmax_div = np.percentile(np.abs(divF_2d), 99)
    im = ax.imshow(divF_2d, origin="lower", extent=extent, cmap="seismic",
                   vmin=-vmax_div, vmax=vmax_div)
    ax.set_title("∂F_x/∂x + ∂F_y/∂y  (2D ∇·F proxy)\nFlower ⇒ ≈ 0")
    plt.colorbar(im, ax=ax)

    fig.suptitle(f"{label}   t = {d['t_xy'][ti]:.1f} ms   (z-midplane slice)")
    fig.tight_layout()
    fig.savefig(save_path, dpi=130)
    plt.close(fig)
    return Fperp_phase, Fperp_mag


end_xy = data["K3=0"]["nframes_xy"] - 1
# end-state panels
for label in FILES:
    spin_texture_panel(label, end_xy, f"{OUT}/spin_texture_{label.replace('=', '_').replace('-', 'm')}_end.png")
    print(f"  wrote spin_texture_{label}_end.png")

# Azimuthal Fourier analysis: count "flower petals"
# For each radius r, look at how arg(F_⊥) winds around 2π
print("\n[part2b] flower petal counting ...")
fig, axes = plt.subplots(1, 2, figsize=(12, 5))
for ax, (label, d) in zip(axes, data.items()):
    Fx = d["Fx_xy"][:, :, end_xy]
    Fy = d["Fy_xy"][:, :, end_xy]
    NXh = Fx.shape[0]
    cx, cy = NXh / 2, NXh / 2
    X, Y = np.meshgrid(np.arange(NXh) - cx, np.arange(NXh) - cy, indexing="ij")
    R = np.hypot(X, Y)
    Theta = np.arctan2(Y, X)

    # For each radial ring, extract F_+ values around the ring and FFT in angle
    radii = np.arange(2, NXh // 2 - 2, 2)
    petal_spectrum = np.zeros((len(radii), 9))  # n = 0..8 petals
    for i, r in enumerate(radii):
        mask = (R >= r - 1) & (R < r + 1)
        if mask.sum() < 8:
            continue
        F_plus = Fx[mask] + 1j * Fy[mask]
        th_ring = Theta[mask]
        order = np.argsort(th_ring)
        F_plus = F_plus[order]
        # crude FT
        for n in range(9):
            petal_spectrum[i, n] = np.abs(np.mean(F_plus * np.exp(-1j * n * th_ring[order])))
    im = ax.imshow(petal_spectrum.T, aspect="auto", origin="lower",
                   extent=[radii[0], radii[-1], -0.5, 8.5],
                   cmap="hot")
    ax.set_xlabel("radial bin (voxels)")
    ax.set_ylabel("azimuthal order n  (n=1 EdH 1-vortex, n≥2 flower)")
    ax.set_title(f"{label}  |⟨F_+ · e^(-inθ)⟩|  end state")
    plt.colorbar(im, ax=ax)
fig.suptitle("Azimuthal Fourier decomposition of F_⊥ — which 'n-petal' dominates?")
fig.tight_layout()
fig.savefig(f"{OUT}/flower_petal_spectrum.png", dpi=130)
plt.close(fig)
print(f"  wrote flower_petal_spectrum.png")


# ============================================================================
# Cleanup
# ============================================================================

for d in data.values():
    d["h5"].close()

print(f"\n[done] outputs in {OUT}/")
for f in sorted(os.listdir(OUT)):
    fp = f"{OUT}/{f}"
    sz = os.path.getsize(fp) // 1024
    print(f"  {f:50s} {sz:>6d} KB")
