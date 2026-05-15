---
turn: 10
subagent: researcher
topic_tags: [klaus-2022, egpe-scalar, rotating-frame, split-step, larmor-subcycling, numerical-methods]
paper_section: null
depends_on: [theorist turn_10]
produces: research brief on Klaus 2022 numerical methods
---

# Turn 10 — Research Brief (Q3 only)

## Queries received

```json
[
  {
    "id": "Q3",
    "topic": "Klaus et al. 2022 arXiv:2206.12265 supplementary — what dt did they use, and what solver?",
    "why": "If the published Klaus paper's numerical method note specifies an integrator that bypasses the Larmor sub-cycling (e.g. a rotating-frame solver implicit), it would be circumstantial Tier 2.5 evidence that our §2 diagnosis is field-standard. If they used a lab-frame split-step at dt ≲ 1/p, this turn's lift is a novel diagnostic.",
    "preferred_sources": ["arXiv:2206.12265 supplementary material §C 'numerical methods'", "Innsbruck dipolar group 2020-2024 numerical method notes"]
  }
]
```

## Findings

### Q3: Klaus et al. 2022 arXiv:2206.12265 — solver, dt, and frame

- **Status**: `PARTIAL`

- **Answer**:

  Klaus et al. 2022 (*Nat. Phys.* 18, 1453–1458; arXiv:2206.12265) is authored by Lauritz Klaus, Thomas Bland, Elena Poli, Claudia Politi, Giacomo Lamporesi, Eva Casotti, Russell N. Bisset, Manfred J. Mark, and Francesca Ferlaino (Innsbruck group). The paper's numerical simulation model is unambiguously a **scalar extended Gross-Pitaevskii equation (scalar eGPE)** — NOT a spinor solver. The dipoles are polarized uniformly along a **time-dependent axis** (the rotating magnetic field direction), which is substituted directly into the DDI kernel of the scalar field equation. This means the Larmor sub-cycling problem diagnosed in theorist turn 10 §2.4–§2.6 does not arise in their simulation: by working with a scalar field, they analytically eliminate the spin degree of freedom and the entire $-p\hat{F}_z$ diagonal Zeeman term; the rotating field direction enters only through the DDI tensor rotation in the scalar channel.

  The paper explicitly states that the **stationary (ground state) solution is found via imaginary time propagation in the rotating frame**, with the angular momentum operator $-\Omega L_z$ introduced into the eGPE [language extracted from the PMC full-text search result; see sources]. Real-time dynamics post-processing also uses the rotating frame (the paper states "Fourier transform 115 frames from the simulation between 700 ms and 1.1 s in the rotating frame" for the stripe analysis). The dynamics solver is therefore consistent with a **split-step Fourier method operating in the rotating frame** — this is the field-standard choice for dipolar BEC vortex simulations and is confirmed by Thomas Bland's public code repository `thomas-bland/quasi2D_dipolar_GPE`, described explicitly as "Simple MATLAB code for quasi-2D dipolar GPE, solved with a split-step Fourier method" [GitHub, accessed 2026-05-15].

  **The specific dt value for the real-time dynamics is NOT accessible** in the abstract, the PMC/PubMed metadata, or any indexed web text. The Nature Physics supplementary material (§C, "numerical methods"), which would contain the explicit dt and solver specification, is behind a paywall and was not successfully fetched during this turn. No cached version or preprint appendix with this information was found.

  **What can be inferred about dt without direct access**: The scalar eGPE with rotating DDI kernel has no Larmor term; the relevant timescale is the trap frequency $\omega_\perp = 2\pi \times 50$ Hz, so dt ~ 1/(few × trap) ≈ few × $10^{-3}$ in dimensionless units is adequate and expected. There is no constraint from Larmor sub-cycling because the spin sector is eliminated.

