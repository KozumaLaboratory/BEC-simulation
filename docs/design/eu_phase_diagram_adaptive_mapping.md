# Eu F=6 phase diagram — cost-optimal + research-correct adaptive mapping

Design for computing the ground-state quantum phases of ¹⁵¹Eu (F=6, dipolar
spinor) across a multi-parameter space, **minimising cost while keeping the
result scientifically correct**. Established and partially implemented in the
2026-06-24 session; see memory
`project_eu_weak_field_gs_pinning_and_adaptive_mapping`.

## Core principle: separate the two concerns

> **Optimise the PATH, verify the RESULT independently.** Never trust a ground
> state because it was cheap to obtain.

On a soft degenerate manifold the cheapest path and the true global GS can
diverge — proven this session: an under-converged continuation sat on a spurious
+1 spin vortex at nearly the same energy as the true (vortex-free) GS. So
optimisation (continuation/seeding) and correctness (multi-seed/verification) are
two layers that run together, not one.

## Cost model (the thing being optimised)

`wall ≈ Σ(all ITP+LBFGS+Newton steps) × per-step`. Per-step is launch/CPU-bound
(~1–5 s) and only weakly resolution-dependent (32³ ~1 s, 48³ ~4 s, 128³ ~3 s; the
old "128³ ~12 s/step" was a silent-CPU-fallback artifact). ⇒ **minimise total
step COUNT, and do steps at the cheapest resolution.** GPU FLOPs are not the
bottleneck; step count × launch overhead is.

## Pillar 1 — optimisation (the computation graph)

1. **Low-resolution-first.** Build the whole phase diagram at 32³ (cheap steps,
   and which-phase is resolution-robust), then promote only the final converged
   cells to 64³→128³ by seeding. The expensive search (basin, ε-ramp, multi-seed)
   happens where steps are cheapest.
2. **Single full anchor.** Exactly one (param) point pays the full price (ITP from
   a symmetry-broken seed + ε-ramp + resolution ladder). Every other cell
   warm-starts from a converged neighbour → short polish (no ITP, no ε-ramp). The
   continuation graph is a spanning tree rooted at the anchor; pick the anchor in
   an EASY unique phase (high B / cigar FM), not in the degenerate region.
3. **Continue along every cheap axis** (B, λ, resolution): use the nearest
   available seed — spectral upsample (same box), B/λ continuation (same grid),
   real-space resample (box changes). Tool: `upsample_spinor(psi, M)`
   (`src/workflow/initialization/upsample.jl`; FFT zero-pad, norm-preserving to 6
   digits; preserves phase/winding).
4. **Pinning is required for the soft (axisymmetric, weak-field) cells.** Add a
   small symmetry-breaking ε (transverse b_x or elliptical trap), warm-ramp
   ε→small, extrapolate E_bare(ε)=E0+c·ε². Reaches |∇E|~1e-5 (4 orders below the
   un-pinned 0.05 Goldstone floor). NOTE: λ=ω_z/ω_⊥ keeps axial symmetry, so those
   cells still need the pin; only in-plane ellipticity (ω_x≠ω_y) removes it.
   Exposed as `find_ground_state_lbfgs(; pin, epsilon_ramp=…)` (default off);
   `pin_transverse_field(; Bz, q)` is the built-in conjugate-field pin
   (`src/solvers/ground_state/pinned.jl`).

## Pillar 2 — correctness (verification layer)

| risk | safeguard |
|---|---|
| metastable branch reported as GS | **multi-seed-from-scratch** per cell, take min-E (gate-1) |
| hysteresis / missed transition | **bidirectional** sweep; where up/down branches differ, a boundary lives there |
| |∇E| floor / trap | gate on **ENERGY + symmetry**, NOT |∇E| (it traps at 3.7e-6 wrong, floors at 0.05 right) |
| pin extrapolation error | quadratic-fit residual QC; refine ε where it breaks (= near transitions, susceptibility diverges) |
| finite resolution / box | resolution series (cheap via seeding) + Richardson extrapolation with error bars; box-convergence spot checks |
| "is it a minimum" | λ_min is currently a **−μ gauge artifact** (constant −12.6 even at |∇E|=7e-6) — use **λ-free** signals (energy basin + symmetry + Newton-CG conv + multi-seed) until the gauge projection is fixed |
| code correctness | A-checks (Hψ self-consistency, GP stationarity, GPU=CPU) on seeded states too |
| hidden phases | diverse seed library (`state_zoo` + polyhedral candidates); cannot prove completeness — report the seed set + lowest-E |

