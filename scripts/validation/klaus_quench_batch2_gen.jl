#!/usr/bin/env julia
#
# klaus_quench_batch2_gen.jl — follow-up after the surprise keep_rot finding
# (Fig K2: keep_rot Ω=-0.5 gave P_{-5,-4} = 0.54, vs 0.22 for free-hold core
# cells across all Ω). Question is whether the keep_rot enhancement is
# (a) Ω-magnitude monotone, (b) sign-symmetric, (c) DDI-dependent.
#
# Batch 2 = 6 new 32³ keep_rot cells:
#   keep_rot Ω = ±0.3, ±0.5 (already), ±0.7 → 4 new + previous = 6 total
#   keep_rot Ω = -0.5 DDI off                    → 1 control
# Plus 2 64³ anchor cells (the prior winner at 64³):
#   keep_rot Ω = -0.5 n=64
#   Ω = 0 n=64 (no-rotation control)
#
# Naming: keep the same "klaus_quench_*" prefix so klaus_quench_summary.jl
# auto-picks them up.

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
const B_FINAL = -2.6e-5

struct Cell
    name::String
    omega::Float64
    ddi_on::Bool
    do_quench::Bool
    keep_rot::Bool
    grid_n::Int
    n_atoms::Int
end

const CELLS = [
    # keep_rot Ω scan (32³).
    Cell("klaus_quench_omm0p3_keeprot",   -0.3, true,  true, true, 32, 10_000),
    Cell("klaus_quench_omm0p7_keeprot",   -0.7, true,  true, true, 32, 10_000),
    Cell("klaus_quench_omp0p3_keeprot",   +0.3, true,  true, true, 32, 10_000),
    Cell("klaus_quench_omp0p5_keeprot",   +0.5, true,  true, true, 32, 10_000),
    # DDI off control for keep_rot.
    Cell("klaus_quench_omm0p5_keeprot_DDIoff", -0.5, false, true, true, 32, 10_000),
    # 64³ anchor of the best Ω + Ω=0 control.
    Cell("klaus_quench_omm0p5_keeprot_n64",   -0.5, true,  true, true,  64, 10_000),
    Cell("klaus_quench_om0p0_n64",             0.0, true,  true, false, 64, 10_000),
]

_ddi_block(ddi_on, secular) = "{enabled: $(ddi_on), secular: $(secular)}"

function _config_text(c::Cell)
    rot_omega = c.omega
    quench_omega = c.keep_rot ? c.omega : 0.0
    hold_omega = c.keep_rot ? c.omega : 0.0
    quench_B = c.do_quench ?
        "{Bz: {from: $(B_ROT), to: $(B_FINAL), duration: $(T_QUENCH)}, theta: 0.0, phi: 0.0}" :
        "{Bz: \"$(B_ROT) Gauss\", theta: 0.0, phi: 0.0}"
    hold_B = c.do_quench ?
        "{Bz: \"$(B_FINAL) Gauss\", theta: 0.0, phi: 0.0}" :
        "{Bz: \"$(B_ROT) Gauss\", theta: 0.0, phi: 0.0}"

    return """
# Klaus 2-phase quench protocol (batch 2) — auto-generated.
# Source: scripts/validation/klaus_quench_batch2_gen.jl
#
# Cell : $(c.name)
#   grid: $(c.grid_n)³,  N: $(c.n_atoms)
#   Ω/ω_⊥ rotation prep   : $(c.omega)
#   Ω/ω_⊥ quench + hold   : $(quench_omega) / $(hold_omega)
#   DDI in dynamics       : $(c.ddi_on)
#   B quench applied      : $(c.do_quench)
#   rotation kept in hold : $(c.keep_rot)

metadata:
  suite: klaus_quench
  cell_name: $(c.name)
  rotation_omega: $(c.omega)
  ddi_on_dynamics: $(c.ddi_on)
  do_B_quench: $(c.do_quench)
  rotation_kept_in_hold: $(c.keep_rot)
  generator: scripts/validation/klaus_quench_batch2_gen.jl

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $(c.n_atoms), omega_ref: $OMEGA_REF}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$(c.grid_n), $(c.grid_n), $(c.grid_n)], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.181818]}
      interactions:
        N_atoms: $(c.n_atoms)
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
      rotating_frame_omega: $(rot_omega)
      B: {Bz: "$(B_ROT) Gauss", theta: 0.0, phi: 0.0}
      ddi: $(_ddi_block(c.ddi_on, false))
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
      rotating_frame_omega: $(quench_omega)
      B: $quench_B
      ddi: $(_ddi_block(c.ddi_on, false))
      lhy: {kind: none}
      save:
        every: 50
        psi: true
        precision: f64

  - dynamics:   # weak_field_hold
      duration: $(round(T_HOLD; digits=5))
      dt: 0.005
      rotating_frame_omega: $(hold_omega)
      B: $hold_B
      ddi: $(_ddi_block(c.ddi_on, false))
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
    println("Generating klaus_quench batch-2 configs in $OUTDIR")
    for c in CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(c))
        println("  wrote $name (grid=$(c.grid_n)³, Ω=$(c.omega), DDI=$(c.ddi_on), keep_rot=$(c.keep_rot))")
    end
    println("Done — $(length(CELLS)) cells.")
end

main()
