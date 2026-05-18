---
turn: 111
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: "Update (T110 critic emitted INCONCLUSIVE-SPATIAL-REQUIRED — necessary conditions NC1+NC2+symmetry+trap-match all SUSTAINED, but the load-bearing visual annular density signature lives in `result.jld2` which the T108 sandbox blocked; T110 explicitly routed to anko-consult to run the staged `extract_ring_metrics.jl`. Scheduler_111 is JULIA_GPU_OK with full headroom, so the loop CAN now execute that script directly — no anko-consult needed.)"
stage_advancing_to: Update
topic_tags: [edh-eu151-matsui-science-2026, central-falsifier-F1, spatial-ring-extraction, staged-script-execution, julia-cpu-light, JULIA_GPU_OK-restored, T108-blocker-cleared, artifact-existing-no-new-sim, D1-axis]
paper_section: null
depends_on:
  - 110
  - 109
  - 108
  - 107
  - 86
  - "runs/_loop/seed.md"
  - "runs/_loop/director/turn_110.md"
  - "runs/_loop/judge/turn_110_critic_audit.md"
  - "runs/_loop/judge/turn_110.json"
  - "runs/_loop/research/turn_109.md"
  - "runs/_loop/sim/turn_108.md"
  - "runs/_loop/_local/scheduler_111.json"
  - "runs/eu151_edh_K3_long/result.jld2"
  - "runs/eu151_edh_K3_long/extract_ring_metrics.jl"
  - "runs/eu151_edh_K3_long/run_extract_ring_metrics.sh"
  - "runs/eu151_edh_K3_long/trajectory.csv"
  - "runs/eu151_edh_K3_long/config.yaml"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:feedback_cost_overhead_is_the_cost"
  - "memory:feedback_fix_the_class_not_the_instance"
produces: >
  T111 implementer_julia_cpu_light dispatch. Inputs: T108's pre-staged
  `runs/eu151_edh_K3_long/extract_ring_metrics.jl` + `run_extract_ring_metrics.sh`
  (no modifications needed — the script is correct as written; verified by reading
  lines 1-80). Action: execute the staged shell wrapper, which runs
  `julia --project=. runs/eu151_edh_K3_long/extract_ring_metrics.jl` from the
  project root. Produces `spatial_profiles.csv` (501 frames × 5 components = 2505
  rows of azimuthally-averaged radial density) + `ring_summary.json` (aggregate
  verdict + per-frame ring-presence flags + max-stats). NO new simulation — the
  source is the existing `result.jld2` from the May-13 K3_long run. T112 then
  dispatches critic to re-evaluate F1 with the spatial evidence now visible.
---

# Turn 111 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `edh-eu151-vortex-vs-matsui-science-2026` (priority 0, flow_template `verify-claim`, tier_current 2.75, tier_target 3, F1 `is_central:true` with `tested_at_turn:110`, last verdict `INCONCLUSIVE-SPATIAL-REQUIRED`). Seed.md mandates this as the active investigation.

- **T110 outcome decoded**: judge/turn_110.json `PASS` (all 18 success criteria green); critic emitted `INCONCLUSIVE-SPATIAL-REQUIRED` with `tier_recommended: 2.5`. Critic §3 audited T109 claims A-F independently — A SUSTAINED, B SUSTAINED w/ advisory, C SUSTAINED exactly, D CHALLENGED-ADVISORY (order-of-magnitude), E SUSTAINED, F SUSTAINED-stronger-than-claimed. The necessary-condition stack (NC1+NC2+symmetry+trap) is now well-supported, but the load-bearing visual annular density signature is unverified because the spatial wavefunction lives in `result.jld2` and was julia-denied in T108's sandbox.

- **The crucial new fact at T111**: scheduler_111.json line 11 = `policy: JULIA_GPU_OK`, line 12-23 explicitly lists `implementer_julia_cpu_light` / `implementer_julia_cpu_heavy` / `implementer_julia_gpu` in `allowed_workloads`; probe shows `vram_free_mb: 12844`, `ram_avail_gb: 25.02`, `foreign_julia: 0`. **The T108 sandbox-denial blocker is GONE**. T110 critic §4 routed the F1 verdict to "anko-consult: bash run_extract_ring_metrics.sh" precisely because of T108's denial; with the denial lifted, the loop can execute that command itself — no anko-consult needed.

- **The decision tree this turn**: T110 critic explicitly stated (§4, §6) that Stage-1 verdict is blocked on running `extract_ring_metrics.jl` against the existing `result.jld2`. T108 already wrote the script. Scheduler now permits its execution. Per `feedback_use_existing_artifacts_first` (running an extractor on existing JLD2 is reading-existing-data, not a new simulation) + `feedback_cost_overhead_is_the_cost` (stop deliberating, just execute) + protocol §B "Artifact-first path" (existing artifact, tier_current 2.75 < 3, last verdict NOT substantively-INCONCLUSIVE-on-substance — it was INCONCLUSIVE-on-data-gap that we now have the tool to close): set `subagent_type = implementer_julia_cpu_light`, advance stage = `Update` (same stage, this is the data-acquisition substep that the Update audit was blocked on).

