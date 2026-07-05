# Rotating-field-AMPLITUDE sweep (transverse Jz=0 start), Omega fixed=0.5.
# For the optimization graph: <L_z>,<F_z> amplitude vs field strength.
# t=15 (captures the peaks around t=4-7) to keep the sweep affordable.

import CUDA
using SpinorBEC
using Printf

# rotating-field amplitudes in Gauss
const AMPS = [0.5e-5, 1.0e-5, 2.13e-5, 4.0e-5, 8.0e-5, 1.6e-4]
const OMEGA = 0.5
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"

function yaml_for(amp)
    freq = OMEGA / (2π)
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
      B: {Bx: "-0.01 Gauss", By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 1.5707963267948966, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9
  - dynamics:
      duration: 0.20
      dt: 0.0005
      ddi: {secular: false}
      B: {Bx: {from: 0.01, to: $amp, duration: 0.20}, By: 0.0, Bz: 0.0}
      save: {every: 400}
  - dynamics:
      duration: 15.0
      dt: 0.001
      ddi: {secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $amp, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: $amp, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 300, psi: true, precision: f32}
"""
end

for amp in AMPS
    ypath = joinpath(SC, @sprintf("fieldsweep_A%.2e.yaml", amp))
    open(ypath, "w") do io; write(io, yaml_for(amp)); end
    @printf("\n===== field sweep amplitude = %.2e G (Omega=%.2f) =====\n", amp, OMEGA)
    rundir = run_yaml(ypath)
    println("run dir: ", rundir)
end
println("FIELD_SWEEP_DONE")
