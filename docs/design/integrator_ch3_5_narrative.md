# §3.5 Force-gradient extension to spinor + DDI — narrative draft

**Status**: draft, 2026-05-11. To be folded into Ch.3 main text.
**Track C closure**. See `docs/design/integrator_ch3_plan.md` for overall Ch.3.

## §3.5.1 Motivation (Chin-Krotscheck 2005 algorithm 4A)

The scalar Gross-Pitaevskii equation admits a fourth-order
forward-symplectic integrator (Chin-Krotscheck, *Phys. Rev. E* **72**,
036705, 2005) of the form

```
ψ(dt) = e^{-i·(dt/6)V(dt)} · e^{-i·(dt/2)T} · e^{-i·(2dt/3)Ṽ(dt/2)}
        · e^{-i·(dt/2)T} · e^{-i·(dt/6)V(0)} ψ(0)
```

with the modified middle V

```
Ṽ = V + (dt²/48) [V, [T, V]] = V + (dt²/48) |∇V|²       (for scalar V)
```

The 5-stage `V K Ṽ K V` composition with all-positive coefficients
(1/6, 1/2, 2/3, 1/2, 1/6) and a `+τ²·|∇V|²` gradient correction in the
middle stage is the simplest forward-positive 4th-order algorithm for
imaginary-time GPE (Sheng-Suzuki-Goldman-Kaper theorems show no plain
ABA composition can be 4th-order with all-positive coefficients beyond
order 2; the gradient correction circumvents this).

For real-time (vortex dynamics, etc.) the substitution τ → it gives

```
Ṽ_real = V − (Δt²/48) |∇V|²       (sign flip from τ² → (iΔt)²)
```

This sign convention was identified during Phase -1 transcription and
prevented an implementation bug at Phase 0 (commit 1ee1de8 → first
order due to wrong sign → 390f474 fixed). The same verify-first
philosophy that caught the AVF state-averaging negative (§3.3.2)
helped here.

## §3.5.2 Phase -1: paper transcription + spinor extension

Phase -1 manuscript in `docs/design/integrator_track_c_derivation.md` carries
the full derivation. Headlines:

- **§5.1 nonlocal scalar V**: `[V_NL, [T, V_NL]] = |∇V_NL|²` retains the
  same scalar form as the local case, because once `V_NL(r)` is computed
  for a given ψ, it acts as ordinary multiplication. Implementation
  uses FFT-based convolution + FFT-based ∇.
- **§5.2 spinor matrix V (c₁ spin-mixing)**: F-matrix algebra introduces
  a derivative `∇ψ` term in `[V_SM, [T, V_SM]]` that scalar V lacks.
  Three explicit terms: (i) `-(i/2)F_ρ(m × ∇²m)_ρ` multiplicative,
  (ii) `-i F_ρ(m × ∇m)_ρ · ∇` derivative, (iii) `-(1/2){F_μ, F_ν}
  (∇m_μ)·(∇m_ν)` multiplicative.
- **§5.3 DDI proper (matrix + nonlocal)**: combines (5.1) and (5.2)
  structures. Cross-commutator-style expansion gives both
  multiplicative `[M, M^(2)] - M^(1)·∇M + ∇M·∇M` and derivative
  `-[M, ∇M]·∇ψ` parts, where M is the matrix-valued local-acting form
  of V_DDI (after FFT convolution).

Aichinger-Chin-Krotscheck 2005 *Computer Physics Communications*
addresses the nonlocal scalar case (§5.1). The Aichinger 2005 paper is
not on arXiv; our derivation proceeds from first principles using
Chin-Krotscheck 2005 + Chin-Janecek-Krotscheck 2008 (arXiv:0809.3739)
as load-bearing sources.

The spinor matrix derivative term (§5.2 term ii) is genuinely new — it
is not present in any of Chin's published scalar GPE work, and it is
the structural obstacle that distinguishes "diagonal-only" Force-Gradient
(v1-v3) from "full spinor" Force-Gradient (v4+).

## §3.5.3 Implementation hierarchy (diagonal-only subset, v1 → v3)

| version | implementation feature | order autonomous | order nonlinear |
|---------|-----------------------|------------------|------------------|
| v1 (1ee1de8) | 4A00 + central FD ∇V | 3.44 | 0.96 |
| v2 (390f474) | + FFT spectral ∇V + Strang predictors (4AWW partial) | 3.86 | 2.92→3.20 |
| v3 (0b0a822) | + endpoint Picard (state-avg midpoint NEGATIVE) | 3.86 | 2.88→3.60 |
| v3.1 (this commit) | + true midpoint Picard (Strang re-prediction) | 3.86 | 2.95→2.76 |

Observations:

* **v1 4A00**: simplest formulation. Autonomous order ~3.4 (limited by
  finite-diff ∇V truncation, not algorithm). Nonlinear order ~1 because
  all five V stages use ψ(0) MF — paper-confirmed pathology.
* **v2 FFT + Strang predictors**: jumps autonomous to ~order 4 (within
  reference precision floor). Nonlinear order ~3 — Strang half-/full-step
  predictors give O(dt²) accurate midpoint/endpoint MF, yielding
  V step output O(dt³) per step → cumulative O(dt²)-O(dt³) global.
* **v3 endpoint Picard**: converges by p=2. Nonlinear order improves
  from 2.92→3.20 (v2.2 p=1) to 2.88→3.60 (v3 p=2 finest dt). State-avg
  midpoint update tried — REPRODUCED the §3.3.2 cos(Hτ/2) AVF failure
  mode inside the FG framework: order collapsed to 2.00. Confirmed
  state-averaging is incompatible with high-order schemes regardless
  of context.
