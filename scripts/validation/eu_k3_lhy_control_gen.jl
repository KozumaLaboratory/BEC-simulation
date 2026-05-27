#!/usr/bin/env julia
#
# eu_k3_lhy_control_gen.jl — K3=0 LHY model control runs.
# Per anko's Task #19C extension: to separate "LHY alone effect"
# from "LHY+K3 cooperation effect", we need the K3=0 row of the
# (K3, LHY) factorial.
#
# Existing cells (cigar regime, K3=200):
#   eu_k3_lhy/LHY_scalar.yaml
#   eu_k3_lhy/LHY_polar_contact.yaml
#   eu_k3_lhy/LHY_icosahedral.yaml
#   eu_k3_sweep/K3x200p0.yaml          (LHY=off baseline at K3=200)
#
# Missing (this script): cigar regime, K3=0, LHY ∈ {scalar, polar_contact,
# icosahedral}. The K3=0 LHY=off baseline already exists in
# eu_k3_sweep/K3x0p0.yaml.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_lhy_control")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0
const SAVE_EVERY = 50
const N_ATOMS = 30_000
const OMEGA_Z = 0.25

function _config_text(lhy_kind::String)
    return """
# K3=0 LHY model control — auto-generated.
# Source: scripts/validation/eu_k3_lhy_control_gen.jl
# LHY = $lhy_kind, K3 = 0, γ_dr = 0.
# Compare to eu_k3_lhy/LHY_$lhy_kind.yaml (same LHY, K3=200) to isolate
# LHY-alone vs LHY+K3 effects.

metadata:
  suite: eu_k3_lhy_control
  ladder_level: 12
  parent_regime: cigar_N30k_omz0p25
  K3_factor: 0
  LHY_kind: $lhy_kind
  generator: scripts/validation/eu_k3_lhy_control_gen.jl

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: 628.3}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $OMEGA_Z]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: 628.3
        c1_ratio: -0.005
      ddi:
        enabled: true
        secular: false
      lhy: {kind: $lhy_kind}
      B: {Bz: "-0.01 Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9

  - dynamics:
      duration: $T_EVOLUTION
      dt: 0.005
      B:
        Bz: {from: 0.01, to: 2.6e-5, duration: 0.0}
        theta: 0.0
        phi: 0.0
      ddi:
        secular: false
      lhy: {kind: $lhy_kind}
      # NO loss block — K3 = 0
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: $SAVE_EVERY
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

for kind in ("scalar", "polar_contact", "icosahedral")
    path = joinpath(OUTDIR, "LHY_$(kind)_K0.yaml")
    write(path, _config_text(kind))
    println("wrote LHY_$(kind)_K0.yaml")
end
