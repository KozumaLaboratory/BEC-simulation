---
turn: 43
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Hypothesize
stage_advancing_to: Design
topic_tags: [yan-li-saito-2026, grid-refinement-experiment, dx-scaling-prediction, theorist-design, free-space-itp-f1, rotating-basis-f1, gpu-budget-discipline]
paper_section: null
depends_on: [42, 41, 40, 37, "runs/_loop/judge/turn_42_critic_audit.md", "runs/_loop/research/turn_41.md", "runs/_loop/sim/turn_40.md", "runs/_loop/theorist/turn_40.md", "runs/_loop/director/turn_42.md", "runs/_loop/state.json (investigations.yan-li-saito-2026-reproduction)", "runs/yan_li_saito_f1_torus_gs/config.yaml", "runs/_loop/templates/yan_li_saito_f1_droplet.yaml", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Theorist Hypothesize+Design output: a formal scaling-prediction hypothesis (n_peak as a function of dx for our underresolved free-space ITP, predicting how density should recover under grid refinement), plus a concrete 3-point grid-refinement YAML config sketch (start from runs/_loop/templates/yan_li_saito_f1_droplet.yaml and patch deltas only). Falsifier criteria for the next Execute stage."
---

# Turn 43 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.8 → tier_target 3). Continuing the T37 → T38 → T39 → T40 → T41 → T42 cascade.
- **Stage transition**: **Hypothesize → Design** (per state.json `current_stage: "Hypothesize"` left by T42 critic; §F1 verify-claim sequence: Update-CORROBORATE on the dx-ratio hypothesis means we now have a refined working hypothesis that needs a Design contract before Execute). Theorist combines hypothesis formalization (scaling prediction) and experiment design (YAML config + observable manifest) since the critic's R1 routing recommendation already specifies both.
- **Tier**: stays 0.8 entering Design. On theorist PASS (clean scaling prediction + executable YAML deltas patched against the template): tier 0.8 → 0.85 (Design stage doesn't change tier substantively; tier moves at Execute/Update with empirical data).
- **Falsifiers tested/refuted (yan-li-saito)**:
  - `f1-direct-reproduction` T37 FALSIFIED. T40 5-point seed/topology discriminator REFUTED (b) density-axis + (a2) topology-axis. T41 closed (c) data-gap on Fig 1c F-identity. T42 CORROBORATEd grid-resolution gap (Section A independent dx-ratio + droplet-cell-count arithmetic, both consistent within factor 2.3) AND closed DDI prefactor bit-equal (Section B; ratio = 1 exact, our `c_dd/2 × (k̂_z² − 1/3)` Fourier kernel equals paper's `μ₀(gμ_B)²/8π × (1 − 3cos²θ)/r³` real-space after FT identity, the 4π and 1/2 cancel cleanly). T42 DISMISSED χ(1.2) as negligible (Section C; estimate 3.5–3.7 matching LP-2011 Fig 1) and accepted Q2 initial-state as sufficient/secondary (Section D).
  - **NEW falsifier to spawn at T43**: `dx-refinement-scaling` — predict n_peak(dx) follows roughly (0.4375/dx)^α with α ∈ [2.5, 3.0] from critic Section E, with concrete numerical targets at dx ∈ {0.08, 0.04, 0.02} a_ho. T44 Execute tests this against actual GPU runs.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed at Tier 3.0.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, documented): blocked on julia P3 validation against anko Klaus phi sweep data — could unblock under JULIA_GPU_OK, but priority 1 owns cascade.
  - `fullbdg-f6-polar-3000x` (priority 99, dormant): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, kind=meta, Observe): T42 critic Section E adds another data point ("researchers can produce PARTIAL quantitative closures that need a critic with algebra-execution to convert into bit-equal; alternative is requiring researchers to produce closed expressions"). Observation pool now T37→T42 (6 turns). Re-evaluate at T46+ when this cascade closes.
  - `meta-internal-b-unification-2026-05-18` (priority 5, kind=meta): CLOSED.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T40 | Design+Execute (theorist+implementer chained) | INCONCLUSIVE-shape / SUBSTANTIVELY REFUTED | Theorist E_DDI=0-for-isotropic-Gaussian derivation predicted all σ-axis points delocalize. Implementer ran 5-pt GPU ITP (P0–P3 σ ∈ {0.5,2,5,14}, P4 fl_vortex JLD2 torus). All n_max ∈ [0.21, 1.06] D₀ vs paper 13000. (b) density-basin + (a2) topology REFUTED. Verdict matrix row 4 → (a4) framework deep bug OR (c) paper-wrong OR (a1) LHY issue. |
| T41 | Research (researcher HTML fetch arXiv:2605.11670) | RESEARCHER_ONLY / Q1 RESOLVED + Q2/Q3 PARTIAL | Fig 1c IS F=1. Paper uses plain free-space ITP, no L_z constraint, dx ≃ 10⁻³ in L₀ units (= 16.35 nm physical = 315 a₀ = 0.0144 a_ho when comparing to our framework). Predicted density gap (30.4)³ ≈ 28000× vs observed 12000× — within factor 2. DDI prefactor "consistent when 4π tracked" (left algebraically open). |
| T42 | Update (critic independent audit) | CRITIC_PASS / CORROBORATE-grid + CLOSED-bit-equal-DDI | Section A CORROBORATE: dx-ratio 30.36 (independent), droplet-cell-count argument (3.2 our cells vs 97 paper cells across droplet) is the stronger geometric chain. Section B CORROBORATE: Fourier algebra closes paper vs SpinorBEC E_ddi to ratio = 1 exact; (a1) LHY/DDI prefactor bug STAYS DEAD. Section C DISMISSED: χ(1.2) ≈ 3.68 (trapezoid) ≈ 3.5 (LP-2011 Fig 1). Section D sufficient. Section E recommends R1 (theorist Hypothesize/Design grid-refinement at dx ∈ {0.08, 0.04, 0.02} a_ho). Tier 0.6 → 0.8. |

**Strategic implication for T43**:

T42 critic delivered a clean, quantitative narrowing. The next-stage action set on state.json by the T42 critic dispatch (per turn_42 §6 `investigation_update.next_falsifier_to_test_after`) is: "T43 = theorist Hypothesize/Design grid-refinement". This is exactly the R1 path from critic Section E. Theorist's job at T43:

1. **Formalize the scaling prediction**: critic stated "(0.4375/dx)^α with α ∈ [2.5, 3.0]" as a heuristic. Theorist must derive a SHARPER prediction by reasoning about the actual physical mechanism. Two competing predictions:
   - (A) **Trivial volumetric scaling**: if the simulation is finding the same delocalized solution at all dx, n_max(dx) ≈ N/V_box = 15000/(box × a_ho)³, where box is roughly fixed in physical units; refining dx doesn't change n_max — REFUTES grid hypothesis.
   - (B) **Droplet-nucleation scaling**: if the droplet basin becomes accessible only when dx < r_droplet, n_max(dx) jumps from ~1 D₀ (delocalized) to ~10⁴ D₀ (paper-grade) at a critical dx ≈ R_droplet_minor ≈ 0.2 a_ho. This is a phase-transition-like behavior, not smooth power-law.
   - (C) **Power-law nucleation envelope**: between (A) and (B), n_max(dx) might increase smoothly with refinement, e.g. n_max(dx) ≈ n_paper × min(1, (dx_crit/dx)^β) with dx_crit ≈ 0.05 a_ho and β ∈ [2, 4].
   - Theorist picks one prediction or a discriminator that separates them; predictions become Execute success criteria.
2. **Design the YAML deltas** starting from `runs/_loop/templates/yan_li_saito_f1_droplet.yaml` (per §F1 Design row: "Implementer MUST start from a template..."): only specify the GRID and BOX deltas; everything else (atom, N_atoms, ε_dd, LHY kind, B=0, init_state, dt, n_steps, tol) is inherited from the template or the T37 config. Three candidate runs:
   - P0: 128³ box=10 a_ho → dx = 0.078 a_ho
   - P1: 192³ box=8 a_ho → dx = 0.042 a_ho
   - P2: 256³ box=5 a_ho → dx = 0.020 a_ho (paper-grade)
3. **State explicit predictions** for each point (in D₀ units): so the next Execute's judge has machine-evaluable success criteria.
4. **Observable manifest**: required = norm conservation, n_max, m-populations, ⟨L_z⟩, ⟨F_z⟩, energy components (E_kin, E_contact, E_DDI, E_LHY). The energy breakdown is critical — if grid refinement reveals that E_LHY is wildly off scale, that flags a deeper LHY-discretization issue.
5. **Stop-rule** (cost discipline): theorist must specify what happens if P0 already corroborates the scaling — do we still need P1+P2? Suggested cascade: run P0 first (~500s GPU); if n_max(P0) ≥ 30 D₀ (≥ 30× over T40's 1 D₀ baseline), proceed to P1 (~1600s); if P1 ≥ 400 D₀, proceed to P2 (~4000s). Otherwise stop and re-narrow.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Stage transition rule** per §B3: T42 was Update CORROBORATE on the meta-hypothesis "grid-resolution gap is the root cause"; this narrowed the falsifier space but did not close the parent hypothesis ("SpinorBEC.jl can reproduce paper"). The natural next stage is **Hypothesize** (formalize the dx-refinement scaling prediction) and then **Design** (build the experiment). State.json shows `current_stage: "Hypothesize"`. Theorist as a single dispatch can do both (Hypothesize formalizes; Design produces the YAML deltas) — this is canonical §F1 because Hypothesize and Design share the same role (theorist).
- **Role for stage Design**: theorist (§F1 Design row: "theorist or implementer ... observable manifest + experimental config + criteria for each falsifier"). Theorist is correct because (a) the experiment requires a formal scaling prediction (theorist work), (b) implementer's job at T44 is to RUN the YAML, not to write predictions.
- **Why this stage now (vs other options)**:
  - **Why not skip to Execute directly (implementer runs all 3 points)**: T40 already burned 18.9M effective on a parameterized sweep WITHOUT theorist-derived predictions, yielding INCONCLUSIVE judge classification because success_criteria didn't anchor cleanly. Theorist gating prevents replay of that anti-pattern.
  - **Why not a second critic dispatch (audit something else)**: T42 critic already did the Update; pre-Design critic is double-counting. The Design product itself will be auditable at T44+ if needed.
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito priority 1, mid-cascade, clear high-leverage next step.
  - **Why not switch to meta-critic-placement (priority 50)**: §B2 interleaving rule — mid-cascade is wrong moment. Re-evaluate at T46+ when this cascade closes.
  - **Why not audit-class-scan (advisory AUDIT_DUE: gap=42)**: §F6 audit-class-scan says "Director honors this UNLESS an urgent physics investigation is blocked". Priority 1 cascade is NOT blocked — it has a clear actionable next step. Defer audit-class-scan to T46+ when cascade closes.
  - **Why not Document REFUTED**: T42 CORROBORATEd grid-resolution; investigation is on a clean path forward.
  - **Why not noop**: actionable high-leverage directive (~1.5M theorist text → unlocks T44 Execute decision).

## 4. Research grounding (§A6)

**External references for this Hypothesize/Design dispatch**:

1. **`runs/_loop/judge/turn_42_critic_audit.md`** (T42 critic Section E): "T43 dispatches theorist to design a 2- to 3-point grid-refinement sweep: P0 dx ≈ 0.08, P1 dx ≈ 0.04, P2 dx ≈ 0.02 a_ho. Predictions: n_max should scale roughly as (0.4375/dx)^α with α ∈ [2.5, 3.0]. Concretely: dx=0.08 → n_max ~ 30-50 D₀; dx=0.04 → n_max ~ 400-700 D₀; dx=0.02 → n_max ~ 3000-7000 D₀." Theorist's job is to SHARPEN these predictions, not replace them.

2. **`runs/_loop/research/turn_41.md`**: arithmetic chain (L₀ = 21 a₀ × 15000 = 315000 a₀; dx_paper ≈ 10⁻³ L₀ = 16.35 nm = 315 a₀; in our a_ho = 1.157 μm = 21864 a₀, dx_paper = 0.0144 a_ho; ratio to our dx = 0.4375 → 30.4× coarser; predicted density deficit ≈ 28000× via cubic).

3. **Memory `yan_li_saito_2026_barnett_paper.md` lines 75-83**: anchor numbers — F=1, N=15000, ε_dd=1.2, B=0, torus density ~13,000 D₀, droplet half-extent visible in Fig 1c r/L₀ ∈ [-0.05, +0.05] meaning physical extent ~0.82 μm = 0.71 a_ho. Droplet minor radius (torus) ~0.2 a_ho per critic Section A. These set the geometric scale theorist must resolve.

4. **`runs/_loop/templates/yan_li_saito_f1_droplet.yaml`** (per §F1 Design "Implementer MUST start from a template"): the canonical YAML structure. T37 config (`runs/yan_li_saito_f1_torus_gs/config.yaml`) is the most-recent patched version. Theorist's deltas: grid.n + grid.box, n_steps (may need adjustment for finer dx), dt (CFL: dt ∝ dx² for kinetic stability — going from dx=0.44 to dx=0.02 = 22× finer means dt must drop 484× from 0.005 to ~10⁻⁵ — CRITICAL design constraint), seed parameters.

5. **CFL for split-step Fourier (DDI free-space)**: for kinetic term dt × k_max² < 2π (von Neumann stability), and k_max = π/dx, so dt < 2dx²/π ≈ 0.64 dx². At dx=0.02: dt < 0.0002 → use 1e-4. At dx=0.08: dt < 0.004 → use 0.001. The 22-fold dt reduction at the finest grid is a significant cost amplifier on top of the 64× cells; theorist must respect this in the cost estimate.

6. **CLAUDE.md "Cascade cost"**: "F=1 16³ runs at 55 ms/step in tdhfb" — for plain GP (no TDHFB) the per-step cost on GPU scales roughly as N_voxels × log(N_voxels) for FFT-dominated work. 256³ ≈ 1.7×10⁷ voxels vs T40's 64³ ≈ 2.6×10⁵ → 64× cells × log_ratio ≈ 70-80× cost per step on GPU. Combined with the dt reduction (× ~20 at dx=0.02), total cost amplification vs T40 P1 (which took ~60s/run) is ~1400× → ~24 hours of GPU per P2 run if naively scaled. **THIS IS A BUDGET-BREAKING NUMBER**. Theorist must address this: either (a) reduce n_steps at finer grids by using a better initial seed (start from a partially-converged coarser run), (b) use F32 mode (~2-3× speedup), (c) run only P0 first and re-evaluate, (d) accept ~1-3 hour P0 + cancel P1/P2 if P0 already corroborates.

7. **CLAUDE.md DDI conventions** (lines 65-67): c_dd = μ₀μ² (no 4π), Q_αβ = k̂_αk̂_β − δ_αβ/3 (no 1/(4π)). Theorist must NOT propose modifying these — T42 critic Section B closed the DDI factor-of-4π question (ratio = 1). The grid-refinement experiment uses the EXISTING DDI implementation unchanged.

8. **director.md §G "AI Scientist v2: Experiment Manager Agent + Best-First Tree Search"**: theorist's Design is the "expand" step in LATS; pre-Execute prediction-formulation is the canonical gate.

9. **director.md §G "Grounded autonomous research (arXiv:2604.12198)"**: theorist must articulate predictions in a way that makes REFUTATION at T44 Execute productive (i.e., a clean refutation must still close a question). If P2 at dx=0.02 still gives n_max < 100 D₀, that empirically REFUTEs the grid-resolution hypothesis — the residual is deeper. Predictions must be set up so this outcome is informative.

10. **`feedback_mathematical_elegance_bias.md`**: prefer "N independent issues → N simple fixes, not 1 unifying reformulation". Grid-refinement is a SIMPLE FIX (more grid points). Theorist should NOT propose a fancier alternative (e.g., adaptive mesh, FEM, sinc collocation). Stick to refining the existing pseudospectral grid.

11. **`feedback_cost_overhead_is_the_cost.md`**: don't deliberate excessively about cost — just propose a sensible cascade and execute. Theorist's stop-rule (P0 first, P1 if P0 corroborates, P2 only if both corroborate) is exactly this — embed cost discipline in the experiment design itself.

12. **`feedback_decision_style.md`**: theorist must commit to ONE central prediction (e.g., "n_max(dx) follows (dx_crit/dx)^β with dx_crit, β specified") and explicit numerical predictions, not 3 alternatives hedged.

**Why these inform the dispatch**: Refs 1-3 anchor the quantitative predictions; refs 4-6 set the executable constraints (CFL, template, cost amplification); ref 7 is a NEGATIVE constraint (don't touch DDI); refs 8-12 are methodological discipline.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics — Yan-Li-Saito F=1 reproduction is the project's first Tier-3 candidate). Theorist sets up a falsifiable experiment whose outcome at T44 either pushes tier toward 1.0+ (grid resolved → density nucleates) OR REFUTES the grid hypothesis and forces deeper framework audit.
- **D3 SECONDARY**: theorist's scaling prediction must be lit-grounded (critic Section E referenced Fig 1c geometry, paper's dx/dt, CFL constraints). The prediction is essentially "Lima-Pelster scalar-LHY scalar dipolar droplet on a finite grid converges to the droplet basin only when dx resolves r_droplet" — a sharper version of standard PSF-resolution arguments.
- **D2 NOT advanced this turn**.
- **Tier ladder position**: 0.8 → 0.85 (Design stage produces a passing Design but tier moves substantively at next Execute/Update; minor bump reflects sharper hypothesis quality).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Design",
  "subagent_type": "theorist",
  "rationale": "T42 critic CORROBORATEd grid-resolution as root cause (Sections A+B), recommended R1: theorist Hypothesize/Design a grid-refinement experiment at dx ∈ {0.08, 0.04, 0.02} a_ho. Per §F1 verify-claim Hypothesize+Design row (theorist role), this turn theorist formalizes a sharper scaling prediction than critic's (0.4375/dx)^α heuristic — committing to ONE central prediction (e.g., n_max(dx) = n_paper × min(1, (dx_crit/dx)^β) with explicit numerical values), specifies predictions at each P0/P1/P2 point as machine-evaluable Execute success criteria, derives the CFL constraint dt ∝ dx² (critical: dt must drop ~22× at finest grid), patches deltas onto runs/_loop/templates/yan_li_saito_f1_droplet.yaml (per §F1 template-first rule), and prescribes a CASCADED stop-rule (run P0 first; advance to P1/P2 only if previous point corroborates) so cost stays bounded. Theorist must address the cost amplification: 64× voxels × ~22× steps × log factor ≈ 1000-3000× cost per P2 vs T40 P1 (~60s) → ~hours per run. Stop-rule + F32 mode + restart from partial-converged seed are the levers.",
  "brief": "## ROLE\n\nYou are the theorist subagent. Combined Hypothesize+Design dispatch for the yan-li-saito-2026-reproduction investigation (T43). Critic T42 CORROBORATEd grid-resolution as root cause and recommended R1 (theorist designs a 3-point grid-refinement experiment). Your job:\n\n1. Formalize a sharper scaling prediction than critic's heuristic.\n2. Design the experiment as YAML deltas patched onto the existing template.\n3. Specify Execute-stage success criteria (machine-evaluable).\n4. Address cost amplification with a cascaded stop-rule.\n\nDeliverable: `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_43.md`.\n\n## CONTEXT (DO NOT RE-DERIVE — READ FIRST)\n\n1. `runs/_loop/judge/turn_42_critic_audit.md` — T42 critic audit. Sections A+B (CORROBORATE grid + closed-bit-equal DDI). Section E (R1 routing with P0/P1/P2 candidate grids and rough n_max predictions). Read end-to-end.\n2. `runs/_loop/research/turn_41.md` — T41 research, arithmetic chain for dx-ratio.\n3. `runs/_loop/sim/turn_40.md` — T40 5-point Execute results (n_max ∈ [0.21, 1.06] D₀ at our 64³ box=28 dx=0.4375 a_ho).\n4. `runs/_loop/theorist/turn_40.md` — your prior turn's E_DDI=0-for-isotropic-Gaussian argument (still relevant: Gaussian seed gives no DDI thrust toward droplet basin, so seed must be carefully chosen).\n5. `runs/yan_li_saito_f1_torus_gs/config.yaml` — the current T37/T40 config. Atom Eu151_f1_effective, N=15000, c1=0, B=0, init_m_idx=1 (m=+F polarized seed), init_sigma=2.0, dt=0.005, n_steps=5000, tol=1e-9. Rotating_basis backend (gauge_fix=false).\n6. `runs/_loop/templates/yan_li_saito_f1_droplet.yaml` — canonical template; patch deltas onto this. Note the template uses spinor backend; the T37 config uses rotating_basis. STICK TO ROTATING_BASIS for continuity unless you have a strong reason — switching backends mid-investigation contaminates the comparison.\n7. Memory `yan_li_saito_2026_barnett_paper.md` lines 75-83 — paper anchor: n_peak ~13000 D₀ for F=1 N=15000 ε_dd=1.2 free-space. Droplet half-extent r/L₀ ∈ [-0.05, +0.05] ≈ 0.05·16.35 μm = 0.82 μm = 0.71 a_ho; torus minor radius ~0.2 a_ho (critic Section A).\n8. CLAUDE.md DDI conventions lines 65-67 — c_dd = μ₀μ² (no 4π), Q_αβ = k̂_αk̂_β − δ_αβ/3. DO NOT propose modifying these (T42 Section B closed the question).\n\n## TASK 1 — Formalize the scaling prediction (Hypothesize)\n\nCommit to ONE central prediction. Three candidate functional forms (your job: pick one and justify, or propose your own sharper form):\n\n- (A) **Trivial volumetric ceiling**: n_max(dx) → N / V_eff where V_eff is determined by box size, NOT dx. If this is right, refining dx does not increase n_max — REFUTES grid hypothesis at Execute. Use box=28 a_ho fixed for fair comparison? Or change box too? Discuss.\n- (B) **Sharp dx_crit threshold**: n_max(dx) = 1 D₀ (delocalized) if dx > dx_crit ≈ 0.2 a_ho (droplet minor radius); n_max(dx) ≈ 13000 D₀ × min(1, (dx_crit/dx)^β) for dx ≤ dx_crit. Sharp phase-transition-like behavior at dx_crit.\n- (C) **Smooth power-law envelope**: n_max(dx) ≈ n_paper × (dx_crit/dx)^β with dx_crit ≈ 0.05 a_ho and β ∈ [2, 4]. Smooth interpolation; no sharp transition.\n- (D) **Your own form** (e.g., based on Lima-Pelster scalar droplet energy minimization on a discrete grid; or based on free-energy barrier between delocalized and self-bound basins).\n\nFor whichever form you pick, derive (or estimate) the parameters (dx_crit, β, etc.) and produce **numerical predictions** at P0/P1/P2:\n\n- P0 (dx ≈ 0.08 a_ho): expected n_max = ____ D₀ (range OK if uncertainty quantified)\n- P1 (dx ≈ 0.04 a_ho): expected n_max = ____ D₀\n- P2 (dx ≈ 0.02 a_ho): expected n_max = ____ D₀\n\nSeparately address: how does ⟨L_z⟩ scale with dx? (Paper's torus has ⟨L_z⟩=0 by flux-closure, but seed-dependent.) How does the total energy scale? (Paper: E_total < 0 self-bound; ours at coarse grid: E_total > 0 quasi-bound or unbound.)\n\nAdditional question — is the seed sigma critical? T37/T40 used init_sigma=2.0 a_ho. If the droplet has true size ~0.7 a_ho radius, sigma=2 is over-extended. At finer dx, should sigma be reduced (e.g., 0.5 a_ho to match)? Justify your choice for each Pj.\n\n## TASK 2 — Design the experiment (Design)\n\nProduce YAML deltas for 3 candidate runs P0/P1/P2. Start from `runs/_loop/templates/yan_li_saito_f1_droplet.yaml` (per §F1 template-first rule; if the template uses spinor backend but you need rotating_basis like T37, document the backend choice and patch). Specify deltas only:\n\nP0:\n  grid: n=[?, ?, ?]  box=[?, ?, ?]\n  dt: ?    # respect CFL: dt < 2dx²/π ≈ 0.64·dx²\n  n_steps: ?    # to reach equivalent total imaginary time as T40 (T40: 5000 × 0.005 = 25 t_ho)\n  init_sigma: ?\n  tol: 1e-9 (or document otherwise)\n\nP1: ... (same template)\nP2: ... (same template)\n\nGive box size choice rationale. Box must be ≥ 2 × droplet diameter (≈ 3 a_ho) to avoid boundary contamination, but smaller box = fewer cells at given dx = lower cost. Candidate: box=10 a_ho (P0), box=8 a_ho (P1), box=5 a_ho (P2). Justify or propose alternatives.\n\nIMPORTANT — cost amplification: 256³ has 64× cells vs 64³, CFL pushes dt down by (0.0144/0.4375)² ≈ 1/925 (extreme case), and FFT cost scales as N log N. T40 P1 took ~60s GPU. Cost estimate for each Pj:\n\n- P0 (128³ box=10 → dx=0.078): ~ (8× cells × 32× dt × log_factor) ≈ 300× T40 cost ≈ 5 hours? Verify. May be unfeasible without optimizations.\n- P1 (192³ box=8 → dx=0.042): ~ ?\n- P2 (256³ box=5 → dx=0.020): ~ ?\n\nIf cost estimate exceeds 4-6 hours per point (per-turn 6M effective ≈ ~30 min wall on GPU at typical rates), you MUST propose mitigations:\n\n- F32 mode (dtype: f32 in ground_state block; ~2-3× speedup per CLAUDE.md F32 caveats — keep an eye on scalar locks for rotation/DDI/spin_mixing).\n- Restart from partial-converged seed (run P0 first; use its converged ψ as seed for P1; etc. — cuts n_steps by 5-10×).\n- Cascaded stop-rule: run P0 ONLY at T44; evaluate before committing to P1/P2.\n- Coarser P0 (e.g., 96³ box=12 → dx=0.125 a_ho) as a 'is anything happening?' first cut. If 96³ shows n_max ≥ 10 D₀, scaling is alive; commit to finer.\n\nAt minimum, T44 should run P0 first (1 GPU run, ≤ 1 hour wall, ≤ 6M effective). Higher-resolution Pj depend on P0 outcome.\n\n## TASK 3 — Execute-stage success criteria (Design contract)\n\nFor T44 Execute (implementer_julia_gpu), specify success criteria as a JSON block in the same shape as director.md §C success_criteria. Examples:\n\n- norm_drift_max < 0.01 (sanity)\n- n_max_p0 > X D_0 (your prediction)\n- n_max_p0 < Y D_0 (anti-runaway, e.g., < 50000 D_0)\n- E_total_p0 < 0 (self-bound at P0?) — predict\n- L_z_per_N close to 0 (paper has flux-closure-torus GS, no net angular momentum)\n- F_z_per_N close to ±1 (paper has fully polarized spin)\n\nFor each criterion, give a clear if-pass/if-fail interpretation:\n\n- pass: corroborates your prediction at this dx → tier 0.8 → 0.9+ at T44 Update, continue to P1\n- fail (numeric mismatch): grid hypothesis still alive but quantitative form is wrong → recalibrate prediction\n- fail (runtime error / CFL blow-up / non-convergent ITP): operational re-dispatch\n- ALL Pj fail with n_max ≤ 10 D₀: grid hypothesis REFUTED-after-corroboration → tier 0.6, escalate to deeper framework audit\n\n## TASK 4 — Cost discipline (write the stop-rule)\n\nState the EXACT cascaded execution plan T44 should follow:\n\n- Step 1: Run P0 (or P0_coarse as 96³ pre-screening) at T44.\n- Step 2 (at T44 Update / judge): IF n_max(P0) ≥ A D_0 (your threshold), proceed to P1 at T45 Execute. ELSE stop, recall T46 = re-narrow.\n- Step 3 (at T45 Update): IF n_max(P1) ≥ B D_0, proceed to P2 at T46. ELSE STOP and report.\n\nThe stop thresholds A, B are YOUR call as theorist. Aggressive thresholds save cost; loose thresholds risk missing a slow approach.\n\n## TASK 5 — Backend choice\n\nT37 used rotating_basis (per config.yaml line 26: `defaults: {kind: rotating_basis, backend: gpu}`). Template defaults to spinor (template line 23: `defaults: {kind: spinor, backend: gpu}`). For continuity with T37/T40 data, recommend rotating_basis. BUT rotating_basis has a hard limit: omega=0 is acceptable (free-space limit per `run_step_rotating/ground_state.jl:22-25`) and gauge_fix=false is OK. Should be fine. Document and justify. If you propose switching to spinor backend, justify why and accept the loss of direct comparability to T40 baseline.\n\n## STYLE\n\n- Per `feedback_decision_style`: pick ONE prediction (functional form A/B/C/D) and commit. Do not present multiple options with no commitment.\n- Per `feedback_mathematical_elegance_bias`: simple grid refinement, no fancy schemes.\n- Per `feedback_cost_overhead_is_the_cost`: don't deliberate cost in prose — embed it in the stop-rule.\n- Per `feedback_no_improvised_terminology`: use standard CFL, droplet-basin, grid-resolution terminology.\n- Use calibration tags [Established], [Plausible], [Speculative], [Unknown] for each numerical prediction.\n- 8-15 sections, ~1500-2500 lines is normal length for a theorist Design memo. Don't pad. Don't omit derivation chains.\n\n## DELIVERABLE\n\nWrite `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_43.md` with sections matching tasks 1-5. End with the standard metrics JSON block (machine-readable for judge.py).\n\n## METRICS BLOCK (required by judge.py at end of memo)\n\n```json\n{\n  \"theorist_md_on_disk\": true,\n  \"scaling_form_chosen\": \"A\" | \"B\" | \"C\" | \"D\",\n  \"scaling_form_rationale_present\": true | false,\n  \"prediction_p0_n_max_d0\": <float or [low, high]>,\n  \"prediction_p1_n_max_d0\": <float or [low, high]>,\n  \"prediction_p2_n_max_d0\": <float or [low, high]>,\n  \"dx_crit_estimate_a_ho\": <float or 'none'>,\n  \"beta_exponent\": <float or 'none'>,\n  \"yaml_deltas_specified\": true | false,\n  \"backend_choice\": \"rotating_basis\" | \"spinor\",\n  \"cfl_constraint_addressed\": true | false,\n  \"cost_estimate_p0_gpu_hours\": <float>,\n  \"cost_estimate_p1_gpu_hours\": <float>,\n  \"cost_estimate_p2_gpu_hours\": <float>,\n  \"stop_rule_specified\": true | false,\n  \"stop_threshold_p0_d0\": <float>,\n  \"stop_threshold_p1_d0\": <float>,\n  \"success_criteria_count\": <integer>,\n  \"observable_manifest_required\": [<strings>],\n  \"f32_mode_recommended\": true | false,\n  \"restart_seed_strategy_proposed\": true | false,\n  \"sources_cited\": <integer>\n}\n```",
  "observable_manifest": {
    "required": [
      "theorist_md_on_disk",
      "scaling_form_chosen",
      "prediction_p0_n_max_d0",
      "yaml_deltas_specified",
      "cfl_constraint_addressed",
      "stop_rule_specified",
      "success_criteria_count"
    ],
    "optional": [
      "prediction_p1_n_max_d0",
      "prediction_p2_n_max_d0",
      "dx_crit_estimate_a_ho",
      "beta_exponent",
      "backend_choice",
      "cost_estimate_p0_gpu_hours",
      "cost_estimate_p1_gpu_hours",
      "cost_estimate_p2_gpu_hours",
      "stop_threshold_p0_d0",
      "stop_threshold_p1_d0",
      "f32_mode_recommended",
      "restart_seed_strategy_proposed"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_42_critic_audit.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_41.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/templates/yan_li_saito_f1_droplet.yaml && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md && test -f /home/suzume/workspace/BEC-simulation/CLAUDE.md && echo 'precondition OK: T42 critic + T41 research + T40 sim/theorist + T37 config + template + memory + CLAUDE all on disk'"
  },
  "success_criteria": [
    {
      "id": "theorist_md_on_disk",
      "metric": "theorist_md_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required; theorist must Write to /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_43.md."
    },
    {
      "id": "scaling_form_chosen_committed",
      "metric": "scaling_form_chosen",
      "operator": "in",
      "value": ["A", "B", "C", "D"],
      "tolerance": null,
      "rationale": "Per feedback_decision_style: theorist must commit to ONE form (volumetric-ceiling / sharp-threshold / power-law-envelope / custom). Do not allow non-commitment."
    },
    {
      "id": "prediction_p0_specified",
      "metric": "prediction_p0_n_max_d0",
      "operator": ">=",
      "value": 0,
      "tolerance": null,
      "rationale": "Numerical prediction at P0 must be present (range or scalar). 0 D₀ is a valid prediction (refuting the grid hypothesis); just must be specified."
    },
    {
      "id": "yaml_deltas_specified",
      "metric": "yaml_deltas_specified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Per §F1 Design row: YAML deltas patched onto the template are the deliverable artifact for T44 implementer."
    },
    {
      "id": "cfl_addressed",
      "metric": "cfl_constraint_addressed",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "dt must scale with dx² (CFL for kinetic). Failing to address this would mean T44 dies on CFL blowup → wasted GPU run."
    },
    {
      "id": "stop_rule_specified",
      "metric": "stop_rule_specified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Cost amplification at 256³ box=5 is 100-1000× T40 — cascaded stop-rule embeds cost discipline in the experiment design rather than relying on per-turn judging."
    },
    {
      "id": "success_criteria_for_t44",
      "metric": "success_criteria_count",
      "operator": ">=",
      "value": 4,
      "tolerance": null,
      "rationale": "T44 implementer needs machine-evaluable criteria: norm-drift, n_max(P0), E_total sign, ⟨L_z⟩, ⟨F_z⟩, etc. Minimum 4."
    },
    {
      "id": "sources_minimum",
      "metric": "sources_cited",
      "operator": ">=",
      "value": 4,
      "tolerance": null,
      "rationale": "Theorist must cite T42 critic + T41 research + memory paper + template/config (4 minimum)."
    }
  ],
  "failure_modes": [
    {
      "if": "theorist_md_on_disk failed",
      "category": "operational",
      "next_action": "T44 = re-dispatch theorist with stricter file-path enforcement. If 2nd attempt fails, escalate to anko."
    },
    {
      "if": "scaling_form_chosen not in [A,B,C,D]",
      "category": "operational",
      "next_action": "T44 = re-dispatch theorist with explicit commit-or-die directive (do not allow 'we will see').".replace("\"","")
    },
    {
      "if": "all predictions specified + yaml_deltas + stop_rule present (Design clean PASS)",
      "category": "scientific_design_complete",
      "next_action": "T44 = implementer_julia_gpu Execute P0 ONLY (per cascaded stop-rule). Budget per-point ≤ 6M effective (per-turn cap). Use exact YAML deltas from theorist's table. Save observables per theorist's required manifest. T45 = judge.py + if-pass-advance-to-P1 or if-fail-Update. Tier yan-li-saito 0.8 → 0.85 (Design done) → 1.0 only after T44 PASS."
    },
    {
      "if": "P0 cost estimate exceeds 6M effective without mitigations",
      "category": "operational_cost_overflow",
      "next_action": "T44 = theorist re-dispatch to add explicit mitigations: F32 mode, restart-seed strategy, coarser P0_pre (96³). Do not dispatch implementer with a >6M plan."
    },
    {
      "if": "theorist proposes switching backend from rotating_basis to spinor without strong rationale",
      "category": "scientific_continuity_risk",
      "next_action": "T44 = critic side-dispatch to audit backend switch (does it invalidate T40 baseline comparison?). If audit passes, accept; if fails, redo at T45 with rotating_basis."
    },
    {
      "if": "theorist proposes modifying DDI conventions",
      "category": "scientific_a1_re_reopen_attempt",
      "next_action": "REJECT. T42 critic Section B closed DDI bit-equal. Re-dispatch theorist with explicit constraint to keep DDI conventions untouched. Escalate if theorist insists."
    },
    {
      "if": "theorist commits to scaling_form A (volumetric ceiling) with strong argument",
      "category": "scientific_alternative_hypothesis_promoted",
      "next_action": "T44 = ONE quick GPU run at finer dx + same box (e.g., 128³ box=28 a_ho dx=0.219) to test volumetric ceiling directly. If n_max DOES increase, A is refuted in favor of B/C; proceed with original cascade. If n_max stays flat, A confirmed, investigation pivots to box-size hypothesis."
    },
    {
      "if": "cost_within_budget failed (theorist text exceeds 3M effective)",
      "category": "operational",
      "next_action": "Acceptable up to per-turn 6M cap; if >6M escalate to anko."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000
  },
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 1200,
    "split_by_subtask": {
      "read_t42_critic_t41_research_artifacts": 300000,
      "read_template_and_t37_config": 200000,
      "task1_scaling_hypothesis_derivation": 400000,
      "task2_yaml_deltas_with_cfl_cost": 300000,
      "task3_4_5_success_criteria_stop_rule_backend": 300000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Execute",
    "if_success_tier_becomes": 0.85,
    "if_success_falsifier_update": "T43 theorist Design produced scaling hypothesis (form chosen + numerical predictions at P0/P1/P2) + YAML deltas patched onto template + CFL-respecting dt + cascaded stop-rule. New falsifier `dx-refinement-scaling` SPAWNED: tested at T44 Execute on P0 first; advance to P1 only if P0 corroborates per theorist stop-rule. Tier 0.8 → 0.85 (Design quality bump only; substantive tier moves at Execute/Update with empirical data).",
    "if_refuted_advance_to_stage": "Hypothesize (re-narrow on alternative root causes)",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "dx-refinement-scaling (P0 first; cascaded). T44 = implementer_julia_gpu Execute P0 using theorist YAML deltas. Budget P0 ≤ 6M effective ≤ ~1 hour wall. T45 = judge + Update (CORROBORATE / NARROW / REFUTE the scaling form). Meta-critic-placement update: T42 critic adding 2 PARTIAL→CLOSED conversions (geometric argument + DDI algebra) in ~1.3M effective is strong evidence that critic-after-research is high-leverage when research is quantitative but unclosed."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_43.json` (policy=PROBE_DRIVEN → JULIA_GPU_OK; theorist in allowed_workloads; window 20019 min left; VRAM 12875 MB free / GPU 9% util — comfortable for T44 GPU follow-up).
- [x] Read `runs/_loop/state.json` investigations.yan-li-saito-2026-reproduction full block (current_stage=Hypothesize, tier_current=0.8, history T42 critic CORROBORATE noted, last_advanced_turn=42).
- [x] Read `runs/_loop/seed.md` end-to-end (yan-li-saito priority 1, Tier-3 candidate).
- [x] Read `runs/_loop/director/turn_42.md` end-to-end (prior dispatch shape).
- [x] Read `runs/_loop/judge/turn_42_critic_audit.md` end-to-end (T42 critic verdict: Section A CORROBORATE grid, Section B CORROBORATE-bit-equal DDI, Section C DISMISSED chi, Section D sufficient, Section E R1 routing with concrete dx/n_max predictions).
- [x] Read `runs/yan_li_saito_f1_torus_gs/config.yaml` end-to-end (T37 config: rotating_basis, atom Eu151_f1_effective, N=15000, c1=0, init_m_idx=1, init_sigma=2.0, dt=0.005, n_steps=5000, tol=1e-9, grid 64³ box=28).
- [x] Read `runs/_loop/templates/yan_li_saito_f1_droplet.yaml` end-to-end (template uses spinor backend; T37 uses rotating_basis — backend choice flagged for theorist).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` end-to-end (anchor numbers, paper geometry, alignment Q1-Q5).
- [x] investigation_id `yan-li-saito-2026-reproduction` valid in state.investigations.
- [x] stage_advancing_to=Design follows §F1 verify-claim (Hypothesize → Design); combined theorist dispatch covers both stages since they share role.
- [x] subagent_type=theorist matches §F1 Design row ("theorist or implementer ... observable manifest + experimental config + criteria for each falsifier").
- [x] success_criteria are machine-evaluable: 8 criteria (file existence, scaling form committed, P0 prediction, YAML deltas, CFL addressed, stop-rule, success criteria count, sources).
- [x] failure_modes cover 8 scenarios: operational missing file, non-committed scaling form, design clean PASS path, cost overflow, backend switch risk, DDI-modification rejection, scaling-form-A alternative, budget overflow.
- [x] observable_manifest precondition_check is literal bash chain (8 test -f + echo) — exits 0 before theorist invocation if all files present.
- [x] Budget 1.5M effective + 20-min wall fits within scheduler window + per-turn 6M cap. Tolerance_overrides set tighter 3M cap for theorist text-only.
- [x] §A6 research-first citations: T42 critic, T41 research, T40 sim/theorist, T37 config, template, memory paper entry, CLAUDE.md DDI, CFL standard, cost-overhead-is-the-cost feedback, decision-style feedback, mathematical-elegance feedback. 12 references covering both quantitative anchors and methodological discipline.
- [x] §A5 D1 PRIMARY articulated (Tier-3 verification of paper reproduction); D3 SECONDARY (lit-grounded scaling prediction); D2 NOT advanced; manuscript NOT in scope.
- [x] investigation_update has explicit success/refute branches: PASS → Execute P0 cascaded at T44, tier 0.8 → 0.85; REFUTED → Hypothesize alt-causes, tier → 0.6.
- [x] Considered switching to klaus-bch-leak (priority 3): rejected — yan-li-saito priority 1 + clear high-leverage next step + cascade continuity.
- [x] Considered switching to meta-critic-placement (priority 50): rejected per §B2 interleaving rule (mid-cascade); current cascade itself is canonical evidence to fold into meta observations.
- [x] Considered audit-class-scan (advisory AUDIT_DUE: gap=42): rejected per §F6 — priority 1 cascade is active and not blocked. Defer to T46+.
- [x] Considered NOOP: rejected — clear high-leverage actionable directive (~1.5M theorist → gates a potential 6M GPU Execute at T44).
- [x] Considered Execute directly (skip theorist Design): rejected — would replay T40 anti-pattern (parameterized sweep without theorist predictions yielded INCONCLUSIVE because success criteria didn't anchor).
- [x] Considered another critic dispatch: rejected — T42 critic Update already done; the next critic dispatch is for T45 if Execute outcomes need independent audit.
- [x] Considered Document closed: rejected — investigation has clear forward path (grid-refinement empirical test pending).
- [x] Honored state.json `current_stage: "Hypothesize"` → advance to Design (combined Hypothesize+Design theorist dispatch).
- [x] Honored T42 critic Section E R1 recommendation: theorist designs grid-refinement experiment.
- [x] `consumed_seed_md: false` — same investigation, no new seed entry.
- [x] Drift advisory DRIFT_MANUSCRIPT_DELTA_ZERO: ignored per `feedback_manuscript_is_not_the_essence.md`.
- [x] Drift advisory AUDIT_DUE: acknowledged + deferred per §F6 (priority 1 active cascade).
- [x] No A3 violation (this turn advances ONE investigation by ONE stage: yan-li-saito Hypothesize → Design via theorist).
- [x] No A4 violation (declarative contract with investigation_id, stage_advancing_to, subagent_type, success_criteria with machine-evaluable thresholds, failure_modes with categories+next_action, observable_manifest with concrete precondition_check, budget with split_by_subtask).
- [x] No A5 violation (D1 articulated; D3 secondary; D2 not advanced; manuscript not in scope).
- [x] No A6 violation (12 external references cited covering quantitative anchors and methodological discipline; theorist Design contract grounded in T42 critic Section E specifically).
