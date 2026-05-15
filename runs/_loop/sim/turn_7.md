# Turn 7 — Implementer Report

## 1. Directive received

```json
{
  "action": "modify_code",
  "rationale": "Replace existing F=6 polar @warn at dispatch.jl:115-128 with a docstring-level method-note that records the corrected mechanism (mechanism (i)+(iii) per turn 7 §2.2, NOT T5's rejected Nambu-doubling claim) and points to a future post-sweep F-δ implementation. This turn produces NO functional code change (no julia execution required, per seed.md light-mode constraint) — purely a docstring/comment edit that lands the corrected mechanism narrative into the source as audit-trail for the post-sweep julia-implementer turn. POST-SWEEP follow-up directive (T8+) will implement the F-δ signature test and add a julia regression test.",
  "target_files": [
    "src/hamiltonian/interactions/lhy/dispatch.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "dispatch.jl:115-128 @warn block is supplemented (NOT replaced) with a 5-10 line comment block titled '## Mechanism (turn 7 audit)' that states: (1) the BdG matrix is bosonic-pseudo-Hermitian under η = diag(I_D, -I_D); (2) imaginary physical Bogoliubov pairs appear as orbit-I (±iΩ) Nambu eigenvalues, NOT as real positive partners (refuting the natural-but-wrong picture); (3) the 3000× offset comes from LAPACK condition-number noise on those imaginary eigenvalues passing the `real(ev) > 1e-10` filter at high k, combined with miscalibrated mu_b on zero-symplectic-norm eigenvectors; (4) the correct fix (F-δ, deferred post-sweep) is a signature test on the Hermitian stability matrix H_S = η H_bdg. Citation chain (Castin-Dum 1998, Colpa 1978, Blaizot-Ripka 1986, Lieu 2018) cited in the comment. No code semantics change — purely doc.",
  "falsification_criterion": "If the post-sweep follow-up (T8+) running F-δ on F=6 polar Eu151 finds that the signature (N_+, N_-) of H_S is balanced (D, D) modulo Goldstones — i.e., NO imaginary modes — then turn 7's mechanism diagnosis is wrong and the 3000× offset has a different origin. Empirical refutation: if signature test gates trigger on F=6 polar but the LHY value remains 3000× wrong even after auto-redirect to PolarContactLHY, then the comment narrative is incomplete (additional mechanism present).",
  "estimated_cost": "≤ 5 min implementer wall-clock; ≤ 0.5M effective tokens. Purely text edit. No julia execution required.",
  "compute_steps": [
    {
      "id": "S1",
      "task": "Symbolically verify (λ, -λ*) pairing of H_bdg at D=2 with random Hermitian L and symmetric M",
      "sympy_expr": "...",
      "expected_form": "4x4 zero matrix (verifying Eq. 1 of §2.1)",
      "verify_against": "turn_7.md §2.1 Eq. 1"
    },
    {
      "id": "S2",
      "task": "Verify orbit classification (R / I / Q / Z) at D=1 toy model: L = a (real), M = b (real); eigenvalues = ±sqrt(a^2 - b^2)",
      "sympy_expr": "...",
      "expected_form": "lambda = ±sqrt(a^2 - b^2); orbit-R at a=2,b=1; orbit-I at a=1,b=2 (imaginary ±i*sqrt(3)); orbit-Z at a=1,b=1",
      "verify_against": "turn_7.md §3 Check 5"
    }
  ]
}
```

## 2. Branch / commit

- Branch: `auto/turn_7_fullbdg-F6-mechanism-note`
- Parent: `2e00d1cd2c5c515e0f7f9566055624fa1a31f973` (main HEAD at dispatch)
- Commits: [`6f92776`]
- Files changed:
  - `src/hamiltonian/interactions/lhy/dispatch.jl` (+18 lines, comment block only)
  - `runs/auto/turn_7_fullbdg-F6-mechanism-note/sympy_s1.py` (new)
  - `runs/auto/turn_7_fullbdg-F6-mechanism-note/sympy_s2.py` (new)

## 3. Commands executed

```
$ git checkout -b auto/turn_7_fullbdg-F6-mechanism-note
# (branched from main HEAD 2e00d1c)

$ uv run --with sympy python3 runs/auto/turn_7_fullbdg-F6-mechanism-note/sympy_s1.py
eta H_bdg eta - H_bdg^dagger =
Matrix([[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])

$ uv run --with sympy python3 runs/auto/turn_7_fullbdg-F6-mechanism-note/sympy_s2.py
Eigenvalues of D=1 H_bdg with L=a, M=b:
  lambda = -sqrt((a - b)*(a + b))  (mult 1)
  lambda = sqrt((a - b)*(a + b))  (mult 1)
  a=2, b=1: eigenvalues = [(-1.7320508075688772+0j), (1.7320508075688772+0j)]  (expected orbit-R)
  a=1, b=2: eigenvalues = [-1.7320508075688772j, 1.7320508075688772j]  (expected orbit-I)
  a=1, b=1: eigenvalues = [0j, 0j]  (expected orbit-Z)

# Edit applied: 18-line "## Mechanism (turn 7 audit)" comment block inserted
# at dispatch.jl before existing NOT-GENERALIZABLE comment, @warn preserved intact.

$ git commit --only src/hamiltonian/interactions/lhy/dispatch.jl \
    runs/auto/turn_7_fullbdg-F6-mechanism-note/ \
    -m "docs(lhy): add turn-7 mechanism audit note to FullBdG F=6 polar warn block"
[auto/turn_7_fullbdg-F6-mechanism-note 6f92776] docs(lhy): add turn-7 mechanism audit ...
 3 files changed, 43 insertions(+)
```

