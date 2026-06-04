# CLAUDE.md

Arbitrary-F spinor Gross–Pitaevskii simulator (split-step Fourier, 1D/2D/3D, CPU + CUDA, YAML-driven). Primary production target: ¹⁵¹Eu at F=6 (13 components). Internal units: ℏ = m = ω_ref = 1.

This file documents the **architectural commitments** that survive across incidents and refactors. What's here is *how the codebase wants to be operated on going forward* — not a snapshot of any particular sprint. Per-incident lessons live in the memory system; this file is the structural fixed-point those incidents accumulate into.

Anchors for orthogonal content:

- `README.md` — what the project does + usage.
- `docs/index.md` — documentation map (guides / reference / design / theory / research_notes / manuscript / validation / api).
- `docs/reference/{yaml_schema_reference,dynamics,architecture}.md` — full YAML schema + dynamics knobs + module data flow.
- `docs/conventions/{sign_bug_proof_architecture,hamiltonian_sign_audit,adding_new_hamiltonian_term}.md` — physics convention authority + 14-term sign × path audit.
- Memory at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/` — `feedback_*` (user norms), `mistake_*` (errors + prevention), `gotcha_*` (sharp edges), `project_*` (active arcs), `reference_*` (external systems).

`AGENTS.md` is a stale fork using pre-rename names (`nematic`, `TwoChannelLHY`) and predates the HamTerm protocol. Prefer this file.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                     # all tests at default tier
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test
julia --project=. -e 'using Pkg; Pkg.instantiate()'               # install deps
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.                # GPU REPL on WSL2
julia --project=. scripts/cli.jl <subcmd> [args]                  # unified CLI (inspect / launch / figure / preflight / autopilot / tag / catalog / tsubame)
```

`SPINORBEC_TEST_TIER` ∈ `{fast, ci, full, physics}`. Tier membership is **explicit in `test/runtests.jl`** — every test belongs to exactly one list. New tests get added to a list, not auto-discovered.

## Project structure

```
src/
├── SpinorBEC.jl               # umbrella module
├── foundation.jl              # types (Grid, Workspace, AbstractPotential…) + math primitives + backend dispatch + Clebsch-Gordan + spherical harmonics
├── hamiltonian.jl             # interactions/ (c0/c1 + singlet_pair + tensor + DDI + LHY family) + potentials/ + terms/ (HamTerm) + integrator/ (split_step + Yoshida + composers + Coriolis + adaptive + rotating_basis) + tdhfb/
├── analysis.jl                # observables + energy + currents + vorticity + tomography/Faraday/imaging + topology + Fisher + spin_rotation + phases/ (Bogoliubov + sign-pattern + F6 diagram + polyhedral classifier)
├── solvers.jl                 # ground_state + lbfgs + continuation/{1d,2d,boundary,arclength,triple_point} + simulation + adaptive + TWA + binary + scalar_egpe + projected_gp + photon_heating + sgpe
├── manuscript.jl              # figure registry (CSV / Python / TikZ emitters keyed by (paper, FIG-N))
├── validation/reference_rhs/  # independent term-by-term Hψ — diff oracle for the self-contained validation chain
├── dynamics/                  # Sinatra TWA-validity helpers + resolution heuristics
└── workflow/
    ├── initialization.jl      # atoms (ATOM_REGISTRY) + init_psi dispatch + state_zoo (22 named builders) + make_workspace + thermal/vacuum noise + Thomas-Fermi
    ├── io.jl                  # save_state + Units submodule + budget + run_summary + html_report + vtk_export (weak ext) + catalog + cluster
    ├── monitoring.jl          # logging + LiveMonitor JSON status + ASCII plots + Slack/desktop notifications + progress + resource monitor
    ├── experiments.jl         # YAML schema (lab-units + templates + mixins + defaults + B-block + noise-block + auto-defaults) + runtime helpers + analyzers + pipeline runner
    ├── experiments/calibration.jl    # `module Calibration` — lab-units preprocess + week-to-week drift sampling
    ├── experiments/optimization.jl   # `module Optimization` — Bayesian opt + multi-fidelity + active-learning phase scan + Faraday fit
    ├── experiments/{inspect,inspect_batch,diff_dicts}.jl  # config introspection + structural diff + 4-severity warnings
    ├── experiment.jl          # Experiment lifecycle (spec + CAS outdir + lazy obs memo)
    ├── validation.jl          # RunResult + ConservationSpec / OperatorRHSSpec + CheckResult + twin_audit + scalar_summary
    ├── io/dashboard.jl        # `module Dashboard` — HTTP/WS server + routes + compute helpers + binary packers (bitshuffle + zstd)
    └── autopilot.jl           # queue + tick + on_complete + retry + budget + breakers + UGE backend + observability + Day-1 recipes + trust gradient

ext/        SpinorBEC{CUDA, Makie, HTTP, VTK}Ext (weak-dep extensions)
test/       subdirs mirror src/ + test/oracles/ (sign-bug-proof gates) + test/helpers/
scripts/    one-off audit drivers (m1_*, m2_*, fisher_*, build_sysimage*, cli.jl, deploy_dashboard_auth.sh)
dashboard/  React + WebGPU frontend (Vite + R3F + Three WebGPU + TSL + leva + shadcn + Tailwind v4)
runs/       YAML configs + per-config jld2 cache + `_loop/` autonomous-research-loop record
docs/       api/ architecture/ conventions/ design/ guides/ reference/ refs/ research_notes/ theory/ validation/ manuscript/
bench/      benchmarks
```

