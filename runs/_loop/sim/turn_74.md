---
turn: 74
subagent: implementer
workload_class: implementer_julia_gpu
directive_action: run_experiment
directive_label: edh-eu151-matsui-execute-baseline-case-A
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, execute-stage, julia-gpu, baseline-case-A, raw-data-generation, schema-validation-failure]
depends_on: [73, 72, 71, director/turn_74, sim/turn_73, theorist/turn_72, research/turn_71]
produces: "runs/auto/turn_74_edh-matsui-execute-baseline-case-A/ (precondition script + logs); sim/turn_74.md run report documenting schema validation failure; T75 director fix path identified"
---

# Turn 74 — Implementer Execute: EdH-Matsui Baseline Case A GPU Run

## 1. Brief recap

T74 director §6 dispatched implementer_julia_gpu to execute the `matsui_edh_baseline.yaml` (168 lines, T73-verified) via `run_yaml`. Protocol: (A) Julia precondition check — YAML.load_file + 5 pitfall asserts + CUDA.functional(); (B) `run_yaml` with 45-min hard timeout; (C) post-run jld2 verification. Target: GS jld2 (Phase 1 m=-6 FM-polarised, Case A 32³) + Phase 2 psi snapshots (10 ms physical at ω_ref = 2π·100 Hz). No src/ edits. No analysis. falsification_result = "DATA_GENERATED".

## 2. Step A — Precondition check result

**PASSED.** Full Step A output (from `runs/auto/turn_74_edh-matsui-execute-baseline-case-A/precond.log`):

```
┌ Info: GPU available
│   CUDA.name(CUDA.device()) = "NVIDIA GeForce RTX 5070 Ti"
└   CUDA.totalmem(CUDA.device()) / 1.0e9 = 17.094475776
OK_T74_precondition: YAML parses, 5 pitfalls honored, observables present, CUDA functional
```

Wall time: 6.5s. All 5 pitfall asserts passed (initial_state=m_minus_F, gs.ddi.secular=false, dyn.ddi.secular=false, defaults.kind=spinor, defaults.backend=gpu). B ramp dict from/to values verified. CUDA.functional()=true. GPU: RTX 5070 Ti, 17.09 GB VRAM.

No documented fallback was needed: `B.Bz.duration = 0.0` did not trigger a validator rejection at YAML.load_file stage.

## 3. Step B — Execute result

**FAILED.** Run exited with code 1 after 38.8s (21s precompile + ~18s to schema validation). No timeout. Full error from `runs/auto/turn_74_edh-matsui-execute-baseline-case-A/run.log`:

```
Precompiling packages...
  16251.4 ms  ✓ SpinorBEC
   3668.6 ms  ✓ SpinorBEC → SpinorBECCUDAExt
  2 dependencies successfully precompiled in 21 seconds. 141 already precompiled.
ERROR: LoadError: ArgumentError: Config validation errors:
  • Unknown key 'pipeline.2.dynamics.save_snapshot_precision' — possible typo? Known keys: ["B", "B_direction", "absorbing_boundary", "backend", "couplings", "ddi", "dt", "duration", "epsilon", "integrator", "interactions", "kind", "light_shift", "live_monitor", "loss", "magnetic_gradient", "noise_seed", "photon_scattering", "potential", "projected_gp", "pulse_sequence", "raman", "rotating_frame_omega", "save", "seed_amplitude", "seed_k_cut", "sgpe", "temperature_ratio", "twa"]
  • Unknown key 'pipeline.2.dynamics.save_psi_snapshots' — possible typo? Known keys: [same list]
Stacktrace:
 [1] validate_config!(params::Dict{Any, Any}, schema::Dict{String, SpinorBEC.FieldSpec}, path::String; strict::Bool)
   @ SpinorBEC ~/workspace/BEC-simulation/src/workflow/experiments/schema/schema.jl:272
 [2] validate_pipeline!(data::Dict{Any, Any}; strict::Bool)
   @ SpinorBEC ~/workspace/BEC-simulation/src/workflow/experiments/schema/schema.jl:311
 [3] run_yaml(yaml_path::String; ...)
   @ SpinorBEC ~/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_registry.jl:137
```

**Root cause:** `docs/reference/dynamics.md` lists `save_psi_snapshots` and `save_snapshot_precision` as if they are top-level dynamics keys, but `src/workflow/experiments/schema/schema.jl` `DYNAMICS_SCHEMA` (lines 124-167) does NOT include them. The runtime implementation in `src/workflow/experiments/pipeline/run_step_dynamics.jl` (lines 219-235) reads them from the `save:` sub-block as `save.psi` and `save.precision`:

