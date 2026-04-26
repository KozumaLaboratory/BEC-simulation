# CLAUDE.md

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                     # all tests (~8600, ~5 min)
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test
julia --project=. -e 'using Pkg; Pkg.instantiate()'               # install deps
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.                # GPU (WSL2)
```

## Project Structure

```
src/
├── foundation/      # types.jl, backend.jl, grid, spin matrices, CG coefficients
├── hamiltonian/     # interactions, potentials (zeeman, trap, DDI, raman, LHY)
├── solvers/         # ground_state (ITP), simulation (RTP), continuation, adaptive
├── workflow/        # experiments (YAML config), initialization, io, monitoring
└── analysis/        # energy, observables, phases, stability, diagnostics, TOF, vorticity
```

## Key Architecture

**Wavefunction**: `psi[x, y, ..., c]` — spatial dims first, spinor last. c=1→m=F, c=D→m=−F.

**Split-step** (`split_step.jl`): `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`.
Inner V is symmetric: `diag SM nematic tensor raman DDI raman tensor nematic SM diag`.
All substeps auto-skip when coupling ≈ 0.

**Two interaction paths** (auto-selected in `make_workspace`):
- **c₀/c₁ path**: diagonal(c₀) + spin_mixing(c₁) + nematic(c₂) + tensor(residual c₄,c₆,...)
- **Scattering-lengths path** (Cr52 etc.): tensor handles ALL channels, c₀=c₁=0

**Entry points**:
- `find_ground_state(;...)` — ITP (imaginary time propagation)
- `make_workspace(;...) |> run_simulation!` — RTP (real time propagation)
- `run_yaml("x.yaml")` — resumable YAML-driven experiment (directory-per-config, one jld2 per point, skips cached files on re-run)
- `load_config("x.yaml") |> run_config` — in-memory YAML run (no resume)
- `scan_continuation(; make_params, ...)` — parameter sweep with continuation
- `scan_phase_diagram_2d(; make_params, ...)` — 2D phase diagram

**YAML schema**: every parameter variation is expressed as a **config path override** — a dotted path into the raw YAML dict (e.g. `pipeline.0.ddi.c_dd`, `pipeline.0.zeeman.p`) mapped to a new value. The runner applies the override, re-parses the experiment dict, and builds a fresh workspace.

```yaml
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [20.0, 20.0, 20.0]}
      interactions: {c_total: 4689, c1_ratio: 0.028}
      ddi: {c_dd: 7647, enabled: true}
      zeeman: {p: 100, q: 0}
      trap: [1.0, 1.0, 1.182]
      dt: 0.005
      n_steps: 20000
      tol: 1.0e-10
      backend: cuda

  - dynamics:                           # each phase is a separate step
      duration: 3.0
      dt: 0.001
      ddi: true
      zeeman: {p: {from: 100, to: 0.39}, q: 0}   # ramp → TimeDependentZeeman
      save_every: 50
      temperature_ratio: 0.1            # T/T_c thermal noise at phase start

  - analyze:                            # post-processing (any number of entries)
      - tomography: {axis: y, n_angles: 19}
      - faraday: {detuning: -64, axis: 3}
      - phase_classify: {}

scan:                                   # orthogonal to pipeline
  zip:                                  # 1D sweep (all paths must agree on length)
    pipeline.0.ddi.c_dd:    [0.0, 4000.0, 7647.0]
    pipeline.0.zeeman.p:    [100.0, 10.0, 1.0]
  product:                              # N-dim Cartesian product
    pipeline.0.interactions.c1_ratio:       [-0.02, -0.01, 0.0]
    pipeline.0.target_magnetization:        [-6.0, -3.0, 0.0]
  comparison_runs:                      # run multiple recipes at every point
    - name: fl_vortex
      override: {pipeline.0.initial_state: spin_coherent, ...}
  continuation: true                    # reuse previous psi as initial condition
  auto_rotate_on_mz: true              # rotate by Δα when target Mz changes
```

**Noise**: both GS (`temperature_ratio`) and phase noise (`dynamics.temperature_ratio`) use Bose-Einstein thermal noise with `T/T_c ∈ (0, 1)`, driving `add_thermal_noise(psi, F; T_over_Tc, seed)`.

**Per-step dynamics knobs** (compose freely in a `dynamics:` block):

```yaml
dynamics:
  duration: 10.0
  dt: 0.005
  sgpe:              {gamma: 0.05, T: 0.1, mu: 0.0, k_cut: 6.0, every: 1, seed: 42}
  projected_gp:      {k_cut: 4.0, smooth: false, every: 1}
  photon_scattering: {Gamma_sc: 0.01, seed: 42}
  loss:              {gamma_dr: 0.02, K3_per_m_si: ["1.5e-30 m^6/s", ...]}
  pulse_sequence:    [...]
  save_psi_snapshots: true
  save_snapshot_precision: "f32"
```

`sgpe`/`projected_gp`/`photon_scattering`/`loss` blocks each return an
`on_step` callback; `pipeline_runner._compose_callbacks` chains them so
multiple can run together without conflict.

**Calibration** (lab-unit YAML preprocess — auto-applied by `run_yaml`):

```yaml
calibration:
  coil_strong: {gauss_per_mv: 0.4, gauss_offset: 0.05}
  fort:        {sqrt_coeffs_hz: [450, 450, 600]}
