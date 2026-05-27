#!/usr/bin/env julia
#
# klaus_hybrid_magnetostir_edh_gen.jl — Klaus magnetostirring → weak-field
# EdH readout hybrid protocol.  anko 2026-05-27.
#
# Two-stage protocol that pulls the orbital excitation from the Klaus
# regime into the Matsui-scale EdH-active weak field:
#
#   Stage 1 (high B = 5.333 G, θ=35°, ε ≫ DDI):
#     adiabatic tilt-up (5 ms)
#     Klaus magnetostirring at Ω = 0.74 ω⊥, 314 ms  ⇒ orbital L_z, vortices
#     (control cell: no φ rotation)
#
#   Stage 2 (weak B = 2.6×10⁻⁵ G):
#     B magnitude quench (1 ms), direction (θ=35°) preserved
#     weak-field EdH readout, 20 ms  ⇒ post-quench spin excitation
#
# 2 cells:
#   Cell A (no-stir control):  GS → tilt-up → hold tilted (no rotation,
#                              same duration as stir) → quench → readout
#   Cell B (Klaus magnetostir): GS → tilt-up → spin-up → steady stir → quench → readout
#
# Notes on numerics:
#  - At B = 5.333 G, ω_L/ω_ref ≈ 7.7×10⁴ → secular_ddi=true is mandatory
#    in Stages 1–4 to avoid Larmor stiffness.
#  - At B = 2.6×10⁻⁵ G, ω_L/DDI ≈ 1, secular_ddi must be FALSE for the
#    EdH-active readout.
#  - dt = 0.005 throughout; B quench step uses dt = 0.001.
#  - 32³ box, m=-F initial, Ω matched-chirality = -0.74.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "klaus_hybrid")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504               # Matsui-like ω_⊥
const C1_RATIO = 0.02778
const N_ATOMS = 10_000

const B_MAG_HIGH = 0.01                  # Spinor-stable strong field (10 mG)
# Klaus's actual 5.333 G requires `kind: rotating_basis` due to ω_L ≫ 1/dt at
# spinor-pathway dt=0.005. 10 mG keeps the same physics regime (ω_L ≫ DDI,
# secular approx valid) at a numerically tractable scale.
const B_MAG_LOW = 2.6e-5                 # Matsui weak-field
# m=-F initial → B along -z. With spherical form: B_mag positive, theta=π.
# Klaus tilt is 35° AWAY from -z (toward upper hemisphere), so theta tilts
# from π toward (π - 0.611).
const THETA_GS = 3.14159                 # along -z (m=-F is GS at this B)
const THETA_KLAUS = 3.14159 - 0.611      # 35° tilt from -z, lower hemisphere
const OMEGA_STIR = -0.74                 # matched chirality with m=-F

const T_TILT_MS = 5.0
const T_SPINUP_MS = 5.0
const T_STEADY_MS = 314.0                # Klaus vortex-onset duration
const T_QUENCH_MS = 1.0
const T_READOUT_MS = 20.0

_to_dim(ms) = ms * 1e-3 * OMEGA_REF
const T_TILT   = _to_dim(T_TILT_MS)
const T_SPINUP = _to_dim(T_SPINUP_MS)
const T_STEADY = _to_dim(T_STEADY_MS)
const T_QUENCH = _to_dim(T_QUENCH_MS)
const T_READOUT = _to_dim(T_READOUT_MS)

