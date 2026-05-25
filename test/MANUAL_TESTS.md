# Manual test inventory

Tests under `test/` that are intentionally NOT wired into
`test/runtests.jl` because they depend on environment conditions the
default test runner cannot guarantee (GPU, dashboard build, opt-in
heavy YAML, scenario directories pending schema migration).

Run each manually as documented below.

## GPU-dependent

### `gpu/test_cuda.jl`

Coarse CUDA backend smoke (Workspace creation, split_step, ground
state on GPU vs CPU). Internally guards on `CUDA.functional()` and
returns silently when CUDA is unavailable.

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  julia --project=. -e 'using CUDA; using SpinorBEC; include("test/gpu/test_cuda.jl")'
```

### `rotating_basis/test_rotating_basis_gpu.jl`

Option-γ rotating_basis on GPU. Exercises every public function with
`CUDA.allowscalar(false)` to surface scalar-indexing bugs. **Errors**
(not skips) if `CUDA.functional() == false`, so it cannot live in the
default-loaded tier.

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  julia --project=. -e 'using CUDA; using SpinorBEC; include("test/rotating_basis/test_rotating_basis_gpu.jl")'
```

## Heavy YAML (opt-in via `SPINORBEC_RUN_HEAVY_YAML=true`)

These tests run full `run_yaml` / `run_config` pipelines. CLAUDE.md
notes a trivial pipeline takes >4 min to first output due to
`Workspace{...23 type params...}` specialisation. Nightly CI sets
`SPINORBEC_RUN_HEAVY_YAML=true`; default `Pkg.test()` does not.

### `workflow/test_active_learning_yaml.jl`

Active-learning YAML wrapper end-to-end (R38). Gates on
`_SKIP_HEAVY_YAML_AL = ENV["SPINORBEC_RUN_HEAVY_YAML"] != "true"`.

```bash
SPINORBEC_RUN_HEAVY_YAML=true \
  julia --project=. -e 'using SpinorBEC; include("test/workflow/test_active_learning_yaml.jl")'
```

### `workflow/test_multi_fidelity_yaml.jl`

Multi-fidelity BO YAML wrapper (R34). Same gate
`_SKIP_HEAVY_YAML_MFBO`.

```bash
SPINORBEC_RUN_HEAVY_YAML=true \
  julia --project=. -e 'using SpinorBEC; include("test/workflow/test_multi_fidelity_yaml.jl")'
```

## Pending Step 2 schema audit (2026-05-25 priorities)

### `workflow/test_klaus_validation.jl`

Klaus 2022 minimal regression — Dy164 16²×8 + 0.5 ω_ref⁻¹ stir.
Uses `initial_state: ferromagnetic_min`, `save: {every: ...}`,
`Bx: {sinusoidal: ...}`. Confirm each maps to current schema before
wiring.

```bash
julia --project=. -e 'using SpinorBEC; include("test/workflow/test_klaus_validation.jl")'
```

## External-process dependent

### `workflow/test_live_monitor.jl`

Spawns `serve_dashboard` on a port and exercises `/api/lab/image`
via raw `Sockets`. Requires `dashboard/dist/index.html` (the test
auto-creates a stub if missing) and a free TCP port. Excluded from
the default tier because TCP binding can collide on CI agents.

```bash
julia --project=. -e 'using SpinorBEC; include("test/workflow/test_live_monitor.jl")'
```

## Classification audit (2026-05-25)

This file was produced by the orphan-test audit step of the
post-InteractionParams-refactor priorities. Of 28 orphan tests
identified, 8 were promoted to `FAST_TESTS`, 12 to `FULL_EXTRA`,
6 remained manual (above), and 2 were deleted:
`test_p2_scenarios.jl` and `test_p34_scenarios.jl` referenced
`runs/scenarios/p*` directories that were curated away by commit
`35245e7 chore(runs)!: curate to 8 essential YAMLs`. The tests
couldn't function without the deleted fixtures.

Four latent bugs surfaced by the audit and fixed in the same pass:

- `src/workflow/experiments/optimization/bayesian_opt.jl` was missing
  `LinearAlgebra: diag` in its imports, so any caller of `gp_predict`
  (downstream of `multi_fidelity_optimize_2tier`,
  `active_learn_phase_scan`, `detect_triple_points`) hit
  `UndefVarError: diag`. All three orphan tests that exercised it
  failed identically — exactly the latent-bug-reservoir pattern that
  motivated the audit.
- `test/gpu/test_mixed_precision_phase3.jl` passed `1.0f0` to
  `HarmonicTrap`, which only has `Float64` constructors. Test bug.
- `test/gpu/test_mixed_precision.jl` "F32 DDI workspace & step"
  built a workspace without `psi_init`, leaving ψ at zero, then
  computed `(n1 - n0) / n0 = 0/0 = NaN`. Test bug.
- `test/analysis/test_imaging.jl` used `Statistics.mean` without
  importing it. Test bug.

Two `FAST`-classified tests (`workflow/test_multi_fidelity_bo.jl`,
`workflow/test_triple_point.jl`) were reclassified to `FULL_EXTRA`
when the wall-clock smoke ran 134s and 106s respectively (BO/GP
fitting cost). They contain no SpinorBEC physics, but their actual
cost exceeded the FAST tier's "~30s total" budget.
