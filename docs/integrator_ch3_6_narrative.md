# §3.6 Modified splitting derivation for spinor + DDI — narrative draft

**Status**: draft, 2026-05-11. To be folded into Ch.3 main text.
**Track B closure**. See `docs/integrator_ch3_plan.md` for overall Ch.3.

## §3.6.1 Motivation (Thalhammer & Thalhammer-Thurner 2026)

Thalhammer's 2026 paper (arXiv:2601.19838) introduces a "modified
operator splitting" framework that generalises the force-gradient
construction of Chin (1997) and Chin-Krotscheck (2005) via the formal
calculus of Lie-derivatives. The framework presents a 4th-order
method for systems of coupled Gross-Pitaevskii equations
(multi-species BECs, J ≥ 2) with two key advantages:

1. **All-positive coefficients** in the principal splitting:
   `(a, b) = ((0, 1/2, 1/2), (1/6, 2/3, 1/6))`. The $\tau^2$-scaled
   gradient correction $c\tau^2 G$ with `c = (0, -1/72, 0)` is
   secondary and does not violate the positive-coefficient property.
2. **Lie-derivative formalism** unifies the historical force-gradient
   construction with general nonlinear-system theory.

The paper provides explicit forms of the iterated commutator
$G = [DF_2, [DF_2, DF_1]]$ for the J=2 contact case (eq 19-20), giving
a concrete recipe for two-species BECs.

## §3.6.2 Phase -1 verification: Thalhammer J=1 ≡ Chin-Krotscheck 4A

The first Phase -1 result is that Thalhammer's J=1 reduction matches
Chin-Krotscheck 2005's algorithm 4A exactly.

### Explicit computation

With Chin-style split ($F_1 = T$ kinetic, $F_2 = V_{\text{total}}$
combined linear and nonlinear potential), the operators are:
- $F_1' = (i/2)\Delta$, $F_1'' = 0$
- $F_2'(v)\cdot w = -i V w$, $F_2'' = 0$ (for ϑ=0 linear case)

Substituting into Thalhammer eq 18c:

$$G(v) = -i|\nabla V|^2 \cdot v \quad \text{(J=1, linear case ϑ=0)}$$

(Algebra in `docs/integrator_track_b_derivation.md` Step 1.1.)

Compare to paper eq 20 (J=1, ϑ=0):
$$G(\Psi) = 2i \nabla_\alpha V \cdot \nabla V \cdot \Psi = 2i \cdot (-\tfrac{1}{2})|\nabla V|^2 \cdot \Psi = -i|\nabla V|^2 \cdot \Psi$$

(With $\alpha = -1/2$ as in Schrödinger convention.) **Matches.**

### Stage 4 phase comparison

At stage 4 (`b₂=2/3, c₂=-1/72`), the modified subproblem
$\partial_t u = b_2 F_2(u) + c_2\tau^2 G(u)$ gives:
$$u(\tau) = e^{-i(2\tau/3)V} \cdot e^{+i(\tau^3/72)|\nabla V|^2} \cdot u(0)$$

Chin-Krotscheck 4A stage 4 with $\tilde V = V - (\tau^2/48)|\nabla V|^2$
(real-time sign):
$$u(\tau) = e^{-i(2\tau/3)\tilde V} \cdot u(0) = e^{-i(2\tau/3)V} \cdot e^{+i(\tau^3/72)|\nabla V|^2} \cdot u(0)$$

**Identical phase contribution at all orders of $\tau$.** The two
methods are formally equivalent for J=1 scalar GPE.

### Implementation consequence

`split_step_thalhammer!` is exported as an alias for
`split_step_forcegrad!`. Bit-exact equivalence verified by
`scripts/bench/forcegrad_thalhammer_equiv.jl` (Track C v3.1
implementation IS Track B for our use case).

## §3.6.3 Spinor matrix extension — Track C v4 §5.2 result confirmed

For F-matrix coupling (c₁ ≠ 0 spin-mixing), the Lie-derivative
formalism of Thalhammer (eq 18c) produces the SAME mathematical
content as the Chin-style derivation in Track C v4 §5.2:

$$[V_{SM}, [T, V_{SM}]] = c_1^2 \left[ -\tfrac{i}{2}F_\rho (\mathbf{m}\times\nabla^2\mathbf{m})_\rho - i F_\rho (\mathbf{m}\times\nabla\mathbf{m})_\rho \cdot \nabla - \tfrac{1}{2}\{F_\mu, F_\nu\}(\nabla m_\mu)\cdot(\nabla m_\nu) \right]$$

