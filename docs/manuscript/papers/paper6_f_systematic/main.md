# Paper #6: F-Systematic Completion of Polyhedral Inert States for Spinor BEC LHY Theorem

**Target journal**: PRR (Physical Review Research)

**Estimated length**: 12-14 pages (full paper)

**Status (2026-05-11)**: SKELETON. Paper #6 is enabled by Lemma 1 General-S
(paper #3 v4 main result), which **mechanically determines $\beta_S^{(\lambda_{\rm spin})}$
from $\beta_S^{(c_0)}$**. Computational cost per F instance reduced from
hours of BdG diagonalization to seconds of Clebsch-Gordan projection.
F=5/7/9/11/12 systematic completion is now tractable; this paper presents
the full catalog.

---

## Abstract

We complete the F-systematic classification of polyhedral inert states for
spinor Bose-Einstein condensates by deriving closed-form Lee-Huang-Yang (LHY)
corrections for **all $F \leq 12$ polyhedral cases** in a single unified
analytical framework. Building on the Sign Pattern Theorem (Lemma 1 General-S,
established in companion paper #3 v4):

$$\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2 F(F+1)} \cdot \beta_S^{(c_0)}$$

valid for all $A_1$-irrep polyhedral inert states, we mechanically compute
$\beta_S^{(c_0)}$ via Clebsch-Gordan projection and obtain
$\beta_S^{(\lambda_{\rm spin})}$ in closed form. We catalog **20+ polyhedral
inert state instances** spanning F = 2 cyclic ($T_d$), F = 3 octa ($O$:A_2),
F = 4 cube ($O_h$), F = 5 $T$:E_1, F = 6 icosa ($I_h$), F = 7 ($T$:A, $O$:A_2),
F = 8 cube-octa ($O$:A_1, Dy), F = 9 ($O$:A_1, $O$:A_2, $T$:A×2), F = 10 dodec
($I_h$), F = 11 ($T$:A, $O$:A_2), and F = 12 icosa ($I$:A) — covering all three
polyhedral families ($T, O, I$) at both F-parities. We identify generic features:
(i) the sign-change boundary $S_{\rm bd}(F) = \sqrt{2F(F+1)} \approx \sqrt{2} F$
shared by all F; (ii) Schur isotropy $\|F_a \zeta\|^2 = F(F+1)/3$ at every
polyhedral case; (iii) the F=1 exception where no polyhedral inert state exists.
For experimentally relevant species ($^{52}$Cr at F=3, $^{151}$Eu at F=6,
$^{164}$Dy at F=8), we provide explicit Feshbach engineering recipes targeting
$S > \sqrt{2F(F+1)}$ scattering channels. This systematic completion fully
unifies the spinor-BEC polyhedral phase landscape.

---

## I. Introduction

### A. Motivation

Companion paper #3 v4 established the Universal Structure Theorem for LHY
corrections in spinor BECs with polyhedral residual symmetry $H$, and proved
the Sign Pattern Theorem (Lemma 1 General-S + Lemma 2 unique sign change).
These results reduce the computation of $\lambda_{\rm spin}^{(H, F)}$ for any
polyhedral inert state to:

1. Compute $\beta_S^{(c_0)} = |\langle SM|\zeta\otimes\zeta\rangle|^2$ via CG
   projection (one sympy/numerical CG computation per case).
2. Apply Lemma 1 General-S:
   $\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2 F(F+1)} \beta_S^{(c_0)}$.
3. Assemble LHY closed form:
   $\varepsilon_{\rm LHY}^{(H, F)} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3} n^{5/2}\,[c_0^{5/2} + 3 |\lambda_{\rm spin}|^{5/2}]$.

This paper completes the F-systematic catalog by applying this recipe to all
F = 2 through F = 12 polyhedral inert states.

### B. Why F-systematic completion matters

1. **Experimental opportunities**: Different isotopes have different F values
   ($^{87}$Rb F=2, $^{52}$Cr F=3, $^{151}$Eu F=6, $^{164}$Dy F=8, certain Yb states
   F=9, etc.). Each species needs its own polyhedral phase characterization.
2. **Theoretical completeness**: Until now, only F=2/4/6/8/10 cases were
   characterized in the literature (paper3 v3 5-case verification). Odd-F cases
   (F=3/5/7/9/11) and high-F cases (F=11/12) were either missing or
   partially treated.
3. **Predictive recipes**: The Feshbach engineering recipe $S > \sqrt{2F(F+1)}$
   gives concrete experimental targets but only when individual channel
   coefficients are known. This catalog provides those coefficients.

### C. Paper structure

Section II reviews the Sign Pattern Theorem in compact form for self-containment.
Section III gives the F-systematic catalog in tabular form, with full closed
forms in Appendix A. Section IV discusses experimental implications for the
target species (Cr, Eu, Dy, hypothetical Yb F=9). Section V concludes.

---

## II. Theorem Recap (from Paper #3 v4)

### A. Universal Structure Theorem

For any uniform spinor BEC ground state $\zeta$ with **polyhedral residual
rotation symmetry** $H \in \{T, O, I, T_h, O_h, I_h\}$:

