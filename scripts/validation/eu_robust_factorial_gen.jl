#!/usr/bin/env julia
#
# eu_robust_factorial_gen.jl — generate 8 YAML configs for the post-pivot
# Eu robust factorial: every combination of {K3 off/on} × {γ_dr off/on} ×
# {LHY off/on} on top of the canonical L4 Hamiltonian-only baseline.
#
# Rationale (docs/validation/self_contained_validation_report.md →
# "Production claim shape"):
#   Conclusions are robust ⇔ they are invariant across this factorial.
#   Hamiltonian-only is collapse-dominated at high resolution; K3, γ_dr,
#   LHY are the dissipative / model axes the experiment imposes. The
#   robustness claim must enumerate which physical observables agree
#   across enough cells.
#
# Each combination writes:
#   runs/eu_robust_factorial/K{0,1}_gdr{0,1}_LHY{0,1}.yaml
#
# Sources match L4_eu_matsui_hamiltonian_only_32.yaml:
#   atom = Eu151, N = 30000, ω_ref = 628.3, c1_ratio = -0.005,
#   grid = (32, 32, 32) box=12, harmonic trap ω = (1,1,1),
#   initial m=-F, Bz quench from 0.01 G to 2.6e-5 G,
#   t_evolution = 6.28 dimless = 10 ms physical.
#
# Loss parameter values (dry_run baselines):
#   K3_per_m_si  = 1.0e-41 m^6/s for every m (13 entries, Eu F=6)
#   gamma_dr     = 0.02 (dimless)
# These are Dy164 order-of-magnitude proxies; Eu has no measured K3 yet.
# The factorial is about *whether the qualitative answer depends on them*,
# not about getting the absolute number right.

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "eu_robust_factorial")
mkpath(OUTDIR)

const COMMON_HEADER = """
# Eu robust factorial — auto-generated, do not hand-edit.
# Source: scripts/validation/eu_robust_factorial_gen.jl
# See docs/validation/self_contained_validation_report.md for design.
#
# Factorial cell:
#   K3_on  = {K3}
#   gdr_on = {GDR}
#   LHY_on = {LHY}
"""

const K3_LIST = "[" * join(fill("\"1.0e-41 m^6/s\"", 13), ", ") * "]"

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

    header = replace(COMMON_HEADER,
        "{K3}" => string(K3),
        "{GDR}" => string(GDR),
        "{LHY}" => string(LHY))

    return """
$header
metadata:
  suite: spinorbec_eu_robust_factorial
  ladder_level: 12
  K3_on: $K3
  gdr_on: $GDR
  LHY_on: $LHY
  generator: scripts/validation/eu_robust_factorial_gen.jl

defaults:
  kind: spinor
  backend: cpu                       # CPU at 32³ avoids the per-environment
                                      # CUDA loader issues that broke the GPU
                                      # smoke run; still ~few-min per cell
  interactions: {N_atoms: 30000, omega_ref: 628.3}

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions:
        N_atoms: 30000
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
      n_steps: 1500
      tol: 1.0e-9

  - dynamics:
      duration: 6.28
      dt: 0.01
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
        every: 50
        psi: true
        precision: f64

  - analyze:
      - phase_classify: {}
      - winding_map: {}
      - energy_decomposition: {}
"""
end

function main()
    println("Generating Eu robust factorial in $OUTDIR")
    count = 0
    for K3 in (false, true), GDR in (false, true), LHY in (false, true)
        name = "K$(K3 ? 1 : 0)_gdr$(GDR ? 1 : 0)_LHY$(LHY ? 1 : 0).yaml"
        path = joinpath(OUTDIR, name)
        write(path, _config_text(K3, GDR, LHY))
        println("  wrote $name (K3=$K3, gdr=$GDR, LHY=$LHY)")
        count += 1
    end
    println("Generated $count configs.")
end

main()
