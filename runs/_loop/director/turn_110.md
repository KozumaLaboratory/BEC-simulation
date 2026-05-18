---
turn: 110
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: "Research (T109 researcher_deep substantively delivered Matsui methodology + symmetry mapping + refined F1 criterion + NC1/NC2 trajectory.csv shortcut — but judge.py marked FAIL_OPERATIONAL on a contract-shape mismatch: success_criterion `symmetry_mapping_verified_kawaguchi_ueda` expected enum string, researcher emitted boolean `true`; the substantive work is sound and load-bearing)"
stage_advancing_to: Update
topic_tags: [edh-eu151-matsui-science-2026, central-falsifier-F1, critic-re-audit, qualitative-ring-criterion, NC1-NC2-population-shortcut, artifact-first-path, no-julia-needed, D1-axis, contract-shape-vs-substance]
paper_section: null
depends_on:
  - 109
  - 108
  - 107
  - 86
  - 71
  - "runs/_loop/seed.md"
  - "runs/_loop/director/turn_109.md"
  - "runs/_loop/research/turn_109.md"
  - "runs/_loop/sim/turn_109.md"
  - "runs/_loop/judge/turn_109.json"
  - "runs/_loop/judge/turn_107_critic_audit.md"
  - "runs/_loop/sim/turn_108.md"
  - "runs/_loop/_local/scheduler_110.json"
  - "runs/eu151_edh_K3_long/config.yaml"
  - "runs/eu151_edh_K3_long/trajectory.csv"
  - "runs/eu151_edh_K3_long/trajectory.png"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:feedback_manuscript_is_not_the_essence"
  - "memory:feedback_cost_overhead_is_the_cost"
  - "memory:feedback_fix_the_class_not_the_instance"
produces: >
  T110 critic dispatch in independent-audit mode. Inputs: T109 research/turn_109.md
  (Matsui qualitative ring criterion + Bragg-interferometric Stage-2 + NC1/NC2 +
  trap (110,110,130) Hz + N~5e4 + symmetry mapping K3_long c=2 ↔ Matsui c=12 +
  K3_long-equivalent ring time ~2.6 ms via N^(2/5) scaling), eu151_edh_K3_long
  artifacts (trajectory.csv, trajectory.png, config.yaml). Critic must (i) verify
  T109's methodology extraction is consistent with cited sources, (ii) apply the
  refined F1 criterion to K3_long artifacts producing CORROBORATE-stage-1 /
  INCONCLUSIVE / REFUTED verdict, (iii) explicitly distinguish Stage-1 (qualitative
  density ring; assessable from trajectory.png + integrated populations) from
  Stage-2 (Bragg interferometric phase-winding; OUT_OF_SCOPE for this loop turn).
  Verdict-shape: critic.md §F8 schema — formal verdict with falsifier table.
---

# Turn 110 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `edh-eu151-vortex-vs-matsui-science-2026` (priority 0, flow_template `verify-claim`, tier_current 2.5, tier_target 3; F1 `is_central:true` with `tested_at_turn:null`). Seed.md mandates this as the active investigation.

- **T109 outcome decoded**: judge/turn_109.json reports `FAIL_OPERATIONAL` BUT the underlying issue is **contract-shape only**: `symmetry_mapping_verified_kawaguchi_ueda` was declared with `operator: "in"` against an enum `["EXTRACTED", "INFERRED", "PARTIAL", "NOT_EXTRACTABLE"]`, and the researcher emitted boolean `true` (because the question "verified or not?" is genuinely yes/no, not an extraction-status enum). **All 13 other criteria PASSED**, including the substantive ones (f1_refined_criterion_text non-empty, n_sources_consulted ≥ 8, kawaguchi-ueda cited, no src/sim/yaml/manuscript edits, no julia/GPU invoked, prompt-injection log present, methodology section present). Substantively this was an excellent researcher pass — 28 sources, WebSearch breakthrough surfacing verbatim arXiv body snippets that direct WebFetch could not reach. Cost ratio 0.57 (well under expected; budget OK).

- **Why this is NOT a substantive failure**: judge.py is doing exactly what it should — flagging a contract violation. The director (me at T109) should have either (a) emitted criterion FORM B `check_cmd` against research/turn_109.md text for "symmetry verified" via grep, or (b) used a different metric name with boolean operator. The researcher correctly emitted "YES verified" as `true`. The substantive deliverable is intact at `runs/_loop/research/turn_109.md` and contains the load-bearing material T110 needs.

- **What T109 actually delivered** (from research/turn_109.md):
  - M1a-f Matsui ring-detection methodology: **qualitative visual ring + Bragg-pulse interferometric phase-winding confirmation** (Fig. 3 protocol). **NO published quantitative depth/aspect threshold**. T82's ad-hoc 20%/1.5 thresholds were never Matsui's criterion.
  - M2a-c symmetry mapping: K3_long c=2 (m=+5) ↔ Matsui c=12 (m=-5) verified via Wigner-Eckart CG invariance + Kawaguchi-Ueda 2012 Phys. Rep. §5.4 + spin-bilinear DDI invariance under joint m↔-m + B↔-B. AM-conservation argument from Kawaguchi-Saito-Ueda 2006 PRL cited.
  - M3 refined F1 criterion: visually-identifiable ring in c=2 (or c=3, c=4) at hold-time t ∈ [1, 25] ms; CORROBORATE if any ring at any t in [1.5, 7] ms K3_long-time (= 2.6 ms scaled-equivalent of Matsui 5 ms via N^(2/5) factor 1.9, with factor-2 band).
  - M4 alternative shortcut: population-threshold NC1 (pop_c2 ≥ 10%) SATISFIED at K3_long t=5.22 ms (peak 16.3%); NC2 (persistence ≥ trap period 9.1 ms) MARGINAL. Spatial extraction NOT bypassable for full F1, but NC1+NC2 are publishable necessary-condition checks.
  - M5 retry: Matsui trap (ω_x, ω_y, ω_z)/(2π) = (110, 110, 130) Hz EXTRACTED (this was T71 NOT_EXTRACTABLE → T109 EXTRACTED via Google snippet harvest of arXiv body text). K3_long config matches to 3 sig figs. N ~ 5×10^4 EXTRACTED. T6 winding ℓ still PARTIAL. S3/S4 spatial profiles PARTIAL (figures exist; pixel values not surfaced).

