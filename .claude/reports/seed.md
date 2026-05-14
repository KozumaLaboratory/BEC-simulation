# Loop seed — Turn 1 (Phase 2 sanity)

## Context

Turn 0 closed the FG sign question (α₂ = -1/48, α₃ = -1/72, both
forms reconciled, regression test pinned). Turn 0 §5 Open Questions
left three threads:

- Q1: exact CK 2005 placement convention (low priority — sign
  result is independent of magnitude derivation route)
- Q2: nonlinear GPE case where V = V₀ + g|ψ|² depends on ψ
  itself — does the BCH argument transfer cleanly?
- Q3: v4 spinor extension — does α₃ = -1/72 survive when V is
  matrix-valued (V_SM = c₁·m·F)? §2.3's BCH algebra is
  dimension-blind so the answer is **plausibly yes, no change**.

## Turn 1 task

Address Q3. The §2.3 argument relied only on commutator algebra
that doesn't reference whether [V,T] components are scalars or
matrices. Confirm by either:

- Symmetry argument: explicitly check that the BCH expansion
  coefficients (-1/24, +1/12) are basis-independent on the spinor
  index. They should be — they come from the structure of the
  symmetric Strang factorisation, not from V's specific form.
- Spot-check: read `src/hamiltonian/integrator/force_gradient.jl`
  and the v4 prototype path to see whether the existing α₃ = -1/72
  is referenced or re-derived for spinor V.

Expected directive: either `analyze_existing` (no new code, just a
note) or `modify_code` (add a docstring/comment locking in the
α₃ = -1/72 invariance under spinor extension). Time budget ≤ 5 min
implementer wall-clock. No `run_experiment` this turn.

## Phase 2 sanity context

This is the first turn after the pass-3 audit lands. The new infra
to exercise:

- `Tier-1 A` state.json flock (Step 6a)
- `Tier-1 B` judge.py crash handling (try/except)
- `Tier-1 D` per-turn timeout (loop.sh `timeout 1200`)
- `Tier-1 E` <RESEARCH_NEEDED> regex narrow (extract_research_queries.py)
- `Tier-2 G` tokens_used patching (extract_turn_tokens.py post-step)
- `Tier-2 H` agent .md hash capture (Step 0d)
- `Tier-2 K` force_critic seed flag — NOT used this turn (no flag below)
- `Tier-4 R` directive.action enum validation (Step 3b)

A noop directive is acceptable if you genuinely have nothing to say.
This is sanity, not science.

## Stop conditions

- Judge PASS → state advances to turn 2, ready for Phase 2 sustained.
- Judge FAIL_* or REJECTED → halt + review.
- judge_status NOOP → also acceptable; advance to turn 2.

(No `force_critic: true` flag this turn — let the standard PASS
path run cleanly.)
