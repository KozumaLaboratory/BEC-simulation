# Compute Gateway — feasibility review (plan vs codebase)

**Status**: review only, no implementation. Audits the "AI research compute
infrastructure" plan (Claude Code → TSUBAME 4.0 + suzume, via an always-on
Compute Gateway) against the current code. Conclusion: the Phase-1 substrate
already exists at production quality; the novel work is concentrated in UMS,
DAG, and multi-user (Phase 2–3).

This is an A/B-style ground-truth check, not an endorsement of the physics or
the operating model. Every claim below is anchored to a file:line.

## Verdict

- The design's spine — **separate the volatile brain (Claude Code session) from
  the durable hands/memory (compute, state, artifacts)**, promote the autopilot
  to the Gateway state engine, abstract the scheduler behind one `Executor` —
  matches what is already in the tree.
- **The plan understates existing assets**: an MCP server, the Grid Engine
  executor, and the executor abstraction itself already exist. Several pieces
  the plan says it will "build" are done.
- **The plan mis-names some reuse targets**: `Observable{T}` and `Sweep` types
  do not exist; observables are plain functions and `sweep` is a function
  returning `Vector{Experiment}`.
- **The genuinely new work is UMS, job-DAG, multi-user/quota, Nix flake, and
  remote MCP transport.** That is where the engineering cost actually lives.

## 1. Already present (reuse is wider than the plan assumes)

| Plan wording | Reality | Anchor |
|---|---|---|
| "new FastMCP gateway, start from 1 file" | **MCP server already exists**: FastMCP, 11 tools (read/write/destructive), stdio-over-WSL → TSUBAME | `scripts/mcp/tsubame_server.py` |
| "add `GridEngineExecutor`" | **`UGEBackend` is production-grade**: `qsub -g` (CLI flag), batched `qstat` snapshot, `qacct` terminal fallback, `qdel`, rsync + SSH ControlMaster, Manifest-hash auto-instantiate, 9 `SPINORBEC_TSUBAME_*` env auto-register | `src/workflow/autopilot/backends_uge.jl`; env triple at `tick.jl:76-100` |
| "define an `Executor` trait" | **`AutopilotBackend` abstract type is the trait.** Methods: `stage_in` / `dispatch!` / `job_status` / `pull_live` / `collect!` / `cancel!` / `find_job_by_name` / `backend_failure_reason` / `next_profile` / `prepare_status_snapshot`. The plan's 4-method trait (submit/poll/cancel/fetch) is a strict subset | `src/workflow/autopilot/types.jl:11`; contract `backends.jl:1-59` |
| "state.toml SSoT, 5-state lifecycle, two-stage submit" | **Exact match**: `(:pending, :running, :done, :killed_data, :killed_bug)`; `runs/<cid>/state.toml` (schema v1.1); mark+fsync → `stage_in` → `dispatch!` → persist | `queue.jl:41-43,203`; `tick.jl:450-488` |
| "policy engine (budget + breakers)" | **Present**: 4 breakers (recipe/lineage/rate/kill), `AutopilotBudget` (quarter + daily cap, realized tracking), divergence kill, retry classification (PERMANENT/TRANSIENT/RESOURCE_PERMANENT → `next_profile` escalation) | `breakers.jl:19`; `budget.jl:35-41`; `monitor.jl:83-91`; `retry.jl:27-52` |
| "CAS dedup" | **Present**: `content_id(spec)` → `<root>/<sha256[1:16]>/`, idempotent `run!` (skips on existing jld2), `sweep` / `twin` / `tabulate` / `spec_diff` | `src/workflow/experiment.jl:113-120,144-205,249-280`; collection ops `689-851` |
| "dashboard read API / SSE" | **HTTP 20+ routes + WebSocket** (`/ws/scrub`, binary) + `_live_status.json` polling | `src/workflow/io/dashboard/server/router.jl:295-415`; `websocket.jl:139-208` |
| "webhook (Slack/Discord)" | **Slack only** | `monitoring.jl:37-48`; `ext/SpinorBECHTTPExt` |
| "bake an Apptainer image" | **`spinorbec.def` exists** (julia:1.12, baked depot, `--nv`) | `scripts/spinorbec.def` |

## 2. Plan claims that are wrong / mis-named

