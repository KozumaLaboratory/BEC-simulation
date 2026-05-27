#!/usr/bin/env julia
#
# eu_k3_arrest_gen.jl — K3 / γ_dr / LHY factorial at the
# COLLAPSING regime (N=30k, ω_z=0.25 cigar) found by the
# `eu_collapse_search` (Task #17). Here Hamiltonian-only crosses
# peak > 2× initial at t = 4.0 dimless, so we can ask the actual
# "K3 arrests collapse?" question.
#
# 8-cell factorial mirrors `eu_robust_factorial` but at the
# cigar/low-N regime. Same K3 × γ_dr × LHY axes; same observables.
#
# CPU 32³ at ~5 min/cell × 8 ≈ 40 min.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_arrest")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0
const SAVE_EVERY = 100
const K3_LIST = "[" * join(fill("\"1.0e-41 m^6/s\"", 13), ", ") * "]"

# Winning collapse regime from `eu_collapse_search/summary.json`:
const N_ATOMS = 30_000
const OMEGA_Z = 0.25

function _config_text(K3::Bool, GDR::Bool, LHY::Bool)
    lhy_kind = LHY ? "scalar" : "none"
    loss_block = if K3 || GDR
        parts = String[]
        GDR && push!(parts, "        gamma_dr: 0.02")
        K3 && push!(parts, "        K3_per_m_si:\n          $(K3_LIST)")
        "      loss:\n" * join(parts, "\n") * "\n"
    else
        ""
    end

    return """
# K3 arrest factorial at collapsing regime — auto-generated.
# Source: scripts/validation/eu_k3_arrest_gen.jl
# Regime: N=$N_ATOMS, ω_z=$OMEGA_Z (cigar), Eu Hamiltonian-only collapses
#         at this baseline (peak doubles at t=4.0 dimless per collapse
#         search). This factorial tests whether K3/γ_dr/LHY arrest it.

metadata:
  suite: eu_k3_arrest
  ladder_level: 12
  parent_search: eu_collapse_search/N30000_omz0p25
  K3_on: $K3
  gdr_on: $GDR
  LHY_on: $LHY
  generator: scripts/validation/eu_k3_arrest_gen.jl

defaults:
  kind: spinor
  backend: cpu
  interactions: {N_atoms: $N_ATOMS, omega_ref: 628.3}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, $OMEGA_Z]}
      interactions:
        N_atoms: $N_ATOMS
        omega_ref: 628.3
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
      duration: $T_EVOLUTION
      dt: 0.005
      B:
        Bz: {from: 0.01, to: 2.6e-5, duration: 0.0}
        theta: 0.0
        phi: 0.0
      ddi:
        secular: false
      lhy: {kind: $lhy_kind}
$loss_block      seed_amplitude: 1.0e-6
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

function main()
    println("Generating K3-arrest factorial at collapsing regime in $OUTDIR")
    println("  (N=$N_ATOMS, ω_z=$OMEGA_Z)")
    for K3 in (false, true), GDR in (false, true), LHY in (false, true)
        name = "K$(K3 ? 1 : 0)_gdr$(GDR ? 1 : 0)_LHY$(LHY ? 1 : 0).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(K3, GDR, LHY))
        println("  wrote $name (K3=$K3, gdr=$GDR, LHY=$LHY)")
    end
end

main()
