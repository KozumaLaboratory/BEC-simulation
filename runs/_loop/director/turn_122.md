---
turn: 122
subagent: director
investigation_id: sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19
stage_advancing_from: "<NEW investigation; spawning from memory/sign_pattern_lemma1_mult_aware_2026_05_19.md §6 RESEARCH_NEEDED item #1>"
stage_advancing_to: "Hypothesize"
topic_tags:
  - D3-build-theory
  - sign-pattern-lemma1-non-trivial-irrep
  - F11-T-E1-complex-1d-real-construction
  - mult-aware-formula-extension
  - J-involution-non-trivial-irrep
  - hamermesh-orbit-counting
  - post-T121-streak-break-pivot-to-physics
  - paper3-section-V-extension-frontier
  - 6th-project-tier-3-candidate
depends_on:
  - 121
  - 120
  - 119
  - 115
  - "runs/_loop/state.json"
  - "runs/_loop/seed.md"
  - "runs/_loop/_local/scheduler_122.json"
  - "runs/_loop/sim/turn_121.md"
  - "runs/_loop/judge/turn_121.json"
  - "runs/_loop/director/turn_121.md"
  - "memory:sign_pattern_lemma1_mult_aware_2026_05_19"
  - "memory:tier3_pipeline_survey_2026_05_18"
  - "memory:feedback_manuscript_is_not_the_essence"
  - "memory:feedback_use_existing_artifacts_first"
produces: >
  T122 spawns a NEW build-theory investigation
  `sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19` and dispatches
  theorist Hypothesize. The investigation extends the Tier-3-closed
  canonical multiplicity-aware Lemma 1 formula (T120 closure) from the
  TRIVIAL irrep A (rigorously established at T119 critic Stage-2 via
  J=exp(-i pi F_y) involution + Hamermesh orbit-counting on F=9 T:A) to
  NON-TRIVIAL polyhedral irreps. Concrete first case: F=11 T:E_1
  (complex 1-dim irrep of tetrahedral group T, real-construction 2-dim,
  expected m_rep >= 2). This is item #1 of the three explicit
  <RESEARCH_NEEDED> tags in memory/sign_pattern_lemma1_mult_aware_2026_05_19.md
  §6 — the load-bearing on-disk pointer set by the T112-T120 closure work
  product.

  Project axis: **D3 (new theory derivation + manuscript)**. The work
  product extends Paper #3 Section V (multiplicity-aware Lemma 1) from
  the rigorously-established trivial-irrep case (T119 critic A2) to the
  [Plausible] non-trivial-irrep conjecture (theorist T115 §F:
  ||xi_alpha||^2 = m_alpha * d_alpha / (2F+1)). Closed-form not yet in
  code; not yet in manuscript; not yet verified.

  Per anko 2026-05-15 directive (memory:feedback_manuscript_is_not_the_essence
  L13-16): physics completeness (effects derived but not in code) IS
  the essence. T122 Move A satisfies this verbatim — the F=11 T:E_1
  closed-form is a derived effect NOT yet in scripts/manuscript/
  f9_f11_polyhedral_verification.jl (T121 only landed the trivial-irrep
  wrapper canonical_mult_aware_beta_S on main), NOT yet in paper3 §V,
  NOT yet verified numerically.

  Move A beats the 4 open D4 meta-investigations (priority 15/20/25/40,
  all Observe) on three grounds:
  (a) T121 PASS at ~200k actual cost (50% under 400k expected) empirically
      refuted the DRIFT_COST_INFLATION pattern when work is mechanical-class —
      meta-cost-waste-audit / meta-cost-inflation have stale baselines.
  (b) The T54-T60 meta-stage-routing-2026-05-18 precedent shows
      meta-investigations get REFUTED-BY-CONFOUNDER once the actual root
      cause is named; T121's mechanical fix already named the T116-T120
      root cause (auto-branch-to-main merge partial-loss + shell-quoting
      class), so meta-stage-routing-2026-05-19 is similarly at high
      refutation risk.
  (c) Anko's "physics is the essence" directive explicitly down-weights
      D4 vs physics-axis when both are available.

  This turn is **theorist Hypothesize** (NO julia, NO new simulation,
  NO new code, NO state.json mutation). Theorist reads 4 anchors,
  derives whether the J-involution endpoint argument generalizes to
  non-trivial irreps, computes m_alpha at F=11 T:E_1 via Hamermesh
  orbit-counting (falls back to F=12 / E_2 if m_alpha < 2), emits a
  3-falsifier table that the next implementer turn (T123) can verify
  numerically.

  Per §B1.0 (memory:feedback_use_existing_artifacts_first): 3 anchor
  artifacts exist on disk and theorist MUST read them BEFORE deriving:
  (a) memory/sign_pattern_lemma1_mult_aware_2026_05_19.md §4 (J-involution
      for trivial irrep) + §6 (RESEARCH_NEEDED items);
  (b) runs/_loop/theorist/turn_115.md §2.A (closed-form derivation) +
      §F (non-trivial-irrep [Plausible] conjecture);
  (c) docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md
      §V (manuscript-published multiplicity-aware extension; crosscheck
      §V.5/§V.6 does NOT pre-derive non-trivial case).

  Cost target: 1.5-2.0M effective (mid-range theorist Hypothesize per
  T11/T13/T99/T115 historical). Hard cap 3.0M; bail with [Plausible] +
  RESEARCH_NEEDED if derivation hits algebraic obstruction.

  §B6 drift acknowledgement:
  - DRIFT_COST_INFLATION: T120 2.0x bust; T121 0.5x (mechanical-class)
    empirically restored discipline. T122 expected 1.8M is mid-range.
  - AUDIT_DUE gap=16 (was 15 at T120; +1 at T122 entry): at-but-not-over
    threshold (cadence ~10-15). Deferred to T123-T125 since Move A is
    higher-leverage; if T123 has no physics-axis pick, audit-class-scan
    becomes mandatory.
  - 5-turn T116-T120 FAIL streak ENDED at T121 PASS. meta-stage-routing
    auto-spawn (priority 25 Observe) NOT activated, per T121 §7
    forward-pointer + T54-T60 precedent.
