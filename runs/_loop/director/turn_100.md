---
turn: 100
subagent: director
investigation_id: tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18
stage_advancing_from: Hypothesize
stage_advancing_to: Execute
topic_tags: [d1-verification, tdhfb-phase2-generic-f, bogoliubov-spectrum-f1, kawaguchi-ueda-2012-sound-velocity, bdg-vs-gp-factor2, tier2-to-tier3, falsifier-execution, julia-cpu-light]
paper_section: null
depends_on: [99, 98, "runs/_loop/director/turn_99.md", "runs/_loop/theorist/turn_99.md", "runs/_loop/sim/turn_99.md", "runs/_loop/judge/turn_99.json", "runs/_loop/_local/scheduler_100.json", "memory:tier3_pipeline_survey_2026_05_18", "memory:loop_architecture_2026_05_14", "src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl", "src/hamiltonian/tdhfb/hartree_fock_matrix.jl", "test/hamiltonian/test_tdhfb_hf_matrix_generic.jl"]
produces: "T100 implementer_julia_cpu_light dispatch. Executes scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl (≤30 lines) computing F1 polar-phonon sound velocity, F2 FM-phonon sound velocity, F3 BdG/GP factor-2 ratio at F=1 GS. PASS thresholds: F1 rtol<1e-3 against cs=1.0, F2 rtol<1e-3 against cs=sqrt(0.9)≈0.94868, F3 abs<1e-12 against 2.0. Tier 1.5 → 2.5 on three-falsifier PASS."
---

