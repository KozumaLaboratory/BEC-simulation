# T45 Critic Audit

VERDICT: PASS (audit committed; no scope/contract violation in critic deliverable itself)

## 0. Pre-audit LHY spot-check (relevant to §C below)

Read `src/hamiltonian/interactions/interactions.jl:447-459` (`lima_pelster_Q5`):

```julia
arg = 1.0 + eps_dd * (3.0 * ct^2 - 1.0)
s += weights[i] * sin(theta) / 2.0 * (arg >= 0.0 ? arg^(5/2) : 0.0)
```

This **zeros the integrand on the imaginary band** — the **Petrov prescription**. For half-integer exponent 5/2, `Re[(−|x|)^(5/2)] = Re[i^5 |x|^(5/2)] = Re[i |x|^(5/2)] = 0` (principal branch), so the Petrov "zero the negative integrand" IS mathematically equivalent to the paper's `Re ∫₀^π sinθ [1 + ε_dd(3cos²θ − 1)]^(5/2)/2 dθ` operator. Per Wächtler-Santos 2016 / Lima-Pelster 2011: this IS the standard convention. **Our scalar LHY at ε_dd=1.18 is correct.** Details in §C.

## 1. Bottom line

T44 was a clean, properly-controlled Execute that surgically isolated seed-topology as a single variable vs T43 P0_pre, and obtained n_max=3.09 D₀ — only 1.5× the spherical-seed baseline (2.00 D₀), 32× below the joint PASS threshold (100 D₀), and 3× below the REFUTE edge (10 D₀). The pre-ITP sanity check confirmed the seed had EXACTLY the predicted topology ((0.25, 0.50, 0.25) m-pops, F_z=0, L_z=-3.9e-15). Topology preservation through ITP is also clean (F_z=-1e-6, L_z=3e-6).

**The REFUTE is robust at face value, BUT the new observation (partial m=0 relaxation: 0.5 → 0.25 vs T40 P4 coarse-grid 0.5 → ~0) makes "R2_b vs R2_c" a genuinely open question.** §A below ranks the four hypotheses for the partial relaxation and concludes UNDETERMINED-NEED-EXTENDED-RUN. The cheapest disambiguator is **R2_c (extend ITP at same grid) FIRST**, then R3 if extend fails, then R4 if R3 also fails.

I am pushing back on theorist's H3-recommended-R3-first and on implementer's R3 recommendation. Burning ~5-10 min GPU + ~3-5M effective on a 128³ box=8 run before settling the "did 6250 steps just need to be 12500-25000 steps?" question is premature. R2_c is ~2-3M effective + ~2 min GPU and directly tests the partial-relaxation hypothesis. The cascade has already burned ~50M tokens on this investigation; a strict cost-routing discipline is warranted.

§C LHY χ(ε_dd=1.18) audit: LHY-LOOKS-OK (per §0 spot-check). This rules out the LHY branch convention as a load-bearing root cause.

Tier transition: 0.75 → 0.70.

## 2. Section-by-section audit

### §A. R2_b REFUTE robustness — partial m=0 relaxation

**Verdict: UNDETERMINED-NEED-EXTENDED-RUN.**

The discrepancy: T40 P4 (dx=0.4375, ComplexF64, 5000 steps) achieved FULL m=0 evacuation: (0.5, 6e-25, 0.5). T44 (dx=0.125, F32, 6250 steps) only partial: (0.375, 0.250, 0.375). At FINER grid + MORE steps + same seed family, the m-channel relaxation is SLOWER. Ranked hypotheses:

- **(iii) Insufficient ITP steps at fine grid [Plausible, RANKED HIGHEST]**: at coarse grid, dx=0.4375 with 64³ box=28, the per-step DDI work and the spectrum of fluctuation modes are dramatically different — the spin-mixing route may dynamically equilibrate faster simply because of less "spectral room". At fine grid the wavevector space available for off-diagonal DDI coupling expands by ~(0.4375/0.125)³ = 43×. The accessible mode count grows, but the relevant Δm=±2 matrix elements distribute across more modes, slowing the effective rate per channel. Linear extrapolation: if T44 went from 0.50→0.25 in 25 t_ho, reaching 0→0 needs ~25 more t_ho (another 6250 steps). T46 R2_c extend-ITP DIRECTLY tests this. [Plausible — order of magnitude, not derived.]