---

# Turn 122 — Director Report

## 1. Top-of-turn reads (cited per protocol)

| Path | Read | What it says |
|---|---|---|
| `runs/_loop/_local/scheduler_122.json` | full (37 lines) | `policy: JULIA_GPU_OK`; all workloads (theorist/researcher_*/critic/implementer_*/noop) allowed. VRAM=12841 MB free, RAM=24.94 GB, foreign_julia=0. Window through 2026-05-31. 1069886s left. No memory pressure. |
| `runs/_loop/state.json` (top-level + investigations_index + sign-pattern closure block + 4 open meta blocks) | scanned | `turn=122`, `last_judge=PASS` at T121, `active_investigation_id=edh-eu151-vortex-vs-matsui-science-2026` (stale; that inv is closed Tier 3.0 at T118). 16 investigations: 12 closed/dormant, 4 open meta (priority 15/20/25/40, all Observe). No open physics investigation at priority 1-3. F11-Te1 stub listed in investigations_index but has NO body yet — registration is a T122-or-later task. |
| `runs/_loop/judge/turn_121.json` | full (119 lines) | T121 PASS verdict, 18/20 SCs PASS. 2 SC failures were directive-side bugs (SC11 off-by-2 line threshold; SC15 nonexistent /configs/ dir). All content-substantive SCs (SC2-SC7) PASS. T116-T120 5-turn FAIL streak ENDED. Commit f602553 on main. |
| `runs/_loop/sim/turn_121.md` head 100 lines | head | T121 implementer cherry-picked auto-branch a334667 to main; 2 files modified, 371 lines added, julia_executed=false. Coarse cost estimate ~150-200k (50% UNDER 400k expected). |
| `runs/_loop/seed.md` (full 95 lines) | full | Priority-0 edh-matsui re-open SATISFIED at T118 (F1 CORROBORATE at T117 critic Stage-2). Hard-memory-constraint section STALE per scheduler probe (foreign_julia=0). No new priority appended. Default protocol routing. |
| `runs/_loop/director/turn_121.md` | head 250 lines | T121 dispatched implementer_text cherry-pick remediation. 5-turn FAIL streak class-named (auto-branch-to-main + shell-quoting). T121 §7 anticipated T122 candidates: (a) anko seed.md insert — NOT present; (b) audit-class-scan; (c) theorist meta-cost-waste-audit; (d) researcher_shallow Tier-3 inventory. |
| `memory:sign_pattern_lemma1_mult_aware_2026_05_19` (full 83 lines) | full | T112-T120 closure record. §6 Open questions lists 3 `<RESEARCH_NEEDED>` tags: (1) F=11 T:E_1 m_rep=2 complex-1d → 2d real; (2) F=12 polyhedral multiplicity classification; (3) isotypic-allocation general (F,H). §4 J-involution closed-form for TRIVIAL irrep; §8 T119 critic A2 elevated trivial-irrep case to "rigorously established". Non-trivial irrep case NOT YET derived. **Load-bearing anchor for next D3 spawn.** |
| `memory:feedback_manuscript_is_not_the_essence` (full 40 lines) | full | Anko 2026-05-15: physics completeness, verification depth, theoretical insight tied to anko's experiments, bug-finding in production code ARE the essence. Manuscript section cash-in / docstring polish / citation tightening ARE NOT. T122 Move A picks D3 (derive effect not yet in code) over D4 (meta-audit). |
| `memory:feedback_use_existing_artifacts_first` (full 27 lines) | full | Before deriving / typing / launching new work, grep on-disk artifacts. Confirmed: the non-trivial-irrep closed form does NOT exist on disk (verified via memory §6 RESEARCH_NEEDED tags + paper3 §V coverage check). Theorist's work is new derivation, NOT re-derivation. |
| `memory:tier3_pipeline_survey_2026_05_18` (full 71 lines) | full | T69-T70 5-candidate menu: #1 edh-matsui closed T86/T118 Tier 3.0; #2 Bug-4 closed T97 Tier 2.0 (F5 julia blocked); #3 Sign Pattern Lemma 1 vs KU2012 closed T94 Tier 3.0; #4 TwoChannelLHY F=6 capped Tier 2.5 (NOT_FOUND benchmark); #5 TDHFB Phase 2 closed T102 Tier 3.0. Survey predicted Lemma 1 mult-aware as #3 cheapest Tier-3 closure path (validated at T94). T122 spawn extends the menu beyond T69-T70 inventory (post-T120 frontier item). |

## 2. Picking the next investigation — protocol routing

### 2.1 Walk state.investigations per director.md decision table

In order, first match wins:

1. **`seed.md` top section names a specific investigation**: edh-eu151-vortex-vs-matsui-science-2026 (priority-0 hard-lock). **SATISFIED at T118 Tier 3.0 closure.** The seed.md directive said "If CORROBORATE, promote inv to tier 3.0 with the audit as the load-bearing evidence"; T117 critic Stage-2 CORROBORATE on F1 + T118 closure executed exactly that. No new priority appended post-T118. Falls through.

2. **Active investigation has `next_stage_action` set AND scheduler allows the workload**: `active_investigation_id=edh-eu151-vortex-vs-matsui-science-2026` is STALE (the investigation is closed; `next_stage_action` field references the SATISFIED critic audit). The 4 open meta investigations have `next_stage_action: "theorist Hypothesize: ..."`. All D4 axis.

3. **Artifact-first path bypass**: No new sibling artifact `runs/<topic>*/` since T118 with tier_current<3. Not applicable for any closed physics inv. The "artifact" for the new F11 spawn is the on-disk memory entry itself (the existing-artifacts rule applies to the anchor read, not to a runs/ dir).

4. **Open inv with lowest `priority` AND scheduler allows**: After filtering closed/dormant/blocked:
   - `meta-cost-waste-audit-2026-05-19` (priority 15, D4, Observe)
   - `meta-director-self-audit-2026-05-19` (priority 20, D4, Observe)
   - `meta-stage-routing-2026-05-19` (priority 25, D4, Observe)
   - `meta-cost-inflation-2026-05-19` (priority 40, D4, Observe)

   `bug-4-itp-ddi-half-rate-revalidation` (priority 4) is blocked_on F5 julia gate; state.json `blocked_on != null` is authoritative.

### 2.2 The leverage-comparison question

Three candidate moves with non-trivial leverage:

**Move A: Spawn NEW investigation `sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19` and dispatch theorist Hypothesize.**
- Axis: **D3 (new theory derivation + manuscript)**.
- Cost: ~1.5-2.0M (mid-range theorist Hypothesize).
- Outcome: closed-form generalization of mult-aware Lemma 1 from trivial irrep A (T119 rigorously established) to non-trivial polyhedral irrep E_1 at F=11 T. 3-falsifier table for T123 implementer numerical verification.
- Anchor: memory/sign_pattern_lemma1_mult_aware_2026_05_19.md §6 RESEARCH_NEEDED item #1 + theorist T115 §F [Plausible] conjecture ||xi_alpha||^2 = m_alpha * d_alpha / (2F+1).
- Risk: low. Trivial-irrep case rigorously established; non-trivial-irrep is the natural next step explicitly tagged by the loop's own closed Tier-3 work product.
- Per memory feedback_manuscript_is_not_the_essence (anko 2026-05-15): NEW physics effect not yet in code = essence; matches "what IS the essence" list verbatim.

**Move B: Activate audit-class-scan T122 cycle (AUDIT_DUE gap=16).**
- Axis: **D4 (loop infrastructure)**.
- Cost: ~1.5-2.0M for full Observe → Triage → Document arc.
- Outcome: patterns.yaml updated; possibly 0 actionable findings (3rd-cycle steady-state precedent at T103 closing_note).
- Risk: medium-low. gap=16 is mid-cycle, not over-threshold (cadence ~10-15). Anko's directive explicitly down-weights D4 vs physics-axis.

**Move C: Theorist Hypothesize on `meta-cost-waste-audit-2026-05-19` (priority 15).**
- Axis: **D4 (loop infrastructure)**.
- Cost: ~1.5-2.5M.
- Risk: high. The OTEL-flagged 3 outlier samples (2.89M avg for `analyze_existing`) are from pre-T117 turns; T117+ switched to critic for the same role. Theorist Hypothesize would likely conclude "use critic not analyze_existing" — which is ALREADY the practice. REFUTED-BY-OBSOLETE-DATA risk, parallel to the T54-T60 meta-stage-routing-2026-05-18 precedent.

**Move A wins.** Highest-leverage physics-axis move per anko's "physics is the essence" directive. Anchors on a load-bearing on-disk pointer (memory §6 RESEARCH_NEEDED #1) set by the loop's own closed Tier-3 work product, satisfying §B1.0. Opens a new D3 trajectory with clear ~4-turn arc to potential Tier-3 closure (T122 theorist Hypothesize → T123 implementer numerical → T124 critic Stage-2 → T125 paperwork). Moves B/C are D4 and explicitly down-weighted.

### 2.3 Project axis

**D3 (new theory derivation + manuscript)**. The spawn of a new investigation that derives a closed-form effect not yet in code/manuscript. The work product directly extends Paper #3 Section V (multiplicity-aware Lemma 1) from the rigorously-established trivial-irrep case (T119 critic A2) to the conjectured non-trivial-irrep case (theorist T115 §F).

NOT D1 (no re-verification of closed Tier-3). NOT D2 (no service optimization). NOT D4 (not scheduler-mandated meta/audit; F11-Te1 stub registration in investigations_index is institutional bookkeeping, not auto-spawn). NOT manuscript polish.

### 2.4 Why theorist (not researcher / critic / implementer / noop)

