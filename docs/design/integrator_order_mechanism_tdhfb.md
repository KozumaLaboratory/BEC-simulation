# Analytical accounting of frozen-MF Yoshida composition order degradation

> **FROZEN 2026-05-13.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Status**: draft skeleton, 2026-05-13. Empirical anchor from B-1 + B-2
diagnostic suite (commit `dbc6522`). Target chapter: D 論 Ch.4 (Magnus
expansion) — methods-paper candidate.

## §1 Phenomenon

Frozen-mean-field Yoshida composition on the SpinorBEC lab path delivers
*non-integer* observed global order, distinct from the nominal order of
the composition coefficients. Handover §4 measurements (F=6 spinor+DDI):

| scheme | nominal | observed |
|---|---|---|
| Strang (plain) | 2 | 2.00 |
| Y4 (Yoshida 1990 sol. A) | 4 | 3.41 |
| Y6 (Yoshida 1990) | 6 | 1.00 |
| CFET4 (Alvermann-Fehske 2011) | 4 | 1.94 |
| Y4-midpoint (Picard substep) | 4 | **4.00** |

The B-2 TDHFB diagnostic (F=1 16³, anti-polar, harmonic trap, T=0.2)
reproduces the **direction** of the lab-path observation at a tractable
scale, but with a sharper signal: plain Strang at vacuum and pre-evolved
states gives observed global slope ≈ 1, NOT 2. This is the focus of
the present analysis.

## §2 Empirical observations (B-1 + B-2)

### §2.1 Palindrome residual — single-step time-reversibility

(B-1, `scripts/diagnostic/palindrome_residual_probe.jl`)

‖S(-dt) ∘ S(dt) − I‖_∞ vs dt log-log slope:

| Reference state | plain Strang | Strang + picard_midpoint |
|---|---|---|
| (1) vacuum (ρ=0, κ=0) | 4.00 | flat at machine eps |
| (2) pre-evolved | 2.15 | flat at machine eps |
| (3) random Hermitian (ρ, κ) | 2.00 | flat at machine eps |

The slope-4 at vacuum is the **anomalous-source-vanishing special case**:
the leading O(dt²) palindrome-residual BCH commutator coefficient is
linear in the Nambu anomalous source (ρ, κ), and so vanishes structurally
at ρ=κ=0. This is a clean falsifier for any BCH derivation: the correct
form must reproduce the coefficient → 0 at vacuum.

### §2.2 Global error — convergence order at fixed T

(B-2, `scripts/diagnostic/order_ladder_full_matrix.jl`)

Full 4 × 3 × 3 matrix (scheme × regime × component) at T=0.2:

**ρ slope** (most diagnostic, no component anomaly):

| scheme | vacuum | pre-evolved | random Hermitian |
|---|---|---|---|
| Strang plain | 0.994 | 0.994 | 0.983 |
| Strang picard | 2.000 | 2.000 | 2.031 |
| Y4 plain | 1.064 | 1.047 | 1.017 |
| Y4 picard (A4) | 3.996 | 3.992 | 4.014 |

**Key findings**:
1. Plain TDHFB Strang is **globally order 1**, not the nominal 2. This
   holds across all three reference states and (for ρ, κ) all three
   components. The docstring "Strang nominal order 2" is misleading on
   TDHFB.
2. Strang + `picard_midpoint=true` delivers a **clean order 2** across
   ALL components and regimes (slopes 2.000 to 2.031). The Picard fix
   does not just kill palindrome residual — it lifts the base method's
   global order from 1 to 2.
3. Y4 + `picard_midpoint=true` (A4 acceptance path) delivers **order 4
   universally** (slopes 3.96 to 4.02). Y4-plain inherits the slope-1
   base order, regardless of palindrome status.
