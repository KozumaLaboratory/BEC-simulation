# Loop seed — Turn 2 (Phase 2 sanity, diversity check)

## Context

Turn 0 (FG sign) and Turn 1 (representation invariance under spinor
extension) both PASSed via free-Lie-algebra BCH argument. Turn 0 §5
left three open threads:

- Q1: exact CK 2005 magnitude derivation route — closed in turn 1 §2.1
  via explicit BCH on (1/6, 2/3, 1/6; 1/2, 1/2) weights.
- Q2: **nonlinear GPE case** — V = V₀(r) + g|ψ|² depends on ψ itself.
- Q3: v4 spinor extension — closed in turn 1.

## Turn 2 task

Address Q2. Non-trivial because:

The turn 1 §2.2 free-Lie-algebra argument relied on V entering BCH
as an *opaque symbol* in `Lie(T, V)`. For nonlinear V = V₀(r) + g|ψ|²,
this assumption needs scrutiny:

- During an infinitesimal step dt, V evolves as ψ does — V is not
  constant in the BCH bookkeeping.
- The double commutator [V,[T,V]] involves ∇|ψ|² ~ ∇ψ⋆∇ψ + c.c.
- BCH typically assumes constants; nonlinear V brings ∂_tV terms.

Possible outcomes (decide which):
1. **Coefficient survives unchanged**: α₂ = -1/48 still cancels the
   leading [V,[T,V]] residual. Order stays 4. The ψ-dependence of V
   contributes only at O(dt⁴) or higher (within the existing
   residual envelope).
2. **Coefficient modified**: α₂ shifts by something like
   g·⟨ψ|...|ψ⟩ / something. New explicit correction term required.
3. **Order degrades**: BCH cancellation fails; net order drops
   from 4 to 3 for nonlinear V. (This would be a real problem for
   GPE applications.)

Anchor argument: at any fixed ψ snapshot, V is a fixed operator and
the turn-1 argument applies. The question is whether the rate of V's
change during one dt step introduces O(dt^k) terms for k ≤ 3 that
disrupt the cancellation.

Useful approach: write
$V(t) = V_0 + V_1(t)$ with $V_1 = g|\psi(t)|^2$, expand
$\partial_t V_1 = g \partial_t |\psi|^2 \sim g\,\nabla\cdot j$
(continuity); plug into the BCH "extended for time-dependent
operators" (e.g. Magnus expansion); check what order the new terms
enter.

Reference: CK 2005 §IV explicitly addresses the GP case; Chin 1997
PRE 55 6841 also has the nonlinear treatment. If unavailable in
WebFetch, `<RESEARCH_NEEDED>` is appropriate.

## Phase 2 sanity continuation

Turn 2 of the post-restructure sanity sequence. Expected directive:
`analyze_existing` or `modify_code` (no new experiments — the bench
isn't well-suited for isolating the nonlinear correction in this
regime). 

`force_critic: false` — standard PASS path.

## Stop conditions

- Judge PASS → state advances to turn 3, ready for sustained Phase 2.
- Judge FAIL_PHYSICS or SUSPICIOUS_NOVEL → halt + anko review.
- noop is acceptable if theorist concludes the question cannot be
  settled in 1 turn without simulation or extensive literature work.
- `<RESEARCH_NEEDED>` emission is encouraged if CK 1997 / 2005 are
  the load-bearing references — researcher dispatch is in scope.
