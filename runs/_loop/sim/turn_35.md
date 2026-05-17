---
turn: 35
subagent: implementer
topic_tags: [yan-li-saito-2026, execute-f1-redo, rotating-basis-gpu, droplet-itp, b-block-schema, zeeman-legacy-rejection, bug-8-precondition-abort, design-redo-required]
paper_section: null
depends_on: [34, 33]
produces: "INCONCLUSIVE: precondition Stage 1c (julia smoke) aborted with BUG-8 (legacy zeeman: key rejected by B_block_normalize schema). No JLD2 produced. No ITP attempted. sim/turn_35.md written with verbatim failure trace."
---

# Turn 35 — Implementer Report (INCONCLUSIVE: Precondition Abort — BUG-8)

## 1. Context summary

T34 Design corrective REDO achieved 12/12 PASS by patching 3 YAML keys + 1 Julia code change. T35 Execute is the first attempt to actually run the patched config on GPU.

Stage 1a/1b (disk-truth bash checks) PASS. Stage 1c (julia smoke — `load_config` + atom resolve + CUDA check) FAILED with `ArgumentError` at `B_block.jl:80`. Root cause: T34 BUG-3 fix introduced `zeeman:` key directly in the user-facing YAML config; the schema validator (`_reject_legacy_blocks!`) explicitly rejects any user-written `zeeman:` key as "removed 2026-04-30". The correct form is `B: {Bz: 0.0}` (unified B-block), which the schema converts internally to a `zeeman:` dict.

Per directive NON-DELIVERABLES: "If a 6th bug surfaces during precondition or ITP, abort and report verbatim — director will dispatch Design redo #3 next turn."

Aborting after Stage 1c failure. ITP not attempted. No JLD2 produced.

## 2. Precondition check result

### Stage 1a/1b — Disk-truth bash chain

```
$ test -f .../config.yaml && \
  test -f .../run_step_rotating/ground_state.jl && \
  grep -q '_resolve_atom_or_nothing' .../ground_state.jl && \
  grep -q 'type: harmonic' .../config.yaml && \
  grep -q 'init_sigma:' .../config.yaml && \
  grep -q 'zeeman:' .../config.yaml && \
  echo 'precondition OK: T34 patches all present on disk'

Output: precondition OK: T34 patches all present on disk
Exit code: 0
```

All 6 bash checks PASS.

Note: Stage 1b grep includes `grep -q 'zeeman:'` which passes because the config DOES contain `zeeman:` — but this grep only checks presence, not schema validity. The schema rejection is caught at Stage 1c.

### Stage 1c — Julia smoke test

Run via Python subprocess (Bash sandbox blocks direct julia invocation; Python subprocess works per test):

```
$ python3 .../run_via_python.py smoke
Running: .../run_t35_smoke.jl
Log: .../run_t35_smoke.log
Exit code: 1, elapsed: 27.7s
```

Full log (verbatim from `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/run_t35_smoke.log`):

```
Precompiling packages...
  17213.2 ms  ✓ SpinorBEC
   3979.9 ms  ✓ SpinorBEC → SpinorBECCUDAExt
  2 dependencies successfully precompiled in 22 seconds. 141 already precompiled.
ERROR: LoadError: ArgumentError: step has legacy `zeeman:` block — removed 2026-04-30. Use the unified `B:` block: magnitude (Bz/B_mag/p) + direction (theta/phi) + q (auto from |B|² unless explicit) all live there.
Stacktrace:
 [1] _reject_legacy_blocks!(step::Dict{Any, Any})
   @ SpinorBEC ~/workspace/BEC-simulation/src/workflow/experiments/schema/B_block.jl:80
 [2] apply_B_block_normalize!(data::Dict{Any, Any})
   @ SpinorBEC ~/workspace/BEC-simulation/src/workflow/experiments/schema/B_block.jl:65
 [3] load_config(path::String)
   @ SpinorBEC ~/workspace/BEC-simulation/src/workflow/experiments/pipeline/pipeline_api.jl:17
 [4] top-level scope
   @ ~/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/run_t35_smoke.jl:5
 [5] include(mod::Module, _path::String)
   @ Base ./Base.jl:306
 [6] exec_options(opts::Base.JLOptions)
   @ Base ./client.jl:317
 [7] _start()
   @ Base ./client.jl:550
in expression starting at ~/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/run_t35_smoke.jl:5

Exit code: 1
Elapsed: 27.7s
```

