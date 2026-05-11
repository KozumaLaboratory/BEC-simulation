# SpinorBEC.jl documentation

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

For build/install/test commands and conventions, see the repo root `README.md` and `CLAUDE.md`.

## Map

```
docs/
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
| Klaus 2022 / Eu fast-Larmor production path | `guides/klaus_regime.md` |
| Upgrade old configs after a convention change | `guides/migration_guide.md` |
| Pick the right precision / save_every / k_cut | `guides/performance_tuning.md` |
| Submit jobs on TSUBAME | `guides/tsubame.md` |

### Looking something up

| Task | Read |
|---|---|
| Every YAML key | `reference/yaml_schema_reference.md` |
| Every key in a `dynamics:` block | `reference/dynamics.md` |
| Module structure + data flow | `reference/architecture.md` |
| API docstrings | `api/index.md` |

### Understanding why the code is the way it is

| Task | Read |
|---|---|
| Rotating-basis derivation (math) | `design/option_gamma_rotating_basis.md` |
| Integrator roadmap + Ch.3 thesis plan | `design/integrator_modernization_plan.md` + `design/integrator_ch3_plan.md` |
| TDHFB pilot | `design/tdhfb_pilot_design.md` |
| Mixed precision rollout | `design/mixed_precision_design.md` |
| All other active design notes | `design/*.md` |

### Physics results

| Task | Read |
|---|---|
| TWA on Eu EdH — bottom line | `research_notes/twa_eu_edh_synthesis.md` |
| Single TWA scan, raw data | `research_notes/twa_*_result.md` |
| F=6 phase boundary scan | `research_notes/F6_phase_boundaries.md` |
| Eu collapse + LHY ablation | `research_notes/eu_collapse_lhy_insufficient.md` |
| Closed-form theory derivations | `theory/*.md` |

## Documentation philosophy

**Reference** docs describe what *exists* in the code today. **Design** docs describe *intent* — implemented features keep their design doc as a permanent record of why; in-progress features track open questions there. **Research notes** are dated scientific snapshots — they reflect data captured on a specific day with a specific code state, and survive their results being reinterpreted (see the TWA Sinatra story for an example of a revised verdict that retained the original write-up). **Archive** is for dated artifacts (session handoffs, bug audits, measurement plans) and for designs that were superseded. See `archive/README.md` for an index of what's there and where the live equivalent lives now.
