# Going beyond Strang order 2

Two parallel tracks to push the split-step integrator order from Strang's 2 to 4. Both are needed because RTP and ITP have different obstacles.

## TL;DR

| Path | Status | Blocker |
|---|---|---|
| **RTP, rotating-basis** | works (Y6 default), MPS-4 viable | none — Y6 production |
| **RTP, lab-path** | order collapses to 1 under MF | inner V step's nested Strang isn't time-symmetric |
| **ITP, all paths** | Strang order 2 only | Sheng-Suzuki barrier (no real-coef 4th-order ITP) |

Recommended next step: **Track A1** (predictor-corrector midpoint evaluation of mean field in lab-path V step) — fixes both the RTP MF collapse and unlocks ITP via the Blanes 2024 complex-coefficient route.

## The shared problem

Strang `S(h) = exp(V h/2) exp(T h) exp(V h/2)` is order 2. To go higher, two routes:

1. **Composition** (Yoshida 1990): `S(w₁ h) S(w₂ h) S(w₃ h)…` with coefficients tuned to cancel low-order error terms. Achieves order 4/6 for **separable autonomous** `H = T(p) + V(q)`.
2. **Multi-product extrapolation** (Chin 2010): linear combination `T₄(h) = -1/3 S(h) + 4/3 S(h/2)²`. Cancels odd-power terms in the Strang local error.

Neither route was derived for self-consistent mean-field `V[ψ] = c₀ |ψ|² + c₁ ⟨F⟩ · F + Φ_DDI[ψ]`. Empirically (see `test/hamiltonian/test_integrator_order_meanfield.jl`):

```
config         Strang  Yoshida4   Yoshida6  CFET4
autonomous     2.00    4.00→3.88  5.08→floor 2.00
DDI active     2.00    3.01→1.19  1.00       1.96
full MF        2.00    3.08→1.21  1.00       1.96  ← collapse
```

Yoshida6 collapses to order 1 under mean field. CFET4 stays at 2.

## Track A — Multi-Product Splitting (Chin 2010, Chin & Geiser 2011)

For Strang `S(h)`:

```
T_4(h) = -1/3 S(h) + 4/3 S(h/2)²
T_6(h) =  1/24 S(h) - 16/15 S(h/2)² + 81/40 S(h/3)³
```

**Properties**: positive coefficients in each `S(h/k)` → imaginary-time-stable. Linear combination of unitaries is **not itself unitary** → norm drift is `O(h⁴)` (bounded, not machine precision). Quadratically growing substep count. Drop-in on any code path that already has Strang.

**Smoke results** (rotating-basis 8³ F=1, T=0.2, 2026-05-11):

| | err@h=0.04 | err@h=0.02 | err@h=0.01 | order |
|---|---|---|---|---|
| Strang | 6.7e-4 | 1.7e-4 | 4.1e-5 | 2.00 |
| Yoshida4 | 1.0e-5 | 6.5e-7 | 4.5e-8 | 4.00 → 3.88 |
| MPS-4 | 1.2e-6 | 7.5e-8 | 8.5e-9 | 3.95 → 3.14 |

MPS-4 is **~9× more accurate than Yoshida4 at the same step count and size** in rotating-basis. Norm drift 4e-10 over T=0.2 (bounded as predicted). Driver: `scripts/bench/mps_smoke.jl`.

### Lab-path failure (the open problem)

Same MPS-4 construction on the lab path collapses to order ≈ 1:

```
                     err@h=4e-3  err@h=2e-3  err@h=1e-3  ord
split_step!          2.09e-5     5.23e-6     1.31e-6     2.00 ✓
MPS-4 (combined)     1.08e-8     5.42e-9     2.79e-9     0.99 ✗
```

**Diagnosis.** MPS-4's coefficients (-1/3, 4/3) cancel only **odd-power** Taylor terms of a symmetric Strang local error. The lab-path V step is a nested Strang `diag · SM · DDI · SM · diag` where each SM and DDI substep evaluates the mean field at substep ENTRY (frozen midpoint). The two SM substeps evaluate Φ at *different* times relative to the middle DDI substep — the inner Strang is no longer exactly symmetric, a τ² even-power term creeps in, MPS-4 doesn't cancel it, order falls.

The rotating-basis V step has different structure (no nested SM/DDI), so its Strang is genuinely symmetric and MPS-4 works.

**Even at order 1, MPS-4's leading constant is ~4000× smaller than Strang.** Crossover with order-2 Strang at h ≈ 6.5e-5; for production dt ∈ [10⁻³, 5×10⁻³] MPS-4 wins by orders of magnitude on cost-per-accuracy. Order-recovery is gated on the V-step asymmetry fix (Track A1).

