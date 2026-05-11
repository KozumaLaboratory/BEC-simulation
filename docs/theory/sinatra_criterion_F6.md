# Sinatra criterion for TWA validity in F=6 spinor BECs

**Stage**: validation infrastructure shipped 2026-05-07; awaiting GPU
runs to fill in the empirical verdict (`docs/research_notes/twa_sinatra_validation.md`).

## TWA validity condition

The truncated Wigner approximation samples the Wigner vacuum on a
discrete plane-wave basis: each grid mode contributes ½ particle of
fluctuation per spinor component. For the truncation
`δψ ∼ stochastic, ψ̄ ∼ classical` to be a controlled approximation, the
*effective number of populated noise modes* must be small compared to
the atom number (Sinatra & Castin 2002, Castin 2001):

  N_modes_eff × D  ≪  N_atoms

with `D = 2F + 1` the number of spinor components. When this fails,
classical thermalisation of the noise modes can mask physical quantum
fluctuations: the ensemble σ/μ at peak does not represent quantum
noise but the build-up of a thermal-like spectrum populated by
sampling artifacts.

## F=6-specific scaling

The factor `D = 13` for ¹⁵¹Eu makes the criterion tighter by an order
of magnitude vs scalar / spin-1 condensates. On an `n³` grid:

  ratio = n³ × 13 / N_atoms

For the canonical Eu EdH setup (`runs/eu151_edh_postfix_local/`,
32³ grid, N=10⁴ atoms):

  ratio = 32 768 × 13 / 10 000 ≈ 43

This is well into the danger regime — most published TWA work targets
ratio ≤ 1.

## Two remedies

1. **Grid coarsening** (dominant for short healing length).
   16³ → 4096 voxels → ratio ≈ 5.3, marginal but improved 8×.
   When the healing length is much shorter than the box but the
   physics of interest lives at scales comparable to the box, the
   excess high-k modes contribute only spurious noise, and dropping
   them by coarsening costs negligible physical accuracy.

2. **Energy-space mode cutoff**.
   `add_vacuum_noise(...; cutoff_energy=E_cut)` zeros plane-wave noise
   modes with `ε_k = k²/2 > E_cut`. Convention: `k_cut = 2 / ξ`,
   twice the inverse healing length, so modes carrying physical
   structure of the GS are kept and high-k thermal-like populations
   are dropped. For `M = ℏ = 1`, this is `E_cut = 2 g n`.

`src/dynamics/sinatra_helpers.jl` exposes the conversions:

* `healing_length(g, n)` → ξ = 1/√(2 g n)
* `cutoff_energy_from_xi(ξ; factor=2.0)` → `E_cut = (factor/ξ)²/2`
* `cutoff_energy_from_gn(g, n; factor=2.0)` → composition; for the
  Sinatra-recommended factor=2 this evaluates to 2·factor²·g·n.
* `effective_n_modes(grid, cutoff_energy; D)` and
  `sinatra_ratio(grid, D, N_atoms; cutoff_energy)` for diagnostic
  evaluation against any candidate (grid, cutoff) pair.

## Recommended setup for Eu EdH-class runs

Given Eu's short healing length (ξ ≈ 0.92 a_ho at n_peak ≈ 0.118), a
k-cutoff at 2/ξ doesn't actually filter any mode (BZ ⊂ k < 2/ξ).
The effective remedy is **grid coarsening**:

* 16³ × 13 / N_atoms = 5.3 (marginal — the safest practical choice).
* 32³ should only be trusted if the σ/μ at peak is verified to be
  grid-independent against the 16³ result (see validation procedure
  below).
* Higher resolutions (48³, 64³) are increasingly suspect; reserve
  for cases where small-feature spatial structure dominates the
  observable and the trajectory count can be increased to wash out
  classical thermalisation.

## Validation procedure

For each new TWA observable (especially σ/μ at peak), run three
ensembles at increasingly aggressive Sinatra remedies:

