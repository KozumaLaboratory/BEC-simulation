# SpinorBEC.jl documentation

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components).
Dimensionless units: ℏ=m=ω_ref=1.

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

| You want to... | Read this |
|---|---|
| Run a simulation that mirrors a lab experiment | `guides/lab_user_tutorial.md` |
| Find a YAML pattern (scan, droplet, calibration, …) | `guides/pipeline_cookbook.md` |
| Look up every YAML key | `reference/yaml_schema_reference.md` |
| Understand the module structure / data flow | `reference/architecture.md` |
| See every accepted key in a `dynamics:` block | `reference/dynamics.md` |
| Pick the right precision / save_every / k_cut | `guides/performance_tuning.md` |
| Upgrade old configs after a convention change | `guides/migration_guide.md` |
| Submit jobs on TSUBAME | `guides/tsubame.md` |
| Understand the rotating-basis (Option γ) solver | `design/option_gamma_rotating_basis.md` |
| Read a closed-form result | `theory/icosahedral_lhy.md` or other `theory/*.md` |
| See the latest TWA / collapse / phase-boundary findings | `research_notes/*.md` |

## Documentation philosophy

- **Reference** docs describe what *exists* in the code today.
- **Design** docs describe *intent* — implemented features keep their design doc as a permanent record of why; in-progress features track open questions there.
- **Research notes** are dated scientific snapshots — they reflect data captured on a specific day with a specific code state, and survive their results being reinterpreted (see the TWA Sinatra story for an example of a revised verdict that retained the original write-up).
- **Archive** is for dated artifacts (session handoffs, bug audits, measurement plans) and for designs that were superseded. See `archive/README.md` for an index of what's there and where the live equivalent lives.
