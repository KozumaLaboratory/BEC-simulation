# CLAUDE.md

Arbitrary-F spinor Gross–Pitaevskii simulator (split-step Fourier, 1D/2D/3D, CPU + CUDA, YAML-driven). Primary production target: ¹⁵¹Eu at F=6 (13 components). Internal units: ℏ = m = ω_ref = 1.

This file is the **structural fixed-point** — design rules that survive across incidents. Per-incident lessons live in memory.

Anchors:

- `README.md` / `docs/index.md` — project description + documentation map.
- `docs/reference/{yaml_schema_reference,dynamics,architecture}.md` — full YAML schema + dynamics knobs + module data flow.
- `docs/conventions/{sign_bug_proof_architecture,hamiltonian_sign_audit,adding_new_hamiltonian_term}.md` — physics convention authority + 14-term sign × path audit.
- Memory at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/` — `feedback_*` (user norms), `mistake_*` (errors + prevention), `gotcha_*` (sharp edges), `project_*` (active arcs), `reference_*` (external systems).

`AGENTS.md` is a stale fork (pre-rename names `nematic` / `TwoChannelLHY`, predates HamTerm protocol); prefer this file.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                     # all tests at default tier
SPINORBEC_TEST_WORKERS=auto julia --project=. -e 'using Pkg; Pkg.test()'  # parallel (1 worker/core)
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test
julia --project=. -e 'using Pkg; Pkg.instantiate()'               # install deps
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.                # GPU REPL on WSL2
julia --project=. scripts/cli.jl <subcmd> [args]                  # unified CLI (inspect / launch / figure / preflight / autopilot / tag / catalog / tsubame)
```

`SPINORBEC_TEST_TIER` ∈ `{fast, ci, full, physics}`. Tier membership is **explicit in `test/runtests.jl`** — every test belongs to exactly one list. New tests get added to a list, not auto-discovered. The runner also honours `SPINORBEC_TEST_WORKERS` (`1` default = serial in-process / `N` / `auto` = split files into N **independent julia processes**, slow files spread across chunks — separate processes, not Distributed workers, so each loads SpinorBEC once in a clean session; a shared worker pool reloads the package mid-run and `x isa T` flakes false), `SPINORBEC_TEST_SKIP` (comma-separated paths to omit), and `SPINORBEC_TEST_TIMING=quiet`. Parallel mode requires each test file to stay a dependency-free unit (own `using` / `@testset` / `@__DIR__` helpers, no cross-file fixed `/tmp` paths) — preserve that when adding tests.

## Project structure

```
src/
├── SpinorBEC.jl               # umbrella module
├── foundation.jl              # types (Grid, Workspace, AbstractPotential…) + math primitives + backend dispatch + Clebsch-Gordan + spherical harmonics
├── hamiltonian.jl             # terms/<term>/ (HamTerm faces + engines: contact ddi lhy zeeman raman light_shift loss trap) + coefficients.jl (c↔g) + shared/ (rotation + spin_rotation) + optics/ + integrator/ (split_step + Yoshida + composers + Coriolis + adaptive + rotating_basis + absorbing_boundary) + tdhfb/
├── analysis.jl                # observables + energy + currents + vorticity + tomography/Faraday/imaging + topology + Fisher + spin_rotation + Sinatra TWA-validity + grid_resolution planning + phases/ (Bogoliubov + sign-pattern + F6 diagram + polyhedral classifier)
├── solvers.jl                 # ground_state + lbfgs + hessian (HvP + trapped-BdG λ_min) + continuation/{1d,2d,boundary,arclength,triple_point} + simulation + adaptive + TWA + binary + scalar_egpe + projected_gp + photon_heating + sgpe
├── manuscript.jl              # figure registry (CSV / Python / TikZ emitters keyed by (paper, FIG-N))
├── validation.jl              # umbrella → validation/{reference_rhs, dumb_reference} — independent term-by-term Hψ + dumb-statement oracle for the self-contained validation chain
└── workflow/
    ├── initialization.jl      # atoms (ATOM_REGISTRY) + init_psi dispatch + state_zoo (22 named builders) + make_workspace + thermal/vacuum noise + Thomas-Fermi
    ├── io.jl                  # save_state + Units submodule + budget + run_summary + html_report + vtk_export (weak ext) + catalog + cluster
    ├── monitoring.jl          # Slack webhook notifications (notify_slack); live-JSON status lives in experiments/pipeline/pipeline_callbacks.jl
    ├── experiments.jl         # YAML schema (lab-units + templates + mixins + defaults + B-block + noise-block + auto-defaults) + runtime helpers + analyzers + pipeline runner
    ├── experiments/calibration.jl    # module Calibration — lab-units preprocess + week-to-week drift sampling
    ├── experiments/optimization.jl   # module Optimization — Bayesian opt + multi-fidelity + active-learning phase scan + Faraday fit
    ├── experiments/{inspect,inspect_batch,diff_dicts}.jl  # config introspection + structural diff + 4-severity warnings
    ├── experiment.jl          # Experiment lifecycle (spec + CAS outdir + lazy obs memo)
    ├── validation.jl          # RunResult + ConservationSpec / OperatorRHSSpec + CheckResult + twin_audit + scalar_summary
    ├── io/dashboard.jl        # module Dashboard — HTTP/WS server + routes + compute helpers + binary packers (bitshuffle + zstd)
    └── autopilot.jl           # queue + tick + on_complete + retry + budget + breakers + UGE backend + observability + Day-1 recipes + trust gradient

ext/        SpinorBEC{CUDA, Makie, HTTP, VTK}Ext (weak-dep extensions)
test/       subdirs mirror src/ + test/oracles/ (sign-bug-proof gates) + test/helpers/
scripts/    one-off audit drivers (m1_*, m2_*, fisher_*, build_sysimage*, cli.jl, deploy_dashboard_auth.sh)
dashboard/  React + WebGPU frontend (Vite + R3F + Three WebGPU + TSL + leva + shadcn + Tailwind v4)
runs/       YAML configs + per-config jld2 cache  (the `_loop/` loop record was RETIRED 2026-06-08 → /home/suzume/workspace/BEC-simulation-archive/loop_record_2026_06_08/ (outside the repo))
docs/       api/ architecture/ conventions/ design/ guides/ reference/ refs/ research_notes/ theory/ validation/ manuscript/
bench/      benchmarks
```

