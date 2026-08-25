# STATE — what this system is, derived from the code

> **GENERATED. Do not edit.** Regenerate with
> `julia --project=. scripts/generate_state.jl`, and
> `test/test_state_doc_is_current.jl` fails if this file and the tree disagree.
>
> **This is SSoT applied to DESCRIPTIONS.** The repo's value-level SSoT held
> perfectly — one line computes the B→p sign, one function defines the substep
> chain. What rotted was every prose restatement of them, because "one place
> defines it" does not imply "every other mention is generated from it".
>
> This file exists because deltas accumulate and nothing states the present.
> `CLAUDE.md`'s split-step list said 5 operators, was corrected to 7, and the
> real number is 9 — two sessions each appending to a hand-copied list. Every
> section here names the code it is read from, so it cannot drift without
> the gate going red.
>
> **What is NOT here:** anything needing judgement — why a design is what it
> is, what a measurement means, which convention is deliberate. That stays
> hand-written in `CLAUDE.md` and the memory store. Derive what is
> checkable; curate what is not.

## Split-step: the forward outer-potential chain

Read from `OUTER_CHAIN` (`src/hamiltonian/integrator/split_step.jl`), the Tuple both directions derive from:
`_outer_operators_fwd!` runs it as declared, `_outer_operators_bwd!` runs
`reverse` of it. **9 substeps.** Each auto-skips when its
coupling is ≈ 0.

1. `diagonal`
2. `light_shift_offdiag`
3. `spin_mixing`
4. `spatial_lhy_spin`
5. `singlet_pair`
6. `tensor`
7. `transverse_zeeman`
8. `spatial_zeeman`
9. `raman`

The backward half reverses this; the pair is the Strang sandwich, with `DDI`
at the centre for RTP. A prose list of this anywhere else is a copy and has
been wrong twice.

## Hamiltonian terms in the registry

`H_TERMS_CANONICAL_ORDER`, in order. **14 terms.**
Each declares its sign in one coefficient function in the file named.

| # | registry symbol | struct | defined at |
|---|---|---|---|
| 1 | `kinetic` | `KineticTerm` | `src/hamiltonian/terms/kinetic.jl` |
| 2 | `trap` | `TrapTerm` | `src/hamiltonian/terms/trap/trap.jl` |
| 3 | `zeeman` | `ZeemanTerm` | `src/hamiltonian/terms/zeeman.jl` |
| 4 | `density_c0` | `DensityC0Term` | `src/hamiltonian/terms/contact/contact.jl` |
| 5 | `spin_c1` | `SpinC1Term` | `src/hamiltonian/terms/contact/contact.jl` |
| 6 | `ddi` | `DDITerm` | `src/hamiltonian/terms/ddi/ddi_term.jl` |
| 7 | `lhy` | `LHYTerm` | `src/hamiltonian/terms/lhy/lhy_term.jl` |
| 8 | `tensor` | `TensorTerm` | `src/hamiltonian/terms/contact/contact.jl` |
| 9 | `raman` | `RamanTerm` | `src/hamiltonian/terms/raman.jl` |
| 10 | `light_shift` | `LightShiftTerm` | `src/hamiltonian/terms/light_shift/light_shift_term.jl` |
| 11 | `coriolis` | `CoriolisTerm` | `src/hamiltonian/terms/coriolis.jl` |
| 12 | `magnetic_gradient` | `MagneticGradientTerm` | `src/hamiltonian/terms/magnetic_gradient.jl` |
| 13 | `spatial_zeeman` | `SpatialZeemanTerm` | `src/hamiltonian/terms/spatial_zeeman.jl` |
| 14 | `loss` | `LossTerm` | `src/hamiltonian/terms/loss.jl` |

## The B → p sign

