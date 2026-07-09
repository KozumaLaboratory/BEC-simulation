#!/usr/bin/env python3
"""Tsubame-side bridge: spin3d.jld2 (from extract_3d.jl, already has all 3-D fields
in the goto on-disk layout) -> goto-format h5 that the PROVEN viz scripts read.
Copies the 3-D fields UNCHANGED (proven scripts transpose(3,2,1,0)); ADDS:
  t       : from the diag jld2 (same frame count for tstride=1 runs)
  B_gauss : analytic from the EdH quench ramp (leg1 10mG->26uG over dur, then hold)
  meta/omega_ref : 691.15
Usage: python make_goto_tsubame.py <spin3d.jld2> <diag.jld2> <out_goto.h5> \
         [--quench_dur 0.14] [--B0 0.01] [--B1 2.6e-5] [--omega 691.15]
"""
import sys, numpy as np, h5py
spin, diag, out = sys.argv[1], sys.argv[2], sys.argv[3]
def opt(flag, d):
    return float(sys.argv[sys.argv.index(flag)+1]) if flag in sys.argv else d
QD=opt("--quench_dur",0.14); B0=opt("--B0",0.01); B1=opt("--B1",2.6e-5); OM=opt("--omega",691.15)
S=h5py.File(spin,"r"); D=h5py.File(diag,"r")
t=np.asarray(D["t"]).astype(float)                       # internal time per frame
nf=len(t)
# B(t): linear quench leg1 (t<=QD), hold B1 after
Bg=np.where(t<=QD, B0+(B1-B0)*np.clip(t/QD,0,1), B1).astype(float)
FIELDS=["n_total_3d","Fx_3d","Fy_3d","Fz_3d","n_m6_3d","n_m5_3d","n_m4_3d",
        "arg_psi_m6_3d","arg_psi_m5_3d","arg_psi_m4_3d"]
with h5py.File(out,"w") as o:
    for k in FIELDS:
        if k in S: o[k]=np.asarray(S[k])                 # copy UNCHANGED (layout preserved)
    o["t"]=t; o["B_gauss"]=Bg
    g=o.create_group("meta")
    for mk in ("F","NX","L_box","vol_stride"):
        if "meta" in S and mk in S["meta"]: g[mk]=np.asarray(S["meta"][mk])
    g["omega_ref"]=OM
print(f"wrote {out}  ({nf} frames, B {Bg[0]:.4g}->{Bg[-1]:.4g} G, t {t[0]:.3g}->{t[-1]:.3g})")
