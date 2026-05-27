#!/usr/bin/env julia
#
# klaus_quench_batch4_gen.jl — mechanism-and-robustness extension after
# the 6-gate publication-grade certification. anko 2026-05-26 evening
# step-up plan:
#
#   Batch B — B × Ω 2D robustness map (9-point grid)
#     existing keep_rot cells cover 5/9 grid points:
#       (B=2.6, Ω∈{-0.3,-0.5,-0.7}) + (B∈{1.3, 5.2}, Ω=-0.5)
#     missing 4 corner cells dispatched here.
#
#   Batch C — rotation start-delay test at the best operating point
#     B = 2.6 nT, Ω = -0.5, matched chirality, hold-only;
#     vary the delay between B quench and rotation onset:
#       delay = 1, 2, 5 ms (delay = 0 reuses omm0p5_holdonly = 0.524)
#
# All 32³ CPU; total 7 new cells.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "klaus_quench")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504
const T_ROT_MS = 10.0
const T_QUENCH_MS = 1.0
const T_HOLD_MS = 10.0
const T_ROT = T_ROT_MS * 1e-3 * OMEGA_REF
const T_QUENCH = T_QUENCH_MS * 1e-3 * OMEGA_REF
const T_HOLD = T_HOLD_MS * 1e-3 * OMEGA_REF
const C1_RATIO = 0.02778
const B_ROT = -0.01
const N_ATOMS = 10_000

_ddi(ddi_on, sec) = "{enabled: $(ddi_on), secular: $(sec)}"

# -------------------- Batch B (4 grid-corner keep_rot cells) --------------------
struct GridCell
    name::String
    omega::Float64
    B_final_nT::Float64
end

const GRID_CELLS = [
    GridCell("klaus_quench_omm0p3_keeprot_Bf1p3", -0.3, 1.3),
    GridCell("klaus_quench_omm0p7_keeprot_Bf1p3", -0.7, 1.3),
    GridCell("klaus_quench_omm0p3_keeprot_Bf5p2", -0.3, 5.2),
    GridCell("klaus_quench_omm0p7_keeprot_Bf5p2", -0.7, 5.2),
]

function _grid_config(c::GridCell)
    B_FINAL = -c.B_final_nT * 1e-5
    return """
# Klaus 2-phase quench — B × Ω 2D robustness map corner (batch 4 B).
# Source: scripts/validation/klaus_quench_batch4_gen.jl
#   Ω/ω_⊥ = $(c.omega)
#   B_final = $(B_FINAL) G ($(c.B_final_nT) nT)
#   keep_rot, m=-F init, DDI on.

metadata:
  suite: klaus_quench
  cell_name: $(c.name)
  rotation_omega: $(c.omega)
  B_final_nT: $(c.B_final_nT)
  variant_kind: grid_corner
  generator: scripts/validation/klaus_quench_batch4_gen.jl

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

  - dynamics:   # rotation_prep
      duration: $(round(T_ROT; digits=5))
      dt: 0.005
      rotating_frame_omega: $(c.omega)
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
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
      rotating_frame_omega: $(c.omega)
      B: {Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # weak_field_hold
      duration: $(round(T_HOLD; digits=5))
      dt: 0.005
      rotating_frame_omega: $(c.omega)
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
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

# -------------------- Batch C (rotation start-delay cells) --------------------
struct DelayCell
    name::String
    delay_ms::Float64
end

const DELAY_CELLS = [
    DelayCell("klaus_quench_omm0p5_holdonly_delay1ms", 1.0),
    DelayCell("klaus_quench_omm0p5_holdonly_delay2ms", 2.0),
    DelayCell("klaus_quench_omm0p5_holdonly_delay5ms", 5.0),
]

function _delay_config(c::DelayCell)
    B_FINAL = -2.6e-5
    delay_dim = c.delay_ms * 1e-3 * OMEGA_REF   # delay in ω_ref⁻¹
    rotate_dim = T_HOLD - delay_dim             # remainder of hold with rotation

    return """
# Klaus 2-phase quench — rotation start-delay test (batch 4 C).
# Source: scripts/validation/klaus_quench_batch4_gen.jl
#   matched chirality (m=-F init, Ω=-0.5)
#   weak-field hold starts with NO rotation for first $(c.delay_ms) ms,
#   then Ω = -0.5 for remaining $(c.delay_ms < T_HOLD_MS ? T_HOLD_MS - c.delay_ms : 0.0) ms.

metadata:
  suite: klaus_quench
  cell_name: $(c.name)
  rotation_omega: -0.5
  delay_ms: $(c.delay_ms)
  variant_kind: delay_test
  generator: scripts/validation/klaus_quench_batch4_gen.jl

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

  - dynamics:   # rotation_prep (no rotation; hold-only protocol)
      duration: $(round(T_ROT; digits=5))
      dt: 0.005
      rotating_frame_omega: 0.0
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 100
        psi: true
        precision: f64

  - dynamics:   # B_quench (no rotation yet)
      duration: $(round(T_QUENCH; digits=5))
      dt: 0.001
      rotating_frame_omega: 0.0
      B: {Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # hold pre-delay (weak B, Ω=0)
      duration: $(round(delay_dim; digits=5))
      dt: 0.005
      rotating_frame_omega: 0.0
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # hold rotating (weak B, Ω=-0.5)
      duration: $(round(rotate_dim; digits=5))
      dt: 0.005
      rotating_frame_omega: -0.5
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi(true, false))
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
    println("Generating klaus_quench batch-4 configs in $OUTDIR")
    println("--- Batch B (grid corners) ---")
    for c in GRID_CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _grid_config(c))
        println("  wrote $name  (Ω=$(c.omega), B=$(c.B_final_nT) nT)")
    end
    println("--- Batch C (delay test) ---")
    for c in DELAY_CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _delay_config(c))
        println("  wrote $name  (delay=$(c.delay_ms) ms)")
    end
    println("Done — $(length(GRID_CELLS) + length(DELAY_CELLS)) cells.")
end

main()
