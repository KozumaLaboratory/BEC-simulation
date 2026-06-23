#!/usr/bin/env python3
"""Data-format bridge: new full-ψ pipeline result.jld2 → derived-observable HDF5.

The accumulated Tsubame plotting suite (3D isosurfaces, HSV spin-texture
quivers, tilted-imaging contrast, density+phase shells, 2D slice panels, …)
was written against the OLD goto_protocol_10mG.jl custom-h5 keys
(n_m_xy, Fx_3d, n_m6_tilted, …). The NEW pipeline instead streams the full
13-component ψ (dynamics/psi_snapshots_streamed/frame_NNNNN, JLD2). This script
reconstructs the derived observables from the full ψ — in numpy — and writes a
standard HDF5 cache with the legacy keys, so the entire plotting suite runs
unchanged on the latest compute scheme.

Pure Python: h5py reads JLD2 (confirmed) and writes plain HDF5; no HDF5.jl
dependency, no Julia changes, no touch to the shared Project.toml.

Conventions (CLAUDE.md): component c=0 ↔ m=+F, c=D-1 ↔ m=−F (F=6, D=13).
So m=−6 is the LAST component (index 12). Arrays are written C-order natural
(frame, x, y[, z]); the ported plotting scripts read them WITHOUT transpose.

Usage:
  python extract_observables.py <result.jld2> <out_cache.h5> \
      [--stride 2] [--tilt -16,0,16] [--box 18] [--F 6]
"""
import sys, os, argparse
import numpy as np
import h5py


def spin_matrices(F):
    """(Fx, Fy, Fz) as (D,D) complex, ordered c=0↔m=+F … c=D-1↔m=−F."""
    D = int(2 * F + 1)
    m = np.arange(F, -F - 1, -1.0)              # [F, F-1, …, -F]
    Fz = np.diag(m).astype(complex)
    Fp = np.zeros((D, D), complex)              # raising in this ordering: c → c-1
    for c in range(1, D):
        mc = m[c]
        Fp[c - 1, c] = np.sqrt(F * (F + 1) - mc * (mc + 1))
    Fm = Fp.conj().T
    Fx = 0.5 * (Fp + Fm)
    Fy = (Fp - Fm) / (2j)
    return Fx, Fy, Fz


def load_frames(path):
    """Yield (index, psi[nx,ny,nz,D] complex) plus the scalar series."""
    f = h5py.File(path, "r")
    # locate the streamed-snapshot group (handles dynamics, dynamics_2, …)
    def find(g, pfx=""):
        out = []
        for k in g.keys():
            try:
                it = g[k]                       # some JLD2 internals (compound
            except Exception:                   # /psi, _types) raise in h5py — skip
                continue
            if isinstance(it, h5py.Group):
                try:
                    sub = list(it.keys())
                except Exception:
                    sub = []
                if "psi_snapshots_streamed" in sub:
                    out.append(pfx + "/" + k if pfx else k)
                out += find(it, (pfx + "/" + k) if pfx else k)
        return out
    groups = find(f)
    if not groups:
        raise SystemExit("no psi_snapshots_streamed group in " + path)
    frames = []
    for g in groups:
        grp = f[g + "/psi_snapshots_streamed"]
        fr = sorted(k for k in grp.keys() if k.startswith("frame_"))
        frames += [(g, k) for k in fr]
    # scalar series (best-effort; legacy keys default to NaN if absent)
    def series(g, name):
        kk = g + "/" + name
        return np.array(f[kk]) if kk in f else None
    g0 = groups[0]
    times = series(g0, "times")
    energies = series(g0, "energies")
    norms = series(g0, "norms")
    mags = series(g0, "magnetizations")
    return f, frames, times, energies, norms, mags


def read_psi(f, group_frame):
    g, k = group_frame
    raw = f[g + "/psi_snapshots_streamed/" + k][()]   # compound (re,im), h5py shape (D,nz,ny,nx)
    psi = (raw["re"].astype(np.float64) + 1j * raw["im"].astype(np.float64))
    return np.transpose(psi, (3, 2, 1, 0))            # → (nx,ny,nz,D)


