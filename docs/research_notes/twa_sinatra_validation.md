# TWA Sinatra criterion validation — superseded

**Status**: VERDICT REVISED 2026-05-08; this scan's analysis is no longer the load-bearing reading. See **`twa_pinned_16g_result.md`** for the correct interpretation. This file is kept only for the raw measurement record (3 ensembles, RTX 5070 Ti, 2026-05-07 19:18, ~75 min runtime).

## What was measured

3 ensembles at the Eu N=10⁴ baseline, sweeping grid + cutoff to vary the Sinatra ratio `n³ × D / N_atoms`:

| Config | Grid | k-cutoff | Sinatra ratio | peak n | on-axis | σ/μ peak |
|---|---:|---:|---:|---:|---:|---:|
| baseline_32g | 32³ | 6.0 | **42.6** | 0.094 | 0.416 | 0.423 |
| coarse_16g   | 16³ | 6.0 | 5.3       | 0.019 | 0.970 | 0.042 |
| cutoff_16g   | 16³ | 1.0 | 5.3       | 0.019 | 0.970 | 0.011 |

Code path: `runs/{baseline_32g, coarse_16g, cutoff_16g}_<hash>/result.jld2`, analysed by `examples/twa_sinatra_validation_analyze.jl`.

## Why the original verdict was wrong

The σ/μ shrinkage from 0.423 → 0.042 → 0.011 was originally read as "classical thermalisation removed when Sinatra ratio drops". That reading is wrong: the 16³ × box=20 setup has dx = 1.25 a_ho which cannot resolve the 3.75 a_ho z-elongated dipolar filament — at this grid the cloud stays smooth Gaussian (peak n drops 5×, on-axis ratio rises to 0.97), so the chaotic dipolar dynamics that drives σ/μ never fires. The σ/μ drop is a **ground-state-resolution artifact**, not a Sinatra-removal effect.

The resolution-matched follow-up (16³ × box=10, dx = 0.625 a_ho) proves this: at N=10⁴ Sinatra-clean it gives σ/μ = 0.42 (matching the 32³ baseline) and at N=10⁵ deeply Sinatra-clean it gives σ/μ = 0.82 — *higher* than the supposedly contaminated 32³ baseline. See `twa_pinned_16g_result.md` for the data and `docs/theory/sinatra_criterion_F6.md` "Caveat" for the corrected interpretation: σ/μ in the dipolar-collapse regime is chaotic trajectory divergence, not Wigner noise amplitude.

## Bug fix (analyzer verdict logic, kept for the record)

`examples/twa_sinatra_validation_analyze.jl` initially used `σ_max, σ_min = extrema(σs)` but `extrema` returns `(min, max)` — order reversed, spread came out negative, verdict printed "REAL quantum noise (publishable)". Swapped to `σ_min, σ_max = extrema(σs)` (2026-05-08). The corrected verdict text ("SPURIOUS classical thermalisation") was itself wrong for the reason above, but the fix to the unpacking is independently correct.