Umbrella files `Foo.jl` `include` sub-files in dependency order; public exports live next to definitions. **Real submodules** (`module Foo`; re-exported at umbrella): `Units`, `Calibration`, `Optimization`, `Dashboard`. Promote to `module` when the subsystem has an independent design lifecycle.

**Cross-layer dispersal is the default for new subsystems**: a feature that touches storage / physics / analysis / pipeline goes into each layer rather than as a vertical slice. The rotating-basis path is the worked example — `foundation/`, `hamiltonian/integrator/`, `analysis/`, `workflow/experiments/analyzers/`, `workflow/experiments/pipeline/run_step_rotating/`.

## Architectural commitments

1. **Arbitrary-F spinor first, F=1 last.** Every closed form, observable, analyzer built for general F. ¹⁵¹Eu (F=6) is production; F=1 is a debugging convenience.
2. **Composable physics modules.** Each Hamiltonian term, loss channel, noise source is an independent unit composing via split-step sandwich or callback. No god-functions.
3. **Zero silent sign drift — guarantee preserved, mechanism updated (2026-06-06).** The invariant: no sign / factor / term-omission can drift silently. Mechanism: **day-0 gated redundancy** — independent statements of the same physics (production fast kernels vs the dumb reference, pinned to physics by directional anchors) compared per-term by CI gates registered from their first commit; a meta-test asserts every statement pair is gated and every oracle file is in a tier (and is itself canaried: deleting a term from one side must turn the meta-test red). Deliberate duplication across dumb/fast statements is the oracle, not a bug; **ungated duplication remains forbidden** — that was the actual pre-2026 disease. Single-declaration derivation is kept where it is free but is not the load-bearing mechanism: runtime-speed targets exclude interpreter evaluation, and a physics-codegen layer would be a thesis-scale detour with a new whole-system bug surface. Design SSoT: `docs/design/hamiltonian_layered_architecture.md`.
4. **Content-addressed computation.** `Experiment(spec)` → `<store.root>/<sha256(canonical_bytes(spec))[1:16]>/`. Users never name outdirs. Collection ops (`sweep`, `twin`, `tabulate`, `spec_diff`) fall out of `Vector{Experiment}` + the spec primitive.
5. **YAML-disk + DSL-memory duality.** Every spec is YAML-serialisable (resumable via `run_yaml`) and Julia-constructible (`config([ground_state(...), dynamics(...), analyze(...)])`). Sweeps/tests use DSL; production uses YAML.
6. **Layered validation.** Code correctness (A: oracle + GPU=CPU + Hψ self-consistency) ⊥ physics agreement (B: closed-form limits + F=1 polar/FM + polyhedral) ⊥ model fidelity (C: published experimental data). Never conflate. Self-contained chain (A + B + reference-RHS oracle) holds correctness without external code.
7. **Tier-gated tests with explicit lists.** `fast` (pure units, quick) / `ci` (+ integration + all oracle gates) / `full` (+ heavy ITP/RTP/BO/GPU) / `physics` (analytic-only). Heavy YAML tests behind env-var guards.
8. **Type stability firewalls at dispatch barriers.** `Workspace` has 23+ type parameters; `Dict{Symbol,Any}` or closures escaping into Workspace paths cause inference to explode (multi-minute JIT hang, no stack trace). `@noinline _step_dispatch!(@nospecialize(step), ...)` in `pipeline/runner.jl` is the load-bearing firewall — do NOT specialize through.
9. **Convention discipline over backward compat.** File name = primary export; function name = what the body computes; YAML analyzer name = real implementation. Renames delete the old name in the same commit; no `const Old = New` aliases by default; no version suffixes (name by content).
10. **Cost-aware execution.** Trivial `run_yaml` pays multi-minute JIT cascade; mixed-precision F32 first-JIT ~10 min; closure-escape triggers 30-min hang. Smoke-test (`--smoke` rendering every code path in ≤ 2 min) before > 10 min launch. CPU success ⇏ GPU works. Background long jobs; don't poll.

## Workflow model (spec → CAS → run → observe)

Four primitives:

1. **`spec`** — YAML-shaped `Dict`. Built via DSL in `experiments/runfactory.jl` (block builders `B`, `ddi`, `lhy`, `loss`, `save`, `ramp`, `rate`; step builders `ground_state`, `dynamics`, `analyze` mirror YAML keys 1:1) or loaded from YAML.
2. **CAS outdir** — `content_id(spec)` deterministic across dict-iteration order, Julia version, YAML round-trip. Same spec ⇒ same outdir, anywhere.
3. **`Experiment(spec)` lifecycle** — `(spec, store, memo)` triple. `run!(exp)` idempotent (skips when `result.jld2` / `point_001.jld2` exists). Observables (`Fz_t`, `Lz_t`, `energy_t`, `peaks`, `populations_t`, `classify`, `density(exp, t)`, `psi(exp, t)`, `density_stats_at`, `integrator_meta`, …) are plain functions on `Experiment` memoizing in `exp.memo`.
4. **Collection ops as derivatives**:
   - `sweep(base; over=:path => values)` → `Vector{Experiment}`.
   - `twin(exp)` → sibling with `lhy: none` + `loss` removed (A/B control).
   - `tabulate(exps, [Fz_t, classify, norm_drift])` → per-cell column NamedTuple; failed cells slot the Exception so the table assembles.
   - `spec_diff(a, b)` → dotted-path diff. Powers twin verification, sweep-axis discovery, compare provenance.

`run_yaml(path)` = disk form: resumable, directory-per-config, one jld2 per scan point, skips cached files on re-run, auto-applies `calibration:`, writes `_live_status.json` + `_exit_summary.json` for autopilot. `load_config(path) |> run_config` = non-resumable in-memory form.

**Spec-driven validation** (`workflow/validation/`):
- `RunResult` = typed view over jld2 (`psi`, `hpsi?`, `grid`, `atom`, `interactions`, `dynamics::DynamicsTimeSeries?`, `e_decomp`, `metadata`).
- `ConservationSpec(; norm_drift=…, energy_rel_drift=…, Jz_drift=…)` — bounds on `RunResult` observables; `check(spec, r) → CheckResult`.
- `OperatorRHSSpec(; tol_hpsi=…, tol_per_term_E=…)` — Level-10 A/B operator-RHS diff via `RunComparison`; requires both runs to have saved `Hψ`.
- `audit(exp; spec=ConservationSpec())` = `run!` + `check`.

