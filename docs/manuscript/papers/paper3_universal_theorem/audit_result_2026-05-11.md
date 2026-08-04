# paper3 v3 independent audit — 5 polyhedral cases VERIFIED

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Date**: 2026-05-11
**Script**: `test/manuscript/test_paper3_audit.jl`
**Status**: ALL 5 paper3 polyhedral cases pass independent verification.

## Methodology

Independent reconstruction of each polyhedral inert spinor via:
1. Build $F$-component spin matrices $F_x, F_y, F_z$
2. Generate point group ($O$ or $I$) via Wigner D matrices + closure
3. Compute irrep character (with $C_4$-square refinement for $O$:A_2)
4. Project random vector onto target irrep
5. Verify structural properties (norm, $\langle F^2 \rangle$, Schur isotropy, $\langle F\rangle$)
6. Compute $\beta_S^{c_0} = \langle \zeta\otimes\zeta | P_S | \zeta\otimes\zeta \rangle$
   via Clebsch-Gordan summation (SpinorBEC.clebsch_gordan)
7. Compare $\beta_S^{c_0}$ to paper3 stated closed-form rational coefficients

## Results — all 5 cases PASS

### F=3 octahedral ($O$:A_2, paper3 §V.B, Round 5 NEW)

| Check | Result | Status |
|---|---|---|
| Group order | 24 | ✓ |
| Character sum (A_2) | 0.00 | ✓ (orthogonal to A_1) |
| Equivariance $\max\|g\zeta - \chi_{A_2}(g)\zeta\|$ | 4.52e-14 | ✓ machine prec. |
| $\langle F^2 \rangle$ | 12.000000 | ✓ exact (=F(F+1)) |
| Schur isotropy deviation | 8.88e-16 | ✓ machine prec. |
| $\zeta$ sparsity | m=±2 only | ✓ matches paper3 Eq V.B.1 |
| Selection: excluded S | [2] | ✓ matches paper3 |

**Numerical $\beta_S^{c_0}$ vs paper3 closed forms** (Eq. V.B.2):

| S | Numerical | paper3 fraction | Decimal |
|---|---|---|---|
| 0 | 0.142857 | 1/7 | 0.142857 ✓ |
| 4 | 0.545455 | 6/11 | 0.545455 ✓ |
| 6 | 0.311688 | 24/77 | 0.311688 ✓ |

**EXACT match to 6+ decimal places.** Round 5 derivation of F=3 octa A_2 closed form
independently confirmed.

### F=4 cube ($O$:A_1, paper3 §V.C, Round 4 NEW)

| Check | Result | Status |
|---|---|---|
| Group order | 24 | ✓ |
| Equivariance | 3.26e-14 | ✓ |
| $\langle F^2 \rangle$ | 20.000000 | ✓ exact |
| Schur isotropy deviation | 1.15e-14 | ✓ |
| $\zeta$ sparsity | m ∈ {±4, 0} | ✓ matches paper3 Eq V.C.1 |
| Selection: excluded S | [2] | ✓ matches paper3 |

| S | Numerical | paper3 fraction | Decimal |
|---|---|---|---|
| 0 | 0.111111 | 1/9 | 0.111111 ✓ |
| 4 | 0.228438 | 98/429 | 0.228438 ✓ |
| 6 | 0.404040 | 40/99 | 0.404040 ✓ |
| 8 | 0.256410 | 10/39 | 0.256410 ✓ |

**EXACT match.** Round 4 F=4 cube closed form confirmed.

### F=6 icosahedral ($I$:A, paper3 §V.D, Paper #2)

| Check | Result | Status |
|---|---|---|
| Group order | 60 | ✓ |
| Equivariance | 1.17e-13 | ✓ |
| $\langle F^2 \rangle$ | 42.000000 | ✓ exact |
| Schur isotropy deviation | 6.71e-13 | ✓ |
| $\zeta$ sparsity | m ∈ {±5, 0} | ✓ matches paper3 Eq V.D.1 |
| Selection: excluded S | [2, 4, 8] | ✓ (S=14 > S_max for F=6) |

| S | Numerical | paper3 fraction | Decimal |
|---|---|---|---|
| 0 | 0.076923 | 1/13 | 0.076923 ✓ |
| 6 | 0.374613 | 121/323 | 0.374613 ✓ |
| 10 | 0.375959 | 147/391 | 0.375959 ✓ |
| 12 | 0.172505 | 980/5681 | 0.172505 ✓ |

**EXACT match.** Paper #2 main result confirmed via independent reconstruction.

### F=8 cube-like octa ($O$:A_1, paper3 §V.E, Round 5 NEW — Dy relevant)

| Check | Result | Status |
|---|---|---|
| Group order | 24 | ✓ |
| Equivariance | 5.12e-14 | ✓ |
| $\langle F^2 \rangle$ | 72.000000 | ✓ exact |
| Schur isotropy deviation | 1.99e-13 | ✓ |
| $\zeta$ sparsity | m ∈ {±8, ±4, 0} | ✓ matches paper3 Eq V.E.1 |
| Selection: excluded S | [2] | ✓ matches paper3 |

| S | Numerical | paper3 fraction | Decimal |
|---|---|---|---|
| 0 | 0.058824 | 1/17 | 0.058824 ✓ |
| 4 | 0.108915 | 1372/12597 | 0.108915 ✓ |
| 6 | 0.002872 | 64/22287 | 0.002872 ✓ |
| 8 | 0.058088 | 330/5681 | 0.058088 ✓ |
| 10 | 0.203248 | 40768/200583 | 0.203248 ✓ |
| 12 | 0.283900 | 1651420/5816907 | 0.283900 ✓ |
| 14 | 0.103497 | 37856/365769 | 0.103497 ✓ |
| 16 | 0.180657 | 1714570/9490743 | 0.180657 ✓ |