- **The decision tree this turn**: T109 substantively unblocked the critic re-audit. Per protocol §B "Artifact-first path" (existing artifact + tier_current < 3 + last verdict NOT INCONCLUSIVE on substance): set `subagent_type = critic`, advance to `Update` stage (the flow_template `verify-claim` audit/review stage). T110 critic ingests T109 research + K3_long artifacts and issues a formal verdict on F1.

- **Why NOT another researcher pass**: T109's NOT_EXTRACTABLE items (M1a, M1b, M1f) are NOT_EXTRACTABLE because **Matsui's published criterion is genuinely qualitative**, not because researcher under-searched. Re-dispatching researcher will return the same NOT_EXTRACTABLE on M1a/b/f. Further parameter retries (T6 winding ℓ exact integer, S4 pixel-level profile) require either (i) anko-shared figure inspection or (ii) institutional Science paywall access — both outside loop reach.

- **Why NOT implementer_julia again**: T108 established sandbox julia denial. Re-dispatch fails identically. T108's `extract_ring_metrics.jl` + `run_extract_ring_metrics.sh` are staged on disk for anko's manual run; T110 critic should explicitly route this as the post-loop next step if a quantitative spatial verdict is needed.

- **Why NOT theorist hard-derivation**: T109 closed the methodology gap; F1 verdict is now blocked on critic synthesis, not theorist work. Theorist Hypothesize for an analytic Bragg-protocol simulation derivation is a T111+ option if T110 returns INCONCLUSIVE-spatial-required, not a T110 first move.

- **Why NOT noop**: scheduler is JULIA_GPU_OK (line 11; permits everything); scheduler probe shows full headroom. The critic re-audit is the planned post-T109 dispatch, exactly per T109's success-mode routing (`if_success_advance_to_stage: Update`). Skipping it wastes the T109 deliverable.

- **Subagent rotation last 6 turns**: impl_text (T105), impl_text (T106), critic (T107), implementer_julia (T108), researcher_deep (T109). T110 = critic. T107 was the last critic dispatch on this same investigation — but that was BEFORE T109's methodology extraction. T110 critic has **new external anchor** (Matsui methodology, symmetry mapping, N-scaling timescale conversion) absent at T107. This is not a repeat-same-dispatch; it's the audit-with-new-evidence dispatch the protocol prescribes.

- **Quota check (§B Quota Precedence)**: scheduler_110.json window_seconds_left=1,108,718 (~18,478 min). Policy JULIA_GPU_OK. Critic is text-only Read tool: ~100 MB memory, no julia, no GPU. Trivially fits.

- **Tier-3 promotion gate awareness (§F8)**: F1 IS the central falsifier with `is_central:true`. T110's verdict directly feeds Tier-3 gate. To clamp ≥3.0 needs CORROBORATE/CONFIRMED on F1. T110 might emit CORROBORATE-stage-1 (qualitative ring confirmed) with a Stage-2 caveat (Bragg interferometry untested) — this is a structurally honest sub-Tier-3 verdict. The "honest Tier-3" likely requires the actual JLD2 spatial extraction (anko manual run), which means T110 may legitimately land at tier 2.75 with Stage-2 escalation note rather than full 3.0.

## 2. Recent-turn audit (last 6 turns)

| Turn | Investigation | Stage | Subagent | Verdict | What happened |
|---|---|---|---|---|---|
| T105 | audit-class-scan-T103 | Triage mech-half | implementer_text | PASS | patterns.yaml + state.json bookkeeping |
| T106 | audit-class-scan-T103 | Document | implementer_text | PASS | Memory entry; close |
| T107 | edh-eu151-matsui | Update | critic | CRITIC_INCONCLUSIVE | F1 INCONCLUSIVE: spatial data gap |
| T108 | edh-eu151-matsui | Update | implementer_julia | INCONCLUSIVE (FAIL_OPERATIONAL_SANDBOX) | Script staged, julia denied |
| T109 | edh-eu151-matsui | Research | researcher_deep | FAIL_OPERATIONAL (contract-shape only; substantive PASS) | Matsui methodology + symmetry + NC1/NC2 extracted; 28 sources; trap params closed |
| **T110** | **edh-eu151-matsui** | **Update (Artifact-first audit)** | **critic** | **TBD** | **Apply T109 refined F1 criterion to K3_long trajectory.csv + trajectory.png + config.yaml; emit formal verdict CORROBORATE-stage-1 / INCONCLUSIVE / REFUTED with explicit Stage-1/Stage-2 split.** |

Class rotation: critic (T107), implementer (T108), researcher (T109), critic (T110). No same-class streak; legitimate next critic dispatch on enriched evidence base.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Stage**: advances Research (T109) → **Update** (T110). Per §B verdict-routing: T109 was FAIL_OPERATIONAL on contract-shape with substantive output intact → treat substantively as PASS for stage-advance purposes; the published-criterion ground truth that Research stage was meant to provide IS now present. **Update is the stage that audits the central falsifier and updates conclusions/<inv_id>.md ledger**.
- **Role for Update stage of `verify-claim`**: per §B table "Update=critic (mandatory independent context)". T110 dispatches critic.
- **Artifact-first path** (protocol §B): K3_long has trajectory.png/result.jld2/trajectory.csv on disk; tier_current=2.5 < 3; last verdict (T109) was NOT substantively INCONCLUSIVE — perfect fit. Set stage = `Update` per the protocol mapping for `verify-claim`. Brief: audit existing artifact + crosswalk against published reference. NO new simulation.

