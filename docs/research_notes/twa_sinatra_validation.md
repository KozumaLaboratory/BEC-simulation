# TWA Sinatra criterion validation — VERDICT: spurious classical thermalisation

**Status**: 3 ensembles complete 2026-05-07 19:18, runtime ~75 min on
RTX 5070 Ti. **VERDICT: the 32³ baseline TWA σ/μ ≈ 0.42 result is
contaminated by classical thermalisation from the violated Sinatra
ratio.** Higher-resolution claims about "quantum fluctuations" in the Eu
EdH ensemble require a Sinatra-clean re-run at 16³.
**Code path**: `runs/{baseline_32g, coarse_16g, cutoff_16g}_<hash>/result.jld2`,
analysed by `examples/twa_sinatra_validation_analyze.jl`.

## Question (recap from prep doc)

The 50-trajectory TWA ensemble at 32³ × F=6 produced σ/μ ≈ 0.42 at peak
density and a 4.5× on-axis-ratio smearing of the deterministic EdH
collapse. Is that quantum noise, or classical thermalisation noise from
violating the TWA validity bound

  N_modes_eff × D ≪ N_atoms

where 32³ × 13 / 10⁴ ≈ 43?

## Result table

| Config | Grid | k-cutoff | k_max²/2 | Sinatra ratio | peak n | on-axis | σ/μ peak | σ/μ ⟨voxels⟩ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline_32g | 32³ | 6.0 | ≈ 12.6 | **42.6** | 0.094 | 0.416 | **0.423** | 0.129 |
| coarse_16g   | 16³ | 6.0 | ≈ 3.16 | 5.3 | 0.019 | 0.970 | 0.042 | 0.012 |
| cutoff_16g   | 16³ | 1.0 | ≈ 3.16 | 5.3 | 0.019 | 0.970 | **0.011** | 0.004 |

## Verdict: SPURIOUS classical thermalisation

σ/μ at peak shrinks from **0.423 → 0.042 → 0.011** across the three
configs. That's a **38×** total drop as the Sinatra ratio drops from 43
to 5. The acceptance criterion was "spread < 20% of max" for "real
quantum noise"; the actual spread is **97% of max**. By the
parallel-session-prescribed rule:

> If σ/μ shrinks substantially as Sinatra ratio drops → spurious
> classical thermalisation; the baseline 32³ result is not a controlled
> approximation, and Eu EdH dynamics need full BdG / TDHFB.

This is the verdict.

## What this means for prior conclusions

**Affected results** (need re-validation at 16³ or with TDHFB):

* `docs/research_notes/eu_collapse_lhy_insufficient.md` — TWA cross-check
  table reports σ/μ = 0.42 and on-axis-ratio smearing 0.092 → 0.416 as
  evidence that "the dipolar instability is robust against quantum
  fluctuations". The shape conclusion (FWHM_z = 6 cells persists) **is**
  robust — that's deterministic GS, unchanged by the TWA noise. But the
  σ/μ-as-quantum-noise framing is contaminated.

* `docs/research_notes/twa_eps_dd_scan.md` — species ε_dd scan reports
  σ/μ = 0.001 / 0.423 / 0.127 / 0.049 across Cr/Eu/Er/Dy. The σ/μ values
  all share the same 32³ × 13 = 425k mode contamination, so the
  *species trend* (peak at marginal Eu, drop at both ends) survives —
  it's a relative comparison at fixed contamination level. But the
  absolute σ/μ values still mix quantum and classical thermalisation
  noise.

* `docs/research_notes/twa_N_scan_result.md` — Finding B claims σ/μ
  peaks at marginal coupling. Same caveat as above: the *trend* is
  robust (different N values share contamination), but absolute σ/μ
  values are contaminated.

**Unaffected results** (pure mean-field):

* All deterministic GS profiles, FWHM measurements, on-axis ratios at
  the deterministic level (0.092 baseline number).
* Eu collapse threshold bracketing (Finding A from the N scan).
* Saito-Li-style LHY-insufficiency conclusion (mean-field driven).
* Round-3 phase diagram (mean-field energy comparison).

## Why grid coarsening alone explains the σ/μ drop

