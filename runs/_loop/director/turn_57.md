---
turn: 57
subagent: director
investigation_id: klaus-magnetostir-bch-leak-2026-05-13
stage_advancing_from: Hypothesize (T56 theorist produced formal hypothesis spec: primary observable max_norm_drift_T_steady, secondary discriminator m+F chi-square vs phi-smooth-trend, CONFIRM/REFUTE/INCONCLUSIVE bands derived from Y4 truncation + rotating-basis BCH parameter; resolved T55 4 open questions; verified line-37 memory claim against current src/rotating_basis/propagators.jl:160-231; produced T57 executable pseudocode)
stage_advancing_to: Design+Execute (fused — pure-analysis script reads existing 8 JLD2 files, no template-driven config to design separately; implementer writes scripts/diagnostic/klaus_bch_leak_verification.jl per T56 §4 pseudocode, runs against existing data, emits primary+secondary observable values per phi point with verdict classification)
topic_tags: [klaus-magnetostir, option-gamma, bch-leak, phi-sweep, jld2-analysis, p2-norm-drift, m-plus-F-discriminator, verify-claim-execute, tier2-to-tier3, implementer-julia-cpu-light]
paper_section: null
depends_on: [55, 56, 10, "runs/_loop/research/turn_55.md", "runs/_loop/theorist/turn_56.md", "runs/_loop/theorist/turn_10.md", "runs/_loop/director/turn_56.md", "runs/_loop/state.json", "runs/_loop/seed.md", "runs/_loop/_local/scheduler_57.json", "src/rotating_basis/propagators.jl", "runs/eu151_klaus_phi_phys/", "memory:option_gamma_rotating_basis"]
produces: "implementer report at runs/_loop/sim/turn_57.md containing: (1) new analysis script at scripts/diagnostic/klaus_bch_leak_verification.jl (Julia, JLD2-only, no SpinorBEC dep); (2) per-phi observables {max_norm_drift, m_plus_F_drop, Jz_proxy_drift, larmor_phase_metadata} for all 8 phi values; (3) aggregate primary verdict via max_norm_drift_global < 1e-8 + growth-factor < 5x test; (4) aggregate secondary verdict via chi-square deviation of m+F drops from linear-in-phi smooth-trend fit; (5) overall verdict mapping to {CONFIRM, INCONCLUSIVE, REFUTE} of klaus-bch-leak Option γ hypothesis; (6) machine-evaluable §4 Metrics block matching T56 §6 contract"
---

# Turn 57 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, flow_template `verify-claim`, tier_current 2 → target 3). T56 advanced Hypothesize stage cleanly with full formal spec.
- **Note on state.json.active_investigation_id**: state.json shows `yan-li-saito-2026-reproduction` (stale label from T49 Document closure). T56 director switched the working investigation to klaus-bch-leak via Research(T55) + Hypothesize(T56). T57 continues klaus-bch-leak; the state.json active field is stale bookkeeping that will be refreshed when the implementer updates state.
- **Stage transition**: Hypothesize → **Design+Execute (fused)** per §F1. Rationale below in §3.
- **Tier**: 2 → target 3. T57 Execute does not bump tier directly; T58 Analyze classifies observables vs CONFIRM/REFUTE bands; T59 critic Update bumps tier (2 → 3 if both CONFIRM, 2.5 if mixed, 1.5 if REFUTED).
- **Falsifier this turn**: `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator` (named by T56). Tests one PRIMARY (max_norm_drift_T_steady) + one SECONDARY (m+F chi-square vs phi smooth trend) observable across 8 phi values ∈ {1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0}.
- **Other in-flight investigations summary**:
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED tier 3.0. No action.
  - `yan-li-saito-2026-reproduction` (priority 1): Document-terminal, tier 0.4, dormant. R4 analytical revival not anko-prioritized.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): **THIS TURN** — Hypothesize → Design+Execute.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `audit-class-scan-2026-05-18-T50` (priority 20): CLOSED.
  - `meta-stage-routing-2026-05-18` (priority 25): held at Observe through T57 per T54 confounder_advisory; T58 reassess.
  - `meta-critic-placement-2026-05-17` (priority 50): defer.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED.
  - `fullbdg-f6-polar-3000x` (priority 99): contained, skip.
