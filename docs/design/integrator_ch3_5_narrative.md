# §3.5 Force-gradient extension to spinor + DDI — narrative draft

> **FROZEN 2026-05-23.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

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

## §3.5.8 v4 Step 1 prototype: discrete Hermiticity and the FG-on-Strang structural limit

A subsequent prototype implementation campaign (post-design, 2026-05-12)
revealed two structural lessons that were not visible in the §3.5.5
derivation alone. We summarize them here because both are publishable
findings; the bench code lives in `scripts/bench/track_c_v4_step1{a,b,c,d}_*.jl`.

**Step 1a (multiplicative kernel verification)** — implementing terms
(i) `−(i/2) F_ρ (m × ∇²m)_ρ` and (iii) `−(1/2){F_μ,F_ν}(∇m_μ)·(∇m_ν)`
of §5.2 directly as a per-voxel matrix function `W(r)` passes all six
limit tests: `c₁ = 0`, constant `m̄`, polar `⟨F⟩ = 0`, non-trivial
spin-wave, anti-Hermitian/Hermitian symmetry split (term i alone is
anti-Hermitian; term iii alone is Hermitian, as the derivation
predicts), and `c₁²` scaling.

**Step 1b → 1c (discrete Hermiticity failure → pivot to direct commutator)** —
Naive implementation of the full `(i)+(ii)+(iii)` decomposition, with
term (ii) `−i F_ρ (m × ∇m)_ρ · ∇` applied as a separate FFT-derivative
substep, FAILS a discrete Hermiticity test `⟨φ, Aψ⟩ = ⟨Aφ, ψ⟩` at
relative deviation `0.65` on a `16³` grid.

The discrete-level palindromic gate test in
`scripts/bench/track_c_v4_step1b_palindrome.jl` (Strang split
`σ(dt) = mult(dt/2) · deriv(dt) · mult(dt/2)` where mult applies
exp(-i α W_mult) and deriv applies the linearised `(I − iα A) ψ`)
confirms the predicted failure mode: palindromic residual
`‖σ(dt)·σ(-dt) ψ − ψ‖ / ‖ψ‖` scales as `O(dt²)` instead of the `O(dt⁵)`
that a properly palindromic Strang split would give (Hermitian pieces).
Numerically (`c₁ = 50`, spin-wave state, `N = 16³`):

| dt    | residual | order |
|-------|----------|-------|
| 0.04  | 6.4e-6   | —     |
| 0.02  | 1.6e-6   | 2.00  |
| 0.01  | 4.0e-7   | 2.00  |
| 0.005 | 1.0e-7   | 2.00  |
| 0.0025| 2.5e-8   | 2.00  |

The order-2 palindromic residual confirms that `exp(-i α W_mult)` is
non-unitary at the discrete level (term (i)'s anti-Hermitian part does
not cancel within the multiplicative substep alone), so Strang's
sandwich symmetry recovers only the leading even order, not the full
`O(dt⁵)` of a Hermitian-piece Strang. The continuum cancellation
between the anti-Hermitian half of term (ii) and term (i) relies on the
identity `∂_α(Q_{ρα}) = (m × ∇²m)_ρ` where `Q_{ρα} = (m × ∂_α m)_ρ`.
At the discrete FFT level this identity FAILS because the pointwise
product `m_μ · ∂_α m_ν` has Fourier modes beyond `±k_Nyq`, so re-FFTing
to compute `∂_α Q_{ρα}` produces an aliased result that differs from
the analytic `(m × ∇²m)_ρ` by Nyquist-folded high-`k` content. We
verified numerically: the variational-prediction ratio `T_2 / (-i⟨F·M⟩)`
came out `1.000` (term (i) implementation correct), but
`T_1 / (+i⟨F·M⟩) = -1.508 + 0.938i` (term (ii) integration-by-parts
shadow does NOT match the continuum prediction).

