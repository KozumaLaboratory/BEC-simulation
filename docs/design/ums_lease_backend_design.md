# UMS low-latency path — leased `node_f` + `UMSBackend`

**Status: DEFERRED — premise not met (2026-06-21).** UMS exists to kill queue
wait. A direct measurement on TSUBAME shows there is none worth killing:
**trial-mode `qsub`→running latency = 7.8 s** (and trial is *lowest priority* =
worst case; a real `-g` job is at least as fast). At ~8 s the autopilot's plain
`qsub` path already gives an interactive-feeling loop, so the lease machinery is
a solution to a non-problem. Not building it. This doc stands as the considered
design should the premise change.

**Revisit only if** a concrete friction appears: (a) `node_f`/multi-node
allocations waiting minutes under congestion (untested — the measurement was
`gpu_1`, uncongested, one sample), or (b) rapid-fire many-tiny-jobs where
per-submit JIT dominates — and even (b) is largely covered by the existing
sysimage support (`UGEBackend.sysimage_path`). The probe
(`scripts/tsubame/ums_probe.sh`) is the insurance instrument for (a).

---

**Original framing (design, not active).** Phase 2 of `compute_gateway_design.md`.
The work would have been: turn "run this param set" from a fresh `qsub` into an
instant dispatch to a held allocation. Fits the existing `AutopilotBackend`
contract; the hard parts are three UMS-specific semantic gaps, resolved below.

## UMS ground truth (from the TSUBAME UMS doc, verbatim API)

- **Acquire**: a normal `qsub -g <group>` job whose script is `sleep infinity`
  with `#$ -l node_f=N -l h_rt=HH:MM:SS`. Gives a batch `job-id`.
- **Start daemon**: `ums-start --job <job-id>` (run on login node once the parent
  job is in state `r`). Spawns a controller + per-node workers.
- **Submit a task**: `ums-submit --group <g> --job <job-id> --name <name>
  --rank <r> --stderr-log <p> --stdout-log <p> <command...>`. `--job` and
  `--name` required; `--rank` defaults 0; logs default `/dev/null`.
- **List**: `ums-list --job <job-id>` → JSON `{name: hostname}` of **actively
  running tasks only**. No state column; a finished task simply disappears.
- **Cancel**: **no `ums-cancel` / `ums-kill` exists.** The only documented stop
  is `qdel <job-id>` on the parent — which kills the whole allocation and every
  task in it.
- **Lifetime**: UMS is subordinate to the parent job; valid only while parent is
  `r`. No detach/persist after the parent ends.
- **Caveat to verify**: the doc notes "array jobs and non-OpenMPI environments
  unsupported" and "MPI programs in a group must run before other grouped tasks".
  Our tasks are single-process Julia (no MPI) — **must confirm UMS accepts a
  plain serial command** before committing. Open question O1.

These three properties (list-shows-only-running, no per-task cancel, parent-bound
lifetime) drive the whole design.

## How it maps onto the existing autopilot

The backend abstraction already absorbs this. `entry.backend_type::Symbol` keys
`config.backends` (`types.jl:75-85`), so a new `:ums` backend slots into the same
tick loop that already mixes `:local` + `:uge`. The contract
(`backends.jl:10-18`) maps cleanly:

| Contract method | UMS implementation |
|---|---|
| `stage_in` | identical to UGE (rsync config + optional code sync) — **reuse UGE rsync helpers** |
| `dispatch!` | `ums-submit --job <lease> --name sb_<cid> --stdout-log … <julia run_yaml>` (requires active lease) |
| `prepare_status_snapshot` | `ums-list --job <lease>` once per tick → cached JSON |
| `job_status(...; snapshot=)` | parse the snapshot JSON (see Problem A) |
| `pull_live` / `collect!` | identical to UGE rsync |
| `cancel!` | cooperative sentinel (see Problem B) |
| `find_job_by_name` | name present in `ums-list` JSON → reconcile |
| `next_profile` | `nothing` (lease is fixed node_f); resource-permanent retry re-routes to `:uge` |

`job_id` semantics: store the parent **lease job-id** in `entry.job_id` (for
provenance / reconcile), and identify the task by `--name = _uge_jobname(cid) =
"sb_<cid>"` — the same naming already used for UGE reconcile (`backends_uge.jl:132`).
`job_status` looks up by **name**, not job_id.

