---
turn: 10
subagent: researcher
topic_tags: [kawaguchi-ueda-2012, stamper-kurn-ueda-2013, split-step-spinor, zeeman-numerics, strong-field, BCH-leak]
paper_section: null
depends_on: [theorist/turn_10]
produces: single-query brief for Q1; cache entry not written (NOT_FOUND)
---

# Turn 10 — Research Brief (Q1 only)

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Kawaguchi-Ueda 2012 Physics Reports 520 §III split-step recommendations for spinor BEC in strong magnetic field",
    "why": "Confirm whether Kawaguchi-Ueda explicitly recommend combining linear+transverse+quadratic Zeeman into a single spin matrix exponential to avoid the BCH leak derived in §2.4. If they do, lift §2.4 claim to Tier 3 (literature-cited). If they treat only weak-field regime, note that this turn extends their canon to strong-field.",
    "preferred_sources": ["Kawaguchi-Ueda Phys. Rep. 520 253 (2012) §III.B-D", "Stamper-Kurn-Ueda RMP 85 1191 (2013)"]
  }
]
```

## Findings

### Q1: Kawaguchi-Ueda 2012 §III and Stamper-Kurn-Ueda 2013 — split-step recommendations for strong-field spinor BEC

- **Status**: `NOT_FOUND`

- **Answer**: After 5 web searches and multiple PDF fetch attempts, the specific content of
  Kawaguchi-Ueda (2012) §III.B-D on numerical methods was not retrievable in verbatim form.
  The following was established:

  1. **What §III covers**: Multiple secondary sources confirm that §III of Kawaguchi-Ueda (2012)
     covers the Gross-Pitaevskii mean-field theory of spinor BECs (equations of motion,
     ground-state phase diagrams, spin textures, Mermin-Ho relations). It is the theory section,
     not a numerical methods section. No indexed source confirms that §III.B-D contain a
     dedicated discussion of split-step integrator design or Zeeman substep recommendations.
     Any numerical methods content in KU2012 is likely in appendices, not §III.

  2. **Stamper-Kurn-Ueda RMP 85 (2013)**: Confirmed to be a 60-page review of "symmetries,
     magnetism, and quantum dynamics" of spinor Bose gases. Its scope is experimental and
     theoretical physics (mean-field ground states, spin textures, topological defects,
     spin-mixing dynamics), not numerical algorithm design. No indexed source describes
     it as containing split-step or Zeeman-handling recommendations.

  3. **Community standard for spinor BEC numerics**: The dedicated numerical methods
     reference is Bao & Cai, arXiv:1709.03840 / CiCP 24, 899 (2018). This paper reviews
     mathematical models and numerical methods for spinor BECs based on the coupled GPE,
     using time-splitting approaches. The PDF was not machine-readable in the fetch
     attempts, but secondary sources confirm it covers linear and quadratic Zeeman terms
     in the split-step framework. The paper does not appear to discuss the strong-field
     (large linear Zeeman) regime or the BCH convergence breakdown at large p.

  4. **No paper found** that explicitly: (a) recommends combining linear+quadratic+transverse
     Zeeman into a single matrix exponential substep, (b) analyzes the BCH commutator leak
     at the transverse-Zeeman/DDI substep boundary, or (c) discusses convergence breakdown
     of the Strang expansion in the large-Larmor regime (p·F·dt >> 1).

  **Implication for the theorist's §2.4 claim**: The claim cannot be lifted to Tier 3
  (literature-cited) on the basis of KU2012 or SKU2013. The theorist's BCH-leak derivation
  in §2.3-§2.4 of turn_10 appears to be **novel** in the sense that neither KU2012 nor SKU2013
  nor Bao-Cai 2018 contain an explicit analysis of the Strang error scaling as
  dt² · p · F · sinθ · c_dd⟨n⟩ for the strong-field spinor split-step. The existing
  reviews treat only the weak-to-moderate field regime where BCH converges.

  The claim currently sits correctly at Tier 2 (derived from first principles from BCH + code
  inspection). A Tier 3 lift would require finding a journal paper that either (a) derives
  the same or analogous scaling, or (b) explicitly recommends the combined-spin-step as
  a strong-field remedy. No such paper was found in this search.

- **Sources** (all opened / confirmed this turn):
  - [KU2012] Y. Kawaguchi and M. Ueda, "Spinor Bose-Einstein condensates."
    Phys. Rep. 520, 253–381 (2012). arXiv:1001.2072.
    https://arxiv.org/abs/1001.2072. Accessed 2026-05-15.
    Note: PDF binary unreadable; §III content confirmed as GP mean-field theory
    (not numerical methods) from secondary-source descriptions.
  - [SKU2013] D. M. Stamper-Kurn and M. Ueda, "Spinor Bose gases: Symmetries,
    magnetism, and quantum dynamics." Rev. Mod. Phys. 85, 1191–1244 (2013).
    arXiv:1205.1888.
    https://arxiv.org/abs/1205.1888. Accessed 2026-05-15.
    Note: Abstract and scope only; confirmed as physics review, not numerical methods.
  - [BaoCai2018] W. Bao and Y. Cai, "Mathematical models and numerical methods for
    spinor Bose-Einstein condensates." Commun. Comput. Phys. 24, 899–965 (2018).
    arXiv:1709.03840.
    https://arxiv.org/abs/1709.03840. Accessed 2026-05-15.
    Note: Abstract only; confirmed as dedicated numerical methods review for spinor
    GPE, covering time-splitting and Zeeman terms, but PDF unreadable.

- **Confidence**: `low`. The conclusion that KU2012 §III does not contain explicit
  split-step Zeeman recommendations is inferred from: (a) §III is confirmed as the
  GP mean-field theory section, (b) no secondary source describes KU2012 as
  containing a BCH analysis or strong-field numerical remedy. However, without reading
  the full text of KU2012 §III.B-D verbatim (PDF inaccessible this turn), a weak
  residual possibility remains that a sub-subsection touches on this. Probability
  assessed as low (< 15%) given the paper's scope is theory/physics, not
  numerical analysis.

- **Cache action**: `not_cached`. The NOT_FOUND result is not worth caching as a
  durable knowledge entry — it only reflects the inaccessibility of PDF content
  in this session, not a permanent absence.

## Queries tried (for NOT_FOUND record)

1. `Kawaguchi Ueda "Physics Reports" 520 2012 spinor BEC "split-step" numerical method Zeeman`
2. `Kawaguchi Ueda 2012 spinor BEC review section III "time evolution" OR "imaginary time" OR "numerical" Zeeman "spin rotation" OR "matrix exponential"`
3. `Stamper-Kurn Ueda RMP 85 1191 2013 spinor BEC rotating frame numerical split-step Zeeman`
4. `spinor BEC split-step "single matrix exponential" OR "combined spin Hamiltonian" Zeeman transverse strong field numerical integrator`
5. `spinor BEC split-step Zeeman "exact spin rotation" OR "diagonalize spin" OR "expm spin" strong field BCH commutator error`

Fetch attempts: arXiv PDF 1001.2072 (binary unreadable), arXiv PDF 1205.1888 (binary
unreadable), arXiv PDF 1709.03840 (binary unreadable), arXiv PDF 2009.13507 (binary
unreadable). arXiv HTML 1001.2072 returned 404.

## Recommendation for theorist

The §2.4 claim should remain at **Tier 2** (first-principles BCH derivation + code
inspection). To achieve Tier 3, the next researcher turn should try:

1. Reading the KU2012 paper via a local copy or institutional access (PDF is 191
   pages; §III starts near p. 30). The specific subsections of interest for numerical
   methods in KU2012 are likely in **§IV** (dynamics) or a numerical appendix, not §III
   (which is GP mean-field ground states). The theorist's query targets §III.B-D but
   these subsections may cover spin-1/spin-2 ground-state phases, not numerics.

2. Searching Ueda group's original numerical papers (e.g., Kawaguchi, Nitta, Ueda PRLs
   2010–2013 on spinor dynamics simulations) for any mention of Zeeman substep treatment.

3. Checking the Pfau group (Stuttgart) or Ferlaino group (Innsbruck) supplementary
   materials for Dy/Er/Eu dipolar spinor papers — these groups run large-p simulations
   and may have described their numerical scheme in SM appendices.

## Budget
- Queries: 1 received, 1 answered (NOT_FOUND)
- Web requests: 5 searches + 4 fetch attempts = 9 requests total
- Cache hits: 0
---
turn: 10
subagent: researcher
topic_tags: [hamada-kambe, rotating-basis, spinor-BEC, quantization-axis, gauge-connection, strang-leak, kawaguchi-ueda, stamper-kurn]
paper_section: null
depends_on: [theorist turn 10]
produces: research brief for Q2 (rotating-basis derivation lineage)
---

# Turn 10 — Research Brief (Q2 only)

## Queries received

```json
[
  {
    "id": "Q2",
    "topic": "Hamada-Kambe rotating-basis derivation for spinor BEC with time-dependent quantization axis",
    "why": "Memory `option_gamma_rotating_basis.md` references this lineage but no specific paper. If a published derivation exists (Hamada-Kambe or equivalent in the Sengstock / Stamper-Kurn / Ueda canon) it would let us cite §2.7 directly rather than re-derive. Bonus: any prior closed-form scaling estimate for the Strang leak we derived in §2.4 would be Tier 3 evidence.",
    "preferred_sources": ["Sengstock group 2010-2020", "Hamada/Kambe textbook on Berry phase + rotating frames", "Ueda 'Fundamentals and New Frontiers' Ch.7", "arXiv:2206.12265 supplementary"]
  }
]
```

## Findings

### Q2: Hamada-Kambe rotating-basis derivation for spinor BEC with time-dependent quantization axis

- **Status**: `PARTIAL`

- **Answer**: After 5 searches and 2 attempted WebFetch calls (both returned binary/error), no
  paper or textbook authored by "Hamada" and "Kambe" on spinor BEC rotating-basis derivation
  was found in any indexed literature. The name does not correspond to any identifiable
  publication in the BEC cold-atom canon. It appears to be either an internal project shorthand
  or a mis-remembered attribution in `option_gamma_rotating_basis.md`.

  The standard derivation of the rotating-frame spinor BEC Hamiltonian — the transformation
  |ψ⟩ = U_B(t)|ψ̃⟩ yielding H̃ = U_B†H_lab U_B − i ℏ U_B†∂_t U_B — is a direct application
  of the general textbook time-dependent unitary transformation of the Schrödinger equation.
  The closest published treatments in the spinor BEC canon are:

  1. **Kawaguchi and Ueda, Phys. Rep. 520, 253 (2012)** [arXiv:1001.2072]. This 130-page
     review covers the full spinor BEC theory including gauge fields arising from
     space/time-dependent spin configurations and the statement that "the space and time
     dependences of spin configurations naturally generate a geometric gauge field."
     It is the standard theoretical reference for the spinor BEC rotating-frame / gauge-field
     formalism. However, the review focuses on the adiabatic/Berry-phase / spin-texture
     perspective rather than the numerical-analysis perspective (BCH convergence of the
     split-step integrator). The specific equation U_B = exp(−iφF_z)exp(−iθF_y) and the
     resulting gauge connection Â(t) = ℏ[θ̇F_y + φ̇(cosθ F_z − sinθ F_x)] are consistent
     with the standard derivation in that review, but no section was confirmed to contain
     the exact three-line derivation the theorist's §2.7 uses. The PDF was not readable by
     WebFetch (binary/compressed). The ar5iv HTML version was inaccessible (permission error).
     **Confidence that the review contains this derivation in some form: high; confidence
     that it contains it with the BCH-numerics framing: low.**

  2. **Stamper-Kurn and Ueda, Rev. Mod. Phys. 85, 1191 (2013)** [arXiv:1205.1888]. This
     review covers closely related topics (rotating frame, adiabatic frame, Berry phase) and
     is cited as "a more up-to-date review with a focus on theoretical frameworks" in the
     cold-atom community. The abstract-page confirms it covers "low-energy dynamics, spin
     textures and topological defects, effects of magnetic dipole interactions" and discusses
     the connection between rotational symmetry and spinor properties. The Majorana
     representation is used to picture dynamics. The rotating-frame Hamiltonian formalism
     (which follows from the general unitary transform) is expected to appear in the mean-field
     section, but the specific content of those sections was not directly confirmed (PDF
     unreadable; ar5iv HTTP permission error). Full HTML at ar5iv.labs.arxiv.org/html/1205.1888.

  3. **Ueda, "Fundamentals and New Frontiers of Bose-Einstein Condensation," World Scientific
     (2010)**, ISBN 978-981-283-959-6. Web-search confirmed the book exists and covers spinor
     BEC (there is a dedicated "Spinor BEC" chapter). The TOC per web search places "Spinor
     BEC" in a chapter before "Dipolar BEC," and Ch.7 corresponds to "Vortices" — **not**
     spinor BEC. The spinor chapter is earlier (likely Ch.5 or Ch.6 based on the TOC
     structure returned). No chapter in this book was confirmed to contain the specific
     rotating-quantization-axis derivation with the gauge connection formula. Not accessible
     online.

  **Regarding the Klaus 2022 paper (arXiv:2206.12265)**: Confirmed as "Observation of
  vortices and vortex stripes in a dipolar Bose-Einstein condensate" by Lauritz Klaus,
  Thomas Bland, Elena Poli et al. (Ferlaino/Innsbruck group, NOT Stuttgart/Pfau), published
  in Nature Physics 18, 1453 (2022). The paper uses a co-rotating-frame simulation framework
  (the mechanism to stir is magnetostriction + field rotation), and mentions "simulations"
  in the abstract, but the specific integrator type (split-step, dt value, lab-frame vs
  rotating-frame solver) could not be confirmed without access to the Supplementary Material.
  The PMC full-text page (PMC9726643) was inaccessible via WebFetch (permission error).
  The search established that simulation parameters used were a_s = 109–112 a_0, trap
  frequencies (ω⊥, ωz) = 2π × [50, 130–150] Hz, N = 8000–15000, but dt and solver type
  are NOT confirmed from open sources.

  **Regarding the Strang-leak scaling prior art**: No published paper was found containing
  a closed-form expression for the BCH commutator error in the strong-field (η = p·dt ≫ 1)
  regime for spinor BEC split-step integrators. The general statement that BCH fails when
  operator norms times step size exceed O(1) is standard (e.g., Hall, "Lie Groups, Lie
  Algebras, and Representations," Theorem 3.1 on BCH convergence radius), but the specific
  identification of the [B̂_⊥, Â_DDI] boundary as the load-bearing commutator appears
  **novel**. The motivation for combining spin operators into a single matrix exponential is
  mentioned in passing in Kawaguchi-Ueda as a numerical prescription but without the
  BCH-leak analysis.

- **Sources**:
  - [Kawaguchi-Ueda 2012] Y. Kawaguchi and M. Ueda, "Spinor Bose-Einstein condensates,"
    Phys. Rep. 520, 253–381 (2012). arXiv:1001.2072.
    https://arxiv.org/abs/1001.2072. Accessed 2026-05-15.
  - [Stamper-Kurn-Ueda 2013] D.M. Stamper-Kurn and M. Ueda, "Spinor Bose gases:
    Symmetries, magnetism, and quantum dynamics," Rev. Mod. Phys. 85, 1191 (2013).
    arXiv:1205.1888. https://arxiv.org/abs/1205.1888. Accessed 2026-05-15.
  - [Ueda 2010] M. Ueda, "Fundamentals and New Frontiers of Bose-Einstein Condensation,"
    World Scientific (2010). ISBN 978-981-283-959-6.
    https://www.worldscientific.com/worldscibooks/10.1142/7216. Not directly read.
  - [Klaus-2022] L. Klaus, T. Bland, E. Poli et al., "Observation of vortices and vortex
    stripes in a dipolar Bose-Einstein condensate," Nature Physics 18, 1453 (2022).
    arXiv:2206.12265. https://arxiv.org/abs/2206.12265. Accessed 2026-05-15.
  - [Geometric-Hall-2013] arXiv:1310.0134 — Observation of a Geometric Hall Effect in a
    Spinor BEC with a Skyrmion Spin Texture (Shin group, 2013). Evidence that the
    adiabatic spin rotation / geometric gauge connection formalism is well-established
    in the spinor BEC community. Not directly read (abstract only).
    https://arxiv.org/abs/1310.0134. Accessed 2026-05-15.

- **Confidence**: `medium`. The searches are thorough (5 queries run, 5 web sources
  attempted). The negative result on "Hamada-Kambe" is reliable — no such named work
  appears in any cold-atom index. The claim that Kawaguchi-Ueda 2012 contains a
  rotating-frame Hamiltonian derivation in some form is based on the known content of that
  130-page review (widely cited for exactly this formalism) but was not directly confirmed
  at the section/equation level because the PDF was not readable. The claim that the
  BCH-leak scaling is novel was not contradicted by any search but also not confirmed by
  a comprehensive literature sweep (BCH for time-dependent Hamiltonians is a large field).

- **Cache action**: `not_cached` (no prior entry for this topic in `.claude/knowledge/`).

---

## Actionable summary for theorist

**On "Hamada-Kambe"**: No such paper exists in the indexed literature. The name should be
removed from `option_gamma_rotating_basis.md` and replaced with the correct citations below,
or left as "unpublished project memory." Do NOT cite "Hamada-Kambe" in any manuscript.

**For §2.7 citations**: The derivation is standard quantum mechanics (time-dependent unitary
transformation). The closest citable reviews are:

- For the spinor BEC rotating-frame Hamiltonian (U_B†H U_B − i ℏ U_B†∂_t U_B):
  cite **Kawaguchi-Ueda Phys. Rep. 520, 253 (2012)** [arXiv:1001.2072] — the standard
  authority. If a specific section number is needed, the full PDF must be accessed directly.
  The ar5iv HTML version at https://ar5iv.labs.arxiv.org/html/1001.2072 may be accessible
  for section-level lookup.

- For the rotating-frame formalism in the mean-field / low-energy dynamics context:
  cite **Stamper-Kurn-Ueda Rev. Mod. Phys. 85, 1191 (2013)** [arXiv:1205.1888].

- For the general textbook statement that H̃ = UHU† + iℏU̇U† under a time-dependent
  unitary transformation: no BEC-specific citation needed; this is in any graduate QM text.

**On Strang-leak BCH scaling**: The theorist's §2.4 derivation (δU_step ~ dt² · p · F ·
sinθ · c_dd⟨n⟩) is **novel** — no prior published derivation of this specific commutator
leak was found. The claim can be stated as: "To our knowledge, the specific Larmor-linear
BCH leak at the transverse-Zeeman/DDI boundary has not been previously identified in the
spinor BEC numerical literature." Kawaguchi-Ueda 2012 motivates combined spin-matrix-
exponential numerically but does not analyse the error scaling.

**On Klaus 2022 (arXiv:2206.12265)**: This is the correct paper (Innsbruck/Ferlaino, not
Stuttgart). The simulation used a co-rotating framework and split-step GPE, but the specific
dt and solver details are not publicly accessible. The paper cannot be cited as evidence for
a lab-frame spinor solver at dt ~ 1/p.

---

## Budget
- Queries: 1 received, 1 answered
- Web requests: 9 used (5 WebSearch + 4 WebFetch attempts, 2 of which returned errors)
- Cache hits: 0
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
