# R36 — 4-D Eu phase active learning

**Target**: validate that AL with entropy acquisition concentrates
samples on the phase-boundary surface in 4-D (c₁/c₀, c_dd/c₀, p, q),
beating uniform-grid sample efficiency by ≥ 3-5×.

**Pre-flight (synthetic 2-D)**: 66.7 % of post-init samples landed
within 0.2 of the boundary vs 40 % random baseline.

## Run

```julia
using SpinorBEC

res = active_learn_phase_scan_yaml(
    "runs/measurement_R3x_eu/r36_4d_phase_al/config.yaml",
    [
        "pipeline.0.ground_state.interactions.c1_ratio",
        "pipeline.0.ground_state.ddi.c_dd_ratio",
        "pipeline.0.ground_state.B.p",
        "pipeline.0.ground_state.B.q",
    ],
    [
        (-0.05,  0.05),     # c₁/c₀
        ( 0.5,   1.5),      # c_dd/c₀
        ( 0.0,  10.0),      # p (Zeeman)
        (-1.0,   1.0),      # q (Zeeman)
    ];
    n_init = 20, n_iter = 200,    # 220 evals total
    temperature = 0.1,
    seed = 42, verbose = true,
    save_history_to = "runs/measurement_R3x_eu/r36_4d_phase_al/history.jld2",
)
@show res.best_p res.best_y
```

## Analysis

Post-run, plot the per-axis projection of `res.X_history`:

```julia
using JLD2, Plots
@load "runs/measurement_R3x_eu/r36_4d_phase_al/history.jld2" X_history y_history
# 4 × 4 grid of pairwise scatter, color = entropy
```

Boundary surface is where 2+ phase candidates have similar distances.
AL should concentrate post-init samples here.

## Expected wall-time

- Per-eval: ~5-30 min (24³ Eu GS + classify_phase_distance, GPU).
  Wide range because c_dd_ratio = 1.5 + p = 10 is much stiffer than
  c_dd_ratio = 0.5 + p = 0.
- 220 evals × 15 min average ≈ 55 h
- Job array: split into 2-3 sub-runs of ~ 80 evals each, run in
  parallel on multiple GPUs if available.

## Quality metrics to compute post-run

- Boundary concentration: fraction of samples in regions where
  classify_phase_distance has top-2 distances within 20 % of each
  other. Target: ≥ 50 %.
- Phase coverage: how many distinct `phase` labels appear in the
  AL trajectory. Target: ≥ 4 (polar, FM, BN, FL minimum).
- Triple-point candidates: filter the history with
  `detect_triple_points` post-hoc (R37).
