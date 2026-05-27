#!/usr/bin/env julia
#
# eu_k3_sweep_96_gen.jl — 96³ anchor for K3 = 150, 200 (operational
# transition pair from 32³ Task #19B). GPU backend (CPU 96³ would
# be ≥ 1 h/cell). Aims to confirm whether the 32³ "150 delay /
# 200 sacrificial_arrest" split survives at higher resolution.
#
# All other parameters match runs/eu_k3_sweep/K3x{150,200}p0.yaml.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_sweep_96")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0
const SAVE_EVERY = 50
const N_ATOMS = 30_000
const OMEGA_Z = 0.25
const K3_BASE_SI = 1.0e-41

function _k3_list(factor::Float64)
    val = factor * K3_BASE_SI
    entries = ["\"" * string(val) * " m^6/s\"" for _ in 1:13]
    "[" * join(entries, ", ") * "]"
end

function _config_text(factor::Float64)
    loss_block = if factor > 0
        "      loss:\n        K3_per_m_si:\n          $(_k3_list(factor))\n"
    else
        ""
    end
    return """
# 96³ anchor — auto-generated for Task #19B operational-transition confirm.
# K3_factor = $(factor) × Dy proxy = $(factor * K3_BASE_SI) m⁶/s.
# Geometry: cigar (N=$N_ATOMS, ω_z=$OMEGA_Z). LHY off, γ_dr off.
metadata:
  suite: eu_k3_sweep_96
  ladder_level: 12
  parent_regime: cigar_N30k_omz0p25
  K3_factor: $factor
  K3_per_m_si_value: $(factor * K3_BASE_SI)
  generator: scripts/validation/eu_k3_sweep_96_gen.jl

defaults:
  kind: spinor
  backend: gpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: 628.3}

dealias:
  enabled: true
  k_cut: 16.0
  auto_dt: true
  dt_safety: 10.0

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [96, 96, 96], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $OMEGA_Z]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: 628.3
        c1_ratio: -0.005
      ddi:
        enabled: true
        secular: false
      lhy: {kind: none}
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
      lhy: {kind: none}
$loss_block      seed_amplitude: 1.0e-6
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

for f in (150.0, 200.0)
    name = "K3x$(replace(string(f), "." => "p"))_n96.yaml"
    path = joinpath(OUTDIR, name)
    write(path, _config_text(f))
    println("wrote $name (factor=$f → K3 = $(f * K3_BASE_SI) m⁶/s)")
end