Umbrella files `Foo.jl` `include` sub-files in dependency order; public exports live next to definitions. **Real submodules** (`module Foo`; re-exported at umbrella): `Units`, `Calibration`, `Optimization`, `Dashboard`. Promote to `module` when the subsystem has an independent design lifecycle and benefits from namespace isolation; otherwise stay flat-namespace inside `SpinorBEC`.

**Cross-layer dispersal is the default for new subsystems**: a feature that touches storage / physics / analysis / pipeline goes into each layer rather than as a vertical slice. The rotating-basis path is the worked example — its files live under `foundation/`, `hamiltonian/integrator/`, `analysis/`, `workflow/experiments/analyzers/`, `workflow/experiments/pipeline/run_step_rotating/` — even though it started as a vertical slice. Plan new subsystems for this shape from day one.

## Architectural commitments

These are the design rules that shape what "correct work" looks like. When in doubt, the commitment wins over the apparent shortcut.

1. **Arbitrary-F spinor first, F=1 special case last.** Every closed form, every observable, every analyzer is built for general F. ¹⁵¹Eu (F=6, 13 components) is the production target; F=1 is a debugging convenience, not the focus.
2. **Composable physics modules.** Each Hamiltonian term, loss channel, and noise source is an independent unit that composes via the split-step sandwich or as a callback. No god-functions.
3. **Single source of truth per sign convention.** Every Hamiltonian term declares its sign in ONE coefficient function; propagator / CPU energy / GPU energy / gradient all derive from it. Bug class "manual N-place duplication of the same physics drifts out of sync" is structurally eliminated for energy and gradient paths; the directional discipline is enforced by the oracle test suite.
4. **Content-addressed computation.** `Experiment(spec)` → `<store.root>/<sha256(canonical_bytes(spec))[1:16]>/`. Users never name an outdir. Collection ops (`sweep`, `twin`, `tabulate`, `spec_diff`) fall out of `Vector{Experiment}` + the spec primitive — they are not new concepts.
5. **YAML-disk + DSL-memory duality.** Every spec is both YAML-serialisable (resumable disk form via `run_yaml`) and Julia-constructible via the DSL (`config([ground_state(...), dynamics(...), analyze(...)])`). Sweeps and tests use the DSL; production runs use YAML.
6. **Layered validation.** Code correctness (A: oracle tests + GPU=CPU + Hψ self-consistency) ⊥ physics agreement (B: closed-form limits + F=1 polar/FM + polyhedral classification) ⊥ model fidelity (C: comparison to published experimental data). Never conflate. The self-contained chain (A + B) plus reference-RHS oracle holds correctness claims without depending on external code.
7. **Tier-gated tests with explicit lists.** `fast` (pure units, must stay quick) / `ci` (+ integration + all oracle gates) / `full` (+ heavy ITP/RTP/BO/GPU) / `physics` (analytic-only subset). Heavy YAML tests live behind env-var guards so the inner loop stays fast.
8. **Type stability firewalls at dispatch barriers.** `Workspace` has 23+ type parameters; `Dict{Symbol,Any}` or closures escaping into Workspace paths cause inference to explode (multi-minute JIT hang with no stack trace). The `@noinline _step_dispatch!(@nospecialize(step), ...)` in `pipeline/runner.jl` is the load-bearing inference firewall — do NOT specialize through.
9. **Convention discipline over backward compat.** File name = primary export; function name = what the body actually computes; YAML analyzer name = the real implementation, not a stub alias. Renames delete the old name and migrate callers in the same commit; no `const Old = New` aliases by default; no version suffixes in names (name by content).
10. **Cost-aware execution.** A trivial `run_yaml` pays a multi-minute JIT cascade; mixed-precision F32 first-JIT is ~10 min; closure-escape into Workspace triggers a 30-min hang. Smoke-test (`--smoke` rendering of every code path in ≤ 2 min) before any > 10 min launch. CPU success does not imply GPU works. Background long jobs; don't poll.

## Workflow model (spec → CAS → run → observe)

Four primitives:

1. **`spec`** — YAML-shaped `Dict`. Built via the DSL in `experiments/runfactory.jl` (block builders `B`, `ddi`, `lhy`, `loss`, `save`, `ramp`, `rate` and step builders `ground_state`, `dynamics`, `analyze` mirror YAML keys 1:1) or loaded from a YAML file.
2. **CAS outdir** — `content_id(spec)` is pure: deterministic across dict-iteration order, Julia version, YAML round-trip. Same spec ⇒ same outdir, anywhere.
3. **`Experiment(spec)` lifecycle** — `(spec, store, memo)` triple. `run!(exp)` idempotent (skips when `result.jld2` / `point_001.jld2` exists). Observables are plain functions on `Experiment` (`Fz_t`, `Lz_t`, `energy_t`, `peaks`, `populations_t`, `classify`, `density(exp, t)`, `psi(exp, t)`, `density_stats_at`, `integrator_meta`, …) that memoize in `exp.memo`.
4. **Collection ops as derivatives**:
   - `sweep(base; over=:path => values)` → `Vector{Experiment}`.
   - `twin(exp)` → sibling with `lhy: none` + `loss` removed (A/B control).
   - `tabulate(exps, [Fz_t, classify, norm_drift])` → per-cell column NamedTuple; failed cells slot in the Exception so the table assembles.
   - `spec_diff(a, b)` → dotted-path diff. Powers twin verification, sweep-axis discovery, compare provenance.

`run_yaml(path)` is the disk form: resumable, directory-per-config, one jld2 per scan point, skips cached files on re-run, auto-applies `calibration:` preprocess, writes `_live_status.json` + `_exit_summary.json` for the autopilot.

