#!/usr/bin/env python3
"""v7_EdH_Fable stage 2 — TRUTH REFERENCE (comparison side of the firewall).

Reads the full wavefunction psi13 and computes, for the frames selected by
sg_forward.py, the true fields the reconstruction will be judged against:
  f_i(r)        3D spin density (i=x,y,z), all voxels, no floor
  n(r)          3D total density
  F_i(x,z)      column-integrated spin density  ∫dy f_i
  Ncol(x,z)     column density                  ∫dy n
This script never touches the reconstruction code path; recon_from_pixels.py
never touches psi. Only viz/audit compare the two files.

env: PSI13, RAW (sg_raw_v7.h5, for the frame list + grid meta), OUT (truth_v7.h5)
"""
import os, sys
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import (open_psi13, load_frames_bulk, spin_density_3d,
                       grid_axes, env)

PSI13 = env("PSI13", "edh_v6_psi13.jld2")
RAW = env("RAW", "sg_raw_v7.h5")
OUT = env("OUT", "truth_v7.h5")

P = open_psi13(PSI13)
L, Ng, ax1d, dx = grid_axes(P)
dy = dx
with h5py.File(RAW, "r") as R:
    FRAMES = list(np.asarray(R["frames_selected"]))
    t_ms = {fr: float(R[f"frames/f{fr:04d}/t_ms"][()]) for fr in FRAMES}

with h5py.File(OUT, "w") as O:
    O["meta/L_box"] = L; O["meta/Ng"] = Ng; O["meta/dx"] = dx
    O["frames_selected"] = np.array(FRAMES)
    PSIS = load_frames_bulk(P, FRAMES)       # one contiguous pass over the file
    for k, fr in enumerate(FRAMES):
        psi = PSIS[k]
        fx, fy, fz = spin_density_3d(psi)
        n = np.sum(np.abs(psi) ** 2, axis=-1)
        g = O.create_group(f"frames/f{fr:04d}")
        g["t_ms"] = t_ms[fr]
        g["fx_3d"] = fx; g["fy_3d"] = fy; g["fz_3d"] = fz; g["n_3d"] = n
        g["Fx_col"] = fx.sum(axis=1) * dy
        g["Fy_col"] = fy.sum(axis=1) * dy
        g["Fz_col"] = fz.sum(axis=1) * dy
        g["Ncol"] = n.sum(axis=1) * dy
        print(f"[truth] frame f{fr:04d}: <Fz>/N={fz.sum() / n.sum():+.3f}", flush=True)
print(f"[truth] wrote {OUT}")
