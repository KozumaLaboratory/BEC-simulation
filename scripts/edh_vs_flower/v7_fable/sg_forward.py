#!/usr/bin/env python3
"""v7_EdH_Fable stage 1 — FORWARD MODEL: generate the synthetic experimental
raw data (tilted-SG absorption images) from the truth wavefunction.

For each selected frame and each tilt setting (axis a, angle b):
  1. adiabatic quantization-axis tilt  = spin-space rotation R = expm(-i b F_a)
     applied uniformly at every voxel (spins follow B; space untouched),
  2. Stern-Gerlach sorts by m along lab ẑ,
  3. absorption imaging along lab ŷ: N_m(x,z) = ∫dy |[R psi]_m(r)|^2.
The per-m pixel images (compute grid = image grid, 96x96, f64, no floor)
are THE observables. Everything downstream (recon_from_pixels.py) reads ONLY
the raw file. Full-13-channel images are stored under sim_only/ (an experiment
sees only the visible block m=-6..-3); settings are tagged by purpose:
  protocol  = the 5-setting +-16deg recipe (the experiment)
  exact90   = 90deg 3-image reference (upper bound / error breakdown)
  heldout   = never used by any reconstruction (circularity breaker)

Frame selection: scans the global per-atom spin trace over ALL frames and
picks ~5 representative epochs (initial / rising / max transverse tilt /
relaxing / late hold). Override with FRAMES=comma,separated,indices.

env: PSI13, GOTO, OUT (sg_raw_v7.h5), OUTDIR (figures), FRAMES (optional)
"""
import os, sys, json
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import (D, ms, VISIBLE_IDX, VISIBLE_MS, FX, FY, FZ, rot,
                       SETTINGS_5, SETTINGS_EXACT, SETTINGS_HELDOUT,
                       open_psi13, psi13_nframes, load_frames_bulk,
                       frame_times_ms, sg_occupations, column_images,
                       grid_axes, env)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PSI13 = env("PSI13", "edh_v6_psi13.jld2")
GOTO = env("GOTO", "goto.h5")
OUT = env("OUT", "sg_raw_v7.h5")
OUTDIR = env("OUTDIR", os.path.dirname(OUT) or ".")
os.makedirs(OUTDIR, exist_ok=True)

P = open_psi13(PSI13)
nf = psi13_nframes(P)
L, Ng, ax1d, dx = grid_axes(P)
dy = dx
t_ms, B_gauss = frame_times_ms(GOTO, nf)
print(f"[sg_forward] psi13={PSI13} nf={nf} grid={Ng}^3 box={L}")

# ---------------------------------------------------------------- global trace
def global_trace():
    """Global N(t), <F_i>(t) AND the winding-proof transverse measure
    sperp_loc(t) = ∫|f_perp(r)| dV / N for ALL frames, streaming one component
    dataset at a time (contiguous reads). Local transverse spin density is
    f_perp = <F+> density: f_x+i f_y = sum_i lambda_i psi*_{i-1} psi_i, so
    adjacent-component products suffice; a running voxelwise accumulator
    keeps |f_perp|(r,t) without ever holding the full spinor.

    WHY sperp_loc: the EdH texture carries azimuthal phase winding, so the
    VOLUME INTEGRAL of the transverse spin cancels (~0 at all times) even
    when the local tilt is large — the signed global trace is winding-blind
    and CANNOT be used for epoch selection (bug caught on the first 96^3 run:
    peak |<F_perp>|=0.000). The cancellation itself is physics (vortex
    signature) and both traces are stored."""
    from v7_common import F as Fq, load_component_full
    dV = dx ** 3
    N = np.zeros(nf); fz = np.zeros(nf)
    fplus_vox = None                               # (nv,nv,nv,nf) complex
    prev = None
    for ci in range(len(ms)):                      # ci: 0-based, m = ms[ci]
        cur = load_component_full(P, ci + 1)       # (nv,nv,nv,nf) raw layout
        nc = np.sum(np.abs(cur) ** 2, axis=(0, 1, 2))
        N += nc; fz += ms[ci] * nc
        if prev is not None:
            lam = np.sqrt(Fq * (Fq + 1) - ms[ci] * (ms[ci] + 1))
            if fplus_vox is None:
                fplus_vox = np.zeros(cur.shape, complex)
            fplus_vox += lam * np.conj(prev) * cur
        prev = cur
        print(f"  trace component {ci + 1}/{len(ms)}", flush=True)
    del prev, cur
    fplus = np.sum(fplus_vox, axis=(0, 1, 2)) * dV          # signed integral
    sperp_loc = np.sum(np.abs(fplus_vox), axis=(0, 1, 2)) * dV  # winding-proof
    del fplus_vox
    N *= dV; fz *= dV
    fx = np.real(fplus); fy = np.imag(fplus)       # <Fx>=Re<F+>, <Fy>=Im<F+>
    sz = fz / N
    sperp = np.hypot(fx / N, fy / N)               # winding-blind (kept for record)
    return N, sz, sperp, fx / N, fy / N, sperp_loc / N

N_t, sz_t, sperp_t, sx_t, sy_t, sperp_loc_t = global_trace()

# ---------------------------------------------------------------- frame choice
def select_frames():
    ov = os.environ.get("FRAMES")
    if ov:
        return sorted({int(s) for s in ov.split(",")}), "env override"
    # selection metric = winding-proof local transverse magnitude sperp_loc
    pk = int(np.argmax(sperp_loc_t))
    peak = sperp_loc_t[pk]
    rise = next((i for i in range(pk + 1) if sperp_loc_t[i] >= 0.5 * peak), 0)
    relax = next((i for i in range(pk, nf) if sperp_loc_t[i] <= 0.4 * peak), nf - 1)
    sel = sorted({0, rise, pk, relax, nf - 1})
    return sel, (f"auto on ∫|f_perp|dV/N: init/rise(0.5pk)/peak/relax(0.4pk)/last, "
                 f"peak={peak:.3f}@fr{pk} (signed |<F_perp>| peak={sperp_t.max():.3f} — winding-cancelled)")