def spin_field(psi, Fx, Fy, Fz):
    """⟨F_i⟩(r) for the spinor field; returns (fx,fy,fz) real (nx,ny,nz)."""
    cpsi = np.conj(psi)
    fx = np.real(np.einsum("xyzi,ij,xyzj->xyz", cpsi, Fx, psi))
    fy = np.real(np.einsum("xyzi,ij,xyzj->xyz", cpsi, Fy, psi))
    fz = np.real(np.einsum("xyzi,ij,xyzj->xyz", cpsi, Fz, psi))
    return fx, fy, fz


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("result"); ap.add_argument("out")
    ap.add_argument("--stride", type=int, default=2)
    ap.add_argument("--tilt", default="-16,0,16")
    ap.add_argument("--box", type=float, default=18.0)
    ap.add_argument("--F", type=int, default=6)
    a = ap.parse_args()

    F, D = a.F, 2 * a.F + 1
    Fx, Fy, Fz = spin_matrices(F)
    tilt = [float(t) for t in a.tilt.split(",")]
    # rotation operators e^{-iθ F_y} via Hermitian eigendecomposition of F_y
    wy, Vy = np.linalg.eigh(Fy)
    def rot(theta):
        ph = np.exp(-1j * np.deg2rad(theta) * wy)
        return (Vy * ph) @ Vy.conj().T
    Rtilt = [rot(t) for t in tilt]
    M6, M5, M4 = D - 1, D - 2, D - 3            # m=−6,−5,−4 component indices

    f, frames, times, energies, norms, mags = load_frames(a.result)
    nf = len(frames)
    psi0 = read_psi(f, frames[0])
    nx, ny, nz, _ = psi0.shape
    zc, yc = nz // 2, ny // 2
    sub = slice(None, None, a.stride)
    nv = len(range(0, nx, a.stride))
    print(f"[extract] {nf} frames  grid=({nx},{ny},{nz}) D={D} F={F} "
          f"stride={a.stride}→{nv}³  tilt={tilt}")

    o = h5py.File(a.out, "w")
    # scalar series + meta
    o["t"] = times if times is not None else np.arange(nf, dtype=float)
    if energies is not None: o["E"] = energies
    if norms is not None: o["N"] = norms
    if mags is not None: o["Mz"] = mags
    mt = o.create_group("meta")
    mt["F"] = F; mt["NX"] = nx; mt["L_box"] = a.box
    mt["vol_stride"] = a.stride; mt["theta_q_deg"] = np.array(tilt)
    mt["m_channels"] = np.arange(F, -F - 1, -1)

    # per-frame stacks (C-order natural: (nf, …); ported scripts read w/o transpose)
    n_m_xy = o.create_dataset("n_m_xy", (nf, D, nx, ny), "f4")
    n_m_xz = o.create_dataset("n_m_xz", (nf, D, nx, nz), "f4")
    fx_xy = o.create_dataset("Fx_xy", (nf, nx, ny), "f4"); fy_xy = o.create_dataset("Fy_xy", (nf, nx, ny), "f4"); fz_xy = o.create_dataset("Fz_xy", (nf, nx, ny), "f4")
    fx_xz = o.create_dataset("Fx_xz", (nf, nx, nz), "f4"); fy_xz = o.create_dataset("Fy_xz", (nf, nx, nz), "f4"); fz_xz = o.create_dataset("Fz_xz", (nf, nx, nz), "f4")
    arg_xy = o.create_dataset("arg_psi_m6_xy", (nf, nx, ny), "f4")
    arg_xz = o.create_dataset("arg_psi_m6_xz", (nf, nx, nz), "f4")
    tiltd = o.create_dataset("n_m6_tilted", (nf, len(tilt), nz, nx), "f4")
    n_tot3 = o.create_dataset("n_total_3d", (nf, nv, nv, nv), "f4")
    n_m6_3 = o.create_dataset("n_m6_3d", (nf, nv, nv, nv), "f4"); n_m5_3 = o.create_dataset("n_m5_3d", (nf, nv, nv, nv), "f4"); n_m4_3 = o.create_dataset("n_m4_3d", (nf, nv, nv, nv), "f4")
    a6 = o.create_dataset("arg_psi_m6_3d", (nf, nv, nv, nv), "f4"); a5 = o.create_dataset("arg_psi_m5_3d", (nf, nv, nv, nv), "f4"); a4 = o.create_dataset("arg_psi_m4_3d", (nf, nv, nv, nv), "f4")
    fx3 = o.create_dataset("Fx_3d", (nf, nv, nv, nv), "f4"); fy3 = o.create_dataset("Fy_3d", (nf, nv, nv, nv), "f4"); fz3 = o.create_dataset("Fz_3d", (nf, nv, nv, nv), "f4")
    Fz_scalar = np.zeros(nf)

    for k, gf in enumerate(frames):
        psi = read_psi(f, gf)
        dens = np.sum(np.abs(psi) ** 2, axis=3)                 # (nx,ny,nz)
        fx, fy, fz = spin_field(psi, Fx, Fy, Fz)
        # global ⟨Fz⟩ (density-weighted)
        Ntot = dens.sum()
        Fz_scalar[k] = fz.sum() / Ntot if Ntot > 0 else 0.0
        # 2-D slices
        n_m_xy[k] = np.transpose(np.abs(psi[:, :, zc, :]) ** 2, (2, 0, 1))
        n_m_xz[k] = np.transpose(np.abs(psi[:, yc, :, :]) ** 2, (2, 0, 1))
        fx_xy[k], fy_xy[k], fz_xy[k] = fx[:, :, zc], fy[:, :, zc], fz[:, :, zc]
        fx_xz[k], fy_xz[k], fz_xz[k] = fx[:, yc, :], fy[:, yc, :], fz[:, yc, :]
        arg_xy[k] = np.angle(psi[:, :, zc, M6]); arg_xz[k] = np.angle(psi[:, yc, :, M6])
        # tilted m=−6 column density (integrate over y), per angle
        for ti, R in enumerate(Rtilt):
            pr = np.einsum("ij,xyzj->xyzi", R, psi)
            tiltd[k, ti] = np.sum(np.abs(pr[:, :, :, M6]) ** 2, axis=1).T   # (nz,nx)
        # 3-D subsampled density / phase / spin
        ps = psi[sub, sub, sub, :]
        n_tot3[k] = np.sum(np.abs(ps) ** 2, axis=3)
        n_m6_3[k] = np.abs(ps[..., M6]) ** 2; n_m5_3[k] = np.abs(ps[..., M5]) ** 2; n_m4_3[k] = np.abs(ps[..., M4]) ** 2
        a6[k] = np.angle(ps[..., M6]); a5[k] = np.angle(ps[..., M5]); a4[k] = np.angle(ps[..., M4])
        fx3[k], fy3[k], fz3[k] = fx[sub, sub, sub], fy[sub, sub, sub], fz[sub, sub, sub]
        if (k + 1) % 10 == 0 or k == nf - 1:
            print(f"  frame {k+1}/{nf}  ⟨Fz⟩={Fz_scalar[k]:+.4f}", flush=True)

    if "Fz" not in o: o["Fz"] = Fz_scalar
    o.close(); f.close()
    print(f"[extract] wrote {a.out}")


if __name__ == "__main__":
    main()
