---
turn: 120
subagent: director
investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
stage_advancing_from: "Update (T119 critic CORROBORATE on 5/5 audit deliverables A1-A5; central falsifier F1 is_central=true re-confirmed at machine precision; two minor errata flagged non-blocking — auto-branch a323222 wrapper not on main, MEMORY 29-vs-26 regression-script drift)"
stage_advancing_to: "closed (Tier-3 terminal closure: F1 central CORROBORATE via T115 Stage-1 + T119 Stage-2 → tier 2.5 → 3.0; current_stage Update → closed; last_verdict TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119_INDEPENDENT_CONTEXT; investigation joins barnett T29, klaus-bch T59, T86-edh-matsui, F=2 cyclic A_1 T94, and edh-matsui-resumption T118 as 5th project Tier-3 trajectory)"
topic_tags:
  - sign-pattern-lemma1-mult-aware
  - f9-ta-multiplicity-2
  - tier3-terminal-closure
  - central-falsifier-F1-CORROBORATE-stage-2
  - artifact-first-T119-stage2
  - state-json-patch
  - critic-flagged-erratum-cherry-pick-a323222
  - critic-flagged-erratum-memory-29-vs-26-drift
  - bundled-4-duty-text-only
  - implementer-text
  - D3-axis-primary
  - D1-axis-secondary
  - manuscript-anchored
  - 5th-project-tier-3
paper_section: "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md §V Multiplicity-Aware Extension (already on main HEAD per T118 Duty B); scripts/manuscript/f9_f11_polyhedral_verification.jl (Duty B: cherry-pick a323222 to bring canonical_mult_aware_beta_S onto main); scripts/manuscript/lemma1_general_S_verification.jl (Duty C: add F=2 cyclic T_d A_1 case at S=0/2/4)"
depends_on:
  - 119
  - 118
  - 117
  - 116
  - 115
  - 114
  - 94
  - "runs/_loop/state.json"
  - "runs/_loop/seed.md"
  - "runs/_loop/_local/scheduler_120.json"
  - "runs/_loop/sim/turn_119.md"
  - "runs/_loop/judge/turn_119_critic_audit.md"
  - "runs/_loop/director/turn_119.md"
  - "runs/_loop/director/turn_118.md"
  - "runs/_loop/sim/turn_118.md"
  - "runs/_loop/conclusions/sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19.md"
  - "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md"
  - "scripts/manuscript/lemma1_general_S_verification.jl"
  - "scripts/manuscript/f9_f11_polyhedral_verification.jl"
  - "memory:sign_pattern_lemma1_mult_aware_2026_05_19"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:feedback_mechanical_vs_investigation_threshold"
  - "memory:feedback_cost_overhead_is_the_cost"
  - "memory:feedback_fix_the_class_not_the_instance"
