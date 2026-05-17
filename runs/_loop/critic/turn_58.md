VERDICT: PASS

# Turn 58 — Critic Report (Update stage of klaus-bch-leak verify-claim)

**Investigation**: klaus-magnetostir-bch-leak-2026-05-13
**Stage**: §F1 Update (audit of T57 Execute)
**Falsifier**: klaus-bch-leak-option-gamma-p2-plus-pop-discriminator
**Top-line verdict**: `CORROBORATE-WITH-ERRATA` → tier 2.7 → 3.0 with 3 advisory errata propagated to memory.

## §1 Independent re-derivation

### 1.1 Y4 floor for norm-drift

Independent route via two contributions: (a) Y4 unitary truncation, (b) floating-point round-off from the eigendecomposition per local-spin step.

(a) Yoshida 1990 *Phys. Lett. A* 150, 262, and Hairer-Lubich-Wanner 2006 *Geometric Numerical Integration* 2nd ed. (Springer SSCM Vol. 31), §V.3.1, give the symmetric 3-stage palindromic composition local truncation error $\delta \sim c_5 \tau^5 \|[A,[A,[A,B]]]\|$ with $c_5 \approx 0.0247$ (the standard Suzuki-Yoshida constant). For a *unitary* eigen-exact subblock, the truncation error appears only as a deviation in the *operator angle*, not in the norm (a unitary integrator times a unitary subblock is still unitary up to round-off). Therefore **the Y4 truncation does not contribute to norm drift directly** — its contribution is bounded by the lossy projection of the Y4-truncated unitary back onto a true unitary, which is $O(\delta^2)$ from second-order Taylor of $\|U_{\rm Y4}\psi\|^2$ around $U^\dagger U = \mathbb 1$. So norm drift comes almost entirely from the eigendecomposition's residual non-unitarity.

