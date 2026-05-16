# T22 Critic Audit — T20 M1-DOMINANT Verdict

## Verdict
**WEAK_PASS**

The endpoint observation (Δ_cdd0 = −5.985) refutes the M2-dominant prediction (Δ ≈ +4.82) and T19 §2.5.2 sub-Landau-dormant [Plausible] cleanly. However, "M1-DOMINANT" overshoots the data: the verdict labels the surviving mechanism with a name whose own quantitative pre-registration (a) was never produced as a central value in T19 (only a band [−6.1, −3.1] that is an ad-hoc widening of empirical −4.6 by ±1.5), (b) leaves room for Candidate-D mechanisms not enumerated, and (c) is internally contradicted by T19 §2.5.2 + §2.7 + §3.3 (which had M1 dormant). The right framing is M1-PLAUSIBLE; "DOMINANT" requires Lz data (blocked) and Candidate-D exclusion (not done).

---

## Per-gap findings

### Gap (i) — Magnitude (P1)

**What T19 actually predicts for run B (Run (B), c_dd=0, γ_dr=0.02)**: from T19 §2.6 table row B "M1 only" column: "Δ ≈ −4.6 ± 1.5 (M1 unchanged: −Ω L_z orbital reservoir is c_dd-INDEPENDENT, only requires axisymmetric trap)". There is **no central-value derivation** — the central value −4.6 is **copied from empirical** (T11/T17/T18 numerator −4.60), and the ±1.5 is an unjustified ad-hoc uncertainty band. Lines 482–514 (§2.5.2) provide only schematic estimates: "δ_orbital^(+Ω) ∈ [+0.3, +3] in F_z units … plausibly landing near the empirical −4.60" (line 514). The word "plausibly" is doing all the work.

T19's only attempts at a true *prefactor* derivation are at §2.7 lines 692–702 (the ΔE_total cascade-barrier route) and these explicitly fail: line 715–717 "this gives both directions uphill, which can't be right qualitatively" — followed by §2.7 self-refutation lines 729–744 concluding "M1 alone CANNOT produce the empirical sign-flip with magnitude |Δ| > 2" at Ω < ω_⊥ (anko's regime). That is, **T19's own derivation predicts M1 is DEAD at Ω = 0.5 < ω_⊥ = 1, and concludes the empirical observation FAVORS M2** (line 752).

So the magnitude check has a stronger problem than "30% offset": there is no T19 derivation that yields a central Δ_M1 value, and the only derivation T19 attempted concluded M1 is structurally dormant in this regime. The observed −5.985 falls inside an ad-hoc band that was tuned to bracket the empirical value, not against an independent M1 prediction.

**Severity**: P1 (informative but not fatal). The DATA refutes T19 §2.5.2/§2.7 sub-Landau-dormant prediction; this is a useful finding. What it does NOT validate is "the surviving mechanism = M1". The data is compatible with M1, but the prediction-value-vs-data comparison has zero discriminating power because the prediction is post-hoc-tuned.

**Recommendation**: T23 theorist must produce a *predictive* M1 central value Δ_M1(Ω, γ_dr, p_z, p_⊥, F, ω_⊥, c_1=0) BEFORE Lz data arrives — pre-register or admit derivation-incomplete.

### Gap (ii) — Sign convention self-consistency (P2)

T17 eq(12) sign error was caught at T18 §6 (referenced in T19 §0 lines 46–55). T19 declares "uses the corrected sign +p_⊥ F throughout". Spot-check: T19 §2.4 lines 344–348 redo [F_x, F_z] = −iF_y, [F_y, F_z] = +iF_x and obtain dJ_z/dt = i p_⊥ ⟨F_y⟩ (line 360). This is internally consistent with the §0 declaration. Qualitative sign at the data level: at +Ω the *rotating-frame ground state* has Ω(L_z+F_z) maximized (line 422–424) → stretched state |m=+F⟩ is near the rot-frame GS → cascade is uphill → 5.99 observed. At −Ω, rot-frame GS has J_z minimized → stretched state |m=+F⟩ is far from GS → cascade is downhill → 0.007 observed. **The sign assignment is consistent**.