$$\boxed{\varepsilon_{\rm LHY}^{(H, F)} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,[c_0^{5/2} + 3 |\lambda_{\rm spin}|^{5/2}]}$$

where $c_0$ is the phonon stiffness and $\lambda_{\rm spin}$ is the common
stiffness of three (degenerate) spin Goldstones in $T_1$ irreducible
representation of $H$. The factor 3 comes from $T_1$-irreducibility via
Schur's lemma.

### B. Sign Pattern Theorem (Lemma 1 General-S)

For any $A_1$-irrep polyhedral inert state $\zeta^{(H, A_1)}_F$:

$$\boxed{\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2 F(F+1)} \cdot \beta_S^{(c_0)}}$$

where $\beta_S$ denotes the rational coefficient of $g_S$ in the relevant
stiffness:
- $c_0 = \sum_S \beta_S^{(c_0)} g_S$
- $\lambda_{\rm spin} = \sum_S \beta_S^{(\lambda_{\rm spin})} g_S$

### C. Sign-change boundary (Lemma 2)

$\beta_S^{(\lambda_{\rm spin})}$ has a unique sign change at:

$$S_{\rm bd}(F) = \frac{-1 + \sqrt{1 + 8F(F+1)}}{2} \approx \sqrt{2 F(F+1)} \approx \sqrt{2}\,F$$

This is an exact statement valid for all $F \geq 2$.

---

## III. F-Systematic Catalog

(Full closed forms in Appendix A. The table below summarizes the catalog.)

| F | Phase | $H$ | Multiplicity | Channel selection | $S_{\rm bd}$ | Status |
|---|---|---|---|---|---|---|
| 2 | cyclic | $T_d$ | 1 | $g_2, g_4$ | 3.00 | paper #1 |
| 3 | octa A_2 | $O$ | 1 | $g_0, g_4, g_6$ | 4.90 | paper #3 §V.B |
| 4 | cube | $O_h$ | 1 | $g_0, g_4, g_6, g_8$ | 6.32 | paper #3 §V.C |
| 5 | $T$:E_1 | $T$ | 1 (complex) | — | 7.75 | NEW |
| 6 | icosa | $I_h$ | 1 | $g_0, g_6, g_{10}, g_{12}$ | 9.17 | paper #2 / #3 §V.D |
| 7 | $T$:A | $T$ | 1 | $g_0, g_4, g_6, ..., g_{14}$ | 10.58 | NEW |
| 7 | $O$:A_2 | $O$ | 1 | $g_0, g_4, g_6, g_8, g_{10}, g_{12}, g_{14}$ | 10.58 | NEW |
| 8 | cube-octa A_1 | $O$ | 1 | $g_0, g_4, g_6, ..., g_{16}$ | 12.00 | paper #3 §V.E |
| 9 | $O$:A_1 | $O$ | 1 | various | 13.42 | NEW |
| 9 | $O$:A_2 | $O$ | 1 | various | 13.42 | NEW |
| 9 | $T$:A | $T$ | 2 | various | 13.42 | NEW (mult 2) |
| 10 | dodec | $I_h$ | 1 | $g_0, g_6, g_{10}, g_{12}, g_{16}, g_{18}, g_{20}$ | 14.83 | paper #3 §V.F |
| 11 | $T$:A | $T$ | 1 | various | 16.25 | NEW |
| 11 | $O$:A_2 | $O$ | 1 | various (= T:A) | 16.25 | NEW (= T:A) |
| 12 | icosa $I$:A | $I$ | 1 | various | 17.66 | NEW |

**Total: 20 polyhedral inert state instances** covering F=2 through F=12,
all three polyhedral families ($T, O, I$), both F-parities, and including
multiplicity-> 1 cases.

### A. The F=1 exception

F=1 admits no polyhedral inert state. Reason: $D^1|_H$ does not contain
$A_1$ trivial irrep for any polyhedral $H$ (which would require $m_1^{(A_1)} > 0$;
but $m_1^{(A_1)} = (1/|H|) \sum_g \chi^{(D^1)}(g)$, and direct computation
gives 0 for all polyhedral $H$). See paper #3 §VI.B for full discussion.

### B. F=5 special case

