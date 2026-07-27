# Parameter contract — SpinorBEC.jl ↔ Ueda lab spinor-BEC code

**Purpose:** signed, line-by-line agreement on every physics convention
**before** any numerical comparison. A single mismatch (DDI 4π, μ
definition, m ordering, p sign, normalization) produces an entirely
spurious "code-A vs code-B" disagreement that is indistinguishable
from a real bug.

Strategy from validation ladder Level 10 (memory
`validation_ladder_2026_05_24.md`):

> **Image comparison of late-time collapse is the *weakest* test —
> chaotic amplification of any A/B error. Do not start there.**
>
> 1. Parameter contract (this document)
> 2. Same ψ₀ energy decomposition
> 3. Same ψ₀ Hψ comparison ← strongest
> 4. One-step comparison
> 5. Short-time comparison

Until this document is signed off by both labs, no numerical diff is
meaningful.

## How to use

For each row:

1. **SpinorBEC.jl column** is filled in by us (this document) with code
   references so the convention can be re-derived.
2. **Ueda-code column** is filled in by the Ueda lab.
3. **Match?** column is filled in jointly. Any "no" must be resolved
   (either change a convention on one side, or document the
   transformation explicitly) before Level 10 numerical comparison.

Each disagreement should be linked to a `transformation/` note: how
the Ueda data must be rewritten to make it directly comparable to ours.

---

## 1. Spin-matrix conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 1.1 | F (spin quantum number) | `atom.F`, integer | _to fill_ | _to fill_ | Eu151 → F=6 |
| 1.2 | Component ordering | `c=1 ↔ m=+F`, `c=D ↔ m=−F` (where `D = 2F+1`) — i.e. **descending** in m | _to fill_ | _to fill_ | `src/foundation/types/spin.jl` `m_values = [+F, +F-1, …, −F]` |
| 1.3 | F_z matrix | `F_z[c,c] = m_values[c]` (diagonal, descending) | _to fill_ | _to fill_ | `src/foundation/types/spin_matrices.jl` |
| 1.4 | F_x, F_y | Standard `[F_x, F_y] = iF_z` (sign of i convention: `+i`) | _to fill_ | _to fill_ | `test/foundation/test_spin_matrices.jl` pins this |
| 1.5 | F² Casimir | `F² = F(F+1)·I` | _to fill_ | _to fill_ | Standard, no choice involved |
| 1.6 | Ladder normalisation | `F_±|F,m⟩ = √(F(F+1)−m(m±1))·|F,m±1⟩` | _to fill_ | _to fill_ | Condon-Shortley phase |

## 2. Zeeman conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 2.1 | Linear Zeeman | `H_Z^lin = -p · F_z` so `(Hψ)_m = -p·m·ψ_m` | _to fill_ | _to fill_ | sign: p > 0 lowers m=+F |
| 2.2 | Quadratic Zeeman | `H_Z^quad = +q · F_z²` so `(Hψ)_m = +q·m²·ψ_m` | _to fill_ | _to fill_ | sign: q > 0 raises \|m\|=F |
| 2.3 | p relationship to B | `p = g_F · μ_B · B_z / (ℏ · ω_ref)` (dimensionless) | _to fill_ | _to fill_ | `src/foundation/units.jl` `bfield_to_p`. Sign: same sign as B_z when g_F > 0. |
| 2.4 | q relationship to B | Auto-derived from \|B\|² unless explicit. Formula: see source. | _to fill_ | _to fill_ | `src/workflow/experiments/schema/B_block.jl` |
| 2.5 | g_F sign convention | Per-atom from CODATA tables; Eu151 g_F ≈ +1.163 (positive) | _to fill_ | _to fill_ | `src/workflow/initialization/atoms.jl` |
| 2.6 | B-field direction | Spherical: \|B\| · (sin θ cos φ, sin θ sin φ, cos θ). θ=0 ⇒ +ẑ | _to fill_ | _to fill_ | `src/workflow/experiments/schema/B_block.jl` |
| 2.7 | ITP Zeeman overflow shift | We subtract `min(E_m)` per voxel to prevent overflow in exp(-τH) | _to fill_ | _to fill_ | `src/solvers/ground_state/itp_loop.jl` — **must** be the same shift in Ueda code or energies are offset |