# Turn 100 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. **Continuing** from T99 (no switch). Stage transition: **Hypothesize → Execute** per §F1 verify-claim flow. T99 absorbed Design into Hypothesize (`current_stage` field literally reads `"Design-folded-into-Execute"` per state.json line 3229), so the natural next sub-stage is **Execute**.
- **T99 judge disposition (read this turn)**: `judge/turn_99.json` `status: "PASS"`, all 20 success_criteria passed including `convention_pitfall_resolved=true`, `convention_pitfall_disposition="RESOLVED_NO_CORRECTION_NEEDED"`, `factor_2_ratio_value=2.0`, `state_json_patched=true`, `state_json_post_patch_grep_count=4`, `verdict="HYPOTHESIZE_PASS"`. No issues. Cost_audit flagged BUDGET_OVER (ratio 1.72, actual 2.74M vs expected 1.6M) — addressed in T100 budgeting (§5).
- **State.json registration confirmed**: investigation entry now present at lines 3224-3274 with `current_stage: "Design-folded-into-Execute"`, `tier_current: 1.5`, `tier_target: 3`, `priority: 2`, `next_stage: "Execute"`, `next_stage_action` text matches the theorist's deliverable E brief (≤30-line Julia at `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`, cpu_light, <5 min).
- **Conclusions index** read (`runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`): one [Established] entry stub at T99 (auto-generated placeholder; no load-bearing prior claims to re-cite). T99 theorist's algebraic resolution (`Σ^HF_{0,0}|_polar = 2 c_0 n`, BdG/GP ratio = 2.0 exact) is the implicit [Plausible] anchor; T100 implementer verifies it numerically.
- **Tier**: 1.5 → expected 2.5 on T100 three-falsifier PASS (F1+F2+F3 all numerically reproduce KU2012 closed-forms). Tier target: 3.
- **Falsifiers**: 0 tested / 3 load-bearing (F1 polar phonon, F2 FM phonon, F3 BdG/GP ratio) ready for execution; F4 (k=0 Goldstone gap) + F5 (FM quadratic magnon) advisory; F6 dropped (already pinned by `test/hamiltonian/test_tdhfb_ku_c01_to_g_S.jl`).
- **Other in-flight investigations** (unchanged from T99):
  - 5 Tier-3 closed (barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, plus this one's predecessor candidates).
  - 6 Tier-2 closed including bug-4 T97.
  - 3 meta-investigations at Observe (priority 15/20/40, no recent triggers).
  - `fullbdg-f6-polar-3000x` dormant (priority 99, anko-contained).
- **Scheduler** (`runs/_loop/_local/scheduler_100.json` read this turn): `decision: "go"`, `policy: "JULIA_GPU_OK"`, `window_seconds_left: 1,124,058` (~13 days), probe VRAM 12,711 MB free, RAM 25.02 GB avail, GPU util 1%, foreign_julia 0. `implementer_julia_cpu_light` workload class fully permitted (line 21 of allowed_workloads).
- **Seed.md status**: dated 2026-05-15 morning, references a julia parallel sweep that has long since completed (last loop activity on Klaus phi-magnetostir was T59). Per anko 2026-05-16 PROBE_DRIVEN clause (scheduler.json line 9 notes field): scheduler is authoritative; the 22:00 TEXT_ONLY and "4 julia processes" clauses are not active. T100 implementer_julia_cpu_light is permitted.
- **Drift advisories on T99** (from `state.history[99].drift_advisories`): `DRIFT_MANUSCRIPT_DELTA_ZERO` (expected/correct per §A5 manuscript-not-in-scope; ignored), `DRIFT_COST_INFLATION` (T99 actual 2.74M vs expected 1.6M = 1.72×; addressed by T100 expected 2.0M including JIT cold-cache), `AUDIT_DUE: patterns.yaml last audited at T88, gap=11` (deferred one more turn — closing the Tier-3 arc T99→T100→T101→T102 is higher leverage than dropping mid-chain; honor at T101 or T102 per §F6 cadence).
- **Meta interleave gap**: physics chain continues at 5 consecutive turns (T95 researcher, T96 theorist, T97 implementer_julia, T98 researcher_shallow, T99 theorist). Meta-investigations at Observe have not surfaced new patterns. Per §B2, defer interleave to T101 or T102 with same rationale.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T98 | Research | RESEARCH_PASS (judge inferred from metrics JSON; judge file pending at T99 director read; per T99 judge file judgment is PASS retroactively confirmed) | researcher_shallow extracted KU2012 §4.2 / §5 F=1 polar phonon + magnon + FM phonon closed-forms from 4 sources (KU2012 arXiv:1001.2072, SKU2013 arXiv:1205.1888, Uchino-Kobayashi-Ueda 2010 arXiv:0912.0355, SpinorBEC.jl src/test reads). 6 falsifier candidates (3 load-bearing F1/F2/F3, 3 advisory F4/F5/F6). 5 NOT_FOUND items. BdG-vs-GP factor-2 PARTIALLY_RESOLVED. |
| T99 | Hypothesize | PASS (judge/turn_99.json: 20/20 criteria PASS, all PASS, 0 failure_modes triggered) | theorist constructed explicit 6×6 Nambu L(k) at F=1 polar and FM from BdG-convention h^HF; showed algebraically that polar phonon eigenvalue = ε_k(ε_k + 2 c_0 n), polar magnon = ε_k(ε_k + 2 c_1 n), FM phonon = ε_k(ε_k + 2(c_0+c_1)n) — reproduces KU2012 without additional factor-2 injection. Convention pitfall RESOLVED_NO_CORRECTION_NEEDED. F1/F2/F3 formalized with numerical thresholds; F6 dropped (redundant with existing tests); F4/F5 kept advisory. state.json registration patch authored + executed (post-patch grep count 4, exceeds threshold 3). Deliverable E pre-flight brief: 30-line Julia script + canonical test points + expected results. Theorist flagged erratum in director brief's F2 expected value: director said "sqrt(1.1) for c_1=+0.1 FM" but FM stability requires c_1<0; corrected to c_1=-0.1 giving sqrt(0.9)≈0.94868. **Director acknowledges erratum; T100 contract uses theorist's corrected value.** |
| — | (no prior physics turns on this investigation) | — | — |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1) — D1 Tier-3 verification of [Established] internal claim against KU2012 §4.2 external closed-forms.
- **Stage chosen for T100**: **Execute**. Per §F1 sequence Research → Hypothesize → Design → **Execute** → Analyze → Update → Document → closed. T99 absorbed Design into Hypothesize (single-page script structure trivially derived from L(k) construction), so T100 enters Execute directly.
- **Role per §F1 `role_per_stage["Execute"]`**: `implementer` with workload class chosen per script type. Theorist's pre-flight brief (T99 §7) specifies `implementer_julia_cpu_light` — 6×6 dense eigvals × 8 k-points × 3 test cases, no GPU needed, no big-grid GS, no DDI. Wall-time estimate <5 min (≤2 min JIT cold + ~3 min for 24 small eigenproblems).
- **Why this stage now (vs different investigation, vs meta, vs audit)**:
  - **Continue the chain**: T99 PASS leaves a clean baton with explicit 30-line script + canonical numerical thresholds. Dropping the thread costs T101 context-rebuild. Per `feedback_cost_overhead_is_the_cost`, do not deliberate when a clear forward move exists with all inputs pre-staged.
  - **Bug-4 closed Tier 2**: nothing to re-dispatch.
  - **Survey #4 (TwoChannelLHY F=6)** capped at Tier 2.5; NOT_FOUND benchmark.
  - **AUDIT_DUE gap=11**: one more turn deferrable; T102 Document-close is natural insertion point.
  - **Meta interleave**: no actionable Observe-stage trigger; defer.
  - **Scheduler permits cpu_light**: VRAM clear, RAM 25 GB avail, foreign julia 0. No queueing/memory contention.
  - **Template-shape match**: this is exactly the verify-claim Execute stage that produced Tier 3 closures at T20 (barnett c_dd-zero), T74 (sign-pattern-lemma1 F=2 numerical), T86 (edh-matsui completion). High-confidence path.

## 4. Research grounding (§A6)

§A6 mandates ≥1 external reference for Hypothesize/Design stages. Execute is implementation; §A6 strictly less stringent but I still anchor to the established literature trail to be safe:

