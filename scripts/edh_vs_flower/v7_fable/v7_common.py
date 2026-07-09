#!/usr/bin/env python3
"""v7_EdH_Fable — shared physics/IO core.

GEOMETRY (locked, user decision 2026-07-02):
  camera line of sight = lab ŷ  (absorption imaging "from the side")
  SG separation axis   = lab ẑ  (gravity / vertical gradient)
  image plane          = (x, z); pixel data are column integrals ∫dy.
  Tilting the quantization axis is a SPIN-SPACE rotation only (adiabatic B
  rotation; spins follow B locally => uniform R applied to psi at every voxel).
  The spatial line of sight NEVER moves: multi-angle tilts scan the spin
  projection axis, not the spatial projection direction, so no new spatial
  information along y is created. See README_v7.md for the derivation.

ROTATION CONVENTION (locked; inherited from texture_tomo.py / AUDIT.py,
verified there to <1e-12 and re-verified in audit_v7.py):
  R_a(beta) = expm(-1j * beta * F_a)         (beta in radians)
  R_y(b)^dag Fz R_y(b) = cos(b) Fz - sin(b) Fx
  R_x(b)^dag Fz R_x(b) = cos(b) Fz + sin(b) Fy
5-SETTING PROTOCOL (theory note unified Part VI):
  identity, R_y(+16deg), R_y(-16deg), R_x(+16deg), R_x(-16deg)
  <Fz> = s(0)
  <Fx> = -(s(y,+16) - s(y,-16)) / (2 sin16)
  <Fy> = +(s(x,+16) - s(x,-16)) / (2 sin16)
  where s(k) = sum_m m N_m^(k) is the pixelwise centroid (spin-density weighted).
EXACT 90deg REFERENCE (3-image method):
  identity, R_y(-90deg) -> +Fx, R_x(+90deg) -> +Fy.

COMPONENT INDEXING: c=1 -> m=+6 ... c=13 -> m=-6 (ms = [6,5,...,-6]).
VISIBLE BLOCK (the experimental channels): m in {-6,-5,-4,-3} = c indices 12..9
(python 0-based: 9,10,11,12 with ms order above -> m=-3,-4,-5,-6).
"""
import os
import numpy as np
import h5py
from scipy.linalg import expm

F = 6
D = 2 * F + 1
ms = np.arange(F, -F - 1, -1)                      # [6, 5, ..., -6]
VISIBLE_MS = (-6, -5, -4, -3)
VISIBLE_IDX = np.array([int(np.where(ms == m)[0][0]) for m in VISIBLE_MS])  # [12,11,10,9]

# ---------------------------------------------------------------- spin algebra
def spin_operators(f=F):
    d = 2 * f + 1
    mvals = np.arange(f, -f - 1, -1)
    Fp = np.zeros((d, d))
    for i in range(d):
        m = mvals[i]
        if m < f:
            Fp[i - 1, i] = np.sqrt(f * (f + 1) - m * (m + 1))
    Fz = np.diag(mvals.astype(float))
    Fx = 0.5 * (Fp + Fp.T)
    Fy = (Fp - Fp.T) / (2j)
    return Fx, Fy, Fz

FX, FY, FZ = spin_operators()

def rot(axis, deg):
    """R_axis(deg) = expm(-i * radians(deg) * F_axis).  axis in {'x','y','id'}."""
    if axis == "id" or deg == 0.0:
        return np.eye(D, dtype=complex)
    op = {"x": FX, "y": FY}[axis]
    return expm(-1j * np.radians(deg) * op)

# ------------------------------------------------- configurable tilt protocol
# The protocol is a comma-separated token list, each token "id" or
# "<axis><signed angle deg>", e.g.  "id,y+16,y-16,x+16,x-16"  (the default),
# "id,y+13.8,y-13.8,x+13.8,x-13.8", "id,y+16,y-16,y+32,x+16,x-16,x+32", ...
# Axis in {x,y}. Override with env V7_TILT_SPEC / V7_HELDOUT_SPEC.
def parse_spec(spec):
    out = []
    for tok in spec.split(","):
        tok = tok.strip()
        if not tok:
            continue
        if tok == "id":
            out.append(("id", "id", 0.0))
        else:
            axis, val = tok[0], float(tok[1:])
            assert axis in ("x", "y"), f"bad tilt token {tok!r}"
            out.append((tok, axis, val))
    return out

