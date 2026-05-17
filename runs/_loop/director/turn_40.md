---
turn: 40
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Update
stage_advancing_to: Design
topic_tags: [yan-li-saito-2026, design-stage, seed-basin-discriminator, sigma-sweep, fl-vortex-from-jld2, paper-fetch-parallel]
paper_section: null
depends_on: [39, 38, 37, "runs/_loop/judge/turn_39_critic_audit.md", "runs/_loop/sim/turn_37.md", "runs/_loop/judge/turn_37.json", "runs/_loop/director/turn_39.md", "runs/_loop/state.json (next_stage_action satisfied)", "runs/yan_li_saito_f1_torus_gs/config.yaml", "memory:yan_li_saito_2026_barnett_paper", "src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl:178-225 (from_jld2 path)"]
produces: "Theorist Design contract: seed-basin discriminator experiment for the falsified F1 reproduction. Primary axis = σ-sweep + fl_vortex topological seed (via from_jld2 hand-crafted JLD2). Predictions per σ value, success criteria for droplet formation vs delocalization, observable manifest, GPU-cost budget. Secondary axis = researcher paper-fetch dispatch for class (c) data-gap resolution (parallelizable / out of T40 main contract)."
---

# Turn 40 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.6 → tier_target 3). Continuing the same investigation as T36→T37→T38→T39 cycle.
- **Stage transition**: **Update → Design**. T39 critic returned `NARROWED-TO-2-CAUSES` verdict (primary: (b)+(a2) initial-state seed-basin disconnect; secondary: (c) paper-claim data-gap). Per state.json directive ("next-turn directive is NOT a fresh Hypothesize until critic narrows root cause to ≤2 candidates") — condition satisfied. Per §F1 verify-claim flow, post-Update with refined hypothesis space → Design.
- **Tier**: stays 0.6 entering Design. On Design success advancing to Execute with the σ-sweep discriminator: tier → 0.7. On Execute success showing droplet at small-σ or with fl_vortex topology: tier → 1.0 (root cause confirmed, framework gap documented).
- **Falsifiers tested/refuted**: F1 FALSIFIED at T37 (n_max=0.99 D_0 vs paper 13000 D_0). T39 critic root-cause narrowed: dominant cause = seed |ψ|²_peak (0.008) is 575× below droplet target (4.6) — seed lives in topologically + energetically disconnected basin.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed at Tier 3.0 at T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, documented): blocked_on julia P3 validation. Could unblock under JULIA_GPU_OK but priority 1 yan-li-saito owns this turn.
  - `fullbdg-f6-polar-3000x` (priority 99, dormant): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, kind=meta, Observe): observation pool now strong — T38 narrowed prematurely to 2 candidates, T39 explicitly told to broaden delivered 4 classes AND narrowed back to 2 with new diagnostics. This is a counter-example to the meta-hypothesis (critic placement was fine; the prompt scope was the lever, not the placement). Meta advances at T42+ after Design+Execute.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T37 | Execute | INCONCLUSIVE-by-null-artifact / SUBSTANTIVELY FALSIFIED | GPU ITP 87.9s; n_max=0.99 D_0 vs paper 13000 D_0 (factor 13000 deficit); m=+F=0.946; γ_LHY=12.8; ε_dd_eff=1.1772; energy_mu=NaN; norm drift 2.22e-16 (machine eps). F1 falsified by 4 orders of magnitude. |
| T38 | Update (critic) | CRITIC_PASS / `NEEDS-FURTHER-DISCRIMINATION` | Critic narrowed to 2 (Q5 HIGH, Q1 MEDIUM, Q2 RULED OUT); recommended Design with ε_dd-sweep + sympy. |
| T39 | Update (critic re-dispatch) | CRITIC_PASS / `NARROWED-TO-2-CAUSES` | 4-class enumeration: (a) framework bug → no active issue; (b) mapping mis-translation → DOMINANT (seed σ=2 has |ψ|²_peak 575× below droplet target 4.6); (c) paper-claim → DATA GAP (PDF permission-denied); (d) sibling schema bug → no active issue. Re-ranked (b)+(a2) seed-basin disconnect #1 HIGH; (c) paper-fetch needed; T38 Q1 LP-Q5 downgraded LOW (algebraically equiv to principal-branch Re). |