Declared **once**, at `src/workflow/io/units.jl:73`, as `p ≡ -g_F μ_B B` (Kawaguchi-Ueda);
22 other references delegate to it. **The uniqueness is a GATE, not a
list** — `test/oracles/test_bfield_sign_declared_once.jl` fails if a second
expression in `src/` combines `g_F` with the Bohr magneton. This section used to
enumerate all 22 sites; a derived list cannot rot but only describes,
whereas the gate refuses the violation. `linear_zeeman_p` carried the opposite
sign for two months because eight test files checked the VALUE and none checked
that there was only one of them.

## `src/solvers/` — what is actually there

**Subdirectories (.jl count):** `continuation/ (5)`, `evaporation/ (9)`, `ground_state/ (6)`, `lbfgs/ (4)`, `simulation/ (4)`

**Top-level files:** `adaptive.jl`, `bdg_frequencies.jl`, `binary_simulation.jl`, `bragg_response.jl`, `convergence_metrics.jl`, `ground_state.jl`, `hessian.jl`, `newton_cg.jl`, `photon_heating.jl`, `preconditioner.jl`, `projected_gp.jl`, `scalar_egpe.jl`, `sgpe.jl`, `simulation.jl`, `spgpe.jl`, `thermal_cfield.jl`, `trapped_bdg.jl`, `twa.jl`

`CLAUDE.md` restated this directory twice and the two restatements disagreed
with each other; both omitted `evaporation/` and five top-level files, and one
named a module whose file was deleted in `e037867c`. Two hand-written
restatements of one directory, in one file, neither checked against the tree
nor against each other.

## Ground-state exit contract: what `tol` bounds

ITP convergence, read from `src/solvers/ground_state/itp_loop.jl:295`:

```julia
if dE < tol && (tol_drho <= 0.0 || drho < tol_drho)
```

`dE` is `_relative_energy_change` — the relative **energy** change, not a
gradient norm. It is evaluated only inside `if step % sp.save_every == 0` (`src/solvers/ground_state/itp_loop.jl:247`), and
the YAML path sets `save_every = max(1, n_steps ÷ 100)`, so at the default
`n_steps=100000` the criterion is tested **1000 steps apart**. A run can be
converged for 999 steps without noticing. `dpsi` appears in the diagnostics
and NOT in the condition above — that absence is derived here, not
remembered.

L-BFGS reports `stop_reason` ∈ `:tol`, `:line_search_stalled`, `:max_steps` (`src/solvers/lbfgs/driver.jl`), which is a different exit contract with a
different meaning of `tol` (there it IS the gradient norm).

## Cache admission: what is served, and what verified it

| provenance | served as a hit | declared at |
|---|---|---|
| `:absent` | no | `src/model/complete.jl:684` |
| `:unmarked` | **yes** | `src/model/complete.jl:717` |
| `:marked` | **yes** | `src/model/complete.jl:745` |
| `:rejected` | no | `src/model/complete.jl:751` |

The provenance set is asserted EQUAL to `keys(admission_counts())`, both
directions. `_count_admission!` mints a key at runtime for an unknown
provenance rather than erroring, and the counter's initializer hardcodes the
four — two lists seventy lines apart, and their agreement is the only thing
checking either.

**4 sites admit a cached payload; 1 re-derives its verdict.**

- admits: `src/workflow/experiment.jl:_admitted_result_path`
- admits: `src/workflow/experiments/pipeline/run_registry.jl:_run_yaml_scan`
- admits: `src/workflow/experiments/pipeline/run_registry.jl:_run_yaml_single`
- admits: `src/workflow/experiments/pipeline/run_step_ground_state.jl:_run_step`
- **verifies**: `src/workflow/experiments/pipeline/run_step_ground_state.jl:_run_step`

Whether that ratio is a gap is judgement — `:unmarked` being a HIT is a dated
migration allowance argued at `src/model/complete.jl`, not an oversight — so
this section reports the counts and does not grade them.

## Artifact identity: every key the digest covers

`artifact_id` (`src/model/identity.jl`) folds **7** keys:
`backend`, `code_rev`, `from`, `kind`, `method`, `model`, `params`.