# OR week-to-week interpolation:
calibration_history:
  - {date: "2026-04-01", coil_strong: {...}, fort: {...}}
  - {date: "2026-04-15", coil_strong: {...}, fort: {...}}
target_date: "2026-04-08"   # optional, defaults to today
```

Lab-unit fields then expand: `zeeman: {p_mv: 2.5, coil_mode: strong}` →
`zeeman: {p: "X Gauss"}`; `trap: {fort_power_mw: [...]}` → `trap.omega: ["f Hz", ...]`.

**State zoo**: 22 named builders in `init_psi_<name>` shape (see
`src/workflow/initialization/state_zoo.jl`). All wrap the same
`init_psi(state=:..., init_state_params=...)` dispatch — same physics,
named API.

**Spinor LHY**: scalar approximation by default. To use the Lima-Pelster
two-channel table, set `ground_state.spinor_lhy: two_channel`.

**Continuation API** (direct-Julia, for benches/tests): `make_params(val) → NamedTuple` overrides any `find_ground_state` kwargs per sweep point. Legacy `make_interactions(val) → InteractionParams` also supported.

**GPU**: `import CUDA` before `using SpinorBEC` to load CUDA extension. Pass `backend=CUDABackend()`. WSL2 needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib`.

## Conventions (do NOT "fix")

- **DDI**: c_dd=μ₀μ² (no 4π), Q_αβ=k̂_αk̂_β−δ_αβ/3 (no 1/(4π)), Q(k=0)=0. Chain self-consistent.
- **ITP Zeeman shift**: subtracts min(E_m) to prevent overflow. Not a bug.
- **Scalar LHY**: `@warn` present. Known approximation.
- **`save_state` elseif branch** (`ddi_padded.ddi.C_dd`): unreachable dead code (ddi_padded only exists when ddi≠nothing).
- **Odd-rank c_extra ignored**: `@warn` present. KU's c₃≠rank-3 tensor.
- **`compute_interaction_params_general_f` returns (0,0)**: by design (tensor_cache handles all).
- **`_YOSHIDA_W0 < 0`**: correct (backward middle substep, all operators time-reversible).

## ¹⁵¹Eu

F=6, g_J=1.9934, g_F≈1.163, μ≈6.977μ_B, a_s≈110a₀. 7 unknown scattering channels (S=0,2,...,12). Constraint: c₀+36c₁=4π(a_s/a_ho)N.

## Constraints

- All structs in `types.jl` (included first). New structs go there.
- Workspace has 18+ type params — never write explicit type params.
- D=13 (Eu): SMatrix heap-allocates. Use Matrix/MVector in hot loops.
- `Val(N)` from type parameter, not `Val(ndim::Int)`.

## Type stability boundaries

`Workspace` has 23+ type params and `run_pipeline` dispatches abstractly on
`PipelineStep`. Any type widening in a `_run_step` branch (e.g. assigning
`zeeman = dict[:zeeman]` from `Dict{Symbol,Any}`) propagates to `make_workspace`'s
type parameter combinations, causing inference to explode — symptom is a **30 min
JIT hang with no stack trace**, not a runtime error. Prevent with two rules:

1. **`Dict{Symbol,Any}` → concrete struct: isolate in a helper function with
   `::ConcreteType` assertions.** The function boundary keeps `Any`-typed
   locals out of `_run_step`, and the type assertion tells the compiler the
   return-tuple elements are concrete. Never let `Any` flow into
   `make_workspace` kwargs directly. (`@noinline` is NOT required — verified;
   the function boundary plus type assertion is what defuses inference.)

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

2. **Never store closures (`FunctionWaveform(t -> ...)`, anonymous functions)
   in struct fields that flow into Workspace.** Each closure site has a unique
   type, multiplying specialization work. Pre-evaluate to `PiecewiseLinearWaveform`
   or `InterpolatedWaveform` (concrete types) before storing.

**Debug procedure** when JIT hangs:
- Direct-call the offending `_run_step(::ConcreteStep, ...)` — if fast, suspect
  abstract-dispatch propagation from `run_pipeline`.
- Check recent additions for `Dict{Symbol,Any}` extractions or closure creation
  in paths that reach `make_workspace`.
- `Cthulhu.descend(run_pipeline, (typeof(config),))` for deep inspection.

**User-supplied callbacks** (live_monitor `extract_observables`, simulation
`SimulationCallbacks.on_step`) accept `::Function` — these are OK in cold paths
but callbacks invoked in hot loops should parameterize: `struct Cb{F1,F2} ...`.

**Current cascade cost** (measured 2026-04-26, Julia 1.12.6, fresh JIT,
no cache): a single `run_yaml` for a trivial `pipeline:` with one
`ground_state:` step (Rb87, 32-pt 1D grid, 50 ITP steps) takes >4 min
to first output, dominated by `make_workspace` + `find_ground_state`
specialization for the freshly-emitted `Workspace{...23 type params...}`.
This is the reason `test_infrastructure.jl` / `test_zeeman_levels.jl`
gate 8 YAML integration tests behind `_SKIP_HEAVY_YAML_INFRA` /
`_SKIP_HEAVY_YAML_ZEEMAN` (default off; opt-in via
`SPINORBEC_RUN_HEAVY_YAML=true`). The nightly workflow
(`.github/workflows/nightly.yml`) flips that env var on cron so the
guarded blocks still get regression coverage without paying the cost
on every push.
