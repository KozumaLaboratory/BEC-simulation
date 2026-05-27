#!/usr/bin/env julia
#
# l4_k3_ladder_gen.jl — generate Task #14 YAML configs:
#   L4 K3 collapse-arrest ladder. Push Eu Hamiltonian-only into the
#   high-resolution collapse regime, then test whether K3 / γ_dr / LHY
#   arrest the collapse.
#
# Matrix (12 cells):
#   64³  × {HamOnly, K3, gdr, K3+gdr, K3+LHY}
#   96³  × {HamOnly, K3, gdr, K3+gdr, K3+LHY}
#   128³ × {HamOnly, K3}
#
# Each cell: 32 ms physical evolution (t = 20.0 dimless = 3.2 × τ_EdH).
# Longer than the standard 10 ms Matsui benchmark to give collapse onset
# (if it exists at the chosen N, density) time to develop. dt = 0.005,
# dealias k_cut = 16 per the L4 cross-grid convergence recipe
# (validation_ladder_2026_05_22 memory).
#
# Cost (GPU est, very rough):
#   64³  : ~5-10 min/cell  →  5 cells × ~8 min = ~40 min
#   96³  : ~20-30 min/cell →  5 cells × ~25 min = ~2.1 h
#   128³ : ~60-90 min/cell →  2 cells × ~75 min = ~2.5 h
#   total: ~5 h GPU
# At 32³ CPU baseline was 3.3 min; high-res GPU is the only practical
# path. Use the `--grid 64` filter argument to generate only the 64³
# subset (fast subset for first-pass iteration).

const OUTDIR = joinpath(@__DIR__, "..", "..", "runs", "l4_k3_ladder")
mkpath(OUTDIR)

const T_EVOLUTION = 20.0   # dimless = ~32 ms at ω_ref = 628.3
const SAVE_EVERY = 100     # 20 saves over 2000 steps → frame_density adequate for onset detection
const K3_LIST = "[" * join(fill("\"1.0e-41 m^6/s\"", 13), ", ") * "]"

function _config_text(grid_n::Int, K3::Bool, gdr::Bool, lhy::Bool, scenario::String)
    lhy_kind = lhy ? "scalar" : "none"
    loss_block = if K3 || gdr
        parts = String[]
        gdr && push!(parts, "        gamma_dr: 0.02")
        K3 && push!(parts, "        K3_per_m_si:\n          $(K3_LIST)")
        "      loss:\n" * join(parts, "\n") * "\n"
    else
        ""
    end

    return """
# Task #14 L4 K3 collapse-arrest ladder — auto-generated.
# Source: scripts/validation/l4_k3_ladder_gen.jl
# Grid: $(grid_n)³, scenario: $scenario, t_evolution: $T_EVOLUTION dimless
# Pass criteria: see runs/l4_k3_ladder/README.md

metadata:
  suite: l4_k3_collapse_arrest_ladder
  ladder_level: 12
  grid_n: $grid_n
  scenario: $scenario
  K3_on: $K3
  gdr_on: $gdr
  LHY_on: $lhy
  generator: scripts/validation/l4_k3_ladder_gen.jl

defaults:
  kind: spinor
  backend: gpu
  interactions: {N_atoms: 30000, omega_ref: 628.3}

dealias:
  enabled: true
  k_cut: 16.0
  auto_dt: true
  dt_safety: 10.0

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$grid_n, $grid_n, $grid_n], box: [12.0, 12.0, 12.0]}
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

const SCENARIOS = (
    ("HamOnly", false, false, false),
    ("K3", true, false, false),
    ("gdr", false, true, false),
    ("K3gdr", true, true, false),
    ("K3LHY", true, false, true),
)

const SCENARIOS_HIRES = (    # 128³ subset
    ("HamOnly", false, false, false),
    ("K3", true, false, false),
)

function main()
    filter_grid = nothing
    for (i, a) in enumerate(ARGS)
        if a == "--grid" && i < length(ARGS)
            filter_grid = parse(Int, ARGS[i + 1])
        end
    end

    println("Generating L4 K3 ladder in $OUTDIR")
    if filter_grid !== nothing
        println("  (restricted to grid = $filter_grid)")
    end
    n_written = 0
    for n in (64, 96, 128)
        filter_grid !== nothing && n != filter_grid && continue
        scenarios = n == 128 ? SCENARIOS_HIRES : SCENARIOS
        for (name, K3, gdr, lhy) in scenarios
            base = "L4_K3_n$(n)_$(name)"
            path = joinpath(OUTDIR, base * ".yaml")
            write(path, _config_text(n, K3, gdr, lhy, name))
            println("  wrote $(base).yaml (n=$n K3=$K3 gdr=$gdr LHY=$lhy)")
            n_written += 1
        end
    end
    println("Generated $n_written configs.")
end

main()
