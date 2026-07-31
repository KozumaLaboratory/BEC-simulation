# Manual test inventory

Two files under `test/` are not wired into any tier. Each reason was
**measured**, not inherited (2026-07-31): every candidate was run, with and
without `SPINORBEC_RUN_HEAVY_YAML=true`, and the three that passed were moved
into tiers. What is left is what genuinely cannot run.

The old framing — "depend on environment conditions the default test runner
cannot guarantee (GPU, dashboard build, opt-in heavy YAML, scenario directories
pending schema migration)" — had stopped being true for three of the five, and
nothing had checked since 2026-05-25. Between them those three carried 35
assertions that no tier ran.

`MANUAL_TESTS_ALLOWLIST` in `test/_tiers.jl` is the machine-readable copy;
`test_tier_membership.jl` asserts the two agree.

## `workflow/test_klaus_validation.jl` — cannot run as written

Not an environment problem. Its `ground_state` step uses the real experimental
field (`B: {Bz: "1.0 Gauss"}`, Dy164, `omega_ref: 314.159`) at `dt: 0.001`.
That is `p ≈ −3.5e4`, so across `m = ±8` the ITP exponent spans
`|p·m·dt| ≈ 278` and `exp` overflows on the first step:

```
ArgumentError: NaN detected in ITP at step 1. Likely DDI or interaction
overflow. Reduce dt.
```

`hamiltonian/test_b_block_builders.jl` documents the same footgun and
deliberately uses `Bz: 1.0e-4` to avoid it:

> Tiny Bz to avoid ITP exp-V underflow at large dimensionless p. Real
> experimental values (e.g. Klaus 2022 Bz=0.819G) give p≈3e4 which requires
> matching small dt and physics-aware setup — not a plumbing test.

So this is a physics-setup decision (a smaller ground-state field with a ramp,
or a `dt` matched to `p`), not the "pending schema audit" it was filed under.
Until that decision is made the file cannot be run at all:

```bash
SPINORBEC_RUN_HEAVY_YAML=true julia --project=. \
  -e 'using Test; using SpinorBEC; include("test/workflow/test_klaus_validation.jl")'
```

It is also the only artifact behind the Klaus 2022 entry in the type-C registry
(`test/validation/test_type_c_claims.jl`), which is why that entry is ungated.

## `workflow/test_live_monitor.jl` — blocks forever

`serve_dashboard` does not return until the server is closed, and this file's
close path is never reached, so the run hangs until something kills it
(measured: SIGTERM at a 2400 s timeout, `Press Ctrl+C to stop` in the log). Its
own comment states the intent — *"the function blocks until the server is
closed; we'll close it manually"* — which is exactly what does not happen.

Needs restructuring (serve on a task, assert, close in a `finally`), not a tier
entry. Run it only if you are prepared to interrupt it:

```bash
julia --project=. \
  -e 'using Test; using SpinorBEC; include("test/workflow/test_live_monitor.jl")'
```

## Moved into tiers, 2026-07-31

| file | was filed as | measured | now |
|---|---|---|---|
| `gpu/test_cuda.jl` | "gated, but needs GPU to be useful" | guards on `CUDA.functional()` like every other `gpu/` file; 3.9 s on a GPU host, no-op without one | `FULL_EXTRA` |
| `workflow/test_active_learning_yaml.jl` | "heavy YAML" | carries its own `_SKIP_HEAVY_YAML_AL`; 0.0 s with the flag off, 19.7 s with it on, passes both ways | `CI_EXTRA` |
| `workflow/test_multi_fidelity_yaml.jl` | "heavy YAML" | same shape; 0.0 s / 50.2 s | `CI_EXTRA` |

The heavy-YAML pair needed no guard added — they already had one. The entry in
this file was the only thing keeping them out of a tier.

## Re-audit (2026-06-19)

Second orphan sweep. Of 12 files outside every tier list, the 6 above
remained manual (now also enumerated in `MANUAL_TESTS_ALLOWLIST` in
`runtests.jl` so the new tier-membership meta-test can tell "deliberately
manual" from "orphaned"). The other 6 had fallen through entirely
(neither in a tier nor here) and were resolved by reduction:

- **Deleted** (abandoned orphans that ran nowhere; the genuinely
  half-baked tail). Two were pure-introspection dispatch-coverage micro
  guards (`solvers/test_lbfgs_forward_coverage.jl`,
  `workflow/test_make_workspace_kwarg_coverage.jl`) — plumbing, not
  physics. Three were gates that overlap running oracle coverage
  (`hamiltonian/test_outer_operator_equivalence.jl` overlaps the
  imag-time propagator/operator gate; `oracles/test_gpu_cpu_fused_group_parity.jl`
  is a CPU no-op and the per-term GPU parity gate runs;
  `oracles/test_multistart_winner_selection.jl` is solver-logic, not a
  physics gate). Recoverable from git history if a specific one is wanted
  back as a running test.
- **Relocated out of `test/`**: `validation/test_validation_matrix.jl`
  was a CSV/Markdown-emitting runner script, not a test — moved to
  `scripts/validation/run_validation_matrix.jl` (its documented home;
  `@__DIR__/../..` still resolves to the repo root, so the test paths it
  loads are unaffected). This also un-breaks the doc links in
  `docs/validation/*` that already pointed at the `scripts/` path.

A new FAST meta-test, `test/test_tier_membership.jl`, now enforces that
every `test_*.jl` under `test/` is in exactly one tier list or this
allowlist — so the orphan-drift state cannot recur unnoticed.

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