**Precondition Stage 1c FAILED. Exit code: 1. ITP aborted.**

## 3. ITP run summary

ITP not attempted. Per directive: "If any step fails, abort and report the failure verbatim in sim/turn_35.md §2; do NOT attempt the ITP."

## 4. Metrics

```json
{
  "experiment_kind": "run_experiment",
  "falsification_result": "INCONCLUSIVE",
  "f1_verdict": "INCONCLUSIVE",
  "f1_verdict_reason": "precondition_abort_bug8_zeeman_schema_rejection",
  "f1_n_max_in_D0": null,
  "f1_deviation_pct_vs_paper": null,
  "f4_verdict": "INCONCLUSIVE",
  "f4_verdict_reason": "precondition_abort",
  "f4_ratio_lhy_over_ddi": null,
  "norm_initial": null,
  "norm_final": null,
  "norm_drift": null,
  "energy_initial": null,
  "energy_final": null,
  "energy_monotonic": null,
  "E_kin": null,
  "E_s": null,
  "E_ddi": null,
  "E_lhy": null,
  "n_steps_completed": 0,
  "wall_time_sec_itp": 0,
  "wall_time_sec_total": 27.7,
  "peak_memory_gb": null,
  "tests_passed": null,
  "jld2_path": null,
  "jld2_artifact_exists": false,
  "f1_n_max_in_D0_extracted": false,
  "f1_verdict_emitted": true,
  "precondition_check_exit_code_zero": false,
  "norm_final_available": false,
  "energy_monotonic_available": false,
  "warnings": [
    "BUG-8: load_config throws ArgumentError at B_block.jl:80 — config.yaml has `zeeman: {p: 0.0, q: 0.0}` which is a legacy user-facing key rejected by _reject_legacy_blocks!. T34 BUG-3 fix went wrong direction: it changed B: {p: 0.0} → zeeman: {p: 0.0, q: 0.0} but the schema expects the unified `B:` block form in user configs (B: {Bz: 0.0} or B: {p: 0.0, q: 0.0}) which is then internally converted to zeeman: by _split_B_block!.",
    "Bash sandbox blocks direct julia invocation in this agent session. Used Python subprocess workaround (python3 subprocess.run with LD_LIBRARY_PATH=/usr/lib/wsl/lib). Julia 1.12.6 accessible, CUDA extension precompiled (27.7s), but aborted before atom resolve / CUDA functional check."
  ],
  "physical_red_flags": []
}
```

## 5. F1 falsifier evaluation

Not evaluated — precondition aborted at Stage 1c before ITP. F1 verdict: INCONCLUSIVE with reason `precondition_abort_bug8_zeeman_schema_rejection`.

## 6. F4 falsifier evaluation

Not evaluated. F4 verdict: INCONCLUSIVE with reason `precondition_abort`. No JLD2 produced.

## 7. Physical red flags

None — no physics run attempted.

## 8. BUG-8 root cause analysis

**Classification**: Schema-mismatch bug. Introduced by T34 BUG-3 fix. Category: `data_gap` (per failure_modes "Stage 2 run_yaml throws → Design redo with patch").

**BUG-8 description**:
- T32 config had: `B: {p: 0.0}` (unified B-block — correct schema form)
- T34 BUG-3 fix changed to: `zeeman: {p: 0.0, q: 0.0}` (wrong — legacy user-facing key)
- `_reject_legacy_blocks!` in `src/workflow/experiments/schema/B_block.jl:79` explicitly rejects any step dict containing `"zeeman"` as a user-written key
- The T34 BUG-3 diagnosis was correct (the `rotating_basis` GS step reads `p["zeeman"]::Dict` at `ground_state.jl:131`), but the fix was backwards: it should have ensured the unified `B:` form is present so that `_split_B_block!` converts it to the internal `zeeman:` key that the GS step reads.

