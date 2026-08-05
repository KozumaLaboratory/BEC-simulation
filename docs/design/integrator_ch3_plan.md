# 修論 Ch.3 Plan — Integrator hierarchy for spinor BEC with DDI

> **FROZEN 2026-05-23.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Status:** plan + framework, 2026-05-11.
**Scope:** 60-80 pages, 3-4 month commitment. Thesis-body chapter alongside
Universal Structure Theorem / EdH / Flower phase chapters.

This document lives next to `docs/design/integrator_modernization_plan.md`
(roadmap-level) and the per-track `docs/design/integrator_track_{c,b}_derivation.md`
(Phase -1 manuscripts). The protocol for entering Phase 0 implementation is
fixed in `docs/design/integrator_phase_minus_1_protocol.md`.

## Final outline

- **§3.1 Failure mode of frozen-MF Strang.** Inner Strang of the lab-path
  V-step `diag · SM · DDI · SM · diag` reads the mean field (Φ_DDI, c₁⟨F⟩,
  c₂A₀₀, c₄⁺ tensor h) at substep ENTRY. Forward and backward SM substeps
  flanking the central DDI substep evaluate the MF at DIFFERENT ψ states,
  breaking time-reversal symmetry of the V step. Document the τ² even-power
  residual numerically (table from
  `test/hamiltonian/test_integrator_order_meanfield.jl`).

- **§3.2 Symmetric Strang via midpoint predictor-corrector.** `_half_potential
  _step_midpoint!`: 2-iteration Picard fixed-point estimate of ψ_mid, then a
  corrector V step where all substeps share the same midpoint MF. Inner
  Strang is then exactly time-reversal symmetric. Order verification on Rb87
  F=1 lab path: Strang remains order 2, Yoshida-4 jumps from collapsed
  order 1.25 to recovered order 4.46.

