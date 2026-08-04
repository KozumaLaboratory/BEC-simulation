# D 論 Year 1 roadmap (post-修論, ~12 ヶ月 plan)

> **FROZEN 2026-05-23.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Date**: 2026-05-11
**Status**: forward-looking plan; assumes 修論 defense 2026-12, D-thesis Year 1 starts
~2027-04 (academic year boundary).

---

## 1. Year 1 strategic objective

Year 1 で 修論本体 4 papers の **submission + review process completion** + **D 論
framework extension foundation** を確立する。3 main research thrusts:

A. **Universal Theorem extension**: paper3 v3 (5 cases) → paper3 v4 (全 polyhedral
   coverage + Sign Pattern rigorous proof attempt)
B. **TDHFB pilot launch**: Chapter 5 §5.8 / `tdhfb_pilot_design.md` の 7-week implementation
C. **D-thesis Ch.3 (integrator modernization)**: 修論期間の Track A1/C/B work を
   independent D-thesis 章 + post-修論 paper として展開

---

## 2. Quarter-by-quarter milestones

### Q1 (2027-04 to 2027-06): paper submission + D-thesis framework

**Papers**:
- Paper #1 (F=2 cyclic LHY) PRA submission with cover letter + supplementary
- Paper #2 (F=6 icosahedral LHY) PRA / PRR submission
- arXiv pre-prints public
- Cover letter drafts for #3, #4

**D-thesis**:
- Ch.3 integrator modernization full chapter draft (~80 pages, based on
  `docs/design/integrator_track_*` series)
- Track A1 Y4-midpoint paper #5 candidate prep (CPC target)

**Code**:
- SpinorBEC.jl v1.0 tagged release (= 修論 publication snapshot)
- Reproducibility verification by external collaborator (上妻研 or other)

### Q2 (2027-07 to 2027-09): paper3 v4 + Sign Pattern proof — **CLOSED AHEAD OF SCHEDULE (2026-05-11)**

**Sign Pattern Theorem (Lemma 1 General-S + Lemma 2 unique sign change) — PROVED**:

The Q2 milestone goal was rigorous proof of the Sign Pattern Anomalous Identity.
**Achieved 2026-05-11** (commits 330e73a → 05de2ef, 5 commits during 2026-05-11
autonomous loop session):

- **Lemma 1 General-S CLOSED FORM** (`sign_pattern_lemma1_general_S.md`):
  $\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2 F(F+1)} \beta_S^{(c_0)}$
  for all $A_1$-irrep polyhedral inert states.
- **Lemma 2 unique sign change PROVED** (`sign_pattern_L2_unique_sign_change.md`):
  corollary of Lemma 1; sign-change boundary $S_{\rm bd}(F) = \sqrt{2F(F+1)} \approx \sqrt{2} F$
  (NOT $2F$ as empirical Ch.6 §6.10 estimate).
- **Rank-2 cross-channel vanishing RIGOROUSLY PROVED**
  (`rank2_vanishing_analytical_proof.md`):
  $m_2^{(A_1)}(H) = (1/|H|) \sum_g \chi^{(D^2)}(g) = 0$ for all polyhedral $H$
  by direct character computation. Therefore $H$-symmetrization kills the rank-2
  contribution, completing the proof.

Verification artifacts:
- 26 channel coefficients matched at exact rational arithmetic (5 cases F=3/4/6/8/10)
- 4 operator-level rank-2 vanishing tests at machine precision (F=3, 4, 6, 8)
- F=2 cyclic + F=1 polar bonus matches
- 6 F-systematic Lemma 1 predictions extending paper3 §V from 5 to 11 cases

**Paper #3 v4 deliverable** — main.md §IX.B rewrite COMPLETE (commits c48d176, 05de2ef):
- Lemma 1 General-S + Lemma 2 stated as proved theorems (not conjectures)
- $S_{\rm bd} = \sqrt{2 F(F+1)}$ instead of empirical $2F$
- Physical interpretation: ratio = two-body spin-spin correlation
- Feshbach engineering recipe updated with corrected boundary

**Remaining Q2 items** (deferred or de-scoped):
- ~~F=12 closed-form derivation (sympy)~~ — Lemma 1 General-S makes this trivial
  if $\beta_S^{(c_0)}$ values are known. Detailed F=12 rational coefficients can
  follow Q3 via mechanical CG projection.
- ~~F=3 A_2 convention fix~~ — Empirical match exact at F=3 octa A_2; the earlier
  "one-step offset" was a script normalization issue, not a true offset.

