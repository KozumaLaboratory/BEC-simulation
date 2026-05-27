# Autopilot — queue + tick + recipe + budget + trust

A thin meta-loop on top of existing pieces (CAS, Experiment, inspector,
`_live_status.json`, notify_slack). No new framework — a `tick` function
that walks `runs/<content_id>/state.toml`. The 2026-05-28 re-foundation
explicitly rejected a separate `queue/{pending,running,…}/` directory
tree: queue state is **per-run metadata** alongside the run's artefacts.

## Architecture in one diagram

```
 enqueue!(exp; …)        cli.jl autopilot tick    dashboard /api/queue
        │                         │                       │
        ▼                         ▼                       │
 runs/<cid>/state.toml ──► autopilot_tick! ──► runs/<cid>/state.toml (mutated)
                                  │
       ┌──────────────────────────┼────────────────────────┐
       │                          │                        │
   inspect_config            budget_gate                trust gate
   (block → killed_bug)      (cap GPU·h)                (suggest/propose/dispatch)
       │                          │                        │
       └─────────► dispatch! (Local | Slurm) ◄────────────┘
                                  │
       ┌──────────────────────────┼────────────────────────┐
   _live_status.json          backend_failure_reason       outcome.toml
   (kill divergent →          (TIMEOUT/OOM →               (NaN/Interrupt →
    killed_data)              RESOURCE_PERMANENT)          PERMANENT/TRANSIENT)
                                  │                        │
                                  └──► retry_failed! ──────┘
                                  (escalate profile or re-pending)
```

## Five queue states

| State | Meaning | Recoverable? |
|---|---|---|
| `:pending`     | Waiting for dispatch | n/a |
| `:running`     | Job dispatched, `job_id` set (or transiently `nothing` mid-submit) | n/a |
| `:done`        | Completed successfully; on_complete fires here | terminal |
| `:killed_data` | Physics-side divergence (norm drift, classify_collapse). **Carries epistemic value** — surrogates may consume the partial trajectory. | terminal (not auto-retried) |
| `:killed_bug`  | NaN cascade / exception / OOM / TIMEOUT. Code- or resource-side problem. | retryable via `retry_failed!` |

