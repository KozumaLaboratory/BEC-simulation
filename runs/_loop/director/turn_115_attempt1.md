---
turn: 115
subagent: director
investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
stage_advancing_from: "Hypothesize (T114 theorist PASS — projector-orbit-average + Schur-isotropic-basis fix proposed, falsifier contract written)"
stage_advancing_to: "Test (implementer_julia_cpu_light runs F1 + F2 + F3 against extended `f9_f11_polyhedral_verification.jl`)"
topic_tags: [sign-pattern-lemma1-general-S, f9-ta-multiplicity-2, paper3-section-V-completeness, projector-orbit-average, schur-isotropic-basis, D3-axis, test-stage, julia-cpu-light]
paper_section: "papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md (extension)"
depends_on:
  - 114
  - 113
  - 112
  - 111
  - 94
  - "runs/_loop/seed.md"
  - "runs/_loop/state.json"
  - "runs/_loop/director/turn_114.md"
  - "runs/_loop/theorist/turn_114.md"
  - "runs/_loop/judge/turn_114.json"
  - "runs/_loop/_local/scheduler_115.json"
  - "docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md"
  - "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md"
  - "scripts/manuscript/f9_f11_polyhedral_verification.jl"
  - "scripts/manuscript/lemma1_general_S_verification.jl"
  - "memory:universal_structure_u1u4_2026_05_13"
  - "memory:feedback_cost_overhead_is_the_cost"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:feedback_manuscript_is_not_the_essence"
produces: >
  T115 advances `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` from
  Hypothesize → Test. T114 theorist (judge PASS 8/8 + precondition) produced
  a clean implementer-executable falsifier contract:
  F1 (central) `|bar_beta_0 - 1/19| < 1e-13` via projector-orbit-average density
  matrix `rho_inv = (1/m_rep) sum_i |zeta_i><zeta_i|` and
  `bar_beta_S = Tr[Pi_S (rho_inv ⊗ rho_inv)]`;
  F2 (advisory) seed-independence across 10 RNG seeds;
  F3 (regression) `scripts/manuscript/lemma1_general_S_verification.jl` 29/29 PASS
  (strict generalization). Disk check this turn: edh-matsui spatial_profiles.csv
  STILL ABSENT, seed.md priority-0 STILL HELD — parallel-track operation continues
  per T114's authorized pivot; edh-matsui investigation remains active at tier 2.75
  frozen-blocked. Scheduler JULIA_GPU_OK; CPU-light is sufficient (D=19 matrices,
  dim-2 multiplicity space, CG sums, no GPU). Subagent: implementer_julia_cpu_light.
  D3 axis (new derivation Tier 1.5 → 2.5 on successful Test). Per
  `feedback_use_existing_artifacts_first`: extend existing
  `scripts/manuscript/f9_f11_polyhedral_verification.jl` (which already imports
  SpinorBEC, has `clebsch_gordan`, `project_onto_irrep`, `project_S_channel`,
  CG-table, group generators) rather than creating a parallel file.
---

# Turn 115 — Director Report

## 1. Top-of-turn disk + state check

| Path | Status this turn | Implies |
|---|---|---|
| `runs/_loop/theorist/turn_114.md` | present, T114 PASS 8/8 | T115 lifts Test stage on the F=9 T:A investigation |
| `runs/eu151_edh_K3_long/spatial_profiles.csv` | **ABSENT** | anko has not run wrapper between T114 and T115 |
| `runs/eu151_edh_K3_long/ring_summary.json` (non-probe) | **ABSENT** | same |
| `runs/_loop/seed.md` | unchanged (priority-0 pin on edh-matsui still held verbatim) | edh-matsui parallel-track holds; F=9 T:A continues per T114 authorization |
| `runs/_loop/state.json` `active_investigation_id` | `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` | T114 already flipped active inv to F=9 T:A |
| `runs/_loop/_local/scheduler_115.json` | `JULIA_GPU_OK`; full menu open | CPU-light julia permitted; no harness constraint |
| `last_judge` | PASS | T114 result clean, advance |
| drift `cost_inflation` | 1.497 at T114 | T114 was 20.7M orchestrator tokens; T115 budget should be modest (~1.5M expected, well-bounded by julia wall-time cap) |
| drift `subagent_repetition` | 0.333 at T114 (down from 0.667 at T113) | streak broke; T115 implementer dispatch is a different class from T114 theorist |

**Routing gate** (per protocol table):
- Active investigation `next_stage_action` is `Test` (per T114 §6 implementer directive + judge `investigation_update.if_success_advance_to_stage`). Scheduler allows. Last verdict PASS. → advance to Test, dispatch implementer.
- Concurrent: edh-matsui remains in active set; the moment `spatial_profiles.csv` appears on disk, a future director turn dispatches critic for spatial F1 re-audit. T115 does not block that path.