## Finding boundaries when there is no map (the chicken-and-egg)

Continuation does **not** find boundaries (and hides them via hysteresis) — it
only fills interiors. Boundaries are **discovered** by independent detection:
multi-seed min-E crossing, order-parameter jump/kink (⟨F⟩, |F⊥|, polyhedral σ_S),
bidirectional hysteresis divergence, and solver-struggle (soft-mode → slow
convergence, ε→0 fit breakdown). Build the map adaptively:
`coarse multi-seed recon → detect where phase changes → bisect / boundary-trace /
active-learn (uncertainty-driven) → fill interiors by continuation`.

## Axes

- **c_dd KNOWN** (=μ₀μ², Eu μ≈6.98 μ_B) ⇒ fixed, not an axis. **Unknown = contact
  spin channels** c1,c2,c4,c6 (7 scattering lengths). c1 is Feshbach-measurable but
  Feshbach needs Gauss-scale B which freezes the µG spinor physics (q∝B²) ⇒ at µG,
  c1 is a fixed background value. Fix c1 at best-estimate (+ uncertainty band).
- **Field at µG = linear p/(c1 n)** only (q≈0; q matters at mG–G).
- Recommended primary 2D = **(B × λ=ω_z/ω_⊥)** (DDI-geometry axis). Optional 3rd
  axis (c_dd/c1 or RTF/ξ) sampled coarsely. Don't densely map >2D.
- **Phases of F=6 are Majorana-star point groups** (polar/cyclic/biaxial/
  icosahedral…), not magnetisation alone. Polyhedral orders need the higher tensor
  channels; a fixed-channel (B,λ) map shows the polar/cyclic/FM competition. Upgrade
  `classify_phase`→`classify_polyhedral` for per-cell Majorana fingerprints.

## "What phases exist in Eu?" — the answer is a figure SET

1. **Phase diagram** (2D control space, regions + boundaries) — WHERE.
2. **Majorana-star catalogue** (each phase = star arrangement + point group) — WHAT.
3. **Order-parameter / σ_S traces** across the diagram — HOW distinguished.
4. **Real-space spin textures** of the structured phases — what they look like.
Headline = phase diagram with Majorana-star insets per region.

## Status (2026-06-24) and tooling

Implemented + validated, all LOCAL (TSUBAME points untouched). The durable
capabilities live in `src/`: the pin ε-continuation + extrapolation
(`find_ground_state_lbfgs(; pin, epsilon_ramp)` + `pin_transverse_field`,
`src/solvers/ground_state/pinned.jl`), spectral seeding (`upsample_spinor`,
`src/workflow/initialization/upsample.jl`), and the gauge/frame-invariant
classifier (`spinor_fingerprint`, `src/analysis/phases/spinor_fingerprint.jl`,
flux-closure oracle `test/analysis/test_spinor_fingerprint.jl`). The one-off
campaign drivers (recon sweeps, figure/texture emitters, viz) are not committed;
reconstruct from these primitives. Results: 1D cyclic→FM @57.5µG (matches known
~60µG); 2D (B×λ) boundary sweeps with λ, |F⊥| maximal in the oblate+weak-field
corner; convergence-quality map = soft-manifold map = where pinning is needed.

Next: refine boundaries (bisection+active-learning); re-converge cyclic cells WITH
pin (provisional labels are under-converged); seed-up confirmed cells 32→64→128;
fix the λ_min −μ gauge projection or commit to λ-free certification.