4. **Component anomaly at random**: at random Hermitian (ρ, κ ~ 0.05,
   φ ~ 0.1), the φ slope for plain Strang is 1.895 (near nominal 2)
   while ρ, κ slopes stay at 1. The asymmetry-induced φ generator
   perturbation `V·Δκ / V·κ ~ dt · 0.01 / 0.05` is small relative to
   the dominant V·κ term — φ truncation looks near-nominal but R-step
   ρ/κ updates feel asymmetry directly.

## §3 Mechanism: left/right φ-half generator asymmetry

The inner HF triple of the TDHFB Strang substep is:

```
φ-sub(dt/2; (ρ, κ)_a)  →  R-sub(dt)  →  φ-sub(dt/2; (ρ, κ)_b)
```

with (ρ, κ)_a = state-at-substep-entry, (ρ, κ)_b = state-after-R-update.
The two φ-halves use **different generators**, breaking the symmetric
Strang structure expected for an autonomous Hamiltonian.

### §3.1 Local truncation order

For a symmetric (palindromic) Strang factorisation `e^{V/2} e^T e^{V/2}`
applied to an autonomous Hamiltonian H = T + V, BCH gives local
truncation O(dt³), global O(dt²) — the textbook order-2 result.

When the two V steps use different generators V_a, V_b that differ
by O(dt) (because R-sub between them advances (ρ, κ) by O(dt)):

  ΔV ≡ V_b − V_a ~ dt · ∂(ρ,κ)V · (ρ̇, κ̇)

the symmetric Strang factorisation becomes `e^{V_a · dt/2} e^{T dt} e^{V_b · dt/2}`,
which is *not* symmetric under dt → -dt. The local truncation error
acquires an extra O(dt² · ΔV) = O(dt³ · ...) contribution. Naively this
preserves order 2 globally — but the per-step *coefficient* is
multiplied by `∂(ρ,κ)V` which can be O(1).

This bound is too loose. The empirical slope is 1, not 2, so we need a
tighter analysis showing the local truncation degrades to O(dt²)
(global O(dt)).

### §3.2 BCH structure of the asymmetric inner triple

The φ subupdate at each inner half-step is
`(φ, conj(φ)) ← top( M_φ · (φ, conj(φ)) )` where `M_φ = exp(−i W^φ · dt/2)`
and W^φ is the 2D × 2D Nambu BdG generator

```
        ⎛  U^φ      Δ^φ   ⎞       U^φ_{c,c'} = Σ V_{c,c';c2,c2'} (conj(φ)φ + ρ)_{c2,c2'}
W^φ  =  ⎜                  ⎟ ,    Δ^φ_{c,c'} = Σ V_{c,c';c2,c2'}  κ_{c2,c2'}
        ⎝ −conj(Δ^φ)  −conj(U^φ) ⎠
```

Between the left and right φ-half-steps, R-sub advances (ρ, κ) by O(dt):

  Δρ = O(dt) · ρ̇ ,  Δκ = O(dt) · κ̇

with `ρ̇ = i [W^R, ρ-block]`, `κ̇ = i [W^R, κ-block]`. The induced
generator shift between right and left is

  δW^φ ≡ W^φ_R − W^φ_L = V · (Δρ + Δκ)  ∝  dt   (B-3 confirms slope ≈ 1)

The leading correction in BCH(M_R, M_L) is `−i(dt/4) (W^φ_R + W^φ_L)` plus
commutators; the asymmetry contribution is `−i(dt/4) · δW^φ`. Decomposed
into Nambu blocks:

```
        ⎛ δU^φ       δΔ^φ   ⎞
δW^φ =  ⎜                    ⎟
        ⎝ −conj(δΔ^φ) −conj(δU^φ) ⎠
```

The φ-component contamination after applying δW^φ to the (φ, conj(φ))
doublet is

  δφ_contam = δU^φ · φ  +  δΔ^φ · conj(φ)             ← key expression

The two terms have **structurally different propagation**:

- `δU^φ · φ` — normal-channel contamination, a phase shift on φ. With
  no Nambu mixing in the baseline rotation `M_φ`, this maps directly
  into the φ amplitude.
