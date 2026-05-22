# CLAUDE.md

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

Full YAML schema lives in `docs/reference/yaml_schema_reference.md`. This file documents the load-bearing conventions and architectural boundaries — things you cannot guess from the code alone.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                     # all tests (~5 min, default tier=full)
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test
julia --project=. -e 'using Pkg; Pkg.instantiate()'               # install deps
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.                # GPU (WSL2)
```

Test tiers via `SPINORBEC_TEST_TIER`: `fast` (units only), `ci` (+ ITP/RTP integration), `full` (default), `physics` (analytic validation only).

## Project Structure

```
src/
├── SpinorBEC.jl          # umbrella; loads each subsystem umbrella below
├── foundation.jl         # → foundation/types/ + math primitives
├── hamiltonian.jl        # → interactions/, potentials/, integrator/
├── analysis.jl           # → observables, energy, currents, vorticity, phases/
├── solvers.jl            # → ground_state/, lbfgs/, continuation/, simulation, twa, binary
├── rotating_basis.jl     # Klaus-regime path (workspace, propagators, integrators)
├── precompile.jl, cuda_graph_stubs.jl
└── workflow/
    ├── initialization.jl, io.jl, monitoring.jl, experiments.jl
    └── experiments/{schema,runtime,analyzers,pipeline,optimization}/

ext/                      # SpinorBEC{CUDA,Makie,HTTP,VTK}Ext (weak-dep extensions)
test/                     # 8600+ tests, tiered, subdirs mirror src/ structure
dashboard/                # React + WebGPU frontend
```

Each subsystem umbrella `Foo.jl` `include`s sub-files in dependency order. Public exports live next to their definitions.

## Key Architecture

**Wavefunction**: `psi[x, y, ..., c]` — spatial dims first, spinor last. c=1→m=F, c=D→m=−F.

**Split-step** (`split_step.jl`): `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`. Inner V is symmetric: `diag SM singlet_pair tensor raman DDI raman tensor singlet_pair SM diag`. All substeps auto-skip when coupling ≈ 0.

**Two interaction paths** (auto-selected in `make_workspace`):
- **c₀/c₁ path**: diagonal(c₀) + spin_mixing(c₁) + singlet_pair(c₂) + tensor(residual c₄,c₆,...)
- **Scattering-lengths path** (Cr52 etc.): tensor handles ALL channels, c₀=c₁=0

**Entry points**:
- `find_ground_state(;...)` — ITP (imaginary time propagation)
- `make_workspace(;...) |> run_simulation!` — RTP (real time propagation)
- `run_yaml("x.yaml")` — resumable YAML-driven experiment (directory-per-config, one jld2 per point, skips cached files on re-run)
- `load_config("x.yaml") |> run_config` — in-memory YAML run (no resume)
- `scan_continuation(; make_params, ...)` — parameter sweep with continuation
- `scan_phase_diagram_2d(; make_params, ...)` — 2D phase diagram

**YAML schema**: parameter variation is expressed as a **config path override** — a dotted path into the raw YAML dict (e.g. `pipeline.0.ddi.c_dd`) mapped to a new value. Full reference: `docs/reference/yaml_schema_reference.md`. Per-step dynamics knobs: `docs/reference/dynamics.md`. Magnetic field uses the **unified `B:` block** (`B: {Bz, theta, phi}` or `B: {p_mv, coil_mode}` for lab-units calibration); `q` auto-derives from |B|² unless explicit. Lab-units features (`units:`, `accuracy:`, `auto_grid:`, `template:`, `mixins:`, `defaults:`, ε hardening) are OPT-IN.

**Mixed precision (rotating_basis only)**: set `dtype: f32` in the `ground_state` block. Plumbs Float32 through Grid, V_trap, workspace, FFT plans, DDI buffers. First-time JIT for the F32 specialisation ~10 min then cached. Caveats: `apply_uniform_spin_rotation!` + `apply_ddi_step!` + `apply_spin_mixing_step!` keep scalar Float64 locks (rotation builder + DDI dt + c1·dt) — array work stays F32. `DDIParams.C_dd` is Float64 by struct definition. F64 is the default. See `test/test_rotating_basis_f32.jl`.

**Noise**: both GS (`temperature_ratio`) and phase noise (`dynamics.temperature_ratio`) use Bose-Einstein thermal noise with `T/T_c ∈ (0, 1)`, driving `add_thermal_noise(psi, F; T_over_Tc, seed)`.

**Calibration**: lab-unit YAML preprocess auto-applied by `run_yaml`. Single `calibration:` block or `calibration_history:` for week-to-week interpolation. Lab fields then expand inside the unified `B:` block: `B: {p_mv: 2.5, coil_mode: strong}` resolves via calibration table to a Gauss value before downstream parsing. See `docs/reference/yaml_schema_reference.md` for canonical examples.

**`phi_omega` Hz form**: `phi_omega: 4.524` (dimensionless ω/ω_ref) and `phi_omega: "226.2 Hz"` are equivalent; Hz converts via `(2π·f)/ω_ref` using parent `interactions.omega_ref`. Eliminates the Klaus 2022 magnetostir 2π footgun (memory: `gotcha_waveform_frequency_convention.md`).

**State zoo**: 22 named builders in `init_psi_<name>` shape (`src/workflow/initialization/state_zoo.jl`). All wrap `init_psi(state=:..., init_state_params=...)` — same physics, named API. Currently WIP for YAML integration (memory: `state_zoo_yaml_integration_wip.md`).

**LHY config** (refactored 2026-05-12): single `lhy:` block inside `ground_state`. `kind` ∈ {`scalar`, `quasi_2d`, `two_channel`, `full_bdg`, `polar_contact`, `polar_dipolar`, `fm_contact`, `fm_dipolar`, `icosahedral`, `none`}. Auto-derive `c_lhy` for `scalar` / `quasi_2d`. Legacy keys (`interactions.c_lhy`, `ground_state.spinor_lhy`) removed.

**Continuation API** (direct-Julia): `make_params(val) → NamedTuple` overrides any `find_ground_state` kwargs per sweep point. Legacy `make_interactions(val) → InteractionParams` also supported.

**GPU**: `import CUDA` before `using SpinorBEC` loads the extension. Pass `backend=CUDABackend()`. WSL2 needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib`.