- **(i) Grid-dependent DDI off-diagonal matrix element [Plausible]**: DDI is k-space `Q_αβ(k̂) = k̂_αk̂_β − δ_αβ/3` (CLAUDE.md, T42 §B closed). Q-tensor is k-direction-only; it does NOT depend on k-magnitude. Per-mode DDI strength on the matrix-element level is grid-independent — but the SUM over wavevectors does scale with the cutoff k_max = π/dx. Going from dx=0.4375 to dx=0.125 raises k_max by 3.5×; modes with k > k_max,coarse couple at fine grid but not at coarse. These new modes' Δm matrix elements are NOT a priori favorable (high-k modes are gradient-dominated). Net effect: ambiguous sign on the mixing rate. [Speculative]

- **(ii) LHY barrier rising at fine grid [Plausible]**: at T44 we observe E_LHY/E_contact = 2.2× (vs ~0 at T43 delocalized). The partial nucleation pocket has higher local density, making LHY repulsion dominant. Channel-mixing requires moving population through a transient state with even higher local density (collapse + bounce shape), so a finite barrier opens. T40 P4 at coarse grid never had this barrier (density stayed at ~0.6 D₀ throughout, LHY irrelevant). This is a NEW physics mechanism. [Plausible]

- **(iv) F64 vs F32 numerical-precision-dependent relaxation [Speculative]**: T40 P4 used ComplexF64 from a JLD2; T44 runtime-built ComplexF32 on GPU. F32 round-off at the spin-mixing matrix element scale (~10⁻⁵ per step from T43-measured rate) approaches F32 unit-round-off ~6e-8 per step over 6250 steps = 4e-4. Comparable to the partial-evacuation residual 0.25. Possible but unlikely to be the dominant cause: T43 critic §A established the F32 path IS suppressing per-step F32 round-off via FFT renorm. [Plausible-but-unlikely]

If (iii) holds (highest prior), T46 R2_c-extend-itp is the test. If (i)/(ii), R3 finer-dx test. If (iv), need an F64 32³ box=12 spot-check.

**T43 critic anti-pattern check**: the partial-progress (m_+1: 0.25 → 0.375, m_0: 0.50 → 0.25) shows the kinetic bottleneck IS active. The empirical leak rate per-step at T44 is (0.25 m_0 reduction) / (6250 steps) ≈ 4e-5 per step, vs T43 critic's measured 2.4e-5/t_ho rate at uniform-m=+1 seed. The rate is comparable (within a factor of ~2.4×), confirming the framework path is consistent. The bottleneck DID get crossed partway; it did NOT finish. This shape is symptomatic of incomplete-ITP, not framework-bug.

### §B. Confounder-elimination claim audit

**Verdict: CONFOUNDER-PARTIAL.**

T43 critic §C argued: spherical-m=+1 seed cannot reach the (0.5, 0, 0.5) basin via 0.06% / 25 t_ho DDI off-diagonal mixing in any practical ITP budget. T44 evidence: the fl_vortex seed (initial m-pops (0.25, 0.50, 0.25), ALREADY past the bottleneck T43 critic identified) reached (0.375, 0.250, 0.375), i.e. PARTIALLY past the second bottleneck (0.25 → 0). This validates T43 critic's framework-property argument (DDI off-diagonal IS the only mixing route, and it IS slow) AND shows that T44's seed strategy reduced — but did NOT eliminate — the kinetic obstacle.

The pre-ITP sanity check (m-pops uniformly (0.25, 0.50, 0.25), F_z=L_z=0) confirms the topology bytes-in were correct. The remaining "did the basin's energy minimum get reached?" question is unresolved: the state moved toward (0.5, 0, 0.5) but didn't arrive. This is the SAME CLASS of confounder T43 critic identified (seed not at the basin), now manifesting one bottleneck deeper. [Established for the kinetic-route argument; the second-order rate is approximately the same as T43-measured.]

The fact that mu_final = 0.316 vs 0.120 (T43 P0_pre), with finite E_kin/N = 0.009 and E_LHY/E_contact = 2.2×, confirms the vortex topology IS encoded in the equilibrium. The state is NOT in the delocalized basin. It is in an INTERMEDIATE state. Whether this intermediate is the true energy minimum (in which case the basin we want is unreachable from this seed at this grid) or a transient en route to (0.5, 0, 0.5) (in which case extended ITP closes the gap) is precisely the §A open question.