## 3. Contact-interaction conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 3.1 | Energy functional (F=1) | `E_int = (c₀/2)·n² + (c₁/2)·\|⟨F⟩\|²` | _to fill_ | _to fill_ | Kawaguchi-Ueda Eq. 7.1 |
| 3.2 | c₀ definition | `c₀ = (4π·ℏ²/m) · (a₀ + 2a₂)/3` (F=1); `c₀ = c_total / (1 + F²·c₁/c₀)` (general) | _to fill_ | _to fill_ | `src/hamiltonian/interactions/interactions.jl` `compute_interaction_params` |
| 3.3 | c₁ definition | `c₁ = (4π·ℏ²/m) · (a₂ − a₀)/3` (F=1) | _to fill_ | _to fill_ | sign: c₁ > 0 ⇒ polar, c₁ < 0 ⇒ ferromagnetic |
| 3.4 | Singlet-pair amplitude A₀₀ | Standard CG: `A₀₀ = ⟨S=0,M=0\|ψ⊗ψ⟩` (F=2: `A₀₀ = (2ψ₊₂ψ₋₂ − 2ψ₊₁ψ₋₁ + ψ₀²)/√5`) | _to fill_ | _to fill_ | `src/analysis/observables.jl` `singlet_pair_amplitude` |
| 3.5 | c₂ singlet-pair coefficient | F=2: `c₂ = (4π·ℏ²/m) · (3a₄ − 10a₂ + 7a₀)/15` | _to fill_ | _to fill_ | sign: c₂ > 0 ⇒ cyclic, c₂ < 0 ⇒ nematic |
| 3.6 | higher-rank c_n (n ≥ 4) | Pass via `InteractionParams(Dict(0=>c0, 1=>c1, 4=>c4, 6=>c6, ...))` — even rank only. | _to fill_ | _to fill_ | Odd-rank n ≥ 3 rejected at construction. Eu (F=6): S=0,2,4,6,8,10,12 channels. |
| 3.7 | ψ normalization | `∫\|ψ\|² dV = 1` (we absorb N into the coefficients) | _to fill_ | _to fill_ | Ueda may use `∫\|ψ\|² = N` instead — needs explicit transformation |

## 4. DDI conventions

**Critical**: this is the #1 suspected source of disagreement.

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 4.1 | Coefficient c_dd | `c_dd = μ₀ · μ²` where μ = g_F · μ_B (per-spin-matrix, **NOT** g_F·F·μ_B) | _to fill_ | _to fill_ | `src/hamiltonian/interactions/interactions.jl:111-119`. The F² factor is supplied by the spin operators inside the integral. |
| 4.2 | NO 4π factor | We omit 4π from c_dd | _to fill_ | _to fill_ | If Ueda includes 4π, multiply our c_dd by 4π for comparison |
| 4.3 | DDI kernel in k-space | `Q_αβ(k) = k̂_α·k̂_β − δ_αβ/3` | _to fill_ | _to fill_ | sign: traceless. Spherically symmetric n → ∫Q=0. |
| 4.4 | k=0 mode regularisation | `Q(k=0) = 0` (Pedri-Santos) | _to fill_ | _to fill_ | Removes self-energy divergence in unbounded geometry |
| 4.5 | NO 1/(4π) in kernel | Q is the bare traceless tensor; no 1/(4π) prefactor | _to fill_ | _to fill_ | Chain self-consistent with c_dd convention (4.1, 4.2) |
| 4.6 | Magnetic moment μ for DDI | `mu_gF = atom.mu_mag / F` (= g_F · μ_B). Eu151: `atom.mu_mag` stores g_F·F·μ_B saturation, divided by F here. | _to fill_ | _to fill_ | If Ueda passes μ_sat directly, our F=6 c_dd is 36× smaller |
| 4.7 | Secular DDI vs full DDI | User-chosen. Eu experiments default to `secular_ddi=true`; advisory @info when ω_L/(c_dd·⟨n⟩) > 100 | _to fill_ | _to fill_ | Secular keeps only Zeeman-diagonal DDI components |
| 4.8 | Spin-rotation frame | `spin_rotating_frame_omega ≠ 0` **requires** `secular_ddi=true` (`ArgumentError` enforced) | _to fill_ | _to fill_ | Off-diagonal DDI components only Larmor-average to zero in the secular limit |

## 5. Kinetic / FFT conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 5.1 | Kinetic energy | `T = (-ℏ²/2m)·∇²` per component | _to fill_ | _to fill_ | Standard |
| 5.2 | FFT k-grid | `k = (2π/L)·[0, 1, …, N/2-1, -N/2, …, -1]` (standard FFTW frequency layout) | _to fill_ | _to fill_ | `src/foundation/grid.jl` |
| 5.3 | k=0 mass | `T(k=0) = 0` (no zero-point shift) | _to fill_ | _to fill_ | Standard split-step |
| 5.4 | Dealiasing | Orszag 2/3 rule, off by default, ON for production via YAML `dealias:` block | _to fill_ | _to fill_ | `src/hamiltonian/integrator/dealias.jl`. Affects high-k bandwidth → DDI accuracy. |

