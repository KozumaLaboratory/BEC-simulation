# 修論 Chapter 5: TWA + Chaotic Dipolar Dynamics in F=6 ¹⁵¹Eu (outline)

**Status**: outline draft 2026-05-08, framing revision after May-7/8
GPU run sequence. Replaces / supersedes the earlier "TWA quantum
fluctuations" framing once the chaotic-instability interpretation
landed. Full chapter writing deferred to a later round.

## Framing change vs earlier (Round-2/3 era) plan

**Earlier framing** (Round 2/3 prep): TWA gives an O(1/N) controlled
expansion around the GP mean field. Eu EdH at marginal collapse shows
σ/μ ≈ 0.42 at peak density ≡ "quantum fluctuations of order O(1)
relative to the mean".

**Why it was wrong**: σ/μ at peak in the dipolar-instability regime is
dominated by chaotic trajectory divergence, not by Wigner-noise
amplitude. The 1/√N test at Sinatra-clean 16³ × box=10 (May 8)
explicitly shows σ/μ × √N growing 17.7 → 41.5 → 259 across N values,
i.e. 1/√N TWA scaling fails.

**Revised framing**: TWA at leading order is a **chaos-onset
diagnostic** for the Eu post-quench dipolar instability, NOT a
quantitative quantum-fluctuation measurement. The σ/μ ≈ 0.4-0.8 signal
tracks where the system enters the chaotic dipolar-collapse manifold.
For controlled quantum-fluctuation claims we need TDHFB, Beliaev, or a
two-time correlation matrix beyond the leading TWA.

## Chapter outline (revised)

### §5.1 Introduction
Eu F=6 post-quench EdH protocol motivates beyond-mean-field treatment;
deterministic GP (Ch.4) shows collapse, so ask: do quantum fluctuations
stop it? Three orthogonal routes (LHY, TWA, TDHFB) each have boundaries
that this chapter delimits.

### §5.2 LHY-insufficiency (5-mode ablation, 2026-05-07 result)
Five LHY treatments (off / scalar / polar_contact / polar_dipolar /
full_bdg) all collapse to the same z-elongated filament for Eu F=6
a_s=110 a_B at 32³.
LHY is sub-leading vs the mean-field DDI in this regime — see
`docs/research_notes/eu_collapse_lhy_insufficient.md`.

### §5.3 TWA implementation in SpinorBEC.jl
Welford-accumulated 50-trajectory ensemble, Wigner vacuum noise per
spinor component, persistent JLD2 layout (mean / variance per
observable per phase). Reference Round-3 Task 5 dashboard panel for
visualisation.

### §5.4 The coupling-strength scan (formerly "N scan")
Configs at `runs/twa_N_scan/N{1000,10000,100000}_<hash>/`. **Finding A**
(collapse-threshold bracketing): natural Eu coupling at N=10⁴ sits at
the collapse boundary; N=10³ is sub-collapse Gaussian, N=10⁵ is
super-collapse blow-up. **Finding B** (σ/μ peaks at marginal): the
chaos-onset diagnostic — trajectories diverge most at the instability
boundary.

(NB: this scan was originally framed as a 1/N TWA validity test but is
actually a coupling-strength scan because c_total ∝ N in the configs.
The canonical 1/N test lives in §5.5 below.)

### §5.5 Sinatra-clean 1/N validity test (the corrected framing)
Configs at `runs/twa_N_scan_pinned_16g/`, resolution-matched to
32³×box=20 baseline (dx = 0.625). Pinned c_total / c_dd at Eu N=10⁴
values (937.453 / 42.204) so MF physics is identical. N varied 10³ →
10⁵, Sinatra ratio swept 53 → 0.53.

**Result**: 1/√N scaling fails. σ/μ × √N grows from 17.7 to 259 across
N. At Sinatra-clean N=10⁵ (ratio 0.53), σ/μ = 0.82 — *higher* than the
contaminated 32³ baseline (0.42). This rules out classical
thermalisation as the cause of σ/μ; the genuine cause is chaotic
trajectory divergence.

**Implication**: TWA leading-order is not a quantitative
quantum-fluctuation observable in the chaotic dipolar regime.

