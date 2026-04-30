# Perf Ralph guardrails

This document is the **system prompt body** read by every iteration of
the perf-Ralph loop (`scripts/ralph_perf.sh`). The agent reads it,
picks one hot kernel, attempts an optimization, and either commits or
reverts based on the bench harness result.

## Goal

Reduce wall-clock or allocation count of one specific hot kernel,
without changing observable physics or breaking the test suite.

## Hard "do not" list

These come from `CLAUDE.md` "Conventions (do NOT 'fix')" and "Type
stability boundaries". Violating any of them produces silently broken
physics or a 30-minute JIT cascade that wastes hours.

1. **Do not change Workspace's struct definition or its 23+ type
   parameters.** Any field add/remove or re-typing propagates JIT
   specialisation across `make_workspace` callers.
2. **Do not store closures (`t -> ...`, anonymous functions) in struct
   fields that flow into Workspace.** Pre-evaluate to
   `PiecewiseLinearWaveform` or `InterpolatedWaveform`.
3. **Do not let `Dict{Symbol,Any}` extractions flow into
   `make_workspace` directly.** Funnel through a `@noinline` helper
   with `::ConcreteType` assertions, as `_apply_pulse_sequence` does.
4. **Do not "fix" the documented conventions:**
   - DDI: `c_dd = μ₀μ²` (no 4π), `Q_αβ = k̂_αk̂_β − δ_αβ/3` (no
     1/(4π)), `Q(k=0) = 0`.
   - ITP Zeeman shift subtracts `min(E_m)`. Not a bug.
   - `_YOSHIDA_W0 < 0` is correct (backward middle substep).
   - Scalar LHY `@warn` is intentional.
   - Odd-rank `c_extra` ignored by design.
   - `compute_interaction_params_general_f` returns `(0, 0)` by design
     for the scattering-lengths path.
5. **Do not remove `@noinline` annotations or `::ConcreteType` type
   assertions** without a benchmarked reason. They are the operative
   defence against the JIT cascade.
6. **Do not change tolerance arguments** (`tol`, `dt`, `n_steps`) in
   tests to make them pass. If a test fails after your edit, the edit
   is wrong — revert.
7. **Do not introduce GPU/CPU dispatch via abstract types.** Use the
   existing extension boundary (`SpinorBECCUDAExt` ext functions).
8. **Do not change file I/O formats** (JLD2 keys, dashboard layout,
   scan.yaml schema). They are observed by external code.

## Safe optimization patterns

Pick ONE of these per iteration. Don't combine.

| pattern | example | risk |
|---|---|---|
| In-place buffer reuse | `mul!(buf, A, x)` instead of `A * x` | low |
| Pre-allocate scratch in struct | new field of concrete `Array{T,N}` | low if struct already exists |
| `@inbounds` + `@simd` on verified loops | tight numerical kernels | low if loop bounds are constant |
| `@views` on slice ops | `psi[:, :, :, m]` → `view(psi, :, :, :, m)` | low |
| `Threads.@threads :static` over independent iterations | per-direction scans | medium — beware shared accumulators |
| Replace `SMatrix{D,D}` with `MMatrix` for D=13 (Eu) | hot spinor mul | medium — heap-alloc tradeoff |
| Fuse broadcasts | `cis.(m .* α) .* psi` → single fused kernel | low |
| GPU broadcast → CUBLAS gemm | spin rotation as D×D mul | medium |
| Drop redundant `convert` / `Float64(…)` calls in F32 hot path | preserve numerical type through pipeline | medium — verify F32 lattice |

## Constraint: numerical correctness

After every edit:
1. Run a **smoke test** subset:
   - `julia --project=. -e 'using Pkg; Pkg.test()'` is too long; instead:
   - `julia --project=. test/test_split_step.jl`
   - `julia --project=. test/test_rotating_basis_f32.jl` (if F32 path
     touched)
   - `julia --project=. test/test_klaus_eu151.jl` (if rotating_basis
     touched)
2. Run the bench harness:
   - `julia --project=. bench/bench_regression.jl` for CPU benches
   - `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/bench_gpu.jl`
     for GPU benches (only if the kernel runs on GPU)
3. Compare to baseline (`bench/baseline.json`):
   - **Accept** the change only if: (a) all smoke tests pass, AND
     (b) the targeted bench's `minimum(t)` strictly decreased
     (ratio < 1.0; even sub-percent wins count because minimum is
     monotone under jitter), AND
     (c) no other bench regresses by >10% (above the WSL2 noise floor).
   - Otherwise: `git checkout -- <files>` and try a different pattern.

## Commit format

If accepted:

```
perf(<scope>): <one-line summary> (<old>μs → <new>μs, <pct>%)

<2-3 sentence why-this-helps>

Bench: <path/to/bench>::<key>
  before:  <old> ns / <old_alloc> alloc / <old_mem> bytes
  after:   <new> ns / <new_alloc> alloc / <new_mem> bytes

Assisted-by: Claude (model: claude-opus-4-7) [perf-ralph]
```

The `[perf-ralph]` tag in the trailer marks the commit as auto-generated
so subsequent reviews can filter / inspect.

## Exit conditions

Stop the loop iteration and report (do NOT keep retrying) when:

- Smoke test fails after 3 different optimization attempts on the same
  kernel — the kernel may be inherently fragile.
- Bench shows no improvement after 3 attempts — the kernel may already
  be optimal, or your benchmark isn't sensitive enough.
- Edit count exceeds 30 lines without commit — likely a refactor in
  disguise; bail out and let a human review.
- A test that was previously passing now hangs (>5min) — JIT cascade
  symptom; revert immediately.

## Hot kernel queue

Read `bench/perf_targets.txt`. Each line is one kernel. Pick the topmost
unmarked entry, append `# done <date>` after a successful commit, or
`# skipped <reason> <date>` if you bailed.

## Out-of-scope

- Adding new features. Strict scope: existing kernel, faster.
- Refactors that touch >2 files. Stop and ask.
- API renames. Stop and ask.
- "Cleanup" passes. Stop and ask.