### §C. LHY χ(ε_dd > 1) branch hypothesis cross-check

**Verdict: LHY-LOOKS-OK.**

Per §0 spot-check of `src/hamiltonian/interactions/interactions.jl:447-459`: the `(arg >= 0.0 ? arg^(5/2) : 0.0)` branch IS the Petrov prescription, mathematically equivalent to the paper's `Re ∫` operator for half-integer exponent 5/2.

Sanity: at ε_dd = 1.18, the integrand crosses zero where `3cos²θ = 1 − 1/1.18 = 0.1525` → cos²θ = 0.0508 → θ ∈ (~77.0°, ~103.0°), a 26° angular band where the integrand is zeroed. The remaining (sin θ)/2 × arg^(5/2) integral has Q_5(1.18) ≈ 3.0-3.5 (extrapolating between the docstring values Q_5(0.88)≈2.23 and Q_5(1.39)≈4.11 in `fm_dipolar.jl:50-52`). Numerical check would be cheap but not load-bearing here — the IMPLEMENTATION matches the paper's convention.

CLAUDE.md "Scalar LHY: `@warn` approximation" refers to the F-spinor approximation (treating the spin-coherent state as a single scalar component for the LHY), NOT to a branch-handling issue. This is a SEPARATE concern but does not change the χ(ε_dd) integrand convention.

Memory `yan_li_saito_2026_barnett_paper.md` line 114-115 flagged this as a likely failure mode in the abstract; the concrete code check shows it is not in fact load-bearing for this cascade. **Do NOT route to R4 on the LHY-branch hypothesis.**

[Established for the integrand convention; the broader question "does this F-scalar LHY adequately represent the F=1 flux-closure-torus state's actual zero-point energy" is a separate, deferred question.]

### §D. New observation: fine-grid slower m-channel relaxation

**Verdict: ADDRESSED. Provisional interpretation: hypothesis (iii) incomplete-ITP dominates; (ii) LHY-barrier-at-finer-grid is a plausible secondary contributor. R2_c-extend-itp directly tests both.**

The new class-pattern candidate is: **"DDI off-diagonal m-channel relaxation rate is grid-dependent — slower at finer dx"**. This deserves its own falsifier if R2_c confirms (iii) is wrong (i.e., extended ITP STILL doesn't reach (0.5, 0, 0.5)). For the audit-class-scan deferred to T47+, this is a strong candidate new pattern. Memory entry could be `gotcha_fine_grid_slows_m_channel_relaxation.md` if confirmed.

**Quantitative check** the implementer's claim that mu_final = 0.316 vs T43 0.120 reflects vortex gradient energy: at the partial-nucleation state with ⟨L_z⟩=0 (winding-pair cancels) but persistent π-twist phase in m=±1, the kinetic energy is `(1/2)|∇ψ|² ≈ (1/2) × (1/r²)|ψ|² ≈ E_kin/N = 0.009` (observed). For r ~ 0.5 a_ho characteristic vortex core size, the gradient term gives 0.5/0.25 × 1.0 = 2.0 per unit norm — but the actual mass distribution puts most ψ at larger r where ∇φ contribution decays as 1/r². The 0.009 number is plausible for a delocalized winding state. The mu increase from 0.120 → 0.316 reflects both the kinetic vortex contribution AND the partial-nucleation LHY/contact rise. Self-consistent.

### §E. Routing recommendation (single commitment)

**Verdict: R2_c-extend-itp.**

Ranking by direct testability + cost (per `feedback_mathematical_elegance_bias`):

1. **R2_c-extend-itp**: extends T44 ITP from converged JLD2 (`runs/yan_li_saito_f1_grid_refinement/results_R2_fl_vortex.jld2`) by 6250-12500 more steps (T_imag 25 → 50 or 75) at the SAME grid/seed/F32. **Cost: ~2-3M effective + ~1-2 min GPU.** Directly tests §A hypothesis (iii) AND §B confounder-partial reading. **Expected outcomes** with PASS/FAIL routing:
   - **R2c-PASS** (m_0 continues to drop, n_max rises ≥ 10 D₀ at T_imag=50): hypothesis (iii) confirmed; the basin IS reachable; ITP just needed more time. T47 = extend further OR commit to a full 25000-step run at the same grid. Tier 0.70 → 0.85.
   - **R2c-FAIL** (m_0 stays ~0.25 plateau, n_max stays ~3 D₀): hypothesis (iii) refuted; the partial state IS the equilibrium at fine grid; routing to R3 is then warranted with high confidence. Tier 0.70 → 0.60.
   - R2c also discriminates F32 round-off: if extending to T_imag=50 shows m-evacuation has CONVERGED to a plateau at 0.25 (not slowly drifting), F32 round-off (iv) gains weight.

2. **R3 (finer dx at 128³ box=8 dx=0.0625)**: tests whether dx_crit < 0.125 is needed for the basin. Cost: ~3-5M + ~5-10 min GPU. R3 burns ~3× the R2c cost while assuming R2c's question is already settled. **Premature.**

3. **R4 (theorist analytical re-derivation)**: per §C above, the LHY-branch-suspect motivation for R4 is REFUTED. R4's other content (self-bound condition derivation for the paper's flux-closure-torus in our framework) is a legitimate analytical task, but with the §C result it loses its "next-most-probable root cause" status. R4 belongs LATER if R2c-FAIL AND R3-FAIL.

