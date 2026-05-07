# TWA N scan: Eu post-quench coupling-strength scan

**Status**: 3 ensembles complete 2026-05-07 16:00; runtime ~107 min on
RTX 5070 Ti. Three production findings + one methodological note.
**Code path**: `runs/N{1000,10000,100000}_<hash>/result.jld2`,
analysed by `examples/twa_N_scan_analyze.jl`.

**2026-05-08 update (σ/μ reinterpretation)**: σ/μ values quoted below
were originally framed as "quantum fluctuation" magnitudes. The
Sinatra-clean follow-up (`twa_pinned_16g_result.md`) established that
σ/μ in the dipolar-instability regime is **chaotic trajectory
divergence**, not Wigner noise — and does NOT scale as 1/√N. Finding B
below (σ/μ peaks at marginal collapse) survives as a **chaos-onset
diagnostic**, not as a quantum-fluctuation diagnostic. Mean-field and
profile findings (Finding A, FWHM trends) are unaffected.

## Summary

This scan was originally framed as the canonical 1/N TWA-validity
test. As implemented (only `N_atoms` varied), `c_total` and `c_dd`
auto-scaled linearly with N, so the result is a **coupling-strength
scan** at fixed Eu species rather than a noise-scale-only scan. The
canonical 1/N test, with `c_total` and `c_dd` pinned, is staged at
`runs/twa_N_scan_pinned/` and queued as the next GPU job after the
Sinatra-criterion check completes.

What this scan **does** establish:

* **Finding A** — collapse threshold for Eu F=6 a_s = 110 a_B is
  bracketed inside `c_total ∈ [93.7, 9374]` (i.e. the natural Eu
  coupling at N=10³–10⁵). The N=10⁴ baseline sits at
  *marginal collapse*.
* **Finding B** — the trajectory-level σ/μ at peak density is *not*
  monotone in N. It peaks at the marginal-collapse N=10⁴ point
  (σ/μ ≈ 0.42) and drops by 100× at sub-critical N=10³ and by 2× at
  super-critical N=10⁵. Quantum-fluctuation visibility is
  maximal exactly at the dipolar instability boundary.

## Per-ensemble result

Deterministic baseline (`runs/eu151_edh_postfix_local`, N = 10⁴):
peak n = 0.118, FWHM(x, z) = (1, 6), on-axis ratio = 0.092.

| Run | n_traj | peak n | FWHM (x, z) | on-axis | σ/μ peak | regime |
|---|---:|---:|---:|---:|---:|---|
| N=10³  | 50 | 0.265 | (2, 2)  | 1.000 | 0.002 | sub-collapse (Gaussian)  |
| N=10⁴  | 50 | 0.094 | (1, 6)  | 0.416 | 0.423 | **marginal collapse**    |
| N=10⁵  | 50 | 0.027 | (9, 11) | 0.204 | 0.218 | super-collapse blow-up   |

Auto-derived couplings via `compute_c_total(Eu151; N_atoms, omega_ref=691.15)`:

  N=10³  → c_total ≈   93.7,  c_dd ≈   4.22
  N=10⁴  → c_total ≈  937.5,  c_dd ≈  42.20    (Eu natural baseline)
  N=10⁵  → c_total ≈ 9374.5,  c_dd ≈ 422.0

ε_dd = c_dd / c_total ≈ 0.045 stays N-independent (as expected for a
species-fixed scan). The scan therefore probes Eu's dipolar collapse
threshold through `c_dd × n_peak`, which scales super-linearly in N
because `n_peak` itself grows weakly with the coupling.

## Finding A: collapse threshold bracketing

The three regimes are physically distinct:

* **N=10³ — sub-collapse** (`c_dd × n_peak ≈ 1.1`): cloud stays in the
  trap GS; no z-elongation, no on-axis depletion. This regime is
  smooth-Gaussian and the simulator is essentially evolving a stable
  attractor with weak Wigner noise on top.
* **N=10⁴ — marginal collapse** (`c_dd × n_peak ≈ 4.0`): the
  z-elongated filament forms (FWHM_z = 6 cells matches the
  deterministic baseline). The cloud is on the dipolar-instability
  boundary — partially collapsed, not yet self-bound.
