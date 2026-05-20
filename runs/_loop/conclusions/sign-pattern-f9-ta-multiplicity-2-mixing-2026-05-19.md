# Conclusions index — sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19

Durable record of [Established] / [Plausible] / falsifier-tested claims for this investigation.
Director reads this before dispatching next subagent so claims aren't re-derived.

### T114 [Established] 2026-05-19T05:37:33.250608+09:00

[Established] `find_invariant_vector` (script lines 164–174) seeds with **one** random Gaussian vector $v \sim \mathcal{N}(0, I_D)$ (seed 1 by default since the loop `for seed in 1:max_seeds` returns on the first successful `P*v`), then computes $\zeta = P v$, normalizes to unit …

### T114 [Established] 2026-05-19T05:37:33.250608+09:00

[Established] The numerical evidence corroborates this: `f9_f11_verification_result.md` line 14 reports Schur isotropy deviation `6.04e-14` (≈ machine precision) for the random representative, which means **the specific random pick happened to be very close to Schur-isotropic**, …

### T114 [Established] 2026-05-19T05:37:33.250608+09:00

[Established] + 5 [Plausible] + 1 [Speculative]
- §5 Open questions: 3 falsifier definitions (F1 central, F2 advisory, F3 mult-1-regression) + 2 RESEARCH_NEEDED items (F=11 T:E_1 mult-2 construction; F=12 multiplicity audit)
- §6 Directive for imp

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] The 2e-4 residual rather than an O(1) deviation suggests that **most** unit vectors in the 2-dim invariant subspace are "close to" the canonical Schur-isotropic representative. Seed 1 (`Random.seed!(1)`) happened to produce a $\zeta$ that has $\beta_0 = 0.0524$ vs the…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] Replace the rank-1 outer product $\zeta \otimes \zeta$ with the **projector onto the 2-dim invariant subspace**, divided by its dimension (so it has unit trace per dim):
$$\hat{P}_{\rm inv} = \zeta_1 \zeta_1^\dagger + \zeta_2 \zeta_2^\dagger, \qquad \rho_{\rm inv} = \…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] By Schur's lemma applied to the **2-dim trivial-irrep multiplicity space** (which carries a trivial action of $H$, since both basis vectors are $H$-invariant), the average $\rho_{\rm inv} = \tfrac{1}{2}(|\zeta_1\rangle\langle\zeta_1| + |\zeta_2\rangle\langle\zeta_2|)$…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] Predicted endpoint: at $S=0$, using that $|0,0\rangle$ is the unique $SU(2)$-singlet:
$$\bar{\beta}_0^{(c_0)} = \mathrm{Tr}\!\left[ |0,0\rangle\langle 0,0| \cdot (\rho_{\rm inv} \otimes \rho_{\rm inv}) \right] = \langle 0,0 | \rho_{\rm inv} \otimes \rho_{\rm inv} | 0,…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] Pick the orthonormal basis $\{\zeta_1, \zeta_2\}$ such that each individual $\zeta_i$ satisfies Schur isotropy $\langle \zeta_i | F_a^2 | \zeta_i\rangle = F(F+1)/3$ AND $\langle \zeta_i | F_a F_b | \zeta_i\rangle = 0$ for $a \neq b$. Existence: such a basis exists bec…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] **Yes, in the sense that both predict $\beta_0 = 1/(2F+1)$ exactly**, but they are NOT computing the same quantity:
- §2.A computes a **scalar averaged over the multiplicity space** — a density-matrix quantity.
- §2.B picks a **single representative vector** that sati…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] The §2.A multiplicity-aware formula reduces to the mult-1 formula automatically: when $\dim \mathrm{Im}(P_{H, \rm irrep}) = 1$, $\rho_{\rm inv} = |\zeta\rangle\langle\zeta|$ is rank-1 and $\rho_{\rm inv} \otimes \rho_{\rm inv} = (\zeta \otimes \zeta)(\zeta \otimes \ze…

### T114 [Plausible] 2026-05-19T05:37:33.250608+09:00

[Plausible] + 1 [Speculative]
- §5 Open questions: 3 falsifier definitions (F1 central, F2 advisory, F3 mult-1-regression) + 2 RESEARCH_NEEDED items (F=11 T:E_1 mult-2 construction; F=12 multiplicity audit)
- §6 Directive for imp

### T114 [Falsifier-tested: F1-multiplicity-aware-schur-restoration-recovers-machine-precision] 2026-05-19T05:37:33.250608+09:00

PENDING (T114 only declares falsifier contract; actual test runs at next Execute stage)

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible]`-tagged mechanism: at the orthogonal SVD basis of the 2-dim T:A
invariant subspace, off-diagonal singlet overlaps `<0,0|zeta_i⊗zeta_j>` (i≠j)
vanish, while diagonals each give 1/(2F+1), yielding `(1/4)(2·1/19 + 2·0) = 1/38`.

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible] — verified empirically at F=9 T:A and mult-1 cases, but not rigorously proven for general (F, H, α).**

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible] The formula $\|(P_W\otimes P_W)|0,0\rangle\|^2 = m_{\rm rep}/(2F+1)$ holds for all polyhedral inert states with $H \in \{T,O,I\}$ and $J\in H$.

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible] The TRUE structural identity is the U(2)-invariant total $\|(P_W\otimes P_W)|0,0\rangle\|^2 = m_{\rm rep}/(2F+1)$. Candidate (i) ($m_{\rm rep}\cdot \mathrm{Tr}[\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$) extracts this identity via the trace, and is basis-independent…

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible] based on F=9 T:A empirical + mult-1 cases. For full rigor, need either character-theoretic computation or independent test at a non-trivial irrep (e.g., F=11 T:E_1 once complex-1-dim → 2-dim-real construction settled, or F=12 polyhedral audit). >`

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible] but not rigorously proven. Empirically verified at F=9 T:A and all mult-1 cases. General proof requires character-theoretic computation of trivial-pairing overlap in each isotypic block. T117+ research item."
  ],
  "falsification_result": "NOT_APPLICABLE",
  "tokens_…