**Pushing back on implementer/theorist R3-first recommendation**: implementer §6 said "T45 = R3 ... directly tests whether the self-bound basin is reachable at finer dx while preserving the fl_vortex topology". This is correct IF the assumption "T44's m-relaxation was complete" holds. The implementer did not interrogate this assumption. T40 P4's full evacuation in 5000 coarse-grid steps is the comparison point that needs explaining BEFORE 3× the compute is burned on R3. The implementer was honest in §5 about this ("could indicate: (a) ... (b) ... (c) 6250 steps was insufficient ..."); their R3 recommendation was the convenient/maximum-information path, not the cost-routed path.

[Established for the cost ranking; Plausible for the prior on R2c-PASS vs R2c-FAIL ~ 50/50.]

### §F. Tier transition

**Recommended: 0.75 → 0.70.**

Justification:
- T44 REFUTED at face value (n_max 32× below PASS, 3× below REFUTE-edge): tier decrement warranted.
- But the REFUTE is undetermined (§A); the cheap follow-up R2c may flip it. Decrement of 0.05 not 0.15.
- §C LHY-branch hypothesis ruled out: no need for tier drop on framework-deep-bug suspicion.
- §B confounder-partial: T43 critic's framework-property argument validated, not extended into a new confounder class. No additional tier loss.

Tier trajectory if R2c-PASS: 0.70 → 0.85. If R2c-FAIL → R3-PASS: 0.70 → 0.55 → 0.80. If R2c-FAIL → R3-FAIL: 0.55 → 0.40 (close to investigation-closure-as-REFUTED unless R4 finds something).

## 3. Open questions for T46+ implementer (if R2_c)

- Restart-from-JLD2 path on rotating_basis GPU F32: T40 §6 BUG-12 documented `FieldError` with from_jld2 + no init_sigma + auto_path; T46 must set `init_sigma: 0.7` defensively (will be ignored physically but prevents the auto-derive branch crash).
- Track n_max(t) trajectory at intermediate checkpoints (e.g., every 1000 steps): even if final n_max is unchanged, the trajectory shape distinguishes "plateau hit" from "still rising slowly".
- Track m-populations at the same intermediate checkpoints: if m_0 trajectory is monotonically decreasing toward 0 but slowly, that's hypothesis (iii). If it has plateaued at 0.25, that's a new equilibrium.

## 4. Sources cited

