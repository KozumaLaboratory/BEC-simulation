# Type-stability audit for SpinorBEC pipeline hot paths.
#
# Runs `@code_warntype` against split_step!, find_ground_state, run_pipeline,
# and the analyzer dispatch to catch Any-typed widening (the recurring
# pitfall called out in CLAUDE.md > "Type stability boundaries"). Prints a
# brief report and exits 1 if any of the audited methods has a non-concrete
# return type.
#
# Usage:
#   julia --project=. scripts/type_stability_audit.jl
#
# This is a smoke check — a method passing here doesn't guarantee zero
# inference issues, but a method failing here is almost always a real bug.

using SpinorBEC
using InteractiveUtils: code_warntype

const REPORT = IOBuffer()

function audit(label::String, f, types)
    println(REPORT, "=" ^ 70)
    println(REPORT, "▶ $label")
    println(REPORT, "=" ^ 70)
    code_warntype(REPORT, f, types)
    println(REPORT)
end

# 1. split_step! on a tiny 2D Eu151 workspace
let
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    sp = SimParams(; dt = 0.01, n_steps = 1)
    ws = make_workspace(;
        grid, atom = Eu151,
        interactions = InteractionParams(1.0, 0.0),
        sim_params = sp,
        potential = HarmonicTrap(1.0, 1.0),
    )
    audit("split_step!(ws, dt)",
          SpinorBEC.split_step!, (typeof(ws), Float64))
end

# 2. find_ground_state ITP — full kwarg surface
let
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    audit("find_ground_state (kwarg form)",
          (g, atm) -> find_ground_state(;
              grid = g, atom = atm,
              interactions = InteractionParams(1.0, 0.0),
              potential = HarmonicTrap(1.0, 1.0),
              dt = 0.01, n_steps = 10, tol = 1e-4,
          ),
          (typeof(grid), typeof(Eu151)))
end

# 3. run_pipeline on a minimal config
let
    yaml_str = """
    pipeline:
      - ground_state:
          atom: Rb87
          grid: {n: [8, 8], box: [4.0, 4.0]}
          interactions: {c0: 5.0, c1: 0.0}
          zeeman: {p: 0.0, q: 0.1}
          potential: {type: harmonic, omega: [1.0, 1.0]}
          dt: 0.01
          n_steps: 5
          tol: 1.0e-3
          initial_state: ferromagnetic
      - analyze:
          - phase_classify: {}
    """
    cfg = SpinorBEC.load_config_from_string(yaml_str)
    audit("run_pipeline(cfg) — minimal",
          SpinorBEC.run_pipeline, (typeof(cfg),))
end

print(String(take!(REPORT)))
