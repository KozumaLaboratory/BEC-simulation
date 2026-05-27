#!/usr/bin/env julia
#
# barnett_week1_gen.jl — Barnett/Klaus ladder Week 1: scalar rotation
# benchmark. Minimal validation of the rotating-frame term -Ω·L_z
# using a scalar (single-component) BEC. No spinor physics. No DDI.
#
# Goal: validate that
#   - The L_z observable is computed correctly.
#   - Ω → 0 gives no rotation response (sanity).
#   - Ω > 0 produces vortex formation when Ω exceeds critical Ω_c
#     (or, at lower Ω, gradient response in ⟨L_z⟩).
#
# Per anko's Klaus/Barnett ladder Week 1: this is the rotating-frame
# foundation everything else builds on. No spinor + DDI yet.
#
# Two YAMLs:
#   scalar_rotation_omega0.yaml      — control (Ω = 0)
#   scalar_rotation_omega_scan.yaml  — Ω ∈ {0.0, 0.3, 0.5, 0.7, 0.9}
#
# The omega_scan is structured as a single config with a `scan:` block
# only if supported; otherwise the chain runner cycles through omega
# values via separate YAMLs. Keeping it simple: separate YAMLs per Ω.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "barnett_week1")
mkpath(OUTDIR)

function _config_text(omega::Float64)
    return """
# Barnett ladder Week 1 — scalar rotation benchmark.
# Source: scripts/validation/barnett_week1_gen.jl
# Ω = $omega  (rotating-frame angular velocity, in units of ω_ref).

metadata:
  suite: barnett_week1
  ladder_level: 0
  rotating_frame_omega: $omega
  generator: scripts/validation/barnett_week1_gen.jl
  notes: |
    Scalar (F=0) BEC in a 2D anisotropic harmonic trap.
    Rotating-frame term -Ω·L_z applied in the dynamics step.
    Validation target:
      - For Ω = 0: no L_z response.
      - For Ω > 0: vortex formation expected above Ω_c ≈ 0.7 ω_⊥
        (Madison-Dalibard critical line; rough estimate).

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: 5000, omega_ref: 100.0}

pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [32, 32, 32], box: [10.0, 10.0, 10.0]}
      # 2D-like anisotropic trap (pancake). The y/x slight anisotropy
      # breaks rotation symmetry → vortex formation possible at large Ω.
      potential: {type: harmonic, omega: [1.0, 1.05, 4.0]}
      interactions:
        N_atoms: 5000
        omega_ref: 100.0
        c1_ratio: 0.0                            # scalar regime
      ddi:
        enabled: false
      lhy: {kind: none}
      B: {Bz: 0.0}
      initial_state: m_plus_F
      init_sigma: 1.5
      dt: 0.01
      n_steps: 2000
      tol: 1.0e-9

  - dynamics:
      duration: 20.0
      dt: 0.005
      rotating_frame_omega: $omega               # rotating-frame term
      ddi: {enabled: false}
      lhy: {kind: none}
      seed_amplitude: 1.0e-5
      seed_k_cut: 2.5
      save:
        every: 200
        psi: true
        precision: f64

  - analyze:
      - energy_decomposition: {}
"""
end

const OMEGA_LIST = (0.0, 0.3, 0.5, 0.7, 0.9)

for omega in OMEGA_LIST
    name = "scalar_rotation_om$(replace(string(omega), "." => "p")).yaml"
    path = joinpath(OUTDIR, name)
    write(path, _config_text(omega))
    println("wrote $name (Ω=$omega)")
end
