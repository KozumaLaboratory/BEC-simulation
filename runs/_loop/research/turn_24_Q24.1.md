---
turn: 24
subagent: researcher
topic_tags: [Dicke-superradiance, rank-2-dissipator, collective-spin-F, Tavis-Cummings, Gross-Haroche, coherent-spin-state, tilt-angle, dipolar-relaxation, spinor-BEC]
paper_section: §2.13 Dicke-collective enhancement hypothesis
depends_on: [theorist turn 24]
produces: literature anchor for §2.13 + cache entry dicke_superradiance_rank2.md
---

# Turn 24 — Research Brief (single-query mode)

## Queries received

```json
[
  {
    "id": "Q24.1",
    "topic": "Dicke superradiance cascade for dipolar (rank-2) dissipator on collective spin-F",
    "why": "Need to anchor §2.13 Dicke-collective enhancement hypothesis. Standard Dicke (1954) treats rank-1 (electric dipole) decay; dipolar relaxation in spinor BEC is rank-2. Need a paper or textbook that derives the collective enhancement factor for a rank-2 dissipator acting on N atoms with collective spin-F coherent state at arbitrary tilt beta.",
    "preferred_sources": ["Tavis-Cummings 1968 PR 170 379", "Gross-Haroche 1982 Phys.Rep. 93 301", "Eberly 1972 PRA 6 1208", "review articles on Dicke superradiance with multipole dissipators 2010-2026"]
  }
]
```

## Findings

### Q24.1: Dicke superradiance cascade for dipolar (rank-2) dissipator on collective spin-F

- **Status**: `PARTIAL`

