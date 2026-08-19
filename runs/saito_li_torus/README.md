# Saito–Li magnetic-vortex torus droplet at ¹⁵¹Eu F=6 — issue #336

Target: Li & Saito, *Quantum droplets with magnetic vortices in spinor dipolar
Bose-Einstein condensates*, [arXiv:2402.18885](https://arxiv.org/abs/2402.18885)
(v1, 29 Feb 2024). Local copy:
`docs/refs/Saito_Li_2024_magnetic_vortex_droplets_arXiv2402.18885.pdf`.

The cell is **Fig. 1(d) third panel / Fig. 2(a) cyan curve**:
(F, N, ε_dd) = (6, 15000, 1.3), B = 0, free space.

## Verdict

**Reproduced, type-C, to within 1.3 % on every published anchor.** The config
that had been sitting here unrun since `9c0e54f0` would not have produced it:
five independent defects, listed below, two of which cancelled in the one
number a reader would have checked.

| Fig. 2(a) anchor | ours (96³) | paper | dev |
|---|---|---|---|
| peak ρ/N | 0.516 μm⁻³ | 0.509 | **+1.3 %** |
| torus radius r_peak | 0.817 μm | 0.815 | **+0.2 %** |
| FWHM inner edge | 0.527 μm | 0.528 | **−0.2 %** |
| FWHM outer edge | 1.106 μm | 1.109 | **−0.3 %** |
| ρ(r=0)/N | 0.007 | 0.011 | hole, both |

Paper values are digitised from Fig. 2(a) by `g3_digitise_fig2a.py`. That
extractor refuses to report until its **positive control** — the F=1 N=15000
curve — reproduces the *independent* Fig. 1(c) panel of the same paper (it gives
2.955 at r = 0.286 μm against 2.97 at 0.29, i.e. 0.5 % and 1.4 %), and until a
colour not present in the figure returns no curve.

Producing commit: `9924e181` (dirty tree; the config and the winding detector in
this branch). Normalisation: the paper's own, ρ/N in μm⁻³ against r in μm, with
`a_ho = 0.78029 μm` from ω_ref = 2π·110 Hz.

### Supporting measurements

* **Per-component winding is v_m = −m for all 13 components** (m = +6 … −6),
  measured per component at r = r_peak, each with the detector's own
  convergence flag. This is Fig. 1(b) — which shows m=+1 winding −2π, m=0 flat,
  m=−1 winding +2π — generalised to F = 6.
* **|f|/ρ = 5.998 against F = 6** at the density peak, with the in-plane
  fraction 1.0000: fully polarised and purely azimuthal. That is the
  assumption Eq. (1) of the paper rests on, so it is checked rather than
  assumed.
* **Flux-closure identity**: E_ddi/E_s = −1.2970 against −ε_dd = −1.3000
  (0.23 %). For a divergence-free fully polarised magnetisation this is exact,
  so it is the sharpest available gate on the DDI prefactor and the ε_dd
  bookkeeping *simultaneously*.
* **J_z = L_z + F_z = 0** to 1e-6, as the paper's B = 0 state requires.
* **Self-bound inside the box**: edge density is 1e-4 of the peak.
* Norm ∫|ψ|²dV = 1.00000000.

### Energy budget

| term | value (per particle) | share of Σ\|E_term\| |
|---|---|---|
| kinetic | +3.749 | 4.0 % |
| contact | +36.951 | 39.2 % |
| DDI | −47.926 | 50.8 % |
| LHY | +5.650 | 6.0 % |
| **total** | **−1.575** | — |

The campaign guard disqualifies runs whose LHY exceeds 15 % **of the total**;
here that ratio is 359 %, because the total is a small residue of large
cancelling terms. Quoted against the gross budget it is 6.0 %. Neither number is
a pass — a droplet is an LHY-stabilised object and is expected to sit here — so
both are stated rather than one being chosen.

The cancellation ratio R = |E_total|/Σ|E_term| = **0.0167**, inside the band
where `find_ground_state`'s advisory fires and the imaginary-time fixed point is
set by dt rather than by the Hamiltonian. This is why `method: lbfgs`.

### Convergence in grid and in box

| cell | dx | E | peak ρ/N | r_peak | edge/peak |
|---|---|---|---|---|---|
| 64³ box 6 | 0.0732 μm | −1.5754124 | 0.513 | 0.812 μm | 1.0e-4 |
| 96³ box 6 | 0.0488 μm | −1.5754124 | 0.516 | 0.817 μm | 9.4e-5 |
| 88³ box 8 | 0.0709 μm | −1.5754118 | 0.513 | 0.825 μm | 2.7e-7 |

Energy is identical to 7 digits across a 1.5× refinement in dx **and** a 1.33×
enlargement of the box at fixed resolution; the radius moves 1.6 % over both.
The 88³ box-8 cell is the box test proper — the box grows while dx does not —
and its edge density is 2.7e-7 of the peak, so the object is self-bound rather
than held by the periodic boundary.

Every cell reaches the L-BFGS energy-comparison floor at |∇E| ≈ 3e-6 and so
reports `converged=false`. That flag means "tol=1e-9 was below what the method
can resolve", not "unconverged"; the driver's own warning says exactly that.

**A convergence scan is not by itself evidence here.** In this regime an ITP
answer is grid-independent to 0.4 % and box-independent to 2 % while being 44 %
wrong, so the scan certifies whatever the solver settled on. The load-bearing
checks are the ones that do not depend on the solver: the flux-closure identity
(0.23 %) and the agreement with the published profile.

### Bistability at B = 0 — the cigar seed falls into the torus

`cells/cigar_n96_box6.yaml` seeds `m_plus_F`: spin uniformly along z, no
winding, the Fig. 3(a) branch. It descends from E = +53.07 through +0.68 and
converges at **E = −1.5754125** — the torus energy, and all four energy terms
agree with the torus cell to 6 digits.

That is not a coincidental degeneracy. At B = 0 with c₁ = 0 the Hamiltonian is
invariant under *simultaneous* space+spin rotation, so the converged droplet may
sit anywhere in an SO(3)-degenerate family, and the **sorted eigenvalues of the
second-moment tensor** are what identify the object (the axis does not):

| cell | sorted ⟨r_a r_b⟩ | symmetry axis | COM |
|---|---|---|---|
| torus 96³ | [0.10383, 0.69018, 0.69018] | (0, 0, 1) | (0, 0, 0) |
| cigar 96³ | [0.10398, 0.69016, 0.69018] | (0.707, −0.707, 0) | (−0.65, −0.66, −0.01) |

Same object, axis rotated into the xy-plane and the centre of mass drifted
(free space is translation-invariant). Profiled about *its own* axis the cigar
cell reproduces the paper as well as the torus cell does: peak 0.515 (+1.2 %),
r_peak 0.828 (+1.6 %), identical FWHM.

**So at B = 0, on this cell, there is no cigar branch** — the uniform seed is
unstable and relaxes into the magnetic vortex. That is consistent with Fig. 3(b),
where the cigar becomes unstable *below* a critical field and the bistability
window is B_z ≃ 0.03–0.17 mG. It is not a reproduction of Fig. 3, which is
published at F = 1, ε_dd = 1.2.

Two measurement traps this cell walked into, both fixed in `g6_measure.jl`
rather than worked around:

* profiling on a fixed z = 0 slice reported the rotated droplet as a centre-peaked
  blob at r = 0.029 μm with ρ(0)/N = 0.482 — a completely wrong state. The
  profile is now taken about the *measured* axis;
* `v_m = −m` is a statement in the basis quantised **along the torus axis**. For
  a tilted cell the components mix and the z-basis windings are not −m. The
  report now says so instead of counting 13 disagreements.

## What was wrong with the config

The file had never been executed. `find runs/saito_li_torus -type f` returned
the config alone, and it had been carried across two schema epochs.

1. **`c_dd: 152` double-counted ε_dd.** ε_dd ≡ a_dd/a_s, and a_dd is fixed by
   the atom (μ = 6.977 μ_B ⇒ a_dd = 59.43 a₀). The paper reaches ε_dd > 1 by
   assuming a *smaller a_s*, so exactly one knob moves. Scaling c_dd as well
   multiplies the ratio a second time by 2.407.
2. **The step-level `interactions:` block silently dropped the mixin's
   `c_total: 583`.** `use:` layering is shallow (`_apply_step_mixins`): a
   step-level block replaces the mixin's wholesale. Resolved, `c_total` read
   back absent, so the run would have used the registry-derived 1406.
3. **(1) and (2) cancelled.** 152·36/(3·1406) = 1.297 ≈ 1.3 — the right ratio,
   reached at 2.4× the paper's absolute interaction scale (a_s = 110 a₀ rather
   than 45.71 a₀). The one number a reader would have checked was right, and
   the system was not the paper's.
