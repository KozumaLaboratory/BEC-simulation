#!/usr/bin/env python3
"""v7_EdH_Fable stage 3 — INVERSE PROBLEM from pixel data ONLY.

FIREWALL: this script opens sg_raw_v7.h5 and nothing else. It never sees psi.
SELF-DESCRIBING: the tilt protocol (which settings exist, their axes/angles,
their purpose) is read from the raw file's settings table — the SAME code
inverts any angle set (default id,y+-16,x+-16; future scans just change
V7_TILT_SPEC at forward-model time, or real experimental angle lists).

(a) Column-integrated <F>(x,z) reconstruction
    Pixelwise centroids s^(k) = sum_m m N_m^(k); then per-pixel least-squares
    inversion of the exact identities s^(k) = n(axis_k, beta_k) . <F>
    (recon_F_general; n from the Rodrigues form, anchors audited).
    Four estimates per frame:
      protocol_vis    : configured tilt set, visible block (THE experiment)
      protocol_all13  : configured tilt set, all channels   (sim-only bound)
      exact90_vis / exact90_all13 : 90deg 3-image reference
    Plus the pixelwise least-squares residual map (data-internal consistency,
    meaningful on real data too) and held-out-angle predictions.

(b) 3D estimation f_i(x,y,z) from d_i(x,z) = ∫dy f_i
    The tilt scan rotates the SPIN projection axis only; the spatial line of
    sight is fixed, so the y-dependence of f_i is in the null space of the
    measurement. Two experiment-available estimates make that quantitative:

    uniform  — minimum-||grad f|| solution of  min ||∇f||^2 s.t. ∫dy f = d.
               Per transverse Fourier mode the constrained minimizer is
               constant along y (the ones vector spans the Neumann null space
               of D_y^†D_y and is an eigenvector of every k^2 I), i.e. ANY
               translation-invariant smoothness prior collapses, lambda-
               independently, to uniform spreading f̂ = d/(Ny·dy) — which
               equals the k_y=0 projection of the truth: the no-prior floor.

    ansatz   — separable cloud-shape prior f̂_i(x,y,z) = d_i(x,z)·w(y,z),
               w(y,z) = Ncol(y->x, z)/∫Ncol dx: the y-profile at height z is
               assumed shaped like the MEASURED x-profile of the column
               density at that z (isotropic-trap x<->y symmetry). Uses only
               the untilted image — experiment-available.

env: RAW (sg_raw_v7.h5), OUT (recon_v7.h5)
"""
import os, sys
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import (ms, recon_F_general, recon_F_from_exact,
                       predict_centroid, env)

RAW = env("RAW", "sg_raw_v7.h5")
OUT = env("OUT", "recon_v7.h5")

R = h5py.File(RAW, "r")
FRAMES = list(np.asarray(R["frames_selected"]))
Ng = int(R["meta/Ng"][()]); dy = float(R["meta/dy"][()])
vis_ms = np.asarray(R["meta/visible_ms"]).astype(float)

names = [s.decode() for s in np.asarray(R["settings/name"])]
axes = [s.decode() for s in np.asarray(R["settings/axis"])]
angs = np.asarray(R["settings/angle_deg"])
purp = [s.decode() for s in np.asarray(R["settings/purpose"])]
PROTO = [(n, a, b) for n, a, b, p in zip(names, axes, angs, purp) if p == "protocol"]
HELD = [(n, a, b) for n, a, b, p in zip(names, axes, angs, purp) if p == "heldout"]
print(f"[recon] raw={RAW} frames={FRAMES} Ng={Ng}")
print(f"[recon] protocol from raw file: {[n for n, _, _ in PROTO]}  heldout: {[n for n, _, _ in HELD]}")

def cents_from(group, channel, wanted):
    w = vis_ms if channel == "visible" else ms.astype(float)
    out = {}
    for name in wanted:
        img = np.asarray(group[f"{channel}/{name}"])            # (Nx,Nz,nch)
        out[name] = np.einsum("xzm,m->xz", img, w)
    return out

with h5py.File(OUT, "w") as O:
    O["frames_selected"] = np.array(FRAMES)
    O["meta/Ng"] = Ng; O["meta/dy"] = dy
    O["meta/protocol"] = np.array([n for n, _, _ in PROTO], dtype="S16")
    O["meta/note"] = ("recon built from sg_raw_v7.h5 ONLY (firewall); protocol "
                      "read from the raw settings table (angle-set agnostic). "
                      "uniform 3D = minimum-grad-norm solution (exact, lambda-"
                      "independent = k_y=0 projection); ansatz 3D = x<->y "
                      "symmetric cloud-shape prior from the measured column density.")
    for fr in FRAMES:
        g = R[f"frames/f{fr:04d}"]
        og = O.create_group(f"frames/f{fr:04d}")
        og["t_ms"] = float(g["t_ms"][()])
        allnames = [n for n, _, _ in PROTO] + [n for n, _, _ in HELD] + ["y-90", "x+90"]
        for tag, ch in (("vis", "visible"), ("all13", "sim_only_all13")):
            c = cents_from(g, ch, allnames)
            fx, fy, fz, resid = recon_F_general(c, PROTO)
            og[f"col/fx_protocol_{tag}"] = fx
            og[f"col/fy_protocol_{tag}"] = fy
            og[f"col/fz_protocol_{tag}"] = fz
            og[f"col/lsq_resid_{tag}"] = resid
            cE = {"id": c["id"], "y-90": c["y-90"], "x+90": c["x+90"]}
            fxE, fyE, fzE = recon_F_from_exact(cE)
            og[f"col/fx_exact90_{tag}"] = fxE
            og[f"col/fy_exact90_{tag}"] = fyE
            og[f"col/fz_exact90_{tag}"] = fzE
            og[f"col/Ncol_{tag}"] = np.asarray(g[f"{ch}/id"]).sum(axis=-1)
            # held-out angle validation: predict never-used settings from recon
            for name, axis, deg in HELD:
                pred = predict_centroid(fx, fy, fz, axis, deg)
                og[f"heldout/{name}_residual_{tag}"] = pred - c[name]
                og[f"heldout/{name}_measured_{tag}"] = c[name]
        # ---------------- 3D estimates from the protocol column fields
        for tag in ("vis", "all13"):
            Ncol = np.asarray(og[f"col/Ncol_{tag}"])
            prof = np.clip(Ncol, 0.0, None)                     # (Nx->y proxy, Nz)
            wz = prof / np.clip(prof.sum(axis=0, keepdims=True), 1e-300, None) / dy
            for comp in ("fx", "fy", "fz"):
                d = np.asarray(og[f"col/{comp}_protocol_{tag}"])  # (Nx,Nz)
                og[f"rec3d/{comp}_uniform_{tag}"] = (
                    np.repeat(d[:, None, :], Ng, axis=1) / (Ng * dy))
                og[f"rec3d/{comp}_ansatz_{tag}"] = d[:, None, :] * wz[None, :, :]
        print(f"[recon] frame f{fr:04d} done", flush=True)
print(f"[recon] wrote {OUT}")