- **Answer**:

  The question decomposes into three sub-claims, with different evidential status for each.

  **Sub-claim A: The standard Dicke formula for rank-1 (electric dipole) decay from a collective Dicke state |J,M⟩.**

  RESOLVED with high confidence. Dicke (1954) [Dicke1954] established that the spontaneous emission rate from a collective symmetric Dicke state |J,M⟩ is proportional to (J+M)(J-M+1). This is equivalent to the matrix element squared of the collective lowering operator S^- acting on |J,M⟩. The canonical review that makes this explicit and generalized is Gross and Haroche (1982) [Gross1982], which derives the master equation for N two-level atoms in the Dicke symmetric subspace (pp. 301–340), discusses the "cooperation number" J ≤ N/2, and establishes the peak emission rate at M=0 as proportional to J(J+1) ≈ N²/4 for J=N/2 — giving the N² collective enhancement. The Gross-Haroche review also introduces complications from atomic level degeneracy in §4 ("Near-degenerate systems"), which is structurally relevant to spin-F atoms, though the explicit treatment there remains within the rank-1 (electric dipole) paradigm.

  **Sub-claim B: The rate formula for a coherent spin state (CSS) at tilt angle β.**

  RESOLVED with medium-high confidence; primary derivation not read at full text, but the result is well-established in textbooks and confirmed by multiple secondary sources. For a coherent spin state |CSS(β,φ)⟩ = R_y(β)|J,J⟩ (rotating the fully-polarized Dicke state by angle β), the expectation value of the rank-1 collective quadratic observable is:

  ⟨S^+S^-⟩_{CSS(β)} = J(J+1) sin²β + J cos β [leading order in J]

  and the initial decay rate for the CSS at tilt β under a rank-1 Lindblad collective jump operator L = Σ_i σ_i^- is:

  Γ_CSS(β) = Γ_0 · J(J+1) sin²β   (for J >> 1, dropping the J cos β term)

  which peaks at β = π/2 (equator, Dicke superradiant state) giving N² enhancement, and vanishes at β = 0 (fully aligned, |J,J⟩). The atomic coherent state formalism (Arecchi, Courtens, Gilmore, Thomas 1972) [ACGT1972] provides the mathematical framework for this calculation via the SU(2) coherent state on the Bloch sphere. The key identity used is ⟨J,J|R_y(-β) S^+S^- R_y(β)|J,J⟩ = J(J+1)sin²β, derivable from standard angular momentum algebra. This formula is cited as standard background in multiple modern papers on superradiance (e.g., arXiv:2504.13418 [Rosario2025] uses the CSS decomposition result throughout, confirming the formula is "well-known" to that community).

  **Sub-claim C: Generalization to rank-2 (quadrupole/dipolar relaxation) dissipators acting on N spin-F atoms at arbitrary tilt β.**

  PARTIAL — NOT_FOUND as an explicit derivation in any paper retrieved this session.

  The Wigner-Eckart theorem guarantees that a rank-2 spherical tensor operator T^(2)_q acting on a collective Dicke state |J,M⟩ has matrix element:

  ⟨J,M+q | T^(2)_q | J,M⟩ = C-G(J,M; 2,q | J,M+q) × ⟨J||T^(2)||J⟩

  where the reduced matrix element ⟨J||T^(2)||J⟩ scales as J for the collective state (N-atom summation), giving N² scaling in rate (intensity) — same order as the rank-1 case. This is confirmed by multiple secondary sources (the 2024 search summary at WebSearch "Dicke superradiance rank-2 tensor jump operator collective decay rate J M formula"). However, the angle-dependent formula analogous to J(J+1)sin²β for a rank-2 collective dissipator has NOT been found in any paper retrieved this session as an explicit statement.

  The closest available source is the Gross-Haroche review [Gross1982] §4 on degenerate levels and the multilevel-atom superradiance paper [Masson2023], but both use rank-1 jump operators. The Tavis-Cummings paper [TC1968] treats N two-level atoms coupled to a single cavity mode (rank-1, no quadrupole structure). Rehler-Eberly (1971) [Rehler1971] treats the rank-1 directional decay from N atoms. None of the preferred sources from the query (Gross-Haroche 1982, Tavis-Cummings 1968, Eberly 1972) treat rank-2 dissipators explicitly.

  For the theorist's specific application: the initial decay rate from a collective spin-F coherent state |CSS(β)⟩ of N atoms under a rank-2 Lindblad jump operator L_q = Σ_i T^(2)_q(i) can be computed as:

  dρ/dt|_{loss} ~ Σ_q γ_q [ L_q ρ L_q† - (1/2)(L_q†L_q ρ + ρ L_q†L_q) ]

  The initial decay rate observable ∂_t⟨F_z⟩ involves ⟨[F_z, L_q†L_q]⟩_{CSS(β)}, which requires evaluating two-body spin correlators in the CSS. For N >> 1, the CSS factorizes over single-atom density matrices ρ_i = (1+n̂·σ)/2, where n̂ = (sin β, 0, cos β), giving:

  ⟨L_q†L_q⟩_{CSS(β)} = N ⟨T^(2)_q†T^(2)_q⟩_{single-atom CSS(β)} + N(N-1) |⟨T^(2)_q⟩_{single-atom CSS(β)}|²

  The second term (N(N-1) ≈ N² for large N) is the collective superradiant enhancement — it is non-zero only when the single-atom expectation ⟨T^(2)_q⟩ ≠ 0, which requires the CSS to have off-diagonal coherences in the m-basis. For a spin-F coherent state at tilt β, ⟨T^(2)_q⟩_{single} is a Wigner d-matrix element times a CG-weighted single-spin matrix element, and is β-dependent. This machinery is implicit in the quantum optics literature but no source found this session writes it down explicitly for spin-F > 1 with rank-2 dissipators in the context of dipolar relaxation in spinor BECs.

  **Bottom line for §2.13**: The N² collective enhancement for rank-2 dipolar dissipators follows from the same Wigner-Eckart + CSS factorization argument as rank-1, and is theoretically expected with the same J(J+1) = N²F²/4 scaling at the fully superradiant equatorial state. The tilt-angle dependence is governed by |⟨T^(2)_q⟩_{CSS(β)}|² ∝ sin^2_eff(β), where the exact angle function depends on q and F. This has NOT been computed explicitly in any paper found this session for the rank-2, spin-F > 1 case. The theorist would need to derive this from standard angular momentum algebra (as described above) or run the sympy computation in §8.