- `δΔ^φ · conj(φ)` — anomalous-channel leak from conj(φ) into φ via the
  off-diagonal Δ block. Whether this leak compounds at O(dt) or partially
  cancels at O(dt²) depends on the baseline Δ^φ rotation activity:
  - If `Δ^φ_baseline ≈ 0` (vacuum / Popov-like states), `M_φ` is
    block-diagonal (no Bogoliubov mixing) → the leak adds linearly to
    φ at each substep → global slope 1.
  - If `Δ^φ_baseline` is non-negligible relative to U^φ, the baseline
    `M_φ` already mixes (φ, conj(φ)) via a Bogoliubov rotation with
    frequency `Ω_Bog = √(|U^φ|² − |Δ^φ|²)`. The perturbation δΔ^φ is
    averaged over this rotation, suppressing the leak by one factor
    of dt → global slope partially lifted toward 2.

### §3.3 Two error mechanisms

Combining §3.1 + §3.2, the global φ error decomposes as

  E_φ(τ) ≈ A_φ · τ² + B_φ · τ + O(τ³)

with two distinct contributions:

- **Mech-A** (asymmetry-driven, sets B_φ): per-step `δφ_contam` from
  the inner triple. B_φ magnitude depends on whether `M_φ` baseline is
  Bogoliubov-active (Δ^φ_baseline ≠ 0) — see B-3 table:
  
  | Regime | ‖U^φ‖ | ‖Δ^φ‖ | Δ^φ/U^φ | φ slope (B-2 / B-3.5) |
  |---|---|---|---|---|
  | B-2 vacuum | 0.02 | 0 | 0% | 1.10 |
  | B-2 pre-evolved | 0.02 | 0.002 | 8.5% | 1.10 |
  | B-3.5 α=0 (rand ρ, κ=0) | 0.34 | 0 | 0% | 1.70 |
  | B-3.5 α=0.1 | 0.34 | 0.023 | 7% | 1.74 |
  | B-3.5 α=0.3 | 0.34 | 0.069 | 20% | 1.80 |
  | B-3.5 α=0.5 | 0.34 | 0.115 | 34% | 1.84 |
  | B-3.5 α=1.0 (full random) | 0.34 | 0.230 | 68% | 1.90 |
  
  Cf. B-3 ‖ΔW^φ‖/‖W^φ_L‖ ratio = ~1% across ALL regimes — relative
  perturbation magnitude does NOT explain the slope difference.
  
  **Both U^φ magnitude and Δ^φ magnitude contribute, continuously
  (NOT threshold)** — see §3.2.5 below.

### §3.2.5 Continuous slope interpolation (B-3.5 finding)

The intermediate-Δ sweep at fixed φ, ρ = random and κ = α × (random κ)
shows φ-slope interpolates linearly with Δ^φ/U^φ:

  slope_φ(Δ^φ/U^φ) ≈ 1.70 + 0.30 · (Δ^φ/U^φ)    (for U^φ ≈ 0.34)

But comparison across U^φ values reveals a second axis:

  Δ slope_φ from U^φ alone (Δ^φ=0):  0.02 → 0.34 lifts slope 1.10 → 1.70
  Δ slope_φ from Δ^φ on top of U^φ:  0% → 68% lifts slope 1.70 → 1.90

The U^φ baseline magnitude is the **larger discriminator**. Combined
phenomenology:

  slope_φ ≈ 1 + f(|U^φ|) + g(Δ^φ / U^φ)

with both f and g continuous and roughly linear in their argument over
the measured range. Mechanism interpretation:

- f(|U^φ|): the baseline `M_φ = exp(-i W^φ · dt/2)` is a fast unitary
  rotation in φ-space (frequency ~ |U^φ|). The asymmetric perturbation
  δW^φ is integrated over this rotation, suppressing the linear-in-dt
  leak by a factor that grows with |U^φ| · τ.
- g(Δ^φ/U^φ): when Δ^φ is active, the unitary rotation involves
  Nambu mixing (Bogoliubov rotation), which provides an additional
  φ ↔ conj(φ) averaging channel.

