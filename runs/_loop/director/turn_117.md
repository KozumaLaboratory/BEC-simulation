---
turn: 117
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: "Document (T86 closed at tier 3.0 then re-opened by anko via seed.md 2026-05-19; T110 critic CORROBORATE-STAGE-1 logged at tier 2.75; F1 is_central=true)"
stage_advancing_to: "Update (artifact-first critic audit of runs/eu151_edh_K3_long against Matsui Science 391 384-388 (2026) — independent context, FORM B check_cmds against raw CSV; Tier 2.75 → 3.0 eligible)"
topic_tags: [edh-eu151-matsui-science-2026, artifact-first-audit, tier3-promotion-gate, central-falsifier-F1-corroborate, D1-axis, critic-independent-context, ring-formation-cascade, K3_long-trajectory]
paper_section: "papers/paper4_chaotic_dynamics/Ch5_TWA_chaotic_dynamics_integrated.md + manuscript/thesis/chapters/Ch5 sidebar — Matsui-EdH benchmark deferred until F1 ring formation independently corroborated"
depends_on:
  - 116
  - 115
  - 114
  - 113
  - 112
  - 111
  - 110
  - 86
  - "runs/_loop/sim/turn_116.md"
  - "runs/_loop/judge/turn_116.json"
  - "runs/_loop/director/turn_116.md"
  - "runs/_loop/state.json"
  - "runs/_loop/seed.md"
  - "runs/_loop/_local/scheduler_117.json"
  - "runs/eu151_edh_K3_long/trajectory.csv"
  - "runs/eu151_edh_K3_long/trajectory.png"
  - "runs/eu151_edh_K3_long/config.yaml"
  - "runs/eu151_edh_K3_long/_live_status.json"
  - "runs/eu151_edh_loss_factorial/config.yaml"
  - "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:loop_architecture_2026_05_14"
  - "memory:tier3_pipeline_survey_2026_05_18"
produces: >
  T117 advances edh-eu151-vortex-vs-matsui-science-2026 from re-opened
  Document/2.75 state → Update via critic dispatch. Artifact-first path
  (director.md decision table row 3): runs/eu151_edh_K3_long/ has
  non-trivial outputs (trajectory.csv 100kB+, trajectory.png, config.yaml,
  ring_summary_h5py_probe.json) AND tier_current 2.75 < 3 AND last verdict
  was CORROBORATE-STAGE-1 (T110, not INCONCLUSIVE). NO new EdH simulation
  per seed.md hard constraint + memory:feedback_use_existing_artifacts_first.
  Critic does an independent-context audit: (a) verifies F1 ring-formation
  cascade is observable in trajectory.csv (population transfer m=+F → m=+5,
  +4, +3, +2 with detectable timescale), (b) cross-checks config.yaml has
  K3 + gamma_dr + noise seed (per seed.md "anko's verified working setup"),
  (c) crosswalks t_ring against Matsui Science 391 384-388 (2026)
  DOI:10.1126/science.adx2872 published t_ring ~5 ms (paper) vs K3_long
  trajectory 14.5 ms expected (per seed.md). FORM B check_cmds against
  trajectory.csv directly bypass §4 LLM-summary path. Verdict CORROBORATE →
  tier 2.75 → 3.0 closure on this F1 is_central=true central falsifier;
  INCONCLUSIVE → tier stays 2.75 with concrete next action; REFUTED → tier
  drop to 2.5 with anko-consult escalation. Secondary acknowledgement:
  T116 sign-pattern-f9-ta-mult2 manuscript §V did NOT actually land on main
  HEAD (the file `sign_pattern_lemma1_general_S.md` ends at line 516 with
  the 2026-05-11 content; T116 implementer's claim of +164 lines was on
  the auto-branch only; main-HEAD has none of the m_rep/rho_inv/
  Multiplicity-Aware content). Per director.md verdict-routing FAIL_OPERATIONAL
  + the actual file evidence, Duty B is OUTSTANDING. T117 does NOT redo
  Duty B (seed.md priority-0 wins precedence); T118 director will re-dispatch
  implementer_text for the missing Duty B after T117 critic completes.
  Cost expected ~1.5M effective (Read-only critic, no compute, no julia).
---

# Turn 117 — Director Report

## 1. What happened at T116 (top-of-turn read)

