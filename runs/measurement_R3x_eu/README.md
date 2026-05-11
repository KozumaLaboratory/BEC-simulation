# Phase 2 measurement-campaign canonical Eu configs

YAML configs for the R32-R39 ROI measurement campaign described in
`docs/archive/MEASUREMENT_CAMPAIGN_PHASE2.md`. Each sub-directory contains:

- `config.yaml` — the canonical Eu thesis-grade input
- a `README.md` with the matching `run` command (heavy-gate envvar) and
  the measurement target.

These are designed to be directly drivable from a TSUBAME job script
via `julia --project=. run_yaml(\"config.yaml\")`. The grids are
deliberately conservative (24³ rather than 64³) so a single benchmark
fits in a few hours; production-quality figures should re-run at 48³+
with the same physics.

| sub-dir | round | wall-time target | measurement |
|---|---|---|---|
| `r33_mfbo_eu_phase/`        | R33 | ~4-5 h | MFBO speedup vs single-fidelity BO |
| `r35_b1_boundary_trace/`    | R35 | ~1 h | B-1 boundary 100 points |
| `r36_4d_phase_al/`          | R36 | 30+ h | 4D AL boundary concentration |
| `r37_triple_point_hunt/`    | R37 | 12-15 h | F=6 triple-point detection |
| `r39_bdg_along_b1/`         | R39 | ~30 min | BdG ω(k) along R35 trace |

All configs share the same Eu151 physical parameters (F=6,
g_F = 1.163, μ ≈ 6.977 μ_B, a_s ≈ 110 a₀) declared via the `Eu151`
atom registry; no run needs to override these.

## Heavy-gate

The R34 / R38 YAML wrappers and R39 spectrum sweeps are gated behind
`SPINORBEC_RUN_HEAVY_YAML=true`. Set in your TSUBAME shell before
launching:

```sh
export SPINORBEC_RUN_HEAVY_YAML=true
julia --project=. -e 'using SpinorBEC; run_yaml("runs/measurement_R3x_eu/r33_mfbo_eu_phase/config.yaml")'
```
