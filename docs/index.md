# SpinorBEC.jl documentation

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

For build/install/test commands and conventions, see the repo root `README.md` and `CLAUDE.md`.

## Map

```
docs/
├── campaign/       active campaign charter (read first in a campaign session)
├── guides/         step-by-step how-tos
├── reference/      API + YAML schema + architecture
├── design/         active design notes (implemented or in-progress)
├── theory/         physics theory write-ups
├── research_notes/ scientific results
├── manuscript/     paper & thesis drafts
├── refs/           reference PDFs
├── api/            Documenter.jl auto-built API reference
└── archive/        dated/superseded docs (see archive/README.md)
```

## Where to start

### Running an experiment

| Task | Read |
|---|---|
| End-to-end walkthrough (calibration → YAML → run → analyze) | `guides/lab_user_tutorial.md` |
| YAML pattern recipes (scan, droplet, calibration, …) | `guides/pipeline_cookbook.md` |
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
| Every YAML key | `reference/yaml_schema_reference.md` |
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
| All other active design notes | `design/*.md` |

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

**Reference** docs describe what *exists* in the code today. **Design** docs describe *intent* — implemented features keep their design doc as a permanent record of why; in-progress features track open questions there. **Research notes** are dated scientific snapshots — they reflect data captured on a specific day with a specific code state, and survive their results being reinterpreted (see the TWA Sinatra story for an example of a revised verdict that retained the original write-up). **Archive** is for dated artifacts (session handoffs, bug audits, measurement plans) and for designs that were superseded. See `archive/README.md` for an index of what's there and where the live equivalent lives now.
