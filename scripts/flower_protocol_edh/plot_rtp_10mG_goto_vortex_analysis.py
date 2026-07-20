#!/usr/bin/env python3
"""
Vortex / angular-momentum analysis for the Goto RTP m=-6, -5, -4 components.

Three diagnostics over the trajectory:

1. ⟨L_z⟩_m(t) per component
   L_z = -iℏ ∂_φ = -iℏ(x∂_y − y∂_x), expectation in units of ℏ:
       ⟨L_z⟩_m = Im(∫ψ_m* (x∂_y − y∂_x) ψ_m d³r) / ∫|ψ_m|² d³r
   A pure ψ_m ∝ e^{iℓφ} gives ⟨L_z⟩ = ℓ. The donut shape in m=-5,-4 should
   show ⟨L_z⟩ approaching −1, −2 respectively (consistent with the dipolar
   spin-orbit selection rule m=-6 + Y_2^j → m=-6+j carrying ΔL_z = −j).

2. Top–bottom phase difference Δφ_topbot(t)
   Density-weighted complex average of ψ_m over the z > 0 and z < 0
   hemispheres separately; report arg(⟨ψ_m⟩_top / ⟨ψ_m⟩_bot). Tells
   whether the upper and lower donut lobes are in phase (Δφ ≈ 0) or
   antiphase (Δφ ≈ ±π) — a signature of l_z-symmetric vs antisymmetric
   z-dependence.

3. Ring winding number w_m(t)
   Sample ψ_m on a circle at radius r = r_ring(t) (set by the xy-density
   maximum) in the z = 0 plane, unwrap arg, integrate around the loop.
   Independent check on ⟨L_z⟩.

Outputs:
   OUT_PNG  multi-panel summary
   OUT_CSV  raw time series (t_ms, B_uG, Lz_m6, Lz_m5, Lz_m4,
            dphi_m5, dphi_m4, w_m5, w_m4)
"""
import os
from pathlib import Path

import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

H5_DEFAULT = "/gs/fs/tga-kozuma-kouhi/ue06186/bec-runs/flower_protocol_edh/rtp_10mG_goto.h5"
H5 = Path(os.environ.get("RTP_H5", H5_DEFAULT))
OUT_PNG = Path(os.environ.get(
    "OUT_PNG",
    "runs/eu151_flower_protocol_edh/figures/goto_protocol_10mG/vortex_analysis_m6m5m4.png",
))
OUT_CSV = Path(os.environ.get(
    "OUT_CSV",
    "runs/eu151_flower_protocol_edh/figures/goto_protocol_10mG/vortex_analysis_m6m5m4.csv",
))
N_PHI_RING = int(os.environ.get("N_PHI_RING", "64"))

COMPONENTS = [
    (-6, "n_m6_3d", "arg_psi_m6_3d"),
    (-5, "n_m5_3d", "arg_psi_m5_3d"),
    (-4, "n_m4_3d", "arg_psi_m4_3d"),
]


def load_dataset(path):
    with h5py.File(path, "r") as f:
        omega_ref = float(f["meta/omega_ref"][()])
        Lbox = float(f["meta/L_box"][()])
        NX = int(f["meta/NX"][()])
        vol_stride = int(f["meta/vol_stride"][()])
        t = f["t"][:]
        B = f["B_gauss"][:]
        data = {}
        for m, dk, pk in COMPONENTS:
            data[m] = (
                np.transpose(f[dk][:], (3, 2, 1, 0)).astype(np.float64),
                np.transpose(f[pk][:], (3, 2, 1, 0)).astype(np.float64),
            )
    return data, t, B, omega_ref, Lbox, NX, vol_stride


def lz_expectation(psi, X, Y, dx):
    """⟨L_z⟩ in units of ℏ. ψ on a regular cubic grid with spacing dx."""
    # central differences with periodic roll (small error at boundaries
    # since |ψ| → 0 there anyway)
    dpsi_dx = (np.roll(psi, -1, axis=0) - np.roll(psi, 1, axis=0)) / (2 * dx)
    dpsi_dy = (np.roll(psi, -1, axis=1) - np.roll(psi, 1, axis=1)) / (2 * dx)
    Lz_psi = -1j * (X * dpsi_dy - Y * dpsi_dx)
    num = np.sum(np.conj(psi) * Lz_psi).imag * (-1.0)  # take Im, then real
    # ∫ψ*Lzψ d³r = real number; the line above already returns Re via .imag·(-1)? recompute clean:
    integrand = np.conj(psi) * Lz_psi
    integral = np.sum(integrand) * dx ** 3
    norm = np.sum(np.abs(psi) ** 2) * dx ** 3
    if norm < 1e-300:
        return float("nan")
    return float(np.real(integral / norm))