4. **The scalar LHY coefficient did not follow either override.** It
   auto-derives from the registry a_s *and* the registry ε_dd = 0.5402,
   giving c_lhy = 972.56 where 2473.56 would have been consistent with the rest
   of that Hamiltonian — 0.39× — while the correct run needs 276.28. LHY is what
   stabilises a droplet, so this is not a peripheral error.
5. **`polar_core_vortex` is the wrong topology.** Its outer region is
   (|+F⟩e^{iφ} + |−F⟩e^{−iφ})/√2, which has ⟨F⟩ = 0 — an unmagnetised
   polar-core vortex, carrying no magnetic vortex, and violating the
   fully-polarised premise of Eq. (1). The paper's state is
   √ρ·e^{−iS_zφ}·ζ^(y): `spin_coherent` with θ=π/2, φ-offset=π/2, charge 1.
6. **`box: [3,3,3]` cut the droplet in half.** `box_size` is the FULL width
   (`grid.jl`: `dx = box_size/n_points`), so 3 a_ho is a half-width of 1.17 μm
   against a cloud that reaches 1.4 μm.
7. **ITP at dt = 5e-3 is the known droplet-regime trap** — see the R = 0.0167
   above.

The trap that made this hard to see: item 3. A config can be wrong in two
places and right in the ratio those two places determine.