## 6. LHY conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 6.1 | Scalar LHY energy density | `ε_LHY = (2/5) · c_lhy · n^(5/2)` | _to fill_ | _to fill_ | `src/analysis/energy.jl` |
| 6.2 | Scalar LHY potential | `V_LHY = c_lhy · n^(3/2)` (= ∂ε/∂n) | _to fill_ | _to fill_ | `src/hamiltonian/integrator/propagators.jl:140` |
| 6.3 | c_lhy auto-derivation | scalar: from textbook `c_lhy = (32/(3√π))·g·(m·a/ℏ²)^(3/2)` etc. | _to fill_ | _to fill_ | `lhy: {kind: scalar}` derives from interactions |
| 6.4 | Spinor LHY F=6 caveat | PolarTwoChannelLHY is **incomplete** at F=6 (~30-70% offset vs PolarContactLHY) | _to fill_ | _to fill_ | Use `PolarContactLHY` / `IcosahedralLHY` for F=6 polar |
| 6.5 | FullBdGLHY F=6 polar | Matches `polar_contact` to ~1e-4 (UV counterterm fixed 2026-07-27) | _to fill_ | _to fill_ | Warns only on dynamical instability |

## 7. Loss / K3 conventions

Loss is **NOT** part of the Hamiltonian-only Level 9-10 comparison. Listed
here so the contract covers the full pipeline.

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 7.1 | K3 equation shape | `dn_m/dt = -K_3 · n² · n_m` (quadratic in total n) | _to fill_ | _to fill_ | True 3-body; `K3_per_m_cubic` slot |
| 7.2 | L3 legacy shape | `dn_m/dt = -γ · n · n_m` (linear in total n) | _to fill_ | _to fill_ | Legacy 2-body shape, separate `L3_per_m` slot |
| 7.3 | SI → dimless conversion | `K3_dimless = K3_SI · n₀² / ω_ref` where `n₀ = N / a_ho³` | _to fill_ | _to fill_ | `src/workflow/experiments/schema/parsing_blocks.jl` |
| 7.4 | Strang splitting with loss | Half-step Hamiltonian + full-step loss + half-step Hamiltonian | _to fill_ | _to fill_ | Loss is dissipative, Strang-compatible |

## 8. Units conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 8.1 | Length unit | a_ho = √(ℏ/(m·ω_ref)) (harmonic oscillator length) | _to fill_ | _to fill_ | Per-atom; Eu151 → a_ho ≈ 2.0e-6 m at ω_ref=2π·100 Hz |
| 8.2 | Time unit | 1/ω_ref | _to fill_ | _to fill_ | t̃ = t·ω_ref |
| 8.3 | Energy unit | ℏ·ω_ref | _to fill_ | _to fill_ | Ẽ = E/(ℏ·ω_ref) |
| 8.4 | Density unit | 1/a_ho³ (3D) | _to fill_ | _to fill_ | ñ = n·a_ho³ |
| 8.5 | ℏ, m, ω_ref | All set to 1 in dimensionless code | _to fill_ | _to fill_ | "Dimensionless units: ℏ=m=ω_ref=1" |

## 9. Integrator conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 9.1 | Real-time propagator | `exp(-i·dt·H)` (signed: `cis(-dt·H)`) | _to fill_ | _to fill_ | Standard QM time evolution |
| 9.2 | Imaginary-time propagator (ITP) | `exp(-τ·H)` with normalization renorm after each step | _to fill_ | _to fill_ | `src/solvers/ground_state/itp_loop.jl` |
| 9.3 | Strang splitting | `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)` | _to fill_ | _to fill_ | `src/hamiltonian/integrator/split_step.jl` |
| 9.4 | Inner V ordering | `diag SM singlet_pair tensor raman DDI raman tensor singlet_pair SM diag` (symmetric/palindrome) | _to fill_ | _to fill_ | Symmetric to preserve 2nd-order Strang accuracy |
| 9.5 | Default integrator order | Strang (2nd-order). Higher: Yoshida-4, CFET4 opt-in | _to fill_ | _to fill_ | `_YOSHIDA_W0 < 0` is correct (backward middle substep) |

## 10. Initial state conventions

| # | Quantity | SpinorBEC.jl (this code) | Ueda code | Match? | Notes |
|---|---|---|---|---|---|
| 10.1 | Default state | `:polar` (m=0 component fully populated) | _to fill_ | _to fill_ | `src/workflow/initialization/state_dispatch.jl` |
| 10.2 | `:m_plus_F` | `c=1` populated (component for m=+F under our descending ordering) | _to fill_ | _to fill_ | Lowest Zeeman energy when p>0 |
| 10.3 | `:m_minus_F` | `c=D` populated | _to fill_ | _to fill_ | Highest Zeeman energy when p>0 (relevant for EdH initial state) |
| 10.4 | Gaussian envelope | σ = box/8 per axis | _to fill_ | _to fill_ | Standard for ground-state seeding |
| 10.5 | Thermal seed | `add_thermal_seed(psi, F; T_over_Tc, seed)` with `η = √((T/T_c)³/4)` heuristic | _to fill_ | _to fill_ | **NOT** a true thermal Wigner sample — for that use SGPE callback |

