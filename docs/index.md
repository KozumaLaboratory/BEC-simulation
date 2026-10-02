# SpinorBEC.jl documentation

Experiment authoring: [Julia experiment definitions](guides/julia_experiments.md).

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

For usage and test commands, see [README.md](../README.md). For agent work,
start with [AGENTS.md](../AGENTS.md), then the shared rules and task map in
[CLAUDE.md](../CLAUDE.md).

## Current state and authority

- [STATE.md](STATE.md) derives code facts and declares its coverage gaps.
- [campaign/claims.toml](campaign/claims.toml) records claim status, uncertainty,
  evidence, and retractions; [CAMPAIGN.md](campaign/CAMPAIGN.md) governs campaign work.
- [testing_strategy.md](conventions/testing_strategy.md) defines what tests can establish.
- [live_docs.jl](../test/helpers/live_docs.jl) declares maintained documents.
  All others carry dated FROZEN headers. Check that status before treating a
  guide, reference, or design note as a current instruction.

## Map

```
docs/
├── campaign/       active campaign charter (read first in a campaign session)
├── guides/         step-by-step how-tos
├── reference/      API + parameter schema + architecture
├── design/         design rationale and proposals (check LIVE/FROZEN status)
├── theory/         physics theory write-ups
├── research_notes/ scientific results
├── manuscript/     paper & thesis drafts
├── refs/           reference PDFs
├── api/            Documenter.jl auto-built API reference
└── archive/        dated/superseded docs (see archive/README.md)
```

## Where to start

### Active work and historical notes

