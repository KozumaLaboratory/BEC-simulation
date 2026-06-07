# M1 Ω>0 conditioning floor — diagnosis + fix (2026-06-08)

The Ω>0 Barnett-map cells do not converge (18/30 stuck at ‖∇E‖ ~ 1-4,
the "conditioning floor"). A continuation warm-start smoke (B=1/Ω=0.1
from the converged Ω=0 neighbour) ran > 54 min without early-stopping —
so the floor is **conditioning-limited, not step-limited**: more LBFGS
steps (or TSUBAME) will not fix it.

## Diagnosis — NUMERICAL, not physical (measured, 2026-06-08)

Before committing to a fix, diagnose WHY (measure-before-launch applied
to the fork itself). Two hypotheses: (a) **physical** — at the vortex-
core-formation Ω_c a BdG mode genuinely → 0 (near-degenerate transition,
no optimizer converges cleanly); (b) **numerical** — a large condition
number makes first-order LBFGS crawl, but the minimum is gapped and a
second-order method cuts through.

The BdG spectrum is only meaningful at a stationary ψ, so the gate-2
Lanczos λ_min was run on the CONVERGED cells straddling the convergence
boundary (`M1_CLASS=converged_single`):

| B [nT] | λ_min(Ω=0) | λ_min(Ω=0.6) | B=100 row: λ_min(Ω=0,.1,.2,.4,.6) |
|---|---|---|---|
| 5   | 2.29 | 2.60 | — |
| 10  | 3.65 | 2.58 | — |
| 100 | 3.20 | 3.41 | 3.20, 3.85, 4.10, 3.43, 3.41 |

**λ_min stays GAPPED (~2.3-4.1) everywhere, with no downward trend
toward the boundary** — the B=100 full-Ω range is flat, the B=5/B=10
boundary-straddling cells are gapped. **No mode → 0 ⇒ NUMERICAL**, not a
physical Ω_c degeneracy. (Limit: the unconverged transition cells
themselves cannot be measured directly; a soft mode localised exactly
there is not fully excluded — but every measurable converged neighbour,
including the entire deep-vortex B=100 row, is gapped, so numerical is
the dominant mechanism. Any cell still stuck after the numerical fix is
then a candidate-physical one, to be BdG-characterised once converged.)

## Fix — a second-order HvP method, NOT a soft-mode preconditioner

The diagnosis redirects the arc. There is no low-k soft mode to
precondition (the premise of the earlier "soft-mode preconditioner"
sketch below was wrong — gapped spectrum, not a Goldstone floor). The
numerical fix is a **matrix-free second-order method on the anchored
Hessian**: first-order LBFGS crawls because the condition number
(λ_max ~ k²_Nyquist/2 kinetic, vs λ_min ~ 2.5) is large; the explicit
Hessian-vector product sees the curvature directly.

- **Trust-region Newton-CG** (HvP-driven): inner CG solves H·δ = −g
  matrix-free (each CG step = one HvP = the `test_bdg_fd_hessian` /
  gate-2 operator, anchored to the gated gradient); trust-region radius
  handles indefiniteness (negative curvature = escape direction).
- **Inner-CG preconditioner**: the existing Sobolev (1+α(−∇²))^(−1) IS
  the right inner preconditioner here (k-space diagonal, cheap) — it
  compresses the kinetic eigenvalue spread that makes CG slow. So the
  Sobolev work is reused, not discarded.
- **Continuation warm-start** (`sprint5_M1_continuation_sweep.jl`) is the
  warm-start layer: Newton-CG converges fast from a good initial guess,
  so the Ω-march seeds each cell.

The anchored Hessian pays off a third time (gate-2 saddle-rejection +
the diagnosis + the Newton-CG operator).

## Validation plan

1. Newton-CG drives one Ω>0 cell's ‖∇E‖ → 1e-5 where Sobolev-LBFGS
   plateaus (the GPU test, one cell first).
2. No regression: the Ω=0 / converged cells still converge.
3. Then the full continuation sweep with Newton-CG as the optimiser.

If a cell remains stuck even under Newton-CG with warm-start, THAT cell
is the candidate-physical one — characterise its BdG spectrum (the
"what goes soft at Ω_c" half-2 physics result).

---

## (superseded) soft-mode preconditioner sketch

The premise below — a low-k Goldstone soft mode Sobolev misses — was
REFUTED by the diagnosis above (gapped spectrum). Kept for the record of
the reasoning the measurement corrected.