TILT_DEG = 16.0  # default protocol angle (kept for docs/labels)
SETTINGS_5 = parse_spec(os.environ.get("V7_TILT_SPEC", "id,y+16,y-16,x+16,x-16"))
SETTINGS_EXACT = [("id", "id", 0.0), ("y-90", "y", -90.0), ("x+90", "x", +90.0)]
# held-out settings never used by any reconstruction (circularity breaker)
SETTINGS_HELDOUT = parse_spec(os.environ.get("V7_HELDOUT_SPEC", "y+30,x-30"))

def meas_direction(axis, deg):
    """Direction n such that R_a(b)^dag Fz R_a(b) = n . F  (exact identity).
    n = R_spatial(a, -b) ẑ. Anchors (verified in audit_v7):
      y: (-sin b, 0, cos b)     x: (0, +sin b, cos b)     id: (0,0,1)."""
    b = np.radians(deg)
    if axis == "id":
        return np.array([0.0, 0.0, 1.0])
    if axis == "y":
        return np.array([-np.sin(b), 0.0, np.cos(b)])
    if axis == "x":
        return np.array([0.0, np.sin(b), np.cos(b)])
    raise ValueError(axis)

def design_matrix(settings):
    """(nset,3) rows = measurement directions; centroid s_k = A_k . <F>."""
    return np.stack([meas_direction(a, d) for (_, a, d) in settings])

def recon_F_general(cents, settings):
    """Per-pixel least-squares inversion of s_k = n_k . <F> for ANY setting
    list (>=3 independent directions). cents: dict name->centroid image.
    Returns (fx, fy, fz, resid) where resid is the pixelwise rms of the
    least-squares residual ||A F - s|| — a data-internal consistency map
    (usable on real experimental data; ~0 for exact all-13-channel data,
    nonzero under visible-block truncation or noise)."""
    A = design_matrix(settings)
    if np.linalg.matrix_rank(A) < 3:
        raise ValueError("tilt spec spans <3 spin directions; cannot solve <F>")
    S = np.stack([cents[n] for (n, _, _) in settings])          # (nset,Nx,Nz)
    Ainv = np.linalg.pinv(A)                                    # (3,nset)
    Fxyz = np.einsum("ik,kxz->ixz", Ainv, S)
    resid = np.sqrt(np.mean((np.einsum("ki,ixz->kxz", A, Fxyz) - S) ** 2, axis=0))
    return Fxyz[0], Fxyz[1], Fxyz[2], resid

# ---------------------------------------------------------------- psi13 loader
def open_psi13(path):
    return h5py.File(path, "r")

def psi13_nframes(P):
    # raw h5py view of Julia (nf,nv,nv,nv) is (nv,nv,nv,nf): frame axis is LAST.
    return P["psi_re_c01"].shape[-1]

def psi13_ngrid(P):
    return P["psi_re_c01"].shape[0]

def load_component_full(P, c):
    """Entire dataset of ONE component, raw h5py layout (nv,nv,nv,nf) complex.
    Frame-axis-last hyperslab slicing ([:,:,:,fr]) on the contiguous storage
    degenerates to ~1e6 8-byte gathers per dataset (catastrophic on Lustre) —
    always read components WHOLE and slice in memory."""
    re = np.asarray(P[f"psi_re_c{c:02d}"])
    im = np.asarray(P[f"psi_im_c{c:02d}"])
    return re + 1j * im

def load_frame(P, fr):
    """Full spinor at one frame -> (Nx,Ny,Nz,13) complex128 (via whole-
    component reads; fine for a few frames / small files — for many frames
    use load_frames_bulk)."""
    return load_frames_bulk(P, [fr])[0]

def load_frames_bulk(P, frames):
    """Spinors at several frames -> (nsel,Nx,Ny,Nz,13) complex128, reading
    each component dataset exactly once (contiguous I/O)."""
    frames = list(frames)
    out = None
    for c in range(1, D + 1):
        full = load_component_full(P, c)                      # (nv,nv,nv,nf)
        sel = np.transpose(full, (2, 1, 0, 3))[..., frames]   # (x,y,z,nsel)
        if out is None:
            nv = sel.shape[0]
            out = np.zeros((len(frames), nv, nv, nv, D), complex)
        out[..., c - 1] = np.moveaxis(sel, -1, 0)
        del full
    return out

def frame_times_ms(goto_path, nf):
    """Times per psi13 frame, in ms. psi13's own 't' is zero-filled (extractor
    bug), so times come from goto.h5, which shares the same snapshot set."""
    with h5py.File(goto_path, "r") as G:
        t = np.asarray(G["t"])
        om = float(G["meta/omega_ref"][()])
        B = np.asarray(G["B_gauss"]) if "B_gauss" in G else None
    if len(t) != nf:
        raise RuntimeError(
            f"goto.h5 t has {len(t)} frames but psi13 has {nf}: "
            "frame axes do not correspond; refusing to guess.")
    return t / om * 1e3, (B if B is not None else np.full(nf, np.nan))