**Resolution**: implement `[V_SM, [T, V_SM]]ψ` directly as
`2·V_SM(T(V_SM ψ)) − V_SM(V_SM(T ψ)) − T(V_SM(V_SM ψ))`. Since `V_SM`
(diagonal in `r`, Hermitian matrix in spin) and `T = −½∇²` (Hermitian
via the anti-Hermitian spectral derivative) are individually
discrete-Hermitian operators, their commutator is automatically
discrete-Hermitian. We verified `⟨φ, Aψ⟩ = ⟨Aφ, ψ⟩` at relative
deviation `4.4e-15` (machine precision) on random test wavefunctions.
The cost is 3 `V_SM` applications + 2 `T` applications per FG substep
(= 4 FFT pairs), modestly more than the decomposed form (~3–5 FFTs) but
with guaranteed unitarity of the implied propagator `exp(-i·dt²·c·[V,[T,V]])`.

The lesson generalizes to any FFT-spectral implementation of a double
commutator involving non-diagonal `V`: the analytical Leibniz/IBP
identities used to decompose `[V,[T,V]]` into separate multiplicative
and derivative substeps are continuum-only. Implementations should
either (a) use the direct discrete commutator form, accepting the
extra FFT cost, or (b) apply 2/3-rule anti-aliasing on the product
modes before spectral differentiation.

**Step 1d (FG-on-Strang gives only order 2 for non-harmonic V)** — even
with the direct discrete commutator kernel verified Hermitian, applying
the standard FG correction `V_eff = V + (dt²/24)[V,[T,V]]` to a Strang
base produces order **2.00** on a `c₁ = 50` spin-mixing test problem
(no trap, no `c₀`), identical to plain Strang. The reason is that the
Strang BCH expansion contains TWO leading commutators:

```
err_per_step = +(dt³/24)[V,[V,T]] − (dt³/12)[T,[V,T]] + O(dt⁵)
             = −(dt³/24)[V,[T,V]] + (dt³/12)[T,[T,V]] + O(dt⁵)
```

The FG correction modifies `V` by an additive term proportional to
`[V,[T,V]]`, which cancels the FIRST commutator but leaves the
`[T,[T,V]]` term untouched. For a harmonic potential `∇²V = const`,
that second commutator vanishes (`[T, V_harm] = ∇V_harm · ∇ + const`,
and `[T, ∇V_harm·∇]` simplifies); for non-harmonic `V`, both
commutators contribute, so FG-on-Strang alone cannot reach order 4.
Order-4 with FG-style force-gradient correction requires a
Forest-Ruth-Chin composition: multiple `K` substeps at optimized
weights, with the FG correction inserted at specific factorization
points, so that BOTH leading-order commutators cancel. This is the
proper "Chin-Krotscheck 4A" structure; the simpler `V_eff(dt/2) K(dt)
V_eff(dt/2)` is in fact only order-2-with-improved-prefactor (= a
better order-2 method, not a true order-4 method) for non-harmonic V.

**Implications for the thesis narrative**: the §3.5.5 statement that
"Force-Gradient achieves order ~3–4 on the lab path" should be
qualified — it does so with the Aichinger-Chin-Krotscheck 4A
composition (multiple `K` weights), NOT with a plain Strang base.
The Track C v1–v3 implementation that achieves order ~3 nonlinear on
1D Rb87 uses the implicit Chin-form V-K-V-K-V triplet, which already
has the correct factorization structure; the standalone "FG kernel
plus Strang" approach we tried in Step 1d does not. This nuance was
implicit in the design phase and is now made explicit through the
prototype.

Implementation of Step 1c–d as production-ready code (= a
`split_step_forcegrad_v4!` with full Forest-Ruth-Chin composition + the
direct discrete commutator kernel + DDI extension §5.3) is logged as
post-修論 work (task #91, Forest-Ruth-Chin composition for the v4
spinor-matrix correction). The Step 1c discrete-Hermiticity finding
extends the literature contribution beyond the §5.2 derivation: it is
a constructive resolution to a discrete-implementation question that
the analytical work alone did not surface.
