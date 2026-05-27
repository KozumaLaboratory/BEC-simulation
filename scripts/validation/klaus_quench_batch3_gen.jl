#!/usr/bin/env julia
#
# klaus_quench_batch3_gen.jl — anko's "research-judgement level" follow-up
# (2026-05-26 evening): 5 killer-control queues that take Klaus from
# "presentation-ready" to "publication-grade":
#
#   Queue 1: symmetry under (initial spin) × (rotation sign) reversal
#   Queue 2: rotation-timing decomposition (prep_only / hold_only / both)
#   Queue 3: B_final dependence (weak-field magnitude scan)
#   Queue 4: dt/2 numerical anchor
#   Queue 5: N=5e4 experimental-scale anchor
#
# 10 new cells, all 32³ CPU (rotating_frame_omega + GPU gotcha applies).

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

# Extended Cell with per-phase rotation flags + sign / B / dt / N variants.
struct Cell
    name::String
    omega::Float64
    rot_prep::Bool        # apply Ω in rotation_prep
    rot_quench::Bool      # apply Ω in B_quench
    rot_hold::Bool        # apply Ω in weak_field_hold
    ddi_on::Bool
    do_quench::Bool
    init_m_sign::Int      # +1 → m=+F, −1 → m=−F
    B_final_nT::Float64   # weak-field magnitude in nT (sign tied to init_m_sign)
    dt_scale::Float64     # 1.0 or 0.5
    n_atoms::Int
end

const CELLS = [
    # Queue 1 — symmetry under (init_m × Ω sign).
    Cell("klaus_quench_omm0p5_keeprot_mFplus", -0.5, true,  true,  true,  true,  true,  +1, 2.6, 1.0, 10_000),
    Cell("klaus_quench_omp0p5_keeprot_mFplus", +0.5, true,  true,  true,  true,  true,  +1, 2.6, 1.0, 10_000),
    # Queue 2 — rotation timing decomposition.
    Cell("klaus_quench_omm0p5_holdonly",       -0.5, false, false, true,  true,  true,  -1, 2.6, 1.0, 10_000),
    # Queue 3 — B_final sweep (2.6 nT already exists as keeprot baseline).
    Cell("klaus_quench_omm0p5_keeprot_Bf1p3",  -0.5, true,  true,  true,  true,  true,  -1, 1.3,  1.0, 10_000),
    Cell("klaus_quench_omm0p5_keeprot_Bf5p2",  -0.5, true,  true,  true,  true,  true,  -1, 5.2,  1.0, 10_000),
    Cell("klaus_quench_omm0p5_keeprot_Bf10",   -0.5, true,  true,  true,  true,  true,  -1, 10.0, 1.0, 10_000),
    # Queue 4 — dt/2 numerical anchor.
    Cell("klaus_quench_omm0p5_keeprot_dt2",    -0.5, true,  true,  true,  true,  true,  -1, 2.6, 0.5, 10_000),
    Cell("klaus_quench_om0p0_dt2",              0.0, true,  true,  false, true,  true,  -1, 2.6, 0.5, 10_000),
    # Queue 5 — N=5e4 experimental-scale anchor.
    Cell("klaus_quench_omm0p5_keeprot_N50k",   -0.5, true,  true,  true,  true,  true,  -1, 2.6, 1.0, 50_000),
    Cell("klaus_quench_om0p0_N50k",             0.0, true,  true,  false, true,  true,  -1, 2.6, 1.0, 50_000),
]

_ddi_block(ddi_on, secular) = "{enabled: $(ddi_on), secular: $(secular)}"