FRAMES, why = select_frames()
print(f"[sg_forward] frames {FRAMES}  ({why})")

# frame-selection trace figure
fig, axs = plt.subplots(3, 1, figsize=(9, 7), sharex=True)
axs[0].plot(t_ms, sperp_loc_t, "-", lw=1.5, color="crimson",
            label=r"$\int |f_\perp|\,dV/N$ (winding-proof)")
axs[0].plot(t_ms, sperp_t, "--", lw=1.2, color="gray",
            label=r"$|\int \vec f_\perp\,dV|/N$ (winding-cancelled)")
axs[0].legend(fontsize=8)
axs[0].set_ylabel(r"transverse spin per atom")
axs[1].plot(t_ms, sz_t, "-", lw=1.5, color="navy")
axs[1].set_ylabel(r"$\langle s_z\rangle$ per atom")
axs[2].plot(t_ms, N_t / N_t[0], "-", lw=1.5, color="darkgreen")
axs[2].set_ylabel(r"$N(t)/N(0)$"); axs[2].set_xlabel("t [ms]")
for a in axs:
    for fr in FRAMES:
        a.axvline(t_ms[fr], color="0.6", ls="--", lw=0.8)
    a.grid(alpha=0.3)
for fr in FRAMES:
    axs[0].annotate(f"fr{fr}\n{t_ms[fr]:.1f}ms", (t_ms[fr], sperp_loc_t[fr]),
                    fontsize=7, ha="center", va="bottom")
axs[0].set_title(f"EdH global spin trace and imaging epochs  ({why})", fontsize=10)
fig.tight_layout()
fig.savefig(os.path.join(OUTDIR, "v7_frame_selection.png"), dpi=140)
plt.close(fig)

# ---------------------------------------------------------------- raw data gen
ALL_SETTINGS = ([(n, a, b, "protocol") for (n, a, b) in SETTINGS_5]
                + [(n, a, b, "exact90") for (n, a, b) in SETTINGS_EXACT if n != "id"]
                + [(n, a, b, "heldout") for (n, a, b) in SETTINGS_HELDOUT])

with h5py.File(OUT, "w") as O:
    g = O.create_group("meta")
    g["geometry"] = ("line_of_sight=lab_y; SG_separation=lab_z; image_plane=(x,z); "
                     "column integral = sum over array axis 1 * dy")
    g["convention"] = ("R_a(b)=expm(-1j*radians(b)*F_a); "
                       "Ry(b)^dag Fz Ry(b)=cos(b)Fz-sin(b)Fx; "
                       "Rx(b)^dag Fz Rx(b)=cos(b)Fz+sin(b)Fy; c=1->m=+6..c=13->m=-6")
    g["L_box"] = L; g["Ng"] = Ng; g["dx"] = dx; g["dy"] = dy
    g["tilt_deg"] = 16.0
    g["visible_ms"] = np.array(VISIBLE_MS)
    g["ms"] = ms
    g["psi13_path"] = PSI13; g["goto_path"] = GOTO
    st = O.create_group("settings")
    st["name"] = np.array([s[0] for s in ALL_SETTINGS], dtype="S16")
    st["axis"] = np.array([s[1] for s in ALL_SETTINGS], dtype="S4")
    st["angle_deg"] = np.array([s[2] for s in ALL_SETTINGS])
    st["purpose"] = np.array([s[3] for s in ALL_SETTINGS], dtype="S16")
    tr = O.create_group("trace")
    tr["t_ms"] = t_ms; tr["B_gauss"] = B_gauss; tr["N"] = N_t
    tr["sz"] = sz_t; tr["sperp"] = sperp_t; tr["sx"] = sx_t; tr["sy"] = sy_t
    tr["sperp_loc"] = sperp_loc_t
    O["frames_selected"] = np.array(FRAMES)

    PSIS = load_frames_bulk(P, FRAMES)       # one contiguous pass over the file
    for k, fr in enumerate(FRAMES):
        psi = PSIS[k]
        fg = O.create_group(f"frames/f{fr:04d}")
        fg["t_ms"] = t_ms[fr]; fg["B_gauss"] = B_gauss[fr]
        for name, axis, deg, purpose in ALL_SETTINGS:
            n_m = sg_occupations(psi, rot(axis, deg))
            img = column_images(n_m, dy)                    # (Nx,Nz,13)
            fg[f"visible/{name}"] = img[..., VISIBLE_IDX]   # (Nx,Nz,4) experiment
            fg[f"sim_only_all13/{name}"] = img              # (Nx,Nz,13) sim only
        # total column density from the untilted setting (experiment-available
        # only as the sum of visible channels; all13 sum stored as sim_only)
        print(f"  frame f{fr:04d} ({t_ms[fr]:.1f} ms): {len(ALL_SETTINGS)} settings", flush=True)

sel = {"frames": FRAMES, "t_ms": [float(t_ms[f]) for f in FRAMES], "why": why}
with open(os.path.join(OUTDIR, "v7_frames_selected.json"), "w") as fjs:
    json.dump(sel, fjs, indent=1)
print(f"[sg_forward] wrote {OUT} and {OUTDIR}/v7_frame_selection.png")