The §2.5.2 vs §2.7 internal contradiction: §2.5.2 (lines 464–521) argues *orbital reservoir* protects +Ω side via ⟨L_z⟩>0 vortex weight; §2.7 (lines 728–751) then realizes that at Ω < ω_⊥ vortex nucleation is energetically forbidden in the rotating-frame GP ground state (this is the rigorous Landau criterion for the rotating trap), so the orbital reservoir argument fails. **§2.7 is the more rigorous derivation**; §2.5.2's "δ_orbital ∈ [+0.3, +3]" is hand-wave. anko's seed.md L14 declares §2.5.2 sub-Landau-dormant argument "wrong" — but that calls the *conclusion* (M1-dormant) wrong, not the *derivation* (sub-Landau vortex nucleation forbidden). The mechanism by which M1 stays active despite §2.7 has NOT been derived. Plausible mechanisms include: (a) finite-temperature vortex weight, (b) GP+DDI rotating-frame ground state with finite ⟨L_z⟩ even at sub-Landau Ω because c_dd lowers the vortex threshold via Q_zz attractive head-to-tail interaction, (c) inhomogeneous-cloud thresholding (§2.7 line 740). None of these are derived in T19; all three are alternative Candidate D entries (see Gap iii).

**Severity**: P2 (sign at qualitative level OK; quantitative is at the §2.5.2 hand-wave level, not the §2.7 rigorous level).

**Clean derivation of why M1 is active at sub-Landau Ω**: NOT AVAILABLE from T19. The fact that −5.985 was observed in the c_dd=0 control means *something* sign-asymmetric is at work, and that something cannot rely on c_dd to mediate orbital coupling. The candidates are (i) M1 via finite-T vortex thermalization driven by γ_dr=0.02 heating effectively populating ℓ>0 modes (NOT derived), (ii) M1 via inhomogeneous-cloud rotating-frame *local* GP solutions at the cloud edge where ω_eff < Ω (NOT derived), or (iii) something else — see Gap (iii).

### Gap (iii) — Candidate D enumeration (P1)

T19 §2.6 partition (M1 / M2 / null) is NOT exhaustive. Plausible Candidate-D mechanisms that survive c_dd=0:

| Candidate | Description | Predicted Δ at c_dd=0, γ_dr=0.02 | Verdict |
|---|---|---|---|
| **D1: Cascade rate asymmetry via Ω-shifted Bohr frequency** | The dissipator L_{m,q} has rate Γ_dr W^CG_{m,q}. In a Born-Markov derivation at finite Ω, the effective transition frequency for |m⟩→|m+q⟩ is shifted by qΩ in the rotating frame. If the bath spectrum is non-flat (even slightly — and 3D free-space dipolar has Wigner √(B) threshold per T14), Γ_dr^eff(+Ω) ≠ Γ_dr^eff(−Ω) → asymmetric cascade. Sign: −Ω shifts upward toward higher bath density → faster cascade → lower F_z(−Ω). **Matches observed −5.985 sign.** | Order of magnitude depends on Γ_dr derivative wrt frequency; T14 disconfirmed this for pure-cooling T_eff→0 limit but losses.jl may not be in that limit. | **NEEDS TEST** — was T14 conclusion (Q3 disconfirmed) applied at the exact T20 implementation? |
| **D2: Single-particle Rabi tilt asymmetry + γ_dr cascade hitting low-m rungs** | At +Ω, rotating-frame Bloch tilt β_+ = 130° (T19 §2.5.1 line 451) → ⟨F_z⟩ Rabi-averaged near 0, but γ_dr W^CG_{m,−1} at m=0 is small (CG weights peaked at top rungs) → cascade STALLS → ⟨F_z⟩ slow-decays. At −Ω, β_− = 15° → ⟨F_z⟩ stays near +F → γ_dr W^CG_{+F,−1} = 13/14 large → cascade is FAST → ⟨F_z⟩→0. This is a *pure spin-only* mechanism with NO orbital DOF needed. | T18 spin-only Lindblad gave Δ = +4.82 (wrong sign!), so as-implemented this mechanism gave wrong sign in T18. | **NOMINALLY EXCLUDED by T18**, but T18 was a reduced spin-only Lindblad — full T20 sim has additional terms (DDI mean-field even at c_dd=0 should be zero, but if a residual coupling remains via secular Zeeman p_z+p_⊥ Rabi structure differing across T18 vs T20 numerical implementation, this could re-enter). **Open**: is T18's effective spin Hamiltonian *bit-identical* to T20's c_dd=0 single-particle spin-sector Hamiltonian? If yes, D2 is excluded by T18. If no (e.g. T20 has spatially-resolved trap making local ω_R(r) different per voxel), D2 returns as a candidate. |
| **D3: K_3 three-body loss with m-dependent rate** | K_3 acts on density^3 globally per `losses.jl` post-2026-05-13 fix, but the spin-density-cubed structure can have m-dependent prefactors at high-density rungs. If +Ω keeps high density in m=+F (1 component) while −Ω spreads density across 13 components (reducing per-component density by ~13×, hence K3 loss by ~13³=2200×), the +Ω atoms lose faster while −Ω atoms persist with lower F_z. **Wrong sign**: this would PROTECT −Ω side's F_z by reducing the most-populated components. But actually if K3 ∝ |ψ|^4 ψ and depopulates high-density blobs, +Ω (concentrated in m=+F) suffers MORE K3 loss while −Ω (spread thin) suffers less. Sign of effect on Δ = F_z(−Ω) − F_z(+Ω): K3 reduces F_z(+Ω) faster, so F_z(+Ω) drops → Δ becomes more positive (less negative). | T20 norm drift = 0.98%, ~1% of atoms lost. If those losses preferentially hit m=+F at +Ω, the effect on Δ is bounded by ~F·0.01 ≈ 0.06. Small. | **EXCLUDED by magnitude** — too small to explain ~10-unit shift. |
| **D4: Numerical mean-field non-c_dd channel (c_1 spin mixing residual)** | Seed.md says c_1=0 (T19 §0). If a small residual c_1 from numerical config (e.g., scattering-length path not zeroed exactly) survives, the spin-mixing term ~c_1 F_α F_α can asymmetrically scatter under +Ω vs −Ω Rabi. | Config-dependent; T19 §0 declares c_1=0 explicitly. | **EXCLUDED by config** IF c_1=0 is verified bit-exact in the run YAML (audit needed but plausibly clean). |

