# Kibble–Zurek with the SPGPE: what the literature fixes, and what it leaves open

> **FROZEN 2026-08-02.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Written 2026-08-02, after a first attempt whose every structural choice was wrong
and whose reported exponent (`α = 0.93 ± 0.08`) is retracted. This document is
the literature basis for the second attempt, so the choices are traceable to
published practice rather than to what made a run finish.

## 1. The two established protocols

**Chemical-potential ramp, 2D homogeneous.** `μ(t) = μ_i + (μ_f − μ_i)t/τ_Q`,
periodic box with `V(r) = 0`, condensation from vacuum, `τ_Q` from 10 to 1000.
Vortices are counted by circulation quantisation `Γ[C] = ∮v·dℓ = 2πw`; only
`w = ±1` is seen. Measurement is at an equilibration time that itself scales,
`t_eq = (3.779 ± 0.693) τ_Q^(0.541 ± 0.069)` — *not* a fixed hold. Averaged over
1000–2000 realisations, `n_v = (249 ± 45) τ_Q^(−0.534 ± 0.047)`, consistent with
the homogeneous mean-field `τ_Q^(−1/2)`.
[arXiv:2506.21670](https://arxiv.org/html/2506.21670v3) (PRL)

**Temperature quench, toroidal.** McDonald & Bradley, PRA 92, 033616 (2015),
[arXiv:1507.08357](https://arxiv.org/abs/1507.08357). The observable is the
*winding number distribution* around the ring rather than a defect tally, which
removes the counting ambiguity entirely. This is the paper to reproduce, for the
reason in §3.

## 2. Exponents

For defect density `𝒟 ∝ τ_Q^(−α)` the trap geometry enters the exponent, not just
the prefactor (del Campo, Retzker & Plenio; quoted in the review literature):

| geometry | general `(ν, z)` | mean field `(1/2, 2)` | F model `(2/3, 3/2)` |
|---|---|---|---|
| homogeneous | `2ν/(1+νz)` | 1/2 | 2/3 |
| harmonic | `2(1+2ν)/(1+νz)` | 2 | 7/3 |
| toroidal | `(1+3ν)/(1+νz)` | 5/4 | 3/2 |

The static class of the BEC transition is 3D-XY (`ν = 0.6717`); the dynamic class
for a superfluid is model F, where an ε-expansion gives `z = 3/2 + α̃/(2ν)` with
`α̃ = max(α_specific-heat, 0)`, and the measured `α = −0.0127(3)` at the λ point
gives `z = 3/2`.

A KZ measurement only ever sees the combination `ν/(1+νz)`, so `ν` and `z` cannot
be separated by one scan. Quote the combination.

## 3. Why the energy-damping reservoir is the point

The number-damping ("simple growth") SPGPE has a non-conserved order parameter
with no coupling to a conserved density — **model A, `z = 2`**. The
energy-damping reservoir is number-conserving and supplies exactly the coupling
that defines model E/F. McDonald & Bradley measured both:

| | `α = zν/(1+zν)` | `β = ν/2(1+zν)` |
|---|---|---|
| number-damping SPGPE | 0.5119 ± 0.0178 | 0.1236 ± 0.0098 |
| **full SPGPE** | **0.7145 ± 0.0358** | **0.0966 ± 0.0128** |
| mean field | 0.5 | 0.125 |
| F model | 0.5 | 0.1667 |
| 3D XY | 0.5677 | 0.1452 |

Number damping alone reproduces mean field. Adding energy damping moves the
result off mean field *and off every equilibrium class* — a departure from a KZM
theory that assumes equilibrium exponents. That is the scientific content of
having built the full SPGPE, and it is a published number to reproduce before
extending anything.

## 4. What the first attempt got wrong

| | published practice | first attempt |
|---|---|---|
| geometry | homogeneous box or torus — uniform traps avoid the causality-induced corrections of inhomogeneous systems | harmonic trap |
| quench | `μ` ramp, or `T` across `T_c` | `T` ramp at fixed `μ`, **entirely inside the condensed phase** (`T_c = 49`, ramp 30 → 2) |
| `γ` | derived from `(μ, T, ϵ_cut, a_s)` | pinned at 0.002 / 0.02, 2.4–370× the physical value |
| `ϵ_cut` | `≳ 2μ`, cutoff-mode occupation ~1–3 | `μ + T`, which is 17 at `T = 2` against `2μ = 30` — **violated at the cold end** |
| measurement | at `t_eq ∝ τ_Q^0.54` | fixed `t_hold = 1`, 0.06 of a response time |
| ensemble | 1000–2000 | 8 |
| observable | winding number, or counting with Poissonian statistics verified | vortex-line count with no distributional check |

The one thing done right was varying `k_cut` by 20% and checking the exponent
moved by 0.92σ while the absolute count moved 3.7× — which is the robustness test
the literature asks for (stability under 10–15% cutoff variation).

## 5. Diagnostics the literature supplies that were missing

- **Poissonian vortex statistics.** Counts are Poissonian (`Var = mean`) both in
  the KZ regime and in the saturated fast-quench regime
  ([Goo, Lim & Shin, PRL 127, 115701](https://arxiv.org/abs/2105.06601)). A count
  distribution that is not Poissonian is a broken counter, and this is a free
  check on every ensemble.
- **Spatial statistics.** Defect positions follow a homogeneous Poisson point
  process with KZ-set density; Voronoi cell-area statistics are the sharper test
  ([arXiv:2510.12770](https://arxiv.org/html/2510.12770)).
- **Saturation at fast quench is real physics, not a fit artefact.** The mean
  defect number saturates for fast quenches because of early-time coarsening
  while the condensate is still growing, *not* because defects annihilate — the
  Poissonian statistics rule out pair annihilation. Early coarsening also changes
  the scaling itself
  ([Goo et al., PRL 128, 135701](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.128.135701)).
  The saturated points must be identified and excluded, not fitted through.
- **Δt convergence before spatial resolution.** For the SPGPE the time step
  matters more than the k-space quadrature
  ([Rooney, Blakie & Bradley, PRE 89, 013302](https://arxiv.org/abs/1310.0161)).
- **Cutoff robustness at ±10–15%**, since the acceptable `ϵ_cut` window is a
  range and results must depend on it only weakly.

## 6. Where the spinor extension actually sits

- Spin-1 KZ is established: Damski & Zurek PRL 99, 130402 (2007) for the analytic
  exponents, Anquez et al. PRL 116, 155301 (2016) for the experiment,
  Sadler et al. Nature 443, 312 (2006) for the quench that started it.
- **A conservation law modifies the exponent.** Świsłocki, Witkowska, Dziarmaga &
  Matuszewski, PRL 110, 045303 (2013): magnetisation conservation gives *two*
  scaling regimes rather than the naive KZ one. This matters directly for ¹⁵¹Eu,
  where contact interactions conserve magnetisation and the DDI does not — so the
  DDI is not a perturbation on the KZ question, it changes which regime applies.
- Cr (F = 3) has strong DDI-induced spin relaxation, so global spin projection is
  not conserved and the linear Zeeman term must be kept.
- The gap: KZ-supersolid work uses the deterministic `T = 0` eGPE on
  spin-polarised ¹⁶⁴Dy ([arXiv:2411.18395](https://arxiv.org/abs/2411.18395)),
  not a finite-temperature SPGPE, and not a high-spin spinor. A finite-`T` SPGPE
  treatment of defect formation in a high-spin dipolar gas appears to be open
  ground — which is where this project's contribution would be, and only after
  §3 is reproduced.

## 7. Order of work

1. Reproduce McDonald & Bradley: torus, `T` quench across `T_c`, winding-number
   distribution, number-damping vs full SPGPE. Target `α = 0.51` and `0.71`.
2. Only then vary anything: spin, dipole, `F`.

Anything reported before step 1 lands is a code result, not a physics result.
