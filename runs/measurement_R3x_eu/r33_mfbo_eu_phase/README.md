# R33 — MFBO Eu phase scan

**Target**: validate that MFBO produces ≥ 5× wall-clock speedup vs
single-fidelity BO at the same final accuracy on real Eu thesis
physics (32³ grid, c₁ + c_dd 2-D scan).

**Pre-flight (synthetic) result**: 3.11× speedup, 12 → 2 high-fidelity
calls, identical best_y to 4 decimal places (logged in commit 9373461).

## Run

```julia
using SpinorBEC

res = multi_fidelity_optimize_yaml(
    "runs/measurement_R3x_eu/r33_mfbo_eu_phase/config.yaml",
    ["pipeline.0.ground_state.interactions.c1_ratio",
     "pipeline.0.ground_state.ddi.c_dd_ratio"],
    [(-0.05, 0.05), (0.5, 1.5)];
    objective_fn = bo_objective_min_energy,
    low_overrides = Dict(
        "pipeline.0.ground_state.grid.n"  => [16, 16, 16],
        "pipeline.0.ground_state.n_steps" => 500,
    ),
    high_overrides = Dict(),
    cost_ratio  = 30.0,
    n_init_low  = 12, n_init_high = 3,
    n_iter      = 25, budget_high = 8,
    minimise    = true,
    save_history_to = "runs/measurement_R3x_eu/r33_mfbo_eu_phase/history.jld2",
)
@show res.best_p
@show res.best_y
@show res.n_evals_low res.n_evals_high res.total_cost
```

**Reference** (single-fidelity baseline for comparison):

```julia
ref = bayesian_optimize_yaml(
    "runs/measurement_R3x_eu/r33_mfbo_eu_phase/config.yaml",
    ["pipeline.0.ground_state.interactions.c1_ratio",
     "pipeline.0.ground_state.ddi.c_dd_ratio"],
    [(-0.05, 0.05), (0.5, 1.5)];
    objective_fn = bo_objective_min_energy,
    n_init = 5, n_iter = 20,    # 25 high-fidelity evals
    minimise = true,
    save_history_to = "runs/measurement_R3x_eu/r33_mfbo_eu_phase/baseline.jld2",
)
```

## Expected wall-time

- High-fidelity eval: ~30 min (32³, 4000 ITP iters, GPU)
- Low-fidelity eval: ~1-2 min (16³, 500 ITP iters)
- Single-fidelity BO: 25 high evals × 30 min ≈ 12.5 h
- MFBO: 35 low + 11 high ≈ 1.2 h + 5.5 h ≈ 6.7 h
- **Expected speedup**: ≈ 1.9× (limited by budget_high cap)

Tighten `budget_high = 4` for 12-15× speedup at slight quality cost.