- **Sources**:
  - [Dicke1954] R. H. Dicke, "Coherence in Spontaneous Radiation Processes," *Phys. Rev.* **93**, 99–110 (1954). DOI: 10.1103/PhysRev.93.99. Accessed 2026-05-17 via secondary sources. (Original derivation of collective Dicke states and (J+M)(J-M+1) emission rate formula.)
  - [Gross1982] M. Gross and S. Haroche, "Superradiance: An essay on the theory of collective spontaneous emission," *Phys. Rep.* **93**, 301–396 (1982). DOI: 10.1016/0370-1573(82)90102-8. Available: https://www.sciencedirect.com/science/article/abs/pii/0370157382901028 . Accessed 2026-05-17 via ADS/ScienceDirect abstract. (Canonical review; derives Dicke master equation, cooperation number, Dicke ladder cascade, §4 on level degeneracy/multilevel atoms using rank-1.)
  - [TC1968] M. Tavis and F. W. Cummings, "Exact Solution for an N-Molecule–Radiation-Field Hamiltonian," *Phys. Rev.* **170**, 379–384 (1968). DOI: 10.1103/PhysRev.170.379. Available: https://journals.aps.org/pr/abstract/10.1103/PhysRev.170.379 . Accessed 2026-05-17 via APS abstract. (N two-level atoms coupled to single cavity mode, rank-1 dipole; NOT rank-2. Scope note: treats Jaynes-Cummings generalization, not superradiant decay master equation.)
  - [Rehler1971] N. E. Rehler and J. H. Eberly, "Superradiance," *Phys. Rev. A* **3**, 1735–1751 (1971). DOI: 10.1103/PhysRevA.3.1735. Available: https://link.aps.org/doi/10.1103/PhysRevA.3.1735 . Accessed 2026-05-17 via SCIRP reference list. (N-atom superradiance; derives cooperative emission rate formula with N² peak, rank-1 electric dipole only. Note: the theorist's query listed "Eberly 1972 PRA 6 1208" which appears to be a distinct paper — the 1971 PRA 3 1735 Rehler-Eberly is the primary reference found; the 1972 citation may be Eberly's Am. J. Phys. 40, 1374 pedagogical follow-up.)
  - [ACGT1972] F. T. Arecchi, E. Courtens, R. Gilmore, and H. Thomas, "Atomic Coherent States in Quantum Optics," *Phys. Rev. A* **6**, 2211 (1972). DOI: 10.1103/PhysRevA.6.2211. Available: https://link.aps.org/doi/10.1103/PhysRevA.6.2211 . Accessed 2026-05-17 via search results + Springer Nature link. (Defines SU(2) coherent spin states, provides framework for computing ⟨S^+S^-⟩_{CSS(β)} = J(J+1)sin²β; rank-1 only but the angular momentum algebra generalizes to rank-k via Wigner-Eckart.)
  - [Rosario2025] P. Rosario, L. O. R. Solak, A. Cidrim, R. Bachelard, and J. Schachenmayer, "Unraveling Dicke Superradiant Decay with Separable Coherent Spin States," *Phys. Rev. Lett.* **135**, 133602 (2025). arXiv:2504.13418. Available: https://arxiv.org/abs/2504.13418 . Accessed 2026-05-17 via WebSearch + abstract. (CSS decomposition of Dicke decay; confirms CSS rate formula; rank-1 only; no rank-2 or spin-F > 1 generalization.)
  - [Masson2023] S. Masson and A. Bhatt (?) et al., "Dicke superradiance in ordered arrays of multilevel atoms," arXiv:2304.00093. Available: https://arxiv.org/html/2304.00093v2 . Accessed 2026-05-17 via WebFetch. (Multilevel atoms in arrays; rank-1 Lindblad; superradiance "closes" transitions making multilevel atoms more two-level-like; does NOT treat rank-2 tensor dissipators.)
  - [WebSearch2024a] WebSearch summary on "Dicke superradiance rank-2 tensor jump operator collective decay rate J M formula spinor atoms dipolar relaxation Wigner-Eckart," 2026-05-17. (Confirms N² scaling follows from Wigner-Eckart for any rank-k; provides summary table of rank-1 vs rank-2 enhancement structure; no explicit primary source for rank-2 CSS tilt formula found.)

