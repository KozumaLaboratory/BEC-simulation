---
turn: 43
subagent: critic
audit_target: T43 Execute (sim/turn_43.md) — judge fired FAIL_NUMERICAL while metrics block carries `falsification_result: REFUTED`
investigation_id: yan-li-saito-2026-reproduction
depends_on: [43, "runs/_loop/theorist/turn_43.md", "runs/_loop/sim/turn_43.md", "runs/_loop/judge/turn_43.json", "runs/_loop/judge/turn_42_critic_audit.md", "runs/_loop/sim/turn_40.md"]
produces: "Independent Update audit. Verdict per-section A-F; T44 routing recommendation; tier transition recommendation."
---

## 1. Bottom line

Operational FAIL_NUMERICAL is a contract-shape artifact of running the strict no-dissipation 1e-8 norm gate against a 6250-step F32 ITP that accumulates ~3.5e-11/step — i.e. 4-5 orders below the F32 single-multiply error floor and 5 orders below the physically meaningful 0.01 gate. Scientific REFUTED of Form (B)-at-dx=0.125-with-spherical-Gaussian-seed is, taken at face value, correct.

**But the REFUTE is CONFOUNDED.** Theorist §2.5 dismissed seed-topology with a non-sequitur (T40 P4 at coarse grid → claim that spherical seed at fine grid suffices). The actual blocker for nucleation is structural: at c1=0 the only m-channel mixing route in our framework is the DDI off-diagonal Q_αβ, and the measured leak rate is 0.06% per 25 t_ho. The paper's GS is a flux-closure torus with locally-FM-globally-zero spin texture requiring m-populations of order 0.5/0.5 — kinetically unreachable from a uniform-m=+1 seed under ITP in any finite budget, regardless of dx. Form (B) is not properly tested by P0_pre as configured.

**Recommended T44 routing: R2 (fl_vortex retry at same grid).** Cheapest direct test of the confounder. Tier 0.8 → 0.75.

## 2. Section-by-section audit

### A. Operational vs scientific classification

**Verdict: ACCEPT-as-framework-limitation.**

Three F32-floor gates fired in the judge:

(i) **norm_drift = 2.2e-7 over 6250 steps**. Per-step accumulation = 3.5e-11. F32 single-precision unit-round-off is ~6e-8; squared-multiply error per FFT pass is ~1e-7. The observed per-step drift is ~3000× below the F32 single-multiply error, meaning the FFT-renorm cycle is actively suppressing F32 round-off, not propagating it. The physical norm-conservation gate (norm_drift < 0.01) clears by 5 orders of magnitude. The `has_dissipation=False, expected=None` strict-1e-8 gate in judge.py is calibrated for F64 RTP norm-conservation tests; applying it to F32 ITP is a category error. [Established]

(ii) **mz_final = 0.998858 (1.1e-3 deviation from target = 1.0)**. m_populations = [0.9994, 1.1e-6, 0.0006] → F_z = 1·0.9994 + 0·1.1e-6 + (-1)·0.0006 = 0.9988. The 0.06% leak into m=-1 is real, not F32 rounding (F32 round-off on |ψ|² of order unity is ~1e-7, three orders below the observed 6e-4 leak). The mechanism is DDI off-diagonal: the Q_αβ kernel has off-diagonal αβ pairs that, when projected on the spin matrices, couple m-channels. This is physics, not framework limitation — and it is FAVORABLE physics for the parent investigation (the framework DOES have an m-channel mixing route, just very slow). For purposes of the n_max measurement, 99.94% main population means peak density is ≥ 99.94% of what a perfectly polarized state would give: n_max measurement is uncontaminated. [Established]

(iii) **converged = false**. Implementer §6 documents: `n_before` rounds to exactly 1.0 in F32 after `normalize_rotating!`, so `log(1.0) = 0` at every step → `|Δμ|` never crosses 1e-8 from below. The `dmu > 0` guard correctly prevents false-positive convergence. The ITP ran all 6250 steps to T_imag = 25 (a long ITP run); state shape is converged at F32 precision. The bookkeeping criterion is broken, not the physics. [Established]