def topbot_phase_diff(psi, Z):
    """arg(⟨ψ⟩_{z>0} / ⟨ψ⟩_{z<0}) weighted by |ψ|."""
    mask_top = Z > 0
    mask_bot = Z < 0
    w_top = np.sum(psi[mask_top] * np.abs(psi[mask_top]))
    w_bot = np.sum(psi[mask_bot] * np.abs(psi[mask_bot]))
    if abs(w_top) < 1e-300 or abs(w_bot) < 1e-300:
        return float("nan")
    return float(np.angle(w_top / w_bot))


def ring_winding(psi, xs, n_phi):
    """Closed-loop winding of arg(ψ) on the xy-density-peak ring at z=0."""
    nx, ny, nz = psi.shape
    z_mid = nz // 2
    psi_z = psi[:, :, z_mid]
    rho_xy = np.abs(psi_z) ** 2
    if rho_xy.max() < 1e-300:
        return float("nan"), 0.0
    # ring radius = density-weighted ⟨r⟩ in the xy plane (excluding the very center)
    X2, Y2 = np.meshgrid(xs, xs, indexing="ij")
    R2 = np.sqrt(X2 ** 2 + Y2 ** 2)
    weight = rho_xy.copy()
    weight[R2 < 0.5 * (xs[-1] - xs[0]) / nx] = 0.0
    if weight.sum() < 1e-300:
        return float("nan"), 0.0
    r_ring = float((R2 * weight).sum() / weight.sum())

    # sample ψ on circle at r_ring
    phis = np.linspace(0.0, 2.0 * np.pi, n_phi, endpoint=False)
    samples = np.empty(n_phi, dtype=complex)
    for k, phi in enumerate(phis):
        x = r_ring * np.cos(phi)
        y = r_ring * np.sin(phi)
        i = int(np.argmin(abs(xs - x)))
        j = int(np.argmin(abs(xs - y)))
        samples[k] = psi_z[i, j]

    # closed loop unwrap: append first to end so the full circle is covered
    args = np.angle(samples)
    args_closed = np.concatenate([args, args[:1]])
    args_unwrapped = np.unwrap(args_closed)
    winding = (args_unwrapped[-1] - args_unwrapped[0]) / (2.0 * np.pi)
    return float(winding), r_ring