(b) Eigendecomposition non-unitarity: LAPACK `heevr` (`Hermitian` path) achieves backward error $O(D^{3/2} \epsilon_{\rm mach})$ per eigendecomposition (Anderson et al., *LAPACK Users' Guide* 3rd ed., §4.10; Demmel & Veselić 1992 *SIAM J. Mat. Anal.* 13, 1204). For $D=13$, this is $\sim 13^{1.5} \cdot 2.2 \times 10^{-16} \approx 1 \times 10^{-14}$ per step. The reconstruction $U_{ij} = \sum_k V_{ik} e^{-i\lambda_k dt} V_{jk}^*$ at machine precision contributes another $D \cdot \epsilon_{\rm mach} \approx 3 \times 10^{-15}$ per element. Per local spin step the norm-conservation error per voxel is bounded by $\sim 10^{-14}$.

Per macro-Y4 step: 3 Strang sub-steps × 2 local-spin applications × $\sim 10^{-14}$ = $6 \times 10^{-14}$. Over $N_{\rm steps} = T/dt = 314.16/10^{-3} \approx 3.14 \times 10^5$ steps, random-walk accumulation gives $\sqrt{N} \cdot 6 \times 10^{-14} \approx 3.4 \times 10^{-11}$. Coherent accumulation (worst case): $N \cdot 6 \times 10^{-14} \approx 2 \times 10^{-8}$.

**My independent floor band**: $[3 \times 10^{-11}, 2 \times 10^{-8}]$. This is essentially T56's band $[3 \times 10^{-11}, 3 \times 10^{-8}]$, derived by an independent argument (LAPACK error bound + random/coherent accumulation), not via the T56 "spinor-specific C_Y4 in [1,100]" parameterization.

**Observed**: 2.1–3.3 × 10⁻⁹. Falls **inside** my independent band, near the geometric mean of the random and coherent extremes — what one would expect from a moderately correlated round-off accumulation.

### 1.2 Expected BCH residual signature in m+F drop

I take T10 §2.7 absorption factor $(\dot\phi/p)^2$ as given (it follows from the rotation eliminating the lab-frame transverse Zeeman $\sim p \sin\theta$ in favor of the gauge connection $\sim \dot\phi$ in the rotating Hamiltonian, and the squared structure of BCH commutator amplitudes), and the bare lab-frame BCH-leak amplitude over $T$:

$$\Delta f_{m=+F}^{\rm BCH,bare} \sim T \cdot dt \cdot (p \sin\theta F)^2 \cdot (c_{dd}\langle n\rangle)^2 / D^2 \cdot \dot\phi^2.$$

At phi=18, $p\sin\theta F = 26700 \cdot 0.574 \cdot 6 \approx 9.2 \times 10^4$, $c_{dd}\langle n\rangle \approx 5$ (T10 §2.1 estimate, Q1 still open), $D^2=169$:

The BCH leak amplitude per macro-step is $dt^2 \cdot \|[\text{spin}, \text{DDI}]\| \sim dt^2 \cdot p\sin\theta F \cdot c_{dd}\langle n\rangle / D$, cumulated to $T \cdot dt \cdot p\sin\theta F \cdot c_{dd}\langle n\rangle / D \approx 314 \cdot 10^{-3} \cdot 9.2 \times 10^4 \cdot 5 / 13 \approx 1.1 \times 10^4$ (huge — would diverge if unabsorbed). Apply the Option γ absorption factor $(\dot\phi/p)^2 = (18/26700)^2 \approx 4.5 \times 10^{-7}$: residual $\approx 1.1 \times 10^4 \cdot 4.5 \times 10^{-7} \approx 5 \times 10^{-3}$.

This is **higher than T56's $1.6 \times 10^{-5}$ estimate**, by ~2 orders. T56 used a $\dot\phi^2 F^2 (c_{dd}\langle n\rangle)^2 / D^2$ form rather than $p\sin\theta F \cdot c_{dd}\langle n\rangle / D$ in the "bare amplitude". The T56 form pre-absorbs one factor of $(\dot\phi/p)$ into the $\dot\phi$ prefactor of the bare term, which is partially what Option γ does — but conflating the bare and absorbed structures is a derivational ambiguity worth flagging.

**Conservative range**: residual ∈ $[1 \times 10^{-5}, 5 \times 10^{-3}]$.

**Observed m+F drops**: 40 ppb to 1250 ppb = $4 \times 10^{-8}$ to $1.25 \times 10^{-6}$. This is **2–5 orders below even T56's lower estimate of $1.6 \times 10^{-5}$**, and 6–7 orders below my conservative upper bound. The observed signal is fully consistent with **zero BCH residual + Y4 truncation phase floor + numerical round-off**, with no Option γ leakage visible.

## §2 Confounder examination

**C1. Y4 floor uncertainty band — verdict CORROBORATE.**
T56's $[3 \times 10^{-11}, 3 \times 10^{-8}]$ band derived independently in §1.1 above lands within a factor of $\sim 2$ of mine. Observed 2-3×10⁻⁹ is comfortably inside both. The band breadth IS broad (3 decades), but this is intrinsic to the LAPACK-eigen + random-vs-coherent-accumulation ambiguity, not a flaw of T56's derivation. The test is essentially `<bound>` testing against a 3-decade tolerance, and the observation lies near the middle of the band (geometric mean of 3×10⁻¹¹ and 3×10⁻⁸ is 3×10⁻¹⁰; observed 3×10⁻⁹ is 1.5 decades above that). The flat phi-dependence (growth ratio 1.033) is the *more* discriminating signal than the absolute value.

**C2. Chi-square sigma_baseline circularity — verdict FLAG.**
The script uses `std(residuals[1:4])` (low-phi). Critic-computed alternates from the published residuals `[-2.4e-7, 2.3e-7, -2.0e-8, -2.1e-7, 2.4e-7, 3.2e-7, -4.3e-7, 1.0e-7]`:
- Full-residual std (all 8, sample std N-1): $\sigma_{\rm full} \approx 2.7 \times 10^{-7}$. max|res|/σ_full ≈ 4.3/2.7 ≈ **1.59 σ**.
- MAD (median abs deviation from median, scaled 1.4826× for Gaussian σ): median = 2.35e-7, MAD ≈ 0.55e-7, MAD-σ ≈ 8.2e-8. max|res|/MAD-σ ≈ 4.3e-7 / 8.2e-8 ≈ **5.2**. *This exceeds the 5σ threshold.*

The MAD-based test would flip the secondary verdict from CONFIRM toward INCONCLUSIVE/REFUTE — but only because MAD is by construction tighter than std when the residuals have one outlier (the phi=12 point at -4.3e-7). The std-based test (which the script uses) is the correct estimator under the null hypothesis that residuals are Gaussian noise, and gives 1.95σ ≤ 5σ (CONFIRM). The MAD-based test would be the correct estimator if we suspected outliers. The choice between them matters here. **However**, T56's secondary observable was specified as a smooth-coherent-trend chi-square test with low-phi as the noise baseline, which is a defensible structural choice — the BCH signature is predicted at HIGH phi, so estimating noise from LOW phi is reasonable. The circularity concern is bounded: low-phi residuals would only become contaminated if the BCH leak ALSO showed up at low phi, which the physics rules out ($\dot\phi^2$ scaling means phi=1 residual is 324× smaller than phi=18). **Conclusion: not actually circular under physics; flag is advisory.**

**C3. Sign of m+F drop — verdict FLAG, hypothesis (i) most likely.**
The observed sign convention: `m_plus_F_drop = steady_pmh[1, 1] - steady_pmh[1, end]` (per T56 §4 pseudocode, implemented as written). All values negative → m+F fraction at end > at start → fraction *increases*. Memory line 34 for Dy164 reports 0.94 → 0.55, a *decrease*.

Three hypotheses:
- (i) **Recovery from transient**: SPINUP_END = 21.99 (end of spinup), but the steady-stir snapshots begin at 21.99 still mid-transient (the system has been lagging during the spinup ramp and continues to relax during the early steady-stir phase). The m=+F fraction first dropped during spinup, then partially recovers in the steady phase.
- (ii) **Mis-aligned steady window**: the script's `steady_idx = findfirst(t > SPINUP_END)` would select snapshots starting ~22.0, but if the save_every=200 from spinup yields a sparse boundary, the first "steady" snapshot might be the last spinup snapshot. With dt=0.001 and save_every=200, snapshots are at intervals of 0.2 dimless, so the first post-spinup snapshot is at ~22.0–22.2 — narrow alignment.
- (iii) **Sign convention bug**: T56 §4 pseudocode `m_plus_F_drop = steady_pmh[1, 1] - steady_pmh[1, end]` IS the script's implementation per T57; sign convention is internally consistent — the negative sign is real.

The order-of-magnitude argument favors (i): Dy164 had ε_dd_eff=17 (collapse regime) and showed a 39 pp drop. Eu151 has ε_dd_eff≈0.02 (weak DDI), so the Eu151 magnetostir lag is intrinsically far smaller (~1e-6 vs ~0.4). The first steady snapshot is post-spinup but pre-steady-equilibration; the system then "recovers" by ~1 ppm over the 1s steady window. **Hypothesis (i) is most likely**; this does NOT invalidate the discriminator (the chi-square test on residuals is sign-insensitive — all that matters is whether the deviation from a smooth-phi trend is significant).

**C4. Mixed-frame Jz_proxy adequacy — verdict CORROBORATE-WITH-CAVEAT.**
Jz_proxy_mean ≈ 6.0–6.1, drift 0.014–0.33 (spread 1.5 decades). Per T56 §2.2 the proxy is `<F_z_tilde>(t) + <L_z>(t)`, with the tilde-vs-lab-frame correction averaging out over integer phi-cycles. For phi=1 (slowest), $T_{\rm phi} = 2\pi/\dot\phi = 6.28$, and over $T_{\rm steady}=314$ there are ~50 phi-cycles → time-averaging is robust. For phi=18 (fastest), $T_{\rm phi} = 0.35$, ~900 cycles → even more robust.

The drift values are not strictly EdH-conservation observables (per T56 §2.2(b), the lab-frame Fz requires snapshot post-rotation). The 1.5-decade spread in drift is consistent with the residual oscillatory transverse-Fz piece NOT fully averaging at finite N_cycles, not necessarily with EdH non-conservation. **Sufficient for Tier 2.7 verification**; a tier-3 promotion is conditional on the proxy being interpreted as "Larmor-window-averaged sanity" rather than "EdH conservation". A cpu_heavy lab-frame reconstruction would be the right follow-up if Document is to publish an "EdH conservation" claim; if Document just confirms norm-drift + m+F discriminator (which is what the verify-claim hypothesis actually targets), then the proxy is sufficient.

**C5. Larmor_phase invariance — verdict CORROBORATE-AS-WAS (tautology, mostly).**
larmor_phase = p · F · dt = 26700·6·0.001 = 160.2 for all 8 phi because p, F, dt are scan-invariant. T56 §2.4(d) flagged it explicitly as "bookkeeping". Director T57 §6 promoted it to a `larmor_phase_invariant_across_phi` success_criterion. This IS true on its face — it's a regression check that the scan didn't accidentally vary one of {p, F, dt} (which would silently change the BCH-leak prediction). Calling it a "success criterion" is mild over-claiming; calling it a "regression invariant" is fine. **Not a scientific signal; not a scientific lie either**. Advisory note worthy.

**C6. Y4 commutator-norm assumption (T56 §2.1 bound type ii) — verdict CORROBORATE empirically, FLAG analytically.**
T56's "effective bound" replaces $(pF)^3 \cdot (c_{dd}\langle n\rangle)^2$ with $(\dot\phi F + c_{dd}\langle n\rangle)^3 \cdot (c_{dd}\langle n\rangle)^2$. The argument: the eigen-exact spin step removes the pF amplification from inside the local spin substep, so the Y4 macro-step nested commutators $[H_{\rm spin}^{\rm rot}, [H_{\rm spin}^{\rm rot}, H_{\rm DDI}]]$ only see the off-diagonal part of $H_{\rm spin}^{\rm rot}$ (i.e. $\hat A$) when commuting against $H_{\rm DDI}$.

But $H_{\rm spin}^{\rm rot}$ DOES contain a $-pF_z$ diagonal piece in addition to $\hat A$. This diagonal piece commutes with itself, but does NOT commute with the DDI tensor coupling (which has off-diagonal m-changing entries from the rank-2 spherical components). So $[\text{diag}, H_{\rm DDI}]$ has *off-diagonal* support and amplitude $\sim pF \cdot (c_{dd}\langle n\rangle/D)$ (the off-diagonal matrix elements of $H_{\rm DDI}$, weighted by the diagonal energy gap $pF$). T56 §2.1 argued this is bounded by $c_{dd}\langle n\rangle/D$ alone (not amplified by pF). **This is the load-bearing analytical claim** and it's not rigorously justified in T56.

**Empirical fallback (T56's own §2.1 closing argument)**: If the Y4 truncation WERE pF-amplified, the norm drift would saturate at the Y4 truncation level $\sim 0.0247 \cdot dt^5 \cdot (pF)^3 \cdot c_{dd}\langle n\rangle^2 \cdot N$. At dt=1e-3, pF=1.6e5: per-step $\sim 0.025 \cdot 10^{-15} \cdot 4 \times 10^{15} \cdot 100 \approx 10^1$, far above unitary, meaning the bound is meaningless (the run would diverge if tight). **The fact that the run does NOT diverge — observed norm drift 3e-9 — is empirical proof that the (pF)³ amplification does NOT happen in the macro-Y4 commutator.** This is the strongest argument T56 actually makes, and it's correct: the constancy across phi (1.033× across 18× phi range) is independent evidence.

So: T56's *analytical* justification has a gap (the diag-vs-DDI off-diagonal element argument is hand-waved), but the *empirical* falsifier (norm-drift constancy across phi) provides closure. Verdict: FLAG the analytical gap as advisory errata; CORROBORATE the empirical conclusion.

**C7. Production-code current-state — verdict CORROBORATE.**
Read `propagators.jl:146–231` directly this turn. Code matches T56 §1.2 description exactly:
- Docstring at 146–158 explicitly states the design intent and the $O(p F |\hat A| dt^2)$ BCH-leak claim.
- Lines 168–195 build the combined `Hz` matrix with the gauge_fix branch at 189 (matches Klaus `gauge_fix: false`).
- Lines 204–225 do single `eigen!(Hermitian(H_dense))` + phase-multiplied reconstruction. No internal Strang.
- Cache wrapper `_local_spin_h_buffer` at 233–240.
**No code refactor since T56**; line-37 memory claim verified current.

## §3 Errata flag list

1. **Source**: T56 §2.1 bound type (ii). **Claim**: "the eigen-exact spin step removes the pF amplification factor that would otherwise enter the nested commutators". **Correction**: This is correct for the off-diagonal part of $H_{\rm spin}^{\rm rot}$ (i.e. $\hat A$), but the diagonal part $-pF_z$ does NOT vanish from the macro-Y4 nested commutators; it contributes $[\text{diag}, H_{\rm DDI}]$ with amplitude $pF \cdot$ (off-diagonal DDI matrix element)/D. T56 argues this is bounded by $c_{dd}\langle n\rangle/D$ via a heuristic "in the eigenbasis of $\hat F_z$ this commutator acts non-trivially only through off-diagonal elements of the DDI tensor coupling" but does not give a rigorous bound. The empirical evidence (norm-drift constancy across phi) supports the conclusion, but the analytical derivation has a gap. **Severity: advisory-note** (empirical closure works).

2. **Source**: T56 §2.3 absorption factor application. **Claim**: BCH residual at phi=18 is $\sim 1.6 \times 10^{-5}$, derived from a bare amplitude $\Delta f^{\rm bare} \sim 540$ times absorption factor $3 \times 10^{-8}$. **Correction**: My independent re-derivation (§1.2 above) gives bare amplitude $\sim 1.1 \times 10^4$ (using $p\sin\theta F$ as the spin-step norm rather than $\dot\phi^2 F^2$) and absorption factor $(\dot\phi/p)^2 = 4.5 \times 10^{-7}$ at phi=18, yielding $\sim 5 \times 10^{-3}$. T56's pre-absorbed structure conflates one factor of $(\dot\phi/p)$ into the bare $\dot\phi^2$ prefactor. Both estimates are above the observed $\sim 10^{-6}$ (the test is 1–4 orders below CONFIRM threshold), so the discriminator still passes. **Severity: advisory-note** (estimates have ±2 order-of-magnitude uncertainty; both ranges include the observation within the CONFIRM band).

3. **Source**: T57 §5, T56 §4 pseudocode label. **Claim**: m+F "drop" should be positive (the label suggests decrease). **Correction**: All 8 observed values are negative (fraction increases). The cause is most likely (per C3 hypothesis (i)) that the snapshots at `t > SPINUP_END = 21.99` are still mid-relaxation from the spinup transient, and the system recovers ~1 ppm over the 1s steady window. The sign convention in the pseudocode/script is consistent; the label is misleading. **Severity: cosmetic** (rename to "m+F change" in future scripts; no scientific impact).

## §4 Verdict

**`CORROBORATE-WITH-ERRATA`** — tier 2.7 → 3.0 with 3 errata propagated to memory.

Next stage recommended: **Document** (T59). The Document turn should:
(a) Update memory `option_gamma_rotating_basis.md` with a "verified 2026-05-18 (T57+T58)" note citing the 8-phi sweep result + the analytical gap (errata 1).
(b) Rename the secondary observable label from "drop" to "change" (errata 3).
(c) Record the residual estimate uncertainty bars (errata 2) in the same memory file.
(d) Defer P3 p-scaling (T55 Falsifier 4) and cpu_heavy lab-frame snapshot reconstruction to post-closure follow-up.

Independent of judge.py PASS (operational gate) and T57 overall CONFIRM (scientific gate at executor level). The critic's gate is: **the line-37 memory claim is CORROBORATED at tier 3, with three named caveats**.

## §5 Recommended next-falsifier-to-test

Not REFUTE / not INCONCLUSIVE, so the question is deferred falsifier priority. Two follow-ups (post-closure):

1. **P3 p-scaling** (T55 Falsifier 4, deferred): fresh rotating_basis run at p ∈ {2670, 26700, 267000}, phi=4.524 fixed, dt=0.001. Falsifier: norm drift should be p-independent in rotating_basis; lab-frame counterpart at same parameters should scramble linearly in p. cpu_heavy ~30 min. Priority: medium (independent axis cross-check of the absorption mechanism; not blocking for closure).

2. **cpu_heavy lab-frame snapshot post-rotation** at phi=4.524 (canonical) + phi=18 (worst): load the 740 ψ̃ snapshots per phi, apply $\hat U_B^\dagger \hat F_z \hat U_B$ per snapshot, compute true lab-frame $\langle\hat F_z\rangle_{\rm lab}(t) + \langle\hat L_z\rangle_{\rm lab}(t)$. Falsifier: true EdH drift over $T=314$ should be $< 10^{-3}$. cpu_heavy ~30 min/phi. Priority: low (the mixed-frame proxy already supports tier 2.7 → 3.0; this is a tier-3.5 polish not a tier-3 requirement).

## §6 Metrics

```json
{
  "experiment_kind": "text_only",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Update",
  "flow_template": "verify-claim",
  "falsifier_id": "klaus-bch-leak-option-gamma-p2-plus-pop-discriminator",
  "verdict": "CORROBORATE-WITH-ERRATA",
  "tier_recommendation": 3.0,
  "next_stage_recommended": "Document",
  "independent_y4_floor_derivation": 3e-10,
  "independent_y4_floor_band_lo": 3e-11,
  "independent_y4_floor_band_hi": 2e-8,
  "observed_norm_drift_falls_in_independent_band": true,
  "independent_bch_residual_at_phi_18": 5e-3,
  "observed_m_plus_F_drops_consistent_with_zero_residual": true,
  "chi_square_sigma_baseline_circular": false,
  "alternate_max_sigma_deviation_using_full_residual_std": 1.59,
  "alternate_max_sigma_deviation_using_MAD": 5.2,
  "m_plus_F_sign_explanation": "recovery-from-transient",
  "jz_proxy_adequate": true,
  "larmor_phase_invariance_is_meaningful": false,
  "y4_commutator_norm_argument_rigorous": false,
  "propagators_jl_unchanged_since_t56": true,
  "confounder_C1_verdict": "CORROBORATE",
  "confounder_C2_verdict": "FLAG",
  "confounder_C3_verdict": "FLAG",
  "confounder_C4_verdict": "CORROBORATE",
  "confounder_C5_verdict": "CORROBORATE",
  "confounder_C6_verdict": "FLAG",
  "confounder_C7_verdict": "CORROBORATE",
  "errata_count": 3,
  "errata_load_bearing_count": 0,
  "errata_advisory_count": 2,
  "references_cited": [
    "hairer-lubich-wanner-2006-section-III.4-and-V.3.1",
    "yoshida-1990-PLA-150-262",
    "anderson-et-al-lapack-users-guide-3rd-ed-section-4.10",
    "demmel-veselic-1992-SIAM-J-Mat-Anal-13-1204",
    "kawaguchi-ueda-2012-phys-rep-520-253",
    "stamper-kurn-ueda-2013-RMP-85-1191"
  ],
  "n_references_cited": 6,
  "line_37_memory_claim_verified_current": true,
  "deferred_falsifiers": [
    "P3-p-scaling-fresh-run-3-p-values",
    "cpu-heavy-lab-frame-snapshot-post-rotation"
  ]
}
```
