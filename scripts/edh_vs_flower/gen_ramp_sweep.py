#!/usr/bin/env python3
"""Generate the EdH magnetic-field RAMP-RATE sweep configs.

Physics question (user 2026-07-02): is a sudden quench really the best way to
drive EdH?  Sweep the descent dB/dt from a fast quench through gentle linear
ramps to a smooth parabolic (Flower-like) landing, and watch what EdH emerges
(Mermin-Ho residual, spin precession, orbital <Lz>, skyrmion charge).

NO long hold (user): each run = descent (10mG -> 26uG over T) + a short
OBSERVATION window (OBS internal units) at 26uG to let the transient develop.
64^3 / f64 compute (physics trend, not tomography -> cheap), f32 snapshots.
All runs load the SAME 64^3 c1=1/36 ground state cache.

Writes runs/eu151_edh_vs_flower/ramp_sweep/*.yaml
"""
import os, yaml, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUTD = os.path.join(ROOT, "runs", "eu151_edh_vs_flower", "ramp_sweep")
os.makedirs(OUTD, exist_ok=True)
GS_CACHE = "runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_64.jld2"
K3 = ["2.1e-41 m^6/s"] * 13
B0, BF = 0.01, 2.6e-5          # 10 mG -> 26 uG (Gauss)
OBS = 40.0                     # observation window after descent (internal units)
C1 = 1.0 / 36.0

MIX = {"eu151_edh_phys": {
    "atom": "Eu151",
    "grid": {"n": [64, 64, 64], "box": [18, 18, 18]},
    "potential": {"type": "harmonic", "omega": [1.0, 1.0, 1.182]},
    "interactions": {"N_atoms": 50000, "omega_ref": 691.15, "c1_ratio": C1}}}

def gs_step():
    return {"ground_state": {"use": ["eu151_edh_phys"], "method": "lbfgs",
                             "B": {"Bz": "0.01 Gauss"}, "n_steps": 1,
                             "tol": 1.0e-9, "cache": GS_CACHE}}

def obs_step():
    n_obs = max(1, int(round(OBS / 0.002 / 40)))     # ~40 obs frames
    return {"dynamics": {"duration": OBS, "dt": 0.002,
                         "B": {"Bz": "2.6e-5 Gauss"},
                         "seed_amplitude": 1.0e-8, "seed_k_cut": 2.5, "noise_seed": 42,
                         "loss": {"K3_per_m_si": K3},
                         "save": {"every": n_obs, "psi": True, "precision": "f32"}}}

def descent_linear(T):
    dt = 0.0005 if T <= 2.0 else 0.002
    n_save = max(1, int(round(T / dt / 40)))          # ~40 descent frames
    return {"dynamics": {"duration": T, "dt": dt,
                         "B": {"Bz": {"from": B0, "to": BF, "duration": T}},
                         "loss": {"K3_per_m_si": K3},
                         "save": {"every": n_save, "psi": True, "precision": "f32"}}}

def descent_parabola(T, npts=17):
    """Soft-landing parabola B(t)=BF+(B0-BF)(1-t/T)^2 (zero slope at t=T)."""
    t = np.linspace(0.0, T, npts)
    v = BF + (B0 - BF) * (1.0 - t / T) ** 2
    dt = 0.002
    n_save = max(1, int(round(T / dt / 40)))
    return {"dynamics": {"duration": T, "dt": dt,
                         "B": {"Bz": {"piecewise": {"times": [float(x) for x in t],
                                                    "values": [float(x) for x in v]}}},
                         "loss": {"K3_per_m_si": K3},
                         "save": {"every": n_save, "psi": True, "precision": "f32"}}}

def write(name, descent):
    cfg = {"defaults": {"kind": "spinor", "backend": "gpu",
                        "interactions": {"N_atoms": 50000, "omega_ref": 691.15}},
           "mixins": MIX,
           "pipeline": [gs_step(), descent, obs_step()]}
    path = os.path.join(OUTD, name + ".yaml")
    with open(path, "w") as f:
        yaml.safe_dump(cfg, f, sort_keys=False, default_flow_style=None)
    return path

# descent-duration axis (internal units; 1 = 1.447 ms)
LIN_T = [0.14, 2.0, 8.0, 30.0, 90.0]     # quench -> gentle
manifest = []
for T in LIN_T:
    tag = ("%g" % T).replace(".", "p")
    manifest.append(write(f"ramp_lin_T{tag}", descent_linear(T)))
manifest.append(write("ramp_par_T90", descent_parabola(90.0)))   # smooth (Flower-like) shape @ T=90

# manifest for the submit loop
with open(os.path.join(OUTD, "MANIFEST.txt"), "w") as f:
    for p in manifest:
        f.write(os.path.relpath(p, ROOT) + "\n")
print(f"wrote {len(manifest)} configs to {OUTD}")
for p in manifest:
    print("  " + os.path.basename(p))
