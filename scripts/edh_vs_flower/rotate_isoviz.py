#!/usr/bin/env python3
"""Apply a quantization-axis tilt (RF rotation R=exp(-i β F_a)) to the FULL
13-component spinor at a chosen time, then render the ROTATED, m-mixed state
with the universal isoviz isosurface method.

This is the sim counterpart of the tilted-SG tomography step: the new m
populations are |[Rψ]_m|² = ⟨ψ|R†|m⟩⟨m|R|ψ⟩, i.e. the rotation mixes ALL m,
and we visualise the resulting per-m density isosurfaces (colour = relative
phase). Needs the FULL psi13 (not goto.h5, which has only 3 components).

env: PSI13 (full 13-comp), GOTO (for t/B/meta), T_MS (target time),
     AXIS (x|y), BETA_DEG, M_LIST, ISO_FRAC, OUT (png), OUT_H5 (rotated goto)
"""
import os, sys
import numpy as np
import h5py

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "v7_fable"))
sys.path.insert(0, HERE)
from v7_common import ms, rot, load_frames_bulk, psi13_nframes, open_psi13
import isoviz

PSI13 = os.environ.get("PSI13", "par_T90_psi13.jld2")
GOTO = os.environ.get("GOTO", "par_T90_goto.h5")
T_MS = float(os.environ.get("T_MS", "148"))
AXIS = os.environ.get("AXIS", "y")
BETA = float(os.environ.get("BETA_DEG", "16"))
M_LIST = tuple(int(x) for x in os.environ.get("M_LIST", "-6,-5,-4,-3,-2,-1,0").split(","))
ISO_FRAC = float(os.environ.get("ISO_FRAC", "0.05"))
OUT = os.environ.get("OUT", "iso_par_T90_tilt.png")
OUT_H5 = os.environ.get("OUT_H5", "par_T90_tilted_goto.h5")

# --- time axis + meta from goto (psi13's own t is zero-filled) ---
with h5py.File(GOTO, "r") as G:
    t = np.asarray(G["t"]); om = float(G["meta/omega_ref"][()])
    B = np.asarray(G["B_gauss"]) if "B_gauss" in G else np.zeros_like(t)
    meta = {k: np.asarray(G["meta"][k]).item() for k in G["meta"]}
t_ms = t / om * 1000.0
k = int(np.argmin(np.abs(t_ms - T_MS)))
print(f"[rot] target {T_MS} ms -> frame {k} (t={t_ms[k]:.1f} ms), R_{AXIS}({BETA}deg)")

P = open_psi13(PSI13)
nf = psi13_nframes(P)
if nf != len(t):
    print(f"[rot] WARN psi13 nf={nf} vs goto t={len(t)}; using min")
psi = load_frames_bulk(P, [k])[0]                      # (nx,ny,nz,13), c1->m=+6
R = rot(AXIS, BETA)
psip = np.einsum("mn,xyzn->xyzm", R, psi)              # rotated spinor
ntot = np.sum(np.abs(psip) ** 2, axis=-1)             # unitary => == pre-rotation

def store(A):                                          # (x,y,z) -> isoviz-read layout
    return np.transpose(A, (2, 1, 0))[..., None]

with h5py.File(OUT_H5, "w") as O:
    O["n_total_3d"] = store(ntot)
    for m in M_LIST:
        i = int(np.where(ms == m)[0][0])               # column index of m in ms=[6..-6]
        comp = psip[..., i]
        O[f"n_m{abs(m)}_3d"] = store(np.abs(comp) ** 2)
        O[f"arg_psi_m{abs(m)}_3d"] = store(np.angle(comp))
    O["t"] = np.array([t[k]]); O["B_gauss"] = np.array([B[k]])
    g = O.create_group("meta")
    for kk, vv in meta.items():
        g[kk] = vv
# report post-rotation populations
L = meta["L_box"]; NX = meta["NX"]; vs = meta.get("vol_stride", 1)
dV = (L / NX * vs) ** 3
Ntot = ntot.sum() * dV
print("[rot] post-tilt populations:")
for m in M_LIST:
    i = int(np.where(ms == m)[0][0])
    frac = 100 * (np.abs(psip[..., i]) ** 2).sum() * dV / Ntot
    print(f"   m={m:+d}: {frac:5.1f}%")

isoviz.render_isosurfaces(
    OUT_H5, frame=0, out=OUT, m_list=M_LIST, iso_frac=ISO_FRAC,
    lang="ja",
    title=f"EdH（最も綺麗・放物線ランプ）を t={t_ms[k]:.0f} ms で $R_{AXIS}$({BETA:.0f}°) 傾けた後の m 分布")
print(f"[rot] wrote {OUT}")
