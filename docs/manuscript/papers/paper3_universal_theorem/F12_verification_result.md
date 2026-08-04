# F=12 icosahedral Universal Theorem verification — partial result

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Date**: 2026-05-11
**Script**: `test/manuscript/test_f12_icosahedral.jl`
**Status**: spinor construction + structural sanity checks COMPLETE; per-channel
β_S^{λ_spin} sign extraction deferred to sympy closed-form derivation.

## Background

paper3 v3 §IX.B Sign Pattern Systematic conjecture predicts $S_{\rm bd} \approx 2F$
empirical bound on the sign change of $\beta_S^{\lambda_{\rm spin}}$ across polyhedral
phases. For F=12 (max channel $S_{\max} = 2F = 24$), the conjecture predicts $S_{\rm bd}
\sim 18-24$. This is listed as deferred Open Question 4 in paper3 §IX.B.

This memo reports the F=12 icosahedral inert state verification, partial.

## Setup

F=12 icosahedral spinor constructed via:
1. Spin matrices $F_x, F_y, F_z$ (25×25)
2. Wigner D matrices for $SO(3)$ via eigendecomposition
3. Icosahedral group $I$ generated from $C_5^z + C_3^{(37.4°,36°)}$
4. Projector $P_A = (1/|I|) \sum_g D^F(g)$ onto trivial irrep
5. $\zeta = P_A v / \|P_A v\|$ for random $v$

## Results — VERIFIED at machine precision

### Spinor sparsity (consistent with $C_5^z$ invariance)

$\zeta^{(F=12, I:A)}$ has non-zero components only at $m \in \{-10, -5, 0, +5, +10\}$
(= multiples of 5), as expected for $C_5^z$-invariant state.

Explicit (one phase choice):
- $\zeta_{+10} = -0.3437 - 0.3450 i$
- $\zeta_{+5} = +0.2135 + 0.2143 i$
- $\zeta_{0} = -0.4132 - 0.4147 i$
- $\zeta_{-5} = -0.2135 - 0.2143 i$
- $\zeta_{-10} = -0.3437 - 0.3450 i$

### Structural sanity checks

| Quantity | Numerical | Expected | Status |
|---|---|---|---|
| $\|\zeta\|^2$ | 1.0 | 1.0 | ✓ |
| $\langle F^2 \rangle$ | 156.000000 | $F(F+1) = 156$ | ✓ exact |
| $\langle F_x^2 \rangle$ | 52.000000 | $F(F+1)/3 = 52$ | ✓ exact |
| $\langle F_y^2 \rangle$ | 52.000000 | 52 | ✓ exact |
| $\langle F_z^2 \rangle$ | 52.000000 | 52 | ✓ exact |
| Schur isotropy dev. | 1.28e-13 | 0 | ✓ machine prec. |
| $\langle \mathbf{F} \rangle$ | $\sim 10^{-14}$ | 0 | ✓ |
| I-invariance $\max\|g\zeta - \zeta\|$ | 6.59e-14 | 0 | ✓ |

**Schur isotropy is machine-precision** — directly verifies the Universal Structure
Theorem's central premise ($T_1\|_I$ irreducibility for F=12).

### Selection rule — F-universality at F=12

Per-channel coefficients $\beta_S^{c_0} = \langle \zeta \otimes \zeta \| P_S \| \zeta \otimes \zeta \rangle$:

| S | $\beta_S^{c_0}$ | I_h harmonic? |
|---|---|---|
| 0 | 0.040000 | ✓ ($A_g$ in $S=0$) |
| **2** | **0.000000** | **✗ excluded** |
| **4** | **0.000000** | **✗ excluded** |
| 6 | 0.074954 | ✓ ($A_g$ in $S=6$) |
| **8** | **0.000000** | **✗ excluded** |
| 10 | 0.016347 | ✓ ($A_g$ in $S=10$) |
| 12 | 0.245220 | ✓ |
| **14** | **0.000000** | **✗ excluded** |
| 16 | 0.151231 | ✓ |
| 18 | 0.004049 | ✓ |
| 20 | 0.239783 | ✓ |
| 22 | 0.122114 | ✓ |
| 24 | 0.106302 | ✓ |

**Selection rule excludes**: $g_2, g_4, g_8, g_{14}$ — **IDENTICAL pattern as F=6 and
F=10 icosahedral** (paper3 §V.D, §V.F).

