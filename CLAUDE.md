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
├── SpinorBEC.jl       # Thin umbrella (~93 LOC) — loads each subsystem umbrella below
├── foundation.jl       # → foundation/types/ (10 struct files) + math primitives
├── hamiltonian.jl      # → interactions/, potentials/, integrator/
├── analysis.jl         # → observables, energy, currents, vorticity, phases/, etc.
├── solvers.jl          # → ground_state/, lbfgs/, continuation/, simulation, twa, binary
├── rotating_basis.jl   # → Klaus-regime path (workspace, propagators, integrators)
├── precompile.jl       # PrecompileTools workload (dashboard hot path + RB primer)
├── cuda_graph_stubs.jl # split_step_captured! base methods (CUDA ext provides real)
├── foundation/         # types/{grid,spin_atom,sim_fft,...} + grid.jl, spin_matrices.jl,
│                       #   clebsch_gordan.jl, spherical_harmonics.jl, waveform.jl,
│                       #   binary_state.jl
├── hamiltonian/        # interactions/{ddi/, lhy/, ...}, potentials/, integrator/
├── dynamics/           # sinatra_helpers, utils_resolution_sinatra (TWA validity)
├── analysis/           # observables, ..., phases/{phase_classification, bogoliubov, ...}
├── solvers/            # ground_state/, lbfgs/, continuation/, simulation, twa, binary
├── rotating_basis/     # Klaus-regime files (workspace, propagators, integrators, ...)
└── workflow/
    ├── initialization.jl, io.jl, monitoring.jl, experiments.jl  # subsystem umbrellas
    ├── initialization/ # atoms, state_dispatch, make_workspace, state_zoo, *_noise
    ├── io/             # io.jl, save_rotating_result, vtk_export (stub), budget,
    │                   # run_summary, html_report, scan_summary, dashboard/
    ├── monitoring/     # ascii_plot, logging, resource_monitor, notifications,
    │                   # progress, live_monitor
    └── experiments/
        ├── schema/         # config_override + 13 parsing/builder files
        ├── runtime/        # adaptive_advice, pulse_sequence, sta_counter_diabatic, ...
        ├── analyzers/      # imaging, phase, topology, spectroscopy, stability, ...
        ├── pipeline/       # pipeline_types, runner, run_step_*, run_registry, pipeline_api
        ├── optimization/   # bayesian_opt(_mf,_yaml), faraday_fit, active_learning
        └── calibration.jl

ext/
├── SpinorBECCUDAExt/  # CUDA acceleration (CUDA in [deps]; ext is the dispatch site)
├── SpinorBECMakieExt/ # plot_density / animate_dynamics methods (Makie weak dep)
├── SpinorBECHTTPExt/  # send_slack_notification real method (HTTP weak dep)
└── SpinorBECVTKExt/   # export_vtk / export_vtk_series real methods (WriteVTK weak dep)

test/                  # 8451 pass + 2 broken in 8 subdirs mirroring src/ structure
```

Each subsystem umbrella `Foo.jl` is a flat-namespace file that just
`include`s its sub-files in dependency order. Public exports live next
to their definitions; the umbrella module re-declares only cross-cutting
extension stubs (CUDA Graph hooks, Makie viz placeholders).

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

**Mixed precision (rotating_basis only)**: set `dtype: f32` in the
`ground_state` block. Plumbs Float32 through Grid, V_trap, workspace,
FFT plans, DDI buffers. Eu thesis runs work; first-time JIT for the
F32 specialisation ~10 min then cached. Caveats: `apply_uniform_spin_rotation!`
+ `apply_ddi_step!` + `apply_spin_mixing_step!` keep their scalar Float64
locks (rotation builder + DDI dt + c1·dt) — these are scalar-only
boundaries, the per-voxel array work stays F32. `DDIParams.C_dd` stays
Float64 by struct definition (mixed: scalar F64, array F32). For the
full picture see `test/test_rotating_basis_f32.jl`. F64 is the default.

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

**`phi_omega` Hz form** (rotating_basis B̂ rotation, dynamics block):
`phi_omega: 4.524` (dimensionless ω/ω_ref) and `phi_omega: "226.2 Hz"` are
equivalent. The Hz form converts via `(2π·f) / ω_ref` using the `omega_ref`
declared in the parent `ground_state.interactions`. `phi_chirp.{from,to}`
accept the same forms. Eliminates the documented Klaus 2022 magnetostir
2π footgun (MEMORY.md `gotcha_waveform_frequency_convention.md`).

**YAML schema overhaul (2026-04-30, 8 phases)**: 5 opt-in pre-parse
stages applied between calibration and schema validation:

```yaml
units: {B: Gauss, ω: Hz, t: ms}      # bare Reals → quantity strings
accuracy: 1.0e-6                     # → epsilon: on rotating_basis steps
auto_grid: true                      # → grid: from TF radius