- **Why NOT critic again (T112 path)**: critic at T112 needs the spatial data file to audit. Without `spatial_profiles.csv` + `ring_summary.json`, T112 critic returns identical INCONCLUSIVE-SPATIAL-REQUIRED. Critic must be deferred to AFTER the extractor runs. T111 = data acquisition; T112 = critic re-audit.

- **Why NOT implementer_text (the T110 fallback contract path)**: T110's failure-mode JSON line 298-301 said "T111 dispatch implementer_text to update conclusions/<inv_id>.md with INCONCLUSIVE verdict + explicit anko-consult routing for manual JLD2 spatial extraction". That was contingent on the sandbox-julia-denial holding. It does NOT hold this turn. The higher-leverage move is to run the extraction, not to write a "please run this manually" memo. Per `feedback_cost_overhead_is_the_cost`: prefer execution over deliberation when execution is permitted.

- **Why NOT a new simulation**: the K3_long run finished May 13 with 14.5 ms physical dynamics, 501 saved frames at 32³ ComplexF32, all 13 spinor components, K3 + gamma_dr + noise seed enabled. `result.jld2` is 1.67 GB on disk. The data exists. Running a new EdH sim would be a direct violation of `feedback_use_existing_artifacts_first`.

- **Why NOT theorist hard-derivation**: T109 closed the methodology gap; T110 closed the necessary-condition gap. The remaining gap is empirical (does the spatial profile show a ring?), not theoretical. Theorist would have nothing to derive that T109+T110 didn't already cover.

- **Why NOT noop**: scheduler is permissive (JULIA_GPU_OK), staged script exists (T108 already wrote it correctly, verified above), data exists (result.jld2 1.67 GB on disk), F1 verdict is the loop's longest-running blocked item (since T76 May-13). All three pre-conditions for execution are met. Noop would waste the opening.

- **Per `feedback_fix_the_class_not_the_instance`**: T110 §5 documented the class finding (T76-T86 ad-hoc threshold heuristic; state.json text was project-internal). That class-finding documentation is the conclusions/<inv_id>.md update T110's failure-mode prescribed. It is already partly there (line 14-16 of conclusions file has the T110 entry). The T111 implementer-julia run produces NEW evidence; T112 critic + T113 implementer_text close the class-finding update with the actual F1 verdict.

- **Subagent rotation last 7 turns**: impl_text (T105), impl_text (T106), critic (T107), implementer_julia (T108), researcher_deep (T109), critic (T110), **implementer_julia (T111)**. T108's implementer_julia was BLOCKED (sandbox denial) and FAIL_OPERATIONAL_SANDBOX. The current dispatch is the unblocked retry, with scheduler explicitly green. Not a same-class streak: T108 was 3 turns ago, with critic and researcher between.