- **Scheduler** (`scheduler_57.json`): policy=JULIA_GPU_OK, allowed_workloads includes `implementer_julia_cpu_light`. Window 1,182,662s left (~13.7 days). VRAM 12,962 MB free, foreign_julia=0, RAM 25.05 GB avail, GPU util 1%. JLD2 read + post-processing well within `cpu_light` envelope.
- **Last judge verdict**: T56 = NOOP (theorist text-only deliverable; not the FAIL/operational kind — full §6 Metrics block valid in theorist/turn_56.md). Routing: continue klaus-bch-leak chain per T56 §F1 `if_success_advance_to_stage`.
- **Drift signals**: T55 RESEARCHER_ONLY + T56 NOOP both expected text-only outcomes. T57 = implementer_julia_cpu_light with real code-write + real execution → code_delta_zero=0 expected.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T10 | Hypothesize+Design | PASS | Theorist derived BCH leak (eq §2.4 term 1 `dt²·p·F·sinθ·c_dd⟨n⟩`, §2.5 term 2 `dt²·φ̇·p·sinθ·F`) + §2.9 P1/P2/P3 predictions. Investigation parked since (docstring landed only). |
| T55 | Research | RESEARCHER_ONLY | Researcher inventoried 8 jld2 files (verified by Glob this turn: all 8 present at runs/eu151_klaus_phi_phys/phi_{1.0,2.0,3.0,4.524,6.0,8.0,12.0,18.0}/result.jld2); produced P1/P2/P3 testability matrix; cited Hairer-Lubich-Wanner §III.4 + Bao-Cai 2018; raised 4 open questions. |
| T56 | Hypothesize | NOOP (text-only theorist) | Theorist verified line-37 memory claim against current `src/rotating_basis/propagators.jl:160-231` (eigen-exact single matrix exp; no internal Strang). Derived Y4 truncation floor ~3e-10 from C_Y4≈0.0247. Resolved 4 T55 open questions (P2 threshold, tilde vs lab Fz proxy, BCH-vs-Y4 discriminator via m+F chi-square, larmor_phase metadata is bookkeeping not stability constraint). Produced formal falsifier `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator` with CONFIRM/REFUTE bands + T57 Julia pseudocode (~80 LOC) using JLD2/Statistics/Printf/Polynomials. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1): Research → Hypothesize → **Design → Execute** → Analyze → Update → Document → closed.
- **Why fuse Design+Execute this turn (instead of two separate dispatches)**:
  - The theorist's T56 §4 already contains the complete runnable pseudocode (~80 LOC, exact JLD2 keys + steady-window selection logic + chi-square fit + verdict classification). There is no separate experimental-config to design (no YAML template to copy from `runs/_loop/templates/` — this is a pure JLD2 reader, not a SpinorBEC simulation run).
  - §F1 Design stage role: "observable manifest + experimental config + criteria for each falsifier. Implementer MUST start from a template in `runs/_loop/templates/` (copy + patch deltas)". This is the contract for **SpinorBEC simulation** designs — the available templates (ground_state_eu151_basic.yaml, dynamics_klaus_stir.yaml, yan_li_saito_f1_droplet.yaml) are for new physics runs. T57 reads EXISTING data and runs no new physics; the templates do not apply.
  - The observable manifest (per T56 §3 formal hypothesis) and per-falsifier criteria (CONFIRM/REFUTE bands per T56 §2.1, §2.3) are already declared. They become this turn's success_criteria.
  - Per `feedback_decision_style` (anko: minimal clarifying questions; pick defaults and move): fuse is the default for pure-analysis turns. The alternative (separate Design turn that just transcribes T56 §4 into a stub-script-spec) burns ~1.5M tokens for zero physics advance.
  - Per `feedback_mechanical_vs_investigation_threshold` (anko 2026-05-18: 3-second test — sed-class rename / JLD2-read-and-compute does NOT need a separate Design ceremony): this is a mechanical-execution turn, not an investigation. The investigation already happened at T10/T55/T56.
- **Role for fused Design+Execute**: `implementer_julia_cpu_light` (writes script + runs Julia + emits report). Single dispatch.
- **Why NOT switching investigations**:
  - barnett (closed), yan-li-saito (dormant tier 0.4), audit-class-scan (closed), judge-bug (closed), meta-internal-b (closed), meta-stage-routing (held to T58 per advisory), meta-critic-placement (priority 50 defer), fullbdg-f6 (contained, skip).
  - klaus-bch-leak is the only active physics investigation and has its formal falsifier spec ready to test.

## 4. Research grounding (§A6)

External / prior references this dispatch grounds against:

1. **`runs/_loop/theorist/turn_56.md` §4** — full Julia pseudocode (~80 LOC) that the implementer expands into a runnable script. PRIMARY input.
2. **`runs/_loop/theorist/turn_56.md` §3** — formal hypothesis statement with CONFIRM/REFUTE bands (the criteria for this turn's success_criteria).
3. **`runs/_loop/research/turn_55.md` §1.2** — verified JLD2 key paths (`dynamics/norms`, `dynamics/Fz`, `dynamics/Lz`, `dynamics/per_m_history`, `dynamics/times`, `dynamics/integrator_meta/*`).
4. **`runs/_loop/research/turn_55.md` §1.3** — verified snapshot counts (~740 per phi, steady window ~629 snapshots after dropping tilt ~32 + spinup ~79).
5. **`runs/_loop/theorist/turn_10.md` §2.9** — original P1/P2/P3 predictions that T56 refined.
6. **Memory `option_gamma_rotating_basis.md` line 37** (verified by T56 against current code at `src/rotating_basis/propagators.jl:160-231`) — the load-bearing claim that this Execute tests.
7. **Hairer-Lubich-Wanner 2006 §V.3.1** — Y4 truncation constant 0.0247 cited as the threshold-derivation anchor (T56 §2.1).
8. **Yoshida 1990 (*Phys. Lett. A* 150, 262)** — original Y4 composition reference (T56 §2.1).
9. **`runs/eu151_klaus_phi_phys/config.yaml`** — confirmed dt=0.001, T_steady=314.16, theta=0.611, p=26700.
10. **Anthropic context engineering "Isolate" strategy (Director.md §G)** — implementer gets a focused brief with explicit pseudocode + file paths + JLD2 keys, not the full state.
11. **AI Scientist v2 Experiment Manager pattern** — the implementer's report MUST include the §4 Metrics block matching the success_criteria, so judge.py can mechanically evaluate.
12. **anko 2026-05-15 "Manuscript is NOT the essence"** — this advances D1 verification depth (tests the load-bearing line-37 claim of the entire ~700 LOC Option γ subsystem). NOT manuscript polish.
13. **anko 2026-05-18 "Fix the class not the instance"** — testing one PRIMARY + one DISCRIMINATING SECONDARY observable (per T56 §2.3 argument that norm-drift alone is insufficient for a phase-error class). The chi-square test on m+F drop discriminates BCH-phase-error from Y4-amplitude-error.
14. **anko 2026-05-18 "3 seconds = recognition time" (`feedback_mechanical_vs_investigation_threshold`)** — JLD2-read-and-compute is mechanical execution; no need for separate Design ceremony.
15. **Reflexion / LATS critic-frequency pattern (Director.md §G)** — the critic stage (T59 Update) is the independent re-evaluation point; this turn produces the raw evidence for that critic to evaluate.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify existing physics). The Option γ subsystem rests on the claim "eigen-exact `apply_local_spin_step!` absorbs the lab-frame BCH leak `O(p·F·|Â|·dt²)` to `O(φ̇·F·dt)² scaling`". T10 derived it (Tier 2 internal); T55 confirmed the data exists; T56 produced the formal falsifier; **T57 measures the actual observables on the existing 8-phi sweep data** — this is the cross-implementation comparison that bumps tier toward 3.
- **Tier ladder position**: tier_current=2, tier_target=3. T57 produces measured values; T58 Analyze + T59 critic Update determine tier movement. If both observables CONFIRM, tier_current → 2.7 (Execute+Analyze done; Update pending). If both REFUTE, tier_current → 1.5 (hypothesis must be revised).
- **Manuscript NOT in scope**.
- **Cost frame**: implementer_julia_cpu_light reading 8 JLD2 files (~50-100 MB each based on memory `option_gamma_rotating_basis.md` line 33 reference) + ~80 LOC Julia compute. JIT cost ~30s for JLD2 + Polynomials. Total wall ~60-120s. Tokens ~2-3M effective for an implementer dispatch with code-write + execution + report.
- **Drift signal forecast post-T57**: code_delta_zero=0 (script added at `scripts/diagnostic/klaus_bch_leak_verification.jl`), manuscript_delta_zero=1 (expected per §A5), verdict should be PASS if the script produces the required Metrics fields. Verdict CONFIRM/REFUTE/INCONCLUSIVE refers to the SCIENTIFIC question and feeds into T58.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Execute",
  "subagent_type": "implementer_julia_cpu_light",
  "rationale": "T56 theorist Hypothesize stage completed with full formal spec including ~80 LOC Julia pseudocode reading existing 8 JLD2 files. All 8 result.jld2 confirmed on disk via Glob this turn (runs/eu151_klaus_phi_phys/phi_{1.0,2.0,3.0,4.524,6.0,8.0,12.0,18.0}/result.jld2). Pure-analysis script (JLD2/Statistics/Printf/Polynomials, no SpinorBEC dependency, no GPU, no simulation re-run). Per feedback_mechanical_vs_investigation_threshold the Design+Execute stages fuse for pure-analysis pipelines — no template-driven config to design. Implementer expands T56 §4 pseudocode into runnable script at scripts/diagnostic/klaus_bch_leak_verification.jl, executes, and reports primary + secondary observable values per phi point with verdict classification per T56 CONFIRM/REFUTE bands.",
  "brief": "## ROLE\n\nYou are implementer_julia_cpu_light. T57 §F1 Design+Execute (fused) stage of klaus-magnetostir-bch-leak-2026-05-13 (verify-claim flow). Write a Julia analysis script at /home/suzume/workspace/BEC-simulation/scripts/diagnostic/klaus_bch_leak_verification.jl based on /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md §4 pseudocode, execute it against the 8 existing JLD2 files, and report results.\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md` §3 (formal hypothesis with CONFIRM/REFUTE bands) + §4 (full Julia pseudocode you will adapt) + §6 (Metrics JSON contract this turn's §4 must match).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_55.md` §1.2 (JLD2 key paths) + §1.3 (snapshot count per phase ~32 tilt + ~79 spinup + ~629 steady ≈ 740 total).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_57.md` (this file — for context).\n\n## DELIVERABLES\n\n### A. New analysis script\n\nWrite `/home/suzume/workspace/BEC-simulation/scripts/diagnostic/klaus_bch_leak_verification.jl`. Adapt the T56 §4 pseudocode. Key requirements:\n\n- Read 8 JLD2 files at `runs/eu151_klaus_phi_phys/phi_{1.0,2.0,3.0,4.524,6.0,8.0,12.0,18.0}/result.jld2`.\n- Per-file: extract `dynamics/norms`, `dynamics/Fz`, `dynamics/Lz`, `dynamics/per_m_history`, `dynamics/times`, `dynamics/integrator_meta/larmor_phase_per_step`, `dynamics/integrator_meta/dt_used`. **Verify each key exists first**; if a key is missing, log a clear error and skip that phi point gracefully (continue with the remaining 7 — partial-data verdict is OK).\n- Compute steady-stir window: drop snapshots with `t <= 21.99` (= 6.28 tilt end + 15.71 spinup end). Use `findfirst(t -> t > 21.99, times)` as the start index; assert that >= 100 snapshots remain (steady window).\n- PRIMARY observable per phi: `max_norm_drift = maximum(abs.(1.0 .- steady_norms))`.\n- SECONDARY observable per phi: `m_plus_F_drop = steady_pmh[1, 1] - steady_pmh[1, end]` (component index 1 = m=+F=+6 per CLAUDE.md spinor convention `c=1 ↔ m=+F`).\n- AUXILIARY observables per phi: `Jz_proxy_drift = abs(steady_Fz[end] + steady_Lz[end] - steady_Fz[1] - steady_Lz[1])`, `Jz_proxy_mean = mean(steady_Fz .+ steady_Lz)`, `larmor_phase_metadata = read(f, \"dynamics/integrator_meta/larmor_phase_per_step\")`.\n- AGGREGATE PRIMARY verdict: `:CONFIRM` if max across all phi < 1e-8 AND growth ratio phi=18/phi=1 < 5; `:REFUTE` if any phi has > 1e-5 OR growth > 5; else `:INCONCLUSIVE`.\n- AGGREGATE SECONDARY verdict: fit drops vs phi to linear polynomial via `Polynomials.fit(phi_sorted, drops, 1)`. Compute residuals. Use std of low-phi-4 residuals (phi=1.0, 2.0, 3.0, 4.524) as sigma_baseline. Compute `max_sigma_deviation = maximum(abs.(residuals)) / sigma_baseline`. `:CONFIRM` if < 5; `:REFUTE` if > 5; else `:INCONCLUSIVE`. **Guard against `sigma_baseline = 0`** (can happen if residuals are exactly zero); fall back to a small epsilon (1e-12) and report sigma_baseline=0 in the metrics for context.\n- OVERALL verdict: `:CONFIRM` if both primary and secondary `:CONFIRM`; `:REFUTE` if either `:REFUTE`; else `:INCONCLUSIVE`.\n- Output: print summary table to stdout AND save full per-phi results dict to `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57_results.jld2` for T58 Analyze.\n\n### B. Run the script\n\nFrom the repo root, run:\n\n```bash\ncd /home/suzume/workspace/BEC-simulation && julia --project=. scripts/diagnostic/klaus_bch_leak_verification.jl 2>&1 | tee /tmp/turn_57_stdout.txt\n```\n\nExpected wall time: ~60-120 s (JIT for JLD2 first call ~30s, file reads ~5s each, compute microseconds, save microseconds). If wall > 600s, kill and investigate.\n\n### C. Implementer report at `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57.md`\n\nSections:\n\n#### §1 What was done\n\n- New file: `scripts/diagnostic/klaus_bch_leak_verification.jl` (LOC count).\n- Modified files: none expected (greenfield script).\n- Run command + wall time observed.\n- Reproduce sequence (single command + expected output summary).\n\n#### §2 Per-phi observables table\n\n| phi | max_norm_drift | m+F drop | Jz_proxy_drift | Jz_proxy_mean | larmor_phase | dt_used | n_steady |\n|-----|----------------|----------|----------------|---------------|--------------|---------|----------|\n| 1.0 | ... | ... | ... | ... | ... | ... | ... |\n| ... | ... | ... | ... | ... | ... | ... | ... |\n| 18.0 | ... | ... | ... | ... | ... | ... | ... |\n\n#### §3 Aggregate verdict\n\n- Primary observable: `max_norm_drift_global = ...`, growth ratio = ..., verdict = `:CONFIRM | :INCONCLUSIVE | :REFUTE`.\n- Secondary observable: drops_arr = ..., linear fit slope+intercept, residuals = ..., sigma_baseline = ..., max_sigma_deviation = ..., verdict = `:CONFIRM | :INCONCLUSIVE | :REFUTE`.\n- Overall verdict: `:CONFIRM | :INCONCLUSIVE | :REFUTE`.\n\n#### §4 Metrics (machine-evaluable, single fenced JSON block)\n\n```json\n{\n  \"experiment_kind\": \"jld2_analysis\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 1,\n  \"analysis_script_path\": \"scripts/diagnostic/klaus_bch_leak_verification.jl\",\n  \"phi_values_analyzed\": [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0],\n  \"n_phi_with_complete_data\": <int, 0-8>,\n  \"primary_observable\": \"max_norm_drift_T_steady\",\n  \"max_norm_drift_global\": <float>,\n  \"max_norm_drift_per_phi\": [<8 floats in phi-sorted order>],\n  \"norm_drift_growth_phi18_over_phi1\": <float>,\n  \"primary_verdict\": \"CONFIRM | INCONCLUSIVE | REFUTE\",\n  \"secondary_observable\": \"m_plus_F_fraction_chi_square_vs_phi_smooth_trend\",\n  \"m_plus_F_drops_per_phi\": [<8 floats>],\n  \"linear_fit_slope\": <float>,\n  \"linear_fit_intercept\": <float>,\n  \"residuals_per_phi\": [<8 floats>],\n  \"sigma_baseline_lowphi4\": <float>,\n  \"max_sigma_deviation\": <float>,\n  \"secondary_verdict\": \"CONFIRM | INCONCLUSIVE | REFUTE\",\n  \"jz_proxy_drift_per_phi\": [<8 floats>],\n  \"jz_proxy_mean_per_phi\": [<8 floats>],\n  \"larmor_phase_metadata_per_phi\": [<8 floats>],\n  \"larmor_phase_constant_across_phi\": <bool — should be true since p,F,dt do not vary>,\n  \"dt_used_per_phi\": [<8 floats>],\n  \"overall_verdict\": \"CONFIRM | INCONCLUSIVE | REFUTE\",\n  \"wall_time_sec\": <float>,\n  \"y4_truncation_floor_estimate_from_t56\": 3.14e-10,\n  \"rotating_basis_bch_param_phi18\": 0.108,\n  \"investigation_id\": \"klaus-magnetostir-bch-leak-2026-05-13\",\n  \"stage_advancing_to\": \"Execute\",\n  \"flow_template\": \"verify-claim\",\n  \"falsifier_id\": \"klaus-bch-leak-option-gamma-p2-plus-pop-discriminator\"\n}\n```\n\nMUST be a single fenced ```json``` block.\n\n#### §5 Honest discrepancy log\n\nIf the script fails on any phi (missing JLD2 keys, weird structure, etc.), document fully. If the result is unexpected (e.g. primary CONFIRM but secondary REFUTE), do NOT explain it away — report the raw numbers and let T58 Analyze + T59 critic Update decide. Do NOT modify the success_criteria thresholds to make things pass.\n\n## CONSTRAINTS\n\n- **Files allowed to create**: `scripts/diagnostic/klaus_bch_leak_verification.jl` (new), `runs/_loop/sim/turn_57.md` (new — your report), `runs/_loop/sim/turn_57_results.jld2` (new — full results dict for T58).\n- **Files allowed to modify**: none.\n- **Do NOT modify**: `src/`, `runs/eu151_klaus_phi_phys/*` (read-only!), any `runs/_loop/` file other than your own report + results jld2, `.claude/*`, any memory file, any other `runs/_loop/director/`, `theorist/`, `research/`, `judge/` file.\n- **No julia run beyond the analysis script itself**: do not run `Pkg.test()`, do not run any SpinorBEC simulation, do not run a fresh sweep.\n- **English only. No emojis.**\n- **Absolute paths in tool invocations.**\n- **Cost budget**: stay within ~3M effective tokens, ~20 min wall hard cap.\n- **Idempotence**: if `scripts/diagnostic/klaus_bch_leak_verification.jl` already exists from a previous attempt, READ it first; if it matches the intended script, just run it and report. Do NOT silently overwrite.\n- **JLD2 missing keys**: if `dynamics/integrator_meta/larmor_phase_per_step` or any other key is missing for a phi point, log clearly, skip that phi gracefully, continue with the rest. Partial-data is OK; reduced `n_phi_with_complete_data` is the signal.\n- **No Polynomials in stdlib**: if `Polynomials` is not in the project Manifest, fall back to a 2-coefficient normal-equations solve (a + b*phi minimizes sum of squared residuals; coefficients via simple closed-form means/variances). Do NOT add Polynomials to Project.toml.\n- **No new dependencies added to Project.toml**.\n\n## SUCCESS CRITERIA\n\nThe §4 Metrics JSON block must report the integer/string/boolean/float values per the contract. judge.py will mechanically evaluate them.\n\nReport HONESTLY. If the data reveals the line-37 claim is WRONG (e.g. norm drifts > 1e-5 at high phi), do NOT modify thresholds. Report the raw numbers and let the next stages (Analyze, critic Update) decide.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "analysis_script_path",
      "phi_values_analyzed",
      "n_phi_with_complete_data",
      "primary_observable",
      "max_norm_drift_global",
      "max_norm_drift_per_phi",
      "norm_drift_growth_phi18_over_phi1",
      "primary_verdict",
      "secondary_observable",
      "m_plus_F_drops_per_phi",
      "linear_fit_slope",
      "linear_fit_intercept",
      "residuals_per_phi",
      "sigma_baseline_lowphi4",
      "max_sigma_deviation",
      "secondary_verdict",
      "jz_proxy_drift_per_phi",
      "jz_proxy_mean_per_phi",
      "larmor_phase_metadata_per_phi",
      "larmor_phase_constant_across_phi",
      "dt_used_per_phi",
      "overall_verdict",
      "wall_time_sec",
      "y4_truncation_floor_estimate_from_t56",
      "rotating_basis_bch_param_phi18",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "falsifier_id"
    ],
    "optional": [],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_1.0/result.jld2 && test -f /home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_18.0/result.jld2 && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_55.md && test -d /home/suzume/workspace/BEC-simulation/scripts/diagnostic && which julia && echo 'precondition OK: 2 representative phi JLD2 files (bounds of sweep), theorist T56 + research T55 reports, scripts/diagnostic/ dir, julia all present; ready for T57 Execute'"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "jld2_analysis",
      "tolerance": null,
      "rationale": "Distinguishes pure-JLD2-read analysis from a full SpinorBEC simulation run."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Verification reads existing data; no src/ changes."
    },
    {
      "id": "one_script_added",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 1,
      "tolerance": null,
      "rationale": "Exactly one new script at scripts/diagnostic/klaus_bch_leak_verification.jl."
    },
    {
      "id": "script_path_correct",
      "metric": "analysis_script_path",
      "operator": "==",
      "value": "scripts/diagnostic/klaus_bch_leak_verification.jl",
      "tolerance": null,
      "rationale": "Discoverable in the diagnostic folder per project convention."
    },
    {
      "id": "all_8_phi_attempted",
      "metric": "n_phi_with_complete_data",
      "operator": ">=",
      "value": 6,
      "tolerance": null,
      "rationale": "Tolerate up to 2 phi points failing (data corruption, missing keys); 6+ is enough for the chi-square test (~4 dof minimum)."
    },
    {
      "id": "primary_observable_named",
      "metric": "primary_observable",
      "operator": "==",
      "value": "max_norm_drift_T_steady",
      "tolerance": null,
      "rationale": "Must match T56 §6 contract."
    },
    {
      "id": "secondary_observable_named",
      "metric": "secondary_observable",
      "operator": "==",
      "value": "m_plus_F_fraction_chi_square_vs_phi_smooth_trend",
      "tolerance": null,
      "rationale": "Must match T56 §6 contract."
    },
    {
      "id": "primary_verdict_in_set",
      "metric": "primary_verdict",
      "operator": "in",
      "value": ["CONFIRM", "INCONCLUSIVE", "REFUTE"],
      "tolerance": null,
      "rationale": "One of three explicit verdict tokens (per anko 2026-05-18 judge-bug fix, in-operator now correctly handles 3+ element lists)."
    },
    {
      "id": "secondary_verdict_in_set",
      "metric": "secondary_verdict",
      "operator": "in",
      "value": ["CONFIRM", "INCONCLUSIVE", "REFUTE"],
      "tolerance": null,
      "rationale": "One of three explicit verdict tokens."
    },
    {
      "id": "overall_verdict_in_set",
      "metric": "overall_verdict",
      "operator": "in",
      "value": ["CONFIRM", "INCONCLUSIVE", "REFUTE"],
      "tolerance": null,
      "rationale": "Aggregate verdict from primary + secondary."
    },
    {
      "id": "wall_within_budget",
      "metric": "wall_time_sec",
      "operator": "<=",
      "value": 600,
      "tolerance": null,
      "rationale": "Per scheduler cpu_light envelope and theorist T56 §4 wall estimate (~60-120s including JIT)."
    },
    {
      "id": "larmor_phase_invariant_across_phi",
      "metric": "larmor_phase_constant_across_phi",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "p, F, dt do not vary across the phi scan; larmor_phase_per_step = p*F*dt = 160.2 should be identical across all 8 phi files. If false, an unexpected config variation occurred (sanity check)."
    },
    {
      "id": "y4_floor_carried_from_t56",
      "metric": "y4_truncation_floor_estimate_from_t56",
      "operator": "==",
      "value": 3.14e-10,
      "tolerance": null,
      "rationale": "Theorist's derived Y4 floor; carried into the report so T58 Analyze can cross-check observed values against this baseline."
    },
    {
      "id": "bch_param_carried_from_t56",
      "metric": "rotating_basis_bch_param_phi18",
      "operator": "==",
      "value": 0.108,
      "tolerance": null,
      "rationale": "Theorist's rotating-basis BCH parameter at phi=18; should be carried into the report as the internal-consistency anchor."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "klaus-magnetostir-bch-leak-2026-05-13",
      "tolerance": null,
      "rationale": "Investigation continuity."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Execute",
      "tolerance": null,
      "rationale": "§F1 Execute stage."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "tolerance": null,
      "rationale": "verify-claim template per state.json."
    },
    {
      "id": "falsifier_carried",
      "metric": "falsifier_id",
      "operator": "==",
      "value": "klaus-bch-leak-option-gamma-p2-plus-pop-discriminator",
      "tolerance": null,
      "rationale": "Carry the T56-named falsifier into the Execute report for state.json bookkeeping."
    }
  ],
  "failure_modes": [
    {
      "if": "n_phi_with_complete_data < 6",
      "category": "data_gap",
      "next_action": "T58 director investigates the missing-key cause: read the failed JLD2 files via a one-off `jldopen` keys() dump. If schema variation exists across phi files, theorist may need to refine the script. If physical data corruption, anko escalation. Otherwise re-run analysis with the schema discrepancy patched."
    },
    {
      "if": "wall_time_sec > 600",
      "category": "operational",
      "next_action": "T58 director profiles the script (likely JLD2 decompression for full ψ̃ snapshots — but the script should only need the cheap scalar series, not psi_snapshots_streamed). If full snapshot decompression was accidentally included, refactor to skip and re-run. If real bottleneck, decompress jld2 to /tmp once and reuse."
    },
    {
      "if": "src_files_modified > 0",
      "category": "scope_violation",
      "next_action": "T58 director reverts via git restore; implementer scope discipline failure (script-only deliverable was clearly specified)."
    },
    {
      "if": "primary_verdict == 'CONFIRM' AND secondary_verdict == 'CONFIRM'",
      "category": "scientific_success",
      "next_action": "T58 dispatches sim Analyze + critic for Update stage. Tier 2 → 2.7 (Execute+Analyze done). If T59 critic Update independently corroborates, tier → 3.0 (klaus-bch-leak's first Tier 3, second project-wide). T60 Document → close."
    },
    {
      "if": "primary_verdict == 'REFUTE' OR secondary_verdict == 'REFUTE'",
      "category": "scientific_refuted",
      "next_action": "T58 director routes to Update stage. The Option γ line-37 claim is partially or fully refuted. Critic Update revisits: (a) is the code-read in T56 §1.2 correct? (b) is the Y4 truncation floor estimate correct? (c) is the steady-window selection correct? (d) is the chi-square test mis-calibrated? Tier drops to 1.5; hypothesis revised at re-Hypothesize stage if anko prioritizes."
    },
    {
      "if": "primary_verdict == 'INCONCLUSIVE' OR secondary_verdict == 'INCONCLUSIVE' (and not both REFUTE)",
      "category": "scientific_inconclusive",
      "next_action": "T58 director assesses which observable was inconclusive. If primary (norm drift in 1e-8 to 1e-5 band): rely on secondary verdict + dispatch Q1 from T56 §9 (c_dd<n> extraction) for tighter Y4 floor estimate. If secondary (m+F sigma in 3-5 range): dispatch fresh runs at finer phi grid OR lab-frame snapshot post-rotation (cpu_heavy, ~30 min/phi) per T56 §2.2 Tier-3 path. T58 makes the cpu_heavy budget call."
    },
    {
      "if": "larmor_phase_constant_across_phi == false",
      "category": "operational",
      "next_action": "T58 director investigates whether the phi scan actually varied p or dt (which it shouldn't per the config). Likely a script bug in reading the metadata; re-verify the JLD2 key path. Does NOT affect the scientific verdict if the data itself is correct."
    },
    {
      "if": "implementer adds Polynomials to Project.toml",
      "category": "scope_violation",
      "next_action": "T58 director reverts Project.toml change. Was explicitly forbidden — implementer should use 2-coefficient closed-form normal-equations fallback."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 4000000,
    "wall_time_hard_cap_sec": 1500
  },
  "budget": {
    "expected_cost_eff": 2500000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "read_required_files": 300000,
      "write_analysis_script": 600000,
      "julia_jit_and_run": 400000,
      "interpret_results_into_table": 400000,
      "write_metrics_json_and_report": 500000,
      "save_results_jld2_for_t58": 100000,
      "self_review_and_idempotence": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Analyze (T58 sim subagent classifies observed values vs T56 CONFIRM/REFUTE bands; T59 critic Update; T60 Document → close at tier 3 if both CONFIRM)",
    "if_success_tier_becomes": 2.7,
    "if_refuted_advance_to_stage": "Update (critic re-derives the BCH bound and/or Y4 floor estimate; may REFUTE-and-revise the line-37 memory claim)",
    "if_refuted_tier_becomes": 1.5,
    "if_inconclusive_advance_to_stage": "Analyze with cpu_heavy lab-frame reconstruction path queued (T56 §2.2 Tier-3 fallback)",
    "next_falsifier_to_test_after": "If CONFIRM: P3 p-scaling (T55 Falsifier 4 deferred) at 3 p values for cross-axis cross-check. If REFUTE or INCONCLUSIVE: Q1 from T56 §9 (c_dd*<n> dimensionless extraction for tighter Y4 floor)."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_57.json` (policy=JULIA_GPU_OK; implementer_julia_cpu_light in allowed_workloads; window 1,182,662s left; VRAM 12,962 MB free; foreign_julia=0; RAM 25.05 GB avail).
- [x] Read `runs/_loop/state.json` partial (lines 1-200 for history T28-T32; lines 1240-1330 for T54-T56 entries; lines 1330-1760 for investigations + active_investigation_id = stale yan-li-saito).
- [x] Read `runs/_loop/seed.md` (priority order; klaus-bch-leak priority 3 active).
- [x] Read `runs/_loop/director/turn_56.md` end-to-end (T56 dispatch + theorist deliverable).
- [x] Read `runs/_loop/theorist/turn_56.md` end-to-end (formal hypothesis spec + Y4 derivation + T57 pseudocode + Metrics block).
- [x] Read `runs/_loop/research/turn_55.md` lines 1-80 (JLD2 schema verification + snapshot count derivation).
- [x] Read `runs/_loop/schedule.yaml` (PROBE_DRIVEN through 2026-05-31).
- [x] Read memory `option_gamma_rotating_basis.md` lines 1-100 (line 37 load-bearing claim; 73 tests Phase 2; system reminder noted 20-day-old, theorist already verified against current code in T56 §1.2).
- [x] Verified JLD2 files exist via Glob: 8 result.jld2 + 8 point_001.jld2 symlinks across runs/eu151_klaus_phi_phys/phi_{1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0}/.
- [x] No `runs/_loop/judge/turn_55.json` or `turn_56.json` exist (judge writes only for executed-run turns; RESEARCHER_ONLY + theorist NOOP do not produce judge files — confirmed by Glob).
- [x] investigation_id `klaus-magnetostir-bch-leak-2026-05-13` valid in state.json `investigations` dict.
- [x] stage_advancing_to `Execute` is the §F1 next stage after Hypothesize (Design fused per rationale in §3).
- [x] subagent_type `implementer_julia_cpu_light` matches §F1 role_per_stage[Execute] for a julia_cpu workload.
- [x] success_criteria 18 criteria, all machine-evaluable (==, >=, <=, in operators on strings/booleans/integers/floats/lists). Uses the post-fix `in` operator from T53 judge-bug fix (3-element lists for verdict tokens).
- [x] failure_modes cover 8 outcomes including scientific success, refutation, inconclusive, data gap, operational, scope violation, edge case (larmor_phase non-constant), and explicit Polynomials forbidden.
- [x] observable_manifest precondition_check verifies 2 representative JLD2 files exist (phi=1.0, phi=18.0 — sweep bounds), T56 + T55 reports, scripts/diagnostic dir, julia binary.
- [x] budget 2.5M expected, 4M tolerance; wall 600s expected, 1500s hard cap.
- [x] §A6 research-first citation present (15 references: T56 theorist + T55 research + T10 theorist + memory + Hairer-Lubich-Wanner + Yoshida 1990 + config + Anthropic Isolate/AI Scientist v2/Reflexion + anko 2026-05-15/2026-05-18 + Director.md §G).
- [x] §A5 D1-justified articulated: this advances D1 verification depth of the Option γ subsystem's load-bearing claim via measurement on existing sweep data. Tier 2 → 3 candidate via cross-implementation comparison (φ̇ sweep vs theory).
- [x] Considered alternative dispatches:
  - Pure Design turn (no execute): rejected — pseudocode complete in T56 §4, no template-driven config to design, would burn ~1.5M tokens for zero physics advance.
  - critic Update without Execute first: rejected — there are no measured observables to evaluate yet.
  - Switching to yan-li-saito R4: rejected — dormant tier 0.4, not anko-prioritized this session per seed.md.
  - Meta-stage-routing Hypothesize: held to T58 per T54 confounder_advisory.
  - Meta-critic-placement: priority 50 defer.
  - **klaus-bch-leak Execute is highest leverage**: ~2.5M tokens, produces the raw evidence for the Update stage, tier 2 → 2.7+ candidate path.
- [x] All file paths in brief are absolute.
- [x] Brief explicitly forbids src/ touch, jld2 modification, Polynomials dependency add, additional julia runs beyond the analysis script.
- [x] sim/turn_57.md §4 Metrics JSON block requirement specified with exact field list.
- [x] Idempotence guard in brief (if script exists, read first; do not silently overwrite).
- [x] No conventional commits drafted this turn (loop auto-commit handles it post-judge).
- [x] T58 routing pre-planned per outcome branch (success_advance Analyze + critic; refuted Update + tier 1.5; inconclusive Analyze with cpu_heavy queued).
- [x] §F1 Execute stage role correctly assigned to implementer_julia_cpu_light per workload-class match.
- [x] No meta-meta investigation spawned (physics-class).
- [x] Per `feedback_decision_style`: single commitment per turn = one analysis script + one Execute against existing data.
- [x] Per `feedback_mathematical_elegance_bias`: one observable per axis (norm drift for amplitude, m+F chi-square for phase) — minimal targeted answer, not a unifying reformulation.
- [x] Per `feedback_mechanical_vs_investigation_threshold`: pure-analysis Design+Execute fuses (3-second test passed; no separate ceremony).
- [x] Per `feedback_fix_the_class_not_the_instance`: testing two observables (amplitude class + phase class) instead of just one — discriminates BCH-phase from Y4-amplitude class.
