# TWA on Eu post-quench EdH — what we learned

Synthesis of 4 ensemble scans + 1 theory check. Raw data records of each scan live in the per-run files in this directory; this page is the place to read for "what does TWA tell us about Eu F=6 dipolar collapse".

## The setup

All scans use the same Eu EdH protocol on a 32³ × box=20 grid (or resolution-matched 16³ × box=10 for the Sinatra-clean control):

- Ground state: Eu151 stretched m=+6, Bz = 0.01 G (1 μT)
- Quench: Bz: 0.01 → 2.6e-5 G in 0.20 ms
- Hold: Bz = 2.6e-5 G for 1.45 ms with γ_dr = 0.02 dipolar relaxation
- 50-trajectory Wigner ensemble per point

Reproduces the dipolar-collapse regime where Eu sits at marginal self-binding (`ε_dd ≈ 0.55`).

## Three findings, one open question

### Finding 1 — LHY can't stop the collapse

5 LHY treatments compared (`off / scalar / polar_contact / polar_dipolar / full_bdg`) at the Eu marginal point. **All five produce the same density profile**: peak 0.118, FWHM(x, z) = (1, 6) cells, on-axis ratio 0.092, Mz 5.44. LHY is sub-leading (~3% of mean-field) at the relevant density and doesn't shift the collapse outcome.

This matches Saito-Li 2024's observation: Eu's measured `a_s = 110 a_B` sits below the droplet-formation threshold; LHY would need to be ~5× stronger. Going beyond mean-field requires TDHFB or full Beliaev — see "Open question" below.

Raw record: `eu_collapse_lhy_insufficient.md`.

### Finding 2 — Coupling-strength threshold brackets Eu at marginal

| N    | c_dd × n_peak | regime | peak n | FWHM (x,z) | on-axis |
|---:  |---:|---|---:|---:|---:|
| 10³  | 1.1 | sub-collapse Gaussian | 0.265 | (2, 2) | 1.000 |
| 10⁴  | 4.0 | **marginal collapse** | 0.094 | (1, 6) | 0.416 |
| 10⁵  | 11.4 | super-collapse, delocalised | 0.027 | (9, 11) | 0.204 |

Eu at the lab-realistic N=10⁴ sits exactly at the dipolar instability boundary — the FWHM_z = 6 cells filament forms but doesn't run away.

Same trend across species (Cr/Eu/Er/Dy at fixed trap geometry, species-varying ε_dd):

| Species | ε_dd | FWHM_z / FWHM_x | on-axis |
|---|---:|---:|---:|
| Cr | 0.15 | 2  | 0.998 |
| **Eu** | **0.55** | **6**  | **0.416** |
| Er | 0.88 | 10 | 0.041 |
| Dy | 1.39 | 1  | 0.025 |

z-elongation grows monotonically with ε_dd until the cloud blows up below grid resolution at Dy. Eu at ε_dd ≈ 0.5 is the canonical onset.

Raw records: `twa_N_scan_result.md`, `twa_eps_dd_scan.md`.

### Finding 3 — σ/μ ≈ 0.4 is chaos, not Wigner noise

Trajectory-level σ/μ at peak voxel reaches ~0.4 at marginal Eu, drops to ~0 at sub-collapse, drops to ~0.1 at super-collapse. **Originally this was framed as quantum fluctuation visibility.** A Sinatra-clean follow-up (16³ × box=10, dx-matched to the 32³ baseline) at three N values overturned that:

| N    | Sinatra ratio | σ/μ peak |
|---:  |---:|---:|
| 10³  | 53.2 (contaminated) | 0.560 |
| 10⁴  | 5.3                  | 0.415 |
| 10⁵  | **0.53 (clean)**     | **0.819** |

If σ/μ were 1/√N Wigner noise, it would shrink as N grows; instead it grows. The signal is **chaotic trajectory divergence in the dipolar-instability regime** — different Wigner-noise seeds drive trajectories to different orientations of the z-elongated filament, and σ at peak measures that physics-bounded chaos amplitude.

The earlier `twa_sinatra_validation.md` "spurious classical thermalisation" verdict was wrong — its 16³ × box=20 control had dx = 1.25 a_ho, too coarse to resolve the 3.75 a_ho filament; the cloud stayed smooth Gaussian without chaos, masquerading as Sinatra cleanup. The dx-matched 16³ × box=10 control fixed this.

Raw records: `twa_pinned_16g_result.md` (the corrected verdict), `twa_sinatra_validation.md` (superseded original).

## What survives, what's reframed

### Observations (data-level, unchanged)

| Observable | Source |
|---|---|
| FWHM, on-axis ratio | deterministic GS — same across all LHY modes, all N |
| Collapse threshold bracketing Eu at marginal | N scan (`twa_N_scan_result.md`) |
| Species z-elongation Cr → Eu → Er progression | ε_dd scan (`twa_eps_dd_scan.md`) |
| σ/μ peaks at marginal coupling | both scans |

### Interpretations (changed after Sinatra-clean follow-up)

| Old framing | Corrected framing |
|---|---|
| σ/μ ≈ 0.4 = Wigner-noise visibility | trajectory-level chaos in the dipolar instability |
| Sinatra ratio drives σ/μ shrinkage at 16³ | the 16³ × box=20 control had wrong dx; shrinkage was a GS-resolution effect |
| TWA-with-large-Sinatra-ratio is "spurious thermalisation" | the σ/μ signal is physics-bounded (chaos amplitude), not noise-bounded |

Manuscript wording change: "σ/μ ≈ 0.4 quantum fluctuation" → "σ/μ ≈ 0.4 trajectory-level fluctuation in the dipolar-instability regime, attributable to chaotic dynamics rather than Wigner noise amplitude".

## Open question — bouncing the σ/μ floor

TWA leading-order is **not a clean σ/μ measurement tool** in chaotic regimes. For quantitative quantum-fluctuation claims at 32³ × F=6 with N=10⁴ atoms (the lab-realistic point), the codebase needs either:

1. **TDHFB** — controlled second moment via the truncated-Hartree-Fock-Bogoliubov hierarchy, or
2. **Full Beliaev** — pairing-field self-consistent BdG.

Neither is implemented. They would target the same phenomenology this TWA scan made visible (chaotic divergence + smearing) but with a controlled approximation that decouples chaos from sampling noise.

## Sinatra criterion in one paragraph

The TWA truncation `ψ_classical + δψ_stochastic` is controlled when `N_modes_eff × D ≪ N_atoms`. Eu's N=10⁴ on 32³ × D=13 gives ratio ≈ 43 — well into the danger regime — but the σ/μ chaos signal is physics-bounded (not noise-bounded), so the contamination question is moot for chaotic-regime σ/μ. Mean-field observables (FWHM, on-axis ratio) are unaffected by the criterion regardless. Full theory: `docs/theory/sinatra_criterion_F6.md` (kept for the per-knob sampling helpers exposed in `src/dynamics/sinatra_helpers.jl`).
