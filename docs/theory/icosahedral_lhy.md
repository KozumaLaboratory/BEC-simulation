# F=6 icosahedral (I_h) Lee–Huang–Yang correction — closed form

> **FROZEN 2026-05-07.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Stage**: D (parallel-session derivation 2026-05-07; verified numerically in this codebase via `test_icosahedral_lhy.jl`, 113 tests).

## Ground state

The F=6 I_h ground state spinor lives in the m = ±5 / m = 0 doublet of the Hilbert space, with the icosahedral 5-fold rotation acting diagonally on m mod 5 and inversion / parity exchanging ±5:

ζ_{I_h} = (0, √7/5, 0, 0, 0, 0, √11/5, 0, 0, 0, 0, −√7/5, 0) m=+5                     m=0                    m=−5

(component order m = +6, +5, ..., −6, normalised to ⟨ζ|ζ⟩ = 7/25 + 11/25 + 7/25 = 1). The state is `ZETA_F6_IH` in `src/hamiltonian/interactions/icosahedral_lhy.jl`.

`Mz = ⟨F_z⟩ = 0` because the m=±5 contributions cancel, so the I_h state is unmagnetised — distinguishing it from the FM phase even in the presence of weak Zeeman terms.

## BdG block structure (mod 5)

The 26×26 BdG operator on an F=6 condensate decomposes under the I_h symmetry into blocks labelled by the 5-fold rotation eigenvalue. Block 0 — the gauge / phonon channel — is 6-dimensional (m = 0, ±5, both u and v branches) and factors further by parity into one phonon-like 2×2 block, one spin-Goldstone 2×2 block (the F_z generator), and one gapped 2×2 block. The other two spin Goldstones sit in the mod-5 = ±1 blocks: F_+ ζ has support at m = +6, +1, −4 (all ≡ 1 mod 5) and F_− ζ at m = +4, −1, −6 (all ≡ 4 mod 5). Across all blocks the count is 1 phonon + 3 spin Goldstones. The Schur lemma decomposition (parallel-session derivation, Appendix VI.A) gives closed-form dispersions:

* Phonon: ω_phonon(k) = √( ε_k (ε_k + 2 c_0 n) ),   ε_k = ℏ² k² / (2M)
* Spin Goldstone (×3 degenerate): ω_spin(k) = √( ε_k (ε_k + 2 |λ_spin| n) )

The factor 3 counts the three SO(3) generators broken by the I_h state (rotational symmetry breaking pattern: SO(3) → I_h, dim = 3 broken).

## Stiffness coefficients

With g_S the per-channel s-wave coupling constants for total spin S (F=6 supports S ∈ {0, 2, 4, 6, 8, 10, 12} only by Bose statistics):

c_0 = g_0/13 + 121 g_6/323 + 147 g_10/391 + 980 g_12/5681 λ_spin = −g_0/13 − 121 g_6/646 + 91 g_10/782 + 840 g_12/5681

These are derived by projecting the contact interaction onto the I_h state and reading off the coefficients of the |0|² and (broken) spin fluctuations. The implementation is `compute_c0_lambda_F6_Ih` in `IcosahedralLHY` (vector and dict overloads).

**Universal cancellation**: g_2, g_4, g_8 contribute exactly zero. This is the I_h harmonic decomposition: the icosahedron has no symmetric rank-2 / rank-4 / rank-8 invariant aligned with the I_h condensate, so those S-channels drop out at this order.

## LHY closed form

Integrating the BdG zero-point energy yields, exactly:

ε_LHY^{F=6, I_h}(n) = (8 √M³ / (15 π² ℏ³)) · n^(5/2) · ( c_0^(5/2) + 3 |λ_spin|^(5/2) )

This is the **universal structure theorem**: the LHY energy of any spinor phase decomposes additively over its independent BdG blocks, each contributing the standard scalar `(8/15π²)(g·n)^(5/2)` form with its own stiffness. For I_h the count is 1 phonon + 3 spin Goldstones, hence `c_0^(5/2) + 3 |λ_spin|^(5/2)`.

## Scalar-limit consistency

For uniform g_S = g (all channels equal):

c_0 = g · (1/13 + 121/323 + 147/391 + 980/5681) = g λ_spin = g · (−1/13 − 121/646 + 91/782 + 840/5681) = 0

so the closed form reduces to ε = (8/15π²)(g·n)^(5/2), which is the standard scalar Lima–Pelster result. All seven 1/13, 121/323, ..., and the four signed terms summing to zero are tested at machine precision in the test suite.

## Eu-like reference values

For g_S = (1.00, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99):

c_0     = 1.0095268024477877 λ_spin  = −0.004061060086770152

so the spin-Goldstone contribution to LHY is 3 × |λ|^(5/2) ≈ 1.05×10⁻⁶ × 3 ≈ 3.2×10⁻⁶ — five and a half orders of magnitude smaller than the phonon contribution (≈ 1) at this slight detuning from scalar uniformity. LHY is dominated by the phonon stiffness c_0 in the Eu-like regime.

## Implementation references

* Module: `src/hamiltonian/interactions/icosahedral_lhy.jl`
  - `ZETA_F6_IH` — the I_h ground state spinor.
  - `compute_c0_lambda_F6_Ih(g_S)` — vector and Dict overloads.
  - `epsilon_LHY_F6_Ih(n, g_S)` — direct LHY energy density.

* Workflow integration: `compute_spinor_lhy_icosahedral` in `src/hamiltonian/interactions/lhy.jl`. Mirrors the FM/polar wrappers by producing a `SpinorLHYTable` with `mode = :icosahedral`. Wired into `make_workspace.jl` under `spinor_lhy: icosahedral` (F=6 only).

* Tests: `test/test_icosahedral_lhy.jl` — 113 assertions covering ZETA normalisation, scalar limit, g_2/g_4/g_8 cancellation, Eu-like reference, LHY positivity, scalar reduction to Lima–Pelster, and argument validation.

* Numerical phase scan: `compute_F6_phase_diagram()` (in `src/analysis/phases/F6_phase_diagram.jl`) computes the I_h vs FM vs cyclic vs polar boundaries in the (g_10, g_12) plane (`docs/research_notes/F6_phase_boundaries.md`).

## Open extensions (Stage E and beyond)

* DDI dressing of the I_h LHY: needs the analogue of `compute_spinor_lhy_polar_dipolar` for I_h's 3 spin-Goldstone modes. Ratio analysis suggests the dressing is suppressed by λ_spin / c_0 ~ 10⁻³ for Eu-like g_S, so the Lima-Pelster Q_5 factor on the phonon contribution dominates.
* T_d (cyclic) closed form: parallel session has not yet provided the analogous coefficient table for tetrahedral states. The numerical phase scan shows a small T_d region near the scalar limit, so this is genuinely open.
