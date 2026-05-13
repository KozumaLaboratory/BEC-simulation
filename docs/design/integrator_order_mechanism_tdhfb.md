# Analytical accounting of frozen-MF Yoshida composition order degradation

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

### §3.2 Why the asymmetry compounds (TODO — fill derivation)

Claim: when V_a, V_b differ by a Nambu-anomalous component that is
*itself* propagated through R-sub via the bosonic Bogoliubov rotation,
the Strang factorisation loses one factor of dt in its leading error.

Specifically: the φ subupdate `(φ, conj(φ)) ← M_φ · (φ, conj(φ))` is the
upper half of a Nambu rotation. M_φ depends on the off-diagonal Δ term,
which is linear in κ. Pre- and post-R values of κ differ by O(dt) at
the φ generator level. The propagated error in φ then enters the *next*
Strang composition step (under Yoshida w_0 · dt < 0), where the
"backward" sub-step amplifies rather than cancels the asymmetry-driven
truncation. Result: per-step phase error ~ O(dt²) instead of O(dt³).

Quantitative form (to derive):

  err_local(dt) ~ C · dt² · ⟨κ̇⟩ + higher-order terms

where ⟨κ̇⟩ is the rate of anomalous-source generation. At vacuum,
κ̇ ≠ 0 *but* the leading palindrome-residual BCH coefficient vanishes
(B-1 result) — so two error mechanisms coexist:

- Mech-A (slope-1 global): asymmetry × κ̇, present at vacuum AND elsewhere
- Mech-B (slope-2 palindrome): anomalous-source linear, vanishes at vacuum

The vacuum special case (B-1 slope 4 palindrome) is Mech-B vanishing.
The slope-1 global (B-2 at vacuum AND pre-evolved) is Mech-A, which is
state-symmetric.

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

## §5 Open questions

1. **Quantitative coefficient for Mech-A**: what is C in
   `err_local ~ C · dt² · ⟨κ̇⟩`? Needed to predict the regime where the
   slope-1 mechanism matters in practice.
2. **Lab-path Y4 = 3.41 — why not 1.00?**: On the lab path, Y4 measures
   3.41, not slope-1 like the TDHFB case. Hypothesis: the lab path V
   step is more weakly state-dependent (c₀|ψ|² doesn't have a Nambu
   doublet structure), so Mech-A is suppressed there but Mech-B still
   degrades 4 → 3.41.
3. **CFET4 = 1.94**: CFET is designed for *linear* non-autonomous H(t),
   not nonlinear MF. The collapse to ~order 2 (nearly slope 2) suggests
   CFET retains the symmetric-V property but loses higher-order
   commutator cancellation. Worth a separate BCH check.
4. **Y6 = 1.00 catastrophic**: Three negative substeps amplify base
   palindrome residual. With Mech-B at slope 2 (lab path), Y6 might
   inherit slope ~1 from `(τ²)^something_negative`. Needs derivation.

## §6 Next steps

- T-sweep at vacuum (B-3, GPU, `transient_T_sweep_gpu.jl`): falsifies
  any remaining "vacuum-T transient" explanation by showing slope-1 is
  T-independent.
- BCH symbolic expansion (B-4): SymPy / Reduce automation of the
  commutator structure to derive Mech-A coefficient.
- Lab-path Y4 measurement (B-5): reproduce handover §4 numbers at
  smaller scale (F=1 16³) to confirm Mech-A is TDHFB-specific.

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
- Memo `integrator_palindrome_state_dependent.md` (state-dep palindromicity)
- Handover document §4 (lab-path Y4/Y6 measurements)
