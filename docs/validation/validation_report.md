# Validation matrix report

Generated: 2026-05-25T07:53:12.715

Source: `scripts/validation/run_validation_matrix.jl`
Ladder: `memory/validation_ladder_2026_05_24.md` (13 levels, 0-12)

## Summary

| Status | Rows | Notes |
|---|---|---|
| PASS | 14 | automated test rows whose tests all passed |
| FAIL | 0 | automated test rows with at least one failure |
| MANUAL | 6 | levels requiring manual runs or external code |
| SKIP | 1 | tests in full tier (slow), skipped by matrix runner |
| ERROR | 0 | test file missing or threw an exception |

Total automated assertions: 5555 pass, 0 fail, 0 broken.

## Per-level results

| Level | Status | Description | Test | Pass | Fail | Broken | Notes |
|---|---|---|---|---|---|---|---|
| 0 | 👤 MANUAL | Environment / reproducibility (git, Manifest, CUDA, seed) | `MANUAL: runs/verification_suite/ env metadata` | 0 | 0 | 0 | runs/verification_suite/ env metadata |
| 1 | ✅ PASS | Scalar exact tests (free uniform, plane wave, harmonic GS) | `test/test_level1_scalar_exact.jl` | 8 | 0 | 0 |  |
| 1 | ✅ PASS | Pseudospectral dealiasing infrastructure | `test/test_dealias_2_3.jl` | 55 | 0 | 0 |  |
| 2 | ✅ PASS | Strang dt²-convergence (ratio ≈ 4 across dt halvings) | `test/test_level2_strang_convergence.jl` | 8 | 0 | 0 |  |
| 3 | ✅ PASS | Zeeman-only dynamics (N_m frozen, ψ_m phase = -i(-pm+qm²)t) | `test/test_level3_zeeman_only.jl` | 12 | 0 | 0 |  |
| 3 | ✅ PASS | Spin matrices ([F_x,F_y]=iF_z, F^2, ladder coefficients) | `test/foundation/test_spin_matrices.jl` | 422 | 0 | 0 |  |
| 3 | ✅ PASS | Zeeman accessor API (linear_p, quadratic_q, transverse_b) | `test/hamiltonian/test_zeeman_accessors.jl` | 15 | 0 | 0 |  |
| 4 | ✅ PASS | Spin-1 SMA c1 sign convention | `test/hamiltonian/test_spin_mixing.jl` | 4 | 0 | 0 |  |
| 4 | ✅ PASS | Spin-2 cyclic / nematic A_00 singlet pair | `test/hamiltonian/test_singlet_pair.jl` | 28 | 0 | 0 |  |
| 4 | ✅ PASS | Higher-rank c_extra builder (S=4,6,...) | `test/hamiltonian/test_tensor_interaction.jl` | 261 | 0 | 0 |  |
| 5 | ✅ PASS | DDI kernel (spherical polarized E_DDI~0) | `test/hamiltonian/test_ddi.jl` | 4644 | 0 | 0 |  |
| 5 | ✅ PASS | DDI padded convolution (FFT vs direct) | `test/hamiltonian/test_ddi_padded.jl` | 14 | 0 | 0 |  |
| 6 | 👤 MANUAL | EdH F=3 toy benchmark (Jz conservation) | `MANUAL: runs/verification_suite/yamls/09_edh_toy_spin_orbit_transfer.yaml` | 0 | 0 | 0 | runs/verification_suite/yamls/09_edh_toy_spin_orbit_transfer.yaml |
| 7 | ⏭ SKIP | K3 loss analytic n(t) = n0/sqrt(1+2K3 n0^2 t) | `test/workflow/test_losses.jl (full tier)` | 0 | 0 | 0 | skipped: full tier |
| 7 | ✅ PASS | K3 / L3 routing + SI conversion edge cases | `test/workflow/test_loss_block_edge_cases.jl` | 20 | 0 | 0 |  |
| 8 | ✅ PASS | Scalar LHY scaling + coefficient + spinor caveat | `test/hamiltonian/test_lhy_level8_unit.jl` | 25 | 0 | 0 |  |
| 8 | ✅ PASS | Norm conservation with LHY | `test/hamiltonian/test_lhy.jl` | 39 | 0 | 0 |  |
| 9 | 👤 MANUAL | Eu Ham-only: N=64/96/128 = 0.00886 at dt=0.005+k_cut=16 | `MANUAL: 2026-05-24 CROSS-GRID CONVERGED` | 0 | 0 | 0 | 2026-05-24 CROSS-GRID CONVERGED |
| 10 | 👤 MANUAL | Ueda operator-RHS comparison (BLOCKED on Ueda code OR test data) | `MANUAL: scripts/validation/{export,compare}_operator_rhs.jl` | 0 | 0 | 0 | scripts/validation/{export,compare}_operator_rhs.jl |
| 11 | 👤 MANUAL | dt/grid/box/seed convergence at Eu params | `MANUAL: convergence sweep` | 0 | 0 | 0 | convergence sweep |
| 12 | 👤 MANUAL | Eu production: DDI off / +K3 / +γ_dr / +LHY twins | `MANUAL: production with controls` | 0 | 0 | 0 | production with controls |

## How to read this

- **PASS** means *every assertion* in the linked test file passed
  (the test file is the contract; if you add new assertions, they
  must pass too).
- **FAIL** means at least one assertion failed; consult the test
  file + the run log.
- **MANUAL** means the level requires either an external code
  (Level 10 Ueda) or a multi-grid sweep too expensive to run
  every time (Levels 9, 11, 12). The "test" column points to
  the relevant artifact.
- **SKIP** means the test is in the `full` tier (heavy ITP/RTP)
  and is excluded from the matrix runner. Run via
  `SPINORBEC_TEST_TIER=full julia --project=. -e 'using Pkg; Pkg.test()'`.

## Acceptance for "perfect simulation"

Per the validation ladder, "perfect simulation" requires:

1. Levels 0-8 all PASS (every automated row green)
2. Level 9 (Eu Ham-only cross-grid): the documented run is
   pinned at `ΔF_z = 0.00886` for N=64/96/128 at dt=0.005,
   k_cut=16.0, dealias enabled.
3. Level 10 (Ueda compare): operator-RHS diff `< 1e-10`
   against an external reference (Ueda lab spinor-BEC code).
   **Currently BLOCKED** until external data is exchanged.
4. Level 11 (convergence): dt/grid/box/seed sweep documented
   in `docs/validation/convergence_plots/`.
5. Level 12 (production): every K3-on / LHY-on production
   run has a K3-off / LHY-off twin for control.

Until **Level 10 PASS**, conclusions about K3 / LHY / long-time
physics from production Eu runs are NOT validated.
