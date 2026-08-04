# F=5 / F=7 odd-F polyhedral verification result

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Date**: 2026-05-11
**Script**: `test/manuscript/test_f5_f7_polyhedral.jl`
**Status**: F=7 T:A + F=7 O:A_2 VERIFIED at machine precision; F=5/F=7 T:E_1 complex
1-dim irreps need 2-dim real representation projection (limitation).

## Background

Paper #6 (F-systematic completion, post-修論 candidate per `dthesis_year1_roadmap.md` §3.3
Q3) targets odd-F polyhedral inert states F=5, 7, 9, 11. This memo reports F=5/7
initial verification.

Per Appendix D §D.5 Table II:
- F=5: $T$:E_1 multiplicity 1 (complex 1-dim, $T$:E_2 = conjugate)
- F=7: $T$:A multiplicity 1, $T$:E_1 multiplicity 1, $O$:A_2 multiplicity 1

## Results

### F=7 $T$:A (true invariant) — VERIFIED ✓

| Check | Value | Status |
|---|---|---|
| Group order | 12 | ✓ (|T| = 12) |
| Character sum | 12.0 + 0.0i | ✓ (trivial irrep) |
| Equivariance max ||g·ζ - χ(g)·ζ|| | 6.91e-14 | ✓ machine prec. |
| $\langle F^2 \rangle$ | 56.000000 | ✓ (= F(F+1)) |
| Schur isotropy dev | 2.38e-13 | ✓ machine prec. |
| $\langle \mathbf{F} \rangle$ | $\sim 10^{-13}$ | ✓ |
| Spinor sparsity | $m \in \{\pm 6, \pm 2\}$ | sparse |
| Selection rule | $[S=2]$ excluded | ✓ |

$\beta_S^{c_0}$ per channel (computed numerically):

| S | $\beta_S^{c_0}$ |
|---|---|
| 0 | 0.066667 = **1/15** |
| 2 | 0 (excluded by $T$ harmonics) |
| 4 | 0.000976 |
| 6 | 0.202946 |
| 8 | 0.168290 |
| 10 | 0.097061 |
| 12 | 0.310917 |
| 14 | 0.153143 |

Note: $\beta_0^{c_0} = 1/15 = 1/(2F+1)$ ✓ — **universal Lemma 1 ($\beta_0 = 1/(2F+1)$)
holds at F=7**, consistent with sign_pattern_anomalous_identity.md endpoint identity.

### F=7 $O$:A_2 (sign rep) — VERIFIED ✓

| Check | Value | Status |
|---|---|---|
| Group order | 24 | ✓ (|O| = 24) |
| Character sum | 0.0 + 0.0i | ✓ (orthogonal to A_1) |
| Equivariance | 6.49e-14 | ✓ machine prec. |
| $\langle F^2 \rangle$ | 56 | ✓ |
| Schur isotropy dev | 3.55e-14 | ✓ |
| $\langle \mathbf{F} \rangle$ | $\sim 10^{-13}$ | ✓ |
| Spinor sparsity | $m \in \{\pm 6, \pm 2\}$ | sparse |
| Selection rule | $[S=2]$ excluded | ✓ |

$\beta_S^{c_0}$ values IDENTICAL to F=7 $T$:A (within machine precision). This is
expected: F=7 has both $T$:A and $O$:A_2 multiplicity 1 in $D^{F=7}$, and the
projection picks the same 1-dim invariant subspace (since $T$:A invariant within $D^{F=7}$
is automatically also $O$:A_2 invariant up to character — this is because $O = T \cup C_4 T$,
and the $C_4$-related sign-flip is exactly the $A_2$ vs $A_1$ distinction).

Selection rule [S=2] excluded same as F=3 octa, F=4 cube, F=8 cube-octa — **F-universal
for $O$-family**.

### F=5 $T$:E_1 — NEEDS 2-dim REAL REPRESENTATION

| Check | Result |
|---|---|
| Character sum | $1.78 \times 10^{-15} + 6.93i$ (imaginary part non-zero) |
| Equivariance | 1.25 (FAIL, expected $\ll 1$) |
| Schur isotropy | deviation 6.0 (FAIL) |
| $\langle \mathbf{F} \rangle$ | $\sim 10^{-14}$ |
| ζ support | $m \in \{\pm 4, \pm 2\}$ |

