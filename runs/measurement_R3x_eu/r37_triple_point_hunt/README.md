# R37 — F=6 triple-point hunting

**Target**: detect points in the (c₁/c₀, c_dd/c₀, p, q) hyperspace
where 3+ Eu phase candidates coexist (similar `classify_phase_distance`
scores). At each candidate, trace the 3 emanating boundary curves.

**Pre-flight (synthetic equilateral 3-phase, 2-D)**: 21/21 tests pass,
centroid found within 0.4, all 3 phase pairs traced (commit 0ff6b5c).

## Run

Two-stage pipeline — AL scan first, then triple-point detection +
multi-direction trace.

```julia
using SpinorBEC

# Step 1: AL scan over the 4-D space (same as R36 but lower n_iter
# and tighter parameter ranges to keep wall time bounded).
yaml_path = "runs/measurement_R3x_eu/r37_triple_point_hunt/config.yaml"

# In-memory eval_fn that runs the YAML pipeline + extracts scores.
override_paths = [
    "pipeline.0.ground_state.interactions.c1_ratio",
    "pipeline.0.ground_state.ddi.c_dd_ratio",
    "pipeline.0.ground_state.B.p",
    "pipeline.0.ground_state.B.q",
]
bounds = [(-0.05, 0.05), (0.5, 1.5), (0.0, 5.0), (-0.5, 0.5)]

# Use the YAML wrapper so we get free heavy-gate compatibility.
al = active_learn_phase_scan_yaml(
    yaml_path, override_paths, bounds;
    n_init = 15, n_iter = 80,    # 95 evals
    temperature = 0.1, seed = 42, verbose = true,
    save_history_to = "runs/measurement_R3x_eu/r37_triple_point_hunt/al_history.jld2",
)

# Step 2: detect_triple_points needs an `eval_fn` that returns a
# NamedTuple with :scores. Build a compatible wrapper.
function eval_with_scores(θ)
    base = SpinorBEC.YAML.load_file(yaml_path; dicttype = Dict{String,Any})
    cand = SpinorBEC.OverrideMap()
    for (path, val) in zip(override_paths, θ)
        cand[path] = val
    end
    modified = SpinorBEC.apply_overrides(base, cand)
    config = SpinorBEC.parse_pipeline(modified)
    result = SpinorBEC.run_pipeline(config; verbose=false)
    scores = SpinorBEC.default_phase_classifier_extractor(result)
    (scores=scores,)
end

candidates = detect_triple_points(eval_with_scores, bounds;
    n_init = 5, n_iter = 0,       # we already ran the AL scan
    tie_ratio_max = 0.15,
    min_phases = 3,
    seed = 42, verbose = true,
)

# Step 3: trace the 3 (or more) boundary curves from the best candidate.
isempty(candidates) && error("no triple-point candidates found")
best = candidates[1]
traces = trace_triple_point_curves(best, eval_with_scores;
    arc_step = 0.005, max_steps = 30, verbose = true)

using JLD2
@save "runs/measurement_R3x_eu/r37_triple_point_hunt/triple_points.jld2" candidates traces
```

## Expected wall-time

- AL scan: 95 evals × ~10 min ≈ 16 h
- detect_triple_points filter: ~ 5 evals at 10 min each = 1 h
- Each trace: ~30 boundary points × 1 min (warm) = 30 min
- 3 traces × 30 min = 1.5 h
- **Total**: ~ 18-20 h (TSUBAME 1 day)

## What "success" looks like

A `triple_points.jld2` containing:
- ≥ 1 `TriplePointCandidate` with tie_ratio < 0.15
- 3 `BoundaryTrace` objects, each with ≥ 10 accepted points
- The 3 traced curves visually meet at the candidate when plotted
  in (c₁_ratio, c_dd_ratio) projection (other 2 axes fixed by
  candidate.θ)

If the F=6 phase diagram has a triple point in this region, the
above procedure detects it. Negative result (no candidates) is also
publishable as evidence that the boundaries don't intersect in this
parameter window.