## Conventions (do NOT "fix")

- **DDI**: `c_dd=μ₀μ²` (no 4π), `Q_αβ=k̂_αk̂_β−δ_αβ/3` (no 1/(4π)), `Q(k=0)=0`. Chain self-consistent.
- **ITP Zeeman shift**: subtracts `min(E_m)` to prevent overflow.
- **Scalar LHY**: `@warn` present. Known approximation.
- **Odd-rank c_extra ignored**: `@warn` present. KU's c₃≠rank-3 tensor.
- **`compute_interaction_params_general_f` returns (0,0)**: by design (tensor_cache handles all).
- **`_YOSHIDA_W0 < 0`**: correct (backward middle substep, all operators time-reversible).

## ¹⁵¹Eu

F=6, g_J=1.9934, g_F≈1.163, μ≈6.977μ_B, a_s≈110a₀. 7 unknown scattering channels (S=0,2,...,12). Constraint: `c₀+36c₁=4π(a_s/a_ho)N`.

## Known limitations (design boundaries — don't "fix")

- **`TwoChannelLHY` is polar-only**, exact at F=1, ~1% off at F=2, **30-70% off at F=6** (pinned by `test_spinor_lhy.jl`). For F≥2 polar use `PolarContactLHY` / `PolarDipolarLHY`; FM → `FMContactLHY` / `FMDipolarLHY`; F=6 I_h → `IcosahedralLHY`.
- **F=6 polar + `FullBdGLHY`** emits a `@warn` (~3000× spurious offset; memory `full_bdg_F6_polar_broken.md`).
- **`secular_ddi=true` is user-chosen** (not auto). `make_workspace` emits `@info` advisory when `ω_L/(c_dd·⟨n⟩) > 100` — Eu experiments almost always live there.
- **`spin_rotating_frame_omega ≠ 0` requires `secular_ddi=true`** (enforced via `ArgumentError`). Full DDI's off-diagonal components only Larmor-average to zero in the secular limit.
- **`even_c_extra(F; c2, c4, c6, …)` is the canonical c_extra builder.** Hand-written `[c2, c4, c6]` silently misindexes for F≥3.
- **Bogoliubov k=0 Goldstone**: μ convention is correct (re-audited 2026-05-02). Earlier "bug" was a test-indexing error — `omega[1, :]` row slice vs `omega[:, 1]` column. Memory `bogoliubov_test_indexing.md`.
- **`split_step_captured!` on GPU silently falls back** to `split_step!`. CUDA Graph implementation in `ext/SpinorBECCUDAExt/gpu_graph.jl` is disabled — replay drift from per-call broadcast allocations (4× slower in bench). Memory `option_gamma_gpu_optimization.md`.
- **`_get_spinor(psi, I, Val(13))` allocates ~352 bytes/call at D=13**. SROA elides some inside hot loops; call site still pays when `c1 ≠ 0`. Rotating-basis path uses gemm-form rotation and is unaffected.

