---
turn: 83
subagent: critic
directive_action: critic_audit
directive_label: edh-matsui-update-T83-critic-operational-gate-deep-audit
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, update-stage, critic-independent-audit, f3-operational-gate-resolution, energy-convention-extensive-vs-intensive, zeeman-shift-handling]
depends_on: [82, 81, 80, 72, director/turn_83, sim/turn_82, theorist/turn_72]
produces: "INDEPENDENT verdict on F3 OPERATIONAL_GATE + F1 NOT_APPLICABLE: classification + next-action pointer for T84"
---

# Turn 83 — Critic Update: EdH-Matsui F3 OPERATIONAL_GATE Deep Audit

## 1. Verdict-up-front

**VERDICT: PASS** (with errata to T82 implementer's §8 interpretation).

**F3 CORROBORATE_AFTER_CONVENTION_FIX**. The OPERATIONAL_GATE was a **misinterpretation by the T82 implementer**, not a framework, theory, or convention bug. The implementer divided `gs_energy_final = -967.027 ℏω_ref` by `N=30000`, getting `e_sim/atom = -0.0322` and then comparing against T72's `+10.5 ℏω_ref/atom`. But `total_energy()` in `src/analysis/energy.jl` (verified line-by-line below) is already **INTENSIVE / per-atom** by construction, because (a) ψ is normalised to `∫|ψ|² dV = 1` (state_dispatch.jl:332-333) and (b) `c0` is normalised by the constraint `c₀+36c₁=4π(a_s/a_ho)N` so it absorbs **one** factor of N. The kinetic, trap, Zeeman and DDI terms with unit-norm ψ all return per-atom energies; the contact term `(c0/2)∫|ψ|⁴ dV` with `c0 ∝ N` also returns per-atom (one N already cancelled). Reading the raw `-967.027` as per-atom and applying T80's `p_dimless = -162.78` for Bz=-0.01 G GS: per-atom Zeeman of dominant m_F=-6 = `-p·m = -(-162.78)·(-6) = -976.7 ℏω_ref/atom`. Per-atom non-Zeeman = `-967.027 - (-976.7) = +9.67 ℏω_ref/atom`. T72 prediction = `+10.5 ℏω_ref/atom`. **Corrected relative error = |9.67 - 10.5|/10.5 = 7.9%, well within CORROBORATE band <20%**. T72 §5.3 derivation independently re-verified line-by-line as **correct**. T84 recommendation: implementer_text Document with T82 §8 errata, advance tier 2.5 → 2.75; T85 closure at 3.0.

**F1 NOT_APPLICABLE_NO_RING ratified** (with caveat). Sub-percent pop_c12 across all 12 frames is not contestable; the 1%-population guard is physically sound. Recommend longer-dynamics rerun (~50 ms physical = 30 dimless) **deferred** until F3 closure; not blocking tier advance.

## 2. Task A — Independent re-derivation of T72 §5.3 E_mf/N at Case A

Parameters: N=30000, ω_ref = 2π·100 Hz = 628.32 rad/s, a_s = 110 a_B, m = 151·AMU.

Constants used:
- ℏ = 1.0546e-34 J·s; m_p = 1.6605e-27 kg (AMU); μ_B = 9.274e-24 J/T; μ_0 = 1.2566e-6 T·m/A; a_B = 5.292e-11 m.

**Step A.1 — a_ho.**
- m_Eu = 151 · 1.6605e-27 = 2.5074e-25 kg
- m·ω = 2.5074e-25 · 628.32 = 1.575e-22 kg/s
- a_ho² = ℏ/(m·ω) = 1.0546e-34 / 1.575e-22 = 6.696e-13 m²
- a_ho = 8.183e-7 m = **0.8183 μm**. ✓ matches T72.

**Step A.2 — a_s in SI.**
- a_s = 110 · 5.292e-11 = 5.821e-9 m.

**Step A.3 — TF parameter (N·a_s/a_ho).**
- N·a_s/a_ho = 30000 · 5.821e-9 / 8.183e-7 = 30000 · 7.114e-3 = **213.4**. ✓

**Step A.4 — μ_TF / (ℏω_ref).**
- 15·(N a_s/a_ho) = 15·213.4 = 3201
- 3201^(2/5): ln(3201)=8.0712; ·(2/5)=3.2285; exp=25.245
- μ_TF/(ℏω_ref) = (1/2)·25.245 = **12.62**. ✓

**Step A.5 — Contact-TF per-atom (5/7 μ_TF rule).**
- (5/7)·12.62 = 9.013 ℏω_ref/atom.

**Step A.6 — Zero-point (3/2 ℏω_ref per atom, isotropic).**
- 1.500 ℏω_ref/atom.

**Step A.7 — DDI at κ=1 (isotropic).**
- f(κ=1) = 0 (Eberlein-Giovanazzi 2005 closed form); E_DDI/N = 0. ✓

**Step A.8 — LHY scalar correction.**
- TF peak: n_peak = (15N)/(8π R³). R = a_ho·√(2μ_TF/(ℏω)) = 0.8183e-6·√(25.24) = 0.8183e-6·5.024 = 4.111e-6 m.
- R³ = 6.948e-17 m³ = 69.4 μm³.
- n_peak = 4.5e5 / (8π · 6.948e-17) = 4.5e5 / 1.746e-15 = **2.577e+20 m⁻³** = 258 μm⁻³.
- T72 reported `n_peak = 61.6 μm⁻³` (4.2× low). Trace: T72 used `n_peak = 15N/(8π · V_TF)` with `V_TF = (4π/3)R³`, which double-counts the `(4π/3)` factor. Canonical TF harmonic peak is `15N/(8π R_x R_y R_z)` — see Erratum E2 below.
- LHY ratio (n a_s³)^(1/2): 2.58e20 · (5.82e-9)³ = 5.08e-5; √ = 7.1e-3 → LHY ~0.7% of contact ≈ 0.06 ℏω_ref/atom. Negligible.

**Step A.9 — Total per-atom mean-field at Case A.**
- E_mf/N = 1.500 + 9.013 + 0 + 0.06 = **10.57 ℏω_ref/atom**. ✓ T72's `10.5` rounded.

**Step A.10 — Convention disambiguation.**
T72 §5.3 writes "10.5 ℏω_ref in dimensionless units" with the per-atom formula E_mf/N = (3/2)ℏω + (5/7)μ_TF. The (5/7)μ_TF result IS per-atom by construction. **`E_mf/N` is unambiguously per-atom intensive**.

## 3. Task B — src/analysis/energy.jl convention audit

Read `src/analysis/energy.jl` (full file, 409 lines) and `src/workflow/initialization/state_dispatch.jl:332-333`.

**Normalisation of ψ.** `state_dispatch.jl:332-333`:
```
norm = sqrt(sum(abs2, psi) * dV)
psi ./= norm
```
After construction (and equivalently after `find_ground_state` ITP renormalisation), `∫|ψ|² dV = 1`. **ψ is UNIT-NORMALISED**, not N-normalised.

**Interaction scaling.** Per `CLAUDE.md §¹⁵¹Eu` constraint: `c₀ + 36 c₁ = 4π(a_s/a_ho)·N`. So `c0 ∝ N`. This is critical — the contact `c0/2 · ∫|ψ|⁴ dV` with unit-norm ψ + `c0 ∝ N` evaluates as `(g·N/2)∫|ψ|⁴ dV`. Compare to physical extensive contact `(g/2)∫|Ψ|⁴ dV = (g/2)·N²·∫|ψ|⁴ dV` (where Ψ=√N ψ is the N-normalised wavefunction). Ratio: code/physical = `1/N`. Code returns **physical / N = per-atom**.

**Per-term audit** (line numbers in `src/analysis/energy.jl`):

- `_kinetic_energy` (l.126-145): `Σ k²|ψ̂|² · dV / n_pts` summed over components. With unit-norm ψ, this gives the per-atom kinetic energy (`⟨k²⟩/2` integrated). **Per-atom**.
- `_trap_energy` (l.147-162): `Σ V_trap·|ψ|² · dV`. With unit-norm ψ: per-atom trap energy `∫V|ψ|²dV`. **Per-atom**.
- `_zeeman_energy` (l.164-178): `Σ_c (-p·m + q·m²) · ∫|ψ_c|² · dV`. With `Σ_c ∫|ψ_c|² · dV = 1`, this is the per-atom Zeeman energy. **Per-atom**. Includes full `-p·m + q·m²` — **no min(E_m) shift** (consistent with the implementer's claim; the shift only lives in `apply_diagonal_potential_step!` propagator, propagators.jl:65, which I verified). ITP-shift inclusion: **FALSE**.
- `_density_interaction_energy` (l.180-194): `(c0/2)·∫|ψ|⁴ dV`. With `c0 ∝ N` and unit-norm ψ, this is per-atom (one N already cancelled). **Per-atom**.
- `_spin_interaction_energy` (l.273-282): `(c1/2)·∫|F|² dV` where `F = ψ†F̂ψ`. Same scaling argument. **Per-atom**.
- `_ddi_energy` (l.289-330): `(1/2)·Σ Φ_α · F_α · dV`. `c_dd` in `DDIParams.C_dd` is a SI-unit constant `μ₀μ²` (no N factor); the DDI energy with unit-norm ψ has F ∝ |ψ|², so it's like `c_dd·n²·V` integrated — but since `n = N|ψ|²` and the workspace's `c_dd_dimless` is computed with the N factor at YAML-load time (`make_workspace` scales c_dd to dimensionless via `c_dd / (ℏω·a_ho³) · N`), this is also per-atom. **Per-atom** (matches T72 prediction convention).
- `_lhy_energy` (l.223-238): `(2/5)·c_lhy·∫n^(5/2)·dV`. `c_lhy` per workspace contains N^(3/2) — per-atom by same chain. **Per-atom**.

**`total_energy()` (l.122-124)**: sum of all per-atom terms = **TOTAL ENERGY IS PER-ATOM (INTENSIVE) by code construction**.

**Conclusion: convention = INTENSIVE (per-atom).** Reading `gs_energy_final = -967.027` as already-per-atom is the correct interpretation.

**Verification of propagators.jl ITP shift claim.** Confirmed `src/hamiltonian/integrator/propagators.jl:65`: `zee_shift = imaginary_time ? minimum(zeeman_diag) : 0.0`. The shift lives **inside the ITP propagator only**, and the shift only affects per-component phase evolution; it cancels across the wavefunction reconstruction. `total_energy()` reads the converged ψ and computes raw `-p·m + q·m²` without any shift. **CONFIRMED: ITP min(E_m) shift does NOT propagate to total_energy.** Consistent with both T82 §8 claim and CLAUDE.md §Conventions.

## 4. Task C — Sim vs theory reconciliation

**Raw datum.** `gs_energy_final = -967.027 ℏω_ref` (per-atom by §3).

**T80 Zeeman analysis** (`runs/_loop/theorist/turn_80.md` cited in T82 metrics): Bz = -0.01 Gauss → p_dimless = -162.78. With dominant m_F = -6 (pop[c=13] = 0.9999 per T81): E_Zee/atom = (-p·m) = -(-162.78)·(-6) = **-976.7 ℏω_ref/atom**. This includes q·m² term (negligible per T72 §2.4: q/p ~ 1e-8 at Bz=2.6 nT; at 0.01 G also negligible for the purposes of this audit).

Cross-check: my own p_dimless computation. g_F·μ_B·|B| = 1.163·9.274e-24·1e-6 T = 1.078e-29 J. ℏω_ref = 1.0546e-34·628.32 = 6.625e-32 J. |p_dimless| = 1.078e-29/6.625e-32 = **162.7** ✓. Sign convention `H_Zee = -p·m` with Bz<0 gives p<0.

**Per-atom non-Zeeman energy.**
`E_nonZee/atom = -967.027 - (-976.7) = +9.67 ℏω_ref/atom`.

**T72 prediction.** `+10.57 ℏω_ref/atom` (Task A re-derived; T72 quoted 10.5).

**Corrected F3 metric.**
- `|E_sim/atom - E_mf/atom| / |E_mf/atom| = |9.67 - 10.57| / 10.57 = 0.85 / 10.57 = 0.080 = **8.0%**`.

**F3 classification.** T72 §5.5 CORROBORATE band: `< 20%`. **8.0% << 20% → CORROBORATE.**

**F3 verdict: CORROBORATE_AFTER_CONVENTION_FIX** (with errata to T82 §8 interpretation).

The 32,580× and 100.3% discrepancies in T82 §8 were both artefacts of the wrongly-performed division by N (T82 implementer's line 308: `e_sim_per_atom = e_gs_total / N_ATOMS`). The sim agrees with the T72 mean-field to **7-8%** — well inside the CORROBORATE gate.

## 5. Task D — F1 NOT_APPLICABLE ratification

**5.1 Ratify NOT_APPLICABLE_NO_RING classification.** Yes. Per the 12-frame summary, `pop_c12 < 0.2%` everywhere. The geometric ring criteria (depth>20%, aspect>1.5) firing at depth=92-99% / aspect=12-998 across all frames is a numerical artefact: when `pop_c12 ~ 1e-5` the spinor component density at the center is dominated by initialization noise (~1e-7 amplitude squared), so the depth ratio `(n_off - n_0)/n_off` saturates near 100% trivially. **The implementer's 1%-population guard is physically justified**: a ring of ~56 atoms (0.19% of 30,000) is not an observationally meaningful structure; Matsui's experimental detection threshold is closer to 10% population transfer to m_F=-5 over τ_EdH=5 ms.

**5.2 Audit the 1% threshold value.** The choice of 1% is reasonable (sub-percent = sub-Poisson signal in a 30k-atom system) but is a refinement of T72 §6.2 (which omitted any pop guard). The threshold could justifiably be anywhere in [0.5%, 5%] without changing the verdict at the current dataset (max pop_c12 = 0.186%). The classification NOT_APPLICABLE_NO_RING is robust to this threshold choice. **Ratify with note**: T84 Document should add the 1% guard back to the T72 §6.2 falsifier text as a calibration refinement, not as a deviation.

**5.3 Longer-dynamics rerun?** Recommend YES, **but deferred until after F3 closure documents tier 3.0**. Reasoning:
- Currently pop_c12 grows 40× in 10 ms (4.78e-5 → 1.86e-3). Extrapolating with the same exponential rate (`Γ = ln(40)/10ms = 0.37/ms`), reaching pop_c12 = 1% requires `t = ln(1e-2/4.78e-5)/0.37 = ln(209)/0.37 = 14.4 ms`. To reach 10% (close to physical observation threshold) requires `~21 ms`.
- After Erratum E2 (Task A.8: corrected τ_DDI ~0.14 ms instead of 0.57 ms), the predicted t_ring upper band shifts down to ~14 ms — so a 30-dimless run (= 48 ms physical) would comfortably bracket the predicted ring.
- Recommended rerun duration: **30 dimless (= 47.7 ms physical, ~10× τ_EdH^exp)**.
- Cost estimate: T81 ran 6.28 dimless / 628 steps in ~30 min GPU wall = ~3 min/dimless. 30 dimless → ~90 min GPU wall ≈ **3M effective**. Plus save volume scales linearly: 30 dimless / save_every=50 = 60 frames at 47 MB/frame × precision=f32 (~14 MB/frame) = ~840 MB jld2 (vs current 48 MB). Disk acceptable.

**Recommendation: yes, but defer to T85+** (after F3 Document at T84). Not blocking on F3 closure to tier 2.75/3.0.

## 6. Task E — T84 next-action pointer

**Single explicit T84 directive**: `T84 dispatches implementer_text Document. Produces (a) memory entry runs/_local/memory_drafts/edh_matsui_baseline_2026.md capturing: T72 §5.3 derivation correct (E_mf/N = 10.57 ℏω_ref/atom at Case A); T82 §8 implementer interpretation erratum (energy is intensive, not extensive — do NOT divide by N); src/analysis/energy.jl convention verification (PER-ATOM by construction); F3 corrected rel_error = 8.0% (CORROBORATE); F1 NOT_APPLICABLE ratified, longer-dynamics rerun deferred to T85+; (b) T72 §5.3 errata addendum (note that 10.5 is in agreement with sim 9.67); (c) T82 §6.2 falsifier refinement addendum (add 1% pop guard); (d) state.json patch: tier_current 2.5 → 2.75, current_stage = "Document (F3 CORROBORATE; F1 deferred-rerun)". Total tier 3.0 closure at T85 after one verification turn (implementer_text confirms patches landed cleanly). NO Julia execution required at T84.`

## 7. Errata

**ERRATUM E1 — load-bearing — T82 §8 (sim/turn_82.md line 308 + the entire F3 reconciliation block lines 326-407)**: The line `e_sim_per_atom = e_gs_total / N_ATOMS  # ℏω_ref/atom` is **incorrect**. `total_energy()` is already per-atom (intensive) by code construction (Task B). Correct interpretation: `e_sim_per_atom = -967.027 ℏω_ref/atom` directly. After Zeeman subtraction with T80's `p_dimless = -162.78`: `non-Zeeman per-atom = +9.67 ℏω_ref/atom`, agreeing with T72 §5.3 prediction of +10.5 to within 7-8%. The OPERATIONAL_GATE classification was triggered by this misinterpretation; with correct intensive reading, F3 = CORROBORATE.

**ERRATUM E2 — advisory — T72 §3.2 peak density formula**: The expression `n_peak = 15 N / (8π · V_TF)` with `V_TF = (4π/3) R³` double-counts the `(4π/3)` factor. Canonical harmonic-trap TF peak is `n_peak = 15N/(8π R_x R_y R_z)` (i.e. just R³, no 4π/3). Effect: T72's reported `n_peak = 6.16e19 m⁻³` should be `2.58e20 m⁻³` at Case A — 4.2× larger. **Downstream impact**: τ_DDI ≈ 0.14 ms (not 0.57 ms); F1 t_ring band shifts from [5.7, 57] ms → [1.4, 14] ms (still brackets experimental 5 ms). **The F3 prediction E_mf/N = 10.5 ℏω_ref/atom is unaffected by E2** (uses μ_TF, not n_peak).

**ERRATUM E3 — advisory — T82 §6 / T72 §6.2 falsifier text**: T82 implementer added a `pop_c12 >= 0.01` guard not present in T72 §6.2. The addition is physically justified (Task D) and should be back-ported into the F1 falsifier text in the state.json record. Not a deviation; a refinement.

**ERRATUM E4 — advisory — T82 metrics field `f3_zeeman_subtracted: false`**: This field is technically correct (the value -967.027 includes Zeeman) but the surrounding interpretation in `f3_zeeman_reconciliation_note` is internally inconsistent (some sentences treat -967.027 as extensive, others as intensive; the implementer flips conventions mid-paragraph). T84 Document should publish a clean per-atom decomposition table.

**errata_count = 4; load-bearing = 1 (E1); advisory = 3 (E2, E3, E4)**.

## 8. Independent references cited

Beyond director's listed references, this critic consulted:

1. `src/workflow/initialization/state_dispatch.jl:332-333` — the canonical normalization point (`norm = sqrt(sum(abs2, psi) * dV); psi ./= norm`). Establishes ψ is unit-normalised.
2. `src/foundation/types/interactions_zeeman.jl:29-43` — `InteractionParams` struct, confirms `c0`, `c1` are stored as the dimensionless scaled couplings (N-scaling absorbed upstream at YAML-load time).
3. `src/workflow/initialization/atoms.jl:208-219` — Eu151 `AtomSpecies` definition, `μ = g_J · 3.5 · μ_B` (≈ 6.977 μ_B), `g_F = g_J · 7/12 ≈ 1.163`, `a_s = 110 a_B`. Confirms T72's atomic constants.
4. `src/hamiltonian/integrator/propagators.jl:55-65` — explicit comment `NOT GENERALIZABLE: ITP-only shift zee_shift = min(zeeman_diag) prevents exp overflow ... constant rephasing that cancels across components, does NOT bias ψ. Skipped in real-time (cis is bounded)`. Verifies T82 §8 claim that the shift does not propagate to `total_energy`.
5. Eberlein, Giovanazzi & O'Dell, PRA 71, 033618 (2005) — `f(κ)` closed-form for dipolar TF clouds; `f(κ=1)=0` for spherical, basis for T72 §5.2 `E_DDI/N ≈ 0` at Case A. Independent literature ground for the DDI=0 claim.
6. Lahaye, Menotti, Santos, Lewenstein & Pfau, Rep. Prog. Phys. 72, 126401 (2009) — review of dipolar BECs; cited for Eberlein-Giovanazzi prefactors and TF dipolar energy convention.
7. Pitaevskii & Stringari, *Bose-Einstein Condensation* (Oxford, 2003) §11 — canonical Thomas-Fermi formulas; `(5/7)μ_TF` per-atom contact energy at harmonic trap.
8. CLAUDE.md §¹⁵¹Eu constraint `c₀+36c₁=4π(a_s/a_ho)N` — load-bearing for the per-atom convention deduction in Task B.

**n_references_cited = 8.**

## 9. Metrics block

```json
{
  "experiment_kind": "critic_audit",
  "workload_class": "critic",
  "f3_critic_classification": "CORROBORATE_AFTER_CONVENTION_FIX",
  "f3_corrected_rel_error": 0.080,
  "f3_convention_resolved": "intensive",
  "t72_section_5_3_correctness": "correct",
  "src_energy_jl_convention": "INTENSIVE per-atom by construction: psi normalised to int|psi|^2=1 (state_dispatch.jl:332-333); c0 absorbs one factor of N via c0+36c1=4pi(a_s/a_ho)N constraint (CLAUDE.md Eu151); contact term (c0/2) int|psi|^4 dV evaluates to per-atom (physical extensive divided by N). Kinetic/trap/Zeeman/DDI/LHY all per-atom by same chain. total_energy() (l.122-124) is per-atom intensive scalar.",
  "src_energy_jl_zeeman_inclusion": true,
  "f1_classification_ratified": true,
  "f1_pop_guard_1pct_justified": true,
  "f1_longer_dynamics_rerun_recommended": true,
  "f1_longer_dynamics_rerun_duration_dimless": 30.0,
  "f1_longer_dynamics_rerun_cost_estimate_M": 3.0,
  "next_action_for_t84": "T84 implementer_text Document: memory entry edh_matsui_baseline_2026.md (T72 derivation correct, T82 sim/turn_82.md section 8 erratum, src energy.jl per-atom convention, F3 corrected rel_error 8.0% CORROBORATE, F1 NOT_APPLICABLE ratified, longer-dynamics rerun deferred T85+); T72 section 5.3 errata addendum noting agreement; T82 section 6.2 falsifier refinement addendum (pop guard 1%); state.json patch tier_current 2.5 to 2.75 current_stage Document. NO Julia execution at T84.",
  "tier_recommendation": 2.75,
  "verdict_token": "CORROBORATE_WITH_ERRATA",
  "errata_count": 4,
  "errata_load_bearing_count": 1,
  "errata_advisory_count": 3,
  "n_references_cited": 8,
  "derivation_lines_independent": 62
}
```

## 10. Self-review checklist

- [x] Re-derived T72 §5.3 line-by-line from scratch (Task A: 10 sub-steps, independent constants, ~62 lines of algebra)
- [x] Read src/analysis/energy.jl with specific line citations (Task B: per-term breakdown with line numbers l.122, l.126-145, l.147-162, l.164-178, l.180-194, l.223-238, l.273-282, l.289-330; also state_dispatch.jl:332-333 normalization, propagators.jl:55-65 ITP shift)
- [x] Reconciled sim vs theory with EXPLICIT convention map (Task C: corrected rel_error 8.0% by reading sim value as intensive per src code, subtracting T80-derived Zeeman -976.7 to get non-Zeeman +9.67, comparing to T72 prediction +10.57)
- [x] Ratified F1 NOT_APPLICABLE with longer-dynamics rerun recommendation deferred (Task D: 30 dimless / 47.7 ms physical / ~3M effective cost, after tier 2.75 closure)
- [x] Emitted concrete T84 pointer (Task E: implementer_text Document with 4 deliverables specified)
- [x] No Julia execution attempted (text-only audit, Read-only tool use)
- [x] No src/ modifications (read-only)
- [x] Metrics block judge-machine-readable (all required fields populated; all enum values from canonical sets)
- [x] No anko-attribution in critic text (cites only file paths, line numbers, prior turns, established literature)
- [x] No improvised terminology (uses TF / Eberlein-Giovanazzi / Larmor / DDI / m_F / per-atom / intensive / extensive — established terms)
- [x] Looked for elegant single-cause explanation first per feedback_mathematical_elegance_bias: the elegant explanation IS the convention discovery (one factor of N misplaced). Did NOT invoke framework bug or theory rewrite when a code-reading suffices.
- [x] No new falsifiers invented; audited F1/F2/F3 as defined
- [x] No manuscript polish; pure D1 verification
- [x] Cost budget: targeted 1.0-1.4M, hard cap 1.7M (text-only critic with bounded file reads).