**Q2 outcome**: paper3 v3 → v4 ready for submission to PRX (vs v3's PRR target —
stronger result). The Sign Pattern Theorem upgrade from conjecture to theorem
constitutes a major contribution.

### Q3 (2027-10 to 2027-12): F-systematic completion + TDHFB pilot

**F-systematic odd-F completion**:
- F=5 $T$:E_1 polyhedral inert state construction + LHY closed form
- F=7 $T$:A, $T$:E_1, $O$:A_2 inert states (Cr-related)
- F=9 $T$:A×2, $T$:E_1, $O$:A_1, $O$:A_2 inert states
- F=11 $T$:A, $T$:E_1×2, $O$:A_2 inert states

Each F instance:
- Spinor explicit construction (Majorana points + sympy CG)
- Schur isotropy + selection rule verification
- Closed forms for $c_0, \lambda_{\rm spin}$ via sympy
- Sign Pattern check (= Anomalous Identity F-coverage)

**Paper from F-systematic** (post-modal phys):
- Title: "F-systematic Universal Theorem completion for spinor BEC polyhedral phases"
- Target: PRR / Phys. Rev. Research
- Length: ~12-14 pages
- Co-author with parallel session (Round 4/5 collaborator)

**TDHFB pilot Phase 1-3**:
- Phase 1 (1 week): TDHFBState type + storage layout
- Phase 2 (2 weeks): HF / condensate / normal / anomalous kernels
- Phase 3 (1 week): Strang TDHFB integrator
- Initial Eu post-quench TDHFB test at 16³ (small to start)

### Q4 (2028-01 to 2028-03): TDHFB production + D-thesis Ch.4 draft

**TDHFB Phase 4-6**:
- Phase 4 (1 week): YAML pipeline integration
- Phase 5 (1 week): TWA-TDHFB comparison + validation
- Phase 6 (1 week): Eu post-quench production runs at 32³

**TDHFB findings**:
- Scenario A/B/C identification (stabilize / renormalize / breakdown)
- σ/μ_TDHFB vs σ/μ_TWA comparison plot
- Lyapunov rate measurement (chaos quantification)

**Paper #5 (TDHFB, PRA/PRR target)**:
- Title: "TDHFB analysis of post-quench dipolar instability in F=6 spinor BEC"
- Length: ~10-12 pages
- Submission target: end of Year 1

**D-thesis Ch.4 (beyond-mean-field methods)**:
- TWA review (= 修論 Ch.5 inline)
- TDHFB formalism + Eu post-quench results
- Beliaev formalism (analytical for uniform polyhedral)
- Comparison + applicability boundaries

---

## 3. Publication targets (Year 1 cumulative)

By end of Year 1 (2028-04):

| # | Title | Target | Status |
|---|---|---|---|
| 1 | F=2 cyclic LHY closed form | PRA | Submitted Q1, expect review |
| 2 | F=6 icosahedral LHY closed form | PRA / PRR | Submitted Q1 |
| 3 v3 → v4 | Universal Theorem (full + Sign Pattern) | PRR → PRX | Resubmit Q2 |
| 4 | TWA chaotic dipolar dynamics | PRR | Submitted Q1 |
| 5 (NEW) | TDHFB analysis of Eu post-quench | PRA / PRR | Submit Q4 |
| 6 (NEW) | F-systematic Universal Theorem completion | PRR | Submit Q3 |
| 7 (NEW) | Integrator modernization (Y4-mid Track A1) | CPC | Submit Q1-Q2 |

7 papers total over Year 1. Aggressive but tractable with:
- 修論本体 4 papers nearly submission-ready already (= Q1 push)
- 2 new papers (TDHFB + F-systematic) developed in Q2-Q4
- 1 paper (integrator) splits from D-thesis Ch.3 work

---

## 4. Research thrust details

### 4.1 Sign Pattern Anomalous Identity proof — Q2 deep dive

Current state: empirical identity verified at 4/5 paper3 cases ($A_1$). F=3 A_2 one-step
offset. β_0, β_{2F} endpoint lemmas proven.

**Q2 work plan**:

**Week 1-2**: Strategy A Layer L1 (algebraic decomposition)
- BdG matrix algebra for spin Goldstone stiffness
- Wigner-Eckart application: $\langle (FF) S' M' | F_a^{(1)} | (FF) S M\rangle$
  via 6j-symbol + CG
- Identify which 6j-symbol products appear in $\beta_S^{\lambda_{\rm spin}}$ formula