## Constraints

- All structs in `src/foundation/types/` (loaded first). New structs go there.
- Workspace has 23+ type params — never write explicit type params.
- D=13 (Eu): `SMatrix` heap-allocates. Use `Matrix`/`MVector` in hot loops.
- `Val(N)` from type parameter, not `Val(ndim::Int)`.

## Type stability boundaries

`Workspace` has 23+ type params and `run_pipeline` dispatches abstractly on `PipelineStep`. Any type widening in a `_run_step` branch (e.g. assigning `zeeman = dict[:zeeman]` from `Dict{Symbol,Any}`) propagates to `make_workspace`'s type parameter combinations, causing inference to explode — symptom is a **30 min JIT hang with no stack trace**, not a runtime error. Prevent with two rules:

1. **`Dict{Symbol,Any}` → concrete struct: isolate in a helper function with `::ConcreteType` assertions.** The function boundary keeps `Any`-typed locals out of `_run_step`; the type assertion tells the compiler the return-tuple elements are concrete. Never let `Any` flow into `make_workspace` kwargs directly. (`@noinline` is NOT required — function boundary plus type assertion is what defuses inference.)

   ```julia
   # NG — zeeman becomes ::Any, pollutes make_workspace inference
   zeeman = ps_compiled[:zeeman]
   ws = make_workspace(; zeeman, ...)

   # OK — helper boundary + ::ConcreteType narrow
   function _apply_pulse_sequence(ps_raw, ..., zeeman, ...)
       ps_raw isa Vector || return (zeeman, ...)
       compiled = compile_pulse_sequence(...)
       zee_out = haskey(compiled, :zeeman) ?
           compiled[:zeeman]::TimeDependentZeeman : zeeman
       (zee_out, ...)
   end
   ```

2. **Never store closures (`FunctionWaveform(t -> ...)`, anonymous functions) in struct fields that flow into Workspace.** Each closure site has a unique type, multiplying specialization work. Pre-evaluate to `PiecewiseLinearWaveform` / `InterpolatedWaveform` before storing.

**Debug procedure** when JIT hangs:
- Direct-call the offending `_run_step(::ConcreteStep, ...)` — if fast, suspect abstract-dispatch propagation from `run_pipeline`.
- Check recent additions for `Dict{Symbol,Any}` extractions or closure creation in paths that reach `make_workspace`.
- `Cthulhu.descend(run_pipeline, (typeof(config),))` for deep inspection.

**User-supplied callbacks** (live_monitor `extract_observables`, simulation `SimulationCallbacks.on_step`) accept `::Function` — OK in cold paths, but callbacks invoked in hot loops should parameterize: `struct Cb{F1,F2} ...`.

**Cascade cost** (measured 2026-04-26, Julia 1.12.6, fresh JIT, no cache): a single `run_yaml` for a trivial Rb87 `ground_state` step (32-pt 1D grid, 50 ITP steps) takes >4 min to first output, dominated by `make_workspace` + `find_ground_state` specialization. `test_infrastructure.jl` / `test_zeeman_levels.jl` gate 8 YAML integration tests behind `_SKIP_HEAVY_YAML_INFRA` / `_SKIP_HEAVY_YAML_ZEEMAN`; `.github/workflows/nightly.yml` flips `SPINORBEC_RUN_HEAVY_YAML=true` so guarded blocks get regression coverage without paying the cost on every push.
