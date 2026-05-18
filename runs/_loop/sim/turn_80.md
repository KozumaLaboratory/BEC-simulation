---
turn: 80
subagent: theorist
workload_class: theorist
experiment_kind: derive_theory
directive_label: edh-matsui-execute-T80-bz-sign-convention-independent-derivation
depends_on: [director/turn_80, theorist/turn_80]
produces: "Shim mirroring theorist §10 Metrics into §4 so judge.py contract evaluation can run. Full derivation in runs/_loop/theorist/turn_80.md."
---

# Turn 80 — Sim shim (theorist-routed derive_theory turn)

This turn was dispatched by the director (route (a) theorist) as a non-Julia
src-anchored derivation, not a code-execution turn. There is no implementer
phase: theorist directly produced the src-anchored prediction and metrics.

The director's §6 declarative contract (`runs/_loop/director/turn_80.md` §6)
specifies 11 success_criteria that judge.py is expected to evaluate against
the theorist's §10 Metrics block. To keep the judge.py invocation pattern
uniform (it reads sim/turn_${N}.md), this file mirrors theorist §10 verbatim
into the canonical §4 Metrics location below.

## 1. Result narrative (one-paragraph)

Theorist verified the SpinorBEC.jl Zeeman sign-convention chain end-to-end
from YAML `Bz: "-0.01 Gauss"` through unit parse, `bfield_to_p` construction,
to the `H_Zee = -p · m_F + q · m_F²` production convention (verbatim from
`src/hamiltonian/potentials/zeeman.jl:10,19`). Sign survives the chain
(p_dimless ≈ −162.78). Under H_Zee = −p · m_F with p < 0, the unique
energetic minimum on m_F ∈ {−6,…,+6} is at m_F = −6, corresponding to
spinor component c = 13. The T75 empirical anchor (Mz = +6.0 at Bz = +0.01 G)
is uniquely consistent with this convention under sign reversal,
independently corroborating the algebra. 6 confounders audited, all ABSENT.
ITP has no `target_magnetization` kwarg set (YAML lacks the field;
default = `nothing`), so the descent is unconstrained and lands at the
energetic minimum. **Prediction: m_F = −6 dominant at GS convergence**,
populations[c=13] > 0.99 expected.

## 2. Falsifier outcome

DERIVATION_COMPLETE. The src-anchored derivation closes T77 critic §5.2's
disclosed src-inspection gap. T81 director should route to GPU retry
(implementer_julia_gpu Execute with approval-gate workaround) with a
high-confidence src-anchored prior.

## 3. Files inspected (read-only)

See theorist §10 `src_files_inspected`. 12 files. No src/, YAML, or docs/
modifications. No git operations.

## 4. Metrics

```json
{
  "experiment_kind": "derive_theory",
  "workload_class": "theorist",
  "step0_haskey_B_count": 2,
  "step0_haskey_zeeman_count": 0,
  "step0_yaml_bz_negative_verified": true,
  "step1_unit_parse_sign_preserved": true,
  "step1_bz_internal_tesla": -1.0e-6,
  "step2_p_dimless_value": -162.78,
  "step2_p_dimless_sign": "negative",
  "step3_h_zee_convention_from_src": "-p·m_F",
  "step3_src_file_citation": "src/hamiltonian/potentials/zeeman.jl:10,19 — `[(-z.p * m + z.q * m^2) for m in sys.m_values]` and `ntuple(c -> -z.p * (F - (c - 1)) + z.q * (F - (c - 1))^2, Val(D))`",
  "t75_empirical_consistent_with_convention": true,
  "step4_target_magnetization_in_yaml": false,
  "step4_predicted_min_m_F": -6,
  "step5_confounders_audited_count": 6,
  "step5_confounders_present": [],
  "final_classification": "PREDICTS_PASS_m_minus_F",
  "derivation_quality_self_assessment": "high",
  "src_files_inspected": [
    "src/workflow/experiments/pipeline/run_step_ground_state.jl",
    "src/workflow/experiments/runtime/zeeman_levels.jl",
    "src/workflow/experiments/schema/B_block.jl",
    "src/workflow/experiments/schema/builders_phase.jl",
    "src/workflow/io/units.jl",
    "src/hamiltonian/potentials/zeeman.jl",
    "src/hamiltonian/integrator/propagators.jl",
    "src/hamiltonian/interactions/interactions.jl",
    "src/solvers/ground_state.jl",
    "runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml",
    "runs/_loop/sim/turn_75.md",
    "runs/_loop/sim/turn_78.md"
  ],
  "src_lines_quoted_verbatim_count": 6,
  "physical_red_flags": [],
  "warnings": [],
  "falsification_result": "DERIVATION_COMPLETE"
}
```

## 5. Notes

- This sim/turn_80.md is a shim. The authoritative derivation is in
  `runs/_loop/theorist/turn_80.md`. Metrics mirrored here are identical
  to theorist §10.
- No Julia binary was invoked this turn (theorist workload class; tools
  Read/Grep/Glob/Write only).
- Token usage: theorist subagent reported by orchestrator post-turn.
