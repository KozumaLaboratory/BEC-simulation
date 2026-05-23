# Appendix E: Verify-first audit details + bug analysis

本 appendix では、Chapter 7 §7.6 で言及した verify-first methodology の concrete
operational instances を 詳述する。paper3 v3 5-case audit + F=12 verification +
Sign Pattern Anomalous Identity の execution detail、bug catches の root-cause
analysis、protocol の applicable scope。

---

## E.1 Verify-first protocol summary

Chapter 7 §7.6.1 で提示した 4-pillar protocol:

1. **Memory-based claim 禁止**: 既存 documentation や記憶への依存を避け、毎回
   primary source (paper / code) を直接参照
2. **Phase -1 hard gate**: paper transcribe + self-check + limit reductions を
   全項目に対して実行
3. **Cross-framework cross-validation**: 1 つの finding を ≥ 2 つの独立 framework
   で reproduce
4. **Negative result formal recording**: failure modes も publishable な structure
   として文書化

本 appendix は 2026-05-11 1 session 内で実行した paper3 audit を例に protocol の
operational details を提示する。

---

## E.2 paper3 v3 5-case audit (2026-05-11 session, commit c811cd7)

### E.2.1 Background

paper3 v3 main.md (PRR/PRX target, 871 lines) は Round 4 (F=4 cube, F=10 dodec) +
Round 5 (F=3 octa A_2, F=8 cube-octa Dy) で derive された closed-form coefficients を
含む。これら derivations は parallel session の sympy で実行された。