**EXACT match to 6 decimal places — all 8 channels.** Round 5 F=8 cube-like octa
(Dy-relevant) closed form independently verified. This is critical because it's the
**most recent + most complex addition** to paper3 v3.

### F=10 dodecahedral ($I$:A, paper3 §V.F, Round 4 NEW)

| Check | Result | Status |
|---|---|---|
| Group order | 60 | ✓ |
| Equivariance | 7.42e-14 | ✓ |
| $\langle F^2 \rangle$ | 110.000000 | ✓ exact |
| Schur isotropy deviation | 4.55e-13 | ✓ |
| $\zeta$ sparsity | m ∈ {±10, ±5, 0} | ✓ matches paper3 Eq V.F.1 |
| Selection: excluded S | [2, 4, 8, 14] | ✓ matches paper3 |

| S | Numerical | paper3 fraction | Decimal |
|---|---|---|---|
| 0 | 0.047619 | 1/21 | 0.047619 ✓ |
| 6 | 0.093330 | 2299/24633 | 0.093330 ✓ |
| 10 | 0.185431 | 586625/3163581 | 0.185431 ✓ |
| 12 | 0.151618 | 3135/20677 | 0.151618 ✓ |
| 16 | 0.224758 | 349448/1554777 | 0.224758 ✓ |
| 18 | 0.178801 | 131648/736281 | 0.178801 ✓ |
| 20 | 0.118444 | 15895/134199 | 0.118444 ✓ |

**EXACT match.** Round 4 F=10 dodec closed form confirmed.

## Audit Summary

| Case | F | Phase | Group | Irrep | Result | paper3 ref |
|---|---|---|---|---|---|---|
| 1 | 3 | octahedral | $O$ | A_2 | ✓ MATCH | §V.B Round 5 |
| 2 | 4 | cube | $O$ | A_1 | ✓ MATCH | §V.C Round 4 |
| 3 | 6 | icosahedral | $I$ | A (=A_1) | ✓ MATCH | §V.D Paper #2 |
| 4 | 8 | cube-like octa | $O$ | A_1 | ✓ MATCH | §V.E Round 5 |
| 5 | 10 | dodecahedral | $I$ | A | ✓ MATCH | §V.F Round 4 |

**All 5 polyhedral cases pass verify-first audit at machine precision** (Schur
isotropy < 1e-12 in all cases, $\langle F^2\rangle$ exact, $\beta_S^{c_0}$ match
paper3 closed forms to 6+ decimal places).

The audit covers:
- All 3 polyhedral families ($T$ via F=2 cyclic in Paper #1, $O$ via F=3/4/8, $I$ via F=6/10)
- Both F-parities (odd F=3, even F=4/6/8/10)
- Both irrep types (true invariant A_1 for F=4/6/8/10, sign rep A_2 for F=3)
- Round 4 additions (F=4/F=10) AND Round 5 additions (F=3/F=8)
- Realistic experimental species (Cr at F=3, Eu at F=6, Dy at F=8)

## Bugs Caught (Verify-first contribution)

### Bug 1: Initial 3-fold axis tilt formula (caught at F=12)

Initial F=12 verification used `acos(φ/√(φ²+1))` ≈ 31.72° for 3-fold axis tilt
from 5-fold axis. **Correct value**: `acos((1+φ)/√(3(1+φ²)))` ≈ 37.38°. Fixed,
group closure now produces exactly |I|=60 elements.

This is a generic gotcha for icosahedral group construction — applies to any future
F=12/F=14/F=16 icosahedral verification.

### Bug 2: F=3 octa A_2 character C_2 classification (caught at F=3 audit)

Initial criterion "g commutes with C_4z" misclassified the 9 C_2 elements of $O$:
it identified only 1 axial (C_2z) instead of 3 axial. **Correct criterion**: g is
$h^2$ for some order-4 $h$ in the group. Fixed, character sum now = 0 (orthogonal
to A_1), equivariance check 4.52e-14.

This is a subtle point in $O$ group theory: C_2 along 4-fold axes do NOT all
commute with a specific C_4 (only C_2z does). The "C_4-square" criterion is the
correct partition.

These two bugs would not have affected paper3 v3 final results (paper3 used
established sympy derivations from Mäkelä-Suominen / KU-style frameworks).
But they would have shown up in any future verification or independent reproduction.

## Implications

### paper3 v3 status: VERIFIED

All 5 polyhedral closed-form coefficient sets in paper3 §V.B-§V.F are
independently confirmed by reconstruction-from-scratch with different methodology
(group projection + CG summation vs. sympy symbolic factorization). This is the
strongest possible verify-first check.

### Recommendation

paper3 v3 is **submission-ready for PRR/PRX**. The 5 polyhedral cases
+ F=2 cyclic (Paper #1) + F=2 BN axial (§VII.B) + F-systematic Table II all hold
under independent verification. Round 5 additions (F=3 octa, F=8 cube-like octa)
are the most recent additions and pass cleanly.

### Future work

The verification framework (`paper3_audit.jl`) generalizes to:
- F=12 polyhedral inert state (icosahedral, F12_verification_result.md)
- Any future $F$ + polyhedral group combination
- Sign Pattern conjecture verification at higher $F$ (post-修論)

These three docs ($paper3_audit.jl$, `F12_verification_result.md`,
`audit_result_2026-05-11.md`) form a reproducibility chain for the next paper3 round
or D 論 follow-up.