def main():
    print(f"loading {H5}")
    data, t, B, omega_ref, Lbox, NX, vol_stride = load_dataset(H5)
    n_frames = data[-6][0].shape[0]
    shape3d = data[-6][0].shape[1:]
    dx = Lbox / NX * vol_stride
    xs = -Lbox / 2.0 + dx * np.arange(shape3d[0]) + dx / 2.0
    X, Y, Z = np.meshgrid(xs, xs, xs, indexing="ij")
    print(f"frames {n_frames}  shape {shape3d}  dx {dx:.4f} μm  ring samples {N_PHI_RING}")

    Lz = {m: np.empty(n_frames) for m, _, _ in COMPONENTS}
    dphi = {m: np.empty(n_frames) for m in (-5, -4)}
    wind = {m: np.empty(n_frames) for m in (-5, -4)}
    r_ring_log = {m: np.empty(n_frames) for m in (-5, -4)}
    t_ms = t / omega_ref * 1000.0
    B_uG = B * 1e6

    for k in range(n_frames):
        for m, _, _ in COMPONENTS:
            dens = data[m][0][k]
            arg = data[m][1][k]
            psi = np.sqrt(dens) * np.exp(1j * arg)
            Lz[m][k] = lz_expectation(psi, X, Y, dx)
            if m in (-5, -4):
                dphi[m][k] = topbot_phase_diff(psi, Z)
                w, r_ring = ring_winding(psi, xs, N_PHI_RING)
                wind[m][k] = w
                r_ring_log[m][k] = r_ring
        if k % 20 == 0 or k == n_frames - 1:
            print(f"  frame {k+1:3d}/{n_frames}  t={t_ms[k]:7.2f} ms  B={B_uG[k]:+8.2f} μG  "
                  f"Lz=[{Lz[-6][k]:+.3f}, {Lz[-5][k]:+.3f}, {Lz[-4][k]:+.3f}]  "
                  f"w=[{wind[-5][k]:+.3f}, {wind[-4][k]:+.3f}]")

    # CSV
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_CSV, "w") as f:
        f.write("t_ms,B_uG,Lz_m6,Lz_m5,Lz_m4,dphi_m5,dphi_m4,w_m5,w_m4,r_ring_m5,r_ring_m4\n")
        for k in range(n_frames):
            f.write(f"{t_ms[k]:.4f},{B_uG[k]:.4f},"
                    f"{Lz[-6][k]:+.6f},{Lz[-5][k]:+.6f},{Lz[-4][k]:+.6f},"
                    f"{dphi[-5][k]:+.6f},{dphi[-4][k]:+.6f},"
                    f"{wind[-5][k]:+.6f},{wind[-4][k]:+.6f},"
                    f"{r_ring_log[-5][k]:.4f},{r_ring_log[-4][k]:.4f}\n")
    print(f"wrote {OUT_CSV}")

    # Plot
    fig, axes = plt.subplots(3, 1, figsize=(10, 11), sharex=True,
                             gridspec_kw=dict(hspace=0.18, top=0.95, bottom=0.08,
                                              left=0.10, right=0.90))
    # B(t) overlay on twin axes
    def twin_B(ax):
        ax2 = ax.twinx()
        ax2.plot(t_ms, B_uG, color="0.6", linestyle=":", linewidth=1.0, zorder=0)
        ax2.set_ylabel("B [μG]", color="0.5", fontsize=9)
        ax2.tick_params(axis="y", labelsize=8, colors="0.5")
        return ax2

    # Panel 1: ⟨L_z⟩
    ax = axes[0]
    ax.plot(t_ms, Lz[-6], color="#1f77b4", label="m = -6", lw=1.4)
    ax.plot(t_ms, Lz[-5], color="#d62728", label="m = -5", lw=1.4)
    ax.plot(t_ms, Lz[-4], color="#2ca02c", label="m = -4", lw=1.4)
    ax.axhline(0, color="k", lw=0.4, alpha=0.4)
    ax.axhline(-1, color="#d62728", ls="--", lw=0.6, alpha=0.5)
    ax.axhline(-2, color="#2ca02c", ls="--", lw=0.6, alpha=0.5)
    ax.set_ylabel(r"$\langle L_z \rangle_m$  [ℏ]")
    ax.set_title("Goto 10 mG protocol — angular momentum per spin component", fontsize=12)
    ax.legend(loc="upper right", fontsize=9)
    twin_B(ax)

    # Panel 2: top-bottom phase diff
    ax = axes[1]
    ax.plot(t_ms, dphi[-5], color="#d62728", label="m = -5", lw=1.4)
    ax.plot(t_ms, dphi[-4], color="#2ca02c", label="m = -4", lw=1.4)
    for ref, lbl in [(0, "in-phase"), (np.pi, "antiphase"), (-np.pi, "antiphase")]:
        ax.axhline(ref, color="k", lw=0.4, ls=":", alpha=0.4)
    ax.set_ylabel(r"$\arg(\langle\psi_m\rangle_{z>0} / \langle\psi_m\rangle_{z<0})$  [rad]")
    ax.set_ylim(-np.pi - 0.2, np.pi + 0.2)
    ax.set_yticks([-np.pi, -np.pi/2, 0, np.pi/2, np.pi])
    ax.set_yticklabels(["−π", "−π/2", "0", "π/2", "π"])
    ax.legend(loc="upper right", fontsize=9)
    twin_B(ax)

    # Panel 3: ring winding
    ax = axes[2]
    ax.plot(t_ms, wind[-5], color="#d62728", label="m = -5", lw=1.4)
    ax.plot(t_ms, wind[-4], color="#2ca02c", label="m = -4", lw=1.4)
    for n in (-2, -1, 0, 1, 2):
        ax.axhline(n, color="k", lw=0.4, ls=":", alpha=0.4)
    ax.set_ylabel("ring winding  $\\oint d\\phi\\,\\partial_\\phi\\arg\\psi / 2\\pi$")
    ax.set_xlabel("t [ms]")
    ax.legend(loc="upper right", fontsize=9)
    twin_B(ax)

    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_PNG, dpi=170)
    print(f"wrote {OUT_PNG}")


if __name__ == "__main__":
    main()