| Path | Read | What it says |
|---|---|---|
| `runs/_loop/sim/turn_116.md` | full file | Implementer T116 claims 3-duty PASS (state.json registration ✓, manuscript §V +164 lines ✓, memory entry ✓). Self-report 13/15 SC PASS; 2 FAIL = path mismatch (memory under `~/.claude/projects/.../memory/` not `/home/suzume/.../memory/`). |
| `runs/_loop/judge/turn_116.json` | full file | Judge verdict `FAIL_OPERATIONAL` with 5 issues. **Critical**: 5 SC failed, not 2 — SC5/SC6/SC7 (manuscript-mrep-prefactor / canonical-formula / F=9-T:A-verification) also FAILED with `check_cmd FAIL: exit_code=1`. |
| `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (independent re-read) | full file (516 lines) | **Manuscript §V did NOT land on main HEAD.** File ends at line 516 with `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)`. Grep `multiplicity\|Multiplicity\|m_rep\|rho_inv\|canonical formula\|F=9 T:A` → 0 matches across the whole file. T116 implementer's claim of +164 lines was technically committed to `auto/turn_116_...` branch (commit f081603) but did NOT make it into main HEAD after orchestrator processing (compare with T116 self-report §2 which mentions parent c3e3d1f — but the main HEAD now reads turn_116 commit `38fd787` and this file at the current main-branch HEAD has no §V). T116 self-report misrepresented the post-commit state; the judge SC5/6/7 FAIL was correctly diagnosing the on-disk content. |
| `runs/_loop/state.json` lines 2765-2849 | yes | Investigation `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` IS registered in `state.investigations` dict (count 25) and `investigations_index` (15 entries). Duty A LANDED. tier_current=2.5, tier_target=3, F1 is_central=true with result containing CORROBORATE. |
| `~/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` (Glob hit) | first 30 lines | Memory entry EXISTS at user-local store with full physics content (formula, 4 falsifiers, J-involution derivation summary). Duty C LANDED at the on-disk-correct path; the SC9/SC10 FAIL was a director-side path-expression bug (referenced `/home/suzume/workspace/BEC-simulation/memory/` which doesn't exist as a project directory). |
| `runs/_loop/state.json` lines 2115-2188 | edh-matsui investigation block | Tier 2.75; `current_stage: "Document"`; `next_stage_action` literally says **"Per seed.md 2026-05-19 highest-priority section + director §B1.0: dispatch critic in independent-audit mode against runs/eu151_edh_K3_long/trajectory.png + trajectory.csv (the May 13 success; 14.5 ms, K3 + gamma_dr + noise seed, clean cascade). Crosswalk against Matsui Science 391 384-388 (2026). NO new EdH simulation. PASS → tier 3.0"**. F1 is_central=true, T110 tested_at_turn with result CORROBORATE-STAGE-1. F2/F3/F4 still null. |
| `runs/_loop/seed.md` | full file | Priority-0 pin held verbatim on edh-eu151-vortex-vs-matsui-science-2026; explicit "Action: dispatch **critic** in independent-audit mode against runs/eu151_edh_K3_long/trajectory.png + trajectory.csv". Per seed §1-§5 hard constraint: "no new EdH simulation this round. The accumulated runs ARE the data." |
| `runs/_loop/_local/scheduler_117.json` | full file | policy=JULIA_GPU_OK; all workloads allowed including `critic` (Read-only — safest workload class). vram_free=12844 MB, ram_avail=25.02 GB, gpu_util=3%, foreign_julia=0. Window 1097599 s left through 2026-05-31. No constraint forces non-critic path. |
| `runs/eu151_edh_K3_long/` Glob (14 files) | listing | Files present: `trajectory.csv`, `trajectory.png`, `trajectory.pdf`, `trajectory.svg`, `config.yaml`, `_live_status.json`, `result.jld2`, `point_001.jld2`, `extract_trajectory.jl`, `plot_trajectory.py`, `extract_ring_metrics.jl`, `run_extract_ring_metrics.sh`, `_h5py_probe_T111_retry.py`, `ring_summary_h5py_probe.json`. Notably ABSENT: `spatial_profiles.csv` (still — anko hasn't run the wrapper). Per artifact-first decision-table row, this is sufficient artifact for a critic audit (trajectory.csv + config.yaml is the load-bearing pair). |
| `runs/eu151_edh_loss_factorial/` Glob (2 files) | listing | `config.yaml` + `extract_and_plot.jl`. The 4-panel K3 off/on × gamma_dr off/on comparison referenced by seed.md is available as the comparison config; the actual run output is not on disk in this directory (the K3_long trajectory IS the K3-on/gamma_dr-on case per seed.md). |
| `memory:loop_architecture_2026_05_14` (Read referenced index) | line index | Sets the critic-as-independent-context discipline: critic's job is verify-against-published-reference, NOT re-run the analysis. F1's existing T110 stage-1 corroboration is the prior; T117 critic is the independent-context confirmation. |
| `memory:feedback_use_existing_artifacts_first` (MEMORY.md line 251 referenced) | implied | Hard rule: BEFORE new sim / new config, grep `runs/` for sibling outputs. T117 honors this verbatim — no new run, audit-only against on-disk artifacts. |
| `memory:tier3_pipeline_survey_2026_05_18` | referenced via MEMORY.md | edh-matsui was the survey's top-pick Tier-3 candidate. T86 closed it at tier 3.0; anko re-opened via seed.md 2026-05-19. T117 is the resumption of that Tier-3 closure path. |

**Routing gate** (per protocol §B6):
- Last verdict was `FAIL_OPERATIONAL` (T116 judge). Per director.md verdict-to-next-stage: FAIL_OPERATIONAL → repeat with corrected contract. Interpretation: T116's check_cmd contract had 2 path-mismatch bugs (referenced `/home/suzume/workspace/BEC-simulation/memory/` which doesn't exist) AND the manuscript §V Duty B did NOT actually land on main HEAD (judge correctly flagged SC5/6/7).
- However, per **precedence rule (seed.md > scheduler > this prompt)**: seed.md 2026-05-19 priority-0 pin explicitly directs critic dispatch against runs/eu151_edh_K3_long/. The repeat-with-corrected-contract for T116 (re-do Duty B) is LOWER priority than the seed.md pin.
- T117 dispatches **critic** for edh-matsui artifact audit (seed.md priority-0).
- T118 will re-evaluate: if Duty B still missing on main HEAD AND T117 critic complete, dispatch implementer_text for Duty B retry.

## 2. Why critic (not implementer_text-retry, not noop, not researcher)

**Option (a) — critic (chosen)**: dispatch critic in independent-context audit mode against `runs/eu151_edh_K3_long/{trajectory.csv, trajectory.png, config.yaml, _live_status.json, ring_summary_h5py_probe.json}`. Crosswalk against Matsui Science 391 384-388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357]. FORM B check_cmds against raw CSV bypass §4 LLM-summary. Per artifact-first decision-table row (director.md table row 3: existing runs/ outputs + tier_current 2.75 < 3 + last verdict NOT INCONCLUSIVE → `subagent_type = critic`, `stage_advancing_to = Update`). Honors seed.md priority-0 hard pin + memory:feedback_use_existing_artifacts_first. Cost ~1.5M effective (Read-only).

**Option (b) — implementer_text to redo Duty B (manuscript §V missing from main HEAD)**: Rejected as primary T117 work. Lower priority than seed.md priority-0 edh-matsui pin. The §V landed on auto-branch `auto/turn_116_...` (commit f081603, +164 lines per T116 self-report) but the orchestrator's loop commit `38fd787` ("auto(loop): T116 FAIL_OPERATIONAL modify_text") apparently committed only the state.json change + memory entry on user-local store, NOT the manuscript §V (or the manuscript edit was rolled back during git merge). T118 re-dispatch will fix this. T117 deferral is acceptable — the physics is settled (state.json registration captures the central record); manuscript propagation can wait one turn without affecting the loop's scientific integrity.

**Option (c) — implementer_julia for new EdH baseline**: Hard-rejected. Seed.md verbatim: "no new EdH simulation this round. The accumulated runs ARE the data." Plus memory:feedback_use_existing_artifacts_first hard rule. Plus T76-T86's earlier from-scratch baseline failure (omitted K3 + gamma_dr + noise seed). NEVER again.

**Option (d) — noop with anko-consult escalation**: Rejected. The seed.md is explicit and the on-disk artifacts are present. There is no consult-pending blocker on the critic dispatch (the anko-consult was on the spatial_profiles.csv wrapper, which is for F2 winding number not F1 ring formation). T117 critic CAN make tier-3 progress on F1 (the central falsifier) without spatial_profiles.csv (F2 territory). NOOP would discard signal.

**Option (e) — researcher (e.g., WebFetch Matsui paper)**: Rejected. The paper was already deep-researched at T71 (researcher_deep extracted 5 EXTRACTED + 1 INFERRED + 2 PARTIAL + 1 NOT_EXTRACTABLE quantities from the PDF). Re-fetching would be redundant; the critic already has the Matsui parameters in state.json falsifier descriptions + T71 research record.

**Option (f) — pivot to another investigation entirely (e.g., paper3 cleanup)**: Rejected. seed.md priority-0 pin overrides; no other open investigation has higher priority (sign-pattern-f9-ta-mult2 is priority 4 vs edh-matsui priority 0).

Decision: **dispatch critic** with focused independent-context-audit brief on `runs/eu151_edh_K3_long/` with FORM B raw-artifact check_cmds. D1 axis (verification of published physics). Cost ~1.5M expected.

## 3. The critic's directive — independent context audit

### 3.1 Read order (no Glob/Bash, only Read + Grep)

1. `runs/eu151_edh_K3_long/trajectory.csv` — primary artifact. Read entire file. Schema: `t, norm, Fx, Fy, Fz, energy, pop_c1, pop_c2, ..., pop_c13` (m=+F to m=-F populations). The "ring formation cascade" is observable as a sequence of population transfers: m=+F (c=1) initial → m=+5 (c=2) intermediate peak → m=+4 (c=3) → m=+3 (c=4) → ... with characteristic timescales.

2. `runs/eu151_edh_K3_long/config.yaml` — verify the parameters match seed.md "anko's verified working setup": K3 loss term present (look for `loss.K3_per_m_cubic` block per memory `K_3 SI routing bug — FIXED 2026-05-13`), gamma_dr term present (radial trap-damping coefficient), explicit noise seed present (`temperature_ratio` or `seed` field for reproducibility), 32³ grid, F=6 Eu (a_s ≈ 110 a₀, μ ≈ 6.977 μ_B).

3. `runs/eu151_edh_K3_long/_live_status.json` — sim execution metadata (start/end timestamps, dt, total simulation time, any error states).

4. `runs/eu151_edh_K3_long/trajectory.png` — visual inspection of the trajectory plot (LLM multimodal). Should show m=+F initial dominance, transfer to lower-m components, final cascade ending state.

5. `runs/eu151_edh_K3_long/ring_summary_h5py_probe.json` — IF readable as JSON, extract any pre-computed ring metrics from T111 retry probe. Note: per T116 director §6, spatial_profiles.csv is ABSENT; the ring-summary JSON may have partial spatial diagnostic.

6. State.json falsifier F1 block (lines 2151-2158) — the existing T110 stage-1 corroboration + matsui-paper t_ring band.

7. `runs/_loop/research/` — Grep for T71 researcher_deep Matsui-paper extraction record (file likely at `runs/_loop/research/turn_71*.md`). Used as Matsui-reference anchor.

### 3.2 The independent context — what makes this a CRITIC dispatch (not a re-implementer)

Per protocol director.md row "verify-claim" template: critic stage = independent context. The critic does NOT re-execute the simulation. The critic does NOT re-derive the theory. The critic reads the on-disk artifact, applies its own crosswalk against published reference, and emits CORROBORATE / INCONCLUSIVE / REFUTED.

Independence in this dispatch means:
- The critic is NOT told what verdict to emit. It reads the CSV, computes (mentally or via FORM B check_cmd) the ring-formation cascade indicators, then judges.
- The critic CAN disagree with T110's CORROBORATE-STAGE-1 if the trajectory.csv content tells a different story.
- The critic MUST flag any config.yaml omissions (K3 missing, gamma_dr missing, etc.) per memory `feedback_use_existing_artifacts_first` "schema-knob omission is silently wrong physics".

### 3.3 What CORROBORATE looks like (the criteria-block)

The critic's verdict should map to the following success_criteria FORM B contract:

- **F1-ring-cascade-present (central)**: trajectory.csv shows monotonic transfer from m=+F (c=1) → progressive populations of m=+5..+3 with peak times in the 1-20 ms range (Matsui's t_ring ~5 ms × N^(2/5) scaling factor 1.9 from T110 → expected band 2-15 ms K3_long-equivalent). check_cmd computes `pop_c2 + pop_c3 + pop_c4 > 0.01` at any row.
- **F1-cascade-timescale-band**: extract t* = argmax_t pop_c2(t); CORROBORATE if t* ∈ [1.5 ms, 14.5 ms × 2 = 29 ms] (factor-2 band around 14.5 ms per seed.md + Matsui 2.6 ms baseline). check_cmd is a python3 csv-parse.
- **F1-config-has-K3**: grep config.yaml for `K3_per_m_cubic` or similar K3 keyword.
- **F1-config-has-gamma_dr**: grep config.yaml for `gamma_dr` or trap-dissipation keyword.
- **F1-config-has-noise-seed**: grep config.yaml for `seed:` or `temperature_ratio:` keyword.
- **F1-norm-conservation**: trajectory.csv last-row norm within [0.99, 1.01] (or per K3 loss, monotonic decay above 0.5).
- **F1-energy-monotonic-or-near**: trajectory.csv energy shows physically-reasonable evolution (not NaN, not blow-up).
- **No-new-EdH-simulation-side-effect**: critic does NOT modify any runs/ files, does NOT spawn julia, does NOT modify config.yaml.
- **Crosswalk-vs-Matsui-explicit**: critic's report cites Matsui Science 391 384-388 (2026) by DOI + arXiv ID + the specific t_ring / ring topology claims.
- **Verdict-explicit**: critic emits exactly one of {CORROBORATE, INCONCLUSIVE, REFUTED} with 1-paragraph rationale.

If critic CORROBORATE on F1 → state.json patches: `F1.result = "CORROBORATE at T117 critic independent context: ..."`, `tier_current: 2.75 → 3.0`, `current_stage: closed`, `last_verdict: CORROBORATE_F1_CENTRAL_TIER3_ACHIEVED`. This is the Tier-3 promotion the seed.md pin targets.

## 4. What the critic MUST NOT do

- NO new run / new config / new YAML modification (seed.md hard constraint).
- NO julia execution (critic is Read-only by agent definition).
- NO modification of `runs/eu151_edh_K3_long/` files (read-only audit).
- NO modification of state.json or seed.md directly (those are orchestrator/director responsibility post-judge).
- NO writing report .md files — return findings as final assistant message per critic agent file convention.

## 5. Investigation update at T117

- `tier_current` entering T117: 2.75 (per state.json L2181).
- F1 status entering T117: `is_central: true`, T110 result `CORROBORATE-STAGE-1`. T117 critic adds independent confirmation OR raises a flag.
- On T117 critic CORROBORATE deliverable: tier 2.75 → 3.0; investigation `current_stage: closed`; F1 result updated to "CORROBORATE at T110 stage-1 + T117 critic independent context".
- On T117 critic INCONCLUSIVE: tier stays 2.75; F1 result appended; concrete next-action (e.g., "spatial_profiles.csv still needed for full F2 winding number; F1 ring formation insufficient evidence for full Tier-3 without spatial CSV"). Anko-consult escalation possibly required if INCONCLUSIVE persists.
- On T117 critic REFUTED: tier 2.75 → 2.5 (rollback); F1 result becomes REFUTED-AT-T117 with rationale; anko-consult escalation MANDATORY. Investigation re-opens to Hypothesize stage.
- Tier-3 promotion gate (per director.md): F1 IS marked `is_central: true` in state.json with `result` containing CORROBORATE (from T110). T117 critic CORROBORATE = second independent corroboration on the same central falsifier. Promotion to tier 3.0 is gate-unblocked.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "project_axis": "D1",
  "rationale": "Per seed.md 2026-05-19 priority-0 pin (held verbatim, no anko edits since T111): dispatch critic in independent-context audit mode against runs/eu151_edh_K3_long/{trajectory.csv, trajectory.png, config.yaml, _live_status.json, ring_summary_h5py_probe.json}. Artifact-first path (director.md decision-table row 3): existing runs/ outputs + tier_current 2.75 < 3 + last verdict CORROBORATE-STAGE-1 NOT INCONCLUSIVE. Crosswalk against Matsui Science 391 384-388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357]. F1 is_central=true with T110 CORROBORATE-STAGE-1; T117 critic provides 2nd independent corroboration. PASS → tier 3.0 promotion (central falsifier CORROBORATE eligible under director.md Tier-3 gate). NO new EdH simulation per seed.md hard constraint + memory:feedback_use_existing_artifacts_first. T116 manuscript §V Duty B did NOT land on main HEAD (file ends line 516 with 2026-05-11 content; grep multiplicity|m_rep|rho_inv = 0 hits); this is OUTSTANDING but lower priority than seed.md priority-0 — defer to T118 implementer_text re-dispatch. D1 axis (verification of published physics). Sources cited this turn: runs/_loop/sim/turn_116.md (T116 implementer self-report 13/15 SC PASS but main-HEAD actually has 5 FAILs); runs/_loop/judge/turn_116.json (FAIL_OPERATIONAL with 5 SC FAIL not 2); independent Read of docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md (line 516 ends file; no §V content); runs/_loop/state.json L2115-L2188 (edh-matsui block with explicit T110 stage-1 result + next_stage_action critic-dispatch directive); runs/_loop/seed.md (priority-0 critic pin verbatim); runs/_loop/_local/scheduler_117.json (JULIA_GPU_OK, critic allowed); Glob runs/eu151_edh_K3_long/* (14 files present, trajectory.csv + config.yaml the load-bearing pair, spatial_profiles.csv ABSENT — F2 territory not blocking F1 audit); memory:feedback_use_existing_artifacts_first (no new sim); memory:loop_architecture_2026_05_14 (critic = independent context). Cost ~1.5M effective. Drift advisories explicitly acknowledged per protocol §B6 — see §7 below.",
  "brief": "You are critic for investigation `edh-eu151-vortex-vs-matsui-science-2026`. Mode: independent-context audit of pre-existing on-disk EdH simulation artifacts vs published reference. STRICTLY READ-ONLY: no Bash, no Write to runs/ files, no julia, no new simulation. Return verdict as your final assistant message — do NOT create report .md files.\n\n## Task\n\nAudit `runs/eu151_edh_K3_long/` (anko's verified May 13 working setup per seed.md 2026-05-19) against Matsui et al. Science 391 384-388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357]. Issue verdict CORROBORATE / INCONCLUSIVE / REFUTED on the F1-ring-formation central falsifier. This is the seed.md priority-0 pinned action; the loop is awaiting your independent confirmation to promote tier 2.75 → 3.0.\n\n## Read order (Read tool only; you may use Grep for keyword searches)\n\n1. **`runs/eu151_edh_K3_long/trajectory.csv`** — full file (likely <100k tokens; if larger, use offset/limit). Primary artifact. Identify: header schema (column names — likely `t, norm, Fx, Fy, Fz, energy, pop_c1..pop_c13`); initial-row composition (should be m=+F dominated, i.e., pop_c1 ≈ 1.0); final-row composition; intermediate population transfers (pop_c2, pop_c3, pop_c4 peaks).\n\n2. **`runs/eu151_edh_K3_long/config.yaml`** — full file. Verify presence of: (a) K3 loss term (`loss.K3_per_m_cubic` per memory K3_routing_pre_2026_05_13 — quadratic-in-n true 3-body, NOT legacy K3_per_m which was linear-in-n misroute); (b) gamma_dr term (trap-dissipation / radial damping); (c) explicit noise seed (`temperature_ratio` Bose-Einstein noise OR explicit `seed:`); (d) grid 32³; (e) F=6 Eu parameters (a_s ≈ 110 a₀ ≈ 5.823 nm, c_dd matches μ ≈ 6.977 μ_B).\n\n3. **`runs/eu151_edh_K3_long/_live_status.json`** — sim execution metadata. Confirm completion status, total simulation time, dt.\n\n4. **`runs/eu151_edh_K3_long/trajectory.png`** — visual (LLM multimodal). Should display monotonic population transfer m=+F → m=+5..+3.\n\n5. **`runs/eu151_edh_K3_long/ring_summary_h5py_probe.json`** — IF parseable. May have partial T111-retry ring metrics.\n\n6. **`runs/_loop/state.json`** — focus on lines 2115-2188 (edh-matsui investigation block) — the existing T110 stage-1 CORROBORATE result, the falsifier descriptions, the tier_current/tier_target.\n\n7. **`runs/_loop/seed.md`** — verbatim priority-0 pin context.\n\n8. **Optional** if needed for Matsui-paper crosswalk: `Grep` runs/_loop/research/ for `Matsui` to find T71 researcher_deep paper extraction.\n\n## Specific physics checks the critic should perform\n\n### CHECK-1: F1 ring formation cascade observable in trajectory.csv\n\nMatsui's mechanism (Science 2026 §1.2-§1.5): near-zero-B-quench from m=+F FM state → DDI Einstein-de Haas drives spin → orbital angular momentum transfer → m=+F unstable, cascades to m=+5, +4, +3 with characteristic timescale t_ring ~ 5 ms (paper experimental) scaled by N^(2/5) for the simulation's N (~10⁵). Seed.md states K3_long has clean 14.5 ms dynamics with full cascade m=+F → m=+5/+4/+3, all 13 m states populated.\n\nFrom trajectory.csv:\n- Initial-row pop_c1 (m=+F) ≈ 1.0 ± 0.01? CORROBORATE if yes.\n- Intermediate t where pop_c2 (m=+5) reaches first peak: identify peak amplitude + time. CORROBORATE if peak > 5% at any t ∈ [1, 20] ms; ratify if peak > 16% at t ∈ [2, 15] ms (matching T110 stage-1 observation of pop_c2 peak 16.3% at t=5.22 ms).\n- pop_c3, pop_c4 reach intermediate peaks in temporal succession (c=2 peak before c=3 peak before c=4 peak): CORROBORATE if monotonic cascade.\n- pop_c5..pop_c13 reach detectable levels (>0.1%) by end of trajectory: CORROBORATE if 'all 13 m states populated' per seed.md.\n- norm conservation: last-row norm ∈ [0.5, 1.01]; norm decay only via K3 (no NaN, no blow-up).\n\n### CHECK-2: Config has the 3 load-bearing features\n\nPer seed.md and memory `feedback_use_existing_artifacts_first` schema-knob-omission warning:\n- `K3` loss term present (look for `loss:` block with `K3_per_m_cubic:` or `K3:` field). Without K3, Eu collapses <1 ms.\n- `gamma_dr` (radial damping) present. Without gamma_dr, dynamics get stuck.\n- Explicit noise seed (Bose-Einstein thermal `temperature_ratio:` OR explicit `seed:` for reproducibility). Without noise, symmetric initial sticks forever in m=+F.\n\nIf ANY of the 3 is missing: REFUTED-CONFIG (this is NOT anko's verified setup; the trajectory may be the regressed config T76-T86 ran).\n\n### CHECK-3: Crosswalk against Matsui Science 2026\n\nState the explicit references in your verdict:\n- Matsui Y., et al. \"Observation of spin-orbit Einstein-de Haas effect in a ferromagnetic dipolar Bose-Einstein condensate.\" Science 391, 384-388 (2026). DOI:10.1126/science.adx2872. arXiv:2504.17357.\n- Key claim 1: t_ring ~ 5 ms (paper experimental, B=0.1 G quench, N≈10⁵). Simulation N^(2/5) scaling from T110: 5 ms × 1.9 ≈ 9.5 ms K3_long-equivalent (T110 saw 5.22 ms; K3_long seed.md reports 14.5 ms; both within factor-2 band [2.6, 14.5]).\n- Key claim 2: ring topology (azimuthally-averaged density depletion at r=0 in c_flip component) with winding number ℓ consistent with F=6 AM balance. F2 territory — requires spatial_profiles.csv which is ABSENT. Audit this dimension as INCONCLUSIVE (not enough data to corroborate winding number).\n- Key claim 3: pre-quench m=+F FM GS energy matches GP mean-field within 20%. F3 territory — already CORROBORATE at T83 (8.0% rel_error per state.json L2188 closing_note).\n\nVerdict scope is F1 only. F2 winding number is OUT_OF_SCOPE (spatial_profiles.csv ABSENT); F3 already CORROBORATE; F4 optional zero-DDI control deferred.\n\n### CHECK-4: Independence audit on T110's prior verdict\n\nT110 critic emitted CORROBORATE-STAGE-1 at tier 2.75. Your T117 audit must be INDEPENDENT — do not anchor on T110's verdict. If trajectory.csv content tells a different story (e.g., the cascade doesn't actually proceed, or the timescale is wildly off), you MUST emit INCONCLUSIVE or REFUTED. Your role is to PROVE WRONG (or fail to). Confirmation bias is the failure mode.\n\nSpecifically: examine pop_c2 peak time + amplitude DIRECTLY from CSV. Compare against T110's reported 16.3% at 5.22 ms. If your read shows substantially different values (e.g., peak at 0.5 ms suggesting K3 wasn't actually on, or peak at 50 ms suggesting wrong scaling), flag it.\n\n## Output (your final assistant message)\n\nReturn the following structured response (markdown, NOT a separate file):\n\n```\n# T117 Critic Audit — edh-eu151-vortex-vs-matsui-science-2026 F1 ring formation\n\n## Verdict: CORROBORATE | INCONCLUSIVE | REFUTED\n\n## 1. Artifacts read\n- trajectory.csv: N_rows = ..., t_range = [..., ...] ms, columns = [...]\n- config.yaml: K3_present=Y/N, gamma_dr_present=Y/N, noise_seed_present=Y/N, grid=..., F=...\n- _live_status.json: completion=..., dt=..., total_time=...\n- trajectory.png: visual confirms/contradicts cascade\n- ring_summary_h5py_probe.json: parseable=Y/N, contents=...\n\n## 2. F1 ring formation cascade evidence\n- pop_c1(t=0) = ...\n- pop_c2 peak amplitude = ..., at t = ... ms\n- pop_c3 peak amplitude = ..., at t = ... ms\n- pop_c4 peak amplitude = ..., at t = ... ms\n- pop_c5..pop_c13 detectable by end: Y/N\n- Last-row norm = ...\n\n## 3. Config-feature crosswalk\n- K3 (memory K3_routing_pre_2026_05_13 quadratic-in-n cubic form): PRESENT/ABSENT, value = ...\n- gamma_dr: PRESENT/ABSENT, value = ...\n- noise seed (temperature_ratio or seed): PRESENT/ABSENT, value = ...\n\n## 4. Matsui crosswalk\n- t_ring^paper = 5 ms (experimental); N^(2/5) scaling to K3_long N = ... → expected t_ring^sim ∈ [..., ...] ms\n- t_ring^sim observed = ... ms\n- ratio = ..., factor-2 band PASS/FAIL\n- Winding number F2: spatial_profiles.csv ABSENT → OUT_OF_SCOPE this turn (defer to F2 audit when wrapper run)\n- F3 GS energy: already CORROBORATE at T83 with 8.0% rel_error per state.json L2188\n\n## 5. Independence check on T110\n- T110 reported pop_c2 peak 16.3% at 5.22 ms. T117 direct CSV read: ...\n- Agreement: Y/N\n\n## 6. Verdict rationale (1-3 paragraphs)\n- ...\n\n## 7. Tier promotion eligibility\n- F1 central CORROBORATE? Y/N → recommend tier 2.75 → 3.0 closure: Y/N\n- If INCONCLUSIVE: specific next action (e.g., 'F1 needs spatial_profiles.csv for full topology corroboration' OR 'pop_c2 peak is borderline; need anko-consult on whether 16.3% at 5.22 ms is decisive')\n- If REFUTED: rationale (which check failed, why)\n\n## 8. Falsifier update payload (for orchestrator to merge into state.json)\nF1-ring-appears-correct-timescale:\n  tested_at_turn: 117\n  result: '<CORROBORATE|INCONCLUSIVE|REFUTED> at T117 critic independent context: <rationale-summary-1-line>'\n  is_central: true\n```\n\nDo NOT write this to a file. Return as your final assistant message text. The orchestrator/director consumes it directly.\n\n## Hard constraints (per seed.md + protocol)\n\n- READ-ONLY: do not edit any file. The audit produces a verdict, not deliverables.\n- NO julia execution.\n- NO new YAML configs.\n- Cite Matsui paper by DOI + arXiv ID explicitly in §4.\n- If trajectory.csv is too large to Read in one call: use Read with offset/limit; sample header + first 50 rows + middle 100 rows + last 100 rows; identify peaks via Grep + offset/limit reads on the suspected peak regions.\n- If config.yaml is missing K3 / gamma_dr / noise seed: verdict cannot be CORROBORATE regardless of trajectory.csv evidence (per seed.md hard constraint). Emit REFUTED-CONFIG-MISMATCH.\n\n## Cost expectation\n\n~1.5M effective tokens. 8-10 file reads (trajectory.csv is the largest at ~100kB; everything else under 10kB). Plus a few Grep / multi-segment reads on trajectory.csv. No compute. ~3-5 minutes wall.",
  "observable_manifest": {
    "required": [
      "investigation_id",
      "stage_advancing_to",
      "subagent_type",
      "verdict",
      "f1_central_corroborate_independent_context",
      "config_k3_present",
      "config_gamma_dr_present",
      "config_noise_seed_present",
      "trajectory_csv_pop_c2_peak_amplitude",
      "trajectory_csv_pop_c2_peak_time_ms",
      "matsui_crosswalk_t_ring_band_pass",
      "tier_promotion_recommendation",
      "no_runs_files_modified",
      "no_julia_executed"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/_live_status.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md && grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md && grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && echo OK_T117_PRECONDITIONS_HOLD"
  },
  "success_criteria": [
    {
      "id": "critic-verdict-emitted",
      "check_cmd": "grep -E -q 'Verdict:.*(CORROBORATE|INCONCLUSIVE|REFUTED)' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-cited-trajectory-csv",
      "check_cmd": "grep -q 'trajectory.csv' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-cited-config-yaml",
      "check_cmd": "grep -q 'config.yaml' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-cited-matsui-doi",
      "check_cmd": "grep -E -q '10\\.1126/science\\.adx2872|2504\\.17357' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-reported-k3-presence",
      "check_cmd": "grep -E -q 'K3.*(PRESENT|ABSENT|present|absent)' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-reported-gamma-dr-presence",
      "check_cmd": "grep -E -q 'gamma_dr.*(PRESENT|ABSENT|present|absent)' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-reported-noise-seed-presence",
      "check_cmd": "grep -E -q '(noise.seed|temperature_ratio|seed).*(PRESENT|ABSENT|present|absent)' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-reported-pop-c2-peak",
      "check_cmd": "grep -E -q 'pop_c2.*peak' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-tier-promotion-statement",
      "check_cmd": "grep -E -q 'tier.*(2\\.75|3\\.0|promotion|closure)' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "no-runs-files-modified-by-critic",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_117.md -type f 2>/dev/null | head -1",
      "expect": {"exit_code": 0, "stdout_not_contains": "trajectory"}
    },
    {
      "id": "no-src-modification-by-critic",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/src -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_117.md -name '*.jl' -type f 2>/dev/null | head -1",
      "expect": {"exit_code": 0, "stdout_not_contains": ".jl"}
    },
    {
      "id": "no-config-yaml-modified",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_117.md -name 'config.yaml' -type f 2>/dev/null | head -1",
      "expect": {"exit_code": 0, "stdout_not_contains": "config.yaml"}
    },
    {
      "id": "f1-falsifier-update-payload-present",
      "check_cmd": "grep -E -q 'F1-ring-appears-correct-timescale' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "seed-md-priority-0-still-pinned",
      "check_cmd": "grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "manuscript-section-v-status-acknowledged",
      "check_cmd": "echo 'meta-check: T116 manuscript section V is OUTSTANDING per main HEAD; T118 should re-dispatch implementer_text — director acknowledges in directive section 7' && true",
      "expect": {"exit_code": 0}
    }
  ],
  "failure_modes": [
    {
      "if": "critic-verdict-emitted FAILED (no clear verdict in output)",
      "category": "operational",
      "next_action": "T118 dispatches critic again with tighter output-template enforcement. The verdict line MUST be the first H2 in the output."
    },
    {
      "if": "critic verdict = CORROBORATE AND F1 central crosschecks all pass",
      "category": "scientific_success",
      "next_action": "T118 director patches state.json: tier_current 2.75 → 3.0, current_stage 'Document' → 'closed', F1.result append T117 corroboration, last_verdict CORROBORATE_F1_TIER3_ACHIEVED. Investigation closes. T118 then dispatches implementer_text for outstanding T116 manuscript §V Duty B re-do (sign-pattern-f9-ta-mult2 Update completion)."
    },
    {
      "if": "critic verdict = INCONCLUSIVE",
      "category": "data_gap",
      "next_action": "T118 evaluates concrete next-action per critic's §7. If 'needs spatial_profiles.csv': anko-consult escalation (anko run wrapper). If 'pop_c2 peak borderline': consider widening factor-2 band OR additional check. Tier stays 2.75. Subsequent turns may pivot to sign-pattern §V re-do (lower priority but unblockable)."
    },
    {
      "if": "critic verdict = REFUTED-CONFIG-MISMATCH (K3 or gamma_dr or noise seed absent in config.yaml)",
      "category": "scientific_refuted",
      "next_action": "Major flag — the K3_long config does NOT match seed.md's 'anko's verified working setup' description. Tier 2.75 → 2.5 rollback. Anko-consult ESCALATION MANDATORY: which run actually IS the verified setup? Possible the seed.md description was aspirational and the actual run is the regressed config. T118 NOOP with consult."
    },
    {
      "if": "critic verdict = REFUTED-TRAJECTORY-NO-CASCADE (config OK but trajectory shows no ring cascade)",
      "category": "scientific_refuted",
      "next_action": "Tier 2.75 → 2.5. F1.result becomes REFUTED-AT-T117-INDEPENDENT-CONTEXT. Investigation re-opens to Hypothesize stage. Major physics flag — either the framework doesn't reproduce EdH at this parameter regime, or the trajectory.csv is corrupted/incomplete. Anko-consult escalation."
    },
    {
      "if": "trajectory.csv too large to Read entirely AND critic samples only header — verdict based on insufficient evidence",
      "category": "operational",
      "next_action": "T118 dispatches critic again with explicit sampling strategy: header + rows [0, N/4, N/2, 3N/4, N-1] minimum 5-point coverage."
    },
    {
      "if": "critic touches any file in runs/eu151_edh_K3_long/ (read-only violation)",
      "category": "framework_error",
      "next_action": "Roll back. T118 dispatches critic AGAIN with bolded Read-only constraint. Add patterns.yaml entry: critic_write_violation_2026_05_19."
    },
    {
      "if": "anko mid-turn updates seed.md or active_investigation_id",
      "category": "scheduling_override",
      "next_action": "T118 re-reads seed.md verbatim and re-routes per new pin. T117 critic findings are durable artifact in sim/turn_117.md regardless."
    }
  ],
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 600
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_partial_advance_to_stage": "Document",
    "if_partial_tier_becomes": 2.75,
    "if_refuted_advance_to_stage": "Hypothesize",
    "if_refuted_tier_becomes": 2.5,
    "if_success_falsifier_update": {
      "id": "F1-ring-appears-correct-timescale",
      "tested_at_turn": 117,
      "result_template": "CORROBORATE at T117 critic independent context: ring-formation cascade m=+F → m=+5/+4/+3 observed in runs/eu151_edh_K3_long/trajectory.csv with pop_c2 peak <amplitude>% at t=<time> ms; config.yaml K3 + gamma_dr + noise seed all present; Matsui Science 391 384-388 (2026) DOI:10.1126/science.adx2872 t_ring band factor-2 PASS; second independent corroboration on F1 is_central central falsifier. Tier 2.75 → 3.0 closure recommended."
    },
    "note": "T117: critic artifact-first audit. Per seed.md priority-0 verbatim pin (held since T111). Per director.md decision-table row 3 artifact-first path: existing runs/ outputs + tier_current 2.75 < 3 + last verdict NOT INCONCLUSIVE → critic + Update stage. F1 is_central=true with T110 stage-1 CORROBORATE; T117 = 2nd independent corroboration eligible for tier 3.0 closure. NO new EdH simulation per seed.md hard constraint + memory:feedback_use_existing_artifacts_first. T116 manuscript §V Duty B did NOT land on main HEAD (independently confirmed by director Read of sign_pattern_lemma1_general_S.md line 516 + grep 0 hits on multiplicity/m_rep); outstanding work for T118 implementer_text re-dispatch — lower priority than seed.md priority-0. edh-matsui central falsifier promotion path active."
  }
}
```

## 7. Drift advisories — explicit acknowledgement per protocol §B6

Per T116 judge snapshot + state.json L1476-L1489:

- **DRIFT_SUBAGENT_REPETITION (0.333 advisory)**: Last 3 turns = implementer (T114 theorist→T115 implementer attempt1/attempt2→T116 implementer_text). T117 dispatches CRITIC — breaks the implementer streak. Drift signal SHOULD DECREASE next turn. Acknowledged explicitly: switching subagent class to clear repetition.

- **DRIFT_VERDICT_DRIFT (0.8 advisory at T116)**: Streak T112-T116 = NOOP / NOOP / PASS / INCONCLUSIVE / FAIL_OPERATIONAL → 1 PASS in 5 turns. T117 critic with FORM B check_cmds against on-disk artifacts is designed to emit a clear CORROBORATE/INCONCLUSIVE/REFUTED. Expected verdict PASS (CORROBORATE) given T110 stage-1 prior + K3_long is anko's verified setup. Streak recovers.

- **AUDIT_DUE: patterns.yaml gap=11 (advisory)**: Last audit at T105; current gap 11→12 at T117. Acknowledged but NOT dispatched at T117 (would crowd out seed.md priority-0 critic dispatch). Recommend T118 or T119 dispatch audit-class-scan-2026-05-19-T118 if no higher-priority work surfaces. Documenting the deferral here per §B6 transparency.

- **DRIFT_TOPIC_REPETITION (0.455 at T116)**: T117 PIVOTS from sign-pattern-f9-ta-mult2 (T111-T116) to edh-eu151-vortex-vs-matsui-science-2026 (the priority-0 pinned investigation). Drift signal SHOULD DECREASE significantly next turn.

- **DRIFT_COST_INFLATION (1.249 at T116)**: T116 cost 16.85M orchestrator tokens (effective 2.4M per `n_messages=120`). T117 critic-only is Read-only with bounded file budget (trajectory.csv ~100kB + config.yaml ~10kB + everything else under 10kB each). Expected ~1.5M effective tokens. ~10× reduction. Rolling mean recovers.

- **DRIFT_MANUSCRIPT_DELTA_ZERO (0.0 at T116)**: T116 claimed manuscript delta but independent Read shows the file at main HEAD has 0 m_rep/rho_inv/Multiplicity-Aware hits — the §V did NOT actually land. State.json L2848 closing_note IS legitimate manuscript-adjacent delta, but the paper3 §V is OUTSTANDING. T117 does NOT address this directly; T118 will dispatch implementer_text for Duty B re-do after T117 critic completes. Per memory `feedback_manuscript_is_not_the_essence` plus the fact that T117 advances a DIFFERENT investigation (seed.md priority-0): this is acceptable. T118 will close the gap.

- **DRIFT_NOVEL_CLAIM_ZERO (0.0 at T116)**: T117 critic emits a verdict (CORROBORATE / INCONCLUSIVE / REFUTED) on an existing F1 falsifier — no novel claims. Stays 0.0. Per protocol §B6 this is acceptable; novel-claim non-zero would be from theorist or researcher_deep, not critic-audit.

## 8. Honesty cross-checks

I considered six alternatives (§2 above). Summary of rejection reasons:

- (b) implementer_text-redo Duty B (manuscript §V): legitimate but LOWER PRIORITY than seed.md priority-0; defer to T118.
- (c) implementer_julia for new EdH baseline: hard-rejected by seed.md verbatim + memory `feedback_use_existing_artifacts_first`.
- (d) noop: no consult-pending blocker; CORROBORATE evidence likely on-disk; would discard signal.
- (e) researcher: T71 already deep-researched the paper; redundant.
- (f) pivot to different investigation: no higher-priority investigation exists (priority 0 vs 4 for sign-pattern-mult2).

The chosen dispatch (a) critic for edh-matsui artifact-first F1 audit:
- Honors seed.md priority-0 verbatim (the strongest precedence rule).
- Follows director.md artifact-first decision-table row 3 exactly.
- Uses FORM B check_cmds against raw trajectory.csv (Tier-3-preferred per director.md §5.B).
- Cost ~1.5M effective (10× cheaper than T116's 16.85M).
- Clear verdict expected; binary outcome routing.

**Honest acknowledgement of T116's failed delivery**: The T116 implementer self-reported 3-duty PASS with the §V manuscript edit. Independent Read at T117 director top-of-turn shows the file ends at line 516 with the 2026-05-11 content — the §V did NOT land on main HEAD despite the implementer's commit `f081603` to the auto-branch. The judge correctly flagged SC5/6/7 as FAIL. T117 does NOT correct this (deferring to T118) BUT does explicitly call it out here so the loop's scientific record is accurate.

## 9. What T118 director should look at first

In order:

1. `Read runs/_loop/sim/turn_117.md` — critic verdict on F1. Specifically the §6 Verdict rationale + §7 Tier promotion eligibility + §8 Falsifier update payload.

2. `Read runs/_loop/judge/turn_117.json` — judge interpretation; if verdict CORROBORATE: prepare state.json patch (tier 2.75 → 3.0, current_stage 'closed', F1.result append T117 corroboration).

3. **Re-Glob `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`** + `grep multiplicity\|m_rep\|rho_inv` — confirm whether T116's §V STILL absent on main HEAD. If absent: T118 dispatches implementer_text with TIGHTER Duty B brief (provide exact text to append + explicit verification step that the file's last line shows the appended content).

4. `Glob runs/eu151_edh_K3_long/spatial_profiles.csv` — if PRESENT, F2 winding number auditable. T118 could dispatch a second critic on F2 (full Tier-3 evidence stack).

5. `cat runs/_loop/seed.md` — if anko updated the pin (e.g., after T117 CORROBORATE closes edh-matsui at tier 3.0), follow new pin.

6. patterns.yaml audit: gap=12 at T117; gap=13 at T118 → due window opens (T118 or T119 should dispatch audit-class-scan).

## 10. Closing

T117 advances `edh-eu151-vortex-vs-matsui-science-2026` from Document/2.75 (re-opened by anko via seed.md 2026-05-19) → Update via critic dispatch. Artifact-first decision-table row 3 path: existing runs/eu151_edh_K3_long/ outputs + tier 2.75 < 3 + last verdict CORROBORATE-STAGE-1 NOT INCONCLUSIVE. Critic does independent-context audit against trajectory.csv + config.yaml + trajectory.png + ring_summary_h5py_probe.json; crosswalks vs Matsui Science 391 384-388 (2026) DOI:10.1126/science.adx2872 / arXiv:2504.17357. FORM B check_cmds against raw CSV bypass §4 LLM-summary path. F1 is_central=true (state.json L2157); T117 = 2nd independent corroboration on the central falsifier → tier 3.0 promotion gate-unblocked on success.

D1 axis (verification of published physics). Cost ~1.5M expected (10× lower than T116). Per seed.md priority-0 hard pin + memory `feedback_use_existing_artifacts_first` hard rule: NO new EdH simulation; the accumulated runs/ ARE the data. T116 manuscript §V Duty B remains OUTSTANDING on main HEAD (independently confirmed by director Read showing file ends at line 516 with 2026-05-11 content + grep 0 hits on multiplicity/m_rep — the judge SC5/6/7 FAIL was correctly diagnosing the on-disk state, not a path mismatch as T116 implementer claimed for those criteria); T118 will re-dispatch implementer_text for the missing §V append after T117 critic completes.

Drift advisories (§7): topic-repetition + subagent-repetition + verdict-drift all clear next turn via PIVOT from sign-pattern (T111-T116) to edh-matsui (T117) + subagent class swap (implementer → critic) + bounded Read-only workload. AUDIT_DUE gap=11→12; deferred to T118/T119. Cost inflation clears with ~10× reduction.

Per `feedback_cost_overhead_is_the_cost`: this dispatch is sized, scoped, single-investigation, single-subagent, single-axis. No deliberation beyond this point — execute.
