# Contributing to SpinorBEC

This is a research codebase, not a public library. The conventions below
are what's worked for the small team running it; deviations are fine if
you're working in your own fork.

## Quick start

```bash
git clone git@github.com:anko9801/BEC-simulation.git
cd BEC-simulation
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'   # ~5 min, runs the FAST tier
```

GPU runs (WSL2):

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.
```

## Branching / commits

- Work on `main` for small fixes; feature branches for anything > 200 lines.
- **Conventional Commits** (`feat`, `fix`, `refactor`, `perf`, `test`,
  `docs`, `chore`). Scope optional, e.g. `fix(raman):`.
- Trailer: `Assisted-by: Claude Code (model: Opus 4.7)` — do NOT use
  `Co-Authored-By`.
- One logical change per commit. If you can't summarise it in one
  sentence, split it.

## Pre-PR checklist

- [ ] `julia --project=. -e 'using Pkg; Pkg.test()'` (fast tier) passes
- [ ] `julia -e 'using JuliaFormatter; format("src/")'` clean
- [ ] No new `Any`-typed slots in `_run_step` paths
      (`scripts/type_stability_audit.jl` to check)
- [ ] If touching the Klaus path: smoke `runs/klaus2022_smoke/config.yaml`
- [ ] If touching CUDA: verify `import CUDA; using SpinorBEC` precompiles
- [ ] CLAUDE.md updated if introducing a new convention
- [ ] No commented-out code in the diff
- [ ] No secrets — gitleaks runs in pre-commit

## Code style

- Simple > clever. Short over abstract.
- Files 200-400 lines typical, 800 max.
- All structs in `src/foundation/types.jl`.
- Workspace has 23+ type params: never write them out explicitly.
- D=13 (Eu): SMatrix heap-allocates; use Matrix/MVector in hot loops.
- `Val(N)` from type parameter, never `Val(ndim::Int)` from a runtime int.
- Comments explain WHY, not what. Rare unless logic is genuinely subtle.

## Testing

Tiers (in `test/runtests.jl`):

- **fast** — quick unit tests, no full ITP. CI runs this.
- **ci**   — fast + integration tests with short ITP/RTP.
- **full** — ci + heavy 3D, continuation, twa, pause/resume.

Run a single test:

```bash
julia --project=. -e 'using SpinorBEC; include("test/test_pipeline.jl")'
```

## Long-running runs

Detach pattern (survives Claude / shell close):

```bash
setsid nohup bash -c '
  LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  julia --project=. scripts/run_batch_overnight.jl
' > logs/x.log 2>&1 < /dev/null &
disown
```

Verify session leader: `ps -o pid,sid,etime,cmd -C julia` — `PID == SID`
means the process owns its session and survives parent close.

For crash-resilience: `scripts/supervised_run.sh <run_name> <max_retries>`.

## Where to put things

| What | Where |
|---|---|
| New struct | `src/foundation/types.jl` |
| New analyzer | `src/workflow/experiments/pipeline_analyzers.jl` + whitelist in `helpers_utils.jl` |
| New atom | `src/workflow/initialization/atoms.jl` |
| New initial state | `src/workflow/initialization/initialization.jl` + wrapper in `state_zoo.jl` |
| New YAML knob | `src/workflow/experiments/schema.jl` + parser in `pipeline_runner.jl` |
| New analyzer kernel | `src/analysis/<topic>.jl` |
| New scenario | `runs/samples/<name>/config.yaml` |
| New design note | `docs/design/<topic>.md` |
| New CLAUDE.md entry | only if it's a non-obvious gotcha |

## Common pitfalls

See `docs/guides/lab_user_tutorial.md`'s troubleshooting table — every recurring
error is pinned to the commit that fixed it.