## 4. Research grounding (§A6)

T110 dispatch citations:

1. **`runs/_loop/seed.md`** lines 3-31 — investigation re-opened; F1 must be evaluated against published Matsui criterion. T109 delivered the criterion. T110 closes the loop.
2. **`runs/_loop/research/turn_109.md`** §2-4 (Methodology + Symmetry + Refined F1) — the load-bearing T110 input. Specifically §4 F1-REFINED-MATSUI-QUALITATIVE statement and §5 NC1/NC2 trajectory.csv shortcut.
3. **`runs/_loop/judge/turn_107_critic_audit.md`** §3-6 — T107 critic flagged T82's ad-hoc 20%/1.5 thresholds as ungrounded; that gap is now closed by T109 establishing the criterion is qualitative + interferometric.
4. **`runs/_loop/sim/turn_108.md`** §3, §8, §10 — sandbox julia denial; T108 script staged for anko manual. T110 must NOT propose another julia invocation; must NOT critique T109 for not running julia (out of scope).
5. **`runs/eu151_edh_K3_long/trajectory.csv`** (501 frames, t ∈ [0, 14.5] ms, 13 m-population columns) — primary K3_long evidence; NC1/NC2 evaluable directly.
6. **`runs/eu151_edh_K3_long/trajectory.png`** — visual artifact for Stage-1 ring inspection (population time series panels; no spatial ring panels by current pipeline). T110 must explicitly note what trajectory.png shows vs what it does NOT show.
7. **`runs/eu151_edh_K3_long/config.yaml`** — K3_long simulation parameters (trap aspect 1:1:1.182, N=10000, K3 loss, gamma_dr, noise seed). Matches Matsui trap to 3 sig figs per T109 §8 SpinorBEC.jl-canonical translation.
8. **`memory/feedback_use_existing_artifacts_first`** — T110 uses ONLY existing artifacts (trajectory.csv, trajectory.png, T109 research output); proposes no new sim/config.
9. **`memory/feedback_fix_the_class_not_the_instance`** — T110 must call out the CLASS finding: the entire T76-T86 F3-alone closure path was built on a heuristic criterion never traced to Matsui's published methodology. T109 fixed the criterion; T110 applies it cleanly.
10. **`memory/feedback_manuscript_is_not_the_essence`** — T110 is D1 physics-verification, NOT manuscript polish. F1 verdict on central falsifier is the load-bearing deliverable.
11. **`scheduler_110.json`** lines 11-24 — JULIA_GPU_OK; `critic` explicitly in allowed_workloads (line 15). 12.85 GB VRAM free, 25 GB RAM avail, foreign_julia=0. Trivial fit.
12. **CLAUDE.md "Wavefunction" + DDI conventions** — c-index convention (c=1↔m=+F, c=13↔m=-F), DDI sign conventions, used for symmetry-mapping consistency check.

## 5. Calibrated progress check

- **D-axis advanced**: **D1 (verification of existing physics; Tier ladder 0→3)** for `edh-eu151-vortex-vs-matsui-science-2026`. T110 emits the formal F1 verdict that the seed.md-priority-0 investigation has been waiting on since T76. This either CORROBORATES (Tier 2.5→2.75 or 3.0 with Stage-2 caveat), INCONCLUSIVES (stays 2.5 with explicit anko-consult routing), or REFUTES (drops to 2.0 with N-scaling caveat).

- **Tier ladder routing decisions**:
  - **CORROBORATE-stage-1** path: if K3_long trajectory.csv NC1 SATISFIED + trajectory.png cascade visible at correct timescale + symmetry mapping verified → tier_current 2.5 → **2.75**. Full 3.0 deferred pending Stage-2 (Bragg interferometric phase-winding measurement, out-of-scope this loop turn; routes to anko's experimental decision whether Stage-1 visual ring + theory anchor is sufficient for the project's Tier-3 standard).
  - **INCONCLUSIVE** path: if NC2 marginality is judged too weak + spatial extraction is the only honest discriminator → tier 2.5 holds. Route T111 to anko-consult or close investigation as paywall-blocked at 2.5.
  - **REFUTED** path: if T109 N^(2/5) scaling estimate (factor 1.9) is challenged successfully (e.g., loss-rate scaling dominates and shifts the band outside [1.5, 7] ms) → tier 2.5 → **2.0** with explicit N-scaling caveat (recommend Matsui-N=50k follow-up before abandoning EdH claim).

- **Drift advisories**:
  - **DRIFT_MANUSCRIPT_DELTA_ZERO**: T110 is D1 physics-verification on a central falsifier. Per `feedback_manuscript_is_not_the_essence`: this IS the essence. Manuscript polish is correctly de-prioritized.
  - **DRIFT_COST_INFLATION**: T110 critic ~1.5-2.0M expected (text-only, Read-bound). Below T107 2.13M and well below 5M hard cap. Per `feedback_cost_overhead_is_the_cost`: hard caps + leverage are the only relevant criteria; this is high-leverage.
  - **DRIFT_VERDICT_DRIFT**: Last 6: PASS, PASS, INCONCLUSIVE, INCONCLUSIVE, FAIL_OPERATIONAL. T110 critic likely emits a structured verdict (CORROBORATE-stage-1 most probable given NC1 met + symmetry verified) → restores PASS trajectory.

- **Class-level finding to surface in critic**: T76-T86 F3-alone closure was on an ad-hoc heuristic criterion (depth>20%, aspect>1.5) that was NEVER Matsui's published criterion. T82 implementer inherited it from state.json text; state.json text was project-internal. T109 has now established Matsui's actual criterion is qualitative + interferometric. T110 critic must call this out explicitly so the conclusions/<inv_id>.md ledger captures the finding and prevents future repetition.

