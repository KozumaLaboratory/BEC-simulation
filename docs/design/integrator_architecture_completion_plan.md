# Integrator Architecture Completion — Master Plan (2026-05-12)

**Scope**: A1–A4 sub-phase program to bring the SpinorBEC.jl integrator
suite from "Y4-midpoint baseline + Track C v3.1 lab-path FG + Step 1c
direct-commutator v4 prototype" to production-grade Thalhammer-Full
(spinor + DDI) with full adaptive control + TDHFB palindromic substep.

**Status**: master plan only. Sub-phase A1, A4 individually scoped in
existing design docs (`docs/design/integrator_track_c_derivation.md`,
`tdhfb_y4_palindromic_substep_design.md`). A2 is bench work, partially
executable this session. A3 is a new research direction with no current
implementation.

**Estimated scope**: 4–8 multi-session blocks per sub-phase.

---

## A1: Track C v4 Step 1b-3 Completion → Thalhammer-Full

**Goal**: A working spinor + DDI Force-Gradient v4 implementation
equivalent to Thalhammer 2008's modified-splitting framework, achieving
order 4 on the F=6 Eu DDI lab path.

**Pre-conditions met (this session series, 2026-05-12)**:
- Step 1a: F=1 multiplicative kernel (terms i + iii) verified at
  6/6 limit tests (`scripts/bench/track_c_v4_step1a_smoke.jl`).
- Step 1b → 1c pivot: analytical (i)+(ii)+(iii) Strang split fails
  discrete Hermiticity (rel dev 0.65) and palindromic gate (order 2
  residual, `scripts/bench/track_c_v4_step1b_palindrome.jl`). Direct
  commutator [V_SM, [T, V_SM]] = 2VTV - VVT - TVV is auto-Hermitian
  at machine precision (rel dev 4.4e-15,
  `scripts/bench/track_c_v4_step1c_direct.jl`).
- Step 1d: FG-on-Strang structurally limited to order 2 for non-
  harmonic V (BCH has [T,[T,V]] term FG cannot cancel,
  `scripts/bench/track_c_v4_step1d_order.jl`).

**Remaining work (multi-session)**:

### A1.1 — Forest-Ruth-Chin composition with direct commutator (COMPLETE 2026-05-12)

Implement the v4 force-gradient correction inserted into a Forest-Ruth
or Chin Type-1 composition (multiple K substeps at optimized weights)
so that BOTH leading BCH commutators `[V,[T,V]]` AND `[T,[T,V]]`
cancel. The Step 1c direct-commutator kernel is auto-Hermitian and
slots cleanly into this structure.

Acceptance (original): order 4 on F=1 spin-mixing lab path (c_1 = 50,
T = 0.04), matching Y4-mid performance.

**Result (`scripts/bench/track_c_v4_a11_chin4A.jl` +
`track_c_v4_a11_alpha_sweep.jl`)**:

1. **FG kernel + sign verified**: bare 5-stage symmetric (1/6, 1/2,
   2/3, 1/2, 1/6) + direct commutator at α = -dt³/72 reaches FP-floor
   (~ 1e-12) in the AUTONOMOUS (linear V_SM = c₁·m̄_global·F) limit.
   α-sweep confirms +1/72 sign gives order 2; only -1/72 yields
   order 4. The negative sign comes from Wick rotation Δτ² → -dt² of
   CK 2005 eq 6.9's (Δτ²/48) FG coefficient.

2. **Nonlinear GP gate FAILS**: with self-consistent V_SM(ψ),
   Chin 4A_freeze and Chin 4A_picard (average-m̄) yield order 2.
   Strang half-step predictor (`Chin4A_predcorr`) reduces the
   constant by 20× but stays at order 2 — same structural barrier
   as Track C v3.1 (CLAUDE.md `pitfall_pipeline_inference.md` family
   note): a 4th-order predictor is needed for the midpoint m̄, which
   makes the scheme circular / expensive.

3. **Forest-Ruth (nonlinear) reaches order 4 with freeze-m̄**: its
   negative-coefficient slot structure tolerates freeze-m̄ at the V
   slots, unlike Chin 4A's all-positive coefficients.

**Practical conclusion**: Y4-midpoint (Track A1) remains the practical
optimum for nonlinear GP. Track C v4 + direct commutator is a clean
theoretical construction but hits the same structural limit as v3.1
on GP lab paths.

**Thesis impact (§3.5.x)**: Section narrative needs to be updated to
say the direct-commutator kernel + correct FG sign achieves order 4
in the autonomous case, and the nonlinear-GP failure is a structural
property of all-positive-coefficient compositions — not specific to
the multiplicative-decomposition (Step 1b) or finite-difference
discretization. Forest-Ruth-Suzuki triple-jump remains the only
positive-effective-coefficient route to order 4 for nonlinear GP
that doesn't require iterative predictors.

### A1.2 — DDI cross-terms

