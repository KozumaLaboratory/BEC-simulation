# Cover Letter — Paper #4 (Chaotic dipolar instability via TWA)

> **FROZEN 2026-05-12.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Target journal**: Physical Review Research (PRR) or Physical Review A (PRA)

**Title**: Chaotic dipolar instability in post-quench F=6 spinor Bose-Einstein condensate: trajectory divergence and species universality

---

To the Editors,

We submit the manuscript "Chaotic dipolar instability in post-quench F=6
spinor Bose-Einstein condensate: trajectory divergence and species
universality" for consideration in Physical Review Research (or PRA at
editorial preference).

### Significance

The Truncated Wigner Approximation (TWA) has become a standard tool for
ensemble-averaged dynamics in cold-atom systems, with its leading-order
prediction $\sigma/\mu \propto 1/\sqrt{N}$ widely used as a quantitative
estimator of "quantum fluctuation strength." We demonstrate that this
interpretation **fails dramatically** for post-quench F=6 dipolar
Bose-Einstein condensates ($\varepsilon_{dd} \gtrsim 0.4$), where the
observed $\sigma/\mu$ scales factor 200+ above the $1/\sqrt{N}$ prediction
at $N = 10^5$. We trace the breakdown to **chaotic dipolar instability**
that amplifies Wigner-sampling seeds exponentially via positive Lyapunov
exponent, producing trajectory-to-trajectory filament-orientation divergence
rather than noise-amplitude-bounded spread.

This reframing has two implications: (a) it methodologically establishes
leading-order TWA as a **chaos diagnostic tool**, not a quantum-fluctuation
tool, in dipolar regimes — a clean delineation that the community needs;
(b) it identifies a specific, falsifiable, species-universal experimental
prediction (the $\sigma/\mu$ peak at $\varepsilon_{dd} \approx 0.5$ = the
chaos-onset regime) that the ${}^{151}$Eu BEC experimental program is
positioned to test.

### Key results

1. **Three independent breakdown benchmarks**: Resolution-matched runs at
   $16^3$ and $32^3$ produce identical $\sigma/\mu$, ruling out
   discretization artifacts. Sinatra-clean ensemble at $N = 10^5$ gives
   $\sigma/\mu = 0.82$, **larger** than at $N = 10^4$ (opposite of $1/\sqrt{N}$).
   $\sigma/\mu \cdot \sqrt{N}$ grows by a factor of 15 as $N$ increases by
   $10^2$.

2. **Lyapunov-like trajectory divergence**: Pairs of nearby Wigner samples
   diverge exponentially with positive Lyapunov rate $\Lambda$ up to
   $t_{\rm sat} \sim \Lambda^{-1} \log\sqrt{N}$, then saturate at amplitude-
   bounded values as trajectories settle into distinct filament-orientation
   attractors.

3. **Species universality (chaos-onset diagnostic)**:

   | Species | $\varepsilon_{dd}$ | $\sigma/\mu$ |
   |---------|-------------------|--------------|
   | Cr | 0.15 | 0.001 |
   | **Eu** | **0.55** | **0.423** |
   | Er | 0.88 | 0.127 |
   | Dy | 1.39 | 0.049 |

   The $\sigma/\mu$ peak at Eu identifies $\varepsilon_{dd} \approx 0.5$ as
   the chaos-onset regime — a species-independent diagnostic prediction.

4. **Methodological reframing**: Leading-order TWA in dipolar regimes
   measures chaos, not quantum fluctuations. Genuine quantum-fluctuation
   magnitude extraction requires TDHFB / Beliaev (deferred to follow-up).

### Connection to existing literature

This work intersects:
- TWA methodology: Polkovnikov 2010 (1/N expansion validity); Sinatra-
  Castin-Lobo 2002 (validity bound); Lemeshko 2018 (pedagogical primer).
- Spinor dipolar dynamics: Kawaguchi-Ueda 2012 review; Stamper-Kurn-Ueda
  2013 review; Miyazawa 2022 ${}^{151}$Eu BEC realization.
- Dipolar droplet physics: Saito-Li 2024; Lima-Pelster 2011-2012 scalar LHY
  with DDI.

We provide a clean experimental-parameter realization of the Polkovnikov
2010 caveat (TWA truncation breakdown for chaotic dynamics), elevating it
from a theoretical footnote to a quantitative methodological recommendation
for the cold-atom community working in dipolar regimes.

### What this paper does NOT claim

We do **not** invalidate prior leading-order TWA results for non-dipolar /
weakly-dipolar regimes. The deterministic GP-LHY mean-field predictions for
post-quench dipolar dynamics (filament patterns, density depletion, species
universality at the mean-field level) are robust and quantitatively correct;
we are reframing the **interpretation of the ensemble spread**, not the
deterministic dynamics itself.

### Suitable referees

- A. Polkovnikov (Boston) — TWA validity theory
- Y. Castin (LKB) — particle-conserving Bogoliubov, Sinatra criterion
- T. Macrì, F. Cinti — dipolar BEC droplets
- T. Kozuma (Tokyo Tech) — ${}^{151}$Eu experimental program
- L. Tarruell, J. Beugnon — dipolar BEC experiments

### Companion submissions

Papers #1 (F=2 cyclic LHY), #2 (F=6 icosahedral LHY), and #3 (Universal
Structure Theorem) address the equilibrium / mean-field side of F=6 spinor
BECs and are submitted in parallel. Paper #4 (this submission) addresses
the post-quench dynamics side and the methodological question of what
leading-order TWA actually measures.

### Suitable handling

We propose Physical Review Research as the primary target, given the
methodological-reframing scope and broad cold-atom community relevance. PRA
is an acceptable alternative.

Thank you for your consideration.

Sincerely,
[Author]
[Affiliation]
[Date]