# ----- Cell A: no-stir control -----
const CONFIG_A = """
# Klaus hybrid Cell A — NO-STIR control.
# GS → tilt-up → tilted hold (no φ rotation) → B quench → weak-field EdH readout.
# Pairs with Cell B (with magnetostir) for delta-comparison.

metadata:
  suite: klaus_hybrid
  cell_name: klaus_hybrid_nostir_control
  rotation_omega: 0.0
  protocol_kind: hybrid_nostir
  generator: scripts/validation/klaus_hybrid_magnetostir_edh_gen.jl

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
      B: {B_mag: "$B_MAG_HIGH Gauss", theta: $THETA_GS, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-9

  - dynamics:   # adiabatic tilt-up at high B
      duration: $(round(T_TILT; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_HIGH Gauss"
        theta: {from: $THETA_GS, to: $THETA_KLAUS, duration: $(round(T_TILT; digits=5))}
        phi: 0.0
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 200
        psi: true
        precision: f64

  - dynamics:   # tilted hold (no rotation) for same duration as stir cell
      duration: $(round(T_SPINUP + T_STEADY; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_HIGH Gauss"
        theta: $THETA_KLAUS
        phi: 0.0
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      save:
        every: 1000
        psi: true
        precision: f64

  - dynamics:   # B quench (high → low magnitude, direction preserved)
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      B:
        B_mag: {from: $B_MAG_HIGH, to: $B_MAG_LOW, duration: $(round(T_QUENCH; digits=5))}
        theta: $THETA_KLAUS
        phi: 0.0
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # weak-field EdH readout (no rotation)
      duration: $(round(T_READOUT; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_LOW Gauss"
        theta: $THETA_KLAUS
        phi: 0.0
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 100
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""

# ----- Cell B: Klaus magnetostir -----
const CONFIG_B = """
# Klaus hybrid Cell B — MAGNETOSTIR + weak-field EdH readout.
# GS → tilt-up → spin-up → steady Klaus magnetostir → B quench → weak-field readout.

metadata:
  suite: klaus_hybrid
  cell_name: klaus_hybrid_magnetostir_omega_m0p74
  rotation_omega: $OMEGA_STIR
  protocol_kind: hybrid_magnetostir
  generator: scripts/validation/klaus_hybrid_magnetostir_edh_gen.jl

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
      B: {B_mag: "$B_MAG_HIGH Gauss", theta: $THETA_GS, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-9

  - dynamics:   # tilt-up
      duration: $(round(T_TILT; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_HIGH Gauss"
        theta: {from: $THETA_GS, to: $THETA_KLAUS, duration: $(round(T_TILT; digits=5))}
        phi: 0.0
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 200
        psi: true
        precision: f64

  - dynamics:   # spin-up (φ-rate 0 → -0.74) at θ=35°
      duration: $(round(T_SPINUP; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_HIGH Gauss"
        theta: $THETA_KLAUS
        phi: {rate: {from: 0.0, to: $OMEGA_STIR, duration: $(round(T_SPINUP; digits=5))}}
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      save:
        every: 200
        psi: true
        precision: f64

  - dynamics:   # steady Klaus magnetostir, 314 ms
      duration: $(round(T_STEADY; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_HIGH Gauss"
        theta: $THETA_KLAUS
        phi: {rate: $OMEGA_STIR}
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      save:
        every: 1000
        psi: true
        precision: f64

  - dynamics:   # B quench (high → low magnitude, direction + φ-rate preserved)
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      B:
        B_mag: {from: $B_MAG_HIGH, to: $B_MAG_LOW, duration: $(round(T_QUENCH; digits=5))}
        theta: $THETA_KLAUS
        phi: {rate: $OMEGA_STIR}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # weak-field EdH readout (rotation OFF after quench)
      duration: $(round(T_READOUT; digits=5))
      dt: 0.005
      B:
        B_mag: "$B_MAG_LOW Gauss"
        theta: $THETA_KLAUS
        phi: 0.0
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 100
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""

function main()
    println("Generating klaus_hybrid configs in $OUTDIR")
    path_A = joinpath(OUTDIR, "klaus_hybrid_nostir_control.yaml")
    write(path_A, CONFIG_A)
    println("  wrote klaus_hybrid_nostir_control.yaml  (no-stir control)")
    path_B = joinpath(OUTDIR, "klaus_hybrid_magnetostir_omega_m0p74.yaml")
    write(path_B, CONFIG_B)
    println("  wrote klaus_hybrid_magnetostir_omega_m0p74.yaml  (with stir, Ω = $OMEGA_STIR)")
    println("Done — 2 cells.")
end

main()
