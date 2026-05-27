#!/usr/bin/env julia
#
# eu_k3_sweep_gen.jl — Task #19A: K3 arrest threshold sweep at the
# cigar collapse regime (N=30k, ω_z=0.25). Hold LHY = γ_dr = off to
# isolate pure K3 response. K3_factor multiplies the literature
# Dy-proxy K3_0 = 1.0e-41 m⁶/s.
#
# Goal: find the smallest K3_factor that converts the K3=1× "delay
# only" behavior (t_coll = 4.0 → 7.5) into actual arrest
# (peak_max plateaus or decreases instead of doubling).
#
# 7 cells × ~6 min CPU 32³ ≈ 40 min total.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_sweep")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0
const SAVE_EVERY = 50           # finer than arrest factorial — 40 snapshots over 4000 steps for clearer collapse onset detection
const N_ATOMS = 30_000
const OMEGA_Z = 0.25
const K3_FACTORS = [0.0, 1.0, 3.0, 10.0, 30.0, 100.0, 150.0, 200.0, 250.0, 300.0]
const K3_BASE_SI = 1.0e-41      # m⁶/s; Dy164 proxy used in eu_k3_arrest

function _k3_list(factor::Float64)
    # 13 entries (Eu F=6, 2F+1=13 components). All equal.
    val = factor * K3_BASE_SI
    entries = ["\"" * string(val) * " m^6/s\"" for _ in 1:13]
    "[" * join(entries, ", ") * "]"
end

function _config_text(factor::Float64)
    loss_block = if factor > 0
        "      loss:\n        K3_per_m_si:\n          $(_k3_list(factor))\n"
    else
        ""
    end

    return """
# K3 arrest threshold sweep — auto-generated.
# Source: scripts/validation/eu_k3_sweep_gen.jl
# Regime: N=$N_ATOMS, ω_z=$OMEGA_Z (cigar collapse regime).
# K3_factor = $(factor) × Dy proxy = $(factor * K3_BASE_SI) m⁶/s
# LHY off, γ_dr off — isolating pure K3 response.

metadata:
  suite: eu_k3_sweep
  ladder_level: 12
  parent_regime: cigar_N30k_omz0p25
  K3_factor: $factor
  K3_per_m_si_value: $(factor * K3_BASE_SI)
  generator: scripts/validation/eu_k3_sweep_gen.jl

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
      lhy: {kind: none}
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
      lhy: {kind: none}
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
    println("Generating K3 sweep configs in $OUTDIR")
    for f in K3_FACTORS
        name = "K3x$(replace(string(f), "." => "p")).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(f))
        println("  wrote $name (factor=$f → K3 = $(f * K3_BASE_SI) m⁶/s)")
    end
end

main()
