#!/usr/bin/env julia
#
# eu_collapse_search_gen.jl — find the (N, trap-aspect) regime where
# Eu Hamiltonian-only actually collapses. The L4 baseline (N=30000,
# isotropic ω=1) does NOT collapse at 64³ / t=20 dimless (Task #14
# 64³ result). To test "K3 arrests collapse" we first need a regime
# where collapse exists.
#
# Levers (most effective first for spin-polarised Eu with B‖z, m_F=-F):
#   (1) N — density ∝ N; ε_dd is N-independent but ∫c_dd·n grows with N.
#   (2) ω_z (cigar shape, ω_z < ω_⊥) — head-to-tail attraction along
#       z is amplified by elongating the cloud in z.
#
# Configuration matrix (4 cells, smallest informative factorial):
#   (N=100000, isotropic ω=1.0)       — N lever only
#   (N=30000,  ω_z=0.25 cigar)        — geometry lever only
#   (N=100000, ω_z=0.25 cigar)        — both levers
#   (N=300000, isotropic ω=1.0)       — extreme N
#
# Hamiltonian-only (no K3, no γ_dr, no LHY). CPU 32³ (fast smoke; if
# collapse is observed, extend to 64³ at the winning parameters).
#
# Output: runs/eu_collapse_search/N{N}_omz{ω_z}.yaml

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_collapse_search")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0
const SAVE_EVERY = 100

function _config_text(N_atoms::Int, omega_z::Float64)
    return """
# Eu collapse-regime search — auto-generated.
# Source: scripts/validation/eu_collapse_search_gen.jl
# (N_atoms=$N_atoms, ω_z=$omega_z, isotropic else; ω_x=ω_y=1.0)
# Target: identify a parameter regime where Hamiltonian-only Eu
# collapses, so that K3-arrest can be tested.

metadata:
  suite: eu_collapse_search
  ladder_level: 12
  N_atoms: $N_atoms
  omega_z: $omega_z
  generator: scripts/validation/eu_collapse_search_gen.jl

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $N_atoms, omega_ref: 628.3}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $omega_z]}
      interactions:
        N_atoms: $N_atoms
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

const CONFIGS = [
    (100_000, 1.0),     # N lever
    (30_000, 0.25),     # cigar lever
    (100_000, 0.25),    # both levers
    (300_000, 1.0),     # extreme N
]

function main()
    println("Generating collapse-search configs in $OUTDIR")
    for (N, omz) in CONFIGS
        name = "N$(N)_omz$(replace(string(omz), "." => "p")).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(N, omz))
        println("  wrote $name (N=$N, ω_z=$omz)")
    end
end

main()
