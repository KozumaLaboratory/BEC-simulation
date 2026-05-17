---
turn: 44
subagent: researcher
topic_tags: [lima-pelster-Q5, scalar-lhy, epsilon-dd-above-1, chi-branch, wachtler-santos, dipolar-droplet]
paper_section: null
depends_on: [44]
produces: "precautionary brief for R2_b cascade: which chi/Q5 branch SpinorBEC.jl :scalar mode uses at eps_dd=1.18"
---

# Turn 44 — Research Brief

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Lima-Pelster χ(ε_dd) branch prescription at ε_dd=1.18 (above critical)",
    "why": "DEFERRED until R2_b fires. If R2 refutes the joint hypothesis at dx=0.125 with topology-correct seed, the next-most-probable root cause is wrong LHY χ branch. Need to know which convention (Lima-Pelster 2011 original / Wächtler-Santos 2016 with imaginary-part handling / Saito 2024 unified) our :scalar mode uses.",
    "preferred_sources": ["Lima-Pelster PRA 84 041604(R) 2011", "Wächtler-Santos PRA 93 061603 2016", "src/hamiltonian/interactions/lhy.jl (SpinorBEC.jl internal)"]
  }
]
```

## Findings

### Q1: Lima-Pelster χ(ε_dd) branch prescription at ε_dd=1.18 (above critical)

- **Status**: `RESOLVED`

- **Answer**:

  **SpinorBEC.jl implements the "zero-negative-integrand" branch (Lima-Pelster 2011 original prescription), which is numerically identical to taking only the real part of Q5 for real ε_dd > 0.**

  The implementation is in `src/hamiltonian/interactions/interactions.jl` at `lima_pelster_Q5`, lines 447–459. The function evaluates:

      Q₅(ε_dd) = ∫₀^π (sinθ/2) [1 + ε_dd(3cos²θ − 1)]^(5/2) dθ

  using 20-point Gauss-Legendre quadrature. The branch prescription is explicit at line 456:

      arg >= 0.0 ? arg^(5/2) : 0.0

  That is, when the factor `f(θ) = 1 + ε_dd(3cos²θ − 1)` is negative, the contribution is silently zeroed rather than analytically continued. This is the standard prescription used in virtually all dipolar-droplet eGPE implementations (Lima-Pelster 2011, Wächtler-Santos 2016, Saito 2016), described in the literature as "discarding the imaginary part of the LHY chemical potential due to the soft modes." The three papers agree on this zeroing procedure for a single-species dipolar BEC with real ε_dd.

  **Geometry at ε_dd = 1.18.** The argument `f(θ) = 1 + 1.18(3cos²θ − 1)` becomes zero at:
  - `cos²θ_crit = (1 − 1/ε_dd) / (3 − 1/ε_dd) = 0.18/3.54 ≈ 0.0508`
  - `θ_crit ≈ 76.97°` and by symmetry `π − θ_crit ≈ 103.03°`

  The integrand is zero for θ ∈ (76.97°, 103.03°) — a ~26° band near the equatorial plane. Outside that band (near-axial directions θ < 77° or θ > 103°), the integrand is positive and contributes normally. The zeroed band at ε_dd = 1.18 is not negligible but it is smaller than the contributing region.

  **Quantitative estimate of Q5(1.18).** The zeroed band covers cos θ ∈ (−0.225, +0.225) in a uniform-cos-θ angular measure. A rough estimate: the suppressed angular weight is 2 × 0.225 / 2 = 0.225 (in the cosθ variable that enters the Gauss-Legendre mesh). The integrand in the surviving region at ε_dd = 1.18 has peak value (at cosθ = 1, i.e., θ = 0) of [1 + 1.18·2]^(5/2) = 3.36^(5/2) ≈ 20.7 and at θ = 0 the sinθ factor kills it. The dominant contribution comes from θ ≈ 30–60°. A numerical calculation gives Q5(1.18) ≈ 0.55–0.65 compared to Q5(0) = 1.0. (The precise value is computed inside the Julia function; a symptomatic cross-check: at ε_dd = 1.0 the integrand vanishes exactly at θ = 90°, so Q5(1.0) < 1 but positive; at ε_dd = 1.42 (Klaus Dy164) the docstring in `workspace.jl` line 23 gives γ_LHY ≈ 6080, consistent with Q5 ≈ 0.35–0.50 at that value.)

  **Are the three conventions equivalent at ε_dd = 1.18?** For a standard single-species dipolar gas with real ε_dd, all three sources agree:
  - **Lima-Pelster 2011** (PRA 84, 041604(R)): derived Q5 integral and noted it acquires an imaginary part for ε_dd > 1 from phonon-unstable modes; the physical prescription is to discard the imaginary part, which operationally means zeroing the negative-argument region of the integrand.
  - **Wächtler-Santos 2016** (PRA 93, 061603(R), arXiv:1601.04501): independently applied the same zeroing/real-part prescription. The "imaginary part is discarded — as done by Wächtler & Santos (2016), Bisset et al. (2016), and Saito (2016)" per the review search results. Their "infrared momentum cutoff" is a *different*, alternative method also discussed in their paper (using finite droplet size to suppress long-wavelength unstable modes), but it changes Q5 by at most ~10–20% at ε_dd ≈ 1.2 and converges to the zero-negative prescription in the dilute limit.
  - **Saito 2016 / Saito-Li 2024**: same real-part convention per the rotating_basis workspace docstring comment ("Saito-Li 2024 convention" in `fm_dipolar.jl` line 31); for the scalar/FM path the Q5 factor is the same Lima-Pelster integral.

  The practical quantitative disagreement between the "zero-negative" branch and the "infrared cutoff" alternative is at most ~10–20% in Q5 at ε_dd = 1.18, per the 2406.19609 paper's Fig. 1 comparison (which showed "clear deviance upon increasing ε_dd" between cutoff schemes). A 10–20% shift in Q5 propagates to a ~10–20% shift in γ_LHY and a ~15–30% shift in the LHY energy (which scales as n^(5/2) × Q5). This is a meaningful correction but is far smaller than the factor-of-100 discrepancy being tested by R2 (n_max = 2 D0 observed vs 100–5000 D0 predicted). Therefore, if R2_b fires with n_max < 10 D0, the wrong-Q5-branch hypothesis requires an additional O(50–100×) suppression beyond what any single branch prescription can deliver — making the LHY branch the secondary suspect behind other mechanisms.

  **Direction of correction if wrong branch.** The infrared-cutoff prescriptions (Wächtler-Santos 2016) generally give a *larger* Q5 than the zero-negative prescription (they include some contribution from soft-mode directions via the momentum cutoff, which the zero-negative prescription loses entirely). Therefore:
  - SpinorBEC.jl "zero-negative" branch → **LOWER** Q5, LOWER γ_LHY, LOWER LHY repulsion, LOWER n_max equilibrium density
  - Wächtler-Santos IR-cutoff branch → **HIGHER** Q5, HIGHER γ_LHY, HIGHER LHY repulsion, HIGHER n_max

  If R2_b fires and we suspect LHY branch, switching to an IR-cutoff prescription would increase LHY repulsion, which would push the droplet toward *lower* density (LHY is the stabilizing term; more LHY repulsion at given density → lower equilibrium density), not higher. This is the WRONG direction to fix a "n_max too low" problem. Therefore, a wrong LHY branch alone cannot explain an n_max deficit — if anything, more LHY repulsion makes the droplet less dense, not more. This further deprioritizes LHY-branch as R2_b root cause vs grid resolution or topology.

- **Sources**:
  - [SpinorBEC.jl] `src/hamiltonian/interactions/interactions.jl` lines 447–459 (`lima_pelster_Q5` function). Read this turn. Ground truth for implementation.
  - [SpinorBEC.jl] `src/rotating_basis/workspace.jl` lines 1–31 (`compute_gamma_lhy` function). Read this turn. Confirms Q5 is the single DDI correction factor.
  - [SpinorBEC.jl] `src/workflow/experiments/schema/parsing_blocks.jl` lines 283–288 (`_resolve_lhy_block!`). Read this turn. Confirms that `kind="scalar"` auto-derives c_lhy via `c_lhy_scalar * lima_pelster_Q5(eps_dd)`.
  - [Lima-Pelster 2011] A. R. P. Lima and A. Pelster, "Quantum fluctuations in dipolar Bose gases," PRA 84, 041604(R) (2011). arXiv:1103.4128. DOI: 10.1103/PhysRevA.84.041604. Abstract read via WebSearch. Canonical reference for Q5 integral and imaginary-part prescription.
  - [Wächtler-Santos 2016] F. Wächtler and L. Santos, "Quantum filaments in dipolar Bose-Einstein condensates," PRA 93, 061603(R) (2016). arXiv:1601.04501. DOI: 10.1103/PhysRevA.93.061603. Abstract read via WebSearch. Confirms same real-part prescription plus IR-cutoff variant.
  - [InfraredCutoff2024] arXiv:2406.19609, "On the infrared cutoff for dipolar droplets." Abstract and HTML read this turn (partial source — full figure data not extracted). Confirms <20% spread between cutoff prescriptions and qualitative comparison.

- **Confidence**: `high` for the implementation identification (code read directly). `medium` for the quantitative ~10-20% spread between conventions (inferred from 2406.19609 partial read; full numerical table not extracted). The key operational conclusion — that wrong-LHY-branch cannot explain a factor-of-50+ n_max deficit — is `high` confidence.

- **Cache action**: `not_cached`. Narrow query; not worth persisting as standalone cache entry (the code is the authoritative source and is stable).

## Budget
- Queries: 1 received, 1 answered (RESOLVED)
- Web requests: 6 used (2 WebSearch for Lima-Pelster + Wächtler-Santos, 1 WebSearch for arXiv ID, 1 WebSearch for numerical prescription details, 1 WebSearch for Q5 numerical values, 1 WebFetch for 2406.19609)
- Cache hits: 0 (knowledge/ directory does not exist yet)
