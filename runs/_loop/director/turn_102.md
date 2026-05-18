---
turn: 102
subagent: director
investigation_id: tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18
stage_advancing_from: Update
stage_advancing_to: Document
topic_tags: [d1-verification, tdhfb-phase2-generic-f, bogoliubov-spectrum-f1, kawaguchi-ueda-2012-sound-velocity, tier275-to-tier3, document-closure, julia-recompute-caveat-resolve, implementer-julia-cpu-light]
paper_section: null
depends_on: [101, 100, 99, "runs/_loop/director/turn_101.md", "runs/_loop/critic/turn_101.md", "runs/_loop/judge/turn_101_critic_audit.md", "runs/_loop/sim/turn_100.md", "runs/_loop/theorist/turn_99.md", "runs/_loop/_local/scheduler_102.json", "scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl", "memory:tier3_pipeline_survey_2026_05_18", "memory:loop_architecture_2026_05_14"]
produces: "T102 implementer_julia_cpu_light dispatch (Document stage with caveat-resolution prerequisite). Single combined turn: (a) write a /tmp/ parameter-override copy of the diagnostic script for two fresh parameter points (polar c_0=2.0, c_1=+0.05 and FM c_0=0.5, c_1=-0.2), run it under julia (~30s warm JIT, ~2-3 min cold), confirm the critic's three symbolic-substitution predictions empirically (recompute_polar_rel_error < 1e-3, recompute_fm_rel_error < 1e-3, recompute_factor_2_ratio abs_err < 1e-12); (b) on empirical PASS, write the Document closure: memory entry `tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md`, append T102 [Established] entry to `runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`, MEMORY.md index entry (1 line under ## TDHFB Phase 2 section). On empirical PASS the tier advances 2.75 -> 3.0 (caveat resolved); on empirical FAIL the tier stays at 2.75 with the caveat made formal and a fix-bug spawn triggered. 6th project Tier-3 closure; arc T98->T99->T100->T101->T102 = 5 turns total."
---

# Turn 102 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. **Continuing** from T101 (no switch). Stage transition: **Update -> Document** per §F1 verify-claim flow with caveat-resolution prerequisite (see §3 below).
- **T101 critic disposition** (read this turn): `runs/_loop/critic/turn_101.md` + `runs/_loop/judge/turn_101_critic_audit.md` verdict = **CORROBORATE_WITH_ERRATA** (METRICS JSON §6: `tier_reached: 2.75`, `verdict: "CORROBORATE_WITH_ERRATA"`, `audit_finding_count_total: 1`, `audit_finding_severity_max: "minor_erratum"`). Breakdown:
  - **Deliverable A (independent algebra)**: CLEAN. Route I (GP-linearization, KU2012 §5.1.2) reproduced polar phonon $\omega^2 = \epsilon_k(\epsilon_k + 2 c_0 n)$ AND FM phonon $\omega^2 = \epsilon_k(\epsilon_k + 2(c_0+c_1)n)$ AND polar magnon $\omega^2 = \epsilon_k(\epsilon_k + 2 c_1 n)$ (latter a Tier-3.5 extension, not load-bearing) via structurally-different route. Factor-2 origin identified differently from T99's Bose-symmetrization route (T99 puts the 2 in $\Sigma^{HF}$; Route I puts it in `diagonal_Hartree + anomalous_Hartree` sum). Same algebraic value reached via different intermediate structures — strongest form of independent confirmation.
  - **Deliverable B (numerical recompute at fresh parameters)**: **DELIVERED BY SYMBOLIC SUBSTITUTION ONLY**. The critic harness in this environment was provisioned with only the `Read` tool — no `Bash`, no `Write` (per critic protocol §A2 typical scope). Critic could not write the `/tmp/` script nor execute `julia`. The recompute predictions at polar c_0=2.0 ($c_s = \sqrt 2$, rel_err ~3e-6 to 1e-5) and FM c_0=0.5 ($c_s = \sqrt{0.3}$, rel_err ~1e-5 to 4e-5) and F3 ratio (2.0 ± few ulps) follow by symbolic substitution into the Route I dispersion formula, which is parameter-uniform in $c_0 n$ or $(c_0+c_1) n$.
  - **Deliverable C (systematic-error audit)**: CLEAN. C1 μ choice `sound` (GS-determined, F4 Goldstone gap = 0 exact confirms). C2 k-grid finite-k correction `matches k^2 Taylor prediction` (predicted $\Delta c_s/c_s \approx k_{\max}^2 / (8 c_0 n) = 1.25\times 10^{-5}$, observed T100 rel_err = 7.86e-6, within factor of 2). C3 Δ-block convention `uniform` (`channel_kernel` un-symmetrized V for anomalous block, `channel_kernel_symmetrized` = 2V for HF self-energy — split by name, both correct).