**Shared machinery (explicit, per the repo ethos). — DONE in Phase 2a.** The
ControlMaster ssh + rsync push/pull/collect/code-sync + Manifest-hash helpers
were scheduler-agnostic and have been extracted to `autopilot/ssh_transport.jl`
(`_ssh_cm` / `_rsync_*` / `_ssh_instantiate_if_needed`), parameterized by
primitives (host, paths). `UGEBackend`'s `_uge_*` builders now delegate to them
(byte-identical, 217/217 autopilot tests green). `UMSBackend` reuses the same
transport rather than copy-pasting it — the duplicated-physics-drift class this
repo forbids.

## Problem A — status without a terminal signal

`ums-list` shows only running tasks; a finished task vanishes with no exit code,
no qacct. So `job_status(::UMSBackend, entry; snapshot)`:

```
name = "sb_" * entry.content_id
present = haskey(parse_json(snapshot), name)
if present
    return :running
else
    # absent: either finished, or not-yet-scheduled (race after dispatch!)
    collect!(b, entry)                       # pull outcome.toml if it landed
    outcome = read runs/<cid>/outcome.toml   # same branch as UGE backends_uge.jl:437-451
    outcome.terminal == "done"               → :done
    outcome.terminal in (killed_data,bug)    → :failed
    # no outcome yet:
    if now - entry.dispatched_at < UMS_DISPATCH_GRACE   → :running   # not scheduled yet
    else                                                → :unknown    # retry next tick
end
```

The `UMS_DISPATCH_GRACE` guard is the key difference from UGE: under UGE,
"absent from qstat" is unambiguously terminal; under UMS, a just-submitted task
may not appear in `ums-list` for a moment. Without the grace window the reap loop
would race-classify a fresh task as terminal-with-no-outcome → `:unknown` churn.
The outcome.toml is authoritative the moment it lands (the Julia run writes it on
exit, same as local/UGE), so the grace window only matters for the no-outcome gap.

## Problem B — divergence kill with no per-task cancel

The reap loop kills divergent runs via `cancel!(backend, entry)`
(`tick.jl:298-301`). For UGE that is `qdel <job_id>`. For UMS, `qdel` would kill
the **lease and every sibling task** — unacceptable.

Resolution: **cooperative abort sentinel.** `cancel!(::UMSBackend, entry)` writes
a `.kill` file into the (remote) run_dir (ssh `touch`, or rsync an empty marker).
`run_pipeline` checks for `<run_dir>/.kill` at the same cadence it writes
`_live_status.json` and aborts cleanly (writing `outcome.toml` with
`terminal=killed_data`). This is a **small `run_pipeline` addition** and is the
one cross-subsystem dependency of this design — call it out, do not hide it
(dependency D1).

Rationale: UMS tasks are short by construction (that is the entire point of the
low-latency path), so cooperative abort at the live-status cadence is responsive
enough. A `pkill`-over-ssh-on-the-task-host alternative (host comes from the
`ums-list` JSON value) is heavier and fragile; keep it as a documented fallback,
not v1. `qdel` of the lease is never used for a single divergent task.

## Problem C — the lease lifecycle (the heart of the new work)

A managed `UMSLease`, persisted to `<qr.path>/.ums_lease.toml` (survives
coordinator restart, same sentinel discipline as `.autopilot.paused`):

```
state machine (advanced once per tick by ums_lease_tick!):

  NONE ──[pending :ums entry exists]──▶ REQUESTED   (qsub sleeper submitted; parent qw)
  REQUESTED ──[parent qstat == r]────▶ ACTIVE       (ums-start --job <id> done)
  ACTIVE ──[idle ≥ max_idle, 0 running tasks]──▶ DRAINING  (no new dispatch accepted)
  DRAINING ──[confirmed idle]────────▶ RELEASED     (qdel <id>); back to NONE
  any ──[parent absent from qstat]───▶ NONE          (crash/preempt reconcile)
```

Fields: `state`, `job_id` (parent), `requested_at`, `active_since`,
`last_activity_at`, `node_spec` (e.g. `node_f=1`), `h_rt`, `max_idle_minutes`.

- **Acquire trigger**: `dispatch!` of a `:ums` entry when lease is not `ACTIVE`
  returns `false` (backend-not-ready, entry stays `:pending`); `ums_lease_tick!`
  sees the pending `:ums` entry and drives `NONE→REQUESTED→ACTIVE`. Once `ACTIVE`,
  the next tick dispatches the waiting entries instantly.