### T115 [Plausible] 2026-05-19T06:38:28.866510+09:00

[Plausible] isotypic-allocation conjecture `||xi_alpha||^2 = m_alpha · d_alpha / (2F+1)` is empirically confirmed at α=A (trivial, d_A=1, m_A=2) at F=9 T. Future verification at non-trivial irreps (F=11 T:E_1 m_rep=2, F=12 polyhedral) is theorist's `<RESEARCH_NEEDED: isotypic-all…

### T115 [Falsifier-tested: F1-multiplicity-aware-formula-revised-with-mrep-prefactor] 2026-05-19T06:38:28.866510+09:00

THEORIST RE-DERIVATION COMPLETE: recommended Candidate = {candidate_id}; predicted bar_beta_0 at F=9 T:A = {value}; F1 falsifier formula for T116 implementer Test = {formula}; m_rep=1 reduction verified; sum rule = {sum_rule_value}; off-diagonal singlet overlap audit verdict = {audit_verdict}.

### T116 [Falsifier-tested: F1-mult-aware-bar_beta_0-equals-1-over-2F-plus-1] 2026-05-19T07:06:34.755610+09:00

CORROBORATE registered in state.json: bar_beta_0_canonical = 0.0526315789473683 = 1/19; dev_from_1/(2F+1) = 1.388e-16; theorist J-involution derivation + 4-falsifier confirmation propagated to manuscript §V at docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md + memory at memory/sign_pattern_lemma1_mult_aware_2026_05_19.md.

### T120 [Falsifier-tested: F1-mult-aware-bar_beta_0-equals-1-over-2F-plus-1] 2026-05-19T08:39:09.929189+09:00

TIER_3_TERMINAL_CLOSURE: T119 critic Stage-2 CORROBORATE 5/5 deliverables (A1 Schur canonical formula re-derived, A2 J-involution endpoint proof tightened to one-line Tr(P_W^2)/(2F+1) = m_rep/(2F+1), A3 Hamermesh orbit-counting m_rep = (1/12)(19+8-3) = 2 exact, A4 1.388e-16 = 2 ULP rounding-only, A5 algebraic sum-rule + m_rep=1 strict reduction); T115 Stage-1 4/4 falsifier machine-precision corroboration retained. 5th project Tier-3 trajectory closure.

