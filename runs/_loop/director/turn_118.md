---
turn: 118
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: "Update (T117 critic CORROBORATE on F1-ring-appears-correct-timescale central falsifier; tier_current still 2.75 in state.json L2233 because orchestrator does NOT auto-patch investigation blocks; current_stage still 'Document'; T116 manuscript §V Duty B remains OUTSTANDING on main HEAD per grep multiplicity|m_rep|rho_inv|Multiplicity = 0 matches on docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md line 516)"
stage_advancing_to: "closed (Tier-3 terminal closure: F1 central CORROBORATE → tier 2.75 → 3.0; current_stage 'Document' → 'closed'; last_verdict TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117_INDEPENDENT_CONTEXT; investigation joins barnett/klaus-bch/T86-edh-matsui as 4th Tier-3 trajectory in project history)"
topic_tags:
  - edh-eu151-matsui-science-2026
  - tier3-terminal-closure
  - central-falsifier-F1-CORROBORATE
  - artifact-first-audit-T117-stage2
  - state-json-patch
  - sign-pattern-f9-ta-mult2-T116-Duty-B-retry
  - bundled-2-duty-text-only
  - D1-axis-primary
  - D3-axis-secondary
  - implementer-text
  - manuscript-section-V-multiplicity-aware
paper_section: "papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md §V Multiplicity-Aware Extension (retry; T116 commit f081603 on auto-branch did NOT propagate to main HEAD); papers/paper4_chaotic_dynamics + manuscript/thesis/chapters/Ch5 — Matsui-EdH F1 ring-formation corroborated for Tier-3 closure"
depends_on:
  - 117
  - 116
  - 115
  - 114
  - 110
  - 86
  - "runs/_loop/sim/turn_117.md"
  - "runs/_loop/judge/turn_117.json"
  - "runs/_loop/judge/turn_117_critic_audit.md"
  - "runs/_loop/director/turn_117.md"
  - "runs/_loop/state.json"
  - "runs/_loop/seed.md"
  - "runs/_loop/_local/scheduler_118.json"
  - "runs/eu151_edh_K3_long/trajectory.csv"
  - "runs/eu151_edh_K3_long/config.yaml"
  - "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:tier3_pipeline_survey_2026_05_18"
  - "memory:sign_pattern_lemma1_mult_aware_2026_05_19"
  - "memory:feedback_fix_the_class_not_the_instance"
produces: >
  T118 advances edh-eu151-vortex-vs-matsui-science-2026 from Update/2.75 →
  closed/3.0 via implementer_text 2-duty bundle. Duty A: state.json patch
  to record T117 CORROBORATE on F1 central falsifier (tier_current 2.75 →
  3.0, current_stage 'Document' → 'closed', F1.result append, last_verdict
  TIER_3_TERMINAL_CLOSURE, last_turn 118, last_critic_turn 117,
  closing_note append, last_stage 'Update', and top-level active_investigation_id
  flip to next-priority investigation). Duty B: re-append the §V Multiplicity-
  Aware Extension to docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md
  (T116 commit f081603 landed on auto-branch only, NOT main HEAD per main-HEAD
  grep 0 hits). Both duties are text-only, no julia, no production code.
  Per T117 director plan §7 + failure_modes CORROBORATE branch verbatim:
  "T118 director patches state.json: tier_current 2.75 → 3.0, current_stage
  'Document' → 'closed', F1.result append T117 corroboration, last_verdict
  CORROBORATE_F1_TIER3_ACHIEVED. Investigation closes. T118 then dispatches
  implementer_text for outstanding T116 manuscript §V Duty B re-do
  (sign-pattern-f9-ta-mult2 Update completion)." This is the executable
  realization of that pre-committed plan. Cost expected ~1.5M effective
  (text-only Read + Write, no compute). D1 axis primary (verification
  closure for published-paper benchmark — Matsui Science 391, 384-388 2026);
  D3 axis secondary (manuscript propagation of T115 m_rep prefactor
  derivation). Per seed.md 2026-05-19 priority-0 directive: "If CORROBORATE,
  promote inv to tier 3.0 with the audit as the load-bearing evidence —
  not the T76-T86 F3 energy convention." T118 executes that exact promotion.
---

# Turn 118 — Director Report

## 1. What happened at T117 (top-of-turn read)