## Subsystem catalog

| Subsystem | Role | Discipline |
|---|---|---|
| **foundation/types/** | Primary home for cross-cutting structs (`Grid`, `Workspace`, `AbstractPotential` + 12 subtypes, spin / atom / Zeeman / Raman / FFT / DDI / Loss / LightShift / TensorCache / Integrator config / SimulationResult / TWA / TOF / BdG / scan / checkpoint / TDHFBState …). Subsystem-local structs (waveform, backend, pipeline steps, validation specs, calibration, …) co-locate with their machinery — `types/` is the default, not an invariant. | Cross-cutting structs go here first. Workspace type params are derived. `Val(N)` from type parameter, not `Val(ndim::Int)`. |
| **hamiltonian/terms/<term>/** (merged 2026-06-06; was interactions/ + potentials/) | Per-term face + engine cohesion: contact/ (c0/c1 + singlet_pair + tensor) + ddi/ (k-space 6-FFT convolution + secular option + zero-padded variant) + lhy/ (closed forms + φ₁-reg + Modes-round-45 + Sigma-Delta dispatch + Lima-Pelster Q5) + zeeman/ (accessors + builders) + raman/ + light_shift/ + loss/ + trap/ (evaluators). Shared machinery is EXPLICIT: `hamiltonian/coefficients.jl` (c↔g algebra — shared with TDHFB + Bogoliubov), `hamiltonian/shared/` (Euler rotation cache: DDI + spin_mixing; uniform spin rotation: Zeeman transverse + Raman + rotating_basis), `hamiltonian/optics/` (beam/config builders), absorbing_boundary in integrator/. | Two interaction paths auto-selected in `make_workspace` (c₀/c₁ vs scattering-lengths). Unified `B:` block; Zeeman operator `H = -p·F_z + q·F_z²` (Kawaguchi-Ueda) with `p ≡ -g_F μ_B B` ⇒ physically `+(g_F μ_B B · F)`; the B→p sign lives in `Units.bfield_to_p` (see `experiments/runtime/b_block_builders.jl`). |
| **hamiltonian/terms/** | **HamTerm protocol.** Each term — Kinetic, Trap, Zeeman (linear `-(b·F)` + quadratic `q F_z²`, diagonal + transverse in ONE term), DensityC0, SpinC1, DDI, LHY, Tensor, Raman, LightShift, Coriolis, MagneticGradient (spin-independent tilt, NOT a Zeeman), Loss — declares its sign in ONE coefficient function; `apply_step!` / `energy_contribution` / `apply_operator!` (ACCUMULATES `out .+= H·ψ`; gate-first; the gradient face) / `sign_oracle` derive from it. `build_h_terms_registry(ws) → NTuple{N, HamTerm}` is type-stable and unrolled. | New H terms go here. Registry pattern is load-bearing for bug-class elimination — do NOT bypass for new physics; do NOT introduce parallel sign declarations. |
| **hamiltonian/integrator/** | Split-step + adaptive Yoshida + Coriolis 3-shear + Yoshida/Suzuki/Blanes-Moan composers + force_gradient + combined_spin_step + dealias + adaptive-dt + rotating-basis propagators/integrators. | `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)` Strang sandwich. `_YOSHIDA_W0 < 0` correct (backward middle substep). |
| **hamiltonian/tdhfb/** | Time-Dependent HFB local-approximation engine — voxel-local BdG Strang step (channel kernel + HF self-energy + Δ from φφ + κ) + Y4-midpoint Picard wrapper + total-energy functional conserved by step. | Engine **parallel to GP**; YAML pipeline integration deferred. Do NOT wire `dynamics.tdhfb` into `run_yaml` without explicit ask. |
| **analysis/** | observables + energy_decomposition + currents + vorticity + vortex_extraction + diagnostics + Majorana stars + icosahedral order + TOF + tomography + Faraday + imaging + Fisher + topology (winding / monopole / holonomy) + synthetic_dimension + time_resolved + stability_analysis + spin_rotation. | `_get_spinor(psi, I, Val(13))` allocates 352 B/call at D=13 (SROA elides inside hot loops). Use `Matrix` / `MVector`; `SMatrix` heap-allocates at D=13. |
| **analysis/phases/** | phase_classification + phase_boundary + Bogoliubov spectrum + scan + sign_pattern + F6 phase diagram + polyhedral classifier (σ_S fingerprint + direct ΔE) + canonical polyhedral states. | Bogoliubov k=0 Goldstone μ convention: `omega[:, 1]` is column-index k-mode 1, NOT `omega[1, :]`. |
| **solvers/ground_state + lbfgs** | ITP (`find_ground_state`) + checkpoint + adaptive + advanced (multistart + Jz-constrained) + LBFGS with Sobolev preconditioner. | ITP Zeeman shift subtracts `min(E_m)`. `find_ground_state_lbfgs` returns an atomic NamedTuple incl. `grad_norm` (spine G). Tensor c2/c4 falls back to ITP with `@warn`. |
| **solvers/continuation** | scan_1d + scan_2d + boundary tracing + pseudo_arclength + triple_point. | `make_params(val)` returns kwarg NamedTuple or `InteractionParams`. Legacy `make_interactions` removed. |
| **solvers/simulation + twa + sgpe + projected_gp + photon_heating + binary** | RTP (`run_simulation!`) + adaptive + embedded-adaptive + Truncated Wigner + SGPE callback (true thermal init) + projected GP + photon scattering + two-component GP. | TWA σ/μ is chaotic-dipolar divergence, NOT classical thermalization. |
| **workflow/experiments/{schema,runtime,analyzers,pipeline}** | YAML compile (units + templates + mixins + defaults + B-block + noise-block + auto-defaults + ε hardening) + runtime helpers (b_block_builders, pulse_sequence, STA counter-diabatic, Feshbach ramp) + analyzers + pipeline runner. | `_step_dispatch!` has `@noinline` + `@nospecialize(step)` — the inference firewall. |
| **workflow/autopilot/** | Queue + tick + 2-stage submit + LocalBackend + UGEBackend (TSUBAME) + budget cap + circuit breakers (recipe / lineage / rate / kill) + on_complete recipe lineage + retry + qw_history + trust gradient + Day-1 recipes (next_random / refine / analyze) + failure_analysis + profile_recommend + observability. | TSUBAME uses UGE not Slurm; `qsub -g <group>` is CLI flag not directive. `.autopilot.{dry_run,paused}` persisted file sentinels. UGE auto-registers from `SPINORBEC_TSUBAME_{HOST,PROJECT_ROOT,RUNS_ROOT,…}` env. |
| **workflow/io/dashboard/** | `module Dashboard`. HTTP + WebSocket + binary packers + JLD2 cache. Routes for density / phase / vortex / scan / catalog / sweep / autopilot queue / budget / inspect / tags. | Caddy admin via Unix socket; oauth2-proxy `hd=isct.ac.jp` admits whole tenant — default to anko-only `authenticated_emails_file`. |
| **workflow/experiments/optimization.jl** | `module Optimization`. `bayesian_optimize` + `multi_fidelity_optimize_2tier` + `active_learn_phase_scan` + GP/EI + Faraday fit. YAML and direct-Julia entry points; built-in objectives `bo_objective_{max_m_transfer,max_lz,min_energy}` + custom via closure. | GP fitting > 100 s wall ⇒ heavy-tier only. |
| **workflow/experiments/calibration.jl** | `module Calibration`. CoilCalibration + FORTCalibration + RabiCalibration + CalibrationHistory (CSV + week-to-week interpolate) + drift sampling. | Lab fields like `B: {p_mv: 2.5, coil_mode: strong}` resolve via calibration table to Gauss **before** downstream parsing. |
| **workflow/initialization + state_zoo** | atoms + `init_psi` dispatch + 22 named `init_psi_<name>` wrappers + Thomas-Fermi + heuristic thermal seed + TWA vacuum noise. | Wrap, don't fork: every named state is `init_psi(state=:..., init_state_params=...)` under the hood. For `:transverse_x` use `init_psi_spin_coherent(grid, sys; theta=π/2, phi=0)`. True thermal init uses SGPE callback. |
| **manuscript.jl + manuscript/figures/** | Figure registry keyed by (paper, FIG-N). Emitters: CSV / Python / TikZ. CLI via `scripts/cli.jl figure --paper <p> --fig <n>` or `--list`. | Paper #1 = F-generic LHY closed forms; Paper #2 = F6 phase diagram; Paper #3 = Sign Pattern Lemma 1 + Universal Theorem; thesis Ch.1-7 in `docs/manuscript/thesis/`. |
| **validation/reference_rhs/** | Independent term-by-term `reference_<term>_apply!` and `reference_<term>_energy` with same numeric prefactor as production. Diff oracle. | Holds self-contained validation claim. External Ueda is `BLOCKED_EXTERNAL` — see `docs/validation/ueda_status.md`. |
| **autonomous research** (external) | Successor to the retired loop: the gated harness at `/home/suzume/workspace/spinorbec-autoresearch/` (OUTER project; this repo is its inner `repo/` worktree on `autoresearch/base`). Own `.claude/` (solver/verifier + require-evidence hook), `spec/` (INVARIANTS/DECISIONS/MATHCODE_MAP), `gate.sh` (independent re-run L0–L4; never trusts Solver metrics). | Lives outside this repo. See `/home/suzume/workspace/spinorbec-autoresearch/CLAUDE.md`. |
| **`.claude/` loop** (RETIRED 2026-06-08) | First autonomous research loop. `loop.sh` guarded (exits RETIRED). Machinery (≈30 scripts + 6 agents + run-loop.md + design docs) moved to `…/BEC-simulation-archive/loop_machinery_2026_06_08/`; record to `…/loop_record_2026_06_08/`. Both OUTSIDE the repo. | Root `.claude/` keeps only shared/CC-internal: `settings.json`, the 2 referenced hooks (`hook_pre_bash` API-key guard, `hook_post_write`), `cache/` `logs/` `projects/` `worktrees/`. |

## Wavefunction conventions

- **Layout**: `psi[x, y, …, c]`. Spatial dims first, spinor last. `c=1 → m=F`, `c=D → m=−F`.
- **Split-step**: `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`. Inner V symmetric: `diag SM singlet_pair tensor raman DDI raman tensor singlet_pair SM diag`. Substeps auto-skip on ≈ 0 coupling.
- **Two interaction paths**, auto-selected in `make_workspace`:
  - **c₀/c₁ path**: `diagonal(c₀) + spin_mixing(c₁) + singlet_pair(c₂) + tensor(residual c₄, c₆, …)`.
  - **Scattering-lengths path** (Cr52 etc.): tensor handles ALL channels, `c₀ = c₁ = 0`.
- **YAML schema**: parameter variation is a **config path override** — dotted path into raw YAML dict (e.g. `pipeline.0.ddi.c_dd`) mapped to a new value. Full ref: `docs/reference/yaml_schema_reference.md`. Unified `B:` block accepts `{Bz, theta, phi}` or `{p_mv, coil_mode}` for lab-units; `q` auto-derives from |B|² unless explicit. Lab-units features (`units:`, `accuracy:`, `auto_grid:`, `template:`, `mixins:`, `defaults:`, ε hardening) are OPT-IN.
- **Mixed precision** (rotating_basis only): `dtype: f32` in `ground_state` plumbs Float32 through Grid / V_trap / Workspace / FFT plans / DDI buffers. F64 default. F32 first-time JIT ~10 min, then cached. `apply_uniform_spin_rotation!` + `apply_ddi_step!` + `apply_spin_mixing_step!` keep scalar Float64 locks (rotation builder + DDI dt + c1·dt); array work stays F32.
- **Noise**: both GS `temperature_ratio` and `dynamics.temperature_ratio` drive a **heuristic** symmetry-breaking kick (η = √((T/T_c)³/4)) via `add_thermal_seed(psi, F; T_over_Tc, seed)`. NOT a true thermal Wigner sample. For true thermal init use SGPE callback.
- **Calibration**: lab-unit YAML preprocess auto-applied by `run_yaml`. Use `calibration:` for single block or `calibration_history:` for week-to-week interpolation.
- **`phi_omega` Hz form**: `phi_omega: 4.524` (dimensionless ω/ω_ref) and `"226.2 Hz"` equivalent; Hz converts via `(2π·f)/ω_ref` using parent `interactions.omega_ref`. Eliminates Klaus 2022 magnetostir 2π footgun.
- **LHY config**: single `lhy:` block inside `ground_state`. `kind` ∈ `{scalar, quasi_2d, polar_two_channel, full_bdg, polar_contact, polar_dipolar, fm_contact, fm_dipolar, icosahedral, none}`. Auto-derive `c_lhy` for `scalar` / `quasi_2d`. Legacy keys (`interactions.c_lhy`, `ground_state.spinor_lhy`) deleted.
- **Tabulated LHY energy is `∫₀ⁿ V dn'`, not `n·V(n)`** — the tables store `V = dε/dn`, and every one has `ε ∝ n^(5/2)`, for which `n·V = (5/2)ε`. Until 2026-07-28 the reported LHY energy was **exactly 2.5× too large for every tabulated mode**, on CPU and GPU alike. The propagator was unaffected (it uses `V` directly), so the dynamics were right and only the number printed beside them was wrong. `ε` is the exact integral of the same piecewise-linear `V` the propagator evaluates, so `dE/dn == V` by construction. Gated by `test/hamiltonian/test_lhy_energy_convention.jl`.
- **Tabulated LHY on GPU** goes through the generic broadcast propagator (the fused GPU kernel's `c_lhy` bound admits only `Nothing`/`NoLHY`/`Float64`/`ScalarLHY`), with the table uploaded once per `objectid` and an O(1) uniform-grid lookup in `ext/.../gpu_lhy_field.jl`. Until 2026-07-28 that path collapsed every table to `c_lhy = 0.0`, so **every GPU run with `polar_contact`/`fm_contact`/`icosahedral`/`polar_dipolar`/`fm_dipolar`/`polar_two_channel`/`full_bdg` ran with no LHY at all** — 12 configs under `runs/` are affected. Gated by `test/hamiltonian/test_tabulated_lhy_propagator_parity.jl` (CPU) + `test/gpu/test_gpu_tabulated_lhy_parity.jl`.
- **GPU**: `import CUDA` before `using SpinorBEC` loads the extension. Pass `backend=CUDABackend()`. WSL2 needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib`. CUDA ext mirrors CPU per-term (energy / singlet_pair / tensor / spin_mixing / Raman / normalize / Euler kernel / TDHFB Phase 5a-5c). `gpu_graph.jl` is disabled (replay drift, 4× slower).

## Sign-bug-proof discipline (HamTerm protocol)

The historical pattern: same physics in N hand-duplicated locations; one drift, others stay correct, tests still pass. Linear z-Zeeman alone used to live in 8 places. The forward commitment:

- **One sign declaration per term.** `_diag_coef(term, m)` / `_h_matrix(term, sm)` / `_<op>(term, …)` at top of `src/hamiltonian/terms/<term>.jl`.
- **All paths via the registry.** `apply_step!` (propagator) / `energy_contribution` (CPU + GPU) / `apply_operator!` (the accumulating gradient face, LBFGS) call the same coefficient function. There is no separate `add_gradient!` — it was the same mathematical object as `apply_operator!` and was consolidated 2026-06-06.
- **Inactive terms short-circuit at top of each method.** Registry is `NTuple{N, HamTerm}` (type-stable, compiler-unrolled); zero per-call cost for inactive terms.
- **Shared scratch via `EnergyContext` / `GradientContext`.** Context-aware overloads reuse pre-built density / spin density / FFT buffer across terms in one pass. New terms benefiting from shared scratch should provide the `ctx`-aware specialization.

**Source of truth**: operator `H = -p·F_z + q·F_z²` (Kawaguchi-Ueda spinor-BEC form). The lab field enters via `p ≡ -g_F μ_B B` (atomic moment `μ = -g_F μ_B F`), so physically `H = +(g_F μ_B B · F) + q F_z²`; +Bz on a g_F>0 atom (Eu, Cr, He*) gives ground state m=-F. The B→p sign is declared **once** in `Units.bfield_to_p` (`src/workflow/io/units.jl`); the 3 sibling converters delegate to it. The operator-form spec is documented at `b_block_builders.jl:27`. Every other Zeeman reference derives from these.

**Adding a new HamTerm — protocol**:

1. Create `src/hamiltonian/terms/<your_term>.jl` with `struct <YourTerm> <: HamTerm`.
2. Declare the sign convention in ONE coefficient function.
3. Implement `apply_step!` / `energy_contribution` / `apply_operator!` (accumulate contract: `out .+= H·ψ`, gate-first, never `fill!` inside; callers zero `out` for the bare action) from it. Delegate to existing audited routines (`_apply_coriolis_step!`, `apply_kinetic_step_batched!`, …) when possible.
4. Provide `sign_oracle(::Type{<YourTerm>})` → `(name, predicate)` — a directional physics observable the *correct* sign produces (FM `⟨|F|²⟩=F²` vs polar 0, prolate vs oblate, `⟨F_z⟩>0` under `+p`, …). A predicate returning `true` regardless is a placeholder, not an oracle.
5. Register in `src/hamiltonian.jl` include list AND `build_h_terms_registry` AND `H_TERMS_CANONICAL_ORDER`.
6. Add a directional test to `test/oracles/test_hamiltonian_sign_oracles.jl`. If term has `sign(E) = sign(c)·X²` shape (tautology), additionally add a physics-anchored oracle to `test/oracles/test_physics_aware_sign_oracles.jl`.
7. Run the oracle suite — every gate must pass:
   - `test_term_consistency.jl` (FD oracle: `apply_operator!` ↔ FD of `energy_contribution`).
   - `test_gpu_cpu_per_term_parity.jl` (per-term GPU↔CPU; closes blind spot where term contributes zero in aggregate test).
   - `test_registry_{energy_decomposition,gradient,strang_step}_parity.jl` (registry vs hand-written bit-identity).
   - `test_magnetic_gradient_gap.jl` style: per-term audit gate when term has a non-obvious path (transverse, off-diagonal, propagator that mutates V).

Full procedure: `docs/conventions/adding_new_hamiltonian_term.md`. Audit table: `docs/conventions/hamiltonian_sign_audit.md`.

## Test taxonomy + oracle gates

Tier membership is **explicit in `test/runtests.jl`** — no auto-discovery.

**Oracle test families** under `test/oracles/`, each gating one bug class:

| Family | What it gates |
|---|---|
| `test_hamiltonian_sign_oracles.jl` | Directional physics per HamTerm: `+p ⇒ ⟨F_z⟩ > 0`, `+Ω ⇒ ⟨L_z⟩ > 0`, `+g_F·grad ⇒ ⟨x⟩ < 0`, etc. |
| `test_physics_aware_sign_oracles.jl` | Physics-anchored oracles for terms with tautology-shape directional tests (SpinC1, DDI, LHY, Tensor). |
| `test_term_consistency.jl` | FD oracle: `apply_operator!` vs finite-difference of `energy_contribution`. Catches energy ↔ gradient drift. |
| `test_gpu_cpu_per_term_parity.jl` | One-term-active GPU vs CPU `energy_decomposition` and `Hψ`. Forbids "term contributes zero in test config, missing GPU path invisible". |
| `test_registry_{energy_decomposition,gradient}_parity.jl` | Registry path identities (legacy shape; ctx vs plain faces). The strang-step variant was deleted 2026-06-06 (post-B3 near-self-comparison); the propagator gate is the dt-valley + RK4-slope suite vs the dumb reference. |
| `test_term_legacy_equivalence.jl` | Per-term: new HamTerm `apply_step!` vs legacy routine. |
| `test_registry_collision_regression.jl` | HamTerm subtype names don't shadow potential types. |
| `test_magnetic_gradient_gap.jl` | Per-term audit for terms whose propagator mutates+restores V (so legacy energy reads clean V and reports zero). |

**Other named regression gates**:
- `solvers/test_itp_ddi_strang_save_every.jl` / `solvers/test_rtp_ddi_strang_save_every.jl` — named after specific historical bugs; do not delete.
- `rotating_basis/test_rotating_frame_regression.jl` — round-by-round dispersal pins.
- `test_level0..level12*.jl` — validation-ladder anchors.

**Heavy YAML integration tests** live behind `SPINORBEC_RUN_HEAVY_YAML=true`. Nightly workflow flips the flag.

## Validation ladder

13 levels, each with a tier-3 instrument under `test/`. Structural answer to "how do we know the code is right?".

| Level | What | Instrument |
|---|---|---|
| 0 | CPU = GPU consistency | `test_level0_gpu_cpu_consistency.jl` + `test_gpu_cpu_per_term_parity.jl` |
| 1 | Scalar exact (Gauss-Hermite ground state) | `test_level1_scalar_exact.jl` |
| 2 | Strang convergence | `test_level2_strang_convergence.jl` |
| 3 | Zeeman-only ground state | `test_level3_zeeman_only.jl` |
| 4 | Phase emergence (F=1 polar/FM, general F polyhedral) | `test_level4_{f1,general_F}_phase_emergence.jl` |
| 8 | LHY unit | `test_lhy_level8_unit.jl` |
| 10 | Hψ self-consistency + operator-RHS A/B diff | `test_level10_hpsi_self_consistency.jl` + `test_L5_operator_rhs_compare.jl` + `OperatorRHSSpec` |
| 11 | Convergence sweep | `test_level11_convergence_sweep.jl` |
| 12 | Production audit + twin control | `test_level12_production_audit.jl` + `twin_audit.jl` |

**Verification-type split**:
- **A: code correctness** — units, sign, conservation, bit-identity, GPU = CPU.
- **B: physics agreement** — closed-form limits, F=1 polar vs FM, polyhedral classification.
- **C: model fidelity** — comparison to published experimental data (Klaus 2022, Matsui Eu Bogoliubov cascade, Prasad 2019 vortex, Yan-Li-Saito Barnett).

Reports must say which type a claim falls under. "Tests pass" is A; "matches Klaus 2022" is C. Do not conflate.

## Autopilot pattern

Stateless meta-loop over the queue. Permanent invariants:

- **Two-stage submit**: mark `:running` + `job_id=nothing` + fsync; backend dispatch sets `job_id`; save_entry with real `job_id`. Crash between stages recoverable via `find_job_by_name`.
- **Backends**: `LocalBackend` (subprocess) + `UGEBackend` (TSUBAME ssh + rsync), auto-registered from env triple.
- **Pre-flight inspector**: 4-severity (`:block` → killed_bug, `:error` → recorded, `:warn` → Slack, `:info` → silent).
- **Budget gate**: quarter + daily GPU·h caps, refreshed from realized hours, checked once per tick.
- **Circuit breakers**: recipe / lineage / rate / kill — trip auto-pauses + Slack-alerts.
- **Persisted sentinels**: `.autopilot.dry_run` and `.autopilot.paused` — toggle via CLI or dashboard without restart. Dry-run still fires on_complete recipes (exercises lineage end-to-end).
- **On_complete recipes**: bounded recipe lineage (default `on_complete_max_descendants=64`). Day-1 set: `next_random` / `refine` / `analyze`.
- **Divergence kill**: reap loop watches `_live_status.json`, cancels divergent runs, classifies `:killed_data`.
- **Failure classification**: `outcome.toml` → `:killed_data` (NaN divergence) or `:killed_bug` (OOM / TIMEOUT / NODE_FAIL). OOM is resource-permanent — retry escalates resource class, not the recipe.

**Autonomous research loop** (RETIRED 2026-06-08): the first loop (`.claude/scripts/loop.sh`, dispatching director / theorist / implementer / researcher / critic) is superseded by the gated harness at `/home/suzume/workspace/spinorbec-autoresearch/` (OUTER project; this repo is its inner `repo/` worktree). `loop.sh` is guarded (exits RETIRED; `LOOP_FORCE_RETIRED_RUN=1` for forensics) and the loop machinery was moved to `/home/suzume/workspace/BEC-simulation-archive/loop_machinery_2026_06_08/`; the record to `…/loop_record_2026_06_08/`. The OAuth-forcing / API-key-guard discipline lives on in the protective hook `hook_pre_bash.sh` (still active for all sessions). Active successor: `/home/suzume/workspace/spinorbec-autoresearch/CLAUDE.md`.

## Conventions (do NOT "fix")

These look "off" but are correct. Changing them silently breaks chained downstream code.

- **DDI**: `c_dd = μ₀μ²` (no 4π), `Q_αβ = k̂_α k̂_β − δ_αβ/3` (no 1/(4π)), `Q(k=0) = 0`. Chain self-consistent.
- **ITP Zeeman shift**: subtracts `min(E_m)` to prevent overflow.
- **Scalar LHY**: `@warn` present. Known approximation.
- **`_YOSHIDA_W0 < 0`**: correct (backward middle substep; all operators time-reversible).
- **Hamiltonian sign source-of-truth**: operator form `H = -p·F_z` spec at `b_block_builders.jl:27`; the B→p sign (`p ≡ -g_F μ_B B`, Kawaguchi-Ueda) lives once in `Units.bfield_to_p`. Every other reference derives.
- **Odd-rank `c_extra` ignored** by design. Even-rank only via `even_c_extra(F; c2, c4, c6, …)`. Hand-written `[c2, c4, c6]` silently misindexes for F ≥ 3.
- **`compute_interaction_params_general_f` returns (0, 0)** by design (`tensor_cache` handles all).
- **`make_workspace` `@info` advisory** when `ω_L / (c_dd · ⟨n⟩) > 100`: secular DDI recommended. User-chosen, not auto. Eu experiments almost always live in that regime.

## Design boundaries (intentional non-support)

NOT bugs — don't "fix".

- **`PolarTwoChannelLHY` is polar-only**, exact at F=1, ~1 % off at F=2, **30–70 % off at F=6** (pinned by `test_spinor_lhy.jl`). Two-channel reduction sums (S=0, S=2) only — exhaustive only up to F=2. For F ≥ 2 polar use `PolarContactLHY` / `PolarDipolarLHY`; FM → `FMContactLHY` / `FMDipolarLHY` (**any F** since 2026-07-27 — the FM closed form needs only `g_{2F}`, and the former F=6-only lookup table was gating an unused field); F=6 I_h → `IcosahedralLHY` (genuinely F=6, the I_h channel structure is specific).
- **`FullBdGLHY` is the general-spinor path** — correct for any `F` and any spinor, gated against `polar_contact` / `fm_contact` / the scalar limit to ~1e-4 by `test/oracles/test_lhy_full_bdg_closed_form_parity.jl`. It warns only when the mean field is **dynamically** unstable (`Im ω ≠ 0`), where ε_LHY is scheme-dependent for closed forms too. (The former "~3000× spurious offset at F=6 polar" was a UV counterterm subtracting ε_k twice — divergent at every F and phase, fixed 2026-07-27.) Prefer the closed forms when the state matches their ansatz: ~100× cheaper.
- **`secular_ddi=true` is user-chosen**, not auto. `make_workspace` `@info` advisory in secular regime.
- **`spin_rotating_frame_omega ≠ 0` requires `secular_ddi=true`** (enforced via `ArgumentError`). Full DDI's off-diagonal components Larmor-average to zero only in secular limit.
- **`even_c_extra(F; c2, c4, c6, …)` is canonical** — hand-written `[c2, c4, c6]` silently misindexes for F ≥ 3.
- CUDA-Graph in `ext/SpinorBECCUDAExt/gpu_graph.jl` disabled (replay drift, 4× slower); `split_step_captured!` itself was deleted 2026-05-22.
- **Spinor LHY tables are built for ONE spinor and applied at every voxel** — `:full_bdg` takes the peak-density spinor, the closed forms assume their own fixed ansatz. Exact for a uniform state; measured ~5% in ε_LHY on converged weak-field Eu textures, with a sign that FLIPS along a B-scan (so it does not cancel in a comparison). Only the magnitude of ⟨F⟩ matters — a pure direction texture (flower / spin vortex / skyrmion, all |⟨F⟩|/F = 1) is free, since ε_LHY is an SO(3) scalar for contact and moves 0.25% under the DDI. `make_workspace` warns above a |⟨F⟩|/F spread of 0.3 (`test/workflow/test_lhy_texture_warning.jl`). Spatially-varying LHY is not implemented.
- **Tensor c2/c4 not in `energy_gradient!`** — LBFGS warns, falls back to ITP. `[KNOWN-LIMIT]`.
- **TDHFB has no YAML pipeline integration.** `dynamics.tdhfb` does NOT exist. Engine parallel-track to GP; do not wire in without explicit ask.

## Adding common artifacts

| Adding… | Where | Enforced by |
|---|---|---|
| Hamiltonian term | `src/hamiltonian/terms/<name>/` (faces in `<name>_term.jl`, engine kernels alongside; single-file terms stay `terms/<name>.jl`) + register in `build_h_terms_registry` + `H_TERMS_CANONICAL_ORDER` + a dumb statement slot in `validation/dumb_reference.jl` (set-equivalence meta-test enforces) | Oracle suite (above) + master oracle. |
| YAML analyzer | `src/workflow/experiments/analyzers/<name>.jl` + dispatch in `_run_analyzer` | Analyzer name = real function, not stub alias. Round-trip `analyze: [{<name>: {}}]` should produce data labelled `<name>` literally. |
| State init | `src/workflow/initialization/state_zoo.jl` wrapper around `init_psi(state=:..., init_state_params=...)` | Same physics, named API. Don't fork `init_psi`; wrap. |
| Pipeline step kind | `pipeline/pipeline_types.jl` (struct) + `pipeline/run_step_<kind>.jl` (handler) + branch in `_step_dispatch!` | `_step_dispatch!` branch is the inference firewall — keep `@nospecialize(step)`. |
| Validation spec | `src/workflow/validation/specs.jl` (struct + `check` method) | Per-observable bounds + `CheckResult`; failed checks must not throw. |
| BO objective | Closure to `bayesian_optimize_yaml(...; objective=...)` or new `bo_objective_<name>` in `optimization/bayesian_opt_yaml.jl` | Signature: `(result) → Float64`. Keep closures monomorphic in hot loops. |
| Autopilot recipe | `src/workflow/autopilot/recipes.jl` (on_complete callback) | Bounded by `on_complete_max_descendants`; outcome.toml classification; trust-store records per recipe. |
| Manuscript figure | `src/manuscript/figures/<paper>_FIG<N>.jl` + register | CLI: `scripts/cli.jl figure --paper <p> --fig <n>`. Emitters: CSV / Python / TikZ. |
| Atom species | `src/workflow/initialization/atoms.jl` + entry in `ATOM_REGISTRY` | Constraint `c₀ + 36 c₁ = 4π(a_s/a_ho)N` for F=6 — see "¹⁵¹Eu". |
| Schema key | `src/workflow/experiments/schema/<block>.jl` + `auto_defaults.jl` if it has a sensible default | `inspect_config` should classify malformed values as `:error`/`:warn`, not silently accept. |

## ¹⁵¹Eu

F = 6, g_J = 1.9934, g_F ≈ 1.163, μ ≈ 6.977 μ_B, a_s ≈ 110 a₀. 7 unknown scattering channels (S = 0, 2, …, 12). Constraint: `c₀ + 36 c₁ = 4π(a_s / a_ho) N`.

## Constraints

- Cross-cutting structs live in `src/foundation/types/` (loaded first); subsystem-local structs co-locate with their machinery. `types/` is the default home, not an invariant.
- Workspace has 23+ type params — never write explicit type params.
- D=13 (Eu): `SMatrix` heap-allocates. Use `Matrix` / `MVector` in hot loops.
- `Val(N)` from a type parameter, not `Val(ndim::Int)`.
- `@noinline _step_dispatch!` with `@nospecialize(step)` is load-bearing inference firewall in `pipeline/runner.jl` — do NOT remove or specialize through.

## Naming convention

Semantic mismatch is not type-visible — static analysis cannot catch file/function/observable drift.

- **File name = primary export.** `src/foo/bar.jl` defines `bar`, `apply_bar_step!`, `BarLHY`. Rename file in same commit as its primary symbol.
- **Function name = what the body actually computes.** Renames delete the old name; no `const Old = New` aliases by default; migrate callers in same commit.
- **YAML analyzer names = real implementations**, not stub aliases. Aliased dispatch through unrelated functions is a silent-bug factory.
- **Backward-compat aliases default to "delete".** Keep one only with load-bearing documented external consumer.
- **No version suffixes** (`eu_ham_only_24_nonsec`, not `step5_v2`). Name by content.

## Type stability boundaries

`Workspace` has 23+ type params; `run_pipeline` dispatches abstractly on `PipelineStep`. Type widening propagates into Workspace specialisation → multi-minute JIT hang with no stack trace. Three rules:

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

3. **Keep `@noinline _step_dispatch!(@nospecialize(step), ...)` as the inference firewall** between `run_pipeline` and `_run_step`. Without it, binary GP path's return-tuple type hits combinatorial explosion across `PipelineStep` subtypes.

**Debug procedure** when JIT hangs:
- Direct-call the offending `_run_step(::ConcreteStep, ...)` — if fast, suspect abstract dispatch propagation from `run_pipeline`.
- Check recent additions for `Dict{Symbol,Any}` extractions or closure creation reaching `make_workspace`.
- `Cthulhu.descend(run_pipeline, (typeof(config),))` for deep inspection.

**User-supplied callbacks** (live_monitor `extract_observables`, simulation `SimulationCallbacks.on_step`) accept `::Function` — OK in cold paths; hot-loop callbacks must parameterize: `struct Cb{F1,F2} ...`.

## Cost model + execution discipline

Cost regime is permanent: this codebase pays a JIT cascade because Workspace is heavily-specialized and `make_workspace` is the hot path for every pipeline step.

- **JIT cascade**: trivial `run_yaml` for 32-pt 1D ground-state pays multi-minute first-output, dominated by `make_workspace` + `find_ground_state` specialization. Inner-loop tests use `SPINORBEC_RUN_HEAVY_YAML` guards.
- **F32 first-JIT** (rotating_basis): ~10 min, then cached.
- **30-min hang regime**: `Dict{Symbol,Any}` or closure escape into Workspace path. Silent inference explosion.
- **GPU split**: WSL2 consumer card for audits / dashboard / smoke (< 2 h). TSUBAME (`UGEBackend`) for multi-cell sweeps, dynamics 128³+, seed × cell arrays (`docs/guides/tsubame.md`).
- **Smoke-test discipline**: before any > 10 min launch, render with `--smoke` (low ITP step count, every code path, ≤ 2 min on GPU). CPU success ⇏ GPU works. Verify state symbols + kwargs by grep first.
- **Background long jobs**:
  ```
  setsid nohup bash -c 'julia ...' > logs/x.log 2>&1 < /dev/null &
  disown
  ```
  Verify: `ps -o pid,ppid,sid,cmd -C julia` — `PID == SID` = session leader, survives Claude close.
- **Don't idle while a long-running task is in flight.** Background with `run_in_background: true` and start next independent task. Completion notifications are the signal; polling is wasted time.

## Memory ↔ CLAUDE.md split

- **CLAUDE.md** = *structural fixed-point*. Conventions + design rules surviving across incidents. Edited rarely.
- **Memory** = *per-incident layer*:
  - `feedback_*.md` — user norms (smoke-test discipline, never delete memory before verifying, never patch when root fix available, …).
  - `mistake_*.md` — errors with structural prevention.
  - `gotcha_*.md` — sharp edges (B_mag spherical form, `ip[n] ≠ g_S`, FG Wick rotation sign, TWA chaos, autopilot timer + JIT WSL crash, …).
  - `project_*.md` — active arc context (Eu phase diagram North Star, validation pivot, …). Decay fast.
  - `reference_*.md` — external systems pointers (TSUBAME 4, web stack, WSL2 networking, Caddy admin socket, dashboard auth boundary, …).
- **`MEMORY.md` index** is the always-loaded TOC.

When CLAUDE.md and a memory file disagree: **CLAUDE.md wins for structural questions** (conventions, architecture); memory wins for per-incident lessons (what specifically went wrong, what to verify). Cross-link with `[[name]]` from memory files when a new mistake should crystallise into CLAUDE.md.

## Quick facts

- Julia 1.12.6 at `/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia`.
- GPU runs: `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. ...`.
- `spin_matrices(F::Int)` takes the spin quantum number (e.g. 6 for ¹⁵¹Eu), NOT 2F+1.
- `|F/n|²` = density-weighted avg of `(f/n)²`, NOT `f²/n`.
- Ramp `:log` scale = time-warp `g(t) = log(1 + (e-1) t)`, NOT geometric. Scan `:log` IS geometric.
- `find_ground_state_lbfgs` returns an atomic NamedTuple **including `grad_norm`** (spine G, recomputed at the returned ψ — never trust disk-cached grad_norm).
- `_run_analyzer` needs `ws_prev` even on cache hit.
- `pipeline_runner.jl` doesn't forward `verbose` to ITP (loud); does forward to LBFGS (silent).
- `_cuda_reclaim_callback` runs between scan points.
- `rotating_basis_history` is multi-phase concatenated.
