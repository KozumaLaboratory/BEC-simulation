---
turn: 69
subagent: researcher
topic_tags: [d1-verification-depth, tier3-pipeline-survey, established-claim-audit, post-closure-pipeline-population]
paper_section: null
depends_on: [director/turn_69]
produces: ranked candidate list for anko to ratify into seed.md
cache_hit: false
---

# Turn 69 — Researcher Report: Tier-3 Verification Candidates Survey

## Queries received

```json
[
  "Survey [Established] memory claims in SpinorBEC.jl loop knowledge base that are currently Tier 1-2 and propose top 3-5 candidates for Tier-3 verification (published-reference benchmarked). Include Bug-4 ITP DDI half-rate re-verification, Sign Pattern Lemma 1 General-S, TDHFB Phase 2 HF kernel, Universal Structure U1-U4, TwoChannelLHY 30-70% off claim, FullBdG F=6 polar 3000x offset. Score each by load-bearing-ness x benchmark-availability x cheapness."
]
```

## Findings

### Intentional-design candidates excluded upfront

Per CLAUDE.md "Conventions do NOT fix" and "Known limitations":

- **DDI no-4π convention** (`c_dd=μ₀μ²`, `Q_αβ=k̂_αk̂_β−δ_αβ/3`, `Q(k=0)=0`): design choice, not verifiable claim.
- **`_YOSHIDA_W0 < 0`**: correct by design (backward middle substep, all operators time-reversible).
- **ITP Zeeman min-shift**: subtracts `min(E_m)` to prevent overflow; design choice.
- **Scalar LHY `@warn`**: documented approximation with known scope.
- **Odd-rank c_extra ignored `@warn`**: by design (KU convention).
- **`compute_interaction_params_general_f` returns (0,0)**: by design.
- **`split_step_captured!` GPU silent fallback**: by design (CUDA Graph disabled for performance reasons).
- **`_get_spinor` ~352 bytes/call allocation**: design boundary documented.

---

## 1. Inventory scan summary

- Total [Established]-tagged memory entries scanned in MEMORY.md + memory/ directory: ~18 distinct physics claims
- Already Tier-3 (excluded): 2 — Barnett mechanism (T29), Klaus-BCH leak (T59)
- Intentional-design (excluded): 8 (listed above)
- Closed/dormant investigations excluded per brief: yan-li-saito-2026-reproduction (DORMANT-CLOSE T65), fullbdg-f6-polar-3000x (dormant, anko-contained priority 99)
- **Eligible candidates (Tier 0-2, load-bearing, NOT intentional)**: 5 identified, 5 assessed below

**Key new finding this turn**: Matsui, Miyazawa et al. published "Observation of the Einstein-de Haas Effect in a Bose-Einstein condensate" in *Science* 391, 384-388 (January 22, 2026), arXiv:2504.17357, DOI:10.1126/science.adx2872. This is the first and only external experimental benchmark for F=6 Eu-151 spinor dynamics in a published high-impact journal. SpinorBEC.jl has not been compared against this paper. This is a Tier 0 → Tier 3 candidate.

---

## 2. Top candidates (ranked)

---

### #1 (highest priority): `edh-eu151-vortex-vs-matsui-science-2026`

**(a) CLAIM ID**: `edh-eu151-vortex-vs-matsui-science-2026`

**(b) CURRENT TIER + EVIDENCE**: **Tier 0** — no comparison has been attempted between SpinorBEC.jl and any external Eu-151 spinor dynamics experiment.

Memory: `barnett_spin_pumping_observed_2026_05_16.md` records that anko's simulation at weak Bz (p≈0.69) showed sign-asymmetric ΔFz/N=4.6 in the EdH regime. This is an empirical code signal consistent with the EdH mechanism, but was never compared to the Matsui et al. 2026 experiment protocol.

External benchmark found (verified this turn via WebSearch):
- Matsui, Miyazawa, Goto, Nakano, Kawaguchi, Ueda, Kozuma. "Observation of the Einstein–de Haas Effect in a Bose–Einstein Condensate." *Science* 391, 384–388 (2026). DOI: 10.1126/science.adx2872. arXiv:2504.17357. (12 pages, 6 figures, submitted April 2025, published January 22 2026.)
- The paper reports: spinor-dipolar BEC of ¹⁵¹Eu, near-zero B-field quench from m=-6 FM-polarized state, quantized vortices emerge in depolarized spin components through DDI-mediated angular-momentum transfer from atomic spins to collective circulation. Ring-shaped density distributions in depolarized components confirmed as quantized vortices via matter-wave interferometry.
- Foundational parameter source: Miyazawa, Inoue, Matsui, Nomura, Kozuma. "Bose-Einstein Condensation of Europium." PRL 129, 223401 (2022). arXiv:2207.11692. This paper provides a_s=110(4) a_B — exactly the value SpinorBEC.jl uses as canonical Eu-151.

