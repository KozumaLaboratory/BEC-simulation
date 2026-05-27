# Matsui 2026 Eu-151 EdH — reproduction status

**As of 2026-05-26.** Replaces all prior "Matsui-inspired" YAMLs with
parameter set matching the published paper (Matsui et al., Science
2026, DOI:10.1126/science.adx2872; arXiv:2504.17357), per anko's
2026-05-26 audit.

## Parameter set (Matsui simulation reproduction target)

| Quantity | Matsui paper | YAML |
|---|---|---|
| Atom | ¹⁵¹Eu, F = 6 | `atom: Eu151` |
| N | 5 × 10⁴ | `N_atoms: 50000` |
| Initial spin state | m_F = −6 (fully polarized) | `initial_state: m_minus_F` |
| Trap (ω_x, ω_y, ω_z)/2π | (110, 110, 130) Hz | `omega: [1, 1, 1.1818]` |
| ω_ref | 2π · 110 Hz = 691.15 rad/s | `omega_ref: 691.15` |
| GS magnetic field | B_z = 1 µT = 0.01 G | `B: {Bz: "0.01 Gauss"}` |
| Dynamics field | B_z = 2.6 nT = 2.6×10⁻⁵ G | `B: {Bz: {to: 2.6e-5}}` |
| Short-range model | `c0·n²/2 + c1·\|f\|²/2` | (built in) |
| Constraint | c0 + F²·c1 = 4πℏ²·a₁₂/M | enforced by `interaction_params_from_constraint` |
| Best-fit profile | c1/c0 = 1/36 | `c1_ratio: 0.02778` |
| Channel coverage | only a₁₂ = 110 a_B known | higher c_n = 0 |
| GS DDI | time-averaged | `ddi.secular: true` |
| Dynamics DDI | full MDDI | `ddi.secular: false` |
| LHY | not included | `lhy: {kind: none}` |
| Atomic loss | **not included in simulation** | (no `loss:` block) |
| Hold time targets | 5 ms (Fig 1) / 40 ms (Fig 2) | `duration: 3.456` / `27.65` |

Matsui experiment has ~40% atom loss at 40 ms in weak field; numerical
simulation in the paper omits this. We track these as two separate
reproduction targets:

- **Matsui simulation target** (loss-free): match Fig 1 ring morphology
  + Fig 2C N_m(t) populations.
- **Matsui experiment target** (loss-on): add phenomenological loss
  to also match Fig 2B absolute population decay.

Honest reporting: claims of "experiment reproduction" require the
loss-on variant; claims of "Matsui simulation reproduction" use the
loss-off baseline.

## Reproduction ladder

| Level | Target | Config | Status |
|---|---|---|---|
| 1 | Parameter consistency check | `matsui_baseline/*.yaml` parses + GS converges to m=−6 | (smoke running) |
| 2 | Early-time EdH selection rule | m=−6 decreasing, m=−5 growing first, m=−5 has `(z·e^{-iφ})` ring node | t < 5ms |
| 3 | 5 ms morphology | m=−5 two-ring, m=−4 three-ring structure | `matsui_5ms_morphology_n{32,64}.yaml` |
| 4 | 0–40 ms population dynamics | N_m(t) matches Fig 2C (loss-free) | `matsui_40ms_dynamics_n64.yaml` |
| 5 | Imaging reproduction | TOF + Stern-Gerlach 42 mT/m + column density | not started; needs imaging pipeline |

## Configs generated 2026-05-26

```
runs/matsui_baseline/
├── matsui_5ms_morphology_n32.yaml  ← smoke (~3 min GPU)
├── matsui_5ms_morphology_n64.yaml  ← Level 3 production
└── matsui_40ms_dynamics_n64.yaml   ← Level 4 production
```

Source: `scripts/validation/matsui_baseline_gen.jl`. Launch via
`/tmp/run_matsui_baseline.sh` (sequential GPU chain). All 3 ran
successfully on 2026-05-26 ≈ 12 min wall time.