## 2. Why implementer_julia_cpu_light (not sympy, not implementer_text)

T114 theorist §6 listed an exact implementer directive:

1. `m_rep = rank(P; tol=1e-8)` — should return 2 for F=9 T:A.
2. SVD basis of `Im(P)`: `zetas = U[:, 1:m_rep]` Gram-Schmidt orthonormalized.
3. `rho_inv = (1/m_rep) * sum(zeta_i * zeta_i' for i in 1:m_rep)`.
4. `mult_aware_beta_S(rho_inv, F, S) = sum over (M, m1, m2, m1', m2') of conj(C^SM_{Fm1,Fm2}) * C^SM_{Fm1',Fm2'} * rho_inv[m1',m1] * rho_inv[m2',m2]`.
5. Verify F1 tolerance `1e-13`.
6. Verify F2 by 10-seed sweep.
7. F3 regression: `julia scripts/manuscript/lemma1_general_S_verification.jl` PASS 29/29.

This is dim-19 matrix algebra + CG sums + a single-script execution. The existing `scripts/manuscript/f9_f11_polyhedral_verification.jl` already has:
- `using SpinorBEC` + `clebsch_gordan` (`Grep` confirmed line 183 calls it).
- `tetrahedral_gen`, `octahedral_gen`, `compute_T_character`, `compute_O_character`, `project_onto_irrep` — the projector machinery.
- `project_S_channel(ζ, F, S)` — the rank-1 baseline computation.
- `verify_case(F, group, irrep)` — driver.

Per `feedback_use_existing_artifacts_first`: the implementer extends this file rather than creating `f9_TA_mult2_schur_restore.jl` from scratch. Two NEW functions:

- `find_invariant_basis(P, D; tol=1e-8)` — SVD basis of `Im(P)`, returns `Vector{Vector{ComplexF64}}` of length `m_rep`.
- `mult_aware_beta_S(rho_inv, F, S)` — Einstein-sum trace formulation.

Plus a new driver `verify_case_mult_aware(F, group, irrep; seeds=1:10)` mirroring `verify_case` but calling the new functions and recording per-seed `bar_beta_0` values for F2.

**Why NOT implementer_sympy**: theorist §6 marks sympy "Optional ... not required". The numerical julia path with `1e-13` tolerance is sufficient to gate F1; the exact-rational `1//19` check is a nice-to-have for a future turn, not load-bearing. Sympy would require re-implementing `clebsch_gordan` exactly in python and porting the group-projector code — strictly more work for a tighter bound the test doesn't need.

**Why NOT implementer_text**: this is the Test stage. Verifying the prediction requires executing julia and reading the numerical output. Text-only cannot evaluate `|bar_beta_0 - 1/19| < 1e-13`.

**Why CPU light not heavy/GPU**: D=2F+1 = 19. SVD of a 19×19 matrix, CG sums over O(F^4)=10000 terms per channel, 10 RNG seeds. Total: a few seconds of math after SpinorBEC precompile. RAM <1 GB. No GPU value.

## 3. Investigation update at T115

- `tier_current`: 0 (post-T114) → if success at T115: 2.5 (closed-form Test passed at machine precision + 10-seed independence + 29-channel regression). Per protocol Tier-3 promotion gate: 2.5 is the cap unless central falsifier marked + CORROBORATE. F1 here IS marked `is_central=true` (per T114 directive). If CORROBORATE at 1e-13, judge.py may promote to 3.0 — but T114 set `if_success_tier_becomes: 1.5` (from Hypothesize → Test). T115 is the Test that closes 1.5 → 2.5 (or → 3.0 if the central falsifier promotion gate triggers).
- `stage_advancing_from`: `Hypothesize` (T114).
- `stage_advancing_to`: `Test`.
- On Test PASS: advance to `Generalize` stage (consider F=11 T:E_1 and F=12 multiplicity audit per theorist §5 generalization scope).
- On Test FAIL with REFUTED: rare scenario — would mean `bar_beta_0 ≠ 1/19` even with orbit-average. Routes to critic in question-validity mode (the closed-form Lemma 1 General-S would be in real trouble) → re-Hypothesize.
- On Test INCONCLUSIVE (e.g., between 1e-13 and 1e-6): tighten tolerance analysis, possibly switch to sympy exact-rational verification (T116+).

## 4. Edh-matsui sidebar (unchanged from T114)

`runs/_loop/seed.md` priority-0 pin on edh-matsui not retracted. Investigation remains in active set at tier 2.75 stage='Update'. F1 Stage-1 spatial verdict still PENDING anko-consult:

```
cd /home/suzume/workspace/BEC-simulation && bash runs/eu151_edh_K3_long/run_extract_ring_metrics.sh
```

The moment `runs/eu151_edh_K3_long/spatial_profiles.csv` appears on disk, the next director turn dispatches critic for spatial F1 re-audit (per T110 §6 routing). T115 does not block that — parallel-track operation continues. The F=9 T:A Test runs in ~3-5 minutes; if anko unblocks edh-matsui mid-window, T116 picks whichever investigation has a Tier-3-promotion-eligible falsifier ready.

## 5. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19",
  "stage_advancing_to": "Test",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "project_axis": "D3",
  "rationale": "T114 theorist Hypothesize PASS (judge 8/8 + precondition; runs/_loop/judge/turn_114.json). Theorist §6 implementer directive is concrete: extend scripts/manuscript/f9_f11_polyhedral_verification.jl with (a) find_invariant_basis(P, D) returning SVD-orthonormal basis of Im(P), (b) mult_aware_beta_S(rho_inv, F, S) computing Tr[Pi_S (rho_inv ⊗ rho_inv)] via CG sums, (c) verify_case_mult_aware driver. Run F=9 T:A; verify F1 |bar_beta_0 − 1/19| < 1e-13, F2 seed-independence 10-seed spread < 1e-13, F3 regression scripts/manuscript/lemma1_general_S_verification.jl 29/29 PASS. Scheduler JULIA_GPU_OK; CPU-light sufficient (D=19, dim-2 multiplicity, CG sums, 10 seeds). Per feedback_use_existing_artifacts_first: extend the existing script (clebsch_gordan + project_onto_irrep + group machinery already in place) rather than creating a parallel file. D3 axis: new derivation closing the only 2e-4 residual in Paper #3 §V verification table, generalizes to all F≥9 multiplicity-≥2 polyhedral inert states (per memory:universal_structure_u1u4_2026_05_13 the largest open hole in the universal structure theorem). Disk check this turn: edh-matsui spatial_profiles.csv STILL ABSENT, seed.md priority-0 STILL HELD verbatim — parallel-track operation continues per T114 authorization; F=9 T:A is the active D3 path, edh-matsui frozen-blocked at tier 2.75. Per feedback_cost_overhead_is_the_cost: dispatch is mechanical from T114 contract; minimal director deliberation. Sources: runs/_loop/judge/turn_114.json (T114 PASS); runs/_loop/theorist/turn_114.md §6 (executable implementer directive); runs/_loop/director/turn_114.md §6 (investigation_update routing); runs/_loop/state.json (active_investigation_id = sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19; cost_inflation 1.497 keep T115 modest); runs/_loop/_local/scheduler_115.json (JULIA_GPU_OK); docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md (2e-4 residual + multiplicity 2 confirmed); scripts/manuscript/f9_f11_polyhedral_verification.jl (existing infrastructure to extend, lines 159-192 projector + channel-S code); scripts/manuscript/lemma1_general_S_verification.jl (29-channel regression baseline); memory:universal_structure_u1u4_2026_05_13 (Paper #3 §V context, multiplicity-≥2 hole); memory:feedback_use_existing_artifacts_first (extend the existing script).",
  "brief": "You are implementer (julia_cpu_light, no GPU). Test stage for investigation `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`. Execute the T114 theorist §6 directive verbatim.\n\n## Read first (in order)\n\n1. `runs/_loop/theorist/turn_114.md` — focus on §2.4 (projector-orbit fix), §6 (implementer directive with exact algorithm), §3 (sanity checks for limit-case mult-1).\n2. `scripts/manuscript/f9_f11_polyhedral_verification.jl` — existing structure. You will EXTEND this file (do NOT create a parallel file per feedback_use_existing_artifacts_first). Note line 18 imports SpinorBEC, line 183 uses clebsch_gordan from SpinorBEC, lines 159-192 hold the existing projector / channel-S code, line 194 is the existing `verify_case` driver.\n3. `scripts/manuscript/lemma1_general_S_verification.jl` — the F3 regression target (29-channel mult-1 baseline; must still PASS after your changes).\n4. `docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md` lines 12-14 (the F=9 T:A row showing 2e-4 dev) and lines 100-112 (multiplicity-2 issue context).\n\n## Implementation directive\n\nIn `scripts/manuscript/f9_f11_polyhedral_verification.jl`, add three new functions (place them adjacent to their existing single-multiplicity counterparts):\n\n```julia\n\"\"\"\n    find_invariant_basis(P::Matrix, D::Int; tol::Real=1e-8) -> Vector{Vector{ComplexF64}}\n\nReturn an orthonormal basis of Im(P) via SVD. Length of returned vector equals\nthe numerical rank of P at tolerance `tol` (the irrep multiplicity m_rep).\nSeed-independent (SVD basis up to U(m_rep) ambiguity, which the orbit-average\nrho_inv = (1/m_rep) * sum_i |zeta_i><zeta_i| washes out by Schur's lemma on\nthe multiplicity space).\n\"\"\"\nfunction find_invariant_basis(P::AbstractMatrix, D::Int; tol::Real=1e-8)\n    U, S, V = svd(Matrix(P))\n    m_rep = count(s -> s > tol, S)\n    basis = [U[:, i] for i in 1:m_rep]\n    # Re-orthonormalize defensively (SVD U is already orthonormal but guard against\n    # numerical drift if P had repeated singular values near the cutoff).\n    for i in 1:m_rep\n        for j in 1:i-1\n            basis[i] -= (basis[j]' * basis[i]) * basis[j]\n        end\n        basis[i] /= norm(basis[i])\n    end\n    return basis, m_rep\nend\n\n\"\"\"\n    mult_aware_beta_S(rho_inv::Matrix, F::Int, S::Int) -> Float64\n\nCompute bar_beta_S = Tr[Pi_S (rho_inv tensor rho_inv)] where Pi_S = sum_M |S,M><S,M|\nin V_F tensor V_F. Strict generalization of `project_S_channel`: reduces to\nthe rank-1 formula when rho_inv = |zeta><zeta|.\n\"\"\"\nfunction mult_aware_beta_S(rho_inv::AbstractMatrix, F::Int, S::Int)\n    total = 0.0\n    # Index convention: i = F - m + 1 (matches project_S_channel in this file).\n    for M in -S:S\n        # Build the channel-S coupling amplitudes c(m1, m2) = <S,M | F m1, F m2>\n        # via Clebsch-Gordan, then compute |sum c rho rho|^2 in matrix form.\n        # Direct Einstein-sum form:\n        #   bar_beta_S += sum_{m1,m2,m1',m2'} conj(c(m1,m2)) * c(m1',m2') *\n        #                  rho_inv[idx(m1'),idx(m1)] * rho_inv[idx(m2'),idx(m2)]\n        D = 2F + 1\n        amp_matrix = zeros(ComplexF64, D, D)\n        for m1 in -F:F, m2 in -F:F\n            if m1 + m2 == M\n                cg = clebsch_gordan(F, m1, F, m2, S, M)\n                amp_matrix[F - m1 + 1, F - m2 + 1] = cg\n            end\n        end\n        # contribution at this M: tr( amp_matrix' * rho_inv * amp_matrix * conj(rho_inv) ) -- careful\n        # Actually the cleanest form: <S,M | (rho_inv tensor rho_inv) | S,M>\n        #   = sum_{m1,m2,m1',m2'} conj(amp(m1,m2)) * rho[idx m1, idx m1'] * rho[idx m2, idx m2'] * amp(m1',m2')\n        # which in matrix form is tr(amp_matrix' * rho_inv * amp_matrix * transpose(rho_inv)).\n        # Hermiticity of rho_inv makes transpose(rho_inv) = conj(rho_inv).\n        contrib = real(tr(amp_matrix' * rho_inv * amp_matrix * transpose(rho_inv)))\n        total += contrib\n    end\n    return total\nend\n\n\"\"\"\n    verify_case_mult_aware(F::Int, group::Symbol, irrep::Symbol; seeds::AbstractRange=1:10)\n\nDriver mirroring `verify_case` but using the projector-orbit-average density-matrix\nformulation. Records per-seed bar_beta_0 for the F2 seed-independence falsifier\n(seeds parameter ONLY affects defensive Gram-Schmidt re-orthonormalization in\nfind_invariant_basis — the orbit average rho_inv is provably seed-independent,\nso the 10-seed spread should be < 1e-13).\n\"\"\"\nfunction verify_case_mult_aware(F::Int, group::Symbol, irrep::Symbol; seeds::AbstractRange=1:10)\n    # mirror verify_case header for symmetry + group + projector construction;\n    # then call find_invariant_basis + build rho_inv + call mult_aware_beta_S for\n    # S in {0, 2, 4, ..., 2F};\n    # for each seed, randomize the SVD column phases (or re-do an internal Gram-Schmidt\n    # with a seeded random kick to confirm seed-independence at machine precision).\n    # Print: m_rep, bar_beta_0 per seed, max-spread, max |bar_beta_0 - 1/(2F+1)|, Schur isotropy of rho_inv (Tr(rho_inv F_a^2) for a = x,y,z).\nend\n```\n\nFill in the body of `verify_case_mult_aware` analogously to the existing `verify_case` (lines 194-243 of the existing script). Print at minimum:\n\n```\n──────────────────────────────────────────────────────────────────────\nF=9 T:A (mult-aware: projector-orbit average)\n──────────────────────────────────────────────────────────────────────\nm_rep (numerical multiplicity at tol=1e-8): 2\nbar_beta_0 (seed 1): <print 15 digits>\nbar_beta_0 (seed 2): <print 15 digits>\n... seeds 3..10 ...\nseed spread max-min: <should be < 1e-13>\n|bar_beta_0 - 1/19|: <should be < 1e-13>\nSchur isotropy of rho_inv: Tr(rho_inv F_x^2), Tr(rho_inv F_y^2), Tr(rho_inv F_z^2) (each should equal F(F+1)/3 = 90/3 = 30)\nbar_beta_S for S = 0, 2, 4, ..., 18: <full table>\nF1 verdict: CORROBORATE | INCONCLUSIVE | REFUTED\nF2 verdict: CORROBORATE | REFUTED\n```\n\nThen call `verify_case_mult_aware(9, :T, :A)` from the bottom of the script (add to whatever main block exists, or as a single direct call after `verify_case(9, :T, :A)` which generated the existing 2e-4 residual baseline so the comparison is clean).\n\nAt the very end of the run, also call the F3 regression:\n\n```julia\n# F3: strict-generalization regression — the 29-channel mult-1 closed-form must still PASS.\nprintln(\"\\n========== F3 REGRESSION: lemma1_general_S_verification.jl ==========\")\ninclude(joinpath(@__DIR__, \"lemma1_general_S_verification.jl\"))\n```\n\nIf `lemma1_general_S_verification.jl` is structured to run on include (it should be — Grep already confirmed it's a standalone regression script), this catches any inadvertent breakage.\n\n## Execution + observable output\n\nRun the extended script with:\n```\ncd /home/suzume/workspace/BEC-simulation && julia --project=. scripts/manuscript/f9_f11_polyhedral_verification.jl 2>&1 | tee runs/_loop/sim/turn_115_f9_TA_mult_aware.log\n```\n\nExpected wall: ~2-4 min (SpinorBEC precompile dominates; CG + SVD math is fast).\n\nAlso write a brief sim report to `runs/_loop/sim/turn_115.md` summarizing: m_rep value, bar_beta_0 seed-spread, |bar_beta_0 - 1/19|, the per-channel bar_beta_S table for F=9 T:A, F3 regression status (29-channel PASS/FAIL count), and the §4 Metrics JSON block required by judge.py.\n\n## Out of scope\n\n- DO NOT modify `lemma1_general_S_verification.jl` (it is the F3 regression baseline; touching it would invalidate the regression).\n- DO NOT touch any SpinorBEC source under `src/`. The fix is entirely in the script file.\n- DO NOT add a parallel `scripts/manuscript/f9_TA_mult2_schur_restore.jl` — extend the existing file (per feedback_use_existing_artifacts_first).\n- DO NOT run GPU. CPU is sufficient and 100× faster on this dim-19 problem (GPU launch overhead >> compute).\n- DO NOT pursue the §2.B Schur-isotropic-basis path in this turn unless the §2.A orbit-average fails F1 — §2.A is the canonical formulation per theorist §2.C recommendation. The §2.B path would be a theory cross-check for a future turn.\n",
  "observable_manifest": {
    "required": [
      "investigation_id",
      "stage_advancing_to",
      "subagent_type",
      "m_rep_value",
      "bar_beta_0_value",
      "bar_beta_0_dev_from_1_over_19",
      "seed_spread_max_min",
      "schur_isotropy_rho_inv_x",
      "schur_isotropy_rho_inv_y",
      "schur_isotropy_rho_inv_z",
      "regression_29_channels_passed_count",
      "regression_29_channels_total_count"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl && grep -q 'clebsch_gordan' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl && grep -q 'project_onto_irrep' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl && echo OK_T115_TEST_STAGE_PRECONDITIONS_HOLD"
  },
  "success_criteria": [
    {
      "id": "F1-central-bar-beta-0-recovers-1-over-19",
      "check_cmd": "grep -E -o 'bar_beta_0_dev[_ ]+from[_ ]+1[_/]19[ :=]+[0-9.eE+-]+' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115.md | head -1 | grep -oE '[0-9]+\\.?[0-9]*[eE]?[+-]?[0-9]*$' | awk '{ if ($1+0 < 1e-13) print \"PASS\"; else print \"FAIL\" }' | grep -q PASS",
      "expect": {"exit_code": 0}
    },
    {
      "id": "F2-advisory-seed-spread-tiny",
      "check_cmd": "grep -E -o 'seed_spread[_ ]+(max[_-]min)?[ :=]+[0-9.eE+-]+' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115.md | head -1 | grep -oE '[0-9]+\\.?[0-9]*[eE]?[+-]?[0-9]*$' | awk '{ if ($1+0 < 1e-10) print \"PASS\"; else print \"FAIL\" }' | grep -q PASS",
      "expect": {"exit_code": 0}
    },
    {
      "id": "F3-regression-29-channels-pass",
      "check_cmd": "grep -E '29[/ ]29 PASS|regression_29_channels_passed[_ ]+count[ :=]+29' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "m-rep-equals-2-for-F9-TA",
      "check_cmd": "grep -E 'm_rep[ :=]+2|m_rep_value[ :=]+2' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "sim-report-written",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_115.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "existing-script-extended-not-replaced",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl && grep -q 'find_invariant_basis\\|mult_aware_beta_S\\|verify_case_mult_aware' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "no-parallel-restore-script-created",
      "check_cmd": "test ! -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_TA_mult2_schur_restore.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "lemma1-general-S-baseline-untouched",
      "check_cmd": "test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl && git diff --quiet HEAD -- scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "seed-md-priority-0-edh-matsui-still-held",
      "check_cmd": "grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md",
      "expect": {"exit_code": 0}
    }
  ],
  "failure_modes": [
    {
      "if": "F1-central-bar-beta-0-recovers-1-over-19 FAILED (|bar_beta_0 - 1/19| >= 1e-13 but < 1e-6)",
      "category": "scientific_inconclusive",
      "next_action": "T116 dispatches implementer_sympy to redo the F=9 T:A computation with exact-rational Clebsch-Gordan coefficients and exact-rational SVD-replacement (Hermite normal form on the projector matrix). If exact-rational gives 1/19 exactly, the numerical 1e-13 floor is a clebsch_gordan / SVD numerical artifact, not a theory issue — promote to Tier 2.5 with the exact-rational result as load-bearing. If exact-rational also deviates, investigate the canonical-basis Schur-isotropic alternative §2.B; further theory work required (Hypothesize stage repeats)."
    },
    {
      "if": "F1-central-bar-beta-0-recovers-1-over-19 FAILED (|bar_beta_0 - 1/19| >= 1e-6, structural deviation)",
      "category": "scientific_refuted",
      "next_action": "T116 dispatches critic in question-validity mode: the projector-orbit-average hypothesis is wrong; Lemma 1 General-S has a structural gap at multiplicity-≥2 polyhedral inert states. Re-Hypothesize stage: either §2.B Schur-isotropic basis is the correct fix and §2.A is wrong, OR a more fundamental reformulation is needed. Tier reverts to 0.5. This is the genuinely-bad outcome but is the falsifier doing its job."
    },
    {
      "if": "F2-advisory-seed-spread-tiny FAILED but F1 passed",
      "category": "data_gap",
      "next_action": "T116 implementer_text audits the seed-handling code in verify_case_mult_aware — the orbit average rho_inv should be provably seed-independent by Schur's lemma on the multiplicity space, so a seed dependence indicates an implementation bug (e.g., the Gram-Schmidt failed to converge, or the SVD column-phase is leaking through). One-turn fix; F2 should retry to PASS at the same tolerance. Investigation stays at Test stage."
    },
    {
      "if": "F3-regression-29-channels-pass FAILED",
      "category": "framework_error",
      "next_action": "T116 implementer reverts the extension to `f9_f11_polyhedral_verification.jl` (the F3 baseline must not be broken by the multiplicity-aware code path; if any test in lemma1_general_S_verification.jl fails after include(), the strict-generalization property is violated). T116 critic dispatches to identify which channel broke — likely a subtle aliasing in `mult_aware_beta_S` (e.g., conjugation convention mismatch with `project_S_channel`). Fix + retry at T117."
    },
    {
      "if": "m-rep-equals-2-for-F9-TA FAILED (m_rep != 2)",
      "category": "data_gap",
      "next_action": "T116 implementer investigates the rank determination: tolerance too tight (m_rep < 2, missing the second basis vector) or too loose (m_rep > 2, spurious basis vectors). Adjust tol in find_invariant_basis from 1e-8 to a tighter band (e.g., 1e-10 to 1e-6 range; the right value lives between the smallest non-zero singular value and the largest near-zero one). If no tolerance choice gives m_rep=2, the projector construction itself is suspect — escalate to theorist re-Hypothesize."
    },
    {
      "if": "existing-script-extended-not-replaced FAILED (implementer created a parallel file)",
      "category": "feedback_use_existing_artifacts_first_violation",
      "next_action": "T116 director (with anko-flagged note) audits the parallel file vs the existing script — if the parallel file is a strict subset, fold into the existing script and delete the duplicate. patterns.yaml entry: feedback_use_existing_artifacts_first_violation_test_stage_2026_05_19. Light corrective dispatch (~100k tokens)."
    },
    {
      "if": "anko ran edh-matsui wrapper between T114 and T115 (spatial_profiles.csv appears mid-window)",
      "category": "scientific_progress_unblocked",
      "next_action": "T116 director (next turn after T115 completes) observes spatial_profiles.csv on disk, dispatches critic for edh-matsui spatial F1 re-audit per T110 §6 routing. The F=9 T:A Test stage completes at T115 independently; investigation remains in the active set with whatever T115 verdict landed. Two-track operation: D3 closure (F=9 T:A) + D1 promotion attempt (edh-matsui Tier-3 gate)."
    },
    {
      "if": "the harness denies julia execution (sandbox-vs-scheduler mismatch, recurrence of T108/T111 class)",
      "category": "framework_error",
      "next_action": "T115 should NOT trigger this — scheduler_115.json explicitly grants `implementer_julia_cpu_light` and the harness path for julia-script invocation is the one already-proven by the T29/T59/T94 closures. If it does, T116 escalates to anko: the sandbox-vs-scheduler-gate-mismatch-2026-05-19 pattern in runs/_loop/patterns.yaml needs a stronger fix than note-only. Pending that, T116 dispatches implementer_sympy as a fallback (re-implement the §6 algorithm in python; ~2x cost but unblocks the Test stage)."
    }
  ],
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 1400
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Generalize",
    "if_success_tier_becomes": 2.5,
    "if_partial_advance_to_stage": "Test",
    "if_partial_tier_becomes": 1.5,
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 0.5,
    "if_success_falsifier_update": {
      "id": "F1-multiplicity-aware-schur-restoration-recovers-machine-precision",
      "tested_at_turn": 115,
      "result_template": "CORROBORATE: bar_beta_0 = {value}, |bar_beta_0 - 1/19| = {dev} (< 1e-13); seed-spread = {spread}; F3 regression 29/29 PASS; m_rep = 2 confirmed at F=9 T:A."
    },
    "note": "T115 Test stage on the active investigation. Tier promotion 1.5 → 2.5 on F1 + F2 + F3 all CORROBORATE; tier stays 1.5 on F1 INCONCLUSIVE; tier 0.5 on F1 REFUTED at >1e-6 (structural). Per Tier-3 promotion gate: F1 is is_central=true; if CORROBORATE at 1e-13 the judge.py central-falsifier gate MAY clamp at 3.0 — but the T114 contract set if_success_tier_becomes=1.5 from Hypothesize, so the natural T115 ceiling is 2.5 (one-stage advance). Full Tier-3 (3.0) requires Generalize stage cross-validation (e.g., independent corroboration at F=11 T:E_1 or F=12 multiplicity audit per theorist §5 generalization scope), deferred to T116+. edh-matsui investigation UNCHANGED at tier 2.75 frozen-blocked (anko-consult pending); seed.md priority-0 still held; parallel-track operation continues."
  }
}
```

## 6. Drift advisories — explicit acknowledgement and trajectory

Per protocol §B6 step (drift signal handling):

- **DRIFT_COST_INFLATION** (1.497 at T114, the dominant signal): T114's 20.7M orchestrator tokens (theorist Hypothesize at the high end of expected — driven by long derivation + reading 5 source files in detail) pushed the rolling mean above 1.0. T115 budget ~1.8M effective for a julia-only Test stage is well under the 4M PROBE_DRIVEN soft cap. Wall time bounded at ~25 min (SpinorBEC precompile + 1-2 min compute). The cost mean recovers naturally as the Test stage cost is dominated by julia wall, not orchestrator token spend.
- **DRIFT_MANUSCRIPT_DELTA_ZERO** (pinned at 1.0 since T88): T115 is Test stage of a derivation closing a manuscript table residual. If F1 CORROBORATE, the natural T116 follow-up is implementer_text to UPDATE `docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md` row "F=9 T:A (mult 2)" from "0.0524 vs 0.0526 (dev 2e-4) mostly ✓ (multiplicity-2 mixing)" to "{new_value} vs 0.052631578... (dev <1e-13) ✓ (mult-aware orbit average)" + cross-link to `sign_pattern_lemma1_general_S.md` with a new §V.7 "multiplicity ≥ 2 extension" subsection. Drift signal clears naturally on that turn — NOT manuscript polish, this is propagating a new result to the manuscript table (per `feedback_manuscript_is_not_the_essence` the distinction is real D3 derivation closure vs polish; this is the former).
- **DRIFT_NOVEL_CLAIM_ZERO** (was 1.0 for 4 consecutive turns T110-T113, dropped to 0.0 at T114 with the theorist novel-claim queue): T115 Test stage executes the novel claim. Stays at 0.0 if F1 PASS (claim becomes Established).
- **DRIFT_SUBAGENT_REPETITION** (0.667 → 0.333 at T114): T115 implementer is a different class from T114 theorist. Streak continues to break.
- **DRIFT_TOPIC_REPETITION** (0.0 at T114 — new investigation): T115 continues on F=9 T:A. Single-turn continuation, not repetition.
- **DRIFT_VERDICT_DRIFT** (0.7 at T114): T115 Test produces a clean PASS/FAIL — verdict_drift drops materially.
- **DRIFT_ESCALATION** (`director_must_address` at T114): T115 implements the T114 directive. Escalation resolves to `none` on PASS, or routes via §5 failure_modes on FAIL.

## 7. Honesty cross-checks

I considered three alternatives before settling on implementer Test:

1. **NOOP again**: rejected. T114 PASS handed a clean, executable contract. The cheapest correct move is to execute it (per `feedback_cost_overhead_is_the_cost`). NOOP here would re-introduce drift_subagent_repetition + drift_novel_claim_zero ceiling.

2. **Critic first** (audit T114 theorist before Test): rejected. T114 already passed judge 8/8 + precondition + sanity-check section. A critic would re-derive what the theorist already documented (no new info). Adding a critic step doubles the path-to-verdict cost. The CORRECT critic step is AFTER Test: if T115 produces unexpected numerics (F1 INCONCLUSIVE), then critic audits the §2.A formula and the implementation in parallel; that's failure_modes branch (a).

3. **Implementer_sympy instead of julia**: rejected per §2 above. Theorist §6 listed sympy as "Optional ... not required". The numerical julia path at 1e-13 tolerance is sufficient to gate F1 CORROBORATE; sympy would require ~2-3× the work to re-port the existing julia infrastructure. Promoting sympy to T115 default would be over-engineering for the Test stage.

The dispatch is mechanical, low-risk, and lifts the T114 contract verbatim with minimal director-side editorialization. Cost-discipline: ~1.8M effective vs ~3-5M if I added critic-first or sympy alternative paths.

## 8. What T116 director should look at first

In order:

1. `Read runs/_loop/sim/turn_115.md` + `runs/_loop/judge/turn_115.json` — verdict on F1/F2/F3. Routes per §5 failure_modes.
2. `Glob runs/eu151_edh_K3_long/spatial_profiles.csv` — if present, anko unblocked edh-matsui; dispatch critic for spatial F1 re-audit per T110 §6 (parallel-track continues with whatever T115 result landed).
3. `cat runs/_loop/seed.md` — if anko updated the pin (retracted / redirected / authorized 2-track explicitly), follow the new pin.
4. If T115 F1 CORROBORATE (clean PASS): T116 advances F=9 T:A to **Generalize** stage. Two natural next moves: (a) implementer_text propagates the result to `docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md` (Documents flow, light cost ~300k); (b) theorist follow-up on F=11 T:E_1 (mult 2, deferred per script header line 13) — would require resolving the complex 1-dim irrep → 2-dim real construction first, possibly a researcher_shallow task. (a) is the cheaper next step and clears DRIFT_MANUSCRIPT_DELTA_ZERO naturally; (b) is the Tier-3 path but requires more infrastructure.
5. If T115 F1 INCONCLUSIVE: per §5 failure_modes (a), T116 dispatches implementer_sympy for exact-rational re-verification. ~2M expected.
6. If T115 F1 REFUTED: per §5 failure_modes (b), T116 dispatches critic in question-validity mode. The closed-form Lemma 1 General-S would have a real gap at multiplicity-≥2; re-Hypothesize via theorist with revised approach. ~2.5M.

## 9. Closing

T115 advances `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` from Hypothesize → Test. Mechanical dispatch of the T114 theorist §6 implementer directive; extend existing `scripts/manuscript/f9_f11_polyhedral_verification.jl` (per `feedback_use_existing_artifacts_first`); F1 + F2 + F3 falsifier ladder; expected wall ~25 min; expected effective cost ~1.8M. edh-matsui parallel-track UNCHANGED: spatial_profiles.csv still absent, seed.md priority-0 still held, investigation frozen at tier 2.75; the moment anko runs the wrapper, the next director turn dispatches critic for spatial F1 re-audit independently of T115's outcome. Drift trajectory: subagent_repetition continues to fall (theorist→implementer break); novel_claim_zero stays at 0.0; cost_inflation rolls down via the budget-bounded Test stage; verdict_drift drops on clean PASS/FAIL. T116 routes on T115 sim/judge output + disk state + seed.md.
