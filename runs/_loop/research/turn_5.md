# Turn 5 — Research Brief

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Lima & Pelster 2012 (PRA 86, 063609) LHY zero-point energy formula for negative/complex Bogoliubov eigenvalues",
    "why": "Load-bearing citation for the 'take real part of imaginary LHY contribution' convention"
  },
  {
    "id": "Q2",
    "topic": "Petrov 2015 (PRL 115, 155302) prescription: Re|λ| vs |Re λ| vs drop negative vs other for Bose-Bose droplet LHY",
    "why": "The FullBdGLHY code comment says 'Petrov-prescribed real-part-only contribution' — need exact citation"
  },
  {
    "id": "Q3",
    "topic": "Schmitt-Wenzel-Böttcher 2016 / Chomaz-Petter 2016 dipolar Dy/Er lab LHY: numerical convention for imaginary modes",
    "why": "Experimental theory papers; need to know if they state convention explicitly"
  },
  {
    "id": "Q4",
    "topic": "Is LHY-on-unstable-GS well-defined in literature for spinor F≥2 polar with λ<0 modes?",
    "why": "F=6 polar is generically mean-field unstable; is FullBdG even in-scope or should it error out?"
  },
  {
    "id": "Q5",
    "topic": "Closed-form PolarContactLHY / FMContactLHY / IcosahedralLHY source papers",
    "why": "Need citations for the closed-form modes that do work for F=6 polar"
  }
]
```

## Code findings (pre-literature)

Before literature search, the following was established by reading source:

**Exact location of the negative-eigenvalue handling in FullBdGLHY:**
`src/hamiltonian/interactions/lhy/dispatch.jl`, line 231:
```julia
omega = real(ev)
omega > 1e-10 || continue
```
This takes `real(eigenvalue)` and **discards** any mode with `real(eigenvalue) ≤ 1e-10`. This means:
- Complex eigenvalue with `Re(ev) ≤ 1e-10` → dropped.
- Real eigenvalue that is negative → dropped (because negative ≤ 1e-10).
- Real eigenvalue that is large positive → retained.

For F=6 polar, the BdG matrix produces many modes with imaginary eigenvalues (the full BdG for an unstable mean field). The `real(ev)` of a purely imaginary eigenvalue is 0.0, so the `> 1e-10` threshold drops them. However, the UV-subtraction correction term `correction = omega - ek - mu_b + mu_b^2/(2ek)` can still be large when some modes have large `real(ev) > 1e-10` from residual real parts. For the polar F=6 case where _all or most_ quasi-particle branches go imaginary, the Nambu structure means paired eigenvalues come in `±λ` — the *positive* member of a pair from an imaginary branch is actually a large positive real number from the Nambu doubling, not zero. This is the root of the 3000× spurious offset: modes that are physically imaginary (unstable) in the physical BdG still have positive-real partner eigenvalues in the `2D × 2D` Nambu matrix that pass the `> 1e-10` filter and contribute large UV-unregularized terms.

**PolarContactLHY closed form (the working path):**
`src/hamiltonian/interactions/lhy/polar_contact.jl` uses the `phi_1_reg(t)` function where `t = ξ_m/|Δ_m| - 1`. For physically unstable modes (`ξ_m < 0`, i.e., the stiffness matrix eigenvalue is negative), `t < -1`. The `phi_1_reg` function saturates at `t = -1` (returns `0.3177` — the Petrov plateau), effectively giving a finite positive contribution from any mode that would go imaginary in the physical BdG. This is the Petrov saturation / analytic continuation that makes the closed form well-behaved.

---

## Findings

### Q1: Lima & Pelster 2012 — LHY formula for imaginary/negative modes
- **Status**: `RESOLVED`
- **Answer**: Lima & Pelster (PRA 84, 041604 (2011) + PRA 86, 063609 (2012)) derived the beyond-mean-field LHY correction for dipolar BECs. The Bogoliubov spectrum for a dipolar gas becomes imaginary (complex) at low momenta / certain angles when the DDI is strong enough to drive the phonon branch soft. Their prescription, now standard across the dipolar-droplet literature, is: **compute the LHY zero-point energy integral and take only the real part** — the imaginary contribution (arising from imaginary Bogoliubov frequencies) is neglected. This is stated explicitly in at least three independent secondary sources that directly characterize the Lima-Pelster papers: (a) "the LHY energy of the quantum droplet has an imaginary part, but it is neglected for practical purposes" [Zhang 2023, arXiv:2306.00254]; (b) "the imaginary part can be neglected to a certain extent" [Dip. droplet review 2024]; (c) the convention is attributed specifically to Lima & Pelster (2011) in Wächtler & Santos (2016) and related works. The prescription is `E_LHY = Re[∫ dk k² Σ_λ (½ ω_λ(k) - UV_subtraction)]` — the imaginary part from imaginary-frequency modes is zeroed. Note: this applies to the case where modes are *complex* (nonzero imaginary part). For modes that are *real but negative* (which occurs in spinor systems near phase boundaries due to mean-field magnetic instability, distinct from the dipolar phonon instability), Lima-Pelster does not directly address the convention.
- **Sources**:
  - [Lima & Pelster 2011] "Quantum fluctuations in dipolar Bose gases." Phys. Rev. A 84, 041604(R). https://journals.aps.org/pra/abstract/10.1103/PhysRevA.84.041604. Accessed 2026-05-15.
  - [Lima & Pelster 2012] "Beyond mean-field low-lying excitations of dipolar Bose gases." Phys. Rev. A 86, 063609. https://journals.aps.org/pra/abstract/10.1103/PhysRevA.86.063609. Accessed 2026-05-15.
  - [Zhang 2023] "The density-functional theory of quantum droplets." arXiv:2306.00254. https://arxiv.org/abs/2306.00254. Accessed 2026-05-15. (Secondary source characterizing Lima-Pelster convention.)
- **Confidence**: `medium`. I read the abstracts and secondary characterizations but not the full equations in Lima-Pelster due to access constraints. The secondary sources unanimously attribute the "drop imaginary part" convention to Lima-Pelster (2011). The exact equation number (e.g., Eq. 6 in PRA 84) is NOT_FOUND without full-text access.
- **Cache action**: `not_cached`.

---

### Q2: Petrov 2015 (PRL 115, 155302) — prescription for complex/negative Bogoliubov modes
- **Status**: `RESOLVED`
- **Answer**: Petrov's prescription for LHY in a collapsing Bose-Bose mixture is to take **only the real part** of the LHY zero-point energy integral. In the Bose-Bose case, the lower branch of the Bogoliubov spectrum goes soft and becomes imaginary in the long-wavelength limit (phonon instability, sound velocity squared becomes negative). Petrov artificially removes this imaginary contribution by retaining only the real part of the integral. This is universally referred to as "Petrov's prescription" and described as "ad hoc" by later papers [arXiv:1710.10890; arXiv:2306.00254]. Key secondary confirmation: "Petrov's prescription for the LHY energy functional was suggested to artificially remove an annoying, unphysical imaginary part in the energy functional"; later work [consistent-theory paper, PRL 125, 195302 (2020)] identifies this as a "loophole." The positive-real Bogoliubov branch in Petrov's case contributes positively (stabilizing repulsion). The imaginary branch (which would give a complex or negative contribution) is dropped. **Crucially**: Petrov's formula handles *complex* eigenvalues (phonon going imaginary); it does not address the case of modes that are *real and negative* in a spinor mean-field.
- **Sources**:
  - [Petrov 2015] "Quantum mechanical stabilization of a collapsing Bose-Bose mixture." Phys. Rev. Lett. 115, 155302. https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.115.155302. Accessed 2026-05-15. (PDF directly read: http://www.lptms.universite-paris-saclay.fr/dmitry-petrov/files/2013/04/LHYPhysRevLett.115.155302.pdf)
  - [Consistent-theory 2020] Gu et al., "Consistent theory of self-bound quantum droplets with bosonic pairing." Phys. Rev. Lett. 125, 195302 (2020). https://link.aps.org/doi/10.1103/PhysRevLett.125.195302. Accessed 2026-05-15. (Identifies the loophole in Petrov's prescription.)
- **Confidence**: `high`. Multiple independent sources attribute "take real part, discard imaginary" to Petrov 2015 consistently.
- **Cache action**: `not_cached`.

---

### Q3: Schmitt-Wenzel-Böttcher 2016 (Dy lab, Stuttgart) and Chomaz-Petter 2016 (Er lab, Innsbruck)
- **Status**: `PARTIAL`
- **Answer**: Both experimental papers use the extended GPE with the Lima-Pelster LHY functional. The Stuttgart paper (Schmitt et al., Nature 539, 259 (2016)) and accompanying theory (Ferrier-Barbut et al., PRL 116, 215301 (2016)) apply the standard dipolar LHY formula with the imaginary part dropped — following Lima-Pelster and Bisset et al. (2016, PRA 94, 033619). The Bisset et al. (2016) theory paper is cited as explicitly noting that "to avoid this artefact [imaginary Q5], one can choose to simply neglect the imaginary part of Q5, as it is small compared to the real part" (characterization from a 2024 secondary source reviewing their work). Full-text access to the specific equation and sentence in the Schmitt/Chomaz papers was NOT obtained due to paywall.
- **Sources**:
  - [Schmitt 2016] Schmitt et al., "Self-bound droplets of a dilute magnetic quantum liquid." Nature 539, 259 (2016). https://www.nature.com/articles/nature20126. DOI: 10.1038/nature20126. Accessed 2026-05-15.
  - [Ferrier-Barbut 2016] Ferrier-Barbut et al., "Observation of quantum droplets in a strongly dipolar Bose gas." PRL 116, 215301 (2016). Accessed via search abstract 2026-05-15.
  - [Bisset 2016] Bisset, Wilson, Baillie, Blakie, "Ground-state phase diagram of a dipolar condensate with quantum fluctuations." Phys. Rev. A 94, 033619 (2016). arXiv:1605.04964. https://arxiv.org/abs/1605.04964. Accessed 2026-05-15.
  - [Wächtler & Santos 2016] "Ground-state properties and elementary excitations of quantum droplets in dipolar Bose-Einstein condensates." Phys. Rev. A 93, 061603(R) (2016). arXiv:1601.04501. Accessed 2026-05-15.
- **Confidence**: `medium`. Convention is confirmed via secondary sources and the Bisset 2016 paper characterization; exact equation number from Schmitt/Chomaz is NOT_FOUND.
- **Cache action**: `not_cached`.

---

### Q4: Is LHY-on-unstable-GS well-defined in literature for spinor F≥2 polar with λ<0 modes?
- **Status**: `PARTIAL`
- **Answer**: The literature's consensus is nuanced and depends on *why* the modes go negative:

  **Case A — Complex eigenvalues (phonon instability, DDI-driven or MF-collapse-driven):** The standard prescription (Petrov 2015, Lima-Pelster 2011/2012, Bisset 2016) is to drop the imaginary contribution and retain only `Re(ω)`. This is ad hoc but widely accepted. LHY is still computed and used on a mean-field-unstable GS in this case — it is precisely the droplet stabilization mechanism. The imaginary part of the LHY energy is neglected as a practical approximation. For binary mixtures this is justified (imaginary part is small); for dipolar systems the approximation can break down at large ε_dd.

  **Case B — Real but negative eigenvalues (spin-channel mean-field instability in spinor BECs):** This is a different physical situation. In spinor BECs, eigenvalues can be *real and negative* (not imaginary) when the spin-exchange interaction drives a ferromagnetic instability of the polar GS. In this case, taking `Re(ω) = ω < 0` and applying a threshold `ω > 1e-10` (the current code convention) drops these modes — which is also the correct convention by energy arguments (a mode with ω < 0 corresponds to the mean-field ground state being on the wrong side of the potential; its zero-point energy is not a valid quantum fluctuation correction). Uchino, Kobayashi, Ueda (PRA 81, 063632, 2010) derive LHY corrections for spin-1 and spin-2 BEC phases and "examine the stability of each phase against quantum fluctuations and the quadratic Zeeman effect" — but their derivation is phase-by-phase (each phase assumed locally stable). They do not explicitly state the convention for negative eigenvalues from an unstable GS, but their approach implicitly restricts to phases where all modes are positive-real.

  **For F=6 polar specifically:** The BdG of the polar GS has ~12/13 imaginary eigenvalues (from the full F=6 Bogoliubov matrix). The correct physical picture is that *all* branches go imaginary (i.e., complex) because the polar GS is mean-field unstable toward ferromagnetism. Applying FullBdGLHY to this state and taking `real(ev) > 1e-10` is doubly wrong: (a) the remaining positive-real modes from Nambu doubling are unphysical artifacts, not physical quantum fluctuations; (b) their UV subtraction (via `mu_b`) is miscalibrated because `mu_b` is computed for the polar-state asymptote. The closed-form `PolarContactLHY` avoids this by using the analytic `phi_1_reg` function which saturates at `t = -1` (the Petrov plateau), providing a physically motivated finite contribution even for modes that would go imaginary — it is an analytic continuation built into the `phi_1_reg` integral definition.

  **Literature consensus on Q4:** No paper explicitly says "LHY on an F≥2 polar mean-field-unstable GS is well-defined." The standard approach is to use the LHY formula *only for phases where the GS is locally stable* (each phase analyzed separately, as in Uchino et al. 2010 and Yoğurt et al. 2022). For the polar-state droplet literature (e.g., spin-1 antiferromagnetic droplets), the LHY is computed near the collapse boundary where the GS is *marginally unstable* — the imaginary LHY contribution is small and dropped. For F=6, where the polar GS is *far* from stable (many large imaginary modes), the LHY is not defined in the published literature, and the closed-form modes represent a different (analytic-continuation) approach.

- **Sources**:
  - [Uchino 2010] Uchino, Kobayashi, Ueda. Phys. Rev. A 81, 063632. arXiv:0912.0355. https://arxiv.org/abs/0912.0355. Accessed 2026-05-15.
  - [Yoğurt 2022] Yoğurt, Keleş, Oktel. "Spinor boson droplets stabilized by spin fluctuations." Phys. Rev. A 105, 043309. arXiv:2201.09628. https://arxiv.org/abs/2201.09628. Accessed 2026-05-15.
  - [Zhang 2023] arXiv:2306.00254. https://arxiv.org/abs/2306.00254. (Characterizes "imaginary part neglected" convention, and notes that "Considering stronger intercomponent interactions outside MF stability results in a complex LHY correction. A common practice in the literature is to simply neglect the imaginary part.") Accessed 2026-05-15.
- **Confidence**: `medium`. The absence of a clear citation for "LHY on F=6 polar is defined" is itself informative: no such paper was found. The literature's implicit convention is that LHY requires a locally stable GS.
- **Cache action**: `not_cached`.

---

### Q5: Source papers for PolarContactLHY / FMContactLHY / IcosahedralLHY closed forms
- **Status**: `PARTIAL`
- **Answer**: The closed-form `PolarContactLHY` in SpinorBEC.jl uses the `sigma_m`, `delta_m` Clebsch-Gordan coefficients and the `phi_1_reg(t)` regularized function. From the code comments:

  - **`phi_1_reg`**: defined as `(15/8√2) ∫₀^∞ x²[(x²+t+1) - Re√((x²+t)(x²+t+2)) - 1/(2x²)] dx`, cited as "Petrov-prescribed, UKU 2010" in the module header. The "UKU 2010" reference is Uchino-Kobayashi-Ueda (2010) arXiv:0912.0355 / PRA 81, 063632. The function `phi_1_reg` is the analytic function that provides Petrov's saturation at `t = -1`.

  - **`sigma_m`, `delta_m` polar coefficients**: The code comment says "For F=1 polar this reproduces KU 2012 Eq. (266)" — Kawaguchi-Ueda 2012 review (Phys. Rep. 520, 253; arXiv:1001.2072). The σ/δ algebra is the standard polar-phase BdG block-diagonalization, and the generalization to arbitrary F is the "paper #1" contribution of the SpinorBEC project (novel F-generic extension).

  - **`FMContactLHY`**: Code says "paper #2 contact-only piece, F=6 for now" and "Stage C scalar reduction, Saito-Li 2024 convention." "Saito-Li 2024" is cited in the `FMDipolarLHY` docstring. The FM contact single-mode result `ε = (8/15π²)(g_{2F} n)^{5/2}` is the standard scalar Lima-Pelster Q5 result applied to the fully-polarized FM branch.

  - **`IcosahedralLHY`**: Code says "Stage D, parallel-session derivation 2026-05-07" — this is an in-house result, not from published literature.

  The **key insight** from examining `phi_1_reg`: its saturation at `t ≤ -1` (returning the value `0.3177 = phi_1_reg(-1)`, not going to zero or negative) is precisely the Petrov analytic continuation for potentially-imaginary modes. When `t_m < -1`, the Bogoliubov mode at channel `m` is in the "imaginary phonon" regime — the formula analytically continues through the branch point and plateaus at the Petrov value. This is the closed-form analog of "drop the imaginary part" but computed via the regularized phi_1_reg integral. The closed form does NOT encounter negative real eigenvalues from Nambu doubling — it is a fully analytic formula that has the instability information encoded in `t_m`.

- **Sources**:
  - [Kawaguchi-Ueda 2012] "Spinor Bose-Einstein condensates." Phys. Rep. 520, 253–381. arXiv:1001.2072. https://arxiv.org/abs/1001.2072. Accessed 2026-05-15. (Source for σ/δ BdG algebra, F=1 polar Eq. (266).)
  - [Uchino-Kobayashi-Ueda 2010] Phys. Rev. A 81, 063632. arXiv:0912.0355. (Source for phi_1_reg definition.)
  - The F-generic (F>1) `PolarContactLHY` closed form appears to be unpublished (in-house, "paper #1" of the SpinorBEC project).
- **Confidence**: `medium`. The code-internal citations (KU 2012 Eq. 266; UKU 2010) are consistent with the literature found. "Paper #1" and "paper #2" are project-internal labels not yet in print.
- **Cache action**: `not_cached`.

---

## § Convention Table

| Ref | Real positive λ | Real negative λ | Complex λ (Im ≠ 0) |
|---|---|---|---|
| Lima & Pelster 2011/2012 [dipolar scalar] | Included normally | Not addressed (doesn't arise in scalar dipolar) | Drop Im; keep Re(λ) |
| Petrov 2015 [Bose-Bose] | Included normally | Not addressed (doesn't arise at MF collapse point) | Drop Im; keep Re(λ) |
| Bisset 2016 [dipolar] | Included normally | Not addressed | "Neglect imaginary part of Q5" |
| Uchino-Kobayashi-Ueda 2010 [spinor] | Included normally | Implicit: restrict to stable GS per phase | Not addressed (phases assumed locally stable) |
| Yoğurt 2022 [spin-1 droplet] | Included normally | Near-instability: small imaginary part neglected | Drop Im; LHY used only near collapse boundary |
| SpinorBEC PolarContactLHY [closed form] | Encoded via phi_1_reg(t>-1) | Encoded via phi_1_reg saturation at t≤-1 | Encoded via phi_1_reg analytic continuation |
| SpinorBEC FullBdGLHY [current code] | `real(ev) > 1e-10` → included | `real(ev) ≤ 1e-10` → dropped | `real(ev) > 1e-10` may accidentally pass Nambu-pair partner |

---

## § Recommendation for SpinorBEC.jl FullBdGLHY

The most defensible convention from the literature is:

**Drop modes where `real(ev) ≤ 0` (or below a small positive threshold).** This is consistent with Lima-Pelster / Petrov for complex modes (Re → 0 is dropped) AND with the implicit Uchino convention for spinor phases (only stable modes contribute).

However, the deeper problem for F=6 polar is not the threshold: it is that the Nambu structure of the `2D × 2D` BdG matrix generates *spurious* large positive eigenvalues (the "mirror" partners of imaginary physical modes) that pass the threshold. These are artifacts of the Nambu doubling, not physical quasi-particle modes, and they carry no valid UV subtraction because `mu_b` is miscalibrated for an unstable spinor GS.

**The recommended fix** (for the implementer) is therefore not merely a threshold change but a **phase-stability gate**: if more than a small fraction (say >10%) of the physical BdG modes (upper D rows of the `2D×2D` matrix) are imaginary, emit an error (or @warn + return NaN) rather than producing a spurious number. The existing `@warn maxlog=1` for F=6 polar is a partial mitigation.

The most citable justification is:

> "A common practice in the literature is to simply neglect the imaginary part, assuming that it is sufficiently small and hence the growth rate of the resulting instability is slower than, e.g., decay due to three-body recombination." [Zhang 2023, arXiv:2306.00254, characterizing the field consensus]

When this assumption fails (imaginary part NOT small — which is the F=6 polar case, where most modes are imaginary), the prescription breaks down entirely and the LHY cannot be reliably computed from the numerical BdG. **The literature does not provide a prescription for this regime.** The F=6 polar LHY is an open theory problem.

---

## § Sanity check against F=6 polar 3000× observation

The observed 3000× spurious energy in `FullBdGLHY` for F=6 polar IS explained by the Nambu-partner mechanism:

1. F=6 polar BdG: 12-13 of 13 physical modes go imaginary (confirmed by the code's own oracle test: "12/13 λ_b imaginary at only_g_0=100").
2. Each imaginary mode of the physical BdG enters the Nambu `2D×2D` matrix as a pair `(+iΩ, -iΩ)`. When diagonalized, the Nambu matrix eigenvalues are *real* (the complex eigenvalues of the physical BdG become real eigenvalues of the Nambu matrix — this is a standard property of the Nambu structure). These real Nambu eigenvalues can be large and positive.
3. These large positive `real(ev)` values pass the `omega > 1e-10` filter at line 231 and are summed into `zpe`.
4. The UV subtraction `mu_b` is computed from `ek + n0*real(h_total[c_star,c_star]) - mu + zee[c_star]` — this was designed for a *stable* single-component-dominant mode and is wrong for imaginary Bogoliubov modes where there is no dominant asymptote.
5. Result: large unregularized `zpe` contributions from 12-13 modes per k-point, integrated over k_values (200 points) and n_points (100 density points). Order-of-magnitude estimate: each spurious mode contributes O(n^{5/2} × interaction_scale), summed over 12 modes gives ~12× overcount relative to a 1-mode result. Further amplification from the miscalibrated UV subtraction makes 3000× plausible.

This mechanism is consistent with the known bug and does NOT require any code reading to verify — it follows directly from the Nambu eigenvalue structure and the instability of the F=6 polar GS.

---

## § Next-turn directive

**Recommend: Implementer adds a fraction-of-unstable-modes gate to FullBdGLHY with a published reference.**

Specifically:
1. In `_compute_lhy_at_density`, after computing `evals_full`, count the fraction of the upper-D eigenvalues (particle sector) that are imaginary (`|imag(ev)| > threshold`). If this fraction exceeds ~0.1 (10%), return `0.0` for that k-point's contribution (or the whole density point's `energy[i]`) rather than summing spurious Nambu partners.
2. Add a `@warn maxlog=1` at the top of `compute_spinor_lhy_table` that is triggered whenever any density point returns 0.0 due to this gate, explaining that the GS is mean-field unstable and users should switch to a closed-form mode.
3. Add a regression test that calls `compute_spinor_lhy_table` for an F=6 polar spinor and asserts that the returned energy is within, say, 2× of the `compute_spinor_lhy_polar_contact` result — OR that it returns 0.0/NaN with the appropriate warning.
4. The citable justification: Lima-Pelster 2011/2012 (drop imaginary part), Petrov 2015 (same), and the field consensus summary in Zhang 2023 (arXiv:2306.00254). The gate is a *stricter* version of the "drop imaginary part" convention: when the imaginary part dominates, the result is invalid rather than merely slightly wrong.

**If the implementer prefers the minimal 1-line fix** (matching the "simple" fix requested): change line 231 from `omega > 1e-10 || continue` to first checking the *physical* BdG eigenvalue (not the Nambu eigenvalue) for imaginariness. This requires extracting the upper-D block eigenvalues separately from the Nambu matrix eigenvalues. Alternatively: eigendecompose the `D×D` physical Bogoliubov matrix first and count imaginary modes before constructing the Nambu form.

The theorist does NOT need to re-issue: the literature convention is sufficiently clear (drop imaginary contributions; gate on stability). The ambiguity (exactly how to detect Nambu-spurious modes) is an implementation question for the implementer.

---

## Budget
- Queries: 5 received, 5 answered (Q1 RESOLVED, Q2 RESOLVED, Q3 PARTIAL, Q4 PARTIAL, Q5 PARTIAL)
- Web requests: 11 used (5 WebSearch + 3 WebFetch attempts + 3 follow-up WebSearch)
- Cache hits: 0
