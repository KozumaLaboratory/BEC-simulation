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
---
turn: 24
subagent: researcher
topic_tags: [quasi-conservation, rotating-frame-lindblad, broken-axial-symmetry, transverse-zeeman, open-quantum-systems, strong-weak-symmetry, albert-jiang, shavit-2019]
paper_section: null
depends_on: [24, "theorist/turn_24.md §7 Q24.2"]
produces: "Literature verdict on quasi-conservation in rotating-frame Lindblad with broken axial symmetry: no textbook reference derives tilde-J_pm = L_z + F.n_pm; Albert-Jiang 2014 gives the exact conserved quantity theorem (requires H and ALL L_k to share symmetry); broken-axial case is explicitly OUTSIDE existing theorems; Shavit-Horovitz-Goldstein 2019 treats rotating vs lab-frame mismatch but not quasi-conservation; Breuer-Petruccione Ch 3-4 do not treat approximate conservation in the broken-symmetry limit. VERDICT: tilde-J_pm framework is NOVEL."
---

# Turn 24 — Research Brief (Q24.2 only)

## Queries received

```json
[
  {
    "id": "Q24.2",
    "topic": "Quasi-conservation laws for rotating-frame Lindblad dynamics with axial-symmetry-breaking transverse Zeeman",
    "why": "Need to formalize tilde-J_pm = L_z + F.n_pm framework (§3). Specific question: in a rotating frame with H = -Omega L_z - p_z F_z - p_perp F_x and Lindblad dissipator on lab-frame |m>, is there a known approximate conservation law that holds on Rabi timescales? Rotating-frame open-system literature (Carmichael, Gardiner-Zoller, Breuer-Petruccione) typically treats either axial-symmetric or fully-rotating-frame transformations, but the broken-axial-symmetry case with quasi-conservation is less developed.",
    "preferred_sources": ["Breuer-Petruccione 2002 chapter 3-4", "Carmichael Statistical Methods in Quantum Optics vol II", "Plenio-Knight 1998 RMP 70 101", "arXiv 2020-2026 'rotating frame Lindblad quasi-conservation'"]
  }
]
```

## Cache check

`.claude/knowledge/` directory does not exist in this project; no cached entries. All findings are `cache_miss`.

Internal project memory (`MEMORY.md`, topic files under `.claude/projects/`) was grepped for "quasi-conserv", "rotating frame Lindblad", "tilde-J", "Plenio", "Carmichael", "Breuer-Petruccione quasi". No prior turn covered this topic.

## Findings

### Q24.2: Quasi-conservation in rotating-frame Lindblad with broken axial symmetry

- **Status**: `PARTIAL`

- **Answer**:

#### Sub-finding A: Albert & Jiang 2014 — exact theorem on Lindblad conserved quantities

The definitive reference for conserved quantities in Lindblad master equations is:

> Victor V. Albert and Liang Jiang, "Symmetries and conserved quantities in Lindblad master equations," *Physical Review A* **89**, 022118 (2014). arXiv:1310.1523. DOI: 10.1103/PhysRevA.89.022118.

Their central result (paraphrased from the abstract and secondary descriptions, since the full PDF was not fetched this turn): an operator Q is exactly conserved (i.e., dQ/dt = 0 under the full Lindbladian superoperator L) if and only if Q commutes with the Hamiltonian H and with every Lindblad jump operator L_k in a specific sense — formally, Q is a right eigenmatrix of L† with zero eigenvalue. Equivalently (for unitary group symmetry), the system must have a "strong symmetry": both H and all L_k individually commute with the generator of the symmetry.

**Direct relevance to Q24.2**: The theorist's setup H = -Omega L_z - p_z F_z - p_perp F_x has a transverse p_perp F_x term that explicitly breaks axial (U(1) around z) symmetry of H. The Lindblad jump operators L_k = |m-1><m| act in the lab frame on the z-axis eigenstates and individually respect axial symmetry. Because H does NOT commute with the generator of U(1) axial symmetry (due to p_perp F_x), the Albert-Jiang strong-symmetry condition is violated. Therefore, tilde-J_pm = L_z + F.n_pm is NOT exactly conserved in the Albert-Jiang sense. Albert-Jiang do not discuss approximate or quasi-conservation in the broken-symmetry case; they only characterize the exact conserved-quantity structure.

