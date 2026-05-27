#!/usr/bin/env julia
#
# klaus_long_omega_large_gen.jl — extend long-time Ω scan past |Ω|=0.7
# toward the centrifugal limit (Ω/ω_⊥ = 1.0 in this normalisation).
#
# Existing data at t=100/ω⊥:
#   Ω = -0.3 : P_exc=0.51,  6 vortices
#   Ω = -0.42: P_exc=0.63, 11 vortices
#   Ω = -0.5 : P_exc=0.96, 24 vortices ★ cascade peak
#   Ω = -0.7 : P_exc=0.89, 56 vortices (over-rotated; cascade slightly down)
#
# New: |Ω| = 0.85, 1.0, 1.15.  Predictions:
#   - approaching centrifugal limit Ω/ω_⊥ = 1 → radial confinement weakens
#   - vortex count may peak then drop (cloud spreads, lattice disorders)
#   - cascade efficiency further drops if rotation becomes destabilising
#   - Ω > 1 in harmonic trap → unbounded centrifugal expansion (numerical
#     explosion possible)

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "klaus_quench_long_time")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504
const T_ROT_MS = 10.0
const T_QUENCH_MS = 1.0
const T_ROT = T_ROT_MS * 1e-3 * OMEGA_REF
const T_QUENCH = T_QUENCH_MS * 1e-3 * OMEGA_REF
const T_HOLD_DIM = 100.0
const C1_RATIO = 0.02778
const N_ATOMS = 10_000
const B_ROT = -0.01
const B_FINAL = -2.6e-5

const OMEGAS = [-0.85, -1.0, -1.15]

function _name(omega::Float64)
    s = replace(string(round(abs(omega); digits=2)), "." => "p")
    return "klaus_long_omm$(s)_holdonly_t100"
end

function _config_text(omega::Float64)
    name = _name(omega)
    return """
# Klaus long-time Ω large scan @ t=100 ω⊥⁻¹.
# Source: scripts/validation/klaus_long_omega_large_gen.jl
#   Ω/ω_⊥ = $(omega)  (near centrifugal limit Ω/ω_⊥ = 1)

metadata:
  suite: klaus_long_time
  cell_name: $name
  rotation_omega: $(omega)
  t_hold_dim: $T_HOLD_DIM
  protocol_kind: hold_only_long_time_large_omega
  generator: scripts/validation/klaus_long_omega_large_gen.jl

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: $OMEGA_REF}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.181818]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: $OMEGA_REF
        c1_ratio: $C1_RATIO
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-9

  - dynamics:   # rotation_prep (no rotation)
      duration: $(round(T_ROT; digits=5))
      dt: 0.005
      rotating_frame_omega: 0.0
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 200, psi: true, precision: f64}

  - dynamics:   # B_quench
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      rotating_frame_omega: 0.0
      B: {Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save: {every: 50, psi: true, precision: f64}

  - dynamics:   # long weak-field hold with rotation
      duration: $(round(T_HOLD_DIM; digits=4))
      dt: 0.005
      rotating_frame_omega: $(omega)
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save: {every: 1000, psi: true, precision: f64}

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

function main()
    for omega in OMEGAS
        path = joinpath(OUTDIR, _name(omega) * ".yaml")
        write(path, _config_text(omega))
        println("wrote $(basename(path))  (Ω = $omega)")
    end
end

main()