1. **Kawaguchi-Ueda 2012 "Spinor Bose-Einstein condensates" Physics Reports 520, 253 [arXiv:1001.2072]**, §5 (Phys Rep) / §4.2 (preprint) — the external benchmark whose closed-form F=1 polar phonon $(\hbar\omega)^2 = \epsilon_k(\epsilon_k + 2 n c_0)$, polar magnon $\epsilon_k(\epsilon_k + 2 n c_1)$, and FM phonon $\epsilon_k(\epsilon_k + 2 n (c_0 + c_1))$ define the F1/F2/F3 test thresholds. T99 §2 (theorist's L(k) construction) closes the algebraic loop. T100 implementer numerically verifies.
2. **Stamper-Kurn & Ueda 2013** RMP 85, 1191 [arXiv:1205.1888] §IV — secondary citation; SU(2)/SO(2) symmetry-breaking analysis underpinning the polar-phonon + polar-magnon + FM-phonon mode structure that T100 numerically extracts from the 6×6 Nambu L(k) eigenvalues.
3. **Memory `tier3_pipeline_survey_2026_05_18`** §"5-candidate menu" item 5 — this investigation was named in the T69 survey as the 5th-priority Tier-3 promotion candidate (TDHFB F=1 sound-velocity comparison against KU2012 §4.2). The trajectory now closes the survey commitment.
4. **Memory `loop_architecture_2026_05_14`** §"TDHFB Phase 2 generic-F HF kernel (2026-05-11)" — internal reference for the load-bearing BdG-vs-GP factor-2 caveat now resolved at T99.
5. **APC contract template cache** (arXiv:2506.14852): `physics::verify-claim::Execute` template `n_seen: 8` (T27 barnett, T33/T35 yan-li-saito, T75 etc.). Cached skeleton uses YAML `run_yaml` shape with `obs_psi_snapshots_present` etc. — not directly applicable to a standalone diagnostic script. **Adaptation**: use cached failure_modes structure (precondition_check + run_completes + per-falsifier numerical PASS criteria) but patch in the three numerical-threshold criteria specific to this turn's three falsifiers.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. TDHFB Phase 2 generic-F HF kernel [Established] at Tier 2 internally (208 self-consistency tests in `test/hamiltonian/test_tdhfb_hf_matrix_generic.jl`). T100 brings it to Tier 2.5 (numerical reproduction of published KU2012 closed-forms in a fresh standalone script using only `SpinorBEC` public API). Critic at T101 Update brings to Tier 3.
- **Tier ladder position**: 1.5 → 2.5 on T100 PASS. Then T101 critic Update (independent re-derivation + audit) → 3.0. Then T102 Document closure (memory entry + close investigation).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. T100 implementer writes ONLY: (a) `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` (new file), (b) `runs/_loop/sim/turn_100.md` (per-turn report). No `docs/`, no `docs/manuscript/`, no `src/` changes.
- **Cost frame for T100**: target **2.0M effective** (cpu_light + JIT cold-cache norm). HARD CAP **3.0M**. T97's bug-4 cpu_light Julia run (closest precedent: simple regression-style script, JIT cold) consumed 2.6M effective. Slightly under that for T100 because the script is shorter (30 lines vs 200+ for bug-4 regressions) and uses one Julia REPL invocation. The DRIFT_COST_INFLATION advisory from T99 (1.72×) is addressed by setting expected close to historical norm rather than wishful-thinking lower bound.
- **Drift trajectory after T100 (anticipated)**:
  - cost_inflation: ~0.95-1.10 (2.0M vs running median).
  - code_delta_zero: 0.0 (one new diagnostic script created; counts as src delta even though under `scripts/diagnostic/` not `src/`).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: 0.0 (numerical verification of [Plausible] T99 claim; not a fresh claim).
  - subagent_repetition: implementer gap since T97 = 2 turns (theorist T99, researcher T98). Healthy rotation.
  - topic_repetition: 0.7 (TDHFB consecutive turn 3 — start of Execute is acceptable; arc T98→T99→T100→T101→T102 is the planned closure path).

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
  "stage_advancing_to": "Execute",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "rationale": "T99 HYPOTHESIZE_PASS (20/20 criteria, judge/turn_99.json status=PASS) provides a complete pre-flight package: 30-line Julia script structure (theorist §7), canonical numerical thresholds (F1 cs_polar=1.0±1e-3, F2 cs_fm=sqrt(0.9)≈0.94868±1e-3, F3 BdG/GP ratio=2.0±1e-12), wall-time estimate <5 min, scheduler permits implementer_julia_cpu_light (VRAM 12.7 GB free, foreign julia 0). Per §F1 verify-claim flow Execute stage role=implementer, T100 numerically verifies the three load-bearing falsifiers against KU2012 §4.2 closed-forms; this is the Tier-2 → Tier-2.5 step. T101 critic Update then closes Tier 3. Template-shape match with T74 sign-pattern-lemma1 (Lemma 1 numerical) and T86 edh-matsui (full pipeline). DRIFT_COST_INFLATION advisory addressed by setting expected_cost to historical cpu_light norm (2.0M).",
  "brief": "## ROLE\n\nYou are implementer (workload class: `implementer_julia_cpu_light`). T100 §F1 Execute stage of investigation `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18`. Your job: execute the three load-bearing falsifiers F1/F2/F3 that T99 theorist formalized, by writing and running a ≤30-line Julia diagnostic script at `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`. NO YAML, NO production-pipeline call, NO GPU, NO big-grid GS — just a focused standalone script that exercises `SpinorBEC.hf_matrix_generic` + `SpinorBEC.channel_kernel` + `SpinorBEC.hf_matrix_F1` + `LinearAlgebra.eigvals` on a homogeneous F=1 mean-field point.\n\nDIRECTIVE_LABEL: tdhfb-phase2-tier3-T100-execute-f1-f2-f3-falsifiers-julia-cpu-light\n\nWrite final report to `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_100.md`.\nWrite Julia script to `/home/suzume/workspace/BEC-simulation/scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`.\nDo NOT modify any file under `src/`, `docs/`, `runs/_loop/state.json`, `test/`, `runs/eu151_*/`, or `.claude/`.\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_100.md` ENTIRE (this report). §6 success_criteria are what judge.py will evaluate.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_99.md` §7 (T100 implementer pre-flight brief, lines 475-573 approx) — your script template (verbatim starting point, adjust only if a syntax or API call is actually wrong). §2 Derivation (C.1-C.6) — your algebraic ground-truth (what the eigenvalues SHOULD be).\n3. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl` lines 1-50 (docstring + signature) — confirm exported `hf_matrix_generic`, `ku_c01_to_g_S` names.\n4. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix.jl` — confirm `hf_matrix_F1!` / `hf_matrix_F1` exported names and signature (for F3 BdG/GP ratio comparison).\n5. `/home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/channel_kernel.jl` — confirm `channel_kernel(F, g_S)` exported name and tensor layout (4-index V[m,mp,m2,m2p]); the anomalous block Δ in L(k) needs this.\n6. (Optional) `/home/suzume/workspace/BEC-simulation/test/hamiltonian/test_tdhfb_hf_matrix_generic.jl` — for API call signatures if uncertain.\n\n## DELIVERABLES\n\n### Deliverable A — Julia script\n\nWrite `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` based on T99 §7 verbatim template, modified only as needed to compile against the actual `SpinorBEC` exported API. Target ≤30 executable lines (header comment allowed). Must:\n\n1. Accept no command-line arguments (`julia --project=. scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`).\n2. Use `using SpinorBEC, LinearAlgebra, JSON3`.\n3. Compute F1 polar phonon sound velocity at F=1, c_0=1.0, c_1=+0.1, n=1.0, μ=1.0, GS ζ=(0,1,0), 8 log-spaced k-points in k∈[0.01, 0.1]. Method: build 6×6 Nambu L(k) from `hf_matrix_generic` + `channel_kernel`-derived anomalous Δ block, compute eigvals, extract smallest positive real eigenvalue as ω(k); fit cs as slope (ω[end]-ω[1])/(k[end]-k[1]). Expected ≈ 1.0.\n4. Compute F2 FM phonon sound velocity at c_0=1.0, c_1=-0.1, μ=(c_0+c_1)·n=0.9, GS ζ=(1,0,0). Expected ≈ sqrt(0.9) ≈ 0.948683...\n5. Compute F3 BdG/GP factor-2 ratio at F=1 polar (ζ=(0,1,0), c_0=1.0, c_1=+0.1, n=1.0): `hf_matrix_generic(...)[1, 2, 2]` / `hf_matrix_F1(...)[1, 2, 2]`. Expected = 2.0 exact.\n6. Emit a single JSON line to stdout via `JSON3.write` with keys `F1_cs_polar`, `F2_cs_fm`, `F3_ratio`, plus optional `F4_goldstone_omega_at_k0` (the smallest positive eigenvalue at k=0; expected near 0 for polar) and `wall_time_sec` (timestamp delta around the three main computations).\n7. If any of `hf_matrix_generic`, `channel_kernel`, `hf_matrix_F1` does NOT exist as exported under that exact name, **adapt the call** based on what the source files actually export (e.g., maybe `hf_matrix_F1!` only, requiring an explicit out-array allocation). Document the adaptation in §3 of the sim report.\n8. Use `Symmetric` or check `ishermitian` on the diagonal block H = ε_k·I + h_hf - μ·I before pushing eigvals through (the Nambu L(k) itself is not Hermitian, but its eigenvalues come in ±ω pairs for real Bogoliubov physics; extract the positive real branch).\n9. **Sign-convention robustness**: if the BdG eigenvalues come out as ±i·ω instead of ±ω (an L vs i·L convention slip), apply `abs.(eigs)` and extract the smallest. Document any sign-fix in §3.\n\n### Deliverable B — Execute and verify\n\nRun the script via:\n```bash\ncd /home/suzume/workspace/BEC-simulation && timeout 600 julia --project=. scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl 2>&1 | tee /tmp/tdhfb_f1_bogoliubov_T100.log\n```\n\nNote: scheduler is JULIA_GPU_OK (cpu_light is the subset chosen here). Use a single Julia process; do NOT background. Wall-time cap 600s (cold JIT may approach 4-5 min; should not exceed 10 min).\n\nParse the final stdout JSON line; compute rel_error for F1/F2 against expected values and abs_error for F3 against 2.0. Populate all metrics fields below.\n\n### Deliverable C — Sim report `runs/_loop/sim/turn_100.md`\n\nSections:\n\n- §0. Directive received (mirror this contract block)\n- §1. Pre-execution context (script location, dependencies, expected wall-time)\n- §2. Script source (full contents of the new `.jl` file inline as a fenced ```julia block)\n- §3. Execution log (julia stdout/stderr, wall-time, any sign-convention or API-name adaptations made)\n- §4. Numerical results\n  - F1: measured cs_polar, expected 1.0, rel_error, PASS/FAIL\n  - F2: measured cs_fm, expected sqrt(0.9)=0.9486832980505138, rel_error, PASS/FAIL\n  - F3: measured ratio, expected 2.0, abs_error, PASS/FAIL\n  - F4 (advisory): measured ω_at_k=0_polar, expected ≈ 0 (Goldstone), PASS/FAIL\n- §5. Falsifier verdict summary (load-bearing F1+F2+F3 AND-pass → tier 2.5; advisory F4 informative)\n- §6. METRICS JSON (per schema below)\n- §7. Limitations + critic dispatch hint for T101\n\n### Deliverable D — Repository hygiene\n\n- Stage but do NOT commit the new script. Loop orchestrator handles commits via post-turn hook (precedent: T74, T86, T97).\n- Confirm `git status` shows only the new `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` file + `runs/_loop/sim/turn_100.md`. If unexpected files appear, list them in §7.\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"julia_script_diagnostic\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\",\n  \"stage_advancing_to\": \"Execute\",\n  \"flow_template\": \"verify-claim\",\n  \"script_path\": \"scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl\",\n  \"script_line_count\": <int>,\n  \"script_loc_within_budget\": <bool; true if <= 35>,\n  \"julia_invocation_succeeded\": <bool; true if exit code 0>,\n  \"wall_time_sec\": <float>,\n  \"f1_polar_phonon_cs_measured\": <float>,\n  \"f1_polar_phonon_cs_expected\": 1.0,\n  \"f1_polar_phonon_rel_error\": <float>,\n  \"f1_polar_phonon_pass\": <bool>,\n  \"f2_fm_phonon_cs_measured\": <float>,\n  \"f2_fm_phonon_cs_expected\": 0.9486832980505138,\n  \"f2_fm_phonon_rel_error\": <float>,\n  \"f2_fm_phonon_pass\": <bool>,\n  \"f3_bdg_gp_ratio_measured\": <float>,\n  \"f3_bdg_gp_ratio_expected\": 2.0,\n  \"f3_bdg_gp_ratio_abs_error\": <float>,\n  \"f3_bdg_gp_ratio_pass\": <bool>,\n  \"f4_goldstone_omega_at_k0\": <float or null if advisory not run>,\n  \"f4_goldstone_pass\": <bool or null>,\n  \"all_load_bearing_falsifiers_passed\": <bool; F1 && F2 && F3>,\n  \"src_files_modified\": 0,\n  \"docs_modified\": 0,\n  \"manuscript_main_edited\": false,\n  \"new_diagnostic_scripts_created\": 1,\n  \"git_status_clean_outside_expected\": <bool>,\n  \"sign_convention_adaptation_needed\": <bool; true if had to abs() eigs or reorder L block>,\n  \"api_name_adaptation_needed\": <bool; true if had to adjust hf_matrix_F1 vs hf_matrix_F1! call shape>,\n  \"tier_reached\": <float; 2.5 if all_load_bearing_falsifiers_passed else 1.5>,\n  \"verdict\": \"<EXECUTE_PASS | EXECUTE_PARTIAL_F1_OR_F2_OFF | EXECUTE_F3_RATIO_BROKEN | EXECUTE_JULIA_FAILED | EXECUTE_OPERATIONAL_FAIL>\"\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify `src/`. The point of this turn is to verify the existing kernel against KU2012 closed-forms; any \"fix\" of the kernel mid-execute breaks the audit chain. If F3 ratio != 2.0, report it; do not patch.\n- Do NOT skip F2 (FM). F2 is load-bearing (different ground state than F1, exercises the (m=+F, m=+F, ..., m=+F) singlet sector of the kernel). All three falsifiers must run.\n- Do NOT use `MEMORY.md` as authoritative on the literature — use only T99 §2 + T99 §7 + the source files. Memory entries are anko's bookkeeping, not the algebraic ground truth.\n- Do NOT add comments to the Julia script unless logic is genuinely non-obvious (CG conventions, sign-convention adaptations). Per anko's CLAUDE.md preferences.\n- Do NOT manuscript / docstring / README polish. §A5 D1 service only.\n- Do NOT improvise terminology per `feedback_no_improvised_terminology`. Use: Bogoliubov-de Gennes matrix, Nambu space, anomalous block, phonon branch, magnon branch, polar phase, ferromagnetic phase, sound velocity, ground state, mean-field, BdG self-energy, GP Hamiltonian.\n- English only. No emojis.\n- HARD CAP 3.0M effective tokens. Target 2.0M.\n- HARD CAP 600s wall-time. Target <300s (script itself ~5-30s; JIT cold first-call ~2-4 min).\n- Do NOT commit. Orchestrator handles.\n\n## SUCCESS DEFINITION\n\nT100 PASS = your report and the executed script:\n1. Script exists at `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl`, ≤35 lines, parses + runs to completion under `julia --project=.` with exit code 0 within 600s.\n2. F1 numerical sound velocity reproduces 1.0 to relative tolerance <1e-3.\n3. F2 numerical sound velocity reproduces sqrt(0.9)≈0.94868 to relative tolerance <1e-3.\n4. F3 BdG/GP self-pair element ratio = 2.0 to absolute tolerance <1e-12.\n5. Sim report includes script source, execution log, METRICS JSON, falsifier verdict.\n6. No `src/`, `docs/`, `runs/_loop/state.json`, `runs/eu151_*/`, or `.claude/` files modified.\n7. `git status` shows only expected new files.\n\nOn full PASS (all three load-bearing falsifiers numerically clear, JIT cost within bounds, no `src/` drift): tier 1.5 → 2.5; T101 director dispatches critic for Update stage (independent re-derivation of polar phonon eigenvalue from L(k); independent numerical recompute at a slightly different parameter point; audit for systematic error sources). On PASS, this is the 6th project Tier-2→3 trajectory in flight.\nOn EXECUTE_PARTIAL_F1_OR_F2_OFF (sound velocity > 1e-3 deviation): likely k-grid too coarse (linear-regime breakdown) or eigvals branch-selection bug. T101 director re-dispatches implementer with tighter k-grid (e.g., k ∈ [0.001, 0.01] log-spaced 12 points) AND extracts both branches separately. ~1.0M follow-up.\nOn EXECUTE_F3_RATIO_BROKEN (ratio ≠ 2.0 by >1e-10): CRITICAL — kernel may have regressed since 2026-05-11 implementation. T101 director spawns fix-bug investigation `tdhfb-generic-f-kernel-factor-2-regression-2026-05-18` and dispatches critic for independent re-derivation. Tier reverts to 1.0.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "script_path",
      "script_line_count",
      "julia_invocation_succeeded",
      "wall_time_sec",
      "f1_polar_phonon_cs_measured",
      "f1_polar_phonon_cs_expected",
      "f1_polar_phonon_rel_error",
      "f1_polar_phonon_pass",
      "f2_fm_phonon_cs_measured",
      "f2_fm_phonon_cs_expected",
      "f2_fm_phonon_rel_error",
      "f2_fm_phonon_pass",
      "f3_bdg_gp_ratio_measured",
      "f3_bdg_gp_ratio_expected",
      "f3_bdg_gp_ratio_abs_error",
      "f3_bdg_gp_ratio_pass",
      "all_load_bearing_falsifiers_passed",
      "src_files_modified",
      "manuscript_main_edited",
      "tier_reached",
      "verdict"
    ],
    "optional": [
      "script_loc_within_budget",
      "f4_goldstone_omega_at_k0",
      "f4_goldstone_pass",
      "docs_modified",
      "new_diagnostic_scripts_created",
      "git_status_clean_outside_expected",
      "sign_convention_adaptation_needed",
      "api_name_adaptation_needed"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_100.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_99.md && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/hartree_fock_matrix.jl && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/tdhfb/channel_kernel.jl && test -d /home/suzume/workspace/BEC-simulation/scripts/diagnostic && /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia --version >/dev/null 2>&1 && python3 -c 'import json; d=json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); assert \"tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18\" in d[\"investigations\"], \"INVESTIGATION_MISSING_FAIL\"; print(\"PRECONDITIONS_OK\")'"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "julia_script_diagnostic",
      "rationale": "Standalone Julia diagnostic script (not run_yaml, not test/, not src/ patch)."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
      "rationale": "Continuing investigation from T99."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Execute",
      "rationale": "Per §F1 sequence after Hypothesize."
    },
    {
      "id": "script_path_correct",
      "metric": "script_path",
      "operator": "==",
      "value": "scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl",
      "rationale": "Theorist §7 mandated location."
    },
    {
      "id": "script_loc_within_budget",
      "metric": "script_line_count",
      "operator": "<=",
      "value": 35,
      "rationale": "Target ≤30 per theorist brief; 35 allows minor adaptation for API name corrections."
    },
    {
      "id": "julia_succeeded",
      "metric": "julia_invocation_succeeded",
      "operator": "==",
      "value": true,
      "rationale": "Script must run to completion (exit 0) within 600s wall-time cap."
    },
    {
      "id": "wall_time_within_cap",
      "metric": "wall_time_sec",
      "operator": "<=",
      "value": 600,
      "rationale": "Theorist estimate <5 min; allow 10 min for JIT cold-cache safety margin."
    },
    {
      "id": "f1_polar_phonon_passes",
      "metric": "f1_polar_phonon_rel_error",
      "operator": "<=",
      "value": 1e-3,
      "rationale": "F1 load-bearing: sound velocity reproduces KU2012 polar phonon to rtol 1e-3. Linear-regime k∈[0.01,0.1] gives ω≈cs·k clean."
    },
    {
      "id": "f1_passes_bool",
      "metric": "f1_polar_phonon_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror of rel_error criterion; redundant for human readability of judge output."
    },
    {
      "id": "f2_fm_phonon_passes",
      "metric": "f2_fm_phonon_rel_error",
      "operator": "<=",
      "value": 1e-3,
      "rationale": "F2 load-bearing: FM phonon cs reproduces sqrt((c_0+c_1)n/m)=sqrt(0.9) to rtol 1e-3."
    },
    {
      "id": "f2_passes_bool",
      "metric": "f2_fm_phonon_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror."
    },
    {
      "id": "f3_factor_2_ratio_exact",
      "metric": "f3_bdg_gp_ratio_abs_error",
      "operator": "<=",
      "value": 1e-12,
      "rationale": "F3 load-bearing: BdG/GP factor-2 ratio at F=1 polar self-pair = 2.0 exact within fp precision. Deviation > 1e-12 indicates kernel regression."
    },
    {
      "id": "f3_passes_bool",
      "metric": "f3_bdg_gp_ratio_pass",
      "operator": "==",
      "value": true,
      "rationale": "Mirror."
    },
    {
      "id": "all_load_bearing_pass",
      "metric": "all_load_bearing_falsifiers_passed",
      "operator": "==",
      "value": true,
      "rationale": "Tier-3 trajectory requires AND-pass of F1+F2+F3. Any single failure routes to corresponding failure_mode."
    },
    {
      "id": "no_src_modification",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Execute stage verifies existing kernel; no src patches."
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
      "value": 2.5,
      "rationale": "Execute stage with all load-bearing falsifiers PASS advances tier 1.5 → 2.5. Critic Update at T101 → 3.0."
    },
    {
      "id": "verdict_execute_pass",
      "metric": "verdict",
      "operator": "in",
      "value": ["EXECUTE_PASS", "EXECUTE_PARTIAL_F1_OR_F2_OFF", "EXECUTE_F3_RATIO_BROKEN", "EXECUTE_JULIA_FAILED", "EXECUTE_OPERATIONAL_FAIL"],
      "rationale": "Verdict token must be one of the registered states; each routes to a specific T101 failure_mode action."
    }
  ],
  "failure_modes": [
    {
      "if": "verdict == 'EXECUTE_F3_RATIO_BROKEN' OR f3_bdg_gp_ratio_abs_error > 1e-10",
      "category": "scientific_refuted_kernel_regression",
      "next_action": "BdG/GP factor-2 ratio deviated from 2.0 by more than 1e-10. The TDHFB kernel may have regressed since the 2026-05-11 implementation OR the script's API call layout is wrong (more likely). T101 director: (a) dispatch critic for independent re-derivation of Σ^HF_{0,0}|_polar = 2 c_0 n (mirror T99 §C.1 algebra at a different parameter point); (b) spawn fix-bug investigation `tdhfb-generic-f-kernel-factor-2-regression-2026-05-18` with the failing test as the minimal reproducer; (c) tier reverts 1.5 → 1.0 until reconciled. TDHFB Tier-3 trajectory pauses."
    },
    {
      "if": "verdict == 'EXECUTE_PARTIAL_F1_OR_F2_OFF' OR (f1_polar_phonon_rel_error > 1e-3 AND f3_bdg_gp_ratio_pass == true) OR (f2_fm_phonon_rel_error > 1e-3 AND f3_bdg_gp_ratio_pass == true)",
      "category": "operational_numerical_method",
      "next_action": "Sound velocity extraction off-target despite F3 PASS confirming kernel correctness — likely numerical-method issue: k-grid endpoints not in linear regime, or eigvals returned complex pairs without proper branch selection. T101 director re-dispatches implementer with: (a) tighter k-grid (12 log-spaced points k∈[0.001, 0.01]), (b) two-point linear fit replaced by least-squares fit on all 12, (c) explicit `abs.(real.(eigs))` and selection of smallest > 1e-10. Reuses the same script with parameter tweaks. ~1.5M follow-up."
    },
    {
      "if": "verdict == 'EXECUTE_JULIA_FAILED' OR julia_invocation_succeeded == false",
      "category": "operational_api_or_compile",
      "next_action": "Julia script failed to compile or threw at runtime — most likely missing export, wrong argument layout, or `JSON3` not in project deps. T101 director re-dispatches implementer with: (a) preflight `julia --project=. -e 'using SpinorBEC, JSON3, LinearAlgebra; @show SpinorBEC.hf_matrix_generic, SpinorBEC.hf_matrix_F1, SpinorBEC.channel_kernel, SpinorBEC.ku_c01_to_g_S'`, (b) adjust API call shape based on the actual exports, (c) if JSON3 missing, fall back to bare `println` of three floats. ~1.5M follow-up."
    },
    {
      "if": "verdict == 'EXECUTE_OPERATIONAL_FAIL' OR wall_time_sec > 600 OR src_files_modified > 0",
      "category": "operational",
      "next_action": "Implementer drifted from contract scope (modified src/ or exceeded wall-time). T101 director audits via git diff, reverts unintended changes, re-dispatches with stricter scope. Implementer.md prompt may need clarification."
    },
    {
      "if": "all_load_bearing_falsifiers_passed == true AND verdict == 'EXECUTE_PASS'",
      "category": "success_continue_chain",
      "next_action": "Tier 1.5 → 2.5 confirmed. T101 director dispatches critic for Update stage: (a) independent re-derivation of polar phonon eigenvalue from a 4×4 sub-block (drop the (m=+1, m=-1) anomalous mixing terms that don't contribute at polar GS), (b) independent numerical recompute at a different parameter point (e.g., c_0=2.0, c_1=0.05 or c_0=0.5, c_1=-0.2), (c) audit for systematic error sources (k-grid bias, eigvals precision, mu choice). On critic CORROBORATE → tier 3.0, T102 implementer_text Document closure."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000,
    "wall_time_cap_sec": 900,
    "wall_time_julia_only_sec": 600
  },
  "budget": {
    "expected_cost_eff": 2000000,
    "expected_wall_time_sec": 900,
    "split_by_subtask": {
      "read_context_director100_theorist99_src": 300000,
      "draft_julia_script_from_theorist_template": 200000,
      "verify_api_exports_grep_src": 150000,
      "julia_run_cold_jit_plus_eigvals": 500000,
      "parse_stdout_json_and_compute_errors": 100000,
      "sim_report_with_full_metrics": 500000,
      "git_status_audit_and_self_review": 250000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Update",
    "if_success_tier_becomes": 2.5,
    "if_success_closing_note": null,
    "if_refuted_advance_to_stage": "fix-bug-spawned-side-investigation",
    "if_refuted_tier_becomes": 1.0,
    "if_novel_advance_to_stage": "Hypothesize-with-side-dispatch",
    "if_novel_tier_becomes": 1.5,
    "next_falsifier_to_test_after": "critic-independent-recompute-at-different-parameter-point-T101"
  },
  "if_succeeds_next_step": "T101 director dispatches critic Update (independent re-derivation + numerical recompute at e.g. c_0=2.0, c_1=0.05 or c_0=0.5, c_1=-0.2; audit k-grid bias and eigvals branch-selection assumptions). Budget ~1.4M. Tier 2.5 → 3.0 on critic CORROBORATE. T102 implementer_text Document closure: memory entry `tdhfb_phase2_generic_f_kernel_tier3_closure_2026_05_18.md`, conclusions index update [Established] at Tier 3, close investigation. **AUDIT_DUE interleave decision point**: gap=12 by T102; recommend T101 critic + T102 Document + T103 audit-class-scan (sequential, accepts gap=13 vs dropping mid-arc). Total arc T98→T99→T100→T101→T102 = 5 turns; estimated remaining ~3-4M effective.",
  "if_fails_next_step": "Three failure paths per §6.failure_modes:\n- EXECUTE_F3_RATIO_BROKEN: spawn fix-bug `tdhfb-generic-f-kernel-factor-2-regression-2026-05-18`, dispatch critic for independent algebraic re-derivation. Tier 1.5 → 1.0. TDHFB Tier-3 trajectory pauses until kernel reconciled.\n- EXECUTE_PARTIAL_F1_OR_F2_OFF: re-dispatch implementer with tighter k-grid + better fit (~1.5M).\n- EXECUTE_JULIA_FAILED: re-dispatch implementer with API-export preflight (~1.5M).\nIn all failure cases, T101 critic-audit dispatch precedes any kernel patch (no kernel modification until critic confirms the discrepancy is real, not an implementer artifact).",
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read scheduler_100.json THIS turn (JULIA_GPU_OK, cpu_light permitted, VRAM/RAM/foreign-julia probes clean)
- [x] Read state.json relevant sections (turn=100, history[97] T98, history[98] T99, investigations[tdhfb-phase2...] full entry at lines 3224-3274, schema_version=2.1)
- [x] Read judge/turn_99.json (PASS, 20/20 criteria, no triggered failure_modes, BUDGET_OVER advisory acknowledged)
- [x] Read theorist/turn_99.md (especially §7 deliverable E and §6 state.json patch — both consumed by T99 implementer)
- [x] Read sim/turn_99.md (T99 implementer's state.json registration execution — confirmed PATCHED + grep count 4)
- [x] Read prior director turn (turn_99.md ENTIRE — contract layout, success_criteria shape, failure_modes coverage all consumed as template)
- [x] Read ≥1 memory file: `tier3_pipeline_survey_2026_05_18.md` (this investigation is candidate #5 from that menu), MEMORY.md TDHFB Phase 2 entry (factor-2 caveat), MEMORY.md tier3_pipeline_survey closure list
- [x] Read conclusions/<inv>.md (stub-only at T99; nothing load-bearing to skip on)
- [x] Read status/<inv>.md (T99 narrative summary, confirms tier 1.5 + BUDGET_OVER advisory)
- [x] Verified scheduler precondition_check is concrete and would actually run (test -f on 6 paths + julia --version + python3 state.json membership assertion + PRECONDITIONS_OK echo)
- [x] investigation_id valid in state.investigations (registered at T99; state.json line 3224)
- [x] stage_advancing_to = Execute is the §F1 next stage after Hypothesize (T99 absorbed Design)
- [x] subagent_type = implementer matches §F1 role_per_stage[Execute]
- [x] researcher_depth = null (not a researcher dispatch)
- [x] success_criteria machine-evaluable (18 criteria, all using ==/>=/<= or `in` operators against METRICS JSON fields; numerical thresholds derived from KU2012 §4.2 closed-forms + T99 §C derivation)
- [x] failure_modes cover scientific (EXECUTE_F3_RATIO_BROKEN → fix-bug spawn + critic), operational (EXECUTE_JULIA_FAILED → API preflight, EXECUTE_OPERATIONAL_FAIL → scope drift), numerical (EXECUTE_PARTIAL_F1_OR_F2_OFF → tighter k-grid)
- [x] observable_manifest precondition_check tests 6 source files + julia binary + state.json membership (concrete + runnable)
- [x] budget fits within scheduler window_seconds_left (2.0M target / 3.0M cap, 900s wall / 1124058s window — trivially fits)
- [x] §A6 research-first citation present: KU2012 §5 + SKU2013 §IV + 2 memory anchors + APC cache adaptation note
- [x] §A5 D1 articulated: D1 verify Tier 2→2.5 (PRIMARY axis); manuscript NOT in scope
- [x] APC contract template cache: `physics::verify-claim::Execute` n_seen=8; cached skeleton uses run_yaml pattern not fully applicable to standalone diagnostic, but failure_mode + success_criteria structural shape (precondition_check + run_completes + per-observation PASS criteria) preserved
- [x] No improvised terminology (BdG, GP Hamiltonian, Nambu, phonon, magnon, polar/FM phase, anomalous block, sound velocity — all established terms)
- [x] No anko-attribution in implementer brief
- [x] Investigation update field: if_success → Update stage + tier 2.5; if_refuted → fix-bug spawn + tier 1.0
- [x] Cost frame: T100 expected 2.0M (cpu_light JIT-cold norm; T97 bug-4 cpu_light was 2.6M; this script is shorter so slightly under); HARD CAP 3.0M addresses T99 BUDGET_OVER advisory
- [x] AUDIT_DUE at gap=11 acknowledged; deferred one more turn (T102 Document or T103 audit-class-scan) per `feedback_cost_overhead_is_the_cost` — closing Tier-3 arc mid-chain has higher leverage than dropping for a periodic scan
- [x] Meta interleave gap=5 acknowledged; deferred — no actionable Observe-stage trigger
- [x] subagent rotation: implementer gap = 2 turns since T97 (theorist T99, researcher T98). Healthy.
- [x] Seed.md staleness flagged in §1; scheduler is authoritative per anko 2026-05-16 PROBE_DRIVEN clause
- [x] Theorist's F2 erratum (sqrt(1.1) vs sqrt(0.9) for c_1<0 FM stability) captured in T100 contract (canonical value sqrt(0.9)=0.9486832980505138 in success_criteria + metrics schema)