This is the **F-universality of the selection rule** explicitly verified at F=12: the
$I_h$ harmonic structure (which $S$ subspaces contain the $A_g$ trivial irrep)
determines selection rule, **independent of F**, for all $F$ that support $I:A$ inert
states. F=6 / F=10 / F=12 all share the $\{S=2,4,8,14\}$ exclusion pattern.

This is a new data point for paper3 §V.G F-universality demonstration: third
icosahedral instance (after F=6, F=10), confirming "selection rule depends on $H$,
not $F$" claim explicitly with 3 independent F values.

## Results — DEFERRED (require sympy closed-form derivation)

### Per-channel $\beta_S^{\lambda_{\rm spin}}$ sign pattern

The conjecture test ($S_{\rm bd} \approx 2F = 24$ for F=12) requires reliable extraction
of $\beta_S^{\lambda_{\rm spin}}$ for each $S \in \{0, 2, ..., 24\}$.

Attempted approach: single-channel BdG perturbation (turn on one $g_S$ at a time,
extract spin Goldstone stiffness from 50×50 BdG matrix). This failed because:

1. **Single-channel BdG is not always physical**: with only one $g_S$ active, the
   effective interaction breaks $SO(3)$ in a non-standard way; the spin Goldstone mode
   structure can degenerate with amplitude modes (mode identification by Bogoliubov
   scaling becomes ambiguous).

2. **Scalar limit yields no spin Goldstones**: with all $g_S = 1$, interaction is
   $SO(3)$-invariant, and the BdG spectrum shows 1 phonon + 24 free-particle-like
   amplitude modes (no spin Goldstone modes). Numerical λ_spin extraction returns
   meaningless value.

Resolution: sympy symbolic derivation of $\beta_S^{\lambda_{\rm spin}}$ as a
representation-theoretic functional of $D^{F=12}$ matrices. This is the proper
analytic path, parallel to Round 5's F=8 cube derivation (paper3 §V.E).

Sympy derivation is a multi-hour task involving:
- F=12 Clebsch-Gordan tabulation (numerical-exact rational coefficients)
- Construction of $\hat\zeta$-rotation perturbed energy functional
- Second-derivative extraction at θ=0 along each $F_a$ generator
- Symbolic factorization of resulting rational function of $g_S$

**Schedule**: post-修論 follow-up if paper3 v4 wants F=12 inclusion, OR D 論 follow-up
as part of "sign pattern conjecture systematic completion across all F" program
(Chapter 6 §6.10.4).

## Implications

### For paper3 v3

paper3 §V.D (F=6) and §V.F (F=10) demonstrate the I_h selection rule pattern. The
F=12 verification adds a third instance, enabling stronger F-universality claim in
§V.G: 3 instances across the I family ($\zeta^{(I:A)}_{F=6}, \zeta^{(I:A)}_{F=10},
\zeta^{(I:A)}_{F=12}$) all share $\{S=2,4,8,14\}$ exclusion.

**Recommendation**: add F=12 to §V.G master table as third I-family instance with
note "selection rule and Schur isotropy verified, closed-form derivation deferred to
v4". This makes the F-universality demonstration empirically tighter.

### For Sign Pattern conjecture

F=12 reliable extraction not achievable today. The conjecture (S_bd ≈ 2F = 24)
remains for D 論 follow-up.

Heuristically: F=6 → S_bd=10, F=10 → S_bd=16, F=8 → S_bd=12. If the empirical
trend continues, F=12 S_bd should land around 18-22 (somewhere between $1.5F=18$ and
$2F=24$). Cannot determine empirically from this verification.

### Reproducibility

Run: `julia --project=. test/manuscript/test_f12_icosahedral.jl`

Runtime ~3 min on standard CPU (dominated by 60-element group closure and CG table
construction). Output is fully deterministic (random seed 42).

## Summary

F=12 I:A inert spinor verified at machine precision for: norm, $\langle F^2 \rangle$,
Schur isotropy, $\langle F\rangle = 0$, I-invariance, $C_5^z$-imposed sparsity, and
selection rule. F-universality of I_h selection rule demonstrated as third I-family
instance after F=6 and F=10.

$\beta_S^{\lambda_{\rm spin}}$ sign pattern (= Sign Pattern Systematic test at F=12)
deferred to sympy closed-form derivation (post-修論 / D 論 follow-up).
