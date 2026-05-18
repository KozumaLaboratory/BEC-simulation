---
turn: 108
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: "Update (T107 critic INCONCLUSIVE on F1 by spatial-evidence data gap; the integrated populations + PNG + _live_status were insufficient — spatial structure lives in result.jld2 which requires Julia)"
stage_advancing_to: Update
topic_tags: [edh-eu151-matsui-science-2026, data-gap-closure, spatial-extraction, central-falsifier-F1, D1-axis, existing-artifacts-first, no-new-sim, drift-cost-inflation-addressed, drift-manuscript-delta-zero-addressed]
paper_section: null
depends_on:
  - 107
  - 106
  - 105
  - 104
  - 103
  - 86
  - 82
  - "runs/_loop/seed.md"
  - "runs/_loop/director/turn_107.md"
  - "runs/_loop/judge/turn_107_critic_audit.md"
  - "runs/_loop/state.json (lines 965-1012, 1636-1700)"
  - "runs/_loop/_local/scheduler_108.json"
  - "runs/eu151_edh_K3_long/result.jld2"
  - "runs/eu151_edh_K3_long/extract_trajectory.jl"
  - "runs/eu151_edh_K3_long/config.yaml"
  - "runs/eu151_edh_K3_long/trajectory.csv"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:feedback_manuscript_is_not_the_essence"
  - "memory:edh_matsui_baseline_2026_05_18"
produces: >
  T108 implementer_julia_cpu_light dispatch to close the T107 spatial-evidence
  data gap. Reads runs/eu151_edh_K3_long/result.jld2 (already on disk; no new
  simulation) and extracts azimuthally-averaged radial density profiles
  |psi_c(r)|^2(t) for c in {1,2,3,4,13} at all 501 saved frames. Computes
  per-frame ring metrics: r=0 vs off-axis-peak depth ratio, FWHM annulus
  aspect ratio, t_ring if either crosses Matsui criterion (depth > 20%,
  aspect > 1.5). Persists results to runs/eu151_edh_K3_long/spatial_profiles.csv
  + a ring_summary.json. The spatial CSV becomes the load-bearing FORM-B
  artifact for T109 critic re-evaluation of central falsifier F1 (which is
  is_central:true, tested_at_turn:null, gates Tier-3 promotion per §F8).
  No src/ edits. No new EdH simulation. No new YAML config. Pure
  analyze_existing-class work on existing on-disk artifact.
---

# Turn 108 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing from T107)**: `edh-eu151-vortex-vs-matsui-science-2026` (priority 0, flow_template `verify-claim`, kind `physics`, tier_current 2.5, tier_target 3). State.json lines 1636-1700: `current_stage: "Update (re-opened 2026-05-18; T76-T86 closure was tier-inflation on F3 alone; F1 ring formation NOT actually reproduced...)"`. T107 critic emitted `f1_central_falsifier_result: INCONCLUSIVE`, `tier_recommendation: 2.5` — F1 is still untested; tier holds at 2.5.

- **T107 critic root cause (load-bearing)**: per `runs/_loop/judge/turn_107_critic_audit.md` §6 (F1.d, F1.e, lines 89-100): "trajectory.csv contains no spatial information... azimuthally-averaged radial profile of |ψ_{c=c_flip}|² lives in result.jld2 → dynamics/psi_snapshots_streamed/frame_NNNNN as a 4-D ComplexF32 array (nx, ny, nz, nc) NOT extractable read-only without julia." The T107 critic explicitly recommended (§9 lines 121-122): **"T108 implementer_julia_cpu_light dispatch with directive 'extract azimuthally-averaged |ψ_c(r)|² radial profiles from runs/eu151_edh_K3_long/result.jld2 at frames near the cascade peak (t ∈ [3, 9] ms)... NO new simulation.'"**

- **Drift advisories at T107 (`director_must_address`)**: `DRIFT_MANUSCRIPT_DELTA_ZERO` (advisory only; T108 is D1 physics-completeness, NOT manuscript work — consistent with `feedback_manuscript_is_not_the_essence`), and `DRIFT_COST_INFLATION` (T107 effective cost ~2.13M slightly over rolling median; T108 must hold ≤ ~2.0M). Both advisories are **addressed by the structural choice of T108**: an analyze-existing julia-cpu-light run that reads a single file, runs a 13×501×32² azimuthal-average loop, writes one CSV + one JSON. No 2nd pass propagation. No new ground-state computation. Pre-existing JLD2 already on disk (cost-aware).

- **Why NOT continue with another critic at T108**: critic at T107 was already independent + thorough (11 refs cited, 3 errata, INCONCLUSIVE verdict honestly arrived at). The remaining gap is **operational** (need a julia process to read JLD2 + compute radial profiles), not cognitive (the criteria are well-defined; T107 spelled them out). Re-dispatching critic at T108 would produce the same INCONCLUSIVE verdict — the spatial data does not enter critic's tool surface (Read-only). T107 §9 routing prescribed implementer_julia_cpu_light; honor it.

- **Why NOT pivot to a new investigation**: F1 central falsifier is `is_central: true`, `tested_at_turn: null`, gates §F8 Tier-3 promotion. Pivoting away leaves the investigation stuck at tier 2.5 with a 100% deterministic next step (extract spatial profiles) sitting unmade. Per `feedback_use_existing_artifacts_first`: the result.jld2 IS the data; just read it.