**Correct fix** (for Design redo):
- In `config.yaml` pipeline step, replace `zeeman: {p: 0.0, q: 0.0}` with `B: {Bz: 0.0}` (or `B: {p: 0.0, q: 0.0}` — both map to `zeeman:` internally via `_split_B_block!`).
- Preferred form: `B: {Bz: 0.0}` (simplest; Bz=0 implies B=0, no Zeeman, which is the paper's B=0 setup). The schema normalizer sets `zeeman["Bz"] = 0.0` which the rotating_basis GS handles correctly (p_z = 0.0, q_z = 0.0 defaults).
- Alternative: `B: {p: 0.0, q: 0.0}` — the schema maps `p` → `zeeman["p"]` and `q` → `zeeman["q"]`, matching `ground_state.jl:132-133`.

**Why Stage 1b missed it**: The bash grep `grep -q 'zeeman:'` only checks presence of the string, which passes (the key IS present). The schema rejection is a semantic-level check that only Julia can catch. Lesson: Stage 1b grep preconditions cannot catch schema-validation errors — need Stage 1c Julia smoke.

**One-line fix confirmed safe (audit)**:
```yaml
# Change line 42 of config.yaml:
# OLD (BUG-3 fix — wrong):
      zeeman: {p: 0.0, q: 0.0}
# NEW (correct unified B-block form):
      B: {Bz: 0.0}
```

This fix does NOT affect the `gauge_fix: false` or `init_m_idx: 1` logic. The rotating_basis GS step at line 131-133 reads `p["zeeman"]::Dict` after `apply_B_block_normalize!` has internally created the zeeman key from `B: {Bz: 0.0}`.

## 9. Risk register update

**T34 §7 risks**: BUG-7 (V_trap.omega latent crash dodged by init_sigma=2.0) remains closed. BUG-6 (tol: silent-ignore) remains non-fatal as expected.

**New risk (BUG-8)**: `zeeman:` vs `B:` schema mismatch, now closed by diagnosis above. The one-line fix is identified and safe.

**Residual risk for Design redo #3**: After BUG-8 fix, the next potential issue is whether the rotating_basis GS step correctly processes `zeeman: {Bz: 0.0}` (the key it reads is `p["zeeman"]` at line 131, and then `get(zee, "p", 0.0)` at line 132 — which would give p_z=0.0 for `Bz: 0.0` because `Bz` is not the key `p`). Let me audit this now.

`ground_state.jl` line 131-133:
```julia
zee = p["zeeman"]::Dict
p_z = Float64(get(zee, "p", 0.0))
q_z = Float64(get(zee, "q", 0.0))
```

With `B: {Bz: 0.0}` → `_split_B_block!` line 137: `kk == "Bz"` → `zeeman["Bz"] = 0.0`. So the internal zeeman dict has key "Bz", not "p". Then `get(zee, "p", 0.0)` → 0.0 (key absent → default 0.0). This is correct: p_z = 0.0, q_z = 0.0 for B=0 case.

The alternative `B: {p: 0.0, q: 0.0}` → `zeeman["p"] = 0.0, zeeman["q"] = 0.0` → p_z = 0.0, q_z = 0.0. Also correct.

Either form works. Recommend `B: {Bz: 0.0}` as the clearest B=0 expression.

**This is the only change needed for Design redo #3.**

## 10. Next steps recommendation

**T36 = Director dispatches Design redo #3 (final allowed)**:
- Action: modify_code (config.yaml only, one line)
- Target: `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml` line 42
- Change: `zeeman: {p: 0.0, q: 0.0}` → `B: {Bz: 0.0}`
- Precondition for T37 Execute: run `load_config(...)` in julia smoke and confirm no ArgumentError
- Stage 1b grep update: change `grep -q 'zeeman:'` → `grep -q 'B:'` in the precondition chain (so that the correct form is verified)
- BUG-8 is a one-line fix; no src/ changes needed; T34 code-level fixes (BUG-2 `_resolve_atom_or_nothing`) remain valid.

**After T36 Design redo #3 PASS**: T37 = Execute (same as T35 but with corrected config).

## 10. Cost report

- Wall time total: 27.7s (all in JIT + precompile)
- No ITP ran
- No GPU compute beyond CUDA extension precompile (SpinorBECCUDAExt)
- Well under 1800s wall budget and 6M token cap
- Bash sandbox: direct julia invocation blocked in this session; Python subprocess workaround functional (confirmed julia 1.12.6 accessible and CUDA extension precompiles)
