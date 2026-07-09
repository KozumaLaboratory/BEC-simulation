#!/usr/bin/env python3
"""v7_EdH_Fable — adversarial AUDIT (hallucination firewall).

Every check is designed to FAIL LOUDLY if a sign / factor / axis / indexing
bug exists anywhere in the v7 chain. Checks 1-3 are self-contained (no data
files); 4-7 audit the actual raw/recon files. Exit code != 0 on any hard
failure. Soft (expected-bias) quantities are printed, not asserted.

 1  operator algebra           [Fx,Fy]=iFz (cyclic), F^2=F(F+1)I
 2  rotation identities        R unitary; Ry(b)+FzRy(b)=cos b Fz - sin b Fx,
                               Rx(b)+FzRx(b)=cos b Fz + sin b Fy  (b=16,30,90)
 3  analytic end-to-end        spin-coherent psi(r) with KNOWN <F>(r)=6 n̂(r)
                               (nontrivial y-dependence) pushed through the
                               REAL sg_forward/recon functions, incl. column
                               integration: 5set_all13 and exact90 must hit
                               machine precision vs the analytic column truth.
 4  unitarity in the data      per-pixel total number identical across ALL
                               tilt settings in sg_raw_v7.h5 (all13)
 5  Fz-consistency maps        cos-averaged +-16 centroids == s(0) (all13)
 6  held-out angles            y+30/x-30 residuals ~ 0 (all13; never used in
                               the reconstruction -> breaks circularity)
 7  global conservation        sum over id all13 centroid image * dx*dz ==
                               global <Fz> from the psi trace; visible-only
                               deficit printed (leakage, expected physics)

env: RAW, RECON  (checks 4-7 skipped if RAW is absent)
"""
import os, sys
import numpy as np
import h5py

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v7_common import (F, D, ms, VISIBLE_IDX, FX, FY, FZ, rot, spin_operators,
                       sg_occupations, column_images, centroid_2d,
                       recon_F_from_5, recon_F_general, recon_F_from_exact,
                       meas_direction, SETTINGS_5, SETTINGS_EXACT,
                       coherent_field, env)

FAILURES = []
def check(name, ok, detail=""):
    tag = "PASS" if ok else "FAIL"
    print(f"[audit] {tag}  {name}  {detail}")
    if not ok:
        FAILURES.append(name)

# ------------------------------------------------------------ 1 operator algebra
comm = FX @ FY - FY @ FX
check("1a [Fx,Fy]=iFz", np.abs(comm - 1j * FZ).max() < 1e-12,
      f"max|.|={np.abs(comm - 1j * FZ).max():.1e}")
F2 = FX @ FX + FY @ FY + FZ @ FZ
check("1b F^2=F(F+1)I", np.abs(F2 - F * (F + 1) * np.eye(D)).max() < 1e-11)

# ------------------------------------------------------------ 2 rotation identities
for b in (16.0, 30.0, 90.0, -16.0, 47.3):
    br = np.radians(b)
    Ry = rot("y", b); Rx = rot("x", b)
    check(f"2a Ry({b}) unitary", np.abs(Ry @ Ry.conj().T - np.eye(D)).max() < 1e-12)
    ey = np.abs(Ry.conj().T @ FZ @ Ry - (np.cos(br) * FZ - np.sin(br) * FX)).max()
    ex = np.abs(Rx.conj().T @ FZ @ Rx - (np.cos(br) * FZ + np.sin(br) * FY)).max()
    check(f"2b Ry({b}) reads -sin*Fx", ey < 1e-12, f"max={ey:.1e}")
    check(f"2c Rx({b}) reads +sin*Fy", ex < 1e-12, f"max={ex:.1e}")
    # 2d meas_direction anchors: R^dag Fz R must equal n.F for the SAME n used
    # by the least-squares reconstruction (kills any axis/sign drift between
    # forward model and inversion)
    for axis, Rm in (("y", Ry), ("x", Rx)):
        n = meas_direction(axis, b)
        e = np.abs(Rm.conj().T @ FZ @ Rm - (n[0] * FX + n[1] * FY + n[2] * FZ)).max()
        check(f"2d n({axis},{b}).F identity", e < 1e-12, f"max={e:.1e}")

