# Multi-user Gateway — identity, quota, authorization over a shared CAS

**Status**: design. Phase 3 of `compute_gateway_design.md`. Turn the
single-operator autopilot into a few-user shared service without losing the CAS
dedup that makes a shared base worth having.

## The core distinction: attribution, not isolation

The CAS is content-addressed and **deliberately shared** — same spec → same
`content_id` → same result, computed once for everyone (`experiment.jl:113-120`,
parent design pillar 4). So multi-user here is **not** about separate per-user
stores. It is about three things layered over one shared CAS:

1. **Attribution** — which user owns / triggered a run.
2. **Quota** — metering compute per user against a shared point budget.
3. **Authorization** — who may cancel / retry / delete whose runs.

"Namespace" in this design means an attribution + quota + authz key, **not** a
storage partition. Isolating storage per user would forfeit dedup — explicitly
rejected.

## What already exists (do not rebuild)

The identity **capture** seam is already in the tree:

- The dashboard HTTP server extracts the authenticated identity from upstream
  reverse-proxy headers, priority-ordered: `X-Auth-Request-Email` (oauth2-proxy +
  Google Workspace, full `anko@isct.ac.jp`) → `X-Authenticated-User` (Caddy
  basicauth) → `X-Forwarded-User` → `Remote-User`; first non-empty wins, trusted
  only behind the proxy (`server/router.jl:142-157`).
- The dashboard enqueue route already stamps that identity into `enqueued_by`
  (`routes/autopilot_enqueue.jl:74`).
- oauth2-proxy deployment exists, anko-only via `authenticated_emails_file`,
  openable to the lab by appending emails (`scripts/deploy_dashboard_auth.sh`).
- `QueueEntry` carries `enqueued_by::String` and `group_id::String`
  (`queue.jl:98,105`); the dashboard groups the queue by `group_id`.

So the OAuth boundary + identity extraction + a provenance field are done. The
gaps are everything that turns captured identity into policy.

## The four gaps

1. **`enqueued_by` is provenance, not an owner.** It also holds `"manual"`,
   `"cli"`, `"on_complete:<recipe>"` — not always a person. Quota/authz need a
   distinct, always-a-principal `owner` field.
2. **Identity doesn't cross the MCP / Claude Code path.** The MCP server runs as
   one service account; `tsubame_enqueue` sends `["enqueue", config_path]` with no
   `--enqueued-by` (`scripts/mcp/tsubame_server.py:442`). Every MCP enqueue is
   currently anonymous. The dashboard path has identity; the agent path does not.
3. **Budget is global.** One `budget.toml` at `qr.path`, one quarter/daily cap,
   `refresh_budget!` sums over all entries (`budget.jl:114-185`). No per-user
   metering.
4. **No authorization on mutating ops.** `cancel!` / `retry_failed!` have no
   ownership check — any caller can act on any run.

## Design

### 4.1 Identity model

Add `owner::String` to `QueueEntry` (institutional email, or a reserved principal
like `svc:harness` for the autonomous harness). Schema bump
`state.toml` v1.1 → v1.2 (migration: absent `owner` → `""` = unattributed
legacy). `enqueued_by` stays as provenance; `owner` is the policy key. A run's
owner is set once at enqueue and never mutated (like other provenance fields).

Dedup nuance: when a second user enqueues a spec whose `content_id` already has a
completed result, `run!` returns the cached result (the whole point). The
**second** request is attributed to its owner for *fairness telemetry* but
incurs **no compute** and **no quota charge** — quota meters realized GPU·hours,
which are zero on a cache hit. Owner of record stays the first to compute it;
later requesters are recorded as consumers, not owners. (Keeps the "don't
recompute across users" win intact.)

### 4.2 Identity through the MCP path

Two principals, two mechanisms:

- **Interactive users (Claude Code → MCP over stdio/SSH).** The MCP process runs
  under the invoking user's session; stamp `owner` from an env var the launcher
  sets per user (`SPINORBEC_PRINCIPAL`, defaulted from the SSH login / OS user).
  `tsubame_enqueue` gains an `--enqueued-by`/owner arg sourced from it.
- **Autonomous harness (Agent SDK service).** A reserved `owner="svc:harness"`
  with its own quota line, as the parent design specified (one service-account
  seat). Its runs are attributable and capped separately from humans.

This is the one greenfield seam on the agent side; the dashboard side already has
identity.

### 4.3 Per-user quota

Generalize the budget from one record to per-principal records, keyed by `owner`:

- `budget.toml` → `budgets/<principal>.toml` (or one file keyed by principal),
  each an `AutopilotBudget` (quarter/daily cap + realized). A `default` template
  applies to new principals.
- `refresh_budget!` groups the realized-hours sum by `entry.owner`
  (`budget.jl:124-131` already iterates entries — add a group-by).
- `budget_gate` is called per principal at dispatch: an entry dispatches only if
  *its owner's* budget allows. A shared **group ceiling** (the TSUBAME point
  pool) sits above the per-user caps — gate against `min(user_cap, group_pool)`.