- **Anticipated drift trajectory T110**:
  - `topic_repetition`: 0.67 (edh-matsui at T107 + T108 + T109 + T110 = 4 of last 6; high but priority-0 per seed.md)
  - `subagent_repetition`: 0.17 (critic at T107 + T110; not consecutive)
  - `manuscript_delta_zero`: 1.0 (expected; critic is verdict-only)
  - `code_delta_zero`: 1.0 (expected; critic is read-only)
  - `verdict_drift`: ↓ (critic emits structured verdict)
  - `cost_inflation`: 0.7-0.9 (critic ~1.5-2.0M < rolling median)
  - `novel_claim_zero`: ↓ (formal F1 verdict + class-finding documentation)

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "researcher_depth": null,
  "parallel_researcher_count": 1,
  "project_axis": "D1",
  "rationale": "T109 researcher_deep substantively delivered (judge FAIL_OPERATIONAL was contract-shape only — symmetry_mapping field expected enum string, researcher emitted boolean True; substantively 13/14 criteria PASSED including methodology + provenance + sources + no-code-edits guards). Matsui ring criterion is now established as qualitative visual + Bragg-interferometric Stage-2 (research/turn_109.md §2 M1a-f); symmetry mapping K3_long c=2 ↔ Matsui c=12 verified via Wigner-Eckart + Kawaguchi-Ueda (§3 M2a-c); refined F1 criterion + NC1/NC2 trajectory.csv shortcut available (§4-5); trap params extracted (110,110,130 Hz match K3_long to 3 sig figs, §6 M5). Protocol §B Artifact-first path applies: K3_long has trajectory.csv/trajectory.png/result.jld2 on disk + tier_current=2.5<3 + last verdict NOT substantively INCONCLUSIVE — dispatch critic in Update stage to apply T109's published criterion to K3_long artifacts. The honest verdict candidates are CORROBORATE-stage-1 (qualitative ring + NC1 met + symmetry verified; tier 2.75), INCONCLUSIVE (Stage-2 strictly required; tier 2.5 holds, route to anko-consult for manual JLD2 julia run), or REFUTED (timescale band miss; tier 2.0 with N-scaling caveat). Critic MUST explicitly split Stage-1 (assessable from existing artifacts) from Stage-2 (Bragg interferometric phase-winding; OUT_OF_SCOPE). Per `feedback_use_existing_artifacts_first`: no new sim. Per `feedback_fix_the_class_not_the_instance`: critic must surface the class-finding that T76-T86 F3-alone closure used a project-internal ad-hoc heuristic never derived from Matsui's published criterion. Per `feedback_manuscript_is_not_the_essence`: this is D1 physics-verification on the central falsifier. Per `feedback_cost_overhead_is_the_cost`: ~1.5-2M expected, well below 5M cap. D1 axis advance.",
  "brief": "## ROLE\n\nYou are the critic for T110 §B-verify-claim Update stage of investigation `edh-eu151-vortex-vs-matsui-science-2026`. T109 researcher_deep substantively delivered the Matsui 2026 ring-detection methodology + symmetry mapping + refined F1 criterion (judge.py marked FAIL_OPERATIONAL only on a contract-shape mismatch — symmetry_mapping field expected enum string, researcher emitted boolean `true`; 13/14 substantive criteria PASSED). Your job is to apply T109's refined F1 criterion to `runs/eu151_edh_K3_long/` artifacts and emit a FORMAL VERDICT on the central falsifier F1-ring-appears-correct-timescale.\n\nDIRECTIVE_LABEL: edh-eu151-matsui-T110-update-critic-apply-refined-f1-criterion-from-t109-research\n\n## CRITICAL CONTEXT (load BEFORE any analysis)\n\nT109 finding chain (read in this order):\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_109.md` ENTIRE FILE — your load-bearing input. Pay special attention to:\n   - §2 M1a-f: Matsui criterion is QUALITATIVE visual ring + Bragg interferometric Stage-2. NO published quantitative depth/aspect threshold. The 20%/1.5 thresholds T82 used were project-internal heuristics inherited from state.json text, NOT derived from Matsui.\n   - §3 M2a-c: symmetry K3_long c=2 (m=+5) ↔ Matsui c=12 (m=-5) verified via Wigner-Eckart CG invariance + Kawaguchi-Ueda 2012 Phys. Rep. §5.4. AM-conservation argument. Density signature identical, Bragg-fringe handedness flipped.\n   - §4 M3: refined F1 criterion is QUALITATIVE — visually-identifiable ring at hold-time t ∈ [1, 25] ms; CORROBORATE if any t ∈ [1.5, 7] ms K3_long-time (N^(2/5)-scaled equivalent of Matsui 5 ms).\n   - §5 M4: NC1 (pop_c2 ≥ 10%) SATISFIED at K3_long t=5.22 ms (peak 16.3%); NC2 (persistence ≥ trap period 9.1 ms) MARGINAL. Population threshold alone is NECESSARY but NOT SUFFICIENT.\n   - §6 M5: trap (ω_x, ω_y, ω_z)/(2π) = (110, 110, 130) Hz EXTRACTED, matches K3_long to 3 sig figs. N_Matsui ~ 5e4 vs N_K3long = 1e4 = 5x. Mean-field timescale factor 1.9. K3_long-equivalent of Matsui 5 ms is ~2.6 ms.\n   - §8 SpinorBEC.jl-canonical translation.\n   - §9 T110 unblocking paragraph.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md` §3-6 — T107 critic's ad-hoc-threshold flag (which T109 now resolves at the source).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_108.md` §3, §10 — sandbox julia denial; T108 staged script for anko manual run. Do NOT propose another julia invocation; do NOT critique T109 for not running julia (out of scope).\n4. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv` — 501 frames, t ∈ [0, 14.5] ms, 13 m-population columns. NC1/NC2 evaluable directly via grep / awk / inspection.\n5. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png` — visual artifact. Note: this is the POPULATION TIME SERIES plot, NOT a spatial ring panel. Be explicit about what it shows and does NOT show.\n6. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml` — K3 loss, gamma_dr, noise seed, trap aspect 1:1:1.182, initial_state=m_plus_F.\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_109.json` — confirms substantive PASS on all except contract-shape symmetry_mapping criterion.\n\n## YOUR TASK\n\nProduce `runs/_loop/judge/turn_110_critic_audit.md` (load-bearing) with formal verdict. Schema (per critic.md §F8):\n\n### §1. Critic role declaration\n\n- Independent context (you did NOT write T109 research; you are the auditor).\n- Investigation under audit: edh-eu151-vortex-vs-matsui-science-2026.\n- Central falsifier under test: F1-ring-appears-correct-timescale.\n- Tier-3 promotion gate: F1 is_central:true; CORROBORATE here clamps tier ≤ 2.75 unless Stage-2 Bragg interferometry is also CORROBORATE (which is out-of-scope this turn).\n\n### §2. Evidence inventory\n\nList all evidence consulted with absolute paths. For each, declare WHAT the artifact CAN tell us about F1 and what it CANNOT.\n\n- T109 research/turn_109.md: methodology + symmetry + refined criterion. CAN tell: criterion is qualitative + interferometric, NC1/NC2 status, timescale scaling.\n- trajectory.csv: integrated populations. CAN tell: NC1, NC2, cascade existence + peak timing. CANNOT tell: spatial ring presence/absence.\n- trajectory.png: population time series (likely 13-line plot). CAN tell: cascade dynamics visually. CANNOT tell: spatial ring.\n- config.yaml: simulation parameters. CAN confirm trap-frequency match + K3/gamma_dr/noise presence.\n- result.jld2: 4D ComplexF32 spatial wavefunction. CAN tell: spatial ring directly. BUT: not extractable in this sandbox (julia-denied per sim/turn_108 §3). Out-of-loop-reach.\n\n### §3. Verification of T109 substantive claims\n\nFor each load-bearing T109 claim, audit independently:\n\n- **Claim T109-A**: Matsui ring criterion is QUALITATIVE visual + Bragg interferometric Stage-2. Verify: re-read T109 §2 sources; check Stage-2 Bragg-protocol description is consistent with Fig. 3 description from snippets; check no quantitative threshold was missed.\n- **Claim T109-B**: Symmetry mapping K3_long c=2 ↔ Matsui c=12. Verify: independently confirm Wigner-Eckart argument (the CG coefficient symmetry C(F,m;2,-1;F,m-1) under m↔-m); confirm Kawaguchi-Ueda 2012 §5.4 anchor is appropriate (the review section is on spinor-dipolar BECs); confirm linear Zeeman ~22 nK is small compared to DDI scales.\n- **Claim T109-C**: Trap (110, 110, 130) Hz matches K3_long. Verify against config.yaml: omega_ref = 691.15 rad/s? trap_aspect = [1, 1, 1.182]? Confirm K3_long omega_z / omega_x = 1.182 = 130/110.\n- **Claim T109-D**: N-scaling factor 1.9 (5^(2/5)). Verify the N^(2/5) argument (R_TF ~ N^(1/5), n ~ N^(2/5), tau_MF ~ 1/(n·c_0)) is dimensionally correct. Note: this is a mean-field-only estimate; DDI-driven timescales may differ. Flag as ORDER-OF-MAGNITUDE.\n- **Claim T109-E**: NC1 SATISFIED. Verify: load trajectory.csv directly (use Read tool, look for pop_c2 column), confirm peak ≥ 10% in t ∈ [1.5, 7] ms band.\n- **Claim T109-F**: NC2 MARGINAL. Verify: pop_c2 width-above-10% from trajectory.csv vs trap period 9.1 ms. If width is ~3-4 ms, MARGINAL is correct.\n\nFor each claim, return SUSTAINED / CHALLENGED / REJECTED with brief justification. SUSTAINED = T109's reasoning holds. CHALLENGED = a sub-claim is weakened (e.g., N-scaling order-of-magnitude). REJECTED = a logical/factual error.\n\n### §4. F1 verdict\n\nApply F1-REFINED-MATSUI-QUALITATIVE (T109 §4) to K3_long artifacts. Issue ONE of:\n\n- **CORROBORATE-STAGE-1**: Stage-1 (qualitative ring + necessary conditions) is CORROBORATED. Justification: NC1 met, symmetry mapping verified, trap match exact, cascade timing in band. Stage-2 (Bragg interferometric phase-winding) is OUT_OF_SCOPE for this turn; full Tier-3 CORROBORATE requires anko's manual JLD2 spatial extraction + a future Bragg-protocol simulation. Recommend tier 2.5 → 2.75 (NOT 3.0 — F1 central falsifier needs Stage-1+Stage-2 for full Tier-3 per §F8 gate).\n- **INCONCLUSIVE-SPATIAL-REQUIRED**: necessary conditions are not sufficient; sandbox cannot produce spatial evidence; the honest verdict is INCONCLUSIVE on Stage-1. Tier 2.5 holds. Route T111 to anko-consult for manual `bash /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh` execution.\n- **REFUTED-TIMESCALE-MISS**: cascade timing falls outside [1.5, 7] ms K3_long-equivalent band; ring formation timescale incompatible. Tier 2.5 → 2.0 with N-scaling caveat (recommend N=50k follow-up before abandoning EdH claim).\n- **REFUTED-OTHER**: a different structural mismatch surfaces (e.g., symmetry argument breaks under closer inspection, trap-match claim falsified, K3 loss config wrong). Specify.\n\nFor each, the verdict must be FORM B compatible (cite the trajectory.csv numeric value or config.yaml line that grounds it).\n\n### §5. Class-finding documentation\n\nState explicitly the class-level finding that T76-T86 closure was on an ad-hoc heuristic (depth>20%, aspect>1.5) that was NEVER traced to Matsui's published criterion. Document for the conclusions/<inv_id>.md ledger so future investigations do not repeat the pattern. Per `feedback_fix_the_class_not_the_instance`: this is the class-finding that justifies the re-open at seed.md.\n\n### §6. Stage-1/Stage-2 split explicit\n\nIn the verdict, be explicit:\n\n- **Stage-1 (qualitative density ring + necessary conditions)**: assessable from current K3_long artifacts + T109 research. Within loop reach.\n- **Stage-2 (Bragg interferometric phase-winding, Matsui Fig. 3)**: requires a separate simulation extension (Bragg-pulse protocol, fringe-pattern imaging). NOT available in current K3_long output. Future investigation (e.g., `eu151_edh_bragg_winding/`) could close this.\n- **Tier-3 promotion**: full 3.0 needs both stages CORROBORATE. Stage-1 alone supports 2.75 at most.\n\nThis split is the structurally honest path for the central falsifier and prevents over-claiming Tier-3 from Stage-1 data alone.\n\n### §7. Falsifier table update\n\nUpdate the F1 falsifier with:\n- tested_at_turn: 110\n- result: '<your verdict>: <one-line justification with key numbers from T109 + trajectory.csv>'\n- evidence_paths: [research/turn_109.md, trajectory.csv, trajectory.png, config.yaml]\n\nNote: do NOT edit state.json directly (you have Read-only). Output the JSON-fragment for the orchestrator to apply.\n\n### §8. Self-review checklist\n\n- [ ] Read T109 research entirely\n- [ ] Audited T109 claims A-F independently\n- [ ] Issued ONE formal verdict (CORROBORATE-STAGE-1 / INCONCLUSIVE-SPATIAL-REQUIRED / REFUTED-TIMESCALE-MISS / REFUTED-OTHER)\n- [ ] Stage-1/Stage-2 split explicit\n- [ ] Class-finding (T76-T86 ad-hoc threshold) documented\n- [ ] Falsifier-update JSON fragment present\n- [ ] No src/, no test/, no julia, no GPU\n- [ ] All paths absolute\n- [ ] No improvised terminology\n- [ ] No anko-attribution in output\n\n## CONSTRAINTS\n\n- **Read-only**. Write only to `runs/_loop/judge/turn_110_critic_audit.md` and `runs/_loop/sim/turn_110.md`. NO state.json mutation. NO src/, NO test/, NO YAML edits.\n- **No julia execution**. No GPU. Pure text-only Read + Write.\n- **English only**. No emojis. No improvised terminology. No anko-attribution.\n- **Absolute paths**.\n- **Budget**: ~1.5-2M effective, 3M hard cap. Wall ~10-15 min.\n- **Verdict shape**: MUST emit ONE of the four labels in §4. No hedging into 'partial-corroborate'. If genuinely split, lean to INCONCLUSIVE-SPATIAL-REQUIRED.\n- **Independence**: do NOT defer to T109's verdict-hint. T109 §9 routes to CORROBORATE-stage-1 as the likely outcome — you may agree, but only after independent audit of claims A-F.\n\n## DELIVERABLES\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md` (~3000-5000 tokens) — §1-§8 above.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_110.md` (~1500-2000 tokens) — standard §4 Metrics JSON block with the observable manifest fields below.\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT propose new simulation / YAML / config / spatial-extraction script. T108 staged that path; T110 routes to anko-consult if needed.\n- Do NOT issue Tier-3 promotion to 3.0 from Stage-1 alone. Stage-2 (Bragg) is OUT_OF_SCOPE; the honest max is 2.75.\n- Do NOT re-extract T109 methodology (read T109 directly, cite §-numbers).\n- Do NOT critique T109 for the contract-shape FAIL_OPERATIONAL (that is the director's contract bug, not the researcher's substance fault).\n- Do NOT issue REFUTED on the F3 8% energy-error finding (T82 closure result) — F3 is non-central; T82's F3 reasoning stands. The audit is on F1, not F3.\n- Do NOT invent a quantitative depth/aspect threshold; if Stage-1 requires spatial extraction for visual identification, route to anko-consult.\n- Do NOT verify with population-only criterion as if it were sufficient — NC1+NC2 are necessary, not sufficient (T109 §5 explicit).",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "critic_verdict",
      "f1_verdict_label",
      "f1_verdict_justification",
      "stage1_assessable_from_existing_artifacts",
      "stage2_bragg_in_scope_this_turn",
      "claim_t109_A_methodology_status",
      "claim_t109_B_symmetry_status",
      "claim_t109_C_trap_match_status",
      "claim_t109_D_N_scaling_status",
      "claim_t109_E_NC1_status",
      "claim_t109_F_NC2_status",
      "class_finding_documented",
      "falsifier_update_present",
      "tier_recommended",
      "src_edited",
      "test_edited",
      "yaml_edited",
      "state_json_edited",
      "julia_invoked",
      "gpu_used",
      "new_simulations_proposed"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_109.md && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md && echo OK_PRECONDITIONS"
  },
  "success_criteria": [
    {
      "id": "critic-audit-deliverable-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "critic-audit-has-formal-verdict",
      "check_cmd": "grep -c -E '(CORROBORATE-STAGE-1|INCONCLUSIVE-SPATIAL-REQUIRED|REFUTED-TIMESCALE-MISS|REFUTED-OTHER)' /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md",
      "expect": {"exit_code": 0, "stdout_min_int": 1}
    },
    {
      "id": "critic-audit-has-stage1-stage2-split",
      "check_cmd": "grep -c -i -E '(stage.?1|stage.?2|bragg|interferomet)' /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md",
      "expect": {"exit_code": 0, "stdout_min_int": 4}
    },
    {
      "id": "critic-audit-audits-t109-claims",
      "check_cmd": "grep -c -E '(T109-A|T109-B|T109-C|T109-D|T109-E|T109-F|SUSTAINED|CHALLENGED|REJECTED)' /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md",
      "expect": {"exit_code": 0, "stdout_min_int": 4}
    },
    {
      "id": "critic-audit-documents-class-finding",
      "check_cmd": "grep -c -i -E '(class.find|ad.hoc|T76|T82|T86|heuristic.never|project-internal)' /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md",
      "expect": {"exit_code": 0, "stdout_min_int": 2}
    },
    {
      "id": "critic-audit-has-falsifier-update",
      "check_cmd": "grep -c -E '(F1-ring-appears-correct-timescale|tested_at_turn|falsifier.update)' /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_110_critic_audit.md",
      "expect": {"exit_code": 0, "stdout_min_int": 1}
    },
    {
      "id": "f1-verdict-label-in-enum",
      "metric": "f1_verdict_label",
      "operator": "in",
      "value": ["CORROBORATE-STAGE-1", "INCONCLUSIVE-SPATIAL-REQUIRED", "REFUTED-TIMESCALE-MISS", "REFUTED-OTHER"]
    },
    {
      "id": "tier-recommended-bounded",
      "metric": "tier_recommended",
      "operator": "in",
      "value": [2.0, 2.5, 2.75]
    },
    {
      "id": "stage2-explicitly-out-of-scope",
      "metric": "stage2_bragg_in_scope_this_turn",
      "operator": "==",
      "value": false
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
      "id": "no-julia-invoked",
      "metric": "julia_invoked",
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
      "id": "no-new-simulation-proposed",
      "metric": "new_simulations_proposed",
      "operator": "==",
      "value": false
    },
    {
      "id": "class-finding-documented",
      "metric": "class_finding_documented",
      "operator": "==",
      "value": true
    },
    {
      "id": "falsifier-update-present",
      "metric": "falsifier_update_present",
      "operator": "==",
      "value": true
    }
  ],
  "failure_modes": [
    {
      "if": "critic-audit-deliverable-exists failed",
      "category": "operational",
      "next_action": "T111 re-dispatch critic with explicit absolute-path requirement; investigate whether critic stalled or wrote to wrong path"
    },
    {
      "if": "f1_verdict_label == 'CORROBORATE-STAGE-1' AND tier_recommended == 2.75",
      "category": "scientific_corroborate_stage1",
      "next_action": "T111 dispatch implementer_text to (a) update state.json F1 falsifier with tested_at_turn=110 + result=CORROBORATE-stage-1, (b) update conclusions/<inv_id>.md ledger with Stage-1 verdict + class-finding + Stage-2 OUT_OF_SCOPE note + anko-consult recommendation for full Tier-3, (c) advance investigation stage to Document. Tier 2.5 → 2.75. F1 still gates full 3.0 via Stage-2."
    },
    {
      "if": "f1_verdict_label == 'INCONCLUSIVE-SPATIAL-REQUIRED'",
      "category": "scientific_inconclusive_spatial_required",
      "next_action": "T111 dispatch implementer_text to update conclusions/<inv_id>.md with INCONCLUSIVE verdict + explicit anko-consult routing for manual JLD2 spatial extraction (bash run_extract_ring_metrics.sh). T112 either anko-consult result or pivot to non-edh-matsui priority investigation. Tier 2.5 holds."
    },
    {
      "if": "f1_verdict_label in ['REFUTED-TIMESCALE-MISS', 'REFUTED-OTHER']",
      "category": "scientific_refuted",
      "next_action": "T111 dispatch implementer_text to update state.json F1 with REFUTED + reason + N-scaling-caveat. Drop tier 2.5 → 2.0. Recommend N=50k follow-up investigation before abandoning EdH claim entirely. Surface in conclusions/<inv_id>.md."
    },
    {
      "if": "critic-audit-audits-t109-claims failed (<4 SUSTAINED/CHALLENGED/REJECTED tags)",
      "category": "framework_error_critic_underaudit",
      "next_action": "Reject critic deliverable; re-dispatch with explicit reminder that audit of T109 claims A-F is mandatory (critic.md independence requirement)"
    },
    {
      "if": "class-finding-documented failed",
      "category": "framework_error_class_finding_missed",
      "next_action": "Re-dispatch critic with explicit reminder of `feedback_fix_the_class_not_the_instance` requirement; T76-T86 ad-hoc threshold class-finding MUST be documented for the conclusions ledger"
    },
    {
      "if": "no-julia-invoked failed OR no-gpu-used failed",
      "category": "framework_error_constraint_violation",
      "next_action": "Reject critic deliverable; critic is strictly text-only Read-tool per critic.md; re-dispatch with explicit text-only guard"
    },
    {
      "if": "tier_recommended == 3.0",
      "category": "framework_error_tier_overclaim",
      "next_action": "Reject critic deliverable; Stage-1 alone CANNOT support Tier 3.0 — F1 is central falsifier with Stage-1+Stage-2 gate per §F8. Cap at 2.75. Re-dispatch with explicit reminder."
    }
  ],
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 900
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document",
    "if_success_tier_becomes": 2.75,
    "if_partial_advance_to_stage": "Update",
    "if_partial_tier_becomes": 2.5,
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 2.0,
    "if_success_falsifier_update": {
      "id": "F1-ring-appears-correct-timescale",
      "tested_at_turn": 110,
      "result_template": "T110 critic CORROBORATE-STAGE-1: NC1 met (pop_c2 peak 16.3% at t=5.22 ms, K3_long-equivalent of Matsui 5 ms via N^(2/5) scaling factor 1.9 → 2.6 ms with factor-2 band [1.5, 7] ms); symmetry mapping K3_long c=2 ↔ Matsui c=12 verified (Wigner-Eckart + Kawaguchi-Ueda 2012 §5.4); trap (110,110,130) Hz matches to 3 sig figs. Stage-1 qualitative density ring assessable from trajectory.png. Stage-2 Bragg interferometric phase-winding OUT_OF_SCOPE this turn — full Tier-3 requires anko manual run + Bragg-protocol simulation. Tier 2.5 → 2.75."
    },
    "post_t110_pivot_options_by_outcome": [
      "T111 implementer_text Document — update state.json F1 + conclusions/<inv_id>.md + class-finding ledger (if CORROBORATE-STAGE-1)",
      "T111 anko-consult escalation (if INCONCLUSIVE-SPATIAL-REQUIRED — manual `bash runs/eu151_edh_K3_long/run_extract_ring_metrics.sh`)",
      "T111 implementer_text REFUTED-update (if REFUTED-* — state.json + conclusions update + drop tier to 2.0)",
      "T112+ pivot to non-edh-matsui priority investigation (sign-pattern-lemma1 Tier-3, TwoChannelLHY F=6, TDHFB Phase-2 HF generic-F) once edh-matsui reaches its loop-reach ceiling"
    ]
  }
}
```

## 7. Drift advisories — explicit acknowledgement

- **DRIFT_MANUSCRIPT_DELTA_ZERO**: T110 is D1 physics-verification on a central falsifier. Per `feedback_manuscript_is_not_the_essence`: this IS the essence. Structural choice match.

- **DRIFT_COST_INFLATION**: T110 critic expected ~1.8M (text-only Read-bound). Well below T107's 2.13M and far below 5M hard cap. Per `feedback_cost_overhead_is_the_cost`: cost guardrails are hard caps + leverage; both fine.

- **DRIFT_VERDICT_DRIFT (from T107-T109 chain)**: T107 INCONCLUSIVE + T108 INCONCLUSIVE + T109 FAIL_OPERATIONAL (contract-shape only). T110 emits a structured verdict (most likely CORROBORATE-STAGE-1 given NC1 met + symmetry verified + trap match exact). Restores verdict trajectory toward PASS-class outcomes.

- **TOPIC_REPETITION** (anticipated 0.67): edh-matsui at T107+T108+T109+T110 = 4 of last 6. High but priority-0 per seed.md; this is the explicit override condition in the protocol picking table.

All advisories accepted + addressed by structural choice.

## 8. Anti-noop justification

T110 is NOT noop because:
- Scheduler policy JULIA_GPU_OK explicitly permits `critic` (scheduler_110.json line 15).
- Probe shows full headroom (critic is text-only Read).
- T109 substantively unlocked the critic re-audit path — skipping it wastes the T109 deliverable.
- The Artifact-first path (protocol §B) explicitly contemplates this dispatch shape: existing artifact + tier<3 + last verdict NOT substantively-INCONCLUSIVE → critic Update.
- Seed.md mandates edh-matsui as priority 0; F1 is the central falsifier; T110 is the formal-verdict turn.
- Pivoting to a non-priority-0 investigation is poor EV with a queued, ready-to-execute critic dispatch.

## 9. Why this is not "critic-after-critic" overshoot

Past 6 turns subagent classes: impl_text (T105), impl_text (T106), critic (T107), impl_julia (T108), researcher (T109), critic (T110). T110 is the 2nd critic in 6 turns, NOT consecutive. The stop-condition "no more than 2 same-subagent in a row" is satisfied — T108 and T109 between T107 and T110 break the streak. Furthermore, T110's critic has MATERIALLY DIFFERENT inputs from T107 (T109's Matsui methodology + symmetry + N-scaling were absent at T107). This is not a re-audit-with-same-evidence; it is the post-research-anchor audit the protocol explicitly prescribes.

## 10. Preservation of T108 + T109 deliverables

- T108's `extract_ring_metrics.jl` + `run_extract_ring_metrics.sh` remain on disk at `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/`. T110 critic does NOT delete or modify them. They remain available for anko's manual run per sim/turn_108 §10 Option B. If T110 emits INCONCLUSIVE-SPATIAL-REQUIRED, the routing recommendation explicitly points anko to this script.

- T109's `runs/_loop/research/turn_109.md` + `runs/_loop/sim/turn_109.md` are the load-bearing inputs. T110 critic reads them as primary sources; does not duplicate or supersede them. The conclusions/<inv_id>.md update at T111 should cite T109 as the methodology anchor.

## 11. Contract-shape lesson recorded

The T109 FAIL_OPERATIONAL was a director-side contract bug: the `symmetry_mapping_verified_kawaguchi_ueda` criterion was declared with `operator: "in"` against an enum string list, when the question "verified or not" is genuinely yes/no. The researcher correctly emitted boolean `true`. This is a one-line lesson for future researcher contracts:

- Yes/no questions → boolean operator (`== true` or `== false`).
- Extraction-status questions → enum operator (`in ["EXTRACTED", ...]`).
- DO NOT mix the two in a single criterion.

This is NOT a meta-improvement candidate (single contract bug, not a class), but worth a one-line note in the conclusions/<inv_id>.md ledger so future investigations adopt the pattern.

## 12. Closing note

T110 is the audit-with-new-evidence dispatch the protocol prescribes: T109 substantively delivered the Matsui methodology + symmetry mapping + refined criterion; T110 critic synthesizes against K3_long artifacts and issues a formal verdict on the central falsifier F1. Most-likely outcome is CORROBORATE-STAGE-1 with tier 2.5 → 2.75 (full 3.0 deferred to Stage-2 Bragg interferometric simulation, OUT_OF_SCOPE this turn). Alternative outcomes (INCONCLUSIVE-SPATIAL-REQUIRED or REFUTED) route to anko-consult or N=50k follow-up respectively. Either way, T110 closes the loop's longest-running central-falsifier evaluation and unblocks T111's Document/pivot routing.