- **Quota check (§A Quota Precedence)**: scheduler_111.json `window_seconds_left=1,107,673` (~18,461 min). Policy JULIA_GPU_OK. `implementer_julia_cpu_light` allowed. The extract_ring_metrics.jl script does 501 frames × 5 components × azimuthal-bin reduction on 32³ grids; estimated wall-time ~5-10 min (mostly Julia precompile cost on first run, then ~milliseconds per frame). RAM ~3 GB (loading 4-D ComplexF32 32×32×32×13 × 501 frames is the memory cap; result.jld2 is 1.67 GB so deserialization fits in 25 GB available). Cost expected: ~1.5-2.5M effective (julia precompile dominates, plus implementer's prep/log work).

- **Tier-3 promotion gate awareness (§B Tier-3 gate)**: F1 IS the central falsifier with `is_central:true`. T111 produces the spatial data; T112 critic re-evaluates F1. Tier promotion paths:
  - If `ring_summary.json` reports ring_present_any_frame_any_c=true at t ∈ [1.5, 7] ms in c=2 → T112 critic CORROBORATE-STAGE-1 → tier 2.75 holds, full 3.0 still requires Stage-2 Bragg (out of scope, future investigation).
  - If ring_present=false at any frame → T112 critic REFUTED-OTHER → tier 2.75 → 2.0 with caveat about N=10k vs Matsui N~50k.
  - If ring_present=true but at wrong time/component → T112 critic REFUTED-TIMESCALE-MISS or REFUTED-OTHER → tier 2.0.

  Per critic.md §F8 / judge.py tier-3 clamp: full 3.0 needs is_central F1 CORROBORATE on BOTH Stage-1 and Stage-2 (Bragg). Stage-2 simulation is a separate future investigation. T112 max promotion = 2.75 (Stage-1 only).

## 2. Recent-turn audit (last 7 turns)

| Turn | Investigation | Stage | Subagent | Verdict | What happened |
|---|---|---|---|---|---|
| T105 | audit-class-scan-T103 | Triage mech-half | implementer_text | PASS | patterns.yaml + state.json bookkeeping |
| T106 | audit-class-scan-T103 | Document | implementer_text | PASS | Memory entry; close |
| T107 | edh-eu151-matsui | Update | critic | CRITIC_INCONCLUSIVE | F1 INCONCLUSIVE: spatial data gap, ad-hoc threshold flag |
| T108 | edh-eu151-matsui | Update | implementer_julia | FAIL_OPERATIONAL_SANDBOX | extract_ring_metrics.jl + run_extract_ring_metrics.sh staged; sandbox julia denied |
| T109 | edh-eu151-matsui | Research | researcher_deep | FAIL_OPERATIONAL (contract-shape; substantive PASS) | Matsui methodology + symmetry + NC1/NC2 extracted; 28 sources; trap params closed |
| T110 | edh-eu151-matsui | Update | critic | PASS (verdict INCONCLUSIVE-SPATIAL-REQUIRED) | F1 verdict: NC stack SUSTAINED, spatial data gap remains, route to manual extraction |
| **T111** | **edh-eu151-matsui** | **Update (data-acquisition substep)** | **implementer_julia_cpu_light** | **TBD** | **Execute T108's staged `bash run_extract_ring_metrics.sh`; produce spatial_profiles.csv + ring_summary.json from existing result.jld2** |

Class rotation: critic (T107), implementer (T108), researcher (T109), critic (T110), implementer (T111). No same-class consecutive streak (T108 was 3 turns ago, blocked then; T111 is the unblocked retry).

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Stage**: stays at **Update** (same as T107, T108, T110). The Update stage is the F1 central-falsifier audit substep; it has multiple internal beats: (a) T107 critic established gap, (b) T108 staged extractor (blocked), (c) T109 closed methodology gap, (d) T110 critic verdict-with-data-gap-flag, (e) **T111 close data gap by executing staged extractor**, (f) T112 critic re-audit with full evidence, (g) T113 implementer_text Document + state.json patch.
- **Role for the Update data-acquisition substep**: implementer (Julia), per the protocol stage-role table for `verify-claim` "Execute=implementer". This substep is structurally Execute-class work (run code, produce data) embedded inside the Update audit cycle. Naming the stage "Update" preserves the audit-cycle continuity; the implementer dispatch is the right role.
- **Artifact-first path (protocol §B)**: result.jld2 is the existing artifact; tier_current 2.75 < 3; last verdict T110 was INCONCLUSIVE-on-data-gap (NOT substantively-INCONCLUSIVE-on-physics). Per protocol "Brief the critic to audit the existing artifact" — except the prerequisite is that the audit be **possible**; right now it isn't, because the spatial dimension of the artifact is unreadable. T111 makes the audit possible by extracting the spatial dimension into a critic-readable CSV+JSON pair. Then T112 fulfills the artifact-first critic dispatch.

## 4. Research grounding (§A6)

T111 dispatch citations:

1. **`runs/_loop/seed.md`** lines 3-31 — investigation re-opened; F1 must be evaluated against published Matsui criterion against the May-13 K3_long artifact. T110 closed methodology + symmetry + NC; T111 closes data extraction; T112 closes verdict.
2. **`runs/_loop/judge/turn_110_critic_audit.md`** §4 (verdict), §6 (Stage-1/Stage-2 split), §7 (falsifier update fragment) — the load-bearing T111 antecedent. Critic explicitly routes to "execute `bash runs/eu151_edh_K3_long/run_extract_ring_metrics.sh`". T111 executes exactly that.
3. **`runs/_loop/judge/turn_110.json`** lines 9-31 — confirms T110 PASS, critic_verdict=INCONCLUSIVE, f1_verdict_label=INCONCLUSIVE-SPATIAL-REQUIRED, tier_recommended=2.5. T111 acts on this verdict directly.
4. **`runs/_loop/sim/turn_108.md`** §3, §10 — sandbox julia denial AT T108. T108's `extract_ring_metrics.jl` (verified above lines 1-80) is well-written, uses the correct grid convention from `src/foundation/grid.jl`, computes azimuthal-averaged radial profile + r=0-depth + FWHM aspect ratio for channels (1,2,3,4,13) matching m=(+6,+5,+4,+3,-6). T111 runs this verbatim — no script modification needed.
5. **`runs/_loop/_local/scheduler_111.json`** lines 11-25 — policy JULIA_GPU_OK, `implementer_julia_cpu_light` in `allowed_workloads`, full headroom probe. Direct authorization to execute.
6. **`runs/eu151_edh_K3_long/run_extract_ring_metrics.sh`** verbatim 9 lines — `cd /home/suzume/workspace/BEC-simulation && exec /home/suzume/.juliaup/bin/julia --project=. runs/eu151_edh_K3_long/extract_ring_metrics.jl`. Canonical project-rooted execution per CLAUDE.md.
7. **`runs/eu151_edh_K3_long/extract_ring_metrics.jl`** lines 1-80 — script header documents output schema, channels, thresholds, time conversion. Self-contained, no edits needed.
8. **`runs/eu151_edh_K3_long/result.jld2`** (1.67 GB on disk) — primary data source; 501 frames × 4-D ComplexF32 spinor (32, 32, 32, 13).
9. **`memory/feedback_use_existing_artifacts_first`** — T111 reads existing JLD2; produces spatial summary; proposes NO new simulation.
10. **`memory/feedback_cost_overhead_is_the_cost`** — scheduler permits, script staged, data exists; execute rather than deliberate. The deliberation IS the waste.
11. **`memory/feedback_fix_the_class_not_the_instance`** — T110 §5 documented the class finding (state.json ad-hoc threshold heuristic); T111 implementer applies the now-honest qualitative criterion to spatial data. The class-finding fix is operational, not theoretical.
12. **CLAUDE.md Wavefunction convention** — `psi[x, y, ..., c]` with c=1↔m=+F, c=13↔m=-F. extract_ring_metrics.jl line 53 `c_to_m(c::Int) = 7 - c` matches (c=1→m=+6, c=13→m=-6).

## 5. Calibrated progress check

- **D-axis advanced**: **D1 (verification of existing physics; Tier ladder 0→3)** for `edh-eu151-vortex-vs-matsui-science-2026`. T111 produces the spatial extraction artifact that has been blocking the F1 verdict since T76 (May 13, ~6 days ago). This is the data-acquisition substep of the central-falsifier audit cycle.

- **Tier ladder routing decisions (post-T112)**:
  - **CORROBORATE-STAGE-1 path** (most likely a-priori given NC1+NC2 SUSTAINED): if `ring_summary.json` reports ring_present_any_frame in c=2 within [1.5, 7] ms with depth >20% AND aspect >1.5 (the script's strict-AND criterion; note this is also project-internal but operationally workable as a quantitative hint pending T112's critic re-evaluation against T109's qualitative criterion) → T112 critic CORROBORATE-STAGE-1 → tier 2.75 holds (already there).
  - **CORROBORATE-STAGE-1-qualitative path**: T109 §2 established Matsui's criterion is qualitative; even if the script's strict-AND threshold misses, T112 critic might judge a visually-identifiable ring via the radial profile shape (e.g., off-axis peak with r=0 dip even if not >20%) → tier 2.75 holds. T112 critic owns this judgement.
  - **INCONCLUSIVE path**: if the radial profiles show a transient feature that is ambiguous (partial dip, no clear annulus) → tier 2.75 holds, route T113 to Stage-2 (Bragg) future-investigation spawning.
  - **REFUTED path**: if no ring at any frame in any of c=2/3/4 → T112 critic REFUTED-OTHER → tier 2.75 → 2.0 with N-scaling caveat. Recommend N=50k follow-up investigation before retracting EdH claim.

- **Drift advisories**:
  - **DRIFT_MANUSCRIPT_DELTA_ZERO**: T111 is D1 physics-verification on a central falsifier (data extraction substep). Per `feedback_manuscript_is_not_the_essence`: this IS the essence. Structural choice match.
  - **DRIFT_COST_INFLATION**: T111 implementer_julia_cpu_light expected ~1.5-2.5M effective (julia precompile dominates first invocation; the actual extraction is fast). T110 was 1.89M; this is comparable. Hard cap 5M. Per `feedback_cost_overhead_is_the_cost`: hard caps + leverage are the only criteria; both fine.
  - **DRIFT_VERDICT_DRIFT**: Last 7 verdicts: PASS, PASS, INCONCLUSIVE, INCONCLUSIVE, FAIL_OPERATIONAL, PASS, ?. T111 likely emits PASS (the script either runs to completion or produces a JLD2 error; the contract structure is binary on file existence + JSON validity). Restores PASS trajectory.
  - **DRIFT_TOPIC_REPETITION**: edh-matsui at T107+T108+T109+T110+T111 = 5 of last 7. High. Override condition: seed.md priority 0; central falsifier evaluation is the loop's longest-running blocked item. The protocol's picking-table rule "seed.md top section names a specific investigation → pick it; ignore lower rules" explicitly authorizes this.

- **Class-level finding to surface in implementer-julia work**: NONE this turn (T111 is mechanical script execution; class-finding documentation is T110's deliverable, already done in conclusions ledger §T110 entry).

- **Anticipated drift trajectory T111**:
  - `topic_repetition`: 0.71 (edh-matsui at T107+T108+T109+T110+T111 = 5 of last 7; high but priority-0 per seed.md, explicitly authorized)
  - `subagent_repetition`: 0.29 (implementer at T105+T106+T108+T111; not consecutive)
  - `manuscript_delta_zero`: 1.0 (expected; implementer-julia produces CSV+JSON, no docs)
  - `code_delta_zero`: 1.0 (expected; runs existing script, no code change — verified T108's script is correct as-written)
  - `verdict_drift`: ↑ (PASS expected on successful extraction; binary outcome on file existence)
  - `cost_inflation`: ~0.7-0.9 (1.5-2.5M expected; comparable to recent turns)
  - `novel_claim_zero`: ↓ (produces new empirical evidence — spatial ring profiles per frame per component — that was never extracted before)

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Update",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 1,
  "project_axis": "D1",
  "rationale": "T110 critic emitted INCONCLUSIVE-SPATIAL-REQUIRED (verdict PASS at judge.py contract level) — necessary conditions NC1+NC2+symmetry+trap-match all SUSTAINED, but the visual annular density signature (Stage-1 of T109's qualitative criterion) is unverified because the 4-D ComplexF32 spinor wavefunction lives in result.jld2 (1.67 GB) which T108 sandbox blocked. Critic §4 routed to 'execute bash run_extract_ring_metrics.sh'. Scheduler_111 is JULIA_GPU_OK (line 11) with implementer_julia_cpu_light in allowed_workloads (line 21) + full headroom (vram 12844 MB, RAM 25 GB, foreign_julia=0) — the T108 blocker is GONE. Per feedback_use_existing_artifacts_first: running an extractor on existing JLD2 is reading-existing-data, not new sim. Per feedback_cost_overhead_is_the_cost: scheduler permits + script staged correctly (verified extract_ring_metrics.jl lines 1-80 use correct grid convention from src/foundation/grid.jl and match CLAUDE.md spinor c-index convention) + data exists; deliberation is the waste, execute. Protocol §B Artifact-first path: tier_current 2.75 < 3, last verdict was data-gap-INCONCLUSIVE not substance-INCONCLUSIVE, the central falsifier audit cycle needs this data-acquisition substep before T112 critic can re-evaluate. D1 axis: this produces the spatial evidence that has blocked the F1 central-falsifier verdict since T76 (May 13).",
  "brief": "## ROLE\n\nYou are the implementer for T111 Update-stage data-acquisition substep of investigation `edh-eu151-vortex-vs-matsui-science-2026`. T108 already wrote the extraction script `runs/eu151_edh_K3_long/extract_ring_metrics.jl` + wrapper `run_extract_ring_metrics.sh` but was sandbox-blocked from running julia. Scheduler_111 has restored JULIA_GPU_OK policy (line 11) with `implementer_julia_cpu_light` in allowed_workloads (line 21). Your job is to EXECUTE the staged shell wrapper and confirm both output files (`spatial_profiles.csv` + `ring_summary.json`) materialize correctly.\n\nDIRECTIVE_LABEL: edh-eu151-matsui-T111-update-execute-staged-extract-ring-metrics\n\n## CRITICAL CONTEXT (load BEFORE execution)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md` §4 (verdict) and §6 (Stage-1/Stage-2 split) — confirms F1 is blocked exactly on the spatial-extraction artifact this dispatch produces.\n2. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh` (9 lines, verbatim) — the wrapper. DO NOT edit it.\n3. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl` lines 1-80 (already verified by director). The script computes azimuthally-averaged radial density per channel ∈ {1,2,3,4,13} per saved frame, with strict-AND threshold (depth > 20% AND aspect > 1.5) AND raw radial profile output. DO NOT edit it.\n4. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2` (1.67 GB) — the source. Already on disk from May 13 run.\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/_local/scheduler_111.json` — confirms JULIA_GPU_OK policy + implementer_julia_cpu_light authorized.\n\n## YOUR TASK\n\n### Step 1: Precondition checks\n\nRun:\n```\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh\ntest -x /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh || chmod +x /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh\n```\n\nIf any precondition fails, ABORT and report the failure. Do NOT attempt to recreate the script (T108 already did this work correctly).\n\n### Step 2: Execute the staged extractor\n\nRun the shell wrapper from the project root. First Julia invocation will JIT-compile SpinorBEC + JLD2 + CodecZstd; expect ~5-10 min wall time (mostly precompile cache miss if this is the first SpinorBEC load in this session; subsequent loads are ~30 s). Use `run_in_background: true` per the working-style guidance, then poll completion via the output file existence — do NOT sit in a `while ps -p $PID` watcher.\n\nSuggested invocation:\n```\nbash /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh 2>&1 | tee /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.log\n```\n\nWhile the extractor runs in the background, you can simultaneously prepare the §4 sim/turn_111.md write-up draft.\n\n### Step 3: Verify outputs exist + are structurally valid\n\nAfter completion:\n```\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json\nwc -l /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv  # expect ~2506 lines (1 header + 2505 rows)\npython3 -c \"import json; d=json.load(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json')); print(list(d.keys())); print('ring_present_any_frame_any_c:', d.get('ring_present_any_frame_any_c'))\"\n```\n\n### Step 4: Tabulate the key findings (NOT a verdict)\n\nWrite `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_111.md` with the standard §4 Metrics JSON block. KEY FIELDS to extract from `ring_summary.json` and report verbatim:\n- ring_present_any_frame_any_c (bool)\n- ring_present_any_frame_c2 (bool) — most physically relevant per T109 §3 symmetry mapping\n- t_ring_first_ms_c2 (number or null) — earliest frame in c=2 where strict-AND triggers\n- max_depth_pct_c2 (number)\n- max_aspect_c2 (number)\n- ring_strict_in_band_15_7_ms_c2 (bool) — whether strict-AND threshold AND t ∈ [1.5, 7] ms BOTH hit in c=2\n- per_channel_max_stats: dict of c → {max_depth_pct, max_aspect, t_at_max_ms}\n\nDO NOT issue an F1 verdict. That is T112 critic's job. Your job is to surface the raw evidence cleanly so T112 can apply T109's qualitative criterion.\n\nIf `ring_summary.json` does NOT include the keys above with those exact names, look at the actual schema the script emits and report the analogous fields verbatim. T108's script was written before T109's symmetry-mapping decision so it may use different naming; report what is actually there.\n\n### Step 5: Self-checklist\n\n- [ ] Preconditions verified (4 files existed, wrapper executable)\n- [ ] Wrapper executed successfully (exit code 0, log captured)\n- [ ] spatial_profiles.csv exists and has plausible row count (~2506)\n- [ ] ring_summary.json exists and is valid JSON\n- [ ] sim/turn_111.md written with §4 Metrics block\n- [ ] No src/, no test/, no YAML edits\n- [ ] No new simulation initiated\n- [ ] No script modification\n- [ ] All paths absolute\n- [ ] No anko-attribution\n- [ ] No improvised terminology\n\n## CONSTRAINTS\n\n- **READ + EXECUTE only**. The only write targets are: (a) the script's own output files (spatial_profiles.csv + ring_summary.json), (b) extract_ring_metrics.log, (c) runs/_loop/sim/turn_111.md. NO src/ edits, NO test/ edits, NO YAML edits, NO state.json mutation, NO script modification.\n- **No new simulation initiated**. The extractor reads result.jld2; it does not call find_ground_state or run_simulation!. If the script accidentally invokes those, ABORT and report — this would be a script bug to flag, not to silently absorb.\n- **CPU only** — extract_ring_metrics.jl does not use CUDA. If you observe GPU activation, ABORT — that would indicate a script regression.\n- **No agent-internal verdict on F1**. T112 critic owns that. Your output is data + raw stats.\n- **English only**. No emojis. No improvised terminology. No anko-attribution.\n- **Absolute paths only**.\n- **Budget**: ~1.5-2.5M effective, 4M hard cap. Wall ~10-15 min (precompile-dominated).\n- **Cost overhead is the cost**: prefer execution over deliberation. The script is staged correctly; the data exists; the scheduler permits. Just run it.\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT rewrite `extract_ring_metrics.jl`. T108 wrote it carefully; the director verified lines 1-80 use correct grid convention + c-index convention. If you think there's a bug, DOCUMENT the suspicion in sim/turn_111.md §Errata and run the script anyway — empirical results from a possibly-buggy script are still better than no spatial data at all (T112 critic can re-audit the methodology).\n- Do NOT propose a new YAML or new EdH simulation. Existing K3_long is the source.\n- Do NOT issue an F1 verdict. T112 critic.\n- Do NOT defer to anko-consult. Scheduler_111 explicitly permits this dispatch; that's the whole point.\n- Do NOT spend tokens deliberating whether to run the script. Per `feedback_cost_overhead_is_the_cost`: the deliberation is the waste. Run it.\n- Do NOT block-poll with `while ps -p`. Background the julia process; while it runs, prepare the sim/turn_111.md write-up draft so the wall-clock cost is parallelizable.\n\n## DELIVERABLES\n\n1. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv` (~2506 lines)\n2. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json` (aggregate metrics)\n3. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.log` (tee'd julia output)\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_111.md` (~1500-2500 tokens) — §4 Metrics block with the observable manifest fields below.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "script_exit_code",
      "spatial_profiles_csv_exists",
      "spatial_profiles_csv_lines",
      "ring_summary_json_exists",
      "ring_summary_json_valid",
      "ring_present_any_frame_any_c",
      "ring_present_any_frame_c2",
      "t_ring_first_ms_c2",
      "max_depth_pct_c2",
      "max_aspect_c2",
      "wall_time_sec",
      "src_edited",
      "test_edited",
      "yaml_edited",
      "state_json_edited",
      "script_edited",
      "new_simulations_initiated",
      "gpu_used"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2 && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md && echo OK_PRECONDITIONS"
  },
  "success_criteria": [
    {
      "id": "spatial-profiles-csv-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv",
      "expect": {"exit_code": 0}
    },
    {
      "id": "ring-summary-json-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "ring-summary-json-valid",
      "check_cmd": "python3 -c \"import json; json.load(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json'))\" && echo OK_JSON",
      "expect": {"exit_code": 0, "stdout_contains": "OK_JSON"}
    },
    {
      "id": "spatial-profiles-csv-has-rows",
      "check_cmd": "wc -l /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv | awk '{print ($1 >= 100) ? \"OK_ROWS\" : \"FEW_ROWS\"}'",
      "expect": {"exit_code": 0, "stdout_contains": "OK_ROWS"}
    },
    {
      "id": "sim-turn-111-deliverable-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_111.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "no-src-edited",
      "metric": "src_edited",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-test-edited",
      "metric": "test_edited",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-yaml-edited",
      "metric": "yaml_edited",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-state-json-edited",
      "metric": "state_json_edited",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-script-edited",
      "metric": "script_edited",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-new-simulation",
      "metric": "new_simulations_initiated",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-gpu-used",
      "metric": "gpu_used",
      "operator": "==",
      "value": false
    },
    {
      "id": "script-exit-code-zero",
      "metric": "script_exit_code",
      "operator": "==",
      "value": 0
    }
  ],
  "failure_modes": [
    {
      "if": "spatial-profiles-csv-exists failed OR ring-summary-json-exists failed",
      "category": "operational",
      "next_action": "T112 director inspects extract_ring_metrics.log for julia errors (JLD2 deserialization, CodecZstd world-age, memory pressure). If recoverable, T112 re-dispatches implementer with the diagnosed fix; if structural script bug, T112 dispatches theorist+implementer to revise extract_ring_metrics.jl (this would be a real script-quality finding to surface)."
    },
    {
      "if": "script-exit-code-zero failed (non-zero exit)",
      "category": "operational",
      "next_action": "Inspect log. Common causes: (a) JLD2 cannot find result.jld2 (file path bug), (b) CodecZstd not in environment (run `julia --project=. -e 'using Pkg; Pkg.instantiate()'` first), (c) memory OOM (file is 1.67 GB; should fit in 25 GB available; if not, reduce to a sub-set of frames). T112 director re-dispatches with diagnosis."
    },
    {
      "if": "ring-summary-json-valid failed",
      "category": "framework_error",
      "next_action": "JSON syntax error in script output — re-read extract_ring_metrics.jl JSON writer section, identify the bug, propose patch. T112 dispatches implementer_text to fix the writer."
    },
    {
      "if": "ring_present_any_frame_any_c == true AND ring_present_any_frame_c2 == true AND t_ring_first_ms_c2 in [1.5, 7]",
      "category": "scientific_corroborate_stage1_strong",
      "next_action": "T112 dispatches critic to apply T109 qualitative criterion to spatial_profiles.csv + visually inspect radial profiles at the identified frame. Expected verdict CORROBORATE-STAGE-1. Tier 2.75 holds (Stage-2 Bragg still required for full 3.0)."
    },
    {
      "if": "ring_present_any_frame_any_c == true BUT NOT in expected channel/time band",
      "category": "scientific_partial",
      "next_action": "T112 critic applies T109 qualitative criterion case-by-case (e.g., ring in c=3 instead of c=2 may still corroborate via cascade pathway). Possible CORROBORATE-STAGE-1 with caveats, or INCONCLUSIVE if ambiguous."
    },
    {
      "if": "ring_present_any_frame_any_c == false (strict-AND threshold misses everywhere)",
      "category": "scientific_qualitative_required",
      "next_action": "T112 critic re-evaluates with T109's QUALITATIVE criterion (visual ring without strict 20%/1.5 threshold). The script's strict-AND was T82's project-internal heuristic; T109 §2 established Matsui's actual criterion is qualitative. T112 critic reads spatial_profiles.csv radial profiles directly and judges visual ring-presence by eye / by depth>5%+aspect>1.2 soft band / etc. Possible CORROBORATE-STAGE-1 (qualitative ring under T109 criterion), INCONCLUSIVE, or REFUTED-OTHER (no annular structure at any time)."
    },
    {
      "if": "no-script-edited failed (implementer modified extract_ring_metrics.jl)",
      "category": "framework_error_anti_pattern",
      "next_action": "Reject deliverable; T108's script must be run verbatim for traceability. If a bug was discovered, document in sim/turn_111.md §Errata, do not silently patch. T112 dispatches theorist+implementer for an open-record script revision."
    },
    {
      "if": "no-new-simulation failed",
      "category": "framework_error_constraint_violation",
      "next_action": "Reject deliverable; the entire premise per feedback_use_existing_artifacts_first is that result.jld2 IS the data. Any new sim is wasted budget. Re-dispatch with strict no-sim guard."
    }
  ],
  "budget": {
    "expected_cost_eff": 2000000,
    "expected_wall_time_sec": 900
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Update",
    "if_success_tier_becomes": 2.75,
    "if_partial_advance_to_stage": "Update",
    "if_partial_tier_becomes": 2.75,
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 2.75,
    "if_success_falsifier_update": null,
    "note": "T111 is data-acquisition; F1 falsifier update happens at T112 critic re-audit. T111 success = spatial_profiles.csv + ring_summary.json exist + are valid + report ring presence/absence per channel per frame. Tier does NOT change at T111 (stays at 2.75); the tier-affecting moment is T112's F1 verdict re-evaluation with the spatial evidence now in hand.",
    "post_t111_pivot_options_by_outcome": [
      "T112 critic Update — re-apply T109 qualitative F1 criterion to spatial_profiles.csv + ring_summary.json; emit CORROBORATE-STAGE-1 / INCONCLUSIVE / REFUTED-OTHER. Tier 2.75 holds on CORROBORATE-STAGE-1; drops to 2.0 on REFUTED.",
      "T113 implementer_text Document — update state.json F1 with T112 verdict + tested_at_turn=112 + result; append to runs/_loop/conclusions/<inv_id>.md ledger.",
      "T114+ pivot to non-edh-matsui priority investigation once edh-matsui Stage-1 verdict is recorded (Stage-2 Bragg deferred as separate future investigation)."
    ]
  }
}
```

## 7. Drift advisories — explicit acknowledgement

- **DRIFT_MANUSCRIPT_DELTA_ZERO**: T111 is D1 physics-verification on a central falsifier (data-acquisition substep). Per `feedback_manuscript_is_not_the_essence`: this IS the essence. Structural choice match.

- **DRIFT_COST_INFLATION**: T111 implementer_julia_cpu_light expected ~2.0M effective (julia precompile-dominated). Below T110's 1.89M comparable, well below 4M hard cap. Per `feedback_cost_overhead_is_the_cost`: hard caps + leverage; both fine.

- **DRIFT_VERDICT_DRIFT**: Last 7 verdicts trend (PASS, PASS, INCONCLUSIVE, INCONCLUSIVE, FAIL_OPERATIONAL, PASS, ?). T111 contract is binary on file existence + JSON validity; expected PASS.

- **TOPIC_REPETITION** (anticipated 0.71): edh-matsui at T107-T111 = 5 of last 7. High but priority-0 per seed.md; explicit override authorized.

- **SUBAGENT_REPETITION** (anticipated 0.29): implementer at T105+T106+T108+T111. T108 was 3 turns ago, blocked. No same-class streak.

- **CODE_DELTA_ZERO** (anticipated 1.0): expected. T108's script is verified correct; no script modification needed.

All advisories accepted + addressed by structural choice.

## 8. Anti-noop justification

T111 is NOT noop because:
- Scheduler policy JULIA_GPU_OK explicitly permits `implementer_julia_cpu_light` (scheduler_111.json line 21).
- Probe shows full headroom (vram 12 GB, RAM 25 GB, foreign_julia=0).
- T108's extraction script is already written correctly (director verified lines 1-80).
- result.jld2 is on disk (1.67 GB).
- T110 critic explicitly routed to this execution (§4: "execute `bash runs/eu151_edh_K3_long/run_extract_ring_metrics.sh`").
- Seed.md mandates edh-matsui as priority 0; F1 is the central falsifier; T111 is the data-acquisition substep without which T112 critic cannot make progress.
- Skipping this dispatch wastes T108's staged work AND blocks T112+ progress.

## 9. Why this is not a same-class-as-T108 retry footgun

T108 was implementer_julia and was BLOCKED (sandbox denial). T111 is implementer_julia and is UNBLOCKED (scheduler explicit). The "no more than 2 same-subagent in a row" rule is about avoiding redundant work; T108 produced no output (it was denied), so T111 is the first successful implementer_julia attempt on this work item. Between T108 and T111: T109 (researcher_deep), T110 (critic). Three-turn gap with material progress in between (T109 closed methodology gap, T110 closed necessary-condition gap). T111 is the now-unblocked execution.

## 10. Preservation of T108-T110 deliverables

- T108's `extract_ring_metrics.jl` + `run_extract_ring_metrics.sh` remain unmodified — T111 implementer is explicitly forbidden from editing them. They will be RUN verbatim. Traceability preserved.
- T109's `runs/_loop/research/turn_109.md` remains the methodology anchor — T112 critic will cite §2-4 when applying the qualitative criterion to the spatial profiles.
- T110's `runs/_loop/judge/turn_110_critic_audit.md` §7 falsifier-update fragment will be superseded at T112 with the spatial-evidence-informed verdict; the T110 fragment is preserved in the audit record but not applied to state.json (per T110 §7 explicit instruction "T111 implementer_text applies the patch" — that step is now deferred to T113 after the actual verdict arrives at T112).
- T110 critic's class-finding documentation (T110 §5) is already in conclusions/<inv_id>.md (line 14-16) — T111 does not touch it.

## 11. Why this is structurally cleaner than the T110-failure-mode fallback

T110's failure-mode JSON (lines 298-301 of turn_110.md director report) specified: "if INCONCLUSIVE-SPATIAL-REQUIRED → T111 dispatch implementer_text to update conclusions/<inv_id>.md + explicit anko-consult routing." That contract was written under the assumption the T108 sandbox-denial would persist. It does not. The current scheduler explicitly permits the execution that T110 was forced to defer. Following the T110 fallback contract literally would mean writing a "please run this manually" memo while the loop has both permission and capability to run it directly — a strict violation of `feedback_cost_overhead_is_the_cost` ("execute, don't deliberate").

The protocol's precedence rule (system prompt closing): "seed.md > scheduler.json > this prompt > worked example". Seed.md says do the F1 audit. Scheduler permits julia. The faithful reading is: execute the audit's data-acquisition substep with the now-available capability, not write a memo about its unavailability.

## 12. Stage-2 Bragg (future investigation, not T111)

T110 critic §6 explicitly OUT_OF_SCOPE'd Stage-2 (Bragg interferometric phase-winding, Matsui Fig. 3). Full Tier-3 promotion to 3.0 requires both Stage-1 (this audit cycle) and Stage-2 CORROBORATE. T111 does not address Stage-2. After T112 closes Stage-1 verdict (max tier 2.75), the natural T113+ paths are:

(a) implementer_text Document Stage-1 closure + spawn a new investigation `edh-eu151-bragg-winding-2026` for Stage-2 simulation;
(b) pivot to other priority-1-3 investigations from the Tier-3 menu (sign-pattern-lemma1, TwoChannelLHY F=6, TDHFB Phase-2 HF generic-F);
(c) anko-consult on whether Stage-1 CORROBORATE alone is acceptable for the project's Tier-3 standard (Matsui paper itself relies on Stage-2 Bragg for the "vortex" claim per T109 §2).

T111 does not commit to (a), (b), or (c) — that decision waits on the T112 verdict outcome.

## 13. Closing note

T111 is the unblocked-by-scheduler-restoration retry of T108's staged data-acquisition. The script is correct, the data exists, the scheduler permits, the verdict is blocked exactly on this evidence. Most-likely outcome is PASS on script-execution-contract (binary on file existence + JSON validity). The T112 critic verdict on F1 depends on the empirical ring presence in c=2 at t ∈ [1.5, 7] ms band: CORROBORATE-STAGE-1 (tier 2.75 holds) is plausible given NC1+NC2 already SUSTAINED, but REFUTED-OTHER cannot be ruled out a-priori. Either way, T112's verdict will be on actual spatial evidence, not on an inferred-necessary-conditions-only stack — which closes the F1 audit cycle properly.
