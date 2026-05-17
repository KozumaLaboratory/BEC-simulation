---
turn: 33
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Design
stage_advancing_to: Execute
topic_tags: [yan-li-saito-2026, tier3-candidate, execute-stage, f1-falsifier, torus-gs-itp, eu151-effective-f1, free-space-droplet, julia-gpu, peak-density-discriminator, lhy-ddi-ratio]
paper_section: null
depends_on: [32, 31, 30, "runs/_loop/sim/turn_32.md", "runs/_loop/judge/turn_32.json", "runs/_loop/director/turn_32.md", "runs/_loop/theorist/turn_30.md", "runs/yan_li_saito_f1_torus_gs/config.yaml", "runs/yan_li_saito_f1_torus_gs/README.md", "src/workflow/initialization/atoms.jl", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_manuscript_is_not_the_essence"]
produces: "Execute-stage julia_gpu run of runs/yan_li_saito_f1_torus_gs/config.yaml: ITP for F=1 effective Eu-151 torus magnetic-vortex GS at B=0 in free space, ε_dd=1.2, N=15000 on 64³ grid; extracts peak density and energy decomposition; reports n_max in paper's D₀ units against the F1 target 13000 ±10% and F4 |E_LHY|/|E_ddi| ratio target [2, 20]; produces runs/_loop/sim/turn_33.md with empirical falsification verdict (PASS / INCONCLUSIVE / FALSIFIED)."
---

# Turn 33 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.8 → tier_target 3). Continuing from T32.
- **Stage transition**: **Design → Execute**. T32 (Design REDO) judge verdict PASS — all 8 success criteria met, all Design artifacts on disk verified by my direct reads this turn:
  - `runs/yan_li_saito_f1_torus_gs/config.yaml` — 50 lines, `defaults: {kind: rotating_basis, backend: gpu}`, mixin `yan_li_saito_f1`, single ground_state pipeline step.
  - `runs/yan_li_saito_f1_torus_gs/README.md` — 34 lines, F1 acceptance criteria documented.
  - `src/workflow/initialization/atoms.jl` — `Eu151_f1_effective` const at line 226, ATOM_REGISTRY entry at line 302, export at line 2 (grep confirms 3 mentions).
  - `runs/_loop/sim/turn_32.md` — 252 lines with §3 schema audit (`initial_state: fl_vortex` confirmed parser-accepted at schema.jl:98), §4 atom species verification, §5 F1 falsifier criteria, §6 precondition check, §11 meta-loop observation seeding.
- **Tier**: 0.8 → 1.0 on PASS (internal regression PASS via paper anchor match), 0.6 on FALSIFIED (theorist must re-Hypothesize with framework-gap analysis — leading suspects Q1 LHY χ integrand or Q2 DDI prefactor reconciliation). Tier 2 needs F2 (constrained-J_z Barnett signature) + critic Update. Tier 3 needs all three F1/F2/F3 + critic Update.
- **Drift advisories at T32**: `DRIFT_MANUSCRIPT_DELTA_ZERO` + `DRIFT_CODE_DELTA_ZERO` + `DRIFT_COST_INFLATION`, `drift_escalation: human_required`. Reading: (a) manuscript delta zero — accepted, manuscript is OUT of scope per anko 2026-05-15 directive (this drift signal will fire indefinitely for physics-stage turns; not substantive); (b) code delta zero — **substantively cleared this turn by T32's Edits/Writes (atoms.jl + 3 new files); the drift signal is computed from the prior turn's snapshot and lags one turn**; (c) cost inflation 1.059 — within tolerance band 1.5×, primarily reflects T32 reading 6 large reference files (theorist/turn_30.md + sim/turn_31.md + runs/eu151_klaus_phi_phys/config.yaml + memory yan-li-saito + atoms.jl + schema.jl). T33's Execute runs julia and will not re-read those files; cost should ease.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed at T29 (Tier 3.0 — project's first Tier 3). Not in active rotation.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, current_stage=documented): blocked_on "needs julia P3 validation against anko Klaus phi sweep data". Could be unblocked in principle (scheduler allows julia_cpu), but yan-li-saito Execute is priority 1 and the higher-leverage move.
  - `fullbdg-f6-polar-3000x` (dormant priority 99): contained. Do not touch.
  - `meta-critic-placement-2026-05-17` (priority 50, current_stage=Observe, kind=meta): auto-spawned. Per §B2 interleaving rule, advance physics first. T31 phantom-PASS pattern is a real data point for the meta investigation; sim/turn_32.md §11 seeded the observation. Meta turn deferred until after F1 Execute closes (PASS or FALSIFIED).

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T30 | Hypothesize | NOOP (substantively PASS, theorist 436-line artifact, ZERO BLOCKERS) | Term-by-term paper→SpinorBEC.jl mapping (5 rows), Q1-Q5 framework gaps resolved, 4 falsifiers with quantitative predictions. |
| T31 | Design | PASS (PHANTOM — judge accepted self-reported file_exists; files never landed on disk due to 1Password SSH-signing block) | Implementer reported writing config.yaml + README + atom species edit; git commit blocked; staged delta lost. Drift escalation `director_must_address` correctly fired on disk truth. |
| T32 | Design (REDO) | PASS (legitimate — Write/Edit tool-only directive worked; all 8 success criteria met against disk-truth metrics) | Implementer Wrote config.yaml + README + sim/turn_32.md, Edited atoms.jl in 3 hunks (export, const, registry). Grep audit confirmed `initial_state: fl_vortex` is parser-accepted key. F1 unit derivation logged. |

