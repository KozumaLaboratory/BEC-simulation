# TWA N scan result — collapse-threshold scan, NOT the 1/N validity test

**Status**: 3 ensembles complete 2026-05-07 16:00; runtime ~107 min.
**Code path**: `runs/N{1000,10000,100000}_<hash>/result.jld2`,
analysed by `examples/twa_N_scan_analyze.jl`.

## TL;DR

The N scan as configured varies `N_atoms` only, which auto-scales the
dimensionless mean-field couplings `c_total ∝ N` and `c_dd ∝ N`. The
result is therefore **not** the intended 1/N TWA-validity test (which
requires fixed physics with only the noise scale changing). What the
data does cleanly establish is that the post-quench EdH instability
has a sharp collapse threshold somewhere between N = 1×10³ and
N = 1×10⁵, with the natural Eu-151 a_s = 110 a_B baseline (N = 10⁴)
sitting near criticality.

A re-run with `c_total` and `c_dd` overridden (locked at the N=10⁴
value) is needed for the canonical 1/N test.

## Per-ensemble result

Deterministic baseline (`runs/eu151_edh_postfix_local`, N = 10⁴):
peak n = 0.118, FWHM(x, z) = (1, 6), on-axis ratio = 0.092.

| Run | n_traj | peak n | FWHM (x, z) | on-axis | σ/μ peak | regime |
|---|---:|---:|---:|---:|---:|---|
| N=10³  | 50 | 0.265 | (2, 2)  | 1.000 | 0.002 | sub-collapse (Gaussian) |
| N=10⁴  | 50 | 0.094 | (1, 6)  | 0.416 | 0.423 | marginal collapse |
| N=10⁵  | 50 | 0.027 | (9, 11) | 0.204 | 0.218 | super-collapse blow-up |

* **N=10³**: cloud stays in the trap GS profile; the dipolar driving
  term `c_dd × n_peak ≈ 765 × 0.27 ≈ 200` is below the collapse
  threshold for this trap. σ/μ ≈ 0.002 is consistent with the
  small-fluctuation regime — TWA noise barely perturbs the GS.
* **N=10⁴**: marginal — same FWHM_z = 6 cells as the deterministic
  EdH baseline, but the on-axis hole is partially smeared
  (0.092 → 0.416). σ/μ at peak ≈ 0.42, the headline number from the
  EdH-collapse note.
* **N=10⁵**: super-critical — collapse runs away, the cloud
  delocalises across most of the box (FWHM 9×11 cells out of 32),
  peak density drops by 4× vs deterministic. Likely the simulator is
  dissipating energy into the box rather than reaching a self-bound
  ground state, and the "ensemble mean" is averaging over chaotic
  trajectories rather than a clean attractor.

## Why this is not a 1/N validity test

The user-intended 1/N expansion check holds physics fixed and varies
only the *quantum-noise scale*: as N → ∞ the trajectory ensemble
should approach the deterministic GP solution with `(σ/μ) ∝ 1/√N` and
`(TWA mean − GP) / GP ∝ 1/N`. This requires single-particle physics
to be invariant — i.e., `c_total = N · g_phys` and `c_dd = N · μ²`
held FIXED while N changes.

In the configs as run, `c_total` was derived from the atom species
+ N_atoms by SpinorBEC's interactions calculator, so it scaled
linearly:

  c_total(N=10³)  ≈ 469
  c_total(N=10⁴)  ≈ 4689
  c_total(N=10⁵)  ≈ 46890

c_dd scaled the same way (Eu's natural ε_dd ≈ 0.55 stayed constant),
which means the mean-field collapse strength changed by a factor of
100× across the three ensembles. The result is a *coupling-strength*
scan, not a noise-scale scan.

Numerically: σ/μ × √N would only be N-independent under fixed
physics. Here it grew from 0.05 to 42 to 69 — the N=10³ "low σ/μ"
is not "fewer fluctuations" but "no instability to fluctuate around";
the N=10⁵ "low σ/μ" is "trajectories collapse into a chaotic
distribution where the variance is misleading because the ensemble
mean is meaningless".

## How to do the canonical 1/N test

Override `c_total` and `c_dd` in the YAML to lock them at the N=10⁴
values:

```yaml
mixins:
  eu151_edh_phys:
    atom:         Eu151
    grid:         {n: [32, 32, 32], box: [20, 20, 20]}
    potential:    {type: harmonic, omega: [1.0, 1.0, 1.182]}
    interactions:
      N_atoms:    1000     # vary across runs
      c_total:    4689.0   # locked at N=10⁴ baseline
      c_dd:       7647.0   # locked at N=10⁴ baseline
      omega_ref:  691.15
      c1_ratio:   0.0
```

With this override, the Wigner noise variance per mode `1/(2V)` is
independent of N_atoms but the relative noise-to-MF ratio scales
inversely with √N_atoms — the proper TWA validity check.

Wall-clock estimate for the canonical re-run: same ~95 min as this
scan.

## Salvageable physics from the current data

* **Collapse threshold for Eu-151 a_s = 110 a_B** lies between
  c_total = 469 and c_total = 46890; the marginal point is at
  c_total ≈ 4700 (the natural N=10⁴ value), confirming the
  EdH-collapse note's analysis from the deterministic side.
* **Anti-collapse regime** (N=10³): the cloud's quantum-statistical
  σ/μ ≈ 0 is consistent with linear-response Wigner sampling around a
  stable GS — a sanity check that the TWA noise injection is
  correctly normalised (no spurious classical heating).
* **Catastrophic regime** (N=10⁵): when the MF instability is fast
  vs the box scale, the simulator cannot stabilise at a self-bound
  state; the ensemble mean's interpretability breaks down regardless
  of the Sinatra criterion. This argues against pushing N-atom-scaled
  studies into the strong-collapse limit without a self-bound LHY
  stabilisation channel — exactly the gap the LHY ablation note
  established for Eu F=6.

## See also

* `docs/research_notes/eu_collapse_lhy_insufficient.md` — the
  five-LHY-mode ablation that motivated this scan.
* `docs/research_notes/twa_sinatra_validation.md` — the orthogonal
  validity test (grid + cutoff). The Sinatra check is the *next*
  required step for the σ/μ ≈ 0.42 result at N = 10⁴ to be
  publishable; the canonical 1/N re-run is the test after that.
* `examples/twa_N_scan.jl`, `examples/twa_N_scan_analyze.jl`,
  `test/test_twa_N_scan.jl`.

## Reproduction

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    examples/twa_N_scan.jl
julia --project=. examples/twa_N_scan_analyze.jl
```

The runner skips configs whose `result.jld2` already exists. The
analyzer resolves the hash-suffixed run dirs by glob.