* **v3.1 midpoint Picard via Strang re-prediction**: does NOT improve
  order — Strang predictor is structurally O(dt²) accurate as a
  midpoint estimate regardless of MF iteration. To push to order 4
  would require a higher-order midpoint estimator (e.g., Y4-mid as
  inner predictor — circular and expensive).

**Verdict**: Force-Gradient on lab path plateaus at order ~3 in nonlinear
regime with practical Picard iterations. Y4-midpoint (Track A1) reaches
clean order 4 at comparable cost. **Y4-mid wins cost-per-accuracy**.

## §3.5.4 Long-time energy drift (Phase 5)

`scripts/bench/forcegrad_phase5.jl` (1D Rb87 F=1, c₀=5, c₁=0, T=20 ω⁻¹,
dt=0.005):

| scheme | ΔE/\|E₀\| at t=20 | wall (s) |
|--------|-----------------|----------|
| Strang | −2.66e-6 | 0.3 |
| **Y4-midpoint** | **−2.78e-10** | 0.4 |
| ForceGrad p=1 | −1.93e-7 | 0.3 |
| ForceGrad p=2 | +1.15e-7 | 0.1 |

Y4-mid achieves machine-precision energy drift (~3e-10 over 4000 steps).
Force-Gradient with Picard p=2 lands at ~1e-7 — about 400× worse than
Y4-mid. The integration accuracy advantage (order 4 vs order 3) directly
manifests as smaller long-time energy drift.

**Conclusion**: Force-Gradient does NOT provide a measurable
energy-conservation advantage over Y4-midpoint in our framework. The
diagonal-only restriction (c₁ = 0, no DDI) keeps the test problem
"easy" — both methods do well.

## §3.5.5 Spinor matrix V (v4): derivation only, implementation deferred

Per §5.2 of `docs/design/integrator_track_c_derivation.md`, the explicit F=1
symbolic form is:

```
[V_SM, [T, V_SM]] = c₁² · [
    −(i/2) F_ρ (m × ∇²m)_ρ                          (mult, term i)
    − i F_ρ (m × ∇m)_ρ · ∇                          (DERIVATIVE, term ii)
    − (1/2) {F_μ, F_ν} (∇m_μ)·(∇m_ν)                (mult, term iii)
]
```

The derivative term (ii) means the modified middle V is no longer a
pure multiplication operator — it has structure `V_mult + V_deriv·∇`.
This requires either:

(a) Splitting Ṽ into mult and deriv parts and applying each via
    separate substep (mult via per-voxel D×D matrix exp; deriv via
    FFT-based phase multiplication).
(b) Reformulating the modified V step to absorb the derivative into a
    modified kinetic-like operator (= a new factorization recipe, not
    pure 4A).

Implementation of (a) is the v4 effort, estimated 1-2 weeks Phase 0
work. The cost increase over v3 is ~3-5 FFTs per outer step
(for ∇m, ∇²m) + 1 matrix exp per voxel (D=3 for F=1, D=13 for F=6).

Given the Phase 5 result (Y4-mid wins long-time energy drift), the
production ROI of v4 implementation is questionable. **For thesis Ch.3
§3.5, the v4 derivation is a contribution** — it identifies the
structural obstacle that distinguishes scalar GPE Force-Gradient from
the spinor case, which is not present in any published Chin-related
work that we could find.

## §3.5.6 DDI proper (v5): derivation only

Per §5.3 of `docs/design/integrator_track_c_derivation.md`, the matrix +
nonlocal case combines the above structures:

```
[V_DD, [T, V_DD]]ψ_α = ([M, ∇²M] · (-½) + ∇M · ∇M − M·∇²M·(½))_αβ ψ_β
                    + (−[M, ∇M])_αβ · ∇ψ_β
```

where M(r) is the matrix-valued local-acting form of V_DD after FFT
convolution. Implementation requires both (a) FFT for ∇M and ∇²M, and
(b) per-voxel D×D matrix operations.

For F=6 (D=13) with full DDI, the cost is substantially higher than
the F=1 case. Combined with the §3.5.5 verdict that Y4-mid is already
sufficient, v5 implementation is not pursued in this thesis.

The Aichinger-Chin-Krotscheck 2005 paper handles the nonlocal scalar
version (= our §5.1) for Kohn-Sham DFT applications. Our F-matrix
extension (§5.2-5.3) is novel and could form a publishable extension
in its own right — but for our thesis purpose, it is a documented
derivation that the framework remains tractable.

## §3.5.7 Track C closure

Track C delivers:

1. ✓ A working diagonal-only Force-Gradient implementation
   (`split_step_forcegrad!`, commit 1ee1de8 → 390f474 → 0b0a822 → this)
   achieving order ~4 autonomous and order ~3 nonlinear on the lab path
2. ✓ Phase -1 derivation of the spinor matrix extension (v4) and DDI
   proper extension (v5)
3. ✓ Phase 5 long-time energy drift comparison showing Y4-midpoint
   (Track A1) wins on the test problem
4. ✗ Full F=6 + DDI implementation — deferred; production deployment
   uses Y4-midpoint baseline

**For thesis Ch.3**: Force-Gradient is presented as a complete
demonstration of the Chin-Krotscheck 2005 framework on the lab path.
The implementation is honest (order 3 nonlinear), the derivation is
complete to the spinor + DDI level, and the comparison to Y4-mid is
clean (composition-based wins over forward-positive-coefficient
approach for our problem class). The §5.2 spinor matrix derivative
term is a genuine contribution to the literature.

Track B (Thalhammer 2026 modified splitting) is now the next thrust
per `docs/design/integrator_ch3_plan.md` schedule.