# ---------------------------------------------------------------- forward model
def sg_occupations(psi, R):
    """Tilted-SG occupation fields n_m^(R)(r) = |[R psi]_m|^2, (Nx,Ny,Nz,13)."""
    rp = np.einsum("mn,xyzn->xyzm", R, psi)
    return np.abs(rp) ** 2

def column_images(n_m, dy):
    """Absorption imaging along the lab-ŷ line of sight: ∫dy.
    (Nx,Ny,Nz,13) -> (Nx,Nz,13). THE defining projection of v7 geometry."""
    return n_m.sum(axis=1) * dy

# ---------------------------------------------------------------- reconstruction
def centroid_2d(images, idx=None):
    """Pixelwise centroid s = sum_m m N_m over channel subset idx (None=all 13).
    images: (Nx,Nz,13)."""
    if idx is None:
        return np.einsum("xzm,m->xz", images, ms.astype(float))
    return np.einsum("xzm,m->xz", images[..., idx], ms[idx].astype(float))

def recon_F_from_5(cents, tilt_deg=TILT_DEG):
    """Closed-form +-tilt difference formulas for the DEFAULT 5-setting spec
    (audit cross-check only — recon_F_general must reproduce this exactly):
      <Fz>=s(0), <Fx>=-(s(y,+)-s(y,-))/2sin b, <Fy>=+(s(x,+)-s(x,-))/2sin b."""
    s = np.sin(np.radians(tilt_deg))
    fz = cents["id"]
    fx = -(cents["y+16"] - cents["y-16"]) / (2 * s)
    fy = +(cents["x+16"] - cents["x-16"]) / (2 * s)
    return fx, fy, fz

def recon_F_from_exact(cents):
    """90deg 3-image reference: R_y(-90)->+Fx, R_x(+90)->+Fy."""
    return cents["y-90"], cents["x+90"], cents["id"]

def predict_centroid(fx, fy, fz, axis, deg):
    """Predict the centroid of ANY tilt setting from a reconstructed <F>
    field via s = n(axis,deg) . <F>. Held-out validation."""
    n = meas_direction(axis, deg)
    return n[0] * fx + n[1] * fy + n[2] * fz

# ---------------------------------------------------------------- truth fields
def spin_density_3d(psi):
    """True spin density fields f_i(r) = Re <psi|F_i|psi> per voxel."""
    def sd(Op):
        return np.real(np.einsum("xyzm,mn,xyzn->xyz", np.conj(psi), Op, psi,
                                 optimize=True))
    return sd(FX), sd(FY), sd(FZ)

# ------------------------------------------------- analytic coherent states
def coherent_field(nhat):
    """Spin-coherent spinor field zeta(n̂(r)): |F;n̂> = R_z(phi)R_y(theta)|F,+F>,
    so <F> = F n̂ exactly at every point. nhat: (...,3) -> (...,D).
    Built with expm per point (slow but convention-locked; smoke/audit only)."""
    th = np.arccos(np.clip(nhat[..., 2], -1, 1))
    ph = np.arctan2(nhat[..., 1], nhat[..., 0])
    e0 = np.zeros(D, complex); e0[0] = 1.0                    # c=1 -> m=+F
    sh = nhat.shape[:-1]
    zeta = np.zeros(sh + (D,), complex)
    for ix in np.ndindex(sh):
        Rm = expm(-1j * ph[ix] * FZ) @ expm(-1j * th[ix] * FY)
        zeta[ix] = Rm @ e0
    return zeta

# ---------------------------------------------------------------- metrics
def metrics(rec, tru, mask=None):
    a = rec[mask] if mask is not None else rec.ravel()
    b = tru[mask] if mask is not None else tru.ravel()
    diff = a - b
    denom = np.linalg.norm(b)
    return dict(rms=float(np.sqrt(np.mean(diff ** 2))),
                max=float(np.abs(diff).max()),
                rel_l2=float(np.linalg.norm(diff) / (denom + 1e-300)),
                corr=float(np.corrcoef(a, b)[0, 1]) if a.std() > 0 and b.std() > 0 else float("nan"))

# ---------------------------------------------------------------- grid helpers
def grid_axes(P):
    L = float(P["meta/L_box"][()])
    Ng = psi13_ngrid(P)
    ax = np.linspace(-L / 2, L / 2, Ng, endpoint=False)
    d = ax[1] - ax[0]
    return L, Ng, ax, d

def env(name, default):
    return os.environ.get(name, default)
