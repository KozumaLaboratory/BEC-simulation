# Integration plan: GP-LHY skeleton → SpinorBEC.jl

The parallel session's `eu_droplet_skeleton.jl` reproduces the
Saito-Li 2024 droplet framework, but with the F=6 polar+DDI LHY
**closed form** (paper #1, Eqs. 5-6) as the local-density correction.
Most of the skeleton duplicates production code at lower fidelity;
only two pieces are genuinely new and need to land in SpinorBEC.jl.

## What's load-bearing in the skeleton

Function | Status | Where it goes
---------|--------|---------------
`phi1_reg(t)` | NEW (paper #1 universal regularised LHY function) | `src/hamiltonian/interactions/lhy.jl`
`eps_LHY_F6_polar_DDI(n, eps_dd, ka)` | NEW (paper #1 main result) | same file, used as `:closed_form_F6_polar` mode of `compute_spinor_lhy_table`

## What duplicates existing infrastructure (drop)

Skeleton feature | Production replacement
-----------------|------------------------
`grid_3d(...)` | `Grid{N,T}` + `make_workspace(grid=...)`
Manual `fft`/`ifft` kinetic step | `BatchedKineticCache` + `_kinetic_step!`
`compute_DDI_potential!` (axial-only kernel) | full F̂-tensor `apply_ddi_step!` in `src/hamiltonian/interactions/ddi.jl` (with `secular_ddi`, `c_extra`, etc.)
`imaginary_time_step!` (Strang only) | `_yoshida_embedded_step!` in `src/solvers/embedded_adaptive.jl` with L2-adaptive dt
`simulate_droplet(...)` | `find_ground_state(; spinor_lhy=:closed_form_F6_polar, n_steps, tol, dt, adaptive_dt=true, ...)`
`initial_cigar_polar` / `initial_torus_FM` | Add to `src/workflow/initialization/state_zoo.jl` as `init_psi_cigar_polar` and `init_psi_torus_FM_vortex` (currently 22 named builders)

## Wiring steps

1. **Add the closed-form to `lhy.jl`**:
   ```julia
   function compute_spinor_lhy_closed_form_F6_polar(; F, c0, c1, c_dd,
                                                    n_max, n_points)
       F == 6 || throw(ArgumentError(":closed_form_F6_polar is F=6 only"))
       # tabulate eps_LHY_F6_polar_DDI(n, eps_dd, ka) over n ∈ [0, n_max]
       # at fixed eps_dd / ka(c0, c1, c_dd) → SpinorLHYTable(:closed_form_F6_polar, …)
   end
   ```
   Then add the `:closed_form_F6_polar` branch to `compute_spinor_lhy_table`.

2. **Wire YAML**:
   ```yaml
   ground_state:
     atom: Eu151
     spinor_lhy: closed_form_F6_polar    # was :scalar / :two_channel
     ...
   ```
   `parsing_units.jl` accepts a Symbol or string for `spinor_lhy`; need to
   add the new symbol to the validation set.

3. **State zoo entries** for cigar / torus-FM-vortex initial conditions.
   The torus initial state has tangent-spin azimuthal phase factor
   `exp(i·sense·m·φ)` — that's a per-component phase already supported by
   the existing `apply_uniform_spin_rotation!` machinery, just needs a
   builder that calls it with the right φ-dependent rotation.

4. **YAML showcase** at `runs/samples/eu_droplet_polar_cigar/config.yaml`
   replicating the skeleton's `run_eu_scenarios()` polar-cigar scenario,
   then a sibling `eu_droplet_torus_FM/` for the FM-vortex case.

5. **Saito-Li 2024 reproduction test** under `test/test_lhy_f6_closed_form.jl`:
   verify the Petrov-regularised energy density matches Saito-Li Eq. (X)
   in the fully-polarised limit (set ka so the m=0 / m=±1 / m≥2 weights
   collapse to scalar Lima-Pelster Q5).

## Open questions for the parallel session

- The skeleton's `ka` is `[4π, 4π, 4π, 4π, 4π, 4π, 4π]` (uniform). Real
  F=6 polar `κ_m` values depend on c_0, c_1, …, c_F linearly — what's
  the explicit map? (Phase A.2 should have it as part of the closed form.)
- Should the |m|≥2 contributions stay contact-only, or does paper #1
  include any DDI dressing for them? (The skeleton comment says
  contact-only because DDI is in the |m|=1 sector for polar — confirm.)
- For non-uniform-density GS (where the LDA evaluation needs n(r)),
  the skeleton tabulates ε_LHY(n, ka) once and interpolates. Should
  the table be 2D `(n, eps_dd)` for runs where ε_dd varies (e.g. via
  scattering-length tuning), or 1D `n` at a fixed ε_dd?
