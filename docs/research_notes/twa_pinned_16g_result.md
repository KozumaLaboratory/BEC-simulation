# Sinatra-clean 1/N TWA validity test on 16³ × box=10 — pinned coupling

**Status**: 3 ensembles complete 2026-05-08 04:55, runtime ~72 min.
Resolution dx = 10/16 = 0.625 a_ho preserved against the 32³ × box=20
baseline; Sinatra ratio swept 53 → 5.3 → 0.53 across the three N values
at fixed mean-field physics (c_total = 937.453, c_dd = 42.204).

**Verdict**: the σ/μ ≈ 0.4 observed at the Eu marginal-collapse point is
**REAL physics — chaotic-dipolar-instability noise**, NOT Sinatra
contamination as the prior `twa_sinatra_validation.md` (May 7) verdict
claimed. The previous verdict conflated the Sinatra effect with a
ground-state-resolution effect from the 16³ × box=20 setup, which had a
qualitatively different GS profile (smooth Gaussian vs filament). The
Sinatra-clean N=10⁵ point at 16³ × box=10 (ratio 0.53) gives σ/μ = 0.82
— *higher* than the 32³ contaminated baseline 0.42, which rules out
classical thermalisation as the dominant source of the σ/μ signal.

The 1/√N TWA validity scaling does NOT hold on this observable: σ/μ × √N
grows from 17.7 to 259 across the three N values. This indicates that
the TWA σ/μ at peak is dominated by **chaotic trajectory divergence**
in the dipolar-instability regime, not by quantum-noise amplitude.
TWA leading-order is therefore not a clean tool for σ/μ in this
chaotic regime — TDHFB or full Beliaev is needed for a controlled
beyond-mean-field treatment.

## Per-N result

| N      | Sinatra ratio | n_traj | peak n | FWHM (x,z) | on-axis | σ/μ peak |
|---:    |---:|---:|---:|---:|---:|---:|
| 10³    | 53.2 | 50 | 0.085 | (4, 6) | 0.133 | 0.560 |
| 10⁴    | 5.3  | 50 | 0.083 | (4, 6) | 0.129 | 0.415 |
| 10⁵    | 0.53 | 50 | 0.073 | (4, 6) | 0.120 | 0.819 |

Mean-field physics (peak n, FWHM, on-axis ratio) is **N-independent**
within ~10%, confirming the pinned-coupling setup gives a stable GS
across the three N values. The dipolar-instability filament
(FWHM_z = 6 cells, on-axis depletion 0.13) is consistent across all
three runs.

## What this overturns

### Wrong: "32³ baseline σ/μ ≈ 0.42 is Sinatra-contaminated"

The earlier `twa_sinatra_validation.md` analysis showed
σ/μ = 0.42 / 0.04 / 0.01 across (32³ box=20) / (16³ box=20) /
(16³ box=20 cutoff_16g) and concluded "spurious classical thermalisation".

The flaw: the 16³ × box=20 setup has dx = 1.25 a_ho, which **cannot
resolve the 3.75 a_ho z-elongated filament**. The cloud at 16³ box=20
stays smooth Gaussian (peak n = 0.019 vs 0.094 at 32³ box=20). With no
filament, there's no dipolar-instability chaos, so σ/μ is small. The
σ/μ shrinkage from 0.42 to 0.04 reflects **GS profile difference**, not
Sinatra contamination.

The current 16³ × box=10 setup preserves dx = 0.625 a_ho (matching
32³ × box=20) and recovers FWHM_z = 6 cells. At N=10⁴ (Sinatra ratio
5.3), σ/μ = 0.42 — exactly matching the 32³ baseline. So the σ/μ
signal is grid-resolution-bound, not Sinatra-bound.

### Right: σ/μ ≈ 0.4-0.8 is real chaotic-dipolar-instability noise