template: klaus_magnetostir          # → 4-phase pipeline
parameters: {atom: Eu151, B_static: "1 Gauss", ...}

defaults: {kind: rotating_basis}     # seeds every step's missing fields
mixins: {eu151_phys: {atom: Eu151, ...}}  # named param sets, use: [...] to import

scan:
  zip:
    parameters.stir_freq:
      from: "50 Hz"  ; to: "900 Hz"  ; n: 8  ; scale: log
```

zeeman additive composition: `sources: [{B_mag: "1G", theta_deg: 35},
{Bx: ...}]` for L2 base + L1 perturbation. ε hardening: `epsilon ≥ 1e-3
+ p·F·dt > π` is now a hard error (not warn).

Showcase: `runs/samples/eu151_klaus_lab_units/config.yaml` (25 lines)
reproduces the 4-phase Klaus protocol that legacy YAML wrote in 65
lines (62% reduction). Both `runs/phi_omega_scan/` and
`runs/berry_crossover_scan/` migrated 2026-04-30. Migration to existing
configs is OPT-IN: legacy bare-Real YAMLs continue to parse unchanged
(no behavior change without `units:` / `template:` / `accuracy:` etc.).
Memory: [yaml_lab_units_design](yaml_lab_units_design.md).

**State zoo**: 22 named builders in `init_psi_<name>` shape (see
`src/workflow/initialization/state_zoo.jl`). All wrap the same
`init_psi(state=:..., init_state_params=...)` dispatch — same physics,
named API.

**LHY config** (refactored 2026-05-12): single `lhy:` block inside the
`ground_state` step. `kind` selects the mode; `c_lhy` is auto-derived
via Lima-Pelster Q5(ε_dd) when omitted for `scalar` / `quasi_2d`.

```yaml
ground_state:
  lhy:
    kind: scalar | quasi_2d | two_channel | full_bdg |
          polar_contact | polar_dipolar | fm_contact | fm_dipolar |
          icosahedral | none
    c_lhy: <override>   # optional; auto-derived for scalar / quasi_2d
    n_max: <override>   # null → 3 × max(|psi_init|²)
    n_points: 200
```

Legacy keys `interactions.c_lhy` + `ground_state.spinor_lhy` were
removed in C6 of the refactor; configs must use the `lhy:` block.

**Continuation API** (direct-Julia, for benches/tests): `make_params(val) → NamedTuple` overrides any `find_ground_state` kwargs per sweep point. Legacy `make_interactions(val) → InteractionParams` also supported.

**GPU**: `import CUDA` before `using SpinorBEC` to load CUDA extension. Pass `backend=CUDABackend()`. WSL2 needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib`.

## Conventions (do NOT "fix")

- **DDI**: c_dd=μ₀μ² (no 4π), Q_αβ=k̂_αk̂_β−δ_αβ/3 (no 1/(4π)), Q(k=0)=0. Chain self-consistent.
- **ITP Zeeman shift**: subtracts min(E_m) to prevent overflow. Not a bug.
- **Scalar LHY**: `@warn` present. Known approximation.
- **Odd-rank c_extra ignored**: `@warn` present. KU's c₃≠rank-3 tensor.
- **`compute_interaction_params_general_f` returns (0,0)**: by design (tensor_cache handles all).
- **`_YOSHIDA_W0 < 0`**: correct (backward middle substep, all operators time-reversible).

## ¹⁵¹Eu

F=6, g_J=1.9934, g_F≈1.163, μ≈6.977μ_B, a_s≈110a₀. 7 unknown scattering channels (S=0,2,...,12). Constraint: c₀+36c₁=4π(a_s/a_ho)N.

## Known limitations / open issues (NOT bugs — design boundaries)

These are documented quirks; do not "fix" without explicit user discussion.

