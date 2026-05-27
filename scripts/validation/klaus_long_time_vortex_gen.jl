#!/usr/bin/env julia
#
# klaus_long_time_vortex_gen.jl — long-time branch to reach the Prasad
# et al. vortex-nucleation timescale.
#
# Reference: Prasad et al. arXiv:1906.08664 — rotating-polarization
# scalar dipolar BEC develops surface fluctuations at t~100/ω⊥, vortex
# entry at t~350/ω⊥, and triangular Abrikosov lattice at t~5000/ω⊥.
# Our existing 34-cell Klaus-I scan used hold = 6.9 ω⊥⁻¹ ≈ 10 ms — too
# short by ~50× to see vortex nucleation.
#
# Branch B (Klaus-I-style with mechanical trap rotation, long hold):
# extend the matched-chirality best cell to hold = 350 ω⊥⁻¹ ≈ 0.51 s
# at the Matsui trap scale (ω⊥ = 2π·110 Hz).

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "klaus_quench_long_time")
mkpath(OUTDIR)

const OMEGA_REF = 691.1504
const T_ROT_MS = 10.0
const T_QUENCH_MS = 1.0
const C1_RATIO = 0.02778
const N_ATOMS = 10_000
const B_ROT = -0.01
const B_FINAL = -2.6e-5

const T_ROT = T_ROT_MS * 1e-3 * OMEGA_REF
const T_QUENCH = T_QUENCH_MS * 1e-3 * OMEGA_REF

struct LongCell
    name::String
    omega::Float64
    t_hold_dim::Float64    # weak-field hold duration in ω_ref⁻¹
end

const CELLS = [
    # hold ≈ 100/ω_⊥ (surface fluctuation onset per Prasad).
    LongCell("klaus_long_omm0p5_holdonly_t100",   -0.5, 100.0),
    # hold ≈ 350/ω_⊥ (vortex-entry timescale per Prasad — main target).
    LongCell("klaus_long_omm0p5_holdonly_t350",   -0.5, 350.0),
    # Ω=0 control at long time (does the system develop vortices without rotation?).
    LongCell("klaus_long_om0p0_holdonly_t350",     0.0, 350.0),
]

function _config_text(c::LongCell)
    return """
# Klaus long-time branch — Prasad-timescale vortex-nucleation probe.
# Source: scripts/validation/klaus_long_time_vortex_gen.jl
# Reference: Prasad et al. arXiv:1906.08664.
#
# Cell : $(c.name)
#   Ω/ω_⊥ during hold     : $(c.omega)
#   hold duration         : $(c.t_hold_dim) ω_ref⁻¹  ≈ $(round(c.t_hold_dim * 1000 / OMEGA_REF; digits=1)) ms
#   Prasad references     : t=100 surface, t=350 vortex entry, t=5000 lattice

metadata:
  suite: klaus_long_time
  cell_name: $(c.name)
  rotation_omega: $(c.omega)
  t_hold_dim: $(c.t_hold_dim)
  protocol_kind: hold_only_long_time
  lit_anchor: Prasad_2019_arXiv_1906.08664
  generator: scripts/validation/klaus_long_time_vortex_gen.jl

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
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 200
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

  - dynamics:   # LONG weak-field hold with rotation
      duration: $(round(c.t_hold_dim; digits=4))
      dt: 0.005
      rotating_frame_omega: $(c.omega)
      B: {Bz: "$(B_FINAL) Gauss", theta: 0.0, phi: 0.0}
      ddi: {enabled: true, secular: false}
      lhy: {kind: none}
      save:
        every: 1000
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

function main()
    println("Generating klaus_long_time configs in $OUTDIR")
    for c in CELLS
        name = "$(c.name).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(c))
        ms = round(c.t_hold_dim * 1000 / OMEGA_REF; digits=1)
        println("  wrote $name  (Ω=$(c.omega), hold=$(c.t_hold_dim) ω⁻¹ ≈ $ms ms)")
    end
    println("Done — $(length(CELLS)) cells.")
end

main()