### Track A1 — predictor-corrector midpoint for lab-path V

Replace `_half_potential_step!`'s nested Strang with:

1. Predictor: from ψ_entry, advance half a substep with frozen ψ_entry mean field → ψ_pred (rough midpoint estimate).
2. Compute `Φ_mid = Φ_DDI[ψ_pred]`, `⟨F⟩_mid = ⟨F⟩[ψ_pred]`.
3. Corrector: re-do the substep using `Φ_mid` / `⟨F⟩_mid` instead of entry-point values.

Cost: ~2× per V step. Order: should restore symmetry → odd-only Taylor expansion → MPS-4 jumps from 1 to 4. Yoshida6 should also recover (currently order 1 under MF, same root cause).

If this works, MPS-4 / Yoshida4 / Yoshida6 / CFET4 / Force-Gradient all become available on the lab path. **Recommended as the next concrete step** (1-2 weeks).

Diagnostic: `scripts/bench/mps4_lab_diagnostic.jl`.

## Track B — Thalhammer 2026 modified splitting (parked)

[arXiv:2601.19838](https://arxiv.org/abs/2601.19838) — modified ABA composition with `+ c_i τ² G` correction (G = iterated commutator `[DF₂, [DF₂, DF₁]]`). 4th-order example: `s=3, a=(0, 1/2, 1/2), b=(1/6, 2/3, 1/6), c=(0, -1/72, 0)`, principal coefficients (a, b) non-negative → ITP-stable. The τ² scaling on c kills the negative-coefficient problem.

What the paper does NOT cover: spinor / matrix-valued `F̂`, DDI / nonlocal interactions, `J ≥ 3` explicit formulas. Adapting to F=6 + DDI needs (1) F₁ extension — trivial, local diagonal in m; (2) F₂ extension — c₁ couples components via F̂, DDI is nonlocal, neither in Thalhammer's pointwise contact form; (3) iterated commutator G derivation **from scratch** for J=13 + spin matrices + DDI cross terms.

Estimated effort: 5-10× the Thalhammer paper's J=2 contact-only derivation. Thesis-Ch.3-contribution territory, not pull-request-sized.

## Track C — Blanes 2024 complex-coefficient ITP (separate problem)

ITP can't use Yoshida 4th-order: real coefficients have `w₀ < 0`, and in imaginary time `exp(+w₀ H τ)` diverges (Sheng-Suzuki barrier). The [Blanes-Casas-Ros 2024 symmetric-conjugate splitting](https://arxiv.org/abs/2407.07016) uses **complex coefficients with positive real parts**:

z_k ∈ ℂ, Re(z_k) > 0 ∀k, Σ z_k = 1

Substeps `exp(-z_k H τ)` decay (Re part), rotate phase (Im part), but ITP renormalises each step so the imaginary-phase accumulation doesn't matter.

**Implementation cost** (for `runs/eu151_phase_diagram_lbfgs/` 121-point scan, the scenario where Strang dt=0.005 binds): coefficient transcription from paper TBD; plumbing `Complex{Float64} dt` through `_outer_potential_*!`, `_ddi_step!`, `apply_kinetic_step_batched!`, `_apply_coriolis_step!` is mostly mechanical since they use `cis(arg)` (complex-friendly); main change is the ITP-specific `exp(-2F·θ)` shift in DDI rotation. Add `integrator: blanes4` YAML opt-in + `_run_itp_loop_blanes4!` driver + `test/test_blanes4_convergence.jl` pinning 4th-order scaling.

Per-step cost: 4× Strang (4 stages); accuracy at fixed dt: ~16× better; allows dt 4× larger at same accuracy → wall-clock save ~4× on the dominant K, V, DDI evaluations.

Status: documentation only. Coefficient table + implementation deferred to a session with paper access.

## Cross-references

**Verification harness in this repo:** `test/hamiltonian/test_integrator_order_meanfield.jl` (empirical order table), `scripts/bench/mps_smoke.jl` (rotating-basis), `scripts/bench/mps4_lab_diagnostic.jl` (lab-path failure).

**Companion guide:** `guides/klaus_regime.md` "Hard constraint" — the separate empirical ε rule for Yoshida6 in the Klaus regime.

**Primary literature:** Yoshida 1990 (composition); Chin 2010, Chin & Geiser 2011 (multi-product splitting); Choi & Vaníček 2020 (NLS instabilities); Blanes-Casas-Ros 2024 (complex-coefficient ITP); Thalhammer 2026 (modified splitting).