NOTE: `falsification_criterion` requires a post-sweep julia run (F-δ signature test on F=6 polar Eu151). Deferred to T8+ julia turn per seed.md light-mode constraint and directive text. No julia execution was required or performed this turn.

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
  "wall_time_sec": 180.0,
  "peak_memory_gb": null,
  "tests_passed": null,
  "n_lines_added": 18,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "total": null
  },
  "warnings": [],
  "physical_red_flags": [],
  "falsification_result": "INCONCLUSIVE",
  "compute_results": [
    {
      "id": "S1",
      "task": "Symbolically verify η H_bdg η = H_bdg† at D=2 with Hermitian L, symmetric M",
      "status": "OK",
      "result": "Matrix([[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])",
      "error": null
    },
    {
      "id": "S2",
      "task": "Verify orbit-R/I/Z classification at D=1 toy model",
      "status": "OK",
      "result": "Eigenvalues: ±sqrt((a-b)(a+b)). orbit-R (a=2,b=1): ±1.732+0j. orbit-I (a=1,b=2): ±1.732j. orbit-Z (a=1,b=1): 0j (defective EP). Confirms turn_7.md §3 Check 5.",
      "error": null
    }
  ]
}
```

## 5. Observations

Both sympy steps confirm the theoretical claims exactly:

- S1: η H_bdg η − H_bdg† = 0 for D=2 with symbolic Hermitian L and symmetric M. This is Eq. 1 of turn_7.md §2.1. The D=2 case exercises the full block algebra (off-diagonal blocks M and M* are both present and independent), so the zero-matrix result is nontrivial.

- S2: orbit-I eigenvalues at (a=1, b=2) are `±1.732j` — purely imaginary, NOT real positive. This is the key result that falsifies T5's claim that "imaginary physical Bogoliubov pairs become large positive-real Nambu eigenvalues." The sympy result shows exactly what the theorist derived in §2.1: orbit-I pairs stay imaginary under the Nambu doubling.

The orbit-Z case (a=1, b=1) gives eigenvalue `0j` with multiplicity 2, consistent with an exceptional point (defective EP). This matches the theorist's §3 Check 5 commentary about the Krein collision.

The comment block as inserted follows all four directive requirements:
1. States bosonic-pseudo-Hermitian identity η H_bdg η = H_bdg†
2. States orbit-I pairs are ±iΩ, not large positive reals (refuting T5)
3. Describes mechanism (i)+(iii): LAPACK noise + zero-symplectic-norm c* ill-definition
4. Points to F-δ fix (deferred post-sweep) via signature test on H_S = η H_bdg

The existing `@warn` block at lines 133-145 (post-edit numbering) is fully preserved unchanged. No code semantics were modified.

## 6. Issues / deviations

- `[WARN]` `run.log` was gitignored (`*.log` pattern in `.gitignore`). The run log content is captured in this report instead.
- `[WARN]` GPG commit signing via 1Password (`op-ssh-sign-wsl.exe`) failed on first attempt with "failed to fill whole buffer". Retry with same command succeeded on second invocation (1Password SSH agent responded). Commit sha `6f92776` is signed (pre-commit hook ran and passed gitleaks scan: 0 leaks found).
- No julia execution performed. No `tests_passed` field applies (no test invocation per directive; `null` is correct per Section D definition for `modify_code` with no test invocation).

## 7. Falsification check

The directive's `falsification_criterion` requires a post-sweep julia run: specifically, running the F-δ signature test (`eigen(Hermitian(η H_bdg))`, counting N₊/N₋) on F=6 polar Eu151 and checking whether signature is (D,D) (would refute T7 mechanism) or unbalanced (would confirm it). This cannot be evaluated this turn because:
1. No julia execution is permitted under seed.md light-mode constraint.
2. F-δ is not yet implemented in the codebase (it is the deferred post-sweep fix).

Falsification result: **INCONCLUSIVE** — the criterion is well-formed and testable, but requires T8+ julia execution to resolve.

The sympy results are *consistent with* the mechanism narrative (orbit-I eigenvalues remain imaginary), but they test the mathematical identity rather than the empirical claim about F=6 polar Eu151.
