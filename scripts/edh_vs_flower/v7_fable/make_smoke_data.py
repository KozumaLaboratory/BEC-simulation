#!/usr/bin/env python3
"""v7_EdH_Fable — synthetic 16^3 smoke dataset in the EXACT psi13/goto layout.

An EdH-like toy: cloud polarized near m=-6 (n̂ ~ -ẑ) with a transient tilt
bump theta(t) and a spatial phase winding (spin-vortex-like texture) plus
genuine y-dependence, and slow atom loss. Written so load_frame()/
frame_times_ms() read it identically to the real Tsubame files:
  psi13: datasets psi_re_c01..13 with h5py shape (nv,nv,nv,nf)  [frame LAST]
         (real files are Julia (nf,nv,nv,nv) column-major = same h5py view),
         values stored so that transpose(2,1,0) recovers (x,y,z).
  goto : t (internal units), B_gauss, meta/omega_ref.
env: OUTDIR (default scratch ./smoke_v7)
"""
import os, sys
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import D, coherent_field, env

OUTDIR = env("OUTDIR", "./smoke_v7")
os.makedirs(OUTDIR, exist_ok=True)
Nv, NF, L = 16, 12, 18.0
ax = np.linspace(-L / 2, L / 2, Nv, endpoint=False)
X, Y, Z = np.meshgrid(ax, ax, ax, indexing="ij")
R2 = X**2 + Y**2 + Z**2
amp0 = np.exp(-R2 / (2 * 3.0**2))

t_int = np.linspace(0.0, 2.0, NF)                 # internal time units
omega_ref = 691.15
theta_amp = 0.6 * np.exp(-((t_int - 0.7) / 0.35) ** 2)   # transient tilt bump

re = np.zeros((D, Nv, Nv, Nv, NF)); im = np.zeros((D, Nv, Nv, Nv, NF))
for k in range(NF):
    th = np.pi - theta_amp[k] * np.exp(-(X**2 + Z**2) / (2 * 4.0**2)) \
         * (1 + 0.4 * np.sin(2 * np.pi * Y / L))          # near -z, y-dependent
    ph = np.arctan2(Z, X) + 0.5 * Y                        # winding + y twist
    nhat = np.stack([np.sin(th) * np.cos(ph),
                     np.sin(th) * np.sin(ph), np.cos(th)], axis=-1)
    psi = (amp0 * np.sqrt(1 - 0.4 * k / (NF - 1)))[..., None] * coherent_field(nhat)
    for c in range(D):
        re[c, ..., k] = psi[..., c].real
        im[c, ..., k] = psi[..., c].imag
    print(f"[smoke] frame {k + 1}/{NF}", flush=True)

p13 = os.path.join(OUTDIR, "smoke_psi13.jld2")
with h5py.File(p13, "w") as O:
    for c in range(D):
        # loader does transpose(2,1,0) on [:,:,:,fr] -> store axes reversed
        O[f"psi_re_c{c + 1:02d}"] = np.transpose(re[c], (2, 1, 0, 3))
        O[f"psi_im_c{c + 1:02d}"] = np.transpose(im[c], (2, 1, 0, 3))
    O["n_total_3d"] = np.transpose((re**2 + im**2).sum(axis=0), (2, 1, 0, 3))
    O["t"] = np.zeros(NF)                          # mimic the extractor bug
    O["meta/F"] = 6; O["meta/NX"] = Nv; O["meta/L_box"] = L; O["meta/vol_stride"] = 1

goto = os.path.join(OUTDIR, "smoke_goto.h5")
with h5py.File(goto, "w") as O:
    O["t"] = t_int
    O["B_gauss"] = 0.01 * np.exp(-3 * t_int / t_int[-1])
    O["meta/omega_ref"] = omega_ref
print(f"[smoke] wrote {p13} and {goto} ({NF} frames, {Nv}^3)")