## Results 2026-05-26 — qualitative reproduction of Matsui Fig 2C

Bz sign fix applied (negative Bz throughout for m=−F lowest energy).
GS converged to m=−F polarized (Mz = −6.0, all populations in m=−6 at
GS). 32³ and 64³ 5ms cells agree to < 1% across all observables —
grid converged at early time.

**5 ms morphology (Matsui Fig 1 target), 64³:**
- Initial: m=−6 100% (post-GS)
- t=0.36 ms (first save): m=−6 92%, m=−5 7.4%, m=−4 0.6% (early EdH)
- t=1.09 ms: m=−6 78%, m=−5 17%, m=−4 4% (m=−5 first transfer
  channel — Matsui MDDI prediction)
- t=2.89 ms: m=−6 77%, m=−5 17%, m=−4 5% (some oscillation)
- t=3.98 ms: m=−6 54%, m=−5 24%, m=−4 15%, m=−3 5% (broader spread)
- Peak ratio = 1.00 at 5 ms (no density growth, only spin transfer
  — consistent with Matsui Fig 1 showing morphology not collapse)
- N(T)/N(0) = 0.99997 ≈ 1.000 (loss-free conservation OK)

**40 ms population dynamics (Matsui Fig 2C target), 64³:**
```
t [ms]   m=−6   m=−5   m=−4   m=−3   m=−2   m=−1   m=0
 1.45    79%    16%    4%     0.8%   0.2%
 2.89    77%    17%    5%     1.2%   0.2%
 4.34    44%    26%    20%    7%     2%
10.13    43%    22%    16%    7%     6%     2%     2%
20.26    50%    19%    9%     4%     3%     4%     7%
30.38    66%    11%    5%     3%     3%     2%     1%
39.07    63%    11%    7%     4%     4%     1%     0.6%
```

**Signatures matching Matsui Fig 2C:**