The right fix is a preconditioner that handles the soft modes the
current one misses.

## Diagnosis

The LBFGS already has a Sobolev preconditioner
(`_sobolev_precondition!`, `lbfgs/helpers.jl`):

    grad ← (1 + α·(−∇²))^(−1) · grad        (α = 0.05; Bao et al. 2025-12)

This damps the **high-k kinetic stiffness** — the Hessian's large
eigenvalues are ~k²/2 (kinetic), and the Sobolev factor (1 + αk²)^(−1)
rescales them. But at **low k** the factor ≈ 1, so it leaves the
low-k modes untouched.

- **Ω = 0 cells are well-conditioned** — the gate-2 Lanczos measured
  λ_min ≈ 2.3-3.7 (no near-zero mode; Eu's DDI gaps the spin
  Goldstones). They converge under Sobolev alone.
- **Ω > 0 cells have a LOW-k soft mode** the Sobolev preconditioner
  cannot see: the Coriolis term −Ω·L̂_z makes the **rotation Goldstone**
  (the L̂_z direction — a vortex/condensate can rotate at low energy
  cost) soft, and the rotating-frame ground state's **spin Goldstones**
  (F̂_α directions) are soft. These are low-k, symmetry-generator
  directions → invisible to (1 + αk²)^(−1) → the conditioning floor.

So the gap is precise: Sobolev preconditions the **spatial/kinetic**
stiffness; the Ω>0 floor is the **symmetry-generator (Noether) soft
directions**.

## Design — a Noether / natural-gradient soft-mode preconditioner

Add, after the Sobolev step, a rescaling of the gradient along the
soft symmetry-generator directions. For generators
G ∈ {L̂_z, F̂_x, F̂_y, F̂_z} (the broken symmetries at the rotating-frame
GS), the soft direction is g_G = G·ψ. Its Hessian curvature

    κ_G = Re⟨g_G, H·g_G⟩ / Re⟨g_G, g_G⟩

is small (that is the soft mode). The natural-gradient step amplifies
the component along g_G by κ_G^(−1) (capped), i.e. preconditions with
the inverse curvature in the symmetry directions instead of leaving
them at ~1 like Sobolev does.

**The anchored FD-Hessian makes this computable and trustworthy.** The
curvature κ_G is one Hessian-vector product per generator
(`H·g_G = (energy_gradient!(ψ+εg_G) − energy_gradient!(ψ−εg_G))/2ε`,
the same HvP `test_bdg_fd_hessian` anchored to the gated gradient). A
handful of generators ⇒ a handful of HvP per LBFGS iteration — cheap,
and the curvature estimates ride on a gated operator (no silent drift
in the preconditioner's metric, the same discipline as the rest of the
arc).

Plug-in point: `lbfgs/driver.jl:137,207` (right after
`_sobolev_precondition!`). A `noether_generators` kwarg (default `()`,
opt-in) lists the active generators; α-style cap on κ_G^(−1).

## Validation plan

1. **Soft-mode confirmation** (cheap, reuses gate-2): run the Lanczos /
   the per-generator Rayleigh quotient κ_G at an Ω>0 cell — confirm a
   small κ_{L_z} (and/or κ_{F_α}) that the Ω=0 cells do not have.
2. **Convergence** (the GPU test): the Noether-preconditioned LBFGS must
   drive an Ω>0 cell's ‖∇E‖ to 1e-5 in a tractable step budget where
   Sobolev-only plateaus. Test on one cell before the full sweep.
3. **No regression**: the Ω=0 cells (already well-conditioned) must
   still converge identically (the soft-mode preconditioner is a no-op
   where κ_G is already O(1)).

Only after (1)-(2) confirm does the full Ω>0 continuation sweep launch
(local GPU overnight or TSUBAME). The continuation script
(`scripts/sprint5_M1_continuation_sweep.jl`) is written but NOT
committed pending this — warm-start alone does not converge (smoke).

## Why this is not tooling gravity

The verdict (the Ω>0 Barnett map) rides on these cells converging to
ground states; a soft-mode preconditioner is the measurement-justified
fix for a demonstrated conditioning floor (54-min non-converging smoke),
not speculative infrastructure. It also reuses, rather than rebuilds,
the anchored FD-Hessian — the arc's operator pays off twice (gate-2
saddle-rejection AND the preconditioner metric).