**Issue**: $T$:E_1 is a **complex 1-dim** irrep. Direct projection via $P_{E_1} = (1/|T|) \sum_g \chi^*_{E_1}(g) D^F(g)$ gives a complex 1-dim eigenvector (eigenvalue $\omega = e^{2\pi i/3}$ of $C_3$), but the resulting "spinor" is not a **real-symmetry** physical state.

For F=2 cyclic ($T_d$:E, paper3 §V.A), the physical spinor was constructed differently
(specific Majorana-points construction yielding the **real 2-dim doublet** combining
$E_1 + E_2$). The projection here picks a single complex element of the doublet.

### F=7 $T$:E_1 — same limitation

Same as F=5: complex 1-dim projection doesn't yield physical spinor.

## Limitation: complex irrep projection needs 2-dim real treatment

For complex 1-dim irreps ($T$:E_1, $T$:E_2 of $T$ group), the physically meaningful
inert state lives in the **real 2-dim representation** $E = E_1 \oplus E_2 \cong T_d$:E.

To construct such states:
1. Project onto the real 2-dim subspace using character projection of $E_1 + E_2$
2. Within the 2-dim subspace, select a specific "doublet element" with appropriate
   $T_d$ ($T$ + reflection) symmetry — this requires explicit Majorana-points
   construction or specific phase assignments

This is a known issue in spinor BEC inert state construction; F=2 cyclic (paper #1)
handles it via the Mäkelä-Suominen 2007 explicit construction.

For F=5/F=7 T:E_1, the proper construction is **deferred to Paper #6 development**
(D 論 Year 1 Q3 per `dthesis_year1_roadmap.md` §2 Q3 plan).

## Implications for Paper #6 F-systematic completion

### Confirmed verifiable instances (Year 1 Q3 target)

| F | Polyhedral inert | Status |
|---|---|---|
| 7 | $T$:A | ✓ verified ($\beta_0 = 1/15$, Schur isotropy 1e-13) |
| 7 | $O$:A_2 | ✓ verified ($\beta_0 = 1/15$, identical to $T$:A) |
| 9 | $T$:A (×2 multiplicity) | TODO Q3 |
| 9 | $O$:A_1 | TODO Q3 |
| 9 | $O$:A_2 | TODO Q3 |
| 11 | $T$:A | TODO Q3 |
| 11 | $O$:A_2 | TODO Q3 |

### Deferred (complex irrep, needs 2-dim real treatment)

| F | Polyhedral inert | Status |
|---|---|---|
| 5 | $T$:E_1 | DEFERRED (2-dim real construction needed) |
| 7 | $T$:E_1 | DEFERRED |
| 9 | $T$:E_1 | DEFERRED |
| 11 | $T$:E_1 ×2 | DEFERRED |

## Verify-first lessons (this attempt)

1. **Matrix-power order check ordering matters**: `is_C4` defined as $g^4 = I$ INCLUDES
   $C_2$ elements (since $(g^2)^2 = I$). Strict order check requires $g^4 = I$ AND
   $g^2 \neq I$ for order-4 distinction. Bug caught + fixed in this session
   (Appendix E §E.5 type lesson, transferable to any group-element classification).

2. **Complex irrep projection limitation**: directly projecting onto complex 1-dim
   $E_1$ character doesn't yield real-spinor inert state. Need 2-dim real $E$
   representation + doublet element selection.

3. **F=7 $T$:A ≡ $O$:A_2 at this F**: The $T$:A invariant within $D^{F=7}$ is
   automatically $O$:A_2 (sign rep under reflection-equivalent $C_4$). At higher F
   with multiplicity > 1, these may diverge — TODO for F=9, 11 verification.

## Next steps

- F=9, 11 verification: extend script (T:A, O:A_1, O:A_2 cases, ~1 day work)
- F=5/7 T:E_1 proper construction: $T_d$:E 2-dim real representation projection,
  Majorana-points style explicit construction
- $\beta_S^{c_0}$ rational coefficients: closed-form sympy derivation for F=7 T:A
  / O:A_2 (similar to F=4 cube structure)
- Sign Pattern Anomalous Identity test at F=7: extend
  `test_sign_pattern_6j.jl` to include F=7 cases (= verify
  Identity at one more odd-F instance to strengthen the conjecture)

These items align with `dthesis_year1_roadmap.md` Q3 milestone.

---

(f5_f7_verification_result.md 終了)
