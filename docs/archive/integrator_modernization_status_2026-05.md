> **FROZEN 2026-05.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

<!-- promoted from agent memory `integrator_modernization_status.md` on 2026-07-31; historical record, not an SSoT -->
<!-- Current state, gates, and decisions for the higher-order-integrator effort on the lab path -->

Current branch: `main`. Latest relevant commits:
- `98213f6` (2026-05-11) feat(integrator): Track A1 midpoint V step
- `59422e6` (2026-05-11) test(bench): Y6 midpoint verification
- `63ad7c1` (2026-05-11) feat(integrator): state-averaged trap V step + Phase 5 negative
- `704c0ee` (2026-05-11) docs(integrator): Ch.3 plan + Phase -1 protocol + Track C/B skeletons
- `1ee1de8` (2026-05-11) feat(integrator): Track C v1 Force-Gradient 4A00 (diagonal-only)
- `390f474` (2026-05-11) feat(integrator): Track C v2 — FFT spectral ∇V + midpoint/endpoint MF
- `0b0a822` (2026-05-11) feat(integrator): Track C v3 endpoint-only Picard + v4 spinor derivation
- `8d34a71` (2026-05-11) feat(integrator): Track C v3.1 + Phase 5 + §3.5 narrative — Track C scope complete
- `1877cf0` (2026-05-11) feat(integrator): Track B Thalhammer — Phase -1 complete, ≡ Chin-Krotscheck for J=1
- `de0b51e` (2026-05-11) docs(integrator): Phase 2b Eu + §3.7/§3.8 narratives — Ch.3 SCOPE COMPLETE

**Key in-repo docs (read in order for next-session pick-up)**:
- `docs/integrator_ch3_plan.md` — 修論 Ch.3 outline + §3.3 framework
  (MPS + state-avg failure modes joint section). Source of truth for
  Track A1/C/B scope and Track B skip decision.
- `docs/integrator_modernization_plan.md` — original plan + Track A1
  outcome update. Cross-references the four new docs.
- `docs/integrator_phase_minus_1_protocol.md` — 4 operational rules
  for Phase -1: (1) no memory paraphrase, (2) running doc with failed
  branches, (3) 3-condition anko review, (4) time hard cap (2 weeks
  Track C, 4 weeks Track B). Hard-gates Phase 0 implementation.
- `docs/integrator_track_c_derivation.md` — Track C Phase -1 skeleton.
  Step 0 is paper fetch (Chin 1997 + Chin-Krotscheck 2005 + Aichinger).
- `docs/integrator_track_b_derivation.md` — Track B Phase -1 skeleton.
  Conditional on Track C not already meeting thesis goals.

**Bench scripts**:
- Phase 2a hard-gate: `scripts/bench/midpoint_order_phase2a.jl`
- Picard convergence (midpoint): `scripts/bench/midpoint_picard_diag.jl`
- Picard convergence (trap): `scripts/bench/trap_picard_diag.jl`
- Phase 5 energy drift smoke: `scripts/bench/avf_drift_phase5_smoke.jl`

## Track A1 PARTIAL SUCCESS (2026-05-11)

`_half_potential_step_midpoint!` (Picard fixed-point predictor-corrector, n_picard=2
default) and `split_step_midpoint!` landed. `psi_mf` kwarg added to the 5
MF-reading substep kernels (spin_mixing, ddi[+padded], diagonal[_svec/_with_ls],
nematic, tensor) and threaded through `_dispatch_diagonal_step!` +
`_half_potential_step!`.

### Phase 2a result (Rb87 F=1, 16³, c0=50, c1=1, c_dd=1)

| scheme               | err@h=4e-3 | err@h=2e-3 | err@h=1e-3 | o12  | o23 |
|----------------------|------------|------------|------------|------|-----|
| Strang (plain & mid) | 2.09e-5    | 5.23e-6    | 1.31e-6    | 2.00 | 2.00 |
| Yoshida4 (plain)     | 3.69e-8    | 1.55e-8    | 7.70e-9    | 1.25 | 1.01 |
| **Yoshida4 (midpoint)** | 2.00e-8 | 9.12e-10   | 4.65e-10   | **4.46** | floor |
| Yoshida6 (plain)     | 4.07e-8    | 2.03e-8    | 1.01e-8    | 1.00 | 1.00 |
| **Yoshida6 (midpoint)** | **5.58e-10** | 5.29e-10 | 5.28e-10 | floor | floor |
| MPS-4 (plain)        | 5.42e-9    | 2.64e-9    | 1.35e-9    | 1.04 | 0.96 |
| MPS-4 (midpoint)     | 1.44e-9    | 5.78e-10   | 5.32e-10   | 1.32 | floor |