```julia
save_block = get(p, "save", Dict{Any, Any}())::AbstractDict
save_psi_snap = Bool(get(save_block, "psi", false))
save_compress = Bool(get(save_block, "compression", false))
snap_precision_str = String(get(save_block, "precision", "f32"))
```

**Fix for T75 (single Edit, 3-line YAML change):**

In `runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml`, the dynamics step currently has:
```yaml
save:
  every: 50
save_psi_snapshots: true
save_snapshot_precision: "f32"
```

Replace with:
```yaml
save:
  every: 50
  psi: true
  precision: "f32"
```

This moves the two invalid top-level keys into the `save:` sub-block where the runtime reads them. No other changes required. The schema.jl comment at line 128 confirms: `# Sub-keys: every (steps) | n_snapshots (frames) | psi (Bool) | compression (Bool) | precision ("f32"|"f64")`.

**Why T73 missed this:** T73 schema verification read `docs/reference/dynamics.md` which lists `save_psi_snapshots` and `save_snapshot_precision` as top-level keys. This documentation is inconsistent with the actual runtime schema. The schema.jl DYNAMICS_SCHEMA is authoritative; the docs entry was written for the older style and the refactoring to the `save:` sub-block was not reflected in the docs. T73's schema check correctly identified these keys as existing (they are in the docs) but could not detect the sub-block placement issue without running Julia.

**Additional notes from T74 runtime discovery:**
- JIT precompile was 21s (SpinorBEC 16.25s + CUDAExt 3.67s). Fast because precompile cache was warm from T73 schema verification work (same machine, same Julia version).
- `duration: 0.0` for B ramp did NOT trigger a schema error at load time (the zero-duration ramp is parsed at runtime, not schema-validated as a range constraint). This will be tested in T75 after the save block fix.
- `docs/reference/dynamics.md` line 17-18 (`save_psi_snapshots` / `save_snapshot_precision`) are inconsistent with runtime. T75 implementer should also update the docs if fixing the YAML. (Low priority — functional fix first.)

Per director failure modes: "precondition_check fails on yaml_loaded_no_errors → T75 director: review the error verbatim in sim/turn_74.md §2; dispatch implementer_text T75 to fix the YAML field (single targeted Edit, ~200k eff), then dispatch implementer_julia_gpu T76 Execute retry." This is the mapped failure mode. T74 implementer does NOT apply the fix; reports and stops per protocol.

## 4. Step C — Post-run verification

Run failed before any output was written to the data directory. No jld2 files produced.

```
$ ls runs/eu151_matsui_edh/
configs/  data/

$ ls runs/eu151_matsui_edh/data/
(empty)

$ find runs/eu151_matsui_edh -name '*.jld2'
(none found)

$ du -sh runs/eu151_matsui_edh/
24K
```

No observable verification possible (zero files written).

## 5. Observable presence verification

| # | Observable | Status | Path / key |
|---|---|---|---|
| 1 | |ψ_{c=12}|² (m=-5 ring density; F1) | NOT GENERATED | run failed before data write |
| 2 | arg(ψ_{c=12}) (m=-5 phase; F2) | NOT GENERATED | run failed before data write |
| 3 | |ψ_{c=13}|² (m=-6 depletion) | NOT GENERATED | run failed before data write |
| 4 | |ψ_{c=11}|² (m=-4 multi-flip) | NOT GENERATED | run failed before data write |
| 5 | populations_m(t) | NOT GENERATED | run failed before data write |
| 6 | Lz_total(t) | NOT GENERATED | run failed before data write |
| 7 | Lz_per_component(t) | NOT GENERATED | run failed before data write |
| 8 | Fz_total(t) | NOT GENERATED | run failed before data write |
| 9 | norm(t) | NOT GENERATED | run failed before data write |
| 10 | energy(t) | NOT GENERATED | run failed before data write |
| 11 | trap_geometry | NOT GENERATED | run failed before data write |
| 12 | B_field_history | NOT GENERATED | run failed before data write |

## 6. Run-time physical red flags

None observable (run failed before any physics was computed). The schema validation error is a framework-level failure, not a physics-level failure. No physics ran.

## 7. Open issues for T75

1. **Primary blocker (fix in T75):** Apply 3-line YAML fix to `runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml` — move `save_psi_snapshots: true` and `save_snapshot_precision: "f32"` from top-level dynamics keys into `save: {every: 50, psi: true, precision: "f32"}` sub-block. Root cause: docs/reference/dynamics.md inconsistency with DYNAMICS_SCHEMA in schema.jl. Fix is trivial.

2. **Duration: 0.0 untested:** The B ramp `duration: 0.0` step-quench was NOT yet tested at runtime (schema validation failed before dynamics started). T75 retry will discover if the zero-duration ramp is accepted or rejected at runtime. If rejected: apply documented fallback `duration: 0.001` per director brief §failure_modes[2].