- **Why NOT noop**: scheduler policy is JULIA_GPU_OK; allowed_workloads includes `implementer_julia_cpu_light` (line 19); window has 1,112,007 sec ≈ 18,533 min left; resource probe shows VRAM 12.8 GB free, RAM 25 GB avail, GPU 1% util, 0 foreign julia. This is a julia-cpu-light job (no GPU needed for JLD2 read + 4D array reduction on 32^3 × 13 × 501 ≈ 200 MB working set). Noop is unjustified — there is a clear physics-axis unblock with allowed workload class.

- **Why NOT researcher_deep on Matsui PDF**: T107 §5 noted critic lacks WebFetch; a follow-up Matsui re-extraction could be done by researcher_deep. But the dominant gap per T107 §6 (F1.d, F1.e) is **spatial structure of K3_long**, not τ_EdH^exp value (τ_EdH^exp=5 ms is well-anchored from T71 + memory). Spatial-extraction is the load-bearing move; Matsui PDF re-extraction is a parallel-low-priority. If T108 spatial-extraction finds a ring at t=5±2 ms, the τ_EdH^exp inheritance is good enough; if it finds no ring, the τ_EdH^exp value would not change the verdict. Defer researcher_deep on Matsui to T109+ if needed.

- **Other in-flight investigations**: 6 Tier-3 closed (barnett T29, klaus-bch T59, edh-matsui T86 contested per T107 E5, sign-pattern-lemma1 T94, tdhfb-phase2 T102) + 5+ Tier-2; 4 auto-spawned meta investigations queued (cost-waste, director-self-audit, cost-inflation, critic-placement) — interleave-only per §B2, not parallel-mandatory. T108 stays on the active edh-matsui investigation.

