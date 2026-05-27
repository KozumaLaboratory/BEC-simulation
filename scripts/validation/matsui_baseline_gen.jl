#!/usr/bin/env julia
#
# matsui_baseline_gen.jl — Matsui 2026 Science Eu-151 EdH reproduction.
# Parameter set fully consistent with the paper (Matsui et al., Science 2026,
# DOI:10.1126/science.adx2872; arXiv:2504.17357), per anko's 2026-05-26 audit.
#
# Key corrections from earlier YAMLs:
#   N_atoms      : 50000   (was 10000 or 30000) — experimental value
#   initial_state: m_minus_F  (was m_plus_F) — Matsui starts m_F = −6
#   c1_ratio     : 1/36   (was 0.0 or −0.005) — Matsui best-fit profile choice
#   omega_z/omega_⊥ : 130/110 ≈ 1.1818 — Matsui near-spherical trap
#   omega_ref    : 2π × 110 Hz = 691.15 rad/s
#   ground_state DDI : secular=true (time-averaged, per Matsui §)
#   dynamics DDI    : secular=false (full MDDI, weak-field EdH)
#   loss / LHY      : off (Matsui simulation is loss-free + no LHY)
#
# Ladder targets:
#   5ms  morphology  → duration =  3.455 dimless (Fig 1 ring structures)
#   40ms population  → duration = 27.64  dimless (Fig 2 N_m(t) dynamics)
#
# Caveats (do NOT hide in production claim):
#   * Matsui experiment has ~40% atom loss at 40ms in weak field;
#     numerical simulation does not. Loss-on YAMLs are a separate
#     "experiment reproduction" target, not Matsui simulation target.
#   * Ramp from 1 µT to 2.6 nT timing is not strictly specified in the
#     paper. We use an instantaneous step.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "matsui_baseline")
mkpath(OUTDIR)

const N_ATOMS = 50_000
const OMEGA_REF = 2π * 110.0   # rad/s
const OMEGA_Z_RATIO = 130.0 / 110.0   # 1.1818...
const C1_RATIO = 1.0 / 36.0            # Matsui best fit
const T_5MS = 5.0e-3 * OMEGA_REF       # 3.4558
const T_40MS = 40.0e-3 * OMEGA_REF     # 27.646

function _config_text(grid_n::Int, t_target::Float64, label::String;
    save_every::Int=100)
    return """
# Matsui 2026 Eu-151 EdH baseline — auto-generated.
# Source: scripts/validation/matsui_baseline_gen.jl
# Target: $label  (duration = $(round(t_target; digits=4)) ω_ref⁻¹)
# Conditions (Matsui simulation, loss-free):
#   N = $N_ATOMS, m_F = -6, c1/c0 = 1/36
#   trap (ω_x, ω_y, ω_z)/ω_ref = (1, 1, $(round(OMEGA_Z_RATIO; digits=4)))
#   ω_ref = 2π · 110 Hz = $(round(OMEGA_REF; digits=3)) rad/s
#   B (ground state) = 1 µT;  B (dynamics) = 2.6 nT
#   DDI: secular for GS, full for dynamics

metadata:
  suite: matsui_baseline
  ladder_level: 12
  reference: Matsui_2026_Science_arxiv_2504_17357
  target: $label
  grid_n: $grid_n
  generator: scripts/validation/matsui_baseline_gen.jl

defaults:
  kind: spinor
  backend: gpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: $(round(OMEGA_REF; digits=4))}

dealias:
  enabled: true
  k_cut: 16.0
  auto_dt: true
  dt_safety: 10.0

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$grid_n, $grid_n, $grid_n], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $(round(OMEGA_Z_RATIO; digits=6))]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: $(round(OMEGA_REF; digits=4))
        c1_ratio: $(round(C1_RATIO; digits=10))
      ddi:
        enabled: true
        secular: true                            # Matsui: time-averaged for GS
      lhy: {kind: none}
      B: {Bz: "-0.01 Gauss", theta: 0.0, phi: 0.0}   # NEGATIVE → m=-F lowest energy
      gauge_fix: false
      initial_state: m_minus_F                   # Matsui: m_F = -6
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9

  - dynamics:
      duration: $(round(t_target; digits=4))
      dt: 0.005
      B:
        Bz: {from: -0.01, to: -2.6e-5, duration: 0.0}   # NEGATIVE throughout
        theta: 0.0
        phi: 0.0
      ddi:
        secular: false                           # Matsui: full MDDI for dynamics
      lhy: {kind: none}                          # Matsui simulation: no LHY
      # NO loss block — Matsui simulation is loss-free
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: $save_every
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

const CONFIGS = [
    # (grid, t_target, label, save_every)
    (32, T_5MS, "5ms_morphology", 50),         # smoke
    (64, T_5MS, "5ms_morphology", 50),         # production morphology
    (64, T_40MS, "40ms_dynamics", 200),        # production dynamics
]

for (g, t, lab, se) in CONFIGS
    name = "matsui_$(lab)_n$(g).yaml"
    path = joinpath(OUTDIR, name)
    write(path, _config_text(g, t, lab; save_every=se))
    println("wrote $name (grid=$g, duration=$(round(t; digits=4)), label=$lab)")
end