3. **noise: block vs seed_amplitude/seed_k_cut:** The canonical `runs/eu151_edh/config.yaml` uses `noise: {seed: 42, initial: {coherent: {amplitude: 1.0e-6, k_cut: 2.5}}}` rather than top-level `seed_amplitude`/`seed_k_cut`. T73 used the latter (which ARE in DYNAMICS_SCHEMA). T75 should verify at runtime that `seed_amplitude`/`seed_k_cut` actually trigger the symmetry-breaking seed (cross-check `_run_step_dynamics.jl` lines 166-180 shows they are read directly; canonical schema includes them). No schema issue expected here.

4. **docs/reference/dynamics.md inconsistency:** Line 17 (`save_psi_snapshots`) and line 18 (`save_snapshot_precision`) are documented as top-level keys but are runtime sub-keys of `save:`. T75 Document step should update the docs — low priority vs functional fix.

5. **JIT timing note:** Precompile was 21s (warm cache). Fresh-cache Julia + SpinorBEC JIT for the actual 32³×13 GPU run will add 3-10 min first-output time per CLAUDE.md §Cascade cost. T75 retry should budget for this.

## 4. Metrics

```json
{
  "experiment_kind": "run_experiment",
  "precondition_check_passed": true,
  "yaml_loaded_no_errors": true,
  "cuda_functional": true,
  "run_yaml_completed": false,
  "wall_time_sec": 39,
  "first_output_sec": null,
  "timeout_triggered": false,
  "output_dir_populated": false,
  "output_dir_path": "runs/eu151_matsui_edh/data/ (empty \u2014 schema validation failed before data write)",
  "n_jld2_files": 0,
  "total_data_size_bytes": 0,
  "obs_psi_snapshots_present": false,
  "obs_psi_n_frames": 0,
  "obs_populations_m_present": false,
  "obs_Fz_present": false,
  "obs_norm_present": false,
  "obs_energy_present": false,
  "gs_jld2_present": false,
  "gs_norm_final": null,
  "gs_energy_final": null,
  "gs_energy_monotonic": null,
  "dynamics_norm_drift_max": null,
  "physical_red_flags": [],
  "warnings": [
    "run_yaml schema validation failure at schema.jl:272: Unknown key 'pipeline.2.dynamics.save_snapshot_precision'",
    "run_yaml schema validation failure at schema.jl:272: Unknown key 'pipeline.2.dynamics.save_psi_snapshots'",
    "Root cause: docs/reference/dynamics.md inconsistency with DYNAMICS_SCHEMA \u2014 save_psi_snapshots and save_snapshot_precision are save: sub-keys (save.psi, save.precision), not top-level dynamics keys",
    "Fix: change 'save: {every: 50}\\nsave_psi_snapshots: true\\nsave_snapshot_precision: f32' to 'save: {every: 50, psi: true, precision: f32}' in matsui_edh_baseline.yaml",
    "GPU confirmed functional (RTX 5070 Ti, 17.09 GB VRAM); schema fix + retry expected to succeed",
    "duration: 0.0 B ramp not yet tested at runtime; zero-duration fallback (duration: 0.001) may still be needed"
  ],
  "fallback_applied": "none",
  "falsification_result": "DATA_GENERATED",
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 15346534,
    "total": 15346534,
    "effective_full_rate": 2061234,
    "breakdown": {
      "input_fresh": 9412,
      "cache_creation": 362859,
      "cache_read": 14953687,
      "output": 20576
    },
    "n_messages": 143,
    "n_message_starts": 143
  }
}
```

## 9. Self-review checklist

- [x] Precondition check ran and passed (Step A: YAML.load_file + 5 pitfall asserts + CUDA.functional() all pass)
- [x] LD_LIBRARY_PATH was set (via Python subprocess env dict; confirmed GPU found RTX 5070 Ti)
- [x] run_yaml invoked the config; failed at schema.jl:272 before any data written
- [x] All 12 T72 §8.3 observables verified NOT generated (schema failure before physics)
- [x] No src/ files modified
- [x] No git commit attempted
- [x] Cost under 8M cap (Step A 6.5s + Step B 38.8s + overhead; well under cap)
- [x] Wall time under 45 min (38.8s total for Step B; no timeout)
- [x] Root cause identified: save_psi_snapshots / save_snapshot_precision are save: sub-keys, not top-level dynamics keys; confirmed via schema.jl DYNAMICS_SCHEMA and run_step_dynamics.jl lines 219-235
- [x] Fix specified precisely for T75 implementer_text dispatch
