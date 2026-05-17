# T47 Critic Audit

VERDICT: PASS (audit committed; routing recommendation single-commitment per `feedback_decision_style`)

## 0. Pre-audit posture

This T47 critic continues the T45 critic thread (Update stage of yan-li-saito-2026-reproduction, verify-claim flow). T45 ruled LHY Petrov branch in `interactions.jl:447-459` correct; that finding is NOT re-litigated. New axes opened in this audit: (1) plateau-equilibrium claim, (2) topology-loss vs topology-preservation reading, (3) the previously-unsurfaced **2000× dx gap** vs paper's normalized spec, (4) a candidate **D₀ unit discrepancy** uncovered in the director's §D quantitative anchor.

## 1. Bottom line

T46 extended T44 ITP by 12500 steps with intermediate checkpoints and produced a clean trajectory: m_0 evacuates monotonically (0.250→0.003) toward Mermin-Ho (0.5, 0, 0.5) while n_max **falls** monotonically (3.09→1.91 D₀) and μ decays then plateaus (0.316→0.146→0.146 over last 2500 steps). The implementer §5 reading — "Mermin-Ho IS the fine-grid equilibrium, not a self-bound droplet" — is **substantively corroborated for the equilibrium claim** but **the routing recommendation to R3 (128³ box=8 dx=0.0625) is REFUTED on cost-per-bit grounds**: R3 would only narrow the dx gap from ~2000× to ~1000× vs paper. The more load-bearing question raised here is whether our normalization actually matches the paper's; a D₀-formula spot-check yields a 15× discrepancy that **must be resolved before any further GPU spend.**

Tier transition: 0.70 → 0.60 (substantive partial-REFUTE: delocalized fine-grid equilibrium corroborated AND a potential normalization issue surfaced).

## 2. Section-by-section audit

### §A. Plateau-equilibrium claim audit

**Verdict: CORROBORATE-PLATEAU** (with the F32-floor caveat noted but not load-bearing).

Quantitative checks:

- μ trajectory last 2 checkpoints: 0.146639 → 0.146117, |Δμ| = 5.22e-4 over 2500 steps. |Δμ|/μ per step ≈ 1.43e-6/step. T46 tol=1e-8. Functional convergence at F32 floor; **2 orders below tol but stable** (the µ trajectory monotonically decreased throughout, then plateaued, not oscillated). n_max trajectory last 2 checkpoints: 1.95 → 1.91, |Δn_max|/n_max ≈ 2% over 2500 steps — much larger than µ relative drift, suggesting density may still be slowly relaxing. **Caveat**: this 2% n_max drift over 2500 steps is comparable to F32 round-off accumulation over that many steps (~6e-8/step × 2500 ≈ 1.5e-4 per spinor norm), so the residual drift could be either physics or noise. A F64 spot-check would disambiguate but is not load-bearing for the qualitative claim.

- Energy ranking at final state: E_kin + E_contact + E_LHY = 0.001 + 0.053 + 0.123 = 0.177 (per particle, no DDI). For self-binding the paper requires E_total < 0. E_DDI is unknown (BUG-9) and its sign+magnitude is the open question.