## Two defects fixed in `src/` rather than here

* `_resolve_derived_params!` printed the run banner's `c_total` and `ε_dd`
  recomputed from the registry, unconditionally — so a run that *correctly*
  honoured `c_total: 584.37` announced `c_total=1406.2 ε_dd=0.5402`. The
  banner is what a reader checks a config against. It now reports the honoured
  value and the effective ε_dd, naming the registry value alongside.
* `component_phase_winding` (new, `src/analysis/topology.jl`). Neither existing
  detector can read a spin-F magnetic vortex: `winding_number_field` resolves
  at most ±1 per plaquette, and `non_abelian_holonomy` returns `cis(phase_acc)`,
  which is ≈1 for *every* integer winding. The new one refuses rather than
  guessing when under-sampled — required, because an under-sampled loop returns
  `ℓ − n·round(ℓ/n)`, a clean and plausible wrong integer.
  Gated by `test/analysis/test_component_phase_winding.jl` (fast tier).

## Reproducing

Run-output directories are not tracked in this repo (no content-addressed run
dir is), so the `runs/torus_n96_box6_<hash>/` names quoted above do not resolve
from a fresh checkout. What IS tracked is `cells/`, and `run_yaml` keys the
output directory on the raw bytes of the config — so the same file reproduces
the same directory name:

```bash
julia --project=. runs/saito_li_torus/g5_make_cells.jl        # regenerate cells from config.yaml
julia --project=. -e 'import CUDA; using SpinorBEC; run_yaml("runs/saito_li_torus/cells/torus_n96_box6.yaml")'
julia --project=. runs/saito_li_torus/g6_measure.jl runs/torus_n96_box6_3014e1e20ffcd4d9
```

Start with `smoke.yaml` (32³, ~1 min) before anything larger.

## Files

| file | what |
|---|---|
| `config.yaml` | the production cell, 128³ box 6 |
| `smoke.yaml` | 32³, 25 iterations — every code path, ~1 min |
| `cells/` | convergence + bistability cells, generated from `config.yaml` |
| `g1_units_and_premises.jl` | gate 1: every asserted number recomputed |
| `g2_resolved_coefficients.jl` | what the YAML resolves to, before/after |
| `g3_digitise_fig2a.py` | Fig. 2(a) digitiser with its controls |
| `g4_what_the_solver_built.jl` | what `_parse_gs_interactions` actually returns |
| `g5_make_cells.jl` | cell generator (one physics source of truth) |
| `g6_measure.jl` | the type-C measurement above |

## Not done, and why

* **The field-driven transition (Fig. 3) and the Einstein-de Haas rotation
  (Fig. 4) are published at F = 1, ε_dd = 1.2 — not at this cell.** Running them
  here is an extrapolation beyond the paper, not a reproduction of it, and must
  be labelled that way. The B = 0 half of the bistability question IS answered
  above; anything on the field axis should follow the #335 discipline of naming
  both states by energy at each field, and should expect the ±10 nT class of
  systematic to matter at 0.03–0.17 mG.
* **The 128³ cell did not run.** It was launched, thrashed a GPU that a
  concurrent session had half-allocated, and was killed in favour of the
  bistability and box cells. 64³/96³/88³-box-8 already agree to 7 digits in
  energy, so it would have been a fourth point on a flat line rather than new
  information — but it is absent, not passed.
* The paper's own numerics use dx ≈ 0.01 μm; this cell is 0.049 μm at 96³. The
  F = 6 object is ~3× larger than the F = 1 one the paper's step was chosen for,
  and the 64³→96³ agreement above is the evidence that it is resolved.