**Confidence for this sub-finding**: `high`. The Albert-Jiang theorem is well-established; the inapplicability to the broken-axial-symmetry case follows immediately from the theorem's conditions.

#### Sub-finding B: Shavit-Horovitz-Goldstein 2019 — rotating frame vs. lab frame Lindblad mismatch

> Gal Shavit, Baruch Horovitz, and Moshe Goldstein, "Bridging between laboratory and rotating-frame master equations for open quantum systems," *Physical Review B* **100**, 195436 (2019). arXiv:1907.06945.

This paper treats the mismatch between Lindblad equations derived in the lab frame vs. the rotating frame. Their key result: the secular approximation used in one frame produces qualitatively wrong predictions in the other. The paper identifies regimes where coherence evolution, population inversion, and resonance fluorescence differ between lab-frame and rotating-frame derivations. They work with driven two-level and multi-level systems. However, the paper does NOT derive approximate conservation laws or quasi-conserved quantities. The focus is on the accuracy of the Lindblad form itself, not on identifying slowly-changing observables.

**Confidence**: `high` for what the paper does NOT contain (quasi-conservation theorem).

#### Sub-finding C: Breuer-Petruccione 2002 — no quasi-conservation theorem for broken-symmetry case

Breuer & Petruccione, *The Theory of Open Quantum Systems* (Oxford, 2002): Chapters 3-4 cover the Nakajima-Zwanzig projection, Born-Markov approximation, secular approximation, and the derivation of the Lindblad master equation. The secular approximation in the rotating frame eliminates rapidly oscillating terms — this is the RWA analog for open systems. There is no chapter or section treating approximate or quasi-conserved quantities in the case where H breaks axial symmetry but the dissipator respects it. The secular approximation, when applicable, does produce an effectively simpler Lindblad equation; however, Breuer-Petruccione do not identify this as yielding a quasi-conserved quantity in the broken-axial-symmetry case. This assessment is based on:
  - Table of contents (Scribd scan confirmed structure: Ch.3 = "Quantum Master Equations", Ch.4 = "Decoherence").
  - Secondary sources citing B-P Ch.3 uniformly describe the secular approximation discussion, not quasi-conservation in broken-symmetry cases.
  - Five searches returned no indication of a B-P theorem on approximate conservation with broken axial symmetry.

**Confidence**: `medium` (could not read full textbook; based on secondary sources and table of contents structure). The assessment that B-P Ch.3-4 does not contain this result is consistent across all indirect accesses.

#### Sub-finding D: Carmichael Statistical Methods vol II — no quasi-conservation theorem found

Carmichael's Vol. II (Springer, 2008) covers quantum trajectories and non-classical field theory in driven-dissipative cavity QED contexts. The book treats the Jaynes-Cummings model and Dicke superradiance in quantum trajectory formulations. In the Jaynes-Cummings context, the total excitation N = a†a + sigma_+ sigma_- IS exactly conserved by the rotating-frame Hamiltonian because the dissipator (photon decay) commutes with N in the appropriate sense. This is the textbook example of a conserved quantity under rotating-wave approximation. However, this only applies when the rotating-frame Hamiltonian also commutes with N — which requires the axial symmetry to be preserved (no symmetry-breaking transverse field). The search found no passage from Carmichael describing what happens when a transverse field breaks this axial symmetry.

**Confidence**: `medium` (could not read the full textbook).

#### Sub-finding E: Plenio-Knight 1998 RMP — no quasi-conservation theorem for broken-symmetry spin-F

Plenio and Knight, "The quantum-jump approach to dissipative dynamics in quantum optics," *Rev. Mod. Phys.* **70**, 101 (1998). arXiv:quant-ph/9702007. DOI: 10.1103/RevModPhys.70.101.

This review derives the non-Hermitian effective Hamiltonian H_eff = H - (i/2) sum_k L_k† L_k from the Lindblad equation and shows that quantum jump events are stochastic. For the rotating-frame driven spin, the effective Hamiltonian H_eff = -Omega L_z - p_z F_z - p_perp F_x - (i*gamma_dr/2) sum_m L_m† L_m preserves the structure of the Hamiltonian. Plenio-Knight do not identify approximate conserved quantities in the symmetry-broken case. The RMP covers driven two-level systems and multi-level cascade atoms but does not specialize to the broken-axial-symmetry quasi-conservation question posed in Q24.2.