A subtlety: the 16³ runs also have a **different ground state** than
32³ runs. At 32³, peak n = 0.094 with z-elongated filament (FWHM_z = 6
cells of 0.625 a_ho ≈ 3.75 a_ho); at 16³, peak n = 0.019 — a 5× drop —
with on-axis ratio 0.97 (smooth Gaussian). The grid-coarsened ground
state simply doesn't resolve the filament.

So the σ/μ drop has two contributing causes:

1. **Sinatra criterion** (the intended check): fewer noise modes → less
   classical thermalisation → cleaner quantum-noise signal.
2. **Grid resolution**: 16³ averages over the filament structure; the
   underlying physics is different.

Disentangling these would require running 16³ with `box = 10` (so the
voxel size matches 32³ × box=20), which preserves resolution but
quadruples the trap frequency. The true Sinatra-isolated test is:

* same physics (same trap, same box, same N_atoms, same c_total/c_dd)
* different grid resolutions
* different cutoff_energy at fixed grid

The current `coarse_16g` and `cutoff_16g` configs share the box=20 trap,
so they don't isolate Sinatra from resolution.

## Honest takeaway

The Sinatra result here is **directionally clear** (32³ baseline is in
the danger regime, σ/μ drops dramatically as the danger is reduced) but
not a **clean Sinatra-only measurement** because the ground-state
profile changes between 32³ and 16³ at fixed box=20. To get a clean
Sinatra-only test, the 16³ run should use box=10 (matching 32³ resolution).

For the manuscript, the conservative claim is:

> "TWA at 32³ × F=6 with N=10⁴ atoms is in the Sinatra danger regime
> (ratio ≈ 43); a coarser-grid comparison shows σ/μ at peak shrinking
> dramatically, indicating that the 32³ ensemble σ/μ is not a clean
> quantum-fluctuation observable. A Sinatra-clean refinement is left
> for follow-up work."

This is enough to flag the issue without overclaiming — and it doesn't
invalidate the deterministic / mean-field findings (Findings A, the
LHY-insufficiency, the 6-polyhedral closed-form analysis) which are
where the bulk of the thesis Ch.6 / Paper #1-3 contribution lives.

## Acceptance criterion outcome

| Criterion | Threshold | Measured | Outcome |
|---|---|---|---|
| σ/μ spread / max | < 20% (publishable) | **97%** | ❌ |
| σ/μ spread / max | < 50% (marginal) | 97% | ❌ |
| σ/μ spread / max | ≥ 50% (broken) | 97% | ✗ confirmed broken |

## Bug fix (analyzer verdict logic)

The first run of `examples/twa_sinatra_validation_analyze.jl` reported
"REAL quantum noise (publishable)" because of a `extrema` unpacking bug:
`σ_max, σ_min = extrema(σs)` — but Julia's `extrema` returns
`(min, max)`, so the order was reversed and `spread` came out negative.
Fixed 2026-05-08 by swapping to `σ_min, σ_max = extrema(σs)`. The
corrected verdict is "SPURIOUS classical thermalisation" as expected
from the data.

## Reproduction

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    examples/twa_sinatra_validation.jl
julia --project=. examples/twa_sinatra_validation_analyze.jl
```

## Recommended follow-up

1. **Sinatra-clean re-run at 16³ with box=10** (same grid resolution as
   32³, so ground state is unchanged). Wall-clock ~5 min on RTX 5070 Ti.
   This is the definitive Sinatra-only test.

2. **Skip 32³ × F=6 TWA for further "quantum fluctuation" claims**.
   Switch to either:
   * **16³ × F=6 baseline** for TWA (Sinatra-safe, but lower spatial
     resolution)
   * **TDHFB or full Beliaev** for 32³ × F=6 (resolved spatial dynamics
     with controlled beyond-mean-field theory)

3. **Quote σ/μ values relative**, not absolute, when comparing across
   N or ε_dd at fixed grid (the trends survive contamination, the
   absolute numbers don't).

## See also

* `docs/research_notes/twa_eps_dd_scan.md` — species scan (with the
  same caveat propagated)
* `docs/research_notes/twa_N_scan_result.md` — N (coupling) scan
  (Finding B trend survives, absolute σ/μ doesn't)
* `docs/theory/sinatra_criterion_F6.md` — the prescriptive theory page
  that this empirical check confirms