### §5.6 Species ε_dd scan
Configs at `runs/twa_eps_dd_scan/`. Cr / Eu / Er / Dy mimicked at
fixed Eu trap by `c_dd` override. Cleanest mean-field results:
z-elongation grows monotonically, on-axis ratio decreases monotonically.
σ/μ peaks at marginal Eu (chaos-onset, consistent with Finding B).

### §5.7 Sinatra criterion + GS-resolution caveat
The Sinatra criterion (N_modes × D ≪ N_atoms) is a necessary
condition for the truncated-Wigner expansion to be controlled, but
NOT sufficient when the dynamics is chaotic. The (32³ vs 16³×box=20)
σ/μ shrinkage observed in the May-7 Sinatra check was a
ground-state-resolution artifact (16³×box=20 cannot resolve the
3.75 a_ho filament), not a Sinatra effect. Resolution-matched
comparison (16³×box=10) preserves the GS profile and reveals the
chaos signature persisting independent of Sinatra ratio.

This is a methodological lesson worth its own subsection — clean
beyond-mean-field validation requires holding the GS attractor fixed
while varying noise / mode-count.

### §5.8 Outlook: TDHFB / Beliaev for chaotic regimes
Where TWA fails, higher-order theories with explicit pair-fluctuation
content (TDHFB) or with full self-consistent Bogoliubov treatment
(Beliaev) become necessary. Implementation roadmap:

* TDHFB: track pair amplitudes <ψψ> alongside <ψ> in a coupled GP+pair
  evolution; computational cost is ~D² fields per voxel, factor D=13
  expensive but feasible at 32³ on GPU.
* Beliaev: full self-consistent Bogoliubov mode resummation; analytical
  for uniform but numerically heavy for trap geometries.

Both are deferred to D-thesis Ch.3 candidates.

## Connection to manuscripts

* **Ch.5 thesis content**: the framing here will be inlined as §5.1-§5.8
  in `docs/manuscript/thesis/chapters/Ch5_TWA_*.md` (final integrated
  file) once the deterministic Ch.4 (SpinorBEC.jl simulator) is
  written.
* **Paper #4 candidate**: "Chaotic dipolar instability and the
  break-down of leading-order TWA in Eu F=6 spinor BEC". PRR target.
  Self-contained around §5.4 + §5.5 + §5.6.
* **No conflict** with Paper #1/2/3 (those are mean-field +
  closed-form LHY work, unaffected by the chaos finding).

## Pending GPU work (none — all 5 GPU sweeps complete)

| Sweep | Status | Result |
|---|---|---|
| 5-LHY-mode ablation | ✅ done | LHY-insufficient |
| Coupling N scan (32³) | ✅ done | Findings A/B |
| Species ε_dd scan | ✅ done | trend confirmed |
| Sinatra check (32³ + 2×16³) | ✅ done | (revised verdict — GS-resolution) |
| Pinned 1/N at 16³×box=10 | ✅ done | chaos signature, 1/√N fails |

The next sweep would be a TDHFB pilot — beyond Round-7 scope.

## Open questions for D-thesis

1. **Quantitative chaos amplitude**: σ/μ ≈ 0.4-0.8 — is there a closed
   form for chaos amplitude from the BdG spectrum at marginal
   collapse?
2. **Connection to experimental observation**: Does single-shot
   imaging of post-quench Eu show 4.5× variability of filament
   orientation across shots? (Predicts σ/μ ~ 0.4 in lab-frame
   density at peak.)
3. **TDHFB convergence**: When the simulator runs TDHFB on this
   regime, do quantum fluctuations stabilise the cloud (no collapse)
   or merely renormalise the chaos amplitude (collapse, but with
   reduced σ/μ)?

## See also

* `docs/research_notes/twa_pinned_16g_result.md` — the May-8 result
  that drove this framing change
* `docs/research_notes/twa_sinatra_validation.md` — corrected verdict
  on the Sinatra check
* `docs/research_notes/twa_N_scan_result.md` — Findings A + B (with
  revised σ/μ interpretation)
* `docs/research_notes/twa_eps_dd_scan.md` — species universality
  reframed as chaos-onset diagnostic
* `docs/theory/sinatra_criterion_F6.md` — caveat added on
  σ/μ-in-chaotic-regimes
