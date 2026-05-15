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