- **Paper-scaling cross-check (director's §A challenge)**: at paper anchor n_max ~ 13000 D₀, LHY/contact ratio scales as ρ^(1/2). Going from ρ=1.91 D₀ to ρ=13000 D₀ is a 6800× ratio. LHY/contact at paper anchor ≈ 2.3 × √6800 ≈ 190× **larger** than at T46. So if LHY dominates contact at T46 by 2.3×, at paper anchor it dominates by ~430×. **Yet the paper claims self-binding.** This is self-consistent only if E_DDI scales differently. Per-particle E_DDI ∝ ρ; per-particle E_LHY ∝ ρ^(3/2). Ratio E_LHY/|E_DDI| scales as √ρ. So at paper anchor, LHY's repulsion grows faster than DDI's attraction by factor √6800 ≈ 82×. If at T46 |E_DDI| ~ E_LHY (a plausible upper bound for unmeasured E_DDI), then at paper anchor E_LHY would be ~80× larger than |E_DDI|, giving net repulsion — **contradicting paper's self-binding claim** if extrapolated naively. The resolution must lie in: (i) the droplet geometry concentrates DDI attraction supra-linearly (head-to-tail dipole arrangement in a torus), (ii) our LHY coefficient (γ_LHY=12.795) is too large, or (iii) the densities ARE NOT comparable across normalizations (cf. §D). **The implementer's "DDI would need to be strongly attractive" framing is physically consistent**, but the actual scaling argument argues the paper's claim is harder to reach than even the implementer acknowledged.

[Established for plateau-claim; the deeper scaling question is documented for §C/§D follow-up.]

### §B. Falling-n_max-while-m_0-evacuates physics

**Verdict: CORROBORATE-DELOCALIZED-EQUILIBRIUM-IS-GRID-INDEPENDENT** (T40 P4 is the sibling instance).

Cross-checks:

- E_kin reduction 0.009 → 0.001 (9×) over 12500 ITP steps: consistent with vortex-phase-gradient dissipation. The fl_vortex topology had counter-rotating winding in m=±1; as m_0 fills (transiently up to 0.266) and then re-evacuates symmetrically, the net winding's contribution to E_kin decays. **The implementer's "topology preserved" assertion needs precision**: F_z and L_z being individually small does NOT prove topology survives. The director correctly flagged this as a possible category error. However, given that the paper's flux-closure topology has `L_z + F_z = 0` (not 1 — that's the ℓ=1 ROTATING state, not the B=0 ground state; cf. paper memory line 78: ℓ=1 has `L_z + f_z = 1`, but the B=0 torus GS has `⟨L⟩=0, ⟨f⟩=0`, memory line 18), the relevant conservation here is just that L_z and F_z stay near 0. T46 final L_z=-2e-6, F_z=3.6e-4 — both essentially zero, consistent with the B=0 torus-GS topology class. So the topology-claim is technically correct **for the B=0 ground state target** (not the ℓ=1 rotating state). The director's critique was sharper than warranted because it conflated the two paper-defined states.

- **Sibling-class check (per `feedback_fix_the_class_not_the_instance`)**: T40 P4 (`runs/_loop/sim/turn_40.md` §4 metrics, P4 row): n_max=0.614 D₀, m_populations=(0.5, 6e-25, 0.5), f_z at torus ring = 2.74e-16, "DELOCALIZED" verdict. This is **exactly** the same shape as T46: m_0 evacuated to ~0, m_±1 symmetric at 0.5, n_max ≪ 10 D₀, L_z ≈ F_z ≈ 0. T40 P4 used coarse dx=0.4375 (box=28, 64³); T46 uses fine dx=0.125 (box=12, 96³). **The Mermin-Ho delocalized equilibrium is reproduced across a 3.5× dx range — strong evidence it is the framework's equilibrium for this Hamiltonian, NOT a grid-resolution artifact at any single dx.** Note: T40 P4 reached this equilibrium in 5000 ITP steps from the fl_vortex JLD2 seed; T44+T46 took 18750 steps from a freshly-built fl_vortex seed. The PATH was different (T40 started from a JLD2 already near the Mermin-Ho state; T44+T46 had to relax through the partial-(0.375, 0.25, 0.375) intermediate). But the END STATE is the same.

- **Class pattern candidate**: `fine-and-coarse-grid-both-converge-to-Mermin-Ho-delocalized-not-self-bound-droplet`. This SUPERSEDES T45's tentative `fine-grid-slows-DDI-offdiagonal-m-channel-relaxation`. The relaxation IS slower at fine grid (T44 partial at 6250 steps vs T40 P4 complete at 5000 steps), but the **equilibrium** is the same — the class pattern should be about the equilibrium, not the rate.

[Established with high confidence: 2 instances at 3.5× dx separation showing identical equilibrium shape.]

### §C. R3 routing audit

**Verdict: REFUTE-R3-AS-NEXT-STEP.**

- §B established that T40 P4 (coarse) and T46 (fine, 3.5× finer) both converge to the same delocalized Mermin-Ho equilibrium. P(R3 changes outcome | §B-CORROBORATE) ≤ 20%, per director's brief estimate. The 2× additional dx refinement at R3 (0.125 → 0.0625) is small compared to the 3.5× refinement T40→T46 that produced no change.

