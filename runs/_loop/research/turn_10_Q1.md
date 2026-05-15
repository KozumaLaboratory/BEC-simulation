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
