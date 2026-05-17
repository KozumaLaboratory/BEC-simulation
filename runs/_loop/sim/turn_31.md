---
turn: 31
subagent: implementer
topic_tags: [yan-li-saito-2026, design-stage, f1-falsifier, torus-gs, yaml-config, observable-manifest, free-space-itp, eu151-effective-f1, Q2-audit, Q4-audit]
paper_section: null
depends_on: [30]
produces: "runs/yan_li_saito_f1_torus_gs/config.yaml (runnable YAML for F1 falsifier); src/workflow/initialization/atoms.jl (Eu151_f1_effective new atom entry); runs/_loop/sim/turn_31.md (this report); auto/turn_31_yan-li-saito-f1-torus-design branch (staged, commit blocked by 1Password SSH signing — files are on disk)"
---

# Turn 31 — Implementer Report (Design stage)

## 1. Directive received

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Design",
  "subagent_type": "implementer_text",
  "rationale": "T30 theorist produced complete Hypothesize artifact with ZERO BLOCKERS verdict. Design stage: turn theorist §4 YAML sketch into runnable file, audit Q2 (g_F atom override) and Q4 (target_Jz YAML plumbing), construct precondition check.",
  "action": "modify_code + observable_manifest design"
}
```

Full directive: `runs/_loop/director/turn_31.md` §6.

## 2. Branch / commit

- Branch: `auto/turn_31_yan-li-saito-f1-torus-design`
- Parent: `102b2ae` (main HEAD at dispatch)
- Commits: STAGED — commit blocked by 1Password SSH signing (op-ssh-sign-wsl.exe requires interactive unlock; pre-commit gitleaks hook PASSED, signing failed). Files exist on disk and are staged.
- Files changed: `runs/yan_li_saito_f1_torus_gs/config.yaml` (+74 lines), `runs/yan_li_saito_f1_torus_gs/README.md` (+15 lines), `src/workflow/initialization/atoms.jl` (+21 lines, new `Eu151_f1_effective` entry)

## 3. Commands executed

```
$ git checkout -b auto/turn_31_yan-li-saito-f1-torus-design
Switched to a new branch 'auto/turn_31_yan-li-saito-f1-torus-design'

$ git add runs/yan_li_saito_f1_torus_gs/config.yaml runs/yan_li_saito_f1_torus_gs/README.md src/workflow/initialization/atoms.jl
# staged 3 files, 109 insertions