§5.3 of `integrator_track_c_derivation.md` outlines:

```
[V_DD, [T, V_DD]] ψ = ([M,∇²M]·(-1/2) + ∇M·∇M - M·∇²M·(1/2))_{αβ} ψ_β
                    + (-[M, ∇M])_{αβ} · ∇ψ_β
```

For F=6 DDI: implement the direct commutator
`2 V_{DD} T V_{DD} - V_{DD}² T - T V_{DD}²` (analog of Step 1c for the
DDI sector). Cost: 2 V_DD applications (each = FFT-convolve + diag
mult) + 1 T application per substep.

Acceptance: order ≥ 3 on F=6 16³ Eu DDI lab path within reference-
precision floor.

### A1.3 — F-matrix + DDI unified

The DDI is matrix-valued in spin (via the dipole coupling structure)
and nonlocal (via convolution). The full v4 correction in this
combined regime has additional cross-terms beyond just `[V_SM, [T,V_SM]]`
or `[V_DD, [T, V_DD]]` — there's also `[V_SM, [T, V_DD]]` and
`[V_DD, [T, V_SM]]`. The full Thalhammer-Full implementation captures
all four.

Acceptance: order 4 on F=6 16³ DDI + c_1 spinor lab path.

**Estimated scope**: 3 sessions (A1.1 = 1 session DONE 2026-05-12,
A1.2 = 1 session, A1.3 = 1 session). Linked to task #91. **A1.2 and
A1.3 are now reconsidered**: extending the direct-commutator kernel to
DDI and full Thalhammer-Full was predicated on Chin 4A reaching order 4
on the nonlinear lab path. Since that gate failed (autonomous order 4
verified, nonlinear order 2 capped), A1.2/A1.3 should target order
≥ 3.5 in the autonomous limit only — the practical takeaway for the
modernization plan is that Y4-midpoint is the production scheme and
Track C v4 is the theoretical complete picture.

---

## A2: Higher-Order Yoshida + MPS Family Audit

**Goal**: definitive characterization of Y6-midpoint true order on the
lab path + MPS-{4, 6, 8} Pareto plot showing accuracy-per-step-cost
tradeoff at production-relevant parameters.

**Pre-conditions met**:
- Y6-midpoint (`split_step_y6_midpoint!` in
  `src/hamiltonian/integrator/y6.jl`) is implemented and reaches the
  reference-precision floor on Problem A (autonomous F=1) — true
  order ≥ Y4 but indistinguishable from Y4-mid at the current floor
  level.
- MPS-{4} (Chin-Geiser midpoint) is implemented and reaches order 4
  on the rotating basis, but collapses to order ~1 on the lab path
  (`scripts/bench/mps4_lab_diagnostic.jl`).

**Remaining work (this session + 1 more)**:

### A2.1 — Y6-mid true-order floor verification (THIS SESSION partial)

Build a higher-precision reference via Y4-midpoint at dt = 4×10⁻⁶ on
the Phase 2a problem (F=1 16³, c_0=50, c_1=1, c_dd=1). Y4-mid at this
tiny dt gives reference accuracy ~10⁻¹² which is below Y6's leading
error at dt = 10⁻³, so the true Y6 order can be measured.

Acceptance: Y6-mid measured order ≥ 5.5 (vs theoretical 6).

### A2.2 — MPS-{4, 6, 8} Pareto

Implement MPS-6 and MPS-8 (Chin-Geiser higher-order extrapolation,
not yet in code). Run on Phase 2a problem. Plot:
- x-axis: log(dt) → grouped equivalent "work" (FFT count)
- y-axis: log(error vs reference)
- color: scheme (Y4-mid, Y6-mid, MPS-4-mid, MPS-6-mid, MPS-8-mid,
  Strang-mid)

Acceptance: clear Pareto frontier showing which scheme dominates at
each accuracy level. Hypothesis: Y4-mid wins at moderate accuracy
(1e-6 < err < 1e-9), Y6-mid wins at higher accuracy (err < 1e-9),
MPS family loses across the board on the lab path.

**Estimated scope**: 2 sessions (A2.1 = partial this session, A2.2 =
1 dedicated session). Bench-only, no new src/ code beyond MPS-6/8.

---

## A3: Adaptive Control Upgrade

**Goal**: production-grade adaptive timestep control via defect-based
estimators, embedded pairs (e.g., Fehlberg-style), or PI controllers.
Current code uses fixed dt only.

**No current implementation**. Three approaches in literature:

### A3.1 — Defect-based estimator (Hairer-Wanner)

For a given scheme `S` of order `p`, compute the local defect via:
```
defect = |S(dt) ψ - exp(-i H dt) ψ| ≈ C · dt^(p+1)
```

The exact `exp(-i H dt)` is approximated by Richardson extrapolation
of `S(dt/2)²` (one order higher). The defect drives a step-size
controller (typical PI form: `dt_new = dt · safety · (tol / defect)^(1/p)`).