### Key findings

- **Composition-based Yoshida4 (midpoint) recovers order 4** at coarse dt; Yoshida6
  (midpoint) lands at the reference noise floor (~5e-10 from Strang dt=2e-5 ref)
  so its true order can't be read off this bench but is qualitatively high.
- **Richardson-based MPS-4 (midpoint) stays at order ~1** — **SUPERSEDED by A2.2
  below.** The three errors 1.44e-9 / 5.78e-10 / 5.32e-10 sit at this bench's own
  ~5e-10 reference floor, so o12 = 1.32 is floor-contaminated, not an order; against
  A2.2's Y6-mid dt=1e-5 reference the same scheme measures order 3.20. Picard converged to
  fixed point by iter 2 (‖p1-p2‖ ≈ 2e-11 at h=4e-3, ‖p2-p3‖ ≈ 2e-15), so the
  failure isn't a predictor accuracy issue: it's structural. S(h) and S(h/2)²
  in MPS-4 evaluate the midpoint MF at different effective time scales which
  don't correspond to the same point in the true solution trajectory, breaking
  the odd-only Richardson cancellation. Confirmed: even at Picard fixed point
  the midpoint scheme is only approximately time-reversible (ψ_mid_fwd ≠
  ψ_mid_bwd because the predictor's fixed-point depends on which direction
  the integration starts from).
- **MPS-{4,6} dropped from later phases** per the bench rule "Phase 2 で order
  崩れる integrator → Phase 3 以降から drop". Composition-based Yoshida-4/6
  is now the canonical high-order path on the lab path.

### Track A1.5: state-averaged trap (anko's "AVF-like" proposal) — NEGATIVE result

`_half_potential_step_trap!` / `split_step_trap!` implemented (Picard fixed-point
on ψ_exit; MF source = (ψ_orig + ψ_exit)/2). Phase 2a result: Y4-trap order 2,
NOT 4, even with Picard converged to fixed point (n_picard=4 gives bit-exact
same as n_picard=2). Phase 5 smoke (T=10 ω⁻¹, dt=0.001, c0=5+c1=0.5): energy
drift ΔE/|E₀| = -1.83e-7 (Y4-trap) vs +1.27e-12 (Y4-mid) - trap is 14万× WORSE.

Root cause (linear-H analysis): `(ψⁿ + ψⁿ⁺¹)/2 = ψⁿ · cos(Hτ/2) · e^{-iHτ/2}` has
an extra `cos(Hτ/2) = 1 - (Hτ)²/8 + ...` factor relative to midpoint - an
EVEN-power-in-τ correction that Y4's odd-only Richardson cancellation cannot
remove, collapsing order to 2 and amplifying drift.

**state-averaged trap ≠ Quispel-McLaren AVF**. AVF averages the GRADIENT
field `(∇H(ψⁿ) + ∇H(ψⁿ⁺¹))/2`, not the state. For quartic H these differ.
True AVF (gradient-avg) is more invasive (per-substep averaged-field buffer
plumbing for density_buf, alpha/beta/theta cache, Phi_x/y/z) and is the
candidate path forward IF energy conservation is a thesis priority.

### Open / follow-up

- **True (gradient-averaged) AVF**: deferred, more invasive than state-avg trap.
  Worth pursuing if Phase 5 Eu DDI long-time vortex bench shows Y4-mid drift
  competing with experimental observables.
- **Y6-midpoint true-order verification**: needs a higher-precision reference
  (Strang at dt=4e-6 or Yoshida4-midpoint as ref) to push the floor below the
  Y6 leading error. Currently can only say "≥ Y4 order".
