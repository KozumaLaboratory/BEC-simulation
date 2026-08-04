# EdH Simulation Fix Plan

> **FROZEN 2026-05-13.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

## Root Cause
`temperature_ratio: 0.1` (T/Tc=10%) is far too large. Paper says "negligible thermal component".
White noise × 12 spin components × all k-modes → DDI amplifies everything → patternless dispersion.

## Fix (ordered by priority)

### 1. Update eu151_edh/config.yaml
- Phase 1 (quench): dt=0.0005, duration=0.14 (0.2ms, OK per paper "momentarily adjusted")
- Phase 2 (relaxation): dt=0.001, duration=27.6 (40ms), save_every=50
- Remove temperature_ratio entirely (pure mean-field EdH)
- No integrator block (not parsed by dynamics _run_step)

### 2. Implement symmetry-breaking seed (thermal_noise.jl)
- New function `add_symmetry_breaking_seed!(psi, F, grid; amplitude=1e-6, seed=42)`
- Adds tiny noise ONLY to m=F-1 component (nearest transverse mode)
- Spatial profile: white noise filtered to k < k_healing (low-pass)
- Much cleaner than full thermal noise across all components

### 3. Run and analyze per-component
- Save Mz(t) trajectory
- Visualize m-component column densities (Stern-Gerlach style)
- Expect: m=-6 sphere, m=-5 two rings, m=-4 three rings (paper Fig 1F,G)

### 4. If numerical noise insufficient
- Add seed_perturbation with amplitude=1e-6 to config
- Or add temperature_ratio: 0.001 (T/Tc=0.1%)
