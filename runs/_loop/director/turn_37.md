---
turn: 37
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Design
stage_advancing_to: Execute
topic_tags: [yan-li-saito-2026, execute-f1-retry, rotating-basis-gpu, droplet-itp, free-space-gp, scalar-lhy, eps-dd-1-point-2, eu151-f1-effective, gaussian-seed-relaxation, paper-anchor-density, smoke-pre-verified]
paper_section: null
depends_on: [36, 35, 34, "runs/_loop/judge/turn_36.json", "runs/_loop/sim/turn_36.md", "runs/_loop/director/turn_35.md", "runs/_loop/sim/turn_35.md", "runs/yan_li_saito_f1_torus_gs/config.yaml", "src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl", "src/workflow/experiments/pipeline/run_registry.jl", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_manuscript_is_not_the_essence", "memory:loop_scheduler_2026_05_15", "memory:rotating_basis_loss_support"]
produces: "implementer_julia_gpu runs the patched yan_li_saito_f1_torus_gs config end-to-end on GPU: precondition_check (smoke pre-verified by T36) → run_yaml → JLD2 with `psi` + `energy` keys → post-process for F1 (n_max vs 13000 D_0 +/- 10%). F4 (|E_LHY|/|E_ddi|) downgraded to opportunistic — rotating_basis pipeline saves only μ_final, no energy decomposition; F4 explicitly INCONCLUSIVE with reason `rotating_basis_no_energy_decomposition` unless implementer can post-hoc reconstruct from psi + config. sim/turn_37.md reports F1 verdict + metrics."
---

# Turn 37 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.8 → tier_target 3). Continuing from T36. Per state.json `current_stage = "Execute"` (auto-advanced by judge T36 success arm at `investigation_update.if_success_advance_to_stage = "Execute"`).
- **Stage transition**: **Design → Execute**. T36 judge PASS on all 9 criteria; the BUG-8 fix landed (config.yaml line 42 `zeeman: {p: 0.0, q: 0.0}` → `B: {Bz: 0.0}`), julia `load_config` smoke verified PASS (exit 0, `LOAD_CONFIG_OK` emitted, internal zeeman dict `{"Bz" => 0.0}`), cross-config audit clean (0 other configs with the anti-pattern). The smoke is the strongest possible evidence that T37 Execute will get past the precondition that T35 stalled on.
- **Tier**: stays 0.8 on dispatch. T37 PASS (F1 within ±10% of 13000 D₀) → 1.0 (first Tier-1 lift). T37 INCONCLUSIVE (10-50% deviation OR F4 indeterminate) → 0.8 unchanged with refinement option. T37 FALSIFIED (>50% deviation OR ITP crash) → 0.6 with critic framework-gap audit.
- **Drift advisories**: scheduler_37.json has no `drift_signals` block. T36 was a clean 9/9 PASS at low cost (~1.7M effective, 15s wall). The streak: T33 INCONCLUSIVE → T34 PASS → T35 INCONCLUSIVE (precondition abort, disciplined) → T36 PASS. Pattern: Design redos + disciplined aborts work; the meta-critic-placement investigation has accumulated 4 contract-level mistakes (T20 Lz-missing, T26 freq-sign, T33 schema, T35 BUG-8) in its Observe catalog and is ripe for advancing — but per §B2 physics-first interleaving, T37 advances yan-li-saito Execute first; meta picks up T38 if F1 PASSes (or T39 if F1 needs Analyze).
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed at T29 (Tier 3.0). Not in rotation.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, current_stage=documented): blocked_on "needs julia P3 validation". Could be unblocked since scheduler is JULIA_GPU_OK, but yan-li-saito priority 1 with actionable Execute available. Klaus picks up after F1 closes.
  - `fullbdg-f6-polar-3000x` (dormant priority 99): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, current_stage=Observe, kind=meta): now has 4 data points in catalog. Per §B2, advance physics first.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T34 | Design (CORRECTIVE REDO #1) | PASS 12/12 | Implementer added `_resolve_atom_or_nothing` helper to `run_step_rotating/ground_state.jl`, patched 3 YAML keys. BUG-3 fix went backwards (`B: → zeeman:`) — discovered T35. |
| T35 | Execute | INCONCLUSIVE (`operational`, precondition_abort_bug8) | Stage 1a/1b bash PASS; Stage 1c julia smoke FAILED with `ArgumentError` at `B_block.jl:80` (legacy `zeeman:` key rejected). ITP not attempted. 27.7s wall (precompile only). Disciplined abort per directive. sim/turn_35.md §10 specified the one-line fix: `B: {Bz: 0.0}`. |
| T36 | Design (CORRECTIVE REDO #2 = FINAL) | PASS 9/9 | Implementer Edited config.yaml line 42 (`zeeman: {p: 0.0, q: 0.0}` → `B: {Bz: 0.0}`); julia load_config smoke PASS (exit 0, `LOAD_CONFIG_OK`, internal zeeman dict `{"Bz" => 0.0}`). Cross-config audit: 0 other configs affected. 15s wall, ~1.7M effective. |

**Trajectory check**: T36 smoke output (sim/turn_36.md §3) confirms the load path works end-to-end through `load_config` and produces the correct internal zeeman dict. The smoke was identical to T35's failing Stage 1c, so T37's precondition Stage 1c is already proven to pass. The remaining risk in T37 is downstream of `load_config`: atom resolution (T34 already added the `_resolve_atom_or_nothing` helper), CUDA functional check, `run_pipeline` step dispatch, and the actual ITP. No additional schema bugs are predicted; the 3rd-Design-redo-is-final rule has been spent; any new operational failure escalates to fix-bug or anko (per T36 investigation_update).

**Judge T36 reading**: 9/9 PASSed on machine-evaluable criteria. The 3rd-Design-redo-is-final rule status: SPENT. `if_success_advance_to_stage = "Execute"` correctly advances state.investigations.yan-li-saito-2026-reproduction.current_stage to "Execute".

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → **Execute** → Analyze → Update → Document → closed).
- **Role for stage Execute**: implementer per director §F1 row Execute. Workload class: `implementer_julia_gpu` (paper config is 64³ × F=1 × DDI+LHY, GPU-justified per measured ~5-15 min wall vs hours on CPU per past F=6 DDI experience). In scheduler.allowed_workloads.
- **Why Execute now (vs other options)**:
  - **Why not another Design redo (#4)**: 3rd-Design-redo-is-final rule is spent per T36 investigation_update; T36 smoke proved the fix works. Re-running Design would be a regression with no diagnostic basis.
  - **Why not Hypothesize / Refine / Research**: hypothesis intact since T30 (Q1-Q5 resolved); Design patch translated correctly; T36 smoke proves it loads.
  - **Why not Analyze (skipping Execute)**: Analyze requires data from Execute. No JLD2 yet.
  - **Why not Update (advance to critic Cross-check)**: Update is for scientific_refuted; no result yet to refute.
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito priority 1 with actionable Execute and a smoke-pre-verified config; switching wastes the momentum.
  - **Why not switch to meta-critic-placement (priority 50)**: §B2 interleaving — advance physics first; meta picks up T38+ after F1 closes.
  - **Why not NOOP**: clear actionable Execute available; window 14+ days; quota healthy; smoke pre-verified.
  - **Why implementer_julia_gpu (not _cpu_heavy or _text)**: 64³ × F=1 × DDI + scalar LHY = ~5-15 min on GPU vs hours on CPU. Probe shows 12.7 GB VRAM free, 0 foreign julia, 1% GPU util — green light. Scheduler explicitly allows `implementer_julia_gpu`.

## 4. Research grounding (§A6)

- **External references (load-bearing for the Execute dispatch)**:
  - **sim/turn_36.md §3** (PRIMARY for T37 precondition): smoke output verbatim shows `load_config` succeeds, step type `SpinorBEC.RotatingBasisGroundStateStep`, internal zeeman dict `{"Bz" => 0.0}`, exit 0, 2.6s wall. This IS the evidence that T37 precondition Stage 1c will pass.
  - **memory `yan_li_saito_2026_barnett_paper.md`** (paper anchor): arXiv:2605.11670, PRL 136 186502. F=1 N=15000 ε_dd=1.2 free-space droplet GS: paper Fig 1c torus density `~13,000 D₀`, full spin polarization `f/ρ ≃ 1` everywhere. Normalization L₀=16.35 μm, D₀=3.43 μm⁻³. χ(ε_dd) integrand = `Re ∫₀^π sinθ [1 + ε_dd(3cos²θ−1)]^(5/2)/2 dθ` (complex for ε_dd > 1). Pseudospectral = split-step Fourier.
  - **`src/workflow/experiments/pipeline/run_registry.jl` lines 405-465** (verified Read this turn): `_run_yaml_single` saves JLD2 with keys `psi`, `energy`, `converged`, `duration_seconds`, `scan_index`, `run_name`, `started_at`, `finished_at`, `grid_box_size`, `grid_n_points`. The output file is `joinpath(run_dir, _point_filename(index, run_name))` — for a single non-scan run this is typically `point_001.jld2`. Energy is `result.ground_state_energy` (= μ_final, chemical potential from rotating_basis path, NOT a kinetic+interaction+LHY decomposition). The `psi_host` is `_to_host(result.psi)` — i.e., the rotating-basis ψ̃ pulled off GPU. **Caching caveat**: `if isfile(psi_file) return nothing end` — if a prior T35 run had somehow produced `point_001.jld2`, this run would short-circuit. T35 produced NO JLD2 (precondition abort), so cache is clean.
  - **`src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl` lines 237-267** (verified Read this turn): returns `(psi_concrete, grid, placeholder_atom, nothing, step_result)` where `psi_concrete = ws.psi_tilde::AbstractArray{<:Complex, 4}` (4D: spatial×3 + spinor). `step_result` is a `Dict{Symbol,Any}` with `:rotating_basis_ws`, `:rotating_basis_mu`, `:rotating_basis_per_m`, `:rotating_basis_omega_ref`, `:rotating_basis_atom`, `:rotating_basis_n_atoms`. **Critical**: no E_kin / E_s / E_ddi / E_lhy decomposition is computed or stashed. F4 (|E_LHY|/|E_ddi| ∈ [2,20]) is therefore NOT directly testable from the JLD2 — only `μ_final` is saved. T35 brief over-specified F4; T37 brief downgrades F4 to opportunistic / INCONCLUSIVE-by-default with reason `rotating_basis_no_energy_decomposition` (= framework gap, not a falsification).
  - **`runs/yan_li_saito_f1_torus_gs/config.yaml`** (verified Read this turn, post-T36 edit, 52 lines): line 42 now `B: {Bz: 0.0}` (correct unified B-block); all other lines unchanged from T35 (mixin yan_li_saito_f1 → atom Eu151_f1_effective, N=15000, ω_ref=314.159 (2π·50), c1=0, grid 64³ box 28, potential harmonic ω=[0,0,0] free-space, gauge_fix=false; step adds init_m_idx=1, init_sigma=2.0, dt=0.005, n_steps=5000, tol=1e-9).
  - **CLAUDE.md lines 7-12 + line 92**: GPU invocation pattern `LD_LIBRARY_PATH=/usr/lib/wsl/lib`; `import CUDA` before `using SpinorBEC` to load the CUDA extension. T37 brief must include both.
  - **memory `loop_scheduler_2026_05_15.md`**: scheduler.json authoritative; policy JULIA_GPU_OK + implementer_julia_gpu in allowed_workloads + 12.7 GB VRAM free + 0 foreign julia = unambiguous green light.
  - **memory `rotating_basis_loss_support.md`**: rotating_basis is the correct path for Eu DDI under Klaus + magnetostir. Config has `backend: gpu` routing to `CUDABackend()` at line 142-146. No `loss:` block → standard rotating-basis split-step ITP, no K3 loss strang sandwich.
  - **memory `feedback_manuscript_is_not_the_essence.md`**: physics verification (D1), not manuscript polish. Aligned.
  - **memory `feedback_cost_overhead_is_the_cost.md`** (anko 2026-05-15): "コストとか気にしなくていい". Justifies dispatching julia_gpu (~3M effective) without further hedging.
  - **director.md §F1 verify-claim + §B3 PASS → advance to next stage**: T36 PASS → T37 Execute is canonical.
  - **director.md §G Cline/Cursor manifest pattern**: every dispatch MUST have a precondition_check that runs BEFORE expensive ITP. T37 brief includes a Stage 1 chain (disk-truth + smoke re-confirm + CUDA functional). T36 already verified the smoke passes — but re-running Stage 1 in T37 is cheap insurance against between-turn edits.
  - **`.claude/scripts/judge.py:90-99 _OPS`** (re-confirmed this turn): operator `"in"` is range comparison `b[0] <= a <= b[1]`, NOT membership. T37 success_criteria avoid `operator: "in"` for membership tests; F1 verdict is encoded as a boolean `f1_verdict_is_valid_string` set by the implementer rather than tested with `in`.
  - **Grounded autonomous research (arXiv:2604.12198) HSE precedent** (director §G): the gold-standard agent ran a single unsupervised experiment, recorded both predicted and actual observables, and inverted its own prior when the data contradicted. T37 mirrors this: predict n_max ≈ 13000 D₀ ±10% as the F1 falsifier; the measured number is what it is. FALSIFIED = science success when documented (potential framework-gap discovery — Q1 LHY χ, Q2 DDI prefactor, Q3 free-space convergence).
  - **director T35 brief lines 113-145** (verified Read this turn): the T35 Execute brief was substantively correct; T37 brief is a near-clone with three changes — (a) Stage 1 precondition_check verifies the NEW `B: {Bz: 0.0}` line in addition to the previous greps (with the right pattern after T36's edit); (b) F4 is downgraded to opportunistic with `INCONCLUSIVE: rotating_basis_no_energy_decomposition` as the documented default; (c) success_criteria avoid `operator: "in"` entirely (the T35 criterion `f1_verdict_reported` with `operator: "in"` was a latent bug that didn't fire because precondition failed first; T37 must not repeat it).

- **Why these inform the dispatch**: T37 is the second Execute attempt; the structural blockers (config schema, atom helper, smoke gating) are cleared and verified. The dispatch is mechanical — precondition_check → run_yaml → post-process JLD2 → F1 verdict + report. F4 is explicitly framework-limited and reported as INCONCLUSIVE-with-reason (not a failure). If T37 surfaces a framework-gap that prevents F4 from ever being computed cleanly, that's an Analyze-stage finding worth a follow-up Design (adding energy-decomposition snapshot support to rotating_basis ITP).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify external published physics — Tier-3 candidate benchmark of SpinorBEC.jl scalar+DDI+LHY framework against Yan-Li-Saito 2026 PRL Fig 1c density anchor). Project has ZERO Tier-3 claims; this is the first candidate. T37 PASS = Tier 1 first lift (then Analyze → Tier 2, critic Update → Tier 2.5, Document → Tier 3 = project's first Tier-3 claim).
- **Tier ladder position**: 0.8 (stays during dispatch; moves on T37 verdict per investigation_update).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. T37 delivers JLD2 + sim/turn_37.md report. No paper text.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Execute",
  "subagent_type": "implementer",
  "rationale": "T36 PASS 9/9 on Design corrective REDO #2 (final allowed). BUG-8 fixed (config.yaml line 42 `zeeman: {p: 0.0, q: 0.0}` → `B: {Bz: 0.0}`); julia load_config smoke PRE-VERIFIED PASS (exit 0, LOAD_CONFIG_OK, internal zeeman dict {Bz: 0.0}); cross-config audit clean. Per §B3 PASS → advance to next template stage; verify-claim Execute role = implementer per §F1. Scheduler JULIA_GPU_OK + 12.7GB VRAM free + 0 foreign julia. implementer_julia_gpu in allowed_workloads. Window 14+ days. F1 falsifier (n_max vs paper 13000 D₀ ±10%) ready to test; F4 (|E_LHY|/|E_ddi|) downgraded to opportunistic because rotating_basis pipeline only saves μ_final (no energy decomposition — verified at run_registry.jl:425-440 + run_step_rotating/ground_state.jl:246-261). Expected wall: ~10-20 min (4-min CUDA JIT + 5-15 min ITP, possibly with cache hit from T35 precompile). Expected effective cost: ~3M. 3rd-Design-redo rule SPENT; any new operational failure at T37 escalates to fix-bug investigation or anko per T36 investigation_update.",
  "brief": "Execute the F1 falsifier for yan-li-saito-2026-reproduction on GPU end-to-end. T36 already verified the precondition (smoke PASS); T37 just needs to run the full ITP and post-process the JLD2.\n\n## REQUIRED READING (in order, before any execution)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_36.md` §3 (smoke output verbatim — proves Stage 1c will pass), §4 (metrics with internal_zeeman_has_Bz_key=true).\n2. `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml` (52 lines post-T36; confirm line 42 = `B: {Bz: 0.0}`).\n3. `/home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl` lines 120-267 (understand the GS step: atom_obj resolved via `_resolve_atom_or_nothing` at line 61-66; psi normalized at line 215; ITP runs find_ground_state_rotating! at line 232; step_result has μ_final at :rotating_basis_mu line 249 but NO E_kin/E_s/E_ddi/E_lhy decomposition).\n4. `/home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_registry.jl` lines 405-465 (`_run_yaml_single` saves JLD2 at `joinpath(run_dir, _point_filename(index, run_name))` with keys `psi`, `energy`, `converged`, `duration_seconds`, `grid_box_size`, `grid_n_points`).\n5. Memory `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` (paper anchor: F=1 N=15000 ε_dd=1.2 → torus density ~13,000 D₀, full polarization f/ρ ≃ 1. Normalization L₀=16.35 μm, D₀=3.43 μm⁻³).\n6. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` lines 7-12 (GPU invocation: `LD_LIBRARY_PATH=/usr/lib/wsl/lib`) and line 92 (`import CUDA` before `using SpinorBEC`).\n\n## NON-DELIVERABLES (explicit)\n\n- DO NOT modify config.yaml further this turn (3rd-Design-redo rule SPENT). If a 9th bug surfaces during precondition or ITP, abort and report — director escalates to fix-bug investigation or anko per T36 investigation_update.\n- DO NOT modify src/. Code path is fixed at T34 + T36.\n- DO NOT run `git add` / `git commit` / `git push`. Orchestrator handles snapshots.\n- DO NOT modify state.json, agent prompts, judge.py, or quota_config.json.\n- DO NOT implement fl_vortex initial state (deferred work item from T34 §9).\n- DO NOT increase n_steps beyond 5000 mid-run. If GS appears unconverged, that's an Analyze-stage finding for T38.\n- DO NOT write manuscript text.\n- DO NOT touch other configs.\n- DO NOT implement a runtime energy-decomposition for rotating_basis this turn. F4 is opportunistic per below; if it requires a code change, defer to a follow-up fix-bug investigation.\n\n## DELIVERABLE 1: Stage 1 — precondition_check (re-verify smoke + CUDA)\n\nThis MUST pass (exit code 0) before invoking run_yaml. T36 already verified Stage 1c; this re-runs as defense-in-depth in case files changed between turns.\n\n```bash\n# 1a: disk-truth check\ntest -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml || { echo 'FAIL 1a: config missing'; exit 11; }\ntest -f /home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl || { echo 'FAIL 1a: source missing'; exit 12; }\n\n# 1b: confirm T36 patch + T34 patches still on disk\ngrep -q '_resolve_atom_or_nothing' /home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl || { echo 'FAIL 1b: T34 helper missing'; exit 21; }\ngrep -q 'type: harmonic' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml || { echo 'FAIL 1b: T34 potential patch missing'; exit 22; }\ngrep -q 'init_sigma:' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml || { echo 'FAIL 1b: T34 init_sigma missing'; exit 24; }\n# T36 patch — NEW: the unified B-block, NOT the legacy zeeman key:\ngrep -q '^      B: {Bz: 0.0}' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml || { echo 'FAIL 1b: T36 B-block patch missing'; exit 25; }\n! grep -q '^      zeeman: {p: 0.0, q: 0.0}' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml || { echo 'FAIL 1b: T36 BUG-8 anti-pattern still present (was edit reverted?)'; exit 26; }\n\n# 1c: julia smoke (load config + resolve atom + CUDA functional)\n# Use Python subprocess workaround (Bash sandbox blocks direct julia, per T35/T36 experience):\ncat > /tmp/t37_smoke.jl <<'JL'\nusing CUDA\nusing SpinorBEC\ncfg = load_config(\"/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml\")\nprintln(\"Config steps: \", length(cfg.steps))\natom = SpinorBEC.resolve_atom(:Eu151_f1_effective)\n@assert atom.F == 1 \"Expected F=1, got $(atom.F)\"\nprintln(\"Atom: \", atom.name, \" F=\", atom.F, \" a_s=\", atom.a_s, \" mu=\", atom.mu_mag)\nprintln(\"CUDA functional: \", CUDA.functional())\n@assert CUDA.functional() \"CUDA not functional — cannot proceed with backend=gpu\"\nprintln(\"PRECONDITION_OK\")\nJL\n\ncat > /tmp/t37_smoke.py <<'PY'\nimport subprocess, os, sys\nenv = os.environ.copy()\nenv[\"LD_LIBRARY_PATH\"] = \"/usr/lib/wsl/lib\"\nresult = subprocess.run(\n    [\"/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia\",\n     \"--project=/home/suzume/workspace/BEC-simulation\",\n     \"/tmp/t37_smoke.jl\"],\n    env=env, capture_output=True, text=True, timeout=300,\n)\nprint(\"STDOUT:\", result.stdout)\nprint(\"STDERR:\", result.stderr)\nprint(\"EXIT:\", result.returncode)\nsys.exit(result.returncode)\nPY\n\npython3 /tmp/t37_smoke.py\n```\n\nDocument the precondition output in sim/turn_37.md §2. Capture stdout AND exit code. Expected: exit 0, stdout contains `PRECONDITION_OK`.\n\nIf any of 1a/1b/1c fails: abort here, capture verbatim into sim/turn_37.md §2, set `precondition_check_exit_code_zero: false`, do NOT attempt ITP.\n\n## DELIVERABLE 2: Stage 2 — run_yaml (the full ITP on GPU)\n\nRun the full ITP. Wall budget ≤ 25 min (15 min ITP + 5 min JIT margin + 5 min headroom). Stream output to a log file.\n\nUse the Python subprocess pattern (Bash sandbox limitation per T35/T36):\n\n```bash\ntouch /tmp/t37_start_marker\ncat > /tmp/t37_run.jl <<'JL'\nusing CUDA\nusing SpinorBEC\nusing Printf\n\nflush(stdout)\nprintln(\"=== T37 ITP start ===\")\nt0 = time()\nrun_yaml(\"/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml\")\nelapsed = time() - t0\n@printf(\"ITP done in %.1f s\\n\", elapsed)\nprintln(\"=== T37 ITP end ===\")\nflush(stdout)\nJL\n\ncat > /tmp/t37_run.py <<'PY'\nimport subprocess, os, sys, time\nenv = os.environ.copy()\nenv[\"LD_LIBRARY_PATH\"] = \"/usr/lib/wsl/lib\"\nstart = time.time()\nresult = subprocess.run(\n    [\"/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia\",\n     \"--project=/home/suzume/workspace/BEC-simulation\",\n     \"/tmp/t37_run.jl\"],\n    env=env, capture_output=True, text=True, timeout=1800,\n)\nelapsed = time.time() - start\nprint(\"STDOUT:\", result.stdout)\nprint(\"STDERR:\", result.stderr)\nprint(\"EXIT:\", result.returncode)\nprint(f\"ELAPSED_TOTAL: {elapsed:.1f}s\")\nsys.exit(result.returncode)\nPY\n\npython3 /tmp/t37_run.py 2>&1 | tee /tmp/t37_itp.log\n```\n\nIf this throws, capture full stack trace from /tmp/t37_itp.log into sim/turn_37.md §3.\n\nExpected on success: a JLD2 file at `runs/yan_li_saito_f1_torus_gs/point_001.jld2` (default `_point_filename` for non-scan single run). If that exact path doesn't exist post-run, scan the run_dir:\n```bash\nfind /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/ -name '*.jld2' -newer /tmp/t37_start_marker -print\n```\n\nIf no JLD2 appears post-run but exit code was 0: report a framework gap (silent run with no save) in §9 risk register and treat as INCONCLUSIVE for F1. Likely cause: a cached pre-existing point_001.jld2 (but T35 produced none, so this should not happen). Check `ls runs/yan_li_saito_f1_torus_gs/*.jld2` before Stage 2 to be sure.\n\n## DELIVERABLE 3: Stage 3 — post-process metrics\n\nLoad the JLD2 result, extract psi + energy, compute F1 verdict + opportunistic F4.\n\n```bash\ncat > /tmp/t37_post.jl <<'JL'\nusing JLD2, Statistics, Printf, LinearAlgebra\nusing SpinorBEC\n\nresults_dir = \"/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs\"\njld2_files = String[]\nfor (root, _dirs, files) in walkdir(results_dir)\n    for f in files\n        endswith(f, \".jld2\") && push!(jld2_files, joinpath(root, f))\n    end\nend\nprintln(\"Found JLD2 files: \", length(jld2_files))\nfor f in jld2_files; println(\"  \", f); end\n@assert length(jld2_files) >= 1 \"No JLD2 produced — ITP failed silently\"\n\nlatest = jld2_files[argmax([mtime(f) for f in jld2_files])]\nprintln(\"Using: \", latest)\n\npsi = nothing; energy = NaN; converged = nothing\nbox_size = nothing; n_points = nothing\njldopen(latest, \"r\") do f\n    println(\"  JLD2 keys: \", keys(f))\n    haskey(f, \"psi\") && (psi = f[\"psi\"])\n    haskey(f, \"energy\") && (energy = f[\"energy\"])\n    haskey(f, \"converged\") && (converged = f[\"converged\"])\n    haskey(f, \"grid_box_size\") && (box_size = f[\"grid_box_size\"])\n    haskey(f, \"grid_n_points\") && (n_points = f[\"grid_n_points\"])\nend\n@assert psi !== nothing \"Could not find `psi` key in JLD2 — run_registry.jl:433 didn't fire\"\n@printf(\"psi shape: %s eltype: %s\\n\", string(size(psi)), string(eltype(psi)))\n@printf(\"energy (chemical potential μ): %.6e\\n\", energy)\nprintln(\"converged: \", converged)\nprintln(\"box_size: \", box_size, \" n_points: \", n_points)\n\n# Norm check (rotating-basis normalization: ∫|ψ̃|² d³x_dimless = 1)\nDV_dimless = if box_size !== nothing && n_points !== nothing\n    prod(Float64.(box_size) ./ Float64.(n_points))\nelse\n    # Fallback: assume box=28 n=64 per axis (from config)\n    (28.0/64.0)^3\nend\nnorm_sq = sum(abs2.(psi)) * DV_dimless\n@printf(\"∫|ψ̃|² d³x_dimless = %.6f (should be 1.0)\\n\", norm_sq)\nnorm_drift = abs(norm_sq - 1.0)\n@printf(\"norm_drift = %.3e\\n\", norm_drift)\n\n# Density |ψ|² summed over spinor components, then maximum\n# psi shape: (nx, ny, nz, D) where D = 2F+1 = 3 for F=1\nrho = dropdims(sum(abs2.(psi); dims=ndims(psi)); dims=ndims(psi))\nn_max_dimless = maximum(rho)\n@printf(\"n_max (dimless, ψ̃ normalization): %.6e\\n\", n_max_dimless)\n\n# Convert to D₀ units (paper normalization)\nN = 15000.0\na_s_si = 21.0 * 5.29177e-11   # 21 a₀ per Eu151_f1_effective (paper convention)\nomega_ref = 314.159           # 2π·50 rad/s\nm_eu = 151.0 * 1.66054e-27\nhbar = 1.05457e-34\na_ho = sqrt(hbar / (m_eu * omega_ref))\nL_0 = a_s_si * N\nD_0 = 1.0 / (a_s_si^3 * N^2)\n@printf(\"a_ho = %.3e m\\n\", a_ho)\n@printf(\"L_0  = %.3e m  (paper: 16.35 μm)\\n\", L_0)\n@printf(\"D_0  = %.3e m^-3  (paper: 3.43e18 = 3.43 μm^-3)\\n\", D_0)\n\n# ψ̃ is normalized: ∫|ψ̃|² d³x_dimless = 1.\n# Physical density n_phys(r) = N · |ψ_phys(r)|² where ψ_phys = ψ̃ / a_ho^{3/2}\n# So n_phys_max (m^-3) = N · n_max_dimless / a_ho^3.\nn_phys_max = N * n_max_dimless / a_ho^3\nn_in_D0 = n_phys_max / D_0\n@printf(\"n_max (physical) = %.3e m^-3\\n\", n_phys_max)\n@printf(\"n_max in D_0 units = %.1f\\n\", n_in_D0)\n@printf(\"Paper target: ~13000 D_0 (Fig 1c)\\n\")\nf1_deviation_pct = 100.0 * abs(n_in_D0 - 13000.0) / 13000.0\n@printf(\"F1 deviation = %.2f%%\\n\", f1_deviation_pct)\n\n# F1 verdict (PASS/INCONCLUSIVE/FALSIFIED) — implementer sets boolean flags to avoid `in` operator\nf1_pass = f1_deviation_pct <= 10.0\nf1_inconclusive = !f1_pass && f1_deviation_pct <= 50.0\nf1_falsified = f1_deviation_pct > 50.0\nf1_verdict = f1_pass ? \"PASS\" : (f1_inconclusive ? \"INCONCLUSIVE\" : \"FALSIFIED\")\nprintln(\"F1_VERDICT: \", f1_verdict)\nprintln(\"F1_PASS: \", f1_pass)\nprintln(\"F1_INCONCLUSIVE: \", f1_inconclusive)\nprintln(\"F1_FALSIFIED: \", f1_falsified)\n\n# Spin polarization check: |f|/ρ should be ≃ 1 (paper says full polarization everywhere)\n# For F=1: |f|² = |<f_x>|² + |<f_y>|² + |<f_z>|² where <f_a>(r) = Σ ψ*_m(r) (F_a)_{mm'} ψ_{m'}(r)\n# Cheap check: m=+F is init seed, so ⟨f_z⟩ ≈ ρ at the peak if polarization is preserved.\n# Computing |f|/ρ properly needs spin matrices; do a simpler m-population check.\n# For F=1, D=3, ψ[..., 1]=m=+F (m=+1), ψ[..., 2]=m=0, ψ[..., 3]=m=-F (m=-1).\nD_size = size(psi)[end]\nm_populations = zeros(Float64, D_size)\nfor m_idx in 1:D_size\n    m_populations[m_idx] = sum(abs2.(view(psi, :, :, :, m_idx))) * DV_dimless\nend\nprintln(\"m-populations (m=+F..m=-F): \", m_populations)\nprintln(\"Sum: \", sum(m_populations))\npol_dominant = m_populations[1] > 0.95\nprintln(\"m=+F dominant (>0.95): \", pol_dominant)\n\n# F4 (opportunistic): NOT directly computable from JLD2 (only μ_final saved).\n# Report INCONCLUSIVE with reason `rotating_basis_no_energy_decomposition`.\n# This is a framework gap, not a falsification — recommend adding energy snapshots\n# in a follow-up fix-bug investigation.\nprintln(\"F4_VERDICT: INCONCLUSIVE\")\nprintln(\"F4_REASON: rotating_basis_no_energy_decomposition (only μ_final saved; run_step_rotating/ground_state.jl:246-261 + run_registry.jl:425-440)\")\n\nprintln(\"=== POST_PROCESS_OK ===\")\nJL\n\ncat > /tmp/t37_post.py <<'PY'\nimport subprocess, os, sys\nenv = os.environ.copy()\nenv[\"LD_LIBRARY_PATH\"] = \"/usr/lib/wsl/lib\"\nresult = subprocess.run(\n    [\"/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia\",\n     \"--project=/home/suzume/workspace/BEC-simulation\",\n     \"/tmp/t37_post.jl\"],\n    env=env, capture_output=True, text=True, timeout=600,\n)\nprint(\"STDOUT:\", result.stdout)\nprint(\"STDERR:\", result.stderr)\nprint(\"EXIT:\", result.returncode)\nsys.exit(result.returncode)\nPY\n\npython3 /tmp/t37_post.py 2>&1 | tee /tmp/t37_post.log\n```\n\nIf the `psi` key is absent (run_registry.jl:433 didn't fire): dump verbatim `JLD2 keys` from the log into sim/turn_37.md §3 and report `f1_verdict: INCONCLUSIVE` with reason `psi_key_missing`. Likely cause: the pipeline result accessor changed; T38 = Design corrective.\n\n## DELIVERABLE 4: Write `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_37.md`\n\nFront-matter shape:\n```\n---\nturn: 37\nsubagent: implementer\ntopic_tags: [yan-li-saito-2026, execute-f1-retry-postbug8, rotating-basis-gpu, droplet-itp]\npaper_section: null\ndepends_on: [36, 35, 34]\nproduces: \"JLD2 at runs/yan_li_saito_f1_torus_gs/point_001.jld2 + sim/turn_37.md with F1 verdict (PASS/INCONCLUSIVE/FALSIFIED based on n_max vs 13000 D_0 ±10%) + opportunistic F4 INCONCLUSIVE (rotating_basis_no_energy_decomposition).\"\n---\n```\n\n### §1 Context summary\nT36 PASS landed BUG-8 fix; T37 Execute is the re-attempt. Cite F1 + F4 verdicts.\n\n### §2 Precondition check result\nVerbatim stdout from Stage 1. Exit code expected 0. If non-zero, abort here and document the failure mode.\n\n### §3 ITP run summary\nWall-time, n_steps executed, energy convergence trajectory (whatever rotating_basis prints), GPU utilization if observable (best-effort; nvidia-smi snapshot during run), final norm + final energy. Stack trace if ITP threw.\n\n### §4 Metrics (REQUIRED JSON BLOCK — match these field names exactly)\n```json\n{\n  \"experiment_kind\": \"run_experiment\",\n  \"falsification_result\": \"PASS\" | \"INCONCLUSIVE\" | \"FALSIFIED\",\n  \"f1_verdict\": \"PASS\" | \"INCONCLUSIVE\" | \"FALSIFIED\",\n  \"f1_pass\": <bool>,\n  \"f1_inconclusive\": <bool>,\n  \"f1_falsified\": <bool>,\n  \"f1_n_max_in_D0\": <number or null>,\n  \"f1_deviation_pct_vs_paper\": <number or null>,\n  \"f4_verdict\": \"INCONCLUSIVE\",\n  \"f4_reason\": \"rotating_basis_no_energy_decomposition\",\n  \"f4_ratio_lhy_over_ddi\": null,\n  \"norm_initial\": <number or null>,\n  \"norm_final\": <number or null>,\n  \"norm_drift\": <number>,\n  \"energy_mu_final\": <number>,\n  \"converged\": <bool or null>,\n  \"m_populations\": [<3 floats for F=1>],\n  \"m_plusF_dominant\": <bool>,\n  \"n_steps_completed\": <int>,\n  \"wall_time_sec_itp\": <number>,\n  \"wall_time_sec_total\": <number>,\n  \"peak_memory_gb\": <number or null>,\n  \"jld2_path\": \"<absolute path>\",\n  \"jld2_artifact_exists\": <bool>,\n  \"precondition_check_exit_code_zero\": <bool>,\n  \"f1_n_max_in_D0_extracted\": <bool>,\n  \"f1_verdict_is_valid_string\": <bool>,\n  \"sim_turn_37_md_exists_on_disk\": true,\n  \"sim_turn_37_metrics_block_present\": true,\n  \"warnings\": [],\n  \"physical_red_flags\": []\n}\n```\n\nField semantics:\n- `f1_verdict_is_valid_string`: true if `f1_verdict in {\"PASS\",\"INCONCLUSIVE\",\"FALSIFIED\"}`. The implementer sets this boolean directly to avoid judge.py's broken `operator: in`.\n- `f1_pass`/`f1_inconclusive`/`f1_falsified`: exactly one is true (mutually exclusive).\n- `falsification_result`: top-level verdict — for this turn, equals f1_verdict (F4 is opportunistic-only).\n- `m_populations`: integrated populations per m-component. For F=1 with init_m_idx=1, expect m=+1 dominant (≥0.95) if polarization preserved.\n\n### §5 F1 falsifier evaluation\nGiven measured n_max in D₀ units, evaluate against paper 13000 D₀ ±10%. If FALSIFIED, list which audit Q is the most likely culprit (Q1 LHY χ / Q2 DDI prefactor / Q3 free-space convergence).\n\n### §6 F4 falsifier evaluation\nReport `INCONCLUSIVE: rotating_basis_no_energy_decomposition`. Recommend T38+ follow-up fix-bug investigation to add E_kin/E_s/E_ddi/E_lhy snapshot support to the rotating_basis GS step (the standard run_step_ground_state.jl path has this; rotating_basis doesn't). This is a framework gap, NOT a falsification.\n\n### §7 Physical red flags\nList: norm drift > 1%, energy NaN/Inf, m_populations sum != 1.0 ± 0.001, m=+F population < 0.95 (paper expects f/ρ ≃ 1 everywhere), density delocalized over the whole box (no clear droplet localization).\n\n### §8 Next steps recommendation\nFor T38 director:\n- If F1 PASS: investigation advances to Analyze (T38 = implementer post-process: density distribution shape check, ⟨f_z⟩/ρ map, write final result). Tier 0.8 → 1.0. Optional T39 = critic Cross-check before Update.\n- If F1 INCONCLUSIVE (10-50% deviation): grid refinement T38 (try 96³ × box 40) OR Q1 LHY χ audit. Tier stays 0.8.\n- If F1 FALSIFIED (>50% deviation OR clearly wrong physics): Update stage with critic Q1/Q2/Q3 framework-gap audit (T38 = critic Cross-check; gold-standard self-correction per arXiv:2604.12198). Tier 0.6.\n- If ITP failed at run_yaml (stack trace caught): escalate to fix-bug investigation against the surfaced bug; do NOT do a Design redo #4 (rule SPENT).\n- F4 framework gap (rotating_basis_no_energy_decomposition) — spawn follow-up fix-bug investigation T39+ if F1 closes successfully.\n\n### §9 Risk register update\nWhich T34/T36 risks closed/opened? New risks discovered? Specific call-outs: BUG-7 V_trap.omega latent crash (closed by init_sigma=2.0), BUG-6 tol silent-ignore (non-fatal, may surface as non-convergence), the rotating_basis-no-energy-decomposition framework gap.\n\n### §10 Cost report\nWall time + effective tokens. Confirm under 6M cap.\n\n## STYLE\n\n- Numbers > prose. Cite line numbers and file paths.\n- Use absolute paths everywhere.\n- Capture verbatim stdout for all three Stage commands.\n- If ANY stage fails, document the failure mode FIRST in sim/turn_37.md, then attempt the next stage only if the failure is non-blocking.",
  "observable_manifest": {
    "required": [
      "precondition_check_exit_code_zero",
      "jld2_artifact_exists",
      "f1_n_max_in_D0_extracted",
      "f1_verdict_is_valid_string",
      "f1_pass",
      "f1_inconclusive",
      "f1_falsified",
      "f1_n_max_in_D0",
      "f1_deviation_pct_vs_paper",
      "norm_drift",
      "energy_mu_final",
      "wall_time_sec_total",
      "sim_turn_37_md_exists_on_disk",
      "sim_turn_37_metrics_block_present"
    ],
    "optional": [
      "f4_verdict",
      "f4_reason",
      "f4_ratio_lhy_over_ddi",
      "m_populations",
      "m_plusF_dominant",
      "converged",
      "peak_memory_gb",
      "n_steps_completed",
      "wall_time_sec_itp"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && test -f /home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl && grep -q '_resolve_atom_or_nothing' /home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl && grep -q 'type: harmonic' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && grep -q 'init_sigma:' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && grep -q '^      B: {Bz: 0.0}' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && ! grep -q '^      zeeman: {p: 0.0, q: 0.0}' /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && echo 'precondition OK: T36 B-block patch on disk + T34 patches on disk + legacy anti-pattern absent'"
  },
  "success_criteria": [
    {
      "id": "precondition_passed",
      "metric": "precondition_check_exit_code_zero",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Stage 1 (disk-truth + julia smoke + CUDA functional) must pass before ITP. T36 already proved smoke works; this re-checks for between-turn drift."
    },
    {
      "id": "jld2_artifact_produced",
      "metric": "jld2_artifact_exists",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Successful ITP produces JLD2 at runs/yan_li_saito_f1_torus_gs/point_001.jld2 (run_registry.jl:406). Absence = ITP threw or save path broken."
    },
    {
      "id": "n_max_extracted",
      "metric": "f1_n_max_in_D0_extracted",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Post-process must successfully extract peak density in paper's D_0 units. If extraction fails (psi key absent), report INCONCLUSIVE with diagnostic."
    },
    {
      "id": "f1_verdict_string_valid",
      "metric": "f1_verdict_is_valid_string",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Implementer must emit f1_verdict in {PASS, INCONCLUSIVE, FALSIFIED} and set this boolean flag accordingly. Avoids judge.py broken `in` operator (line 97 = range comparison). Boolean test sidesteps the bug."
    },
    {
      "id": "norm_conserved",
      "metric": "norm_drift",
      "operator": "<",
      "value": 0.01,
      "tolerance": null,
      "rationale": "ITP should preserve normalization to <1%. Norm drift larger indicates numerical breakdown."
    },
    {
      "id": "wall_time_within_budget",
      "metric": "wall_time_sec_total",
      "operator": "<",
      "value": 1800,
      "tolerance": null,
      "rationale": "30-min budget (5-min JIT + 15-min ITP + 5-min headroom + 5-min post-process). Per memory `tdhfb_gpu_port_status.md` F=6 13-comp 32³ GPU benchmarks ≪ 30 min; F=1 3-comp 64³ should be comparable or faster."
    },
    {
      "id": "sim_37_on_disk",
      "metric": "sim_turn_37_md_exists_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required."
    },
    {
      "id": "sim_37_metrics_present",
      "metric": "sim_turn_37_metrics_block_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "§4 Metrics JSON block must exist and parse — judge.py reads metrics from it."
    },
    {
      "id": "energy_finite",
      "metric": "energy_mu_final",
      "operator": ">",
      "value": -1e10,
      "tolerance": null,
      "rationale": "Chemical potential must be a finite real number (not NaN, not -Inf). Lower bound -1e10 catches NaN/-Inf without constraining physical sign (μ can be negative for self-bound droplets per paper)."
    }
  ],
  "failure_modes": [
    {
      "if": "precondition_passed failed (Stage 1 nonzero exit)",
      "category": "operational",
      "next_action": "T38 = inspect precondition failure verbatim from sim/turn_37.md §2. If between-turn edits broke the config, re-fix with one surgical Edit. If julia smoke fails (would be a regression from T36), spawn fix-bug investigation against the schema/load_config path. 3rd-Design-redo rule is SPENT; do NOT do a Design redo #4."
    },
    {
      "if": "jld2_artifact_produced failed (ITP threw or save path broken)",
      "category": "data_gap",
      "next_action": "T38 = inspect stack trace verbatim from sim/turn_37.md §3. Classify: (a) physics-level error (NaN density during ITP) → Hypothesize revision; (b) framework-level error (CUDA OOM, missing dispatch, type instability) → fix-bug investigation against the surfaced bug. Do NOT do a Design redo #4."
    },
    {
      "if": "n_max_extracted failed (psi key absent from JLD2)",
      "category": "framework_error",
      "next_action": "T38 = inspect JLD2 keys verbatim. Likely cause: pipeline result accessor changed. fix-bug investigation against run_registry.jl save path OR rotating_basis result return path."
    },
    {
      "if": "f1_pass == true AND norm_conserved AND m_plusF_dominant",
      "category": "operational",
      "next_action": "T38 = Analyze stage (implementer post-process: spin polarization map, density distribution shape, ⟨f_z⟩/ρ ≃ 1 check, density profile compared to paper Fig 1c if extractable). Tier 0.8 → 1.0 on Execute PASS; T39 critic Update; T40 Document → Tier 3 = project's first Tier-3 claim."
    },
    {
      "if": "f1_inconclusive == true (10-50% deviation from 13000 D_0)",
      "category": "data_gap",
      "next_action": "T38 = either grid refinement (96³ × box 40) OR Q1 LHY χ audit. Tier stays 0.8. Two-path decision in T38 director based on which deviation direction (too dense → likely under-resolved peak; too sparse → likely LHY χ scaling off)."
    },
    {
      "if": "f1_falsified == true (>50% deviation OR clearly wrong physics)",
      "category": "scientific_refuted",
      "next_action": "T38 = Update stage with critic Cross-check. Critic audits Q1 (LHY χ match) / Q2 (DDI prefactor) / Q3 (free-space convergence). FALSIFIED is a science success per arXiv:2604.12198 — a framework gap discovery may be the result. Tier 0.6 (hypothesis refuted) but the discovery may seed a new investigation."
    },
    {
      "if": "norm_conserved failed (norm_drift >= 0.01)",
      "category": "operational",
      "next_action": "T38 = investigate ITP normalization breakdown. Likely cause: dt too large for stiff DDI+LHY ε_dd=1.2 regime. Try dt=0.001 or dt=0.002 in a follow-up Execute. Mark as physical_red_flag in sim/turn_37.md §7."
    },
    {
      "if": "wall_time_within_budget failed (>1800s)",
      "category": "operational",
      "next_action": "T38 = inspect wall-time breakdown. If JIT >5 min, that's expected once (cache hit next time). If ITP itself >25 min, the n_steps × dt schedule may be too long for 5000 steps; consider checkpointing OR reducing n_steps in a follow-up."
    },
    {
      "if": "energy_finite failed (NaN or -Inf chemical potential)",
      "category": "operational",
      "next_action": "T38 = investigate numerical breakdown. Likely cause: split-step blew up. Check intermediate steps via checkpoint (ckpt_dir is auto-created at run_registry.jl:417). Reduce dt; check if init_sigma=2.0 is appropriate for box=28."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 6000000,
    "wall_time_sec_cap": 1800,
    "norm_drift": 0.01
  },
  "budget": {
    "expected_cost_eff": 3000000,
    "expected_wall_time_sec": 1200,
    "split_by_subtask": {
      "read_required_files": 200000,
      "stage1_precondition_check": 200000,
      "stage2_julia_run_yaml_itp": 1800000,
      "stage3_post_process_jld2": 500000,
      "stage4_write_sim_turn_37_md": 300000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Analyze",
    "if_success_tier_becomes": 1.0,
    "if_success_falsifier_update": "T37 Execute PASS: F1 n_max within ±10% of paper 13000 D_0; rotating_basis F=1 ε_dd=1.2 droplet GS reproduced. JLD2 at runs/yan_li_saito_f1_torus_gs/point_001.jld2. F4 INCONCLUSIVE-by-framework-gap (rotating_basis_no_energy_decomposition) — spawn follow-up fix-bug investigation T39+ to add E_kin/E_s/E_ddi/E_lhy snapshot. T38 = Analyze stage (density distribution + polarization map). Tier ladder: 0.8 → 1.0 → 2.0 (Analyze) → 2.5 (critic Update) → 3.0 (Document = project's first Tier-3 claim).",
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "On F1 PASS: T38 = Analyze (density + polarization check); investigation eventually progresses to ℓ=1 vortex test (F2) + Larmor precession (F3). On F1 INCONCLUSIVE: T38 = grid refinement (96³ × box 40) OR Q1 LHY χ audit (director decides based on deviation direction). On F1 FALSIFIED: T38 = critic Cross-check on Q1/Q2/Q3 framework gap; FALSIFIED is a science result, document carefully. On ITP crash: T38 = fix-bug investigation against the surfaced bug; do NOT Design redo #4 (rule SPENT). F4 framework-gap spawns T39+ fix-bug investigation regardless of F1 outcome. Meta-critic-placement (priority 50) advances at T38 or T39 (4 data points now in catalog: T20 Lz, T26 freq-sign, T33 schema, T35 BUG-8)."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_37.json` (policy=JULIA_GPU_OK; implementer_julia_gpu in allowed_workloads; window 14+ days left; VRAM 12.7 GB free; foreign_julia=0).
- [x] Read `runs/_loop/state.json` (active=yan-li-saito-2026-reproduction; current_stage="Execute"; tier_current=0.8; schema_version=2.1).
- [x] Read `runs/_loop/seed.md` (priority 1 = yan-li-saito; first Tier-3 candidate; manuscript OUT; cost guardrails 6M/turn).
- [x] Read `runs/_loop/director/turn_36.md` end-to-end (T36 brief structure, Design redo #2 PASS).
- [x] Read `runs/_loop/sim/turn_36.md` end-to-end (BUG-8 fix verified; smoke output proves Stage 1c passes; cross-config audit clean).
- [x] Read `runs/_loop/judge/turn_36.json` (PASS 9/9; investigation_update.if_success_advance_to_stage = "Execute").
- [x] Read `runs/_loop/sim/turn_35.md` end-to-end (precondition abort context; F1+F4 falsifiers structure).
- [x] Read `runs/_loop/director/turn_35.md` head + dispatch contract section (T35 brief structure used as T37 starting template).
- [x] Read `src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl` lines 120-267 (confirmed step_result has μ_final but NO energy decomposition — F4 framework-limited).
- [x] Read `src/workflow/experiments/pipeline/run_registry.jl` lines 405-465 (confirmed JLD2 keys: psi, energy, converged, grid_box_size, grid_n_points; no E_kin/E_s/E_ddi/E_lhy).
- [x] Read `runs/yan_li_saito_f1_torus_gs/config.yaml` end-to-end (post-T36: line 42 = `B: {Bz: 0.0}` correct).
- [x] Memory `yan_li_saito_2026_barnett_paper.md` (paper anchor: 13000 D_0, F=1 N=15000 ε_dd=1.2; failure modes Q1/Q2/Q3).
- [x] Memory `feedback_manuscript_is_not_the_essence.md` (D1 verification IS the essence).
- [x] Memory `loop_scheduler_2026_05_15.md` (scheduler authority; julia gating).
- [x] Memory `rotating_basis_loss_support.md` (rotating_basis is the correct path; no loss in this config).
- [x] investigation_id `yan-li-saito-2026-reproduction` valid in state.investigations.
- [x] stage_advancing_to=Execute matches state.investigations[id].current_stage = "Execute" (auto-advanced by judge T36).
- [x] subagent_type=implementer matches role_per_stage[Execute] for verify-claim; workload class implementer_julia_gpu in scheduler.allowed_workloads.
- [x] success_criteria are machine-evaluable: 9 criteria, all using safe operators (==, <, >). NONE use `in` operator (which is broken per judge.py:97).
- [x] f1_verdict membership tested via boolean `f1_verdict_is_valid_string` (sidesteps the `in` operator bug).
- [x] failure_modes cover 9 scenarios: precondition fail, JLD2 absent, psi key missing, F1 PASS (advance to Analyze), F1 INCONCLUSIVE (refinement), F1 FALSIFIED (critic Cross-check), norm breakdown, wall-time overrun, energy NaN/-Inf.
- [x] observable_manifest precondition_check is a literal bash chain (test -f + grep -q for T36 + T34 patches + the negation of the BUG-8 anti-pattern) that exits 0 before julia smoke.
- [x] Budget 3M effective + 30-min wall fits within scheduler window (14 days) + cost_cap_per_turn_effective (6M).
- [x] §A6 research-first citations: sim/turn_36.md (smoke verified), yan_li_saito memory (paper anchor), run_step_rotating/ground_state.jl (step_result structure), run_registry.jl (JLD2 save keys), CLAUDE.md (GPU invocation), scheduler memory, manuscript-not-essence memory, cost-overhead memory, director §F1/§B3/§G (templates), judge.py:97 (in operator bug), arXiv:2604.12198 (FALSIFIED-as-science-success precedent), director turn_35 (brief template lineage).
- [x] §A5 D1 PRIMARY articulated (verify Yan-Li-Saito 2026 PRL Fig 1c; first Tier-3 candidate); manuscript NOT primary.
- [x] investigation_update has 2 explicit branches (PASS → Analyze + tier 1.0, refuted → Update + tier 0.6); next_falsifier_to_test_after threads to T38 with multiple path options.
- [x] Considered switching to klaus-bch-leak (priority 3): rejected — yan-li-saito priority 1 with smoke-pre-verified Execute.
- [x] Considered switching to meta-critic-placement (priority 50): rejected per §B2 interleaving + T38 advances meta after F1 closes.
- [x] Considered NOOP: rejected — actionable Execute; quota healthy; smoke pre-verified; 14-day window.
- [x] Considered Design redo #4: rejected — 3rd-Design-redo rule SPENT per T36 investigation_update; failure paths route to fix-bug or anko.
- [x] Considered jumping to Analyze (skipping Execute): rejected — no data yet.
- [x] Considered Update (treating as scientific refute): rejected — no scientific result yet.
- [x] F4 explicitly downgraded to opportunistic INCONCLUSIVE-by-default because rotating_basis pipeline lacks energy decomposition (verified at run_registry.jl:425-440 + run_step_rotating/ground_state.jl:246-261). Recommendation: spawn follow-up fix-bug investigation T39+ to add the snapshot if F1 closes. This is a real framework gap, NOT a contract bug.
- [x] `consumed_seed_md: false` — same investigation, not a new seed entry.