That set is exactly `fieldnames(Stage)` plus `code_rev`, asserted as an
EQUALITY in both directions — a missing key means a `Stage` input silently
left the identity, an extra one means something undeclared entered it. Set
equality proves no *field* is selected out; it does NOT prove content
completeness (`model_toml_dict` deliberately omits non-required slots equal
to their own default), and that qualification is judgement, not derived.

## Ground-state knob defaults, by entry path

| knob | `find_ground_state` | `find_ground_state_lbfgs` | YAML fallback |
|---|---|---|---|
| `n_steps` | 10000 | 1000 | method === :lbfgs ? 500 : 100000 / 1000 / 100000 / 4000 / use_from_jld2 ? 0 : 200 (schema `100000`) |
| `tol` | 1e-10 | 1e-8 | 1e-8 / 1e-6 / 1.0e-9 (schema `1.0e-8`) |
| `m_lbfgs` | 20 | 20 | 10 (schema `10`) |

**`m_lbfgs` is the live trap.** Both Julia entries default to 20 and
`ground_state.jl` carries a `# keep in sync with find_ground_state_lbfgs
default` comment; 20 is the MEASURED value (~9× lower grad_norm floor, ~30 %
fewer line-search backtracks against 10 on Eu F=6+DDI 16³). The YAML path
defaults to 10, so every production run that omits the key gets the worse
one. The sync obligation was written for the two Julia entries and never
extended to the path most runs take. Whether to change it is a decision, so
this section reports the disagreement and does not assert it away.

## Sizes and vocabularies, by introspection

Read from the loaded module. Every row below was stated by hand in `CLAUDE.md`
and every one was wrong on 2026-08-05 — each correct when written, none ever
re-derived. **Do not restate these anywhere.**

| what | value | read from |
|---|---|---|
| `Workspace` type parameters | 20 | `length(Base.unwrap_unionall(Workspace).parameters)` |
| `AbstractPotential` subtypes | 16 | `length(subtypes(AbstractPotential))` |
| named `init_psi_*` builders | 26 | exported names of `SpinorBEC` |
| `H_TERMS_CANONICAL_ORDER` | 14 | the registry constant |
| `LHY_KINDS` | 11 | `src/model/specs.jl` |
| `RunResult` fields | path, psi, hpsi, grid, atom, interactions, dynamics, e_decomp, metadata | `fieldnames(RunResult)` |
| `docs/` subdirectories | 17 | `readdir("docs")` |

`LHY_KINDS`: `none`, `scalar`, `quasi_2d`, `polar_two_channel`, `full_bdg`, `polar_contact`, `polar_dipolar`, `fm_contact`, `fm_dipolar`, `icosahedral`, `spatial`

## YAML surface

**Top-level keys (10):** `accuracy`, `auto_grid`, `calibration`, `calibration_history`, `defaults`, `mixins`, `pipeline`, `scan`, `target_date`, `units`

**Pipeline step kinds (2):** `dynamics`, `ground_state`

**Retired keys (13)** — from `docs/reference/yaml_schema_reference.md`. A LIVE document teaching one
of these fails `test/test_docs_examples_avoid_removed_keys.jl`.