- The UMS lease (Phase 2) charges its idle/active GPU·hours to the principal who
  triggered the lease, or to a shared `infra` principal if it serves multiple —
  decide per O-question below.

### 4.4 Authorization

Ownership guard on mutating queue ops:

- `cancel!` / `retry` / archive accept a `caller` principal and refuse when
  `entry.owner != caller` unless `caller` is an admin principal (config list).
- The reap loop's divergence-kill is system-initiated (`caller="svc:autopilot"`,
  always allowed).
- The MCP `cancel` tool passes the session principal; the CLI passes the OS user.
- Enforced at the queue-op boundary, not scattered — one `authorize(op, entry,
  caller)` helper. Failures return a CheckResult-style refusal, never throw
  (consistent with the inspector's 4-severity model).

### 4.5 Command-guard for the headless / raw-SSH surface

The parent design demotes raw-SSH MCP tools to an escape hatch; multi-user makes
the guard load-bearing. A PreToolUse-style guard (mirroring the audit's
`slurm-mcp-server` SSH-escape categories) blocks, for any principal:

- `qdel` of a job not owned by the caller (cross-check against the queue).
- writes/`rm` under another principal's attribution or the group disk root.
- compute on the login node (enforce submit+monitor-only, per parent design).

### 4.6 Dashboard read API / SSE

The read surface is HTTP + WebSocket today (`server/router.jl`,
`/ws/scrub`); no SSE. For multi-user live status, add an SSE endpoint
(`/api/events`) emitting queue/owner/budget deltas, filtered by the viewer's
principal (from the same proxy header). SSE over WS here because the payload is
small JSON deltas, not binary scrub frames, and SSE rides the existing
proxy/auth path with no upgrade handshake.

### 4.7 Submit-time DAG (optional, deferred)

`-hold_jid` submit-time dependencies (audit gap) are independent of multi-user
and only needed if campaigns require ordered chains beyond `on_complete`
lineage. Keep out of Phase 3 unless a concrete campaign needs it.

## Phased checklist

**3a — attribution**
1. `owner` field + state.toml v1.2 migration; set at enqueue (dashboard already
   has identity; wire MCP `--enqueued-by`/owner from `SPINORBEC_PRINCIPAL`).
2. Reserve `svc:harness` / `svc:autopilot` principals.

**3b — quota + authz**
3. Per-principal budgets; `refresh_budget!` group-by-owner; per-owner
   `budget_gate` under a shared group ceiling.
4. `authorize(op, entry, caller)` guard on cancel/retry/archive + admin list.

**3c — surface**
5. Command-guard for raw-SSH/headless (cross-owner qdel, group-disk writes,
   login-node compute).
6. SSE `/api/events` filtered by principal; dashboard queue/budget views per user.
7. Open oauth2-proxy from anko-only to the lab roster; tailnet ACL per role.

## Open questions

- **O1**: lease (Phase 2) cost attribution — per-trigger principal vs a shared
  `infra` line? A lease serving many users' interactive tasks is naturally shared;
  charging one user is unfair, charging `infra` hides it from per-user caps.
- **O2**: admin principal source — config list, or a tailnet/OAuth group claim?
- **O3**: do we trust `SPINORBEC_PRINCIPAL` on the interactive MCP path, or
  require the same OAuth as the dashboard? (stdio MCP has no proxy in front.)
- **O4**: fairness telemetry for cache-hit consumers — worth surfacing, or noise?

## References

- Parent design: `docs/design/compute_gateway_design.md`
- UMS lease (Phase 2): `docs/design/ums_lease_backend_design.md`
- Identity capture: `src/workflow/io/dashboard/server/router.jl:142-157`,
  `routes/autopilot_enqueue.jl:74`
- OAuth deploy: `scripts/deploy_dashboard_auth.sh`
- Queue entry / budget: `src/workflow/autopilot/queue.jl:88-138`,
  `src/workflow/autopilot/budget.jl`
- MCP: `scripts/mcp/tsubame_server.py`