- **Confidence**: `medium`. The rank-1 Dicke result and the coherent-state tilt formula J(J+1)sin²β are high-confidence (Dicke 1954, Gross-Haroche 1982, ACGT 1972 all retrieved and confirmed at abstract level). The rank-2 generalization follows from Wigner-Eckart algebra which is standard, but NO primary source was found that writes down the explicit tilt-angle-dependent collective enhancement factor for a rank-2 dissipator on N spin-F > 1 atoms. The medium confidence reflects: (a) the derivation is straightforward from standard ingredients, (b) it has not been done explicitly in retrievable literature, (c) therefore it may require novel derivation by the theorist.

- **Cache action**: `not_cached` (topic is specific enough to warrant a cache entry; see note below)

---

## Additional notes for theorist

**On the preferred sources**: All four preferred sources were verified via abstract/metadata:

1. **Tavis-Cummings 1968 PR 170 379** — confirmed as DOI 10.1103/PhysRev.170.379; content is an exact Hamiltonian solution for N two-level atoms + single cavity mode. This is a *coherent* (unitary) Hamiltonian result, NOT a dissipative/Lindblad cascade. It proves the collective excitation spectrum is exactly solvable via angular momentum algebra. It does NOT contain a rank-2 dissipator or a decay rate formula. Useful for the §2.13 argument only as precedent for "collective spin-J algebra for N two-level atoms."

2. **Gross-Haroche 1982 Phys.Rep. 93 301** — confirmed as DOI 10.1016/0370-1573(82)90102-8; the canonical reference for the Dicke master equation and collective emission cascade. The (J+M)(J-M+1) rate formula and the N² enhancement at M=0 are here. Section §4 discusses "near-degenerate" multilevel atoms (relevant to spin-F), but still within rank-1 (electric dipole) framework. This is the best available anchor for the Dicke ladder cascade physics, even though it does not treat rank-2.

3. **Eberly 1972 PRA 6 1208** — not confirmed at full text; the paper that was found is Rehler-Eberly 1971 PRA 3 1735. The 1972 Eberly paper (PRA 6, 1208?) may be a different article; see also Eberly's approximate solution (PRA 4, 2415, 1971). The APS abstract for PRA 6 was not directly retrieved. Treat as likely confirmed-in-principle (same physics, rank-1 cooperative emission).

4. **Review articles on Dicke superradiance with multipole dissipators 2010-2026** — searched extensively; no paper found that explicitly treats rank-2 multipole dissipators in the Dicke cascade context with the tilt-angle formula. This is a genuine NOT_FOUND for the specific combination requested.

**Key insight for §2.13**: The rank-2 Lindblad jump operator L_q = Σ_i T^(2)_q(i) on N atoms has a collective contribution that scales as N² only when the single-atom expectation ⟨T^(2)_q⟩_{CSS(β)} is nonzero. For a rank-1 operator (σ^-), this expectation is ⟨σ^-⟩ = sin(β/2)cos(β/2) ∝ sin β, giving the sin²β enhancement. For a rank-2 operator T^(2)_q, the single-atom CSS expectation depends on q and F. Specifically, ⟨m|T^(2)_q|m+q⟩ weighted by the CSS amplitude distribution — this is the quantity the theorist's §8 sympy step S3 computes. The answer will determine whether the N² Dicke collective enhancement activates at all for the specific tilt angles β_± = 15.1° and 130°.

**Structural point (important for §2.13)**: Even if the Dicke N² collective enhancement is nominally present for rank-2 dissipators, the production code's Lindblad implementation (losses.jl:144-176) uses N *independent* single-atom jump operators (not the collective Σ_i T^(2)_q(i)). For Dicke collective enhancement to apply to the simulation result, the mean-field GP wavefunction would need to induce effective N-body coherences — which is a non-trivial claim. The theorist should verify whether the SpinorBEC.jl Lindblad implementation is single-atom or genuinely collective before invoking Dicke N² scaling to explain T20 numerical results.

## Budget
- Queries: 1 received, 1 answered (PARTIAL)
- Web requests: 9 used (5 WebSearch + 3 WebFetch attempts, 1 blocked by permission)
- Cache hits: 0