The original "Nambu mixing as binary toggle" hypothesis is REFUTED.
The corrected picture is that the entire W^φ eigenstructure — both
U^φ magnitude AND Δ^φ magnitude — sets the absorption capability for
asymmetric perturbations. This is more physically natural: any unitary
rotation by W^φ tends to randomise the phase contamination from δW^φ.

### §3.2.6 Phase-accumulation hypothesis — REFUTED

Initial framing: a single dimensionless control parameter
`Ω · T` (Ω ~ ‖W^φ‖_∞, T integration time) would drive `slope_φ ≈ 1 + S(Ω·T)`
with S monotonically increasing. Tested directly by `T_sweep_alpha0.jl`:

| T | Ω · T | slope(φ) | slope(ρ) | slope(κ) |
|---|---|---|---|---|
| 0.05 | 0.017 | (pre-asymptotic) | — | — |
| 0.2 | 0.068 | 1.702 | 0.807 | 1.019 |
| 1.0 | 0.339 | **1.630** | 0.990 | 0.978 |

T=0.05 lies in the pre-asymptotic regime (too few steps for the
asymptotic behaviour to manifest, dt=0.02 gives only 2 Strang steps).
At T = 0.2 and T = 1.0, both well in the asymptotic regime, slope_φ
is essentially T-independent (1.702 vs 1.630 — within the noise of a
4-point log-log fit). Ω·T grows by 5× but slope does NOT track it.

**The phase-accumulation framing is refuted.** The slope is a static
property of the W^φ eigenstructure at the initial state (or whatever
state dominates the early-time integration), NOT an integrated rotation
average. The decreasing trend 1.702 → 1.630 is the opposite of what
phase-accumulation predicts.

This is the THIRD hypothesis refutation across this analysis:
1. "Baseline magnitude suppression by ‖ΔW^φ‖/‖W^φ‖ ratio" — refuted by
   B-3 (ratio uniform at ~1% across regimes, yet slopes vary 1.1 to 1.9).
2. "Nambu mixing binary threshold" — refuted by B-3.5 (continuous
   interpolation, not threshold).
3. "Phase accumulation Ω·T" — refuted by T-sweep (T-independent slope).

The empirical evidence supports a static mechanism:
- B-2 vacuum (‖U^φ‖ = 0.02, Δ^φ = 0): slope 1.10
- B-3.5 α=0 (‖U^φ‖ = 0.34, Δ^φ = 0): slope 1.70
- B-3.5 α=1 (‖U^φ‖ = 0.34, Δ^φ = 0.23): slope 1.90

|U^φ| alone shifts slope by ~0.6; adding Δ^φ shifts it by a further
~0.2. Both contributions are static (initial-state) properties. The
mechanism is not understood at the BCH derivation level yet — the next
diagnostic should be a per-step local-error decomposition (separate
the per-substep truncation order from any cumulative effect) to
isolate whether the slope-suppression mechanism lives in a single
Strang step or across many steps.

- **Mech-B** (palindrome breakdown, sets a Yoshida-composition ceiling):
  even when B_φ = 0 (symmetric V steps, e.g. lab path), the *next-order*
  palindrome residual sources a (3,4)-floor on Yoshida composition.
  B-1 measured slope 2 palindrome residual in populated regimes (3.4
  Y4 measured on lab path) and slope 4 at vacuum (anomalous source
  coeff vanishes structurally — not the production regime).

Mech-A and Mech-B are independent:
- Mech-A degrades the base method itself (B-2: Strang plain slope 1)
- Mech-B degrades only the higher-order composition over a symmetric base

TDHFB suffers from BOTH; the lab/GP path suffers from Mech-B only
(its V step has no Nambu doublet asymmetry).

### §3.4 ρ, κ components — no Nambu absorption