Quantitative summary: norm_drift_per_step = 3.5e-11, ~5 orders below the physical gate 0.01. F32 floor argument: ACCEPTED.

### B. Discriminator sharpness audit

**Verdict: PARTIAL-CLOSE.**

(i) Theorist's Form-B lower bound at P0_pre was 3000 D₀ (Nyquist penalty `(dx/r_minor)² = 0.39` → 39% peak attenuation envelope, lower bound 0.61·13000 ≈ 8000; theorist further softened to 3000 to allow "partial nucleation within 5000 steps" from a spherical seed). Observed n_max = 2.00 D₀ is **1500×** below this softened 3000 floor. Even taking the most generous reading where Nyquist attenuation could multiplicatively cap at 39% of 13000 ≈ 5070 D₀, observed is **2540× below** the best-case Form-B floor. The measurement is genuinely refuting Form-B-with-dx_crit=0.20-and-spherical-Gaussian-seed. [Established]

(ii) **However, the measurement cannot uniquely distinguish two scenarios**:
  - Scenario X: Form (B) with dx_crit = 0.20 a_ho IS correct; we are below threshold; some non-grid mechanism (e.g., seed topology) blocks nucleation.
  - Scenario Y: Form (B) with dx_crit ≪ 0.125 a_ho (e.g., 0.05 a_ho); we are still above threshold; finer dx would nucleate.

Both predict n_max ≪ paper at dx=0.125. [Plausible]

(iii) The §2.7 sanity check (theorist) showed (0.4375/0.0144)³ ≈ 27985 vs observed gap 12300 → "within factor 2" of Form-B saturated ceiling argument. This consistency, used as positive evidence in T43, is too weak to anchor dx_crit = 0.20 vs dx_crit = 0.05 a_ho. The geometric chain from T42 §A(ii) inferred r_minor ≈ 0.2 from "torus aspect ratio in Fig 1c" — a literature read, not a derivation from coupling constants. dx_crit could plausibly be finer. [Plausible]

CONCLUSION: dx=0.125 measurement closes Form-B-with-dx_crit=0.20 + spherical seed, but leaves Form-B-with-finer-dx_crit alive AND leaves Form-B-with-correct-topology alive. PARTIAL-CLOSE.

### C. Seed-topology + c1=0 confounder (LOAD-BEARING)

**Verdict: CONFOUNDER-CONFIRMED.**

This is the load-bearing finding. Theorist §2.5 reasoning chain is:

> "T40 P4 showed that even with topologically correct flux-closure torus seed the density stayed at ~0.6 D₀ at our coarse grid (topology was preserved but density didn't rise). The grid-resolution hypothesis says: at finer grid, a spherical Gaussian seed at the right scale ALSO nucleates the droplet."

Both clauses are individually defensible but their conjunction is not:

1. **"T40 P4 at COARSE grid failed → spherical-at-fine is sufficient"** is a non-sequitur. T40 P4 (dx=0.4375) was below the resolution at which any droplet basin is representable on the grid; it tells us nothing about whether fl_vortex topology IS or IS NOT required at a grid where the basin IS resolvable. The argument equates "fl_vortex didn't help at coarse" with "fl_vortex isn't needed anywhere". [Established]