Use [open issues](https://github.com/KozumaLaboratory/BEC-simulation/issues?q=is%3Aissue%20is%3Aopen)
for current task status; this map does not duplicate their checklists.

- Evaporation: [#502](https://github.com/KozumaLaboratory/BEC-simulation/issues/502)
  owns the fixed-endpoint experiment connection. [#75](https://github.com/KozumaLaboratory/BEC-simulation/issues/75)
  retains older model-validation work; [#468](https://github.com/KozumaLaboratory/BEC-simulation/issues/468)
  tracks calibration and loss-channel uncertainty. Old ramp gains are not predictions for the current endpoint.
- Eu measurement comparison: [#503](https://github.com/KozumaLaboratory/BEC-simulation/issues/503)
  owns experimental calibration and comparison. [#89](https://github.com/KozumaLaboratory/BEC-simulation/issues/89)
  and [#97](https://github.com/KozumaLaboratory/BEC-simulation/issues/97) retain mode-identification
  and excitation questions; their old branch results need provenance and validity checks.
- Stored-run reanalysis: [#495](https://github.com/KozumaLaboratory/BEC-simulation/issues/495)
  tracks the remaining real-data equivalence check, not a new driver migration.
- Memory: use the available project-specific store and the
  [auditor](../scripts/audit_memory.py) with an explicit `--memory-dir`.
  [The 2026-08-04 ledger](audit/memory_ledger_2026-08-04.md) is a historical snapshot,
  not evidence that those external memory files exist on the current host.

### Running an experiment

| Task | Read |
|---|---|
| Define a new experiment in Julia and persist its inputs/results | [README usage](../README.md#usage), then [workflow rules](../CLAUDE.md#workflow-model-spec--cas--run--observe) |
| End-to-end walkthrough (calibration → definition → run → analyze) | `guides/lab_user_tutorial.md` |
| Experiment pattern recipes (scan, droplet, calibration, …) | `guides/pipeline_cookbook.md` |
| Fast-Larmor regime (Eu / Dy production path) | `guides/fast_larmor_regime.md` |
| Preparing the weak-field Eu chiral ground state (B ramp / κ ramp / z torque) — **its hysteresis reading is RETRACTED, see the next row** | `guides/eu_adiabatic_protocol.md` |
| The κ-dependent transition, re-measured: the "loop" is a J_z slide; the deliverable is a Stern-Gerlach level count | `guides/eu_kappa_hysteresis_loop.md` |
| Nucleating that state in place instead of transporting it — the C-region window, the minimum atom number the flower texture needs, and what a cooling trajectory selects | `guides/eu_in_place_nucleation.md` |
| ¹⁵¹Eu vs ¹⁵³Eu: the one prediction that needs no scattering length — a 2.2787× magnon-frequency ratio at the same field, and why the mixture engine is not justified yet | `guides/eu_isotope_q_prediction.md` |
| 磁場遮蔽仕様 — 弱磁場 Eu の状態を保持するための B⊥ 上限（AC/DC 分離、共鳴 26 Hz） | `guides/eu_shielding_spec.md` |
| Upgrade old configs after a convention change | `guides/migration_guide.md` |
| Pick the right precision / save_every / k_cut | `guides/performance_tuning.md` |
| Finite-T reservoirs / second-scale evaporation (full SPGPE) | `guides/spgpe.md` |
| Submit jobs on TSUBAME | `guides/tsubame.md` |
| Run locally without swapping or freezing the machine — limits derived per host, no tuning constants | `guides/local_run_environment.md` |
| Magnetic field a spin-polarised cloud radiates | `guides/dipole_field.md` |

### Looking something up

| Task | Read |
|---|---|
| Parameter schema (legacy filename) | `reference/yaml_schema_reference.md` |
| Every key in a `dynamics:` block | `reference/dynamics.md` |
| Module structure + data flow | `reference/architecture.md` |
| API docstrings | `api/index.md` |
| Which "Klaus" is meant — the paper, the fast-Larmor regime, or our own protocol | `conventions/klaus_name_disambiguation.md` |

### Understanding why the code is the way it is

| Task | Read |
|---|---|
| Rotating-basis derivation (math) | `design/option_gamma_rotating_basis.md` |
| Integrator roadmap + Ch.3 thesis plan | `design/integrator_modernization_plan.md` + `design/integrator_ch3_plan.md` |
| TDHFB pilot | `design/tdhfb_pilot_design.md` |
| What limits L-BFGS speed (per-iteration cost + why ~600 iterations) | `design/lbfgs_speed_limits.md` |
| Mixed precision rollout | `design/mixed_precision_design.md` |
| Other design notes (dated records unless declared LIVE) | `design/*.md` |

### Physics results

| Task | Read |
|---|---|
| TWA on Eu EdH — bottom line | `research_notes/twa_eu_edh_synthesis.md` |
| Single TWA scan, raw data | `research_notes/twa_*_result.md` |
| F=6 phase boundary scan | `research_notes/F6_phase_boundaries.md` |
| Eu collapse + LHY ablation | `research_notes/eu_collapse_lhy_insufficient.md` |
| Evaporative cooling to BEC (0-D truncated-Boltzmann model) | `research_notes/evaporation_bec_prep_model_2026-06-15.md` |
| Superfluidity / dipolar supersolids — known vs unknown | `validation/superfluidity_knowledge_state.md` |
| Whether a stored `runs/` result can still be quoted | `validation/stored_results_vintage_audit.md` |
| Whether a stored run can be RE-READ instead of re-run, which duplicate directories are waste and which are parity arms, and what a re-analysis result may be used for | `validation/store_reuse_census.md` |
| Whether a claim is campaign-eligible (ancestor gate, guards, lanes) | `campaign/CAMPAIGN.md` |
| Whether a mistake you are about to make has a class, a count and a gate already | `campaign/pr_mistake_census_2026_08_22.md` (frozen; `scripts/pr_mistake_census.py` re-derives it) |
| Which polarisation an EdH / rotation-assisted run must prepare, and why the m label alone is not the answer | `campaign/edh_quench_polarisation_decision.md` |
| Whether a claim survives the ¹⁵¹Eu `a_S` measurement, or waits for it | `campaign/as_dependency_map.md` |
| Dipolar supersolid tube (type-C reproduction) | `validation/dipolar_supersolid_tube.md` |
| Klaus et al. 2022 magnetostirring vortex stripes (type-C reproduction): published parameters per figure, systematics, model selection, pre-registered accept/reject | `validation/klaus2022_primary_source.md` |
| Closed-form theory derivations | `theory/*.md` |

## Documentation philosophy

Directory names describe purpose, not freshness. **Reference** docs explain APIs;
**design** docs retain intent and rationale; **research notes** preserve dated
scientific snapshots, including results later reinterpreted. **Archive** contains
dated or superseded artifacts. A FROZEN reference may describe an older API, and a
design proposal does not prove implementation. Use the maintained set and the code
to establish current behavior. See [archive/README.md](archive/README.md) for
historical records and their successors.