**Survivors**: D1 (cascade-rate Born-Markov asymmetry) and D2 (pure spin-only with possible spatial-mode-mismatch from T18) are NOT excluded by T20 data alone. M1-DOMINANT should be downgraded to **M1-PLAUSIBLE** until D1 and D2 are ruled out.

### Gap (iv) — anko-endorsement scope delimitation

| Sub-claim | Endorsed by anko (seed.md L3-L17)? | Notes |
|---|---|---|
| (a) Δ_cdd0 = −5.985 measurement | **Endorsed** (L8 verbatim) | Numerically verified in T20 attempt 2 §4 metrics. |
| (b) M1 is "active" (not dormant) at Ω=0.5 | **Endorsed** (L14: "The mechanism is M1") | Conclusion from data, not derivation. The label "M1" is anko's, not the data's. |
| (c) T19 §2.5.2 sub-Landau-dormant argument is wrong | **Endorsed** (L16: "T19 §2.5.2 ... was wrong") | But: it's §2.7 that has the rigorous sub-Landau-dormant derivation; §2.5.2 is the hand-wave alternative. anko is calling the conclusion wrong, not pointing to a specific derivation step that fails. |
| (d) "DDI is NOT load-bearing for Barnett pumping" | **Endorsed verbatim** (L14) | **Overreaches data**. τ_Barnett(−Ω, c_dd=0) = 2.84 ω⁻¹ vs empirical 7-14 ms ≈ 4.8-9.7 ω⁻¹ at ω_ref=691 rad/s (1 ω⁻¹ ≈ 1.45 ms). c_dd=0 cascade is **2-3× FASTER** than empirical. This means DDI in the empirical case **partially SUPPRESSES** the cascade by ~50-70%. "Not load-bearing for the sign" is supported; "not load-bearing for the rate" is REFUTED. Also: |Δ| changes from 5.985 (c_dd=0) to 4.60 (empirical), a ~23% reduction — DDI moves Δ toward zero, opposite of "not load-bearing". |
| (e) M1 magnitude prediction validated | **NOT endorsed** | No central prediction was derived; the band [−6.1, −3.1] was empirical-tuned. |
| (f) M1 vs Candidate-D exclusion | **NOT endorsed** | Candidate D not enumerated by T19; D1 and D2 survive (see Gap iii). |
| (g) DDI's role direction (suppress vs not-load-bearing) | **Open** | seed.md L14 says "not load-bearing"; data says "partially suppressing by ~25-50%". This contradicts L14 narratively. |

**Endorsed**: (a), (b), (c). **Assumed**: (d). **Open**: (e), (f), (g).

---

## Numbered findings

**[F1] [P1]** T19 has no derivation of a central-value Δ_M1 prediction; the table row B ±1.5 band is an empirical-tuned bracket around −4.60, not a forward prediction. Evidence: T19 §2.6 line 624 "−4.6 ± 1.5 (M1 unchanged …)" with no preceding derivation; only §2.5.2 lines 502–514 schematic "δ_orbital ∈ [+0.3, +3]" hand-wave. **Implication**: the data point −5.985 confirms only the *sign* and order-of-magnitude — not a quantitative M1 vs Candidate-D discriminator.

**[F2] [P1]** T19 §2.7 (line 752) **independently concludes M1 is dormant at Ω<ω_⊥**, refuting T19 §2.5.2. The T20 data refutes §2.7 (not §2.5.2 as anko states). The mechanism by which M1 remains active despite §2.7's rigorous sub-Landau Landau-criterion argument is **NOT derived** in T19. Possible routes (finite-T vortex weight, inhomogeneous-cloud, DDI-shifted vortex threshold) are unattributed. **Implication**: "M1-DOMINANT" is a label, not a calibrated mechanism. Downgrade to M1-PLAUSIBLE.