2. **The c1=0 + spherical-m=+1 seed combination locks the spin texture**. In our GP framework with the static-spinor path (c1=0, no spin-mixing operator), the only m-channel-coupling term in ITP is the DDI off-diagonal Q_αβ projection onto spin matrices. The implementer measured this rate **directly via the result**: 0.06% leak into m=-1 channel over T_imag = 25 t_ho. Linear extrapolation: reaching m-populations of order 0.5/0.5 (required for f_z to average to zero across the torus while being locally |f|=1, per the paper's flux-closure topology, memory paper lines 104-110) would need approximately 0.5/0.0006 ≈ 833× more imaginary-time evolution ≈ 21000 t_ho. At dt=0.004 this is ~5,250,000 steps vs the 6250 executed. Even with three orders of n_steps and infinite dx refinement, the uniform-m=+1 seed cannot reach the paper's torus basin via ITP. [Established for the rate; Plausible for the linear extrapolation — non-linear feedback could speed up or slow down once populations equilibrate, but the order of magnitude stands.]

3. **Cross-check: the m=-1 leak rate IS positive**, confirming the framework has the mixing route. The route is just too slow at our coupling values for the ITP budget. This is informative: the parent investigation is not blocked on framework architecture but on seed preparation.

4. **What about the secular-DDI advisory?** rotating_basis defaults: at high B-field, the DDI off-diagonal Larmor-averages to zero (CLAUDE.md known-limitations: "spin_rotating_frame_omega ≠ 0 requires secular_ddi=true"). At B_z = 0 (our config), there is no Larmor averaging, so the full Q_αβ kernel acts — including the off-diagonal m-mixing channels. The measured 0.06% leak rate is the empirical answer to "how strong is the residual mixing at our coupling and box". Independent of whether secular_ddi is on or off — the implementer config didn't set it, and the leak occurred anyway, so the off-diagonal channel is active. [Established]

**Consequence**: Form (B) refute is **INVALID as configured**. ITP from σ=0.7 spherical m=+1 seed cannot enter the paper's GS basin in any finite computational budget. The measurement is consistent with both "Form (B) is wrong" AND "Form (B) is right but seed/topology blocks it". These are not distinguishable without a topology-corrected retry.

c1_zero_freezes_spin_texture: **true** (modulo the slow DDI off-diagonal route, which empirically saturates 99.94% in m=+1 at T_imag=25).

DDI off-diagonal mixing rate per t_ho: **0.06%/25 ≈ 2.4e-5 per t_ho** (from implementer measurement, linear estimate).

### D. Form (A) volumetric ceiling quantitative check

**Verdict: CONFIRMED.**

(i) For 96³ box=12 a_ho with σ=0.7 spherical Gaussian seed at full delocalization, |ψ|² → 1/V_box = 1/12³ = 1/1728 = **5.787e-4 a_ho⁻³**. [Established]

(ii) Convert: 5.787e-4 × 2990.1 = **1.73 D₀** (volumetric ceiling). [Established]

(iii) Observed n_max_D₀ = **2.00** = 1.15× the volumetric ceiling. The 15% excess is the residual Gaussian peak structure (σ=0.7 hasn't fully delocalized — at T_imag=25 the state is approaching, not at, full uniform fill). [Established]

(iv) Form (B) prediction at P0_pre was [3000, 13000] D₀ → 1500-6500× above observed. Form (C) with β=3, dx_crit=0.05 would predict ≈ 830 D₀ → 415× above observed. Form (A) volumetric ceiling predicts 1.73 D₀ → 0.86× observed. **Form (A) is quantitatively consistent at the 15% level**, two orders better than Form (C), three orders better than Form (B). [Established]

(v) Physical reading: at c1=0 + DDI-active + spherical-m=+1 seed, ITP relaxes to a state where contact repulsion + LHY repulsion dominate kinetic confinement, producing a delocalized uniform-fill solution. DDI net effect is mildly repulsive for an isotropic density profile (per T40 §2 reasoning). The state IS the delocalized basin — it is not "Form B failed", it is "the wrong basin won". [Plausible]

### E. T44 routing recommendation

**Verdict: R2 (CONFOUNDER-RETRY).**

Decision logic:
- §C verdict = CONFOUNDER-CONFIRMED → R2 is the heuristic match.
- R2 is also the **cheapest direct test of the dominant uncertainty**: at the same grid (96³ box=12 dx=0.125 F32), swap the σ=0.7 spherical m=+1 seed for a fl_vortex seed (loaded via `interpolate_psi_for_restart.jl` from T40 P4's JLD2, k-space-padded 64³ → 96³).
- Budget: ~3M effective + ~2 min GPU per T43 budget profile.

**Expected outcomes and routing**:
- **R2_a**: n_max(P0_pre_fl_vortex) ≥ 100 D₀ → seed-topology is required; Form (B) + topology-required becomes the joint hypothesis; tier bump warranted; T45 = run P1 with topology-corrected seed.
- **R2_b**: n_max(P0_pre_fl_vortex) ≈ 2 D₀ (same as P0_pre) → seed topology is NOT the confounder at this dx; refute is robust at the dx=0.125 level; T45 = either R3 (finer-dx test) or R4 (theorist re-derivation of self-bound condition in our `:scalar` LHY framework).
- **R2_c**: n_max(P0_pre_fl_vortex) ∈ [10, 100) D₀ → partial nucleation; needs N-steps extension before verdict.

**Why not R3 (finer-dx)?** R3 runs P1 at 128³ box=8 dx=0.0625 with spherical seed. If the confounder is real, R3 will ALSO give n_max ≈ 2 D₀ (since the c1=0 + uniform-m=+1 seed cannot reach the basin regardless of dx). R3 then leaves us where R2_b would have, but at ~2× the cost and without resolving the confounder ambiguity. R2 strictly dominates R3 in expected information per GPU-minute. [Plausible]

**Why not R4 (theorist analytical re-derivation of self-bound condition)?** This is the deepest path but is text-only and ~2M effective. It is the right move IF R2_b confirms the refute is robust — i.e., R4 belongs after R2, not as a parallel alternative. The parent investigation can absorb one more cheap experimental data point before pivoting fully to analytical work. [Plausible]

**Why not R1 (accept refute, theorist alt-causes)?** R1 retracts Form (B) without first ruling out the confounder. Given §C, the refute is not yet entitled to retract Form (B) — only to flag "not tested as configured". R1 is over-strong. [Established]

### F. Tier verdict

**Recommended: tier 0.8 → 0.75.**

Per the dispatched brief heuristic:
> §A operational dismissed AND §C confounder confirmed → tier 0.8 → 0.75 (Form B alive pending R2 retry).

This is the matching case. Justification:
- T42 §A grid-hypothesis CORROBORATE chain (independent dx-ratio + droplet-cell-count) is unchanged; nothing in T43 refutes it.
- Form (B) is unverified at this turn but not retracted — the experiment as run did not test Form (B) faithfully (confounder).
- Form (A) is the **observed empirical result at this seed/grid combination**, not the leading scientific hypothesis for the paper's GS. The investigation does not retreat to Form (A) on the basis of one confounded measurement.
- Tier decrement reflects that the easy win at dx=0.125 with a spherical seed did not land — we lost a turn-budget and have to spend another on R2 — but the parent hypothesis (grid resolution + topology jointly required) is alive.

If R2 returns R2_b (n_max ≈ 2 D₀ with fl_vortex seed at dx=0.125), tier drops further: 0.75 → 0.6. If R2 returns R2_a (n_max ≥ 100 D₀), tier bumps back: 0.75 → 0.85.

## 3. Additional notes for theorist (input for T44 directive design, if R2 is chosen)

1. **JLD2 grid resample**: theorist T43 §9.1 flagged that `interpolate_psi_for_restart.jl` is needed for P0_pre → P1 (96³ → 128³). Implementer §3 confirms the helper exists. For R2, the resample direction is **opposite** (64³ T40 P4 → 96³ P0_pre): k-space zero-pad in spatial frequency works in both directions and preserves Parseval norm. No new helper needed.

2. **fl_vortex JLD2 source**: implementer should re-confirm T40 P4 saved a JLD2 with the full 13-component spinor (or 3-component for F=1). If only F=6 13-component is on disk, an additional projection step to F=1 is needed before resample. Theorist should verify this is in scope before committing.

3. **Falsification criterion design for R2**: the falsifier should not be n_max alone but joint:
   - PASS: n_max ≥ 100 D₀ AND m_populations within (0.4, 0.6) for m=+1 AND L_z_per_N within (-0.05, 0.05).
   - The middle condition is the operational signature of "ITP reached the topology-correct basin".
   - n_max ≥ 100 D₀ (not 3000) is the LOWER bound because partial nucleation from an interpolated-from-coarse seed is plausible; full saturation would require P1.

4. **DDI off-diagonal mixing rate** measured at this turn (~2.4e-5/t_ho) is itself a useful empirical anchor. If R2 also gives slow mixing despite topology-correct seed, the framework's c1=0 path may need augmentation (e.g., explicit spin-mixing operator or initialization with the equilibrated spin texture pre-baked).

5. **Do NOT reopen** T42 §A grid hypothesis or §B DDI bit-equal closure. Both remain CORROBORATEd. R2 tests SEED topology, not GRID.

## 4. Sources cited

1. `runs/_loop/sim/turn_43.md` §1 (directive), §4 (metrics — n_max_D0=2.00, m_populations, norm_drift=2.2e-7), §5 (delocalization observation), §6 (F32 floor framework issues), §7 (falsification table).
2. `runs/_loop/theorist/turn_43.md` §2.2 (Form-B commit), §2.3 (dx_crit derivation), §2.4 (prediction range [3000, 13000]), §2.5 (seed sigma — the load-bearing argument), §2.8 (sharp discriminator).
3. `runs/_loop/judge/turn_43.json` (issues list, FAIL_NUMERICAL with falsification_result=REFUTED in metrics).
4. Memory `yan_li_saito_2026_barnett_paper.md` lines 17-25 (paper torus GS spec) + lines 104-110 (locally-FM-globally-zero phase classification).
5. `runs/_loop/judge/turn_42_critic_audit.md` §A (grid hypothesis CORROBORATE) and §B (DDI bit-equal closure) — load-bearing for tier baseline and for what NOT to reopen at T44.
6. `runs/_loop/sim/turn_40.md` §4 (P4 fl_vortex at coarse grid n_max ≈ 0.62 D₀ — used to refute theorist §2.5's "T40 P4 showed topology doesn't matter" argument).
7. `CLAUDE.md` lines 65-67 (DDI conventions) + the "spin_rotating_frame_omega ≠ 0 requires secular_ddi=true" known-limitations bullet (used in §C(4) to confirm DDI off-diagonal active at B_z=0).

Sources cited: **7**.

## 5. Metrics block

```json
{
  "critic_md_on_disk": false,
  "critic_md_returned_inline": true,
  "section_A_operational_classification_verdict": "ACCEPT-as-framework-limitation",
  "section_A_norm_drift_per_step": 3.5e-11,
  "section_A_f32_floor_argument_accepted": true,
  "section_B_discriminator_verdict": "PARTIAL-CLOSE",
  "section_B_form_b_genuinely_refuted_at_dx_0p125": true,
  "section_B_finer_dx_crit_still_possible": true,
  "section_C_confounder_verdict": "CONFOUNDER-CONFIRMED",
  "section_C_c1_zero_freezes_spin_texture": true,
  "section_C_ddi_offdiag_mixing_rate_per_t_ho": 2.4e-5,
  "section_D_form_a_volumetric_ceiling_consistent": "CONFIRMED",
  "section_D_volumetric_ceiling_estimate_d0": 1.73,
  "section_D_observed_n_max_d0": 2.0,
  "section_E_t44_routing": "R2",
  "section_F_tier_recommendation": 0.75,
  "sources_cited": 7,
  "new_evidence_for_meta_critic_placement": "judge.py strict 1e-8 norm gate fires spuriously on F32 ITP at 6250 steps (~3.5e-11/step actual); recommend a workload-aware effective tolerance: eff_tol = max(1e-8, n_steps * 1e-9) for F32 mode."
}
```

VERDICT: PASS