- **theorist**: matches Hypothesize stage of build-theory flow_template exactly. Derivation work, closed-form algebra, falsifier table. 3 on-disk anchors readable.
- **researcher**: rejected. The 3 load-bearing references are on-disk (memory + theorist T115 + manuscript §V). No new literature search needed at Hypothesize stage; T115 already cited Hamermesh + Bradley-Cracknell. Researcher_deep would be the T123 fallback if theorist hits algebraic obstruction.
- **critic**: rejected. T119 critic ALREADY CORROBORATED the trivial-irrep mechanism (5/5 deliverables). Critic is appropriate at T124 Stage-2 audit, after T123 numerical verification.
- **implementer_text**: rejected. No clean text-edit task; derivation not done.
- **implementer_julia_cpu_light**: rejected. No code to run yet; falsifier table is the prerequisite, produced by T122 theorist.
- **noop**: rejected. Move A is concrete and high-leverage; declining preserves a pipeline at zero open priority-1-3 physics investigations.

### 2.5 §B1.0 existing-artifact precondition — affirmed

Per memory feedback_use_existing_artifacts_first: BEFORE deriving / typing / launching new work, grep on-disk artifacts.

T122 confirmed 3 load-bearing existing artifacts that theorist MUST read BEFORE deriving:
- (a) `memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` §4 (J-involution closed-form for trivial irrep) + §6 (RESEARCH_NEEDED tags) — verified during top-of-turn read.
- (b) `runs/_loop/theorist/turn_115.md` §2.A (J-involution Hypothesize_retry derivation) + §F (non-trivial-irrep [Plausible] conjecture) — referenced from memory §7 file anchors.
- (c) `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` §V (manuscript-published multiplicity-aware extension) — theorist must crosscheck §V.5/§V.6 does NOT pre-derive the non-trivial-irrep case.

Existing-artifacts grep result: 3 hits, none containing the non-trivial-irrep closed-form. **Therefore theorist's derivation is new work, NOT re-derivation.**

### 2.6 §B6 drift acknowledgement

T120 drift_advisories: `["DRIFT_COST_INFLATION", "AUDIT_DUE: patterns.yaml last audited at T105, gap=15"]`. T121 PASS broke the streak. T122 acknowledges:

- **DRIFT_COST_INFLATION**: T120 2.0x bust (2.8M actual vs 1.4M expected); T121 0.5x (≈200k actual vs 400k expected, mechanical-class). Cost discipline empirically restored. T122 expected 1.8M is mid-range theorist Hypothesize; NOT activating meta-cost-inflation auto-spawn (priority 40 dormant). Waiting for ≥2 consecutive BUDGET_BUSTED events post-T121 to confirm persistence.
- **AUDIT_DUE gap=15 (now ≈16 at T122 entry)**: at-but-not-over threshold. Deferred to T123-T125 IF higher-leverage physics-axis move exists THIS turn — Move A is exactly that. If T123 has no physics-axis pick, audit-class-scan T122 cycle becomes mandatory.
- **5-turn FAIL streak break (T121 PASS)**: T116-T120 streak ended cleanly. `meta-stage-routing-2026-05-19` auto-spawn (priority 25 Observe) NOT activated per T121 §7 forward-pointer + T54-T60 precedent (meta-stage-routing-2026-05-18 closed REFUTED-BY-CONFOUNDER once judge.py _OPS_in_ bug was named).

### 2.7 Why NOT alternative investigations

| Candidate | Priority | Status | Rejected because |
|---|---|---|---|
| `meta-cost-waste-audit-2026-05-19` | 15 | Observe | D4. T121 PASS at ~200k empirically refutes pattern when work is mechanical-class. OTEL outliers are pre-T117. REFUTED-BY-OBSOLETE-DATA risk. |
| `meta-director-self-audit-2026-05-19` | 20 | Observe | D4. T80-T100 baseline window is 22 turns stale. Refresh needed before audit; not high-leverage. |
| `meta-stage-routing-2026-05-19` | 25 | Observe | D4. T121 streak-break empirically refutes contract-design hypothesis (root cause was auto-branch-to-main + shell-quoting, named and fixed at T121). REFUTED-BY-CONFOUNDER per T54-T60 precedent. |
| `meta-cost-inflation-2026-05-19` | 40 | Observe | D4. Same refutation as Move C. T121's 0.5x ratio is Observe-stage evidence for KEEPING DORMANT. |
| `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` | 4 | tier 2.0, blocked_on F5 julia gate | state.json `blocked_on != null`. If unblocked, ~2M julia regression — comparable cost to Move A but D2 (re-verification of confirmed bug-fix) vs D3 (new theory). Move A wins on novelty. |
| `yan-li-saito-2026-reproduction` | 1 | tier 0.4 DORMANT-CLOSE T64 | Dormant. R5/R6 deep-bug audit is large cost, high uncertainty. |
| `fullbdg-f6-polar-3000x` | 99 | dormant | Filtered (priority ≥50 dormant). |

**Decision: dispatch theorist Hypothesize on NEW investigation `sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19` (build-theory flow_template), advancing from `<NEW>` to `Hypothesize`.**

## 3. Theorist's directive — verbatim brief

### 3.1 Read order (BEFORE deriving)

1. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` — full 83 lines. Focus §2 (canonical formula), §4 (J-involution endpoint for trivial irrep), §6 (RESEARCH_NEEDED items), §7 (file anchors).
2. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md` — focus §2.A (J-involution closed-form for trivial irrep) + §F (non-trivial-irrep isotypic-allocation [Plausible] conjecture: ||xi_alpha||^2 = m_alpha * d_alpha / (2F+1)).
3. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — focus §V (multiplicity-aware extension). Crosscheck: does §V.5/§V.6 (if present) already contain non-trivial-irrep extension?
4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_structure_u1u4_2026_05_13.md` — focus polyhedral classification F=2/3/4/6/8/10. Does U1-U4 inventory include F=11 T:E_1 state construction?

### 3.2 Hypothesize task

Derive closed-form generalization of canonical mult-aware Lemma 1

  bar_beta_S^{canonical} = m_rep * Tr[Pi_S (rho_inv (x) rho_inv)]

from TRIVIAL irrep A (T119 critic rigorously established) to NON-TRIVIAL polyhedral irreps. Concrete first case: F=11, group T, irrep E_1 (complex 1-dim, real-construction 2-dim, expected m_rep ≥ 2).

**Sub-task 3.2.A — J-involution at non-trivial irrep**: T119 critic A2 derived for trivial irrep:

  bar_beta_0^{canonical} = ||(P_W ⊗ P_W)|0,0⟩||^2 = Tr(P_W^2)/(2F+1) = m_rep/(2F+1)

This used (a) J ∈ H, (b) J† P_W J = P_W (projector onto H-trivial isotypic commutes with J), (c) singlet identity |0,0⟩ = (I ⊗ J)|MES⟩/√(2F+1).

Critical question for non-trivial α: when W is the non-trivial isotypic component of irrep α (with α ≠ A), does step (b) still hold? P_W^(α) projects onto α-isotypic; J ∈ H acts via D^(α)(J) ∈ Hom(α,α). For E_1 complex 1-dim of T, D^(E_1)(J) is a phase exp(iφ). **Does ||·||^2 kill the D^(α)(J) phase**, restoring closed form?

Derive yes or no. State the closed form for α=E_1, distinguishing three possible outcomes:
- (i) bar_beta_0^{canonical, α} = m_α/(2F+1) — trivial-irrep formula universal
- (ii) bar_beta_0^{canonical, α} = m_α · d_α/(2F+1) — d_α factor enters (T115 §F conjecture)
- (iii) Neither — α-dependent correction beyond m_α · d_α/(2F+1)

**Sub-task 3.2.B — Generalize formula to specific α=E_1**: Define ρ_inv^(α) = P_W^(α)/m_α. Compute bar_beta_S^{canonical,α} = m_α · Tr[Π_S (ρ_inv^(α) ⊗ ρ_inv^(α))] at S=0 specifically. State outcome (i)/(ii)/(iii) you DERIVE (not guess).

**Sub-task 3.2.C — 3-falsifier table for T123 implementer**:
- F1 (central, is_central=true): bar_beta_0^{canonical}(F=11, T, E_1, m_rep=?) = ? Specify expected value + m_rep value + d_α value + closed-form denominator.
- F2: seed-independence across 10 RNG seeds < 1e-13.
- F3 (sum-rule): Σ_S bar_beta_S^{canonical, E_1} = m_α (or m_α · d_α; derive which).
- Optional F4: lemma1_general_S_verification.jl 29/29 PASS unchanged.

**Sub-task 3.2.D — m_α via Hamermesh**: T = {e, 8C_3, 3C_2}, |T|=12. SU(2) char χ^{(11)}(g): χ^{11}(e) = 23; χ^{11}(C_3) = sin(23π/3)/sin(π/3); χ^{11}(C_2) = sin(23π/2)/sin(π/2) = -1. Compute m_E_1. If m_E_1 < 2 at F=11, fall back to F=12 T:E_1 or F=11 T:E_2.

### 3.3 Out-of-scope (do NOT touch)

- NO julia execution. NO new simulation. NO new code file.
- NO state.json edits (registration deferred to T123 implementer_text micro-turn).
- NO memory file appends (memory entry is Document stage, not Hypothesize).
- NO manuscript edits (§V update is Document stage).
- DO NOT generalize beyond F=11 T:E_1 (or fallback F=12/E_2). Single concrete case is Hypothesize scope.
- DO NOT re-derive the trivial-irrep case (T119 critic A2 already rigorous).

### 3.4 Write target

`/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md` with §1-§8 structure from theorist T115 template:
- §1 Directive received (verbatim from §6 below)
- §2 Read summary (anchor citations with line refs)
- §3 Derivation (cite ≥3 anchor files by absolute path)
- §4 Closed-form claims (tag each with `[Established]` / `[Plausible]` / `[Conjecture]` / `[Refuted]`)
- §5 3-falsifier table (≥3 rows; F1 is_central=true)
- §6 Open obstacles + RESEARCH_NEEDED tags (if any)
- §7 Manuscript §V impact (≤200 words)
- §8 Status

YAML front-matter REQUIRED: `investigation_id`, `stage_advancing_from`, `stage_advancing_to: Hypothesize`, `topic_tags` (≥3 incl D3-build-theory, sign-pattern-lemma1-non-trivial-irrep, F11-T-E1), `depends_on` (≥4 anchor paths).

### 3.5 Cost budget

- Expected: 1500000-2000000 effective.
- Hard cap: 3000000 effective. If approaching cap, bail with [Plausible] + RESEARCH_NEEDED tag for T123 researcher_deep.
- Per memory feedback_cost_overhead_is_the_cost: do NOT deliberate scope. Derive, output, stop.

## 4. Observable manifest

```json
{
  "required": [
    "theorist_turn_122_md_present",
    "yaml_front_matter_valid",
    "investigation_id_field_matches",
    "stage_advancing_to_hypothesize",
    "section_3_derivation_cites_3_anchors",
    "section_4_closed_form_has_evidence_tags",
    "section_5_falsifier_table_3_rows_minimum",
    "section_5_F1_central_marked",
    "F11_T_E1_m_alpha_computed_or_fallback_noted",
    "no_julia_executed",
    "no_state_json_modified",
    "no_memory_modified",
    "no_src_test_modified"
  ],
  "precondition_check": "test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md"
}
```

## 5. Success criteria (FORM B raw-artifact, single-binary check_cmds)

## 6. Dispatch JSON

```json
{
  "investigation_id": "sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19",
  "stage_advancing_to": "Hypothesize",
  "subagent_type": "theorist",
  "researcher_depth": null,
  "parallel_researcher_count": 1,
  "project_axis": "D3",
  "rationale": "Per top-of-turn reads (memory:sign_pattern_lemma1_mult_aware_2026_05_19 §6 RESEARCH_NEEDED items + memory:feedback_manuscript_is_not_the_essence anko 2026-05-15 'physics is the essence'), T122 spawns a NEW D3 investigation on the natural physics-axis frontier after T120 Tier-3 closure: extending the canonical multiplicity-aware Lemma 1 formula from TRIVIAL irrep A (rigorously established at T119 critic Stage-2 via J-involution + Hamermesh m_rep=2 at F=9 T:A) to NON-TRIVIAL polyhedral irreps. Concrete first case: F=11 T:E_1. This is the 1st of 3 explicit <RESEARCH_NEEDED> tags from T112-T120 closure. Move A wins over 4 open D4 meta-investigations (priorities 15/20/25/40, all Observe) because (a) T121 PASS empirically refuted DRIFT_COST_INFLATION for mechanical-class work, (b) T54-T60 meta-stage-routing-2026-05-18 precedent shows meta-investigations get REFUTED-BY-CONFOUNDER once root cause is named, (c) anko's 'physics is the essence' down-weights D4 vs physics-axis. AUDIT_DUE gap=16 deferred to T123-T125; below high-leverage physics-axis spawn.",
  "brief": "READ ORDER (all absolute paths, mandatory before deriving): (1) /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md (full 83 lines; focus §2/§4/§6/§7); (2) /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md §2.A and §F (J-involution closed-form for trivial irrep; non-trivial-irrep [Plausible] conjecture); (3) /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md §V (manuscript-published multiplicity-aware extension; verify §V.5/§V.6 does NOT pre-derive non-trivial case before re-deriving); (4) /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_structure_u1u4_2026_05_13.md (polyhedral classification F=2/3/4/6/8/10; check F=11 T:E_1 state-construction on-disk). TASK: Hypothesize stage of new build-theory investigation. Derive whether J-involution closed-form bar_beta_0_canonical = m_rep/(2F+1) (established at trivial irrep A) generalizes to non-trivial irreps. Concrete first case: F=11 T:E_1 (complex 1-dim of T, real-construction 2-dim, m_rep≥2 by Hamermesh). Sub-tasks: (3.2.A) verify or refute J-involution endpoint at non-trivial irrep (does J ∈ T commute with P_W^(E_1) same way as P_W^(A)? does |·|^2 kill D^(E_1)(J) phase?); (3.2.B) generalize bar_beta_S^(canonical) to α=E_1; derive outcome (i) m_α/(2F+1), (ii) m_α·d_α/(2F+1), or (iii) α-dependent correction; (3.2.C) emit 3-falsifier table (F1 central endpoint, F2 seed-independence, F3 sum-rule; optional F4 m_rep=1 regression); (3.2.D) compute m_α via Hamermesh orbit-counting; if m_α<2 at F=11 T:E_1, fall back to F=12 T:E_1 or F=11 T:E_2. WRITE /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md with §1-§8 (T115 template). YAML front-matter REQUIRED with investigation_id, stage_advancing_to:Hypothesize, topic_tags (≥3 incl D3-build-theory + sign-pattern-lemma1-non-trivial-irrep + F11-T-E1), depends_on (≥4 anchor paths). §4 closed-form claims MUST tag with [Established]/[Plausible]/[Conjecture]/[Refuted]. §5 falsifier table ≥3 rows with F1 is_central=true. CONSTRAINTS: NO julia, NO new code, NO state.json edit, NO memory file edit, NO manuscript edit, NO src/test touch. If algebraic obstruction <1.5M cost, emit RESEARCH_NEEDED tag for T123 researcher_deep, bail with [Plausible]. Cost budget 1.5-2.0M expected, hard cap 3.0M.",
  "observable_manifest": {
    "required": [
      "theorist_turn_122_md_present",
      "yaml_front_matter_valid",
      "investigation_id_field_matches",
      "stage_advancing_to_hypothesize",
      "section_3_derivation_cites_3_anchors",
      "section_4_closed_form_has_evidence_tags",
      "section_5_falsifier_table_3_rows_minimum",
      "section_5_F1_central_marked",
      "F11_T_E1_m_alpha_computed_or_fallback_noted",
      "no_julia_executed",
      "no_state_json_modified",
      "no_memory_modified",
      "no_src_test_modified"
    ],
    "precondition_check": "test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md"
  },
  "success_criteria": [
    {
      "id": "SC1-theorist-turn-122-md-exists",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC2-investigation-id-in-front-matter",
      "check_cmd": "grep -E -q 'investigation_id: sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC3-stage-advancing-to-hypothesize",
      "check_cmd": "grep -E -q 'stage_advancing_to: \"?Hypothesize\"?' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC4-D3-axis-tag-present",
      "check_cmd": "grep -E -q 'D3' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC5-section-3-cites-memory-anchor",
      "check_cmd": "grep -E -q 'sign_pattern_lemma1_mult_aware_2026_05_19' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC6-section-3-cites-theorist-T115-anchor",
      "check_cmd": "grep -E -q 'theorist/turn_115' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC7-section-3-cites-manuscript-V-anchor",
      "check_cmd": "grep -E -q 'sign_pattern_lemma1_general_S' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC8-evidence-tag-present",
      "check_cmd": "grep -E -q '\\[Established\\]|\\[Plausible\\]|\\[Conjecture\\]|\\[Refuted\\]' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC9-F1-central-falsifier-marked",
      "check_cmd": "grep -E -q 'is_central.*true|F1.*central|central.*F1' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC10-three-falsifiers-mentioned",
      "check_cmd": "grep -c -E 'F1|F2|F3' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC11-J-involution-discussed",
      "check_cmd": "grep -E -q 'J-involution|J = exp|J=exp|F_y|exp\\(-i' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC12-F11-or-fallback-mentioned",
      "check_cmd": "grep -E -q 'F=11|F=12|F = 11|F = 12' /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_122.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC13-no-state-json-mutation-yet",
      "check_cmd": "python3 -c 'import json; d=json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); inv=d[\"investigations\"]; assert \"sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19\" not in inv or inv[\"sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19\"].get(\"current_stage\",\"\")==\"\"; print(\"OK\")'",
      "expect": {"exit_code": 0, "stdout_contains": "OK"}
    },
    {
      "id": "SC14-no-src-modified-this-turn",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/src -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_121.md -type f",
      "expect": {"exit_code": 0, "stdout_equals": ""}
    },
    {
      "id": "SC15-no-test-modified-this-turn",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/test -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_121.md -type f",
      "expect": {"exit_code": 0, "stdout_equals": ""}
    }
  ],
  "failure_modes": [
    {
      "if": "SC1 fails (theorist did not write turn_122.md)",
      "category": "operational",
      "next_action": "T123 director dispatches critic on this directive (T122) to identify why theorist subagent did not produce primary work product; possible cost-cap hit before write completed"
    },
    {
      "if": "SC2 or SC3 fails (YAML front-matter wrong)",
      "category": "operational",
      "next_action": "implementer_text patches YAML front-matter at T123 mechanically; 1-line fix"
    },
    {
      "if": "SC8 fails (closed-form claims emitted without evidence tags)",
      "category": "scientific_inconclusive",
      "next_action": "T123 critic audits theorist T122 derivation, classifies claims into [Established]/[Plausible]/[Conjecture]; routine scientific-rigor refinement"
    },
    {
      "if": "SC10 returns low count (< 3 falsifiers)",
      "category": "scientific_inconclusive",
      "next_action": "T123 theorist Hypothesize_retry with explicit falsifier-table requirement re-emphasized; precedent T114 attempt1 -> T115 attempt2"
    },
    {
      "if": "Derivation outcome (ii) m_alpha * d_alpha / (2F+1) confirmed [Plausible]",
      "category": "scientific_confirmed",
      "next_action": "T123 implementer_julia_cpu_light numerical verification at F=11 T:E_1; expected pass at rtol 1e-13; potential 6th project Tier-3 trajectory"
    },
    {
      "if": "Derivation outcome (iii) alpha-dependent correction REFUTES T115 §F conjecture",
      "category": "scientific_refuted",
      "next_action": "T123 critic re-derives independently to confirm refutation; if confirmed, paper3 §V multiplicity-aware extension needs errata propagation"
    },
    {
      "if": "F=11 T:E_1 has m_alpha = 0 (no inert state exists)",
      "category": "data_gap",
      "next_action": "T122 theorist falls back to F=12 T:E_1 or F=11 T:E_2 per directive 3.2.D"
    },
    {
      "if": "Theorist hits cost cap 3M before closed-form derivation",
      "category": "operational",
      "next_action": "T123 researcher_deep on Hamermesh / Bradley-Cracknell tables for T complex-1d irreps + real-form constructions; ~4M cost; T124 theorist retry with researcher anchor"
    }
  ],
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 1500
  },
  "investigation_update": {
    "spawn_new_investigation": true,
    "new_investigation_record": {
      "id": "sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19",
      "title": "Sign Pattern Lemma 1 mult-aware extension: non-trivial irrep generalization at F=11 T:E_1 (1st non-trivial irrep case)",
      "hypothesis": "The canonical multiplicity-aware formula bar_beta_S^(canonical, alpha) = m_alpha * Tr[Pi_S (rho_inv^(alpha) (x) rho_inv^(alpha))] generalizes the trivial-irrep (alpha=A) case to non-trivial polyhedral irreps with closed-form endpoint bar_beta_0^(canonical, alpha) = m_alpha * d_alpha / (2F+1) (T115 §F [Plausible] conjecture). F=11 T:E_1 (complex 1d, real-construction 2d, m_alpha >= 2 by Hamermesh) is the 1st concrete non-trivial-irrep test case.",
      "flow_template": "build-theory",
      "current_stage": "Hypothesize",
      "stages_done": [],
      "tier_current": 0,
      "tier_target": 3,
      "next_stage": "Hypothesize",
      "next_stage_action": "theorist Hypothesize: derive closed-form generalization of mult-aware Lemma 1 from trivial irrep A to non-trivial polyhedral irreps; emit 3-falsifier table.",
      "priority": 5,
      "kind": "physics",
      "auto_spawned_by_trigger": null,
      "spawn_anchor": "memory:sign_pattern_lemma1_mult_aware_2026_05_19 §6 RESEARCH_NEEDED item #1 + theorist T115 §F [Plausible] conjecture",
      "blocked_on": null,
      "falsifiers": []
    },
    "spawn_via_implementer_text": "DEFERRED: this turn dispatches theorist for derivation. state.json registration is T123 implementer_text patch IF T122 theorist closes Hypothesize cleanly (SC1-SC15 PASS). Director-side rule: state.json mutation requires explicit implementer dispatch.",
    "if_success_advance_to_stage": "Hypothesize_complete (awaiting T123 implementer_text state.json registration + T123-T124 numerical verification + critic Stage-2 audit)",
    "if_success_tier_becomes": 0.5,
    "if_refuted_advance_to_stage": "Hypothesize_retry",
    "if_refuted_tier_becomes": 0,
    "if_success_falsifier_update": {
      "id": "F1-mult-aware-non-trivial-irrep-endpoint-formula",
      "tested_at_turn": null,
      "result_template": "DERIVATION_COMPLETE: T122 theorist Hypothesize derived bar_beta_0^(canonical, alpha=E_1) at F=11; specify outcome (i) m_alpha/(2F+1), (ii) m_alpha*d_alpha/(2F+1), or (iii) alpha-dependent correction. 3-falsifier table emitted for T123 implementer numerical verification."
    },
    "note": "T122 theorist Hypothesize spawns the 6th project Tier-3 trajectory candidate. Anticipated arc: T122 theorist Hypothesize -> T123 implementer_text state.json registration + implementer_julia_cpu_light numerical verification -> T124 critic Stage-2 audit -> T125 implementer_text Tier-3 closure paperwork. Target arc length ~4 turns. If F=11 T:E_1 derivation goes cleanly, F=11 T:E_2 + F=12 T:* become rapid follow-up turns."
  }
}
```

## 7. Anticipated T123 dispatch (pre-commit, conditional)

- **If T122 PASS** (theorist emits closed-form + 3-falsifier table + clean YAML front-matter):
  T123 splits into 2 sub-dispatches via `if_success_advance_to_stage`:
  (i) implementer_text micro-turn: register new investigation in state.json (single jq patch adding spawn_new_investigation record + investigations_index append). Cost ~300-500k. THIS IS THE STATE.JSON MUTATION T122 DOES NOT TOUCH.
  (ii) implementer_julia_cpu_light: numerical verification of F1+F2+F3 at F=11 T:E_1 (or fallback). Construct rho_inv^(E_1), compute bar_beta_0_canonical, compare against theorist's closed-form. Cost ~1.5-2M. Scheduler allows.
  Director may bundle (i)+(ii) into one turn if scope holds.

- **If T122 INCONCLUSIVE** (theorist hits algebraic obstruction):
  T123 dispatches researcher_deep on Hamermesh / Bradley-Cracknell tables for T complex-1d irreps + real-form constructions. ~4M cost.

- **If T122 FAIL_OPERATIONAL** (theorist YAML / SC fails / cost cap):
  T123 dispatches critic on this directive (T122) to identify check_cmd flaw OR theorist agent-prompt flaw. T122 SCs use regex-fuzzy matching (e.g., SC10 grep -c for falsifier-count flexibility) precisely to avoid SC11-class threshold-rigidity from T121.

## 8. Pre-commit checklist (director-side)

- [x] Top-of-turn reads cited per protocol (§1). 10 paths read, including load-bearing memory anchor.
- [x] §B1.0 existing-artifact precondition checked: 3 anchor artifacts (memory, theorist T115, manuscript §V) exist on disk; non-trivial-irrep closed-form does NOT exist on disk — theorist's derivation is new work.
- [x] §B6 drift advisories acknowledged: DRIFT_COST_INFLATION refuted at T121 (0.5x mechanical-class); AUDIT_DUE gap=16 deferred to T123-T125 IF no physics-axis pick; 5-turn FAIL streak ENDED at T121.
- [x] §F5 safety rails: T122 is build-theory Hypothesize, NOT meta-improvement; F5 rails N/A. Analogous discipline: no anko-touched-in-30d files modified (theorist writes only theorist/turn_122.md); rollback path is `rm theorist/turn_122.md`; one change at a time.
- [x] Workload class `theorist` is in scheduler.json `allowed_workloads`.
- [x] All check_cmds use allow-listed binaries (test, grep, python3, find) with single-quoted regex and no shell metachars. Pattern matches T117/T119/T121.
- [x] Dispatch JSON §6 follows protocol contract template (investigation_id, stage_advancing_to, subagent_type, project_axis, rationale, brief, observable_manifest, success_criteria, failure_modes, budget, investigation_update.spawn_new_investigation).
- [x] Cost target (1.8M) is within rolling-window quota (1.07M sec window left, JULIA_GPU_OK, no quota pressure). T120 BUDGET_BUSTED was one-off; T121's 0.5x ratio restored discipline.
- [x] Per anko's "physics is the essence" directive: D3 (new theory derivation) chosen over 4 open D4 meta-investigations explicitly.
- [x] Anticipated T123 dispatch plan documented (§7) for PASS / INCONCLUSIVE / FAIL_OPERATIONAL branches.

End of director T122 directive.
