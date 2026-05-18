---
turn: 107
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: "Update (re-opened at T_seed-2026-05-19 per seed.md; F1 central falsifier never tested against the K3_long artifact)"
stage_advancing_to: Update
topic_tags: [edh-eu151-matsui-science-2026, artifact-first-path, K3_long-audit, central-falsifier-F1, subagent-rotation, D1-axis]
paper_section: null
depends_on:
  - 106
  - 105
  - 104
  - 103
  - 86
  - 84
  - 83
  - 82
  - "runs/_loop/seed.md"
  - "runs/_loop/director/turn_106.md"
  - "runs/_loop/sim/turn_106.md"
  - "runs/_loop/judge/turn_106.json"
  - "runs/_loop/state.json"
  - "runs/_loop/_local/scheduler_107.json"
  - "runs/eu151_edh_K3_long/trajectory.csv"
  - "runs/eu151_edh_K3_long/trajectory.png"
  - "runs/eu151_edh_K3_long/config.yaml"
  - "runs/eu151_edh_K3_long/_live_status.json"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:edh_matsui_baseline_2026_05_18"
  - "memory:feedback_manuscript_is_not_the_essence"
produces: >
  T107 critic dispatch for the §B-Decision-Table "Artifact-first path" against
  edh-eu151-vortex-vs-matsui-science-2026. Independent audit of the
  May-13 runs/eu151_edh_K3_long/ artifact (32^3, K3 + gamma_dr + noise
  seed, 100k steps reaching t = 9.98 dimless = 14.5 ms, 14.5 MB CSV + PNG
  + result.jld2 all on disk) against Matsui et al. Science 391, 384-388
  (2026) [DOI:10.1126/science.adx2872]. Critic emits CORROBORATE /
  INCONCLUSIVE / REFUTED verdict on the central falsifier F1
  (ring-appears-correct-timescale). Tier promotion to 3.0 is gated on
  FORM-B raw-CSV check_cmd (judge.py §F8 Tier-3 promotion gate). NO new
  simulation per anko's "existing-artifacts-first" rule (seed.md +
  memory feedback_use_existing_artifacts_first). NO julia execution by
  the critic (Read-only role).
---

# Turn 107 — Director Report

## 1. Investigation state snapshot

- **Active investigation (PIVOT from prior T103-T106 audit cycle)**: `edh-eu151-vortex-vs-matsui-science-2026` (priority 0, flow_template `verify-claim`, kind `physics`, tier_target 3). State.json (lines 3178-3262) shows `current_stage: "Update (re-opened 2026-05-18; T76-T86 closure was tier-inflation on F3 alone; F1 ring formation NOT actually reproduced. Existing runs/eu151_edh_K3_long/trajectory.png (May 13, 14.5 ms, clean cascade, K3+gamma_dr+noise seed) likely already shows EdH cascade — needs independent critic audit per §B1.0)"`, `tier_current: 2.5`, `tier_target: 3`, `next_stage: "closed"`, `next_stage_action: "Per seed.md 2026-05-19 highest-priority section + director §B1.0: dispatch critic in independent-audit mode against runs/eu151_edh_K3_long/trajectory.png + trajectory.csv (the May 13 success; 14.5 ms, K3 + gamma_dr + noise seed, clean cascade). Crosswalk against Matsui Science 391 384-388 (2026). NO new EdH simulation. PASS → tier 3.0 with audit as load-bearing evidence."`. The pre-routing matches seed.md verbatim.

- **Closed investigation just exited**: `audit-class-scan-2026-05-19-T103` PASSED 43/43 contract criteria at T106 (judge/turn_106.json `status: PASS`, all `criteria_results.passed: true`, `triggered_failure_modes: []`), `tier_current 1.5 → 2.0`, `current_stage: closed`, `closing_note` registered, `stages_done` includes `Document`. The 4-cycle audit-class-scan arc (T103 researcher → T104 critic L3 audit → T105 implementer mechanical → T106 implementer Document) is terminally closed. Memory `audit_class_scan_t103_cycle_2026_05_19.md` written.

- **Stage transition**: `verify-claim` flow_template; T107 advances to **Update** (re-opened branch). Per §B-Flow-Template-Table: `Update = critic (mandatory independent context)`. T107 dispatches **critic** to perform an independent audit of the on-disk K3_long artifact against Matsui Science 2026. Success at FORM-B central-falsifier check unlocks Tier 3.0 closure at T108+ Document.

- **Falsifier this turn evaluated**: `F1-ring-appears-correct-timescale` (`is_central: true`, `tested_at_turn: null`, `result: null`). This is the load-bearing central falsifier. The T76-T86 "Tier-3 closure" was on F3 (energy convention) alone — seed.md correctly flags that as tier-inflation. F1 has never been tested against the K3_long artifact, only against the regressed `matsui_edh_baseline_9ca97308` config (no K3, no gamma_dr, no noise seed) which predictably produced NOT_APPLICABLE_NO_RING at T82-T84.

- **Other in-flight investigations** (state.json scan; unchanged since T106):
  - **6 Tier-3 closures**: barnett T29, klaus-bch T59, edh-matsui T86 (on F3 only — being re-audited), sign-pattern-lemma1 T94, tdhfb-phase2 T102, plus yan-li-saito-2026-reproduction (REFUTED-CLEAN at T65 tier 0.4).
  - **Tier-2 closures**: bug-4-itp-ddi-half-rate-revalidation T97, judge-in-operator-bug T54, audit-due-heuristic-bug T68, meta-internal-b-unification T54, plus 4 audit-class-scan cycles T54 / T63 / T89 / T106.
  - **Auto-spawned metas in Observe (queued)**: meta-cost-waste-audit-2026-05-18 (priority 15), meta-director-self-audit-2026-05-19 (priority 20), meta-cost-inflation-2026-05-19 (priority 40), meta-critic-placement-2026-05-17 (priority 50).
  - **Deferred**: tier3-verification-pipeline-survey (Document closed at T90), fullbdg-f6-polar-3000x (dormant, anko-contained).