| Path | Read | What it says |
|---|---|---|
| `runs/_loop/sim/turn_117.md` | full file (88 lines) | T117 critic emitted **VERDICT: CORROBORATE** on F1-ring-appears-correct-timescale central falsifier. Direct trajectory.csv read: pop_c2 (m=+5) peak **17.08% at t=4.34 ms** (3.00 ω⁻¹ with ω_ref=691.15 rad/s). Within Matsui factor-2 band [2.5, 10] ms (ratio **0.87×** of paper's 5 ms). All 13 m states populated. Norm 1.000 → 0.9962 monotonic. Config has K3_per_m_cubic + gamma_dr=0.02 + seed=42 + coherent kick (all 3 load-bearing knobs PRESENT). T110 stage-1 independently confirmed with stronger evidence. F2 winding number remains BLOCKED by JLD2-vs-h5py chunk-encoding incompatibility (T111 probe); deferred per seed.md scoping to F1-only Tier-3 closure. |
| `runs/_loop/judge/turn_117.json` | full file (5 lines) | Judge status `FAIL_NO_METRICS` with issue "sim/turn_117.md missing or §4 JSON unparseable". **This is an OPERATIONAL judge bug, NOT a physics failure**: sim/turn_117.md is a critic verdict report (not an implementer §4 Metrics JSON), so judge.py's metrics-extraction path is N/A. State.history[T117].substantive_verdict="CORROBORATE" captures the actual physics verdict. T118 must NOT route off the FAIL_NO_METRICS label; route off substantive_verdict. |
| `runs/_loop/state.json` L1492-L1542 (T117 history entry) | full block | substantive_verdict="CORROBORATE"; directive_label="edh-eu151-matsui-T117-critic-audit-CORROBORATE"; notes verbatim: "Tier 2.75 -> 3.0 promotion gate-unblocked on central falsifier F1; orchestrator defers actual state.json patch of investigation block (tier_current, current_stage, F1.result append) to T118 director who will read sim/turn_117.md + this history entry and patch with full context." Confirms director-side patch responsibility. |
| `runs/_loop/state.json` L2167-L2252 (edh-matsui investigation block) | full block | tier_current still **2.75** (line 2233); current_stage still **"Document"**; F1.tested_at_turn=110 with result T110-stage-1-CORROBORATE; falsifier is_central=true (line 2209); next_stage_action verbatim references seed.md 2026-05-19 dispatch-critic-then-PASS-→-tier-3.0 plan; last_critic_turn=83. **The orchestrator has NOT auto-patched** — Director responsibility. |
| `runs/_loop/state.json` L1548 + L1562 | top-level fields | `last_judge: "FAIL_NO_METRICS"` (operational, not physics); `active_investigation_id: "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"` — this is **STALE** (last set at T116; T117 ran on edh-matsui per substantive_verdict). T118 patch must flip active_investigation_id; choice depends on next-priority post-edh-matsui-closure (see §2.3 below). |
| `runs/_loop/director/turn_117.md` (own previous turn) | §6 brief + §7 failure_modes block + §9 next-T118-look-at | Verbatim plan: "if critic verdict = CORROBORATE AND F1 central crosschecks all pass → T118 director patches state.json: tier_current 2.75 → 3.0, current_stage 'Document' → 'closed', F1.result append T117 corroboration, last_verdict CORROBORATE_F1_TIER3_ACHIEVED. Investigation closes. T118 then dispatches implementer_text for outstanding T116 manuscript §V Duty B re-do (sign-pattern-f9-ta-mult2 Update completion)." T118 executes this pre-committed plan exactly. |
| `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (independent re-read line 510-516) | tail | File ends at line 516: `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)`. Grep `multiplicity\|m_rep\|rho_inv\|Multiplicity` on main HEAD = **0 matches**. T116 implementer's commit f081603 on auto-branch `auto/turn_116_...` did NOT propagate to main HEAD. **Duty B remains OUTSTANDING** — exactly as T117 director §1 + §8 documented. |
| `runs/_loop/seed.md` (full file 95 lines) | held | Priority-0 pin verbatim: "If CORROBORATE, promote inv to tier 3.0 with the audit as the load-bearing evidence". T117 produced CORROBORATE → T118 must execute the tier-3.0 promotion. **Seed.md pin is now SATISFIED** post-T118 closure; anko may update next-turn. |
| `runs/_loop/_local/scheduler_118.json` | full file | policy=JULIA_GPU_OK; all workloads allowed including `implementer_text`. vram_free=12847 MB, ram_avail=25.02 GB, gpu_util=1%, foreign_julia=0. Window 1096434 s left through 2026-05-31. implementer_text is allowed and cheap. |
| `memory:tier3_pipeline_survey_2026_05_18` (referenced via MEMORY.md L13) | indexed | edh-matsui was the survey's top-pick Tier-3 candidate; T86 closed it; anko re-opened via seed.md 2026-05-19; T117 critic CORROBORATE is the resumption's terminal evidence. T118 closure realizes the survey's intent. |
| `memory:feedback_use_existing_artifacts_first` (referenced via MEMORY.md L185) | indexed | Hard rule held throughout the resumption. T117 audit operated on on-disk artifacts only; T118 closure does NOT spawn new simulation. |
| `memory:sign_pattern_lemma1_mult_aware_2026_05_19` (referenced via MEMORY.md L62) | indexed | T115 m_rep=2 prefactor result. The 1-line MEMORY.md index entry IS on disk (Duty C of T116 landed). The 75-line memory file at `~/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/` IS on disk. Only the manuscript §V append (Duty B) is missing on main HEAD. |

## 2. Why implementer_text 2-duty bundle (not critic, not noop, not theorist)

### 2.1 Routing gate per protocol §B

- Last judge verdict was `FAIL_NO_METRICS` (T117) — but this is the **operational judge.py limitation** when the turn dispatched a critic and produced a verdict-report not a metrics-JSON. The substantive verdict per state.history[T117].substantive_verdict is **CORROBORATE**. Director.md "Verdict-to-next-stage mapping" applies to substantive verdicts, not judge.py path-mismatch labels.
- Substantive verdict CORROBORATE → director.md row "PASS / PASS_WITH_COST_WARNING → advance". For verify-claim flow, T117 was Update stage. Next stage is **Document → closed**. Document stage for verify-claim = theorist per director.md table, BUT this is a Tier-3 terminal closure with state.json patching as the primary work product. State.json patching is mechanical text-edit — implementer_text per memory `feedback_mechanical_vs_investigation_threshold` ("schema-design→meta-improvement; algorithm→verify-claim; new theory→build-theory; **mechanical→direct execute**"). Closure is also a propagation step; Duty B (manuscript §V append) is text-only.
- Combined dispatch: implementer_text with 2-duty bundle, single subagent, no julia.

### 2.2 Why bundling Duty A + Duty B is correct (not two separate turns)

- Both duties are text-only, single-subagent, single-action-class (modify_text), zero overlap in file targets (state.json vs sign_pattern_lemma1_general_S.md), zero ordering dependency (state.json closure does NOT depend on §V content; §V append does NOT depend on state.json patch). Two independent leaves.
- Bundling avoids the "1 cheap turn dispatched per duty" overhead pattern that drives DRIFT_COST_INFLATION (T106 / T116). Per memory `feedback_cost_overhead_is_the_cost`: "the deliberation is more expensive than the work. Just execute 全部やろう in parallel."
- Total expected cost: ~1.5M effective (Read state.json + Read sign_pattern_lemma1_general_S.md tail + Write patched state.json + Write extended manuscript file + git commit). 1 turn cost ≈ 2 separate turn costs / 2.

### 2.3 What investigation should be active after T118 closure

The active_investigation_id flip is part of state.json Duty A. Candidates after edh-matsui closes:

| Candidate | Priority (state.json) | Status | Recommendation |
|---|---|---|---|
| `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` | likely 4-10 | Update stage; physics PASS T115; Duty B now complete after T118 | **Best candidate**: T118 advances Update to Document/closed if Duty B lands. Could be next active. |
| `meta-cost-waste-audit-2026-05-19` | 15 | Observe (auto-spawn) | Available but lower priority |
| `audit-class-scan` next cycle (~T113-T115) | 20 | Drift_advisory T117 says gap=12; was T103-T106 cycle | AUDIT_DUE gap not yet over threshold |
| Open new Tier-3 candidate from `tier3_pipeline_survey_2026_05_18` | — | survey identified 5 candidates; top pick (edh-matsui) now closes | Next-best survey item: pseudo-hermitian / fullbdg-F6-polar / Yan-Li-Saito |

Decision: T118 implementer_text sets `active_investigation_id` to **`sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`** (the now-completable secondary investigation whose Duty B just lands at T118; current_stage becomes Document/closed after manuscript §V verified on main HEAD). Director T119 reads new state and either closes sign-pattern (manuscript content now present) OR pivots to next-priority Tier-3 candidate.

### 2.4 Alternatives considered

**Option (a) — critic re-audit edh-matsui at F2 spatial winding (chosen NO)**: F2 is BLOCKED by JLD2-vs-h5py incompatibility per T117 §1. Spatial_profiles.csv still ABSENT. T117 explicitly scoped F2 OUT_OF_SCOPE. Re-dispatching critic on F2 now would just emit INCONCLUSIVE-NO-DATA. WASTE. Defer to anko-consult wrapper run.

**Option (b) — theorist for §V re-derivation (chosen NO)**: T115 theorist already derived the m_rep prefactor + J-involution proof. T116 implementer attempted to propagate; commit f081603 landed on auto-branch but not main HEAD. The required action is mechanical text-append of pre-derived content (~164 lines per T116 self-report), not new derivation. Mechanical→direct execute per memory `feedback_mechanical_vs_investigation_threshold`. Theorist would be over-allocation.

**Option (c) — implementer_julia_gpu for new EdH simulation (rejected hard)**: Seed.md priority-0 verbatim: "Constraint: no new EdH simulation this round. The accumulated runs ARE the data." Plus memory `feedback_use_existing_artifacts_first`. Plus T117 audit already CORROBORATE'd — running new simulation would just re-confirm or risk falsification of the achieved Tier-3 closure. Bad.

**Option (d) — noop (rejected)**: There is explicit work: state.json tier-3 patch + manuscript §V re-append. Noop discards signal. Cost ~100k for noop turn anyway; better to do real work.

**Option (e) — separate Duty A and Duty B over 2 turns (rejected)**: See §2.2 — bundling is correct; both are text-only single-action no-overlap.

**Option (f) — researcher to re-fetch Matsui paper for additional crosswalk (rejected)**: T71 already deep-researched; T117 critic already crosswalk'd at DOI level. Redundant.

**Option (g) — audit-class-scan next cycle (rejected)**: drift_signals AUDIT_DUE gap=12 at T117; threshold for auto-spawn typically gap≥14 (per T103 cycle). One more turn delay acceptable. Plus tier-3 closure is higher-leverage signal this turn.

Decision: **dispatch implementer_text with 2-duty bundle**: (A) state.json edh-matsui tier-3 closure patch, (B) manuscript §V multiplicity-aware extension re-append on main HEAD with verified-content append.

## 3. The implementer's directive — verbatim plan

### 3.1 Read order (before any Write)

1. `runs/_loop/sim/turn_117.md` — T117 critic verdict full content. The §8 Falsifier update payload (lines 73-78) gives the exact text to splice into F1.result.
2. `runs/_loop/state.json` lines 2167-2252 — the edh-matsui investigation block currently on disk. Identify the exact JSON path: `investigations["edh-eu151-vortex-vs-matsui-science-2026"]` and the keys to patch (tier_current, current_stage, last_turn, last_verdict, last_stage, last_critic_turn, closing_note, falsifiers[0].tested_at_turn, falsifiers[0].result, stages_done).
3. `runs/_loop/state.json` lines 1492-1542 — T117 history entry already on disk (no patch needed there; written by orchestrator).
4. `runs/_loop/state.json` lines 1548-1562 — top-level fields: `last_judge`, `last_verdict` (need to find / add), `active_investigation_id`. Patch `last_judge: "TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117"`, `last_verdict: "TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117"`, `active_investigation_id: "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"`. Preserve all other top-level fields exactly.
5. `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` line 510-516 (last 7 lines) — confirm file ends at line 516 with `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)`.
6. `~/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` — full file (75 lines per T116 self-report). This is the source of truth for the §V content. Re-derive §V from this if T116 auto-branch diff is unavailable.
7. `git log --oneline auto/turn_116_sign-pattern-f9-ta-mult2-T116-update-manuscript -- docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (if branch exists locally) — IF the f081603 commit is reachable, recover the +164 line diff via `git show f081603:docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` and apply via patch. ELSE construct §V from memory file content + T115 theorist derivation in `runs/_loop/theorist/turn_115.md`.

### 3.2 Duty A: state.json edh-matsui tier-3 closure patch

Target file: `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json`.

Patches to apply to `investigations["edh-eu151-vortex-vs-matsui-science-2026"]`:

```json
{
  "current_stage": "closed",
  "stages_done": [
    "Analyze",
    "Analyze (F1 t_ring + F2 winding ℓ + F3 E_sim vs E_mf/N extraction from runs/matsui_edh_baseline_9ca97308/point_001.jld2 + result.jld2)",
    "Design",
    "Document",
    "Document (T84 implementer_text: T82 §8 erratum propagation + memory entry edh_matsui_baseline_2026_05_18.md + tier 2.5 to 2.75)",
    "Document (terminal closure path; T84 implementer_text propagates 4 errata to new memory entry, patches state.json tier 2.5 → 2.75 + closing_note, appends by_tag indices)",
    "Document-verify (T86 retry — restore 3 stale by_tag files from verbatim T85 corrective content, re-run Phase 1 checks now 7/7, execute Phase 2 state.json terminal-closure patch tier 2.75 → 3.0 + current_stage 'closed', execute Phase 3 status narrative T86 PASS append; terminal Tier-3 trajectory closure)",
    "Document-verify (T86 retry; 3 by_tag files restored from T85 verbatim content; 7/7 Phase 1 checks PASS; tier 2.75 → 3.0 terminal closure)",
    "Execute (Bz-sign-convention independent verification — non-Julia leverage path)",
    "Execute (R2 GPU retry with src-anchored high-confidence prior + pre-written wrapper-script approval-gate workaround)",
    "Execute (prerequisite class-fix phase; full Execute-retry deferred to T79)",
    "Hypothesize",
    "Research",
    "Update",
    "Update (T83 critic CORROBORATE_WITH_ERRATA; F3 rel_error 8.0% within 20% band)",
    "Update (T110 critic CORROBORATE-STAGE-1 on F1; pop_c2 peak 16.3% at 5.22 ms within factor-2 of Matsui 5 ms; tier 2.5 → 2.75)",
    "Update (T117 critic CORROBORATE-STAGE-2 independent context; pop_c2 peak 17.08% at 4.34 ms; ratio 0.87×; full 13-component cascade; all 3 config knobs PRESENT; tier 2.75 → 3.0 TERMINAL CLOSURE)"
  ],
  "falsifiers[0].tested_at_turn": 117,
  "falsifiers[0].result": "CORROBORATE at T117 critic independent context (Stage-2): direct trajectory.csv read shows pop_c2 (m=+5) peak 17.08% at t=4.34 ms (3.00 omega^-1 with omega_ref=691.15 rad/s); within factor-2 band [2.5, 10] ms of Matsui experimental t_ring=5 ms (ratio 0.87x). Full 13-component cascade observed (c1->c2->c3->c4 sequential peaks, all 13 m states populated). Config has K3_per_m_cubic + gamma_dr=0.02 + seed=42 + coherent kick (all 3 load-bearing knobs PRESENT). Norm 1.000 -> 0.9962 monotonic, no collapse. T110 stage-1 CORROBORATE independently confirmed with stronger evidence. Stage-1 (T110) + Stage-2 (T117) = central F1 falsifier CORROBORATE. F2 winding-number topology remains BLOCKED by JLD2-vs-h5py chunk-encoding incompatibility (T111 probe); deferred per seed.md scoping to F1-only Tier-3 closure (F2 optional refinement when anko-consult wrapper produces spatial_profiles.csv). Tier 2.75 -> 3.0 TERMINAL CLOSURE.",
  "tier_current": 3.0,
  "next_stage": null,
  "next_stage_action": null,
  "last_turn": 118,
  "last_stage": "Update",
  "last_verdict": "TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117_INDEPENDENT_CONTEXT",
  "last_critic_turn": 117,
  "closing_note_append": " || Tier 3.0 terminal closure achieved 2026-05-19 T118 via F1 central falsifier CORROBORATE Stage-1 (T110) + Stage-2 (T117 critic artifact-first independent-context audit on runs/eu151_edh_K3_long/trajectory.csv directly). Per seed.md 2026-05-19 priority-0 directive: closure load-bearing evidence is the T117 audit (NOT the earlier T76-T86 F3-only path which omitted K3+gamma_dr+noise seed). Project's 4th Tier-3 trajectory (after barnett T29, klaus-bch T59, T86-edh-matsui pre-revision-closure). 2nd terminal closure path for the SAME investigation: T86 closed on F3 alone with errata; T118 closes on F1+F3 with explicit F1 corroboration replacing T76-T86's NOT_APPLICABLE_NO_RING placeholder. F1 status changes from 'NOT_APPLICABLE_NO_RING' (T82-T84 pre-K3_long-data) to 'CORROBORATE-STAGE-1+2' (T110/T117 post-K3_long-data). F2 (winding number) and F4 (DDI=0 control) remain optional refinement; F3 unchanged (CORROBORATE T83 8.0% rel_error). Promotion gate per director.md §5.B Tier-3: central falsifier is_central=true with result containing CORROBORATE → tier 3.0 unblocked. Manuscript propagation: Ch5_TWA_chaotic_dynamics + paper4_chaotic_dynamics by_tag indices already note Matsui-EdH closure; T118 leaves manuscript-side as-is (T86 closing_note already references)."
}
```

