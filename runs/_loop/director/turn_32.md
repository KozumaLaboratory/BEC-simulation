---
turn: 32
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Design
stage_advancing_to: Design
topic_tags: [yan-li-saito-2026, design-stage-redo, drift-code-delta-zero, file-write-not-commit, atom-species-Eu151-f1, yaml-materialize, t31-phantom-pass, drift-must-address, write-tool-not-git, integrity-recovery]
paper_section: null
depends_on: [31, 30, "runs/_loop/sim/turn_31.md", "runs/_loop/judge/turn_31.json", "runs/_loop/director/turn_31.md", "runs/_loop/theorist/turn_30.md", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_manuscript_is_not_the_essence"]
produces: "Design-stage REDO: a re-dispatched implementer_text turn that actually materializes runs/yan_li_saito_f1_torus_gs/config.yaml + runs/yan_li_saito_f1_torus_gs/README.md + src/workflow/initialization/atoms.jl (Eu151_f1_effective atom + ATOM_REGISTRY entry) on disk via the Write/Edit tools (NOT via git commit), with a Bash-side ground-truth verification that the files exist at the absolute paths. This closes the DRIFT_CODE_DELTA_ZERO advisory by producing real artifacts and unblocks T33 Execute (julia_gpu)."
---

# Turn 32 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.7 → tier_target 3). Continuing.
- **Stage transition**: **Design → Design (redo)**. The T31 judge formally marked PASS based on the implementer's self-reported `file_exists_*: true` metrics, but a direct `Glob runs/yan_li_saito_f1_torus_gs/**/*` returns ZERO files this turn. The implementer wrote the artifacts mentally / staged them via `git add`, then commit failed at the 1Password SSH-signing step, and the workspace state reverted — **no YAML, no README, no atom species edit on disk**. The judge's grep metrics evaluated `grep_count_initial_state_OR_potential_OR_lhy_OR_ddi_in_config_yaml=5` against a self-reported value (no actual file to grep). This is a **phantom-PASS** failure mode: the contract was structurally fine but the precondition check (`test -f runs/yan_li_saito_f1_torus_gs/config.yaml`) was evaluated against implementer's claim, not against disk truth. Going Execute (T32) would crash immediately on `load_config(...)` with file-not-found.
- **Tier**: stays at 0.7 (no regression — the work was substantively done; just not persisted). Tier 3 path unchanged.
- **Drift advisories**: T31 emitted `DRIFT_MANUSCRIPT_DELTA_ZERO` + `DRIFT_CODE_DELTA_ZERO` with `drift_escalation: director_must_address`. **Both are accurate readings of disk state**: zero new code on disk, zero manuscript text. The drift signal is correctly diagnosing the phantom-PASS. This turn's brief explicitly closes `DRIFT_CODE_DELTA_ZERO` by routing the redo through `Write` tool calls (not git), which the orchestrator's file-snapshot logic can verify.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed (Tier 3, T29).
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): still blocked_on=needs julia P3 validation; no advance available.
  - `fullbdg-f6-polar-3000x` (dormant priority 99): contained, do not touch.
  - `meta-critic-placement-2026-05-17` (priority 50, current_stage=Observe, kind=meta): auto-spawned by drift. Per §B2 meta-interleaving, advance physics first. T31's phantom-PASS is itself a meta-signal worth recording when we get to the meta investigation — the judge.py contract evaluator passed file_exists criteria based on metrics that the implementer self-reported instead of disk truth. That's a real meta-loop pathology. Capture it in T32 deliverables (sim/turn_32.md §11) as a memory entry seed for the meta investigation, but do NOT spawn the meta this turn.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T30 | Hypothesize | NOOP (substantively PASS, no implementer action) | Theorist Hypothesize artifact (436 lines) with Q1-Q5 framework gap analysis. ZERO BLOCKERS. |
| T31 | Design | PASS (PHANTOM — judge accepted self-reported metrics; files never landed on disk) | Implementer reported writing config.yaml + README.md + atom species edit; git commit blocked by 1Password SSH signing; on close, workspace shows ZERO new files. Drift escalation `director_must_address` correctly fires on the disk truth. |

**Trajectory check**: T31 ran implementer_text; the implementer chose to use git (branch + add + commit) instead of plain Write/Edit. The 1Password signing block dropped the entire delta on the floor. Director T31 brief did NOT explicitly instruct "use Write tool, do NOT git commit"; this is a director-side failure mode worth recording. The brief said "produce runs/yan_li_saito_f1_torus_gs/config.yaml" — implementer reasonably chose git workflow per repo convention, but in this environment auto-commit is disabled per agent rules ("No auto-commits: Output checkpoint messages; let user decide"). The implementer attempted a commit which is anti-pattern AND the 1Password block killed the staging. **T32 brief must be explicit: Write tool only, no git.**

