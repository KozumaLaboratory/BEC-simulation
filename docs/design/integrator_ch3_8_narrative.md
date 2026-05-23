# §3.8 Comparison & recommendations — narrative draft

**Status**: draft, 2026-05-11. Final section of Ch.3 closure.

## §3.8.1 Method hierarchy summary

Five integrator families investigated for the lab-path SpinorBEC
V step:

| family | order | cost / V step | energy drift |
|--------|-------|---------------|--------------|
| Strang (plain) | 2 | 1× | O(τ²) per step |
| Strang-midpoint (Track A1) | 2 | ~2× | O(τ²) per step |
| **Yoshida-4 midpoint** (Track A1) | **4** | **~12×** | **machine precision** |
| Yoshida-6 midpoint (Track A1) | 6 (ref-floor limited) | ~24× | machine precision |
| Force-Gradient v3 (Track C) | 3-4 | ~11× | order-3 limited |
| MPS-4 (Track A) | 1 (collapse) | 3× | — |
| AVF state-avg (Track A1.5) | 2 (collapse) | 4× | 14万× worse than Y4 |

(Phase 2a benchmark: Rb87 F=1, 16³, c0+c1+c_dd; verification:
`scripts/bench/midpoint_order_phase2a.jl`. Phase 5 long-time: Rb87 F=1,
1D, T=20 ω⁻¹; `scripts/bench/forcegrad_phase5.jl`.)

## §3.8.2 Practical optimum: Yoshida-4 midpoint

**Recommendation**: Yoshida-4 with midpoint predictor-corrector V step
(Track A1) is the practical optimum for the SpinorBEC lab path.

Justification:
1. **Order 4** verified on Rb87 F=1 lab path (Phase 2a o12 = 4.46 at
   coarse end; o23 hits reference precision floor) and on Eu151 F=6
   (Phase 2b) — full physical Hamiltonian including c₀ + c₁ + c_dd.
2. **Machine-precision energy drift** verified over T = 20 ω⁻¹
   (Phase 5): ΔE/|E₀| = 2.78e-10 at 4000 steps. Long-time integration
   does not require switching to specialised energy-preserving schemes
   (e.g., true Quispel-McLaren AVF).
3. **Cost competitive** with the alternatives: ~12× plain Strang per
   outer step, comparable to Force-Gradient v3 (11×). For order-2
   schemes the cost ratio is ~2×.
4. **Numerically robust**: Picard fixed-point on midpoint MF converges
   in 2 iterations to machine precision on the lab path. No special
   handling for c1, DDI, tensor, etc. (all included automatically).

## §3.8.3 Decision tree by use case

### Real-time vortex dynamics (T_FINAL ~ 100-1000 ω⁻¹)

**Use Y4-midpoint.** Order 4 + machine-precision energy drift gives
clean trajectories. Force-Gradient offers no measurable benefit on
the lab path.

### Imaginary time propagation (ground state computation)

**Use Y4-midpoint** for the V step, with adaptive PI controller for
time stepping. Force-Gradient would be needed if the
all-positive-coefficients property were essential (= ITP convergence
in some special regimes). For our Eu151 Flower phase, anko's
`itp_profile.jl` will determine integrator-limited vs
landscape-limited classification. If landscape-limited:
high-order doesn't help, use Strang. If integrator-limited:
Y4-midpoint provides the wall-clock speedup.

### Spinor + DDI realistic Eu151 (c₁ ≠ 0, c_dd ≠ 0)

**Y4-midpoint** handles the full Hamiltonian via the existing
substep kernels (spin_mixing, DDI, etc.). All accept `psi_mf` for
midpoint MF evaluation per Track A1's plumbing.

Force-Gradient v3 (`split_step_forcegrad!`) is currently **diagonal-only**
scope (panics on c₁ ≠ 0 or DDI on). Extension to F-matrix + DDI is
Track C v4/v5 derivation completed (`docs/design/integrator_track_c_derivation.md`
§5.2-5.3) but implementation deferred — Y4-midpoint already wins on
the lab path so the ROI is low.

### Multi-species BEC (two-component, J=2)

**Not supported by SpinorBEC** as currently structured (single-species
F-matrix spinor). Out of scope.

### Long-time energy conservation critical (T_FINAL >> 1000 ω⁻¹)

**Y4-midpoint suffices** based on Phase 5 evidence
(2.78e-10 at T=20 ω⁻¹). Extrapolation: drift scales linearly with
T, giving ~1e-8 at T=10⁴, still below any experimental observable
(Faraday signal floor ~1e-5). For T > 10⁶ ω⁻¹ or extreme precision
requirements, true Quispel-McLaren AVF (gradient-averaged, not
state-averaged) would be the next step but is not motivated by
current production needs.

## §3.8.4 Methods to AVOID

Three methods documented as **negative results** to NOT use:

### MPS-4 / MPS-6 (Richardson 1-step on Strang)