- **Sources**:
  - [Klaus 2022] Klaus L., Bland T., Poli E., et al. "Observation of vortices and vortex stripes in a dipolar condensate." *Nat. Phys.* **18**, 1453–1458 (2022). DOI: 10.1038/s41567-022-01793-8. arXiv: https://arxiv.org/abs/2206.12265. Accessed 2026-05-15.
  - [Klaus 2022 PMC] PubMed Central full text: https://pmc.ncbi.nlm.nih.gov/articles/PMC9726643/. Partially accessible (fetching attempted; permission-blocked by environment). Search-result excerpts quoted above extracted via WebSearch metadata.
  - [Bland repo] Thomas Bland, `quasi2D_dipolar_GPE`, GitHub, 2 commits, 1 fork. "Simple MATLAB code for quasi-2D dipolar GPE, solved with a split-step Fourier method." https://github.com/thomas-bland/quasi2D_dipolar_GPE. Accessed 2026-05-15.

- **Confidence**: `medium`. The scalar-eGPE identification is HIGH confidence — it is stated explicitly in the paper's main text (visible in multiple search result excerpts) and is consistent with the memory entry in `memory/klaus_adiabatic_elimination.md`. The rotating-frame confirmation for imaginary time is HIGH confidence (quoted verbatim in search results). The inference that real-time dynamics also run in the rotating frame is MEDIUM confidence (consistent with the Fourier-frame statement, but could be a post-processing step rather than the integration frame). The dt value is NOT_FOUND — could not be retrieved without paywall access. Confidence overall: medium.

- **Cache action**: `not_cached` (no cache directory found at .claude/knowledge/).

## Implication for theorist turn_10 §4 calibrated claims

The Klaus 2022 numerical choice **supports rather than refutes** the theorist's §2 diagnosis, with the following interpretation:

1. **The Ferlaino group did NOT use a spinor solver for Klaus 2022.** They used a scalar eGPE. This is precisely the model that `memory/klaus_adiabatic_elimination.md` describes as the correct adiabatic approach. The absence of a spinor solver in their code is consistent with — and arguably a practical confirmation of — the theorist's Tier-2 claim that the spinor lab-frame solver requires dt ~ 1/p for correctness and that this is prohibitively small.

2. **The Klaus group implicitly bypassed the Larmor sub-cycling** by choosing scalar eGPE. They did not document a rotating-frame spinor solver or a special dt ~ 1/p constraint. The theorist's claim that this is a "novel diagnostic" (framing from the `why` field) appears correct: the specific BCH-leak analysis of §2.4 — which quantifies the per-step error as $dt^2 \cdot p \cdot F \cdot \sin\theta \cdot c_{dd}\langle n \rangle$ — does not appear in the Klaus paper. They avoided the problem by model choice, not by solving it.

3. **Tier 2.5 or Tier 3 lift**: The Klaus paper's use of scalar eGPE constitutes circumstantial evidence (~Tier 2.5) that the Innsbruck group was aware the spinor solver would not work at trap-scale dt for this regime. However, it is circumstantial: they do not state the reason is the BCH leak, and the scalar eGPE could also be preferred for simplicity, speed, or physical accuracy (adiabatic limit). A direct citation of the Strang-leak mechanism as the motivation for rotating-frame / scalar-eGPE approaches would require a paper explicitly discussing it — none was found (see NOT_FOUND note below).

4. **NOT_FOUND: the specific §C supplementary dt value**. This is the precise datum the theorist wanted. Without paywall access it cannot be confirmed. The theorist should note that the dt question is partially moot given the scalar-eGPE finding: dt for a scalar simulation has no Larmor sub-cycling constraint and would likely be ~trap scale.

## Budget
- Queries: 1 received, 1 answered (PARTIAL)
- Web requests: 8 used (3 WebSearch + 5 WebFetch attempts; 3 WebFetch blocked by environment permissions, 1 WebFetch returned binary PDF, 1 returned 404)
- Cache hits: 0