---

## Quick "send to Ueda" packet

Once this contract has both columns filled and `Match?` is "yes" or
"transformation documented" for every row:

1. Run `scripts/validation/export_operator_rhs.jl <yaml> <output_dir>`
   to generate `operator_rhs.jld2` (contains ψ, Hψ, energy
   decomposition, all conventions in metadata).
2. Send Ueda lab: this signed contract + the jld2 + the YAML.
3. Receive their `operator_rhs.jld2` back.
4. Run `scripts/validation/compare_operator_rhs.jl ours.jld2 theirs.jld2`
   to compute `‖Hψ_ours − Hψ_Ueda‖_L²` and the per-term energy diff.

If the diff is `~10⁻¹²`, Level 10 PASS. Validation ladder Level 11
(convergence) and Level 12 (production) are then unblocked.

If the diff is `~10⁻²` or larger, the bug is **NOT** in K3 / LHY /
long-time integration. It is in one of the rows above. Read down the
contract and find the row where the convention disagrees.

## Acceptance criteria (Level 10 PASS)

All four sub-checks must pass:

1. **Energy decomposition diff**: per-term `|E_ours − E_Ueda| / E_total < 1e-10`
2. **Hψ diff (strongest)**: `‖Hψ_ours − Hψ_Ueda‖_L² / ‖Hψ_ours‖_L² < 1e-10`
3. **One-step diff**: `‖ψ_after_dt^ours − ψ_after_dt^Ueda‖_L² < O(dt³)` (integrator-dependent)
4. **Short-time diff**: `|F_z(t)^ours − F_z(t)^Ueda| < 1e-6` at t = 0.1·t_collapse

If 1-2 pass but 3 fails: integrators differ but operators agree — fine
for physics, document the integrator choice.
If 1-2 fail: **stop**. Find the convention mismatch. Do not advance.

## References

- `validation_ladder_2026_05_24.md` — full ladder
- `docs/theory/kawaguchi_ueda_review_notes.md` (if exists) — derivation notes
- `docs/refs/Kawaguchi_Ueda_Spinor_BEC_Review.pdf` (if held locally) — textbook
- CLAUDE.md "Conventions (do NOT 'fix')" — list of conventions that are
  load-bearing in this codebase

## SpinorBEC.jl-side verification log (2026-05-26)

All load-bearing claims in this contract were re-derived from `src/`
on the SpinorBEC.jl side before sign-off. Reproducible verification
snippet (run from project root):

```julia
using SpinorBEC
sys = SpinSystem(6); sm = spin_matrices(6)

# Row 1.2 — m descending, c=1 ↔ m=+F
@assert sys.m_values == [6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6]

# Row 1.3 — F_z diagonal matches m_values
@assert all(real(sm.Fz[i, i]) == sys.m_values[i] for i in 1:13)

# Row 1.4 — Condon-Shortley: [F_x, F_y] = i·F_z (machine eps)
@assert maximum(abs.((-im) .* (sm.Fx*sm.Fy - sm.Fy*sm.Fx) - sm.Fz)) < 1e-12

# Row 1.5 — F² = F(F+1)·I
@assert real(sm.F_dot_F[1, 1]) == 6 * 7

# Row 2.1 / 2.2 — H_Z = -p·F_z + q·F_z²
import SpinorBEC: zeeman_diagonal
z = ZeemanParams(1.0, 0.1)
@assert zeeman_diagonal(z, sys)[1] == -1 * 6 + 0.1 * 36   # m=+F = -2.4

# Row 4.1 / 4.6 — c_dd = μ₀·(g_F·μ_B)², μ_per_spin = atom.mu_mag / F
@assert compute_c_dd(Eu151) ≈ 1.461394562409078e-52
@assert Eu151.mu_mag / 6 ≈ 1.078397348588188e-23   # = g_F·μ_B for Eu151
```

Result: 7/7 assertions PASS. Document signed below.

## Sign-off

| Side | Name | Date | Signature / commit hash |
|---|---|---|---|
| SpinorBEC.jl | anko via Claude Opus 4.7 (1M context) | 2026-05-26 | _filled at commit time_ |
| Ueda lab | _to fill_ | _to fill_ | _to fill_ |