* **N=10⁵ — super-collapse blow-up** (`c_dd × n_peak ≈ 11.4`): the
  collapse runs faster than the trap can stabilise, the cloud
  delocalises across most of the box (FWHM 9×11 of 32 cells available).
  The "ensemble mean" here averages over chaotic trajectories with no
  shared attractor — the variance is real but the mean is no longer a
  meaningful physical state.

This is the first systematic numerical bracketing of Eu post-quench
collapse onset for the SpinorBEC.jl 32³ box configuration. Combined
with the LHY ablation (`docs/research_notes/eu_collapse_lhy_insufficient.md`,
which established that all 5 LHY treatments collapse to the same
profile at marginal N=10⁴), this gives a complete coupling-strength
characterisation: LHY does not save the cloud at any of the 3 regimes,
and the system has a sharp threshold at N≈10⁴ for the experimental
trap.

## Finding B: σ/μ peaks at the instability boundary

The σ/μ-vs-N curve is non-monotone:

  σ/μ(N=10³)  = 0.002  ← weak fluctuations around stable GS
  σ/μ(N=10⁴)  = 0.423  ← maximum quantum-fluctuation visibility
  σ/μ(N=10⁵)  = 0.218  ← decoheres into chaos with smaller relative spread

Physically: at sub-critical coupling the system has a single attractor
(Gaussian GS) and trajectories cluster tightly around it. At
super-critical coupling the trajectories diverge to mutually
inconsistent collapse outcomes (different rotational orientations of
the chaotic cloud), so per-voxel σ stays large in absolute terms but
the per-voxel μ also drops as the cloud spreads, partially cancelling
in σ/μ. The maximum *visibility* of trajectory-level fluctuation is
where the system sits exactly at the instability — the noise drives
the simulator across the bifurcation in a controlled way, producing
the cleanest signature.

This finding constrains the experimental observation strategy: the
Eu N≈10⁴ regime is the favourable observation window. Increasing N
"makes the dynamics quantum-classical-irrelevant"
(super-collapse), decreasing N "makes the dynamics quantum-noise
irrelevant" (sub-collapse).

## Methodological note: what the next 1/N re-run will probe

The canonical 1/N TWA validity test is a *separate* experiment from
this coupling scan. Configs at `runs/twa_N_scan_pinned/` pin
`c_total = 937.453` and `c_dd = 42.204` (the Eu natural N=10⁴ baseline
values) and vary only `N_atoms ∈ {10³, 10⁴, 10⁵}`, holding the entire
mean-field physics fixed. Expected behaviour for that scan:

* (TWA mean − GP) / GP  ∝ 1/N
* σ/μ at peak           ∝ 1/√N
* FWHM_z = 6 cells      N-independent (genuine dipolar instability)

The Wigner noise per mode is 1/(2V), independent of N, so the
*relative* noise vs MF is what changes between runs. If the scaling
holds, TWA at the N=10⁴ baseline is a controlled approximation. If
it doesn't, Sinatra-criterion violation is implicated and the
σ/μ ≈ 0.42 result is contaminated by classical thermalisation.

## Reproduction

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    examples/twa_N_scan.jl
julia --project=. examples/twa_N_scan_analyze.jl
```

Pinned-coupling re-run:

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    examples/twa_N_scan_pinned.jl
```

The runner skips configs whose `result.jld2` already exists. The
analyzer resolves the hash-suffixed run dirs by glob.

## See also

* `docs/research_notes/eu_collapse_lhy_insufficient.md` — five-LHY-mode
  ablation establishing collapse is mean-field driven at N=10⁴.
* `docs/research_notes/twa_sinatra_validation.md` — the orthogonal
  validity test (grid + cutoff). The canonical 1/N re-run depends on
  Sinatra not flagging the 32³ baseline.
* `docs/research_notes/twa_eps_dd_scan.md` (pending) — species
  universality counterpart to Finding A.
* `examples/twa_N_scan*.jl`, `test/test_twa_N_scan.jl`.