Track A. Collapses to order ~1 on lab path due to multi-scale MF
mismatch between S(h) and S(h/2)². Even with Track A1 midpoint
plumbing, structural failure persists. Use Yoshida composition
instead.

### AVF state-averaging `(ψⁿ + ψⁿ⁺¹)/2`

Track A1.5. cos(Hτ/2) even-power bias breaks Yoshida-4 order
recovery → order 2 + 14万× worse drift. Generic anti-pattern (§3.7),
applies to any state-avg-based midpoint estimation.

### Force-Gradient with state-avg midpoint Picard refinement

Track C v3 attempt 1. Reproduces AVF failure mode inside FG framework
→ order 2.92 → 2.00 with one Picard iteration. Same cos(Hτ/2) bias.
Use the v3.1 implementation (`split_step_forcegrad!` n_picard ≥ 1)
which iterates on ENDPOINT only, not state-avg midpoint.

## §3.8.5 Track A1 + C + B comparison summary

Track A1 (midpoint composition): **practical winner**.
- Yoshida-4 midpoint = order 4, machine-precision drift
- Yoshida-6 midpoint = order 6 (ref-floor limited), machine-precision drift
- Pre-existing midpoint Picard machinery handles c1, DDI, spin-mixing
  automatically via `psi_mf` kwarg through the substep kernels.

Track C (Force-Gradient + spinor extension): **derivation-level
contribution**.
- v1-v3.1 implementation diagonal-only, order 3-4
- Phase -1 + v4/v5 derivations cover the spinor matrix + DDI extension
  algebraically (novel ∇ψ derivative term)
- Phase 5 loses to Y4-mid by 400-700× in energy drift
- Practical recommendation: don't implement F-matrix extension unless
  a specific motivation arises

## §3.8.6 Negative results catalogue (Ch.3 §3.7 + scattered)

The thesis contribution includes a deliberate catalogue of negative
results — each tested empirically AND explained formally:

1. **MPS multi-scale failure** (§3.3.1, Track A): Richardson
   coefficients fail when midpoint MF differs between S(h) and S(h/2)²
2. **AVF state-averaging** (§3.3.2 / §3.7.4.b, Track A1.5): cos(Hτ/2)
   bias breaks Yoshida composition
3. **Force-Gradient state-avg Picard** (§3.7.4.c, Track C v3): same
   bias reproduced inside the FG framework
4. **Force-Gradient ROI on lab path** (§3.5.7, Track C): order 3 +
   400× drift vs Y4-mid → practical recommendation is Y4-mid

These negatives form a coherent "what doesn't work and why" structure
that complements the positive Y4-midpoint recommendation.

## §3.8.7 Future work (post-修論)

1. **F-matrix + DDI Force-Gradient implementation** (Track C v4/v5):
   derivation complete, implementation = 1-2 weeks of Phase 0 work.
   Motivated only if production use case shows Y4-mid drift
   competing with experimental signal floor.

2. **True Quispel-McLaren AVF (gradient-averaged, not state-averaged)**:
   exact energy preservation on quartic H. Not pursued because
   Y4-mid already achieves machine precision drift; ROI assessment
   negative.

3. **Multi-species BEC extension** (J=2+): requires new SpinorBEC
   framework infrastructure for cross-channel coupling. Outside
   current Eu151 single-species scope.

4. **Adaptive PI controller** for Y4-mid: existing L2-PI controller
   covers production scope. Embedded local error estimators (e.g.,
   compare Y4 with Strang each step) could replace it for cleaner
   adaptive behaviour but the gain is small.

5. **Higher-order force-gradient (6th-order modified splitting)**:
   per Chin 2005 PRE 71, 016703 (cited in Chin-Krotscheck 2005
   paper §VI), 6th-order forward symplectic algorithms exist with
   ADDITIONAL commutator requirements not implementable in our
   framework. Track A1 Y6-midpoint already reaches order 6 via
   Yoshida composition + midpoint Picard, so the force-gradient
   higher-order path is dominated.

## §3.8.8 §3.8 + Ch.3 closure

Yoshida-4 midpoint (Track A1) is the practical optimum for the
SpinorBEC lab path. Order 4 + machine-precision energy drift, with
cost comparable to alternatives. Force-Gradient (Track C) provides
a derivation-level contribution (spinor matrix + DDI extension) but
loses cost-per-accuracy to Y4-mid on the lab path.

The thesis Ch.3 chapter delivers: (a) Y4-mid as the empirically
verified practical optimum, (b) Track C derivation of the spinor
matrix ∇ψ derivative term (novel), and (c) a catalogue of negative
results that justify the design choices via formal failure analysis.

Ch.3 = ~60-80 pages combining §3.1-§3.4 (positive theorem + Track A1
implementation), §3.5 (Track C derivation),
§3.7 (state-averaging negative theorem), §3.8 (this section,
comparison + recommendations). Thesis-body chapter alongside Universal
Structure Theorem, EdH, and Flower phase chapters.
