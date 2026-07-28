# Pure rotation-controlled Barnett: transverse (Jz=0) start.
#
# The m=+F run showed EdH-from-initial-spin (Jz=+6) dominates and the
# rotation only modulates (oscillatory, not clean direction control).
# Here we remove the initial-spin bias: GS with B along +x -> spin
# polarised in-plane (<F_z>=0, Jz_z=0). Then a field rotating around z
# at Omega drags the spin around z -> Barnett magnetisation along z
# (sign = Omega) + DDI-driven vortices (chirality = Omega). With Jz_z=0
# initially, ROTATION is the sole chirality source -> ±Omega give clean
# mirror images.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_transverse_barnett.jl

import CUDA
using SpinorBEC
using Printf

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
  # GS with B along +x -> spin polarised in-plane (<F_z>=0)
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: "-0.01 Gauss", By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 1.5707963267948966, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9
  # quench transverse field to weak + field rotating around z at Omega
  - dynamics:
      duration: 0.20
      dt: 0.0005
      ddi: {secular: false}
      B: {Bx: {from: 0.01, to: 2.13e-5, duration: 0.20}, By: 0.0, Bz: 0.0}
      save: {every: 400}
  - dynamics:
      duration: 25.0
      dt: 0.001
      ddi: {secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: 2.13e-5, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: 2.13e-5, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 500, psi: true, precision: f32}
"""
end

for Om in OMEGAS
    ypath = joinpath(SC, @sprintf("transv_O%+.2f.yaml", Om))
    open(ypath, "w") do io; write(io, yaml_for(Om)); end
    @printf("\n===== transverse-start Omega = %+.2f =====\n", Om)
    rundir = run_yaml(ypath)
    println("run dir: ", rundir)
end
println("TRANSVERSE_BARNETT_DONE")