**T39 critic's structural argument (sim/turn_39_critic_audit.md §2(b))**:
- L₀ = a_s·N ≈ 14.4 a_ho. Paper droplet width scale ≈ 14 a_ho.
- Anko's seed σ = 2 a_ho. Seed is 7× narrower than target.
- Seed |ψ|²_peak ≈ 1/((2π)^(3/2)·σ³) ≈ 0.008. Target |ψ|²_peak = 13000/N ≈ 4.6 (per paper Fig 1c via memory anchor).
- **Seed density 575× SMALLER than droplet target**. At seed density, kinetic + repulsive contact dominate (1.45 vs LHY 0.009 vs DDI 0.5) → ITP spreads (delocalizes) instead of collapsing to droplet. This is EXACTLY what T37 observed.
- The seed lives in the wrong basin both topologically (no flux-closure structure) and energetically (wrong density scale).

**Strategic implication**: cheap σ-sweep gives multi-σ data points that discriminate seed-basin-cause (b) from any latent framework-cause (a) — if smaller σ produces droplet, (b) is confirmed and the rest of the framework is sound; if NO σ produces droplet, the framework has a deeper bug. Parallel: researcher fetches arXiv:2605.11670 to close (c) data gap.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Role for stage Design**: theorist or implementer per §F1 ("Design | theorist or implementer | observable manifest + experimental config + criteria for each falsifier").
- **Choice this turn = theorist** because:
  - The design is non-trivial: σ-sweep + fl_vortex topological seed + multiple density predictions per σ. The bookkeeping needs derivations (peak-density estimates, energy-balance arguments, droplet-formation criteria).
  - Implementer would produce a working config but not the *prediction table* that gives each σ a numerical expectation (droplet vs delocalized vs partial).
  - T19 precedent: theorist authored Barnett Design with falsifier table — same shape applies here.
- **Why Design now (vs other options)**:
  - **Why not Hypothesize**: state.json directive condition satisfied (critic narrowed to ≤2). Hypothesis is now sharpened, not redefined — the seed-basin-disconnect hypothesis IS the refined hypothesis, and Design encodes it as testable.
  - **Why not Execute directly**: skipping Design would commit GPU cycles without per-σ predictions, defeating the discriminator design. Need theorist to specify success/failure criteria per σ before running.
  - **Why not Document (close investigation)**: T39 critic explicitly says "Do NOT close investigation".
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito priority 1 owns this turn; we have a clear actionable next step.
  - **Why not switch to meta (priority 50)**: meta picks up after Update closes. Currently mid-cycle; meta-observation pool grows passively (T39 outcome is data for the meta-hypothesis: critic-prompt scope > critic placement, weakening the meta-hypothesis).
  - **Why not noop**: clear actionable directive, well-narrowed root cause, GPU available, cheap discriminator possible.

## 4. Research grounding (§A6)

**External references (load-bearing for the Design dispatch)**:

1. **Yan-Li-Saito 2026 PRL (arXiv:2605.11670)** memory lines 70-72: paper Methods uses "phase imprint exp(iℓφ) + L_z-conserving relaxation" for the ℓ=1 rotating state. Memory lines 99-101 explicitly flag that state_zoo lacks `init_psi_vortex(ℓ=1)` or torus builder — this is the framework gap mapped in T39 critic's (a2) sub-candidate. The hand-crafted JLD2 + `from_jld2` path (ground_state.jl:178-225) is the lever to inject a topologically nontrivial initial state without writing a new state_zoo builder.

2. **T39 critic audit §2(b) — quantitative seed-density argument**: |ψ|²_peak 575× gap is structurally explanatory; the seed-basin discriminator is the canonical falsifier.

3. **AI Scientist v2 (Lu et al. 2024) Experiment Manager Agent — director.md §G**: post-falsification root-cause confirmation by *cheap multi-axis discriminator before expensive single-point retry*. σ-sweep across 3-4 values + 1 fl_vortex jld2 ≈ same GPU cost (4 × 88s = ~6 min) as the single T37 run — multi-axis-cheap is the canonical Design move.