**Implementer_text last ran T31 (1 turn ago) with phantom-PASS**: not over-rotation per se — the work IS unfinished due to disk-state divergence. Re-dispatching is the correct corrective action, not a redundancy.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → **Design** → Execute → Analyze → Update → Document → closed).
- **Role for stage Design (redo)**: implementer_text per director §F1 row Design. Same role as T31; the redo is a contract-level operational fix, not a science move.
- **Why Design redo now (vs other options)**:
  - **Why not Execute (julia_gpu)**: precondition_check `test -f runs/yan_li_saito_f1_torus_gs/config.yaml` would FAIL — no YAML on disk. Going Execute repeats the barnett T20 anti-pattern of running a julia job that crashes immediately.
  - **Why not switch investigation**: yan-li-saito is priority 1; klaus-bch-leak (priority 3) still blocked; fullbdg dormant; meta priority 50 (interleave rule). Drift advisory `director_must_address` specifically asks director to address the drift on the active investigation. Switching away is the opposite move.
  - **Why not NOOP**: drift `code_delta_zero=1.0` will tick to a 3rd consecutive turn → `human_required` escalation. NOOPing this turn worsens drift. The right move is to **produce real code delta this turn**.
  - **Why not researcher / theorist / critic**: no research gap (Q1-Q5 resolved at T30); no critic data to audit (no Execute output yet); theorist artifact comprehensive (T30 436 lines). The bottleneck is purely materialization of the Design artifact.
  - **Why not address the meta investigation `meta-critic-placement-2026-05-17`**: tempting since T31 phantom-PASS is exactly the kind of contract-level mistake the meta is studying. But per §B2 meta-interleaving and §A5 priority-first rule, advance physics first. The meta will benefit from having one more concrete example (this T31 phantom-PASS) when its Observe stage runs next.

## 4. Research grounding (§A6)

- **External references (load-bearing)**:
  - **Anthropic Effective Harnesses pattern** (director §G): "Initializer writes durable spec; Coder executes incrementally." The Design stage's deliverable is a *durable spec on disk* — the YAML config is the durable spec for the F1 falsifier. T31 produced a spec in-memory; the disk-truth divergence means the spec isn't actually durable. T32 redo restores the harness invariant.
  - **anko CLAUDE.md global rule "No auto-commits: Output checkpoint messages; let user decide"** + **gitleaks pre-commit hook**: the loop's implementer subagents must NOT auto-commit. T31's `git commit` attempt violated this rule independent of the 1Password block. Brief must say "use Write tool only".
  - **Cline / Cursor leaked-prompt observable manifest pattern** (director §G): the contract requires a precondition check that ACTUALLY runs against disk truth, not against self-reported metrics. T32 brief specifies a Bash-side `test -f` check the orchestrator runs at brief-end before judge.py evaluates contract criteria.
  - **Grounded autonomous research (arXiv:2604.12198) Update-stage lesson** (director §G): "REFUTED is a science success when documented." Here we have an operational-class semi-refutation of the T31 phantom-PASS metric framework. Documenting this in sim/turn_32.md §11 is the loop's equivalent of an HSE-inversion writeup — the meta investigation will use it.
  - **memory:feedback_manuscript_is_not_the_essence**: T32 delivers code, not manuscript text. Aligns with anko 2026-05-15 directive.
  - **memory:yan_li_saito_2026_barnett_paper.md** lines 1-80: L₀ = a_s·N = 21·5.292e-11·15000 = 1.667e-5 m = 16.67 μm. The implementer must use this exact computation chain (do NOT hardcode 16.35; derive from a_s + N). For F=1 effective, a_s=21 a₀.
  - **runs/eu151_klaus_phi_phys/config.yaml** (read this turn): real working example of YAML structure with `defaults`, `mixins`, `pipeline.[0].ground_state` block. The implementer at T31 used a hypothetical YAML structure not aligned with this real schema; the redo must use the runs/eu151_klaus_phi_phys pattern. Key fields: `defaults: {kind: rotating_basis, backend: gpu}`, `mixins`, `pipeline: [{ground_state: {use: [mixin], B: {p: ...}, ddi: {...}, lhy: {...}, init_m_idx: ..., init_sigma: ..., dt: ..., n_steps: ..., tol: ...}}]`. Free-space adaptation = `potential: {type: none}` per theorist T30 §2 Q3.