Trajectories diverge because the dipolar-collapse direction depends
sensitively on the Wigner-noise seed (rotational orientation of the
filament fluctuates trajectory to trajectory). σ at peak measures this
chaotic spread, which is **bounded by physics not by noise amplitude**:
even at low Wigner noise (high N), trajectories still diverge because
the instability is intrinsically chaotic.

This explains why σ/μ × √N grows instead of being constant: the
quantum-noise contribution to σ shrinks as 1/√N, but the
chaotic-divergence contribution does not. At high N, the chaotic
contribution dominates → σ/μ saturates or grows.

## Implications for the thesis / paper

### What survives:
* All deterministic / mean-field results (FWHM, on-axis ratio,
  collapse threshold, polyhedral closed forms — unchanged)
* The σ/μ ≈ 0.4 signature at marginal Eu **as a chaotic-instability
  signature**, not as a "quantum fluctuation" measurement
* The species ε_dd trend (z-elongation grows with ε_dd, σ/μ peaks at
  marginal Eu) — same phenomenology, just reinterpreted

### What needs reframing:
* Manuscript wording: "σ/μ ≈ 0.4 quantum fluctuation" → "σ/μ ≈ 0.4
  trajectory-level fluctuation in the dipolar-instability regime,
  attributable to chaotic dynamics rather than Wigner noise amplitude"
* The 4.5× on-axis-ratio smearing (0.092 → 0.416) is partially real
  (chaos averages over different filament orientations) and is
  consistent with the chaotic-divergence picture
* TWA leading-order is **not a clean σ/μ measurement tool** here —
  for quantitative quantum-fluctuation claims, need TDHFB or Beliaev

### Bug in the prior Sinatra verdict
The `twa_sinatra_validation.md` write-up's conclusion was wrong. The
verdict-logic bug fix (extrema unpacking) was correct, but the
INTERPRETATION ("spurious classical thermalisation") was a
misdiagnosis. The actual cause of σ/μ shrinkage in `coarse_16g` and
`cutoff_16g` runs was that the cloud's GS profile changed (smooth
Gaussian instead of filament), not that classical thermalisation was
removed.

## Bonus: The N=10⁵ result is the cleanest TWA observable in the study

At Sinatra ratio 0.53, the truncated-Wigner expansion is in its
nominal validity regime. The result σ/μ = 0.82 is therefore the
cleanest measurement of the chaotic-dipolar σ/μ in this study. It
sets the **physical scale** of trajectory-level dispersion in the
Eu marginal-collapse regime, independent of grid choice.

For experimental connection: σ/μ ≈ 1 means trajectory variance is
comparable to mean density. Equivalently, 50 random Wigner samples
populate a wide manifold of collapse outcomes (different filament
orientations). This is what one would observe in repeated-shot
single-particle imaging of an Eu post-quench experiment, modulo
shot-to-shot atom-number noise.

## Reproduction

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib bash /tmp/twa_N_scan_pinned_16g_runner.sh
julia --project=. examples/twa_N_scan_pinned_16g_analyze.jl
```

Configs at `runs/twa_N_scan_pinned_16g/N{1000,10000,100000}_pinned_16g.yaml`,
results at `runs/N{N}_pinned_16g_<hash>/result.jld2`.

## See also

* `docs/research_notes/twa_sinatra_validation.md` — to be revised in
  light of this finding (the "spurious" verdict was wrong — the
  σ/μ shrinkage was a GS-resolution effect, not Sinatra contamination)
* `docs/research_notes/twa_N_scan_result.md` — Findings A/B (collapse
  threshold + σ/μ peak at marginal) survive but reinterpreted
* `docs/research_notes/twa_eps_dd_scan.md` — species trend survives;
  σ/μ values are now real chaotic-divergence signatures
* `docs/theory/sinatra_criterion_F6.md` — theory page should add a
  caveat that σ/μ in chaotic dynamical regimes is not a clean Wigner
  diagnostic; need amplitude-mode-resolved diagnostics or higher-order
  theory