- **Scheduler** (`runs/_loop/_local/scheduler_108.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, `allowed_workloads` includes `implementer_julia_cpu_light` (line 19). Window 2026-05-15 → 2026-05-31. Probe: VRAM 12,839 MB free, RAM 24.94 GB avail, GPU 1%, foreign_julia 0. `implementer_julia_cpu_light` (JLD2 read + array reduce + CSV write) fits cleanly — ~2 GB RAM working set max, no GPU, ~3-5 min wall.

- **Subagent rotation**: last 6 turns critic(T101) → implementer_julia_cpu_light(T102) → researcher_shallow(T103) → critic(T104) → implementer_text(T105) → implementer_text(T106) → critic(T107). T108 implementer_julia_cpu_light breaks the (critic-after-critic-impl-impl-critic) streak; clean rotation. Implementer_text streak was 2 (T105-T106), not 3; implementer_julia_cpu_light at T108 is a different sub-class (julia vs text) and is the structurally correct workload for this work.

- **Cost frame**: T108 expected ~1.5-1.8M effective. Comparable to T100 (TDHFB Phase 2 Tier-3 julia-cpu-light recompute, ~1.6M) and T102 (TDHFB Phase 2 Document with julia recompute, ~1.7M). 2.0M soft cap to address DRIFT_COST_INFLATION. 3.0M hard cap. Wall time ~5 min (single JLD2 read; no propagation).

## 2. Recent-turn audit (last 6 turns)

| Turn | Investigation | Stage | Subagent | Verdict | What happened |
|---|---|---|---|---|---|
| T103 | audit-class-scan-T103 | Observe | researcher_shallow | RESEARCHER_ONLY | 10-pattern sweep; 0 actionable |
| T104 | audit-class-scan-T103 | Triage L3-half | critic | CRITIC_PASS, L3_FAIL_REJECT | First-ever §F6 L3 REJECT |
| T105 | audit-class-scan-T103 | Triage mech-half | implementer_text | PASS (23/23) | patterns.yaml + state.json bookkeeping |
| T106 | audit-class-scan-T103 | Document | implementer_text | PASS (43/43) | Memory entry + tier 1.5→2; terminal close |
| T107 | edh-eu151-matsui | Update | critic | CRITIC_INCONCLUSIVE | F1 INCONCLUSIVE by spatial-evidence data gap; tier holds 2.5 |
| **T108** | **edh-eu151-matsui** | **Update (continued; close T107 data gap)** | **implementer_julia_cpu_light** | **TBD** | **Extract azimuthally-averaged \|ψ_c(r)\|² radial profiles from result.jld2; compute ring metrics; write spatial_profiles.csv + ring_summary.json. No new simulation.** |

T108 = first julia-touching turn since T102. Closes the T107 critic's stated data gap. Continues the same investigation (no pivot) since F1 central falsifier still untested.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Stage**: stays at **Update** (re-opened branch). T107 critic was the first Update pass; T108 closes the operational data gap T107 surfaced. T109 will re-run the critic with the spatial CSV in hand, then advance to Document.
- **Verdict-routing per §B Verdict-To-Next-Stage Mapping**:
  - Last verdict was **INCONCLUSIVE** → "repeat current with refined approach". T108 repeats Update with the data gap closed (spatial profiles extracted). T108 is not a critic re-dispatch (critic can't read JLD2); it is the operational predecessor that lets T109's critic actually evaluate F1.
- **Role for Update with operational-prerequisite work**: when Update needs a data-extraction step before audit, the implementer pre-computes and the critic follows. This is analogous to T100→T101 (implementer_julia_cpu_light recompute → critic Route I audit) for tdhfb-phase2. Same pattern.
- **Artifact-first path**: still applies — `runs/eu151_edh_K3_long/result.jld2` exists; tier_current 2.5 < 3; T108 reads from it, does NOT launch a new simulation.

## 4. Research grounding (§A6)

T108 dispatch citations:

1. **`/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md`** — primary driver. §6 (F1.d, F1.e) identifies the spatial-evidence data gap; §9 prescribes T108 implementer_julia_cpu_light spatial extraction; §10 metrics block lists `spatial_ring_observed_via_artifact: null` (the field T108 must populate).
2. **`/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2`** — the on-disk artifact T108 reads. Per `extract_trajectory.jl` lines 20-31, JLD2 structure is: `dynamics/times`, `dynamics/norms`, `dynamics/Fz`, `dynamics/component_populations`, `dynamics/psi_snapshots_streamed/frame_NNNNN` (4D ComplexF32 (nx,ny,nz,nc)). T108's extraction script will mirror this access pattern.
3. **`/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_trajectory.jl`** — template for the new script. Reuse the JLD2 access pattern; replace peak-density-only computation with azimuthal-average + radial-profile computation.
4. **`/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml`** — grid params (32^3, box=20 a_ho → dr ≈ 0.625 a_ho ≈ 0.8 μm for ω=2π·110 Hz). Needed to interpret the radial coordinate.
5. **State.json F1 falsifier text (lines 1673-1677)**: criteria — "azimuthally-averaged |ψ_{c=c_flip}|² has local minimum at r=0 within ±20% depth + annulus aspect ratio >1.5. CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp]". τ_EdH^exp = 5 ms (T71 inherited). T108 must compute both metrics per (frame, component).
6. **T107 critic table §2 (lines 27-39)**: cascade peaks at t≈7 ms with 25% population transfer to m=+5/+4 (pop_c2~16%, pop_c3~12%); cascade reverses by t=14.5 ms. T108's frame-range focus: full sweep (all 501 frames) is cheap; do not pre-filter — let the data show t_ring if it exists.
7. **`memory/feedback_use_existing_artifacts_first.md`** — explicit anko rule. T108 reads the existing artifact; no new YAML, no new simulation.
8. **`memory/feedback_manuscript_is_not_the_essence.md`** — T108 is D1 physics-completeness verification on a central falsifier (anko's positive example axis); explicitly NOT manuscript polish. Addresses DRIFT_MANUSCRIPT_DELTA_ZERO advisory by being correctly-on-physics-axis.
9. **CLAUDE.md "Wavefunction" section** — `psi[x, y, ..., c]` shape; c=1 → m=F, c=13 → m=−F for Eu-151 D=13. T108 azimuthal average is over (x,y) plane around grid center; the trap is ω_x=ω_y=1, ω_z=1.182 (config.yaml line 32) so cylindrical axis = z.
10. **`memory/edh_matsui_baseline_2026_05_18.md`**: τ_EdH^exp = 5 ms anchor; F1 band [1.4, 14] ms (post-E2-erratum correction). T108 will materialize the t_ring values for direct comparison to this band.
11. **Scheduler JULIA_GPU_OK policy + `implementer_julia_cpu_light` in allowed_workloads** — the workload class is structurally allowed this window.
12. **§F8 Tier-3 promotion gate**: requires FORM-B check_cmd on raw artifact for central falsifier. T108 writes `spatial_profiles.csv` + `ring_summary.json`; T109 critic + check_cmd reads them. Two-step gate completion in the queue.

## 5. Calibrated progress check

- **D-axis advanced**: **D1 (verification of existing physics; Tier ladder 0→3)** for `edh-eu151-vortex-vs-matsui-science-2026`. The investigation's central F1 falsifier is one data-extraction away from being testable. T108 is the operational unblock; T109 critic is the cognitive close.

- **Tier ladder**: tier_current 2.5 stays at 2.5 at T108 (no central-falsifier verdict change; T108 is data-prep). Tier becomes 3.0 (or 2.0 if REFUTED) at T109/T110.

- **Drift advisories addressed**:
  - **DRIFT_MANUSCRIPT_DELTA_ZERO** — T108 is D1 physics verification on a central falsifier (NOT manuscript). Per `feedback_manuscript_is_not_the_essence`: explicit positive-axis match. Advisory is correctly-addressed-by-design.
  - **DRIFT_COST_INFLATION** — T107 was 2.13M effective (1.14× rolling median). T108 budget capped at 1.8M expected (single JLD2 read + array reduce; no propagation, no expensive matrix ops). Implementer_julia_cpu_light per `feedback_cost_overhead_is_the_cost`: hard caps in judge.py / quota_check.py are the only relevant guardrails, but T108 expected cost is structurally below the inflation level.

- **Drift trajectory anticipated for T108**:
  - `topic_repetition`: ~0.5 (edh-eu151-matsui at T107 + T108 = 2 of last 6; under threshold).
  - `subagent_repetition`: ~0.33 (different subagent classes in last 6).
  - `manuscript_delta_zero`: 1.0 (advisory only; T108 is correctly physics-axis).
  - `code_delta_zero`: 0.0 → ~0.2 (T108 creates a new analysis script at `runs/eu151_edh_K3_long/extract_ring_metrics.jl` — not src/ but is a new file; consistent with analyze-existing-class work).
  - `verdict_drift`: low.
  - `cost_inflation`: ~0.85-0.95 (back under median).
  - `novel_claim_zero`: low (T108 will materialize concrete ring-metric values per frame — those are novel quantitative claims).

- **Recommended T109-T112 trajectory**:
  1. **T109 (depends on T108 output)**:
     - If `ring_summary.json` shows `ring_present_any_frame: true` with `t_ring ∈ [2.5, 10] ms` and `depth_pct > 20` and `aspect > 1.5`: dispatch **critic** (Update repeat with spatial evidence) to re-evaluate F1 → CORROBORATE; T110 implementer_text Document tier 2.5→3.0.
     - If `ring_summary.json` shows `ring_present_any_frame: false` across all 501 frames: dispatch **critic** Update → REFUTED-CLEAN; T110 implementer_text Document tier 2.5→2.0; memory update + project Tier-3 count 6→5 (or "5+1 contested"→"5 fully").
     - If ambiguous (depth or aspect borderline; OR ring present only in m=+5 with aspect=1.4): dispatch **theorist** to refine the F1 detection criterion against Matsui's actual experimental signature in arXiv:2504.17357 (via WebFetch).
  2. **T111+ pivot options**: meta-cost-waste-audit (priority 15), meta-director-self-audit (priority 20), or close edh-matsui Document → next priority-0 candidate.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Update",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 1,
  "project_axis": "D1",
  "rationale": "T107 critic emitted F1 INCONCLUSIVE with explicit data-gap diagnosis (judge/turn_107_critic_audit.md §6 F1.d/F1.e + §9): the spatial ring criterion (azimuthally-averaged |psi_c(r)|^2 with depth >20% + aspect >1.5) cannot be evaluated from trajectory.csv (integrated populations only) or trajectory.png (no spatial panels); spatial structure lives in runs/eu151_edh_K3_long/result.jld2 dynamics/psi_snapshots_streamed/frame_NNNNN as a 4D ComplexF32 array. T108 = implementer_julia_cpu_light dispatch to extract azimuthally-averaged radial density profiles for c in {1,2,3,4,13} across all 501 saved frames; compute per-frame r=0 depth and FWHM annulus aspect; write spatial_profiles.csv + ring_summary.json. NO new simulation per anko's existing-artifacts-first rule (the JLD2 already encodes the data; we just need to read it). NO src/ edits. NO new YAML. Pure analyze_existing on existing on-disk artifact. Scheduler policy JULIA_GPU_OK (scheduler_108.json line 19 allowed_workloads includes implementer_julia_cpu_light); probe shows VRAM 12.8 GB free, RAM 25 GB avail, 0 foreign julia procs. Expected cost ~1.6-1.8M effective (single JLD2 read + array reduce; comparable to T100/T102). Drift advisories DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_COST_INFLATION at T107 director_must_address: T108 addresses both — physics-axis D1 (not manuscript) per feedback_manuscript_is_not_the_essence, and structurally cost-bounded (no propagation work). D1 axis: this is the structural unblock for §F8 Tier-3 promotion gate on F1 (is_central:true, tested_at_turn:null). T109 critic re-evaluation uses T108's CSV as load-bearing FORM-B evidence.",
  "brief": "## ROLE\n\nYou are the implementer for T108 §B-verify-claim Update stage (data-gap closure pass) of investigation `edh-eu151-vortex-vs-matsui-science-2026`. T107 critic emitted F1 INCONCLUSIVE because the spatial ring criterion lives in `result.jld2` (4D ComplexF32 psi snapshots) which requires Julia to read; trajectory.csv has integrated populations only, trajectory.png has no spatial panels. Your job: read `runs/eu151_edh_K3_long/result.jld2`, compute azimuthally-averaged radial density profiles |psi_c(r)|^2(t) for c in {1, 2, 3, 4, 13} at all 501 saved frames, derive per-frame ring metrics (r=0 depth relative to off-axis peak, FWHM annulus aspect ratio), find t_ring if any frame satisfies depth >20% AND aspect >1.5, and write results to two new files. NO new simulation. NO src/ edits. NO new YAML. NO GPU. This is julia-cpu-light analyze_existing work.\n\nDIRECTIVE_LABEL: edh-eu151-matsui-T108-update-implementer-spatial-ring-extraction-from-k3-long-jld2\n\n## REQUIRED READING (in order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/seed.md` lines 1-31 — the seed-mandated investigation; constraint 'no new EdH simulation this round'.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_108.md` (this report) — §6 contract + §4 grounding.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md` — full audit. The data-gap §6 F1.d/F1.e and routing §9 prescribe exactly this turn.\n4. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_trajectory.jl` (72 lines) — template for JLD2 access pattern: `jldopen(RESULT, 'r') do f; f['dynamics/times']; snap_grp = f['dynamics/psi_snapshots_streamed']; psi = snap_grp[@sprintf('frame_%05d', i)]`.\n5. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml` — grid (32^3, box=20 a_ho), omega aspect (1, 1, 1.182), N=10000. Cylindrical axis = z (trap ω_z slightly larger).\n6. State.json lines 1673-1677 — F1 criteria verbatim.\n7. CLAUDE.md sections 'Wavefunction' (psi[x,y,...,c] shape; c=1 → m=+F=+6, c=D=13 → m=−F=−6) and '¹⁵¹Eu' (F=6, D=13). Grid spacing dr = box / n = 20 / 32 = 0.625 a_ho.\n8. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_use_existing_artifacts_first.md` — read the JLD2; do not propose new sims.\n\n## YOUR TASK (julia-cpu-light, no GPU)\n\nWrite a new analysis script `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl` (modeled on `extract_trajectory.jl`; ~120-180 LOC). The script must:\n\n### (a) Open `result.jld2`, read time series + all psi snapshots\n\n```julia\nusing SpinorBEC, JLD2, CodecZstd, Printf, Statistics\nconst RUN_DIR = @__DIR__\nconst RESULT = joinpath(RUN_DIR, \"result.jld2\")\nconst CSV_OUT = joinpath(RUN_DIR, \"spatial_profiles.csv\")\nconst JSON_OUT = joinpath(RUN_DIR, \"ring_summary.json\")\n```\n\nFor each saved frame i (1..n_frames), read `psi = snap_grp[@sprintf(\"frame_%05d\", i)]` as a (nx, ny, nz, nc) ComplexF32 array, then for each c in CHANNELS = (1, 2, 3, 4, 13):\n\n### (b) Compute azimuthally-averaged radial density profile\n\nGrid centering: trap is harmonic centered at the box center. In SpinorBEC's grid convention, grid points are `x = ((1:nx) .- (nx+1)/2) * dx` (or check Grid struct in src/foundation/types/grid.jl if uncertain). For nx=32, the center is between indices 16 and 17. Use the half-integer center for radial coordinate r = sqrt((x_i - x_c)^2 + (y_j - y_c)^2).\n\nIntegrate over z (the cylindrical axis): `n_2d[i, j] = sum(abs2.(psi[i, j, :, c])) * dz` for component c. Result is a 2D radial density.\n\nAzimuthal-average bin: define `n_radial_bins = 16` (half of nx=32 grid; resolution ~ dr = 0.625 a_ho per bin). For each (i, j) compute r_ij, find bin = floor(Int, r_ij / dr) + 1, clamp 1..16. Accumulate `radial_profile[c, frame, bin] = sum_{i,j in bin} n_2d[i, j] / count_in_bin`.\n\n### (c) Compute per-frame ring metrics\n\nFor each (c, frame):\n- `n0 = radial_profile[c, frame, 1]` (r=0 bin density).\n- `n_max_off_axis, k_max = findmax(radial_profile[c, frame, 2:end])` (peak away from r=0). Adjust index back: k_max += 1.\n- `depth_pct = (n_max_off_axis - n0) / n_max_off_axis * 100` if n_max_off_axis > 0, else 0.\n- FWHM annulus aspect: find r_inner (smallest r > 0 where radial_profile >= 0.5 n_max_off_axis) and r_outer (largest r where same). aspect = r_outer / r_inner (NaN-safe; default 1.0 if r_inner = 0 or undefined).\n- `ring_present = (depth_pct > 20.0) && (aspect > 1.5)`.\n\n### (d) Write CSV (`spatial_profiles.csv`)\n\nColumns: `frame, t_dimless, t_ms, c, m, depth_pct, aspect, ring_present, n0, n_max_off_axis, r_inner, r_outer`. One row per (frame, c). With 501 frames × 5 components = 2,505 rows.\n\nUse `t_ms = t_dimless * (1000 / 691.15) * 2*pi` if ω_ref = 691.15 rad/s? Actually: `t_dimless` is in units of ω_ref^(-1); ω_ref = 691.15 rad/s = 2π·110 Hz; T_ref = 1/ω_ref ≈ 1.447 ms. So `t_ms = t_dimless * 1000 / 691.15`. Double-check: at t_dimless = 10, t_ms should be ≈ 14.5 ms (consistent with config.yaml comment line 58 'Phase 2: weak-field hold... 10 ω⁻¹ ≈ 14.5 ms'). 10 / 691.15 * 1000 = 14.47 ms. PASS.\n\nWrite `m = 7 - c` (so c=1 → m=+6, c=2 → m=+5, ..., c=13 → m=-6).\n\n### (e) Write JSON summary (`ring_summary.json`)\n\nKeys:\n- `n_frames_total`: 501\n- `n_components_audited`: 5 (c in {1,2,3,4,13})\n- `tau_edh_exp_ms`: 5.0 (inherited from T71 / memory edh_matsui_baseline_2026_05_18.md)\n- `f1_band_corroborate_ms`: [2.5, 10.0] (= [0.5, 2.0] × τ_EdH^exp)\n- `f1_band_inconclusive_ms`: [1.0, 25.0] (= [0.2, 5.0] × τ_EdH^exp)\n- `f1_band_refute_threshold_ms`: 50.0 (= 10 × τ_EdH^exp; experiment ends at 14.5 ms anyway so REFUTED is bounded by simulation duration not band)\n- `ring_present_any_frame_any_c`: bool — true if any (frame, c) row has ring_present=true\n- `t_ring_first_ms`: float or null — t_ms of earliest frame with ring_present=true (across any c in {1,2,3,4,13})\n- `c_ring_first`: int or null — which component first satisfies the ring criterion\n- `m_ring_first`: int or null — corresponding magnetic quantum number\n- `t_ring_first_in_corroborate_band`: bool (or null)\n- `t_ring_first_in_inconclusive_band`: bool (or null)\n- `max_depth_pct_observed`: float (peak across all frames/components)\n- `max_aspect_observed`: float\n- `arg_max_depth_pct`: {frame, t_ms, c, m} dict\n- `arg_max_aspect`: {frame, t_ms, c, m} dict\n- `metadata`: {script_version: 1, jld2_path: \"runs/eu151_edh_K3_long/result.jld2\", n_radial_bins: 16, dr_a_ho: 0.625}\n\n### (f) Execute the script\n\n```bash\ncd /home/suzume/workspace/BEC-simulation\njulia --project=. runs/eu151_edh_K3_long/extract_ring_metrics.jl\n```\n\nExpected runtime ~2-5 min CPU (501 frames × 32^3 × 13 components ≈ 200 MB working set; pure array reduction).\n\nIf the run takes >10 min, abort and switch to a single-component scan (just c=2, the dominant cascade product) to first prove the pattern, then expand.\n\n### (g) Acceptance preconditions before launching julia\n\nRun these bash gates first (output to stdout; if any fails, STOP and report):\n\n```bash\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2 && echo OK_JLD2_EXISTS\ntest -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_trajectory.jl && echo OK_TEMPLATE_EXISTS\nls -la /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2 | awk '{print \"jld2_size_bytes=\"$5}'\n```\n\nExpect: 3 OK lines + a non-trivial jld2_size_bytes (>= 100 MB likely; the file holds 501 frames × 32^3 × 13 complex-32 ≈ 270 MB raw, plus compression).\n\n### (h) Output discipline\n\nAlso write `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_108.md` with the standard sim-narrative structure (§1 contract recap, §2 preflight, §3 script outline, §4 metrics block, §5 next routing) per implementer.md §C-Output. The metrics block in §4 is the FORM-A input for judge.py.\n\n## SUCCESS CRITERIA (FORM-B preferred; raw-artifact check_cmds against the new CSV + JSON)\n\nThe critical checks are: (1) the script ran and wrote both files; (2) the CSV has the expected row count and columns; (3) the JSON has the expected schema and a deterministic ring_present_any_frame_any_c verdict.\n\nSee §6 success_criteria array for FORM-B check_cmds.\n\n## CONSTRAINTS\n\n- **Files allowed to create**:\n  - `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl` (new analysis script; ~120-180 LOC)\n  - `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv` (script output)\n  - `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json` (script output)\n  - `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_108.md` (turn-narrative)\n- **Files FORBIDDEN to modify**:\n  - `src/` (any file under it)\n  - `runs/_loop/state.json` (orchestrator-managed)\n  - `runs/_loop/patterns.yaml`\n  - `runs/eu151_edh_K3_long/config.yaml`, `.../result.jld2`, `.../trajectory.csv`, `.../_live_status.json`, `.../trajectory.png`, `.../extract_trajectory.jl` (existing artifacts; read-only)\n  - `.claude/agents/*`, `.claude/scripts/*`\n  - `docs/manuscript/*`, any manuscript directory\n- **No new YAML config**. No new ground_state or dynamics pipeline step. NO new simulation. NO GPU. NO `Pkg.test()`. NO `Pkg.instantiate()` (deps already installed for this project).\n- **No emojis. English only. No improvised metaphor terminology. No anko-attribution in code comments.**\n- **Absolute paths** for all file I/O.\n- **Cost budget**: stay ≤ ~1.8M effective (DRIFT_COST_INFLATION advisory; per `feedback_cost_overhead_is_the_cost` the cap is the only relevant guardrail). 3.0M hard cap.\n- **Wall-time budget**: julia execution ≤ 10 min (single-frame loop, 501 iterations). If runtime exceeds 10 min on a CPU read, abort + downscope per (f).\n- **No fabrication**: every metric value in `ring_summary.json` MUST be computed by the script from `result.jld2`. Do not hand-place values. The JSON is the FORM-B artifact T109 critic will check.\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify `extract_trajectory.jl` to add ring extraction. Write a separate `extract_ring_metrics.jl` so the original CSV-extract is reproducible.\n- Do NOT propose a new simulation. The JLD2 has all 501 frames already. If a frame turns out to be unreadable, log it as a data point in the JSON (n_frames_unreadable field) and continue.\n- Do NOT classify ring_present=true on weak evidence. The criterion is depth_pct > 20.0 AND aspect > 1.5 — strict AND.\n- Do NOT inflate the verdict. The script's job is to produce the metric values honestly. T109 critic decides CORROBORATE / INCONCLUSIVE / REFUTED.\n- Do NOT pin the radial-binning resolution at less than n_radial_bins=16. Coarser binning hides ring structure.\n- Do NOT skip c=13 (m=−6). It is the literal 'c_flip' for unit-vector flip from m=+F. Even if pop_c13 is tiny (~1e-10), the ratio of (off-axis n) / (n at r=0) within that channel could still be informative (a torus in m=−6 with very low total amplitude is still a torus and could indicate the EdH-spin-to-orbit transfer signature).\n- Do NOT compute the radial profile using GPU. CPU is sufficient; GPU would burn the implementer_julia_cpu_light budget toward heavy.\n- Do NOT print full radial profile arrays to stdout. Only summary statistics + the final 'wrote SPATIAL_PROFILES.csv ($N_rows rows), wrote RING_SUMMARY.json' log line.\n\n## REPORTING DISCIPLINE\n\n- If `result.jld2` cannot be opened (e.g. corrupted, missing key `dynamics/psi_snapshots_streamed`), STOP and report the exception. Do NOT improvise.\n- If a single frame fails to read (HDF5 IO error), log frame_NNNNN_failed, populate row with NaN ring metrics, continue to next frame.\n- If `n_frames_unreadable / n_frames_total > 0.1`, abort the run and report (suggests a corrupted JLD2; routes to T109 implementer re-extract with diagnostics).\n- If the JSON shows `ring_present_any_frame_any_c: true`, this is a candidate for CORROBORATE at T109; if `false`, candidate REFUTED. T108's job is to produce honest data, not pre-decide the F1 verdict.\n- Write a one-paragraph 'What I found' summary in §5 of `sim/turn_108.md` with: t_ring_first_ms (or 'no ring'), max_depth_pct_observed, max_aspect_observed, and which (c, frame) those came from. This is the load-bearing handoff to T109.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "extract_script_created",
      "spatial_profiles_csv_created",
      "ring_summary_json_created",
      "n_frames_processed",
      "n_frames_unreadable",
      "n_components_audited",
      "ring_present_any_frame_any_c",
      "t_ring_first_ms",
      "c_ring_first",
      "m_ring_first",
      "max_depth_pct_observed",
      "max_aspect_observed",
      "tau_edh_exp_ms",
      "f1_band_corroborate_ms_low",
      "f1_band_corroborate_ms_high",
      "t_ring_first_in_corroborate_band",
      "t_ring_first_in_inconclusive_band",
      "src_edited",
      "new_simulations_proposed",
      "new_yaml_created",
      "manuscript_edited",
      "gpu_used",
      "wall_time_julia_sec"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2 && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_trajectory.jl && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml && python3 -c \"import os; sz=os.path.getsize('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2'); assert sz > 50_000_000, f'jld2 unexpectedly small: {sz} bytes (expected > 50 MB)'; print(f'OK precondition jld2_size_mb={sz/1e6:.1f}')\""
  },
  "success_criteria": [
    {
      "id": "extract-script-written",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl && wc -l /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl | awk '{print ($1>=80 && $1<=300) ? \"SCRIPT_LOC_OK \"$1 : \"SCRIPT_LOC_BAD \"$1}'",
      "expect": {"exit_code": 0, "stdout_contains": "SCRIPT_LOC_OK"}
    },
    {
      "id": "spatial-profiles-csv-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv && python3 -c \"import csv; rows=list(csv.DictReader(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/spatial_profiles.csv'))); n=len(rows); cols=set(rows[0].keys()) if rows else set(); needed={'frame','t_dimless','t_ms','c','m','depth_pct','aspect','ring_present'}; ok = (n >= 1000 and needed.issubset(cols)); print(f'CSV_ROWS={n} CSV_COLS_OK={needed.issubset(cols)} ' + ('CSV_OK' if ok else 'CSV_BAD'))\"",
      "expect": {"exit_code": 0, "stdout_contains": "CSV_OK"}
    },
    {
      "id": "ring-summary-json-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json && python3 -c \"import json; d=json.load(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json')); needed={'n_frames_total','ring_present_any_frame_any_c','max_depth_pct_observed','max_aspect_observed','tau_edh_exp_ms','f1_band_corroborate_ms'}; ok = needed.issubset(set(d.keys())); print('JSON_SCHEMA_OK' if ok else 'JSON_SCHEMA_BAD missing=' + str(needed - set(d.keys())))\"",
      "expect": {"exit_code": 0, "stdout_contains": "JSON_SCHEMA_OK"}
    },
    {
      "id": "ring-summary-has-deterministic-verdict",
      "check_cmd": "python3 -c \"import json; d=json.load(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/ring_summary.json')); v=d.get('ring_present_any_frame_any_c'); print('VERDICT_DETERMINISTIC' if v in (True, False) else 'VERDICT_AMBIGUOUS')\"",
      "expect": {"exit_code": 0, "stdout_contains": "VERDICT_DETERMINISTIC"}
    },
    {
      "id": "n-frames-bound",
      "metric": "n_frames_processed",
      "operator": ">=",
      "value": 450
    },
    {
      "id": "n-frames-unreadable-bound",
      "metric": "n_frames_unreadable",
      "operator": "<=",
      "value": 50
    },
    {
      "id": "n-components-audited-eq-5",
      "metric": "n_components_audited",
      "operator": "==",
      "value": 5
    },
    {
      "id": "no-src-edited",
      "metric": "src_edited",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-new-simulation",
      "metric": "new_simulations_proposed",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-new-yaml",
      "metric": "new_yaml_created",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-manuscript-edit",
      "metric": "manuscript_edited",
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
      "id": "wall-time-bound",
      "metric": "wall_time_julia_sec",
      "operator": "<=",
      "value": 900
    }
  ],
  "failure_modes": [
    {
      "if": "extract-script-written failed (script missing or LOC outside [80, 300])",
      "category": "operational",
      "next_action": "re-dispatch implementer at T109 with explicit LOC bound + script-scaffolding template; tier holds 2.5"
    },
    {
      "if": "spatial-profiles-csv-exists failed (CSV missing, < 1000 rows, or missing required columns)",
      "category": "operational",
      "next_action": "diagnose JLD2 read failure or array-reduction bug; re-dispatch implementer with diagnostic mode (single-frame test)"
    },
    {
      "if": "ring-summary-json-exists failed (JSON missing or schema incomplete)",
      "category": "operational",
      "next_action": "re-dispatch implementer to patch JSON-emit step; tier holds 2.5"
    },
    {
      "if": "n-frames-unreadable-bound failed (>10% frames unreadable)",
      "category": "data_gap",
      "next_action": "investigate JLD2 corruption — possibly K3_long needs re-run; route to anko consult before any re-run authorization"
    },
    {
      "if": "ring-summary-has-deterministic-verdict passed AND ring_present_any_frame_any_c==true AND t_ring_first_ms in [2.5, 10.0]",
      "category": "scientific_corroborate_candidate",
      "next_action": "T109 critic Update re-evaluation of F1 with spatial_profiles.csv + ring_summary.json as FORM-B evidence → expected CORROBORATE → T110 implementer_text Document tier 2.5 → 3.0"
    },
    {
      "if": "ring-summary-has-deterministic-verdict passed AND ring_present_any_frame_any_c==true AND t_ring_first_ms in [1.0, 2.5] OR [10.0, 25.0]",
      "category": "scientific_inconclusive_band_edge",
      "next_action": "T109 critic Update INCONCLUSIVE band-edge; theorist refinement at T110 against Matsui-paper ring criterion (WebFetch researcher_deep if needed)"
    },
    {
      "if": "ring-summary-has-deterministic-verdict passed AND ring_present_any_frame_any_c==false",
      "category": "scientific_refuted_candidate",
      "next_action": "T109 critic Update REFUTED-CLEAN candidate; theorist sanity check (is the K3_long N=10k vs Matsui N=30k mismatch the cause? per T107 §3 the N-factor-3 difference matters); then T110 implementer_text Document tier 2.5 → 2.0 OR theorist branches to Matsui-N=30k follow-up consult with anko (no auto-run)"
    },
    {
      "if": "wall-time-bound failed (julia ran > 15 min)",
      "category": "operational_resource",
      "next_action": "downscope to single-component (c=2) scan + reduce n_radial_bins; re-dispatch with tighter scope"
    },
    {
      "if": "no-gpu-used failed (implementer used GPU)",
      "category": "framework_error",
      "next_action": "reject the work product; re-dispatch with hardened CPU-only guard; this is cost-budget over-spend per DRIFT_COST_INFLATION advisory"
    }
  ],
  "budget": {
    "expected_cost_eff": 1700000,
    "expected_wall_time_sec": 600
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Update (T109 critic re-eval with spatial evidence)",
    "if_success_tier_becomes": 2.5,
    "if_partial_advance_to_stage": "Update (T109 implementer re-extract with diagnostic mode)",
    "if_partial_tier_becomes": 2.5,
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 2.5,
    "if_success_falsifier_update": {
      "id": "F1-ring-appears-correct-timescale",
      "tested_at_turn": null,
      "result_template": "T108 spatial-extraction operational pass — data prepared for T109 critic central-falsifier re-evaluation. Per ring_summary.json: ring_present_any_frame_any_c=<value>, t_ring_first_ms=<value or null>, max_depth_pct_observed=<value>, max_aspect_observed=<value>. F1 verdict deferred to T109 critic."
    },
    "post_t108_pivot_options_by_outcome": [
      "T109 critic Update CORROBORATE candidate (if ring_present_any_frame_any_c=true + t_ring in [2.5, 10] ms)",
      "T109 critic Update INCONCLUSIVE-band-edge (if ring_present but t_ring on band edge)",
      "T109 critic Update REFUTED-CLEAN candidate (if ring_present_any_frame_any_c=false)",
      "T109 theorist branch to Matsui-N=30k re-run consult with anko (no auto-run) if N-factor-3 is the suspected cause of REFUTED"
    ]
  }
}
```

## 7. Drift advisories — explicit acknowledgement

Per scheduler.json + T107 history (drift_escalation: `director_must_address`):

- **DRIFT_MANUSCRIPT_DELTA_ZERO**: T108 advances D1 physics-completeness on a central falsifier of a Tier-3 candidate investigation. NOT manuscript work. Per `memory/feedback_manuscript_is_not_the_essence.md`: "Physics correctness, verification, unimplemented effects... ARE [the essence]". Advisory addressed by-design.

- **DRIFT_COST_INFLATION**: T107 was 2.13M effective (1.14× rolling median). T108 budget is 1.7M expected (single JLD2 read + array reduce + CSV/JSON write; no propagation, no expensive Bogoliubov solve, no julia_cpu_heavy classification). Per `feedback_cost_overhead_is_the_cost`: hard caps are the only relevant guardrails; T108 is structurally below the inflation level by design (no expensive ops in the script). The work-class itself (analyze_existing) is the cheapest julia class.

Both advisories accepted (acknowledged + addressed by structural choice). Drift escalation expected to drop to `advisory` after T108 by virtue of no further repetition of the cost-inflation pattern.

## 8. Anti-noop justification

T108 is NOT noop because:
- Scheduler policy JULIA_GPU_OK explicitly permits `implementer_julia_cpu_light` (scheduler_108.json line 19).
- Probe shows healthy headroom (12.8 GB VRAM, 25 GB RAM, 0 foreign julia).
- The work is bounded (single JLD2 file, ~270 MB compressed, 501 frames, 5 components × 32^2 azimuthal averages = 5120 reductions total).
- The output directly unblocks a §F8 Tier-3 promotion gate (F1 central falsifier currently `tested_at_turn: null`).
- Per `feedback_use_existing_artifacts_first`: the JLD2 is the data anko already paid for. Reading it is the canonical existing-artifacts-first move.

If for some unforeseen reason the precondition_check fails (jld2 < 50 MB or extract_trajectory.jl missing), the implementer must abort and report — at which point T109 would be noop or a researcher_shallow into "where did result.jld2 go" — but the Glob this turn confirmed all 9 expected files in `runs/eu151_edh_K3_long/` are present (config.yaml, _live_status.json, result.jld2, point_001.jld2, extract_trajectory.jl, trajectory.csv, plot_trajectory.py, trajectory.pdf, trajectory.png, trajectory.svg).

## 9. Why this is not "implementer-after-implementer" overshoot

Past 6 turns subagent classes: critic (T101), impl_julia_cpu_light (T102), researcher_shallow (T103), critic (T104), impl_text (T105), impl_text (T106), critic (T107). T108 = impl_julia_cpu_light — same class as T102 (6 turns ago), different class from immediate predecessors (critic T107, impl_text T105/T106). No "implementer 3-in-a-row" violation; the seed.md stop-condition "no more than 2 same-subagent in a row" is not at risk (impl_text T105/T106 = 2; then critic T107; T108 impl_julia is a different sub-class anyway).