- **§3.3 Fragility of Richardson-cancellation under non-uniform MF
  approximation.** A common framework for the negative results.

  Theorem (informal). High-order schemes built on Richardson / odd-only
  Taylor cancellation (MPS-4 Chin-Geiser, Yoshida composition) achieve
  nominal order *only if* the V step's local error has a purely odd-power
  Taylor expansion in τ. This requires the V step to be **frame-consistent
  symmetric**: all substeps within one V evaluation share a single
  MF-evaluation point (= same τ-level snapshot).

  Two failure modes preserved as negative results in the literature for the
  spinor + DDI lab path:

  - **§3.3.1 MPS-4 multi-scale failure** (Track A,
    `scripts/bench/mps4_lab_diagnostic.jl`). The Richardson formula
    `T₄(h) = (4/3)·S(h/2)² − (1/3)·S(h)` evaluates the midpoint MF at TWO
    different effective time scales: `S(h)` uses one midpoint, `S(h/2)²`
    uses two (and they don't coincide with a single true trajectory point).
    Even at Picard fixed-point per stage, the resulting V-step local error
    contains τ² terms which Richardson coefficients cannot cancel —
    collapsing MPS-4 to global order ≈ 1. Verified on F=1 (Rb87) and F=6
    (Eu151) lab paths; the rotating-basis path's V step has no inner
    nesting and MPS-4 there gives order 4 cleanly.

  - **§3.3.2 State-averaging ("AVF-like") failure** (Track A1.5,
    `scripts/bench/avf_drift_phase5_smoke.jl`). A predictor-corrector V
    step with MF source `(ψⁿ + ψⁿ⁺¹)/2` (state-average) gives Y4-composed
    order 2, not 4. Linear-H analysis:
    `(ψⁿ + ψⁿ⁺¹)/2 = ψⁿ · cos(Hτ/2) · e^{−iHτ/2}` differs from the true
    midpoint by `cos(Hτ/2) = 1 − (Hτ)²/8 + ...` — an EVEN-power-in-τ
    correction. The τ² shift in the effective Hamiltonian breaks Yoshida's
    odd-only Richardson cancellation. Energy drift consequently 14·10⁴ ×
    worse than Y4-midpoint at machine-precision baseline.

  Common lesson: schemes designed to cancel τ³ + τ⁵ + ... fail whenever
  the V step's leading error carries even-power-in-τ structure. The two
  pathologies above are distinct origins of the same fragility — MPS-4
  multi-scale sampling and state-averaging cos(Hτ/2) — and are presented
  side-by-side in the framework.

  This is NOT a Richardson-versus-composition theorem: Yoshida composition
  is itself a Richardson-like (odd-cancellation) device. The crucial
  positive condition is **frame-consistency of MF evaluation**, which
  Y4-midpoint Picard satisfies and the two failure modes above do not.

- **§3.4 Yoshida composition hierarchy.** Y4-midpoint (order 4 verified on
  lab path), Y6-midpoint (order ≥ 4 on lab path, true-order verification
  requires finer reference than current Strang-at-dt=2e-5 floor; bench
  table from `scripts/bench/midpoint_order_phase2a.jl`).

- **§3.5 Force-gradient extension to spinor + DDI** (Track C, Chin 1997 +
  Chin-Krotscheck 2005 + Aichinger-Chin-Krotscheck 2005). Independent
  derivation of the `[V, [T, V]]` double commutator under (a) c₀|ψ|⁴ +
  c₁⟨F⟩² contact spinor matrix algebra, (b) DDI nonlocal extension
  ∇V_dd^eff = U_dd ∗ ∇ρ. Phase -1 manuscript:
  `docs/design/integrator_track_c_derivation.md`. Phase 0+ implementation,
  smoke / lab / Pareto bench.

- **§3.7 [or §3.3.2 if framework integration accepted] State-averaging
  AVF negative result.** See §3.3.2 above. If §3.3 is kept as the
  positive theorem + 2 failure modes joint section, §3.7 is freed up for
  optional content (true gradient-averaged AVF analysis or Force-Gradient
  ablation). If §3.3 is split into §3.3.1 only, §3.7 holds the AVF
  state-averaging negative on its own.

- **§3.8 Comparison & recommendations.** Pareto front (cost-per-accuracy)
  for real-time vortex dynamics. Recommended default = Y4-midpoint for
  generic real-time GPE-with-MF; Force-Gradient (Track C) recommended if
  long-time energy drift is the observable constraint. Decision tree by
  problem class.

## Status (2026-05-11)

| Track | Status | Latest evidence |
|---|---|---|
| A — drop-in MPS-{4,6} | Parked, see §3.3.1 | `scripts/bench/mps4_lab_diagnostic.jl` |
| A1 — midpoint Strang | Done | commits 98213f6 + 59422e6 |
| A1.5 — state-averaging trap | Negative, see §3.3.2 | commit 63ad7c1 |
| C — Force-Gradient + DDI | Phase -1 not started | template at `docs/design/integrator_track_c_derivation.md` |

## Verify-first reinforcement

The AVF state-averaging negative result (§3.3.2) traced back to a
**memory-based formula paraphrase** at proposal time — the same failure
mode as the earlier MPS-{10,12} over-optimism and the Chin C₆₀ misread
(both documented in `docs/design/integrator_modernization_plan.md` and
`memory/integrator_modernization_status.md`). The Phase -1 protocol
(`docs/design/integrator_phase_minus_1_protocol.md`) hardens against this
for Track C: no formula enters the derivation manuscript without
verbatim transcription from the cited paper, and Phase 0 implementation
is blocked until anko's review confirms transcription + justification +
self-checks all pass. Time hard cap (2 weeks Track C) prevents
sunk-cost continuation when derivation diverges.

## Schedule (M2 8-month plan)

- **Month 1-2** (current + next): Track A1 finish (commits 98213f6,
  59422e6, 63ad7c1 land Y4/Y6-midpoint + AVF state-avg negative). Phase 2b
  (Eu151 F=6 order table) + Phase 3 (Pareto) + Phase 5 (long-time
  stability with Y4-mid baseline) in next session(s).
- **Month 3-4**: Track C — Phase -1 (paper fetch + 紙 derivation, 2-week
  hard cap), then Phase 0 implementation + Phase 1-2 smoke / lab bench.
- **Month 5-8**: Phase 3-5 integrated bench. §3.5 manuscript draft.
  §3.8 comparison + Ch.3 final.