- **Scheduler** (`runs/_loop/_local/scheduler_107.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, `allowed_workloads` includes `critic`. Window ends 2026-05-31T23:59 JST with **1,113,193 sec (~18,553 min) remaining**. Probe: VRAM 12,835 MB free, RAM 25.02 GB avail, GPU util 1%, foreign_julia 0. `critic` is Read-only — trivial fit, no julia, no GPU.

- **Last judge verdict (T106)**: PASS (43/43 success criteria, 0 issues, 0 triggered_failure_modes). investigation_update.post_close_pivot_options enumerated 4 candidates, the highest-leverage of which is NOT in that list — the seed.md edh re-open supersedes all enumerated post-close options. Per precedence rule (seed > scheduler > prompt > worked example), seed.md wins.

- **Drift signals (most recent, T104 footer — T105/T106 drift not yet recorded in state.history; T107 will reflect the pivot)**: at T106 close:
  - `topic_repetition: ~0.5` (audit-class-scan spanned T103-T106 = 4 consecutive turns; T107 pivots to a different topic → topic_repetition drops sharply next turn).
  - `subagent_repetition: ~0.5` (implementer_text 4 of last 6 turns; T107 critic dispatch breaks the streak per "no more than 2 same-subagent in a row" rule in seed.md stop-conditions; also satisfies T106 §5 anticipated rotation pressure).
  - `manuscript_delta_zero: 1.0` (advisory only per `feedback_manuscript_is_not_the_essence` — T107 critic dispatch is D1 verification depth, not manuscript work; advisory is correct by design).
  - `code_delta_zero: 1.0` (critic Read-only; no src/ touched — correct by design for an audit turn).
  - `verdict_drift: 0` (T103-T106 all PASS or RESEARCHER_ONLY → CRITIC_PASS → PASS → PASS; clean recovery).
  - `cost_inflation: ~0.85` at T104; T105/T106 within bound; T107 critic expected ~1.5-2.0M (mirror T58 / T101 / T93 critic ~1.5-2.2M).
  - `AUDIT_DUE`: cleared since T105 audit_history row turn:105; gap=2 at T107; stays cleared until ~T113-T115 next cycle.
  - `novel_claim_zero`: T107 will produce CORROBORATE / INCONCLUSIVE / REFUTED verdict + new errata if any (novel-claim non-zero anticipated).

- **Why this is the right move (not continuing audit-class-scan, not picking a different post-close pivot, not noop)**:
  - **seed.md explicit "Highest priority NOW (2026-05-19)" section MANDATES this**. Verbatim: "Investigation `edh-eu151-vortex-vs-matsui-science-2026` is re-opened (was wrongly closed at T76-T86 on F3 alone; F1 ring formation was NOT reproduced). **Director MUST pick this as next active investigation.**" Per precedence (seed > scheduler > prompt > worked-example), seed.md wins. The audit-class-scan cycle is closed at T106 — the seed.md route is now actionable.
  - **The "Artifact-first path" in director.md §B-Decision-Table applies cleanly**: (a) `runs/eu151_edh_K3_long/` exists with non-trivial outputs (trajectory.png + result.jld2 + trajectory.csv + config.yaml + _live_status.json all confirmed on disk this turn via Glob); (b) `tier_current = 2.5 < 3`; (c) last verdict was `TIER_3_TERMINAL_CLOSURE` (NOT `INCONCLUSIVE`) — but seed.md explicitly inverts that, declaring the T86 closure to be tier-inflation on F3 alone. The re-open is anko-routed, not loop-routed; the rule's intent (avoid re-litigating closed-correctly verdicts) is honored by seed.md's explicit override. Per the table, `subagent_type = critic`; `stage_advancing_to = Update` (verify-claim's audit/review stage). Brief: audit existing artifact + crosswalk against published reference. No new simulation.
  - **Central falsifier F1 has `is_central: true` and `tested_at_turn: null`** — Tier-3 promotion gate (§F8 / judge.py auto-clamping) REQUIRES a central falsifier with CORROBORATE / CONFIRMED result via FORM-B check_cmd. T107 is the structural unblock.
  - **K3_long artifact is the canonical anko-verified setup**: per `memory/feedback_use_existing_artifacts_first.md` — "runs/eu151_edh_K3_long/trajectory.png (May 13, 14.5 ms dynamics, clean cascade m=+F → m=+5/+4/+3, K3 + gamma_dr + noise seed, all 13 components populated)". The K3 routing was fixed on 2026-05-13 (commit 6bfe9d9; per `gotcha_K3_routing_pre_2026_05_13.md`), making this the first proper post-fix run. The T76-T86 arc used a regressed `matsui_edh_baseline_9ca97308` config that omitted K3 + gamma_dr + noise seed — Eu collapses <1 ms without K3; symmetric initial sticks forever in m=+F.
  - **Subagent rotation pressure addressed**: T103 researcher → T104 critic → T105 implementer → T106 implementer (4 implementer_text in last 6 turns per T106 §5 drift advisory). T107 critic dispatch breaks the streak. Also satisfies the seed.md stop-condition "no more than 2 same-subagent in a row" (implementer was about to violate this; critic resets).
  - **NOT continuing audit-class-scan**: that cycle is terminally closed at T106 (current_stage="closed", tier 2, stages_done includes Document). Re-opening would be state-corruption.
  - **NOT advancing tier3-verification-pipeline-survey Document closure**: it was already closed at T90 (state.json line 3149 `current_stage: closed`, `last_turn: 90`); the T106 §5 "post_close_pivot_options" list mentioned this stale item from a prior reading. Not actionable.
  - **NOT advancing meta investigations**: per §B2 meta-investigations are interleaved, not parallel-mandatory; the seed.md re-open is a physics priority (D1 axis) that supersedes meta queue. Meta investigations also live behind F5 safety rails which require an Arbiter-style adversarial-audit step before any director.md patch — F5 is not the cheapest move this turn.
  - **NOT spawning a drift_signals.py idempotency fix-bug**: T104 critic + T105 director + T106 director all deferred this routing. T107 is the highest-leverage physics move; that fix-bug remains a candidate for T108+.
  - **NOT noop**: physics axis D1 has a clear unblock (central falsifier F1 untested against K3_long; tier 2.5 → 3.0 promotion gate is one critic audit away). Noop is justified only when no julia-safe / artifact-safe move has leverage; the artifact-audit move is purpose-built for this turn.
  - **NOT running a new simulation**: per seed.md "**no new EdH simulation this round. The accumulated runs ARE the data.**" Per `memory/feedback_use_existing_artifacts_first.md` — the existing artifact IS the primary evidence; independent critic audit advances tier.

- **Cost frame**: T58 (analogous critic audit for klaus-bch-leak Tier-3 promotion) cost ~1.69M effective. T83 (analogous critic audit for edh-matsui F3 erratum capture) cost ~1.8M. T93 (sign-pattern Lemma 1 F=2 cyclic critic audit) cost ~1.6M. T101 (TDHFB Phase 2 critic Route I audit) cost ~1.5M. T107 expected ~1.6-2.2M (critic must read trajectory.csv + trajectory.png + config.yaml + _live_status.json + Matsui paper PDF + 3-4 sibling memory entries + state.json F1 falsifier text). 3.0M hard cap.

## 2. Recent-turn audit (last 6 turns; rotation lens)

| Turn | Investigation | Stage | Subagent | Verdict | What happened |
|---|---|---|---|---|---|
| T101 | tdhfb-phase2 | Update_2 | critic | CRITIC_PASS, CORROBORATE_WITH_ERRATA | Route I independent re-derivation; tier 2.5 → 2.75 |
| T102 | tdhfb-phase2 | Document | implementer_julia_cpu_light | PASS, TIER_3_CLOSURE_PASS | recompute at fresh parameters c_0=2.0 / 0.5; all F1/F2/F3 PASS; tier 2.75 → 3.0 |
| T103 | audit-class-scan-T103 | Observe | researcher_shallow | RESEARCHER_ONLY | 10-pattern sweep; 0 actionable; 1 L3 candidate proposed; anomaly-watch flagged duplicate metas |
| T104 | audit-class-scan-T103 | Triage L3-half | critic | CRITIC_PASS, L3_FAIL_REJECT | Q1+Q2 PASS, Q3+Q4 FAIL; first-ever L3 REJECT in §F6 history |
| T105 | audit-class-scan-T103 | Triage mech-half | implementer_text | PASS (23/23) | patterns.yaml + state.json bookkeeping; 2 duplicate-meta pairs cleaned |
| T106 | audit-class-scan-T103 | Document | implementer_text | PASS (43/43) | memory entry created; state.json tier 1.5 → 2; cycle terminal close |
| **T107** | **edh-eu151-matsui-science-2026** | **Update (re-opened)** | **critic** | **TBD** | **Independent audit of runs/eu151_edh_K3_long/ artifact against Matsui Science 2026; FORM-B central-falsifier check on F1** |

T107 = first T103-cycle-exit turn; rotates subagent class (implementer → critic); pivots topic (audit-class-scan → edh-matsui); advances physics D1 axis after a 4-turn loop-infrastructure detour.

## 3. Flow template recall

- **Template**: `verify-claim` (§B-Flow-Template-Table): Research → Hypothesize → Design → Execute → Analyze → **Update** → Document → closed.
- **Role for Update**: `critic (mandatory independent context)` per §B Flow-Template-Table. T107 dispatches critic in independent-audit mode.
- **Verdict-driven routing per §B Verdict-To-Next-Stage Mapping**:
  - If T107 critic verdict = **CORROBORATE** (F1 ring formation observed at correct timescale in K3_long): advance to Document (T108 implementer_text) with tier 2.5 → 3.0 promotion gate UNLOCKED. FORM-B check_cmd must independently confirm.
  - If T107 verdict = **INCONCLUSIVE** (ring formation pattern partial, e.g. cascade present but ring-density-minimum not unambiguously identified): stay at Update; theorist or critic re-dispatch at T108 with refined criteria. Tier stays 2.5; F1 result = INCONCLUSIVE.
  - If T107 verdict = **REFUTED** (no ring at any t < 10 τ_EdH^exp, OR ring in wrong spin component): advance to Document (T108 implementer_text) with tier 2.5 → 2.0 demotion + closing_note. Investigation closes REFUTED-CLEAN per `feedback_fix_the_class_not_the_instance` (the T76-T86 false closure stands corrected).
  - F1 is `is_central: true`; verdict directly drives §F8 Tier-3 promotion gate.

- **Why Update NOW (not Hypothesize, not Design, not Execute)**:
  - The artifact is ON DISK. No new simulation is needed (and seed.md explicitly forbids it). No new hypothesis is needed (F1 falsifier criteria are well-defined in state.json: "CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp]; INCONCLUSIVE if t_ring ∈ [0.2, 5.0] τ_EdH^exp; REFUTED if no ring at any t<10 τ_EdH^exp OR ring in wrong spin component"). No new design is needed (the K3_long config.yaml is the design).
  - The MISSING step is independent verification: did the K3_long run actually produce a ring formation matching Matsui's experimental cascade, or is the "clean cascade" claim in seed.md / memory based on an unaudited reading of trajectory.png?
  - Per "Artifact-first path" (director.md §B-Decision-Table): bypass flow_template stage order; jump to Update (verify-claim's audit/review stage).

- **Why critic, not theorist**:
  - The work is independent verification, not derivation. State.json's F1 falsifier text already encodes the criteria. The critic's job: read the raw data (trajectory.csv) + the configuration (config.yaml) + the experimental reference (Matsui Science 2026), apply the F1 criteria honestly, emit verdict.
  - Per §B-Flow-Template-Table, Update role is `critic (mandatory independent context)`. Honor the template.

## 4. Research grounding (§A6)

T107 dispatch citations (≥1 external reference per §A6; central-falsifier-audit turn so research grounding is on the artifact + the literature anchor):

1. **`runs/_loop/seed.md` "Highest priority NOW (2026-05-19)" section** — verbatim mandate to dispatch critic in independent-audit mode against `runs/eu151_edh_K3_long/trajectory.png` + `trajectory.csv` + sibling configs, crosswalk against Matsui Science 391 384-388 (2026) DOI:10.1126/science.adx2872. NO new EdH simulation. PASS → tier 3.0 with audit as load-bearing evidence.

2. **`runs/eu151_edh_K3_long/trajectory.csv`** — the canonical primary evidence (101 frames, t ∈ [0, 9.98] dimless ≈ [0, 14.5] ms). Columns: frame, t, norm, peak_density, Fz, pop_c1..pop_c13 (13 m-state populations). Final-frame (t=9.98): pop_c1=0.98 (m=+6), pop_c2=0.008 (m=+5), pop_c3=0.008 (m=+4), pop_c4=0.0018 (m=+3), pop_c5=0.0013 (m=+2), pop_c6=1.2e-4 (m=+1), pop_c7=3.3e-5 (m=0), ..., pop_c13=9e-10 (m=-6). All 13 m-states populated. Norm = 0.996 (small atom loss from K3 + γ_dr per config). Fz = 5.88 (mild depolarization from initial 6.0). **Cascade is mild (~2% out of m=+F); whether this constitutes "ring formation" per Matsui's criteria is exactly what the critic must judge**.

3. **`runs/eu151_edh_K3_long/config.yaml`** — the production setup: Eu151, F=6 D=13, 32^3 grid, box=20 a_ho, omega=(1,1,1.182), N=10000, c1_ratio=0, scalar LHY GS, B-quench 0.01 G → 2.6e-5 G in 0.14 ω^-1, weak-hold 2.6e-5 G for 10 ω^-1 = 14.5 ms, dt=1e-4, K3_per_m_si=1e-41 m^6/s on all 13 channels (Dy164 proxy), γ_dr=0.02 dipolar relaxation, noise seed=42 amplitude=1e-6, save every 200. **Matches Matsui's Case A modulo (a) N=10000 vs 30000 atoms; (b) Bz quench depth ~ 2.6 nT vs Matsui's near-zero; (c) Dy164 K3 proxy since Eu has no measured K_3 yet**.

4. **`runs/eu151_edh_K3_long/_live_status.json`** — final-step authoritative state (step=100000, t=9.98, energy=4.33 hbar*omega_ref, norm=0.996; populations vector confirming pop_c1=0.981, pop_c2=0.008, ..., pop_c13=9e-10). Independent of trajectory.csv (different writer).

5. **`runs/eu151_edh_K3_long/trajectory.png`** — the visual artifact anko cited in seed.md. Critic should READ the PNG (vision) and compare to the trajectory.csv numerical state; consistency check.

6. **Matsui, T. et al. Science 391, 384-388 (2026), DOI:10.1126/science.adx2872, arXiv:2504.17357** — primary experimental reference. The critic's literature anchor; F1 verdict requires comparing K3_long's t_ring to Matsui's τ_EdH^exp. T71 researcher_deep already extracted τ_EdH^exp, ℓ_paper from the PDF (per state.json stages_at_turn.Research[71]); critic can reuse the T71 extraction without re-extracting (cost saver).

7. **`memory/edh_matsui_baseline_2026_05_18.md`** — the T84 closure memory for the regressed `matsui_edh_baseline_9ca97308` config. Critic should read for: (a) the F3 erratum chain (E1 LOAD-BEARING extensive/intensive interpretation; E2-E4 advisory); (b) the F1 NOT_APPLICABLE_NO_RING ratification at T82-T84 (which was on the regressed config, NOT on K3_long); (c) τ_EdH^exp = 5 ms from Matsui as recorded; (d) F1 t_ring band [1.4, 14] ms post-E2-erratum correction. **Note**: that memory documents the closure that seed.md is overruling; critic must NOT carry forward the F3-alone tier inflation.

8. **`memory/feedback_use_existing_artifacts_first.md`** — anko's 2026-05-18 explicit rule. Critic operates entirely within this rule: audit the existing K3_long artifact against external lit; do NOT propose new simulations. The rule's positive form: "When the user mentions a topic, and `runs/<topic>*/` exists with a `.png` / `.csv` / non-trivial `result.*` — the loop's first move is **independent critic audit of THAT artifact against the literature** to confirm it is publication-grade Tier-3 evidence."

9. **`memory/feedback_manuscript_is_not_the_essence.md`** — anko's 2026-05-15 rule. T107 is D1 verification depth on a published-experiment benchmark, NOT manuscript polish; matches the rule's positive examples ("verification depth (D2), real bug-finding in production code ARE [what the loop is for]").

10. **`memory/gotcha_K3_routing_pre_2026_05_13.md`** — K3_per_m_si and dimless K3_per_m flowed into the WRONG LossParams field (L3_per_m linear-in-n 2-body shape) instead of K3_per_m_cubic (quadratic-in-n true 3-body) until commit 6bfe9d9. **K3_long was produced on or after 2026-05-13, so it is the FIRST proper post-fix K3 EdH run**. Critic must verify the trajectory was produced from a post-6bfe9d9 working tree (config.yaml comment lines 9-13 explicitly cite this; git log on the run timestamp would confirm but is optional — the comment in the config is the documented record).

11. **State.json F1 falsifier text (line 3215-3220)** — the criterion: "Reproduce Matsui near-zero-B-quench from m=+F FM state; measure t_ring where azimuthally-averaged |ψ_{c=c_flip}|^2 has local minimum at r=0 within ±20% depth + annulus aspect ratio >1.5. CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp]; INCONCLUSIVE if t_ring ∈ [0.2, 5.0] τ_EdH^exp; REFUTED if no ring at any t<10 τ_EdH^exp OR ring in wrong spin component. τ_EdH^exp extracted at T71 from paper PDF (NOT invented)." **Critic must apply this verbatim**.

12. **`runs/_loop/sim/turn_82.md`** + **`runs/_loop/judge/turn_83_critic_audit.md`** (T82 analyze + T83 critic) — prior analysis precedent on edh-matsui. T83 critic used "Route I" (independent re-derivation of TF closed forms); T107 critic should use an analogous "Route I" (independent re-derivation of τ_EdH^exp from Matsui's published numbers, not from T71's already-extracted value) to qualify as truly independent. **Note**: T83 audited the regressed `matsui_edh_baseline_9ca97308` artifact and found F3 CORROBORATE_WITH_ERRATA + F1 NOT_APPLICABLE_NO_RING. T107 audits the K3_long artifact and may produce a DIFFERENT verdict on F1; that is the entire point of the re-open.

13. **Grounded autonomous research (arXiv:2604.12198, Director.md §G)** — Arbiter-style adversarial audit is the canonical pattern for self-correction. T107 critic IS the Arbiter for the T76-T86 closure (which seed.md flagged as tier-inflation). The critic's job: independent verification, not corroboration of the prior closure.

14. **Director.md §B "Artifact-first path" rule** — already cited above (decision rationale). Stage = Update; subagent = critic; brief = audit existing artifact + crosswalk against published reference; NO new sim.

15. **Director.md §F8 Tier-3 promotion gate** — `judge.py` auto-clamps `if_success_tier_becomes ≥ 3.0` to 2.75 unless central falsifier has `result` containing CORROBORATE / CONFIRMED. F1 is central. FORM-B check_cmd against raw artifacts is required (cannot use LLM-summary FORM-A). T107 §6 contract specifies a FORM-B check_cmd reading trajectory.csv directly.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification of existing physics; Tier ladder 0→3)** for `edh-eu151-vortex-vs-matsui-science-2026`. The investigation's tier_target is 3 and central falsifier F1 is `tested_at_turn: null` — T107 is the structural unblock for tier 2.5 → 3.0. Per the project axes table: "D1: Matsui EdH critic audit" is the canonical example. Not D2 (no performance/optimization), not D3 (no new theory derivation; the theory was settled at T72), not D4 (this is not scheduler-mandated meta/audit work; it is anko-routed physics).

- **Tier ladder position**: T107 evaluates the central falsifier F1. On CORROBORATE: tier 2.5 → 3.0 at T108 Document. On INCONCLUSIVE: tier stays 2.5; one more refinement turn. On REFUTED: tier 2.5 → 2.0 with REFUTED-CLEAN closing_note (the T76-T86 closure stands corrected; physics is honest). **Project Tier-3 count today: 6 (barnett T29, klaus-bch T59, edh-matsui T86-but-being-re-audited, sign-pattern-lemma1 T94, tdhfb-phase2 T102; plus dormant-closed yan-li-saito at tier 0.4)**. If T107 produces CORROBORATE + T108 Document, edh-matsui's Tier-3 status becomes *load-bearing* (currently on F3 alone + closing-note-acknowledged F1 NOT_APPLICABLE). If REFUTED, the project's Tier-3 count drops to 5 honestly.

- **Project D1 verification depth narrative**: T107 is the highest-leverage single-turn move in the queue. It either upgrades a wobbly Tier-3 closure to a load-bearing one (good) or honestly demotes it (also good — falsifies a public claim before it spreads). Both outcomes advance scientific integrity.

- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. T107 reads on-disk artifacts + literature + state.json + memory; writes ONE critic-audit report at `runs/_loop/judge/turn_107_critic_audit.md` (per critic.md §C-Output) + ONE sim/turn_107.md narrative + state.json `falsifiers[F1].result` field update.

- **Cost frame**: target ~1.8-2.2M effective (per T58/T83/T93/T101 precedent). 3.0M hard cap.

- **Drift trajectory after T107 (anticipated)**:
  - `cost_inflation`: ~0.85-1.0 (~1.8M is just under the rolling effective median; no inflation).
  - `code_delta_zero`: 1.0 (critic is Read-only; no src/; correct by design for audit).
  - `manuscript_delta_zero`: 1.0 (advisory only).
  - `novel_claim_zero`: 0.0 (critic emits CORROBORATE / INCONCLUSIVE / REFUTED verdict + possibly new errata).
  - `topic_repetition`: drops sharply (audit-class-scan → edh-matsui pivot).
  - `subagent_repetition`: drops (implementer × 4 in last 6 → critic resets to 0.167 for critic; 0.333 for implementer).
  - `verdict_drift`: low if CORROBORATE, moderate spike if REFUTED (verdict-class change is expected on re-audit).
  - `AUDIT_DUE`: cleared since T105; gap=2; stays cleared.
  - Drift escalation: `advisory` or `clean`.

- **Recommended T108-T112 trajectory**:
  1. **T108 (depends on T107 verdict)**:
     - If CORROBORATE: implementer_text Document closure (tier 2.5 → 3.0; memory entry update on `edh_matsui_baseline_2026_05_18.md`; state.json closing_note revision; F1 result update from null to CORROBORATE). 1-turn, ~1.5M.
     - If INCONCLUSIVE: theorist refinement at T108 (sharpen criteria, e.g. ring-detection algorithm definition; per state.json the criterion uses "azimuthally-averaged |ψ_{c=c_flip}|^2 local minimum at r=0" — this needs an explicit numerical recipe applied to the trajectory.csv columns or to result.jld2 spatial data). Tier stays 2.5.
     - If REFUTED: implementer_text Document with REFUTED-CLEAN closing_note. Tier 2.5 → 2.0. Project's Tier-3 count drops by 1 (honest correction).
  2. **T109+ pivot options** (priority-ordered, with rotation pressure favoring non-critic subagents at T109):
     - **meta-cost-waste-audit-2026-05-18 Hypothesize** (priority 15): theorist (rotation-friendly after critic).
     - **meta-director-self-audit-2026-05-19 Hypothesize** (priority 20): theorist + F5 Arbiter rail.
     - **drift_signals.py idempotency fix-bug** (T104+T105+T106 deferred): theorist Hypothesize then implementer Patch.
     - **F1 ring-detection script formalization** (D2 service axis): if T107 verdict is INCONCLUSIVE, develop a reusable `check_ring_in_trajectory.py` that downstream T_n+ runs can reuse. Subagent: implementer_text or implementer_sympy.
  3. **Window has 18553 minutes left** — ample budget; no urgency.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "researcher_depth": null,
  "parallel_researcher_count": 1,
  "project_axis": "D1",
  "rationale": "Per seed.md 'Highest priority NOW (2026-05-19)' MANDATE (verbatim: 'Director MUST pick this as next active investigation'): independent critic audit of runs/eu151_edh_K3_long/{trajectory.csv, trajectory.png, config.yaml, _live_status.json, result.jld2} (May 13 run; 32^3, K3 + gamma_dr + noise seed, 100k steps reaching t=9.98 dimless = 14.5 ms; norm=0.996; all 13 m-states populated by t=10) against Matsui et al. Science 391, 384-388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357]. Director §B-Decision-Table 'Artifact-first path' rule directly applies (artifact exists with non-trivial outputs; tier_current 2.5 < 3; central falsifier F1-ring-appears-correct-timescale has is_central:true and tested_at_turn:null). Stage = Update (verify-claim's audit/review stage); subagent = critic (Update role per §B Flow-Template-Table); brief = audit existing artifact + crosswalk against published reference; NO new simulation per anko's existing-artifacts-first rule (memory/feedback_use_existing_artifacts_first). Audit-class-scan-T103 cycle terminally closed at T106 (43/43 PASS, tier 2); subagent rotation pressure (implementer × 4 in last 6 turns per T106 §5 drift advisory + seed.md 'no more than 2 same-subagent in a row' stop condition) addressed by critic dispatch. D1 axis: verification depth on the project's lab-paper benchmark; tier-promotion gate F8 unlocks (or honestly REFUTES the T76-T86 closure). 6th project Tier-3 closure status is at stake — either upgraded to load-bearing (CORROBORATE on F1, the central falsifier) or honestly demoted (REFUTED-CLEAN; project Tier-3 count goes 6 → 5 with scientific integrity intact).",
  "brief": "## ROLE\n\nYou are the critic for T107 §B-verify-claim Update stage of investigation `edh-eu151-vortex-vs-matsui-science-2026`. Mandatory independent context: do NOT trust the T70-T86 closure narrative (which was on F3 alone; F1 was NOT actually tested against the K3_long artifact). Your job: apply state.json F1 falsifier criteria VERBATIM to the K3_long artifact + crosswalk against Matsui Science 2026, emit ONE verdict in {CORROBORATE, CORROBORATE-WITH-ERRATA, INCONCLUSIVE, REFUTED}.\n\nDIRECTIVE_LABEL: edh-eu151-matsui-T107-update-critic-audit-k3-long-vs-matsui-2026\n\nNO new simulation. NO julia execution. Read-only. Crosswalk only.\n\n## REQUIRED READING (in order; READ all before forming any verdict)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/seed.md` 'Highest priority NOW (2026-05-19)' section (lines 1-31) — the explicit mandate that frames this turn.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_107.md` (this director report) — §6 contract + §4 research grounding + §1 rationale.\n3. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml` (77 lines) — the production setup. CONFIRM: scalar LHY GS + K3_per_m_si=1e-41 m^6/s on all 13 channels + gamma_dr=0.02 + noise.seed=42 amplitude=1e-6 + N=10000 + 32^3 grid + 14.5 ms hold. Note c1_ratio=0 (pure DDI+contact, no spin-mixing). Note p_dimless implicit from Bz=2.6e-5 G.\n4. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv` (ALL 101 lines, but you may sample if too long; columns: frame, t, norm, peak_density, Fz, pop_c1..pop_c13). Primary numerical evidence.\n5. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/_live_status.json` — final-step authoritative (step=100000, t=9.98, norm=0.996, populations[13]).\n6. `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png` — visual artifact (use vision; describe what you see; cross-check vs trajectory.csv).\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 3178-3262 — F1/F2/F3/F4 falsifier text. F1 criteria VERBATIM: 'Reproduce Matsui near-zero-B-quench from m=+F FM state; measure t_ring where azimuthally-averaged |ψ_{c=c_flip}|^2 has local minimum at r=0 within ±20% depth + annulus aspect ratio >1.5. CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp]; INCONCLUSIVE if t_ring ∈ [0.2, 5.0] τ_EdH^exp; REFUTED if no ring at any t<10 τ_EdH^exp OR ring in wrong spin component.'\n8. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md` — the T84 closure memory for the REGRESSED matsui_edh_baseline_9ca97308 (NOT K3_long). Note τ_EdH^exp = 5 ms from Matsui, F1 t_ring band post-erratum [1.4, 14] ms. Use the τ_EdH^exp and band; do NOT recycle the F1 NOT_APPLICABLE verdict from this memory — that was on the regressed config.\n9. **Matsui, T. et al. Science 391, 384-388 (2026), DOI:10.1126/science.adx2872, arXiv:2504.17357** — fetch via WebFetch on arXiv (use `https://arxiv.org/abs/2504.17357` first, then `https://arxiv.org/pdf/2504.17357` if more detail needed). Extract independently: τ_EdH^exp band, ring formation timescale, spin component where ring appears (c_flip = m=−6 = pop_c13 at unit-vector flip from m=+6 GS), winding number ℓ_paper. Compare to T71 researcher_deep's prior extraction (state.json stages_at_turn.Research[71]).\n10. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_use_existing_artifacts_first.md` — anko's rule; explicitly authorizes/requires this audit shape.\n11. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/gotcha_K3_routing_pre_2026_05_13.md` — K3 routing was buggy until 2026-05-13 commit 6bfe9d9. CONFIRM K3_long is post-fix (config.yaml lines 9-13 explicitly cite the fix). If unclear, run `git log --format=oneline -- runs/eu151_edh_K3_long/` and `git log --format=oneline 6bfe9d9 | head -1` via WebFetch is NOT applicable — use Read tool on .git/logs/HEAD if needed. Document in audit.\n\n## YOUR AUDIT TASK — 5 questions to answer\n\nFor each question, cite a specific line/frame/value from the artifact OR the paper. Do NOT hand-wave.\n\n### Q1: F1 RING-FORMATION CASCADE PRESENT?\n\nIs there evidence of a Matsui-style ring formation in the K3_long trajectory?\n\n- The 'c_flip' for Matsui's near-zero-B-quench from m=+6 GS is m=−6 = pop_c13 if the quench fully inverts, or pop_c2/pop_c3 (m=+5/+4) if the cascade is partial.\n- At t=9.98 (final): pop_c1=0.98, pop_c2=0.008, pop_c3=0.008, pop_c4=0.0018, pop_c5=0.0013, pop_c6=1.2e-4, ..., pop_c13=9e-10. **Cascade is mild — ~2% out of m=+F**. Matsui's experimental observation is a CLEAR ring on m=c_flip with depth > 20% and aspect > 1.5. Is the 2% cascade enough to detect a ring, or is K3_long sub-threshold?\n- F1 criterion is on the spatial structure (azimuthal density profile of pop_c_flip), not just the integrated population. The trajectory.csv has populations integrated over space; the spatial structure lives in result.jld2 (which we cannot easily read without julia, so the critic CANNOT directly verify the spatial ring claim from trajectory.csv alone — this is the central scope question).\n- **If you can demonstrate from trajectory.csv + trajectory.png alone that a ring formed at some t in [1.4, 14] ms**: CORROBORATE.\n- **If trajectory.csv only shows the cascade fraction (no spatial info) and trajectory.png is ambiguous**: INCONCLUSIVE (spatial extraction from result.jld2 is needed — defer to D2-service-axis follow-up turn).\n- **If trajectory.csv shows NO cascade OR cascade in wrong spin component**: REFUTED.\n\n### Q2: K3_LONG CONFIG ANCHORS TO MATSUI'S EXPERIMENTAL SETUP?\n\nDoes K3_long's config.yaml match Matsui's Case A within factor-2?\n\n- N=10000 (config) vs Matsui's N~30000 — factor 3 off.\n- omega_ref=691.15 rad/s = 2*pi*110 Hz (config) vs Matsui's 2*pi*100 Hz — factor 1.1 off.\n- trap aspect (1, 1, 1.182) (config) vs Matsui's near-isotropic — OK.\n- Bz quench depth 0.01 G → 2.6e-5 G (config) vs Matsui's 'near-zero B' final state — OK at the right order.\n- K3_per_m_si=1e-41 (Dy164 proxy) vs Eu's unmeasured — UNAVOIDABLE proxy.\n- gamma_dr=0.02 (config) vs Matsui's unspecified phenomenological dipolar relaxation rate — order-of-magnitude reasonable.\n- noise.seed=42 amplitude=1e-6 (config) vs Matsui's experimental imperfections — order-of-magnitude reasonable.\n\n**Question**: are the factor-3 N-difference and factor-1.1 omega-difference within Matsui's reported experimental uncertainty bands, or do they push K3_long outside Matsui's parameter regime? Cite Matsui section.\n\n### Q3: τ_EdH^EXP INDEPENDENT RE-EXTRACTION FROM PAPER?\n\nIndependently extract τ_EdH^exp from Matsui Science 2026 (arXiv:2504.17357). Compare to the T71 researcher_deep extraction (per state.json stages_at_turn.Research[71] note 'tau_EdH^exp, ell_paper extracted'). Confirm or correct.\n\n### Q4: K3 ROUTING POST-FIX CONFIRMATION?\n\nVerify K3_long was produced after the 2026-05-13 K3 routing fix (commit 6bfe9d9 per memory/gotcha_K3_routing_pre_2026_05_13.md). The config.yaml comment lines 9-13 explicitly cite this fix. Run a one-line WebFetch-equivalent check or accept the config-self-claim. If pre-fix, K3 was applied as linear-in-n loss (2x too small at n=2n0, 10x too large at n=0.1n0) → K3_long's claimed K3 effect is wrong → INCONCLUSIVE at minimum.\n\n### Q5: F1 VERDICT (load-bearing)\n\nApply state.json F1 falsifier criteria verbatim. Emit:\n- CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp] and spatial ring confirmed.\n- INCONCLUSIVE if t_ring ∈ [0.2, 5.0] τ_EdH^exp OR spatial ring cannot be confirmed from trajectory.csv + trajectory.png + _live_status.json alone.\n- REFUTED if no ring at any t < 10 τ_EdH^exp OR ring in wrong spin component.\n\n## OUTPUT — write `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md`\n\nStructure:\n\n```markdown\n---\nturn: 107\nsubagent: critic\ninvestigation_id: edh-eu151-vortex-vs-matsui-science-2026\nstage_advancing_to: Update\nverdict_token: CORROBORATE | CORROBORATE-WITH-ERRATA | INCONCLUSIVE | REFUTED\nf1_central_falsifier_result: CORROBORATE | CORROBORATE-WITH-ERRATA | INCONCLUSIVE | REFUTED\ntier_recommendation: 3.0 | 2.5 | 2.0\nn_references_cited: <int>\nerrata_count: <int>\nerrata_load_bearing_count: <int>\nerrata_advisory_count: <int>\n---\n\n# Turn 107 — Critic Audit (edh-eu151-matsui-science-2026 Update stage; F1 central falsifier re-test against runs/eu151_edh_K3_long/ artifact)\n\n## 1. Independent context\n\n[Your independent path: re-read seed.md mandate; do NOT trust T76-T86 closure; the K3_long artifact has never been audited for F1.]\n\n## 2. Artifact triage\n\n[Cite trajectory.csv frame N at t = X; pop_c1 = Y; ... ; cite trajectory.png visual content; cite _live_status.json step=100000.]\n\n## 3. K3_long config crosswalk vs Matsui Case A (Q2 answer)\n\n[Table of N, omega, trap aspect, Bz_initial, Bz_final, K3, gamma_dr, noise; one row per parameter; column 'config' vs 'Matsui' vs 'factor diff' vs 'within band?'.]\n\n## 4. K3 routing post-fix confirmation (Q4 answer)\n\n[Cite config.yaml comment lines 9-13 + memory/gotcha_K3_routing_pre_2026_05_13.md; record verdict.]\n\n## 5. tau_EdH^exp independent re-extraction (Q3 answer)\n\n[Cite Matsui section + value extracted; compare to T71 researcher_deep value.]\n\n## 6. F1 verdict on the K3_long artifact (Q1 + Q5 answer)\n\n[The load-bearing analysis: is there a ring in m=c_flip with depth >20% + aspect >1.5 at some t ∈ [1.4, 14] ms? If trajectory.csv + trajectory.png + _live_status.json alone are sufficient, decide. If NOT sufficient (because spatial structure lives in result.jld2 which requires julia to read), recommend INCONCLUSIVE and route to a D2-service implementer_julia_cpu_light turn to extract spatial density slices.]\n\n## 7. Errata list (load-bearing + advisory)\n\n[Any new errata vs T82-T84 closure narrative; class-level findings; advisory or load-bearing classification.]\n\n## 8. Verdict + tier recommendation\n\n[Single sentence: F1 = CORROBORATE | INCONCLUSIVE | REFUTED → tier_target 3.0 | 2.5 | 2.0.]\n\n## 9. Routing for T108\n\n[If CORROBORATE: T108 implementer_text Document with tier 3.0 closure + memory entry update. If INCONCLUSIVE: T108 implementer_julia_cpu_light extracts spatial slices from result.jld2; OR theorist refines criteria. If REFUTED: T108 implementer_text Document with REFUTED-CLEAN closing_note.]\n\n## 10. Metrics block (FORM-A + FORM-B inputs for judge.py §F8)\n\n```json\n{\n  \"experiment_kind\": \"text_only_critic_audit\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"edh-eu151-vortex-vs-matsui-science-2026\",\n  \"stage_advancing_to\": \"Update\",\n  \"flow_template\": \"verify-claim\",\n  \"verdict_token\": \"CORROBORATE | CORROBORATE-WITH-ERRATA | INCONCLUSIVE | REFUTED\",\n  \"f1_central_falsifier_result\": \"<same value as verdict_token mapped to F1 result space>\",\n  \"tier_recommendation\": <3.0|2.5|2.0>,\n  \"n_references_cited\": <int>,\n  \"errata_count\": <int>,\n  \"errata_load_bearing_count\": <int>,\n  \"errata_advisory_count\": <int>,\n  \"k3_long_config_matches_matsui_case_a_within_factor_2\": true|false,\n  \"k3_routing_post_fix_confirmed\": true|false,\n  \"tau_edh_exp_extracted_independently_value_ms\": <float or null>,\n  \"cascade_fraction_at_t_final\": 0.0192,\n  \"spatial_ring_observed_via_artifact\": true|false|null,\n  \"trajectory_csv_read\": true,\n  \"trajectory_png_read\": true,\n  \"config_yaml_read\": true,\n  \"_live_status_json_read\": true,\n  \"matsui_paper_fetched\": true,\n  \"src_edited\": false,\n  \"julia_executed\": false,\n  \"manuscript_edited\": false,\n  \"new_simulations_proposed\": false\n}\n```\n```\n\n## SUCCESS CRITERIA (FORM-B for F1 central falsifier; judge.py §F8 promotion gate)\n\nThe Tier-3 promotion gate requires a FORM-B check_cmd against raw artifacts. T107 §6 contract specifies two FORM-B check_cmds:\n\n### Form-B check #1 (cascade-present sanity gate; pre-condition)\n\n`python3 -c \"import csv; rows=list(csv.DictReader(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv'))); last=rows[-1]; cascade=sum(float(last[f'pop_c{i}']) for i in range(2,14)); fz=float(last['Fz']); pop_c1=float(last['pop_c1']); print(f'CASCADE_FRACTION={cascade:.4f} FZ={fz:.4f} POP_C1={pop_c1:.4f} CASCADE_PRESENT' if (cascade > 0.01 and fz < 5.95) else f'CASCADE_FRACTION={cascade:.4f} FZ={fz:.4f} POP_C1={pop_c1:.4f} NO_CASCADE')\"`\n\nExpect: exit_code 0, stdout contains `CASCADE_PRESENT`.\n\n### Form-B check #2 (F1 verdict materialized in critic-audit YAML)\n\n`python3 -c \"import re,sys; t=open('/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md').read(); m=re.search(r'f1_central_falsifier_result:\\s*(\\S+)', t); v=m.group(1) if m else None; print('F1_RESULT='+str(v))\"`\n\nExpect: exit_code 0, stdout matches one of {CORROBORATE, CORROBORATE-WITH-ERRATA, INCONCLUSIVE, REFUTED}.\n\n## CONSTRAINTS\n\n- **Files allowed to create**: `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md` (the audit report; mandatory).\n- **Files allowed to modify**: `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_107.md` (optional turn-narrative if your role requires; usually critic writes only the audit md, not a sim md).\n- **Files FORBIDDEN to modify**: `src/`, `runs/eu151_*/`, `runs/_loop/state.json` (the orchestrator handles state.json updates based on your verdict), `runs/_loop/patterns.yaml`, `.claude/agents/*`, `.claude/scripts/*`, `runs/auto/`, any manuscript directory.\n- **No julia execution**. No new simulation. No new analysis script in `runs/auto/`.\n- **English only. No emojis. No improvised metaphor terminology.**\n- **Absolute paths in all Read tool calls.**\n- **Cost budget**: stay within ~2.5M effective tokens, ~15 min wall hard cap. Target ~1.8-2.2M (per T58/T83/T93/T101 critic precedent).\n- **No fabrication**: every claimed metric value in turn_107_critic_audit.md §10 must correspond to actual file state observable via Read; every claimed Matsui paper value must cite a section or table.\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT carry forward the T76-T86 F1 NOT_APPLICABLE_NO_RING verdict; that was on the regressed `matsui_edh_baseline_9ca97308` config, NOT on K3_long.\n- Do NOT propose a new simulation. Per seed.md: 'no new EdH simulation this round. The accumulated runs ARE the data.'\n- Do NOT claim a spatial ring exists without spatial evidence. trajectory.csv has integrated populations; trajectory.png has whatever the May-13 extract_trajectory.jl plotted (likely population vs t, not spatial slices). result.jld2 has the spatial data but requires julia. If the spatial evidence is unavailable from the readable artifacts, the honest verdict is INCONCLUSIVE (route to D2-service follow-up at T108).\n- Do NOT inflate to CORROBORATE on cascade-alone. Matsui's F1 criterion is a SPATIAL ring with depth >20% and aspect >1.5. A 2% cascade integrated over space is consistent with EITHER 'small ring forming' OR 'uniform leakage'. Honesty over closure.\n- Do NOT use anko-attribution in the audit report.\n- Do NOT use improvised metaphor terminology.\n- Do NOT exceed 2.5M effective tokens.\n- Do NOT modify any other investigation in state.json (orchestrator-managed; T108 will patch based on your verdict).\n\n## REPORTING DISCIPLINE\n\nIf any required file is missing (state.json malformed; trajectory.csv parseable; etc.), STOP and report; do not improvise. If the Matsui paper WebFetch fails after 2 retries, document the failure in §5 and recommend INCONCLUSIVE pending paper access at T108. If your verdict is REFUTED, the project's Tier-3 count drops 6 → 5 — be explicit about this consequence in §8 and §9. Honest verdict only; the loop's scientific integrity is the load-bearing output.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "verdict_token",
      "f1_central_falsifier_result",
      "tier_recommendation",
      "n_references_cited",
      "errata_count",
      "errata_load_bearing_count",
      "errata_advisory_count",
      "k3_long_config_matches_matsui_case_a_within_factor_2",
      "k3_routing_post_fix_confirmed",
      "tau_edh_exp_extracted_independently_value_ms",
      "cascade_fraction_at_t_final",
      "spatial_ring_observed_via_artifact",
      "trajectory_csv_read",
      "trajectory_png_read",
      "config_yaml_read",
      "_live_status_json_read",
      "matsui_paper_fetched",
      "src_edited",
      "julia_executed",
      "manuscript_edited",
      "new_simulations_proposed"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/_live_status.json && python3 -c \"import csv; rows=list(csv.DictReader(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv'))); assert len(rows)>=50, f'expected >=50 frames, got {len(rows)}'; assert 'pop_c1' in rows[0] and 'pop_c13' in rows[0], 'missing pop columns'; assert 'Fz' in rows[0], 'missing Fz'; print('OK precondition: '+str(len(rows))+' frames, columns OK')\""
  },
  "success_criteria": [
    {
      "id": "F1-cascade-present-precondition",
      "check_cmd": "python3 -c \"import csv; rows=list(csv.DictReader(open('/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv'))); last=rows[-1]; cascade=sum(float(last[f'pop_c{i}']) for i in range(2,14)); fz=float(last['Fz']); pop_c1=float(last['pop_c1']); print(f'CASCADE_FRACTION={cascade:.4f} FZ={fz:.4f} POP_C1={pop_c1:.4f} CASCADE_PRESENT' if (cascade > 0.01 and fz < 5.95) else f'CASCADE_FRACTION={cascade:.4f} FZ={fz:.4f} POP_C1={pop_c1:.4f} NO_CASCADE')\"",
      "expect": {"exit_code": 0, "stdout_contains": "CASCADE_PRESENT"}
    },
    {
      "id": "F1-verdict-materialized-in-audit",
      "check_cmd": "python3 -c \"import re; t=open('/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md').read(); m=re.search(r'f1_central_falsifier_result:\\s*(\\S+)', t); v=(m.group(1) if m else 'NONE').strip(); ok=v in ('CORROBORATE','CORROBORATE-WITH-ERRATA','INCONCLUSIVE','REFUTED'); print('F1_RESULT='+v+(' OK' if ok else ' BAD'))\"",
      "expect": {"exit_code": 0, "stdout_contains": "OK"}
    },
    {
      "id": "audit-md-has-verdict-token",
      "check_cmd": "python3 -c \"import re; t=open('/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md').read(); m=re.search(r'verdict_token:\\s*(\\S+)', t); v=(m.group(1) if m else 'NONE').strip(); ok=v in ('CORROBORATE','CORROBORATE-WITH-ERRATA','INCONCLUSIVE','REFUTED'); print('VERDICT='+v+(' OK' if ok else ' BAD'))\"",
      "expect": {"exit_code": 0, "stdout_contains": "OK"}
    },
    {
      "id": "no-new-simulation-proposed",
      "metric": "new_simulations_proposed",
      "operator": "==",
      "value": false
    },
    {
      "id": "no-julia-executed",
      "metric": "julia_executed",
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
      "id": "trajectory-csv-read",
      "metric": "trajectory_csv_read",
      "operator": "==",
      "value": true
    },
    {
      "id": "trajectory-png-read",
      "metric": "trajectory_png_read",
      "operator": "==",
      "value": true
    },
    {
      "id": "config-yaml-read",
      "metric": "config_yaml_read",
      "operator": "==",
      "value": true
    },
    {
      "id": "matsui-paper-fetched",
      "metric": "matsui_paper_fetched",
      "operator": "==",
      "value": true
    },
    {
      "id": "n-refs-bound",
      "metric": "n_references_cited",
      "operator": ">=",
      "value": 5
    },
    {
      "id": "tier-recommendation-bounded",
      "metric": "tier_recommendation",
      "operator": "in",
      "value": [2.0, 2.5, 3.0]
    }
  ],
  "failure_modes": [
    {
      "if": "F1-cascade-present-precondition failed (CASCADE_FRACTION <= 0.01 OR FZ >= 5.95)",
      "category": "data_gap",
      "next_action": "stop and report; the K3_long artifact is unexpectedly featureless (which would itself be a finding worth re-running this from-scratch; would route to T108 implementer_julia_cpu_light spatial-extraction or new K3_long re-run with longer duration; do NOT advance to F1 verdict on insufficient data)"
    },
    {
      "if": "F1-verdict-materialized-in-audit failed (audit md missing or verdict token not in allowed set)",
      "category": "operational",
      "next_action": "re-dispatch critic at T108 with verdict-format hardening; tier_target unchanged at 2.5"
    },
    {
      "if": "audit-md-has-verdict-token failed (verdict_token in YAML frontmatter not in allowed set)",
      "category": "operational",
      "next_action": "re-dispatch critic at T108 with frontmatter hardening; tier_target unchanged at 2.5"
    },
    {
      "if": "n-refs-bound failed (n_references_cited < 5)",
      "category": "operational",
      "next_action": "re-dispatch critic at T108 with research-grounding push (must cite ≥5 sources including Matsui paper + ≥3 prior turns + ≥1 memory file)"
    },
    {
      "if": "no-new-simulation-proposed failed (critic proposed a new simulation)",
      "category": "framework_error",
      "next_action": "REJECT the critic verdict; the rule from seed.md + memory/feedback_use_existing_artifacts_first is absolute. Re-dispatch critic at T108 with anti-pattern guard pushed."
    },
    {
      "if": "F1 verdict is CORROBORATE but spatial_ring_observed_via_artifact != true",
      "category": "scientific_overreach",
      "next_action": "DOWNGRADE F1 result to INCONCLUSIVE; cascade-alone does not satisfy Matsui's spatial-ring criterion. Re-dispatch critic at T108 with the cascade-vs-spatial-ring distinction pushed."
    },
    {
      "if": "F1 verdict is REFUTED",
      "category": "scientific_refuted",
      "next_action": "T108 implementer_text Document with REFUTED-CLEAN closing_note; tier 2.5 → 2.0; project Tier-3 count 6 → 5; update memory/edh_matsui_baseline_2026_05_18.md with REFUTED status + erratum chain"
    },
    {
      "if": "F1 verdict is INCONCLUSIVE and spatial_ring_observed_via_artifact is null",
      "category": "data_gap",
      "next_action": "T108 implementer_julia_cpu_light dispatch to extract spatial density slices from result.jld2 (D2 service axis); follow-up T109 re-runs the critic with spatial evidence"
    }
  ],
  "budget": {
    "expected_cost_eff": 2000000,
    "expected_wall_time_sec": 900
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document",
    "if_success_tier_becomes": 3.0,
    "if_partial_advance_to_stage": "Update (re-dispatch with refined criteria OR spatial-extraction D2 follow-up)",
    "if_partial_tier_becomes": 2.5,
    "if_refuted_advance_to_stage": "Document",
    "if_refuted_tier_becomes": 2.0,
    "if_success_falsifier_update": {
      "id": "F1-ring-appears-correct-timescale",
      "tested_at_turn": 107,
      "result_template": "CORROBORATE: F1 ring formation confirmed via independent critic audit of runs/eu151_edh_K3_long/ artifact (t_ring = <T107 critic-extracted value> ms ∈ Matsui τ_EdH^exp ± factor-2 band; cascade fraction at t_final = <value>; spatial ring depth >20% + aspect >1.5 confirmed via <evidence>). Tier 2.5 → 3.0 promotion gate unlocked per §F8."
    },
    "post_critic_pivot_options": [
      "T108 implementer_text Document closure (if CORROBORATE; tier 2.5 → 3.0)",
      "T108 implementer_julia_cpu_light spatial-extraction from result.jld2 (if INCONCLUSIVE due to data gap)",
      "T108 implementer_text Document REFUTED-CLEAN closure (if REFUTED; tier 2.5 → 2.0; project Tier-3 count 6 → 5)",
      "T108 theorist refinement of F1 detection algorithm (if INCONCLUSIVE due to ambiguous criteria)"
    ]
  }
}
```
