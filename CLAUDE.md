# CLAUDE.md

Arbitrary-F spinor Gross–Pitaevskii simulator (split-step Fourier, 1D/2D/3D, CPU + CUDA, Julia-defined experiments). Primary production target: ¹⁵¹Eu at F=6 (13 components). Internal units: ℏ = m = ω_ref = 1.

This file is the **structural fixed-point** — design rules that survive across incidents. Per-incident lessons live in memory.

## Reading map

Read `docs/STATE.md` first for derivable facts, then the architectural commitments
and the sections below relevant to the task. This map is navigation; the linked
sections retain the full requirements.

| Task | Required sections / sources |
|---|---|
| Locate code or choose a layer | [Project structure](#project-structure), [Subsystem catalog](#subsystem-catalog), `docs/index.md` |
| Change physics or add a term | [Wavefunction conventions](#wavefunction-conventions), [HamTerm protocol](#sign-bug-proof-discipline-hamterm-protocol), [Conventions](#conventions-do-not-fix), [Design boundaries](#design-boundaries-intentional-non-support) |
| Add an API, step, analyzer, or schema key | [Adding common artifacts](#adding-common-artifacts), [Naming convention](#naming-convention), [Type stability boundaries](#type-stability-boundaries) |
| Choose validation and tests | [Commands](#commands), [Test taxonomy](#test-taxonomy--oracle-gates), [Validation ladder](#validation-ladder), `docs/conventions/testing_strategy.md` |
| Start an investigation or launch simulations | [Prior art](#before-starting-a-topic--enumerate-the-open-work-and-disposition-it), [Compute gates](#before-computing--five-gates), [Cost model](#cost-model--execution-discipline) |
| Audit a corpus or maintain memory | [Calibrated scans](#measuring-never-write-a-bespoke-scan), [Memory](#memory--claudemd-split) |

For derivable facts, `docs/STATE.md` wins over this file. For campaign execution,
read `docs/campaign/CAMPAIGN.md`; for physics claims, check
`docs/campaign/claims.toml`. FROZEN documents are dated evidence, not current
instructions. Structural rules live here; incident-specific lessons live in memory.

### Authority and maintenance

- `docs/STATE.md` derives the current registry, operator chain, schemas, tiers,
  cache contracts, and known limits. Regenerate with
  `julia --project=. scripts/generate_state.jl`; do not edit it by hand.
  `test/test_state_doc_is_current.jl` checks freshness. The generator's coverage
  disclosure matters: a green comparison cannot prove coverage of an unmodeled
  subsystem. Extend derivation and its coverage controls when the system grows.
- `docs/campaign/claims.toml` records claim status, scope, uncertainty, evidence,
  producing commit, and retractions. Keep uncertainty explicit (including
  `unbounded: <reason>`). Refuted claims need not have a replacement. Update the
  ledger instead of adding another list of retired numbers; point-of-use
  retraction gates derive from it. Prospective `Claim` and retrospective
  `LedgerClaim` have different jobs.
- `docs/conventions/testing_strategy.md` defines what evidence a test supports;
  `docs/design/hamiltonian_layered_architecture.md` explains the Hamiltonian design.
  The sign audit and sign-bug-proof architecture documents under conventions are
  FROZEN historical evidence. The current HamTerm procedure is below.
- Read `docs/conventions/klaus_name_disambiguation.md` before writing "Klaus":
  the paper, fast-Larmor regime, and this project's protocols are distinct.
- `test/helpers/live_docs.jl` declares maintained documents under `docs/`;
  other documents require a dated FROZEN header. A directory name such as
  `reference/` or `design/` does not establish that a document is current.
- `AGENTS.md` routes here. `.codex/agents/` contains optional task roles, not a
  scheduler. The former autonomous research loop was retired; do not recreate
  its output tree or assume an external harness exists in this checkout.

Keep structural rules here, task references at their existing authority, and
incident narratives in dated records or git history. Do not duplicate enumerations
that code or a ledger can derive. When changing instructions, check their callers,
role prompts, links, and documentation gates as well as the edited paragraph.

## Commands

Run from the repository root. `Project.toml` defines Julia compatibility;
`.github/workflows/ci.yml` defines the CI version and required jobs. Locate Julia
on the current host instead of copying an absolute path from another machine.

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")'
julia --project=. scripts/cli.jl <subcmd> [args]
julia --project=. scripts/generate_state.jl
```

These assignments use Bash. In PowerShell set
`$env:SPINORBEC_TEST_TIER = 'fast'` before invoking Julia. WSL2 GPU runs may need
`LD_LIBRARY_PATH=/usr/lib/wsl/lib`; that path is specific to WSL2.
Tests invoking `bash` need a working Bash on PATH; on Windows, verify that it
resolves to Git Bash or a configured WSL installation, not an inactive app alias.

Choose checks by the changed behavior. Explicitly select a tier: the default
`Pkg.test()` runs `full`, which is expensive. Tier definitions and runner knobs
live in `test/_tiers.jl`, `test/runtests.jl`, and README's Tests section.
For GPU changes, load CUDA and run a device test at a dimension that reaches the
changed code; a CPU-only pass does not establish device coverage.

## Project structure

Use `docs/STATE.md` for inventories and `docs/index.md` for the documentation map.
The subsystem catalog below describes ownership rather than enumerating every file.

- `src/` contains layered Julia code; umbrella files include dependencies in order.
  Public exports live beside definitions. Promote a subsystem to a real module
  when it has an independent design lifecycle.
- `ext/` contains backend and optional integrations. Read extension triggers from
  `Project.toml`; CUDA is not a weak dependency.
- `test/` mirrors source areas, with independent physics checks in `test/oracles/`.
- `scripts/` contains operational entry points, gated by
  `test/test_scripts_allowlist.jl`. Do not accumulate one-off drivers there.
- `runs/` contains experiment inputs and stored results. Inspect relevant siblings
  before defining a new experiment; preserve user-owned inputs and outputs.
- `bench/` contains performance probes; `docs/` contains guides, theory, and records.

Features touching physics, storage, analysis, and pipeline execution belong in
those respective layers. The rotating-basis implementation is the worked example.

## Architectural commitments

1. **Arbitrary-F first.** Design formulas, observables, and analyzers for general F.
   F=6 Eu is the production target; F=1 is a debugging and analytic limit.
2. **Composable physics.** Keep Hamiltonian terms, loss, and noise independently
   composable through propagators and callbacks.
3. **No silent sign, factor, or term drift.** Independent fast and reference
   statements are deliberate redundancy, gated from their first commit. Include
   directional physics anchors and a mutation proving the gate can fail. Ungated
   duplication is forbidden. Design authority:
   `docs/design/hamiltonian_layered_architecture.md`.
4. **Content-addressed computation with provenance.** `Experiment(spec)` and
   `run_experiment` use `content_id(spec)`. Julia definitions are evaluated
   before keying; source comments and filenames do not change conditions.
   Reusing a point requires matching recorded code provenance and clean trees.
   Do not implicitly enable `SPINORBEC_ALLOW_STALE_POINTS`; report any override.
5. **Julia experiment definitions, persistent snapshots.** Use `PipelineConfig`
   and typed steps; share protocols as Julia functions. `run_experiment` persists
   input and resolved conditions as JSON. Do not add YAML or TOML input compatibility.
6. **Separate validation claims.** Code correctness, agreement with analytic
   physics, and agreement with experiments are different claims (A/B/C below).
7. **Explicit test tiers.** Register every new test in `test/_tiers.jl`.
   Each file must run independently, with its own imports and helpers, and without
   shared fixed temporary paths. Keep heavy solver tests behind their existing guard.
8. **Protect type stability.** No `Any`-typed local or stored closure may flow
   into `make_workspace`. Retain dispatch annotations as a precaution; the
   2026-08-04 measurements did not reproduce the historical hang by removing
   annotations alone. See Type stability boundaries for the implementation rule.
9. **Names follow behavior.** File names, exports, and analyzer names agree.
   Migrate callers when renaming; no old-name aliases by default or version suffixes.
10. **Pay for evidence deliberately.** Estimate resources, smoke-test the actual
    backend before a long launch, and record completion status. See Cost model.
11. **A new single source of truth ships with migration enforcement.** In the same
    change, migrate callers or gate against new uses of the old form. A new API
    with unguarded legacy callers leaves two live declarations. Gate production
    consumers, not only an unused replacement implementation.
12. **Execute the rejected case before relaxing a constraint.** Construct an input
    the guard rejects, run the proposed relaxed behavior, then decide. Preserve a
    test of the guard's premise so it fails when that premise stops being true.
    A contradictory test is evidence to investigate, not an obstacle to remove.

## Workflow model (spec → CAS → run → observe)

Author new experiments using `PipelineConfig` with typed steps (README has a
minimal example). `Experiment(config)` converts to a serializable spec and owns
storage plus lazy observations. `run!(exp)` executes; `Fz_t(exp)`, `Lz_t(exp)`,
`energy_t(exp)`, `density(exp, t)`, and `classify(exp)` read cached results.
`write_run!(exp)` writes the snapshot for dispatch. Implementation:
`src/workflow/experiment.jl`.

`run_experiment(config_or_snapshot)` persists `config.json`, resolved conditions,
per-point JLD2, progress, and exit summaries. `run_experiment(path)` evaluates
Julia definitions or resumes generated JSON snapshots. `load_config(path)` and `run_pipeline(config)` provide the
in-memory path. Check `src/workflow/experiments/pipeline/run_registry.jl` and
`src/workflow/experiments/runtime/config_artifacts.jl` when changing persistence.

Collections are `Vector{Experiment}`, not a new batch abstraction. Use Julia
comprehensions for typed definitions; existing Dict helpers `sweep(base; over=...)`,
`twin(exp)`, `tabulate(exps, observables)`, and `spec_diff(a, b)` are in
`src/workflow/experiment_collections.jl`. Keep override syntax specific to the
entry point; dotted parameter paths and the single-axis `sweep` symbol are not identical.

Validation uses `ConservationSpec(; norm_drift=..., energy_rel_drift=..., Jz_drift=...)`,
`OperatorRHSSpec(; tol_hpsi=..., tol_per_term_E=...)`, and `check(spec, result)`.
Operator-RHS comparison requires saved Hψ. Failed checks return `CheckResult`
rather than throwing. See `src/workflow/validation/specs.jl`.

**Inspect stored results before recomputing.** Use `reanalyze(series, dirs;
observable, declare)` in `src/workflow/validation/reanalysis.jl`. Declare the
window, reduction, and boundary rule before reading; carry producing vintage and
machine-readable admissibility. A clean tree alone does not establish campaign
eligibility. Boundary rejection withholds an edge argmax; oversized windows must
fail per arm rather than silently clip. `hold_window_frames(hold; dt, save_every)`
requires the actual cadence. Use the multi-observable form for one shared read.
Stored-run readers must be migrated with their reference reduction or explicitly
classified by `test/test_reanalysis_driver_coverage.jl`. Evidence and limitations:
`docs/validation/store_reuse_census.md`.

## Subsystem catalog

| Area | Ownership and local discipline |
|---|---|
| `src/foundation/types/` | Cross-cutting structs; subsystem-local types stay with their machinery. Never spell out Workspace type parameters. |
| `src/hamiltonian/terms/` | Term faces and kernels. Shared channel conversion is `src/hamiltonian/coefficients.jl`; shared spin rotation is `src/foundation/spinor_utils/uniform_rotation.jl`. Follow the HamTerm protocol below. |
| `src/hamiltonian/integrator/` | Split-step composition and rotating basis. `spin_chain` is fusion, not another splitting: adding an outer operator also requires updating `_spin_chain_reason`. |
| `src/hamiltonian/tdhfb/` | Parallel engine to GP; no pipeline integration without an explicit request. |
| `src/analysis/` | Observables, energy, imaging, spectra, and phases. `_get_spinor(psi, I, Val(D))` needs D from a type parameter; benchmark the relevant overload. Bogoliubov k-mode 1 is `omega[:, 1]`. |
| `src/solvers/` | Ground state, dynamics, continuation, and stochastic solvers. `find_ground_state_lbfgs` returns `grad_norm` recomputed at the returned state. Continuation's caller-supplied `make_params(val)` returns a NamedTuple or `InteractionParams`. Draw stochastic noise on-device with `_randn_fill!`; TWA spread is not proof of thermalization. |
| `src/workflow/experiments/` | Typed steps, config parsing, runtime conversion, analyzers, and execution. Check schema and sibling configs; do not infer accepted keys from a historical guide. |
| `src/workflow/initialization/` | Species and state builders. Named states wrap `init_psi(state=..., init_state_params=...)`; do not fork its physics. For transverse x, use `init_psi_spin_coherent(grid, sys; theta=π/2, phi=0)`. |
| `src/workflow/experiments/calibration.jl` | Lab-field calibration precedes unit parsing; drift and history are part of the calibration module. |
| `src/workflow/experiments/optimization.jl` | Optimization module and objectives. Expensive GP fitting belongs in heavy tests. |
| `src/model/` | Model, identity, admission, and claim contracts. Inspect actual consumers before assuming an architectural migration is complete. |
| `src/validation/` | Independent RHS and dumb-reference physics statements. External-comparison status lives in `docs/validation/ueda_status.md`. |
| `src/manuscript/` | Figure registry and CSV/Python/TikZ emitters; CLI via `scripts/cli.jl figure`. |

## Wavefunction conventions

- Layout: `psi[x, y, ..., c]`; spatial dimensions first, spinor last.
  `c=1 → m=F` and `c=D → m=−F`.
- Strang composition is `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`.
  The outer-potential chain is `OUTER_CHAIN` in
  `src/hamiltonian/integrator/split_step.jl`; reverse traversal derives the
  backward half, with DDI between halves. Do not re-enumerate substeps here.
  `OUTER_CHAIN_TERMS` and its external-term mapping must cover every registry slot.
- Interaction paths are auto-selected in `make_workspace`: the c₀/c₁ path uses
  `diagonal(c₀) + spin_mixing(c₁) + singlet_pair(c₂) + tensor(residual c₄, c₆, ...)`;
  on the scattering-lengths path the tensor handles all channels and c₀=c₁=0.
- Config keys, LHY kinds, opt-in lab-unit features, and defaults are defined by the
  schema and derived in `docs/STATE.md`. Read
  `docs/reference/yaml_schema_reference.md` and `docs/reference/dynamics.md`
  for usage, checking the implementation when changing behavior.
- `phi_omega` in Hz converts as `2πf/omega_ref` using the parent reference
  frequency. Calibration resolves lab fields before unit parsing.
- `temperature_ratio` seeds a heuristic symmetry-breaking kick through
  `add_thermal_seed(psi, F; T_over_Tc, seed)`, not a thermal Wigner sample.
  Use SGPE for thermal initialization.
- Tabulated LHY stores `V=dε/dn`. Energy is the integral of the same interpolated
  V, not `n*V(n)`. CPU energy and GPU propagation both need parity gates:
  `test/hamiltonian/test_lhy_energy_convention.jl`,
  `test/gpu/test_gpu_tabulated_lhy_parity.jl`, and
  `test/gpu/test_gpu_tabulated_lhy_fused_diagonal_parity.jl`.
- For CUDA, `import CUDA` before `using SpinorBEC`; use `CUDABackend()`.
  Never broadcast host grid/weight/mask arrays against device ψ. Use
  `_to_device(ws.backend, a)` or `_to_device_cached` for workspace-lifetime
  arrays; check both operands of mapreduce too. Review `grid.` accesses and local
  arrays in every GPU diff. Device tests must reach the relevant dimension/path.
- Float32 support is path-specific; verify it in the intended solver. In the
  rotating-basis path, array work can be F32 while scalar rotation/DDI/spin-mixing
  coefficients retain Float64. Separate first-JIT cost from steady-state performance.

## Sign-bug-proof discipline (HamTerm protocol)

Declare each term's sign once in its coefficient function, such as
`_diag_coef(term, m)`. Energy and gradient use `build_h_terms_registry(ws)`;
the production propagator uses fused kernels and `OUTER_CHAIN`. Do not replace
fusion with per-term iteration merely because `apply_step!` exists.
Keep fast/reference statement pairs independently implemented and gated.

`apply_operator!` **accumulates** `out .+= H*ψ`. Callers zero the output;
terms never clear it. Inactive terms return early. Use context-aware
`energy_contribution` and `apply_operator!` methods where shared
`EnergyContext` / `GradientContext` scratch avoids repeated work.

The Zeeman operator is `-(b·F) + q(b̂·F)²`; quadratic Zeeman follows the field
axis. For an axial field this becomes `-p*F_z + q*F_z²`.
The lab conversion `p = -g_F*μ_B*B` is declared only in `Units.bfield_to_p`
(`src/workflow/io/units.jl`); all converters delegate. For g_F>0, +Bz
has ground state m=-F. A transverse field changes the quadratic axis too.

**Adding a new HamTerm — protocol**:

1. Put the term beside its kernels in `src/hamiltonian/terms/`. Implement a
   `HamTerm` subtype, one coefficient/sign declaration, and the inactive guard.
2. Implement `apply_step!`, `energy_contribution`, and accumulating
   `apply_operator!`, including the relevant CPU/GPU and scratch-context paths.
3. Supply `sign_oracle(::Type{YourTerm})` with a directional physics predicate,
   not an always-true placeholder or an identity that cannot reject a wrong sign.
4. Add the include in `src/hamiltonian.jl` and register the term and ordering in
   `src/hamiltonian/terms/registry.jl`. Check the derived energy-breakdown keys
   and any legacy field mapping.
5. Add the independent statement to `src/validation/dumb_reference.jl`.
   Wire the actual propagator and its outer-chain mapping; update
   `_spin_chain_reason` so unsupported fusion cannot silently drop the new term.
6. Add active fixtures, directional and finite-difference oracles, and CPU/GPU
   parity where applicable. Register tests in `test/_tiers.jl` and include a
   mutation showing the relevant wrong sign/factor/omission is detected.
7. Run the affected gates in Test taxonomy below. Regenerate `docs/STATE.md`
   when its derived state changes. Report any path that could not be executed.

This is the canonical procedure. `docs/conventions/adding_new_hamiltonian_term.md`
is a pointer; the frozen sign audit provides historical context.

## Test taxonomy + oracle gates

Register tests in `test/_tiers.jl`; discovery does not add them automatically.
Per-PR CI uses explicit smoke views in `test/_smoke.jl`; nightly runs `full`,
including the deferred tests. `test_tier_membership.jl` gates those separately.
CI uses the Julia version in `Manifest.toml` and a portable smoke cache.
Heavy solver blocks retain the legacy guard `SPINORBEC_RUN_HEAVY_YAML=true`.

Select gates by the changed contract; these are entry points, not an exhaustive
test inventory:

| Contract | Gate |
|---|---|
| Independent term energy/RHS agrees with production | `test/oracles/test_master_oracle.jl` |
| Every energy-bearing registry term has an active FD fixture | `test/oracles/test_term_fd_registry_coverage.jl` |
| Sign is anchored to physical direction | `test/oracles/test_hamiltonian_sign_oracles.jl` and `test/oracles/test_physics_aware_sign_oracles.jl` |
| Registry and production propagator coverage agree | `test/oracles/test_outer_chain_registry_mapping.jl` |
| Device implementation agrees per active term | `test/oracles/test_gpu_cpu_per_term_parity.jl` |
| Energy and gradient registry interfaces agree | `test/oracles/test_registry_energy_decomposition_parity.jl` and `test/oracles/test_registry_gradient_parity.jl` |
| New term face preserves its legacy contract | `test/oracles/test_term_legacy_equivalence.jl` |
| A mutating potential path still contributes to energy | `test/oracles/test_magnetic_gradient_gap.jl` |

Keep historical regression tests whose contracts survive a refactor; retarget the
contract rather than deleting coverage with the old function. Inspect existing
save-cadence, rotating-frame, and validation-ladder gates for the affected path.

## Validation ladder

Instrument names, paths, and missing levels are derived in `docs/STATE.md`.
Do not maintain a second ladder table here or infer coverage from a level number.

- **A: code correctness** — units, sign, conservation, bit-identity, GPU = CPU.
- **B: physics agreement** — closed-form limits, F=1 polar/FM, polyhedral classification.
- **C: model fidelity** — published experimental data (Klaus et al. 2022, Matsui Eu Bogoliubov cascade, Prasad 2019 vortex, Yan-Li-Saito Barnett).

Reports state which type the evidence supports. Read
`docs/conventions/testing_strategy.md` for grounding methods and claim × path
coverage. `test/_inventory.jl` and `test/mutation/` expose coverage and sensitivity.
A variational bound can refute an extremum on the wrong side of a trial value
without trusting either solver; see `variational_bound`.

## Conventions (do NOT "fix")

Changing these requires evidence about the guarded behavior, not intuition.

- `trapped_bdg_low_modes` returns Hessian eigenvalues, not frequencies:
  `ω = √(λ₊λ₋)/2`. Use `trapped_bdg_frequencies` for excitations and inspect
  `spectrum_reached`; false means the null manifold prevented reaching a
  spectrum. `bragg_response` gives dynamic S(k,ω); quote its
  `omega_resolution = 2π/T` with peaks. Static S(k) is frequency-integrated.
  Energetic instability and dynamical growth are distinct axes.
  See `docs/design/trapped_spinor_bdg_spectrum.md`.
- DDI: `c_dd = μ₀μ²` (no 4π), `Q_αβ = k̂_α k̂_β − δ_αβ/3` (no 1/(4π)),
  and `Q(k=0) = 0`.
- ITP subtracts `min(E_m)` from Zeeman energies to avoid overflow.
- Scalar LHY's warning documents an approximation; do not suppress it as noise.
- `_YOSHIDA_W0 < 0` is the intentional backward middle substep.
- Zeeman signs follow the HamTerm section; never add another lab-field converter.
- Odd-rank `c_extra` is rejected, not ignored. Even ranks use a rank-keyed Dict:
  `interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra=Dict(4 => c₄, 6 => c₆))`.
  See `src/hamiltonian/coefficients.jl`; positional channel arrays can misindex.
- On the scattering-lengths path, `tensor_cache` carries all channels and
  c₀=c₁=0 deliberately.
- Secular DDI is user-chosen. The `make_workspace` advisory recommends it in
  the fast-Larmor regime; an advisory does not silently change the model.

## Design boundaries (intentional non-support)

- `PolarTwoChannelLHY` is polar-only and inaccurate at F=6. For polar states
  use `PolarContactLHY` / `PolarDipolarLHY` within their domains; for FM use
  `FMContactLHY` / `FMDipolarLHY`. `IcosahedralLHY` is specifically F=6 I_h,
  not a substitute for a polar state.
- `IcosahedralLHY` refuses negative spin-mode eigenvalue (c₁<0) and table
  construction rejects non-finite values. Use the general `FullBdGLHY` path
  for states outside the closed-form ansatz; do not revive the retired assertion
  that its F=6 polar UV counterterm is broken. Parity is gated by
  `test/oracles/test_lhy_full_bdg_closed_form_parity.jl`.
  Dynamically unstable mean fields still make LHY scheme-dependent; consult
  `docs/theory/lhy_scheme_selection_eu_f6.md`. Prefer cheaper closed forms when
  their assumptions hold.
- The combined L-BFGS preconditioner `P_C` is off by default because measured
  weak-field Eu+DDI performance was worse. Do not infer that all preconditioning
  is ineffective or attribute the cost to an exact Goldstone without evidence.
  See `docs/design/lbfgs_speed_limits.md` for the dated analysis.
- Nonzero `spin_rotating_frame_omega` requires `secular_ddi=true`.
- CUDA graph replay in `ext/SpinorBECCUDAExt/gpu_graph.jl` is disabled after
  drift and performance regressions.
- Nonspatial spinor LHY uses one spinor for the cloud (peak-density for full BdG,
  fixed ansatz for closed forms). `SpatialLHY` resolves density/polarization
  variation but polarization alone does not specify the spinor; quote
  `spatial_lhy_residual` with results using it. A texture warning requires
  assessing this approximation, not hiding the warning.
- Tensor channels participate in registry-driven `energy_gradient!`; the old
  "tensor forces an ITP fallback" limitation is retired.
- TDHFB is a parallel engine with no pipeline integration. Add that integration
  only on an explicit request; do not invent a `dynamics.tdhfb` key.

## Adding common artifacts

| Adding… | Where | Enforced by |
|---|---|---|
| Hamiltonian term | `src/hamiltonian/terms/<name>/` (faces in `<name>_term.jl`, engine kernels alongside; single-file terms stay `terms/<name>.jl`) + register in `build_h_terms_registry` + `H_TERMS_CANONICAL_ORDER` + a dumb statement slot in `validation/dumb_reference.jl` (set-equivalence meta-test enforces) | Oracle suite (above) + master oracle. |
| Pipeline analyzer | `src/workflow/experiments/analyzers/<name>.jl` + dispatch in `_run_analyzer` | Analyzer name = real function, not stub alias. Round-trip `analyze: [{<name>: {}}]` should produce data labelled `<name>` literally. |
| State init | `src/workflow/initialization/state_zoo.jl` wrapper around `init_psi(state=:..., init_state_params=...)` | Same physics, named API. Don't fork `init_psi`; wrap. |
| Pipeline step kind | `pipeline/pipeline_types.jl` (struct) + `pipeline/run_step_<kind>.jl` (handler) + branch in `_step_dispatch!` | `_step_dispatch!` branch is the inference firewall — keep `@nospecialize(step)`. |
| Validation spec | `src/workflow/validation/specs.jl` (struct + `check` method) | Per-observable bounds + `CheckResult`; failed checks must not throw. |
| BO objective | Closure to `bayesian_optimize_config(...; objective=...)` or new `bo_objective_<name>` in `optimization/bayesian_opt_config.jl` | Signature: `(result) → Float64`. Keep closures monomorphic in hot loops. |
| Manuscript figure | `src/manuscript/figures/<paper>_FIG<N>.jl` + register | CLI: `scripts/cli.jl figure --paper <p> --fig <n>`. Emitters: CSV / Python / TikZ. |
| Atom species | `src/workflow/initialization/atoms.jl` + entry in `ATOM_REGISTRY` | Constraint `c₀ + 36 c₁ = 4π(a_s/a_ho)N` for F=6 — see "¹⁵¹Eu". |
| Schema key | `src/workflow/experiments/schema/<block>.jl` + `auto_defaults.jl` if it has a sensible default | `inspect_config` should classify malformed values as `:error`/`:warn`, not silently accept. |

## ¹⁵¹Eu

Species constants live in `src/workflow/initialization/atoms.jl`; read them rather
than maintaining a second table here. F=6 has seven even scattering channels.
The stretched channel a₁₂ is measured; the other six are unmeasured. Do not invent
them. The constraint is `c₀ + 36c₁ = 4π(a_s/a_ho)N`. Claim dependence on
unmeasured channels is tracked in `docs/campaign/as_dependency_map.md`.

## Constraints

Cross-cutting structs go in `src/foundation/types/`; subsystem-local structs stay
with their implementation. Workspace parameters are derived in `docs/STATE.md`;
never specify them explicitly.

At D=13, prefer `Matrix` / `MVector` in hot paths over large `SMatrix` fields.
Construct `Val(N)` from a type parameter, not `Val(ndim::Int)`. Preserve the
dispatch boundary and enforce the rules in Type stability boundaries.

## Naming convention

Semantic mismatch is not type-visible — static analysis cannot catch file/function/observable drift.

- **File name = primary export.** `src/foo/bar.jl` defines `bar`, `apply_bar_step!`, `BarLHY`. Rename file in same commit as its primary symbol.
- **Function name = what the body actually computes.** Renames delete the old name; no `const Old = New` aliases by default; migrate callers in same commit.
- **Pipeline analyzer names = real implementations**, not stub aliases. Aliased dispatch through unrelated functions is a silent-bug factory.
- **Backward-compat aliases default to "delete".** Keep one only with load-bearing documented external consumer.
- **No version suffixes** (`eu_ham_only_24_nonsec`, not `step5_v2`). Name by content.

## Type stability boundaries

`Workspace` is heavily parameterized (see `docs/STATE.md`); `run_pipeline` dispatches abstractly on `PipelineStep`. Type widening propagates into Workspace specialisation → multi-minute JIT hang with no stack trace. Three rules:

1. **`Dict{Symbol,Any}` → concrete struct**: isolate in a helper function with `::ConcreteType` assertions. Function boundary keeps `Any`-typed locals out of `_run_step`; type assertion narrows return tuple. Never let `Any` flow into `make_workspace` kwargs directly.

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

2. **Never store closures in struct fields that flow into Workspace.** Each closure site has a unique type, multiplying specialization. Pre-evaluate `t -> ...` to `PiecewiseLinearWaveform` / `InterpolatedWaveform` before storing.

3. **Keep `@noinline _step_dispatch!(@nospecialize(step), ...)` at the dispatch boundary** between `run_pipeline` and `_run_step`. These annotations are retained as a precaution; their removal did not reproduce the historical hang in the measurement recorded under architectural commitment 8. Enforce the measured rule: no `Any`-typed local or stored closure may escape into a Workspace path.

**Debug procedure** when JIT hangs:
- Direct-call the offending `_run_step(::ConcreteStep, ...)` — if fast, suspect abstract dispatch propagation from `run_pipeline`.
- Check recent additions for `Dict{Symbol,Any}` extractions or closure creation reaching `make_workspace`.
- `Cthulhu.descend(run_pipeline, (typeof(config),))` for deep inspection.

**User-supplied callbacks** (simulation `SimulationCallbacks.on_step`; this also named `extract_observables` until 2026-08-05, a symbol that exists nowhere in the repo) accept `::Function` — OK in cold paths; hot-loop callbacks must parameterize: `struct Cb{F1,F2} ...`.

## Measuring: never write a bespoke scan

Use `test/helpers/calibrated_scan.jl` for audits and gates over a corpus.
`calibrated_scan(corpus; match, present, absent)` verifies a positive and negative
control before returning results; `count_matches` counts matches, not lines.
`tree_files` defines the corpus; respect its path base and include untracked files
when auditing the working tree.

Assert that the intended corpus is nonempty and fully opened. A missing file,
failed parser, or unreachable tree is not an empty result. Controls must represent
the actual failure being guarded against and reject prose-only matches when the
target is executable code. Test both the PASS and FAIL directions, including the
sharpest legitimate case. A green gate alone does not prove that it looked.

## Before starting a topic — enumerate the open work, and disposition it

```bash
python3 scripts/prior_art.py --topic <name> --keywords <k1> <k2>
```

Read the matching PRs, issues, and branches recorded in
`docs/campaign/prior_art/<name>.md`. Set each row to `read`, `unrelated`,
`superseded`, or `depends`, with a note explaining the disposition. Do not leave
`unread`; `test/test_prior_art_dispositions.jl` rejects it. Existing sibling
experiments, artifacts, and relevant memory also count as prior work to inspect.

The record is a dated snapshot. The gate cannot establish freshness or whether a
row was actually read. If enumeration fails, record the limitation honestly and
retain earlier dispositions; do not turn a network failure into "nothing found".

## Before computing — five gates

1. **Read the primary source before spending compute.** For an experimental
   comparison, record sourced atom number, temperature/condensate fraction,
   already-fitted parameters and their targets, loss mechanism, systematics on
   every axis, and whether theory and data use the same observable.
2. **Sensitivity before scans.** Build a two-point (parameter, observable) table,
   normalizing responses by observable uncertainty. A zero response is a useful
   constraint on what a scan can measure.
3. **Systematics before residuals.** Compare a parameter's effect with variation
   across uncertain axes, including axes held fixed. A bootstrap cannot remove an
   omitted systematic. Prefer observables invariant under that uncertainty.
4. **Pre-register rejection.** Put the acceptance/rejection criterion in the
   experiment definition before launch; do not choose it from the result.
5. **One arm, then report.** Verify the premise before expanding to a batch.

Discrete observables can be useful, but demonstrate resolution robustness rather
than presuming no uncertainty. Check whether the published reference calculation
already misses the data before trying to fit the same residual away.

State what normalization removes. Inspect row sums versus the abscissa when loading
external fixtures; population fractions can erase atom loss. Re-derive a
component-local discrepancy under a second normalization before explaining it.
A sum closing by identity is not an independent budget; show its components.

## Cost model + execution discipline

Workspace specialization makes first-call compilation significant. Separate JIT
from steady-state timing; small experiment runs can spend minutes compiling and F32
rotating-basis compilation has historically taken about ten minutes. Investigate
`Any` or closure escape when inference stalls (see Type stability boundaries).

- Prefer power-of-two grid edges for threaded FFTW `MEASURE`/`PATIENT` planning.
  Mixed-radix grids with real Julia threads have shown large planner-memory costs,
  even when the corresponding larger power-of-two grid is cheap. A smoke grid's
  resource behavior does not automatically transfer to production.
  `SPINORBEC_FFT_PLAN=estimate` is the explicit planning opt-out.
- Before a launch expected to exceed ten minutes, smoke-test every intended path
  on the actual backend (use `--smoke` where supported; target at most two minutes
  on GPU). Verify symbols and kwargs against the code first.
- Apply the host limits in `docs/guides/local_run_environment.md`; use
  `docs/guides/tsubame.md` for larger sweeps and production GPU jobs. Do not assume
  GPU or cluster access from a remembered host path.
- Background long jobs through the tools available in the current environment.
  Capture logs and an exit status; a vanished PID does not mean success. Continue
  independent work while execution runs.
- Promise a later completion report only with a working notification/watcher.
  On supported Bash hosts, `scripts/watch_until_done.sh` distinguishes GREEN,
  RED, TIMEOUT, and UNKNOWN; exercise `--canary`. If the environment cannot deliver
  a future turn, report the current state and the saved monitoring artifacts.

## Memory ↔ CLAUDE.md split

This file holds structural rules; memory holds incident lessons and active context.
Use a memory store only when it is available in the current environment. The
historical Linux store was outside the repository; its absence does not imply
that `memory/` exists locally or authorize recreating it.

When maintaining that store, run
`python3 scripts/audit_memory.py --memory-dir <actual-store> --repo .`.
Keep the index within the
script's conservative limit; do not substitute an uncited model context limit.
Entries stay short; move growing sections verbatim to linked sub-indexes and verify
that no entry or reachable file vanished. Audit after adding or renaming memories.

Judge references by resolvability: a fabricated path, a path on another ref, a
moved symbol, and a historically deleted file are different cases. Anchor claims
about another branch to its ref. `--fix-relocations` is appropriate only for the
script's unambiguous relocation matches. Preserve dated evidence rather than
rewriting it as current fact.

For issue maintenance, reconcile the body with later comments, merged changes,
and remaining acceptance evidence. A merged implementation does not discharge an
unrun validation. Put corrections beside the affected claim, narrow the task to
remaining work, and link successor issues instead of retaining parallel plans.
Do not turn a historical user request into permanent authority for new runs.

For structural conflicts this file wins; incident records explain what failed and
what to verify. Promote recurring prevention rules here without copying the full
incident narrative. Rules needed every session must not live only in an optional
memory index.

## Quick facts

- `spin_matrices(F::Int)` takes F, not the component count.
- `|F/n|²` is the density-weighted average of `(f/n)²`, not `f²/n`.
- Ramp `:log` uses the time-warp `g(t) = log(1 + (e-1)t)`; scan `:log` is geometric.
- Recompute L-BFGS `grad_norm` at the returned state; do not trust cached values.
- `_run_analyzer` requires `ws_prev` even on cache hit.
- `_cuda_reclaim_callback` runs between scan points.
- `rotating_basis_history` concatenates phases.