**Week 3-4**: Strategy A Layer L2 (single sign change)
- Spectral analysis of $X_S^{(\rm anom)}$ as function of $S$
- Use generic polyhedrally inert spinor structure (sparse support, ⟨F⟩=0)
- Try to show: $X_S^{(\rm anom)} < 0$ for $S < S_{\rm bd}$, $> 0$ for $S \geq S_{\rm bd}$,
  with $S_{\rm bd}$ depending on polyhedral group + $F$

**Week 5-6**: F=3 A_2 sign convention
- Carefully track parity factors in BdG matrix elements
- Derive correct Identity formula for A_2 states
- Verify F=3 A_2 then re-check 4 A_1 cases

**Week 7-8**: F=12 sympy closed form derivation
- Sympy setup for D=25 spinors + 50×50 BdG
- Numerical-exact rational symbolic computation
- Output: $c_0^{F=12, I_h}, \lambda_{\rm spin}^{F=12, I_h}$ as $\sum_S \beta_S g_S$
- Test Anomalous Identity + Sign Pattern conjecture at F=12

**Week 9-12**: Paper #3 v4 manuscript revision
- Insert proofs into §IX.B
- Add F=12 to §V.G as 3rd icosahedral case (after F=6, F=10)
- Address potential reviewer questions on Sign Pattern + Universal Theorem F-scope
- Final figures + supplementary material

### 4.2 TDHFB pilot — Q3-Q4 implementation

Per `docs/design/tdhfb_pilot_design.md`:

**Phase 1 (Q3 Week 1)**: TDHFBState struct + memory layout
- New types/tdhfb_state.jl with phi, rho, kappa arrays
- Generic over (N, D) (N spatial dims, D spinor components)
- Compatible with existing SpinorBEC.Workspace pipeline

**Phase 2 (Q3 Week 2-3)**: TDHFB kernels
- Hartree-Fock matrix construction from (phi, rho, kappa)
- Condensate / normal / anomalous evolution kernels
- FFT-based kinetic + matrix-multiplied potential

**Phase 3 (Q3 Week 4)**: Strang TDHFB integrator
- 2nd-order Strang split for TDHFB
- (Future) Y4-midpoint TDHFB integrator (= same Y4 framework from D-thesis Ch.3)

**Phase 4 (Q4 Week 1)**: YAML pipeline integration
- New `dynamics: tdhfb: {enabled: true, ...}` knob
- Coupled with existing `dynamics:` knobs (TWA, SGPE, etc.)

**Phase 5 (Q4 Week 2)**: TWA-TDHFB comparison validation
- Run same Eu post-quench config under both TWA + TDHFB
- Verify particle conservation + energy conservation
- Compare σ/μ_TWA vs σ_TDHFB / |φ_TDHFB|

**Phase 6 (Q4 Week 3-4)**: Eu production runs
- 32³ Eu post-quench at marginal collapse
- Determine which scenario (A/B/C) realizes
- Publication-ready figures + tables

### 4.3 D-thesis Ch.3 integrator modernization — Q1 + ongoing

修論期間 Track A1/C/B work (commits 98213f6 → de0b51e, 10 commits) は post-修論 D-thesis
Ch.3 として展開:

- **Ch.3 §3.1-§3.2**: Frozen-MF Strang failure + Track A1 midpoint resurrection
- **Ch.3 §3.3-§3.4**: MPS-{4,6} Richardson failure analysis
- **Ch.3 §3.5-§3.6**: Track C Force-Gradient v4/v5 (spinor matrix + DDI)
- **Ch.3 §3.7**: State-averaging generic failure theorem
- **Ch.3 §3.8**: Comparison + practical optimum (Y4-mid)

各 § は modular で paper #7 (CPC target) として extraction 可能。

---

## 5. Risks + mitigations

### Risk 1: paper3 v4 Sign Pattern proof doesn't close

If Strategy A Layer L1 + L2 don't produce rigorous proof in Q2, escalate:
- **Mitigation A**: submit paper3 v4 as "empirical conjecture + endpoint lemmas +
  Anomalous Identity numerical evidence" — Already a strong result vs v3
- **Mitigation B**: collaborate with Wigner-Eckart specialist (formal group theory
  expert) for Q2 deep-dive

### Risk 2: TDHFB pilot doesn't converge in chaotic regime

If TDHFB blows up at Eu post-quench (Scenario C, `tdhfb_pilot_design.md` Risk 1):
- **Mitigation**: pivot Paper #5 to "TDHFB breakdown criterion in chaotic dipolar
  regimes" — Still publishable as negative result + methodology contribution

### Risk 3: F-systematic completion incomplete

