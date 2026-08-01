# Manual test inventory — empty

**No file under `test/` is outside a tier.** `MANUAL_TESTS_ALLOWLIST` in
`test/_tiers.jl` is `String[]`, and `test_tier_membership.jl` asserts this file
and that list agree.

It held five files / 53 assertions that no tier ran, untouched since
2026-05-25, each with an environment reason nobody had rechecked since. Every
one was run, 2026-07-31 / 08-02:

| file | was filed as | what was actually true | now |
|---|---|---|---|
| `gpu/test_cuda.jl` | "needs GPU to be useful" | guards on `CUDA.functional()` like every other `gpu/` file — on a CPU-only runner it is the same no-op they are. 3.9 s on a GPU host | `FULL_EXTRA` |
| `workflow/test_active_learning_yaml.jl` | "heavy YAML" | already carried `_SKIP_HEAVY_YAML_AL`: 0.0 s with the flag off, 21.7 s with it on | `CI_EXTRA` |
| `workflow/test_multi_fidelity_yaml.jl` | "heavy YAML" | same shape; 0.0 s / **776 s on the runner** — see `_COST` | `CI_EXTRA` |
| `workflow/test_klaus_validation.jl` | "pending schema audit" | the schema was fine. `initial_state: m_plus_F` was inverted against the field sign, so ITP underflowed every surviving component and the state normalised to NaN. 68 s at the real 1 Gauss field | `CI_EXTRA` |
| `workflow/test_live_monitor.jl` | "spawns a server on a TCP port" | the port was never the problem. Two independent defects, the first hiding the second — see below. 10 s | `CI_EXTRA` |

**Three of the five needed no code change at all** — only for someone to run
them.

## What was wrong with `test_live_monitor.jl`

1. The POST sent no `Connection: close`, and the test then did
   `read(sock, String)`, which reads to EOF. HTTP/1.1 keeps the connection
   alive by default, so the read never returned.
2. Teardown was `Base.throwto(srv_task, InterruptException())` on a task parked
   in `accept`. `throwto` switches to the target task and does not reliably
   come back, so the server stayed up and the process hung until something
   killed it (measured: SIGTERM at a 2400 s timeout, `Press Ctrl+C to stop` in
   the log).

`serve_dashboard` had no way to be stopped programmatically — it creates its
listen socket internally and loops on `accept`, exiting only on an
`InterruptException`. It now takes `server_ref::Ref`, so a caller that spawned
it on a task can `close(ref[])`; `accept` throws, the `finally` runs, and
`wait(srv_task)` is deterministic. That is useful beyond the test.

Fixing the hang exposed a third defect that had never executed:
`Base.Filesystem.touch(path; times=…)` is not a Julia method. The endpoint ages
a run by its **mtime** (`routes/lab_live.jl`), so the back-dating is real and is
now done with `touch -d @epoch`, with an assertion that it took.

## Keep this empty

A file that cannot run is a file to fix or delete. Parking one here is how 53
assertions stopped being tests for ten weeks. If something genuinely must be
manual it needs an entry here with a reason that was **measured**.

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