**Audit motivation**: paper3 main.md の coefficients が paper3 外の **independent**
methodology で reproduce 可能か検証 (= verify-first protocol "cross-framework
cross-validation" 第 3 pillar)。

### E.2.2 Independent methodology

Audit framework (script: `scripts/manuscript/paper3_audit.jl`):

**Step 1**: Spin matrices $F_x, F_y, F_z$ を direct construction (raising/lowering
operator $\sqrt{F(F+1) - m(m \pm 1)}$ 公式)

**Step 2**: Wigner D-matrix を $\exp(-i \theta \mathbf{F}\cdot\hat{n})$ の
eigendecomposition で 構築

**Step 3**: Polyhedral group $\{T, O, I\}$ を 2 generators (rotation about z + tilted
3-fold axis) から group closure

**Step 4**: Irrep character compute (A_1 trivial, A_2 sign rep for $O$, A for $I$)

**Step 5**: Projector $P_\Gamma = (1/|G|) \sum_g \chi^*_\Gamma(g) D^F(g)$ を random
vector に適用、normalize

**Step 6**: 構造 sanity check:
- $\|\zeta\| = 1$
- $\langle F^2 \rangle = F(F+1)$ exact
- Schur isotropy: $\langle F_x^2\rangle = \langle F_y^2\rangle = \langle F_z^2\rangle = F(F+1)/3$
- $\langle \mathbf{F}\rangle = 0$
- $g \zeta = \chi_\Gamma(g) \zeta$ for all $g \in G$ (equivariance)

**Step 7**: $\beta_S^{c_0} = |\langle S | \zeta \otimes \zeta\rangle|^2$ を CG
summation で compute (SpinorBEC.clebsch_gordan)

**Step 8**: $\beta_S^{c_0}$ 数値と paper3 stated rational coefficients を比較

### E.2.3 Audit results (5 cases all PASS)

| F | Phase | Group / irrep | Equivariance | Schur isotropy | $\beta_S^{c_0}$ match |
|---|---|---|---|---|---|
| 3 | octa | $O$:A_2 | 4.52e-14 | 8.88e-16 | exact 6 decimals |
| 4 | cube | $O$:A_1 | 3.26e-14 | 1.15e-14 | exact 6 decimals |
| 6 | icosahedral | $I$:A | 1.17e-13 | 6.71e-13 | exact 6 decimals |
| 8 | cube-octa Dy | $O$:A_1 | 5.12e-14 | 1.99e-13 | exact 6 decimals |
| 10 | dodec | $I$:A | 7.42e-14 | 4.55e-13 | exact 6 decimals |

**All 5 cases PASS at machine precision**. paper3 v3 coefficients confirmed via
independent group-projection methodology (vs. paper3's original sympy
Hamiltonian-projection methodology).

Detailed numerical tables: `docs/manuscript/papers/paper3_universal_theorem/audit_result_2026-05-11.md`.

---

## E.3 F=12 icosahedral verification (Round 7 NEW)

### E.3.1 Motivation

paper3 §IX.B "Sign Pattern Systematic" conjecture が F=12 で $S_{\rm bd} \sim 18-24$
を予測。F=12 instance を構築し:
- Selection rule $\{S = 2, 4, 8, 14\}$ exclusion が F=6, F=10 と同じであることを check
  (= F-universality of $I_h$ selection rule, 3rd instance)
- $\beta_S^{c_0}$ coefficients を tabulate

### E.3.2 Result

F=12 I:A spinor (script: `f12_icosahedral_verification.jl`):
- ζ sparse on $m \in \{\pm 10, \pm 5, 0\}$
- $\langle F^2\rangle = 156 = F(F+1)$ exact
- Schur isotropy 1.28e-13 (machine precision)
- **Selection rule $\{2, 4, 8, 14\}$ excluded — IDENTICAL pattern as F=6, F=10**

This extends paper3 §V.G F-universality demonstration from 2 instances (F=6, F=10)
to **3 instances (F=6, F=10, F=12)** for $I_h$ family.

Detail: `F12_verification_result.md`.

---

## E.4 Sign Pattern Anomalous Identity (Strategy A Step 4 numerical)

### E.4.1 Conjecture refined

paper3 §IX.B Sign Pattern Systematic は元々 "empirical observation" として記述。
本 session で 数値的 structural identity に refine:

$$\text{sign}(\beta_S^{\lambda_{\rm spin}}) = \text{sign}(X_S^{(\rm anom)})$$

with $X_S^{(\rm anom)} = \text{Re}[\langle S | F_a \zeta \otimes F_a \zeta\rangle \cdot \langle \zeta\otimes\zeta | S\rangle^*]$.

### E.4.2 Verification (4 of 5 cases match)

Script: `sign_pattern_6j_numerical.jl`.

- F=4 cube: sign change at $S=6$ ✓ matches paper3
- F=6 icosa: sign change at $S=10$ ✓ matches paper3
- F=8 cube-octa: sign change at $S=12$ ✓ matches paper3
- F=10 dodec: sign change at $S=16$ ✓ matches paper3
- F=3 octa A_2: predicts $S=4$, paper3 says $S=6$ — **one-step offset due to A_2 sign
  convention**

Detail: `sign_pattern_anomalous_identity.md`.

---

## E.5 Bug catches (2 issues caught by verify-first)

### E.5.1 Bug 1: Icosahedral 3-fold axis tilt (F=12 verification)

**Symptom**: Initial F=12 script with axis tilt 31.72° (= acos(φ/√(φ²+1))) produced
group of 164 elements instead of |I|=60.

**Root cause**: The original formula was for a different geometric quantity (not the
3-fold rotation axis). Correct formula for the 3-fold axis tilt from the 5-fold axis
in standard icosahedral orientation:

$$\theta_{3\text{-fold}} = \arccos\left(\frac{1 + \phi}{\sqrt{3(1 + \phi^2)}}\right) \approx 37.38°$$

with azimuth $\pi/5$ (= 36°, halfway between upper-ring vertices).

**Fix**: Updated to correct formula, group closure produces exactly |I|=60. F=12
spinor verified with machine-precision Schur isotropy.

**Generic transferable lesson**: When constructing polyhedral groups from rotation
generators, **verify the group order numerically** (group closure should produce
|T|=12, |O|=24, or |I|=60 exactly; otherwise the axis choice is wrong).

### E.5.2 Bug 2: F=3 octa A_2 character C_2 classification

**Symptom**: Initial paper3 audit at F=3 octa (O:A_2 irrep) showed character sum
= −4 (should be 0 for orthogonal-to-A_1 irrep), equivariance check 1.92 (huge),
Schur isotropy deviation 0.215 (non-isotropic).

**Root cause**: My initial $A_2$ character assignment used the criterion "C_2 element
commutes with $C_{4z}$" to identify axial C_2 elements (in $T$ subgroup of $O$,
$\chi_{A_2} = +1$). This criterion was incorrect — it identified ONLY $C_2^z$
(commutes with $C_4^z$ trivially), missing $C_2^x$ and $C_2^y$ which **do not**
commute with $C_4^z$ (axes are not parallel).

Result: 1 axial + 8 diagonal (instead of 3 + 6), character sum off by $(1-3) \cdot 1 + (8-6) \cdot (-1) = -4$.

**Fix**: Use correct criterion "g is the square of some order-4 element of $G$".
The 3 axial C_2 elements (squares of 6 C_4) are in $T$ subgroup; the 6 diagonal C_2'
elements are not squares of any C_4.

After fix: character sum = 0, equivariance 4.52e-14, Schur isotropy 8.88e-16. F=3
octa A_2 audit PASS.