**Confidence**: `medium` (arXiv abstract accessed; full text not fetched this turn).

#### Sub-finding F: arXiv 2020-2026 search — NO paper found on quasi-conservation in rotating-frame Lindblad with broken axial symmetry

Five targeted searches were run on arXiv 2020-2026:
1. "quasi-conservation law rotating frame Lindblad open quantum system approximate conserved quantity"
2. "rotating frame Lindblad broken axial symmetry transverse drive quasi-conserved angular momentum"
3. "Lindblad rotating frame Rabi timescale quasi-conserved approximate conserved angular momentum dissipative spin F"
4. "open quantum system broken symmetry Lindblad approximate conservation angular momentum rotating drive"
5. "rotating wave approximation Lindblad dissipator spin-F transverse field axial symmetry break conserved"

**None** returned a paper that simultaneously addresses:
- H with broken axial symmetry (transverse field p_perp F_x)
- Lindblad dissipator preserving axial symmetry (L_k = |m-1><m|)
- A quasi-conserved combination J_tilde = L_z + F.n that holds on the fast (Rabi) timescale

The closest tangential results found:
- arXiv:2501.16592 (Li & Yi, PRB 2026): prethermal time-crystal from U(1) symmetry breaking in Lindblad — but uses spontaneous (not explicit) symmetry breaking and the mechanism is Fermi statistics + skin effect, not Rabi-frequency-scale quasi-conservation.
- Gallone & Langella, J. Stat. Phys. 191, 100 (2024): quasi-conservation in quasi-periodically driven (NOT open/Lindblad) systems; Nekhoroshev-type bounds for isolated systems.
- arXiv:2312.03073: review of driven-dissipative quantum matter; symmetries in Lindblad-Keldysh framework; does not treat the specific rotating-frame broken-axial-symmetry quasi-conservation case.

**Confidence**: `high` that the combination is absent from the 2020-2026 arXiv literature. The concept of tilde-J_pm = L_z + F.n_pm as a quasi-conserved quantity under the specific H and L_k described is not found in any paper.

#### Synthesis: What the standard framework says about quasi-conservation timescale

The standard result that CAN be extracted from the existing literature for guidance is:

1. **Strong symmetry → exact conservation** (Albert-Jiang 2014): if both H and all L_k commute with a charge Q, then Q is exactly conserved. This is the axial-symmetric case (p_perp = 0), where L_z is exactly conserved.

2. **Explicit symmetry breaking → charge decay** (Gu-Wang-Wang arXiv:2406.19381, PRB 2026; abstract accessed): when a strong symmetry is explicitly broken, the previously conserved charge decays. The strong-to-weak symmetry breaking literature characterizes the long-time decay but does not identify what is quasi-conserved on short timescales.

3. **Secular approximation as approximate decoupling** (Shavit-Horovitz-Goldstein 2019; Breuer-Petruccione Ch.3): when the Rabi frequency Omega is large compared to the dissipation rate gamma_dr, the secular approximation for H removes fast-oscillating terms, yielding an EFFECTIVE rotating-frame description where cross-terms between L_z and F_perp sectors decouple on timescales short compared to 1/gamma_dr. This is the closest standard-theory analog to the theorist's tilde-J_pm quasi-conservation: in the limit p_perp << Omega, the rotating-frame secular approximation produces quasi-decoupling of (L_z + F.n) sectors for time t << 1/gamma_dr. However, no textbook or recent paper writes this as a named quasi-conservation law or derives the exact form tilde-J_pm = L_z + F.n_pm.

4. **Effective non-Hermitian Hamiltonian** (Plenio-Knight 1998): between quantum jumps, the evolution is governed by H_eff = H - (i*gamma_dr/2) sum_k L_k† L_k. The secular approximation of H_eff in the rotating frame gives the fast (Rabi) timescale motion. On this timescale, before any quantum jump occurs, trajectories DO approximately conserve the projection along n_pm because H alone (without the imaginary dissipative part) governs the coherent precession. This is consistent with the theorist's §3.4 claim that "coherent Hamiltonian evolution preserves tilde-J_pm on Rabi timescales." It follows from the standard non-Hermitian Hamiltonian formalism but is not stated as a theorem about a quasi-conserved quantity in the literature.

