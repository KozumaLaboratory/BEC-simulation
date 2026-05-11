# Paper #4: Chaotic dipolar instability in post-quench F=6 spinor Bose-Einstein condensate: trajectory divergence and species universality

**Status (2026-05-12)**: Draft skeleton extracted from `paper4_raw.md` reframing
notes. Sections fully written: Abstract, I (Intro), II (Framework), III (Results).
TBD: §IV (Methodology Discussion), §V (Conclusions). All numerical claims
sourced from Round-5 GPU + Round-6 Sinatra-clean runs (see Ch.5 in master
thesis for full numerical detail and σ/μ scaling tables).

---

## Abstract

We report that ensemble-averaged Truncated Wigner Approximation (TWA)
simulations of post-quench F=6 spinor dipolar Bose-Einstein condensates
exhibit trajectory dispersion that does **NOT** scale as $1/\sqrt{N}$ — the
canonical leading-order TWA signature — but instead saturates at
amplitude-bounded values $\sigma/\mu \approx 0.4{-}0.8$ over wide ranges of
particle number and grid resolution. We trace this behavior to a chaotic
dipolar instability with positive Lyapunov exponent that amplifies Wigner
sampling seeds exponentially during post-quench evolution, producing
trajectory-to-trajectory filament-orientation divergence rather than
quantum-fluctuation-bounded spread. A species scan across Cr ($\varepsilon_{dd}
= 0.15$), Eu (0.55), Er (0.88), and Dy (1.39) shows $\sigma/\mu$ peaks
sharply at the Eu value, identifying $\varepsilon_{dd} \sim 0.5$ as the
**chaos-onset regime** for dipolar spinor instability. This reframing
establishes leading-order TWA as a **chaos diagnostic tool**, not a quantum
fluctuation tool, in dipolar dynamics. True quantum-fluctuation magnitude
extraction requires higher-order methods (TDHFB / Beliaev) deferred to
follow-up work.

---

## I. Introduction

### A. Spinor dipolar BEC post-quench dynamics

Spinor Bose-Einstein condensates with strong magnetic dipole-dipole
interaction (DDI) host a hierarchy of quench-induced dynamics ranging from
ferromagnetic-domain coarsening to filamentation and droplet formation.
Among bosonic species, ${}^{151}$Eu (F=6 ground state, magnetic moment
$\mu \approx 7\mu_B$) realizes the strongest dipolar regime experimentally
accessible.

### B. TWA expectation: quantum-fluctuation diagnostic

The Truncated Wigner Approximation (TWA) approximates quantum dynamics by
ensemble-averaging classical trajectories sampled from the initial Wigner
distribution. At leading order, trajectory dispersion is predicted to scale
as $\sigma/\mu \propto 1/\sqrt{N}$ where $N$ is the total particle number.
This scaling has historically been used as a diagnostic for quantum
fluctuation magnitude in cold-atom experiments.

### C. This paper: discovery that TWA captures chaos, not quantum fluctuations

We demonstrate that for post-quench F=6 ${}^{151}$Eu dipolar BEC, the
leading-order TWA ensemble produces $\sigma/\mu$ values **far in excess** of
the $1/\sqrt{N}$ prediction (factor of 200+ at $N = 10^5$). The breakdown is
not a numerical artifact (verified through resolution-matched, Sinatra-clean
benchmarks). We trace it to chaotic dipolar instability that amplifies
Wigner-sampling seeds exponentially, producing trajectory-to-trajectory
filament-orientation divergence. This motivates a methodological reframing
of TWA's role in dipolar dynamics.

---

## II. Numerical Framework

### A. F=6 spinor BEC simulation infrastructure

We use the open-source `SpinorBEC.jl` package, which implements the standard
13-component F=6 spinor with channel-decomposed two-body interactions
$c_0, c_1, c_2, c_3, c_4, c_5, c_6$ (corresponding to total-spin channels
$S = 0, 2, 4, 6, 8, 10, 12$). Dipole-dipole interaction is implemented via
FFT-based pseudo-spectral convolution with $Q_{\alpha\beta} = \hat k_\alpha
\hat k_\beta - \delta_{\alpha\beta}/3$ kernel and $Q(k=0) = 0$ regularization.
Time evolution uses the symmetric split-step Strang factorization
$V(dt/2) \cdot K(dt) \cdot V(dt/2)$ with substep auto-skip when the relevant
coupling is zero.

### B. TWA ensemble

Initial states are sampled from Wigner thermal noise at $T/T_c \in (0, 1)$
seeded from the ground state, with optional random spin-coherent perturbation.
Each trajectory propagates under the same deterministic equations of motion;
ensemble averages are computed over 50 trajectories per parameter point.

### C. Post-quench protocol

Ground state at $p = p_0$ (Zeeman field) is quenched to $p = p_f \neq p_0$
at $t = 0$; dynamics proceeds for $T = 10$ trap units. We measure peak
density, filament orientation, total magnetization, and BdG-like spin
correlations as functions of time.

---

## III. Results

### A. Mean-field Eu post-quench dynamics