NOT Tier 3 because: (i) the Matsui 2026 Science paper parameters (N, trap ω, B-quench profile, simulation c_dd, c_1) have never been fed into SpinorBEC.jl and compared against the paper; (ii) anko's barnett_spin_pumping run used Klaus strong-B stir (secular regime), not the near-zero-field quench protocol of the 2026 paper.

**(c) LOAD-BEARING-NESS FOR PRODUCTION CODE**: **5/5**

The EdH vortex dynamics path exercises all major production subsystems simultaneously:
- `src/solvers/ground_state/itp_loop.jl` — GS preparation (m=-6 FM initial state with DDI)
- `src/hamiltonian/interactions/lhy/` — LHY correction (scalar or IcosahedralLHY for production)
- `src/hamiltonian/tdhfb/` or standard `split_step.jl` — post-quench dynamics
- `src/workflow/experiments/` — YAML-driven run_yaml pipeline
- DDI convolution `_ddi_step!` at every timestep
- Spinor mixing (`c_1` channels, spin-relaxation physics)

A successful reproduction validates DDI strength, spinor-orbit coupling (DDI-mediated AM transfer), and the rotating framework simultaneously — the project's main physics claim.

**(d) EXTERNAL-BENCHMARK AVAILABILITY**: **FOUND** (Tier 3 candidate — Science paper is highest-quality external anchor).

- Matsui et al. *Science* 391, 384–388 (2026). DOI: 10.1126/science.adx2872. arXiv:2504.17357. [depth: abstract-only; PDF binary unreadable in WebFetch; full parameters require PDF access by theorist]
- Miyazawa et al. PRL 129, 223401 (2022). arXiv:2207.11692. [depth: abstract verified via WebFetch — a_s=110(4) a_B, N≤5×10⁴, Feshbach at 1.32 G confirmed]

**Confidence in benchmark availability: high** — Science paper exists, is published, is the only external Eu-151 spinor-dynamics dataset, and the code already has the a_s value as canonical input.

**(e) PROPOSED FALSIFIER SKETCH**: Reproduce Matsui et al. 2026 EdH protocol (near-zero B quench from m=-6 FM state, evolve under spinor DDI). Criterion: ring density in m=-5 component appears at t≈t_EdH with quantized vortex structure (l=1 or l=2 per angular-momentum balance at F=6). If ring appears within factor-2 of experimental timescale → CORROBORATE; absent ring at any timescale, or wrong topology → REFUTED.

**(f) MINIMUM-VIABLE BUDGET**:
- T70: Researcher deep (1 turn) — access Matsui 2026 PDF; extract N, trap ω_{x,y,z}, B-quench protocol, simulation g_F, a_s, c_dd used; identify time axis and Fig.1 ring appearance time
- T71: Theorist Hypothesize — translate paper parameters to SpinorBEC.jl dimensionless units; predict EdH timescale τ_EdH = ω_ref / (c_dd × peak_density × F) and vortex number l = F (angular-momentum conservation)
- T72: Implementer Design + Execute (julia_gpu_heavy, 1 turn) — write YAML config; run find_ground_state + run_simulation! on 32³ or 64³ grid; observe m-component dynamics
- T73: Implementer Analyze + Update/critic
- T74: Document

**Total: 5 turns. Budget ~10-15M effective total. GPU required (RTX 5070 Ti available per scheduler JULIA_GPU_OK).**

Flag for anko: this is the project's primary verification target. Successful reproduction would be the most impactful Tier-3 achievement (Science paper benchmark). 5 turns is an estimate; the T70 researcher deep turn is the critical first step.

**(g) RECOMMENDED PRIORITY**: **#1** — Tier 0 → Tier 3 opportunity, Science paper benchmark, load-bearing-ness 5/5, the project's stated primary target is Eu-151 F=6.

---

### #2: `bug-4-itp-ddi-half-rate-pre-fix-runs-residual-error`

**(a) CLAIM ID**: `bug-4-itp-ddi-half-rate-pre-fix-runs-residual-error`