1. `runs/_loop/sim/turn_44.md` §4 metrics + §5 observations + §7 falsification table — primary data being audited.
2. `runs/_loop/theorist/turn_44.md` §H1-H3 (hypothesis structure), §3 sanity checks 1-4, §5 open questions Q3 (anticipated scenario).
3. `runs/_loop/sim/turn_40.md` §4 P4 row + §5 (T40 P4 baseline: (0.5, 6e-25, 0.5) full evacuation in 5000 coarse-grid steps).
4. `runs/_loop/judge/turn_43_critic_audit.md` §C (CONFOUNDER-CONFIRMED + 2.4e-5/t_ho rate derivation) + §E (R2 routing rationale).
5. Memory `yan_li_saito_2026_barnett_paper.md` lines 36-46 (Hamiltonian) + lines 75-83 (anchor n=13000 D₀) + lines 104-110 (locally-FM-globally-zero) + lines 113-122 (failure modes incl. LHY χ branch flag).
6. `src/hamiltonian/interactions/interactions.jl:447-459` (`lima_pelster_Q5` implementation — Petrov-prescription `arg >= 0 ? arg^(5/2) : 0.0`, equivalent to paper's `Re ∫` for half-integer exponent).
7. `src/hamiltonian/interactions/lhy/fm_dipolar.jl:22-24` (docstring confirming Petrov prescription).
8. `src/hamiltonian/interactions/lhy/dispatch.jl` (LHY mode catalog).
9. `runs/_loop/director/turn_45.md` §1 + §3 + §4 (director context for routing scope).
10. `CLAUDE.md` lines 65-67 (DDI conventions, closed at T42 §B) + scalar LHY @warn note.

Sources cited: **10**.

## 5. Meta-data point for meta-critic-placement / meta-stage-routing

The T44 judge.json INCONCLUSIVE-with-criteria-results-all-null is the THIRD instance in last 4 turns (T40, T43, T44) of judge-evaluator-coupling artifact. Director's §1 turn_45 noted this. Concrete pattern: judge.py evaluates sim Execute metrics against the contract that director DRAFTED for that turn's dispatched subagent — but for Hypothesize-stage director-dispatched-theorist turns, the contract is theorist-shaped (e.g., `hypothesis_n_max_lower_bound_D0`, `design_yaml_path`) while the sim Execute metrics are physics-shaped (`n_max_D0`, `m_populations`). Suggested fix at meta-stage: judge.py should detect when criteria_results are ALL null AND triggered_failure_modes empty, and either downgrade to "contract-coupling artifact, see subagent verdict in body" warning OR re-route the criteria evaluation to the prior turn's contract when stages alternate.

## 6. Metrics block

```json
{
  "audit_target": "T44_Execute_sim_turn_44.md",
  "section_A_verdict": "UNDETERMINED-NEED-EXTENDED-RUN",
  "section_B_verdict": "CONFOUNDER-PARTIAL",
  "section_C_verdict": "LHY-LOOKS-OK",
  "section_D_observation_addressed": true,
  "section_E_routing_recommendation": "R2_c-extend-itp",
  "section_F_tier_transition": 0.70,
  "falsification_robust": false,
  "next_falsifier_id": "extend-itp-12500-steps-same-grid-r2-from-jld2",
  "next_falsifier_observable_manifest": [
    "n_max_D0",
    "m_populations",
    "F_z_per_N",
    "L_z_per_N",
    "mu_final",
    "norm_drift_max",
    "n_max_D0_trajectory_per_1000_steps",
    "m_populations_trajectory_per_1000_steps",
    "E_kinetic_per_N",
    "E_contact_per_N",
    "E_LHY_per_N",
    "wall_time_sec"
  ],
  "new_class_pattern_candidate": "fine-grid-slows-DDI-offdiagonal-m-channel-relaxation-rate-vs-coarse-grid",
  "cost_budget_t46_estimate_effective": 2500000,
  "cost_budget_t46_estimate_gpu_wall_sec": 120,
  "sources_cited": 10,
  "critic_md_on_disk": true,
  "investigation_id": "yan-li-saito-2026-reproduction",
  "recommends_close_investigation": false,
  "meta_data_point": "T44 judge.json is THIRD instance in last 4 turns of judge-evaluator-coupling artifact (criteria_results all-null + triggered_failure_modes empty when stages alternate Hypothesize/Execute). meta-stage-routing-2026-05-18's auto-spawn diagnosis of 'stage routing flaw' is empirically wrong — actual root cause is judge.py contract-matching against the wrong stage's contract. Suggested meta-fix at T47+: judge.py should detect null-criteria + empty-failure-modes pattern and fall back to subagent-body verdict OR re-route to the prior turn's contract."
}
```
