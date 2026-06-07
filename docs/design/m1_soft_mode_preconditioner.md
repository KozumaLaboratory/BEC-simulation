# M1 soft-mode preconditioner — design (2026-06-08)

The Ω>0 Barnett-map cells do not converge (18/30 stuck at ‖∇E‖ ~ 1-4,
the "conditioning floor"). A continuation warm-start smoke (B=1/Ω=0.1
from the converged Ω=0 neighbour) ran > 54 min without early-stopping —
so the floor is **conditioning-limited, not step-limited**: more LBFGS
steps (or TSUBAME) will not fix it. The right fix is a preconditioner
that handles the soft modes the current one misses.

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
