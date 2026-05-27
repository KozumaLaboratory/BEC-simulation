# scripts/validation/

This directory used to contain a half-dozen ad-hoc analyzer / compare
scripts (`eu_ham_only_*_analyze.jl`, `L4_post_parserfix_compare.jl`,
`export_operator_rhs.jl`, `compare_operator_rhs.jl`). They are gone.

The same workflows now live as **proper API in
`src/workflow/validation/`** (10 exported symbols), exercised by
~130 unit tests in `test/workflow/validation/`. Use the REPL — no
scripts needed.

## Common recipes

### Single-run conservation audit

```julia
using SpinorBEC
r = open_result("runs/eu_ham_only_24_nonsec_<hash>/point_001.jld2")
spec = ConservationSpec(norm_drift=1e-12, energy_rel_drift=1e-3, Jz_drift=5e-2)
res = check(spec, r)
println(res.summary)
```

Replaces: `eu_ham_only_ramp_quench_analyze.jl`,
`step5_eu_hamiltonian_only_analyze.jl`.

### Grid-convergence sweep

```julia
sweep = sweep_runs([
    "runs/L4_32_<hash>/point_001.jld2",
    "runs/L4_48_<hash>/point_001.jld2",
    "runs/L4_64_<hash>/point_001.jld2",
]; vary = :grid => [32, 48, 64])
results = check(ConservationSpec(norm_drift=1e-12, Jz_drift=5e-2), sweep)
for (n, r) in zip(sweep.varying.second, results)
    println("$(n)³: ", r.summary)
end
```

Replaces: `eu_ham_only_conservation_analyze.jl`.

### Pre-fix vs post-fix comparison

```julia
c = compare_runs(
    open_result("runs/<pre-fix-hash>/point_001.jld2"),
    open_result("runs/<post-fix-hash>/point_001.jld2");
    label_a = "pre-fix",
    label_b = "post-fix",
)
@show c.a.Fz_drift c.b.Fz_drift
```

Replaces: `L4_post_parserfix_compare.jl`.

### Operator-RHS export for Ueda hand-off

```julia
using SpinorBEC
# Step 1: run the YAML (with `hpsi_export` analyzer) to produce operator_rhs.jld2
run_yaml("docs/validation/step6_ueda_reference_state/reference_state.yaml")
# Step 2: open + re-save in canonical form with MANIFEST.md
r = open_result("docs/validation/step6_ueda_reference_state/operator_rhs.jld2")
art = save_operator_rhs(r, "docs/validation/step6_ueda_reference_state/")
# art.jld2_path / art.manifest_path / art.sha256
```

Replaces: `export_operator_rhs.jl`.

### Bilateral operator-RHS diff

```julia
spec = OperatorRHSSpec(; tol_hpsi=1e-10, tol_per_term_E=1e-10)
c = compare_runs(
    open_result("ours/operator_rhs.jld2"),
    open_result("theirs/operator_rhs.jld2");
    label_a="ours", label_b="ueda",
)
res = check(spec, c)
println(res.summary)
for (k, d) in res.details
    @printf("  %-20s %s\n", k, d.pass ? "PASS" : "FAIL")
end
```

Replaces: `compare_operator_rhs.jl`.

## What remains in this dir

Past orchestrator scripts have all been retired in favour of the
`Experiment` / `Batch` model + the corresponding @testset blocks:

* `L5_operator_rhs_compare.jl` → `test/validation/test_L5_operator_rhs_compare.jl`
* `production_audit.jl` → `audit_twin_controls(runs_root)` (validation submodule)
* `run_validation_matrix.jl` → `test/validation/test_validation_matrix.jl`
* `edh_validation_ladder.jl` → deleted (CLI ladder; equivalent via Batch
  + per-level @test_skip gating)

For ladder-style audits, build a Batch of Experiments per level and
guard heavy levels with `SPINORBEC_TEST_TIER` checks.

## API reference

| Symbol | Purpose |
|--------|---------|
| `RunResult` | typed view of a single jld2 |
| `RunSweep` | typed collection of RunResults with parametric axis |
| `RunComparison` | A/B paired view |
| `DynamicsTimeSeries` | times/norms/energies/Fz/Lz block |
| `ConservationSpec` | declarative drift bounds |
| `OperatorRHSSpec` | tol_hpsi + tol_per_term_E |
| `CheckResult` | verdict struct |
| `open_result(path)` | jld2 → RunResult |
| `sweep_runs(paths; vary)` | multiple jld2s → RunSweep |
| `compare_runs(a, b; ...)` | A/B pair → RunComparison |
| `check(spec, target)` | spec + target → CheckResult |
| `save_operator_rhs(r, out_dir)` | RunResult → operator_rhs.jld2 + MANIFEST |

Tests: `test/workflow/validation/test_*.jl` (~130 PASS in FAST tier).