# ------------------------------------------------------------ 3 analytic end-to-end
def coherent_state(nhat):
    """|F; n̂> via rotation of |m=+F>: R_z(phi)R_y(theta)|F,F> -> <F>=F n̂."""
    th = np.arccos(np.clip(nhat[..., 2], -1, 1))
    ph = np.arctan2(nhat[..., 1], nhat[..., 0])
    # zeta_m = D^F_{m,F}(phi,theta,0); build by rotating e_+F with expm per point
    e0 = np.zeros(D, complex); e0[0] = 1.0                  # m=+6 first
    sh = nhat.shape[:-1]
    zeta = np.zeros(sh + (D,), complex)
    it = np.ndindex(sh)
    from scipy.linalg import expm
    for ix in it:
        Rm = expm(-1j * ph[ix] * FZ) @ expm(-1j * th[ix] * FY)
        zeta[ix] = Rm @ e0
    return zeta

Ngs = 14
ax = np.linspace(-1.5, 1.5, Ngs)
X, Y, Z = np.meshgrid(ax, ax, ax, indexing="ij")
amp = np.exp(-(X**2 + Y**2 + Z**2))
# direction field with genuine x,y,z dependence (incl. line-of-sight y)
theta = 0.7 * np.exp(-(X**2 + Z**2)) * (1 + 0.5 * np.sin(2.1 * Y))
phi = np.arctan2(Z, X) + 0.6 * Y
nhat = np.stack([np.sin(theta) * np.cos(phi),
                 np.sin(theta) * np.sin(phi),
                 np.cos(theta)], axis=-1)
psi = amp[..., None] * coherent_state(nhat)
dya = ax[1] - ax[0]
truth_col = {c: (F * amp**2 * nhat[..., i]).sum(axis=1) * dya
             for i, c in enumerate(("fx", "fy", "fz"))}
imgs = {}
for name, axis, deg in SETTINGS_5 + [s for s in SETTINGS_EXACT if s[0] != "id"]:
    imgs[name] = column_images(sg_occupations(psi, rot(axis, deg)), dya)
cents = {k: centroid_2d(v) for k, v in imgs.items()}
fx5, fy5, fz5, resid5 = recon_F_general(cents, SETTINGS_5)
fxE, fyE, fzE = recon_F_from_exact(cents)
scale = np.abs(truth_col["fz"]).max()
for lbl, rec, tru in (("protocol fx", fx5, truth_col["fx"]),
                      ("protocol fy", fy5, truth_col["fy"]),
                      ("protocol fz", fz5, truth_col["fz"]),
                      ("exact90 fx", fxE, truth_col["fx"]),
                      ("exact90 fy", fyE, truth_col["fy"])):
    e = np.abs(rec - tru).max() / scale
    check(f"3 analytic end-to-end {lbl}", e < 1e-10, f"rel={e:.1e}")
check("3b lsq residual ~0 (all13 exact data)", resid5.max() / scale < 1e-10,
      f"rel={resid5.max() / scale:.1e}")
# 3c: general pinv inversion must reproduce the closed-form +-16 difference
# formulas when the spec IS the default (two independent derivations agree)
names5 = {n for n, _, _ in SETTINGS_5}
if names5 == {"id", "y+16", "y-16", "x+16", "x-16"}:
    fxd, fyd, fzd = recon_F_from_5(cents)
    e = max(np.abs(fx5 - fxd).max(), np.abs(fy5 - fyd).max(),
            np.abs(fz5 - fzd).max()) / scale
    check("3c pinv == closed-form +-16 formulas", e < 1e-10, f"rel={e:.1e}")