- **Caveat nature**: NOT a scientific caveat. The dispersion formula is structurally parameter-uniform under Route I (the critic's algebra-only verification at fresh parameters catches the algebraic prediction); the missing empirical recompute does not catch parameter-conditioning bugs in `eigvals` at extreme `g_S` regimes, but the test parameters ($|c_1/c_0|=0.4$ FM, $|c_1/c_0|=0.025$ polar) are well within standard regimes with no `g_S` sign change. The caveat is purely a tooling-restriction artifact (critic Read-only harness), resolvable by ~30s of Julia execution.
- **state.json field status** (lines 3332-3384 read this turn): `tier_current: 2.5` (will be updated to 2.75 by orchestrator post-T101 commit; verify on T102 read), `next_stage: "Update"` (stale; orchestrator should update to `Document` on T101 commit), `last_turn: 100` (stale; orchestrator should update to 101), `priority: 2`, `kind: "physics"`. **Stale-field cleanup**: orchestrator commits these tier/stage/turn updates as part of the post-turn judge cycle; if T101 commit hasn't landed by the time T102 implementer reads state.json, the implementer should still proceed with the documented next stage (Document) per this director contract.
- **Tier**: 2.75 (post-T101 CORROBORATE_WITH_ERRATA) -> expected 3.0 on T102 empirical-recompute PASS (caveat resolved). Tier target: 3. **This is the final substantive step before Tier-3 closure**, exactly as anticipated by T101 director §6.failure_modes[1].next_action ("dispatch implementer_text for Document stage with the caveat captured in the memory entry; tier becomes 2.75") — but with a refinement: rather than just documenting the caveat at 2.75 in perpetuity, T102 can resolve it via the same /tmp/ Julia recompute the critic recommended in §5.
- **Falsifiers tested status** (after T101): F1 polar phonon at c_0=1.0 PASS (T100 rel_err 7.86e-6) + symbolic at c_0=2.0 PASS (T101 prediction); F2 FM phonon at c_0=1.0, c_1=-0.1 PASS (T100 rel_err 8.74e-6) + symbolic at c_0=0.5, c_1=-0.2 PASS (T101 prediction); F3 BdG/GP factor-2 ratio PASS (T100 abs_err 1.33e-15) + audit-confirmed structural origin (T101). T102 closes the empirical loop on the symbolic predictions.
- **Other in-flight investigations** (state.json line 3385+):
  - `meta-director-self-audit-2026-05-19` (Observe stage, priority 20, safety_class: low, auto_spawned_at_turn: 100). Still waiting for an actionable Hypothesize trigger; T101 deferred this and T102 continues to defer per §B2 "Meta is INTERLEAVED, not parallel — physics arc takes precedence". After T102 closes the Tier-3 arc, **T103 should be the natural insertion point for the meta-investigation Hypothesize stage OR an audit-class-scan**.
  - `bug-4-itp-ddi-revalidation` closed Tier 2 (state.json line 3320) at T97 with F5 sandbox-deferred memo. Stable.
  - 6 prior Tier-3 closures (state.json lists; including in-flight one at T102 closing makes 6).
  - `fullbdg-f6-polar-3000x` dormant priority 99 (anko-contained).
- **Scheduler** (`runs/_loop/_local/scheduler_102.json` read this turn): `decision: "go"`, `policy: "JULIA_GPU_OK"`, `window_seconds_left: 1,121,358` (~13 days), probe VRAM 12,707 MB free, RAM 25.05 GB avail, GPU util 1%, foreign_julia 0. `implementer_julia_cpu_light` workload class permitted (line 20 of `allowed_workloads`). The recompute is ~30s warm-JIT julia (the existing script at scripts/diagnostic/ runs in 2.15s warm; first JIT in fresh process likely 2-3 min for SpinorBEC umbrella import). Document-stage text portion (memory entry + conclusions append + state.json patch text) is text-only and adds <500 tokens. Single combined turn fits comfortably.
- **Seed.md status**: dated 2026-05-15, references Julia parallel sweep long since complete. Per anko 2026-05-16 PROBE_DRIVEN clause, scheduler is authoritative. Implementer-julia-cpu-light is fully permitted; no julia-forbidden clause active.
- **Drift advisories on T101** (anticipated, not yet visible in state.json this turn read): CORROBORATE_WITH_ERRATA may or may not have triggered a `DRIFT_CORROBORATION_DOWNGRADE` advisory; not material to T102 decision. `DRIFT_MANUSCRIPT_DELTA_ZERO` (expected; manuscript not in scope). `AUDIT_DUE: gap` now at gap=13 by T102 read (acknowledged; deferred to T103 per arc-closure priority).
- **Meta interleave gap**: 6 consecutive physics turns at T101 → 7 at T102. After T102 closes the arc, **T103 MUST switch** to meta-director-self-audit Hypothesize OR audit-class-scan to honor §B2's "Meta is INTERLEAVED, not parallel" rule. Documented as `if_succeeds_next_step` below.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T99 | Hypothesize | PASS (20/20 criteria) | theorist 6×6 Nambu L(k) at F=1 polar + FM via CG-orthogonality (table C.0); proved $\Sigma^{HF}_{0,0}\|_{\rm polar} = 2 c_0 n$ algebraically; reproduces KU2012 phonon dispersions; F1/F2/F3 falsifiers formalized. |
| T100 | Execute | PASS (18/18 criteria, EXECUTE_PASS) | implementer_julia_cpu_light wrote 35-line `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`, ran in 2.15s warm. F1 rel_err 7.86e-6 vs 1e-3, F2 rel_err 8.74e-6 vs 1e-3, F3 abs_err 1.33e-15 vs 1e-12. 100x-750x margin on every falsifier. F4 Goldstone exact 0.0. Tier 1.5 -> 2.5. |
| T101 | Update | **CORROBORATE_WITH_ERRATA** | critic delivered Route I (GP-linearization) independent algebraic re-derivation reproducing polar+FM phonons + polar magnon (Tier-3.5 bonus); audit C1/C2/C3 all clean; **Deliverable B numerical recompute at fresh parameters delivered by symbolic substitution only** because the critic harness was Read-only and could not execute Julia. Tier 2.5 -> 2.75. Caveat is purely tooling-restriction, not scientific. Critic explicitly recommended T102 implementer-Julia to convert symbolic prediction to empirical measurement in ~30s. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1) — D1 Tier-3 verification of [Established] internal claim against KU2012 §4.2 / §5 external closed-forms.
- **Stage chosen for T102**: **Document** (with caveat-resolution prerequisite folded in). Per §F1 sequence Research -> Hypothesize -> Design -> Execute -> Update -> **Document** -> closed. T101 Update verdict was CORROBORATE_WITH_ERRATA which routes (per director T101 §6.failure_modes[1].next_action) to "dispatch implementer_text for Document stage with the caveat captured". But §A2 ("research-grounded value test, advance D1 verification") plus the critic's own §5 explicit recommendation ("recommended T102 action: implementer_text Document with the caveat captured as a Document-stage prerequisite — run the /tmp/ recompute script") combine to upgrade the workload class to `implementer_julia_cpu_light` (covers BOTH the /tmp/ Julia recompute AND the text-only Document deliverables). This is `feedback_mechanical_vs_investigation_threshold` applied: the Julia recompute is mechanical (3-second test: "predicted PASS at fresh parameters? confirm empirically with one parameter-override copy") and doesn't need its own Execute stage; it folds into Document.
- **Role per §F1 `role_per_stage["Document"]`**: per the template definition, Document is `implementer` (text-only by default). The upgrade to `implementer_julia_cpu_light` is justified by the caveat-resolution prerequisite: the Document stage's memory entry must accurately reflect the [Established] claim, and a 30s julia recompute converts "predicted PASS via symbolic substitution" to "PASS at empirical measurement", which strengthens the memory entry from Tier 2.75 to Tier 3.0. This is anko's mechanical-vs-investigation threshold pattern: the recompute is mechanical (~30 lines of script delta, predicted outcome, sub-1-minute Julia), it does not need a separate Execute turn.
- **Why this stage now (vs splitting into two turns)**:
  - **Splitting wastes a turn**: T102 implementer_text Document at tier 2.75 + T103 implementer_julia_cpu_light recompute to clear the caveat + T104 implementer_text Document-revision at tier 3.0 = 3 turns. T102 implementer_julia_cpu_light combined = 1 turn. The combined path is 3× cheaper for the same final state.
  - **Scope is well-bounded**: critic provided the exact parameter values, the script to copy, and the expected PASS thresholds. Implementer has no design discretion — they execute the recompute exactly as specified.
  - **Failure is contained**: if the empirical recompute FAILS (rel_err > 1e-3 or factor-2 ratio off), the Document closure still happens but tier stays at 2.75 with caveat documented as formal rather than tooling-restriction, and a fix-bug spawn is triggered for T103. The Document memory entry adapts to either outcome.
  - **Meta interleave**: T103 must switch to meta or audit per §B2; combining T102 lets T103 be a clean meta-investigation turn.
  - **AUDIT_DUE deferred again**: gap=13 by T102 reading. T103 audit at gap=14 still in cadence range. T102 combined-closure path frees T103 for meta or audit (director's choice based on T102 outcome).
  - **Template-shape match**: T86 edh-matsui Document closure was a single implementer turn combining empirical verification + memory entry + state.json patch (T86 director read this turn for precedent confirmation). Same pattern applies here.

## 4. Research grounding (§A6)

§A6 mandates ≥1 external reference for Hypothesize/Design stages. Document is a closure stage; §A6 not stringent, but I anchor to the relevant references to make the contract auditable:

1. **Kawaguchi-Ueda 2012 "Spinor Bose-Einstein condensates" Physics Reports 520, 253 [arXiv:1001.2072]** §4.2 / §5 — the external benchmark whose F=1 polar/FM phonon closed-forms T99-T100-T101 verified. T102 Document closure memorializes that this benchmark is reproduced by `hf_matrix_generic` + `channel_kernel` to relative tolerance 1e-3 in the small-k regime at two parameter sets (T100's c_0=1, c_1=±0.1 plus T102's empirical fresh-parameter recompute c_0=2, c_1=+0.05 and c_0=0.5, c_1=-0.2).
2. **T101 critic report §5 explicit recommendation** (read this turn): "Recommended T102 action: implementer_text Document with the caveat captured as a Document-stage prerequisite — run the /tmp/ recompute script (the brief in director/turn_101.md already specifies the exact parameters and command), confirm the three predicted PASS values empirically, then advance to tier 3.0 closure." T102 honors this recommendation literally.
3. **Memory `tier3_pipeline_survey_2026_05_18` §"5-candidate menu" item 5** — this investigation was the 5th-priority Tier-3 promotion candidate. T102 closure completes 5/5 of the survey menu trajectory (5/5 closed: #1 EdH-Matsui T86, #2 Bug-4 T97 at Tier 2 with F5-deferred, #3 Lemma 1 T94, #5 TDHFB Phase 2 T102; #4 TwoChannelLHY F=6 capped at Tier 2.5 due to NOT_FOUND benchmark).
4. **Prior loop turn T86 edh-matsui Document closure** — methodological template: single implementer turn combining empirical verification (Case A baseline GS rerun) + memory entry + conclusions index + state.json patch. T102 mirrors this shape.
5. **APC contract template cache**: `physics::verify-claim::Document` template (T59 klaus-bch, T86 edh-matsui, T94 lemma1) `n_seen: 3`. Cached skeleton: success_criteria include `memory_entry_committed`, `conclusions_appended`, `state_json_patched`, `tier_reached >= 3.0` (CORROBORATE branch) OR `tier_reached >= 2.75` (CORROBORATE_WITH_ERRATA caveat path). Failure modes shape: closure-time bugs (memory entry typo, conclusions duplicate) -> minor; production code touched -> operational; empirical recompute fails -> fix-bug spawn + tier stays 2.75. T102 adapts this skeleton with tdhfb-specific recompute as a folded-in Execute-class prerequisite.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. T102 closes the TDHFB Phase 2 generic-F HF kernel verification arc by (a) converting T101's symbolic-substitution prediction into an empirical measurement at fresh parameters, resolving the CORROBORATE_WITH_ERRATA tooling caveat, and (b) committing the Document closure artifacts (memory entry, conclusions index, state.json patch). Tier 2.75 -> 3.0 on empirical PASS; tier stays 2.75 on empirical FAIL (with adapted closure).
- **Tier ladder position**: 2.75 -> 3.0 on success. This becomes the 6th project Tier-3 closure (after barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, in-flight tdhfb at T102; bug-4 was Tier 2 only). 6 Tier-3 closures in 102 turns = 5.9% per-turn Tier-3 yield.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. T102 implementer writes ONLY: `runs/_loop/sim/turn_102.md` (per-turn report; even though this is a Document stage we follow the implementer sim/turn_N.md convention since `implementer_julia_cpu_light` is the workload class), the memory entry at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md`, the conclusions index append at `runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`, optionally MEMORY.md index line entry. No `docs/manuscript/`, no `src/`, no test file mods.
- **Cost frame for T102**: target **2.2M effective** (implementer_julia_cpu_light norm at T100 was 2.05M; T102 has slightly more text work but the julia portion is single-script ~30s warm or ~3 min cold so similar). HARD CAP **3.5M**. Cold-julia-JIT risk: SpinorBEC umbrella import in fresh process ~2-3 min; warm JIT (after recent `using SpinorBEC` sessions in T100) ~30s. The diagnostic script uses `SpinorBEC.hf_matrix_generic` + `SpinorBEC.channel_kernel` which were already loaded at T100 — but unless the same Julia process is still running, T102 is a cold JIT.
- **Drift trajectory after T102 (anticipated)**:
  - cost_inflation: ~1.0 if julia is warm; ~1.3 if cold (within normal).
  - code_delta_zero: 1.0 (no `src/` modification; the /tmp/ script lives outside the repo).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: variable (T102 is closure, no novel claim by design — just empirical confirmation of T101's prediction).
  - subagent_repetition: implementer gap since T100 = 2 turns (T101 was critic). Healthy.
  - topic_repetition: 5 consecutive turns on TDHFB (T98 researcher, T99 theorist, T100 implementer, T101 critic, T102 implementer). At the upper edge of acceptable. **T103 must switch off TDHFB** — meta or audit-class-scan are the natural picks.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
  "stage_advancing_to": "Document",
  "subagent_type": "implementer",
  "workload_class": "implementer_julia_cpu_light",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "rationale": "T101 critic verdict CORROBORATE_WITH_ERRATA (tier 2.75) had a single caveat: Deliverable B (numerical recompute at fresh parameter points) was delivered by symbolic substitution only because the critic harness was Read-only and could not execute Julia. The caveat is purely tooling-restriction, not scientific — the critic explicitly recommended in §5 that T102 dispatch an implementer with Julia capability to run the /tmp/ recompute script (~30s warm JIT) at the exact parameters and thresholds the T101 brief already specified, converting symbolic predictions into empirical measurements and clearing the tier to 3.0. T102 combines this caveat-resolution prerequisite with the Document closure (memory entry + conclusions append + state.json patch text) in a single implementer_julia_cpu_light turn. This is the mechanical-vs-investigation threshold pattern: ~30 lines of script delta with predicted PASS at well-defined thresholds is mechanical, does not need its own Execute stage. Scheduler JULIA_GPU_OK fully permits implementer_julia_cpu_light. Budget ~2.2M (T100 implementer norm). On empirical PASS: tier 2.75 -> 3.0 + Document artifacts committed + arc closes T98-T102 (5 turns). On empirical FAIL (rel_err > 1e-3 or factor-2 ratio off): tier stays at 2.75, Document closes with formal caveat instead of tooling caveat, fix-bug spawn triggered for T103. Either way the investigation closes at this turn.",
  "brief": "## ROLE\n\nYou are implementer (workload class: `implementer_julia_cpu_light`). T102 §F1 Document stage (with caveat-resolution prerequisite) of investigation `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. Your job has TWO parts in sequence: (Part 1, the caveat-resolution Julia recompute) write a /tmp/ parameter-override copy of the existing diagnostic script and run it under julia to convert T101's symbolic-substitution predictions into empirical measurements at two fresh parameter points; (Part 2, the Document closure) write the memory entry, append the conclusions index entry, and provide the state.json patch text. Tool access: Bash (julia, mv, cp, mkdir), Read, Write, Edit, Grep, Glob. You may modify only: the /tmp/ recompute script (outside repo), the memory file in `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/` (your home dir), the conclusions index file at `runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`, and your own report at `runs/_loop/sim/turn_102.md`. Do NOT modify: `src/`, `test/`, `runs/_loop/state.json` (write the patch text in your report; orchestrator commits), `runs/eu151_*/`, `.claude/`, `docs/`, the production diagnostic script `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`, MEMORY.md (you may suggest a 1-line index update in your report text; anko commits).\n\nDIRECTIVE_LABEL: tdhfb-phase2-tier3-T102-document-with-julia-recompute-caveat-resolve\n\nWrite final report to `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_102.md`.\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_102.md` ENTIRE (this report).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_101.md` ENTIRE — especially §3 (Deliverable B structure including the exact script algorithm to copy), §5 (recommended T102 action explicit), §6 (METRICS JSON predicted values), §7 (conclusions index append text — you will adapt this).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_101.md` §6 (Deliverable B specification with the exact two parameter points and shell invocation).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_100.md` §2 (verbatim script source) + §3 (the k-range and least-squares adaptations you must preserve).\n5. `/home/suzume/workspace/BEC-simulation/scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` ENTIRE (the production script you will copy and parameter-override; DO NOT MODIFY).\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md` (file exists; you will append to it).\n7. Two prior Document-stage precedents for memory-entry shape: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` (shape template) + (read by grep for `closing_note` patterns in state.json the T86, T94, T59 entries).\n\n## PART 1 — CAVEAT-RESOLUTION JULIA RECOMPUTE\n\n### P1.1 — Write the /tmp/ override script\n\nCopy `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` to `/tmp/tdhfb_f1_bogoliubov_T102_critic_recompute.jl`. Modify the parameter values at the three `bdg_omegas(...)` (or equivalent) call sites and the F3 call signature to use:\n\n- **Polar fresh point**: $c_0 = 2.0$, $c_1 = +0.05$, $n = 1.0$, $\\mu = c_0 n = 2.0$, $\\zeta = (0, 1, 0)$. Expected $c_s^{\\rm polar} = \\sqrt{2.0} \\approx 1.4142135623730951$.\n- **FM fresh point**: $c_0 = 0.5$, $c_1 = -0.2$, $n = 1.0$, $\\mu = (c_0 + c_1) n = 0.3$, $\\zeta = (1, 0, 0)$. Expected $c_s^{\\rm FM} = \\sqrt{0.3} \\approx 0.5477225575051661$.\n- **F3 ratio**: at the fresh polar point ($c_0=2.0$), expected $h_{\\rm bdg}[1,2,2] / h_{\\rm gp}[1,2,2] = 2.0$ exactly within machine epsilon ($\\le 10^{-12}$).\n\nKEEP the k-range $[10^{-3}, 10^{-2}]$ and the least-squares fit (NOT chord slope) that T100 §3 documented as the critical adaptation. KEEP `n_k = 10` log-spaced points.\n\nOutput format: the script MUST print a single JSON object to stdout with the following keys (so your report and the judge can parse cleanly):\n\n```\n{\n  \"recompute_polar_c0_2_c1_05_cs_measured\": <float>,\n  \"recompute_polar_c0_2_c1_05_cs_expected\": 1.4142135623730951,\n  \"recompute_polar_rel_error\": <float>,\n  \"recompute_polar_pass\": <bool; true if rel_error < 1e-3>,\n  \"recompute_fm_c0_05_cm1_02_cs_measured\": <float>,\n  \"recompute_fm_c0_05_cm1_02_cs_expected\": 0.5477225575051661,\n  \"recompute_fm_rel_error\": <float>,\n  \"recompute_fm_pass\": <bool; true if rel_error < 1e-3>,\n  \"recompute_factor_2_ratio_measured\": <float>,\n  \"recompute_factor_2_ratio_abs_error\": <float; |measured - 2.0|>,\n  \"recompute_factor_2_ratio_pass\": <bool; true if abs_error < 1e-12>,\n  \"all_recompute_falsifiers_passed\": <bool; AND of three>\n}\n```\n\n### P1.2 — Execute\n\nFrom `/home/suzume/workspace/BEC-simulation`:\n\n```bash\ntimeout 600 /home/suzume/.juliaup/bin/julia --project=. /tmp/tdhfb_f1_bogoliubov_T102_critic_recompute.jl 2>&1 | tee /tmp/tdhfb_T102_recompute.log\n```\n\nExpected wall-time: 30s if julia process from T100 is still warm-JIT'd; 2-3 min cold JIT (fresh SpinorBEC umbrella import). HARD CAP 600s. Capture the JSON output line from the log; that becomes part of your METRICS JSON in §6 of your report.\n\n### P1.3 — Verify\n\nThe three falsifier predictions from T101 §6 are: rel_err polar ~3e-6 to 1e-5 (PASS), rel_err FM ~1e-5 to 4e-5 (PASS), F3 ratio abs_err ~few ulps (PASS). Compare empirical measurements to predictions in your report §3. If the measurements PASS the same thresholds T100 used (rel_err < 1e-3 for both sound velocities, abs_err < 1e-12 for F3 ratio): caveat resolved, tier advances 2.75 -> 3.0. If any falsifier FAILS: caveat is formalized as a real scientific finding (rather than tooling restriction), tier stays at 2.75, fix-bug spawn for T103.\n\n## PART 2 — DOCUMENT CLOSURE\n\n### P2.1 — Memory entry\n\nWrite `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md` (~1 page).\n\nShape (mirror tier3_pipeline_survey_2026_05_18 + closure-style memory entries):\n\n```\n---\nname: tdhfb-phase2-generic-f-kernel-tier3-closure-2026-05-18\ndescription: \"<one-sentence summary of what was verified, by what method, with what result, citing T98-T102 arc>\"\nmetadata:\n  node_type: memory\n  type: project\n  originSessionId: <fresh UUID-style or leave as orchestrator-fills>\n---\n\n# TDHFB Phase 2 generic-F HF kernel Tier-3 closure 2026-05-18 (T98-T102)\n\n## [Established] (T102 PASS or T102 partial — adapt to empirical outcome)\n\nTDHFB Phase 2 generic-F HF kernel (`hf_matrix_generic` + un-symmetrized `channel_kernel` anomalous block, `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl` + `src/hamiltonian/tdhfb/channel_kernel.jl`) reproduces KU2012 §4.2 / §5 F=1 Bogoliubov dispersions at small k in 6x6 Nambu form L(k):\n\n- Polar phonon: omega^2 = epsilon_k(epsilon_k + 2 c_0 n) at polar GS zeta=(0,1,0), mu = c_0 n. T100 c_0=1.0: rel_err 7.86e-6. T102 c_0=2.0, c_1=+0.05: rel_err <measured>. PASS at both points.\n- FM phonon: omega^2 = epsilon_k(epsilon_k + 2(c_0+c_1) n) at FM GS zeta=(1,0,0), mu = (c_0+c_1) n. T100 c_0=1.0, c_1=-0.1: rel_err 8.74e-6. T102 c_0=0.5, c_1=-0.2 (|c_1/c_0|=0.4 ratio, 4x T100): rel_err <measured>. PASS at both points.\n- BdG/GP factor-2 ratio: hf_matrix_generic[1,2,2]|polar / hf_matrix_F1[1,2,2]|polar = 2.0 exactly within machine epsilon (abs_err < 1e-12). Structural — Bose-symmetrization in channel_kernel_symmetrized = 2V vs un-symmetrized V — not a kernel bug. Confirmed parameter-independent at T100 c_0=1.0 (1.33e-15) and T102 c_0=2.0 (<measured>).\n- Polar magnon (Tier-3.5 extension, Route I algebra by T101 critic, not numerically tested): omega^2 = epsilon_k(epsilon_k + 2 c_1 n) at polar GS (m=+1, m=-1) BdG block. Same kernel + anomalous block machinery produces this branch by construction.\n\n## Independent corroboration (T101 critic)\n\nRoute I (GP-linearization, KU2012 §5.1.2 preprint) independent derivation by T101 critic reproduces the polar phonon, FM phonon, AND polar magnon dispersions via the first-functional-derivative form (vs T99's second-functional-derivative + CG-orthogonality route). Factor-2 in `2 c_0 n` packed differently: T99 puts it in $\\Sigma^{HF}_{0,0}$ via $P = 2V$ Bose-symmetrization of the rank-4 projector; Route I puts it in `diagonal_Hartree + anomalous_Hartree` sum from chain rule of $|\\phi|^2\\phi$. Same algebraic value via structurally-different routes — strongest form of independent confirmation.\n\nAudit (T101): mu choice sound (GS-determined; F4 Goldstone gap = 0 exact confirms); k-grid finite-k correction matches predicted k^2 Taylor scaling within factor of 2 of leading $c_s k^2/(8 c_0 n)$; channel_kernel convention uniform across documented call sites.\n\n## Arc summary\n\n- T98 (researcher_shallow): KU2012 §4.2 + SKU2013 §IV + Uchino-Kobayashi-Ueda 2010 extracted; 6 falsifier candidates, 3 load-bearing.\n- T99 (theorist): 6x6 Nambu L(k) algebraic construction; convention pitfall (BdG vs GP factor 2) RESOLVED_NO_CORRECTION_NEEDED.\n- T100 (implementer_julia_cpu_light): 35-line diagnostic script; F1/F2/F3 PASS by 100x-750x margin; tier 1.5 -> 2.5.\n- T101 (critic): Route I independent re-derivation + audit C1/C2/C3 clean; tier 2.5 -> 2.75 (caveat: tooling-restriction on Deliverable B numerical recompute).\n- T102 (implementer_julia_cpu_light): caveat-resolution recompute at fresh parameters + Document closure; tier 2.75 -> 3.0 (or stays at 2.75 if empirical FAIL).\n\n## Context for production code\n\n`hf_matrix_generic` (`src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl`) is the channel-decomposed HF self-energy via CG coefficients for arbitrary F (per existing MEMORY.md TDHFB Phase 2 section). The factor 2 in self-pair diagonal entries comes from Bose symmetrization in `channel_kernel_symmetrized = 2V`. The companion `hf_matrix_F1` (`src/hamiltonian/tdhfb/hartree_fock_matrix.jl`) returns the GP Hamiltonian form (∂E/∂φ* / φ), which lacks the second self-pair factor — by design. Ratio 2.0 between the two at polar self-pair diagonal is structural and confirmed across two parameter points + algebraic re-derivation.\n\nFor production users: when using TDHFB Phase 2 generic-F kernel in Bogoliubov-mode (extracting excitation spectra), use `hf_matrix_generic` for the diagonal of L(k) AND `channel_kernel` (un-symmetrized V) for the anomalous Δ block. The two call sites must match the documented convention split.\n\n## Caveat (only if T102 empirical FAILS)\n\n<adapt this section based on Part 1 outcome; if PASS, delete this section>\n\n## Related entries\n\n- MEMORY.md `## TDHFB Phase 2 generic-F HF kernel (2026-05-11)` (now superseded — this entry is the Tier-3 closure)\n- `runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md` (full audit trail)\n- `scripts/manuscript/lemma1_general_S_verification.jl` (companion Tier-3 closure trajectory at T94)\n- Tier-3 pipeline survey: `tier3_pipeline_survey_2026_05_18.md` (this is 6th project Tier-3 closure)\n\n## References\n\n- Kawaguchi-Ueda 2012 [arXiv:1001.2072] §4.2 / §5 (external benchmark)\n- Stamper-Kurn & Ueda 2013 RMP 85, 1191 [arXiv:1205.1888] §IV.B.1 (independent textbook route)\n- T98-T102 loop turns: research/turn_98.md, theorist/turn_99.md, sim/turn_{100,102}.md, critic/turn_101.md, judge/turn_{100,101_critic_audit}.{json,md}.\n```\n\n### P2.2 — Conclusions index append\n\nAppend a `### T102 [Established]` entry to `/home/suzume/workspace/BEC-simulation/runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`. Use T101 critic §7 text as a starting template; adapt to T102 outcome (empirical PASS/FAIL). The append (not overwrite) is mandatory — preserve all prior entries.\n\n### P2.3 — state.json patch text in your report (do NOT modify state.json directly)\n\nIn your report §5, provide a JSON snippet with the precise field updates:\n\n```json\n{\n  \"investigations\": {\n    \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\": {\n      \"current_stage\": \"closed\",\n      \"tier_current\": <3.0 on empirical PASS | 2.75 on empirical FAIL>,\n      \"last_turn\": 102,\n      \"last_stage\": \"Document\",\n      \"last_verdict\": \"<TIER_3_CLOSURE_PASS | TIER_2_75_CLOSURE_WITH_CAVEAT>\",\n      \"closing_note\": \"<exactly the same shape as bug-4 entry's closing_note field; 1-3 sentences summarizing the arc T98-T102, the verification method, and any caveat>\",\n      \"next_stage\": null,\n      \"next_stage_action\": null,\n      \"falsifiers\": [\n        {\"id\": \"F1-polar-phonon-sound-velocity\", \"tested_at_turn\": <100 + 102>, \"result\": \"<CONFIRMED at c_0=1.0 T100 + CONFIRMED at c_0=2.0 T102 OR adapted>\"},\n        {\"id\": \"F2-fm-phonon-sound-velocity\", \"tested_at_turn\": <100 + 102>, \"result\": \"<CONFIRMED at c_0=1.0,c_1=-0.1 T100 + CONFIRMED at c_0=0.5,c_1=-0.2 T102 OR adapted>\"},\n        {\"id\": \"F3-bdg-vs-gp-factor-2-ratio\", \"tested_at_turn\": <100 + 102>, \"result\": \"<CONFIRMED parameter-independent T100 c_0=1.0 + T102 c_0=2.0 OR adapted>\"}\n      ]\n    }\n  }\n}\n```\n\nOrchestrator applies this patch post-turn.\n\n### P2.4 — MEMORY.md index suggestion (in your report only, anko commits)\n\nSuggest a 1-line index entry to add to MEMORY.md under the existing `## TDHFB Phase 2 generic-F HF kernel (2026-05-11)` section (or as a new section right after it):\n\n```\n## TDHFB Phase 2 F=1 Bogoliubov Tier-3 closure (2026-05-18, T98-T102)\n- [TDHFB Phase 2 F=1 Bogoliubov Tier-3](tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md) — `hf_matrix_generic` + un-symmetrized `channel_kernel` reproduces KU2012 F=1 polar phonon omega^2=epsilon_k(epsilon_k+2c_0 n), FM phonon omega^2=epsilon_k(epsilon_k+2(c_0+c_1) n), and BdG/GP factor-2 ratio = 2.0 at two parameter points each (T100: c_0=1; T102: c_0=2/0.5 fresh). T101 critic Route I (GP linearization) independent re-derivation. 6th project Tier-3 closure.\n```\n\nDo NOT modify MEMORY.md yourself; the instruction is text in your report only.\n\n## DELIVERABLES SUMMARY\n\n1. `/tmp/tdhfb_f1_bogoliubov_T102_critic_recompute.jl` — script (outside repo)\n2. `/tmp/tdhfb_T102_recompute.log` — execution log (outside repo)\n3. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md` — memory entry\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md` — appended T102 [Established] entry\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_102.md` — implementer report with all results, the state.json patch text, MEMORY.md index suggestion, and METRICS JSON\n\nSections of `sim/turn_102.md` (mirror prior sim reports):\n- §0 Directive received\n- §1 Pre-task context (T101 critic verdict, caveat nature, /tmp/ recompute strategy)\n- §2 Part 1 — /tmp/ script source (full text) + diff vs production script (just the parameter-override lines)\n- §3 Part 1 — Execution log + JSON output parse + comparison to T101 predictions\n- §4 Part 2 — Memory entry text (full, ready for Write)\n- §5 Part 2 — Conclusions append text + state.json patch text + MEMORY.md index suggestion\n- §6 METRICS JSON (per schema below)\n- §7 Limitations / open advisories (e.g., polar magnon not numerically tested; cold-JIT cost if applicable)\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"document_with_recompute_prerequisite\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\",\n  \"stage_advancing_to\": \"Document\",\n  \"flow_template\": \"verify-claim\",\n  \"tmp_script_written\": <bool>,\n  \"tmp_script_path\": \"/tmp/tdhfb_f1_bogoliubov_T102_critic_recompute.jl\",\n  \"julia_execution_wall_time_sec\": <float>,\n  \"julia_execution_returncode\": <int; 0 = success>,\n  \"recompute_polar_c0_2_c1_05_cs_measured\": <float>,\n  \"recompute_polar_c0_2_c1_05_cs_expected\": 1.4142135623730951,\n  \"recompute_polar_rel_error\": <float>,\n  \"recompute_polar_pass\": <bool>,\n  \"recompute_fm_c0_05_cm1_02_cs_measured\": <float>,\n  \"recompute_fm_c0_05_cm1_02_cs_expected\": 0.5477225575051661,\n  \"recompute_fm_rel_error\": <float>,\n  \"recompute_fm_pass\": <bool>,\n  \"recompute_factor_2_ratio_measured\": <float>,\n  \"recompute_factor_2_ratio_abs_error\": <float>,\n  \"recompute_factor_2_ratio_pass\": <bool>,\n  \"all_recompute_falsifiers_passed\": <bool>,\n  \"memory_entry_committed\": <bool; true if Write succeeded>,\n  \"memory_entry_path\": \"/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md\",\n  \"conclusions_appended\": <bool>,\n  \"state_json_patch_text_provided\": <bool>,\n  \"memory_md_index_suggestion_provided\": <bool>,\n  \"src_files_modified\": 0,\n  \"docs_modified\": 0,\n  \"manuscript_main_edited\": false,\n  \"production_script_modified\": false,\n  \"test_files_modified\": 0,\n  \"state_json_modified_directly\": false,\n  \"tier_reached\": <float; 3.0 if all_recompute_falsifiers_passed else 2.75>,\n  \"verdict\": \"<TIER_3_CLOSURE_PASS | TIER_2_75_CLOSURE_WITH_CAVEAT | DOCUMENT_OPERATIONAL_FAIL>\"\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`. Copy to /tmp/ first.\n- Do NOT modify `src/`. Production code stays untouched.\n- Do NOT modify `runs/_loop/state.json` directly. Write the patch text in your report; orchestrator commits.\n- Do NOT modify `MEMORY.md`. Write the index suggestion in your report; anko commits.\n- Do NOT write the memory entry in `/home/suzume/workspace/BEC-simulation/`. Memory files live in `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/`.\n- Do NOT polish the manuscript (`docs/manuscript/`). Out of scope per `feedback_manuscript_is_not_the_essence`.\n- Do NOT improvise terminology per `feedback_no_improvised_terminology`. Use: Bogoliubov-de Gennes (BdG), Gross-Pitaevskii (GP), Nambu space, anomalous block, phonon branch, magnon branch, polar phase, ferromagnetic (FM) phase, sound velocity, mean-field, BdG self-energy, GP Hamiltonian, Hartree-Fock kernel, Bose symmetrization, channel decomposition.\n- Do NOT skip Part 2 if Part 1 fails. On empirical FAIL, the Document closure still happens with adapted text (caveat formalized, tier stays at 2.75, fix-bug spawn flagged in your report).\n- English only. No emojis.\n- HARD CAP 3.5M effective tokens. Target 2.2M.\n- HARD CAP julia wall-time 600s; expected 30s warm or 2-3 min cold.\n- Do NOT commit (git commit) — orchestrator handles commits in the post-turn cycle.\n\n## SUCCESS DEFINITION\n\nT102 PASS = your report:\n\n1. /tmp/ script written with the two parameter points + F3 ratio at fresh polar; julia run succeeded (returncode 0; wall < 600s); JSON output parsed.\n2. All three falsifier predictions empirically PASS the same thresholds T100 used (recompute_polar_rel_error < 1e-3, recompute_fm_rel_error < 1e-3, recompute_factor_2_ratio_abs_error < 1e-12) — `all_recompute_falsifiers_passed == true` — OR Part 2 adapts to a graceful FAIL closure.\n3. Memory entry committed at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md`.\n4. Conclusions index appended (not overwritten) at `runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`.\n5. state.json patch text + MEMORY.md index suggestion provided in your report.\n6. METRICS JSON parses cleanly; verdict ∈ {TIER_3_CLOSURE_PASS, TIER_2_75_CLOSURE_WITH_CAVEAT, DOCUMENT_OPERATIONAL_FAIL}.\n7. No `src/`, `test/`, `runs/_loop/state.json`, `runs/eu151_*/`, `.claude/`, `docs/`, or production-script files modified.\n\nOn TIER_3_CLOSURE_PASS: tier 2.75 -> 3.0; T103 director switches to meta-director-self-audit Hypothesize OR audit-class-scan (gap=14) per `if_succeeds_next_step`.\nOn TIER_2_75_CLOSURE_WITH_CAVEAT (empirical recompute FAILS at fresh parameters): tier stays 2.75; closure documents the failure mode explicitly; T103 director spawns `tdhfb-generic-f-kernel-fresh-parameter-regression-T102` fix-bug investigation as priority 3.\nOn DOCUMENT_OPERATIONAL_FAIL (julia timeout, /tmp/ script bug, memory-write failure, etc.): tier preserved at 2.75; T103 director re-dispatches with corrected scope; arc T102 retries.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "tmp_script_written",
      "julia_execution_returncode",
      "recompute_polar_c0_2_c1_05_cs_measured",
      "recompute_polar_rel_error",
      "recompute_polar_pass",
      "recompute_fm_c0_05_cm1_02_cs_measured",
      "recompute_fm_rel_error",
      "recompute_fm_pass",
      "recompute_factor_2_ratio_measured",
      "recompute_factor_2_ratio_abs_error",
      "recompute_factor_2_ratio_pass",
      "all_recompute_falsifiers_passed",
      "memory_entry_committed",
      "conclusions_appended",
      "state_json_patch_text_provided",
      "src_files_modified",
      "production_script_modified",
      "state_json_modified_directly",
      "tier_reached",
      "verdict"
    ],
    "optional": [
      "julia_execution_wall_time_sec",
      "memory_md_index_suggestion_provided",
      "docs_modified",
      "manuscript_main_edited",
      "test_files_modified"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_102.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_101.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_101.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_100.md && test -f /home/suzume/workspace/BEC-simulation/scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md && test -d /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory && /home/suzume/.juliaup/bin/julia --version >/dev/null 2>&1 && python3 -c 'import json; d=json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); inv = d[\"investigations\"][\"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\"]; assert inv[\"tier_current\"] in (2.5, 2.75), f\"TIER_UNEXPECTED: expected 2.5 or 2.75 got {inv[\\\"tier_current\\\"]}\"; print(\"PRECONDITIONS_OK\")'"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "document_with_recompute_prerequisite",
      "rationale": "Document stage with caveat-resolution prerequisite folded in; not pure document_only."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
      "rationale": "Continuing investigation from T101."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Document",
      "rationale": "§F1 verify-claim sequence after Update; closure stage."
    },
    {
      "id": "tmp_script_written",
      "metric": "tmp_script_written",
      "operator": "==",
      "value": true,
      "rationale": "Caveat-resolution prerequisite Part 1 requires a /tmp/ override script copy."
    },
    {
      "id": "julia_completed",
      "metric": "julia_execution_returncode",
      "operator": "==",
      "value": 0,
      "rationale": "julia process must exit cleanly (no segfault, no timeout)."
    },
    {
      "id": "recompute_polar_passes",
      "metric": "recompute_polar_rel_error",
      "operator": "<=",
      "value": 1e-3,
      "rationale": "Polar fresh parameter point (c_0=2.0, c_1=+0.05, cs_expected=√2) must reproduce the same threshold T100 used."
    },
    {
      "id": "recompute_polar_pass_bool",
      "metric": "recompute_polar_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror of recompute_polar_rel_error threshold."
    },
    {
      "id": "recompute_fm_passes",
      "metric": "recompute_fm_rel_error",
      "operator": "<=",
      "value": 1e-3,
      "rationale": "FM fresh parameter point (c_0=0.5, c_1=-0.2, cs_expected=√0.3) must reproduce. Larger |c_1/c_0|=0.4 ratio is harder test."
    },
    {
      "id": "recompute_fm_pass_bool",
      "metric": "recompute_fm_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror."
    },
    {
      "id": "recompute_factor_2_passes",
      "metric": "recompute_factor_2_ratio_abs_error",
      "operator": "<=",
      "value": 1e-12,
      "rationale": "Parameter-independent factor 2 ratio at fresh polar c_0=2.0 must remain at 2.0 within fp precision."
    },
    {
      "id": "all_recompute_pass",
      "metric": "all_recompute_falsifiers_passed",
      "operator": "==",
      "value": true,
      "rationale": "AND of three recompute falsifiers — required for TIER_3_CLOSURE_PASS verdict; if false, routes to TIER_2_75_CLOSURE_WITH_CAVEAT (failure_mode branch handles)."
    },
    {
      "id": "memory_entry_committed",
      "metric": "memory_entry_committed",
      "operator": "==",
      "value": true,
      "rationale": "Document closure requires memory entry."
    },
    {
      "id": "conclusions_appended",
      "metric": "conclusions_appended",
      "operator": "==",
      "value": true,
      "rationale": "Conclusions index must record this closure."
    },
    {
      "id": "state_patch_text_provided",
      "metric": "state_json_patch_text_provided",
      "operator": "==",
      "value": true,
      "rationale": "Orchestrator needs the patch text to update state.json post-turn."
    },
    {
      "id": "no_src_modification",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Production code stays untouched during closure."
    },
    {
      "id": "no_production_script_modification",
      "metric": "production_script_modified",
      "operator": "==",
      "value": false,
      "rationale": "Recompute uses /tmp/ copy; production diagnostic script untouched."
    },
    {
      "id": "no_state_json_direct",
      "metric": "state_json_modified_directly",
      "operator": "==",
      "value": false,
      "rationale": "Implementer provides patch text; orchestrator commits."
    },
    {
      "id": "no_manuscript",
      "metric": "manuscript_main_edited",
      "operator": "==",
      "value": false,
      "rationale": "§A5 manuscript polish OUT."
    },
    {
      "id": "tier_advancement",
      "metric": "tier_reached",
      "operator": ">=",
      "value": 2.75,
      "rationale": "Floor: closure must at least preserve tier 2.75. Empirical PASS path bumps to 3.0; empirical FAIL path stays at 2.75."
    },
    {
      "id": "verdict_in_registered_set",
      "metric": "verdict",
      "operator": "in",
      "value": ["TIER_3_CLOSURE_PASS", "TIER_2_75_CLOSURE_WITH_CAVEAT", "DOCUMENT_OPERATIONAL_FAIL"],
      "rationale": "Verdict token must be one of the three registered states; each routes to specific T103 follow-up."
    }
  ],
  "failure_modes": [
    {
      "if": "verdict == 'TIER_3_CLOSURE_PASS' AND all_recompute_falsifiers_passed == true AND memory_entry_committed == true AND conclusions_appended == true",
      "category": "success_tier_3_closure",
      "next_action": "Tier 2.75 -> 3.0 confirmed. Investigation closes (current_stage: closed). Arc T98 -> T102 = 5 turns total. 6th project Tier-3 closure (after barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, in-flight Tier-3). T103 director switches off TDHFB topic — meta-director-self-audit-2026-05-19 (Observe -> Hypothesize, priority 20, auto-spawned at T100; honor the auto-spawn trigger now that the physics arc is complete) OR audit-class-scan (gap=14 by T103, within cadence). Director picks based on which has clearer trigger evidence in state.json T102 commit. Meta interleave §B2 mandate satisfied."
    },
    {
      "if": "verdict == 'TIER_2_75_CLOSURE_WITH_CAVEAT' OR all_recompute_falsifiers_passed == false",
      "category": "scientific_partial_with_recompute_regression",
      "next_action": "Empirical recompute at fresh parameters FAILS one or more falsifier thresholds despite T101 critic predicting PASS via symbolic substitution. This means the kernel has a parameter-conditioning bug not caught by T100's single parameter point OR T101's Route I algebra is incomplete. Tier stays 2.75 (Update verdict CORROBORATE_WITH_ERRATA preserved; the formal caveat now has empirical evidence rather than tooling-restriction reasoning). T103 director: (a) read T102 §3 to identify WHICH falsifier failed at WHAT magnitude; (b) spawn fix-bug investigation `tdhfb-generic-f-kernel-fresh-parameter-regression-T102-{specific-issue}` at priority 3; (c) dispatch theorist (NOT implementer) to algebraically diagnose the discrepancy — Route I gives a clean prediction so the disagreement isolates either an implementation bug OR an algebraic flaw in the symbolic prediction. Note: this is unlikely; T101 critic §3 showed the Route I formula is parameter-uniform under c_0 n / (c_0+c_1) n with no special parameter-tuning structure, so empirical FAIL would be surprising and informative."
    },
    {
      "if": "verdict == 'DOCUMENT_OPERATIONAL_FAIL' OR julia_execution_returncode != 0 OR memory_entry_committed == false OR src_files_modified > 0 OR state_json_modified_directly == true",
      "category": "operational",
      "next_action": "Implementer drifted from contract scope OR julia timed out OR /tmp/ script had a bug OR memory write failed. T103 director audits via git status + log inspection, reverts unintended changes, re-dispatches implementer_julia_cpu_light with corrected scope. Investigation tier preserved at 2.75 (no downgrade for operational issue alone). If julia timed out (cold JIT > 600s), use the longer timeout 1200s on retry; if /tmp/ script bug, fix it from your report's error message."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3500000,
    "wall_time_cap_sec": 1200,
    "wall_time_julia_only_sec": 600
  },
  "budget": {
    "expected_cost_eff": 2200000,
    "expected_wall_time_sec": 900,
    "split_by_subtask": {
      "read_context_director102_critic101_director101_sim100": 400000,
      "part1_write_tmp_script": 200000,
      "part1_julia_execution_and_parse": 200000,
      "part2_memory_entry_write": 600000,
      "part2_conclusions_append": 200000,
      "part2_state_patch_and_memory_md_suggestion_in_report": 200000,
      "implementer_report_with_metrics": 400000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_success_closing_note": "Tier-3 closure 2026-05-19 T102: implementer_julia_cpu_light combined caveat-resolution recompute (Part 1, /tmp/ script at fresh parameter points c_0=2.0 polar + c_0=0.5 FM) and Document closure (Part 2, memory entry + conclusions append + state.json patch text). Empirical PASS at all three falsifiers — polar phonon, FM phonon, BdG/GP factor-2 ratio — confirming T101 critic Route I symbolic-substitution predictions and resolving the CORROBORATE_WITH_ERRATA tooling caveat. KU2012 §4.2 / §5 F=1 Bogoliubov dispersions reproduced by `hf_matrix_generic` + `channel_kernel` at two parameter sets (T100 c_0=1, T102 c_0=2/0.5). 6th project Tier-3 closure. Arc T98 -> T102 = 5 turns total, approximately 11M cumulative.",
    "if_partial_advance_to_stage": "closed",
    "if_partial_tier_becomes": 2.75,
    "if_partial_closing_note": "Tier 2.75 closure 2026-05-19 T102: empirical recompute at fresh parameters FAILED one or more falsifier thresholds (see sim/turn_102.md §3 for specific failure mode). The T101 critic's CORROBORATE_WITH_ERRATA caveat is now formalized as a real scientific finding rather than tooling restriction. Fix-bug investigation `tdhfb-generic-f-kernel-fresh-parameter-regression-T102-...` spawned at T103.",
    "if_refuted_advance_to_stage": "fix-bug-spawned-side-investigation",
    "if_refuted_tier_becomes": 1.5,
    "if_novel_advance_to_stage": "Hypothesize-with-side-dispatch",
    "if_novel_tier_becomes": 2.5,
    "next_falsifier_to_test_after": "T103-meta-or-audit-class-scan; investigation closed at T102"
  },
  "if_succeeds_next_step": "T103 director SWITCHES off TDHFB topic (5 consecutive TDHFB turns + 1 closure at T102 = sufficient; topic_repetition threshold met). Two natural picks:\n- meta-director-self-audit-2026-05-19 Hypothesize (priority 20, Observe stage at T100 auto-spawn, safety_class: low). Per §B2 §F5 meta-improvement template: dispatch theorist for Hypothesize at the meta question 'has director pick-quality / tier-estimation-accuracy / waste-rate drifted? identify which axis if so'. Mandatory critic audit at Design stage per §F5 S3.\n- audit-class-scan (gap=14 by T103). Dispatch researcher to run patterns.yaml grep scans; mechanical findings batch-fixed in same turn per §F6 Triage stage.\nDirector chooses based on which has clearer evidence in T102 state.json commit: if a new drift advisory appears post-T102 commit indicating pick-quality concern, pick meta; if patterns.yaml has new candidate patterns from anko or auto-derivation, pick audit. In absence of either signal, default to meta (priority 20 honors the auto-spawn cleaner than letting audit go to gap=15 next turn).",
  "if_fails_next_step": "Three failure paths per §6.failure_modes:\n- TIER_2_75_CLOSURE_WITH_CAVEAT (empirical recompute fails fresh-parameter falsifier): tier stays 2.75; spawn fix-bug `tdhfb-generic-f-kernel-fresh-parameter-regression-T102-{specific}` at priority 3; dispatch theorist (NOT implementer) for algebraic diagnosis — Route I prediction is parameter-uniform so empirical FAIL is informative about implementation vs algebra. Tier of parent investigation closes at 2.75; child fix-bug investigation has its own tier_target=2.\n- DOCUMENT_OPERATIONAL_FAIL (julia timeout > 600s, /tmp/ script bug, memory-write failure, scope drift): re-dispatch implementer_julia_cpu_light with corrected scope; tier preserved at 2.75 (no downgrade for operational issue); investigation does not yet close. Adjust timeout to 1200s on retry if cold-JIT was the culprit.\n- If fix-bug spawn (path 1) reveals an implementation bug fixable in < 200 LOC, dispatch implementer_julia_cpu_light for the fix in T104; if it reveals an algebraic flaw in T101 critic Route I, dispatch theorist for re-derivation and revert tdhfb investigation to Update stage at tier 2.0.",
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read scheduler_102.json THIS turn (JULIA_GPU_OK, implementer_julia_cpu_light permitted, VRAM 12,707 MB free, RAM 25.05 GB avail, foreign_julia 0, window 13 days)
- [x] Read state.json relevant sections (lines 2127-2367 history T98-T101; lines 3332-3384 active investigation entry; line 3385+ meta-director-self-audit at Observe)
- [x] Read critic/turn_101.md ENTIRE (verdict CORROBORATE_WITH_ERRATA tier 2.75; §3 symbolic-substitution caveat; §5 explicit T102 recommendation)
- [x] Read judge/turn_101_critic_audit.md ENTIRE (same content as critic report — that file is the orchestrator-saved verbatim critic response)
- [x] Read prior director turn_101.md ENTIRE (consumed contract template + failure_modes structure)
- [x] Read sim/turn_100.md previously (implicitly via T101 director's quote of §3 adaptations)
- [x] Read theorist/turn_99.md previously (via T101 director's §1 quote of §C.0-C.6)
- [x] Read ≥1 memory file: tier3_pipeline_survey_2026_05_18 (T102 closure completes 5/5 menu items)
- [x] Verified observable_manifest precondition_check is concrete and runnable (test -f 6 paths + test -d memory dir + julia --version + python state.json field assertion with tier_current ∈ {2.5, 2.75})
- [x] investigation_id valid (line 3332 of state.json; tier_current 2.5 pre-T101-commit or 2.75 post-T101-commit)
- [x] stage_advancing_to = Document is §F1 next stage after Update
- [x] subagent_type = implementer with workload_class = implementer_julia_cpu_light matches §F1 role_per_stage[Document] (default implementer; upgrade to julia-capable per critic recommendation; scheduler permits)
- [x] researcher_depth = null (not researcher)
- [x] success_criteria machine-evaluable (20 criteria — all using ==/>=/<= or `in` operators against METRICS JSON fields; numerical thresholds match T100/T101 thresholds for consistency)
- [x] failure_modes cover SUCCESS (TIER_3_CLOSURE_PASS -> meta or audit at T103), PARTIAL (TIER_2_75_CLOSURE_WITH_CAVEAT -> fix-bug spawn + theorist for algebra), OPERATIONAL (DOCUMENT_OPERATIONAL_FAIL -> re-dispatch with longer timeout / corrected scope)
- [x] observable_manifest precondition_check tests 6 source files + memory dir + julia binary + state.json field flexibility (accepts tier 2.5 or 2.75 since orchestrator commit may or may not have landed)
- [x] budget fits within scheduler window_seconds_left (2.2M target / 3.5M cap, 900s wall / 1,121,358s window — trivially fits)
- [x] §A6 research-first citation present: KU2012 §4.2 / §5 (external benchmark anchor), T101 critic §5 (explicit T102 recommendation), tier3_pipeline_survey memory (5/5 closure tracking), T86 edh-matsui Document precedent (structural template), APC cache n_seen=3 for verify-claim::Document
- [x] §A5 D1 articulated: D1 verify Tier 2.75->3.0 (PRIMARY axis); manuscript NOT in scope
- [x] APC contract template cache: `physics::verify-claim::Document` n_seen=3 (T59 klaus-bch, T86 edh-matsui, T94 sign-pattern-lemma1); cached skeleton preserved (memory_entry + conclusions + state.json patch + tier closure); patched with tdhfb-specific recompute-prerequisite delta
- [x] No improvised terminology (BdG, GP, Nambu, phonon, magnon, polar/FM phase, anomalous block, sound velocity, Bose symmetrization, channel decomposition — all established physics terms)
- [x] No anko-attribution in implementer brief
- [x] Investigation update field: if_success -> closed + tier 3.0; if_partial -> closed + tier 2.75 (parent closes; child fix-bug investigation has its own tier_target=2); if_refuted -> not applicable at Document stage; closing_note populated for both PASS and PARTIAL paths
- [x] Cost frame: T102 expected 2.2M (T100 implementer norm 2.05M; slight bump for Document text work); HARD CAP 3.5M; cold-JIT risk acknowledged with 1200s wall-time fallback
- [x] AUDIT_DUE at gap=13 by T102 (gap=14 by T103) acknowledged; deferred again for arc-closure priority; T103 gets the audit-vs-meta choice
- [x] Meta interleave: 5 consecutive TDHFB turns T98-T101 + closure T102 = 6 total; T103 MUST switch per §B2; if_succeeds_next_step routes to meta-director-self-audit Hypothesize or audit-class-scan
- [x] subagent rotation: implementer gap = 2 turns since T100 (T101 was critic). Healthy.
- [x] active_investigation_id stale-field concern from T101 §1 acknowledged; orchestrator commits handle this
- [x] Seed.md staleness flagged in §1; scheduler authoritative per PROBE_DRIVEN clause; implementer_julia_cpu_light fully permitted
- [x] §A2 no-execution honored: director does not write the /tmp/ script body; brief specifies parameter values + JSON schema + invocation; implementer constructs the script
- [x] §A3 flow discipline: Document stage explicitly in §F1 verify-claim template; caveat-resolution prerequisite folded into Document is the mechanical-vs-investigation pattern not a new freeform stage
- [x] §A4 declarative contract: investigation_id, stage_advancing_to, subagent_type, success_criteria, failure_modes, observable_manifest, budget — all populated; rationale + brief cite specific evidence (critic/turn_101.md §5 recommendation, T100 thresholds, KU2012 anchor)
- [x] §A5 D1/D2/D3 articulated; D1 verify tier 2.75->3.0; D2/D3 not applicable; manuscript NOT in scope
- [x] §A6 research-first citation present (KU2012, T101 critic §5, tier3 survey memory, T86 precedent)
- [x] `feedback_manuscript_is_not_the_essence` honored: no manuscript polish; no docstring polish; D1 verification depth is the axis
- [x] `feedback_mechanical_vs_investigation_threshold` applied: ~30 lines of script delta + predicted PASS at well-defined thresholds = mechanical; folds into Document not separate Execute
- [x] `feedback_use_existing_artifacts_first` honored: T102 uses the existing diagnostic script (copy to /tmp/, override params) rather than writing from scratch
- [x] `feedback_no_improvised_terminology` honored throughout director report and implementer brief
- [x] `feedback_no_anko_attribution_in_prompts` honored: implementer brief states requirements directly without "per anko" citations
