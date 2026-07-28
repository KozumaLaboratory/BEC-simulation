# Direction-controlled rotating-field run (F=6 Eu, correct regime).
#
# m=-F polarised GS -> quench Bz to weak + apply a rotating transverse
# field B_perp(t) at Omega = {+O, 0, -O}. The rotating magnetization
# drives, via DDI, a rotating anisotropy that stirs the cloud: vortices
# nucleate with chirality set by the FIELD ROTATION direction, and the
# axial magnetization shifts (Barnett). UNITARY (no loss) so any change
# is coherent. Separate per-Omega runs (avoids the scan-override bug on
# sinusoidal.frequency).
#
# Each run's psi snapshots are analysed offline (analyze_barnett.jl) for
# <L_z>(t), winding-based vortex census, per-m populations.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_rotfield_dyn.jl

import CUDA
using SpinorBEC
using Printf

# Omega -> sinusoidal frequency (Omega = 2*pi*freq); sign flips direction.
const OMEGAS = [0.5, 0.0, -0.5]
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"

function yaml_for(Om)
    freq = Om / (2π)
    """
defaults:
  kind: spinor
  backend: gpu
  interactions: {N_atoms: 30000, omega_ref: 628.3}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bz: "-0.01 Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9
  # quench Bz strong->weak z-component of a 35deg tilted weak field
  - dynamics:
      duration: 0.20
      dt: 0.0005
      ddi: {secular: false}
      B: {Bz: {from: 0.01, to: 2.13e-5, duration: 0.20}, theta: 0.0, phi: 0.0}
      save: {every: 400}
  # weak Bz + rotating transverse field; NO loss
  - dynamics:
      duration: 25.0
      dt: 0.001
      ddi: {secular: false}
      B:
        Bz: "2.13e-5 Gauss"
        Bx: {sinusoidal: {amplitude: 1.49e-5, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: 1.49e-5, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 500, psi: true, precision: f32}
"""
end

for Om in OMEGAS
    ypath = joinpath(SC, @sprintf("rotfield_O%+.2f.yaml", Om))
    open(ypath, "w") do io; write(io, yaml_for(Om)); end
    @printf("\n===== rotating field Omega = %+.2f (freq=%.6f) =====\n", Om, Om/(2π))
    rundir = run_yaml(ypath)
    println("run dir: ", rundir)
end
println("ROTFIELD_DYN_DONE")