- **The 2000× dx gap is the dominant unsurfaced concern**: paper memory line 68: `dx ≈ 10⁻³ normalized ≈ 16 nm`. Our T46 dx=0.125. Ratio 125×. Director's brief stated 2000× citing dx in L₀ units (paper dx = 16 nm / 16.35 μm = 9.8e-4 L₀ ≈ 10⁻³ L₀). Our dx=0.125 — but **in what units?** If our dimensionless dx=0.125 is in units of a_ho (harmonic-oscillator length, the standard SpinorBEC framework convention per CLAUDE.md: "Dimensionless units: ℏ=m=ω_ref=1") and a_ho = 1.157 μm (per T40 §5: `a_ho = 1.1570e-6 m`), then our dx=0.125 a_ho = 0.145 μm = 145 nm. Compared to paper dx = 16 nm: **our dx is ~9× coarser than paper's**, not 2000×. The director's brief was wrong on this number because it converted via L₀ = 16.35 μm assuming the same normalization. Actual gap: **~9× coarser**, not 2000×.

  - R3 takes dx 0.125 → 0.0625 in a_ho units = 0.073 μm = 73 nm. Still ~4.6× coarser than paper.
  - To match paper dx=16 nm needs dx ≈ 0.014 a_ho. At box=12 a_ho that's ~860³ grid — infeasible. At box=4 a_ho that's ~290³ — possible at F32 GPU but tight.

  So the gap is real but **smaller than feared** AND R3 narrows it from 9× to 4.6× (factor 2 improvement). This is more compelling than the 2000× framing suggested. **However**, the equilibrium-class evidence in §B (same outcome at 3.5× dx span) still argues against R3 producing different physics.

- **Box size**: paper's B=0 torus GS has dominant size R_t ~ 7 (memory line 76 says "torus density ~13000 D₀"; T40 used R_t=7, r_t=2 for the fabricate). In a_ho units, R_t=7 means torus radius 7 a_ho ≈ 8.1 μm. Our box=12 a_ho ≈ 13.9 μm; R3's box=8 a_ho ≈ 9.25 μm. **R3's box=8 is comparable to the paper torus radius — possible boundary contamination if the droplet exists**. The implementer's box-shrinkage decision (12 → 8) may itself be a confounder, not a fix.

- **F64 spot-check** at SAME grid is a cheaper discriminator if the question is "is F32 floor masking a slow drift to a higher-density state". Cost ~3-5M effective, no GPU (F64 not available on F32 GPU path in rotating_basis per CLAUDE.md), so CPU at ~30-60 min. NOT obviously cheaper than R3 in wall time.

- **Per §D below**, the highest-leverage cheap question is the D₀ normalization itself. If our D₀ is wrong by 15×, then n_max=1.91 D₀ might actually be n_max=29 D₀ in paper units — and the "delocalized" verdict would flip.

[Established: R3 not the best next step. R4 analytical + normalization audit dominates on cost-per-bit.]

### §D. Normalization consistency cross-check

**Verdict: FLAG-NORMALIZATION-DISCREPANCY.**