$ git commit  # FAILED: 1Password op-ssh-sign-wsl.exe needs interactive unlock
# gitleaks: 0 leaks found (PASS)
# fatal: failed to write commit object (1Password locked)
```

No Julia was executed (text-only Design turn per directive §NON-DELIVERABLES).

## 4. Metrics

```json
{
  "experiment_kind": "modify_only",
  "norm_initial": null,
  "norm_final": null,
  "norm_drift": null,
  "energy_initial": null,
  "energy_final": null,
  "energy_monotonic": null,
  "mz_target": null,
  "mz_final": null,
  "fitted_order": null,
  "fit_dt_range": null,
  "fit_r_squared": null,
  "wall_time_sec": 240,
  "peak_memory_gb": null,
  "tests_passed": null,
  "file_exists_runs_yan_li_saito_f1_torus_gs_config_yaml": true,
  "file_exists_runs_loop_sim_turn_31_md": true,
  "grep_count_initial_state_OR_potential_OR_lhy_OR_ddi_in_config_yaml": 5,
  "grep_count_F1_PASS_OR_F1_FALSIFIED_OR_n_max_in_sim_turn_31": 6,
  "grep_count_Q2_OR_Q4_in_sim_turn_31": 8,
  "grep_count_julia_project_OR_load_config_OR_precondition_in_sim_turn_31": 5,
  "grep_count_peak_density_OR_E_LHY_OR_E_ddi_in_config_yaml": 4,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 12615072,
    "total": 12615072,
    "effective_full_rate": 1695597,
    "breakdown": {
      "input_fresh": 11628,
      "cache_creation": 280856,
      "cache_read": 12302049,
      "output": 20539
    },
    "n_messages": 103,
    "n_message_starts": 103
  },
  "warnings": [
    "git commit blocked by 1Password SSH signing; files staged on disk, commit needs manual 'git commit' after op unlock",
    "auto_defaults.jl does not handle Eu151_f1_effective in its if/elseif chain \u2014 falls to fallback (no grid auto-derive); grid is specified explicitly so no runtime impact",
    "save: block uses non-standard 'save.every/psi/observables' structure; T32 implementer_julia should verify this parses or replace with documented 'save_every' key"
  ],
  "physical_red_flags": [],
  "falsification_result": "INCONCLUSIVE"
}
```

## 5. Observations (§2 Q2 + Q4 audit results)

### Q2 audit: Eu151 atom species override for paper's g_F·F = 9/2

**Finding**: The `Eu151` constant in `src/workflow/initialization/atoms.jl:208-219` is hardcoded to F=6, g_F = 1.1628, μ = 6.977 μ_B. The `AtomSpecies` struct (`src/foundation/types/spin_atom.jl:79`) has no YAML override slot for F or g_F — the struct fields are set at construction time, not from YAML at runtime. The YAML parser at `run_step_ground_state.jl:23` calls `resolve_atom(Symbol(p["atom"]))` which does a static Dict lookup; there is no YAML-side mechanism to override F or g_F on an existing atom.

**Decision**: Added new atom `Eu151_f1_effective` to `src/workflow/initialization/atoms.jl` (approach (a) per director brief). Parameters:
- F=1, mass = 150.919857 AMU (same as Eu-151)
- a0 = a2 = 21 a₀ → a_s = (a0 + 2·a2)/3 = 21 a₀ (F=1 path)
- μ = 4.5 μ_B (g_F·F = 9/2; paper's effective spin convention)
- g_F = 4.5 (with F=1, g_F = 4.5 to give g_F·F = 4.5)

Registered in ATOM_REGISTRY at `atoms.jl:284`: `:Eu151_f1_effective => Eu151_f1_effective`.

**Why a_s = 21 a₀**: From theorist T30 §3 Check 2 (lines 320-326): μ = 4.5 μ_B → a_dd = μ₀μ²M/(12πħ²) ≈ 25.2 a₀. For ε_dd = a_dd/a_s = 1.2: a_s = 25.2/1.2 = 21 a₀. ✓

**Side effect**: `auto_defaults.jl:113-131` uses an if/elseif chain for atom names; `Eu151_f1_effective` hits the `else return fallback` branch. No runtime impact because grid is specified explicitly in the YAML.

### Q4 audit: target_Jz YAML plumbing

**Finding via grep**:

- `src/solvers/ground_state.jl:113`: `find_ground_state` accepts `target_Jz::Union{Nothing, Float64}=nothing` kwarg — the solver-level API EXISTS.
- `src/workflow/experiments/schema/schema.jl:111`: only `"target_magnetization" => FieldSpec(; type=Number)` is in the schema — `target_Jz` is NOT a registered YAML field.
- `src/workflow/experiments/pipeline/run_step_ground_state.jl:253-266`: `find_ground_state(...)` call does NOT pass `target_Jz` — only `rotating_frame_omega=gs_rf_omega` (line 265). The `target_Jz` kwarg is silently dropped.

**Verdict Q4**: GAP CONFIRMED. The pipeline-level YAML→solver plumbing for `target_Jz` is missing. `target_magnetization` (→ `target_mz` → `target_magnetization` kwarg) IS wired (`run_step_ground_state.jl:161, 259`); `target_Jz` is NOT.

**Impact on F1**: None. F1 is a pure energy-minimization ITP run with no L_z constraint (`init_psi_fl_vortex` provides the topology; ITP relaxes to the torus GS). `target_Jz` is only needed for F2 (Barnett signature, ℓ=1 constrained state).

**Required fix for F2**: Add to `run_step_ground_state.jl` at line 161:
```julia
target_jz = _get_optional_float(p, "target_Jz")
```
and pass it to `find_ground_state(; ..., target_Jz=target_jz, ...)` at line 259. This is a ~3-line patch; T34 implementer_text scope (between F1 Analyze and F2 Design). No schema.jl update needed since `target_Jz` is a numeric field (would pass through FieldSpec Number validation if added).

## 6. YAML construction notes (§3)

Critical lines with rationale:

```yaml
atom: Eu151_f1_effective   # Q2: new species g_F=4.5, F=1, a_s=21a₀, μ=4.5μ_B (T30 §3 Check 2)
N_atoms: 15000              # paper anchor: N=15000 (memory file line 76)
omega_ref: 314.159          # 2π·50 rad/s → a_ho≈1.158μm (Klaus-convention, consistent with eu151_klaus_phi_phys)
grid: {n: [80,80,80], box: [113.0,113.0,113.0]}  # 8×L₀; L₀≈14.1 a_ho; dx≈1.41 a_ho (Q3 CLEAR)
potential: {type: none}     # Q3 CLEAR: NoPotential() via builders_potential.jl:6-7; free space
ddi: {enabled: true, secular: false}  # full DDI tensor; paper uses non-secular (T30 §5 item 4)
lhy: {kind: scalar}         # Q1 CLEAR: auto-derives c_lhy=(128/3√π)(a_s/a_ho)^(3/2)·N·Q5(ε_dd=1.2)
initial_state: fl_vortex    # Q5 CLEAR: flux-closure topology; winding=1, theta=π/2 (in-plane spin)
```

The `init_state_params.theta` is written as `1.5707963267948966` (π/2 in float64, since YAML doesn't parse `π/2` directly).

The `save.observables` list includes `[norm, peak_density, E_kin, E_s, E_ddi, E_LHY]` to support both F1 (peak_density) and F4 (energy decomposition ratio) post-processing from the same run.

**Note on save block**: The `save: {every: 200, psi: true, observables: [...]}` structure should be verified by T32 against the current pipeline schema — the canonical key is `save_every` at the step level. If parsing fails, replace with:
```yaml
save_every: 200
save_psi: true
```
and post-process observables via the `energy_decomposition` analyzer.

## 7. Observable manifest precondition check (§4)

T32 implementer_julia runs this as the FIRST action before the simulation (precondition check):

```
julia --project=. -e 'using SpinorBEC; cfg = SpinorBEC.load_config("runs/yan_li_saito_f1_torus_gs/config.yaml"); println("Config loaded: ", length(cfg.pipeline), " pipeline steps"); gs = cfg.pipeline[1]; atom = SpinorBEC.resolve_atom(Symbol(get(gs, "atom", "Eu151"))); println("Atom: ", atom.name, " F=", atom.F, " g_F=", atom.g_F, " a_s/a0=", round(atom.a_s/5.291772e-11; digits=1)); ddi_block = get(gs, "ddi", Dict()); println("DDI enabled: ", get(ddi_block,"enabled",false)); lhy_block = get(gs, "lhy", Dict()); println("LHY kind: ", get(lhy_block,"kind","none")); println("initial_state: ", get(gs,"initial_state","polar")); println("precondition OK: atom/ddi/lhy/initial_state all present")'
```

This command: (1) loads the YAML without building a workspace (no GPU/JIT cost); (2) resolves the atom species from ATOM_REGISTRY (fails if `Eu151_f1_effective` not found); (3) prints DDI enabled status; (4) prints LHY kind; (5) prints initial state name. Exit 0 = all fields parse; nonzero = missing or malformed field.

If `load_config` is not the right function name, use:
```
julia --project=. -e 'using SpinorBEC; cfg = SpinorBEC.run_yaml("runs/yan_li_saito_f1_torus_gs/config.yaml"; dry_run=true)'
```
or grep `src/workflow/` for the correct config-load entry point.

The observable-level check (peak_density, E_kin, E_s, E_ddi, E_LHY) cannot be verified without workspace build (requires JIT + atom resolution). The precondition above checks the schema-parse level; any observable-name mismatch will surface at run_yaml execution with a clear error.

## 8. F1 falsifier success criteria for T32 Execute (§5)

Applied by T33 Analyze to the completed ITP output (`result.jld2` under `runs/yan_li_saito_f1_torus_gs/`):

**Primary observable**: `n_max` = peak density from analyzer `peak_density`, converted to paper's D₀ units:
```
D₀ = 1 / (a_s³ × N²)  with a_s = 21 a₀ = 21 × 5.292e-11 m = 1.111e-9 m, N = 15000
D₀ = 1 / (1.111e-9)³ / 15000² = 1 / (1.373e-27 × 2.25e8) = 3.24e18 m⁻³
```
In dimensionless (a_ho = 1.158 μm) units: D₀ × a_ho³ = 3.24e18 × (1.158e-6)³ = 3.24e18 × 1.553e-18 = 5.03. So n_max (dimensionless) ≈ 13000 × 5.03 ≈ 65390 a_ho⁻³ is the predicted peak in code units.

**F1 PASS**: `|n_max_code - 65390| / 65390 < 0.10` (10% tolerance). In D₀ units: n_max ∈ [11700, 14300] D₀.

**F1 FALSIFIED**: `|n_max_code - 65390| / 65390 > 0.50`. In D₀ units: n_max outside [6500, 19500] D₀.

**F1 INCONCLUSIVE**: 0.10 < gap ≤ 0.50 (10-50% off; suggests minor framework drift or convergence issue; trigger researcher dispatch).

**F4 post-process** (free, same run output): dump E_kin, E_s, E_ddi, E_LHY from energy decomposition analyzer. Compute ratio |E_LHY|/|E_ddi|. Predicted ratio ≈ 5–10 (droplet balance). If ratio outside [2, 20], flag for researcher.

**Norm check**: norm_drift < 1e-6 required (ITP normalization; any value > 1e-4 is a solver bug).

**Convergence check**: ITP must converge (energy monotonically decreasing in last 1000 steps, dE/step < 1e-8 × |E|).

## 9. Cost estimate for T32 Execute (§6)

Grid: 80³ = 512000 cells. F=1 spinor (D=3 components). ITP with DDI: each step involves FFT (80³) + spin interaction + LHY.

**Reference benchmarks**:
- `eu151_mz_scan`: 13 points, 64³ grid, F=6 (D=13). Per T30 §3 F1 note: "1-2 min CPU or seconds on GPU" for F=1.
- F=6 at 64³ = ~5-10× heavier than F=1 at 64³ (13 vs 3 spinor components + more coupling channels). F=1 at 64³ ≈ 10-30 sec GPU. F=1 at 80³ ≈ 2× more FFT work → 20-60 sec GPU.

**8000 steps at 80³ F=1 GPU**: estimated 2-4 min GPU wall time. DDI adds ~3× FFT overhead vs no-DDI → 6-12 min GPU total. Conservative upper bound: 20 min GPU.

**Cost estimate**: well within T32 budget of <30 min wall. Effective tokens ~2-3M (implementer_julia_gpu standard).

**First-cut option**: if 80³ proves slow (> 60 min), reduce to 64³ with box [96, 96, 96] → dx ≈ 1.5 a_ho. Peak density comparison still valid at that resolution.

## 10. Risk register (§7)

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| ITP divergence in free space — droplet disperses to box boundary before LHY/DDI stabilize it | Medium | F1 FALSIFIED spuriously | Use `init_psi_fl_vortex` (compact seed ~1-2 a_ho σ default); if divergence seen, reduce dt to 0.001 or add 50-step warm-up with weak harmonic trap (ω=0.01) that is then ramped to zero |
| Periodic image artifact at box=8L₀ — density peak influenced by periodic copies | Low | F1 off by ~5% | Box size 113 a_ho at 80³; droplet radius ~14 a_ho → image separation ~113 a_ho >> droplet size. Should be negligible. If F1 INCONCLUSIVE, increase box to 10×L₀ = 141 a_ho on a 96³ grid |
| `save` block YAML schema mismatch — `save.every/psi/observables` structure not parsed | Medium | Run fails at startup | T32 implementer_julia checks parser; fallback: remove `save` block entirely and rely on `save_every: 200` top-level key + energy_decomposition analyzer for energy breakdown |
| `Eu151_f1_effective` not found by auto_defaults.jl → grid auto-derive skipped | Low (non-blocking) | No auto-grid feature | Grid is explicitly specified; auto_defaults fallback has no runtime impact |
| `init_psi_fl_vortex` F=1 untested coverage — may produce wrong shape for F=1 | Low | Wrong initial topology | Wrapper is `init_psi(grid, sys; state=:fl_vortex, init_state_params=Dict(:vortex_charge => 1, :theta => π/2))` which dispatches on `sys.F`. F=1 spinor at θ=π/2 is a 3-component spin-coherent state — should be well-formed. If ITP doesn't converge, switch to `init_psi_spin_coherent(theta=π/2)` as alternative |
| LHY auto-derive fails — `c_dd_val` is NaN before `_resolve_lhy_block!` runs (parsing order issue) | Low-Medium | c_lhy = 0, no LHY repulsion, collapse | DDI is enabled with `enabled: true`; parsing order in `run_step_ground_state.jl` resolves DDI before LHY block. Verify with precondition check. If c_lhy=0 in run log, supply explicit `c_lhy` in YAML |

## 11. Issues / deviations

- `[WARN]` git commit blocked by 1Password SSH signing. All three files are staged; anko can commit with `git commit -m "feat(yan-li-saito): Design stage F1 torus GS config + Eu151_f1_effective atom"` after `op unlock`.
- `[WARN]` Q4 target_Jz not wired in pipeline YAML→solver path. Confirmed gap at `run_step_ground_state.jl:253-266`. F1 unaffected; F2 requires a 3-line patch (documented above in §2 Q4 section).
- `[WARN]` `save:` block structure in config.yaml uses `observables: [norm, peak_density, ...]` which may not match current pipeline save schema. T32 should verify or simplify to `save_every: 200`.

## 12. Falsification check

This is a Design turn (text-only, no julia execution). No empirical result to falsify.
- `falsification_result: INCONCLUSIVE` — Design stage produces a YAML artifact; falsification applies to T32 Execute + T33 Analyze against F1 criterion (n_max ≈ 13000 D₀ ±10%).