If F=5/7/9/11 closed-form derivations exceed Q3 budget:
- **Mitigation**: split into Q3 (F=5, 7) + Q4 (F=9, 11), defer one F to D 論 Year 2 if necessary

### Risk 4: 修論 review delays Q1 paper submissions

If 内部/教員 review of 修論 papers extends to Q2:
- **Mitigation**: parallelize — paper #1/#2 submission Q1, paper #3/#4 Q2, paper #5/#6 Q4

---

## 6. Year 1 success criteria

End of Year 1 (2028-04) success metrics:

- [ ] 6-7 papers submitted (4 from 修論 + 2-3 new D-thesis-era)
- [ ] paper3 Sign Pattern proof completed OR formal partial result
- [ ] TDHFB pilot first results (Scenario A/B/C identified)
- [ ] D-thesis Ch.3 + Ch.4 draft complete
- [ ] F-systematic odd-F coverage F=5, 7, 9, 11 at least 2 instances done
- [ ] SpinorBEC.jl v1.0 tagged + external collaborator reproducibility verified
- [ ] At least 1 conference presentation (March Meeting 2028 / DAMOP 2027-06)

Quantitative target: 6+ papers submitted, 2+ accepted by end of Year 1.

---

## 7. Year 2-3 preview

Year 2 (2028-04 to 2029-04):
- Beliaev formalism for uniform polyhedral phases (analytical)
- Multi-species (binary) BEC extension (Y4-midpoint baseline)
- Dipolar generalization (Lima-Pelster $Q_5$) for polyhedral
- Eu droplet realization prediction + 上妻研 experimental collaboration

Year 3 (2029-04 to 2030-04):
- Experimental synthesis (single-shot imaging vs σ/μ chaos)
- Innsbruck Dy spinor droplet collaboration
- D 論 finalization + defense
- 5-7 more papers from D 論期 work

Total D 論期 publication target: 12-15 papers across 3 years.

---

## 8. Funding + resource considerations

### Computational
- GPU access: TSUBAME 4.0 continued (modestly upgraded with newer GPU at 24 GB?)
- SpinorBEC.jl infrastructure: stable, occasional bug fixes
- TDHFB additional memory: ~500 MB GPU per config × ~20 configs in parallel queue

### Travel
- DAMOP 2027 (June 2027), 2028 (June 2028) — present TWA chaos + Universal Theorem
- March Meeting 2028, 2029 — D 論 results
- DPC (Tokyo) 2027, 2028, 2029 — 上妻研 + 国内 community

### Collaborations
- 上妻研 (東大): Eu spinor BEC experimental data + post-quench imaging
- Stuttgart (Pfau group): Cr spinor BEC + dipolar droplet
- Innsbruck (Ferlaino group): Dy spinor + Feshbach $a_S$ measurements
- 並列セッション (paper3 round 4/5 collaborator): Universal Theorem v4 + F-systematic

---

## 9. Year 1 immediate action items (post-修論 defense, ~2027-01)

- [ ] Set up D 論 advisor meeting cadence (weekly / biweekly)
- [ ] Establish workflow for parallel paper submission tracking
- [ ] Provision LaTeX + bibliography infrastructure (`submission_packaging.md`)
- [ ] Recruit TDHFB implementation collaborator (if needed)
- [ ] Set up F-systematic odd-F task tracking
- [ ] Confirm 上妻研 collaboration MOU + data sharing agreement

---

## 10. Connection to 修論 results

This Year 1 roadmap is **directly downstream** from 修論 results:

| 修論結果 | Year 1 follow-up |
|---|---|
| Ch.3 F=2 cyclic [Paper #1] | Submission Q1 |
| Ch.4 Universal Theorem [Paper #3 v3] | Paper #3 v4 (Q2) + F=12 + Sign Pattern proof |
| Ch.5 TWA chaos [Paper #4] | Submission Q1 + TDHFB pilot (Q3-Q4) |
| Ch.6 polyhedral verifications [Paper #2 + extras] | Submission Q1 |
| Appendix A audit framework | F-systematic extension (Q3) |
| Verify-first methodology | Continued application Year 1+ |
| D 論 Ch.3 integrator (Track A1/C/B) | Standalone paper (Q1-Q2) |
| `tdhfb_pilot_design.md` | Implementation Q3-Q4 |
| `sign_pattern_strategy_A.md` | Layer L1/L2 proof attempt (Q2) |

修論 → D 論 Year 1 transition は **seamless**、各 修論本体 chapter / appendix が
具体的 Year 1 work item に直接対応。

---

(dthesis_year1_roadmap.md 終了)