`killed_data` vs `killed_bug` is the load-bearing distinction: data-side
kills are **information** (the trajectory diverged — that's a finding),
not failures.

## Quick start

```julia
using SpinorBEC

# 1. Build experiments via the usual sweep / config DSL.
base = SpinorBEC.load_config("runs/eu151_phi_omega/config.yaml")
exps = sweep(base; over=:pipeline_2_dynamics_B_hat_phi_omega => [1.0, 2.0, 4.524])

# 2. Enqueue → writes runs/<content_id>/state.toml with status=:pending.
enqueue!(exps; enqueued_by="phi-omega sweep")

# 3. Run one tick. LocalBackend executes inline; SlurmBackend shells out.
stats = autopilot_tick!()
```

Continuous operation via cron / systemd-user:

```bash
* * * * * cd /path/to/BEC-simulation && julia --project=. scripts/cli.jl autopilot tick
```

## `enqueue!` API

```julia
enqueue!(exp::Experiment;
    priority::Int=5,
    enqueued_by::AbstractString="manual",
    recipe_name::Union{Nothing,Symbol}=nothing,
    recipe_params::AbstractDict=Dict(),
    autonomy_level::Symbol=:dispatch,        # :suggest | :propose | :dispatch
    parent_id::Union{Nothing,AbstractString}=nothing,
    profile::AbstractString="default",       # sbatch profile
    estimated_walltime_hours::Real=2.0,
    backend_type::Symbol=:local,
    qr::QueueRoot=autopilot_queue_root(),
) -> QueueEntry

enqueue!(exps::Vector{Experiment}; kwargs...) -> Vector{QueueEntry}
```

`autonomy_level=:dispatch` is the only level that actually submits. The
gradient `:suggest → :propose → :dispatch` lets you ramp up trust in a
recipe gradually (see `trust.jl` and `record_calibration!`).

## Recipes (`on_complete`)

Recipes are registered by Symbol. The autopilot looks up
`entry.recipe_name` after `:done` and invokes `f(entry, params)` —
returned `Experiment`s are enqueued as children with `parent_id` set.

```julia
register_on_complete!(:next_phi) do entry, params
    target = params["target_fz"]::Float64
    exp = Experiment(entry.spec_path)
    last_fz = last(Fz_t(exp))
    [Experiment(_build_next_spec(last_fz, target))]
end

enqueue!(exp;
    recipe_name=:next_phi,
    recipe_params=Dict("target_fz" => -3.5),
    autonomy_level=:dispatch,
    enqueued_by="surrogate-iter-0")
```

A buggy recipe can't blow up the queue: `on_complete_max_descendants`
(default 64) caps the transitive descendant count of any single root
enqueue.

## Backends

```julia
LocalBackend(; max_concurrent=1)             # serial in-process, for tests
SlurmBackend(;
    sbatch_template = "scripts/slurm/eu151_h100_single.sbatch",
    ssh_host        = nothing,                # nothing → run sbatch locally
)
```

Dispatch is 2-stage and crash-safe:
1. mark `status=:running, job_id=nothing`, fsync state.toml
2. call `dispatch!(backend, entry)` — mutates `entry.job_id`
3. fsync state.toml with real `job_id`

A crash between (1) and (3) leaves a zombie (`running` + `job_id=nothing`).
The next tick reconciles via `find_job_by_name(backend, content_id)` —
SLURM submissions go through with `--job-name=<content_id>` so a stale
zombie can be adopted from `squeue`.

## Kill-divergent — `_live_status.json`

`run_pipeline` writes `<run_dir>/_live_status.json` periodically. The
tick reads it for each `running` entry; jobs exceeding
`divergence_thresholds()` → `scancel` + `set_status!(:killed_data)`.

```julia
set_divergence_thresholds!(DivergenceThresholds(;
    norm_drift = 5e-3,
    fz_jump    = 1.0,
    classify_kill = Set([:collapse, :unbounded_growth]),
))
```

## Retry classification (`retry_failed!`)

Reads `<run_dir>/outcome.toml` (written at run_pipeline exit) and the
backend's post-mortem reason. Classification:

| Source | Value | Class |
|---|---|---|
| outcome.toml `nan_encountered: true` | — | **PERMANENT** |
| outcome.toml `exception_type` | `Interrupt*` / `SystemError` / `IOError` / `ProcessExited*` | **TRANSIENT** |
| outcome.toml `exception_type` | any other | **PERMANENT** |
| backend reason | `OUT_OF_MEMORY` / `OOM_KILLED` | **RESOURCE_PERMANENT** (escalates profile) |
| backend reason | `TIMEOUT` | **RESOURCE_PERMANENT** (escalates walltime) |
| backend reason | `NODE_FAIL` / `PREEMPTED` | **TRANSIENT** |
| no signal | — | **UNKNOWN_CLASS** (treated as TRANSIENT, one more shot) |

```julia
retry_failed!(; max_retries=3)
# (retried=2, escalated=1, abandoned=4)
```

RESOURCE_PERMANENT re-enqueues with `next_profile(entry.profile)` —
walking up the resource ladder (`default → single_h100 → …`). When the
escalation chain ends, the entry is abandoned.

`killed_data` is **not** in `retry_failed!`'s scope — divergence is data,
not failure.

## Budget gate

```julia
get_budget()        # AutopilotBudget — quarter + daily GPU·h caps
budget_gate()       # BudgetDecision: :ok | :soft_cap | :hard_cap
```

Caps are enforced at dispatch time. `:soft_cap` blocks new high-priority
dispatches but lets in-flight jobs finish; `:hard_cap` halts dispatch
entirely (pause sentinel still respected). Spent GPU·h is refreshed from
sacct after each tick.

## Trust gradient

Per-recipe calibration history determines how high an autonomy_level the
autopilot honours.

```julia
record_calibration!(:next_phi; outcome=:hit_target, gpu_hours=2.3)
get_recipe_trust(:next_phi)
# RecipeTrust(samples=12, hit_rate=0.83, max_autonomy=:dispatch)
```

A recipe submitted at `autonomy_level=:dispatch` whose trust hasn't
reached the threshold gets demoted to `:propose` — recorded but not
dispatched. Operator can then promote manually.

## CLI surface

```bash
julia --project=. scripts/cli.jl autopilot status
#   autopilot status
#     paused:    false
#     lock held: false
#     states:
#       pending     3
#       running     1
#       done        147
#       killed_data 4
#       killed_bug  2
#     throughput (24h): 12 entries
#     gpu·h (24h):      28.4
#     gpu·h (total):    412.7

julia --project=. scripts/cli.jl autopilot tick
julia --project=. scripts/cli.jl autopilot enqueue runs/foo/config.yaml --priority 3
julia --project=. scripts/cli.jl autopilot retry 3
julia --project=. scripts/cli.jl autopilot pause     # touch .autopilot.paused
julia --project=. scripts/cli.jl autopilot resume    # rm .autopilot.paused
julia --project=. scripts/cli.jl autopilot drain     # block until running drains
julia --project=. scripts/cli.jl autopilot why <content_id>  # lineage chain
```

## Dashboard panel

`/api/queue` returns the 5-state queue. The React `QueuePanel` renders
the summary strip + per-state tables (cid / recipe / autonomy / profile
/ attempt / walltime / gpu·h / job_id / parent / reason). Read-only —
operate via the CLI.

## Where to run autopilot

Three options:

1. **WSL + systemd-user + SSH tunnel to Tsubame login** *(recommended)*.
   Tick every minute on the local machine; `SlurmBackend(ssh_host=…)`
   shells out over SSH.
2. **Small VPS** with persistent SSH key into Tsubame.
3. **Tsubame login cron** — fastest path to sbatch, but most clusters
   cap login-node processes (15-min limit). Viable only if your cluster
   permits short cron jobs.

The `_live_status.json` watcher works through any of these because the
dashboard exposes `/api/live/<run>` — autopilot fetches live status via
HTTP through the SSH tunnel rather than relying on shared filesystem
visibility.

## Operating the queue by hand

The queue is just per-run `state.toml` files. Shell intervention:

```bash
# Look at every queued entry.
find runs -name state.toml -exec grep -H "status" {} \;

# Bump priority on a stuck pending entry (the entry knows its own status).
# Edit runs/<cid>/state.toml's [state] priority field directly.

# Manually fail a running ghost.
# Edit status="killed_bug" and add kill_reason in state.toml.

# Pause / resume.
touch runs/.autopilot.paused
rm    runs/.autopilot.paused
```

## Long-term correctness

### Schema versioning

`state.toml` carries `schema_version = "1.0"`. Bump
`STATE_TOML_SCHEMA_VERSION` + add a clause in `_STATE_TOML_MIGRATIONS`
when fields shift; old entries migrate in-memory at read time.

### Reproducibility metadata (captured at `enqueue!`, immutable)

- `code_sha` — `git rev-parse HEAD` (`-dirty` suffix when working tree mutated)
- `recipe_version` — semver via `register_on_complete_version!`
- `inspector_snapshot_hash` — SHA-256 of `inspect_config` output at enqueue
- `autopilot_config_hash` — SHA of the AutopilotConfig at dispatch

"What code produced this run?" is `grep code_sha runs/*/state.toml`.

### Per-entry locking

`with_entry_lock(entry) do … end` is an mkdir-based exclusive mutex at
`<run_dir>/.state.lock/`. `set_status!` re-reads inside the lock so
concurrent ticks/monitors don't clobber. Stale locks (mtime > 5 min)
are forcibly taken.

## Operational safety

### Circuit breakers — `check_breakers()`

Four reactive cuts (predictive layer is trust + budget):

| Breaker | Trips when |
|---|---|
| `BREAKER_RECIPE_FAILURE` | recent-N entries for a recipe show ≥ 70% kills |
| `BREAKER_LINEAGE_DEPTH`  | any `parent_id` chain > 16 |
| `BREAKER_DISPATCH_RATE`  | > 64 dispatches in last hour |
| `BREAKER_KILL_RATE`      | kills/dispatches > 1.0 in last hour |

```julia
trip, details = check_breakers()
if trip !== BREAKER_OK
    autopilot_pause!()
    notify_slack("[autopilot] $trip — $details")
end
```

### Per-recipe divergence thresholds

`register_recipe_divergence_thresholds!(:klaus_deep_quench,
DivergenceThresholds(; norm_drift=0.1, fz_jump=3.0))` carves out an
envelope for physics that legitimately drifts. Global thresholds remain
the fallback. **Set this before turning surrogates on** — otherwise
the surrogate learns "this region is divergent" from autopilot's
false-positive kills.

### Dry-run + shadow rollout

| Week | Mode | Daily cap | Purpose |
|---|---|---|---|
| 0 | `dry_run=true` | n/a | sanity-check tick + classification |
| 1 | live | 5–10 GPU·h | shadow alongside manual dispatch |
| 2–3 | live | graduated 20→60 | confirm trust calibration |
| 4+  | live | budget-policy cap | routine |

`AutopilotConfig.dry_run=true` skips real `dispatch!`, writes a
synthetic `outcome.toml`, so the tick walks the full state machine
without spending GPU·h.

### Day-1 recipes (`setup_default_recipes!()`)

Four starters at `autonomy_level=:suggest` by default:

- `:next_random_in_bounds` — warmup random sampling within `[lo, hi]`
- `:refine_around_best` — hierarchical ±scale refinement
- `:twin_with_loss_off` — auto-twin every parent (K3-off control)
- `:analyze_majorana` — analysis-only pass

## Observability + watchdog

`autopilot_tick!` appends to `<qr.path>/.autopilot.metrics.jsonl` per
tick. Last 24h at 5-min cadence via `recent_metric_samples(288)`.
Recipe trajectory:

```julia
autopilot_recipe_success_rate(:next_phi)
# (rate=0.62, n=49, last_24h=0.71)
```

`append_error_event!(reason, details)` writes to
`<qr.path>/.autopilot.errors.log` for in-tick recoverables.

systemd-user unit + timer ship in `scripts/systemd/`:

```bash
mkdir -p ~/.config/systemd/user
cp scripts/systemd/spinor-autopilot.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now spinor-autopilot.timer
journalctl --user -u spinor-autopilot.service -f
```

`Restart=no` is intentional — the timer is the retry loop, so panics
don't tight-loop on a broken binary.

## TODO

- Warmup window before `is_divergent_status` fires (currently from t=0)
- `cli.jl autopilot cancel <content_id>` for in-flight cancellation
- Dashboard-side metrics tab (timeseries from `.autopilot.metrics.jsonl`)
- More migrations in `_STATE_TOML_MIGRATIONS` once schema evolves

## See also

- `CONTRIBUTING.md` — `scripts/` invariant (cli.jl is the only entry)
- `docs/guides/experiment_api.md` — Experiment + CAS + sweep semantics
- `docs/guides/tsubame.md` — cluster deployment