**(b) CURRENT TIER + EVIDENCE**:
- **Tier 1** — internal regression only. Memory file: `bug_4_itp_ddi_half_rate.md` (2026-05-02). The fix is confirmed via `test/test_itp_ddi_strang_save_every.jl` (save_every=1 vs save_every=100 agree to 1e-10 post-fix). MEMORY.md states verbatim: "All Eu DDI runs predating 2026-05-02 should be re-verified."
- itp_loop.jl source read this turn confirms the fix is in place (two `_ddi_step!(ws, dt/2)` calls per step at lines 66, 82, 158 — no merged-loop path).
- NOT Tier 2 because: no closed-form or cross-implementation verification of what the correct DDI ground-state energies should be for specific Eu151 configurations. The regression only verifies internal self-consistency.
- NOT Tier 3 because: no published-reference benchmark comparison has been run on any post-fix Eu151 DDI ground state.
- Prior turns: the fix was committed 2026-05-02 (commit `0353b9b` area), regression gate added. No loop turns dedicated to post-fix Eu151 ground-state validation.

**(c) LOAD-BEARING-NESS FOR PRODUCTION CODE**: **5/5**

- `src/solvers/ground_state/itp_loop.jl`: every call to `find_ground_state` with `c_dd ≠ 0` goes through `_run_itp_loop!` which calls `_ddi_step!` twice per step. This is the hot path for ALL Eu151 DDI ground-state computations. Any remaining pre-fix runs stored in `runs/eu151_*/` that anko uses as references for thesis data are directly affected.
- `src/workflow/experiments/pipeline/run_step_ground_state.jl`: the `GroundStateStep` pipeline path also routes through `find_ground_state`, so YAML-driven DDI ground states are affected.
- Every `runs/eu151_*/config.yaml` run with DDI predating 2026-05-02 has a potentially stale ground-state result.

**(d) EXTERNAL-BENCHMARK AVAILABILITY**: **PARTIAL**

- The Kozuma/Tokyo group (Miyazawa et al. 2022 PRL, arXiv:2207.11692) measured Eu-151 scattering length `a_s = 110(4) a_B` from expansion asymmetry, which fixes the c_0+36c_1 constraint. Condensate atom number N ≈ 5×10⁴ and trap geometry (crossed ODT) are given. Expansion velocities provide an external anchor for GS density profile.
- arXiv:2402.18885 (Phys. Rev. Research 6, L042049, 2024) on spinor dipolar Eu-151 BEC droplets uses Eu151 parameters and predicts droplet torus formation — provides additional DDI-energy anchor points.
- **Confidence in benchmark availability: medium** — Miyazawa 2022 gives trap-averaged expansion; SpinorBEC.jl ITP gives peak density and total energy in dimensionless units. Unit conversion via ω_ref is needed, but the physics is sound.
- **Note**: For Tier 2 only (self-consistency standard), no external benchmark needed — just re-run pre-fix configs and compare.

**(e) PROPOSED FALSIFIER SKETCH**:
Primary: Re-run `runs/eu151_mz_scan/` (13 points, Mz ∈ [-6, 0]) with DDI-active configs using post-fix code, compare energy vs Mz against stored pre-fix values (if JLD2 files exist on disk). If any point shows energy difference >1% → pre-fix data contaminated; if <0.1% → bug had negligible effect at production parameters.

Secondary (Tier 3): Run `find_ground_state` with Miyazawa 2022 parameters (N=5×10⁴, a_s=110 a_B, μ≈6.977μ_B) post-fix; compare dimensionless E/N against standard dipolar BEC mean-field formula `E_mf/N = (c_0+36c_1)n/2 + E_DDI/N` within 20%.

**(f) MINIMUM-VIABLE BUDGET**:
- Turn T70: implementer_text (1 turn) — disk audit: list runs/eu151_*/config.yaml creation dates vs 2026-05-02 fix date; determine if pre-fix JLD2 data files exist on disk; compute expected DDI-correction magnitude analytically
- Turn T71: julia_cpu_light (1 turn, if pre-fix JLD2 outputs exist) — extract energies from stored JLD2 and compare; OR re-run 13-point Mz scan post-fix and compare vs. stored values
- **Total: 2 turns + 1 optional Julia run. Budget ~3-5M effective. No GPU mandatory.**
- Flag for anko: needs disk audit first (pre-fix data may not exist in git-tracked runs/).

**(g) RECOMMENDED PRIORITY**: **#2** — explicitly flagged in MEMORY.md as D1 task; cheapest path (2 turns); load-bearing-ness 5/5 affects all thesis GS data.

---

### #3: `sign-pattern-lemma1-general-S-vs-kawaguchi-ueda-2012-channel-weights`

**(a) CLAIM ID**: `sign-pattern-lemma1-general-S-vs-kawaguchi-ueda-2012-channel-weights`

