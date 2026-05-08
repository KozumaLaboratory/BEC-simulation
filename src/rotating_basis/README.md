# `src/rotating_basis/` — Klaus-regime support

Specialised solver path for the **strong-field / fast-Larmor regime**:
roughly `B ≳ 0.1 G` (Eu) or `ω_L / ω_trap ≳ 100`. Used for Klaus 2022
magnetostir reproduction, $\phi_\omega$ scans, and any future
high-$p$ Eu / Dy work.

The standard `split_step.jl` solver can in principle handle the same
physics, but at prohibitive cost: at $|p \cdot F \cdot dt| > \pi$ the
Larmor sub-cycling forces `dt ~ 10⁻⁵` and `epsilon ~ 1e-6` (see memory
`eps_threshold_finding.md`). The rotating-basis path **removes Larmor
analytically** via the gauge transform $|\psi\rangle = \hat U_B(t)|\tilde\psi\rangle$,
allowing `dt ~ 10⁻³` while preserving spin excitations.

For low-field / standard-trap work (LHY closed forms, TWA, polyhedral
phase studies, F=2/F=6/F=10 LHY papers), use the **plain `split_step!`**
path — none of the recent Round 1–7 work goes through this directory.

## Files

| File | Purpose |
|---|---|
| `workspace.jl` | `RotatingBasisWS` struct, `make_rotating_basis_ws` factory, Lima-Pelster $Q_5$ helper, `U_B` ↔ tilde basis transforms |
| `propagators.jl` | Per-substep operators in the rotating basis: kinetic, spatial-diagonal, local-spin, DDI, gauge. Plus lab-basis reference operators for Phase III equivalence checks. |
| `integrators.jl` | Time-stepping drivers: `split_step_rotating!`, Yoshida 4 / 6, CFET 4, `find_ground_state_rotating!`. |
| `analysis.jl` | Post-evolution diagnostics: per-m norms, total density, $L_z$, coordinate buffers. |
| `analyzers.jl` | Higher-level analyzers for the pipeline `:rotating_basis_dynamics` Dict (population dynamics, EdH conservation, spin texture, per-m vortices, Berry connection). |
| `scalar_egpe.jl` | Alternative adiabatic-elimination path: scalar GPE with time-dependent dipole axis $\hat B(t)$. Serves as the Phase-II reference for the rotating-basis Phase-III equivalence check, and as an option for the deep adiabatic limit where `tilde_psi_{m≠−F} → 0`. |

Pipeline integration lives outside this dir:

* `src/workflow/experiments/pipeline/run_step_rotating.jl` — `_run_step(::RotatingBasisGroundStateStep)` etc. and chirp-phase helpers.
* `src/workflow/io/save_rotating_result.jl` — canonical JLD2 layout for the rotating-basis history.

## Public API (commonly used externally)

Workspace + mode dispatch:

* `make_rotating_basis_ws(grid, F, V_trap; ...)` → `RotatingBasisWS`
* `make_scalar_ws(grid, V_trap; ...)` → `ScalarSimWS` (adiabatic alternative)
* `lima_pelster_Q5(ε_dd)`, `compute_gamma_lhy(a_s/a_ho, ε_dd, N_atoms)`

Time stepping (rotating basis):

* `split_step_rotating!(ws, dt, t)`
* `evolve_rotating!(ws, n_steps, dt; t0, on_step)`
* `evolve_rotating_yoshida4!`, `_yoshida6!`, `_cfet4_real!`
* `find_ground_state_rotating!(ws, n_steps, dt; tol, ...)`
* `normalize_rotating!(ws)`, `rotating_norm(ws)`

Lab-basis equivalence path:

* `evolve_lab!(ws, n_steps, dt; ...)`
* `split_step_lab!(ws, dt, t)`

Post-evolution observables:

* `rotating_per_m_norms(ws)` → `Vector{T}` length 2F+1
* `rotating_total_density(ws)` → 3D array
* `rotating_Lz(ws)` (3D only)
* From the pipeline-history Dict (`:rotating_basis_dynamics`):
  * `population_dynamics`, `edh_conservation`, `spin_texture_xy`,
    `per_m_column_density`, `detect_per_m_vortices`,
    `berry_connection_trajectory`.

Scalar (adiabatic-elim) path:

* `split_step_scalar!`, `evolve_scalar!`, `find_ground_state_scalar!`
* `compute_tilted_dipole_potential!`
* `scalar_norm`, `scalar_com`, `scalar_aspect_ratio`,
  `scalar_energies`, `scalar_Lz`

## YAML config integration

```yaml
defaults:
  kind: rotating_basis      # routes to _run_step(::RotatingBasis*Step)
  backend: gpu

pipeline:
  - ground_state:
      atom: Eu151
      grid: {...}
      interactions: {...}
      B: {magnitude_G: 1.0, theta_deg: 35}
      integrator: yoshida6
      epsilon: 1.0e-6   # ε_threshold for high-p; see memory note
      ...
  - dynamics:
      duration: ...
      phi_omega: 4.524        # stir frequency / ω_ref
      phi_chirp: {from: ..., to: ...}
      ...
```

See `runs/klaus_baseline/`, `runs/phi_omega_scan/`,
`runs/berry_crossover_scan/`, `runs/eu151_phase_diagram_lbfgs/` for
worked examples.

## Tests

* `test/test_rotating_basis_gpe.jl` — Phase I + II core
* `test/test_rotating_basis_phase_ii.jl` — static-tilt regression
* `test/test_rotating_basis_phase_iii.jl` — lab-frame agreement
* `test/test_rotating_basis_pipeline_parsing.jl` — YAML parsing + ε threshold
* `test/test_rotating_basis_f32.jl` — Float32 mixed-precision pin
* `test/test_rotating_basis_analyzers.jl` — modular analyzer dispatch
* `test/test_rotating_basis_gpu.jl` — CUDA equivalence
* `test/test_rotating_frame_regression.jl` — `secular_ddi=true` regression
* `test/test_scalar_egpe_smoke.jl`, `test/test_scalar_egpe_dipole_kernel.jl`
  — scalar-eGPE smoke + DDI kernel

## See also

* `docs/option_gamma_rotating_basis.md` — full design doc with phase
  decomposition (Phase I CPU GPE → II static tilt → III lab agreement).
* `docs/AUDIT_BUG4.md` — DDI integration rate fix (2026-05-02);
  rotating-basis runs were not affected since they use their own
  `apply_ddi_step_rotating!`.
* `memory/option_gamma_rotating_basis.md`, `memory/option_gamma_gpu_optimization.md`,
  `memory/eps_threshold_finding.md`, `memory/klaus_adiabatic_elimination.md`
  for the design history.