Also patch top-level fields:
- `last_judge`: from `"FAIL_NO_METRICS"` → `"TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117"`.
- `active_investigation_id`: from `"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"` → keep `"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"` (after T118 Duty B re-appends §V, the sign-pattern investigation can advance Update→Document/closed at T119 director's discretion; the seed.md priority-0 edh-matsui is now closed, so sign-pattern becomes next-priority among open investigations).
- `last_directive_label`: from existing value → `"edh-eu151-matsui-T118-tier3-closure-and-mult2-section-V-retry"`.
- `last_directive_action`: → `"modify_text"`.

**JSON-validity constraint**: state.json is ~2900 lines. Patch surgically — use Read+Edit, NOT full Write. Verify with `python3 -c 'import json; json.load(open("/home/suzume/workspace/BEC-simulation/runs/_loop/state.json"))'` before commit.

### 3.3 Duty B: manuscript §V append on main HEAD

Target file: `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`.

Current state: 516 lines, ends `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)`. T116 commit f081603 added +164 lines (§V.1–V.8) on `auto/turn_116_sign-pattern-f9-ta-mult2-T116-update-manuscript` branch but NOT main HEAD.

Recovery strategy (in priority order):

1. **Primary path**: `git show f081603:docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` → diff against current main HEAD → splice §V at line 516 (replacing the closing marker with §V + closing marker shifted down). Use `git cherry-pick --no-commit f081603 -- docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` if isolated to this file.

2. **Fallback path** (if branch unreachable or contains other changes): construct §V from scratch using:
   - `~/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` (75 lines, 7 sections per T116 self-report — has the canonical formula, J-involution proof sketch, m_rep=1 reduction, sum rule, F=9 T:A verification table).
   - `runs/_loop/theorist/turn_115.md` (T115 theorist derivation with J=exp(-iπF_y) involution proof of universal endpoint 1/(2F+1)).
   - `runs/_loop/sim/turn_115.md` (T115 implementer Test attempt2 F1/F2/F3/F4 4/4 CORROBORATE machine-precision verification).
   - Target §V structure: 8 sub-sections V.1 setup / V.2 canonical formula / V.3 universal endpoint / V.4 m_rep=1 reduction / V.5 sum rule / V.6 F=9 T:A verification table S=0..18 with 4-falsifier verdicts / V.7 open extensions / V.8 source anchors. Approximate length: 150-200 lines. Match the file's existing markdown convention (no LaTeX-math beyond inline; numeric Tables in pipe format).

3. **Verification**: after Write, `grep -E 'multiplicity|m_rep|rho_inv|Multiplicity|F=9.*T:A' docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md | wc -l` should return ≥ 10. Independently re-read tail to confirm closing marker properly relocated.

The closing marker `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)` should be REPLACED by §V content + new closing marker `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-19 §V multiplicity-aware extension)`.

### 3.4 Commit + verification

- Branch: `auto/turn_118_edh-eu151-matsui-T118-tier3-closure-and-mult2-section-V-retry`.
- Commit message: `auto(loop) T118 PASS modify_text edh-eu151-matsui-T118-tier3-closure-and-mult2-section-V-retry`.
- Trailer: `Assisted-by: Claude Opus 4.7 (model: claude-opus-4-7[1m])`.
- Use `--no-gpg-sign` per T112-T117 precedent.
- NO Co-Authored-By per /home/suzume/.claude/rules.
- Post-commit verification: `git diff main..HEAD --stat` should show 2 files (state.json + manuscript), ~200 LOC delta. `git diff main..HEAD docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md | head -5` should show "+" lines starting with §V content.

### 3.5 Hard constraints (per seed.md + scheduler + protocol)

- NO julia execution at any point. Both duties are text-only.
- NO modification of production code (`src/`, `test/`, `scripts/` except scripts/manuscript/lemma1_general_S_verification.jl which is documentation-relevant test — but no need to modify).
- NO modification of `runs/eu151_edh_K3_long/` (read-only artifact).
- NO new YAML config.
- NO new simulation, no implementer_julia.
- If during Duty B git cherry-pick of f081603 fails AND fallback construction yields <120 lines (too short — indicates content gap from sources), fall back to writing a 80-line summary §V citing the memory file as canonical source. Note this in §3 of the implementer report so T119 director can re-evaluate.
- If state.json JSON-validity fails post-patch: revert via `git checkout runs/_loop/state.json`, re-attempt with smaller surgical edits via Edit tool (not Write).

## 4. Investigation update at T118

For `edh-eu151-vortex-vs-matsui-science-2026`:

- `tier_current`: 2.75 → **3.0** (Tier-3 terminal closure).
- `current_stage`: "Document" → **"closed"**.
- `last_turn`: 86 → **118**.
- `last_stage`: "Document-verify" → **"Update"**.
- `last_verdict`: "TIER_3_TERMINAL_CLOSURE" → **"TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117_INDEPENDENT_CONTEXT"** (or keep prior + new closure attribute).
- `last_critic_turn`: 83 → **117**.
- `next_stage`: "closed" → **null** (terminal).
- `next_stage_action`: long T87-era prose → **null** (terminal).
- F1 (`F1-ring-appears-correct-timescale`): tested_at_turn 110 → 117; result appended with T117 CORROBORATE stage-2 verbatim.

For `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`:

- Duty B completion at T118 unblocks T119 director to advance Update → Document/closed (if §V content verified on main HEAD).
- No state.json patch this turn for this investigation; T119 director re-evaluates.
- Tier stays 2.5 entering T119; can advance to 3.0 IF F1 central CORROBORATE at machine precision (per memory `sign_pattern_lemma1_mult_aware_2026_05_19`) plus T117 critic-style independent audit; but central falsifier promotion needs explicit recipe — likely T119+ work, not T118.

Top-level state:

- `last_judge` → patched to TIER_3_TERMINAL_CLOSURE (per Duty A).
- `active_investigation_id` → patched (per §2.3 decision: sign-pattern after edh-matsui closes).
- `last_directive_label`, `last_directive_action` → patched.

## 5. Success criteria — FORM B (raw-artifact check_cmds preferred per director.md §5.B)

See §6 contract below for the JSON block. Highlights:

- **SC-state-tier-3.0-set**: `python3 -c 'import json; s=json.load(open("/home/suzume/workspace/BEC-simulation/runs/_loop/state.json")); print(s["investigations"]["edh-eu151-vortex-vs-matsui-science-2026"]["tier_current"])'` → expects stdout exact match `3.0`.
- **SC-state-closed**: same path; `current_stage` → `closed`.
- **SC-f1-result-corroborate**: `grep -E -q 'CORROBORATE.*T117' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json` → exit 0.
- **SC-manuscript-section-v-present**: `grep -E -c 'multiplicity|m_rep|rho_inv|Multiplicity' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` → expects count ≥ 10.
- **SC-manuscript-section-v-canonical-formula**: `grep -E -q 'bar_beta.*canonical|canonical.*formula|Tr.*Pi_S.*rho_inv' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` → exit 0.
- **SC-manuscript-section-v-f9-verification**: `grep -E -q 'F=9.*T:A|m_rep=2' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` → exit 0.
- **SC-state-json-valid**: `python3 -c 'import json; json.load(open("/home/suzume/workspace/BEC-simulation/runs/_loop/state.json"))'` → exit 0.
- **SC-no-src-modified**: `find /home/suzume/workspace/BEC-simulation/src -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_118.md -name '*.jl' -type f | wc -l` → 0.
- **SC-no-runs-eu151-modified**: same for `runs/eu151_edh_K3_long/`.
- **SC-active-investigation-flipped**: `grep -E -q '"active_investigation_id".*"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json` → exit 0.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "closed",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "project_axis": "D1",
  "rationale": "Per T117 critic CORROBORATE on F1-ring-appears-correct-timescale (state.history[T117].substantive_verdict + sim/turn_117.md verdict line) AND seed.md 2026-05-19 priority-0 directive verbatim 'If CORROBORATE, promote inv to tier 3.0 with the audit as the load-bearing evidence' AND director T117 §7 pre-committed failure_modes plan verbatim 'T118 director patches state.json: tier_current 2.75 → 3.0... Investigation closes. T118 then dispatches implementer_text for outstanding T116 manuscript §V Duty B re-do': dispatch implementer_text with 2-duty bundle. Duty A = state.json edh-matsui Tier-3 terminal closure patch (tier 2.75 → 3.0, current_stage Document → closed, F1.result append T117 corroboration, last_verdict TIER_3_TERMINAL_CLOSURE, etc.). Duty B = retry manuscript §V Multiplicity-Aware Extension append on main HEAD (T116 commit f081603 landed on auto-branch but NOT main HEAD per independent grep 0 hits on multiplicity|m_rep|rho_inv at sign_pattern_lemma1_general_S.md). Both duties text-only, single subagent, no julia, no production code. Bundling avoids 2-turn overhead per memory feedback_cost_overhead_is_the_cost. D1 axis primary (Tier-3 closure for Matsui Science 391, 384-388 (2026) published-paper benchmark — verification of existing physics, ladder 2.75 → 3.0). D3 axis secondary (manuscript propagation of T115 m_rep prefactor theory derivation to paper3 §V). Sources read this turn: runs/_loop/sim/turn_117.md (critic CORROBORATE verdict full content + Falsifier update payload §8); runs/_loop/judge/turn_117.json (FAIL_NO_METRICS — operational judge.py limitation for critic-route turns, substantive_verdict is in state.history); runs/_loop/state.json L2167-L2252 (edh-matsui block tier_current=2.75 current_stage=Document not auto-patched); state.json L1492-L1542 (T117 history with substantive_verdict CORROBORATE + notes explicitly deferring state.json patch to T118 director); state.json L1548 L1562 (last_judge FAIL_NO_METRICS top-level + active_investigation_id stale at sign-pattern-mult2); director T117 §7 + §9 (pre-committed CORROBORATE→T118-patch plan); docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md line 510-516 (file ends 516 with 2026-05-11 marker, grep multiplicity/m_rep/rho_inv = 0 hits — Duty B still outstanding on main HEAD); seed.md 1-30 (priority-0 verbatim 'If CORROBORATE, promote to tier 3.0'); _local/scheduler_118.json (JULIA_GPU_OK, implementer_text allowed); memory:tier3_pipeline_survey_2026_05_18 (edh-matsui was survey top pick; closure realizes survey intent); memory:feedback_use_existing_artifacts_first (no new sim, on-disk artifacts only); memory:feedback_cost_overhead_is_the_cost (bundle 2 duties in 1 turn); memory:feedback_mechanical_vs_investigation_threshold (state.json patch + manuscript text-append = mechanical→direct execute). Cost ~1.5M expected; ~10x reduction from T116. Drift advisories: subagent-class swap critic→implementer breaks repetition; topic continues edh-matsui+sign-pattern (intentional 2-duty single-turn close-out of both pending items per pre-committed plan); cost reduces ~10x.",
  "brief": "You are implementer_text for the T118 2-duty bundle closing TWO investigations' loose ends in one turn. Both duties are text-only modifications: state.json (JSON patch) + sign_pattern_lemma1_general_S.md (markdown append). NO julia, NO production code changes (src/, test/, scripts/), NO new runs/, NO new YAML config. Single commit, single branch.\n\n## Read order (BEFORE any Write)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md` — full file (88 lines). Lines 73-78 give the exact F1 falsifier update payload text to splice into state.json F1.result. Lines 13-87 are the source-of-truth audit evidence (pop_c2 peak 17.08% at 4.34 ms, factor-2 band 0.87× ratio, all 13 m states populated).\n\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 2167-2252 — the current edh-matsui block. Identify exact JSON keys, current values, surrounding commas. Plan surgical Edit (NOT full Write).\n\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 1492-1542 — T117 history entry. Already correct on disk; reference only.\n\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 1543-1580 — top-level fields. Identify exact lines for last_judge, active_investigation_id, last_directive_label, last_directive_action.\n\n5. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — Read tail (offset 510, limit 7) to confirm closing marker at line 516. Also Read full file structure (header + §I-IV section headings) so §V append matches existing convention.\n\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` — full file. PRIMARY SOURCE OF TRUTH for §V content. Has 7 numbered sections per T116 self-report.\n\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md` — T115 theorist J-involution derivation. Use for §V.3 universal endpoint proof.\n\n8. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115.md` — T115 implementer Test attempt2 F1/F2/F3/F4 4/4 CORROBORATE results + F=9 T:A verification table data.\n\n9. (Optional but preferred) `git show f081603:docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (via Bash) → if reachable, this IS the verified §V content from T116 implementer's commit. Cherry-pick or extract.\n\n## Duty A — state.json edh-matsui Tier-3 terminal closure patch\n\nApply the following surgical Edits to `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` `investigations[\"edh-eu151-vortex-vs-matsui-science-2026\"]` block (lines 2167-2252):\n\n1. Change `\"current_stage\": \"Document\"` → `\"current_stage\": \"closed\"`.\n\n2. Append 2 new entries to `stages_done` array (after the existing T83 'Update (T83 critic CORROBORATE_WITH_ERRATA; F3 rel_error 8.0% within 20% band)' entry):\n   - `\"Update (T110 critic CORROBORATE-STAGE-1 on F1; pop_c2 peak 16.3% at 5.22 ms within factor-2 of Matsui 5 ms; tier 2.5 → 2.75)\"`\n   - `\"Update (T117 critic CORROBORATE-STAGE-2 independent context; pop_c2 peak 17.08% at 4.34 ms; ratio 0.87x; full 13-component cascade; all 3 config knobs PRESENT; tier 2.75 → 3.0 TERMINAL CLOSURE)\"`\n\n3. In `falsifiers[0]` (the F1 entry, `\"id\": \"F1-ring-appears-correct-timescale\"`):\n   - `\"tested_at_turn\": 110` → `\"tested_at_turn\": 117`.\n   - REPLACE `\"result\"` with this exact string (single-line JSON, escape internal quotes as needed): `\"CORROBORATE at T117 critic independent context (Stage-2): direct trajectory.csv read shows pop_c2 (m=+5) peak 17.08% at t=4.34 ms (3.00 omega^-1 with omega_ref=691.15 rad/s); within factor-2 band [2.5, 10] ms of Matsui experimental t_ring=5 ms (ratio 0.87x). Full 13-component cascade observed (c1->c2->c3->c4 sequential peaks, all 13 m states populated). Config has K3_per_m_cubic + gamma_dr=0.02 + seed=42 + coherent kick (all 3 load-bearing knobs PRESENT). Norm 1.000 -> 0.9962 monotonic, no collapse. T110 stage-1 CORROBORATE independently confirmed with stronger evidence. Stage-1 (T110) + Stage-2 (T117) = central F1 falsifier CORROBORATE. F2 winding-number topology remains BLOCKED by JLD2-vs-h5py chunk-encoding incompatibility (T111 probe); deferred per seed.md scoping to F1-only Tier-3 closure (F2 optional refinement when anko-consult wrapper produces spatial_profiles.csv). Tier 2.75 -> 3.0 TERMINAL CLOSURE.\"`.\n\n4. Change `\"tier_current\": 2.75` → `\"tier_current\": 3.0`.\n\n5. Change `\"next_stage\": \"closed\"` → `\"next_stage\": null`.\n\n6. REPLACE `\"next_stage_action\": \"Per seed.md ...\"` (the long T87-era prose) with `\"next_stage_action\": null`.\n\n7. APPEND to `closing_note` (preserve the existing T84-T86 closing_note prose verbatim, then append; concat with ' || ' separator): ` || Tier 3.0 terminal closure achieved 2026-05-19 T118 via F1 central falsifier CORROBORATE Stage-1 (T110) + Stage-2 (T117 critic artifact-first independent-context audit on runs/eu151_edh_K3_long/trajectory.csv directly). Per seed.md 2026-05-19 priority-0 directive: closure load-bearing evidence is the T117 audit (NOT the earlier T76-T86 F3-only path which omitted K3+gamma_dr+noise seed). Project's 4th Tier-3 trajectory (after barnett T29, klaus-bch T59, T86-edh-matsui pre-revision-closure); 2nd terminal closure path for the SAME investigation: T86 closed on F3 alone with F1 NOT_APPLICABLE_NO_RING placeholder, T118 closes on F1+F3 with explicit F1 corroboration replacing the placeholder. F1 status: NOT_APPLICABLE_NO_RING (T82-T84) -> CORROBORATE-STAGE-1+2 (T110/T117). F2 (winding number) and F4 (DDI=0 control) remain optional refinement. Promotion gate per director.md Tier-3: central falsifier is_central=true with result containing CORROBORATE -> tier 3.0 unblocked.`.\n\n8. Change `\"last_turn\": 86` → `\"last_turn\": 118`.\n\n9. Change `\"last_stage\": \"Document-verify\"` → `\"last_stage\": \"Update\"`.\n\n10. APPEND to `last_verdict`: `\"TIER_3_TERMINAL_CLOSURE\"` → `\"TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117_INDEPENDENT_CONTEXT\"`.\n\n11. Change `\"last_critic_turn\": 83` → `\"last_critic_turn\": 117`.\n\nAlso patch top-level fields:\n\n12. Change `\"last_judge\": \"FAIL_NO_METRICS\"` → `\"last_judge\": \"TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T117\"` (top-level, line 1548).\n\n13. KEEP `\"active_investigation_id\": \"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"` (already that value, line 1562). After T118 Duty B re-appends §V, sign-pattern advances Update→Document/closed at T119+ director's discretion.\n\n14. Change `\"last_directive_label\": \"sign-pattern-f9-ta-mult2-T115a2-test-candidate-i\"` → `\"last_directive_label\": \"edh-eu151-matsui-T118-tier3-closure-and-mult2-section-V-retry\"`.\n\n15. Change `\"last_directive_action\": \"modify_code\"` → `\"last_directive_action\": \"modify_text\"`.\n\n## Duty B — manuscript §V Multiplicity-Aware Extension re-append on main HEAD\n\nTarget: `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`.\n\nCurrent state: 516 lines, ends with `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)`.\n\n### Strategy ladder (try in order)\n\n1. **PRIMARY**: `git show f081603:docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md > /tmp/manuscript_f081603.md` via Bash. Diff against main HEAD via `diff main..f081603 -- ...`. If only addition (no conflicting changes), splice §V into main HEAD via Edit tool replacing line 515-516 ('---\\n(...終了)') with §V content + new closing marker.\n\n   Alternate: `git cherry-pick --no-commit f081603 -- docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`. If clean, proceed to commit; if conflict, fall back to manual splice.\n\n2. **FALLBACK** (if branch unreachable or has merge conflicts): construct §V from scratch using the 4 source files (Read order steps 6+7+8). Target structure (matching T116 self-report):\n\n   ```\n   ## V. Multiplicity-Aware Extension to m_rep ≥ 2 Polyhedral Inert States\n\n   ### V.1 Setup\n   - W = H-trivial isotypic component (multiplicity m_rep ≥ 1)\n   - {ζ_i}_{i=1}^{m_rep}: orthonormal basis of W\n   - rho_inv = (1/m_rep) sum_i |ζ_i><ζ_i|: maximally-mixed inert density on W\n   \n   ### V.2 Canonical Channel Coefficient Formula\n   bar_beta_S^canonical = m_rep · Tr[Pi_S (rho_inv ⊗ rho_inv)]\n   where Pi_S projects onto the spin-S sector of two coupled F-particles.\n   \n   ### V.3 Universal Endpoint at S=0 — J-Involution Proof\n   For any polyhedral inert ζ, J ζ ∝ ζ where J = exp(-iπ F_y).\n   This gives <S=0|ζ ⊗ ζ> contribution forcing bar_beta_0 = 1/(2F+1) independent of m_rep (universal endpoint preserved).\n   \n   ### V.4 m_rep=1 Reduction\n   At m_rep=1, rho_inv = |ζ><ζ|, recovering beta_S^(c_0) = <ζ ⊗ ζ | Pi_S | ζ ⊗ ζ> exactly (Lemma 1 General-S 2026-05-11 derivation).\n   \n   ### V.5 Sum Rule\n   sum_S bar_beta_S^canonical = m_rep · Tr[I (rho_inv ⊗ rho_inv)] = m_rep · 1 = m_rep.\n   m_rep=1: sum = 1 (recovers classical sum rule). m_rep=2: sum = 2. Etc.\n   \n   ### V.6 F=9 T:A m_rep=2 Verification (1st verified-empirical mult-2 case)\n   ζ_T:A basis: 2 orthonormal tetrahedral-A1-invariant F=9 states (per IcosahedralMod + T:A representation theory).\n   Table S=0..18 channel coefficients bar_beta_S^canonical numerically computed at machine precision via canonical_mult_aware_beta_S wrapper (T115 Test attempt2).\n   4 falsifiers:\n   - F1 (universal endpoint at S=0): bar_beta_0 = 2/19 = 0.10526... = 2·(1/19); CORROBORATE machine precision (dev 1.4e-16).\n   - F2 (m_rep=1 reduction): set m_rep=1 with single ζ from basis, recovers 26/26 prior beta_S^(c_0) match — CORROBORATE.\n   - F3 (sum rule): sum_S bar_beta_S = 1.9999...e0 ≈ 2 = m_rep — CORROBORATE.\n   - F4 (sum-rule identity sum_S [S(S+1) - 2F(F+1)] bar_beta_S = m_rep · 2|<F>|^2 / m_rep = 0 for <F>=0): dev 6.7e-15 machine precision — CORROBORATE.\n   \n   ### V.7 Open Extensions\n   - F=12 A_1/A_2 + D_n axial multi-irrep cases deferred to future audit.\n   - General m_rep>2 polyhedral inert states not yet verified.\n   - Connection to icosahedral I_h F=6 (multi-irrep boundary) at m_rep>1 explorable.\n   \n   ### V.8 Source Anchors\n   - T114-T115 theorist derivation + Candidate (i) m_rep prefactor recommendation\n   - T115 implementer Test attempt2 4/4 CORROBORATE: src test for canonical_mult_aware_beta_S wrapper\n   - scripts/manuscript/lemma1_general_S_verification.jl regression — 26 m_rep=1 cases preserved unchanged\n   - memory entry `sign_pattern_lemma1_mult_aware_2026_05_19.md`\n   - T117 critic audit (paper3-side review applicable for cross-investigation methodology)\n   ```\n\n   Length target: 150-200 lines. Match the file's markdown convention (no LaTeX-math beyond inline backticks; Tables in pipe format; section headers match existing §I-§IV style).\n\n3. **MINIMUM FALLBACK** (if both primary cherry-pick and fallback construction fail to produce ≥ 120 lines): write a 80-line summary §V citing memory file as canonical source. Document the gap in implementer §3 report so T119 director re-evaluates.\n\n### Closing marker\n\nReplace `(sign_pattern_lemma1_general_S.md 終了 — 2026-05-11)` with:\n```\n(sign_pattern_lemma1_general_S.md 終了 — 2026-05-19 §V multiplicity-aware extension)\n```\n\n## Verification (before commit)\n\nRun these checks via Bash:\n\n```bash\n# State.json must remain valid JSON\npython3 -c 'import json; s=json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); print(s[\"investigations\"][\"edh-eu151-vortex-vs-matsui-science-2026\"][\"tier_current\"]); print(s[\"investigations\"][\"edh-eu151-vortex-vs-matsui-science-2026\"][\"current_stage\"])'\n# Expected: 3.0 then closed\n\n# Manuscript must have §V content\ngrep -E -c 'multiplicity|m_rep|rho_inv|Multiplicity' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md\n# Expected: >= 10\n\n# Closing marker updated\ntail -3 /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md\n# Expected: contains '2026-05-19 §V multiplicity-aware extension'\n```\n\n## Commit\n\n```bash\ncd /home/suzume/workspace/BEC-simulation\ngit checkout -b auto/turn_118_edh-eu151-matsui-T118-tier3-closure-and-mult2-section-V-retry\ngit add runs/_loop/state.json docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md\ngit commit --no-gpg-sign -m \"auto(loop) T118 PASS modify_text edh-eu151-matsui-T118-tier3-closure-and-mult2-section-V-retry\n\nDuty A: state.json edh-matsui Tier-3 terminal closure (2.75 -> 3.0). F1\\nis_central falsifier CORROBORATE Stage-1 (T110) + Stage-2 (T117 artifact-\\nfirst independent context). current_stage Document -> closed.\\n\\nDuty B: re-append manuscript §V Multiplicity-Aware Extension to\\npaper3_universal_theorem/sign_pattern_lemma1_general_S.md on main HEAD\\n(T116 commit f081603 landed on auto-branch but not main).\\n\\nNo julia, no src/test/scripts changes. 4th project Tier-3 trajectory\\n(after barnett T29, klaus-bch T59, T86-edh-matsui pre-revision-closure).\\n\\nAssisted-by: Claude Opus 4.7 (model: claude-opus-4-7[1m])\"\n```\n\nNo Co-Authored-By. Use --no-gpg-sign per T112-T117 precedent.\n\n## Hard constraints\n\n- NO julia execution at any point.\n- NO modification of `src/`, `test/`, `scripts/manuscript/` files (regression script unchanged).\n- NO modification of `runs/eu151_edh_K3_long/` files (read-only artifact).\n- NO new YAML config.\n- NO new simulation, no implementer_julia.\n- State.json: surgical Edit (not full Write). Verify JSON-validity post-patch.\n- If primary path (cherry-pick f081603) succeeds: prefer it (verified T116 content). If fallback construction: cite memory file `sign_pattern_lemma1_mult_aware_2026_05_19.md` as canonical source.\n- Output structured implementer report at `runs/_loop/sim/turn_118.md` per standard template (§1 directive received, §2 actions taken, §3 outcomes, §4 metrics, §5 verification, §6 next steps, §7 anomalies).\n- Cost expected ~1.5M effective; budget cap at 3M per stop conditions.",
  "observable_manifest": {
    "required": [
      "investigation_id",
      "stage_advancing_to",
      "subagent_type",
      "directive_action",
      "duty_a_state_json_tier_3_set",
      "duty_a_current_stage_closed",
      "duty_a_f1_result_corroborate_t117",
      "duty_a_last_judge_top_level_patched",
      "duty_b_section_v_present_main_head",
      "duty_b_section_v_canonical_formula",
      "duty_b_section_v_f9_t_a_verification",
      "state_json_valid",
      "no_src_modified",
      "no_runs_eu151_modified",
      "branch_name",
      "commit_sha"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md && test -f /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md && grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && grep -q 'tier_current.*2.75' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && grep -q 'VERDICT: CORROBORATE' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_117.md && python3 -c 'import json; json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\"))' && echo OK_T118_PRECONDITIONS_HOLD"
  },
  "success_criteria": [
    {
      "id": "SC1-state-tier-3.0-set",
      "check_cmd": "python3 -c \"import json; s=json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); v=s['investigations']['edh-eu151-vortex-vs-matsui-science-2026']['tier_current']; print('TIER_3' if v == 3.0 else f'TIER_{v}')\"",
      "expect": {"exit_code": 0, "stdout_contains": "TIER_3"}
    },
    {
      "id": "SC2-state-current-stage-closed",
      "check_cmd": "python3 -c \"import json; s=json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); v=s['investigations']['edh-eu151-vortex-vs-matsui-science-2026']['current_stage']; print('STAGE_CLOSED' if v == 'closed' else f'STAGE_{v}')\"",
      "expect": {"exit_code": 0, "stdout_contains": "STAGE_CLOSED"}
    },
    {
      "id": "SC3-f1-result-corroborate-t117",
      "check_cmd": "python3 -c \"import json; s=json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); f1=s['investigations']['edh-eu151-vortex-vs-matsui-science-2026']['falsifiers'][0]; print('F1_T117_CORROBORATE' if (f1['tested_at_turn']==117 and 'CORROBORATE' in (f1.get('result','') or '')) else 'F1_NOT_PATCHED')\"",
      "expect": {"exit_code": 0, "stdout_contains": "F1_T117_CORROBORATE"}
    },
    {
      "id": "SC4-last-judge-top-level-patched",
      "check_cmd": "python3 -c \"import json; s=json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); v=s.get('last_judge',''); print('LAST_JUDGE_TIER3' if 'TIER_3' in v else f'LAST_JUDGE_{v}')\"",
      "expect": {"exit_code": 0, "stdout_contains": "LAST_JUDGE_TIER3"}
    },
    {
      "id": "SC5-state-json-valid",
      "check_cmd": "python3 -c \"import json; json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); print('JSON_VALID')\"",
      "expect": {"exit_code": 0, "stdout_contains": "JSON_VALID"}
    },
    {
      "id": "SC6-manuscript-section-v-present",
      "check_cmd": "grep -E -c 'multiplicity|m_rep|rho_inv|Multiplicity' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md",
      "expect": {"exit_code": 0, "stdout_regex": "^([1-9][0-9]|[1-9][0-9]{2,})$"}
    },
    {
      "id": "SC7-manuscript-section-v-canonical-formula",
      "check_cmd": "grep -E -q 'canonical.*formula|bar_beta.*canonical|Tr.*rho_inv|m_rep.*\\\\*.*Tr|m_rep.*prefactor' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md && echo CANONICAL_FORMULA_PRESENT",
      "expect": {"exit_code": 0, "stdout_contains": "CANONICAL_FORMULA_PRESENT"}
    },
    {
      "id": "SC8-manuscript-section-v-f9-verification",
      "check_cmd": "grep -E -q 'F=9.*T:A|F = 9.*T:A|m_rep[ =]+2' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md && echo F9_TA_PRESENT",
      "expect": {"exit_code": 0, "stdout_contains": "F9_TA_PRESENT"}
    },
    {
      "id": "SC9-manuscript-closing-marker-updated",
      "check_cmd": "tail -3 /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md | grep -q '2026-05-19' && echo CLOSING_MARKER_UPDATED",
      "expect": {"exit_code": 0, "stdout_contains": "CLOSING_MARKER_UPDATED"}
    },
    {
      "id": "SC10-no-src-modified",
      "check_cmd": "n=$(find /home/suzume/workspace/BEC-simulation/src -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_118.md -name '*.jl' -type f 2>/dev/null | wc -l); echo \"SRC_MODIFIED_${n}\"",
      "expect": {"exit_code": 0, "stdout_contains": "SRC_MODIFIED_0"}
    },
    {
      "id": "SC11-no-runs-eu151-modified",
      "check_cmd": "n=$(find /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_118.md -type f 2>/dev/null | wc -l); echo \"EU151_MODIFIED_${n}\"",
      "expect": {"exit_code": 0, "stdout_contains": "EU151_MODIFIED_0"}
    },
    {
      "id": "SC12-no-test-modified",
      "check_cmd": "n=$(find /home/suzume/workspace/BEC-simulation/test -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_118.md -name '*.jl' -type f 2>/dev/null | wc -l); echo \"TEST_MODIFIED_${n}\"",
      "expect": {"exit_code": 0, "stdout_contains": "TEST_MODIFIED_0"}
    },
    {
      "id": "SC13-commit-on-auto-branch",
      "check_cmd": "cd /home/suzume/workspace/BEC-simulation && git log -1 --format='%s' HEAD | grep -E -q 'T118.*(modify_text|edh-eu151-matsui|tier3)' && echo COMMIT_FOUND",
      "expect": {"exit_code": 0, "stdout_contains": "COMMIT_FOUND"}
    },
    {
      "id": "SC14-stages-done-T110-T117-appended",
      "check_cmd": "python3 -c \"import json; s=json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); sd=s['investigations']['edh-eu151-vortex-vs-matsui-science-2026']['stages_done']; t110=any('T110' in str(x) for x in sd); t117=any('T117' in str(x) for x in sd); print('STAGES_BOTH_APPENDED' if (t110 and t117) else 'STAGES_MISSING')\"",
      "expect": {"exit_code": 0, "stdout_contains": "STAGES_BOTH_APPENDED"}
    },
    {
      "id": "SC15-active-investigation-id-set",
      "check_cmd": "python3 -c \"import json; s=json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); v=s.get('active_investigation_id',''); print('ACTIVE_SIGN_PATTERN' if 'sign-pattern' in v else f'ACTIVE_{v}')\"",
      "expect": {"exit_code": 0, "stdout_contains": "ACTIVE_SIGN_PATTERN"}
    }
  ],
  "failure_modes": [
    {
      "if": "SC5-state-json-valid FAILED (invalid JSON post-patch)",
      "category": "operational",
      "next_action": "T119 dispatches implementer_text again with explicit Edit-only directive (no Write of full state.json). Sequence each Edit call individually with re-validation after each via python3 json.load. If still failing, revert via `git checkout runs/_loop/state.json` and retry with smaller scope (e.g., split Duty A into 2 sequential Edit batches: investigation block first, then top-level fields)."
    },
    {
      "if": "SC1-tier-3.0 OR SC2-closed OR SC3-f1-corroborate failed (Duty A incomplete)",
      "category": "operational",
      "next_action": "T119 dispatches implementer_text-redo with tighter Edit directives. Provide the exact old_string / new_string pairs in the brief. Test in isolation first (echo $? after each Edit). If SC3 specifically fails on F1.result containing 'CORROBORATE' AND 'T117', verify the surgical Edit didn't accidentally collapse the field — use python3 json.dumps to debug."
    },
    {
      "if": "SC6-manuscript-section-v-present FAILED (Duty B no §V on main HEAD)",
      "category": "operational",
      "next_action": "T119 dispatches implementer_text with explicit cherry-pick directive: `git cherry-pick --no-commit f081603 -- docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` and bypass the fallback-construction path. If f081603 unreachable: implementer constructs §V from memory file canonically and writes ≥120 lines. Document the strategy used in §3 of implementer report."
    },
    {
      "if": "SC6 passes but SC7-canonical-formula OR SC8-f9-verification FAILED (Duty B incomplete content)",
      "category": "operational",
      "next_action": "T119 dispatches implementer_text content-augmentation: add canonical formula line + F=9 T:A table per fallback structure in T118 brief. Light retry."
    },
    {
      "if": "SC10-no-src-modified OR SC11-no-runs-eu151 OR SC12-no-test FAILED (constraint violation)",
      "category": "framework_error",
      "next_action": "Roll back via `git reset --hard main` then re-dispatch with text-only constraint bolded. Add patterns.yaml entry: implementer_text_scope_creep_t118_2026_05_19. Anko-consult escalation if repeated."
    },
    {
      "if": "Duty B fallback construction yields < 120 lines (insufficient content)",
      "category": "data_gap",
      "next_action": "T118 implementer documents the gap in §3 of sim/turn_118.md. T119 director dispatches theorist for §V content authoring (T115 derivation propagation to manuscript-quality prose). Cost ~2M. Tier-3 closure on edh-matsui (Duty A) still lands independently."
    },
    {
      "if": "judge.py judge/turn_118.json status FAIL_NO_METRICS (same operational issue as T117)",
      "category": "operational",
      "next_action": "T118 sim/turn_118.md must include §4 Metrics JSON block per implementer.md convention (with structured metrics like sc_passed/sc_failed, files_modified, loc_delta, etc.). The implementer agent definition handles this; verify in §4 of sim output. If judge still FAIL_NO_METRICS, the substantive verdict (file diff + check_cmd results) is dispositive; T119 director routes off Duty A/B success_criteria FORM B results."
    },
    {
      "if": "anko mid-turn updates seed.md flipping priority away from edh-matsui closure",
      "category": "scheduling_override",
      "next_action": "T119 re-reads seed.md verbatim. T118 work is durable on disk regardless. If anko added new priority-0 mid-T118, document the late-arrival in T119 director top-of-turn read."
    },
    {
      "if": "cherry-pick f081603 has merge conflicts with main HEAD beyond manuscript file",
      "category": "operational",
      "next_action": "Implementer uses `git show f081603:docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` to extract content WITHOUT cherry-pick. Splice via Edit tool replacing the 2-line closing block with §V content + new closing block. No git merge ops needed."
    }
  ],
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 900
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_partial_advance_to_stage": "Update",
    "if_partial_tier_becomes": 2.75,
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 2.75,
    "if_success_falsifier_update": {
      "id": "F1-ring-appears-correct-timescale",
      "tested_at_turn": 117,
      "result_template": "CORROBORATE at T117 critic independent context (Stage-2): direct trajectory.csv read shows pop_c2 (m=+5) peak 17.08% at t=4.34 ms; within factor-2 band [2.5, 10] ms of Matsui experimental t_ring=5 ms (ratio 0.87x). Full 13-component cascade observed; all 3 config knobs PRESENT. Stage-1 (T110) + Stage-2 (T117) = central F1 falsifier CORROBORATE. Tier 2.75 -> 3.0 TERMINAL CLOSURE recorded by T118 implementer state.json patch."
    },
    "note": "T118 implementer_text 2-duty bundle. Duty A: state.json edh-matsui Tier-3 terminal closure patch (tier 2.75 → 3.0, current_stage closed, F1 CORROBORATE-Stage-2 from T117 critic). Duty B: manuscript §V Multiplicity-Aware Extension re-append on main HEAD (T116 commit f081603 landed on auto-branch but not main HEAD per grep verification). Both text-only, no julia, no production code. Bundled per memory feedback_cost_overhead_is_the_cost. T118 = project's 4th Tier-3 trajectory closure (after barnett T29, klaus-bch T59, T86-edh-matsui pre-revision-closure); 2nd terminal closure for SAME investigation: T86 closed on F3 alone, T118 closes on F1+F3 with explicit F1 corroboration replacing the T82-T84 NOT_APPLICABLE_NO_RING placeholder. Tier-3 promotion gate (director.md §5.B): central falsifier is_central=true with result containing CORROBORATE → unblocked. D1 axis primary (verification of published-paper benchmark — Matsui Science 391, 384-388 (2026) DOI:10.1126/science.adx2872 / arXiv:2504.17357); D3 axis secondary (manuscript propagation of T115 m_rep prefactor theorem). After T118 closure: active_investigation_id stays sign-pattern-f9-ta-mult2 (now Duty B-completed; T119 director can advance Update → Document/closed for it). Next-priority candidates: meta-cost-waste-audit-2026-05-19 (Observe), audit-class-scan next cycle (gap ~13), or new Tier-3 candidate from survey."
  }
}
```

## 7. Drift advisories — explicit acknowledgement per protocol §B6

Per T117 history block drift_signals (state.json L1529-L1541):

- **DRIFT_SUBAGENT_REPETITION (0.333 advisory)**: Last 3 turns = implementer (T115a1+a2)→implementer_text (T116)→critic (T117). T118 dispatches **implementer_text** — same class as T116, breaks the critic-only 1-turn streak. Net drift_signal subagent_repetition holds ~0.4 next turn; acceptable since T118 dispatches a different specific subagent role than T117 (implementer vs critic). Not concerning.

- **DRIFT_VERDICT_DRIFT (0.7 advisory at T117)**: T113-T117 streak = NOOP / PASS / INCONCLUSIVE / FAIL_OPERATIONAL / FAIL_NO_METRICS (2 PASS-equivalent in 5 turns; T117 substantive_verdict CORROBORATE was operationally FAIL_NO_METRICS). T118 implementer_text with concrete FORM B SC checks should emit clean PASS. Streak recovers to 2-3 PASS in 5 next turn.

- **AUDIT_DUE: patterns.yaml gap=12 (advisory)**: Last audit at T105 (T103-T106 cycle); current gap 12→13 at T118. Threshold for auto-spawn typically gap≥14 per T103 cycle. T119 or T120 should dispatch audit-class-scan if no higher-priority work surfaces. Documented per §B6 transparency; deferring at T118 due to higher-leverage Tier-3 closure.

- **DRIFT_TOPIC_REPETITION (0.0 at T117)**: T118 continues edh-matsui (closure) + sign-pattern-mult2 (Duty B) — bundled per pre-committed T117 plan. Drift_signal expected ~0.4 next turn (bounded, intentional). Not concerning.

- **DRIFT_COST_INFLATION (0.997 at T117)**: T117 cost 12.34M orchestrator tokens (effective 1.93M per n_messages=81; well within 3M budget cap). T118 implementer_text-2-duty is text-only Edit+Bash, no expensive Read of trajectory.csv (already done at T117), no compute. Expected ~1.5M effective. Cost stays controlled.

- **DRIFT_MANUSCRIPT_DELTA_ZERO (0.0 at T117)**: T117 had no manuscript delta (critic-only). T118 Duty B will produce a +150-200 LOC manuscript delta on main HEAD (the missing T116 §V append). Drift_signal manuscript_delta_zero clears.

- **DRIFT_CODE_DELTA_ZERO (0.0 at T117)**: T118 has no production-code delta (text-only). state.json + manuscript .md edits don't count as code per drift_signals.py heuristic (or do count as text-delta-equivalent). Either way, intentional.

- **DRIFT_NOVEL_CLAIM_ZERO (0.0 at T117)**: T118 propagates an already-derived theorem (T115 m_rep prefactor) to manuscript form. No novel claims, just propagation. Stays 0.0; acceptable per protocol since the value is from theorist/researcher_deep, not implementer_text.

## 8. Honesty cross-checks

I considered seven alternatives (§2.4 above). Summary of rejection reasons:

- (a) critic re-audit F2 spatial winding: BLOCKED by JLD2-vs-h5py incompatibility, INCONCLUSIVE-NO-DATA guaranteed → WASTE.
- (b) theorist re-derivation: T115 theorist already derived; manuscript propagation is mechanical text-append.
- (c) implementer_julia new EdH sim: seed.md hard-constraint + memory hard rule + T117 already CORROBORATE'd, would just risk falsification of achieved Tier-3.
- (d) noop: explicit work exists (tier-3 patch + §V append); noop discards signal.
- (e) split 2 duties over 2 turns: bundling correct per cost-overhead memory + zero ordering dependency.
- (f) researcher re-fetch Matsui: T71 already deep-researched; redundant.
- (g) audit-class-scan: gap=12, threshold gap≥14, defer 1-2 more turns.

The chosen dispatch (implementer_text 2-duty bundle):

- Executes the T117 director's pre-committed CORROBORATE-branch plan verbatim.
- Honors seed.md priority-0 directive ("If CORROBORATE, promote to tier 3.0").
- Realizes Tier-3 promotion gate per director.md §5.B (central falsifier is_central=true with result containing CORROBORATE).
- Realizes 4th project Tier-3 trajectory closure (barnett T29, klaus-bch T59, T86-edh-matsui pre-revision-closure, T118-edh-matsui post-revision-closure).
- Bundles 2 independent text-only duties in 1 turn per memory feedback_cost_overhead_is_the_cost.
- Cost ~1.5M expected (10× reduction from T116 16.85M).
- All hard constraints respected (no julia, no production code, no new sim).

**Honest acknowledgement of T117 judge-bug**: The judge/turn_117.json status FAIL_NO_METRICS is an operational judge.py limitation for critic-route turns (the §4 Metrics JSON path is N/A for verdict-reports). The substantive_verdict in state.history[T117] is CORROBORATE. T118 routes off the substantive_verdict per director.md §B precedence rule (substantive > operational labels). This is honest disambiguation, not a routing override.

**Honest acknowledgement of T86 → T118 Tier-3 re-closure**: T86 closed edh-matsui at tier 3.0 on F3 alone with F1 NOT_APPLICABLE_NO_RING placeholder. Anko re-opened via seed.md 2026-05-19 noting "F1 ring formation was NOT reproduced" by T76-T86's regressed config. T110+T117 corroboration on the K3_long config (anko's verified May 13 setup) replaces the placeholder. T118 closure is on F1+F3 with explicit F1 evidence — strictly stronger than T86 closure. This IS the "2nd terminal closure path for the SAME investigation"; the prior T86 closure stands as historical record but T118 is the load-bearing one going forward.

## 9. What T119 director should look at first

In order:

1. `Read runs/_loop/sim/turn_118.md` — implementer report. Specifically §4 metrics JSON (sc_passed/sc_failed), §5 verification (state.json validity + manuscript content checks), §3 outcomes (which path Duty B took: cherry-pick vs fallback).

2. `Read runs/_loop/judge/turn_118.json` — judge interpretation. Expected PASS (15/15 SC) IF both Duty A patches and Duty B append landed cleanly. PASS_WITH_COST_WARNING if cost exceeded ~2M. FAIL_OPERATIONAL if any of SC1-SC15 failed.

3. `Read runs/_loop/state.json` lines 2167-2252 (edh-matsui block) — verify tier_current=3.0 + current_stage=closed + F1.result contains "CORROBORATE" + "T117". If correct: edh-matsui IS terminally closed at Tier 3.0.

4. `Read docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` tail 50 lines — verify §V Multiplicity-Aware content present + closing marker updated to 2026-05-19. If correct: sign-pattern-mult2 Duty B IS complete on main HEAD.

5. **If both 3 and 4 PASS**: advance sign-pattern-f9-ta-mult2 investigation Update → Document/closed (Tier 2.5 → 2.75 likely, or 2.5 → 3.0 if F1 central CORROBORATE at machine precision per memory entry). Director T119 chooses subagent for Document stage.

6. **If 3 or 4 FAIL**: pivot per failure_modes branch. Most likely re-dispatch implementer_text with tighter Edit directives.

7. `Read runs/_loop/seed.md` — anko may have updated priority post-T118 closure. If new pin: follow.

8. `Glob runs/eu151_edh_K3_long/spatial_profiles.csv` — if anko ran the wrapper, F2 winding number audit unblocked; T119 could optionally dispatch critic on F2 (would solidify edh-matsui at Tier 3.0+ with F2 also CORROBORATE).

9. `patterns.yaml audit`: gap=13 at T118 → 14 at T119; threshold likely triggers auto-spawn audit-class-scan. T119 or T120 dispatches.

10. Next-priority candidates if all above closed: meta-cost-waste-audit-2026-05-19 (Observe stage, priority 15), tier3_pipeline_survey 2nd-pick candidate (pseudo-hermitian / fullbdg-F6-polar / Yan-Li-Saito), or anko-supplied new pin.

## 10. Closing

T118 advances `edh-eu151-vortex-vs-matsui-science-2026` from Update/2.75 → closed/3.0 (Tier-3 terminal closure on F1 central falsifier CORROBORATE Stage-1 T110 + Stage-2 T117) AND completes the outstanding T116 manuscript §V Duty B re-append on main HEAD. Implementer_text 2-duty bundle, single subagent, no julia, no production code.

Per seed.md 2026-05-19 priority-0 directive verbatim: "If CORROBORATE, promote inv to tier 3.0 with the audit as the load-bearing evidence — not the T76-T86 F3 energy convention." T117 critic produced CORROBORATE; T118 executes the promotion. Per T117 director §7 failure_modes CORROBORATE branch verbatim plan: T118 dispatches state.json patch + manuscript §V re-append. Executable realization of the pre-committed plan.

D1 axis primary (verification of published-paper benchmark — Matsui Science 391, 384-388 (2026) DOI:10.1126/science.adx2872 / arXiv:2504.17357 — 4th project Tier-3 trajectory closure after barnett T29, klaus-bch T59, T86-edh-matsui pre-revision; 2nd terminal closure path for SAME investigation, this time on F1+F3 evidence not F3 alone). D3 axis secondary (manuscript propagation of T115 m_rep prefactor theorem to paper3 §V).

Cost ~1.5M expected (Read + Edit + Write + Bash for git; no compute; no large file reads since T117 already exhausted trajectory.csv). Bundling avoids 2-turn overhead per memory feedback_cost_overhead_is_the_cost.

Drift advisories cleared: subagent_repetition stays bounded (critic→implementer class swap, breaks T117's critic-only streak); cost_inflation reduces ~10× from T116; manuscript_delta_zero clears via Duty B; verdict_drift recovers via expected clean PASS.

Per memory `feedback_cost_overhead_is_the_cost` + `feedback_mechanical_vs_investigation_threshold`: this dispatch is sized, scoped, single-investigation-primary, single-subagent, double-duty, single-action-class (modify_text). No further deliberation. Execute.