The matrix-valued $F_2 = c_1 \langle\hat{F}\rangle \cdot \hat{F}$ makes
$F_2''$ non-trivial in Thalhammer's eq 18c, producing the same
$\nabla\psi$ derivative term identified in Track C. The two formalisms
**converge at the algebraic content** for our F-matrix problem class.

This is a unification: the Chin-Krotscheck force-gradient and
Thalhammer Lie-derivative pictures describe the **same family of 4th-order
modified splitting methods**, with different notational frameworks. For
scalar GPE the equivalence is bit-exact at the algorithm level; for
spinor + DDI the equivalence is at the derivation-content level.

## §3.6.4 DDI extension — Track C v5 §5.3 result confirmed

For nonlocal DDI: $V_{DD}(r) = c_{dd} \sum_\mu \hat{F}_\mu \cdot (U_{dd,\mu\nu} \ast \langle\hat{F}_\nu\rangle)(r)$,
the Aichinger-Chin-Krotscheck 2005 framework treats the nonlocal scalar
case. Thalhammer's Lie-derivative formalism extends generically to
non-local operators via appropriate Fréchet derivatives — same
algebraic content as Track C v5 §5.3.

For our F=6 + DDI use case, the combined matrix + nonlocal extension
gives ~10-15 cross-term commutator terms. Implementation deferred (= Track C v5+).

## §3.6.5 Track B novelty for SpinorBEC

For our SpinorBEC framework specifically, Track B's novelty over
Track C is **two-fold**:

1. **Formal unification**: explicit proof Chin-Krotscheck = Thalhammer
   for J=1, connecting historical force-gradient literature to modern
   Lie-derivative framework.
2. **J=2+ multi-species path**: Thalhammer eq 19-20 give explicit G
   for two-species BECs with cross-channel $\vartheta_{jk}$. Our
   SpinorBEC framework is single-species F-matrix; this path is
   out-of-scope but would apply to a future binary BEC extension
   (87Rb-23Na, 87Rb-39K, ...).

Track B does NOT provide a new high-order scheme beyond Track C for
our specific use case. The "$\tau^2 G$ correction" is the same
mathematical object as the "[V,[T,V]] = |∇V|² correction" of Chin —
just packaged in the Lie-derivative formalism.

## §3.6.6 Track B closure + thesis contribution

Track B deliverables:
- ✓ Paper transcribed: arXiv:2601.19838v1 §3-4 verbatim (eq 11, 18a-c,
  19, 20, 22)
- ✓ J=1 reduction verified: Thalhammer eq 22 ≡ Chin-Krotscheck 4A
  (Step 1.1-1.3 in `docs/integrator_track_b_derivation.md`)
- ✓ Implementation: `split_step_thalhammer!` alias + bit-exact
  equivalence verification bench
- ✓ Spinor + DDI extension (= Track C v4/v5) confirmed to give same
  result in both formalisms
- ✗ Multi-species J=2+ cross-channel: out-of-scope for SpinorBEC

**Thesis-level contributions** (§3.6 + §3.5 combined):

1. **Explicit equivalence proof Chin-Krotscheck 2005 ↔ Thalhammer 2026**
   for J=1 GPE. Connects two formal frameworks (classical force-gradient
   vs Lie-derivative iterated commutator) at the algorithm level.
2. **Novel ∇ψ derivative term in $[V_{SM}, [T, V_{SM}]]$** for spinor
   matrix V (= Track C §5.2). This term emerges identically in both
   formalisms and is not present in any published scalar GPE
   force-gradient work.
3. **Cross-formalism characterisation** of the modified splitting
   framework on the lab path: Y4-midpoint (Track A1) wins
   cost-per-accuracy and energy drift; modified splitting + spinor +
   DDI derivation is the additional contribution.

## §3.6.7 Modified Ch.3 outline (final)

- §3.1 Failure mode of frozen-MF Strang
- §3.2 Symmetric Strang via midpoint predictor-corrector
- §3.3 Fragility of Richardson-cancellation under non-uniform MF
  (MPS + AVF state-averaging joint section)
- §3.4 Yoshida composition hierarchy (Y4-mid, Y6-mid)
- §3.5 **Force-gradient extension to spinor + DDI** (Track C, novel
  ∇ψ term)
- §3.6 **Modified splitting framework unification** (Track B,
  Chin = Thalhammer for J=1 + Lie-derivative reformulation)
- §3.7 State-averaging fails generically across frameworks
  (= §3.3.2 expanded)
- §3.8 Comparison & recommendations (Y4-mid as practical optimum)

60-80 pages total. Track C + Track B together provide the
"derivation + comparison" thesis-level contribution for the modified
splitting framework on the lab path.
