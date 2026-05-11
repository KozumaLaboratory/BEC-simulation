# SpinorBEC API reference

Auto-generated from docstrings via [Documenter.jl](https://documenter.juliadocs.org/).
To rebuild locally:

```julia
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=".")); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

The output lands in `docs/build/`.

## Manually-curated entry points

**Guides (how to do something):**

- [Pipeline cookbook](../guides/pipeline_cookbook.md) — common YAML patterns
- [Lab user tutorial](../guides/lab_user_tutorial.md) — start-to-finish workflow
- [Performance tuning](../guides/performance_tuning.md) — when to use which knob

**Reference (look something up):**

- [Architecture](../reference/architecture.md) — module structure & data flow
- [YAML schema reference](../reference/yaml_schema_reference.md) — every key

**Design notes (why something exists):**

- [Mixed precision](../design/mixed_precision_design.md) — F32 / F64 path
- [Two-component GP](../design/two_component_gp_design.md) — #51 plan
- [Live monitor](../design/live_monitor_design.md) — #67 plan

## Module exports (selected)

### Pipeline

```@docs
run_yaml
run_config
load_config
load_config_from_string
print_run_summary
compare_runs
```

### Solvers

```@docs
find_ground_state
find_ground_state_lbfgs
make_workspace
run_simulation!
apply_sgpe_step!
sgpe_callback
apply_projected_gp!
projected_gp_callback
```

### Calibration

```@docs
CalibrationSet
CalibrationHistory
load_calibration
load_calibration_history
load_calibration_csv
interpolate_calibration
apply_calibration!
```

### State zoo (selected)

```@docs
init_psi_polar
init_psi_ferromagnetic
init_psi_skyrmion_lattice
init_psi_vortex_lattice
init_psi_biaxial_nematic
init_psi_chiral_spin_vortex
```

### Two-component (scaffold)

```@docs
BinaryCouplings
find_binary_ground_state
is_immiscible
droplet_regime_petrov
```
