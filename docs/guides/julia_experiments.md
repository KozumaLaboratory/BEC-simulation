# Julia experiment definitions

Experiment conditions are authored in Julia. YAML and TOML input readers and
format-specific execution APIs have been removed. Use Julia functions, includes,
loops, and comprehensions to share parameters and generate sweeps.

A definition file returns a `PipelineConfig`:

```julia
using SpinorBEC

PipelineConfig([
    GroundStateStep(
        atom=:Rb87,
        grid=(n=[32], box=[12.0]),
        interactions=(N_atoms=100, omega_ref=100.0, c0=1.0, c1=0.0),
        potential=(type=:harmonic, omega=[1.0]),
        initial_state=:polar, dt=0.001, n_steps=1000, tol=1e-6,
    ),
    DynamicsStep(duration=0.1, dt=0.001, save=(every=10,)),
])
```

Save this as `example.experiment.jl`, then inspect and run it:

```julia
inspect_config("example.experiment.jl")
run_experiment("example.experiment.jl")
```

The file is evaluated as Julia code in a fresh module with `SpinorBEC` available.
Relative `include` calls resolve beside the definition. As with other Julia
scripts, run only definitions you trust. A dictionary return value is also
accepted for the existing pipeline parameter resolver. The migrated corpus uses
this representation to preserve the original conditions exactly.

Use the `.experiment.jl` suffix for files that automated corpus tools may load.
Those tools ignore ordinary `.jl` driver scripts, which may launch computations.
The explicit loader accepts any `.jl` filename.

`run_experiment` saves input and resolved conditions as a generated `config.json`
record next to results. This record supports resume and cluster dispatch; it is
not another authoring format. Result directories are keyed by evaluated
conditions, so changing a source comment does not change the run identity.
Recorded code provenance still controls admission of cached results.

Construct `Model` values directly in Julia. `model_data` and `model_from_data`
encode result provenance and identity without a TOML experiment input API.
Julia package manifests, tooling configuration, literature-reference tables,
claim ledgers, and operational/result metadata retain their own formats.