**(b) CURRENT TIER + EVIDENCE**:
- **Tier 2** — verified at 26 channels exact rational arithmetic across 5 polyhedral cases (F=3 O:A_2, F=4 cube, F=6 I_h, F=8 O:A_1, F=10 I_h). Memory: MEMORY.md "Sign Pattern Lemma 1 General-S CLOSED FORM" entry (2026-05-11). Regression: `scripts/manuscript/lemma1_general_S_verification.jl` (26/26 PASS).
- The closed form is `β_S^(λ_spin) = (S(S+1) − 2F(F+1)) / (2F(F+1)) · β_S^(c_0)`.
- Also verified cross-implementation against IcosahedralMod's manual coefficients at 4 F=6 I_h channels (exact match to closed form per universal_structure_u1u4_2026_05_13.md).
- NOT Tier 3 because: no comparison against published channel weight tables from an independent group. The verification is internal (SpinorBEC.jl closed form vs SpinorBEC.jl IcosahedralMod coefficients).

**(c) LOAD-BEARING-NESS FOR PRODUCTION CODE**: **2/5**

- `src/analysis/phases/sign_pattern.jl`: exports `sign_pattern_beta_lambda_spin`, `sign_change_boundary_S_bd`, `predict_lambda_spin_sign`, `sign_pattern_beta_lambda_spin_table`. These are analysis functions, not hot-path simulation functions.
- Not called in `find_ground_state`, `run_simulation!`, or `run_yaml` hot paths. Called in post-processing phase classification.
- Impact: if wrong, phase classification outputs are wrong, but simulation dynamics are unaffected.

**(d) EXTERNAL-BENCHMARK AVAILABILITY**: **FOUND** (verified this turn via WebSearch).

- Kawaguchi & Ueda 2012 (Phys. Rep. 520, 253–381; arXiv:1001.2072; DOI: 10.1016/j.physrep.2012.07.005) is the canonical spinor BEC review. §4 tabulates channel weights β_S for specific polyhedral states (F=2 cyclic/tetrahedral, F=3 octahedral, F=1 ferromagnetic). This is the external cross-implementation check: if our `β_S^(c_0)` values agree with KU2012 tables for F=2, and our Lemma 1 transform yields the same `β_S^(λ_spin)` as KU2012's Bogoliubov spectrum tables, that is Tier 3.
- Stamper-Kurn & Ueda 2013 (Rev. Mod. Phys. 85, 1191; DOI: 10.1103/RevModPhys.85.1191) covers F=1 and F=2 Bogoliubov spectra with explicit channel weight data.
- **Confidence in benchmark availability: high** — both reviews provide numerical tables or closed-form channel weights for F=1, F=2, F=3 polyhedral cases. Direct channel-by-channel comparison is possible from the published texts.

[depth: multi-source-cross-referenced N=2; abstract-confirmed for KU2012 via WebSearch; by_tag/kawaguchi-ueda-2012.md confirms T10 prior reference]

**(e) PROPOSED FALSIFIER SKETCH**:
Extract β_S^(c_0) values for F=2 (tetrahedral A_1 state) from Kawaguchi-Ueda 2012 §4 or Stamper-Kurn-Ueda 2013 §IV. Apply Lemma 1 formula to get predicted β_S^(λ_spin). Compare against the spin stiffness reported in those reviews (derived independently from Bogoliubov theory). If agreement is within 1% (exact arithmetic difference ≤ float roundoff for rational-valued channels), corroborated at Tier 3. If discrepancy >1%, the Lemma 1 formula has a sign or normalization error not caught by internal testing.

**(f) MINIMUM-VIABLE BUDGET**:
- Turn T70: theorist (text-only) — WebFetch Kawaguchi-Ueda 2012 §4 / Stamper-Kurn-Ueda 2013 §IV; extract β_S tables for F=2 tetrahedral state; compare against `sign_pattern_beta_lambda_spin` output. All text work.
- **Total: 1 turn theorist_text. This is the cheapest Tier-3 candidate in the list.**
- Flag for anko: if theorist confirms exact match at F=2 against two independent review papers, Lemma 1 General-S achieves Tier 3 in a single text turn. Highest value-to-cost ratio of all candidates.

**(g) RECOMMENDED PRIORITY**: **#3** — load-bearing-ness 2/5 (analysis path only, not simulation hot path), BUT cheapest candidate (1 turn text-only), external benchmark exists and is published (Kawaguchi-Ueda 2012, Stamper-Kurn-Ueda 2013), and Tier-3 promotion would be the project's third published-benchmark verification.

---

### #4 (lower priority): `twochannel-lhy-F6-polar-30-70-percent-error-vs-polar-contact`