For the (ρ, κ) sub-update, the generator W^R is itself asymmetric
across substeps (the φ update between the two R-halves changes
`V·(φ*φ + ρ)`). There is no analogous "Bogoliubov rotation absorbs
the leak" mechanism for the bilinear sector — the Nambu density
R = [[ρ, κ]; [conj(κ), I + conj(ρ)]] update via M·R·M† is direct, and
asymmetry feeds into all four blocks. As a result:

- **ρ, κ slopes are universally 1** across all regimes (B-2: 0.98 to
  1.06 for ρ and κ at every cell with plain Strang).
- The component-specific mechanism only applies to φ, which is the
  upper half of the Nambu doublet that *can* selectively activate
  Bogoliubov mixing.

## §4 Yoshida composition over a Mech-A-broken base

Yoshida-4 theorem: composition `S(w₁τ) ∘ S(w₀τ) ∘ S(w₁τ)` with
`w₀³ + 2w₁³ = 0` delivers order 4 IFF base S(τ) satisfies:

1. Order 2 globally (per-step error O(τ³))
2. Palindromic: `S(-τ) ∘ S(τ) = I + O(τ⁵)`

Our TDHFB Strang base violates BOTH conditions:
- Mech-A: base order is empirically 1 (B-2), not 2
- Mech-B: palindromic residual is O(τ²), not O(τ⁵)

The combined effect on Y4: nominal order 4 degrades. The TDHFB and
lab-path paths show **different mechanisms** dominating:

| path | base order | base palindrome | Y4 measured | dominant mech |
|---|---|---|---|---|
| Lab (GP, handover §4) | 2 | O(τ²) | 3.41 | Mech-B (partial cancel 4→3.4) |
| TDHFB (B-2) | 1 | O(τ²) | 1.00 | Mech-A (base floor 1) |
| Either + Picard | 2 | machine eps | 4.00 | both fixed |

Mech-A is more destructive than Mech-B: it sets a lower order ceiling
on the base method itself, so Yoshida composition cannot recover. On
the lab path Mech-A is *not* present (the V step is symmetric — c₀|ψ|²
has no Nambu doublet asymmetry), so only Mech-B degrades Y4. On TDHFB
the Nambu doublet anomalous channel introduces Mech-A.

### §4.1 The Picard fix as a structural change

`picard_midpoint=true` replaces the asymmetric inner triple with a
fixed-point iteration that converges (ρ_mid, κ_mid) to a state-symmetric
midpoint value. With converged Picard:

- V_a = V_b = V(ρ_mid, κ_mid)  — symmetric V steps
- Strang factorisation recovers exact palindromicity (B-1: residual flat
  at machine eps across all 3 regimes)
- Base order rises to 2 (B-2: Strang picard = 2.000 across components)
- Y4 composition delivers nominal 4

Picard kills BOTH Mech-A AND Mech-B simultaneously, because both are
symptoms of the same underlying violation (V_a ≠ V_b under frozen MF).

## §4.2 Production guidance (refined)

The "TDHFB plain Strang is globally order 1" framing is overshoot —
the more accurate statement is **regime-dependent slope between 1 and
slightly below 2**, with the effective order set by the W^φ eigenstructure
of the running state. Polar-like / sparsely populated regimes (small
‖U^φ‖, no Δ^φ) get worst-case slope ~1; densely populated / Bogoliubov-
active regimes (Eu151 thermalised, dense spinor states) get up toward
slope 2 but never reach it cleanly.

For production work the universal predictability is gone without
Picard. Use the deterministic-order variants:

- **`tdhfb_strang_step!(..., picard_midpoint=true)`** — universal slope
  2.000 across regimes (B-2: 2.000 / 2.000 / 2.018 in 9 cells), wall
  cost ~5× plain Strang. Default for production accuracy.
- **`tdhfb_y4_midpoint_step!(..., picard_midpoint=true)`** — universal
  slope 4.0 across regimes (B-2: 3.97 / 4.02 / 3.98), wall cost ~15×
  plain Strang. For tight tolerance (state error below ~1e-8).