- **F ≥ 2 spinor LHY with `c_extra ≠ 0` is research-open.** `TwoChannelLHY`
  is F-generic in formula (uses `2F · |c1|^(5/2)`) but parameterises ONLY
  the (S=0, S=2) channels via (c0, c1). For F=1 it's exact. For F ≥ 2 with
  `c_extra = 0` it stays consistent with the mean field (still a valid
  approximation). For F ≥ 2 with `c_extra ≠ 0` the S ≥ 4 channels are
  silently missing from the LHY — use the closed-form `TabulatedLHY`
  subtypes instead (`PolarContactLHY` / `PolarDipolarLHY` for polar,
  `FMContactLHY` / `FMDipolarLHY` for FM, `IcosahedralLHY` for F=6 I_h).
  F=6 polar + `FullBdGLHY` emits a `@warn` pointing at the closed forms
  (~3000× spurious offset, see memory full_bdg_F6_polar_broken.md).
- **`apply_nematic_step!` is the S=0 singlet-pair Hamiltonian, NOT the
  rank-2 nematic tensor observable.** Naming is legacy. Observable side
  is `nematic_tensor_eigenvalues` (different function). Do not conflate.
- **`secular_ddi=true` is the user's decision**, not auto. `make_workspace`
  emits an `@info` advisory when `ω_L / (c_dd · ⟨n⟩) > 100` — Eu experiments
  almost always live in this regime.
- **`spin_rotating_frame_omega ≠ 0` requires `secular_ddi=true`.** Now
  enforced via `ArgumentError` in `make_workspace`. Reason: full DDI's
  off-diagonal components rotate at ω_R and only Larmor-average to zero in
  the secular limit.
- **`even_c_extra(F; c2, c4, c6, …)` is the canonical way to construct
  `c_extra`.** Hand-written `[c2, c4, c6]` (length 3) silently misindexes
  for F ≥ 3 because c_extra[idx] = c_{idx+1} (so odd slots must be 0).
- **`Workspace` 23+ type params can JIT-hang for 30 min**. See "Type
  stability boundaries" below — the operative discipline (helper-fn
  boundary + `::ConcreteType` narrow + no closures in struct fields) is
  load-bearing. A "small refactor" here can cost an evening.
- **Bogoliubov k=0 Goldstone mode — diagnosis was wrong, code is right.**
  Earlier note here claimed `_bdg_k_scan` had a μ convention bug
  producing a residual k=0 gap (F=1: gap ≈ 0.4, F=6 DDI: gap ≈ 1440).
  Re-audit on 2026-05-02 found the actual cause was a TEST INDEXING
  bug: `test_bogoliubov_goldstone.jl` sliced the BdG omega matrix as
  `omega[1, :]` (row 1 across all k columns), but `_bdg_k_scan` writes
  eigenvalues into `omega[:, ik]` in LAPACK-arbitrary order returned
  by `eigen(L)`. Picking the row-1 eigenvalue at every k is meaningless;
  the F=6 case happened to land on the largest eigenvalue
  (≈ ±c_dd·Q_zz·F·m·n₀). Correct slice is `omega[:, 1]` — all
  eigenvalues at the smallest k. With that, F=1 gives 2 zeros at k=0
  (gauge + 1 spin Goldstone), F=6 DDI gives 4 zeros (gauge + 3 spin
  Goldstones for SU(2) → U(1)). μ convention is correct. Test now
  asserts `gap < 1e-6` directly (no `@test_broken`).
- **`split_step_captured!` on GPU silently falls back to `split_step!`.**
  CUDA Graph capture is implemented in `ext/SpinorBECCUDAExt/gpu_graph.jl`
  but currently disabled — replay drift from per-call broadcast allocations
  (e.g. `cis.(m_gpu .* α)` recreates CuArrays each frame, invalidating
  captured kernel arg pointers). Bench shows captured 4× slower than plain
  on the current code path. The bench helper
  `gpu_graph.jl::bench_split_step_capture` exists to validate any future
  re-enable. Until then `split_step_captured!(::Workspace{N, <:CuArray})`
  is a transparent alias for `split_step!`.
- **`_get_spinor(psi, I, Val(13))` allocates ~352 bytes / call at D=13.**
  Measured in microbench (16k voxels × 1k iter → 5.5 GB). Inside real
  hot loops (`_spin_mixing_loop!`, `apply_raman_step!`) the compiler may
  elide some via SROA, but the call site still costs allocation when
  `c1 ≠ 0` and Eu151 F=6. Future work: an `_apply_euler_spin_rotation!`
  variant that operates in-place on `psi` slabs without round-tripping
  through `SVector{13, ComplexF64}`. Not relevant to rotating-basis
  (Option γ) path — that one uses gemm-form rotation instead.

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