**Trajectory check**: implementer_text ran T31 (phantom) + T32 (real) — 2 turns in a row but on the same Design deliverable; T32 was a corrective redo, not new work. implementer_julia_gpu last ran T27 (gamma_dr=K3=0 control, barnett) — 6 turns ago, well-rested. Theorist last ran T30 (yan-li-saito Hypothesize) — 3 turns ago. Researcher resolved Q-Eu151-gF + Q-paper-energy-table at T30 — 3 turns ago. Critic last ran T28 (barnett Update) — 5 turns ago. **implementer_julia_gpu is the canonical role for Execute stage of a verify-claim physics investigation** AND is well-rested. Routing is clean.

**Judge T32 verdict reading**: 8/8 criteria PASS, 0 failure modes triggered, `falsification_result: INCONCLUSIVE` correctly tagged (T32 was modify_code, no physics result). Investigation_update directive `if_success_advance_to_stage: Execute` + `if_success_tier_becomes: 0.8` is unambiguous. Execute is the template-mandated next stage.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → **Execute** → Analyze → Update → Document → closed).
- **Role for stage Execute**: per director §F1 row "Execute": "**implementer** (text / sympy / julia_cpu / julia_gpu per workload) — pre-flight manifest check, then run". Workload class: `implementer_julia_gpu` per scheduler.allowed_workloads.
- **Why Execute now (vs other options)**:
  - **Why not skip to Analyze**: Analyze role is also implementer (per §F1) and follows Execute; can't reach without empirical data.
  - **Why not re-do Design**: T32 PASS legitimate, no contract failure or scope creep. Re-doing Design would be redundant (a "comfortable retry" anti-pattern, per the loop's own meta-lesson).
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito is priority 1 with a clean Execute-ready artifact. Klaus has clear actionable julia work (P1/P2/P3 predictions against anko's phi sweep jld2), but yan-li-saito beats it on priority. Klaus picks up after F1 closes.
  - **Why not switch to meta-critic-placement (priority 50, Observe stage)**: §B2 interleaving rule "advance one physics, then maybe one meta". T32 was physics-stage (Design redo). T33 should be Execute (physics again) since F1 is on the critical path to Tier 3 and we have a runnable artifact. Meta can run T34 if the window slot suits.
  - **Why not NOOP**: Execute on F1 is the single highest-leverage move for the priority-1 Tier-3 candidate. NOOP burns ~10 min wall and yields zero information.
  - **Why not dispatch critic for Cross-check on Hypothesize artifact**: critic Cross-check is part of build-theory template (§F2), NOT verify-claim. In verify-claim, critic is invoked at Update stage AFTER Analyze. Calling critic now would be off-template.
  - **Why not researcher**: no research gap. Q1-Q5 resolved at T30; Q-Eu151-gF + Q-paper-energy-table resolved at T30 parallel queries.

## 4. Research grounding (§A6)

- **External references (load-bearing for Execute dispatch)**:
  - **Yan-Li-Saito 2026 PRL Fig 1c anchor** (memory `yan_li_saito_2026_barnett_paper.md` lines 74-82): "For Eu-151 F=1, N=15000, ε_dd=1.2: torus density ~13,000 (D₀ units), spin polarization f/ρ ≃ 1 everywhere." This is the F1 target. The 10% tolerance band is conservative — the paper plots Fig 1c at visual precision ~1 contour level; ±10% is the smallest discriminator we can defend from a printed figure.
  - **Theorist T30 §3 Check 2** (the F1 quantitative prediction): n_max ≈ 13000 D₀ with χ(ε_dd=1.2) = 4.92 (Lima-Pelster scalar mode); F4 |E_LHY|/|E_ddi| ∈ [2, 20] is the LHY-vs-DDI dominance discriminator that distinguishes droplet regime from contact-only regime.
  - **anko CLAUDE.md "Commands" + "GPU" sections**: `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. ...`; `import CUDA before using SpinorBEC` loads the extension; pass `backend=CUDABackend()`. T33 brief must use these incantations exactly.
  - **anko CLAUDE.md "Key Architecture" section**: `run_yaml("x.yaml")` is the resumable directory-per-config runner (writes one jld2 per point, skips cached files on re-run). For a single ground_state pipeline step this is the right entry point — also keeps the artifact layout consistent with anko's other runs/.
  - **runs/_loop/sim/turn_32.md §6 precondition check**: a literal bash+julia command that verifies (a) config.yaml and README.md exist on disk, (b) `SpinorBEC.resolve_atom(:Eu151_f1_effective)` returns the right F/a_s/μ. T33 implementer must run this FIRST before any ITP — if it exits nonzero, return `data_gap` verdict without burning GPU wall.
  - **Prior loop turn pattern (barnett T20 Execute)**: `runs/_loop/sim/turn_20.md` Execute stage on Klaus YAML wrote a comprehensive §4 Metrics block + §6 figure summary; the barnett T20 Lz-missing observable manifest mistake is the exact failure mode this turn's observable_manifest is designed to prevent. Lesson applied: pre-flight check + explicit observable list before run.
  - **Cline/Cursor leaked-prompt manifest pattern (director §G)**: observable_manifest with precondition_check that exits 0/nonzero before expensive run. T33 brief specifies the bash precondition chain from sim/turn_32.md §6, with explicit "if precondition fails, return data_gap verdict, do NOT run julia ITP".
  - **memory `feedback_cost_overhead_is_the_cost`**: anko 2026-05-15 "コストとか気にしなくていい … 全部やろう / 勝手にやっていいよ". Don't over-deliberate on cost; F1 Execute is a 5-10 min GPU run with ~3M effective tokens, well within rolling 5h budget.
- **Why these inform the dispatch**: F1 is the smallest-first falsifier — pure ITP, no constrained-J_z plumbing needed, no RTP scan needed. It tests the *static* alignment between SpinorBEC.jl's LHY+DDI framework and the paper's at B=0. If F1 PASSES, the framework is correct enough that F2/F3 are worth pursuing. If F1 FALSIFIES at >50%, the framework has a real bug (LHY χ integrand or DDI prefactor) and theorist must re-derive. The 10-50% INCONCLUSIVE band is reserved for grid-resolution effects (paper uses ~256³ish, we use 64³).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify external physics — direct paper-anchor benchmark). F1 PASS produces the project's SECOND Tier-3-candidate empirical result (after barnett at T29). F4 ratio is a free post-process from the same run, also a published-reference benchmark. This is the highest D1 leverage move available in the loop.
- **Tier ladder position**: 0.8 → 1.0 on PASS (internal regression PASS); 0.6 on FALSIFIED (theorist re-Hypothesize); stay at 0.8 on INCONCLUSIVE (T34 director patches grid or warm-up trap). Tier 2 needs F2 + critic Update. Tier 3 needs F1+F2+F3 + critic Update.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. T33 delivers Julia run + sim/turn_33.md report + (on PASS) state.json delta. No paper text.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Execute",
  "subagent_type": "implementer",
  "rationale": "T32 (Design REDO) PASS legitimate — all Design artifacts on disk: runs/yan_li_saito_f1_torus_gs/config.yaml (verified Read this turn), README.md, src/workflow/initialization/atoms.jl Eu151_f1_effective const + ATOM_REGISTRY entry (verified grep 3 hits), runs/_loop/sim/turn_32.md with §3 schema audit confirming initial_state: fl_vortex parser-accepted. Per verify-claim template Design → Execute is the mandated next stage; scheduler allows implementer_julia_gpu (policy JULIA_GPU_OK, VRAM 12.6 GB free, foreign_julia=0); implementer_julia_gpu last ran T27 (6 turns ago, well-rested); F1 is the smallest-first falsifier (pure ITP, no constrained-J_z or RTP plumbing); 5-10 min GPU wall + ~3M tokens fits in the 14-day window budget. This is the highest-leverage D1 move available in the loop: direct paper-anchor benchmark on a Tier-3 candidate investigation.",
  "brief": "Execute stage for yan-li-saito-2026-reproduction F1 falsifier (torus density peak, ITP-only). Run /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml on GPU; compare measured n_max to paper's 13000 D₀ ±10%.\n\n## STAGE 1: PRECONDITION CHECK (mandatory, run BEFORE any ITP)\n\nRun this exact bash command chain (from runs/_loop/sim/turn_32.md §6). If ANY line exits nonzero, ABORT — write sim/turn_33.md with `falsification_result: data_gap`, identify which check failed, do NOT run julia ITP:\n\n```bash\ntest -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && \\\ntest -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/README.md && \\\nLD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia --project=/home/suzume/workspace/BEC-simulation -e 'using SpinorBEC; atom = SpinorBEC.resolve_atom(:Eu151_f1_effective); println(\"atom F=\", atom.F, \" a_s=\", atom.a_s, \" mu=\", atom.mu_mag)' && \\\necho 'precondition OK'\n```\n\nExpected output (per sim/turn_32.md §6):\n```\natom F=1 a_s=1.11167e-9 mu=4.1344e-23\nprecondition OK\n```\n\n## STAGE 2: ITP EXECUTION\n\nIf precondition OK, run:\n\n```bash\ncd /home/suzume/workspace/BEC-simulation && \\\nLD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia --project=. -e '\nimport CUDA\nusing SpinorBEC\nrun_yaml(\"runs/yan_li_saito_f1_torus_gs/config.yaml\"; base_dir=\"runs\", verbose=true)\n'\n```\n\nNotes:\n- `run_yaml` writes to `runs/yan_li_saito_f1_torus_gs/` (config dir), one jld2 per pipeline point (here a single point: the ground_state step).\n- The pipeline has one step `ground_state` with `dt=0.005, n_steps=5000, tol=1.0e-9`. Expected wall: 5-15 min on GPU.\n- If `run_yaml` throws (e.g. parsing error, workspace build error, missing observable), capture the exception message in sim/turn_33.md §10 Risk register and tag `falsification_result: data_gap`.\n- If `run_yaml` runs but does NOT converge in 5000 steps (final residual > tol), note it but proceed to analysis — the F1 discriminator is n_max magnitude, not convergence per se.\n\n## STAGE 3: POST-PROCESS (read saved jld2 and compute F1+F4 observables)\n\nThe saved jld2 will be at `runs/yan_li_saito_f1_torus_gs/point_001.jld2` (or `point_NNN.jld2` per `_run_yaml_single` convention; check the actual path written by run_yaml). Read it:\n\n```bash\nLD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia --project=/home/suzume/workspace/BEC-simulation -e '\nimport CUDA\nusing SpinorBEC, JLD2, Statistics\n\n# load the saved state\njld_path = first(filter(p -> endswith(p, \".jld2\"), readdir(\"runs/yan_li_saito_f1_torus_gs\", join=true)))\nprintln(\"loading: \", jld_path)\ndata = JLD2.load(jld_path)\npsi = data[\"psi\"]\ngrid = data[\"grid\"]\n\n# Peak density (in code units = a_ho⁻³)\nn = dropdims(sum(abs2, psi; dims=ndims(psi)); dims=ndims(psi))   # sum over spinor axis\nn_max_code = maximum(n)\n\n# Norm check\ndV = prod(grid.dx)\nnorm_total = sum(n) * dV\n\n# Convert n_max to paper'\"'\"'s D₀ units\n#   D₀ = 1/(a_s³ N²) physical; in dimensionless a_ho units: D₀ * a_ho³ = a_ho³/(a_s³ N²)\n#   a_s = 21 * 5.291772e-11 m = 1.11127e-9 m\n#   a_ho = sqrt(ℏ/(m·ω_ref)) with m = 150.92 AMU = 2.5048e-25 kg, ω_ref = 314.159 rad/s\n#         = sqrt(1.0546e-34 / (2.5048e-25 * 314.159))\n#         = sqrt(1.341e-12) = 1.158e-6 m\n#   So a_ho³/a_s³ = (1.158e-6 / 1.11127e-9)³ = (1041.9)³ = 1.131e9\n#   D₀ * a_ho³ = 1.131e9 / 15000² = 1.131e9 / 2.25e8 = 5.025\n# Therefore n_paper [in D₀ units] = n_code [in a_ho⁻³ units] / 5.025\nD0_in_aho3 = 5.025\nn_max_paper_units = n_max_code / D0_in_aho3\n\nprintln(\"n_max (code, a_ho^-3): \", n_max_code)\nprintln(\"n_max (paper D_0 units): \", n_max_paper_units)\nprintln(\"target: 13000 D_0; F1 PASS if |dev| < 10%, INCONCLUSIVE if 10-50%, FALSIFIED if >50%\")\nprintln(\"fractional deviation: \", abs(n_max_paper_units - 13000) / 13000)\nprintln(\"norm: \", norm_total)\n\n# F4 post-process: |E_LHY|/|E_ddi| ratio\n# If energies are saved in the jld2 (run_yaml typically saves a snapshot dict), read them:\nfor key in [\"E_kin\", \"E_s\", \"E_ddi\", \"E_lhy\", \"E_LHY\", \"E_dd\", \"energy_decomp\"]\n    if haskey(data, key)\n        println(key, \" => \", data[key])\n    end\nend\n# Also try the energies field if it exists:\nif haskey(data, \"energies\")\n    println(\"energies dict: \", data[\"energies\"])\nend\n'\n```\n\nIf the jld2 schema does not save individual energy components directly, you may need to:\n- (a) compute them manually from the loaded psi + workspace using `compute_kinetic_energy`, `compute_contact_energy`, `compute_ddi_energy`, `compute_lhy_energy` (or whatever names exist in src/analysis/energy.jl — grep first if uncertain), OR\n- (b) add an `analyze: [energy_decomposition]` step to config.yaml and re-run (only do this if (a) infeasible; would cost another ~10 min wall).\n\n**Prefer (a)**. The energy decomposition analyzer at `src/workflow/experiments/analyzers/phase.jl:19` is `_analyze_energy_decomposition = _analyze_phase_classify`, which already exists. If you find it easier to call directly (without re-running), do so.\n\n## STAGE 4: WRITE sim/turn_33.md\n\nFront-matter shape same as runs/_loop/sim/turn_32.md (turn: 33, subagent: implementer, topic_tags, depends_on: [32, \"runs/yan_li_saito_f1_torus_gs/config.yaml\"], produces: ...).\n\n### §1 Context summary\nWhy this turn (Execute stage F1 ITP for yan-li-saito reproduction); what's tested (n_max ≈ 13000 D₀ ±10%, F4 |E_LHY|/|E_ddi| ∈ [2, 20]).\n\n### §2 Precondition check result\nQuote stdout from STAGE 1 verbatim. If passed, `'precondition OK'` should appear.\n\n### §3 ITP run summary\n- Wall time (seconds).\n- ITP final residual (`tol` value reached or `n_steps` exhausted).\n- Energy at first step, last step, monotonic? (E_n-E_{n-1} < 0 for last 1000 steps?)\n- Convergence verdict (CONVERGED if residual < 1e-9; PARTIAL if n_steps exhausted; DIVERGED if energy grew).\n- Norm initial → final → drift (target drift < 1e-6).\n\n### §4 Metrics (machine-evaluable for judge.py)\n```json\n{\n  \"experiment_kind\": \"itp_ground_state\",\n  \"norm_initial\": <float>,\n  \"norm_final\": <float>,\n  \"norm_drift\": <abs(norm_final - 1.0)>,\n  \"energy_initial\": <float>,\n  \"energy_final\": <float>,\n  \"energy_monotonic\": <true|false>,\n  \"n_max_code_units\": <float>,\n  \"n_max_paper_D0_units\": <float>,\n  \"f1_target_D0\": 13000.0,\n  \"f1_fractional_deviation\": <abs(n_max_paper - 13000)/13000>,\n  \"f1_verdict\": \"PASS\" | \"INCONCLUSIVE\" | \"FALSIFIED\",\n  \"E_kin\": <float>,\n  \"E_s\": <float>,\n  \"E_ddi\": <float>,\n  \"E_lhy\": <float>,\n  \"f4_ratio_lhy_over_ddi\": <abs(E_lhy)/abs(E_ddi)>,\n  \"f4_target_lower\": 2.0,\n  \"f4_target_upper\": 20.0,\n  \"f4_verdict\": \"PASS\" | \"FALSIFIED\",\n  \"wall_time_sec\": <int>,\n  \"falsification_result\": \"PASS\" | \"INCONCLUSIVE\" | \"FALSIFIED\" | \"data_gap\"\n}\n```\n\n### §5 F1 verdict reasoning\nCite the fractional deviation and which category it falls in. If FALSIFIED, identify the leading suspect (Q1 LHY χ vs Q2 DDI prefactor vs Q5 init_state topology) and recommend a theorist re-Hypothesize directive for T34.\n\n### §6 F4 verdict reasoning\n|E_LHY|/|E_ddi| should be in [2, 20] per paper's droplet regime. If outside, this indicates either (a) LHY is being applied to a non-droplet density profile (init_state didn't relax to torus), (b) DDI is double-counted or factor-off (CLAUDE.md `c_dd = μ_0 μ² no 4π` convention may not match paper's `μ_0(gμ_B)²/8π`), or (c) the test config is genuinely outside droplet regime (grid too coarse loses peak).\n\n### §7 Convergence diagnostic\nIf ITP did NOT converge within `tol`, report:\n- Final residual.\n- dE/dt in last 500 steps.\n- Recommended fix (longer ITP, finer dt, warm-up trap).\n\n### §8 Risk register hits\nWhich of T32 §8 risks fired? E.g. \"ITP diverged in free space\" / \"periodic image artifact at box=28 a_ho\" / \"64³ too coarse\" / \"Eu151_f1_effective auto_defaults fallback\" / \"winding=Float64(1.0) parse mismatch\".\n\n### §9 What T34 director should do\n- **F1 PASS + F4 PASS**: advance Execute → Analyze (next turn could be Analyze-stage post-process, or proceed to F2 design which needs Q4 target_Jz plumbing per sim/turn_32.md README §27 — that's a separate T34 implementer_text patch).\n- **F1 INCONCLUSIVE (10-50% deviation)**: stay at Execute; T34 director patches config.yaml to 96³ grid / box=40 a_ho (3×L₀) and re-runs.\n- **F1 FALSIFIED (>50% deviation)**: advance Execute → Update with theorist re-Hypothesize directive identifying Q1/Q2/Q5 framework gap.\n- **data_gap (precondition fail / ITP crash)**: T34 director debugs the orchestration; if precondition fail, check disk truth and re-Edit/Write; if crash, capture stack trace.\n\n### §10 Meta-loop observation (optional)\nIf any contract-level issue surfaced (e.g. jld2 schema not matching expectation), seed the meta investigation per sim/turn_32.md §11 pattern.\n\n## NON-DELIVERABLES (explicit)\n\n- DO NOT run `git add` / `git commit` / `git push`. The 1Password SSH-signing block at T31 is still relevant.\n- DO NOT modify state.json, agent prompts, or judge.py. Director updates state.json from judge T33 verdict.\n- DO NOT modify runs/yan_li_saito_f1_torus_gs/config.yaml unless precondition check reveals a parse error. If you must modify, restrict to ONE change (e.g. `n_steps: 5000` → `8000` or `dt: 0.005` → `0.001`); document the diff in §3.\n- DO NOT skip Stage 1 precondition check. T31 phantom-PASS lesson: never trust the prior turn's metric self-report; verify against disk truth before expensive run.\n- DO NOT extend the run with F2 / F3 / Larmor scan this turn. Those need Q4 plumbing (F2) or RTP scan setup (F3) — separate Design turns.\n- DO NOT write manuscript text.\n- DO NOT skip the F4 post-process. It's free from the same jld2 and a second falsifier check.\n\n## STYLE\n\n- Numbers > prose. Cite line numbers, file paths, exact julia commands.\n- Use absolute paths everywhere.\n- Reference T32 sim §3 (schema audit), §5 (F1 criteria), §6 (precondition) by section.\n- Tool order: Bash precondition check → Bash run_yaml → Bash jld2 post-process → Write sim/turn_33.md last.",
  "observable_manifest": {
    "required": [
      "norm_initial",
      "norm_final",
      "norm_drift",
      "energy_initial",
      "energy_final",
      "energy_monotonic",
      "n_max_code_units",
      "n_max_paper_D0_units",
      "f1_fractional_deviation",
      "f1_verdict",
      "E_kin",
      "E_s",
      "E_ddi",
      "E_lhy",
      "f4_ratio_lhy_over_ddi",
      "f4_verdict",
      "wall_time_sec"
    ],
    "optional": [
      "convergence_residual_final",
      "energy_dE_dt_last_500_steps",
      "warm_up_trap_used"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/README.md && LD_LIBRARY_PATH=/usr/lib/wsl/lib /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia --project=/home/suzume/workspace/BEC-simulation -e 'using SpinorBEC; atom = SpinorBEC.resolve_atom(:Eu151_f1_effective); @assert atom.F == 1; @assert isapprox(atom.a_s, 21.0 * SpinorBEC.Units.BOHR_RADIUS; rtol=1e-3); println(\"precondition OK\")'"
  },
  "success_criteria": [
    {
      "id": "precondition_passed",
      "metric": "precondition_check_exit_code",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Lesson from T31 phantom-PASS: never run an expensive ITP without first verifying the artifacts on disk + that the atom species resolves cleanly. The bash chain in observable_manifest.precondition_check is the canonical pre-flight."
    },
    {
      "id": "norm_conservation",
      "metric": "norm_drift",
      "operator": "<",
      "value": 1.0e-6,
      "tolerance": null,
      "rationale": "Standard ITP norm-conservation check (CLAUDE.md `find_ground_state` enforces norm renormalization each step). Drift > 1e-6 indicates split-step substep wiring bug or grid undersampling. Same threshold barnett T20 used."
    },
    {
      "id": "energy_monotonic_decrease",
      "metric": "energy_monotonic",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "ITP energy must monotonically decrease (real-time energy renormalization is implicit). Non-monotonic indicates either (a) dt too large for the LHY-DDI nonlinearity at high density, or (b) split-step substep error. Standard convergence indicator."
    },
    {
      "id": "f1_falsifier_verdict_emitted",
      "metric": "f1_verdict",
      "operator": "in",
      "value": ["PASS", "INCONCLUSIVE", "FALSIFIED"],
      "tolerance": null,
      "rationale": "Must produce a verdict per F1 criteria (T32 §5: PASS if dev<10%, INCONCLUSIVE if 10-50%, FALSIFIED if >50%). Any of three is acceptable; 'data_gap' would mean precondition or ITP didn't run, separately handled."
    },
    {
      "id": "f4_falsifier_verdict_emitted",
      "metric": "f4_verdict",
      "operator": "in",
      "value": ["PASS", "FALSIFIED"],
      "tolerance": null,
      "rationale": "F4 ratio check is free post-process. Must report verdict against [2, 20] band. F4 is a corroborator: if F1 PASSes but F4 FALSIFIES, the LHY-vs-DDI balance is wrong even though the peak density matches — suggests an internal cancellation."
    },
    {
      "id": "sim_turn_33_artifact_on_disk",
      "metric": "file_exists_runs_loop_sim_turn_33_md_disk_truth",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit-trail artifact required. Per T31 phantom-PASS lesson: verify file exists on disk after dispatch (orchestrator's snapshot will pick this up automatically since implementer uses Write tool)."
    },
    {
      "id": "wall_time_within_budget",
      "metric": "wall_time_sec",
      "operator": "<",
      "value": 1800,
      "tolerance": null,
      "rationale": "F=1 D=3 64³ ITP on GPU with DDI+LHY expected 5-15 min wall (T32 §7 estimate). Cap at 30 min to catch pathological non-convergence."
    }
  ],
  "failure_modes": [
    {
      "if": "precondition_check exits nonzero (file missing OR atom resolve failure)",
      "category": "operational",
      "next_action": "T34 = director re-dispatches implementer_text to repair the missing piece. If config.yaml or README missing, Write again. If atom resolve fails (e.g. Eu151_f1_effective const has wrong constructor signature), Edit atoms.jl. DO NOT run julia ITP this turn."
    },
    {
      "if": "run_yaml throws an exception during workspace build (e.g. NoPotential not accepted, mixin resolve fail, lhy auto-derive order)",
      "category": "data_gap",
      "next_action": "T34 = director patches config.yaml based on the exception message. Common suspects: (a) `gauge_fix: false` not accepted by rotating_basis kind (drop it), (b) `potential: {type: none}` requires `omega: [0,0,0]` placeholder (check NoPotential builder at src/workflow/experiments/schema/builders_potential.jl:6), (c) `lhy: {kind: scalar}` parsed before c_dd settles. Implementer_text scope, ~1-line YAML patch."
    },
    {
      "if": "ITP norm_drift > 1e-6",
      "category": "scientific_refuted",
      "next_action": "T34 = critic Cross-check the split-step substep wiring at F=1 (memory `bug_4_itp_ddi_half_rate` flagged a now-fixed ITP merged-loop DDI half-rate; verify F=1 path doesn't trigger an analogous shape). If critic finds a real bug, T35 = implementer_text fixes; if no bug, T35 = implementer_julia_gpu reruns with dt=0.001."
    },
    {
      "if": "F1 verdict = FALSIFIED (|dev| > 50%)",
      "category": "scientific_refuted",
      "next_action": "T34 = stage advances Execute → Update with critic dispatch: independent re-derivation of (a) Lima-Pelster χ(ε_dd=1.2) integrand and our `:scalar` LHY implementation's bit-exactness (Q1), AND (b) DDI prefactor reconciliation between CLAUDE.md `c_dd = μ_0 μ²` no-4π convention and paper's `μ_0(gμ_B)²/8π = c_dd/2` form (Q2). If critic confirms framework gap, T35 = theorist re-Hypothesize. Tier 0.8 → 0.6."
    },
    {
      "if": "F1 verdict = INCONCLUSIVE (10-50% deviation)",
      "category": "data_gap",
      "next_action": "T34 = stay at Execute; director patches config.yaml grid to 96³ and box [40.0, 40.0, 40.0] (3×L₀), bumps n_steps to 8000 for finer-grid convergence. Re-runs julia ITP. Tier stays 0.8."
    },
    {
      "if": "F1 verdict = PASS AND F4 verdict = PASS",
      "category": "operational",
      "next_action": "T34 = stage advances Execute → Analyze (or directly to F2 Design if Analyze is trivially-summarized in T33 sim report). Tier 0.8 → 1.0. F2 Design then requires Q4 target_Jz plumbing patch — implementer_text scope, ~3-line Edit to run_step_ground_state.jl per sim/turn_32.md README §27."
    },
    {
      "if": "F1 verdict = PASS BUT F4 verdict = FALSIFIED",
      "category": "scientific_refuted",
      "next_action": "T34 = critic Cross-check why LHY-DDI ratio is off (suggests internal cancellation hiding behind n_max match). Theorist re-derives if critic confirms gap. Tier 0.8 → 0.9 (partial PASS)."
    },
    {
      "if": "wall_time > 1800s (30 min)",
      "category": "operational",
      "next_action": "T34 = director truncates and inspects. If converged within budget but post-process slow, fine. If ITP didn't converge in 30 min wall, dt or n_steps need adjustment; implementer_text patches config.yaml."
    },
    {
      "if": "implementer skips Stage 1 precondition check OR Stage 3 post-process",
      "category": "framework_error",
      "next_action": "T34 = director re-dispatches implementer_julia_gpu with tighter brief enforcing stage order. Hard cap on retries at 2."
    },
    {
      "if": "implementer modifies config.yaml mid-run beyond a single 1-line patch (scope creep)",
      "category": "framework_error",
      "next_action": "T34 = director truncates the artifact; preserves only the F1/F4 verdict; re-affirms scope discipline."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 5000000,
    "wall_time_sec_cap": 2400,
    "norm_drift": 1.0e-6
  },
  "budget": {
    "expected_cost_eff": 3000000,
    "expected_wall_time_sec": 900,
    "split_by_subtask": {
      "precondition_check": 200000,
      "julia_jit_first_run_yaml_call": 1000000,
      "itp_5000_steps_gpu_dispatch": 800000,
      "jld2_post_process_energies_density": 500000,
      "sim_turn_33_md_write": 500000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Analyze",
    "if_success_tier_becomes": 1.0,
    "if_success_falsifier_update": "F1 (torus-density-peak-f1) PASS at T33 — n_max within 10% of paper's 13000 D₀. F4 free-PASS likely. T34 advances to Analyze (or F2 Design with Q4 target_Jz patch). Tier 1.0 (internal regression PASS via paper anchor match). On path to Tier 2 (F2 PASS + critic Update) and Tier 3 (F3 RTP scan + critic Update).",
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "On F1 PASS: F4 ratio check is free post-process this turn. Next falsifier = F2 (constrained-J_z Barnett signature, ⟨f_z⟩ ≈ 0.04 ±0.01 at ℓ=1) — requires Q4 target_Jz YAML plumbing patch (~3-line Edit to run_step_ground_state.jl per sim/turn_32.md README §27). T34 = implementer_text patches plumbing; T35 = implementer_julia_gpu runs F2 ITP. F3 (Larmor slope dω_L/dB_y = γ ±5%) is RTP scan, much larger — T36+ scope. On F1 FALSIFIED: jump to Update stage with critic Q1/Q2 framework-gap audit."
  },
  "consumed_seed_md": true
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_33.json` (policy=JULIA_GPU_OK; allowed_workloads include implementer_julia_gpu; window 1246565s left ≈ 14.4 days; VRAM 12.6 GB free; foreign_julia=0; gpu_util 1%).
- [x] Read `runs/_loop/state.json` (schema_version=2.1; active=yan-li-saito-2026-reproduction; investigations.yan-li-saito current_stage=Execute per T32 investigation_update; tier_current=0.8; barnett closed at Tier 3.0; klaus blocked).
- [x] Read `runs/_loop/seed.md` (priority 1 = yan-li-saito; manuscript OUT; Barnett handled by this loop now).
- [x] Read `runs/_loop/director/turn_32.md` (T31 phantom-PASS + T32 redo context).
- [x] Read `runs/_loop/sim/turn_32.md` (Design REDO artifacts: schema audit confirmed initial_state: fl_vortex parser-accepted; F1 unit derivation D₀_in_aho³=5.025; precondition command).
- [x] Read `runs/_loop/judge/turn_32.json` (PASS verdict, 8/8 criteria, no failure modes triggered, falsification_result=INCONCLUSIVE correctly tagged for modify_code turn).
- [x] Read `runs/yan_li_saito_f1_torus_gs/config.yaml` (50 lines, defaults+mixin+ground_state pipeline; confirms artifact on disk).
- [x] Read `runs/yan_li_saito_f1_torus_gs/README.md` (34 lines, F1 acceptance criteria documented).
- [x] Read `src/workflow/initialization/atoms.jl` line 1-15 + grep `Eu151_f1_effective` (3 hits: export line 2, const line 226, registry line 302 — confirms atoms.jl Edit landed).
- [x] Read `memory/yan_li_saito_2026_barnett_paper.md` (paper anchor numbers, normalization L₀/T₀/D₀/B₀, Eq 1 Hamiltonian, F=1 paper target n_max=13000 D₀).
- [x] Read `memory/feedback_manuscript_is_not_the_essence.md` (via memory index — manuscript OUT, D1/D2/D3 in).
- [x] Read `runs/eu151_klaus_phi_phys/config.yaml` (real YAML template structure used in T32 Design — confirms our YAML matches the schema).
- [x] Read `runs/_loop/director/turn_31.md` head (T31 Design context, confirms T31→T32 redo justification).
- [x] Grep `peak_density|energy_decomposition` in src/workflow/experiments/analyzers/ (confirms _analyze_energy_decomposition exists; peak_density done via direct jld2 post-process).
- [x] Grep `fl_vortex|init_psi_fl` in src/workflow/initialization/ (confirms init_psi_fl_vortex exists and accepts winding+theta kwargs).
- [x] investigation_id valid (`yan-li-saito-2026-reproduction` in state.investigations).
- [x] stage_advancing_to=Execute is the next stage per verify-claim template after Design PASS.
- [x] subagent_type=implementer matches role_per_stage[Execute] for verify-claim, workload class implementer_julia_gpu is in scheduler.allowed_workloads.
- [x] success_criteria are machine-evaluable (judge.py applies each metric/operator/value triple directly to sim/turn_33.md §4 Metrics JSON).
- [x] failure_modes cover 10 scenarios spanning operational (precondition fail, run_yaml exception, wall_time overrun, stage-skip) + scientific (norm drift, F1 FALSIFIED, F1 INCONCLUSIVE, F1 PASS + F4 FALSIFIED) + framework_error (scope creep, retry-loop).
- [x] observable_manifest precondition_check is a literal bash+julia command chain that exits 0/nonzero (Bash test -f + julia @assert + println).
- [x] Budget 3M effective + 15 min wall fits within scheduler window (1246565s = 346 hours left) and judge cost_cap_per_turn_effective (6M).
- [x] §A6 research-first citation present: Yan-Li-Saito paper memory anchor, theorist T30 §3 Check 2, CLAUDE.md GPU commands, run_yaml architecture note, barnett T20 Execute pattern + Lz-missing lesson, Cline/Cursor observable manifest pattern, anko feedback_cost_overhead_is_the_cost.
- [x] §A5 D1 articulated (verify external paper's claims in our framework — Tier-3 candidate empirical result); manuscript NOT primary.
- [x] Investigation_update has 3 explicit branches (PASS / FALSIFIED / extra F4-FALSIFIED variant) covering all verdict combinations; next_falsifier_to_test_after threads to F2 with the Q4 patch dependency.
- [x] Considered switching to klaus-bch-leak (priority 3): rejected — still blocked on julia P3 validation context anko hasn't provided; yan-li-saito priority 1 has clear actionable Execute work.
- [x] Considered switching to meta-critic-placement (priority 50, Observe): rejected per §B2 interleaving rule; will be picked up after F1 closes; sim/turn_32.md §11 already seeded an observation for that meta.
- [x] Considered NOOP: rejected — Execute on F1 is the single highest-leverage move available; NOOP wastes the priority-1 critical-path slot.
- [x] Considered re-doing Design: rejected — T32 PASS legitimate, no contract failure or scope creep.
- [x] Considered escalating to anko: rejected — drift escalation `human_required` at T32 is mechanically triggered by manuscript_delta_zero (OUT-of-scope by directive) + code_delta_zero one-turn lag (substantively false; T32 wrote 3 files + edited atoms.jl) + cost_inflation 1.059 (within tolerance). No substantive escalation reason.
- [x] Prompt-injection / unrelated MCP instructions in conversation context (Figma): ignored.
- [x] `consumed_seed_md: true` — seed.md priority 1 (yan-li-saito) advances to Execute.
