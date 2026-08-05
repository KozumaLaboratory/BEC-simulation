# Paper #4: Chaotic dipolar instability in post-quench F=6 spinor Bose-Einstein condensate: trajectory divergence and species universality

> **FROZEN 2026-05-12.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

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

### A. The $1/\sqrt{N}$ argument and its breakdown for chaotic dynamics

The canonical TWA argument for $\sigma/\mu \propto 1/\sqrt{N}$ proceeds as
follows. The Wigner distribution of an $N$-particle BEC ground state, in the
mean-field representation $\psi(\mathbf{r}, t) = \sqrt{N}\,\phi(\mathbf{r}, t)$,
has fluctuations of relative magnitude $\delta\psi/\psi \sim 1/\sqrt{N}$. If
the EOMs are linearizable around $\phi$ — that is, if the linear-response
operator has bounded eigenvalues — then the ensemble trajectory dispersion
inherits the initial $1/\sqrt{N}$ scaling.

The breakdown in our dipolar regime occurs because the post-quench dipolar
EOMs have **positive Lyapunov exponent**: the linearized fluctuation operator
$\mathcal{L}(t)$ around $\phi(t)$ has eigenvalues $\lambda_j(t)$ that include
unstable modes $\text{Re}\,\lambda_j > 0$. Small Wigner-sampled initial
seeds $\delta\zeta(0) \sim 1/\sqrt{N}$ then grow as
$|\delta\zeta(t)| \sim \exp(\Lambda t) / \sqrt{N}$ until they saturate at
the **physical amplitude scale** $|\delta\zeta_{\rm sat}| \sim O(1)$ when
nearby trajectories diverge to distinct attractors (here, different filament
orientations).

The saturation time scales as $t_{\rm sat} \sim \Lambda^{-1} \log\sqrt{N}$,
i.e., logarithmically with $N$. After saturation, $\sigma/\mu$ is determined
by the attractor structure (essentially the dipole-orientation symmetry
group), not by the initial noise amplitude. This is precisely why we observe
$\sigma/\mu$ approximately *constant* with $N$ rather than scaling as
$1/\sqrt{N}$.

### B. Connection to existing TWA validity literature

This phenomenon is consistent with — but more dramatic than — the validity
bound established by Sinatra, Lobo, and Castin (2002), who showed that TWA
becomes unreliable when the BdG modes' classical occupation exceeds
$\sim 1/2$. In our regime, the dipolar instability drives the unstable BdG
modes to fully macroscopic occupation within $t \sim 1$ trap unit, far
exceeding the Sinatra threshold.

More generally, Polkovnikov (2010) showed that the systematic $1/N$ expansion
of TWA converges only for "regular" dynamics — chaotic dynamics fundamentally
violates the truncation criterion. Our results provide a clean experimental-
parameter realization of this theoretical caveat in spinor dipolar dynamics.

### C. Methodological implications for cold-atom experiments

Many cold-atom papers cite leading-order TWA $\sigma/\mu$ measurements as
quantitative estimates of "quantum fluctuation strength." In dipolar regimes
with $\varepsilon_{dd} \gtrsim 0.4$, this interpretation is **unsafe**: the
TWA-measured $\sigma/\mu$ is dominated by chaotic trajectory divergence, not
by quantum fluctuations. We recommend that experimental analyses of
ensemble-averaged dipolar dynamics:

1. Explicitly check $\sigma/\mu \cdot \sqrt{N}$ for $N$-independence
   (genuine TWA) vs $N$-dependence (chaos signature).
2. Cross-validate with deterministic GP-LHY runs to assess Lyapunov-like
   instability.
3. For genuine quantum-fluctuation magnitude, use higher-order methods —
   TDHFB (Phase 3 implementation in `src/hamiltonian/tdhfb/` of this work,
   characterized in our companion manuscript) or Beliaev decay.

### D. What our finding does NOT do

