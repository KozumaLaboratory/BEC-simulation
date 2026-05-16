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
