#!/usr/bin/env julia
#
# klaus_omega_refine_gen.jl — local Ω refinement around the 3-point
# quadratic-interpolation vertex.
#
# 3-point parabolic fit of (Ω, P_-5,-4) = (0.3, 0.517) / (0.5, 0.540) /
# (0.7, 0.344) gives vertex Ω* ≈ 0.42, P_max ≈ 0.558.  The sampled
# 0.500 was operationally best but is NOT the true optimum.
#
# This batch resamples 7 points around Ω* with the protocol-optimized
# delay = 2 ms (which gave the all-time peak P_-5,-4 = 0.626 at
# Ω = -0.5).  Hold-only matched chirality.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "klaus_quench")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504
const T_ROT_MS = 10.0
const T_QUENCH_MS = 1.0
const T_PREDELAY_MS = 2.0     # rotation start delay
const T_HOLD_TOTAL_MS = 10.0
const T_HOLD_ROT_MS = T_HOLD_TOTAL_MS - T_PREDELAY_MS

const T_ROT = T_ROT_MS * 1e-3 * OMEGA_REF
const T_QUENCH = T_QUENCH_MS * 1e-3 * OMEGA_REF
const T_PREDELAY = T_PREDELAY_MS * 1e-3 * OMEGA_REF
const T_HOLD_ROT = T_HOLD_ROT_MS * 1e-3 * OMEGA_REF

const C1_RATIO = 0.02778
const B_ROT = -0.01
const B_FINAL = -2.6e-5
const N_ATOMS = 10_000

# 7-point local refinement around the parabolic vertex.
const OMEGAS = [-0.34, -0.38, -0.42, -0.46, -0.50, -0.54, -0.58]

function _name(omega::Float64)
    abs_om = abs(omega)
    s_om = replace(string(round(abs_om; digits=2)), "." => "p")
    return "klaus_quench_omm$(s_om)_holdonly_delay2ms_refine"
end

function _config_text(omega::Float64)
    name = _name(omega)
    return """
# Klaus Ω refinement around the parabolic-interpolation vertex (Ω*≈0.42).
# Source: scripts/validation/klaus_omega_refine_gen.jl
#   Ω/ω_⊥ = $(omega)
#   B_hold = 2.6 nT, matched chirality (m=-F, Ω<0), hold-only,
#   rotation-start delay = 2 ms (the protocol-optimal delay).

metadata:
  suite: klaus_quench_refine
  cell_name: $name
  rotation_omega: $(omega)
  protocol_kind: holdonly_delay2ms
  generator: scripts/validation/klaus_omega_refine_gen.jl

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

  - dynamics:   # rotation_prep (hold-only: no rotation here)
      duration: $(round(T_ROT; digits=5))
      dt: 0.005
      rotating_frame_omega: 0.0
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 100
        psi: true
        precision: f64

  - dynamics:   # B_quench
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      rotating_frame_omega: 0.0
      B: {Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # hold pre-delay (Ω=0, 2 ms)
      duration: $(round(T_PREDELAY; digits=5))
      dt: 0.005
      rotating_frame_omega: 0.0
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # hold rotating (Ω = $(omega), 8 ms)
      duration: $(round(T_HOLD_ROT; digits=5))
      dt: 0.005
      rotating_frame_omega: $(omega)
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
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
end

function main()
    println("Generating Ω-refinement configs in $OUTDIR")
    for omega in OMEGAS
        path = joinpath(OUTDIR, _name(omega) * ".yaml")
        write(path, _config_text(omega))
        println("  wrote $(basename(path))  (Ω = $omega)")
    end
    println("Done — $(length(OMEGAS)) cells.")
end

main()
