#!/usr/bin/env julia
#
# eu_lhy_longtime_gen.jl — Task #26: long-time stability ladder for
# polar_contact / icosahedral LHY at K3=0 cigar regime. Per anko's
# 2026-05-26 framing: the "stable_arrest" claim applies only to the
# simulated time window (so far t=20 dimless ≈ 29 ms). Long-time
# metastability needs explicit testing.
#
# Three durations, two LHY models, 6 cells:
#   t = 34.6 ω_ref⁻¹  ≈ 50 ms
#   t = 69.1 ω_ref⁻¹  ≈ 100 ms
#   t = 138.2 ω_ref⁻¹ ≈ 200 ms
# LHY ∈ {polar_contact, icosahedral}, K3 = 0.
#
# Grid 64³ GPU. 50 ms ≈ 25 min/cell; 100 ms ≈ 50 min; 200 ms ≈ 100 min.
# Total ~5 h GPU.
#
# If 50 ms cells stay clean (peak plateau, energy drift small),
# proceed to 100 ms. If 100 ms still clean, proceed to 200 ms. If any
# step shows drift or collapse onset, branch to dt/2 + 96³ + seed×3
# controls.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_lhy_longtime")
mkpath(OUTDIR)

const OMEGA_REF = 628.3
const SAVE_EVERY = 200    # ~70 frames at 50ms, 140 at 100ms, 280 at 200ms
const N_ATOMS = 30_000
const OMEGA_Z = 0.25

# Convert ms → dimless time: t_dimless = t_ms * 1e-3 * omega_ref
const T_50 = 50e-3 * OMEGA_REF   # 31.4 dimless
const T_100 = 100e-3 * OMEGA_REF  # 62.8 dimless
const T_200 = 200e-3 * OMEGA_REF  # 125.7 dimless

function _config_text(lhy_kind::String, duration::Float64, ms_label::String)
    return """
# Long-time LHY stability ladder — auto-generated.
# Source: scripts/validation/eu_lhy_longtime_gen.jl
# LHY = $lhy_kind, K3 = 0, duration = $(round(duration; digits=2)) ω_ref⁻¹ ≈ $ms_label

metadata:
  suite: eu_lhy_longtime
  ladder_level: 12
  parent_regime: cigar_N30k_omz0p25
  K3_factor: 0
  LHY_kind: $lhy_kind
  target_ms: $ms_label
  generator: scripts/validation/eu_lhy_longtime_gen.jl
  caveat: |
    Tests whether "polar/icosa LHY → stable_arrest with N=1.000"
    survives at simulated time well beyond the original 30 ms window.

defaults:
  kind: spinor
  backend: gpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: $OMEGA_REF}

dealias:
  enabled: true
  k_cut: 16.0
  auto_dt: true
  dt_safety: 10.0

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $OMEGA_Z]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: $OMEGA_REF
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
      duration: $(round(duration; digits=4))
      dt: 0.005
      B:
        Bz: {from: 0.01, to: 2.6e-5, duration: 0.0}
        theta: 0.0
        phi: 0.0
      ddi:
        secular: false
      lhy: {kind: $lhy_kind}
      # NO loss block — K3 = 0
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

const CELLS = [
    ("polar_contact", T_50, "50ms"),
    ("polar_contact", T_100, "100ms"),
    ("polar_contact", T_200, "200ms"),
    ("icosahedral", T_50, "50ms"),
    ("icosahedral", T_100, "100ms"),
    ("icosahedral", T_200, "200ms"),
]

for (kind, dur, lab) in CELLS
    name = "LHY_$(kind)_$(lab).yaml"
    path = joinpath(OUTDIR, name)
    write(path, _config_text(kind, dur, lab))
    println("wrote $name (kind=$kind, duration=$dur, target=$lab)")
end