function _config_text(c::Cell)
    init_state = c.init_m_sign > 0 ? "m_plus_F" : "m_minus_F"
    B_ROT = c.init_m_sign > 0 ? +0.01 : -0.01
    B_FINAL = c.init_m_sign > 0 ? +c.B_final_nT * 1e-5 : -c.B_final_nT * 1e-5

    omega_prep = c.rot_prep ? c.omega : 0.0
    omega_quench = c.rot_quench ? c.omega : 0.0
    omega_hold = c.rot_hold ? c.omega : 0.0

    dt = round(0.005 * c.dt_scale; digits=6)
    dt_q = round(0.001 * c.dt_scale; digits=7)
    # Save frequency scales with 1/dt_scale so total snapshots stay similar.
    save_step = Int(round(100 / c.dt_scale))
    save_step_q = Int(round(50 / c.dt_scale))

    quench_B = c.do_quench ?
        "{Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}" :
        "{Bz: \"$(B_ROT) Gauss\", theta: 0.0, phi: 0.0}"
    hold_B = c.do_quench ?
        "{Bz: \"$(B_FINAL) Gauss\", theta: 0.0, phi: 0.0}" :
        "{Bz: \"$(B_ROT) Gauss\", theta: 0.0, phi: 0.0}"

    return """
# Klaus 2-phase quench protocol (batch 3 killer controls) — auto-generated.
# Source: scripts/validation/klaus_quench_batch3_gen.jl
#
# Cell : $(c.name)
#   initial state         : $init_state    (m_sign = $(c.init_m_sign > 0 ? "+F" : "−F"))
#   Ω/ω_⊥ scan magnitude  : $(c.omega)
#   Ω applied in          : prep=$(c.rot_prep)  quench=$(c.rot_quench)  hold=$(c.rot_hold)
#   DDI in dynamics       : $(c.ddi_on)
#   B quench applied      : $(c.do_quench)
#   B_rot / B_final       : $(B_ROT) G  /  $(B_FINAL) G  ($(c.B_final_nT) nT magnitude)
#   dt scale              : $(c.dt_scale)
#   N_atoms               : $(c.n_atoms)

metadata:
  suite: klaus_quench
  cell_name: $(c.name)
  rotation_omega: $(c.omega)
  rot_prep: $(c.rot_prep)
  rot_quench: $(c.rot_quench)
  rot_hold: $(c.rot_hold)
  ddi_on_dynamics: $(c.ddi_on)
  do_B_quench: $(c.do_quench)
  initial_m_sign: $(c.init_m_sign)
  B_final_nT: $(c.B_final_nT)
  dt_scale: $(c.dt_scale)
  N_atoms: $(c.n_atoms)
  generator: scripts/validation/klaus_quench_batch3_gen.jl

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $(c.n_atoms), omega_ref: $OMEGA_REF}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.181818]}
      interactions:
        N_atoms: $(c.n_atoms)
        omega_ref: $OMEGA_REF
        c1_ratio: $C1_RATIO
      ddi: {enabled: true, secular: true}
      lhy: {kind: none}
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: $init_state
      init_sigma: 1.5
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-9

  - dynamics:   # rotation_prep
      duration: $(round(T_ROT; digits=5))
      dt: $dt
      rotating_frame_omega: $omega_prep
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi_block(c.ddi_on, false))
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: $save_step
        psi: true
        precision: f64

  - dynamics:   # B_quench
      duration: $(round(T_QUENCH; digits=5))
      dt: $dt_q
      rotating_frame_omega: $omega_quench
      B: $quench_B
      ddi: $(_ddi_block(c.ddi_on, false))
      lhy: {kind: none}
      save:
        every: $save_step_q
        psi: true
        precision: f64

  - dynamics:   # weak_field_hold
      duration: $(round(T_HOLD; digits=5))
      dt: $dt
      rotating_frame_omega: $omega_hold
      B: $hold_B
      ddi: $(_ddi_block(c.ddi_on, false))
      lhy: {kind: none}
      save:
        every: $save_step
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

function main()
    println("Generating klaus_quench batch-3 configs in $OUTDIR")
    for c in CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(c))
        println("  wrote $name  (m_sign=$(c.init_m_sign), Ω=$(c.omega), rot=$(c.rot_prep)/$(c.rot_quench)/$(c.rot_hold), B_f=$(c.B_final_nT)nT, dt×$(c.dt_scale), N=$(c.n_atoms))")
    end
    println("Done — $(length(CELLS)) cells.")
end

main()