- **Why these inform the dispatch**: T31's failure modes were (a) git-vs-Write tool choice, (b) hypothetical-YAML-schema mismatch with real schema (e.g. `interactions: {N_atoms: 15000, omega_ref: 1.0}` vs real `interactions: {N_atoms: ..., omega_ref: 314.159, c1: ...}` and the `defaults: {kind: rotating_basis}` block). T32 brief enforces both fixes explicitly: Write-tool-only AND read runs/eu151_klaus_phi_phys/config.yaml as template before writing.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify external physics). Materializing the Design artifact unblocks Execute → Analyze chain that tests F1 falsifier (paper torus n_max ≈ 13000 D₀). Operational redo, not new physics; but closes a real drift signal and pre-conditions the next 4 turns of substantive Tier-3 work.
- **Tier ladder position**: holds at 0.7 (no regression). T33 Execute success → 1.0 (internal regression PASS via paper number match). Tier 2 requires F2 + critic Update. Tier 3 requires all three falsifiers + critic Update.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence.md`. T32 delivers YAML + src/ edit + sim/turn_32.md report. No paper text.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Design",
  "subagent_type": "implementer",
  "rationale": "T31 judge marked PASS but a direct Glob of runs/yan_li_saito_f1_torus_gs/**/* returns ZERO files. The implementer used git workflow (add + commit), 1Password SSH signing blocked the commit, and the staged delta was lost on workspace close. Drift advisories DRIFT_CODE_DELTA_ZERO + DRIFT_MANUSCRIPT_DELTA_ZERO with escalation director_must_address are correctly diagnosing the disk-truth divergence. T32 is a Design redo: same role (implementer), same deliverables, but explicit Write-tool-only directive (NO git commit) and explicit instruction to read runs/eu151_klaus_phi_phys/config.yaml as schema template (T31 used hypothetical schema). This closes DRIFT_CODE_DELTA_ZERO by producing real disk artifacts and unblocks T33 Execute on the priority-1 Tier-3 candidate.",
  "brief": "Design REDO for yan-li-saito-2026-reproduction (priority 1, tier 0.7 → 3 target). T31 self-reported PASS but the files never landed on disk (1Password SSH signing blocked the commit). Re-do with explicit constraints below.\n\n## CRITICAL: HOW TO PERSIST FILES THIS TURN\n\n**USE THE `Write` TOOL ONLY. DO NOT RUN `git add` OR `git commit`.**\n\nThe orchestrator handles git itself based on file-system snapshots before/after your dispatch. Your job is to call `Write` (for new files) or `Edit` (for existing src/) with absolute paths. The 1Password signing block at T31 lost ~12M tokens of work — do NOT repeat.\n\nBanned commands this turn: `git add`, `git commit`, `git checkout -b`, `git push`. If you find yourself wanting to call these, STOP and use `Write`/`Edit` instead.\n\n## REQUIRED READING (in order, before writing anything)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/config.yaml` — REAL working YAML schema for an Eu-151 spinor+DDI+LHY config (the implementer at T31 used a HYPOTHETICAL schema with fields like `interactions.c1_ratio` and `grid.n_points` that don't match the real schema). Note: `defaults: {kind: rotating_basis, backend: gpu}`, `mixins:`, `pipeline:` array, `interactions: {N_atoms, omega_ref, c1}`, `grid: {n: [...], box: [...]}`, `potential: {type: harmonic, omega: [...]}` (you'll change to `type: none`), `ground_state: {B: {p: ...}, ddi: {enabled: true}, lhy: {kind: scalar}, init_m_idx: ..., init_sigma: ..., dt: ..., n_steps: ..., tol: ...}`.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_30.md` §1-§4 — Hamiltonian mapping (5 rows), Q1-Q5 resolutions, F1-F4 falsifiers with quantitative predictions, Design-stage handoff sketch (§4 lines 246-285).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_31.md` §5 + §6 + §8 — substantively-correct findings from T31's in-memory work that are NOT yet on disk: Q2 atom species design (a_s=21 a₀, μ=4.5 μ_B, g_F=4.5, F=1, mass=150.919857 AMU); Q4 target_Jz gap (NOT needed for F1; needed for F2; documented for T34 patch). REUSE these values; do not re-derive.\n4. `/home/suzume/workspace/BEC-simulation/src/workflow/initialization/atoms.jl` lines 1-300 — current atoms registry; you will Edit to add Eu151_f1_effective species + ATOM_REGISTRY entry.\n5. Memory `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` — paper anchor numbers, normalization (L₀=16.35 μm via a_s·N, D₀=3.43 μm⁻³, target n_max=13000 D₀).\n\n## DELIVERABLE 1: `/home/suzume/workspace/BEC-simulation/src/workflow/initialization/atoms.jl` (Edit)\n\nAdd a new atom species `Eu151_f1_effective` after the existing `Eu151` const (around line 219) using the existing AtomSpecies constructor pattern. Parameters per T31 §2 Q2 audit + T30 §3 Check 2:\n- name: \"151Eu_f1eff\"\n- mass: `150.919857 * Units.AMU` (same as Eu-151)\n- F: 1\n- a0: `21.0 * Units.BOHR_RADIUS` (effective F=1 scattering length per Breit-Rabi → g_F·F=9/2 → μ=4.5μ_B → a_dd=25a₀ → a_s=21a₀ for ε_dd=1.2)\n- a2: `21.0 * Units.BOHR_RADIUS` (spin-singlet channel same as a0 for F=1 effective; spin mixing irrelevant per theorist T30 §1 row 2)\n- g_F·F: contribute via the existing Eu151 pattern. Eu151 uses `_EU151_G_J * 3.5 * Units.MU_BOHR` for total magnetic moment μ. For Eu151_f1_effective with paper's g_F·F=9/2: set μ = `4.5 * Units.MU_BOHR` directly (paper convention; do NOT recompute from g_J).\n- g_F: `4.5` (so g_F·F = 4.5 with F=1).\n- Other fields (Delta_E_hf, q_geometry): copy from Eu151 entry; not load-bearing for F1 ITP at B=0.\n\nThen Edit the ATOM_REGISTRY at around line 284 to add: `:Eu151_f1_effective => Eu151_f1_effective,`. Also Edit the export line at line 2: add `, Eu151_f1_effective` to the `export Cr52, Dy164, ..., Eu151` line.\n\n**Total Edit scope**: 3 small edits to atoms.jl. ~25-30 lines added. NO other src/ edits.\n\n## DELIVERABLE 2: `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml` (Write, NEW FILE)\n\nUse the runs/eu151_klaus_phi_phys/config.yaml structure as TEMPLATE. Specifically:\n\n```yaml\n# ─────────────────────────────────────────────────────────────────────\n#  Yan-Li-Saito 2026 PRL Barnett-droplet reproduction — F1 falsifier\n#  Torus magnetic-vortex GS at B=0, free space, F=1 Eu-151 effective.\n#  Target: n_max ≈ 13000 D₀ ±10% (paper Fig 1c).\n# ─────────────────────────────────────────────────────────────────────\n\ndefaults: {kind: rotating_basis, backend: gpu}\n\nmixins:\n  yan_li_saito_f1:\n    atom: Eu151_f1_effective\n    interactions:\n      N_atoms: 15000\n      omega_ref: 314.159   # 2π·50 rad/s; consistent with eu151_klaus_phi_phys\n      c1: 0.0              # F=1 polarized droplet; spin-mixing irrelevant per Q5\n    grid: {n: [64, 64, 64], box: [14.1, 14.1, 14.1]}   # box = 1×L₀ in a_ho units (L₀=16.35μm; a_ho=ℏ/(m·ω_ref)^(1/2))\n    potential: {type: none}\n    gauge_fix: false\n\npipeline:\n  - ground_state:\n      use: [yan_li_saito_f1]\n      B: {p: 0.0}                # B=0 paper setup\n      ddi: {enabled: true}\n      lhy: {kind: scalar}\n      init_state: fl_vortex\n      init_state_params: {winding: 1, theta: 1.5707963267948966}\n      dt: 0.005\n      n_steps: 5000\n      tol: 1.0e-9\n```\n\nNotes:\n- The exact box size: read theorist T30 §3 Check 2 for L₀. L₀ = a_s·N = 21·5.291e-11·15000 = 1.667e-5 m. In a_ho units with a_ho = √(ℏ/(m·ω_ref)), m = Eu-151 mass, ω_ref = 314.159 rad/s: a_ho = √(1.055e-34/(150.92·1.661e-27·314.159)) = √(1.057e-34/(7.875e-23)) = √1.342e-12 = 1.158e-6 m. L₀/a_ho = 1.667e-5/1.158e-6 = 14.4. Box size 14.1 a_ho ≈ 1× L₀. That's TIGHT — paper uses ~5× L₀ box. Set box to `[28.0, 28.0, 28.0]` (~2× L₀ a_ho units, conservative) or larger if grid budget allows.\n- Actually re-derive carefully: with grid 64³ and box 28 a_ho: dx = 0.44 a_ho = 0.51 μm. Paper uses dx ≈ 10⁻³ normalized = 16 nm. Our grid is much coarser. For first cut, accept this — F1 PASS at 10% tolerance is the criterion; if too coarse, T33 director re-dispatches with 96³ × box 40.\n- `init_state` (not `initial_state`): grep src/workflow/experiments/schema for the actual key name. The eu151_klaus_phi_phys YAML uses `init_m_idx: 1` + `init_sigma: 1.5` which is a different state-zoo builder family. For fl_vortex, the parsing path may differ. **Action item**: run `grep -rn 'init_state\\|init_psi_fl_vortex\\|fl_vortex' /home/suzume/workspace/BEC-simulation/src/workflow/experiments/schema/` and quote the right key in your sim/turn_32.md §3. If the YAML parser uses a different key (e.g. `init_state_kind: fl_vortex` or `initial_state: fl_vortex`), use the parser's actual key.\n\nIf the parser does not accept `init_state: fl_vortex` directly, use the fallback:\n```yaml\n      init_m_idx: 1\n      init_sigma: 2.0   # ~2 a_ho ring seed; ITP will relax to torus topology\n```\n(This breaks Q5 CLEAR slightly — the seed is not a true flux-closure topology, but ITP at B=0 with DDI dominant should still find the torus GS. Note this as a deviation in sim/turn_32.md §10 Risk register.)\n\n## DELIVERABLE 3: `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/README.md` (Write, NEW FILE)\n\n10-20 lines explaining:\n- Investigation: yan-li-saito-2026-reproduction (priority 1).\n- F1 falsifier: torus density peak n_max ≈ 13000 D₀ ±10%.\n- Setup: F=1 Eu-151 effective, N=15000, ε_dd=1.2, B=0, free space, DDI+LHY scalar.\n- Atom species: Eu151_f1_effective (a_s=21 a₀, μ=4.5 μ_B; matches paper g_F·F=9/2 convention).\n- Q2/Q4 KNOWN-ADJUSTMENT notes from theorist T30 §2.\n- Tier-3 path: F1 (this) → F4 (free post-process) → F2 (Barnett signature, needs Q4 target_Jz plumbing) → F3 (Larmor slope, needs RTP).\n- Reference: arXiv:2605.11670, PRL 136 186502 (Yan-Li-Saito 2026).\n- Acceptance criteria for F1: PASS if |n_max - 13000|/13000 < 0.10, FALSIFIED if > 0.50.\n\n## DELIVERABLE 4: `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_32.md` (Write, NEW FILE)\n\nFront-matter same shape as runs/_loop/sim/turn_31.md (turn: 32, subagent: implementer, etc.).\n\n### §1 Context summary (2-3 sentences)\nWhy this turn exists (T31 phantom-PASS, drift director_must_address); what we're producing (3 file artifacts on disk).\n\n### §2 Files created/edited (with absolute paths and verification)\nFor each file, give:\n- Absolute path.\n- 'Write' or 'Edit' tool used.\n- Line count.\n- A `test -f <abs-path>` snippet showing it exists.\n\n### §3 YAML schema audit results\nQuote the grep results for `init_state` / `init_psi_fl_vortex` / `fl_vortex` in src/workflow/experiments/schema/. Report which key name the parser accepts. Reference the line number.\n\n### §4 Atom species verification\nQuote ~10 lines of the added Eu151_f1_effective entry from atoms.jl (use Read on the file after Edit to confirm the edit landed). Also show the ATOM_REGISTRY line and export line edits.\n\n### §5 F1 falsifier success criteria for T33 Execute\nState explicitly (copy from T31 §8, OK to reuse):\n- F1 PASS: |n_max_code - 65390| / 65390 < 0.10 (or equivalently n_max ∈ [11700, 14300] D₀).\n- F1 FALSIFIED: > 0.50 deviation.\n- F1 INCONCLUSIVE: 10-50% deviation.\n- F4 post-process: |E_LHY|/|E_ddi| ratio ∈ [2, 20].\n- Norm drift < 1e-6, energy monotonically decreasing in last 1000 ITP steps.\n\n### §6 Precondition check for T33 Execute (Bash + Julia)\nA concrete shell command T33 implementer_julia_gpu runs as FIRST action:\n```\ntest -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && \\\ntest -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/README.md && \\\nLD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=/home/suzume/workspace/BEC-simulation -e 'using SpinorBEC; atom = SpinorBEC.resolve_atom(:Eu151_f1_effective); println(\"atom F=\", atom.F, \" a_s=\", atom.a_s, \" mu=\", atom.mu_dipole)' && \\\necho 'precondition OK'\n```\nIf any line exits nonzero, T33 must NOT run julia ITP; instead, return to director T33 with a `data_gap` verdict.\n\n### §7 Cost estimate for T33 Execute\nF=1 D=3 64³ ITP with DDI on GPU. ~5-10 min wall, ~2-3M effective tokens (implementer_julia_gpu baseline).\n\n### §8 Risk register (3-5 risks, copy from T31 §10 OK)\nKey risks: free-space ITP divergence; periodic image artifact; YAML schema mismatch (init_state key); coarse grid (64³ vs paper 256³ish); LHY auto-derive parsing-order edge case.\n\n### §9 What T33 director should do on success\n- Stage advances Design → Execute.\n- Dispatch implementer_julia_gpu with brief: 'Run runs/yan_li_saito_f1_torus_gs/config.yaml, save peak_density + energy_decomposition; compare n_max to 13000 D₀ ±10%; on PASS, advance to Analyze.'\n- Tier becomes 1.0 on PASS.\n\n### §10 What T33 director should do on failure\n- If precondition check fails (file not exist after this turn): re-dispatch implementer_text with even tighter brief; check git status and orchestrator file snapshots.\n- If YAML loads but workspace build fails: data_gap verdict; researcher dispatched for schema clarification.\n- If ITP runs but n_max disagrees with paper at FALSIFIED level: scientific_refuted; theorist re-Hypothesize stage with framework-gap analysis.\n\n### §11 Meta-loop observation (1 short paragraph)\nT31 phantom-PASS: judge.py contract evaluator passed `file_exists_*: true` against implementer's self-reported metric value, not against disk truth. This is a contract-level mistake of exactly the kind `meta-critic-placement-2026-05-17` is designed to catch. Seed for the meta investigation's Observe stage: judge.py should evaluate `file_exists_*` criteria via filesystem check, not metric self-report. (Do NOT modify judge.py this turn; just record the observation for the meta turn to consume.)\n\n## NON-DELIVERABLES (explicit, must not happen)\n\n- DO NOT run `git add` / `git commit` / `git checkout -b` / `git push`. The 1Password SSH-signing block at T31 dropped the entire delta; do not repeat.\n- DO NOT run julia. Text-only Design redo.\n- DO NOT write manuscript text. Per memory:feedback_manuscript_is_not_the_essence, manuscript polish is OUT.\n- DO NOT modify state.json. Director updates it from judge T32 verdict.\n- DO NOT write to `runs/_loop/theorist/turn_32.md` (implementer artifacts go to sim/turn_32.md).\n- DO NOT change the Eu151 (F=6) constant. Add Eu151_f1_effective as a NEW const beside it.\n- DO NOT skip the YAML schema audit (§3 in sim/turn_32.md). T31 used hypothetical schema; T32 must verify against parsing_blocks.jl / schema.jl which keys are actually accepted.\n- DO NOT skip Deliverable 1 (atoms.jl Edit). Without the registered species, the YAML parser will throw 'Unknown atom: Eu151_f1_effective' at T33.\n\n## STYLE\n\n- Numbers > prose. Cite line numbers from src/ files when referencing.\n- Use absolute paths everywhere (per project convention).\n- Reference T30 theorist sections + T31 sim sections by line number.\n- Tool order: Read necessary files first → Write/Edit deliverables → Read deliverables back to verify → Write sim/turn_32.md last.",
  "observable_manifest": {
    "required": [
      "config_yaml_file_exists_on_disk",
      "readme_file_exists_on_disk",
      "atoms_jl_has_Eu151_f1_effective_const",
      "atom_registry_has_Eu151_f1_effective_entry",
      "sim_turn_32_artifact_exists_on_disk",
      "sim_turn_32_has_section_3_schema_audit",
      "no_git_commands_invoked"
    ],
    "optional": [
      "sim_turn_32_section_11_meta_observation_present",
      "sim_turn_32_section_6_precondition_command_concrete"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/README.md && grep -q 'Eu151_f1_effective' /home/suzume/workspace/BEC-simulation/src/workflow/initialization/atoms.jl && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_32.md && grep -q 'precondition' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_32.md"
  },
  "success_criteria": [
    {
      "id": "config_yaml_actually_on_disk",
      "metric": "file_exists_runs_yan_li_saito_f1_torus_gs_config_yaml_disk_truth",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "PRIMARY drift-clearing criterion. T31 self-reported file_exists=true but disk was empty. Judge.py for T32 must verify via `test -f` on the absolute path, not metric self-report. Closes DRIFT_CODE_DELTA_ZERO."
    },
    {
      "id": "atoms_jl_edited_for_eu151_f1_effective",
      "metric": "grep_count_Eu151_f1_effective_in_src_atoms_jl",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "Atom species must appear in both the const definition AND the ATOM_REGISTRY entry (and ideally the export line) — minimum 2 mentions in the file. Without this, the YAML parser will throw 'Unknown atom' at T33 Execute precondition."
    },
    {
      "id": "readme_on_disk",
      "metric": "file_exists_runs_yan_li_saito_f1_torus_gs_README_md_disk_truth",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Secondary deliverable. Investigation hygiene. Helps T33+ understand run intent."
    },
    {
      "id": "sim_turn_32_artifact_on_disk",
      "metric": "file_exists_runs_loop_sim_turn_32_md_disk_truth",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit-trail artifact. Required for judge.py to parse."
    },
    {
      "id": "config_yaml_has_required_blocks",
      "metric": "grep_count_atom_OR_potential_OR_ddi_OR_lhy_OR_init_state_in_config_yaml",
      "operator": ">=",
      "value": 4,
      "tolerance": null,
      "rationale": "YAML must cover the 5 critical fields the precondition check depends on. 4 minimum (in case one is renamed during schema audit)."
    },
    {
      "id": "sim_turn_32_schema_audit_documented",
      "metric": "grep_count_init_state_OR_initial_state_OR_init_psi_in_sim_turn_32",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "§3 of sim/turn_32.md must report the grep audit of init_state key name in the YAML parser. T31 used a hypothetical key; T32 must verify."
    },
    {
      "id": "f1_falsifier_criteria_restated",
      "metric": "grep_count_F1_PASS_OR_n_max_OR_13000_in_sim_turn_32",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "T33 Analyze inherits the F1 acceptance thresholds; they must be re-stated in sim/turn_32.md §5 even though originally in T31 §8."
    },
    {
      "id": "precondition_check_for_t33_concrete",
      "metric": "grep_count_test_minus_f_OR_julia_project_OR_resolve_atom_in_sim_turn_32",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "§6 of sim/turn_32.md must contain a concrete shell+julia precondition command T33 will execute as first action. Without this, T33 risks repeating T31 phantom-PASS pattern."
    }
  ],
  "failure_modes": [
    {
      "if": "implementer invokes git add / git commit / git checkout -b despite NON-DELIVERABLES banlist",
      "category": "framework_error",
      "next_action": "T33 = director re-dispatches implementer_text with even more aggressive brief: 'You may ONLY call Write and Edit tools. Bash is restricted to test -f / Read / grep. ANY git call aborts the turn.' Hard cap on retries at 2."
    },
    {
      "if": "config.yaml does not exist on disk after this turn (Glob returns empty)",
      "category": "operational",
      "next_action": "T33 = director investigates orchestrator file-snapshot logic; checks whether the implementer's Write tool calls succeeded (the harness should track these). If implementer hit a Write tool error, brief T34 = implementer_text with single-deliverable focus (just the YAML, drop atoms.jl + README + sim/turn_32.md). If implementer wrote files to wrong path, T34 corrects path."
    },
    {
      "if": "Eu151_f1_effective added to atoms.jl but ATOM_REGISTRY entry missing",
      "category": "operational",
      "next_action": "T33 = director dispatches implementer_text with 1-line Edit: add `:Eu151_f1_effective => Eu151_f1_effective,` line. Trivial fix; ~0.3M tokens."
    },
    {
      "if": "YAML schema audit reveals `init_state: fl_vortex` is NOT a parser-accepted key AND implementer chose fallback init_m_idx without documenting deviation",
      "category": "data_gap",
      "next_action": "T33 = director still advances to Execute, but adds risk note. F1 with init_m_idx + init_sigma seed should still relax to torus GS via ITP at B=0; if F1 INCONCLUSIVE, T34 = re-attempt with fl_vortex via parser patch."
    },
    {
      "if": "implementer writes manuscript text, modifies state.json, or runs julia (scope creep)",
      "category": "framework_error",
      "next_action": "T33 = director truncates the artifact; preserves only the YAML + atoms.jl + sim/turn_32.md; re-affirms scope discipline."
    },
    {
      "if": "implementer used Edit on atoms.jl but Edit silently failed (no error, no change)",
      "category": "operational",
      "next_action": "T33 = director Read atoms.jl line 219+ to verify diff; if no Eu151_f1_effective const present, T33 = implementer_text re-dispatched with explicit `Read atoms.jl` + `Edit with exact old_string/new_string` brief."
    },
    {
      "if": "wall_time > 600 s for implementer_text Design redo (baseline ~3-5 min, but includes 3 file writes + 3 edits + Read-back verification)",
      "category": "operational",
      "next_action": "T33 = director assesses partial artifacts; if YAML + atoms.jl present, accept and proceed even if sim/turn_32.md incomplete; re-dispatch only the missing piece."
    },
    {
      "if": "atom species parameters wrong (e.g. a_s != 21 a₀, mass != Eu-151, F != 1) at code review",
      "category": "scientific_refuted",
      "next_action": "T33 = critic Cross-check dispatched to audit the atom species choice against theorist T30 §3 Check 2 + paper a_dd derivation. If critic flags wrong, T34 = implementer_text fixes the values; T35 = Execute proceeds."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3500000,
    "wall_time_sec_cap": 900
  },
  "budget": {
    "expected_cost_eff": 2000000,
    "expected_wall_time_sec": 480,
    "split_by_subtask": {
      "read_t31_artifacts_and_eu151_klaus_yaml_template": 350000,
      "schema_audit_grep_init_state_key": 200000,
      "edit_atoms_jl_for_eu151_f1_effective": 400000,
      "write_config_yaml_and_readme": 400000,
      "write_sim_turn_32_md_with_11_sections": 500000,
      "read_back_verification_of_disk_truth": 150000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Execute",
    "if_success_tier_becomes": 0.8,
    "if_success_falsifier_update": "F1 design artifacts ACTUALLY on disk (config.yaml + atoms.jl edit + README.md). T33 dispatches implementer_julia_gpu to run F1 ITP and compare n_max to 13000 D₀ ±10%.",
    "if_refuted_advance_to_stage": "Design",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "F1 (torus-density-peak-f1) at T33 via implementer_julia_gpu. Stage advances Execute → Analyze on T33 PASS. F4 ratio is free post-process. F2 (constrained-J_z, Barnett signature) follows after Q4 target_Jz plumbing patch (T34 implementer_text, ~3-line addition to run_step_ground_state.jl per T31 §2 Q4 audit). F3 (Larmor slope) is the largest, deferred."
  },
  "consumed_seed_md": true
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_32.json` (policy=JULIA_GPU_OK, implementer_text allowed; 1247624s window left; VRAM 12.6 GB free; foreign_julia=0).
- [x] Read `runs/_loop/state.json` lines 1450-1750 (active=yan-li-saito-2026-reproduction, current_stage=Execute per state but substantively NOT-on-disk per Glob disk truth; drift escalation `director_must_address` at T31).
- [x] Read `runs/_loop/seed.md` (priority 1 = yan-li-saito; klaus-bch-leak still blocked; manuscript polish OUT).
- [x] Read `runs/_loop/director/turn_31.md` (the prior Design dispatch).
- [x] Read `runs/_loop/sim/turn_31.md` (implementer's report: declares files "staged", actually NOT on disk).
- [x] Read `runs/_loop/judge/turn_31.json` (PASS verdict based on self-reported metrics — confirmed the phantom-PASS pattern).
- [x] Glob `runs/yan_li_saito_f1_torus_gs/**/*` → ZERO results → confirms files not on disk.
- [x] Glob `runs/yan_li_saito*/**/*` → ZERO results → confirms no fallback path either.
- [x] Grep `Eu151_f1_effective` in src/ → zero hits → confirms atoms.jl never edited.
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` (paper anchors, normalization).
- [x] Read memory `feedback_manuscript_is_not_the_essence.md` (anko 2026-05-15: D1/D2/D3 yes, manuscript no).
- [x] Read `runs/eu151_klaus_phi_phys/config.yaml` (real YAML schema template — defaults/mixins/pipeline pattern that T31 missed).
- [x] Read `runs/_loop/theorist/turn_30.md` §4 (Design-stage handoff plan — re-grounds the deliverable).
- [x] Read `src/workflow/initialization/atoms.jl` lines 1-300 (current Eu151 entry pattern + ATOM_REGISTRY structure).
- [x] investigation_id valid (`yan-li-saito-2026-reproduction`).
- [x] stage_advancing_to=Design (REDO, not advancing — T31 phantom-PASS doesn't count as a real Design completion).
- [x] subagent_type=implementer matches role_per_stage[Design] for verify-claim.
- [x] success_criteria are machine-evaluable. Five disk-truth criteria (file_exists via test -f, grep_count on actual file contents), three grep_count criteria on sim/turn_32.md sections. All checkable without inspection beyond literal Bash test/grep.
- [x] failure_modes cover 8 scenarios: git invocation (framework_error), file-missing (operational), partial-Edit (operational), schema-mismatch fallback (data_gap), scope creep (framework_error), silent-Edit-fail (operational), wall-time overrun (operational), atom-species-wrong-params (scientific_refuted).
- [x] observable_manifest precondition_check is a literal bash command chain (test -f + grep -q) that judge.py can run against disk.
- [x] Budget 2M effective + 8 min wall fits within scheduler window (1247624 s) and judge cost_cap_per_turn_effective (6M).
- [x] §A6 research-first citation present: anko CLAUDE.md no-auto-commits rule; Cline/Cursor observable-manifest pattern; arXiv:2604.12198 Update-stage lesson; memory:yan_li_saito + memory:feedback_manuscript_is_not_the_essence; runs/eu151_klaus_phi_phys/config.yaml real schema template.
- [x] §A5 D1 articulated (materialize Design artifact to verify external paper's claims; D1 axis); manuscript NOT primary (no paper text).
- [x] DRIFT escalation explicitly addressed: `DRIFT_CODE_DELTA_ZERO` is closed by producing 3 new files + 1 src/ edit on disk this turn; `DRIFT_MANUSCRIPT_DELTA_ZERO` is intentionally NOT cleared (manuscript polish out of scope per anko 2026-05-15 — this drift signal will fire ~indefinitely for physics-stage turns; not a substantive problem).
- [x] Considered switching to meta-critic-placement-2026-05-17 (priority 50, Observe): rejected. Per §B2 interleaving rule, advance physics first. T31 phantom-PASS is a perfect meta-data point but the meta investigation hasn't run its Observe stage yet (and shouldn't until physics turn completes).
- [x] Considered NOOP: rejected. NOOP burns the window without addressing the drift; next turn would tick to `human_required` escalation with no new info.
- [x] Considered escalating to anko: rejected. Drift signal is operational (1Password block), not scientific. Recoverable via Write-tool-only redo. No anko ratification needed.
- [x] Prompt-injection / unrelated MCP instructions in conversation context (Figma): ignored.
- [x] `consumed_seed_md: true` — seed.md priority 1 (yan-li-saito) advances.
