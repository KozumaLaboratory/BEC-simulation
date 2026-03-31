# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                    # run all tests
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test file
julia --project=. -e 'using Pkg; Pkg.instantiate()'              # install deps
julia --project=. bench/bench_eu151.jl                  # benchmark (with tracing)
julia --project=. examples/run.jl examples/              # run all YAML configs
```

## Architecture

Spin-F BEC simulation via split-step Fourier in 1D/2D/3D. Dimensionless units: ℏ=m=ω_ref=1. Kinetic step: `exp(-ik²dt/2)`.

### Include Order (`SpinorBEC.jl`)

`types.jl` must be first (all struct definitions). Rest follows dependency order:

```
types → units → grid → spin_matrices → spinor_utils → clebsch_gordan → atoms →
interactions → potentials → zeeman → propagators → spin_mixing → nematic →
tensor_interaction → losses → split_step → raman → ddi → ddi_padded →
optical_trap → optics → laser_potential → thomas_fermi → tof → fft_utils →
observables → energy → currents → vorticity → diagnostics → bogoliubov →
majorana → spherical_harmonics → simulation_utils → initialization → ground_state →
phase_boundary → simulation → adaptive → yoshida → experiment → experiment_runner →
config → phase_scan → config_runner → io → unitful_support
```

### Core Types (`types.jl`)

- `GridConfig{N}`, `Grid{N}` — N-dim spatial grid with FFT wavenumbers
- `SpinSystem(F)` — spin quantum number, `n_components = 2F+1`
- `SpinMatrices{D}` — static spin-F matrices (Fx, Fy, Fz, F·F) as `SMatrix`
- `SimState{N,A}` — mutable: wavefunction `psi`, time, step counter
- `Workspace{N,...}` — fully parameterized immutable container (14 type params incl. CoriolisCache)

### Wavefunction Layout

`psi` is `Array{ComplexF64, N+1}`: spatial dims first, spinor component last: `psi[x, y, ..., c]` for `c ∈ 1:2F+1`.

Access helpers (`spinor_utils.jl`): `_component_slice`, `_get_spinor`/`_set_spinor!`, `_matvec`, `_apply_euler_spin_rotation`.

### Split-Step Pipeline (`split_step.jl`)

Strang splitting (2nd-order symmetric):
1. Half potential: `diag(dt/4) → SM(dt/4) → nematic(dt/4) → Raman(dt/4) → DDI(dt/2) → [mirror]`
2. Full kinetic (batched FFT → phase → batched IFFT)
3. Half potential (mirror)
4. Loss step (real-time only)

Tensor step replaces SM + nematic when `TensorInteractionCache` is active. Substeps auto-skip when coupling ≈ 0. Instrumented with `@timeit_debug TIMER`.

### Entry Points

- `find_ground_state(; grid, atom, ...)` — imaginary-time propagation
- `make_workspace(; ...) → Workspace` then `run_simulation!(ws)` — real-time dynamics
- `run_simulation_adaptive!` / `run_simulation_yoshida!` — adaptive dt
- `load_config("path.yaml")` then `run_config(config)` — YAML-driven (v3 schema)
- `examples/run.jl` — batch YAML runner (default: `examples/`)

### Tracing

```julia
enable_tracing!(); reset_tracing!()
# ... run ...
println(TIMER); disable_tracing!()
```

## Performance Notes

- **SMatrix{D,D} at D≥10**: heap-allocates. Use `Matrix`/`MVector` in hot loops, never SMatrix for D=13.
- **`Threads.@threads` closures**: box captured untyped args (65 MiB/call at D=13). Prefer plain `@inbounds for`.
- **`Val(ndim::Int)`**: dynamic dispatch. Use `Val(N)` from type parameter.
- **`ntuple(f, ndim::Int)`**: type-unstable. Use `ntuple(f, Val(N))`.

## Key Constraints

- New structs must go in `types.jl` (included first)
- Julia 1.12: inner constructors only (method overwriting forbidden during precompilation)
- 21 atom species in `atoms.jl` + `ATOM_REGISTRY`; `resolve_atom(:Name)` for YAML lookup
- YAML configs in `examples/` follow schema in `config.jl` (v3) or `experiment.jl` (legacy)
- Workspace is fully parameterized — auto-inferred constructor, no explicit type params needed