else:
    print(f"[audit] info: non-default tilt spec {sorted(names5)} -> 3c skipped")
# visible-block truncation bias on the analytic state (reported, not asserted)
cv = {k: centroid_2d(v, VISIBLE_IDX) for k, v in imgs.items()}
fxv, fyv, fzv, _ = recon_F_general(cv, SETTINGS_5)
print(f"[audit] info: analytic visible-block bias rel={np.abs(fzv - truth_col['fz']).max() / scale:.2e} "
      "(expected: state points near +z here, so visible m=-6..-3 sees little; "
      "the EdH state points near -z where the block covers ~90%)")

# ------------------------------------------------------------ 4-7 data audits
RAW = env("RAW", "")
RECON = env("RECON", "")
if RAW and os.path.exists(RAW):
    Rw = h5py.File(RAW, "r")
    FRAMES = list(np.asarray(Rw["frames_selected"]))
    dx = float(Rw["meta/dx"][()])
    for fr in FRAMES:
        g = Rw[f"frames/f{fr:04d}/sim_only_all13"]
        tots = {name: np.asarray(g[name]).sum(axis=-1) for name in g}
        ref = tots["id"]
        worst = max(np.abs(v - ref).max() for k, v in tots.items() if k != "id")
        check(f"4 unitarity f{fr:04d}", worst / ref.max() < 1e-9,
              f"rel={worst / ref.max():.1e}")
        # 7: global <Fz> from image vs psi trace
        cid = centroid_2d(np.asarray(g["id"]))
        Fz_img = cid.sum() * dx * dx
        tr = Rw["trace"]
        Fz_tr = float(np.asarray(tr["sz"])[fr] * np.asarray(tr["N"])[fr])
        check(f"7 global <Fz> f{fr:04d}", abs(Fz_img - Fz_tr) / (abs(Fz_tr) + 1e-30) < 1e-8,
              f"img={Fz_img:.6f} trace={Fz_tr:.6f}")
        cvis = centroid_2d(np.asarray(g["id"]), VISIBLE_IDX)
        print(f"[audit] info: f{fr:04d} visible-only global <Fz> deficit = "
              f"{(cid.sum() - cvis.sum()) * dx * dx:+.4f} (leakage-carried spin; "
              "conservation must use ALL channels)")
    if RECON and os.path.exists(RECON):
        Rc = h5py.File(RECON, "r")
        for fr in FRAMES:
            og = Rc[f"frames/f{fr:04d}"]
            scale = np.abs(np.asarray(og["col/fz_protocol_all13"])).max() + 1e-30
            e5 = np.asarray(og["col/lsq_resid_all13"]).max()
            check(f"5 lsq consistency f{fr:04d} (all13)", e5 / scale < 1e-9,
                  f"rel={e5 / scale:.1e}")
            ev = np.asarray(og["col/lsq_resid_vis"]).max()
            print(f"[audit] info: f{fr:04d} vis lsq residual rel={ev / scale:.2e} (truncation)")
            held = [k.split("_residual_")[0] for k in og["heldout"]
                    if k.endswith("_residual_all13")]
            eh = max(np.abs(np.asarray(og[f"heldout/{n}_residual_all13"])).max()
                     for n in held)
            check(f"6 held-out f{fr:04d} (all13)", eh / scale < 1e-9,
                  f"rel={eh / scale:.1e}")
            ehv = max(np.abs(np.asarray(og[f"heldout/{n}_residual_vis"])).max()
                      for n in held)
            print(f"[audit] info: f{fr:04d} vis held-out rel={ehv / scale:.2e}")
else:
    print("[audit] RAW not provided/found -> data checks 4-7 skipped (self-contained 1-3 only)")

print(f"\n[audit] {'ALL PASS' if not FAILURES else 'FAILURES: ' + ', '.join(FAILURES)}")
sys.exit(1 if FAILURES else 0)