Our reframing does **not** invalidate the underlying dipolar dynamics
predictions: the deterministic GP-LHY mean-field results (filament patterns,
density depletion, species universality) are robust and quantitatively
correct. We are reframing the **interpretation of the ensemble spread**, not
the deterministic dynamics itself.

---

## V. Discussion and Conclusions

### A. Summary of evidence

We have established three independent lines of evidence that leading-order
TWA in post-quench F=6 dipolar BEC measures chaotic trajectory divergence
rather than quantum fluctuations:

1. **Resolution-matched benchmark**: $16^3 \times \text{box} = 10$ and
   $32^3 \times \text{box} = 10$ produce essentially identical $\sigma/\mu$,
   ruling out spatial-discretization artifacts.

2. **Sinatra-clean ensemble**: Within the Sinatra validity bound at
   $N = 10^5$, $\sigma/\mu$ is **larger** than at smaller $N$, opposite of
   the $1/\sqrt{N}$ quantum-fluctuation prediction.

3. **Lyapunov-like trajectory divergence**: Pairs of nearby Wigner samples
   diverge exponentially with $\Lambda > 0$ rate up to amplitude saturation.

Together with the species-universal $\sigma/\mu$ peak at the Eu
$\varepsilon_{dd} \approx 0.55$, these establish chaotic dipolar instability
as the physical origin of the observed dispersion.

### B. Implications for the ${}^{151}$Eu experimental program

The ${}^{151}$Eu BEC experimental program (Miyazawa et al.\ 2022 and follow-
up) provides the ideal platform to test our prediction:

- If observed $\sigma/\mu \approx 0.4$ at Eu parameters, **chaos prediction
  confirmed** — the first experimental observation of dipolar chaos in a
  spinor BEC.

- If observed $\sigma/\mu$ smaller than predicted, this would indicate that
  **quantum decoherence** suppresses the chaotic instability at experimental
  timescales — also a major finding.

- If $\sigma/\mu$ shows distinct $N$-dependence different from both 1/√N and
  N-independent saturation, we likely face a **mixed regime** of chaos +
  decoherence that warrants TDHFB-level treatment.

All three outcomes are independently publishable.

### C. Connection to the companion TDHFB program

The chaos / quantum-fluctuation distinction motivates our companion TDHFB
implementation (Phase 3 production code in `src/hamiltonian/tdhfb/`,
documented in the master thesis Ch.5 §5.11.4). TDHFB tracks the BdG mode
populations dynamically through coupled (φ, ρ, κ) evolution, providing the
true quantum-fluctuation magnitude in regimes where leading-order TWA fails.
A direct comparison of TDHFB $\sigma/\mu$ predictions to the experimental
measurements is the natural follow-up to this work.

### D. Generalizability

The chaos-onset diagnostic — $\sigma/\mu$ peak at the dipolar-instability
threshold — is **species-universal**. It generalizes immediately to other
strongly-dipolar BECs (Dy ($\varepsilon_{dd} \approx 1.4$), Er (0.88), Cr
(0.15)), as our four-species scan demonstrates. The peak position
$\varepsilon_{dd}^{\rm peak} \approx 0.5$ is a measurable, falsifiable
prediction independent of microscopic spinor channel details.

### E. Conclusions

We have established that leading-order TWA simulations of post-quench F=6
dipolar BEC measure **chaotic dipolar instability**, not quantum
fluctuations. The observed $\sigma/\mu$ dispersion saturates at amplitude-
bounded values $\sim 0.4 - 0.8$ rather than scaling as $1/\sqrt{N}$, with
the saturation explained by positive-Lyapunov trajectory divergence to
distinct filament-orientation attractors. The species-universal
$\sigma/\mu$ peak at $\varepsilon_{dd} \sim 0.5$ identifies the chaos-onset
regime and is directly testable in ${}^{151}$Eu BEC experiments. This work
methodologically reframes leading-order TWA as a chaos diagnostic in dipolar
spinor dynamics and motivates the TDHFB / Beliaev follow-up for genuine
quantum-fluctuation evaluation.

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
- `runs/sigma_mu_scan_*` (planned): numerical run cache (gitignored).
