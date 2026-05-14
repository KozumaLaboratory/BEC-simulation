# Loop seed — Turn 3 (Phase 2 sanity, compute_sympy infrastructure verification)

## Context

T0/T1/T2 closed the FG (Force-Gradient) sign / spinor-invariance /
nonlinear-V branches of the Chin–Krotscheck 2005 4A correction work.
The infrastructure for sympy-backed rational arithmetic
(`compute_sympy` action, `compute_steps[]` directive field,
`runs/_loop/sim/turn_N.md` §4 `compute_results[]`) was added 2026-05-15
but never exercised in a real turn.

This turn's purpose: **exercise the compute_sympy path end-to-end on
a trivial-but-load-bearing arithmetic** that will exit the loop with
high probability and validate (i) the directive schema accepts
`compute_steps`, (ii) the implementer's `run_sympy.py` invocation
works under `uv run --with sympy python3` ephemeral install, (iii) the
results appear in sim §4 `compute_results[]`, and (iv) judge.py
accepts the result.

## Turn 3 task

The FG sign work pinned in T0 (commit `c589f8f`, test
`test_force_gradient_wick_sign.jl`) and the spinor-invariance
docstring pinned in T1 (commit `28966b2`, force_gradient.jl lines
41-54) rest on **three arithmetic invariants** that, if violated,
break the whole derivation:

(I1) Wick rotation: $(i \cdot dt)^2 = -dt^2$.
     Equivalently: $i^2 = -1$.

(I2) Chin 4A slot weight relation: $(2/3) \cdot (1/48) = 1/72$.
     This bridges the production code's $\alpha_2 = -1/48$
     coefficient (on $\tilde V$) to the bench's $\alpha_3 = -1/72$
     coefficient (on the FG exponent gate).

(I3) Symmetric palindromic Strang sum: $2 \cdot (1/6) + 2/3 = 1$.
     I.e. the outer V-slot weights $a_o = 1/6$ at each end plus the
     middle V-slot weight $a_m = 2/3$ exactly partition unity.

You MUST use sympy via the new `compute_sympy` infrastructure to
verify each of I1, I2, I3 as a `compute_steps[]` entry. (These are
trivial sympy exercises — the point is to exercise the path, not to
discover anything new. The "discovery" is the schema's first
successful use.)

In §2 of your report, walk through *why* each invariant is necessary
for the FG sign result:

- I1 is the Wick rotation sign flip — without it, real-time α stays
  positive and the FG correction acts in the wrong direction.
- I2 is the bridging identity — without it, the bench's empirical
  $-1/72$ and production's $-1/48$ would look unrelated and the
  representation-invariance proof from T1 §2.3 would lack its
  factorization step.
- I3 is what makes the 5-stage Chin 4A composition a normalized
  partition of dt — without it, the BCH expansion in T1 §2.1 has the
  wrong leading-order $-i\,dt\,(T+V)$ term and the entire residual
  count is off.

In §0 declare your convention (Wick direction, slot weight notation,
sign of $\beta_C$).

In §8 (Publishability), the right answer is `Out of scope —
infrastructure-verification turn.` This is not a publishable physics
finding; it's an architecture sanity test.

## Expected directive

A SINGLE `modify_code` directive with `compute_steps[]` populated (3
entries). The implementer:
1. Runs each sympy step via `run_sympy.py` → captures results into
   sim §4 `compute_results[]`.
2. Adds a 3-line "verified arithmetic invariants" docstring block to
   `src/hamiltonian/integrator/force_gradient.jl` (above the existing
   line 41 invariance note from T1), each line citing the verified
   identity:
   ```
   # Verified arithmetic invariants (turn_3 compute_sympy):
   #   I1: (i*dt)^2 = -dt^2  ← Wick rotation sign flip
   #   I2: (2/3)*(1/48) = 1/72  ← α_2 ↔ α_3 bridging identity
   #   I3: 2*(1/6) + 2/3 = 1  ← Chin 4A weight partition of unity
   ```
3. Runs the existing regression test `test_force_gradient_wick_sign.jl`
   (must still 18/18 PASS — the new docstring doesn't touch line 267).
4. `tests_passed: true` in §4 metrics, all 3 compute_results status:
   "OK".

## Stop conditions

- All 3 sympy steps OK + tests pass + judge PASS → state advances to
  turn 4, infrastructure validated, future turns can use compute_sympy
  for non-trivial rational coefficient derivations (e.g. F=6 I_h LHY
  closed form per the user's exemplar Round 2 deliverable).
- Any sympy step FAILED/TIMEOUT → investigate `run_sympy.py` or
  `uv run --with sympy` setup. Halt + diagnose.
- Test regression → revert immediately; the docstring change must be
  truly cosmetic.

`force_critic: false` — trivial arithmetic doesn't need critic review.

## Why this is a good first compute_sympy turn

- Result is **mathematically certain** (1/2 + 1/2 = 1 level): no
  physics uncertainty obscures whether the infra works.
- Result is **mechanically simple**: 3 one-line sympy expressions
  (e.g. `from sympy import *; print(Rational(2,3) * Rational(1,48))`).
- Result has **realistic physical context**: ties to existing FG work,
  not pure dummy math.
- Result is **falsifiable trivially**: each fact has a known answer,
  any deviation = infrastructure bug.
- Cost is **bounded**: 3 sympy calls × ~5 sec each = ~15 sec
  compute overhead, total turn ≤ same as T1/T2 (~12 min wall).