- **Phase 2b (Eu151 F=6 full order table)** — separate session per anko's
  direction. Will use Y4/Y6-midpoint as the high-order schemes; MPS drops;
  state-avg trap drops too (Phase 5 confirmed it's worse than midpoint).
- **Phase 3 Pareto / Phase 4 ITP / Phase 5 long-time stability** — also
  separate session. Force-Gradient (Track C) v1 landed 2026-05-11.

## Track C v1 + v2 outcome (2026-05-11, commits 1ee1de8 + 390f474)

Phase -1 partial pass + Phase 0 v1 (4A00, central diff) + v2 (FFT spectral ∇V
+ midpoint/endpoint MF estimation via Strang predictors).

`split_step_forcegrad!(ws; midpoint=true, endpoint=true)` exported.
`_assert_forcegrad_diagonal_only` panics outside scope (c1≠0, DDI, etc).

Verified on 1D Rb87 F=1 (`scripts/bench/forcegrad_smoke.jl`):

| version | autonomous c0=0 | nonlinear c0=50 |
|---|---|---|
| v1 4A00 (central diff) | order 3.44 | order 0.96 |
| v2 (FFT + midpoint + endpoint MF) | order 3.86 | order 2.92→3.20 |
| Y4-mid (Track A1 baseline) | order 4.03 | order 4.00 |

v2 autonomous: ~4 within reference-precision floor.
v2 nonlinear: order ~3 (Strang predictors give O(dt²) MF accuracy →
V step output O(dt³) → cumulative O(dt²)≈order 3 in test range).

Aichinger-Chin-Krotscheck 2005 (CPC) not on arXiv. Step 5 derivation
in docs/integrator_track_c_derivation.md sketched from first principles:
- §5.1 nonlocal scalar V: same |∇V|² formula as local
- §5.2 spinor matrix V (c1): F-matrix algebra ({F_μ,F_ν} + iε_μνρ F_ρ)
- §5.3 DDI proper: combined matrix + nonlocal, ~10-15 cross-terms
- §5.4 v1-v5 roadmap

### Track C v3 partial (commit 0b0a822)

v3 endpoint-only Picard implemented. Converges by p=2. Nonlinear order
2.92 (p=1) → 3.60 (p=2). State-avg midpoint Picard attempted but FAILED
— reproduced §3.3.2 cos(Hτ/2) failure mode inside FG framework (order
collapsed to 2). Proper midpoint Picard via Strang re-prediction
deferred to next session.

v4 derivation (Step 5.2 in derivation doc): explicit F=1 [V_SM,[T,V_SM]]
symbolic form derived — 3 terms (i mult-Laplacian, ii **derivative** in
∇ψ, iii mult-gradient²). Term (ii) is the structural obstacle vs scalar
case. Implementation strategy outlined: multiplicative D×D matrix exp +
derivative FFT substep.

### Track C SCOPE COMPLETE (2026-05-11, commit 8d34a71)

All v3.1/v4/v5/Phase 5/§3.5 deliverables landed:

1. **v3.1 true midpoint Picard**: implemented (Strang re-prediction).
   Result: NO order improvement — Strang predictor structurally O(dt²)
   regardless of Picard iteration. Force-Gradient plateaus at order ~3
   nonlinear.
2. **v4 spinor matrix derivation**: explicit F=1 [V_SM,[T,V_SM]] in
   docs/integrator_track_c_derivation.md §5.2. Key finding: term (ii)
   `−i F_ρ(m × ∇m)_ρ · ∇` is a DERIVATIVE term — structural obstacle
   not present in scalar GPE Force-Gradient. Implementation deferred
   (low production ROI given Y4-mid wins).
3. **v5 DDI proper derivation**: matrix + nonlocal cross-term form
   drafted in §5.3 + §3.5.6.
4. **Phase 5 long-time drift**: scripts/bench/forcegrad_phase5.jl
   (1D Rb87 F=1, T=20 ω⁻¹). Y4-mid 2.8e-10 (machine precision)
   vs ForceGrad p=2 1.2e-7 — Y4-mid wins ~400×.
5. **§3.5 narrative**: docs/integrator_ch3_5_narrative.md with 7
   sections covering Track C complete picture.

**Verdict**: Y4-midpoint (Track A1) wins cost-per-accuracy AND
long-time energy drift in the diagonal-only test problem. Force-Gradient
is a working but inferior 4th-order scheme on the lab path.

**Thesis contributions**: (a) honest implementation + verification
of Chin-Krotscheck 2005 framework on lab path (v1-v3.1), (b) novel
derivation of spinor matrix term ii (∇ψ derivative — not in any
published scalar GPE Force-Gradient work), (c) clean Pareto comparison
to Y4-mid.

### Track B Phase -1 COMPLETE (2026-05-11, commit 1877cf0)

arXiv:2601.19838v1 fetched + §3-4 transcribed. Major finding:
Thalhammer eq 22 ≡ Chin-Krotscheck 2005 4A for J=1 scalar GPE
(bit-exact verified). `split_step_thalhammer!` alias exported.
F-matrix spinor + DDI extension produces SAME mathematical content
as Track C v4 §5.2 / v5 §5.3 via Lie-derivative formalism.
Implementation = Track C scope (deferred for F-matrix + DDI).

Phase -1 completed in 1 session (vs 4-week cap) because:
1. Paper structure was favourable (arXiv-available, well-organised §3-4)
2. J=1 reduction = known-correct (Chin's 4A reproduced by Thalhammer)
3. F-matrix extension = Track C v4/v5 content reused

§3.6 narrative drafted in `docs/integrator_ch3_6_narrative.md`.

### Track C + Track B unified picture

Two formalisms describing the SAME family of 4th-order modified
splitting methods. Bit-exact equivalence at J=1 implementation,
algebraic equivalence for F-matrix + DDI derivation.

**Publishable thesis Ch.3 findings**:
1. Explicit Chin-Krotscheck = Thalhammer equivalence proof for J=1
   (connects historical force-gradient with modern Lie-derivative)
2. Novel ∇ψ derivative term in [V_SM,[T,V_SM]] for spinor matrix V
   (= Track C v4 §5.2, Track B §3.6.3 confirms in alternative
   formalism)
3. Y4-midpoint wins cost-per-accuracy + long-time energy drift on
   lab path (Track A1 + Phase 5)

For thesis Ch.3: §3.5 (Track C) + §3.6 (Track B unification) provide
the derivation-level contribution. §3.8 recommends Y4-midpoint as
practical optimum.

## Track A originally (parked → superseded by A1)

- MPS-4 (Chin-Geiser) works on rotating-basis F=1 (~order 4) — verified in
  `scripts/bench/mps_smoke.jl`.
- Same MPS-4 on lab path collapses to order 1 (F=1 and F=6) — verified in
  `scripts/bench/mps4_lab_diagnostic.jl`.
- Root cause originally hypothesised as τ² from nested-Strang V step asymmetry;
  Track A1 testing now shows this is part of the story but not the whole story
  — even when the V step is structurally symmetric (Picard fixed-point MF) the
  Richardson 1-step coefficients don't survive the multi-scale evaluation
  S(h) vs S(h/2)².

## Track C v4 Step 1a/1c/1d (2026-05-12)

Followed-up implementation pass per anko's "全部やろう":

1. **Step 1a** (`scripts/bench/track_c_v4_step1a_smoke.jl`) — F=1 [V_SM,[T,V_SM]]
   multiplicative kernel (terms i + iii from §5.2). 6/6 explicit limit tests
   pass. Verified Hermitian + anti-Hermitian structure as predicted.

2. **Step 1b → 1c pivot** — Initially implemented analytical decomposition
   (i)+(ii)+(iii). Hermiticity test FAILED at order unity. Root cause: discrete
   FFT product aliasing breaks ∂_α(Q_ρα)=(m × ∇²m)_ρ identity → IBP cancellation
   between term (i) anti-Herm and term (ii) ∇ψ "shadow" doesn't work discretely.

   **Resolution** (`scripts/bench/track_c_v4_step1c_direct.jl`): use direct
   discrete commutator [V,[T,V]] = 2VTV − VVT − TVV. Automatically Hermitian
   since V_SM and T are individually discrete-Hermitian. **Rel dev 4.4e-15
   (machine precision)** on 7/7 tests. Cost: 3 V + 2 T applications per
   substep. Memory: [v4 discrete Hermiticity](integrator_v4_discrete_hermiticity.md).

3. **Step 1d order test** (`scripts/bench/track_c_v4_step1d_order.jl`) —
   c₁=50, T=0.04, N=16³, T_FINAL=0.04. Strang baseline order 2.00 ✓.
   **Strang + v4 FG correction (α=dt³/48): also order 2.00, error ratio
   1.00× vs Strang**. FAIL Gate 1.

   **Diagnosis**: Strang truncation has TWO commutators in the BCH expansion,
   `-(dt³/24)[V,[T,V]] + (dt³/12)[T,[T,V]]`. FG correction (V_eff modification)
   cancels [V,[T,V]] but NOT [T,[T,V]]. For non-harmonic V (spin-mixing V_SM is),
   both contribute → FG alone cannot reach order 4.

   **Implication**: Track C v4 needs Forest-Ruth-Chin composition (multiple K
   substeps with optimized weights, e.g. Chin Type-1 schemes) to cancel both
   error terms. The Step 1c direct-commutator kernel is correct and reusable;
   the multi-step skeleton is the missing piece. = post-修論 work.

   **Y4-midpoint (Track A1) remains the 修論 practical optimum** by virtue of
   already achieving order 4 on lab path with simple composition.

## A1.1 Chin 4A + direct-commutator order test (2026-05-12)

`scripts/bench/track_c_v4_a11_chin4A.jl` + `..._alpha_sweep.jl`:
- **FG sign for real time = α = -dt³/72** (Wick rotation flip of CK 2005
  eq 6.9 imaginary-time Δτ²/48 → -dt²/48). Memory:
  [FG sign under Wick rotation](gotcha_fg_correction_sign_wick_rotation.md).
- **Autonomous Chin 4A** with correct sign reaches FP-floor (~1e-12,
  matches Forest-Ruth frozen reference) → order 4 verified for the
  composition + direct-commutator kernel + sign combo.
- **Nonlinear (self-consistent GP)** stuck at order 2 in all variants:
  freeze m̄, simple Picard ((m_entry+m_exit)/2), Strang-half-step
  predictor-corrector. All-positive-coefficient compositions need a
  4th-order midpoint predictor, which is circular/expensive.
- **Forest-Ruth (no FG)** reaches order 4 even with freeze-m̄ —
  negative-coefficient slot structure tolerates m̄ recomputation per
  slot, unlike Chin 4A's all-positive coefficients.
- **Practical**: Y4-midpoint remains production optimum; Track C v4 is
  the theoretical complete picture for §3.5 with the FG sign confirmed.

## A3 adaptive control (2026-05-12, INFRASTRUCTURE COMPLETE)

`scripts/bench/track_a3_adaptive_y4mid.jl` (smooth Phase 2a) +
`track_a3_adaptive_burst.jl` (Gaussian Zeeman pulse). Bench-only; src/
integration deferred (requires Workspace.sim_params mutability fix OR
`split_step!(ws; dt)` API refactor — both invasive).

Defect estimator (Hairer-Wanner Richardson, ψ_full vs ψ_half²) + PI
controller (α=β=1/(p+1)) implemented. **Controller works**:
- Closed-loop convergence: tol → 0 ⇒ err → 0.
- Burst detection: in test 4.2 the controller shrinks dt 3× in the
  pulse region (mean dt = 5.1e-4 vs smooth 1.5e-3).

**But acceptance tests FAIL**:
- Test 4.1 (smooth Phase 2a): 2.13× vs cheapest fixed Y4-mid (target
  ≤ 2×). Defect-based controller has structural 3× cost; smooth
  problems can't absorb the overhead.
- Test 4.2 (Gaussian Zeeman pulse, synthetic near-instability):
  8× SLOWER than fixed Y4-mid at dt=2e-3. **Diagnosis**: the
  synthetic pulse isn't actually stiff (Y4-mid handles it fine at
  dt=2e-3). True Eu post-quench would test the controller properly
  but costs ~30 min for fixed-dt baseline.

**Limit-cycle behavior at loose tol**: err-vs-tol slope = 0.63
(expected 1.0). Söderlind's recommended NEGATIVE β would dampen
this (α=β=1/(p+1) here, positive — destabilizing).

**Production integration COMPLETE (2026-05-12 commit `c755e18`)**:
- `src/hamiltonian/integrator/adaptive.jl` exports `AdaptiveDtState`,
  `adaptive_step!`, `adaptive_run!`. Threads dt via new
  `split_step_midpoint!(ws; dt=...)` kwarg.
- `test/hamiltonian/test_adaptive_dt.jl`: 18 tests PASS.
- Regression: integrator suite (DDI/CFET4/Y4/Y6/combined_spin/
  batched_kinetic) all green.

**Eu151 post-quench validation (commit `57bf131`)**:
`scripts/bench/track_a3_eu_postquench.jl`. F=6 D=13 16³ with Zeeman
quench p: 1→100 at t=0.025, T=0.05. Adaptive correctly refines dt
4× through the quench region (mean dt: 8.6e-4 pre → 2.3e-4 quench →
3.3e-4 post). 85× dt span at tol=1e-9. Pareto: 1.6-2.3× slower than
fixed-dt match at tol≥1e-7, but tol=1e-9 (err=1.8e-7) is UNREACHABLE
by tested fixed-dt range — adaptive uniquely covers tight tolerance.

**Path forward for further improvement (not blocking)**:
1. Switch to global-error scaling (normalize defect by dt/T) — slope-1
   behavior expected.
2. Embedded-pair error estimator (vs defect's 3× cost) to make adaptive
   competitive at moderate accuracy.
3. Eu post-quench at F=6 T=1.0 (full design-doc spec, ~30 min) for
   long-time validation.

## A2.2 MPS-{4,6,8} Pareto (2026-05-12)

`scripts/bench/track_a22_mps_pareto.jl` on Phase 2a (Rb87 F=1, N=16³,
c0=50, c1=1, c_dd=1, T=0.04, Y6-mid dt=1e-5 reference):

| dt    | Strang-mid | Y4-mid   | Y6-mid   | MPS-4    | MPS-6    | MPS-8    |
|-------|------------|----------|----------|----------|----------|----------|
| 4e-3  | 2.09e-5    | 2.04e-8  | 9.10e-11 | 1.00e-9  | 9.11e-11 | 9.10e-11 |
| 2e-3  | 5.23e-6    | 1.28e-9  | 9.08e-11 | 1.09e-10 | 9.10e-11 | 9.09e-11 |
| 1e-3  | 1.31e-6    | 1.22e-10 | 9.03e-11 | 9.09e-11 | 9.07e-11 | 9.05e-11 |
| 5e-4  | 3.27e-7    | 9.07e-11 | 8.94e-11 | 9.06e-11 | 9.02e-11 | 8.96e-11 |

First-step orders (4e-3 → 2e-3): Strang 2.00, Y4 **3.99**, MPS-4
**3.20**, Y6/MPS-6/MPS-8 floor-limited at ~9e-11 from coarsest dt.

**MPS-4 on lab path with `_half_potential_step_midpoint!` recovers
order ~3-4**, falsifying the original Track A diagnostic "MPS family
loses on lab path" (which used plain `split_step_combined!` with the
asymmetric V step). The Track A1 midpoint fix restored Richardson
cancellation.

Pareto winner per accuracy band (cost in inner-midpoint-Strang units):
- err < 1e-4: Strang-mid (10 units)
- err < 1e-6: Y4-mid (30 units) — same cost as MPS-4 but no floor risk
- err < 1e-8: Y4-mid (60 units, dt=2e-3)
- err < 1e-10: **MPS-6 (60 units)** — beats Y6-mid (70) by ~15%

**Recommendation**: keep Y4-mid as production default. MPS-6 src/
integration is a future option for high-accuracy long-time evolution
where 15% cost win matters.

## What's NOT verified

- Y6-midpoint true order on the lab path (floor-limited bench data).
- MPS-{6,8} true order on the lab path (also floor-limited; finer
  reference Y6-mid at dt ≤ 2e-6 would resolve it).
- Force-Gradient (Chin) DDI extension — A1.2 deferred; original
  acceptance was contingent on Chin 4A reaching nonlinear order 4
  which it didn't.
- Thalhammer 2026 modified-splitting extension to spinor + DDI —
  research-grade derivation, not started.
- Eu151 F=6 lab-path behavior with Y4/Y6-midpoint — Phase 2b in
  separate session.
