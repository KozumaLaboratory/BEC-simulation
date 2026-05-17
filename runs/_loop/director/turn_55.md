---
turn: 55
subagent: director
investigation_id: klaus-magnetostir-bch-leak-2026-05-13
stage_advancing_from: documented (T10 closure; investigation parked since T11 awaiting julia P3 validation against existing eu151_klaus_phi_phys/ jld2 data; blocker now lifted by JULIA_GPU_OK policy + verified jld2 inventory)
stage_advancing_to: Research (data-survey researcher dispatch — inventory observables saved per jld2 across the 8-point φ̇ sweep; map them to the P1/P2/P3 predictions from theorist/turn_10.md §2.9; identify which predictions are testable from existing data vs require a fresh rotating-basis+lab-frame head-to-head run)
topic_tags: [klaus-magnetostir, option-gamma, bch-leak, phi-sweep, p3-scaling-test, data-inventory, jld2-survey, tier2-to-tier3, verify-claim-reopen]
paper_section: null
depends_on: [10, 54, 53, 52, "runs/_loop/theorist/turn_10.md", "runs/_loop/director/turn_10.md", "runs/_loop/state.json", "runs/_loop/seed.md", "runs/_loop/_local/scheduler_55.json", "runs/eu151_klaus_phi_phys/config.yaml", "runs/eu151_klaus_phi_phys/phi_*.{jld2,yaml} inventory (16 files)", "memory:option_gamma_rotating_basis", "memory:active_handoff", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_decision_style"]
produces: "researcher report at runs/_loop/research/turn_55.md inventorying the existing eu151_klaus_phi_phys/ jld2 data (which observables are saved per file, snapshot cadence, total samples, file sizes), mapping each observable to the P1/P2/P3 predictions in theorist/turn_10.md §2.9, and producing a 3-column matrix [prediction → testable-from-existing-data? → suggested test shape]. Output gates the T56 theorist Hypothesize stage."
---

# Turn 55 — Director Report

## 1. Investigation state snapshot

- **Active investigation (switching)**: `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, flow_template `verify-claim`, tier_current 2 → target 3). Prior active investigation `audit-class-scan-2026-05-18-T50` closed cleanly at T54 (PASS, 18/18 criteria); `judge-in-operator-bug-2026-05-18` also closed at T54.
- **Why switching**: per T54 §6 failure_modes "all PASS" branch, the pre-planned T55 candidate (a) was "klaus-magnetostir-bch-leak unblock — survey runs/eu151_klaus_phi_phys/ jld2 data inventory to confirm theorist re-Hypothesize has input data; if yes, dispatch theorist Research stage at priority 3". I verified this pre-flight (Glob on runs/eu151_klaus_phi_phys/**/*.jld2 returned 16 files: 8 phi values × 2 jld2 per dir; config.yaml + 8 per-point config.yaml present). The data exists and is the natural unblocker.
- **Stage transition**: `documented` → **Research** (re-opening the investigation at the Research stage of a fresh verify-claim sub-cycle on a NEW falsifier — the P3 scaling test was never executed; investigation was parked at "documented" but tier_target=3 requires a published-reference benchmark or cross-implementation. The φ̇-sweep data IS the cross-implementation evidence anchor).
- **Tier**: 2 → target 3. T55 Research stage does not bump tier; it establishes data preconditions for the T56-T57 Hypothesize+Design+Execute cycle that will push tier.
- **Falsifiers**: tested 0 of P1/P2/P3 from theorist/turn_10.md §2.9 (the T10 directive landed only docstring + scripts/diagnostic stub; never executed the julia probe per anko's scheduler at the time). The φ̇ sweep data is uniquely suited to test P2 (Option γ dt-stability across stir rates) and a φ̇-variant of P3 (scrambling-error scales with φ̇·p — term 2 of P1 — so varying φ̇ at fixed p tests the time-dependence-leak coefficient).
- **Other in-flight investigations summary**:
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED tier 3.0. No action.
  - `yan-li-saito-2026-reproduction` (priority 1): Document-terminal, tier 0.4, dormant. R4 analytical revival is a ~5M theorist+sympy investigation; not anko-prioritized this session. Defer.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): **THIS TURN** — re-open Research stage.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1. No action.
  - `audit-class-scan-2026-05-18-T50` (priority 20): CLOSED T54.
  - `meta-stage-routing-2026-05-18` (priority 25): held at Observe through T57 per T54 confounder_advisory; reassess at T58 against post-T53 FAIL/INCONCLUSIVE rate.
  - `meta-critic-placement-2026-05-17` (priority 50): defer.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED T54.
  - `fullbdg-f6-polar-3000x` (priority 99): contained per anko. Skip.
- **Scheduler** (`scheduler_55.json`): policy=JULIA_GPU_OK (probe-driven default), all 9 workloads allowed including researcher, implementer_julia_cpu_light, implementer_julia_gpu. Window 1,185,594s left (~13.7 days). VRAM 12,969 MB free, foreign_julia=0, RAM 25.07 GB avail. Researcher (text-only) is well within budget; future T56/T57 julia analysis dispatches also unconstrained.
- **Last judge verdict**: T54 = PASS (18/18 criteria). No drift escalation; routing per T54 "all PASS" branch.
- **Drift signals**: T54 closed clean. T55 advances a new investigation — code_delta_zero=1 (researcher data inventory; expected zero src/ touch), manuscript_delta_zero=1 (no manuscript work; expected).

## 2. Recent-turn audit (last 3 turns of THIS investigation chain)

The klaus-magnetostir-bch-leak investigation has been dormant since T11 (docstring-only landing per T10 directive). Most recent turns on this investigation:

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T10 | Hypothesize+Design | PASS | Theorist derived the BCH commutator: lab-frame Strang has δÛ ~ dt²·p·F·sinθ·c_dd⟨n⟩ leak (eq §2.4) + dt²·φ̇·p·sinθ·F time-dep leak (§2.5); Option γ drops BCH parameter from p·F·dt≈26.7 to φ̇·F·dt≈0.027 (4-decade). P1/P2/P3 predictions stated §2.9. Directive landed docstring-only modify_only edit (scripts/diagnostic stub). falsification_result INCONCLUSIVE (no observable output; modify_only). |
| T11 | (none) | n/a | Investigation parked; no further work in this chain. |
| (since T11, 44 turns) | n/a | n/a | Other investigations occupied loop bandwidth: barnett-mechanism (T12-T29 closed tier 3), yan-li-saito (T30-T49 closed at tier 0.4 partial-REFUTE), meta cycles (T44+), audit-class-scan T50 (T50-T54 closed). |

**What changed that unblocks klaus-bch-leak now**:
1. **Scheduler policy** is JULIA_GPU_OK (was anko's TEXT_ONLY at T10/T11 per memory `loop_scheduler_2026_05_15`).
2. **eu151_klaus_phi_phys/ jld2 data exists**: 8 φ̇ points × {result.jld2, point_001.jld2} + 9 config.yaml files. Confirmed via Glob pre-flight.
3. **Configuration** (`runs/eu151_klaus_phi_phys/config.yaml`) sets `defaults: {kind: rotating_basis, backend: gpu}` — so the existing jld2 IS the Option γ data path (P2 stability test); the lab-frame head-to-head data is NOT in this directory and would require a fresh run.
4. **Active investigation slot is open** (audit-class-scan + judge-bug both closed T54; barnett+yan-li-saito both terminal).

## 3. Flow template recall

- **Template**: `verify-claim` (§F1): Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed.
- **Why re-enter at Research (not skip to Design/Execute)**:
  - The T10 directive's P1/P2/P3 predictions were stated against operator-norm scalings, not against specific jld2 observables. Before designing the falsifier we must know what is actually saved per jld2: is `<F_z>(t)` saved at every snapshot? `<L_z>(t)`? norm drift trajectory? per-m populations? snapshot cadence?
  - Per `option_gamma_rotating_basis.md` line 73-83, rotating_basis dynamics step saves "full ψ̃ snapshots + ⟨F_z⟩(t) + ⟨L_z⟩(t)" with `save_psi_snapshots=true` default. The Klaus config sets `save: {every: 200}` (tilt), `{every: 200}` (spinup), `{every: 500}` (steady). With dt=0.001 and durations 6.28+15.71+314.16, that's ~32+78+628 ≈ 738 snapshots per point. But the actual saved keys depend on the analyzer pipeline that wasn't applied at run time.
  - We need data inventory FIRST. A researcher dispatch that loads each jld2, lists its keys, and tabulates them against the P1/P2/P3 prediction needs is mechanical and ~300k tokens. The output is the falsifier-design spec for T56 theorist Hypothesize.
- **Role for Research stage**: `researcher` (lit-scan + prior-loop-turn + memory + data-inventory; produces gap-mapping table for next Hypothesize). Per §F1: "lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain".
- **Why this is NOT a "build-theory" template**: the theory (BCH leak mechanism) is already derived at T10 §2.4. We are verifying an existing theoretical claim against existing data. verify-claim is correct.

## 4. Research grounding (§A6)

External / prior references this dispatch grounds against:

1. **`runs/_loop/theorist/turn_10.md` §2.9 P1/P2/P3** — the prediction text the researcher maps observations against.
2. **`runs/_loop/theorist/turn_10.md` §2.4 + §2.5** — the two leak terms: term 1 = `dt²·p·F·sinθ·c_dd⟨n⟩` (interaction-flanked) + term 2 = `dt²·φ̇·p·sinθ·F` (time-dep). Term 2's φ̇-linear scaling is testable from the existing sweep.
3. **`runs/eu151_klaus_phi_phys/config.yaml`** — protocol structure: tilt 0→35° (6.28 ω⁻¹) → spinup 0→φ̇ (15.71 ω⁻¹) → steady stir (314.16 ω⁻¹). The 8 zip points are pipeline.3 + pipeline.2 simultaneously varied: φ̇ ∈ {1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0}.
4. **Memory `option_gamma_rotating_basis.md`** (20 days old; verify against code per system reminder) — line 73-83 claims rotating_basis dynamics saves full ψ̃ snapshots + ⟨F_z⟩(t) + ⟨L_z⟩(t). Researcher MUST verify this claim against actual jld2 contents (not just trust memory).
5. **Memory `active_handoff.md`** — lab-frame Mz scrambles at dt=4e-4 (Tier-1 empirical that motivates Option γ). Researcher should note this as the lab-frame comparison baseline (not in this jld2 dataset; would require a separate run if comparison desired).
6. **`runs/_loop/director/turn_10.md`** — the original Research-stage directive (citations chain from option γ memory + active_handoff + klaus_adiabatic_elimination + gotcha_waveform_frequency_convention). T55 researcher inherits this citation chain.
7. **Anthropic context engineering** (per director.md §G): the "Select" strategy — researcher reads only relevant slices (jld2 keys, not full ψ̃ arrays). Use Julia `using JLD2; jldopen(path) do f; keys(f); end` to enumerate keys without loading data.
8. **AI Scientist v2 Experiment Manager pattern** (director.md §G): data-inventory-before-experiment is the standard precondition for falsifier design.
9. **Director.md §F1 Research stage** verbatim: "lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain". This T55 dispatch does exactly that, with the addition of a data-inventory layer because the data already exists.
10. **anko 2026-05-15 "Manuscript is NOT the essence"** — this advances D1 (verify existing physics: the BCH leak claim that the entire Option γ subsystem rests on, per `option_gamma_rotating_basis.md` line 37 load-bearing assertion). NOT manuscript polish.
11. **anko 2026-05-18 "Fix the class not the instance"** — applies to bug audits; the analogue for theory-verification is "verify the load-bearing claim, not the surface symptom". The Option γ memory line 37 BCH-leak claim is load-bearing for ~700 LOC; verifying it against actual sweep data IS the class-level move.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify existing physics). The Option γ subsystem (~700 LOC, 106+ tests) rests on the claim "Strang-splitting Larmor + transverse produces O(p·F·|Â|·dt²) errors that scale with the LARGE Larmor". T10 derived this in closed form but never empirically verified the scaling against numerical data. This is a Tier-2 → Tier-3 lift via cross-implementation evidence (φ̇ sweep at fixed p tests the time-dep term in the leak).
- **Tier ladder position**: tier_current=2, tier_target=3. T55 Research stage gates the Hypothesize → Design → Execute that pushes the tier. Closed-form derivation (Tier 2) is in hand; what's missing for Tier 3 is empirical scaling verification against the 8-point φ̇ sweep data + lab-frame head-to-head where feasible.
- **Manuscript NOT in scope**.
- **Cost frame**: researcher dispatch with bounded data inventory (16 jld2 files, enumerate keys + 1 representative metric per key) ≈ 300-500k effective tokens; well under per-turn 6M cap.
- **Drift signal forecast post-T55**: code_delta_zero=1 (researcher produces a report, no src/ edits expected; if researcher accidentally edits src/, that's a scope violation). manuscript_delta_zero=1 (expected). verdict_drift should be fine — researcher reports with §4 Metrics block.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "rationale": "klaus-bch-leak parked since T11 awaiting julia P3 validation; the eu151_klaus_phi_phys/ data exists (16 jld2 files across 8 φ̇ points, confirmed via pre-flight Glob), JULIA_GPU_OK is the active policy, and T54 closed audit-class-scan + judge-bug investigations clearing the active slot. Per T54 §6 'all PASS' routing, the natural T55 is a data-inventory researcher dispatch that maps the existing jld2 contents to P1/P2/P3 predictions in theorist/turn_10.md §2.9 — without this map, T56 theorist Hypothesize would be guesswork. Per `feedback_decision_style` single commitment per turn: this dispatch ONLY produces the inventory + falsifier-design spec, not an analysis script and not a julia run. The analysis script + run land at T56/T57.",
  "brief": "## ROLE\n\nYou are the researcher subagent. T55 §F1 Research stage of klaus-magnetostir-bch-leak-2026-05-13 (verify-claim flow). Data-inventory + falsifier-design-spec deliverable. NO julia execution this turn; NO src/ edits; NO new analysis scripts. Output is a researcher report at /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_55.md.\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_10.md` (full file, especially §2.4 / §2.5 / §2.9 — the P1/P2/P3 predictions are your verification targets).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_10.md` (T10 directive for context on what was/wasn't executed at T10).\n3. `/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/config.yaml` (the φ̇-sweep protocol).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 1363-1395 (the klaus-bch-leak investigation entry).\n5. Memory `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/option_gamma_rotating_basis.md` (treat as 20-day-old hint per system reminder; verify file:line claims against current code if you cite them).\n6. Memory `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/active_handoff.md` (lab-frame baseline context).\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_55.md` (this file — for context).\n\n## DELIVERABLE 1: jld2 data inventory\n\nFor each of the 8 phi values (1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0) inspect:\n- `/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_<X>/result.jld2`\n- `/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_<X>/point_001.jld2`\n- `/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_<X>/config.yaml`\n\nEnumerate top-level keys (and one level of nesting if meaningful) without loading full arrays. Use:\n```julia\nusing JLD2\njldopen(\"path/to/result.jld2\", \"r\") do f\n    for k in keys(f)\n        v = f[k]\n        sz = sizeof(v) > 1024*1024 ? \"$(round(sizeof(v)/1024/1024, digits=2)) MB\" : \"$(sizeof(v)) B\"\n        @info \"$k :: $(typeof(v)) :: $sz\"\n    end\nend\n```\n(or equivalent Python h5py for HDF5-backed jld2). If julia loading is needed, you may use `implementer_julia_cpu_light` budget — but prefer a single short julia script that prints the inventory to stdout; no long compilation. Acceptable: write `/tmp/klaus_inventory.jl` (≤ 30 LOC) and execute via `julia --project=/home/suzume/workspace/BEC-simulation /tmp/klaus_inventory.jl`. JIT cost ~30s for JLD2 first load.\n\nReport per file:\n- Top-level keys (e.g. `psi_final`, `Fz_history`, `Lz_history`, `t_history`, `params`, `norm_history`, ...).\n- For time-series keys: length + sample dt + total wall time covered.\n- For snapshot keys: number of snapshots + grid shape.\n- File size on disk.\n\n## DELIVERABLE 2: P1/P2/P3 testability matrix\n\nProduce a markdown table with columns:\n\n| Prediction (from theorist/turn_10.md §2.9) | Required observable | Available in existing jld2? | If yes, suggested test shape | If no, what's needed to test it |\n\nRows (at minimum):\n- **P1 term 1** (`dt²·p·F·sinθ·c_dd⟨n⟩` interaction-flanked leak) — requires lab-frame solver output for comparison; existing data is rotating_basis only.\n- **P1 term 2** (`dt²·φ̇·p·sinθ·F` time-dep leak) — testable from the φ̇ sweep IF the dataset shows φ̇-dependent drift in a quantity that SHOULD be conserved in the ideal Option γ limit (e.g., norm drift, or ⟨F_z+L_z⟩ conservation per EdH).\n- **P2 (Option γ dt-stability)** — directly testable: norm drift across the 8 points at fixed dt=0.001 should stay ≲ 10⁻¹⁰ if Option γ absorbs the leak as claimed.\n- **P3 (p-scaling)** — NOT testable from existing data (p is fixed at 26700 across all 8 points). Requires a fresh p-sweep run (e.g., {p=2670, 26700, 267000}).\n- **EdH conservation** (Berry-connection prediction from `option_gamma_rotating_basis.md` line 76 `edh_conservation` analyzer) — testable IF Fz_history + Lz_history are saved.\n\n## DELIVERABLE 3: falsifier-design spec for T56 theorist Hypothesize\n\nFor each P-prediction marked 'testable from existing data', propose a falsifier of the form:\n\n```\nfalsifier_id: <kebab-case-id>\nprediction: <one-line text>\nmeasurement: <which jld2 key(s) to read, what operation to apply>\nnull_hypothesis: <what value range counts as REFUTE>\nconfirm_hypothesis: <what value range counts as CONFIRM>\nestimated_julia_cost: <cpu_light / cpu_heavy / gpu>\nestimated_wall_time: <seconds>\n```\n\nAim for 2-4 falsifiers, each tightly bounded.\n\n## DELIVERABLE 4: literature anchor (one paragraph)\n\nFind ONE published reference for split-step BCH error analysis in spinor BEC or related context (Hatano-Suzuki splitting, Yoshida4 vs Strang error bounds, or Cohen-Tannoudji rotating-frame transformation). Cite by author+year+title. ≤ 5 min web search; if no direct hit in 5 min, cite a standard textbook reference (e.g., Hairer-Lubich-Wanner 'Geometric Numerical Integration' §III.4 on splitting methods for non-commuting operators) and move on. This is the §A6 research-first citation for T56's Hypothesize stage.\n\n## DELIVERABLE 5: researcher report at runs/_loop/research/turn_55.md\n\nStructure:\n\n```markdown\n---\nturn: 55\nsubagent: researcher\ninvestigation_id: klaus-magnetostir-bch-leak-2026-05-13\nstage: Research\n---\n\n# Turn 55 — klaus-bch-leak data inventory + falsifier-design spec\n\n## 1. Existing jld2 inventory\n\n[per-file table per Deliverable 1]\n\n## 2. P1/P2/P3 testability matrix\n\n[markdown table per Deliverable 2]\n\n## 3. Proposed falsifiers for T56 Hypothesize\n\n[2-4 falsifiers per Deliverable 3]\n\n## 4. Literature anchor\n\n[one paragraph + 1 citation per Deliverable 4]\n\n## 5. Recommendations for T56 director\n\n- Which falsifier to advance first (cheapest + sharpest).\n- Whether a fresh julia run is required (and if so, scope estimate).\n- Open questions for theorist to resolve at Hypothesize.\n\n## 6. Metrics\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"jld2_files_inventoried\": <N>,\n  \"jld2_files_loadable\": <N or fewer if any failed>,\n  \"yaml_configs_read\": <N>,\n  \"p_predictions_mapped\": 3,\n  \"falsifiers_proposed\": <2-4>,\n  \"literature_citations\": <≥1>,\n  \"investigation_id\": \"klaus-magnetostir-bch-leak-2026-05-13\",\n  \"stage_advancing_to\": \"Research\",\n  \"flow_template\": \"verify-claim\",\n  \"fresh_julia_run_required_for_p3\": true,\n  \"existing_data_sufficient_for_p2\": <true|false based on inventory>,\n  \"existing_data_sufficient_for_p1_term2\": <true|false based on inventory>\n}\n```\n```\n\nMUST be a single fenced ```json``` block parseable by judge.py.\n\n## CONSTRAINTS\n\n- **Files allowed to modify**:\n  - `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_55.md` (new — Deliverable 5).\n  - `/tmp/klaus_inventory.jl` (transient diagnostic script; ≤ 30 LOC; OK to leave behind for T56 reference).\n- **Do NOT modify**: `src/`, any `runs/eu151_*/` jld2 or config.yaml, `.claude/*`, any other `runs/_loop/` file. Read-only on the data + state files.\n- **No julia run beyond key-enumeration**: do NOT load full ψ̃ arrays into memory; do NOT compute observables this turn (T57 Execute stage's job). One short JLD2-enumeration script is acceptable.\n- **English only. No emojis.**\n- **Absolute paths in tool invocations.**\n- **Cost budget**: stay within ~500k effective tokens, ~10 min wall.\n- **Idempotence**: if research/turn_55.md already exists from a previous attempt, do NOT overwrite without first reading it.\n\n## SUCCESS CRITERIA\n\nThe §6 Metrics JSON block must report the integer/boolean values per the contract. judge.py will mechanically evaluate them.\n\nReport HONESTLY. If a jld2 file fails to load (corrupted, version-mismatched JLD2, etc.), report `jld2_files_loadable < jld2_files_inventoried` and document which failed and why. Do not fake success.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "jld2_files_inventoried",
      "jld2_files_loadable",
      "yaml_configs_read",
      "p_predictions_mapped",
      "falsifiers_proposed",
      "literature_citations",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "fresh_julia_run_required_for_p3",
      "existing_data_sufficient_for_p2",
      "existing_data_sufficient_for_p1_term2"
    ],
    "optional": [],
    "precondition_check": "ls /home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_*/result.jld2 | wc -l | xargs -I{} test {} -eq 8 && ls /home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/phi_*/config.yaml | wc -l | xargs -I{} test {} -eq 8 && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_10.md && echo 'precondition OK: 8 result.jld2 + 8 config.yaml + theorist/turn_10.md present'"
  },
  "success_criteria": [
    {
      "id": "report_produced",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "T55 is a researcher data-survey; no execution beyond key-enumeration."
    },
    {
      "id": "no_src_touch",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Researcher must not edit src/ during Research stage."
    },
    {
      "id": "jld2_inventory_complete",
      "metric": "jld2_files_inventoried",
      "operator": ">=",
      "value": 16,
      "tolerance": null,
      "rationale": "8 phi values × 2 jld2 per dir = 16 files minimum. Researcher should inventory all of them."
    },
    {
      "id": "jld2_load_success",
      "metric": "jld2_files_loadable",
      "operator": ">=",
      "value": 8,
      "tolerance": null,
      "rationale": "At minimum the 8 result.jld2 files (one per phi value) must load. point_001.jld2 may be redundant or in a different format; OK to skip if it duplicates result.jld2."
    },
    {
      "id": "yaml_configs_read",
      "metric": "yaml_configs_read",
      "operator": ">=",
      "value": 1,
      "tolerance": null,
      "rationale": "At minimum the top-level config.yaml must be read to confirm protocol parameters."
    },
    {
      "id": "p123_mapped",
      "metric": "p_predictions_mapped",
      "operator": "==",
      "value": 3,
      "tolerance": null,
      "rationale": "All three P1/P2/P3 predictions from theorist/turn_10.md §2.9 must appear in the testability matrix."
    },
    {
      "id": "falsifiers_proposed",
      "metric": "falsifiers_proposed",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "At least 2 concrete falsifiers (preferably 3-4) for T56 Hypothesize."
    },
    {
      "id": "lit_anchor_present",
      "metric": "literature_citations",
      "operator": ">=",
      "value": 1,
      "tolerance": null,
      "rationale": "At least 1 published reference for split-step BCH error analysis."
    },
    {
      "id": "investigation_id_consistent",
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
      "value": "Research",
      "tolerance": null,
      "rationale": "§F1 Research stage."
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
      "id": "p3_needs_fresh_run",
      "metric": "fresh_julia_run_required_for_p3",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Existing data is at fixed p=26700; P3 (p-scaling) cannot be tested without varying p — researcher must acknowledge this."
    },
    {
      "id": "no_analysis_scripts",
      "metric": "new_analysis_scripts_written",
      "operator": "<=",
      "value": 1,
      "tolerance": null,
      "rationale": "At most one transient /tmp/klaus_inventory.jl for key enumeration. T57 Execute stage produces the full analysis script."
    }
  ],
  "failure_modes": [
    {
      "if": "jld2_files_loadable < 8",
      "category": "data_gap",
      "next_action": "T56 director re-routes: if loadable jld2 < 4 the dataset is unusable and we need to spawn a fresh klaus rotating_basis run (implementer_julia_gpu, est ~30 min wall + JIT) to regenerate. If 4 <= loadable < 8, work with the subset and re-plan."
    },
    {
      "if": "p_predictions_mapped < 3 OR falsifiers_proposed < 2",
      "category": "operational",
      "next_action": "T56 director re-dispatches researcher with explicit pointer to theorist/turn_10.md §2.9 and the testability matrix template."
    },
    {
      "if": "existing_data_sufficient_for_p2 == false AND existing_data_sufficient_for_p1_term2 == false",
      "category": "data_gap",
      "next_action": "T56 director must dispatch implementer_julia_gpu to re-run the klaus protocol with an explicit `analyzers: [edh_conservation, population_dynamics, norm_drift_trace]` block to generate the missing observables. Estimate: ~30-45 min wall + first-time JIT for analyzer pipeline."
    },
    {
      "if": "src_files_modified > 0",
      "category": "scope_violation",
      "next_action": "T56 director reverts via git restore; researcher scope-discipline failure. Re-dispatch with stricter brief."
    },
    {
      "if": "new_analysis_scripts_written > 1",
      "category": "scope_violation",
      "next_action": "T56 director notes the scope-overshoot but proceeds — extra scripts at /tmp/ are not load-bearing. Re-dispatch with stricter brief next time."
    },
    {
      "if": "literature_citations < 1",
      "category": "operational",
      "next_action": "T56 director accepts but re-dispatches with explicit Hairer-Lubich-Wanner pointer for T56's Hypothesize lit anchor."
    },
    {
      "if": "all PASS",
      "category": "scientific_success",
      "next_action": "T56 director dispatches theorist Hypothesize stage with the researcher's falsifier-design spec as input. Theorist refines 1 falsifier (highest leverage: likely P2 norm-drift across the φ̇ sweep IF EdH conservation analyzer was already applied) into formal predicted signature + criteria. T57 implementer_julia_cpu_light writes the analysis script + Execute. T58 Analyze. T59 critic Update. T60 Document → close at tier 3 if P2 confirms within bounds OR REFUTE-and-revise if not. If researcher recommends a fresh julia run (no in-place observable), T56 may instead dispatch implementer_julia_gpu Design+Execute combined."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 800000,
    "wall_time_hard_cap_sec": 900
  },
  "budget": {
    "expected_cost_eff": 450000,
    "expected_wall_time_sec": 480,
    "split_by_subtask": {
      "read_required_files": 120000,
      "jld2_key_enumeration_julia_script": 80000,
      "yaml_configs_read": 30000,
      "build_testability_matrix": 80000,
      "literature_search": 60000,
      "write_research_report": 80000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Hypothesize (T56 theorist takes the falsifier-design spec and produces formal predicted signature + criteria)",
    "if_success_tier_becomes": 2.1,
    "if_refuted_advance_to_stage": "N/A — Research stage produces inventory, not REFUTED verdicts. Operational failures route per failure_modes.",
    "if_refuted_tier_becomes": "N/A",
    "next_falsifier_to_test_after": "P2-option-gamma-norm-drift-stability-across-phi-sweep (likely; researcher will confirm/refine in their §3)"
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_55.json` (policy=JULIA_GPU_OK; researcher in allowed_workloads; window 1,185,594s left; VRAM 12,969 MB free; foreign_julia=0).
- [x] Read `runs/_loop/state.json` partial (lines 1, 1292-1700 covering all investigation entries; T54 PASS confirmed; klaus-bch-leak blocked_on text confirmed; audit-class-scan + judge-bug closed).
- [x] Read `runs/_loop/seed.md` (priority order intact: barnett 1 CLOSED → yan-li-saito 2 dormant → klaus-bch-leak 3 blocked-on-julia; per anko T54 note klaus-bch-leak is now unblocked by JULIA_GPU_OK).
- [x] Read `runs/_loop/director/turn_54.md` end-to-end (T54 closed audit-class-scan + judge-bug; T55 routing prediction in failure_modes 'all PASS' branch named klaus-bch-leak jld2-data-survey as top candidate).
- [x] Read `runs/_loop/judge/turn_54.json` (18/18 criteria PASS).
- [x] Read `runs/_loop/sim/turn_54.md` (clean implementer execution; no scope violations; YAML/JSON validated post-edit).
- [x] Read `runs/_loop/theorist/turn_10.md` lines 1-280, 280-470 (full P1/P2/P3 predictions + §2.4 + §2.5 leak terms; convention block §0).
- [x] Read `runs/eu151_klaus_phi_phys/config.yaml` (8-point φ̇ zip sweep at fixed p=26700; rotating_basis backend gpu; save cadence 200/200/500).
- [x] Pre-flight Glob confirmed 16 jld2 files + 9 config.yaml files in eu151_klaus_phi_phys/ — data exists.
- [x] Recalled memory `option_gamma_rotating_basis.md` (load-bearing claim line 37 about Strang-splitting Larmor leak; 20-day-old caveat per system reminder — researcher must verify file:line claims against current code).
- [x] Recalled memory `active_handoff.md` (referenced via theorist/turn_10.md context).
- [x] Recalled memory `feedback_mechanical_vs_investigation_threshold.md` (data inventory is mechanical at this scope; the theory-verification cycle as a whole is investigation-grade — 3-second test passes for the inventory step but the multi-turn verify-claim flow is appropriate).
- [x] Recalled memory `feedback_decision_style.md` (single commitment per turn: T55 produces ONLY the inventory + falsifier-design spec; T56/T57 execute).
- [x] investigation_id `klaus-magnetostir-bch-leak-2026-05-13` valid in state.json `investigations` dict.
- [x] stage_advancing_to `Research` is the §F1 verify-claim entry stage; appropriate for re-opening a tier-2 investigation with a new falsifier target.
- [x] subagent_type `researcher` matches §F1 role_per_stage[Research].
- [x] success_criteria 13 criteria, all machine-evaluable (==, >=, <= operators on integers/booleans/strings).
- [x] failure_modes cover 7 outcomes including data_gap routing (loadable < 8 → fresh run) and success-routing to T56.
- [x] observable_manifest precondition_check runs ls/test/wc to verify 8 jld2 + 8 yaml + theorist/turn_10.md exist before researcher starts.
- [x] budget 450k expected, 800k tolerance; wall 8 min < 900s hard cap.
- [x] §A6 research-first citation present (11 references: theorist T10, director T10, T55 sim/director continuity, config.yaml, 2 memories, Anthropic context engineering, AI Scientist v2, director.md §F1, anko 2026-05-15, anko 2026-05-18).
- [x] §A5 D1-justified articulated: Option γ subsystem rests on load-bearing BCH-leak claim; verifying it against actual data is D1 verification-depth lift Tier 2 → Tier 3.
- [x] Considered alternative dispatches:
  - yan-li-saito R4 analytical revival: not anko-prioritized; deferred.
  - meta-stage-routing Observe→Hypothesize: held per T54 confounder_advisory until T58.
  - meta-critic-placement Hypothesize: priority 50; deferred.
  - audit-class-scan new cycle: not due (next ~T62).
  - klaus-bch-leak Execute directly (skip Research): rejected — without knowing what observables are in the jld2, Execute would be guesswork.
  - klaus-bch-leak Hypothesize directly: rejected — theorist would propose falsifiers that may not be testable from existing data.
  - **klaus-bch-leak Research data-inventory is highest leverage**: cheapest unblocker (~500k tokens), produces concrete falsifier-design spec for T56, anchors the multi-turn tier 2→3 push against existing data.
- [x] All file paths in brief are absolute.
- [x] Brief explicitly forbids src/ + analysis-script-creation beyond /tmp inventory + jld2/config modification.
- [x] research/turn_55.md §6 Metrics JSON block requirement specified to prevent T50-style FAIL_NO_METRICS.
- [x] Idempotence guard in brief (if research/turn_55.md exists, read first).
- [x] No conventional commits drafted this turn (researcher does not commit; T56-T60 implementer dispatches will).
- [x] T56 routing pre-planned in 'all PASS' branch: theorist Hypothesize with researcher's falsifier-design spec.
- [x] §F1 Research stage is the correct verify-claim entry; not skipping any stage.
- [x] No meta-meta investigation spawned (this is physics-class).