1. baseline (current grid + cutoff)
2. coarse  (n³ → (n/2)³, same cutoff)
3. cutoff  ((n/2)³ + tighter `cutoff_energy`)

If the spread of the observable across the three is < 20%, the
result is grid- and cutoff-independent → the leading-order TWA is
controlled and the result is publishable. If the observable shrinks
by ≥ 50% as the Sinatra ratio drops, the baseline is dominated by
spurious classical thermalisation.

`runs/twa_sinatra_validation/` carries the canonical three-config
template; `examples/twa_sinatra_validation.jl` runs and analyses them.

## Effective classical temperature (advanced diagnostic)

A complementary check: long-time Wigner-mode population fitting to
Bose–Einstein. If `T_class ≫ T_initial` after the protocol, classical
thermalisation has set in. Implementation deferred — the σ/μ
spread test above is sharper for the questions our EdH study asks.

## Caveat: σ/μ in chaotic dynamical regimes is not a clean Sinatra
diagnostic

The σ/μ-spread protocol above implicitly assumes σ/μ at peak measures
the Wigner-noise amplitude, with classical thermalisation as the only
non-Wigner contribution. **For the Eu EdH dipolar-collapse regime, this
assumption fails.** The dipolar instability is intrinsically chaotic:
different Wigner-noise seeds drive trajectories to different
orientations of the z-elongated filament, and the trajectory-to-trajectory
spread σ at the densest voxel is dominated by this chaotic divergence
rather than by the Wigner-noise amplitude itself.

Empirical evidence (`docs/research_notes/twa_pinned_16g_result.md`,
2026-05-08): the resolution-matched 16³ × box=10 run at Sinatra-clean
ratio 0.53 (N=10⁵) gives σ/μ = 0.82 — *higher* than the contaminated
32³ × box=20 baseline σ/μ = 0.42. If σ/μ were Sinatra-bound it should
have shrunk; instead it grew, because the chaos amplitude is
physics-bounded and not noise-bounded.

**Practical consequence:** the σ/μ-spread three-config protocol works
for "is the simulator near a unique attractor" diagnostics but not
for "is TWA controlled in chaotic dynamics" questions. For chaotic
regimes use:

* deterministic profile / FWHM / on-axis ratio diagnostics (these
  reflect the GS attractor — robust against Sinatra contamination
  AND against trajectory-divergence chaos)
* TDHFB or Beliaev for controlled beyond-mean-field σ/μ measurements

Chaos-induced σ/μ is itself a meaningful **physics signature**
(chaos-onset diagnostic, peaks at marginal collapse coupling — see
species ε_dd scan), just not a clean quantum-fluctuation observable.

## Resolution-matched Sinatra-clean test design

To vary the Sinatra ratio without changing the GS profile (so the
chaos vs Sinatra-amplitude question can be cleanly disentangled), keep
the grid spacing dx fixed when reducing the grid:

  32³ × box=20 → 16³ × box=10  (both have dx = 0.625 a_ho, same physics)

This was the design used for the corrected 2026-05-08 1/N test. The
naive 16³ × box=20 has dx = 1.25 a_ho, twice the filament-resolving
spacing, and the cloud stays smooth Gaussian without chaos — invalidating
the Sinatra-axis comparison.

## See also

**Companion docs in this repo:**

* `docs/research_notes/twa_eu_edh_synthesis.md` — synthesis of the four empirical scans this criterion was tested against.
* `docs/research_notes/twa_sinatra_validation.md` — original empirical verdict (superseded; see `twa_pinned_16g_result.md` for the corrected reading).
* `docs/theory/icosahedral_lhy.md` — I_h closed form whose TWA validity hinges on this same criterion.

**Primary literature:**

* Sinatra & Castin 2002, *J. Mod. Opt.* 47, 2671.
* Castin 2001, in *Coherent atomic matter waves* (Les Houches Summer School 1999).