produces: >
  T120 closes sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19 at Tier 3.0
  via implementer_text 4-duty bundle. Duty A: state.json patch (tier 2.5 → 3.0,
  current_stage Update → closed, F1.result append T119 CORROBORATE-Stage-2,
  last_turn 116 → 120, last_critic_turn → 119, last_stage Update → Update-Stage-2,
  last_verdict → TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119, closing_note
  append T120 5th-trajectory marker, top-level active_investigation_id flip to
  next-priority candidate per anko routing). Duty B: cherry-pick auto-branch
  commit a323222's scripts/manuscript/f9_f11_polyhedral_verification.jl onto
  main (critic T119 erratum #1 — canonical_mult_aware_beta_S wrapper not on
  main per critic §5.1; remediation explicitly recommended in critic
  recommended_action). Duty C: add F=2 cyclic T_d A_1 case at S=0/2/4 (β_c0
  = 1/5, 2/7, 18/35; β_λ_spin = -1/5, -1/7, 12/35 from MEMORY F=2 cyclic
  Tier-3 closure entry) to scripts/manuscript/lemma1_general_S_verification.jl,
  closing the 29-vs-26 regression-script drift (critic T119 erratum #2).
  Duty D: append T119+T120 closure entries to
  memory/sign_pattern_lemma1_mult_aware_2026_05_19.md (T119 5/5 audit
  CORROBORATE, T120 Tier-3 trajectory marker, errata closure record).
  All 4 duties are text-only (Duties A/C/D are pure markdown/JSON edits;
  Duty B is a git checkout from existing commit, NO julia execution).

  This is the executable realization of T119 director §7 pre-committed plan
  ("T120 dispatch (anticipated): If T119 critic VERDICT = CORROBORATE →
  implementer_text Duty A: state.json sign-pattern-f9-ta-mult2 closure patch")
  PLUS the critic T119 recommended_action verbatim ("Suggest T120+
  implementer_text cherry-pick auto-branch commit a323222 to bring
  canonical_mult_aware_beta_S onto main, AND close MEMORY 29-vs-26 drift
  by adding F=2 cyclic A_1 case to lemma1_general_S_verification.jl").

  D3 axis primary (theory verification closure on T115 mult-aware extension
  — completes 5-turn T112-T119 trajectory at Tier 3.0; closes 5th project
  Tier-3 trajectory). D1 axis secondary (regression script extension to
  6 polyhedral cases / 29 channels aligns the on-disk record with the
  MEMORY claim, closing a verification ledger drift). Cost expected
  ~1.4M effective (Read 8-10 files + Write 4 files + 1 git checkout
  + 1 git commit, no julia execution, no compute). ~40% below T118
  (2.3M); aligned with anko's DRIFT_COST_INFLATION advisory.

  Per memory feedback_mechanical_vs_investigation_threshold: 4 text-only
  edits with predictable outcome (regex-verifiable success criteria,
  no theory derivation, no compute) → mechanical class → direct execute
  via implementer_text. NOT a new investigation, NOT a meta-improvement,
  NOT a critic re-audit. The audit closed at T119; T120 is the closure
  paperwork.

  Per memory feedback_fix_the_class_not_the_instance: when critic flagged
  TWO errata (auto-branch wrapper not on main, 29-vs-26 drift), T120
  fixes BOTH instances together rather than deferring one — both belong
  to the same class "T115-era propagation completeness gap".

  CRITICAL: success_criteria MUST use only allow-listed programs (python3,
  grep, jq, test, cat, head, tail, wc, find, git) with NO shell metachars
  (no &&, no ||, no | as pipe, no $(), no cd). All check_cmds are
  single-program + args with regex patterns wrapped in single-quotes.
  This is the explicit lesson from T115/T116/T118 shell-quoting INCONCLUSIVE
  cascade AND the T117/T119 PASSING pattern. The meta-stage-routing-2026-05-19
  auto-spawn at T118 (priority 25, Observe stage) remains the wrong tool;
  T120 director PREVENTS recurrence by hand-discipline (single-binary
  check_cmds + single-quoted regex), not by activating the meta-investigation.
---

# Turn 120 — Director Report

## 1. Top-of-turn reads (cited per protocol)

| Path | Read | What it says |
|---|---|---|
| `runs/_loop/_local/scheduler_120.json` | full file (37 lines) | `policy: JULIA_GPU_OK`, all workloads allowed including `implementer_text`. VRAM=12845 MB free, RAM=25.02 GB, GPU=1%, foreign_julia=0. Window 1093727 s left through 2026-05-31. No constraints. |
| `runs/_loop/state.json` lines 1595-1673 + 2930-3013 | scanned | T119 history entry: substantive_verdict="CORROBORATE", route="critic", investigation_id="sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19", note "unblocks T120 director Tier-3 patch". Top-level: last_judge="FAIL_NO_METRICS" (operational, not physics — same as T117 critic-route), active_investigation_id="sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19", last_critic_turn=119, last_critic_verdict="CORROBORATE". Investigation block: tier_current=2.5, tier_target=3, current_stage="Update", priority=4, F1 is_central=true with CORROBORATE result + dev 1.388e-16, closing_note "eligible for Tier 3 closure pending T117+ critic crosswalk audit". All gate prerequisites SATISFIED. |
| `runs/_loop/seed.md` (full 95 lines) | full | Priority-0 directive (edh-matsui) SATISFIED at T118. No new priority appended. Falls through to default protocol routing. Hard memory constraint section stale (scheduler shows ram_avail 25 GB / foreign_julia=0 / full JULIA_GPU_OK). |
| `runs/_loop/director/turn_119.md` (own previous turn) | full (462 lines) + §7 verbatim | T119 was critic dispatch on sign-pattern-f9-ta-mult2. Pre-committed plan §7: "T120 dispatch (anticipated): If T119 critic VERDICT = CORROBORATE → implementer_text Duty A: state.json sign-pattern-f9-ta-mult2 closure patch (tier 2.5 → 3.0, current_stage closed). 5th project Tier-3 trajectory closure." T120 executes this exactly, BUNDLED with critic-flagged errata fix. |
| `runs/_loop/sim/turn_119.md` (T119 critic verdict) | full (168 lines) | VERDICT: CORROBORATE. All 5 deliverables (A1 canonical formula independently re-derived via Schur, A2 J-involution endpoint proof tightened to one-line $J^\dagger P_W J = P_W \Rightarrow \mathrm{Tr}(P_W^2)/(2F+1) = m_{\rm rep}/(2F+1)$, A3 Hamermesh orbit-counting gives m_rep = (1/12)(19+8-3) = 2 exactly, A4 1.388e-16 = ~2 ULP at 0.05 rounding-only, A5 sum-rule algebraic from $\sum_S \Pi_S = I$ + m_rep=1 reduction strict). Two errata flagged: (#1) f9_f11_polyhedral_verification.jl wrapper at commit a323222 not on main; (#2) MEMORY claims 29 channels / 6 cases but on-disk script has 26/5 (missing F=2 cyclic T_d A_1). Critic recommended_action verbatim: "Suggest T120+ implementer_text cherry-pick auto-branch commit a323222 to bring canonical_mult_aware_beta_S onto main, AND close MEMORY 29-vs-26 drift by adding F=2 cyclic A_1 case to lemma1_general_S_verification.jl." |
| `runs/_loop/judge/turn_119_critic_audit.md` | symlink → sim/turn_119.md per protocol Step 1d-bis | Same content as above. |
| `runs/_loop/director/turn_118.md` (Tier-3 closure precedent) | first 120 lines | T118 closed edh-matsui at Tier 3.0 via implementer_text 2-duty bundle (state.json patch + manuscript §V append). EXACT template for T120 — same routing, same bundling principle, same shell-quoting discipline. T118 §2.2 verbatim: "Bundling avoids the '1 cheap turn dispatched per duty' overhead pattern that drives DRIFT_COST_INFLATION." |
| `runs/_loop/sim/turn_118.md` (T118 implementer report) | first 100 lines | T118 implementer executed 2 duties cleanly: 14/14 SCs PASSED for substantive work; only operational SC10-13 INCONCLUSIVE due to director-side check_cmd shell-quoting bugs (subsequently lesson-learned for T119 and T120). T120 uses single-quoted regex pattern from T117/T119 that PASSED. |
| `runs/_loop/conclusions/sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19.md` | full (103 lines) | Durable [Established]/[Plausible] ledger + 4 falsifier registrations. T120 will not modify this file (closure is captured in state.json + memory entry per T118 pattern). |
| `memory:sign_pattern_lemma1_mult_aware_2026_05_19` | full (57 lines) | Memory entry documents formula, T115 numerical confirmation, theorist J-involution derivation, m_rep=1 regression, open questions (F=11 T:E_1, F=12, isotypic-allocation general), and file anchors. Duty D extends this with T119+T120 closure entries. §5 caveat explicitly notes the 29-vs-26 drift that Duty C closes. §7 line 52 documents the a323222 auto-branch wrapper that Duty B fast-forwards to main. Memory IS already structured for these closures. |
| `memory:feedback_mechanical_vs_investigation_threshold` (MEMORY.md L227) | indexed | Hard rule: 4 text-only edits with regex-verifiable outcomes = mechanical → direct execute via implementer_text, NOT meta-improvement / verify-claim / build-theory. |
| `memory:feedback_cost_overhead_is_the_cost` (MEMORY.md L233) | indexed | Bundle multiple duties into one turn when they share subagent class + zero ordering dependency. Duties A/B/C/D are independent: state.json patch ⊥ script cherry-pick ⊥ regression-script extension ⊥ memory edit. |
| `memory:feedback_fix_the_class_not_the_instance` (MEMORY.md L228) | indexed | When ONE instance (critic erratum #1: a323222 wrapper not on main) surfaces, sweep for siblings. Critic ALREADY surfaced erratum #2 (29-vs-26 drift) in same audit. T120 fixes BOTH together — same class "T115-era propagation completeness gap". |
| `memory:feedback_use_existing_artifacts_first` (MEMORY.md L240) | indexed | The F=2 cyclic A_1 β values needed for Duty C are ALREADY on disk in MEMORY.md L77-80 (F=2 cyclic-tetrahedral A_1 Tier-3 closure entry — β_c0 = 1/5, 2/7, 18/35; β_λ_spin = -1/5, -1/7, 12/35; verified at T94). No new derivation. |
| `scripts/manuscript/lemma1_general_S_verification.jl` (head + tail) | lines 1-30 + 100-116 | Confirmed structure: @testset entries per F-case, exact rational arithmetic, terminal println line 115 "26 channel coefficients verified across 5 cases". Duty C adds a new @testset block for F=2 cyclic with 3 channels (S=0, 2, 4) AND updates terminal println to "29 channel coefficients verified across 6 cases". |

## 2. Picking the next investigation — protocol routing

### 2.1 Walk state.investigations

Per director.md "Picking the next investigation" table, evaluate in order:

1. **`seed.md` top section names a specific investigation**: edh-matsui priority-0 SATISFIED at T118. No new priority appended. **Falls through.**

2. **Active investigation has `next_stage_action` set AND scheduler allows the workload**: `active_investigation_id = sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`. State.json L3004-3005 `next_stage: null, next_stage_action: null` (not pre-routed). BUT investigation block L3013 `closing_note` explicitly verbatim: "eligible for Tier 3 closure pending T117+ critic crosswalk audit (central falsifier F1 marked)". T119 SUPPLIED that critic crosswalk audit with VERDICT: CORROBORATE. Plus T119 director §7 pre-committed plan: "If T119 critic VERDICT = CORROBORATE → implementer_text Duty A: state.json sign-pattern-f9-ta-mult2 closure patch". **MATCH — pre-committed by closing_note + T119 director §7 + critic recommended_action.**

3. **Artifact-first path bypass**: NOT applicable here — this is the Document/closed stage, not a new audit. The artifact-first path applies when artifacts exist but tier_current < 3 AND last verdict was NOT INCONCLUSIVE — both conditions held at T119 (which dispatched critic). NOW tier_current=2.5 and last verdict CORROBORATE; the next action per the table is "PASS / PASS_WITH_COST_WARNING → advance". For build-theory flow, Update → Document → closed. Document for build-theory = theorist per director.md table, BUT this is a Tier-3 terminal closure where the work product is mechanical state.json patching + flagged-erratum fixes — implementer_text per memory `feedback_mechanical_vs_investigation_threshold`.

### 2.2 Why NOT alternative investigations

| Candidate | Priority (state.json) | Status | Rejected because |
|---|---|---|---|
| `edh-eu151-vortex-vs-matsui-science-2026` | 0 | tier 3.0 CLOSED at T118 | Already terminally closed. F2/F4 BLOCKED on h5py. Re-opening violates seed.md "audit IS the data". |
| `barnett-mechanism-2026-05-16` | 1 | tier 3.0 CLOSED at T29 | Already closed. |
| `klaus-magnetostir-bch-leak-2026-05-13` | 3 | tier 3.0 CLOSED at T59 | Already closed. |
| `judge-in-operator-bug-2026-05-18` | 2 | tier 2.0 closed | Done. |
| `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` | 4 | tier 2.0 blocked_on F5 julia gate | Blocked: "F5 empirical julia execution pending (sandbox approval gate)". DEFER. |
| `yan-li-saito-2026-reproduction` | 1 | tier 0.4 open | T45-T48 partial; deep researcher → theorist → julia GPU chain. Cost 5-10× higher than mechanical closure. T120 dispatches the cheap closure FIRST, then T121 can pivot to higher-cost candidate. DEFER. |
| `meta-cost-waste-audit-2026-05-19` (auto-spawn) | 15 | Observe | D4 axis. Lower priority than Tier-3 closure paperwork. anko's "physics completeness/verification depth" preference. DEFER. |
| `meta-stage-routing-2026-05-19` (auto-spawn T118) | 25 | Observe | D4 axis. T120 PREVENTS recurrence by hand-discipline (single-quoted regex + single-binary check_cmds), NOT by activating meta-investigation. |
| `audit-class-scan` next cycle | dormant | gap=14 at T119 advisory | AUDIT_DUE drift advisory at gap=14 — threshold met but Tier-3 closure is higher leverage. DEFER 1 turn; T121 can pick up audit cycle if gap continues. |

**Decision: dispatch implementer_text on sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19 for 4-duty Tier-3 terminal closure bundle.**

### 2.3 Project axis

**D3 (theory derivation + manuscript) primary**: closure of T115 mult-aware extension at Tier 3.0 + manuscript & regression-script propagation completeness. Completes the 5-turn T112-T119 trajectory. Closes the 5th project Tier-3 trajectory. **D1 (verification) secondary**: regression-script extension from 26 channels / 5 cases to 29 channels / 6 cases aligns on-disk verification record with MEMORY claim — closes a verification-ledger drift.

### 2.4 Why implementer_text (not critic, not noop, not theorist, not researcher)

- **critic**: T119 already CORROBORATE'd all 5 audit deliverables. Re-dispatching would re-confirm what's on disk; WASTE.
- **noop**: Explicit work to do (Tier-3 closure paperwork + 2 critic-flagged errata fixes). Noop discards signal that T119 provided.
- **theorist**: No new derivation needed. T115 J-involution proof + T119 tightened one-line proof are both on disk. The required action is mechanical state.json + script + memory edits.
- **researcher**: No new literature lookup needed. T119 critic already crosswalked Hamermesh, Stamper-Kurn-Ueda, Kawaguchi-Ueda. Recommended Web fetches were OPTIONAL fallback path (not blocking; critic chose the Hamermesh on-disk path).
- **implementer_text**: Read-only on Reads, single Write per file, predictable outcomes (regex-verifiable). Matches the T118 closure-on-CORROBORATE template exactly. T118 implementer emitted 14/14 substantive SCs PASSED at ~2.3M cost; T120 4-duty bundle should land at ~1.4M-1.7M (lower per-duty due to smaller scope per file).

### 2.5 Implementer_text role per director.md flow table

`flow_template = build-theory` for this investigation. Document/closed stage role per director.md table: "Document=theorist". HOWEVER, per memory `feedback_mechanical_vs_investigation_threshold`: closure paperwork (state.json edits, script extension, memory entry update) is mechanical text editing, NOT theorist derivation work. Implementer_text is the correct role per the mechanical class threshold; theorist would over-allocate. The role guideline in director.md is an default — the mechanical-threshold override applies when the work product is text edits with predictable outcomes.

## 3. Implementer's directive — verbatim brief

The implementer dispatched at T120 must execute 4 duties in a single auto-branch + single commit (per T118 precedent).

### 3.1 Read order (BEFORE any Write)

1. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — read sign-pattern investigation block at lines 2930-3013 (need: F1 falsifier object, falsifiers array, closing_note text, tier_current 2.5, current_stage "Update", priority 4, last_turn 116, last_stage "Update"). Read top-level fields at lines 1659-1673 (need: last_judge "FAIL_NO_METRICS", active_investigation_id "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19", last_critic_turn 119, last_critic_verdict "CORROBORATE", last_directive_label, last_directive_action). DO NOT read the 1000+ lines of history — only the investigation block + top-level fields.

2. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_119.md` — full (168 lines). Source the T119 critic verdict prose verbatim for state.json F1.result append + closing_note append. Take the §6 verdict block JSON as canonical CORROBORATE wording.

3. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` — full (116 lines). Confirm @testset structure + final println signature for Duty C edit.

4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` — full (57 lines). Source structure for Duty D append (T119 audit closure + T120 trajectory marker + errata closure entries).

5. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_118.md` — lines 1-120 only (no need for full 600+ line file). Source T118 closure-patch JSON structure for Duty A modeling.

### 3.2 The 4 duties (verbatim from implementer perspective)

#### Duty A — state.json Tier-3 terminal closure patch

Surgical Edits to `runs/_loop/state.json` patching the `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` investigation block AND top-level fields. Mirrors T118 closure pattern exactly.

**Investigation-block edits** (key path `investigations["sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"]`):

- `tier_current`: `2.5` → `3.0`
- `tier`: `2.5` → `3.0` (mirror field per state.json schema)
- `current_stage`: `"Update"` → `"closed"`
- `last_turn`: `116` → `120`
- `last_stage`: `"Update"` → `"Update-Stage-2-T119-critic"` (records T119 critic-route as the Stage-2 culmination)
- `last_verdict`: `"CORROBORATE_4_OF_4_PHYSICS_PASS_MANUSCRIPT_PROPAGATED"` → `"TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119_INDEPENDENT_CONTEXT_5TH_PROJECT_TIER_3_TRAJECTORY"`
- `last_critic_turn`: append field with value `119` (or update if exists)
- `stages_done`: append `"Document"` and `"closed"` (representing T119 Stage-2 audit completion + T120 closure)
- `stages_at_turn`: append `"Document": [119, "critic T119 independent-context audit 5/5 deliverables CORROBORATE: A1 Schur-canonical formula re-derivation, A2 J-involution endpoint proof tightened to one-line tr(P_W^2)/(2F+1)=m_rep/(2F+1), A3 Hamermesh orbit-counting gives m_rep=2 exactly, A4 1.388e-16 = ~2 ULP rounding-only, A5 sum-rule algebraic"]` AND `"closed": [120, "implementer_text 4-duty terminal closure: state.json patch + cherry-pick a323222 wrapper to main + add F=2 cyclic A_1 case to regression script + memory entry append"]`
- `falsifiers[0].tested_at_turns`: append `119` to the list (so it becomes `["115_attempt1", 115, 119]`)
- `falsifiers[0].result`: append (preserve existing text + append after a separator): ` || T119 critic Stage-2 CORROBORATE (independent-context audit, 5/5 deliverables A1-A5 independently re-derived; J^†P_W J = P_W + P_W^2 = P_W chain gives one-line proof of tr(P_W)/(2F+1) = m_rep/(2F+1) endpoint; Hamermesh orbit-counting confirms m_rep = (1/12)(19+8-3) = 2 exactly; 1.388e-16 = 2 ULP at 0.05 rounding-only; F4 sum-rule algebraic from sum_S Π_S = I; F3 m_rep=1 reduction strict-generalization). 5th project Tier-3 trajectory closure.`
- `closing_note`: preserve existing text + append (after a `\n\nT120 closure:` separator): `Tier 3.0 terminal closure at T120 via implementer_text 4-duty bundle. T119 critic CORROBORATE on 5/5 deliverables A1-A5 (Schur canonical formula, J-involution endpoint, Hamermesh m_rep=2, 1-ULP numerics, algebraic sum-rule + m_rep=1 reduction). 5th project Tier-3 trajectory (after barnett T29, klaus-bch T59, T86-edh-matsui-original, T94-F=2-cyclic-A_1, T118-edh-matsui-resumption). Two critic-flagged errata closed: (#1) cherry-picked auto-branch commit a323222 to bring canonical_mult_aware_beta_S wrapper onto main scripts/manuscript/f9_f11_polyhedral_verification.jl; (#2) added F=2 cyclic T_d A_1 case (S=0/2/4 channels) to scripts/manuscript/lemma1_general_S_verification.jl, closing the 29-vs-26 MEMORY.md drift. Investigation closed.`

**Top-level edits**:

- `last_judge`: `"FAIL_NO_METRICS"` → `"TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119"`
- `last_directive_label`: → `"sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle"`
- `last_directive_action`: → `"modify_text"`
- `active_investigation_id`: retain as `"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19"` UNTIL closure is committed; OR flip to `null` (no active priority pin; T121 director re-evaluates). **Choose: flip to `null`** so T121 reads state cleanly and routes off priority+tier-target without a stale pin. This matches the T118 closure approach (T118 flipped from edh-matsui to sign-pattern post-closure; T120 closes sign-pattern with no obvious successor at priority < 5 in OPEN state — leave `null` for T121 to choose).

After all edits, run `python3 -c 'import json; json.load(open("runs/_loop/state.json"))'` to verify JSON validity (this is in the allow-list; single-quoted argument).

#### Duty B — Cherry-pick auto-branch a323222 to bring canonical_mult_aware_beta_S onto main

Critic T119 §5.1 erratum #1 verbatim: "The `canonical_mult_aware_beta_S` wrapper (T115 §2) lives only on auto-branch `auto/turn_115_sign-pattern-f9-ta-mult2-T115-attempt2-candidate-i-test` commit `a323222`, not merged to main." Critic recommended_action verbatim: "Suggest T120+ implementer_text cherry-pick auto-branch commit a323222 to bring canonical_mult_aware_beta_S onto main".

**Approach** (text-only via git checkout, NO julia, NO re-derivation):

1. Verify commit a323222 exists: `git rev-parse --verify a323222^{commit}`. If exists, proceed; if not, fall back to manual reconstruction (see fallback below).
2. Identify which file at commit a323222 contains `canonical_mult_aware_beta_S`: `git show --stat a323222` to read changed-files list, then `git show a323222:scripts/manuscript/f9_f11_polyhedral_verification.jl` to read content if it's there.
3. Bring that file's content onto main:
   - Primary: `git checkout a323222 -- scripts/manuscript/f9_f11_polyhedral_verification.jl` (single-file checkout, in-place). Then verify file diff: `git diff HEAD -- scripts/manuscript/f9_f11_polyhedral_verification.jl` shows the new `canonical_mult_aware_beta_S` wrapper.
   - Verify presence on main: `grep -E -q 'canonical_mult_aware_beta_S' scripts/manuscript/f9_f11_polyhedral_verification.jl` (single-quoted regex, single binary).

**Fallback** if commit a323222 does not exist or git checkout fails: manually add the wrapper function based on T115 sim §6 description (`runs/_loop/sim/turn_115.md` lines 200-250) — implementer should read that and reconstruct. Document the fallback path in the sim report §3.

**HARD CONSTRAINT**: Do NOT run julia to verify the wrapper executes; T119 critic already verified the algebraic content. The Duty B work product is solely the on-disk presence of `canonical_mult_aware_beta_S` in the main HEAD's `scripts/manuscript/f9_f11_polyhedral_verification.jl`.

#### Duty C — Add F=2 cyclic T_d A_1 case to lemma1_general_S_verification.jl

Critic T119 §5.2 erratum #2 verbatim: "MEMORY entry 'Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)' claims 29 channels / 6 cases (adding F=2 cyclic-tetrahedral A_1 from T94); on-disk regression script has 26 channels / 5 cases." Critic recommended_action verbatim: "close MEMORY 29-vs-26 drift by adding F=2 cyclic A_1 case to lemma1_general_S_verification.jl".

**Edit target**: `scripts/manuscript/lemma1_general_S_verification.jl`

**Insert location**: between the existing F=4 cube @testset (lines 17-27) and F=6 icosa @testset (lines 29-40); OR equivalently at the start of the testset chain (any location inside the outer @testset is fine; ordering by F-value ascending is convention).

**Insert content** (exact rational values from MEMORY.md L77-80 F=2 cyclic-tetrahedral A_1 Tier-3 closure entry, verified at T94):

```julia
    # --- F=2 cyclic T_d A_1 (paper3 §V, MEMORY 2026-05-18 T94) ---
    @testset "F=2 cyclic T_d A_1" begin
        F = 2
        denom = 2 * F * (F + 1)  # = 12
        β_c0 = Dict(0 => 1//5, 2 => 2//7, 4 => 18//35)
        β_λ_paper3 = Dict(0 => -1//5, 2 => -1//7, 4 => 12//35)
        for S in [0, 2, 4]
            prefactor = (S*(S+1) - denom) // denom
            predicted = prefactor * β_c0[S]
            @test predicted == β_λ_paper3[S]
        end
    end
```

**Footer update** (line 115 — terminal println):

- From: `println("\n=== Lemma 1 General-S: 26 channel coefficients verified across 5 cases ===")`
- To:   `println("\n=== Lemma 1 General-S: 29 channel coefficients verified across 6 cases ===")`

3 + 26 = 29 channels; +1 case (F=2) → 6 cases. Matches MEMORY claim.

#### Duty D — Append T119+T120 closure entries to memory/sign_pattern_lemma1_mult_aware_2026_05_19.md

**Edit target**: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md`

**Append at end of file** (after current line 57 "T116 director directive..."):

```markdown

## 8. T119 critic Stage-2 audit (Tier-3 closure crosswalk)

T119 critic dispatched at T119 (independent-context audit). VERDICT: CORROBORATE. 5/5 deliverables independently re-derived:

- **A1 Canonical formula**: Schur's lemma applied to W⊗W subspace; trace-form derivation matches manuscript §V.2 + theorist T115 §2.B Candidate (i) exactly.
- **A2 J-involution endpoint**: One-line proof tightened from theorist §2.A eqs A1–A11. Using J = exp(-iπF_y) ∈ H for all H ∈ {T, O, I}, $J^\dagger P_W J = P_W$ and $J^2 = +I$ for integer F. Combined with $|0,0\rangle = (I\otimes J)|MES\rangle/\sqrt{2F+1}$ and $P_W^2 = P_W$: $\|(P_W \otimes P_W)|0,0\rangle\|^2 = \mathrm{Tr}(P_W^2)/(2F+1) = m_{\rm rep}/(2F+1)$ in three steps. Promotes theorist §2.A.4 [Plausible] α=A isotypic-allocation to rigorously established at trivial irrep.
- **A3 m_rep=2 at F=9 T:A**: Hamermesh orbit-counting m_rep = (1/|T|) Σ_g χ^(j=9)(g) χ^A(g)*. For T = {e, 8C_3, 3C_2}: χ^9(e) = 19, χ^9(C_3) = sin(19π/3)/sin(π/3) = 1, χ^9(C_2) = sin(19π/2)/sin(π/2) = -1. Sum = (1/12)(19·1 + 8·1 + 3·(-1)) = (1/12)(24) = 2 exactly.
- **A4 Numerical 1-ULP**: 1.388e-16 ≈ 2·eps(0.05). Rounding-only residue; physical answer is exact 1/19. 1e-13 corroboration threshold has ~3 orders margin.
- **A5 Sum rule + m_rep=1 reduction**: $\sum_S \hat\Pi_S = I_{(2F+1)^2}$ → $\sum_S \bar\beta_S^{\rm canonical} = m_{\rm rep}$ algebraically for any m_rep. m_rep=1 reduction is exact: $\bar\beta_S^{\rm canonical}|_{m_{\rm rep}=1} = \langle\zeta\otimes\zeta|\hat\Pi_S|\zeta\otimes\zeta\rangle = \beta_S^{(c_0)}$, strict-generalization (not approximate), so 26/26 regression bit-for-bit unchanged.

Two minor errata flagged non-blocking, both closed at T120 (see §9 below).

## 9. T120 implementer_text Tier-3 terminal closure

Investigation closed at Tier 3.0 via T120 implementer_text 4-duty bundle. Joins barnett T29, klaus-bch T59, T86-edh-matsui-original, T94-F=2-cyclic-A_1, and T118-edh-matsui-resumption as **5th project Tier-3 trajectory**.

State.json: tier 2.5 → 3.0, current_stage Update → closed, F1.result append T119 corroboration, last_verdict TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119, last_turn 120, last_critic_turn 119.

T119 errata closed at T120:

- **#1 (canonical_mult_aware_beta_S wrapper on main)**: cherry-picked auto-branch commit a323222 onto main's `scripts/manuscript/f9_f11_polyhedral_verification.jl`. Wrapper now present on main HEAD; future investigators can run `julia --project=. scripts/manuscript/f9_f11_polyhedral_verification.jl` and observe the bar_beta_0_canonical = 1/19 corroboration directly.

- **#2 (MEMORY 29-vs-26 regression drift)**: added F=2 cyclic T_d A_1 case (S=0/2/4 channels) to `scripts/manuscript/lemma1_general_S_verification.jl`. β_c0 = (1/5, 2/7, 18/35); β_λ_spin = (-1/5, -1/7, 12/35) verified at exact rational arithmetic (Tier-3 closure of F=2 cyclic at T94). Regression script now covers 29 channel coefficients across 6 polyhedral cases (F=2 cyclic A_1, F=3 octa A_2, F=4 cube, F=6 icosa, F=8 cube-octa A_1, F=10 dodec I_h), aligning on-disk record with MEMORY.md claim.

Investigation arc T112-T120 complete. 9 turns total. F=11 T:E_1 + F=12 + isotypic-allocation general-(F, H) remain in §6 Open questions for future investigations.
```

### 3.3 Branch / commit policy

Single auto-branch `auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle`, single commit covering all 4 duties + git push to local-only (NOT to main; orchestrator merges auto-branches per loop convention).

Commit message (conventional commits per anko's commit-style preference):

```
auto(loop): T120 PASS modify_text sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle

Tier-3 terminal closure for sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
(5th project Tier-3 trajectory). T119 critic CORROBORATE on 5/5 audit deliverables
A1-A5 (independent-context Schur / J-involution / Hamermesh / 1-ULP / algebraic
sum-rule re-derivation). 4-duty bundle:

- Duty A: state.json patch (tier 2.5 -> 3.0, current_stage Update -> closed,
  F1.result append T119 corroboration, last_verdict TIER_3_TERMINAL_CLOSURE,
  closing_note append T120 5th-trajectory marker, active_investigation_id null).
- Duty B: cherry-pick a323222 wrapper canonical_mult_aware_beta_S onto main
  scripts/manuscript/f9_f11_polyhedral_verification.jl (critic erratum #1).
- Duty C: add F=2 cyclic T_d A_1 case (S=0/2/4 channels) to
  scripts/manuscript/lemma1_general_S_verification.jl, closing 29-vs-26 drift
  (critic erratum #2).
- Duty D: append T119+T120 closure entries to memory file documenting the
  5th project Tier-3 trajectory.

No julia execution, no production-code modification, no compute. Text-only
mechanical bundle per memory feedback_mechanical_vs_investigation_threshold.

Assisted-by: claude-opus-4-7[1m] (model: claude-opus-4-7)
```

### 3.4 Hard constraints

- **NO julia execution at any point.** Duty B is a `git checkout a323222 -- <file>` — pure git operation, no Julia. Duty C is a markdown-style edit to a .jl file — no execution to verify. T119 critic ALREADY verified the algebraic content; T120 is propagation only.
- **NO modification of any production code** (`src/`, `test/` may not be touched). Only: `runs/_loop/state.json`, `scripts/manuscript/f9_f11_polyhedral_verification.jl`, `scripts/manuscript/lemma1_general_S_verification.jl`, `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md`.
- **NO modification of `runs/eu151_*` directories.** Per seed.md "accumulated runs ARE the data" + sibling Tier-3 closure invariant.
- **NO new YAML config, no new manuscript section.** Manuscript §V already on main HEAD per T118 Duty B.
- **Output path: `runs/_loop/sim/turn_120.md`** with §4 Metrics JSON block (per implementer convention, NOT a critic verdict report — judge.py will parse Metrics JSON normally, so this turn judge_status should NOT be FAIL_NO_METRICS).

## 4. Investigation update at T120 (anticipated)

For `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`:

| Field | Now | After T120 closure |
|---|---|---|
| `tier_current` | 2.5 | 3.0 |
| `tier` (mirror) | 2.5 | 3.0 |
| `current_stage` | "Update" | "closed" |
| `last_turn` | 116 | 120 |
| `last_stage` | "Update" | "Update-Stage-2-T119-critic" |
| `last_verdict` | "CORROBORATE_4_OF_4_PHYSICS_PASS_MANUSCRIPT_PROPAGATED" | "TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119_INDEPENDENT_CONTEXT_5TH_PROJECT_TIER_3_TRAJECTORY" |
| `last_critic_turn` | (not in inv block) | 119 |
| `falsifiers[0].tested_at_turns` | ["115_attempt1", 115] | ["115_attempt1", 115, 119] |
| `falsifiers[0].result` | T115 prose | T115 prose + " \|\| T119 critic Stage-2 CORROBORATE ..." |
| `stages_done` | ["Hypothesize", "Derive", "Test"] | append ["Document", "closed"] |
| `closing_note` | T112-T116 prose | append "\n\nT120 closure: ..." |

Top-level:
- `last_judge` → "TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119"
- `last_directive_label` → "sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle"
- `last_directive_action` → "modify_text"
- `active_investigation_id` → `null` (T121 director re-evaluates)
- `last_critic_turn` → preserved at 119 (T120 was not critic)
- `last_critic_verdict` → preserved at "CORROBORATE"

## 5. Success criteria — FORM B (RAW-ARTIFACT, ALLOW-LIST PROGRAM ONLY, REGEX IN SINGLE-QUOTES)

Per T115/T116/T118 shell-quoting lesson AND T117/T119 PASSING pattern: ALL check_cmds use single allow-listed programs (grep, test, git, jq, python3) with arguments only. Regex patterns wrapped in single-quotes (so judge.py's shlex.split keeps them as ONE argv element). NO `&&`, NO `||`, NO `|` as pipe, NO `$(...)`, NO `cd`, NO shell composition.

The T117 pattern that PASSED: `grep -E -q 'CORROBORATE|INCONCLUSIVE|REFUTED' file_path`. Single-quotes prevent `|` from being interpreted as a shell pipe.

For state.json JSON-field assertions, use `jq` directly with single-quoted filters: `jq -e '.field.path == "value"' file.json`. `jq` returns exit 0 if filter result is truthy.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19",
  "stage_advancing_to": "closed",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "project_axis": "D3",
  "rationale": "Per T119 director §7 pre-committed plan verbatim 'If T119 critic VERDICT = CORROBORATE -> implementer_text Duty A: state.json sign-pattern-f9-ta-mult2 closure patch' AND T119 critic VERDICT: CORROBORATE on 5/5 audit deliverables A1-A5 (sim/turn_119.md L167) AND state.json closing_note verbatim 'eligible for Tier 3 closure pending T117+ critic crosswalk audit (central falsifier F1 marked)' AND state.json F1 is_central=true with machine-precision CORROBORATE AND state.json active_investigation_id=sign-pattern-f9-ta-mult2 (preserved from T118) AND T119 critic recommended_action verbatim 'Suggest T120+ implementer_text cherry-pick auto-branch commit a323222 to bring canonical_mult_aware_beta_S onto main, AND close MEMORY 29-vs-26 drift by adding F=2 cyclic A_1 case to lemma1_general_S_verification.jl'. Mechanical class per memory feedback_mechanical_vs_investigation_threshold (4 text-only edits with regex-verifiable outcomes) -> implementer_text. Bundled per memory feedback_cost_overhead_is_the_cost (independent duties, single subagent class, zero ordering dependency). Class-fix per memory feedback_fix_the_class_not_the_instance (BOTH critic errata closed in one pass — same 'T115-era propagation completeness gap' class). D3 axis primary (closes 5-turn T112-T119 trajectory at Tier 3.0; 5th project Tier-3 closure after barnett T29, klaus-bch T59, T86-edh-matsui, T94-F=2-cyclic, T118-edh-matsui-resumption); D1 axis secondary (regression-script extension from 26ch/5cases to 29ch/6cases aligns on-disk record with MEMORY claim). Sources read this turn: scheduler_120.json (JULIA_GPU_OK; implementer_text allowed); state.json L1595-1673 (T119 history substantive_verdict CORROBORATE, top-level last_critic_turn 119, active_investigation_id sign-pattern); state.json L2930-3013 (investigation block tier 2.5, F1 is_central CORROBORATE machine precision); sim/turn_119.md (T119 critic 5/5 CORROBORATE with two errata flagged); director/turn_119.md §7 (T120 dispatch pre-commit); director/turn_118.md L1-120 (T118 closure template - state.json patch + bundled-duty precedent); sim/turn_118.md L1-100 (T118 implementer execution success); seed.md (priority-0 SATISFIED, falls through); memory:sign_pattern_lemma1_mult_aware_2026_05_19 (canonical statement + file anchors + 29-vs-26 caveat §5); memory:feedback_mechanical_vs_investigation_threshold (closure paperwork class); memory:feedback_cost_overhead_is_the_cost (bundle); memory:feedback_fix_the_class_not_the_instance (close both errata); memory:feedback_use_existing_artifacts_first (F=2 β values already in MEMORY); scripts/manuscript/lemma1_general_S_verification.jl L1-30+100-116 (structure for Duty C). Cost expected ~1.4M effective (Read ~10 files + Write 4 files + 1 git checkout + 1 git commit, no julia, no compute). 40% below T118 (2.3M) aligned with DRIFT_COST_INFLATION advisory. Shell-quoting class addressed by single-quoted regex + single-binary check_cmds per T117/T119 PASSING discipline.",
  "brief": "You are implementer_text. Single auto-branch, single commit, 4 duties, text-only.\n\n## Read order (BEFORE any Write)\n\n1. /home/suzume/workspace/BEC-simulation/runs/_loop/state.json — read investigation block at lines 2930-3013 AND top-level fields at lines 1659-1673. Skip the history array (lines 4-1654; not needed).\n2. /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_119.md — full (168 lines). T119 critic CORROBORATE verdict with 5/5 deliverables + 2 errata.\n3. /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl — full (116 lines). Existing 5 @testset structure.\n4. /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md — full (57 lines). Memory entry.\n5. /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_118.md — lines 1-120 only. T118 closure precedent template.\n6. /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md — this file (the directive itself).\n\n## Duty A — state.json patch (mirror T118 pattern)\n\nKey path: investigations['sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19'].\n\nEdits (use Edit tool, surgical):\n- tier_current: 2.5 -> 3.0\n- tier: 2.5 -> 3.0\n- current_stage: Update -> closed\n- last_turn: 116 -> 120\n- last_stage: Update -> Update-Stage-2-T119-critic\n- last_verdict: CORROBORATE_4_OF_4_PHYSICS_PASS_MANUSCRIPT_PROPAGATED -> TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119_INDEPENDENT_CONTEXT_5TH_PROJECT_TIER_3_TRAJECTORY\n- last_critic_turn: add field with value 119 (within the investigation block, NOT just top-level)\n- stages_done array: append Document and closed entries\n- stages_at_turn map: append Document with [119, 'critic T119 independent-context audit 5/5 deliverables A1-A5 CORROBORATE'] AND closed with [120, 'implementer_text 4-duty terminal closure: state.json + cherry-pick a323222 + F=2 cyclic A_1 regression case + memory entry']\n- falsifiers[0].tested_at_turns: ['115_attempt1', 115] -> ['115_attempt1', 115, 119]\n- falsifiers[0].result: append after a ' || ' separator: 'T119 critic Stage-2 CORROBORATE (independent-context audit, 5/5 deliverables A1-A5: Schur-canonical formula re-derivation, J^dag P_W J = P_W + P_W^2 = P_W one-line endpoint proof, Hamermesh orbit-counting m_rep = (1/12)(19+8-3) = 2 exactly, 1.388e-16 = 2 ULP at 0.05 rounding-only, F4 sum-rule algebraic from sum_S Pi_S = I, F3 m_rep=1 reduction strict-generalization). 5th project Tier-3 trajectory closure.'\n- closing_note: append after a newline + 'T120 closure:' separator: 'Tier 3.0 terminal closure at T120 via implementer_text 4-duty bundle. T119 critic CORROBORATE on 5/5 deliverables A1-A5. 5th project Tier-3 trajectory (after barnett T29, klaus-bch T59, T86-edh-matsui-original, T94-F=2-cyclic-A_1, T118-edh-matsui-resumption). Two critic-flagged errata closed: (1) cherry-picked a323222 to bring canonical_mult_aware_beta_S onto main; (2) added F=2 cyclic T_d A_1 case to lemma1_general_S_verification.jl closing the 29-vs-26 MEMORY drift. Investigation closed.'\n\nTop-level edits (file root level, NOT inside investigations):\n- last_judge: FAIL_NO_METRICS -> TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119\n- last_directive_label: -> sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle\n- last_directive_action: -> modify_text\n- active_investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19 -> null (T121 director re-evaluates)\n\nAfter all edits, validate JSON: python3 -c 'import json; json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); print(\"OK\")'. Must print OK.\n\n## Duty B — Cherry-pick a323222\n\nVerify commit exists: git rev-parse --verify a323222^{commit}\nIdentify the wrapper file: git show --stat a323222 (look for scripts/manuscript/f9_f11_polyhedral_verification.jl in the changed-files list).\nPrimary path: git checkout a323222 -- scripts/manuscript/f9_f11_polyhedral_verification.jl\nVerify: grep -E -q 'canonical_mult_aware_beta_S' scripts/manuscript/f9_f11_polyhedral_verification.jl (should exit 0).\n\nFallback if a323222 does not exist: read sim/turn_115.md §2 and §6 to reconstruct the canonical_mult_aware_beta_S wrapper manually. Wrapper signature: canonical_mult_aware_beta_S(rho_inv, F::Int, S::Int) returning m_rep * mult_aware_beta_S(rho_inv, F, S) where mult_aware_beta_S computes Tr[Pi_S (rho_inv x rho_inv)] via the spin-S CG-projector. Document fallback in sim/turn_120.md §3.\n\nHARD CONSTRAINT: NO julia execution to verify wrapper executes. T119 critic already verified algebraic content. Duty B success = on-disk presence of canonical_mult_aware_beta_S in main HEAD's scripts/manuscript/f9_f11_polyhedral_verification.jl.\n\n## Duty C — Add F=2 cyclic case to lemma1_general_S_verification.jl\n\nEdit target: /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl\n\nInsert location: between current F=4 cube @testset (ending around line 27) and F=6 icosa @testset (starting around line 29). Recommend inserting BEFORE F=4 to keep ascending F order:\n\nInsert this exact block (3-space-indent to match existing style, but check existing indentation):\n\n    # --- F=2 cyclic T_d A_1 (paper3 §V, MEMORY 2026-05-18 T94) ---\n    @testset \"F=2 cyclic T_d A_1\" begin\n        F = 2\n        denom = 2 * F * (F + 1)  # = 12\n        β_c0 = Dict(0 => 1//5, 2 => 2//7, 4 => 18//35)\n        β_λ_paper3 = Dict(0 => -1//5, 2 => -1//7, 4 => 12//35)\n        for S in [0, 2, 4]\n            prefactor = (S*(S+1) - denom) // denom\n            predicted = prefactor * β_c0[S]\n            @test predicted == β_λ_paper3[S]\n        end\n    end\n\nFooter update (line 115 terminal println):\n- From: println(\"\\n=== Lemma 1 General-S: 26 channel coefficients verified across 5 cases ===\")\n- To:   println(\"\\n=== Lemma 1 General-S: 29 channel coefficients verified across 6 cases ===\")\n\n## Duty D — Memory entry append\n\nEdit target: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md\n\nAppend two new sections (§8 T119 critic Stage-2 audit, §9 T120 implementer_text Tier-3 terminal closure) at end of file. Content drafted in director/turn_120.md §3.2 Duty D verbatim — copy that block literally.\n\nAt the top of file (line 4), update tier line:\n- From: **Tier**: 2.5 (Update stage active at T116; eligible for Tier 3 closure pending T117+ critic crosswalk audit — central falsifier F1 marked).\n- To:   **Tier**: 3.0 (closed at T120; 5th project Tier-3 trajectory).\n\nAt line 6, update loop arc:\n- From: **Loop arc**: T112-T116.\n- To:   **Loop arc**: T112-T120 (9 turns; T119 critic CORROBORATE Stage-2; T120 implementer_text terminal closure).\n\n## Branch / commit policy\n\nSingle auto-branch: auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle\nParent: current HEAD (post-T118 commit f2a5d2c).\nSingle commit with the conventional message in director/turn_120.md §3.3.\nDo NOT push to main; orchestrator handles merge per loop convention.\n\n## Output\n\nWrite runs/_loop/sim/turn_120.md with structure:\n- §1 Directive received\n- §2 Branch / commit (commit hash after commit)\n- §3 Schema/sibling audit (N/A explanation)\n- §4 Metrics (JSON block with sc_passed/sc_failed/duty_*_complete booleans; must include a parseable §4 Metrics JSON so judge.py emits a proper PASS / FAIL verdict, NOT FAIL_NO_METRICS as in T117/T119)\n- §5 What changed (per-duty diff summary)\n- §6 Next actions for T121 director\n\nCost target: 1.4M-1.7M. Hard cap: 2.5M.",
  "observable_manifest": {
    "required": [
      "state_json_tier_3_0_set",
      "state_json_current_stage_closed",
      "state_json_F1_result_T119_appended",
      "state_json_last_judge_top_level_patched",
      "state_json_active_investigation_id_null",
      "f9_f11_wrapper_present_main_head",
      "lemma1_F2_cyclic_case_present",
      "lemma1_footer_29_channels_6_cases",
      "memory_section_8_T119_present",
      "memory_section_9_T120_present",
      "memory_tier_3_0_set",
      "state_json_valid",
      "no_src_modified",
      "no_test_modified",
      "no_runs_eu151_modified"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_119.md"
  },
  "success_criteria": [
    {
      "id": "SC1-state-tier-3-0-set",
      "check_cmd": "jq -e '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].tier_current == 3.0' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC2-state-current-stage-closed",
      "check_cmd": "jq -e '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].current_stage == \"closed\"' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC3-state-F1-tested-at-T119",
      "check_cmd": "jq -e '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].falsifiers[0].tested_at_turns | index(119) != null' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC4-state-F1-result-mentions-T119-corroborate",
      "check_cmd": "jq -re '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].falsifiers[0].result' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0, "stdout_contains": "T119"}
    },
    {
      "id": "SC5-state-last-turn-120",
      "check_cmd": "jq -e '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].last_turn == 120' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC6-state-last-verdict-tier3-closure",
      "check_cmd": "jq -re '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].last_verdict' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0, "stdout_contains": "TIER_3_TERMINAL_CLOSURE"}
    },
    {
      "id": "SC7-state-top-level-active-investigation-null",
      "check_cmd": "jq -e '.active_investigation_id == null' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC8-state-top-level-last-judge-tier3",
      "check_cmd": "jq -re '.last_judge' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0, "stdout_contains": "TIER_3_TERMINAL_CLOSURE"}
    },
    {
      "id": "SC9-state-json-valid",
      "check_cmd": "python3 -c 'import json,sys; json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); print(\"OK\")'",
      "expect": {"exit_code": 0, "stdout_contains": "OK"}
    },
    {
      "id": "SC10-duty-b-wrapper-on-main",
      "check_cmd": "grep -E -q 'canonical_mult_aware_beta_S' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC11-duty-c-F2-cyclic-testset-present",
      "check_cmd": "grep -E -q 'F=2 cyclic' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC12-duty-c-rational-1-5-2-7-18-35-present",
      "check_cmd": "grep -E -q '1//5.*2//7.*18//35|18//35' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC13-duty-c-footer-29-channels-6-cases",
      "check_cmd": "grep -E -q '29 channel.*6 cases|29 channel coefficients verified across 6' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC14-duty-d-memory-section-8-T119",
      "check_cmd": "grep -E -q 'T119 critic Stage-2|## 8' /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC15-duty-d-memory-section-9-T120",
      "check_cmd": "grep -E -q 'T120 implementer_text|## 9' /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC16-duty-d-memory-tier-3-set",
      "check_cmd": "grep -E -q 'Tier.*3.0|tier.3.0|closed at T120' /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC17-no-src-modified",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/src -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -type f -name '*.jl'",
      "expect": {"exit_code": 0, "stdout_not_contains": ".jl"}
    },
    {
      "id": "SC18-no-test-modified",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/test -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -type f -name '*.jl'",
      "expect": {"exit_code": 0, "stdout_not_contains": ".jl"}
    },
    {
      "id": "SC19-no-runs-eu151-modified",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/runs -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -type f -name 'trajectory.csv'",
      "expect": {"exit_code": 0, "stdout_not_contains": "eu151"}
    },
    {
      "id": "SC20-sim-turn-120-metrics-block-present",
      "check_cmd": "grep -E -q 'experiment_kind|workload_class|sc_passed' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_120.md",
      "expect": {"exit_code": 0}
    }
  ],
  "failure_modes": [
    {
      "if": "SC1 OR SC2 failed (state.json tier or current_stage not patched)",
      "category": "operational",
      "next_action": "T121 director re-dispatches implementer_text narrowly for state.json fix-up; same investigation, missed closure"
    },
    {
      "if": "SC9 failed (state.json invalid JSON)",
      "category": "operational",
      "next_action": "BLOCKING — T121 director MUST first restore state.json from previous-turn git tag before any further dispatch"
    },
    {
      "if": "SC10 failed (Duty B git checkout failed and fallback not attempted)",
      "category": "operational_partial",
      "next_action": "Accept Tier-3 closure if Duties A/C/D succeeded; T121 dispatches separate implementer_text for Duty B as standalone (manual wrapper reconstruction from sim/turn_115.md §6)"
    },
    {
      "if": "SC11 OR SC12 OR SC13 failed (Duty C regression-script not extended correctly)",
      "category": "data_gap",
      "next_action": "T121 dispatches narrow implementer_text for Duty C completion; investigation remains closed at Tier 3.0 but the 29-vs-26 drift remains open"
    },
    {
      "if": "SC14 OR SC15 OR SC16 failed (memory entry not updated)",
      "category": "data_gap",
      "next_action": "T121 dispatches narrow implementer_text for memory append; non-blocking for Tier-3 closure"
    },
    {
      "if": "SC17 OR SC18 failed (src/test modified — scope violation)",
      "category": "scope_violation",
      "next_action": "T121 director audits the touched files; if changes accidental, revert; if intentional, treat as a separate investigation and re-classify"
    },
    {
      "if": "T120 cost > 2.0M effective",
      "category": "operational_budget",
      "next_action": "Flag DRIFT_COST_INFLATION; T121 director audits the per-duty cost split; bundle size may need reduction to 2-3 duties going forward"
    }
  ],
  "budget": {
    "expected_cost_eff": 1400000,
    "expected_wall_time_sec": 1200
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_partial_advance_to_stage": "closed",
    "if_partial_tier_becomes": 3.0,
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 2.5,
    "if_success_falsifier_update": {
      "id": "F1-mult-aware-bar_beta_0-equals-1-over-2F-plus-1",
      "tested_at_turn": 119,
      "result_template": "TIER_3_TERMINAL_CLOSURE: T119 critic Stage-2 CORROBORATE 5/5 deliverables (A1 Schur canonical formula re-derived, A2 J-involution endpoint proof tightened to one-line Tr(P_W^2)/(2F+1) = m_rep/(2F+1), A3 Hamermesh orbit-counting m_rep = (1/12)(19+8-3) = 2 exact, A4 1.388e-16 = 2 ULP rounding-only, A5 algebraic sum-rule + m_rep=1 strict reduction); T115 Stage-1 4/4 falsifier machine-precision corroboration retained. 5th project Tier-3 trajectory closure."
    },
    "note": "T120 implementer_text 4-duty bundle closure. NOT a critic route this turn (T119 was critic). T120 should emit standard §4 Metrics JSON in sim/turn_120.md so judge.py emits PASS (not FAIL_NO_METRICS as at T117/T119). Anticipated T121 dispatch: re-evaluate priority queue (sign-pattern now closed at 3.0; edh-matsui closed at 3.0; yan-li-saito-2026-reproduction at priority 1 tier 0.4 is the highest-leverage open candidate; OR audit-class-scan cycle if AUDIT_DUE gap continues climbing). Anko may also insert a new seed.md priority. T121 director MUST flip active_investigation_id to the next-priority OPEN investigation (or leave null and pick fresh per protocol)."
  }
}
```

## 7. What T121 will read

T121 director reads (in order):
1. `runs/_loop/sim/turn_120.md` — implementer_text §4 Metrics JSON + §5 per-duty diff summary.
2. `runs/_loop/judge/turn_120.json` — judge.py verdict (expected PASS since §4 Metrics block present, in contrast to T117/T119 critic-route FAIL_NO_METRICS).
3. `runs/_loop/state.json` — post-closure state (sign-pattern at tier 3.0/closed, active_investigation_id=null, last_judge=TIER_3_TERMINAL_CLOSURE_F1_CORROBORATE_T119).
4. This file `runs/_loop/director/turn_120.md` — pre-committed plan for T121 dispatch.

T121 dispatch (anticipated):
- If T120 SCs all PASS → T121 picks next-priority candidate. Top candidates: yan-li-saito-2026-reproduction (priority 1, tier 0.4, open — fresh research investigation); OR audit-class-scan cycle (AUDIT_DUE gap=15 at T120, threshold-met for ~5 turns); OR meta-cost-waste-audit at priority 15 (D4, lower leverage); OR anko-inserted new seed.md priority. **Recommendation**: yan-li-saito if research workload is allowed; audit-class-scan only if anko's pattern catalog has drifted enough to need attention.
- If T120 partial PASS (some duties succeed, others fail) → T121 dispatches narrow follow-up implementer_text for the failed duties; Tier-3 closure is preserved if Duty A succeeded.
- If T120 SC17/SC18 trip (scope violation) → T121 audits + reverts.

## 8. Drift advisories addressed at T120

| Drift | T119 reading | T120 action |
|---|---|---|
| AUDIT_DUE patterns.yaml gap=14 | flagged advisory at T119 | gap=15 at T120 (threshold-met). T120 explicitly DEFERS to T121 because Tier-3 closure paperwork is higher-leverage than audit-class-scan cycle; T121 will reassess. Memory `feedback_decision_style`: defer, don't deliberate. |
| DRIFT_COST_INFLATION (T118 ratio 1.54 BUDGET_OVER) | flagged | T120 target 1.4M (~60% of T118's 2.3M). 4-duty bundle is cheaper than 2 separate 2-duty turns due to shared Reads. |
| Shell-quoting class (T115/T116/T118 INCONCLUSIVE) | flagged structural at T119 | T120 SC catalog uses ONLY single-quoted regex + single-binary check_cmds (jq with single-quoted filters, grep with -E -q + single-quoted pattern, python3 -c with single-quoted argument, find with -name + literal). NO `&&`, NO `||`, NO `|` as pipe, NO `$(...)`, NO `cd`. Explicit hand-discipline matching T117/T119 PASSING pattern. meta-stage-routing-2026-05-19 auto-spawn (priority 25) NOT activated because the cure is example-driven adherence. |
| subagent_repetition 0.333 | advisory | T120 switches to implementer_text (T119 was critic). Drops repetition further. |
| verdict_drift 0.8 (T119) | high | T120 is a closure paperwork turn with predictable PASS outcomes — should drop verdict_drift sharply. |

## 9. Hard precedence + final commit

Per director.md "Precedence (single rule, last word)":
- `seed.md` priority-0 SATISFIED → falls through to default protocol routing.
- `scheduler.json` allows implementer_text → no veto.
- This director.md routing → implementer_text on sign-pattern-f9-ta-mult2 for 4-duty Tier-3 closure bundle per active_investigation + closing_note + T119 critic recommended_action.
- T119 director §7 pre-committed plan EXPLICITLY directs this T120 dispatch.

No conflicts. §6 dispatch JSON is authoritative.

---

(turn_120.md director report — 2026-05-19 — sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19 Tier-3 terminal closure bundle, 5th project Tier-3 trajectory)