- **Idle reap**: `last_activity_at` updates on every `ums-submit` and whenever
  `ums-list` is non-empty. `now - last_activity_at > max_idle` AND `ums-list`
  empty → `DRAINING → RELEASED` (`qdel`). This is the cost-control mechanism.
- **Crash recovery**: on coordinator restart, reconcile `.ums_lease.toml`
  against `qstat` — if the parent job-id is gone, reset to `NONE`; if still `r`,
  resume `ACTIVE` (re-run `ums-start` is idempotent / no-op if daemon up — verify,
  open question O2).
- **`h_rt` ceiling**: the parent has a hard walltime; near expiry, force
  `DRAINING` and let in-flight tasks finish or migrate. A lease is not permanent
  even if busy — re-acquire after expiry.

`ums_lease_tick!(backend, qr)` runs once per `:ums` backend per tick, **before
the dispatch passes** in `autopilot_tick!`, so a freshly-`ACTIVE` lease is usable
the same tick the entries are dispatched.

## Problem D — budget accounting for the lease

`refresh_budget!` (`budget.jl:114-136`) sums `gpu_hours_realized` over
terminal+running **entries**. The lease is not an entry, and it burns `node_f`
(4× H100) continuously while held — the dominant new budget risk.

Resolution, minimal and on the existing seam:

- While `ACTIVE`/`DRAINING`, `budget_gate` adds projected lease cost
  `(now - active_since) × gpus_per_node` to `predicted` (so an idle lease pushes
  toward the cap and pressures release).
- On `RELEASED`, finalize the realized lease hours into a `lease_realized` field
  in `budget.toml`; `refresh_budget!` adds it to `realized_total`.
- The **kill breaker** is the backstop: an `ACTIVE` lease with no activity past
  `max_idle` and a budget already near the ceiling trips toward forced release.
  The "max-idle policy on the existing budget + kill breaker" promised in the
  parent design is exactly this — no new cost machinery, just lease-aware terms.

`max_idle_minutes` is **not a guess to hardcode** — it is set from the probe's
C1 idle burn rate (see "Policy constants" below). Pending that number it stays a
conservative placeholder, because idle `node_f` is the single most expensive
failure mode here.

## Policy constants — set from the probe, not guessed

The lease parameters below are currently **placeholders**. `scripts/tsubame/ums_probe.sh`
measures the real numbers on TSUBAME; **2b is held until it returns** so the
lease model is written without assumptions (retrofitting a single-tenant lease
into a multi-tenant one is expensive — resolve the seam first).

| probe output | sets | placeholder |
|---|---|---|
| **C1** `idle_points_per_hour` | `max_idle_minutes`; and the **Phase 2↔3 lease-isolation seam** (below) | 10 min |
| **C2** `warm_speedup_x` (cold qsub ÷ warm dispatch) | go/no-go for UMS itself — if ≈ 1 the premise collapses | assumed ≫ 1 |
| **C3** `umslist_appear_lag_s` / `missed_polls` | `UMS_DISPATCH_GRACE` floor; whether `job_status` needs a missed-poll debounce | 30 s grace |

**The Phase 2↔3 lease-isolation seam (decide before 2b writes the lease model).**
C1 alone picks the lease topology, and the choice is painful to reverse:

- **cheap idle node_f** → **per-user lease**: each principal (Phase 3) gets its
  own lease, isolation is trivial, cost attribution is exact (the lease bills its
  owner). The `UMSLease` is a per-principal object.
- **expensive idle node_f** → **single shared warm pool + fair-share**: one lease
  serves all interactive users, scheduled fairly; cost goes to a shared `infra`
  principal, not a person. The `UMSLease` is a singleton with a fair-share queue.

Writing 2b against the wrong topology means re-plumbing ownership through the
lease later. So the `UMSLease` shape (per-principal vs singleton) is **gated on
C1** and must be fixed before 2b — this is the same decision as multi_user
`O1`/lease-cost-attribution, surfaced early.

## Routing

`entry.backend_type=:ums` is set at enqueue by the Gateway's low-latency path
(MCP "enqueue --low-latency", or the interactive harness). Phase-2 rule, kept
simple and explicit (no learned routing yet):

- interactive / small / short (estimated walltime below a threshold, many
  same-shape variants) → `:ums`
