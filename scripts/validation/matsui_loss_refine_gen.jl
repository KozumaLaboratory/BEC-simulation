#!/usr/bin/env julia
#
# matsui_loss_refine_gen.jl — fine K3 bracket of Matsui experimental
# ~40% loss at the Matsui parameter set.
#
# Existing data:
#   loss-free:     N(T)/N(0) = 1.000
#   K3 factor 30:  N(T)/N(0) = 0.516
#   K3 factor 100: N(T)/N(0) = 0.244
#   Matsui experimental reference: ~0.6  ⇒  effective K3 is between
#   loss-free (factor 0) and factor 30.
#
# New 5-cell scan at GPU:  K3 factor ∈ {5, 10, 15, 20, 25}.
# All other parameters identical to the existing Matsui loss-on
# (matsui_40ms_lossy_medium.yaml).

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "matsui_baseline")
mkpath(OUTDIR)

const K3_BASE_SI = 1.0e-41           # Dy literature proxy in m^6/s
const FACTORS = [5.0, 10.0, 15.0, 20.0, 25.0]

function _k3_list(factor::Float64)
    val = factor * K3_BASE_SI
    entries = ["\"" * string(val) * " m^6/s\"" for _ in 1:13]
    "[" * join(entries, ",\n           ") * "]"
end

function _config_text(factor::Float64)
    name = "matsui_40ms_lossy_K3factor_$(Int(factor))"
    val = factor * K3_BASE_SI
    return """
# Matsui K3 fine bracket — auto-generated.
# Source: scripts/validation/matsui_loss_refine_gen.jl
# Target: bracket Matsui experimental N(T)/N(0) ≈ 0.6 at 40 ms.
#   K3 factor = $(Int(factor))  ⇒  K3 = $(val) m^6/s

metadata:
  suite: matsui_baseline
  variant: loss_refine_K3factor_$(Int(factor))
  ladder_level: 12
  reference: Matsui_2026_Science_arxiv_2504_17357
  target: 40ms_dynamics_lossy_K3factor_$(Int(factor))
  grid_n: 64
  K3_factor: $factor
  K3_per_m_si_value: $val
  caveat: |
    Phenomenological K3-only loss model.  Goal: identify the
    effective K3 that reproduces Matsui's experimental ~40% atom
    loss at 40 ms.  This is NOT a measurement of Eu's actual K3.

defaults:
  kind: spinor
  backend: gpu
  interactions: {N_atoms: 50000, omega_ref: 691.1504}

dealias:
  enabled: true
  k_cut: 16.0
  auto_dt: true
  dt_safety: 10.0

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.181818]}
      interactions:
        N_atoms: 50000
        omega_ref: 691.1504
        c1_ratio: 0.0277777778
      ddi:
        enabled: true
        secular: true
      lhy: {kind: none}
      B: {Bz: "-0.01 Gauss", theta: 0.0, phi: 0.0}
      gauge_fix: false
      initial_state: m_minus_F
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9

  - dynamics:
      duration: 27.646
      dt: 0.005
      B:
        Bz: {from: -0.01, to: -2.6e-5, duration: 0.0}
        theta: 0.0
        phi: 0.0
      ddi:
        secular: false
      lhy: {kind: none}
      loss:
        K3_per_m_si:
          $(_k3_list(factor))
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save:
        every: 200
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

function main()
    println("Generating Matsui K3-refine configs in $OUTDIR")
    for f in FACTORS
        name = "matsui_40ms_lossy_K3factor_$(Int(f)).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(f))
        println("  wrote $name  (K3 = $(f * 1.0e-41) m^6/s)")
    end
    println("Done — $(length(FACTORS)) cells.")
end

main()
