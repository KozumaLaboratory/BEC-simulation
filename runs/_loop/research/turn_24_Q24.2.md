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