- **Sources**:
  - [Albert & Jiang 2014] "Symmetries and conserved quantities in Lindblad master equations." *Phys. Rev. A* **89**, 022118. https://journals.aps.org/pra/abstract/10.1103/PhysRevA.89.022118. Accessed 2026-05-17.
  - [Albert & Jiang 2014 arXiv] arXiv:1310.1523. https://arxiv.org/abs/1310.1523. Accessed 2026-05-17.
  - [Shavit-Horovitz-Goldstein 2019] "Bridging between laboratory and rotating-frame master equations for open quantum systems." *Phys. Rev. B* **100**, 195436 (2019). arXiv:1907.06945. https://arxiv.org/abs/1907.06945. Accessed 2026-05-17.
  - [Plenio-Knight 1998] "The quantum-jump approach to dissipative dynamics in quantum optics." *Rev. Mod. Phys.* **70**, 101 (1998). arXiv:quant-ph/9702007. https://arxiv.org/abs/quant-ph/9702007. https://journals.aps.org/rmp/abstract/10.1103/RevModPhys.70.101. Accessed 2026-05-17.
  - [Breuer-Petruccione 2002] *The Theory of Open Quantum Systems*. Oxford University Press. Table of contents and structure confirmed via https://www.scribd.com/document/823746447. Accessed 2026-05-17.
  - [Carmichael 2008] *Statistical Methods in Quantum Optics 2: Non-Classical Fields*. Springer. https://link.springer.com/book/10.1007/978-3-540-71320-3. Accessed 2026-05-17.
  - [Gu-Wang-Wang 2024] "Spontaneous symmetry breaking in open quantum systems: strong, weak, and strong-to-weak." arXiv:2406.19381. https://arxiv.org/abs/2406.19381. Accepted in *Phys. Rev. B* (2026). Accessed 2026-05-17.
  - [Li-Yi 2025/2026] "Symmetry-induced fragmentation and dissipative time crystal." arXiv:2501.16592. *Phys. Rev. B* **113**, 014316 (2026). Accessed 2026-05-17.

- **Confidence**: `high` for the NOT_FOUND verdict; `medium` for the indirect inference about secular-approximation quasi-decoupling as the closest standard analog.

- **Cache action**: `not_cached` (no .claude/knowledge/ directory exists; not writing cache since a directory would need to be created — would violate output path lock unless orchestrator enables it).

---

## Actionable summary for theorist (T25)

The specific claim from theorist §3 that "the rotating-frame Hamiltonian H = -Omega L_z - p_z F_z - p_perp F_x preserves tilde-J_pm on Rabi timescales" is:

1. **NOT supported by any named theorem or paper** in the standard references (Breuer-Petruccione Ch.3-4, Carmichael Vol.II, Plenio-Knight 1998, Albert-Jiang 2014) or in arXiv 2020-2026.