**Generic transferable lesson**: Group theoretic classification of elements (axial
vs diagonal C_2, etc.) requires **group-structural criterion** (e.g., "is the square
of an order-4 element"), not naive commutator criteria. Verify by character sum check
(should equal 0 for non-trivial irrep, |G| for trivial irrep).

### E.5.3 Bug-catch frequency analysis

2 bugs caught in 1 session of audit work (~3 hours wall clock). Both bugs would NOT
affect paper3 v3 final results (paper3 v3 used sympy with different methodology), but
WOULD affect any future independent verification.

**Conclusion**: verify-first protocol successfully catches methodology-specific bugs
that might otherwise propagate into D-thesis follow-up work. Each bug catch becomes
a transferable lesson + documented gotcha (this Appendix + MEMORY.md).

---

## E.6 Negative results documented

本 session で確立した 3 つの "structural negative results":

### E.6.1 F=12 single-channel BdG ambiguity

F=12 spinor では single-channel $g_S$ perturbation での spin Goldstone identification
が ambiguous (`F12_verification_result.md` §"DEFERRED" 節)。Single channel $g_S$ では
SO(3) breaking が 非標準的 → BdG mode classification (phonon vs spin Goldstone vs
amplitude) が degenerate。Multi-channel sympy derivation が proper path。

### E.6.2 F=3 octa A_2 in Anomalous Identity

A_2 sign rep state では Anomalous Identity (E.4) が one-step offset (predicts $S=4$
sign change, actual $S=6$)。A_2 convention の sign factor が missing。$A_1$ cases
(F=4/6/8/10) では Identity が exactly matches。修正可能だが本 session では deferred。

### E.6.3 Sign Pattern conjecture interior (deferred)

Sign Pattern conjecture の "single sign change" interior (= S_bd $\in [1.5F, 2F]$) は
本 session で証明されず。Anomalous Identity (= sign の structural origin) + endpoint
lemmas (β_0, β_{2F}) は確立、interior proof は D 論 Year 1 candidate。

---

## E.7 Applicable scope + limitations

### E.7.1 What verify-first audit framework covers

✓ Polyhedral inert state spinor construction (any F, any $\{T, O, I\}$ subgroup, any
1-dim irrep)
✓ Structural sanity (norm, $\langle F^2\rangle$, Schur isotropy, $\langle F\rangle$, group invariance)
✓ Selection rule $\beta_S^{c_0}$ computation via CG summation
✓ Sign Pattern Anomalous Identity per-channel sign extraction

### E.7.2 What verify-first audit does NOT cover

✗ Full sympy closed-form derivation of $\beta_S^{c_0/\lambda_{\rm spin}}$ rational
  coefficients (requires sympy + BdG factorization)
✗ Higher-order LHY corrections ($\mathcal{O}(n^{7/2})$)
✗ Time-dependent dynamics validation (= Chapter 5 TWA / TDHFB scope)
✗ Experimental data comparison (= D 論 Year 3 scope)

These limitations define the boundary between **修論 audit-confirmed material** vs.
**D 論 / post-修論 extensions**.

---

## E.8 Future audit framework extensions

D 論 Year 1 candidates for extending E.2-E.4 framework:

1. **F=5, 7, 9, 11 odd-F polyhedral** (paper3 §V.B-G F-completion):
   $T$:A and $O$:A_2 instances at F=5, 7, 9, 11 — sympy + audit verification
2. **F=12 closed-form derivation** (paper3 §IX.B Sign Pattern $S_{\rm bd}$ tight bound
   numerical check at F=12)
3. **Sign Pattern Anomalous Identity 解析的 proof** (Strategy A Step 3, Wigner-Eckart 6j
   sign factorization)
4. **Dipolar generalization audit**: Lima-Pelster $Q_5$-corrected closed forms for
   polyhedral phases
5. **Multi-species J=2 framework verification**: binary BEC cross-channel
   couplings

各 extension は本 Appendix の framework に increment 追加可能、reproducibility chain
は 修論 → D 論 を seamless に bridge。

---

## E.9 Verify-first 哲学の transfer (本研究 outside)

本研究で確立した verify-first methodology は本修論 specific physics を超えて、

- 任意の論文 reproducibility audit ("can I independently reconstruct this?")
- 数値 framework cross-validation (≥ 2 frameworks で同じ finding)
- Bug catch via group order / character sum / equivariance check

を提供する universal template として 当該研究 community 全体への contribution。

D 論期間 + post-修論 follow-up papers 全てで本 template を継承運用する。

---

(Appendix E 終了)