**Pros**: clean theoretical basis, well-tested in ODE community.
**Cons**: extra cost of `S(dt/2)²` is ~3× per step at minimum.

### A3.2 — Embedded pairs (Fehlberg / Dormand-Prince style)

Use two schemes of orders `p` and `p-1` that share most of the same
FFT/V evaluations. Difference between the two gives the local error
estimate at minimal additional cost.

**Pros**: very cheap error estimation (often free or 1.1× cost).
**Cons**: requires finding split-step schemes with embedded pairs —
not all our schemes (Strang, Y4-mid, etc.) have natural embedded
counterparts. Need to construct them.

### A3.3 — L2-PI controller (Söderlind 2003)

Standard PI controller for step-size with safety factors:
```
dt_{n+1} = dt_n · safety · (tol/err_n)^α · (err_{n-1}/err_n)^β
```

with α = 1/(p+1), β = 1/(p+1) typically. Stable across smoothness
changes.

**Pros**: simple to add to existing scheme + error estimator.
**Cons**: needs the error estimator from A3.1 or A3.2 as a sub-routine.

### A3.4 — Recommended approach

Implement A3.1 defect-based with A3.3 L2-PI controller as the
combined adaptive system. Test on Phase 2a (smooth dynamics) and
Phase 5 (long-T near-instability). Compare to fixed-dt Y4-mid /
Y6-mid baselines.

Acceptance: adaptive control delivers same final accuracy at ≤ 2×
fixed-dt cost on Phase 2a, and at < 50× fixed-dt cost on the
near-instability regime where fixed-dt requires conservative dt.

**Estimated scope**: 2–3 sessions (controller plumbing in src/ +
two bench problems).

---

## A4: TDHFB Y4 Palindromic Substep (#86 Option B)

**Goal**: make `tdhfb_y4_midpoint_step!` actually order 4 (currently
order 2 due to palindromic gap, see
`tdhfb_y4_palindromic_substep_design.md`).

**Pre-condition**: Phase 5 GPU port complete (per Option B's 2700×
per-voxel cost increase, see #84 design doc).

**Remaining work (multi-session, post-修論)**:

### A4.1 — GPU port (Phase 5, #84)

Per `docs/design/tdhfb_gpu_port_design.md`: port per-voxel BdG matrix
exp to cuSOLVER batched eigen, port FFT to CUFFT, etc.

### A4.2 — Bogoliubov-amplitude basis

Diagonalize BdG once per substep, evolve amplitudes via
diag(exp(-i λ_k dt)), compress back to (φ, ρ, κ).

### A4.3 — Palindromic gate verify + Y4 composition

Re-test `‖S(-dt) S(dt) - I‖∞ ≤ O(dt⁵)`. Run Yoshida-4 composition
on the new substep → should now deliver order 4 globally.

### A4.4 — Production validation

C3 / C4 conservation tests at strict 10⁻⁶ tolerance, Eu Regime A
+ Regime B production data with proper variational consistency.

**Estimated scope**: 3 sessions A4.1-A4.4 (after GPU port = #84).

---

## Cross-references / dependencies

```
       (Phase 5 GPU port, #84)
              |
              ↓
        (#86, A4: Y4 palindromic)
              |          ↑
              ↓          |
       (A2: Y6-mid       (A3: adaptive
        + MPS audit)      control)
              |
              ↓
       (A1: Track C v4
        Step 1b-3,
        Thalhammer-Full)
              |
              ↓
       (修論 Ch.3 final
        narrative)
```

A2 and A3 are independent and can be parallelized. A1 depends on
nothing new (Step 1c kernel is done). A4 depends on Phase 5 GPU port.

---

## What this session accomplished (2026-05-12)

Pre-A1 work:
- Step 1a/1b/1c/1d benches (commits `2401ac2`, `445d7c8`).
- §3.5.8 narrative integration (commits `7c684c8`, `7bb600e`).

A4 prep work:
- `tdhfb_y4_palindromic_substep_design.md` design doc (commit `689ee37`).

Submission-prep (#78):
- All 4 papers: main.md drafts, cover letters, references.txt,
  LaTeX + bib filter pipelines, figure inventory + 8/16 figure builders.

---

## Next sessions priority order

1. **A2.1**: Y6-mid floor-test verification (small, doable in 1 session).
2. **A1.1**: Forest-Ruth-Chin composition with direct commutator
   (foundational for A1.2, A1.3).
3. **A2.2**: MPS-6/8 Pareto.
4. **A3.4**: Adaptive control (defect-based + L2-PI).
5. **Phase 5 GPU port** (#84).
6. **A4.1-4**: TDHFB Y4 palindromic substep.
7. **A1.2, A1.3**: DDI cross-terms + Thalhammer-Full unified.

---

**Last update**: 2026-05-12 (initial plan; cross-references the 2026-05-12
session series commits `5b457a7..689ee37` on origin/main).
