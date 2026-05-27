#!/usr/bin/env julia
#
# eu_k3_lhy_gen.jl — Task #19C: LHY model interference at K3=200×.
# Goal: is the scalar-LHY-K3 antagonism (Task #18) specific to scalar
# LHY, or does it appear with any LHY model?
#
# 3 new cells; LHY=off baseline already exists as
# runs/eu_k3_sweep/K3x200p0.yaml.
#
# LHY models tested:
#   scalar         — n^{5/2} local EoS (used in Task #18; antagonistic)
#   polar_contact  — channel-decomposed contact LHY (polar-phase EoS)
#   icosahedral    — F=6 I_h symmetric LHY (closed form for I_h state)
#
# Caveat: polar_contact and icosahedral assume their respective phase
# is the local order parameter. Our cigar dynamics starts m=-F (FM-up)
# and develops EdH transfer — neither polar nor I_h. We are stress-
# testing the antagonism *against* LHY model choice, not claiming any
# of these is the "right" EoS for the cigar dynamics.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_lhy")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0
const SAVE_EVERY = 50
const N_ATOMS = 30_000
const OMEGA_Z = 0.25
const K3_FACTOR = 200.0
const K3_SI = K3_FACTOR * 1.0e-41
const K3_LIST = "[" * join(["\"$(K3_SI) m^6/s\"" for _ in 1:13], ", ") * "]"

function _config_text(lhy_kind::String)
    return """
# Task #19C — LHY interference at K3=200× cigar regime.
# Source: scripts/validation/eu_k3_lhy_gen.jl
# LHY kind = $lhy_kind (applied outside nominal regime; see scope note).

metadata:
  suite: eu_k3_lhy
  ladder_level: 12
  parent_regime: cigar_N30k_omz0p25
  K3_factor: $K3_FACTOR
  LHY_kind: $lhy_kind
  generator: scripts/validation/eu_k3_lhy_gen.jl

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
      loss:
        K3_per_m_si:
          $(K3_LIST)
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
    path = joinpath(OUTDIR, "LHY_$(kind).yaml")
    write(path, _config_text(kind))
    println("wrote LHY_$(kind).yaml")
end