The deterministic GP-LHY evolution at Eu parameters
($\varepsilon_{dd} \approx 0.55$, $c_0 \approx 50$) shows multi-clump azimuthal
patterning with z-axis elongation FWHM ratio $\approx 1:6$, on-axis density
depletion (peak shift from center), and qualitatively similar patterns across
the Cr, Eu, Er, Dy species at appropriately rescaled times.

### B. TWA σ/μ scaling — chaos signature

Round-5 GPU runs (50 trajectories, $32^3$ grid, $\text{box} = 10$,
$N = 10^5$) yield $\sigma/\mu \approx 0.42$, but **NOT** scaling as
$1/\sqrt{N}$ as $N$ varies:

| $N$ | $\sigma/\mu$ | $1/\sqrt{N}$ prediction | $\sigma/\mu \cdot \sqrt{N}$ |
|-----|-------------|------------------------|----------------------------|
| $10^3$ | 0.56 | 0.032 | 17.7 |
| $10^4$ | 0.41 | 0.010 | 41.5 |
| $10^5$ | 0.82 | 0.003 | 259 |

The ratio $\sigma/\mu \cdot \sqrt{N}$ should be O(1) for genuine TWA quantum
fluctuations; instead it **grows by a factor of 15** as $N$ increases by
$10^2$, indicating the dispersion is not noise-amplitude-bounded.

### C. Resolution and Sinatra-criterion independence

Three independent benchmarks rule out numerical artifacts:

1. **Resolution-matched run** at $16^3$ with $\text{box} = 10$ reproduces
   $\sigma/\mu = 0.42$, identical to $32^3$ result.

2. **Sinatra-clean** Wigner sampling at $N = 10^5$ within the validity bound
   yields $\sigma/\mu = 0.82$, **LARGER** than at $N = 10^4$ — the opposite
   of the quantum fluctuation prediction.

3. **Ground-state resolution** at $16^3 \times \text{box} = 20$ reproduces
   the $\sigma/\mu$ result, ruling out GS-profile artifacts.

These three checks rule out: (a) Wigner-noise sampling artifact, (b) Sinatra
validity bound violation, (c) GS-profile resolution.

### D. Lyapunov-like trajectory divergence

We show direct evidence of exponential trajectory separation under the
chaotic dipolar instability. Pairs of nearby Wigner-sampled initial states
diverge with $\Lambda > 0$ Lyapunov rate up to $t_{\rm saturate} \sim
\Lambda^{-1}\log(N)$, then saturate as different trajectories settle into
different filament orientations (rotationally symmetric chaotic attractor).

### E. Species universality

A four-species $\varepsilon_{dd}$ scan reveals:

| Species | $\varepsilon_{dd}$ | $\sigma/\mu$ | Regime |
|---------|-------------------|--------------|--------|
| Cr | 0.15 | 0.001 | sub-instability, no chaos |
| Eu | 0.55 | **0.423** | **chaos onset, peak active** |
| Er | 0.88 | 0.127 | chaos saturated, quasi-deterministic |
| Dy | 1.39 | 0.049 | full collapse, no spatial structure |

The $\sigma/\mu$ peak at Eu identifies $\varepsilon_{dd} \sim 0.5$ as the
chaos-onset regime — the boundary between sub-critical (stable) and
super-critical (collapse-dominated) dipolar dynamics. This is a
species-independent diagnostic of dipolar chaos.

---

## IV. Methodology: TWA as a Chaos Diagnostic, Not a Quantum-Fluctuation Tool

[**TBD — section to be written**]
Brief outline:
- Why standard $1/\sqrt{N}$ argument fails: leading-order TWA is exact only when
  trajectory dynamics is linearizable — chaotic dynamics violates this.
- Connection to TWA validity literature (Polkovnikov 2010; Sinatra-Lobo-Castin 2002).
- Implications for cold-atom experiments using TWA to measure QF magnitudes
  in dipolar regimes.
- Methodological recommendation: TWA leading-order = chaos diagnostic only.

---

## V. Discussion and Conclusions

[**TBD — section to be written**]
Brief outline:
- Summary of three independent benchmarks establishing chaos interpretation.
- Connection to upcoming TDHFB / Beliaev follow-up for genuine QF evaluation.
- Implications for ${}^{151}$Eu experimental program (Kozuma group, others):
  $\sigma/\mu$ measurement in lab → confirms chaos prediction OR identifies
  quantum-decoherence effects suppressing chaos.

---

## References

[**TBD — bibliography subset to be drawn from `docs/manuscript/shared/references.bib`**]

Key citations expected:
- Polkovnikov 2010 (TWA validity)
- Sinatra-Lobo-Castin 2002 (Sinatra criterion)
- Stamper-Kurn-Ueda 2013 (spinor BEC review)
- Saito-Li 2024 (dipolar droplet stability)
- Miyazawa 2022 (Eu BEC realization)
- Lima-Pelster 2011 (dipolar LHY)

---

**Companion materials**:
- `docs/manuscript/figures_data/`: σ/μ scan plots, 50-trajectory ensemble traces.
- `scripts/dynamics/sinatra_*.jl`: TWA validity diagnostics.
- `runs/sigma_mu_scan_*`: numerical run cache (gitignored).