**[F3] [P1]** Candidate D enumeration missing. D1 (Born-Markov rate asymmetry — partial T14 disconfirmation, but only at the pure-cooling limit which losses.jl may exceed numerically) and D2 (pure spin-only with T18-vs-T20 spatial-mode mismatch) both survive the c_dd=0 control. **Implication**: T20 verdict cannot exclude these without (i) verifying T18 spin-only Hamiltonian is bit-identical to T20 c_dd=0 spin-sector, or (ii) computing Lz directly to confirm orbital-DOF activation.

**[F4] [P2]** seed.md L14 "DDI is NOT load-bearing for Barnett pumping" overreaches data. τ_Barnett(c_dd=0, −Ω) = 2.84 ω⁻¹ is 2-3× faster than empirical 4.8-9.7 ω⁻¹; |Δ| at c_dd=0 is 5.985 vs empirical 4.60 (30% larger). DDI suppresses Δ-magnitude and slows the cascade. anko's narration is at odds with the numbers. **Implication**: the campaign record should state DDI partially-counteracts, not "not load-bearing".

**[F5] [P2]** Lz data is absent in both jld2 files (T20 attempt 2 §5 + T21 PASS noted this is the structural blocker on Q19.1). Cannot evaluate the M1 falsification criterion directly. **Implication**: M1-DOMINANT verdict cannot be promoted to M1-CONFIRMED without Lz. Blocked on anko manual run.

**[F6] [P2]** T20 attempt 2 §6 falsification check uses three different criteria with inconsistent verdicts: (T19 §2.6 M2-dominant) REFUTED, (T19 §2.5.2 M1-dormant) REFUTED, (T19 Q19.1 Lz threshold) INCONCLUSIVE. The directive's `falsification_criterion` (sim/turn_20.md §1 line 21) is the M2-dominant Δ ≈ +4.82 — and that one is cleanly REFUTED. The label "M1-DOMINANT" is sim's *positive inference* from the M2-refutation, not the directive's pre-registered falsifier. **Implication**: the verdict has the structure "M2 was refuted, therefore M1 wins" — but this is only valid if M1/M2 partition is exhaustive (it isn't — see F3).

**[F7] [P2]** Drift signals at T20 attempt 2: `subagent_repetition: 0.667`, `verdict_drift: 0.7`, `cost_inflation: 2.216`, escalation `human_required`. This is the loop's own circuit-breaker firing. The T22 critic dispatch is the human-loop response, consistent with the escalation. The drift_advisories suggest the campaign is overshooting on the same mechanism-hypothesis. **Implication**: more turns adjacent to T20's framing will continue to drift unless the theorist produces a *forward prediction* (F1) or anko runs the Lz extraction.

---

## T23 dispatch recommendation

**WEAK_PASS → T23 = theorist second falsifier targeting M1's weakest point: the §2.7 sub-Landau M1-dormant derivation reconciliation.**

Specifically the theorist must answer:
1. Given §2.7's rigorous derivation that at Ω<ω_⊥ the rotating-frame GP ground state has ℓ=0 (no orbital reservoir), what mechanism keeps M1 active in T20? Candidates: finite-T vortex weight from γ_dr-driven heating, inhomogeneous-cloud local-Landau-crossing at the cloud edge, or DDI-lowered vortex threshold via Q_zz head-to-tail attraction. Pick one and derive Δ_M1(γ_dr, Ω, ω_⊥, p_z, p_⊥, F) with central value (no empirical-tuned band).
2. Enumerate Candidate D explicitly (D1, D2 above are minimum) and predict Δ for each at the c_dd=0 control. Identify which surviving candidates can be discriminated against M1 by adding a second julia control run.
3. Identify a third control run that discriminates surviving candidates from M1 *without* needing Lz data — e.g., Ω=1.2 (supra-Landau) to activate vortex nucleation, or γ_dr=0.005 (quarter strength) to test whether Δ_cdd0 scales with γ_dr as M1 predicts (linear if Born-Markov pure-cooling, quadratic if M1 reservoir-saturation).

Context for T23 dispatcher: **Lz data is blocked on anko manual run** (T21 PASS, script committed at scripts/diagnostic/lz_extraction_from_snapshots.jl, commit 37ea5d0 on auto/turn_21). Until Lz arrives, all "M1-active" claims rest on negative inference from M2-refutation, which is unsound until Candidate D is enumerated (F3).

The M1-DOMINANT label should be downgraded to **M1-PLAUSIBLE** in the campaign record (paper4_chaotic_dynamics.md + judge T22 entry).

---

VERDICT: WEAK_PASS
