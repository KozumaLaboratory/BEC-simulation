# Symmetric-conjugate ITP splitting (Blanes 2024) — design

**Status**: design only, not yet implemented (2026-05-02). Coefficients
need to be transcribed from the source paper before code goes in.

## Motivation

The current ITP integrator in `_run_itp_loop!` is **Strang 2nd order**.
For Eu151 64³ phase-diagram runs (`runs/eu151_phase_diagram_lbfgs/`,
121 points × ~30 s/point + LBFGS polish) the integration error from
Strang dominates over the LBFGS polish floor when c_dd / contact ratio
is large. A 4th-order ITP splitting would let `dt` grow from ~0.005 to
~0.02 (4× factor) while keeping the same converged-energy precision —
direct ~4× speedup on the dominant cost.

The standard 4th-order splitting (Yoshida 1990, BM 1994) uses real
composition coefficients `(w_0, w_1, w_2)` with `w_0 < 0`. In **real
time** that's fine — every substep is a unitary `exp(±i H τ)`.

In **imaginary time** (`τ → -i τ`) the substeps become `exp(-H τ)` (for
positive `w`) or `exp(+H τ)` (for negative `w`). The latter blows up:
DDI rotation `exp(-2F · θ)` with `θ = phi_mag · w_neg · dt > 0` saturates
to numerical zero, the kinetic step `exp(-k² · w_neg · dt)` saturates to
infinity, and the converged ψ is corrupted. This is the **Sheng-Suzuki
barrier**: no 4th-order real-coefficient splitting can have all positive
weights.

## Blanes-Casas-Ros 2024

[Blanes, Casas, Ros 2024 — "Splitting and composition methods with
symmetric-conjugate complex coefficients"] proposes 4-stage splittings
where the coefficients are **complex with positive real parts**:

    z_k ∈ ℂ,  Re(z_k) > 0  ∀ k,  Σ z_k = 1

The substeps `exp(-z_k · H · τ)` keep `Re(z_k) · τ > 0`, so the real
exponential decays (no overflow), while the imaginary part rotates the
phase — but in ITP we don't care about the global phase (we re-normalize
each step).

Key claim from the paper: 4th-order ITP accuracy with single-pass
evaluation cost equivalent to 3-4× Strang.

## Implementation plan

1. **Transcribe coefficients**: the symmetric-conjugate 4-stage 4th-order
   set `(z_1, z_2, z_3, z_4)` from the paper (Table 2 or Eq. 5.x —
   exact reference TBD).
2. **`Complex{Float64} dt` plumbing**: `_outer_potential_*!`,
   `_ddi_step!`, `apply_kinetic_step_batched!`, `_apply_coriolis_step!`
   all accept `Float64 dt`. Generalise to accept `Complex{Float64}`
   substep weights `z · dt`. Most substeps already use `cis(arg) =
   exp(i·arg)` which is valid for complex args; the ITP-specific
   `exp(-2F·θ)` shift in DDI rotation needs an analogous adjustment.
3. **Re-normalize**: after each full 4-stage step, the ψ has accumulated
   a global complex phase. ITP normalisation (`norm_psi!`) already
   removes magnitude drift; need to also remove the phase by dividing
   by `exp(i · arg(⟨0|ψ⟩))` before measuring energy. (Optional —
   energy is gauge-invariant.)
4. **`integrator: blanes4` YAML opt-in**: alongside the existing
   `:strang` (current default), `:yoshida` (RTP only — broken in ITP),
   `:adaptive` (Richardson). Keep the existing closed branches working.
5. **Validation**: 4th-order convergence rate test. Run a known 1D
   Rosensweig profile at `dt = 0.02, 0.01, 0.005, 0.0025`; the energy
   error should scale as `O(dt^4)` (Strang gives `O(dt^2)`, Yoshida-real
   gives `O(dt^4)` but is forbidden in ITP).
6. **Per-step cost benchmark**: 4-stage vs 1-stage Strang. Each stage is
   a full Strang call internally, so cost is exactly 4× per ITP step.
   For accuracy gain ~16× per fixed dt (or 4× larger dt at same
   accuracy), the wall-clock saving is 4× for the dominant K, V, DDI
   evaluations.

## Files that change

- `src/solvers/ground_state/itp_loop.jl` — add `_run_itp_loop_blanes4!`
  driver. Keep existing function unchanged for `:strang` users.
- `src/foundation/types/integrator.jl` — extend `IntegratorConfig.method`
  to allow `:blanes4`.
- `src/hamiltonian/split_step.jl` — generalise V-substep helpers to
  accept `Complex{Float64} dt_outer / dt_ddi`. Most internal calls
  (`apply_spin_mixing_step!`, `apply_singlet_pair_step!`, etc) already
  do `cis` and complex-friendly expressions — bulk of the change is the
  `_dispatch_diagonal_step!` and DDI rotation shift.
- `test/test_blanes4_convergence.jl` — new file pinning 4th-order
  scaling.

## Open questions

- Coefficient transcription accuracy: the paper has multiple variant
  sets; which one is implemented? Document choice + paper reference.
- Edge cases: `secular_ddi=true`, `target_magnetization`, constrained
  Jz manifolds — do they need special handling at the new substep
  boundaries?
- GPU path: complex-`dt` substeps need to compose with the existing
  GPU broadcast forms (`apply_diagonal_step_gpu!`, etc). Mostly
  mechanical but worth a per-step regression test.

## Cost / benefit summary

For Eu151 phase-diagram production (the scenario where Strang's `dt =
0.005` is binding):

| Method        | Order | Substeps/step | dt (target tol) | Wall-clock |
|---------------|-------|---------------|------------------|------------|
| Strang (now)  | 2     | 1             | 0.005            | 1.0× (baseline) |
| Blanes4       | 4     | 4             | 0.020            | ≈ 1.0×, 4× larger range  |

For Strang `dt > 0.005` the energy starts losing precision. Blanes4
buys headroom that the LBFGS polish can then capitalise on (the polish
is currently bottlenecked by the warm-up GS quality at the largest
`dt` Strang allows).

## Status

Documentation only. Coefficient table and implementation deferred to a
session with paper access.