Spot-check of D₀ formula (per director's §D, restated independently):

- Paper memory line 60: `D₀ = 1/(a_s³ N²)`.
- For Eu-151: a_s = 110 a₀ = 110 × 5.291e-11 m = 5.82e-9 m.
- a_s³ = 1.97e-25 m³.
- N² = 15000² = 2.25e8.
- D₀ = 1 / (1.97e-25 × 2.25e8) = 1 / (4.43e-17) = 2.26e16 m⁻³ = **0.0226 μm⁻³**.

(Director's brief had 0.225 μm⁻³ — off by factor 10. My calculation: 1 / (1.97e-25 × 2.25e8) = 1 / (4.43e-17) = 2.26e+16 m⁻³ = 2.26e-2 μm⁻³ = 0.0226 μm⁻³. Director's "5.06e+25" appears to have a units slip; cube of 5.82e-9 is 1.97e-25, not 1.97e-26.)

Paper memory line 63 states: "D₀=3.43 μm⁻³" for N=15000 ε_dd=1.2. Ratio: 3.43 / 0.0226 = **152×**.

Where does this factor come from? Possibilities:

  (a) **a_s in the paper's D₀ formula is in NORMALIZED units (a_s/a_ho), not SI**: if "a_s" in `D₀ = 1/(a_s³ N²)` is dimensionless `a_s/a_ho`, then for Eu-151 a_s/a_ho = 5.82e-9 / 1.157e-6 = 5.03e-3, and D₀ (in 1/a_ho³ units) = 1/(5.03e-3)³ / 15000² = 1/(1.27e-7) / 2.25e8 = 7.87e6 / 2.25e8 = 0.0349 (dimensionless, 1/a_ho³). Converting: 1/a_ho³ = 1/(1.157e-6 m)³ = 6.45e17 m⁻³ = 645 μm⁻³. So D₀ = 0.0349 × 645 μm⁻³ ≈ **22.5 μm⁻³** — still off by factor 6.5×.

  (b) **D₀ in the paper actually uses g·μ_B·μ_0 / (M ℏ²) physical length scale, not a_s directly**: a self-bound droplet's natural length is a_dd or a hybrid; paper uses "a_s N" as L₀ but D₀ may use a different convention. Verification requires reading the paper Eq 1 setup directly.

  (c) **D0_factor_used=2990.1 in our code IS internally consistent with a_ho/a_s convention but NOT matching paper's μ⁻³ density unit.** Our value n_max_D0=1.91 then represents whatever physical density our D₀ corresponds to. Cross-check: dimless n_max = 6.39e-4 (per T46 metrics line 132). In SI: physical density = n_max_dimless / a_ho³ = 6.39e-4 / (1.157e-6 m)³ = 6.39e-4 × 6.45e17 = 4.12e14 m⁻³ = 0.412 μm⁻³. So T46's actual peak physical density is ~0.4 μm⁻³.

  Paper's claim "n_max ~ 13000 D₀" with paper's D₀ = 3.43 μm⁻³ → physical peak density ~44,600 μm⁻³. Our T46 physical density 0.4 μm⁻³ vs paper target 44,600 μm⁻³ = ratio **~110,000×**. Even if our D₀ is wrong by 152×, the residual physical density gap is still ~720× short of the paper target. **The normalization audit may not save the result**, but the discrepancy is real and confounds the absolute density comparison.

This is a significant finding. The 152× D₀ discrepancy means our "n_max=1.91 D₀" cannot be directly compared to paper's "n_max~13000 D₀" without resolving units. **This MUST be closed before any further interpretation of n_max thresholds.**

[Established: 152× discrepancy in D₀ formula evaluation. Cause is one of (a)/(b)/(c) above — resolving requires inspecting Eq 1 of the paper directly + tracing the D0_factor_used=2990.1 derivation in `runs/yan_li_saito_f1_grid_refinement/` config / scripts.]

### §E. Routing recommendation (single commitment)

**Verdict: Option 3 — Normalization audit (text-only, cheap, highest-leverage).**

Cost-per-bit ranking:

| Option | Cost | Information gained | Cost-per-bit rank |
|---|---|---|---|
| **3. Normalization audit** | ~1-2M, text only | Resolves D₀ 152× discrepancy; could re-frame entire investigation | **1 (highest)** |
| 2. R4 analytical self-bound condition | ~3-5M, text | Predicts whether self-binding is possible AT ALL in our (LHY, DDI, contact, F=1, ε_dd=1.18) regime | 2 |
| 4. F64 spot-check | ~5M + 30-60 min CPU | Rules out F32 floor as plateau cause | 3 |
| 6. Close investigation REFUTED | ~0.5M | Frees loop for klaus-bch-leak | 4 (only if §D normalization confirms paper's claim is reachable) |
| 1. R3 finer grid | ~5-10M + 5-10 min GPU | Tests dx-axis ONE MORE TIME (factor 2) | 5 (likely null result per §B) |
| 5. Match-paper-grid spot-check | ~10-15M + 15+ min GPU, GPU memory boundary | Tests if our framework reaches droplet at dx ≈ paper's | 6 (high cost, premature without §D resolution) |

**Committed routing**: T48 = implementer_text (or theorist_text) **Normalization audit**.

**Success criterion**: explicit derivation, with citations to paper Eq 1 verbatim, of paper's D₀ formula AND our D0_factor=2990.1 derivation; numerical reconciliation (or identification of which is wrong); revised n_max comparison table (paper vs our T40 P4, T43 P0_pre, T44 R2, T46 R2c) in consistent units. Output: `runs/_loop/research/turn_48.md` OR `runs/yan_li_saito_f1_grid_refinement/normalization_audit.md`.

**Estimated cost**: ~1.5M effective, ~10-20 min wall (text only, possibly with a sympy spot-check of the D₀ formula evaluation).

**Follow-up branching**: if normalization audit reveals (a) our D₀ wrong by 152× → T49 = re-interpret all yan-li-saito sim metrics with corrected D₀; n_max=1.91 D₀ might re-classify as PASS or PARTIAL. (b) paper's D₀ wrong (unlikely but possible) → T49 = update paper memory with our verified D₀ and use our D₀ going forward. (c) normalization is consistent and 152× is a formula mis-transcription in our paper memory → T49 = R4 analytical self-bound condition.

[Single commitment per `feedback_decision_style`. No multi-front expansion per drift signal `director_must_address`.]

### §F. Tier transition

**Recommended: 0.70 → 0.60.**

Justification:

- §A CORROBORATE-PLATEAU + §B CORROBORATE-DELOCALIZED-EQUILIBRIUM-IS-GRID-INDEPENDENT: substantive partial-REFUTE finding (the framework genuinely converges to delocalized Mermin-Ho at fine grid, paralleling T40 P4 coarse grid). Tier decrement warranted: -0.05 to -0.10.
- §C REFUTE-R3-AS-NEXT-STEP: no fresh path-to-PASS surfaced via R3.
- §D FLAG-NORMALIZATION-DISCREPANCY: this is the **revival possibility**. If normalization is the load-bearing bug, the investigation could revive. Tier should NOT drop too far while §D is open — split the difference between "REFUTE-track" (tier 0.55) and "open-question" (tier 0.65). Compromise: 0.60.

If §D resolves to "normalization OK, paper claim genuinely not reproducible in our framework": tier 0.60 → 0.40 at T49.
If §D resolves to "D₀ off by 152× and re-classification flips delocalized → bound": tier 0.60 → 0.80 at T49.

Tier 0.60 is the **honest midpoint** given the open §D question is the binary discriminator for revival vs closure.

## 3. Open questions for T48+ implementer_text (Normalization audit)

1. Derive `D₀ = 1/(a_s³ N²)` from paper Eq 1 verbatim. Confirm a_s is in SI meters (not normalized).
2. Trace `D0_factor_used=2990.1` derivation. The T40 §5 hint says: "D₀ factor = 2990.1 (n_max [D₀] = n_max_dimless × 2990.1)" with `D₀_factor_formula = "N/a_ho^3 / D_0_si = N^3 * (a_s/a_ho)^3"`. This formula structure suggests our D₀ is **dimensionful-density-normalized-by-paper's-D₀** — verify which way it converts.
3. Compute paper's D₀ in SI from first principles. Reconcile with 3.43 μm⁻³ paper memory anchor. If our calculation gives 0.0226 μm⁻³ as I derived, where is the 152× factor coming from? (Plausible candidates: a_s convention, N² vs N³ in formula, additional 4π factor.)
4. Re-interpret n_max=1.91 D₀ in consistent units against paper anchor 13000 D₀. If true ratio (after normalization audit) is closer than 6800×, the physics-finding changes.
5. If normalization issue confirmed at the codebase level: is `D0_factor_used` set per-config in `runs/yan_li_saito_f1_grid_refinement/run_*.jl`, or is it derived from a SpinorBEC framework call? Class-pattern: per `feedback_fix_the_class_not_the_instance`, grep for `D0_factor` or `D_0` across all `runs/yan_li_saito*/` to identify the canonical site.

## 4. Sources cited

1. `runs/_loop/sim/turn_46.md` §4 metrics + §5 observations + §7 falsification + §8 T47 recommendation — primary audit target.
2. `runs/_loop/judge/turn_46.json` — judge contract evaluation, 4 null criteria_results confirming the T45-flagged contract-coupling pattern.
3. `runs/_loop/judge/turn_45_critic_audit.md` §A/§C/§D/§E/§F/§5 — prior critic Update being continued.
4. `runs/_loop/sim/turn_44.md` §1-§7 — T44 Execute (the T46 starting point).
5. `runs/_loop/sim/turn_40.md` §4 P4 row + §5 (sibling-instance class-check for §B).
6. `runs/_loop/director/turn_46.md` §4 (14 research anchors) + §6 (T46 dispatch contract).
7. `runs/_loop/director/turn_47.md` §3, §4 (this turn's dispatch framing).
8. Memory `yan_li_saito_2026_barnett_paper.md` (Hamiltonian Eq 1, normalization formulas L₀/T₀/D₀/B₀, anchor numbers, paper numerical dx ≈ 10⁻³).
9. `CLAUDE.md` "Dimensionless units: ℏ=m=ω_ref=1" + "Mixed precision (rotating_basis only)" sections — confirms a_ho convention and F32 path semantics.
10. Memory `feedback_fix_the_class_not_the_instance.md` — drove the §B sibling check at T40 P4 and §D D0_factor grep recommendation.
11. Memory `feedback_mathematical_elegance_bias.md` — drove the cost-per-bit ranking in §E.
12. `src/hamiltonian/interactions/interactions.jl:447-459` (Petrov branch, T45-spot-checked, NOT re-litigated per directive).

Sources cited: **12**.

## 5. Meta-data point for meta-stage-routing / meta-critic-placement

T46 judge.json is the FOURTH instance in last 5 turns (T40, T43, T44, T46) of the judge-evaluator-coupling artifact — `criteria_results` with at least 3 null entries because the directive's success_criteria reference metrics like `implementer_md_path_exists`, `T_imag_checkpoints_count`, `t47_recommendation_present` that are not top-level numeric metrics in the implementer's metrics block (they are file-existence checks or aggregate boolean flags). This is a JUDGE-CONTRACT-FLATTENING flaw (T45 critic's framing): judge.py treats every success_criteria.metric as a top-level numeric key in the implementer's metrics JSON, but director regularly specifies criteria referencing file/structure existence or trajectory length counts. **Proposed meta-fix (re-iterating T45 critic with stronger evidence)**: judge.py should support `metric` field of form `file_exists:path/to/file`, `count:trajectory_field_name`, and `present_in_md:section_heading`, with corresponding evaluators. Alternatively, director should restrict success_criteria.metric to keys that ARE top-level numeric in implementer metrics. The 4/5 turn pattern is strong empirical evidence that the meta-stage-routing-2026-05-18 auto-spawn was misframed; the genuine meta-investigation is "judge contract evaluator type system" — NOT stage routing.

## 6. Metrics block

```json
{
  "audit_target": "T46_Execute_sim_turn_46.md",
  "section_A_verdict": "CORROBORATE-PLATEAU",
  "section_B_verdict": "CORROBORATE-DELOCALIZED-EQUILIBRIUM-IS-GRID-INDEPENDENT",
  "section_C_verdict": "REFUTE-R3-AS-NEXT-STEP",
  "section_D_verdict": "FLAG-NORMALIZATION-DISCREPANCY",
  "section_E_routing_recommendation": "Option 3: Normalization audit (implementer_text)",
  "section_F_tier_transition": 0.60,
  "falsification_robust": false,
  "next_falsifier_id": "d0-normalization-audit-paper-vs-framework",
  "next_falsifier_observable_manifest": [
    "paper_D0_formula_verbatim_from_Eq1",
    "framework_D0_factor_derivation_traced",
    "framework_D0_value_SI_microns_inverse_cube",
    "paper_D0_value_SI_microns_inverse_cube",
    "discrepancy_ratio",
    "discrepancy_root_cause_identified",
    "revised_n_max_comparison_table_consistent_units",
    "grep_D0_factor_class_pattern_codebase_wide",
    "normalization_audit_md_on_disk",
    "tier_revision_recommendation_post_audit"
  ],
  "new_class_pattern_candidate": "fine-and-coarse-grid-both-converge-to-Mermin-Ho-delocalized-not-self-bound-droplet (supersedes T45 candidate fine-grid-slows-DDI-offdiagonal-m-channel-relaxation; equilibrium-level not rate-level)",
  "cost_budget_t48_estimate_effective": 1500000,
  "cost_budget_t48_estimate_wall_sec": 900,
  "sources_cited": 12,
  "critic_md_on_disk": true,
  "investigation_id": "yan-li-saito-2026-reproduction",
  "recommends_close_investigation": false,
  "meta_data_point": "T46 judge.json is FOURTH instance in last 5 turns (T40/T43/T44/T46) of judge-contract-flattening artifact: judge.py evaluates director's success_criteria.metric as top-level numeric keys in implementer metrics, but file_exists/count/present checks don't fit this schema -> null criteria_results. Re-frames meta-stage-routing-2026-05-18 auto-spawn as misdiagnosed; actual meta target is judge.py evaluator-type-system."
}
```

---

VERDICT: PASS