4. **arXiv:2604.12198 (grounded autonomous research, director.md §G)**: "REFUTED is a science success when documented". If σ-sweep shows NO σ produces droplet (i.e., (b) is REFUTED), this is still a scientific success — it would force (a4) deep framework bug OR (c) paper-claim REFUTED. Both are tier-1+ findings.

5. **Reflexion (Shinn et al. NeurIPS 2023)**: T39 critic broadened root-cause space → narrowed via cheap diagnostics; this turn's Design encodes the cheap discriminator at the experimental level. Verbal critique cycle has converged; physics experiment now arbitrates.

6. **Memory `feedback_manuscript_is_not_the_essence.md`**: real bug-finding in production code IS the essence. The σ-sweep discriminator distinguishes (b) "config-level seed mismatch" from (a) "framework can't produce droplet at any seed" — either outcome is a real finding.

7. **`src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl:178-225`**: `from_jld2` short-circuit path verified to exist; supports loading hand-crafted ψ_init. Avoids needing to extend state_zoo this turn.

8. **`runs/_loop/judge/turn_39_critic_audit.md` §4 Recommended T40 stage**: critic explicitly recommended Design with σ-sweep + fl_vortex; T40 director honors and operationalizes the recommendation.

9. **director.md §F1 Design row**: theorist or implementer authors observable manifest + experimental config + criteria for each falsifier. Theorist chosen for per-σ prediction-table specificity.

10. **director.md §B2 scheduler-aware design**: scheduler JULIA_GPU_OK, window 20000+ min left, VRAM 12.7 GB free; design includes GPU Execute cost ≤ 6M effective per anko cost_cap_per_turn_effective.

11. **Drift advisories from T39**: `DRIFT_MANUSCRIPT_DELTA_ZERO` (ignore per `feedback_manuscript_is_not_the_essence`), `DRIFT_COST_INFLATION` (cost_inflation = 1.032 — Design stage should be theorist text-only, ~2M effective, well within budget).

