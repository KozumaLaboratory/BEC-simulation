# M1 polar/AFM crossover arc — diagnostic record (2026-06-08/09)

> **FROZEN 2026-06-08.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Audit narrative for the `scripts/m1_*` drivers below. Written so the record is
self-explanatory and honest: several early λ-based drivers carry **superseded
interpretations**, flagged here, with the certificate that supersedes them
(`m1_lanczos_niter_convergence.jl`). Read this before reusing any single driver's
numbers.

## Result

The static (Ω=0) Eu B-axis under an **in-plane field Bx** — the production sweep's
"polar (B≤2.6 nT) → antiferromagnetic (B=5) → …" sequence — is **NOT a phase
transition**. It is the smooth canting of the spin toward Bx: a field-induced
magnetization crossover. Settled FOUR independent ways, all agreeing:

1. **rank-1 empirical** — `m1_transverse_mag.jl`: ⟨F_x⟩(Bx) = 0→F=6 smooth, monotone,
   saturating (Newton-CG-polished cells); ⟨F_y⟩=⟨F_z⟩≈0 (canting along the field).
2. **rank-1 analytic** — the conjugate-field principle: Bx (H ⊃ −Bx·F_x) explicitly
   breaks every F_x-odd operation protecting ⟨F_x⟩=0, so ⟨F_x⟩ is an induced response
   and a transition in Bx is symmetry-forbidden (as Ising m(h) is analytic for h>0).
3. **rank-2 empirical** — `m1_nematic_rank2.jl`: cloud-integrated ⟨Q⟩ eigenvalues +
   biaxiality smooth/monotone across 0→100 nT AND the fine boundary 2.6→5 — no hidden
   rank-2 transition under the canting.
4. **1st-order ruled out** — `m1_polar_afm_boundary.jl`: cross-branch fidelity merges
   0.61→0.996 (no distinct coexisting branches; valid on floored states).

Full physics + the symmetry argument: `memory/project_polar_afm_crossover_conjugate_field_2026_06_09.md`.

## The diagnostic method (λ-free suite) — reusable template

The gate-2 Lanczos λ_min MAGNITUDE turned out unreliable (below). Every real signal
in this arc was λ-FREE, and these transfer to the next regime (interaction-channel
nematic / Ω-vortex, where OPs are NOT Bx-conjugate so transitions ARE symmetry-allowed):

- **Newton-CG convergence** = behavioural minimum-certificate (a trust-region method
  escapes negative curvature, so converging quadratically ⇒ positive curvature). The
  reliable SIGN where the Lanczos magnitude fails.
- **state fidelity** |⟨ψ_a|ψ_b⟩|² — 1st-order vs continuous; needs no eigensolve or
  stationarity (valid on floored states).
- **conjugate-field symmetry** — the selector for WHICH order parameter can host a
  transition (an OP conjugate to the applied field cannot — crossover only).
- **order-parameter smoothness** (⟨F_x⟩, ⟨Q⟩) and **energy crossings**.

## Scripts (chronological; superseded interpretations flagged)

| script | established | status |
|---|---|---|
| `m1_b1_multistart_newton.jl` | B=1 Ω=0.1 multistart — weak-field is broadly soft (not a thin boundary) | finding stands |
| `m1_b1_omega_branches.jl` | B=1 Ω-slice branch continuation; method's domain = gapped only | finding stands |
| `m1_polar_afm_boundary.jl` | fidelity-merger ⇒ 1st-order ruled out | fidelity stands; **its gate-2 λ values are SUPERSEDED** (see below) |
| `m1_halfone_reverify.jl` | half-1 cells are minima (via Newton-CG convergence) | SIGN stands; its λ magnitudes superseded |
| `m1_lanczos_niter_convergence.jl` | **PROOF** the gate-2 Lanczos λ_min never converges in niter (B=5: 1.34→0.048 at niter=200, still dropping) | the λ-artifact certificate — read first |
| `m1_transverse_mag.jl` | ⟨F_x⟩(Bx)=0→F smooth ⇒ crossover (rank-1) | stands |
| `m1_nematic_rank2.jl` | global ⟨Q⟩ smooth ⇒ no hidden rank-2 transition | stands |
| `m1_highB_texture.jl` | capstone: high-B = uniform-x-ferro vs texture | see Capstone |

**Superseded λ interpretations:** any gate-2 `trapped_bdg_lowest_eigenvalue` MAGNITUDE
reported during this arc (the "gapped λ≈1.3-1.7", a "B=5 λ dip to 0.72", boundary
softening values) is an under-converged-Lanczos artifact — the 110k-dim trapped
constrained Hessian has a dense low spectrum that random-start Lanczos resolves
glacially. Only the SIGN (minimum, via Newton-CG convergence) survived. A quantitative
λ_min needs a preconditioned / M-metric eigensolver (deferred infra). See
`memory/mistake_stability_verdict_from_nonstationary_point.md` (two convergence axes:
the point AND the eigensolver).

## Capstone — the static B-axis statement

High-B is a **UNIFORM x-FERROMAGNET, not a texture** (`m1_highB_texture.jl`):
|F|/N = 6 = F (maximally stretched) and align = ⟨F_x⟩/⟨|F|⟩ → 0.968 (B=5), 0.988
(B=10), 0.9998 (B=100), with the local spin angle from x shrinking θ_std = 8.2°→5.1°→
0.74° and ⟨L_z⟩≈0. The spin is fully stretched and (at high B) uniformly +x — NOT a
coreless PCV / Mermin-Ho texture (which would have align≪1 and large/growing θ_std).
The mild residual tilt at intermediate B is an edge canting that VANISHES as the field
dominates, not a topological winding.

**The stale "B=10/100 nT = coreless PCV texture (⟨L_z⟩=0)" label is RETIRED** — a
pre-cleanup artifact contradicted by ⟨F_x⟩≈F. **The entire Ω=0 B-axis (0→100 nT) is ONE
field-induced canting crossover: polar (m=0, ⟨F⟩=0) → uniform x-ferromagnet (⟨F_x⟩=F),
smooth in all multipoles, zero transitions.** The static B-axis is now a definitive
single-crossover statement.

## Production status

These are **diagnostic drivers**, separate from production (the Newton-CG solver +
single-source Hessian they ride on are committed: `src/solvers/newton_cg.jl`,
`src/solvers/hessian.jl`). Kept as the arc's audit record + a method template.