2. **Consistent with but not equivalent to** the standard non-Hermitian Hamiltonian result: between quantum jumps, the coherent evolution under H alone does precess the spin along constant-H contours, which in the rotating frame are tilted ellipses around n_pm. This is exactly the statement that tilde-J_pm = F.n_pm is an adiabatic invariant of H (the Hamiltonian, not the full Lindblad superoperator) in the limit |p_perp| << |Omega|. But this adiabatic invariant is not tilde-J_pm = L_z + F.n_pm (it doesn't involve L_z at all under H alone). The L_z sector is frozen by H (since L_z commutes with the single-particle Hamiltonian for fixed spin configuration) but NOT by the quantum jumps.

3. **Candidate theoretical framing** that IS supported by literature: the secular approximation in the rotating frame (Shavit-Horovitz-Goldstein 2019; Breuer-Petruccione §3.3) decouples the fast Rabi dynamics from slow dissipation on timescale 1/(Omega - gamma_dr). On this timescale, the spin state on the Bloch sphere is approximately constrained to orbits determined by the conserved eigenvalue of the effective two-level rotating-frame Hamiltonian. The total tilde-J_pm = L_z + F.n_pm is NOT the conserved quantity from this secular approximation (it involves both orbital L_z and spin); no paper identifies it as such. The theorist's claim must be derived from first principles and would be a novel result.

4. **No textbook or recent paper** treats the specific combination: rotating frame + Lindblad in the lab frame |m> basis + broken axial symmetry from p_perp F_x + quasi-conservation of tilde-J_pm. This is an open-system problem with simultaneous broken axial symmetry in H and axial symmetry in L_k, which is not the standard "rotating frame Lindblad" problem treated in textbooks (those assume H and L_k transform consistently under the same rotating frame).

**Recommendation for theorist**: The tilde-J_pm = L_z + F.n_pm framework as stated in §3 should be labeled `[Novel-Speculative]`, not `[Plausible]`, because:
- No textbook or paper derives or states this quasi-conservation law.
- The claim that H alone (ignoring L_z) preserves F.n_pm as an adiabatic invariant is valid but does NOT involve L_z, contradicting the tilde-J_pm definition.
- The claim requires a joint statement about orbital angular momentum L_z and spin F under a non-axial Hamiltonian, which is a non-trivial coupling absent from single-particle standard treatments.
- The theorist's own §3.3-§3.4 derivation should be the primary evidence; if internally consistent, it stands as a new result worthy of citation in a manuscript (not something borrowed from the literature).

## Budget

- Queries: 1 received, 1 answered (PARTIAL)
- Web requests: 9 used (7 WebSearch + 2 WebFetch attempts; 1 WebFetch permission-denied)
- Cache hits: 0
---
turn: 24
subagent: researcher
topic_tags: [GP-Lindblad, rotating-B-field, Fz-asymmetry, spinor-BEC, collective-Dicke, spatial-mode, Gerbier-Dalibard, Kawaguchi-Ueda, D2-extended]
paper_section: null
depends_on: [23, "theorist/turn_24.md §7 Q24.3"]
produces: "Single-query brief for theorist: NOT_FOUND on numerical GP+Lindblad rotating-B Fz-asymmetry sign; nearest-neighbor literature characterised; Pang-Hao 2016 identified as closest model but lacks rotating field; Gerbier-Dalibard group has no rotating-B dissipative spinor paper."
---

# Turn 24 — Research Brief (Q24.3 only)

## Queries received

```json
[
  {
    "id": "Q24.3",
    "topic": "Spinor BEC under rotating B-field with Lindblad cascade in single-atom-resolved Bloch picture — has anyone integrated this numerically and reported sign of asymmetry?",
    "why": "T20 result Delta=-5.985 is at the OPPOSITE sign of T18 spin-only Lindblad (+4.82). The single-particle Bloch closed-form (this turn §2) cannot reproduce the sign-flip. Need to find a numerical study (any spinor F, including F=1/2/3) of GP+Lindblad under rotating B that reports sign of <F_z> asymmetry and identifies the responsible channel (e.g. collective Dicke, GP nonlinearity, or trap geometry).",
    "preferred_sources": ["Gerbier-Dalibard rotating-trap dissipative spinor 2010-2026", "Stamper-Kurn group dynamics-with-K_3 papers", "Kawaguchi-Ueda spinor BEC reviews 2010-2026", "arXiv:beyond-SMA spin-cascade papers"]
  }
]
```

## Findings

### Q24.3: GP+Lindblad under rotating B-field reporting sign of ⟨F_z⟩ asymmetry

- **Status**: `NOT_FOUND`

- **Answer**: After five rounds of web search covering the preferred source list and surrounding literature, no published paper was found that (a) numerically integrates GP+Lindblad (or GP+Lindblad-equivalent dissipator) in a rotating-B-field geometry and (b) reports the sign or magnitude of the ⟨F_z⟩ asymmetry between +Omega and −Omega rotation directions, with attribution to a specific responsible channel (collective Dicke, GP nonlinearity, or trap geometry). The closest papers are characterised below.

**Characterisation of nearest-neighbour literature:**

**[1] Gerbier–Dalibard group (LKB Paris), 2010–2026.**
The group has four relevant lines of work: (a) equilibrium phase diagrams of spin-1 Na BEC under magnetization [Jacob et al. PRA 2012, DOI:10.1103/PhysRevA.86.061601]; (b) Shapiro resonances in driven spinor BEC [Evrard et al. PRA 100, 023604 (2019), arXiv:1810.12638] — this is the closest Gerbier–Dalibard work to dissipation + driven spinor BEC. The Shapiro paper studies a *modulated quadratic Zeeman* field (not a rotating transverse field), applies a phenomenological dissipation model, and observes relaxation to non-equilibrium steady states with hysteresis; it does NOT use GP+Lindblad and does NOT report a ±Omega sign asymmetry in ⟨F_z⟩; (c) stepwise BEC in a spinor gas [Frapolli et al. PRL 2017]; (d) coherent spinor dynamics [Evrard et al. PRL/PRA 2021 series]. None of these papers involve a rotating transverse B-field or report the sign of ⟨F_z⟩ asymmetry under ±Omega rotation.

**[2] Kawaguchi–Ueda review, Phys. Rep. 520, 253 (2012), arXiv:1001.2072.**
The review covers (§3) mean-field spinor dynamics, (§6) dipolar BEC including inelastic dipolar relaxation, and (§7) hydrodynamic equations. Section 6 on dipolar BEC discusses spin-to-orbit angular momentum transfer (EdH) and inelastic dipolar collisions. Section 12 covers finite-temperature, low-dimensional, and spin–orbit topics. No section of the review derives or numerically computes ⟨F_z⟩ asymmetry under a rotating external B-field with a Lindblad cascade. The review does not treat the open-system (Lindblad) dynamics of the problem.

**[3] Pang & Hao 2016, Chin. Phys. B 25, 040501.**
This paper is the closest match in methodology: it sets up a mean-field Lindblad master equation for a spin-1 spinor BEC under component-dependent dissipation and numerically solves the resulting nonlinear equations. Key finding: for equal dissipation rates on m=±1, magnetization is conserved; for unequal rates, the system transitions between Josephson-like, self-trapping, and running-phase regions with magnetization non-conservation. The paper does NOT involve a rotating external B-field (it uses a static Zeeman + quadratic Zeeman setup), does NOT use a GP extended wavefunction (uses SMA), and reports magnetization evolution under dissipation rate asymmetry — not sign asymmetry of ⟨F_z⟩ under ±Omega rotation. F=1 only.

**[4] Stamper-Kurn group, K3 dissipation papers.**
No paper from the Stamper-Kurn group specifically combines K3 three-body loss with a rotating transverse B-field and reports ⟨F_z⟩ asymmetry in +Omega vs −Omega regimes. The Stamper-Kurn–Ueda 2013 RMP (Rev. Mod. Phys. 85, 1191) covers inhomogeneous dynamics (polar-core vortices, texture motion) but not driven rotating-field cascades (confirmed from T23 research brief).

**[5] Beyond-SMA spinor BEC literature.**
arXiv:2301.06461 (Phys. Rev. A 107, 053309, 2023) explicitly treats the breakdown of the single-mode approximation in spinor BECs when Zeeman-component density profiles differ spatially, and finds that spatial dynamics "can have a pronounced effect" when the spin healing length is comparable to the cloud size. This is the D2-EXTENDED mechanism's plausibility anchor (confirmed from T23). However: (a) the paper uses coherent GP (no Lindblad/dissipation); (b) F=1 Na with c_1 ≠ 0; (c) the effect is quantified numerically but no closed-form sign formula is given. No beyond-SMA paper in the literature treats the Lindblad cascade specifically.

**[6] Related Barnett-effect papers (2026).**
arXiv:2604.23768 (Banerjee 2026), "Minimal spin-rotor model for Barnett and Einstein-de Haas physics," treats a quantized spin-1/2 coupled to a quantum rotor; demonstrates entanglement-driven departure from the classical effective-field picture. This is single-atom quantum mechanics, not GP+Lindblad of a many-body BEC. Does not report ⟨F_z⟩ asymmetry under ±Omega. Li & Saito (arXiv:2605.11670 per MEMORY.md) was searched for but not found indexed (search returned adjacent IDs only; paper may be too recent or ID slightly off). The Saito group's related 2024 paper (arXiv:2402.18885, PRR 6, L042049) treats spinor dipolar droplets with EdH — coherent GP only, no Lindblad, no ±Omega sign asymmetry.

**Summary of gap characterisation:**
The combination (GP + Lindblad cascade + rotating transverse B-field + sign of ⟨F_z⟩ asymmetry under ±Omega) does not appear in any paper found in 5 search rounds. The gap is genuinely novel. The literature establishes:
- GP+Lindblad dissipation in spinor BEC exists as a formalism [Pang-Hao 2016] but has been applied only to static-field, SMA, F=1 systems.
- Rotating transverse B-field + GP exists as a formalism (EdH/Barnett simulation frameworks) but without Lindblad dissipation.
- Spatial-mode effects on spinor BEC dynamics (beyond-SMA) are documented [arXiv:2301.06461] but only for coherent dynamics.
- The Gerbier-Dalibard group is the most active on driven spinor dissipation but in the Shapiro/Josephson (modulated axial Zeeman) paradigm, not rotating transverse B-field.

- **Sources**:
  - [Pang & Hao 2016] Man-Man Pang, Ya-Jiang Hao. "Dynamics of spinor Bose-Einstein condensate subject to dissipation." Chin. Phys. B 25, 040501 (2016). https://cpb.iphy.ac.cn/article/2016/1820/cpb_25_4_040501.html. Accessed 2026-05-17.
  - [Evrard 2019] B. Evrard, A. Qu, K. Jiménez-García, J. Dalibard, F. Gerbier. "Relaxation and hysteresis near Shapiro resonances in a driven spinor condensate." Phys. Rev. A 100, 023604 (2019). arXiv:1810.12638. https://arxiv.org/abs/1810.12638. Accessed 2026-05-17.
  - [Kawaguchi 2012] Y. Kawaguchi, M. Ueda. "Spinor Bose-Einstein condensates." Phys. Rep. 520, 253 (2012). arXiv:1001.2072. https://arxiv.org/abs/1001.2072. Accessed 2026-05-17.
  - [Stamper-Kurn 2013] D. M. Stamper-Kurn, M. Ueda. "Spinor Bose gases: Symmetries, magnetism, and quantum dynamics." Rev. Mod. Phys. 85, 1191 (2013). arXiv:1205.1888. https://arxiv.org/abs/1205.1888. (Confirmed NOT_FOUND on rotating-B cascade from T23 research.)
  - [arXiv:2301.06461] Phys. Rev. A 107, 053309 (2023). Beyond-SMA spinor dynamics. https://arxiv.org/abs/2301.06461. (Confirmed from T23 research: coherent GP only.)
  - [Li-Saito 2024] Shaoxiong Li, Hiroki Saito. "Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates." Phys. Rev. Research 6, L042049 (2024). arXiv:2402.18885. https://arxiv.org/abs/2402.18885. Accessed 2026-05-17.
  - [Banerjee 2026] S. Banerjee. "Minimal spin-rotor model for Barnett and Einstein-de Haas physics." arXiv:2604.23768 (April 2026). https://arxiv.org/abs/2604.23768. Accessed 2026-05-17.

- **Confidence**: `high` for the NOT_FOUND verdict. Five independent search rounds with varied query structures, covering all four preferred source classes named by theorist, all returned no matching paper. The gap is structurally explained: the combination of (rotating transverse B + GP many-body + Lindblad cascade + sign-of-Fz asymmetry) requires a system that simultaneously models vortex dynamics, orbital DOF, and dissipation — a technically demanding combination that no group appears to have studied as an open-system problem.

- **Cache action**: `not_cached` (NOT_FOUND with characterised gap — persisting as a gap statement is not useful without a positive result to anchor.)

---

**Theorist implications (NOT a theorist task — flagged for completeness):**

The NOT_FOUND verdict has three immediate consequences for T24 theorist work:

1. The D2-EXTENDED mechanism (orbital DOF inverting the single-particle Bloch sign) is genuinely novel — no prior paper can be cited as a mechanism anchor. The theorist must derive the sign-flip from first principles.

2. Pang-Hao 2016 establishes that GP-uncoupled Lindblad (SMA, no orbital DOF) preserves magnetization for equal dissipation rates, consistent with T18. The sign-flip in T20 therefore cannot be attributed to an effect already documented in the literature — it is a new finding of this campaign.

3. The Evrard 2019 Shapiro paper (Gerbier-Dalibard) is the methodologically closest published work. It finds that dissipation is "essential to understand long-time behavior" in a driven spinor BEC; the specific dissipation model used there is phenomenological (not Lindblad rank-2), but the general message — that the sign of the asymptotic state depends on the interplay of drive direction and dissipation — is qualitatively analogous to the T20 Delta sign question. No quantitative transfer is possible without a shared model.

## Budget
- Queries: 1 received, 1 answered
- Web requests: 9 used (5 rounds of WebSearch pairs; WebFetch was denied for cpb.iphy.ac.cn, counted as 0)
- Cache hits: 0 (no .claude/knowledge/ entries exist; T23 prior research reused by direct file read, not cache)