**Why these inform the dispatch**: AI Scientist v2 + Reflexion + grounded autonomous research converge on "after refutation, design the cheap multi-axis discriminator". The from_jld2 path provides the topological-seed lever without state_zoo extension. T39 critic's recommendation IS the canonical next step. Theorist is the right role for prediction-table authoring; implementer authors the running config after theorist locks predictions.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics). Design stage encodes the seed-basin discriminator that closes T39's narrowed-to-2 root-cause space. Successful Execute at T41 confirms (b) and moves the investigation to tier 1.0; null Execute escalates to (a) framework deep-bug OR (c) paper-claim REFUTED — all tier-1+ outcomes.
- **D2 SERVICE**: implicit. If σ=0.5 succeeds, this validates the rotating_basis ITP for free-space dipolar droplets — a service finding that downstream Eu F=6 + Yan-Li-Saito-extension work can build on.
- **D3 NOT advanced this turn** (lit-grounded new theory). Design is verification-shaped.
- **Tier ladder position**: 0.6 (after T39 Update) → 0.7 (after T40 Design dispatch) → 1.0+ (after T41 Execute + Analyze). Tier-3 path preserved.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. T40 delivers theorist Design only.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Design",
  "subagent_type": "theorist",
  "rationale": "T39 critic Update-redispatch returned NARROWED-TO-2-CAUSES verdict: primary cause = initial-state seed-basin disconnect (b)+(a2) (|ψ|²_peak 575× gap between σ=2 Gaussian seed and droplet target); secondary = (c) paper-claim data gap (PDF permission-denied, parallelizable). State.json directive condition satisfied (critic narrowed to ≤2). Per §F1 verify-claim flow, Update → Design. Theorist authors the σ-sweep + fl_vortex topological-seed discriminator with per-σ prediction table and criteria for each outcome (droplet / partial / delocalized). The `from_jld2` path at ground_state.jl:178-225 is the lever for topologically-nontrivial seed injection without state_zoo extension. AI Scientist v2 + Reflexion + grounded-autonomous-research jointly endorse 'cheap multi-axis discriminator after refutation'. Cost: theorist ~2M effective; downstream T41 Execute ≤ 6M effective (4 × 88s GPU). Drift signal DRIFT_COST_INFLATION respected by keeping Design at text-only theorist (no GPU this turn).",
  "brief": "Author a Design contract for the seed-basin discriminator experiment on yan-li-saito-2026-reproduction. T39 critic (runs/_loop/judge/turn_39_critic_audit.md) narrowed the root-cause space for the T37 falsification (n_max=0.99 D₀ vs paper 13000 D₀, factor 13000 deficit) to:\n  - (b)+(a2) initial-state seed-basin disconnect (HIGH; the σ=2 Gaussian seed has |ψ|²_peak ≈ 0.008, paper droplet has |ψ|²_peak ≈ 4.6 — a 575× gap, plus topology mismatch: spherical Gaussian vs flux-closure torus).\n  - (c) paper-claim wrong (LOW-MEDIUM data gap — PDF was permission-denied at T39).\n\nYour job: design the cheapest experiment that DISCRIMINATES between (b) and 'something deeper (a/c)' using GPU ≤ 6M effective.\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_39_critic_audit.md` end-to-end — especially §2(b) cross-reference table, §2(b) 575× density-gap argument, §3 re-ranking, §4 T40 recommendation.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_37.md` — T37 result: γ_LHY=12.8, n_max=0.99 D₀, m=+F=0.946, energy_mu=NaN, ε_dd_eff=1.1772, 5000 ITP steps, 87.9s GPU.\n3. `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml` — the existing config. Your Design should specify how to vary it (NOT modify it directly).\n4. `/home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl` lines 178-225 — `from_jld2` short-circuit path. This is your lever for topologically-nontrivial seed injection without writing a state_zoo builder this session.\n5. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` lines 55-82 (anchor numbers) + lines 66-72 (paper Methods: dx≈10⁻³ ≈ 16 nm ≈ 0.014 a_ho; dt≈10⁻⁷; phase imprint for ℓ=1).\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_39.md` — directorial context for the re-dispatch chain.\n7. (optional) `/home/suzume/workspace/BEC-simulation/src/workflow/initialization/state_zoo.jl` — view fl_vortex builder if it exists in non-rotating_basis path; you can reference it for the hand-crafted JLD2 shape, but DO NOT call for a state_zoo extension this turn.\n\n## DELIVERABLE: Write `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_40.md`\n\n### §1 Hypothesis (sharpened from T39 critic verdict)\n\nState the seed-basin-disconnect hypothesis precisely. Cite T39 critic's quantitative argument. Distinguish (b) seed-density-too-low from (a2) topology-mismatch as orthogonal axes.\n\n### §2 Discriminator design — σ-sweep + topological-seed axes\n\nDesign a 4-5 point experiment varying along TWO axes:\n\n**Axis 1 — seed width σ** (cheapest, single config-knob change):\n- σ_baseline = 2.0 a_ho (T37 = control / known-delocalized).\n- σ_compact = 0.5 a_ho (peak density ~64× higher; tests density-basin axis alone).\n- σ_matched = 5.0 a_ho (intermediate; tests whether monotonic in σ).\n- σ_wide = 14.0 a_ho (peak density LOWER than baseline but matches droplet WIDTH scale; tests width-vs-density tradeoff).\n\n**Axis 2 — topology** (1 additional point):\n- Hand-crafted JLD2 flux-closure torus seed at compact peak density. Specify: torus minor radius r_t, major radius R_t, spin texture (flux-closure: f(r)/ρ(r) = ê_φ × ẑ at each cylindrical-φ slice ≡ in-plane spin winding ±1 around z-axis), peak density target |ψ|²_peak ≈ 1-5 (within order of magnitude of paper).\n- Lever: produce a jld2 file path; config uses `initial_state: from_jld2` with `init_state_params.path: ...`. Specify the **schema** the jld2 must have (this turn: text-only; T41 implementer materializes the jld2).\n\nMinimum: provide a **prediction table** of expected outcome per (σ, topology) point:\n\n| Point | σ | topology | predicted n_max [D₀] | predicted m=+F | predicted energy_mu | verdict if observed |\n|---|---|---|---|---|---|---|\n| P0 (T37 control) | 2.0 | Gaussian | ~1 (replicates T37) | ~0.95 | NaN | seed-disconnect confirmed if matches T37 |\n| P1 | 0.5 | Gaussian | ? | ? | ? | (b) confirmed if droplet forms; framework deeper-bug suspected if not |\n| P2 | 5.0 | Gaussian | ? | ? | ? | tests monotonic in σ |\n| P3 | 14.0 | Gaussian | ? | ? | ? | tests width-vs-density |\n| P4 | (~3 minor, ~7 major) | fl_vortex jld2 | ? | ? | ? | (a2) topology-axis tested |\n\nFor each '?', derive your best a-priori estimate from energy-balance arguments (kinetic 1/(4σ²) + contact c0·|ψ|² + LHY γ·|ψ|³ + DDI). Cite the relevant terms; numbers go in the table.\n\n### §3 Observable manifest\n\nMandatory observables (must be saved per run):\n- `n_max` (peak density in D₀ units, i.e. divided by 1/(a_s³ N²)).\n- `m_population` per component (3 m-states for F=1).\n- `energy_total`, `energy_kinetic`, `energy_contact`, `energy_LHY`, `energy_DDI`, `energy_chemical_potential` (energy_mu was NaN at T37; track per-piece breakdown to localize).\n- `density_profile` (1D radial slice).\n- `spin_density` (⟨f_x⟩, ⟨f_y⟩, ⟨f_z⟩ per voxel) — critical for fl_vortex topology check.\n- `norm` (drift sanity).\n\n### §4 Success/failure criteria PER point\n\nDefine machine-evaluable criteria. Example structure:\n- P1 (σ=0.5) PASS iff n_max ∈ [100, 50000] D₀ AND norm ∈ [0.99, 1.01] (droplet-class signature). Fail iff n_max < 10 D₀ (still delocalized).\n- P4 (fl_vortex) PASS iff n_max ∈ [100, 50000] D₀ AND spin texture preserves flux-closure (⟨f_z⟩ < 0.1·⟨f_total⟩ on-axis) after ITP convergence.\n- All points: norm drift ≤ 1e-3, energy_mu finite (T37 had energy_mu=NaN — flag if recurs).\n\n### §5 Cost estimate\n\n- 4 GPU runs × 88s = 352s = 6 min wall (matches T37 single-run cost).\n- 1 JLD2 fabrication script (julia_cpu_light): ~30s wall, ~0.5M effective.\n- 1 analyze step (text-only metrics extraction): ~0.5M effective.\n- Total Execute+Analyze: ≤ 5-6M effective. Within cost_cap_per_turn_effective (6M).\n\n### §6 Verdict matrix (T41+ routing)\n\n| P1 outcome | P4 outcome | Implied root cause | T41 routing |\n|---|---|---|---|\n| droplet (PASS) | droplet (PASS) | (b) seed-basin disconnect confirmed; both density and topology contribute | Analyze → Update → Document; tier 0.6 → 1.0; possibly close investigation as 'verified at F=1 with corrected seed'. |\n| droplet (PASS) | delocalized (FAIL) | (b) density-axis dominates; (a2) topology not the issue | Same as above but flag topology-as-non-issue for future work. |\n| delocalized (FAIL) | droplet (PASS) | (a2) topology dominates; density-axis insufficient | Document framework gap; spawn fix-bug for fl_vortex state_zoo builder (D2). |\n| delocalized (FAIL) | delocalized (FAIL) | (b)/(a2) both refuted; either (a4) framework deep-bug (F=1 path) or (c) paper-claim-wrong | Spawn deep-framework-audit OR researcher PDF-fetch with anko ratification path. Tier stays 0.6. |\n\n### §7 Out-of-scope (do NOT do this turn)\n\n- DO NOT write julia code.\n- DO NOT run julia.\n- DO NOT modify config.yaml or src/.\n- DO NOT extend state_zoo this turn (use from_jld2 lever instead).\n- DO NOT design the paper-fetch researcher dispatch (director will spawn that as a parallel side-dispatch if needed).\n- DO NOT close the investigation.\n- DO NOT lobby for a specific outcome — design the experiment that distinguishes the possibilities cleanly.\n\n### §8 Metrics block\n\nReport at the bottom of turn_40.md (JSON block) the following machine-readable fields for judge.py:\n- `four_or_five_point_design`: true if Design has ≥4 (σ, topology) points enumerated.\n- `prediction_table_present`: true if per-point predicted n_max + m_pop + verdict-rule present.\n- `from_jld2_seed_path_specified`: true if §2(P4) includes the jld2 schema for fl_vortex injection.\n- `observable_manifest_complete`: true if §3 lists n_max, energy breakdown, spin_density, density_profile, norm.\n- `success_criteria_per_point`: true if §4 has machine-evaluable criteria per point.\n- `t41_routing_matrix`: true if §6 has the 4-cell verdict matrix.\n- `cost_within_budget`: true if §5 estimates Execute+Analyze ≤ 6M effective.\n\n## STYLE\n\n- Energy-balance arguments > prose. Per-point predicted n_max should derive from terms in Eq 1 with explicit numbers.\n- Pick the cheapest discriminator that closes the (b) vs (a)/(c) gap. 5 points × 88s GPU is fine; 10 points is overkill.\n- Lock the from_jld2 schema down (what fields, what dtype, what shape) so T41 implementer can materialize the jld2 in <30s wall.\n- If you find a flaw in T39 critic's argument (e.g. you compute |ψ|²_peak differently), DOCUMENT and disagree — the truth matters more than continuity.\n- Cost-conscious: stay text-only; no julia, no sympy.",
  "observable_manifest": {
    "required": [
      "theorist_turn_40_md_exists_on_disk",
      "theorist_turn_40_metrics_block_present",
      "four_or_five_point_design",
      "prediction_table_present",
      "from_jld2_seed_path_specified",
      "observable_manifest_complete",
      "success_criteria_per_point",
      "t41_routing_matrix",
      "cost_within_budget"
    ],
    "optional": [
      "energy_balance_derivation_present",
      "disagreement_with_T39_critic_noted_if_any",
      "fl_vortex_schema_specified",
      "alternative_topology_seed_proposed"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_39_critic_audit.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_37.md && test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && test -f /home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl && grep -q 'NARROWED-TO-2-CAUSES' /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_39_critic_audit.md && grep -q 'from_jld2' /home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl && echo 'precondition OK: T39 critic narrowed-to-2 + T37 sim + config.yaml + ground_state.jl from_jld2 path all on disk'"
  },
  "success_criteria": [
    {
      "id": "theorist_md_on_disk",
      "metric": "theorist_turn_40_md_exists_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required."
    },
    {
      "id": "theorist_metrics_present",
      "metric": "theorist_turn_40_metrics_block_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "§8 metrics block must exist and parse — judge.py reads metrics from it."
    },
    {
      "id": "multi_point_design",
      "metric": "four_or_five_point_design",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "≥4 (σ, topology) points required for the discriminator to distinguish (b) seed-basin from (a)/(c) deeper causes — single point is what T37 was, which is exactly what failed to discriminate."
    },
    {
      "id": "predictions_present",
      "metric": "prediction_table_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Per-point predicted n_max + m-population + verdict rule mandatory; otherwise Execute can't be machine-evaluated against design intent."
    },
    {
      "id": "jld2_lever_specified",
      "metric": "from_jld2_seed_path_specified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Topology axis (P4) requires hand-crafted JLD2; schema must be locked this turn so T41 implementer materializes it in <30s wall."
    },
    {
      "id": "observables_complete",
      "metric": "observable_manifest_complete",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "T37 had energy_mu=NaN; missing energy breakdown blocked root-cause localization. T41 must save full breakdown."
    },
    {
      "id": "criteria_per_point",
      "metric": "success_criteria_per_point",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Machine-evaluable criteria per point required for judge.py + Analyze stage."
    },
    {
      "id": "routing_matrix",
      "metric": "t41_routing_matrix",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Verdict matrix maps Execute outcome → T42 routing (Analyze, Document, fix-bug spawn, anko-ratification) — required for declarative downstream decisions."
    },
    {
      "id": "budget_OK",
      "metric": "cost_within_budget",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Execute+Analyze must fit ≤ 6M effective per-turn cap; design should not propose unrealistic GPU sweep."
    }
  ],
  "failure_modes": [
    {
      "if": "theorist_md_on_disk failed OR theorist_metrics_present failed",
      "category": "operational",
      "next_action": "T41 = re-dispatch theorist with stricter schema. If 2nd attempt fails, escalate to anko (subagent infrastructure problem)."
    },
    {
      "if": "multi_point_design failed OR predictions_present failed",
      "category": "framework_error",
      "next_action": "T41 = re-dispatch theorist with explicit '4+ points + prediction-table-numbers-with-derivation' framing. Log as meta-observation: theorist sometimes returns text without quantitative predictions despite explicit ask."
    },
    {
      "if": "jld2_lever_specified failed AND otherwise PASS",
      "category": "data_gap",
      "next_action": "T41 = Execute σ-sweep without fl_vortex topology axis (Axis 1 only, 4 points). Skip P4. Document gap; if σ-sweep ALL FAIL, T42 = re-dispatch theorist for jld2 schema OR spawn fl_vortex state_zoo extension as separate D2 investigation."
    },
    {
      "if": "cost_within_budget failed (Design exceeds 6M)",
      "category": "operational",
      "next_action": "T41 = re-dispatch theorist with budget cut: reduce to 3 points (P0 control, P1 σ=0.5, P4 fl_vortex)."
    },
    {
      "if": "Design PASS AND T41 Execute shows P1 droplet AND P4 droplet",
      "category": "scientific_corroborated",
      "next_action": "T42 = Analyze (implementer extracts droplet metrics) → T43 = Update (critic confirms (b) root cause) → T44 = Document (memory entry + fl_vortex state_zoo extension proposal). Tier 0.6 → 1.0 → 1.5."
    },
    {
      "if": "Design PASS AND T41 Execute shows ALL POINTS delocalized",
      "category": "scientific_refuted",
      "next_action": "T42 = Update (critic) — (b) REFUTED, hypothesis space collapses to (a4) framework deep-bug OR (c) paper-claim-wrong. T43 = parallel dispatch: researcher PDF fetch arXiv:2605.11670 + theorist deep-audit of F=1 rotating_basis ITP code path. Tier stays 0.6 until one of those resolves."
    },
    {
      "if": "Design PASS AND T41 Execute shows mixed (some droplet, some not)",
      "category": "scientific_partial",
      "next_action": "T42 = Analyze + Update; identify the boundary in (σ, topology) space; spawn a Tier-1.0 documented finding 'seed-basin transition at σ_c ≈ X'. Tier 0.6 → 0.9. Possibly schedule single-point T43 Execute closer to the boundary."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000
  },
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "read_required_files_7": 400000,
      "energy_balance_derivation_per_point": 500000,
      "prediction_table_4_5_points": 400000,
      "jld2_schema_specification": 200000,
      "criteria_and_routing_matrix": 200000,
      "write_theorist_turn_40_md": 100000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Execute",
    "if_success_tier_becomes": 0.7,
    "if_success_falsifier_update": "T40 theorist Design: σ-sweep (P0 σ=2 control, P1 σ=0.5, P2 σ=5, P3 σ=14) + topology axis (P4 fl_vortex from_jld2). Predictions per point derived from energy-balance. Routing matrix locks T41 Execute and T42 routing per outcome cell. F1 falsifier status: 'tested-and-refuted; T40 Design encodes the seed-basin discriminator; T41 Execute will determine whether (b) seed-basin is confirmed, refuted, or partial'. Tier moves 0.6 → 0.7 (Design locked in). On Execute success at T41 with droplet at P1 or P4: tier → 1.0 → 1.5 (root cause confirmed at lit-grounded discriminator).",
    "if_refuted_advance_to_stage": "Hypothesize (retry with reduced scope)",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "T41 implementer_julia_gpu executes the 4-5 point Design under the from_jld2 lever; spawns parallel researcher dispatch at T42+ if (c) data-gap blocking. Meta-critic-placement (priority 50) gathers passive observation but does not advance this turn — current evidence (T38 narrowed prematurely → T39 broadened explicitly → re-narrowed cleanly with new diagnostics) is a partial *counter*-example to the meta-hypothesis (suggests critic-prompt scope > critic placement). Re-evaluate meta at T44+."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_40.json` (policy=JULIA_GPU_OK; theorist in allowed_workloads; window 20118 min left; VRAM 12.7 GB free; no resource constraints).
- [x] Read `runs/_loop/state.json` end-to-end including history T35-T39 + next_stage_action directive (condition satisfied: critic narrowed to 2). T39 entry: judge_status CRITIC_PASS, label `yan-li-saito-T38-4hypothesis-redispatch-narrowed-to-2`, drift advisories DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_COST_INFLATION.
- [x] Read `runs/_loop/seed.md` (yan-li-saito priority 1; first Tier-3 candidate path).
- [x] Read `runs/_loop/director/turn_39.md` end-to-end (prior turn's dispatch and structure).
- [x] Read `runs/_loop/judge/turn_39_critic_audit.md` end-to-end (T39 critic 4-class enumeration + narrowing to (b)+(a2) primary + (c) data-gap secondary).
- [x] Read `runs/_loop/sim/turn_37.md` end-to-end (T37 substantive falsification).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` (paper Eq 1, anchor numbers, likely failure modes, framework gaps).
- [x] Read `runs/yan_li_saito_f1_torus_gs/config.yaml` (init_sigma=2.0 line 48 — the dominant seed-basin issue).
- [x] Grep'd `src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl` for `from_jld2` — verified path exists at lines 178-225 (the lever for topological seed injection without state_zoo extension).
- [x] investigation_id `yan-li-saito-2026-reproduction` valid in state.investigations.
- [x] stage_advancing_to=Design is the canonical move per §F1 verify-claim after Update with narrowed root-cause space. State.json directive condition (critic narrowed to ≤2) IS satisfied.
- [x] subagent_type=theorist matches §F1 Design row ("theorist or implementer"); theorist chosen for prediction-table authoring.
- [x] success_criteria are machine-evaluable: 9 criteria covering file-existence, metrics block, multi-point design, prediction table, jld2 schema, observable completeness, per-point criteria, routing matrix, cost budget.
- [x] failure_modes cover 7 scenarios: operational (no md / no metrics), design-incomplete (no predictions / no jld2 / over-budget), and 3 Execute-outcome routing scenarios (corroborated / refuted / partial).
- [x] observable_manifest precondition_check is literal bash chain (5 test -f + 2 grep checks) that exits 0 before theorist invocation.
- [x] Budget 1.8M effective + 10-min wall fits within scheduler window + cost_cap_per_turn_effective (6M). Quota healthy. Tolerance_overrides set tighter cost_cap (3M) for this text-only Design stage.
- [x] §A6 research-first citations: Yan-Li-Saito paper memory, T39 critic audit, AI Scientist v2, Reflexion, arXiv:2604.12198, `feedback_manuscript_is_not_the_essence.md`, ground_state.jl from_jld2 path, T39 critic §4 recommendation, director.md §F1 + §B2.
- [x] §A5 D1 PRIMARY articulated (Design encodes the seed-basin discriminator that closes the T39-narrowed root-cause space); D2 service implicit; manuscript NOT primary.
- [x] investigation_update has explicit success/refute branches and per-Execute-outcome T42 routing.
- [x] Considered switching to klaus-bch-leak (priority 3): rejected — yan-li-saito priority 1 + clear actionable next step.
- [x] Considered switching to meta-critic-placement (priority 50): rejected per §B2 interleaving rule; meta picks up after Design+Execute closes. The T38→T39 sequence is partial counter-evidence to the meta-hypothesis (prompt scope > placement), informing T44+ re-evaluation.
- [x] Considered NOOP: rejected — clear actionable directive; theorist is text-only and cheap (1.8M); GPU window 20118 min left.
- [x] Considered Execute directly (skip Design): rejected — without per-σ predictions, Execute is not a discriminator; T39 critic explicitly recommended Design.
- [x] Considered Hypothesize: rejected — state.json directive condition satisfied; hypothesis is sharpened, not redefined.
- [x] Honored T39 critic's §4 recommendation: Design with seed-basin discriminator as primary falsifier.
- [x] `consumed_seed_md: false` — same investigation, not a new seed entry.
- [x] Drift advisory DRIFT_COST_INFLATION respected: this turn is theorist text-only (~1.8M); cost-tight Design before committing GPU at T41.