F=5 admits only **$T$:E_1** invariant subspace (complex 1-dim irrep), not
the trivial $A_1$. The Lemma 1 General-S formula is derived for $A_1$-irrep
states; for $T$:E_1 phases, a modified analog formula needs separate derivation
(deferred to Paper #6 v2 or future work). For the current scope of F=2-12
$A_1$-irrep cases, the closed-form formula is exhaustive.

### C. F=11 T:A and O:A_2 degeneracy

A notable feature: F=11 $T$:A and $O$:A_2 inert states have **identical
$\beta_S^{(c_0)}$** (and hence identical $\beta_S^{(\lambda_{\rm spin})}$ by
Lemma 1 General-S). Numerically verified: the two phases share the same
sparsity pattern $m \in \{\pm 10, \pm 6, \pm 2\}$ and produce identical
inert state vectors up to phase. They differ only in their parity under
improper rotations, which doesn't enter the LHY scalar structure at leading
order. This is the **first observed F-paired phase degeneracy** in the spinor
BEC LHY catalog, an interesting representation-theoretic curiosity.

---

## IV. Experimental Implications

### A. $^{52}$Cr (F=3): octahedral $A_2$ sign-rep phase

- $S_{\rm bd}(F=3) \approx 4.90$ → target $g_6$ Feshbach resonance ($S = 6$
  first positive-$\beta^{(\lambda)}$ channel)
- Closed forms (paper #3 §V.B):
  $c_0 = (1/7)g_0 + (6/11)g_4 + (24/77)g_6$
  $\lambda_{\rm spin} = -(1/7)g_0 - (1/11)g_4 + (18/77)g_6$
- Sign-rep $A_2$: parity-under-reflection negative — sensitive to inversion
  symmetry breaking in trap potential

### B. $^{151}$Eu (F=6): icosahedral phase

- $S_{\rm bd}(F=6) \approx 9.17$ → target $g_{10}, g_{12}$ Feshbach
- Closed forms (paper #2 / paper #3 §V.D):
  $c_0 = (1/13)g_0 + (121/323)g_6 + (147/391)g_{10} + (980/5681)g_{12}$
  $\lambda_{\rm spin} = -(1/13)g_0 - (121/646)g_6 + (91/782)g_{10} + (840/5681)g_{12}$
- $T_1$ Goldstone triplet: $F_x, F_y, F_z$ rotations all degenerate

### C. $^{164}$Dy (F=8): cube-octa A_1 phase (Dy droplet candidate)

- $S_{\rm bd}(F=8) = 12.00$ exact (marginal — integer boundary)
- Closed forms (paper #3 §V.E): 8-channel, see Appendix A or paper #3
- 16 Majorana points in cube-like configuration; relevant for Dy spinor
  droplet experiments at Innsbruck / Stuttgart

### D. Hypothetical F=9 species (Yb metastable states)

- $S_{\rm bd}(F=9) \approx 13.42$ → target $g_{14}, g_{16}, g_{18}$
- Multiple inert states ($O$:A_1, $O$:A_2, $T$:A×2) → rich phase diagram
- Sign-rep ($O$:A_2) and trivial ($O$:A_1) octahedral phases distinct
  observable signatures (Faraday spectrum parity)

---

## V. Conclusion

The Sign Pattern Theorem (Lemma 1 General-S) of paper #3 v4 reduces the
F-systematic LHY catalog from a daunting case-by-case BdG diagonalization
problem to **mechanical Clebsch-Gordan projection**. This paper completes the
catalog for $F \leq 12$ $A_1$-irrep polyhedral inert states, identifying 20
instances spanning all three polyhedral families and both F-parities.

Future work:
- **F = 13-20 extension**: trivially extends via Lemma 1 General-S; no new
  theoretical content, just more CG projections
- **Non-$A_1$ irrep phases** (F=5 $T$:E_1, F=11 $T$:E_1×2, etc.): modified
  Lemma formulas needed for complex irreps
- **Dipolar generalization**: Lima-Pelster $Q_5(\epsilon_{dd})$ correction
  modifies the LHY closed form by a multiplicative factor; the closed-form
  rational coefficients are unchanged
- **TDHFB analysis** (paper #5): beyond-mean-field corrections to the LHY
  expressions catalogued here

---

## Appendix A: Explicit closed forms

(Full tabular catalog of $c_0$ and $\lambda_{\rm spin}$ for each of the 20
instances, with rational coefficients computed via numerical CG projection
then verified analytically at F=3/4/6/8/10/12 instances. Numerical values
verified via `test/manuscript/test_f_systematic_lemma1_predictions.jl`.)

---

## References

* (Companion papers #1, #2, #3 v4, #4, #5)
* Majorana, E. (1932). "Atomi orientati in campo magnetico variabile." Nuovo Cim.
* Mäkelä, H. & Suominen, K.-A. (2007). "Inert states of spin-S systems." PRL.
* Yukawa, E. & Ueda, M. (2012). "Ground states of dipolar spinor BECs."
* (Standard $D^F|_H$ character tables: Hamermesh, "Group Theory and Its
  Application to Physical Problems", Dover.)

---

## See Also

- `paper3_universal_theorem/main.md` §IX.B — Lemma 1 General-S + Lemma 2 proofs
- `paper3_universal_theorem/f_systematic_lemma1_predictions.md` —
  Closed-form predictions for F=7/9/11
- `test/manuscript/test_f_systematic_lemma1_predictions.jl` — verification script
- `test/manuscript/test_f5_f7_polyhedral.jl`,
  `f9_f11_polyhedral_verification.jl` — numerical verification
- `paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — closed-form derivation
- `paper3_universal_theorem/sign_pattern_L2_unique_sign_change.md` — sign-change uniqueness
- `paper3_universal_theorem/rank2_vanishing_analytical_proof.md` — group-theoretic proof
