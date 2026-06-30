#!/usr/bin/env python3
"""Bridge: adapt new-scheme spin3d.jld2 -> goto-format h5 the PROVEN scripts read.
The spin3d already has every 3-D field in the right on-disk layout (JLD2; the
proven scripts transpose(3,2,1,0)). We only ADD what they additionally need:
  t        : real internal-time per frame, taken from the trustworthy diag
             (frame map t3[i] = diag_t[2i], validated to 1e-4 against <Fz>)
  B_gauss  : reconstructed analytically from the YAML B-ramp of each leg
  meta/omega_ref : 691.15  (internal-unit reference, from the run config)
3-D fields are copied through UNCHANGED so the proven transpose stays correct.
"""
import os, numpy as np, h5py

SCR = os.path.dirname(os.path.abspath(__file__))
DIAG = os.path.join(os.path.expanduser("~"),
    "Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/"
    "runs/eu151_edh_vs_flower/figures/newscheme_8004024")
OMEGA = 691.15
FIELDS = ["Fx_3d","Fy_3d","Fz_3d","n_total_3d",
          "n_m6_3d","n_m5_3d","n_m4_3d",
          "arg_psi_m6_3d","arg_psi_m5_3d","arg_psi_m4_3d"]

def B_edh(tau):
    # quench 0.01 -> 2.6e-5 Gauss over duration 0.14 (internal), then hold
    return np.where(tau <= 0.14, 0.01 + (2.6e-5 - 0.01)*(tau/0.14), 2.6e-5)

FLO_T = np.array([0.0,6.912,13.823,20.735,27.646,29.028,30.411,31.793,33.175,
    34.558,51.836,69.115,86.394,103.673,120.951,138.230,155.509,172.788,189.375])
FLO_V = np.array([0.01,0.0082,0.0064,0.0046,0.0028,0.00216398,0.00166598,
    0.00130598,0.00108398,0.001,0.000821516,0.000660563,0.000517141,0.00039125,
    0.000282891,0.000192063,0.000118766,6.3001e-05,2.59597e-05])
def B_flower(t):
    b = np.interp(t, FLO_T, FLO_V)
    return np.where(t > FLO_T[-1], 2.6e-5, b)

def bridge(leg, spin, diag, Bfun):
    s = h5py.File(os.path.join(SCR, spin), "r")
    d = h5py.File(os.path.join(DIAG, diag), "r")
    dt = np.asarray(d["t"]); nf = s["Fz_3d"].shape[-1]
    t_int = dt[np.clip(np.arange(nf)*2, 0, len(dt)-1)]      # validated frame map
    Bg = Bfun(t_int).astype(np.float64)
    out = os.path.join(SCR, f"{leg}_goto.h5")
    with h5py.File(out, "w") as o:
        for k in FIELDS:
            o.create_dataset(k, data=s[k][:])               # copy UNCHANGED
        o.create_dataset("t", data=t_int.astype(np.float64))
        o.create_dataset("B_gauss", data=Bg)
        g = o.create_group("meta")
        g["omega_ref"] = np.float64(OMEGA)
        g["L_box"] = np.float64(s["meta/L_box"][()])
        g["NX"] = np.int64(s["meta/NX"][()])
        g["vol_stride"] = np.int64(s["meta/vol_stride"][()])
        g["F"] = np.int64(s["meta/F"][()])
    print(f"{leg}: wrote {out}  nf={nf}  t={t_int[0]/OMEGA*1000:.1f}->{t_int[-1]/OMEGA*1000:.1f}ms"
          f"  B={Bg[0]*1e3:.2f}->{Bg[-1]*1e6:.2f}  (mG->uG)")

bridge("edh", "edh_spin3d.jld2", "edh_diag.jld2", B_edh)
bridge("flower", "flower_spin3d.jld2", "flower_diag.jld2", B_flower)