`load_config(path) |> run_config` is the non-resumable in-memory form.

**Spec-driven validation** (`workflow/validation/`):
- `RunResult` = typed view over a jld2 (`psi`, `hpsi?`, `grid`, `atom`, `interactions`, `dynamics::DynamicsTimeSeries?`, `e_decomp`, `metadata`).
- `ConservationSpec(; norm_drift=…, energy_rel_drift=…, Jz_drift=…)` — bounds on `RunResult` observables; `check(spec, r) → CheckResult`.
- `OperatorRHSSpec(; tol_hpsi=…, tol_per_term_E=…)` — Level-10 A/B operator-RHS diff via `RunComparison`; requires both runs to have saved `Hψ`.
- `audit(exp; spec=ConservationSpec())` = `run!` + `check`. 1-liner for "this spec must conserve".

## Subsystem catalog

Each row is a permanent role in the system, not a snapshot.

| Subsystem | Role | Discipline |
|---|---|---|
| **foundation/types/** | All structs (`Grid`, `Workspace`, `AbstractPotential` + 12 subtypes, spin / atom / Zeeman / Raman / FFT / DDI / Loss / LightShift / TensorCache / Integrator config / SimulationResult / TWA / TOF / BdG / scan / checkpoint / TDHFBState …). | New structs go here first. `Workspace` type params are derived — never write explicit. `Val(N)` comes from a type parameter, not `Val(ndim::Int)`. |
| **hamiltonian/interactions/** | c0/c1 + singlet_pair + tensor + DDI (k-space 6-FFT convolution + Euler 5-stage spinor rotation + secular option + zero-padded variant) + LHY (closed forms + φ₁-reg + Modes-round-45 + Sigma-Delta polar F1-F8/FM F6 dispatch + Lima-Pelster Q5) + losses + absorbing_boundary. | Two interaction paths auto-selected in `make_workspace` (c₀/c₁ vs scattering-lengths). |
| **hamiltonian/potentials/** | Trap + Zeeman (Linear z + Quadratic z + Transverse x/y + time-dep) + Raman + Gaussian-beam optics + laser_potential + optical_trap + light_shift. | Unified `B:` block in YAML; Zeeman sign source-of-truth is `H_Zeeman = -(g_F μ_B B · F) + q F_z²` declared at `experiments/runtime/b_block_builders.jl`. |
| **hamiltonian/terms/** | **HamTerm protocol.** Each term — Kinetic, Trap, LinearZeemanZ, TransverseZeeman, DensityC0, SpinC1, DDI, LHY, Tensor, Raman, LightShift, Coriolis, MagneticGradient, Loss — declares its sign in ONE coefficient function; `apply_step!` / `energy_contribution` / `add_gradient!` / `sign_oracle` derive from it. `build_h_terms_registry(ws) → NTuple{N, HamTerm}` is type-stable and unrolled. | New H terms go here. The registry pattern is **load-bearing for the bug-class elimination** — do NOT bypass for new physics; do NOT introduce parallel sign declarations. |
| **hamiltonian/integrator/** | Split-step + adaptive Yoshida + Coriolis 3-shear + Yoshida/Suzuki/Blanes-Moan composers + force_gradient + combined_spin_step + dealias + adaptive-dt + rotating-basis propagators/integrators. | `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)` Strang sandwich. `_YOSHIDA_W0 < 0` is correct (backward middle substep; all operators time-reversible). |
| **hamiltonian/tdhfb/** | Time-Dependent HFB local-approximation engine — voxel-local BdG Strang step (channel kernel + HF self-energy + Δ from φφ + κ) + Y4-midpoint Picard wrapper + total-energy functional conserved by the step. | Engine is **parallel to GP**; YAML pipeline integration deferred. Do NOT wire `dynamics.tdhfb` into `run_yaml` without explicit ask. |
| **analysis/** | observables + energy_decomposition + currents + vorticity + vortex_extraction + diagnostics + Majorana stars + icosahedral order + TOF + tomography + Faraday + imaging + Fisher + topology (winding / monopole / holonomy) + synthetic_dimension + time_resolved + stability_analysis + spin_rotation. | `_get_spinor(psi, I, Val(13))` allocates 352 B/call at D=13 (SROA elides inside hot loops). Use `Matrix` / `MVector` in hot loops; `SMatrix` heap-allocates at D=13. |
| **analysis/phases/** | phase_classification + phase_boundary + Bogoliubov spectrum + scan + sign_pattern + F6 phase diagram + polyhedral classifier (σ_S fingerprint + direct ΔE) + canonical polyhedral states. | Bogoliubov k=0 Goldstone μ convention: `omega[:, 1]` is the column index for k-mode 1, NOT `omega[1, :]`. |
| **solvers/ground_state + lbfgs** | ITP (`find_ground_state`) + checkpoint + adaptive + advanced (multistart + Jz-constrained) + LBFGS with Sobolev preconditioner. | ITP Zeeman shift subtracts `min(E_m)` to prevent overflow. `find_ground_state_lbfgs` returns `(workspace, converged, energy, dE, last_step)` — no grad_norm. Tensor c2/c4 falls back to ITP with `@warn`. |
| **solvers/continuation** | scan_1d + scan_2d + boundary tracing + pseudo_arclength + triple_point. | `make_params(val)` returns kwarg NamedTuple or `InteractionParams`. Legacy `make_interactions` removed; pass via `make_params`. |
| **solvers/simulation + twa + sgpe + projected_gp + photon_heating + binary** | RTP (`run_simulation!`) + adaptive + embedded-adaptive + Truncated Wigner + SGPE callback (true thermal init) + projected GP + photon scattering + two-component GP. | TWA σ/μ is chaotic-dipolar divergence, NOT classical thermalization. |
| **workflow/experiments/{schema,runtime,analyzers,pipeline}** | YAML compile (units + templates + mixins + defaults + B-block + noise-block + auto-defaults + ε hardening) + runtime helpers (b_block_builders, pulse_sequence, STA counter-diabatic, Feshbach ramp) + analyzers + pipeline runner. | `_step_dispatch!` has `@noinline` + `@nospecialize(step)` — the inference firewall. Removing or specializing through it triggers a multi-minute JIT cascade on the binary GP path. |
| **workflow/autopilot/** | Queue + tick + 2-stage submit + LocalBackend + UGEBackend (TSUBAME) + budget cap + circuit breakers (recipe / lineage / rate / kill) + on_complete recipe lineage + retry + qw_history + trust gradient + Day-1 recipes (next_random / refine / analyze) + failure_analysis + profile_recommend + observability. | TSUBAME uses UGE not Slurm; `qsub -g <group>` is CLI flag not directive. `dry_run` and `pause` are persisted file sentinels (`.autopilot.dry_run`, `.autopilot.paused`). UGE backend auto-registers from `SPINORBEC_TSUBAME_{HOST,PROJECT_ROOT,RUNS_ROOT,…}` env. |
| **workflow/io/dashboard/** | `module Dashboard`. HTTP server + WebSocket + binary packers + JLD2 cache. Routes for density / phase / vortex / scan / catalog / sweep / autopilot queue / budget / inspect / tags. | Caddy admin via Unix socket; oauth2-proxy `hd=isct.ac.jp` admits whole tenant — default to `authenticated_emails_file` anko-only. |
| **workflow/experiments/optimization.jl** | `module Optimization`. `bayesian_optimize` + `multi_fidelity_optimize_2tier` + `active_learn_phase_scan` + GP/EI + Faraday fit. YAML and direct-Julia entry points; built-in objectives `bo_objective_{max_m_transfer,max_lz,min_energy}` + custom via closure. | GP fitting > 100 s wall ⇒ heavy-tier only. |
| **workflow/experiments/calibration.jl** | `module Calibration`. CoilCalibration + FORTCalibration + RabiCalibration + CalibrationHistory (CSV + week-to-week interpolate) + drift sampling. | Lab fields like `B: {p_mv: 2.5, coil_mode: strong}` resolve via calibration table to Gauss **before** downstream parsing. |
| **workflow/initialization + state_zoo** | atoms + `init_psi` dispatch + 22 named `init_psi_<name>` wrappers + Thomas-Fermi + heuristic thermal seed + TWA vacuum noise. | Wrap, don't fork: every named state is `init_psi(state=:..., init_state_params=...)` under the hood. For `:transverse_x` use `init_psi_spin_coherent(grid, sys; theta=π/2, phi=0)`. For true thermal init use the SGPE callback. |
| **manuscript.jl + manuscript/figures/** | Figure registry keyed by (paper, FIG-N). Emitters: CSV / Python / TikZ. CLI via `scripts/cli.jl figure --paper <p> --fig <n>` or `--list`. | Paper #1 = F-generic LHY closed forms; Paper #2 = F6 phase diagram; Paper #3 = Sign Pattern Lemma 1 + Universal Theorem; thesis Ch.1-7 in `docs/manuscript/thesis/`. |
| **validation/reference_rhs/** | Independent term-by-term `reference_<term>_apply!` and `reference_<term>_energy` with the *same* numeric prefactor as production. Used as diff oracle. | Holds the self-contained validation claim. External Ueda comparison is `BLOCKED_EXTERNAL` (no active channel) — see `docs/validation/ueda_status.md`. |
| **`.claude/` + `runs/_loop/`** | Autonomous research-loop infrastructure. `.claude/scripts/loop.sh` drives turns as `claude -p /run-loop`. State in `runs/_loop/state.json`; subdirs `conclusions/`, `sim/`, `judge/`, `debug/`, `critic/`, `director/`, `by_subagent/`, `by_paper/`, `by_tag/`, `regression/`, `research/`, `patterns.yaml`, `schedule.yaml`. | OAuth (Max plan) only — `loop.sh` aggressively unsets `ANTHROPIC_API_KEY`. |

## Wavefunction conventions

**Layout**: `psi[x, y, …, c]`. Spatial dims first, spinor last. `c=1 → m=F`, `c=D → m=−F`.

**Split-step**: `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`. Inner V is symmetric `diag SM singlet_pair tensor raman DDI raman tensor singlet_pair SM diag`. Substeps auto-skip when their coupling ≈ 0.

**Two interaction paths**, auto-selected in `make_workspace`:
- **c₀/c₁ path**: `diagonal(c₀) + spin_mixing(c₁) + singlet_pair(c₂) + tensor(residual c₄, c₆, …)`.
- **Scattering-lengths path** (Cr52 etc.): tensor handles ALL channels, `c₀ = c₁ = 0`.

**YAML schema**: parameter variation is a **config path override** — dotted path into the raw YAML dict (e.g. `pipeline.0.ddi.c_dd`) mapped to a new value. Full reference: `docs/reference/yaml_schema_reference.md`. The unified `B:` block accepts `{Bz, theta, phi}` or `{p_mv, coil_mode}` for lab-units; `q` auto-derives from |B|² unless explicit. Lab-units features (`units:`, `accuracy:`, `auto_grid:`, `template:`, `mixins:`, `defaults:`, ε hardening) are OPT-IN.

**Mixed precision** (rotating_basis only): `dtype: f32` in `ground_state` plumbs Float32 through Grid / V_trap / Workspace / FFT plans / DDI buffers. F64 is the default. First-time JIT for the F32 specialisation is ~10 min, then cached. `apply_uniform_spin_rotation!` + `apply_ddi_step!` + `apply_spin_mixing_step!` keep scalar Float64 locks (rotation builder + DDI dt + c1·dt); array work stays F32.

**Noise**: both GS `temperature_ratio` and `dynamics.temperature_ratio` drive a **heuristic** symmetry-breaking kick (amplitude `η = √((T/T_c)³/4)`, BEC-scaling), via `add_thermal_seed(psi, F; T_over_Tc, seed)`. NOT a true thermal Wigner sample. For true thermal init use the SGPE callback.

**Calibration**: lab-unit YAML preprocess auto-applied by `run_yaml`. Use `calibration:` for a single block or `calibration_history:` for week-to-week interpolation.

**`phi_omega` Hz form**: `phi_omega: 4.524` (dimensionless ω/ω_ref) and `phi_omega: "226.2 Hz"` are equivalent; Hz converts via `(2π·f) / ω_ref` using parent `interactions.omega_ref`. Eliminates the Klaus 2022 magnetostir 2π footgun.

**LHY config**: single `lhy:` block inside `ground_state`. `kind` ∈ `{scalar, quasi_2d, polar_two_channel, full_bdg, polar_contact, polar_dipolar, fm_contact, fm_dipolar, icosahedral, none}`. Auto-derive `c_lhy` for `scalar` / `quasi_2d`. Legacy keys (`interactions.c_lhy`, `ground_state.spinor_lhy`) are deleted.

**GPU**: `import CUDA` before `using SpinorBEC` loads the extension. Pass `backend=CUDABackend()`. WSL2 needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib`. CUDA ext mirrors CPU per-term implementations (energy / singlet_pair / tensor / spin_mixing / Raman / normalize / Euler kernel / TDHFB Phase 5a-5c). `gpu_graph.jl` is disabled — replay drift from per-call broadcast allocations (4× slower in bench).

## Sign-bug-proof discipline (HamTerm protocol)

The historical pattern that motivated the protocol: same physics expressed in N hand-duplicated locations; one drift, others stay correct, tests still pass. Linear z-Zeeman alone used to live in 8 places. The forward-looking commitment is that this cannot recur:

- **One sign declaration per term.** `_diag_coef(term, m)` or `_h_matrix(term, sm)` or `_<op>(term, …)` — pick one, put it at the top of `src/hamiltonian/terms/<term>.jl`, derive everything else.
- **All paths via the registry.** `apply_step!` (propagator) / `energy_contribution` (CPU + GPU) / `add_gradient!` (LBFGS) call the same coefficient function. Cannot drift relative to each other.
- **Inactive terms short-circuit at top of each method.** Registry is always `NTuple{N, HamTerm}` (type-stable, compiler-unrolled); zero per-call cost for inactive terms.
- **Shared scratch via `EnergyContext` / `GradientContext`.** The context-aware overloads reuse pre-built density / spin density / FFT buffer across terms in one pass. New terms that benefit from shared scratch should provide the `ctx`-aware specialization; the default fallback to the no-ctx variant is correct but loses sharing.

**Source of truth**: `H_Zeeman = -(g_F μ_B B · F) + q F_z²` declared at `src/workflow/experiments/runtime/b_block_builders.jl`. Every other Zeeman reference derives from there.

**Adding a new HamTerm — protocol**:

1. Create `src/hamiltonian/terms/<your_term>.jl` with `struct <YourTerm> <: HamTerm`.
2. Declare the sign convention in ONE coefficient function.
3. Implement `apply_step!` / `energy_contribution` / `add_gradient!` from it. Delegate to existing audited routines (`_apply_coriolis_step!`, `apply_kinetic_step_batched!`, etc.) when possible.
4. Provide `sign_oracle(::Type{<YourTerm>})` returning `(name, predicate)` — a directional physics observable that the *correct* sign produces (FM `⟨|F|²⟩=F²` vs polar 0, prolate vs oblate, `⟨F_z⟩>0` under `+p`, etc.). A predicate that returns `true` regardless is a placeholder, not an oracle.
5. Register in `src/hamiltonian.jl` include list AND `build_h_terms_registry` AND `H_TERMS_CANONICAL_ORDER`.
6. Add a directional test to `test/oracles/test_hamiltonian_sign_oracles.jl`. If the term has `sign(E) = sign(c)·X²` shape (X² ≥ 0 makes the test tautological), additionally add a physics-anchored oracle to `test/oracles/test_physics_aware_sign_oracles.jl`.
7. Run the oracle suite — every gate must pass:
   - `test_term_consistency.jl` (FD oracle: `add_gradient!` ↔ FD of `energy_contribution`).
   - `test_gpu_cpu_per_term_parity.jl` (per-term GPU↔CPU; closes the blind spot where a term contributes zero in the aggregate test).
   - `test_registry_{energy_decomposition,gradient,strang_step}_parity.jl` (registry vs hand-written bit-identity).
   - `test_magnetic_gradient_gap.jl` style: per-term audit gate when the term has a non-obvious path (transverse, off-diagonal, propagator that mutates V).

Full procedure: `docs/conventions/adding_new_hamiltonian_term.md`. Audit table: `docs/conventions/hamiltonian_sign_audit.md`.

## Test taxonomy + oracle gates

Tier membership is **explicit in `test/runtests.jl`**. The file is the source of truth — there is no auto-discovery.

**Oracle test families** under `test/oracles/`, each gating one bug class:

| Family | What it gates |
|---|---|
| `test_hamiltonian_sign_oracles.jl` | Directional physics per HamTerm: `+p ⇒ ⟨F_z⟩ > 0`, `+Ω ⇒ ⟨L_z⟩ > 0`, `+g_F·grad ⇒ ⟨x⟩ < 0`, etc. |
| `test_physics_aware_sign_oracles.jl` | Physics-anchored oracles for terms with tautology-shape directional tests (SpinC1, DDI, LHY, Tensor). |
| `test_term_consistency.jl` | FD oracle: `add_gradient!` vs finite-difference of `energy_contribution`. Catches energy ↔ gradient drift. |
| `test_gpu_cpu_per_term_parity.jl` | One-term-active GPU vs CPU `energy_decomposition` and `Hψ`. Forbids "term contributes zero in test config, so missing GPU path is invisible". |
| `test_registry_{energy_decomposition,gradient,strang_step}_parity.jl` | Registry path vs legacy bit-identity. |
| `test_term_legacy_equivalence.jl` | Per-term: new HamTerm `apply_step!` vs legacy routine. |
| `test_registry_collision_regression.jl` | HamTerm subtype names don't shadow potential types. |
| `test_magnetic_gradient_gap.jl` | Per-term audit for terms whose propagator mutates+restores V (so legacy energy reads the clean V and reports zero). |

**Other named regression gates**:
- `solvers/test_itp_ddi_strang_save_every.jl` / `solvers/test_rtp_ddi_strang_save_every.jl` — named after a specific historical bug; do not delete.
- `rotating_basis/test_rotating_frame_regression.jl` — round-by-round dispersal pins.
- `test_level0..level12*.jl` — validation-ladder anchors.

**Heavy YAML integration tests** live behind `SPINORBEC_RUN_HEAVY_YAML=true` so the inner-loop tier doesn't pay the JIT cascade on every push. The nightly workflow flips the flag.

## Validation ladder

13 levels, each with a tier-3 instrument under `test/`. The ladder is the structural answer to "how do we know the code is right?".

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

Reports must say which type a claim falls under. "Tests pass" is A; "matches Klaus 2022" is C; do not conflate.

## Autopilot pattern

Stateless meta-loop over the queue. The pattern is permanent; specific recipes and breakers come and go.

- **Two-stage submit**: mark `:running` + `job_id=nothing` + fsync; backend dispatch sets `job_id`; save_entry with real `job_id`. Crash between stages is recoverable via `find_job_by_name`.
- **Backends**: `LocalBackend` (subprocess) + `UGEBackend` (TSUBAME ssh + rsync), auto-registered from env triple.
- **Pre-flight inspector**: 4-severity (`:block` → killed_bug, `:error` → recorded, `:warn` → Slack, `:info` → silent).
- **Budget gate**: quarter + daily GPU·h caps, refreshed from realized hours, checked once per tick.
- **Circuit breakers**: recipe / lineage / rate / kill — trip auto-pauses + Slack-alerts.
- **Persisted sentinels**: `.autopilot.dry_run` and `.autopilot.paused` files — toggle via CLI or dashboard without restart. Dry-run still fires on_complete recipes (exercises lineage end-to-end).
- **On_complete recipes**: bounded recipe lineage (default `on_complete_max_descendants=64`). `next_random` / `refine` / `analyze` are the Day-1 set.
- **Divergence kill**: reap loop watches `_live_status.json`, cancels divergent runs, classifies `:killed_data`.
- **Failure classification**: `outcome.toml` → `:killed_data` (NaN divergence) or `:killed_bug` (OOM / TIMEOUT / NODE_FAIL). OOM is resource-permanent — retry escalates resource class, not the recipe.

**Autonomous research loop**: `.claude/scripts/loop.sh` drives turns. Each turn dispatches one subagent role (director / theorist / implementer / researcher / critic / judge). State + history persist in `runs/_loop/state.json`. Conclusions in `runs/_loop/conclusions/`. Critical: the script aggressively unsets `ANTHROPIC_API_KEY` so OAuth (Max plan) is forced — never API billing.

## Conventions (do NOT "fix")

These are physics conventions that look "off" but are correct. Changing them silently breaks chained downstream code that assumes the convention.

- **DDI**: `c_dd = μ₀μ²` (no 4π), `Q_αβ = k̂_α k̂_β − δ_αβ/3` (no 1/(4π)), `Q(k=0) = 0`. Chain is self-consistent.
- **ITP Zeeman shift**: subtracts `min(E_m)` to prevent overflow.
- **Scalar LHY**: `@warn` present. Known approximation.
- **`_YOSHIDA_W0 < 0`**: correct (backward middle substep, all operators time-reversible).
- **Hamiltonian sign source-of-truth**: declared at `b_block_builders.jl:27`. Every other reference derives.
- **Odd-rank `c_extra` ignored** by design. Even-rank only via `even_c_extra(F; c2, c4, c6, …)`. Hand-written `[c2, c4, c6]` silently misindexes for F ≥ 3.
- **`compute_interaction_params_general_f` returns (0, 0)** by design (`tensor_cache` handles all).
- **`make_workspace` `@info` advisory** when `ω_L / (c_dd · ⟨n⟩) > 100`: secular DDI recommended. User-chosen, not auto. Eu experiments almost always live in that regime.

## Adding common artifacts — protocols

Each row says "where does the work go, what enforces correctness".

| Adding… | Where | Enforced by |
|---|---|---|
| Hamiltonian term | `src/hamiltonian/terms/<name>.jl` + register in `build_h_terms_registry` + `H_TERMS_CANONICAL_ORDER` | Oracle suite (see "Sign-bug-proof discipline" above). |
| YAML analyzer | `src/workflow/experiments/analyzers/<name>.jl` + dispatch in `_run_analyzer` | Analyzer name = real function, not stub alias. Round-trip via `analyze: [{<name>: {}}]` should produce data labelled `<name>` literally. |
| State init | `src/workflow/initialization/state_zoo.jl` wrapper around `init_psi(state=:..., init_state_params=...)` | Same physics, named API. Don't fork `init_psi`; wrap. |
| Pipeline step kind | `src/workflow/experiments/pipeline/pipeline_types.jl` (struct) + `pipeline/run_step_<kind>.jl` (handler) + branch in `_step_dispatch!` | The `_step_dispatch!` branch is the inference firewall — keep `@nospecialize(step)`. |
| Validation spec | `src/workflow/validation/specs.jl` (struct + `check` method) | Per-observable bounds + `CheckResult` shape; failed checks must not throw (keeps batch reports running). |
| BO objective | Closure passed to `bayesian_optimize_yaml(...; objective=...)` or new `bo_objective_<name>` in `optimization/bayesian_opt_yaml.jl` | Signature: `(result) → Float64`. Keep closures monomorphic if used in hot loops. |
| Autopilot recipe | `src/workflow/autopilot/recipes.jl` (on_complete callback) | Bounded by `on_complete_max_descendants`; failure classification via outcome.toml; trust-store records outcome per recipe. |
| Manuscript figure | `src/manuscript/figures/<paper>_FIG<N>.jl` + register | CLI: `scripts/cli.jl figure --paper <p> --fig <n>`. Emitters are CSV / Python / TikZ. |
| Atom species | `src/workflow/initialization/atoms.jl` + entry in `ATOM_REGISTRY` | Constraint `c₀ + 36 c₁ = 4π(a_s/a_ho)N` for F=6 etc. — see "¹⁵¹Eu". |
| Schema key | `src/workflow/experiments/schema/<block>.jl` + `auto_defaults.jl` if it has a sensible default | Round-trip through `inspect_config` should classify any malformed value as `:error` or `:warn`, not silently accept. |

## ¹⁵¹Eu

F = 6, g_J = 1.9934, g_F ≈ 1.163, μ ≈ 6.977 μ_B, a_s ≈ 110 a₀. 7 unknown scattering channels (S = 0, 2, …, 12). Constraint: `c₀ + 36 c₁ = 4π(a_s / a_ho) N`.

## Design boundaries — intentional non-support

These are NOT bugs; the codebase decided not to support them. Don't "fix".

- **`PolarTwoChannelLHY` is polar-only**, exact at F=1, ~1 % off at F=2, **30–70 % off at F=6** (pinned by `test_spinor_lhy.jl`). The two-channel reduction sums over (S=0, S=2) only — mathematically exhaustive only up to F=2. For F ≥ 2 polar use `PolarContactLHY` / `PolarDipolarLHY`; FM → `FMContactLHY` / `FMDipolarLHY`; F=6 I_h → `IcosahedralLHY`. The type name carries the polar-only constraint.
- **F=6 polar + `FullBdGLHY`** emits a `@warn` (~3000× spurious offset).
- **`secular_ddi=true` is user-chosen**, not auto. `make_workspace` emits `@info` advisory in the secular regime.
- **`spin_rotating_frame_omega ≠ 0` requires `secular_ddi=true`** (enforced via `ArgumentError`). Full DDI's off-diagonal components only Larmor-average to zero in the secular limit.
- **`even_c_extra(F; c2, c4, c6, …)` is canonical** — hand-written `[c2, c4, c6]` silently misindexes for F ≥ 3.
- **`split_step_captured!` on GPU silently falls back** to `split_step!`. The CUDA-Graph implementation in `ext/SpinorBECCUDAExt/gpu_graph.jl` is disabled (replay drift from per-call broadcast allocations).
- **Tensor c2/c4 not in `energy_gradient!`** — LBFGS warns and falls back to ITP. Marker `[KNOWN-LIMIT]`.
- **TDHFB has no YAML pipeline integration.** The `dynamics.tdhfb` block does NOT exist. Engine is parallel-track to GP; future Claude must not wire it in without explicit ask.

## Constraints

- All structs in `src/foundation/types/` (loaded first). New structs go there.
- Workspace has 23+ type params — never write explicit type params.
- D=13 (Eu): `SMatrix` heap-allocates. Use `Matrix` / `MVector` in hot loops.
- `Val(N)` from a type parameter, not `Val(ndim::Int)`.
- `@noinline _step_dispatch!` with `@nospecialize(step)` is the load-bearing inference firewall in `pipeline/runner.jl` — do NOT remove or specialize through.

## Naming convention

Static analysis cannot catch file/function/observable mismatches — semantic mismatch is not type-visible. Discipline:

- **File name = primary export.** `src/foo/bar.jl` defines `bar`, `apply_bar_step!`, `BarLHY`, etc. Rename file in the same commit when its primary symbol changes.
- **Function name = what the body actually computes.** Renames delete the old name; no `const Old = New` aliases by default; migrate callers in the same commit.
- **YAML analyzer names = real implementations**, not stub aliases. `analyze: [{foo: {}}]` returning data labelled `foo` should literally be the output of an entry point named `foo`. Aliased dispatch through unrelated functions is a silent-bug factory.
- **Backward-compat aliases default to "delete".** Keep one only if there's a load-bearing external consumer that can't be migrated; document the consumer at the alias definition site.
- **No version suffixes** (`eu_ham_only_24_nonsec`, not `step5_v2`). Name by content.

## Type stability boundaries

`Workspace` has 23+ type params and `run_pipeline` dispatches abstractly on `PipelineStep`. Type widening propagates into Workspace specialisation and causes inference to explode — symptom is a multi-minute JIT hang with no stack trace. Three rules:

1. **`Dict{Symbol,Any}` → concrete struct: isolate in a helper function with `::ConcreteType` assertions.** The function boundary keeps `Any`-typed locals out of `_run_step`; the type assertion narrows the return tuple. Never let `Any` flow into `make_workspace` kwargs directly.

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

2. **Never store closures in struct fields that flow into Workspace.** Each closure site has a unique type, multiplying specialization work. Pre-evaluate `t -> ...` to `PiecewiseLinearWaveform` / `InterpolatedWaveform` before storing.

3. **Keep `@noinline _step_dispatch!(@nospecialize(step), ...)` as the inference firewall** between `run_pipeline` and `_run_step`. Without it, the binary GP path's return-tuple type hits a combinatorial explosion across `PipelineStep` subtypes.

**Debug procedure** when JIT hangs:
- Direct-call the offending `_run_step(::ConcreteStep, ...)` — if fast, suspect abstract dispatch propagation from `run_pipeline`.
- Check recent additions for `Dict{Symbol,Any}` extractions or closure creation in paths that reach `make_workspace`.
- `Cthulhu.descend(run_pipeline, (typeof(config),))` for deep inspection.

**User-supplied callbacks** (live_monitor `extract_observables`, simulation `SimulationCallbacks.on_step`) accept `::Function` — OK in cold paths, but callbacks invoked in hot loops should parameterize: `struct Cb{F1,F2} ...`.

## Cost model + execution discipline

The cost regime is permanent: this codebase pays a JIT cascade because the Workspace is heavily-specialized and `make_workspace` is the hot path for every pipeline step. The disciplines below exist *because of* that cost, not in spite of it.

- **JIT cascade**: a trivial `run_yaml` for a 32-pt 1D ground-state step pays multi-minute first-output time on cold JIT, dominated by `make_workspace` + `find_ground_state` specialization. Inner-loop tests use `SPINORBEC_RUN_HEAVY_YAML` guards to opt heavy YAML integration in only on nightly.
- **F32 first-JIT** (rotating_basis): ~10 min, then cached.
- **30-min hang regime**: `Dict{Symbol,Any}` or closure escape into Workspace path. Not a runtime error; a silent inference explosion.
- **GPU split**: WSL2 consumer card for audits / dashboard / smoke (< 2 h). TSUBAME (`UGEBackend`) for multi-cell sweeps, dynamics 128³+, seed × cell arrays (`docs/guides/tsubame.md`).
- **Smoke-test discipline**: before any > 10 min launch, render the script with `--smoke` (low ITP step count, every code path exercised, ≤ 2 min on GPU). CPU success does NOT imply GPU works. Verify state symbols + kwargs by grep before writing.
- **Background long jobs**:
  ```
  setsid nohup bash -c 'julia ...' > logs/x.log 2>&1 < /dev/null &
  disown
  ```
  Verify: `ps -o pid,ppid,sid,cmd -C julia` — `PID == SID` means session leader, survives Claude close.
- **Don't idle while a long-running task is in flight.** Background with `run_in_background: true` and start the next independent task. Completion notifications are the signal; polling is wasted time.

## Memory ↔ CLAUDE.md split

- **CLAUDE.md (this file)** is the *structural fixed-point*. Conventions and design rules that survive across incidents. Edited rarely, and only when a new commitment crystallises.
- **Memory** at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/` is the *per-incident layer*:
  - `feedback_*.md` — user norms (smoke-test discipline, never delete memory before verifying, never patch when root fix is available, etc.).
  - `mistake_*.md` — errors with structural prevention.
  - `gotcha_*.md` — sharp edges in code (B_mag spherical form, `ip[n] ≠ g_S`, FG Wick rotation sign, TWA chaos, autopilot timer + JIT WSL crash, etc.).
  - `project_*.md` — active arc context (Eu phase diagram North Star, validation pivot, dashboard inspector lift, autopilot honest v1.1, etc.). Decay fast.
  - `reference_*.md` — external systems pointers (TSUBAME 4 scheduler, web stack, WSL2 networking, Caddy admin socket, dashboard auth boundary, etc.).
- **`MEMORY.md` index** is the always-loaded TOC.

When CLAUDE.md and a memory file disagree: **CLAUDE.md wins for structural questions** (conventions, architecture); memory wins for per-incident lessons (what specifically went wrong, what to verify). Cross-link with `[[name]]` from memory files when a new mistake should crystallise into CLAUDE.md.

## Quick facts

- Julia 1.12.6 at `/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia`.
- GPU runs: `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. ...`.
- `spin_matrices(F::Int)` takes the spin quantum number (e.g. 6 for ¹⁵¹Eu), NOT 2F+1.
- `|F/n|²` = density-weighted avg of `(f/n)²`, NOT `f²/n`.
- Ramp `:log` scale = time-warp `g(t) = log(1 + (e-1) t)`, NOT geometric. Scan `:log` IS geometric.
- `find_ground_state_lbfgs` returns `(workspace, converged, energy, dE, last_step)` (no grad_norm).
- `_run_analyzer` needs `ws_prev` even on cache hit.
- `pipeline_runner.jl` doesn't forward `verbose` to ITP (loud); does forward to LBFGS (silent).
- `_cuda_reclaim_callback` runs between scan points.
- `rotating_basis_history` is multi-phase concatenated.