| Plan wording | Reality |
|---|---|
| "existing `Observable{T}` becomes the submit/results schema" | **No `Observable{T}` type.** Observables are plain functions on `Experiment` (`Fz_t`, `classify`, `peaks`…), memoized in `exp.memo`. |
| "reuse the `Sweep` type" | **No `Sweep` type.** `sweep()` is a function → `Vector{Experiment}`. `SweepResult` / `SweepAxis` / `RunSweep` exist but are post-hoc analysis carriers, not a submission schema. |
| "`tabulate` → vector / `spec_diff` → vector" | `tabulate` → **`NamedTuple`** (per-column Vectors); `spec_diff` → `Vector{(path,a,b)}` records. |
| "`load_config \|> run_config`" | **Pattern does not exist.** Real forms: `config([...])` + `Experiment(spec)` + `run!`, or `run_yaml(path)`. |
| "dashboard … SSE" | **No SSE.** WebSocket (`/ws/scrub`) + `_live_status.json` polling. |
| "Slack/Discord" | **Discord not implemented** (would need separate embed-JSON path). |
| "suzume local/SLURM; add `SlurmExecutor`; reuse `SlurmBackend`" | **No `SlurmBackend` exists.** suzume bare is covered by `LocalBackend`. SLURM is greenfield **and likely unnecessary**. Note: `docs/guides/tsubame.md` itself says "ships with SlurmBackend only" — that line is **stale** (predates UGEBackend) and should be fixed. |

**Implication for the MCP schema**: build `submit`/`results` on `Experiment` /
`Vector{Experiment}` + function observables, not on new `Sweep` / `Observable{T}`
types. The runtime model is spec-centric; mirror it.

## 3. Genuinely greenfield (where the real cost is)

1. **UMS low-latency path** — no reference to `ums-submit` / `ums-list` / UMS in
   code or docs. The plan's central idea (§4) is entirely new. Cleanest seam:
   swap `_uge_qstat_list_cmd` / `prepare_status_snapshot` for `ums-list`, and add
   a `dispatch!` variant targeting a held allocation.
2. **Job dependencies / DAG / `-hold_jid`** — none. Each entry is independent.
   `on_complete` (parent_id lineage) is the nearest mechanism but fires *after*
   completion; it is not a submit-time DAG.
3. **Multi-user / project tags / namespace / per-user quota** — none.
   `enqueued_by` is a provenance string; budget is global. Phase 3 is all-new.
4. **Nix flake** — no `flake.nix` in this repo (the plan assumes it as "your
   home turf", but it is not yet wired here).
5. **Remote MCP transport (HTTP/SSE)** — existing MCP is stdio-only; Remote
   Control over HTTP/SSE is new.
6. **Cross-target routing** — `next_profile` escalates within one backend; there
   is no TSUBAME↔suzume routing policy.

## 4. Sharp edges

- **MCP duplication risk.** `tsubame_server.py` already exists. Standing up a
  separate Gateway MCP creates two. Decide up front: *extend the existing one to
  multi-HPC* vs *replace it*. The plan is written greenfield and does not mention
  this asset.
- **UMS held allocation ⊥ "small always-on Gateway".** UMS keeps a `node_f`
  alive; idle time burns points. This is in tension with the lightweight
  always-on service model. Who holds/tears down the allocation is unspecified.
- **Login-node compute ban.** The plan respects it, but the Gateway/MCP must be
  constrained in code to submit+monitor only — the current SSH-wrapper MCP can
  run arbitrary remote commands.
- **`qsub -g` must be a CLI flag** (`#$ -g` is rejected by the TSUBAME4 wrapper).
  Already learned and encoded (`backends_uge.jl:165-168`); preserve in new code.
- **Stale doc.** `docs/guides/tsubame.md` "SlurmBackend only" contradicts the
  shipped UGEBackend.

## 5. Re-scoped recommendation

- **Phase 1 is a thin shell.** Expose `submit/status/results/list_runs` over
  `Experiment` + the autopilot queue. Executor abstraction = `AutopilotBackend`;
  GridEngineExecutor = `UGEBackend`; LocalExecutor = `LocalBackend` — all present.
  The only new code is MCP bindings (extending `tsubame_server.py`).
- **Drop `SlurmExecutor`** (LocalBackend covers suzume).
- **Concentrate effort on Phase 2 UMS and Phase 3 multi-user** — that is the
  hard, novel surface. Plan the budget accordingly.

## References

- Plan source: conversation 2026-06-21 (this worktree).
- Autopilot: `src/workflow/autopilot/{types,backends,backends_uge,queue,tick,breakers,budget,monitor,retry,on_complete}.jl`
- CAS / Experiment: `src/workflow/experiment.jl`
- Dashboard: `src/workflow/io/dashboard/server/router.jl`, `websocket.jl`
- MCP: `scripts/mcp/tsubame_server.py`
- TSUBAME guide (note stale line): `docs/guides/tsubame.md`
- Container: `scripts/spinorbec.def`