| removed | replacement |
|---|---|
| `zeeman:` (step-level) | unified `B:` block |
| `B_hat:` (step-level) | unified `B:` block (`:spherical` coord) or `B_direction` for rotating_basis |
| `interactions.c_lhy` | `lhy.c_lhy` |
| `ground_state.spinor_lhy` | `lhy.kind` |
| `phi_omega` / `phi_dot` (flat B_hat) | `B: {phi: <waveform>}` or `B_direction: {phi: {rate: ...}}` |
| `theta_const`, `theta_ramp`, `phi_chirp` (flat B_hat) | `B: {theta: <waveform>}` |
| `initial_state: ferromagnetic` | `m_plus_F` or `m_minus_F` |
| `kind: option_gamma` | `kind: rotating_basis` |
| `backend: cuda` | `backend: gpu` |
| `B: {level: <0 | 1 |
| `B: {magnitude: ...}` | `B: {B_mag: ...}` |
| `loss: {K3_per_m: ...}` | `loss: {K3_per_m_cubic: ...}` (or `K3_per_m_si`) |
| `photon_scattering: {gamma_sc: ...}` | `photon_scattering: {Gamma_sc: ...}` |

## Test tiers

Tier lists in `test/_tiers.jl`. Membership is explicit — no auto-discovery.

- `FAST_TESTS`
- `CI_EXTRA`
- `FULL_EXTRA`
- `PHYSICS_TESTS`
- `ORACLE_TESTS`
- `INTEGRATION_TESTS`

## Validation ladder — instruments present on disk

| level | instrument (located by walking `test/`) |
|---|---|
| 0 | `test/test_level0_gpu_cpu_consistency.jl` |
| 1 | `test/test_level1_scalar_exact.jl` |
| 2 | `test/test_level2_strang_convergence.jl` |
| 3 | `test/test_level3_zeeman_only.jl` |
| 4 | `test/test_level4_f1_phase_emergence.jl` |
| 4 | `test/test_level4_general_F_phase_emergence.jl` |
| 8 | `test/hamiltonian/test_lhy_level8_unit.jl` |
| 10 | `test/test_level10_hpsi_self_consistency.jl` |
| 11 | `test/test_level11_convergence_sweep.jl` |
| 12 | `test/test_level12_production_audit.jl` |

## Extensions and how their triggers are declared

Derived from `Project.toml`. CLAUDE.md called all four *weak-dep*
extensions; one is not. Loading is lazy either way — a bare
`using SpinorBEC` pulls in none of them — so the mismatch shows up at
install time, not startup.

| extension | trigger | in `[weakdeps]` | in `[deps]` |
|---|---|---|---|
| `SpinorBECCUDAExt` | `CUDA` | **no** | **yes** |
| `SpinorBECHTTPExt` | `HTTP` | yes | no |
| `SpinorBECMakieExt` | `Makie` | yes | no |
| `SpinorBECVTKExt` | `WriteVTK` | yes | no |

## What the code says about itself is unfinished

Files carrying `KNOWN-LIMIT` or an explicit not-implemented marker —
**8 files, 13 markers.** This is the
only enumeration of it in the tree; prose elsewhere goes stale (a
`KNOWN-LIMIT` in `contact.jl` contradicted the function twenty lines below
it until 2026-08-04).

- `src/validation/dumb_reference.jl` — 4
- `src/hamiltonian/terms/raman.jl` — 2
- `src/manuscript/figures.jl` — 2
- `src/analysis/phases/sign_pattern.jl` — 1
- `src/foundation/types/ddi_loss.jl` — 1
- `src/hamiltonian/terms/loss.jl` — 1
- `src/hamiltonian/terms/contact/contact.jl` — 1
- `src/workflow/experiments/pipeline/run_step_dynamics.jl` — 1

## What this document does NOT cover

Cited FILES over total, per `src/` subtree — not a boolean. A first version
asked only whether the directory name appeared anywhere, so one citation
would have flipped a whole subtree to "covered" and the gap report would
have overstated itself the moment any section landed. A low ratio is not a
defect: it is this document saying how little it knows about that area, so
silence here is not read as absence in the code. **What would be a defect is
this table vanishing** — a generated document whose gaps are invisible reads
as complete.

| subtree | files cited | of |
|---|---|---|
| `src/hamiltonian/` | 13 | 63 |
| `src/model/` | 3 | 16 |
| `src/validation/` | 1 | 10 |
| `src/manuscript/` | 1 | 17 |
| `src/solvers/` | 2 | 46 |
| `src/workflow/` | 5 | 182 |
| `src/foundation/` | 1 | 41 |
| `src/analysis/` | 1 | 51 |

Where the ratio is low the code is the only authority; `CLAUDE.md`'s subsystem
catalog is a curated summary and carries no staleness gate.

