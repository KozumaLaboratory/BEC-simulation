# TWA Sinatra criterion validation

**Status**: infrastructure shipped 2026-05-07; awaiting GPU runs.
**Code path**: `runs/twa_sinatra_validation/`, `examples/twa_sinatra_validation*.jl`,
`src/dynamics/sinatra_helpers.jl`.

## Question

The 50-trajectory TWA ensemble at 32³ × F=6 produced σ/μ ≈ 0.42 at peak
density and a 4.5× on-axis-ratio smearing of the deterministic EdH
collapse. Is that quantum noise, or classical thermalisation noise from
violating the TWA validity bound

  N_modes_eff × D ≪ N_atoms

where 32³ × 13 / 10⁴ ≈ 43?

## Configurations

| Config | Grid | k-cutoff energy | k_max² / 2 | Sinatra ratio | Wall-clock (RTX 5070 Ti) |
|---|---:|---:|---:|---:|---:|
| `baseline_32g` | 32³ | 6.0 | ≈ 12.6 | ≈ 43 | ~31 min |
| `coarse_16g`   | 16³ | 6.0 | ≈ 3.16 | ≈ 5.3 | ~5 min  |
| `cutoff_16g`   | 16³ | 1.0 | ≈ 3.16 | ≈ 3.5 | ~5 min  |

The cutoff in `coarse_16g` does not actually filter anything beyond the
8× grid coarsening (cutoff > k_max²/2). `cutoff_16g` adds a hard k-cut
on top of the coarsened grid.

## Acceptance criterion

Per parallel-session prediction:

* If σ/μ at peak is grid- and cutoff-independent (< 20% spread)
  → real quantum noise, ensemble result publishable.
* If σ/μ shrinks substantially as Sinatra ratio drops
  → spurious classical thermalisation; baseline 32³ result is not a
  controlled approximation, and Eu EdH dynamics need full BdG / TDHFB.

## Reproduction

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    examples/twa_sinatra_validation.jl
```

Runner skips configs whose `result.jld2` already exists. The included
analyzer computes σ/μ at peak, σ/μ averaged over high-density voxels,
on-axis ratio and prints the verdict line.

## Helper API

`src/dynamics/sinatra_helpers.jl` exposes (all dimensionless,
ℏ = M = ω_ref = 1 by default):

* `healing_length(g, n)` — `ξ = 1/√(2 g n)`
* `cutoff_energy_from_xi(ξ; factor=2.0)` — yields the
  `cutoff_energy` knob in `add_vacuum_noise` for `k_cut = factor / ξ`
* `cutoff_energy_from_gn(g, n; factor=2.0)` — composition of the above
* `effective_n_modes(grid, cutoff_energy; D)` — count of plane-wave
  modes that survive the cutoff
* `sinatra_ratio(grid, D, N_atoms; cutoff_energy)` — N_modes_eff / N_atoms

## Result table (placeholder)

To be filled in once GPU runs land.

| Config | n_traj | peak n | on-axis ratio | σ/μ peak | σ/μ ⟨voxels⟩ |
|---|---:|---:|---:|---:|---:|
| baseline_32g | — | — | — | — | — |
| coarse_16g   | — | — | — | — | — |
| cutoff_16g   | — | — | — | — | — |

## Verdict (placeholder)

To be written after the spread of σ/μ peak across the three configs is
known.

## See also

* `runs/twa_N_scan/` — N-atom scan as the orthogonal validity check
  (1/N expansion). The Sinatra and 1/N tests ground different aspects:
  the 1/N test probes whether the leading-order TWA captures atom-number
  scaling correctly, while the Sinatra test probes whether the 32³
  starting grid is in the controlled regime in the first place.
* `docs/research_notes/eu_collapse_lhy_insufficient.md` — the
  mean-field-level conclusion that established the EdH collapse is real
  irrespective of LHY treatment, motivating the TWA quantum-noise
  question.
