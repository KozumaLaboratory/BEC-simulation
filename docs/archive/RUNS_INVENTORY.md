# Runs inventory — Bug-4 / Bug-5 audit

Generated 2026-05-02 by querying every `config.yaml` under `runs/` and cross-referencing the post-fix code state (commit baafd08).

## Severity legend

- 🔴 Bug-4 affected: ITP ran at < 0.55× true DDI rate
- 🟡 Bug-4 partially affected (rotating_basis path doesn't use ITP merge)
- ✅ Not Bug-4 affected (rotating_basis exclusively, or save_every=1)
- 🌒 Bug-5 (Faraday) affected if `faraday` analyzer was used post-2026-05-02

## Inventory

| Run | Atom | Kind | n_steps | save_every | DDI | Bug-4 eff_DDI | Severity |
|---|---|---|---|---|---|---|---|
| `eu151_edh` | Eu151 | spinor | 100000 | 1000 | yes | 0.500 | 🔴 |
| `eu151_lab_calibrated` | Eu151 | spinor(default) | 4000 | 40 | yes | 0.512 | 🔴 |
| `berry_crossover_scan` | Eu151 | rotating_basis | — | 1 | yes | 1.000 | ✅ |
| `eu151_phase_diagram_lbfgs` | Eu151 | rotating_basis | 500 | 5 | yes | 1.000 | ✅ |
| `klaus_baseline` | Eu151 | rotating_basis | — | 1 | yes | 1.000 | ✅ |
| `phi_omega_scan` | Eu151 | rotating_basis | — | 1 | yes | 1.000 | ✅ |

## Re-run priority

### 🔴 Critical (re-run for any thesis-bound figure):
- `runs/eu151_edh/`
- `runs/eu151_lab_calibrated/`

### ✅ Not affected (rotating_basis or save_every=1):
- `runs/berry_crossover_scan/`
- `runs/eu151_phase_diagram_lbfgs/`
- `runs/klaus_baseline/`
- `runs/phi_omega_scan/`

## Re-run plan

Each affected run's ground-state phase should be re-run on GPU with the fixed integrator (commit 4f56cc3+). Production-grade phases (dynamics) chained on the GS will inherit the corrected initial state automatically.

See `runs/measurement_R3x_eu/` for the new canonical configs that the Phase 2 measurement campaign uses.