1. **m=−6 → m=−5 first transfer** dominates the first 2-3 ms.
2. **m=−4 builds up** by t ≈ 4 ms (Matsui's "(−5)→(−4) cascade").
3. **m=0 reaches a few percent** by t = 20 ms — coherent spread
   reaches the equator.
4. **Partial recovery** of m=−6 at long time (30-40 ms) — coherent
   oscillation in a finite trap, NOT thermalisation. Matsui's Fig 2C
   shows similar non-monotonic behavior.
5. **N conserved to 0.99992** (Matsui simulation is loss-free; we
   match this assumption exactly).
6. **Peak ratio = 2.10 at 40 ms** — peak density doubles. At this trap
   + N + c1 combination, peak grows but stays bounded (no collapse;
   total N conserved).

**Cross-grid robustness:** 32³ and 64³ at 5 ms give:
- Fz/N : −4.8432 vs −4.8371 (0.13% difference)
- m=−6 population at t=3.98 ms: 0.5354 vs 0.5398 (0.8% difference)
- Peak density: 5.957e-3 vs 6.112e-3 (2.6% — small grid sensitivity
  expected from spatial resolution alone)

Matsui dynamics is grid-converged at 32³ for early-time spin transfer.

**Caveats (do NOT hide in production claim):**

- **No quantitative comparison to Matsui Fig 2C yet.** The
  qualitative shape (m=−5 dominant first, m=−4 follows, m=0 appears
  late, partial recovery) matches. Exact population fractions at
  specific times need Matsui Fig 2C digitised data to compare.
- **40 ms cell peak ratio = 2.10** — peak doubles, but no collapse
  (N conserved). This is the "natural EdH transient" of Matsui's
  setup. NOT the cigar regime; this is near-spherical at experimental
  parameters.
- **5 ms cell peak ratio = 1.00** — at the morphology timescale,
  density is essentially static. The dynamics at 5 ms is purely
  spin-component reorganisation.
- **Loss-on variant** (experiment reproduction, ~40% atom loss at
  40 ms) is the *next* step; not in this run set.

## Caveats on LHY model dependency (Task #19C extended, applies here too)

**Important honesty note (anko, 2026-05-26, updated after 2×4 factorial):**

`polar_contact` and `icosahedral` LHY models are *effective* LHY EoS
constructions that assume a specific local order parameter (polar
phase, I_h-symmetric F=6 state respectively). They are NOT
automatically the correct LHY for an arbitrary non-equilibrium spin
texture.

The 2×4 K3 × LHY factorial confirms:

- **scalar LHY at F=6 is insufficient** (≡ no LHY).
- **polar_contact / icosahedral LHY alone (K3=0)** give lossless
  stable_arrest. The arrest mechanism is LHY-driven, NOT K3-driven.
- K3=200×proxy on top of proper LHY adds atom loss without changing
  the arrest character.

But the proper-LHY result is still an *upper bound on the LHY
contribution*: if the local spin texture were actually polar / I_h
symmetric, LHY pressure would be as computed. For a general
(rotating, EdH-transferred, partially collapsed) state, the true
spinor LHY is unknown — neither scalar n^{5/2} nor the polar / I_h
approximations is automatically correct.

The right interpretation:
> **F=6 high-spin dipolar collapse-arrest prediction is strongly
> model-dependent at the LHY level. The question "does K3 arrest
> collapse?" is ill-posed without first specifying the LHY closure.**

Matsui's simulation explicitly omits LHY altogether. Our L4 isotropic
result (< 1% LHY perturbation) is consistent with that choice for
the experimental regime; the LHY model question only matters in the
collapse-prone cigar stress regime, where the experiment doesn't live.

## Earlier YAMLs that did NOT match Matsui (now superseded)

- `runs/eu_robust_factorial/*.yaml` (N=30k, c1_ratio=−0.005, isotropic)
  — these are valid as L4-isotropic robustness factorial but should
  not be claimed as Matsui reproduction. The c1_ratio sign flip alone
  is decisive.
- `runs/l4_k3_ladder/*.yaml` (N=30k, c1_ratio=−0.005, isotropic)
  — same. These are the validation Level 9 cross-grid result; not
  Matsui reproduction.
- `runs/eu_k3_*` (cigar N=30k geometry) — these are *stress test*
  configurations, not experimental conditions. Cigar is the geometry
  where collapse can be induced; Matsui experiment uses near-spherical.

## What the cigar + K3 sweep is NOT

The K3 arrest threshold (~200×) and the LHY-K3 antagonism found at
cigar N=30k regime are **stress-test results**, not Matsui experiment
explanations. They live under "appendix: code stress test" in the
self-contained validation chain, not under "explains Eu experiment".

The right framing for the K3 sweep:

> When the simulator is pushed into a collapse-dominated regime by
> non-experimental parameters (cigar geometry), the model's response
> to K3 / LHY axes is sub-critical (delay/sacrificial arrest) at
> literature K3 ≤ 100× — and LHY is antagonistic to K3 regardless of
> LHY model. This characterises the *simulator* in the high-density
> limit, not the Eu experiment.

The right framing for L4 isotropic (Matsui-protocol-adjacent):

> The L4 isotropic protocol (N=30k, ω=(1,1,1), c1_ratio=−0.005,
> t=10 ms) is robustly no-collapse at 64/96/128 — K3 / γ_dr / LHY
> contribute small (≪ 1%) corrections to peak density and EdH transfer.
> The full Matsui parameter set (N=50k, near-spherical, c1/c0=+1/36,
> loss-off) is now under reproduction via `matsui_baseline/`.

## References

- Matsui et al. 2026, Science, DOI:10.1126/science.adx2872
- arXiv:2504.17357
- `scripts/validation/matsui_baseline_gen.jl` — generator
- `src/hamiltonian/interactions/interactions.jl:265-272` —
  `interaction_params_from_constraint(c_total, c1_ratio, F=6)`
  enforces `c0 + 36·c1 = c_total`, matching Matsui's constraint.