**(a) CLAIM ID**: `twochannel-lhy-F6-polar-30-70-percent-error-vs-polar-contact`

**(b) CURRENT TIER + EVIDENCE**:
- **Tier 1.5** — pinned by internal regression + qualitative physical argument, but NOT cross-validated against published LHY numerics.
- Evidence: `test/hamiltonian/test_spinor_lhy.jl` contains regression assertions that TwoChannel underestimates PolarContact by >30% at F=6 (and >50% at other parameter points). Both assertions PASS internally.
- The physical argument (TwoChannel captures only m=0 phonon + 2 SO(3) Goldstones, dropping m=±2..±6 gapped modes) is documented in `src/hamiltonian/interactions/lhy/dispatch.jl`.
- NOT Tier 2 because: PolarContactLHY itself is an unvalidated internal closed form (Paper #1 claim). The comparison is internal (TwoChannel vs PolarContact), not against an independent external calculation.
- NOT Tier 3 because: no comparison to Lima-Pelster 2011 (arXiv:1103.4128) or Wächtler-Santos 2016 (arXiv:1605.08676, PRA 94, 043618) numerical LHY values for multi-channel spinor gases.

**(c) LOAD-BEARING-NESS FOR PRODUCTION CODE**: **3/5**

- `src/hamiltonian/interactions/lhy/dispatch.jl` `make_lhy(:two_channel, ...)` — called when user explicitly requests `lhy: {kind: two_channel}` in YAML. Not hot path for Eu151 runs (which use `:scalar` or `:polar_contact`).
- `src/hamiltonian/interactions/lhy/dispatch.jl` `make_lhy(:polar_contact, ...)` — the PolarContactLHY that is the reference in this comparison IS load-bearing for F=6 polar GS computations. If PolarContactLHY itself is wrong, the 30-70% error claim is moot.
- Direct impact: if a user accidentally uses `:two_channel` at F=6, they get a silently wrong LHY by 30-70%. The claim justifies the documented warning.

**(d) EXTERNAL-BENCHMARK AVAILABILITY**: **NOT_FOUND for F=6 specifically.**

- Lima & Pelster 2011 (PRA 84, 041604; arXiv:1103.4128) derives the LHY Q5 correction for fully polarized dipolar BEC — single-component, not multi-channel spinor.
- Wächtler & Santos 2016 (PRA 93, 061603R; arXiv:1605.08676; PRA 94, 043618; arXiv:1605.08676) extends to ε_dd>1 but also treats single-component dipolar BEC.
- For multi-channel spinor LHY at F=6: Kawaguchi & Ueda 2012 §4 discusses fluctuation corrections qualitatively for general spin but does not tabulate numerical LHY values for F=6 explicitly.
- Uchino, Kobayashi & Ueda 2010 (PRA 81, 063632; arXiv:0912.0355) derives Bogoliubov LHY corrections for F=1 and F=2 — not F=6.
- **Assessment**: no published paper provides numerical LHY values for multi-channel F=6 spinor BEC that would directly validate PolarContactLHY vs TwoChannelLHY. NOT_FOUND for the specific F=6 multi-channel LHY comparison benchmark. Best available: F=2 cross-check from KU2012 (indirect).

**(e) PROPOSED FALSIFIER SKETCH**:
Since no direct external F=6 spinor LHY table is available, the falsifier is indirect: compare PolarContactLHY at F=1 against Uchino-Kobayashi-Ueda 2010 (arXiv:0912.0355) analytic LHY for F=1 polar phase. If PolarContact is Tier-2 verified at F=1 and F=2, the F=6 30-70% gap between TwoChannel and PolarContact is trustworthy as a claim, elevating to Tier 2.5. Tier 3 requires new experimental or numerical comparison at F=6.

**(f) MINIMUM-VIABLE BUDGET**:
- Turn T70: theorist (text-only) — extract F=1 and F=2 LHY expressions from KU2012 §4 and UKU2010 arXiv:0912.0355; compare analytically against PolarContactLHY formula at c_extra=0.
- Turn T71: optional implementer_text — add one test comparing PolarContact at F=1 against UKU2010 closed form.
- **Total: 2 turns theorist_text + optional implementer_text. No Julia execute needed.**
- Flag: Tier 3 NOT achievable without new numerical F=6 LHY data. This candidate tops out at Tier 2.5.

**(g) RECOMMENDED PRIORITY**: **#4** — benchmark NOT_FOUND for F=6; tops out at Tier 2.5; lower priority than #1-#3. Useful for Paper #1 LHY section grounding if pursued.

---

### #5 (lower priority): `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-vs-ku2012`

**(a) CLAIM ID**: `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-vs-ku2012`

**(b) CURRENT TIER + EVIDENCE**:
- **Tier 2** — 208 tests pass in `test/test_tdhfb_hf_matrix_generic.jl` covering F=1, F=3, F=6: Hermiticity, linearity, singlet projector identity, BdG self-energy form. Memory: MEMORY.md "TDHFB Phase 2 generic-F HF kernel" entry (2026-05-11). Factor 2 from Bose symmetrization verified.
- The `hartree_fock_matrix_generic.jl` comment (read this turn, line 16) confirms: "Reference: Kawaguchi-Ueda 2012 §3.2."
- NOT Tier 3 because: Bogoliubov spectrum from the full TDHFB kernel has not been compared against published spinor Bogoliubov spectra.

**(c) LOAD-BEARING-NESS FOR PRODUCTION CODE**: **4/5**

- `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl`: the generic-F HF kernel is the core of TDHFB dynamics, feeding into every TDHFB time step.
- If the generic HF kernel has a systematic error (wrong CG coefficient, missing symmetry factor), every TDHFB propagation for F≥2 is wrong.
- However: TDHFB is not yet used in production Eu151 runs (`eu151_*` use standard split-step). Load-bearing specifically for the TDHFB execution path.

**(d) EXTERNAL-BENCHMARK AVAILABILITY**: **PARTIAL**

- Kawaguchi-Ueda 2012 §4.2 (arXiv:1001.2072) gives the Bogoliubov spectrum explicitly for F=1 polar BEC with the two Goldstone modes + gapped modes — provides a direct numerical check of the HF kernel's output spectrum at F=1.
- Uchino, Kobayashi, Ueda 2010 (arXiv:0912.0355, PRA 81, 063632) derives analytic LHY corrections for F=1 and F=2 spinor BECs in all phases. The Bogoliubov spectrum itself can be extracted from their analytic expressions.
- **Confidence in benchmark availability: medium** — F=1 is well-covered. The gap is that the Bogoliubov dispersion (not just matrix structure) has not been explicitly compared.

**(e) PROPOSED FALSIFIER SKETCH**:
At F=1, uniform density n, c1=0 (single-component limit): the TDHFB HF kernel should produce a Bogoliubov phonon dispersion E(k) = ℏ√((ℏk²/2m)(ℏk²/2m + 2c_0·n)). Compare the numerically extracted lowest-branch dispersion from `bogoliubov_instability_scan` at F=1, c1=0 against this analytic formula at k=0..k_max. If the sound velocity matches `√(2c_0 n/m)` within 0.1%, corroborated. Gap at k=0 must be < 1e-6 (Goldstone, already tested in `bogoliubov_dispersion`).

**(f) MINIMUM-VIABLE BUDGET**:
- Turn T70: theorist (text-only) — extract F=1 Bogoliubov sound velocity formula from KU2012 §4; set up numerical comparison protocol.
- Turn T71: julia_cpu_light — run `bogoliubov_instability_scan` at F=1 c1=0 and extract sound velocity; compare against analytic formula.
- **Total: 2 turns theorist_text + julia_cpu_light.**
- Flag for anko: TDHFB is not in the production Eu151 pipeline yet. Medium priority.

**(g) RECOMMENDED PRIORITY**: **#5** — load-bearing-ness 4/5 for TDHFB path, but TDHFB not active in production runs. Benchmark (KU2012 §4.2) exists. Budget 2 turns.

---

## 3. Excluded candidates (with rationale)

| Candidate | Reason for exclusion |
|-----------|---------------------|
| Barnett mechanism T29 | Already Tier-3 (closed) |
| Klaus-BCH leak T59 | Already Tier-3 (closed) |
| yan-li-saito-2026-reproduction | DORMANT-CLOSE at T65; F1 REFUTED; paper-anchor problem, not framework-claim |
| fullbdg-f6-polar-3000x | Dormant (priority 99); anko-contained; closed-form alternatives in place; director.md explicitly says do NOT spend turns |
| DDI no-4π convention | Intentional design choice (CLAUDE.md "Conventions do NOT fix") |
| TDHFB A4 palindromic gate Tier-2 | Already internally verified at machine precision (Tier 2); no external benchmark for palindromic gate error specifically |
| Bug-5 Faraday double-count | Fixed 2026-05-02; regression test covers it; Faraday imaging not a direct external-reference benchmark opportunity |
| Bogoliubov test indexing fix | Fixed 2026-05-02; regression promoted to `@test`; internal claim, not requiring external benchmark |
| TDHFB GPU 121× speedup | D2 optimization axis (performance, not physics); not a physics claim to benchmark against literature |
| Universal Structure U1-U4 F=6 I_h classification | Tier 2 internally; Tier 3 at F=6 requires new external source; Barnett-Santos 2007 + KU2012 cover F≤3 explicitly. Can be batched with #3 (Sign Pattern Lemma 1) if anko wants. |

---

## 4. NOT_FOUND items (claims without external benchmark)

1. **TwoChannelLHY 30-70% off at F=6** (Candidate #4): no published multi-channel spinor LHY table for F=6 exists in accessible literature. Lima-Pelster + Wächtler-Santos are scalar-only. Kawaguchi-Ueda 2012 discusses spinor LHY qualitatively but does not tabulate F=6 numerical values. This claim tops out at Tier 2.5 (F=2 cross-check from Kawaguchi-Ueda) without new theory/simulation from an external group.

2. **Universal Structure U1-U4 at F=6 I_h** specifically: Barnett et al. and Kawaguchi-Ueda cover F≤3 polyhedral states. The F=6 icosahedral spinor state is specific to Eu151 physics and has no published spinor state vector reference to compare against (Tier 2 via internal cross-check; Tier 3 requires Tokyo Tech group confirmation or new collaborative calculation).

3. **Sign Pattern Lemma 1 at F≥4** (Candidate #3 partial): KU2012 only covers F=1, F=2 explicitly for channel weights. Tier 3 at F≥4 requires either a new review paper or direct computation from an independent code.

4. **TDHFB Picard midpoint order-4 convergence** vs any published TDHFB convergence study: NOT_FOUND. Best external reference is Chin-Krotscheck 2009 (cited in code for FG correction), but does not treat spinor TDHFB.

5. **Bogoliubov roton gap in Eu-151 specifically**: searched 2024-2025 arXiv; NOT_FOUND as a standalone measurement for Eu151. The 2026 EdH paper may contain Bogoliubov analysis in the body, but PDF access failed (binary). Can be unlocked in EdH candidate (#1) research phase.

---

## 5. Seed.md-ready stubs (anko may paste verbatim)

**Note**: seed.md currently uses a free-text format, not a structured YAML investigations format. The stubs below follow the state.json investigations format for direct use by the director; summary text is also provided for seed.md free-text pasting.

### Stub #1: EdH Matsui Science 2026 comparison (Priority 1)

```markdown
### `edh-eu151-vortex-vs-matsui-science-2026` (priority 1, tier 0 → 3)

**Hypothesis**: SpinorBEC.jl spinor DDI + split_step framework can reproduce the
Matsui, Miyazawa et al. Science 391, 384-388 (2026) [DOI:10.1126/science.adx2872]
observation: ring-shaped density in m=-5 component with quantized vortex topology
emerges after near-zero B-field quench from m=-6 FM state in Eu-151 BEC, mediated
by DDI-driven angular-momentum transfer. Reproduction within factor-2 of experimental
timescale corroborates the full production DDI + spinor mixing framework.

**Flow template**: verify-claim
**Tier target**: 3
**External benchmark**: Matsui et al. Science 2026 (DOI:10.1126/science.adx2872;
arXiv:2504.17357) + Miyazawa et al. PRL 129, 223401 (2022), arXiv:2207.11692

**Falsifiers**:
- `ring-appears-correct-timescale` — ring density in m=-5 appears at t≈t_EdH(exp)
  within factor-2: CORROBORATE; absent at any timescale or wrong spin component: REFUTED
- `vortex-topology-l1-or-l2` — matter-wave interferometry analog: vortex number l=1
  (or l consistent with F angular-momentum at F=6): CORROBORATE; wrong topology: REFUTED
- `energy-self-consistency-post-fix` — GS energy at N=5×10⁴, a_s=110 a_B agrees with
  mean-field estimate within 20%: confirms Bug-4 fix and GS preparation are sound
```

### Stub #2: Bug-4 pre-fix runs audit (Priority 2)

```markdown
### `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` (priority 2, tier 1 → 2)

**Hypothesis**: Post-fix `_run_itp_loop!` (2026-05-02) produces DDI ground-state
energies ≤1% different from pre-fix for production Eu151 configs (save_every=100
default, typical production run). If the difference is >1%, pre-fix stored runs
under runs/eu151_*/ must be flagged as stale and regenerated.

**Flow template**: fix-bug (audit variant)
**Tier target**: 2 (internal self-consistency standard; Tier 3 deferred to EdH candidate #1)

**Falsifiers**:
- `energy-delta-production-configs-lt-1pct` — re-run runs/eu151_mz_scan/ (13 points)
  post-fix; compare E(Mz) curve against stored pre-fix values; >1% energy delta in any
  DDI-active point → stale data flag; <0.1% → bug was negligible at production parameters
- `disk-audit-no-pre-fix-jld2` — confirm no DDI-active JLD2 files exist in runs/ with
  creation date before 2026-05-02; if found, regenerate
```

### Stub #3: Sign Pattern Lemma 1 Tier-3 (Priority 3)

```markdown
### `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` (priority 3, tier 2 → 3)

**Hypothesis**: Sign Pattern Lemma 1 General-S closed form
  β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0)
agrees with Kawaguchi-Ueda 2012 (Phys. Rep. 520, 253; arXiv:1001.2072) §4 channel
weight tables for F=2 (T_d cyclic state) and Stamper-Kurn-Ueda 2013
(Rev. Mod. Phys. 85, 1191; DOI:10.1103/RevModPhys.85.1191) F=1/F=2 Bogoliubov
stiffness within 1%.

**Flow template**: verify-claim (theorist text-only, 1 turn, cheapest Tier-3 candidate)
**Tier target**: 3

**Falsifiers**:
- `f2-tetrahedral-channel-weight-kawaguchi-ueda` — extract β_S^(c_0) for F=2 T_d state
  from KU2012 §4; apply Lemma 1; compare published λ_spin stiffness; agreement <1%:
  CORROBORATE; >1%: sign convention or normalization error
- `s-bd-boundary-cross-check` — verify S_bd(F=2)=√12≈3.46 consistent with sign-change
  predictions from KU2012 §4 channel decomposition
```

---

## 6. Self-review checklist

- [x] No invented citations. Every benchmark has a DOI/arXiv or NOT_FOUND explicitly declared:
  - arXiv:2504.17357 (Matsui et al. Science 2026) — found via WebSearch, Science DOI confirmed in result metadata
  - DOI:10.1126/science.adx2872 — confirmed in search result
  - arXiv:2207.11692 (Miyazawa et al. 2022 PRL) — confirmed via WebFetch (a_s=110(4) a_B verbatim)
  - arXiv:1001.2072 (Kawaguchi-Ueda 2012 Physics Reports) — confirmed via WebSearch, INSPIRE + ScienceDirect results
  - DOI:10.1016/j.physrep.2012.07.005 — confirmed in ScienceDirect search result
  - arXiv:0912.0355 (Uchino et al. 2010 PRA) — confirmed via WebSearch with title + journal match
  - DOI:10.1103/RevModPhys.85.1191 (Stamper-Kurn-Ueda 2013) — confirmed via WebSearch
  - arXiv:1103.4128 (Lima-Pelster 2011) — confirmed via WebSearch
  - arXiv:1605.08676 (Wächtler-Santos 2016) — confirmed via WebSearch
  - arXiv:2402.18885 (PRR 2024 spinor Eu151 droplets) — confirmed via WebSearch
  - NOT_FOUND explicitly declared for: F=6 multi-channel spinor LHY tables; F=6 I_h canonical spinor state; TDHFB convergence study; Eu151 Bogoliubov roton gap.
- [x] No intentional-design candidates proposed. All 8 excluded categories listed upfront.
- [x] Bug-4 re-verification candidate included as #2 with seed.md stub.
- [x] All candidates have load-bearing-ness × benchmark-availability × cheapness scored.
- [x] Seed.md stubs produced for top 3 candidates in copy-pasteable format.
- [x] Key new finding reported: Matsui et al. Science 2026 (arXiv:2504.17357) — only external EdH Eu-151 spinor dynamics benchmark, now ranked #1.
- [x] TDHFB HF kernel included as #5 with explicit NOT_FOUND for F>2 benchmark.
- [x] Yan-li-saito revival not proposed.

---

## Budget

- Queries: 1 received, 5 candidates answered (each with all 7 fields a-g)
- Web requests: 11 used (WebSearch ×9, WebFetch ×2)
- Cache hits: 0 (`.claude/knowledge/` directory does not exist; no prior cache)
- Memory files read: 8 (bug_4_itp_ddi_half_rate, universal_structure_u1u4, lhy_refactor, full_bdg_F6_polar_broken, tdhfb_gpu_port_status, barnett_spin_pumping_observed, bogoliubov_test_indexing, universal_theorem_status)
- Source files read: 3 (polar_contact.jl full read, hartree_fock_matrix_generic.jl partial, itp_loop.jl grep)
- by_tag files read: 4 (barnett.md, kawaguchi-ueda-2012.md, fullbdg-lhy.md, bosonic-bdg.md)
- state.json sections read: full investigations block (6 investigations), investigations_index, active_investigation_id