- production / long / large array → `:uge`
- resource-permanent failure on `:ums` (the fixed lease can't grow) → re-route
  the retry to `:uge` with `next_profile` escalation.

## Struct + file sketch

```julia
struct UMSBackend <: AutopilotBackend
    ssh_host::Union{Nothing,String}
    project_root::String
    remote_runs_root::Union{Nothing,String}
    compute_group::String          # ums-submit --group + qsub -g
    julia_path::String; julia_depot::String; sysimage_path::String; cuda_module::String
    node_spec::String              # "node_f=1"
    h_rt::String                   # "24:00:00"
    max_idle_minutes::Int
    sync_code::Bool
    lease_path::String             # <qr.path>/.ums_lease.toml
end
```

New files: `autopilot/ssh_transport.jl` (extracted shared rsync/ssh-CM helpers),
`autopilot/backends_ums.jl` (`UMSBackend` + `UMSLease` + `ums_lease_tick!`).
Touched: `tick.jl` (call `ums_lease_tick!` before dispatch passes; UMS-aware
`dispatch!` returning false when lease not ready is already handled by the
existing backend-full path), `budget.jl` (lease-aware `predicted` + `lease_realized`),
`run_pipeline` (D1: honor `.kill` sentinel).

## Implementation checklist (Phase 2a → 2c)

**2a — backend skeleton (no lease yet, manual lease)**
1. ~~Extract `ssh_transport.jl`; re-point `UGEBackend` at it (parity test: UGE
   command builders byte-identical before/after).~~ **DONE** — byte-identical,
   217/217 autopilot tests green.
2. `UMSBackend` with `stage_in`/`pull_live`/`collect!` (reuse), `dispatch!` via
   `ums-submit` against a **manually-started** lease (operator runs `qsub` +
   `ums-start`, passes job-id). `prepare_status_snapshot`=`ums-list`, `job_status`
   with the grace guard (Problem A). Verify a single task round-trips end-to-end.

**2b — lease state machine** — ⛔ GATED on the probe (C1/C2/C3). Do not write the
`UMSLease` shape until C1 fixes the per-principal-vs-singleton seam (above), or it
will need re-plumbing for Phase 3. If C2 shows no warm speedup, UMS is dropped
entirely and this phase is moot.
3. `UMSLease` (per-principal **or** singleton, per C1) + `.ums_lease.toml`
   persistence + `ums_lease_tick!` (acquire → start → drain → release) wired into
   `autopilot_tick!`.
4. Budget integration (Problem D); `max_idle_minutes` from C1.
5. Crash-recovery reconcile against `qstat`.

**2c — divergence + routing + verify**
6. D1: `run_pipeline` `.kill` sentinel; `cancel!(::UMSBackend)` writes it;
   divergence-kill test under UMS (cooperative abort lands `outcome.toml`).
7. Routing helper sets `backend_type`; resource-permanent → re-route to `:uge`.
8. End-to-end: low-latency enqueue of N same-shape variants → instant dispatch to
   a held lease → idle timeout auto-`qdel`. Measure dispatch latency vs cold
   `qsub` (the headline win).

## Open questions

All of these are answered by `scripts/tsubame/ums_probe.sh` in one run (yes/no
gates O1/O2/O3/O5 + policy constants C1/C2/C3). 2b stays blocked until it has run.

- **O1**: does UMS accept a plain serial (non-MPI) Julia command? The doc's
  "non-OpenMPI unsupported" note must be cleared first — it could block the whole
  approach or force an `mpirun -n 1` wrapper.
- **O2**: is `ums-start` idempotent (safe to re-run on an already-active lease
  after a coordinator restart)? Needed for crash recovery.
- **O3**: UMS concurrency limit per lease (tasks per node / total)? Unspecified;
  governs how many variants can be in-flight before queueing inside UMS.
- **O4**: `--rank` for single-node `node_f=1` is always 0; for multi-node leases,
  who assigns ranks? Defer multi-node lease to later.
- **O5**: stdout/stderr land in `$HOME/.ums/log/<name>-<id>/` per the doc — does
  `--stdout-log` fully redirect, or does the controller also keep its own? Affects
  where `backend_failure_reason` reads.

## References

- Parent design: `docs/design/compute_gateway_design.md`
- UGE backend (mirror + shared helpers): `src/workflow/autopilot/backends_uge.jl`
- Backend contract: `src/workflow/autopilot/backends.jl:1-59`
- Tick reap / divergence / dispatch: `src/workflow/autopilot/tick.jl:198-301,393`
- Budget seam: `src/workflow/autopilot/budget.jl:114-185`
- Divergence: `src/workflow/autopilot/monitor.jl`
- TSUBAME UMS: https://www.t4.cii.isct.ac.jp/docs/experimental/ums/