ρ, κ components show universal slope 1 with plain Strang across ALL
regimes — there is no analogous Bogoliubov absorption for the bilinear
sector. If ρ or κ accuracy matters (e.g., depletion / pair-coherence
observables), Picard is required for any meaningful order. The lab-path
suggestion "Strang is fine for short runs at loose tolerance" does NOT
transfer to TDHFB without verification per regime.

## §5 Open questions

1. **Threshold vs continuous Δ^φ dependence**: §3.2 hypothesis is that
   Nambu mixing activation is a *threshold* (Δ^φ_baseline below some
   fraction of U^φ → slope 1; above → slope partially lifted toward 2).
   B-3 only sampled 3 regimes (Δ/U = 0%, 8.5%, 68%). An intermediate-Δ
   sweep at α ∈ {0, 0.1, 0.3, 0.5, 1.0} (κ-scale on random ρ; script
   `scripts/diagnostic/intermediate_delta_sweep.jl`) tests whether
   φ-slope transitions sharply or interpolates continuously.
2. **Quantitative coefficient for B_φ**: what fraction of the symbolic
   `δΔ^φ · conj(φ)` Nambu leak survives one Bogoliubov rotation period
   `2π / Ω_Bog`? Needed to predict the lift factor from slope 1 to ~2.
3. **Lab-path Y4 = 3.41 — why not 1.00?**: On the lab path, Y4 measures
   3.41, not slope-1 like the TDHFB case. The lab V step has no Nambu
   doublet (c₀|ψ|² is a real scalar on the V step), so Mech-A is
   structurally absent. Only Mech-B degrades Y4 → 3.41. Direct test
   at F=1 16³ lab path (B-5, pending) would confirm.
4. **CFET4 = 1.94 / Y6 = 1.00 catastrophic**: CFET is designed for
   *linear* non-autonomous H(t), not nonlinear MF. Y6's three negative
   substeps amplify any palindrome residual. With Mech-B at slope 2
   (lab path), Y6 might inherit slope ~1 from compounding negative
   substep amplification. Both warrant BCH check in a follow-up.

## §6 Next steps

- **Intermediate-Δ sweep** (B-3.5, this commit): `intermediate_delta_sweep.jl`
  — distinguish threshold from continuous mechanism for φ slope vs
  Δ^φ_baseline. Falsifies the §3.2 threshold hypothesis cleanly.
- **BCH symbolic expansion** (later): SymPy / Reduce automation of the
  commutator structure `δW^φ · M_φ^{baseline}` to derive the B_φ lift
  factor analytically.
- **Lab-path Y4 measurement** (B-5): reproduce handover §4 numbers at
  smaller scale (F=1 16³) on the GP path to confirm Mech-A is TDHFB-
  specific (no Nambu doublet → no slope-1 floor).

## References

- Yoshida, H. (1990). Construction of higher order symplectic
  integrators. *Phys. Lett. A* 150, 262.
- Chin, S. A. (2007). On the failure of higher-order operator
  splittings for nonlinear evolution problems. *arXiv:0710.0396*.
- Alvermann, A. & Fehske, H. (2011). High-order commutator-free
  exponential time-propagation of driven quantum systems.
  *J. Comput. Phys.* 230, 5930.
- Choi, S. & Vaníček, J. (2020). High-order time-reversible nonlinear
  Schrödinger equation. *arXiv:2006.16902*.

Internal:
- `scripts/diagnostic/palindrome_residual_probe.jl` (B-1)
- `scripts/diagnostic/order_ladder_full_matrix.jl` (B-2)
- `scripts/diagnostic/asymmetry_probe.jl` (B-3 substep generator)
- `scripts/diagnostic/intermediate_delta_sweep.jl` (B-3.5 threshold test)
- Memo `integrator_palindrome_state_dependent.md` (state-dep palindromicity)
- Memo `integrator_tdhfb_base_order_is_1.md` (B-2 global order finding)
- Handover document §4 (lab-path Y4/Y6 measurements)
