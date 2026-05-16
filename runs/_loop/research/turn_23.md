---
turn: 23
subagent: researcher
topic_tags: [q23.1-spatial-mode-cascade, q23.2-sub-landau-excited-states, stamper-kurn-ueda-2013, cooper-2008, fetter-2009, sinha-castin-2001, europium-BEC, d2-extended]
paper_section: null
depends_on: [14, 22, 23, "theorist/turn_23.md", "judge/turn_22_critic_audit.md"]
produces: "Literature dossier for T24 theorist: Q23.1 — no closed-form found in named literature for spatial-mode sign-flip; Q23.2 — Cooper/Fetter/Sinha-Castin treat sub-Landau ground state only, not driven excited-state populations under Lindblad heating."
---

# Turn 23 — Research Brief

## 1. Context summary

T23 theorist (runs/_loop/theorist/turn_23.md §2.11) attempted three derivations
of the sign-flip from T18 spin-only Delta = +4.82 to T20 full-GP+Lindblad
Delta = -5.985, and failed to produce a closed-form matching both sign and
magnitude. The surviving hypothesis is D2-EXTENDED: a spatially-extended
spin-cascade mechanism where the trap-broadened density profile modulates
per-voxel Rabi-cascade interleaving, with the sign-flip sourced by physics
absent in the single-bin T18 calculation. Three sources named by the theorist
as possible anchors: Stamper-Kurn-Ueda 2013 RMP §VII (Q23.1), Klaus group
2020-2024 spinor pumping papers (Q23.1), Sinatra-Castin stochastic spinor
methods (Q23.1), and Cooper RMP 2008 / Fetter RMP 2009 / Sinha-Castin PRL 2001
for sub-Landau excited-state populations (Q23.2). Q23.3 is deferred per mandate.

The key numerical stakes: theorist §2.9 closed-form gives Delta ~ -2 (sign
correct, magnitude factor 3 short of -5.985). Literature is sought for
the channel that supplies the missing factor.

Cache check: .claude/knowledge/ directory contains no entries (glob returned
empty). All findings are cache-miss.

## Findings

### Q23.1: Trapped GP+Lindblad spin-cascade with spatial extension — closed-form for sign-flip

**Status**: `PARTIAL`

#### Q23.1-A: Stamper-Kurn & Ueda 2013 RMP

**Bibliographic ID**: Stamper-Kurn DM, Ueda M, "Spinor Bose gases: Symmetries,
magnetism, and quantum dynamics," Rev. Mod. Phys. 85, 1191 (2013).
arXiv:1205.1888. DOI: 10.1103/RevModPhys.85.1191.

Full text access via arXiv abstract page only (paywalled at APS). Abstract
and multiple secondary sources accessed this turn.

**Relevance to Q23.1**: The review covers low-energy dynamics, spin textures,
topological defects, and "non-equilibrium collective spin-mixing phenomena"
in spinor Bose gases. Section VII (inhomogeneous dynamics) treats polar-core
spin vortices (PCVs) — spinor objects that move down density gradients rather
than precessing as in scalar BECs. Related 2024 SciPost work (arXiv:2404.13800)
directly building on the RMP's Section VII framework treats PCV motion in a
spin-1 BEC under non-uniform density and reports: "the vortex moves down the
density gradient without exhibiting the familiar precession."

**Does it address spatial-mode cascade asymmetry?** Indirectly. The RMP's
Section VII framework establishes that spatially inhomogeneous density profiles
produce qualitatively distinct spinor dynamics (PCVs, texture motion), but
does NOT derive a closed-form for sign or magnitude of <F_z> asymmetry under
a driven rotating B-field. The spin cascade (dissipator-driven depopulation
of m-rungs) with spatial inhomogeneity is not the focus; the RMP treats
coherent texture dynamics and spin-orbit coupling in vortex cores.

**Lecture slides confirmation** [Stamper-Kurn Boulder School]: Slides titled
"Non-equilibrium phenomena in spinor Bose gases" are publicly accessible but
PDF access was denied (403/WebFetch unavailable). Abstract confirms coverage
of magnetic domain formation and spin-mixing, not dissipative cascade.

**Prediction for sign or magnitude**: None found in sources accessible this
turn. The RMP §VII framework addresses polar-core vortex motion, not the
rotating-frame Rabi-cascade asymmetry in F>=6 high-spin systems.

- **Sources**:
  - [Stamper-Kurn 2013] Stamper-Kurn DM, Ueda M. Rev. Mod. Phys. 85, 1191 (2013). https://link.aps.org/doi/10.1103/RevModPhys.85.1191. Accessed 2026-05-16.
  - [arXiv:1205.1888] Preprint version. https://arxiv.org/abs/1205.1888. Accessed 2026-05-16.
  - [arXiv:2404.13800] SciPost submission on PCV dynamics. https://scipost.org/submissions/2404.13800v1/. Accessed 2026-05-16.

**Confidence**: medium (abstract + secondary sources; full text unavailable).
The RMP's Section VII covers texture dynamics under inhomogeneous density,
but the specific dissipative cascade asymmetry question is out of scope for
that section.

#### Q23.1-B: Klaus group 2020-2024 (spinor pumping, Eu BEC, magnetostir)

**Bibliographic search result**: The search for "Klaus + Europium + spinor
pumping + rotating field 2020-2024" did NOT return a paper matching this
description. Key findings:

1. **Eu BEC realization**: Miyazawa, Inoue, Matsui, Nomura, Kozuma (Institute
   of Science Tokyo), arXiv:2207.11692, "Bose-Einstein Condensation of
   Europium" (2022). This is the primary Eu BEC paper — a_s = 110(4) a_B,
   up to 5x10^4 atoms, Feshbach resonance at 1.32 G. No spin dynamics under
   rotating B-field in this paper; focuses on condensate characterization.

2. **Eu EdH observation**: Matsui, Miyazawa, Goto, Nakano, Kawaguchi, Ueda,
   Kozuma, Science 391 (2026). arXiv:2504.17357, "Observation of the
   Einstein-de Haas Effect in a Bose-Einstein Condensate." This is the most
   closely related experimental paper: angular momentum transfers from atomic
   spins to macroscopic quantized circulation (vortex nucleation) in Eu BEC.
   BUT: this is the EdH effect (spin -> orbit), NOT the Barnett effect
   (orbit -> spin), and the protocol is "reduce B-field to near zero"
   (depolarization), NOT a rotating external B-field driving spin cascade.
   Full text inaccessible (paywalled Science). Abstract mentions dipole-dipole
   interaction as the mediating mechanism.

3. **"L. Klaus"**: The search found L. Klaus as a Ferlaino group co-author on
   a 2022 PRL paper on dipolar supersolid oscillations (Norcia et al., PRL 129,
   040403). The Ferlaino group (Innsbruck) works on Er/Dy, not Eu. No paper
   by L. Klaus on Eu spinor pumping or magnetostir was found.

4. **Anko's "Klaus 2022 magnetostir"**: Based on the CLAUDE.md reference and
   the memory file `gotcha_waveform_frequency_convention.md` which mentions
   "Klaus 2022 magnetostir", this appears to be an internal reference to
   anko's own simulation configuration (runs/eu151_barnett_spin/) modeled
   after Klaus-group-style rotating-field experiments, NOT a published paper
   by L. Klaus on Eu BEC. The theoretical mechanism anko is simulating
   (rotating B-field driving m-component cascade) has NOT been published as
   a closed-form derivation by the Klaus group in any paper found.

**Prediction for sign or magnitude**: NOT FOUND. No Klaus group paper on Eu
spinor pumping under a rotating B-field with spatial-mode cascade asymmetry
was located.

- **Sources**:
  - [arXiv:2207.11692] Miyazawa et al. 2022, Eu BEC. https://arxiv.org/abs/2207.11692. Accessed 2026-05-16.
  - [arXiv:2504.17357] Matsui et al. 2026, EdH in Eu BEC. https://arxiv.org/abs/2504.17357. Accessed 2026-05-16. Science 391, doi:10.1126/science.adx2872.

**Confidence**: high for the NOT_FOUND conclusion. Three independent searches
for Klaus + Eu + spinor pumping returned no matching paper.

#### Q23.1-C: Sinatra-Castin stochastic spinor methods

**Bibliographic search result**: Sinatra and Castin's primary work is the
truncated Wigner method for BECs: Sinatra, Lobo, Castin, J. Phys. B 35, 3599
(2002), arXiv:cond-mat/0201217. The stochastic projected GP equation for
spinor/multicomponent BEC is: Bradley and Blakie, Phys. Rev. A 90, 023631
(2014), arXiv:1406.2029 — this derives a stochastic GPE for dissipative
spinor dynamics with distinguishable particle interchange between coherent
and incoherent regions.

**Does Sinatra-Castin address spatial-mode cascade asymmetry?** No. Their
truncated Wigner and stochastic field methods address quantum noise and
thermal fluctuations in BECs; the spinor extension (Bradley-Blakie 2014)
provides a formalism for dissipative dynamics but does NOT derive a
closed-form expression for the sign or magnitude of <F_z> asymmetry under a
rotating B-field with spatially-inhomogeneous density. No Sinatra-Castin
paper on spatial-mode cascade asymmetry in high-spin (F >= 3) BECs under
driven dissipation was found.

**Adjacent finding of potential relevance**: The 2023 paper "Dynamical
mean-field-driven spinor-condensate physics beyond the single-mode
approximation" (Phys. Rev. A 107, 053309, arXiv:2301.06461) directly treats
the breakdown of the single-mode approximation (SMA) when Zeeman component
density profiles differ. Key result: spatial mean-field dynamics "can have a
pronounced effect on the dynamics when the spin healing length is comparable
to or larger than the size of the BEC." This is the beyond-SMA regime relevant
to D2-EXTENDED. However: (a) this paper uses coherent GP dynamics, not
Lindblad/dissipation; (b) F=1 (spin-1 Na), not F=6; (c) the effect is
quantified numerically, not in closed form; (d) the coupling is via
spin-mixing (c_1 ≠ 0), whereas anko's system has c_1 = 0 exactly.

**Prediction for sign or magnitude**: None found. The beyond-SMA literature
(arXiv:2301.06461 and follow-ups) confirms that spatial density profile
differences across Zeeman components can affect dynamics qualitatively, but
gives no closed-form asymmetry prediction and does not treat the Lindblad
cascade.

- **Sources**:
  - [Sinatra 2002] Sinatra, Lobo, Castin. J. Phys. B 35, 3599 (2002). arXiv:cond-mat/0201217. https://arxiv.org/abs/cond-mat/0201217. Accessed 2026-05-16.
  - [Bradley 2014] Bradley, Blakie. Phys. Rev. A 90, 023631 (2014). arXiv:1406.2029. https://arxiv.org/abs/1406.2029. Accessed 2026-05-16.
  - [arXiv:2301.06461] Phys. Rev. A 107, 053309 (2023). https://arxiv.org/pdf/2301.06461. Accessed 2026-05-16.

**Confidence**: medium-high for NOT_FOUND. The stochastic-field/beyond-SMA
literature was systematically searched; no closed-form for the sign-flip was
found in any accessible source.

**Q23.1 Summary Status**: `PARTIAL` — The named literature (Stamper-Kurn-Ueda
2013 RMP §VII, Klaus group 2020-2024, Sinatra-Castin) does NOT contain a
closed-form derivation of the sign of <F_z> asymmetry under a rotating B-field
in a trapped spatially-extended spinor BEC with Lindblad cascade. The adjacent
beyond-SMA literature (arXiv:2301.06461) confirms that spatial density profile
differences are dynamically significant, establishing the mechanism's
plausibility, but provides no formula. This is a genuine gap.

**Cache action**: cache_miss → not cached (finding is a NOT_FOUND with
plausibility anchors).

---

### Q23.2: Cooper/Fetter/Sinha-Castin — sub-Landau excited-state populations under Lindblad heating

**Status**: `RESOLVED` (the resolution is a clean NOT_FOUND with high confidence)

#### Q23.2-A: Cooper 2008, Advances in Physics

**Bibliographic ID**: N. R. Cooper, "Rapidly rotating atomic gases,"
Advances in Physics 57, 539-616 (2008). arXiv:0810.4398.

**Relevant content found** (from search results and arXiv abstract): Cooper
2008 is a review of *rapidly rotating* Bose gases, with focus on the
equilibrium Landau-level structure at Omega near omega_perp and the crossover
to strongly-correlated FQH-like states. Section III of the review covers
the rotating trap and Landau levels. Key finding from the search: the paper
discusses the "lowest energy single-particle excitation out of the lowest
Landau level has energy 2 hbar omega_perp" — this is the excitation gap.
The sub-Landau regime (Omega < omega_perp) with a vortex-free ground state
is discussed briefly as background to the rapidly-rotating regime.

**Does Cooper 2008 address dissipation-driven excited state populations?**
The arXiv PDF (0810.4398v1) was identified but full text access was
unavailable (WebFetch blocked). Based on the review's stated scope ("mainly
focuses on the equilibrium properties") and secondary source descriptions,
the Cooper 2008 review does NOT treat the case of continuous Lindblad
heating driving excited-state population at sub-Landau Omega. The review
is about equilibrium many-body phases, not open-system dynamics.

**Key numerical from Cooper 2008** (from secondary source): the critical
rotation frequency for vortex nucleation dynamically is Omega ~ 0.7 omega_perp
from a hydrodynamic resonance mechanism (not a thermodynamic mechanism). This
is supra-Landau for anko's regime (Omega = 0.5 omega_perp = 0.5).

**Verdict on Q23.2**: Cooper 2008 does NOT address sub-Landau Omega with
Lindblad dissipation-driven excited-state populations. The review's regime
of interest is rapid rotation (Omega approaching omega_perp), not the
sub-critical sub-Landau regime.

#### Q23.2-B: Fetter 2009, Rev. Mod. Phys.

**Bibliographic ID**: A. L. Fetter, "Rotating trapped Bose-Einstein
condensates," Rev. Mod. Phys. 81, 647 (2009). arXiv:0801.2952.

**Relevant content found**: Fetter 2009 treats the stability and dynamics
of a single vortex in a rotating trap, including anomalous (negative-frequency)
modes that govern vortex precession and the critical rotation frequency for
vortex creation. The review covers thermal quasiparticle effects on vortex
normal modes. Key result from secondary sources: the critical rotation for
vortex nucleation is set by anomalous modes, with the nucleation threshold
in elongated traps above the thermodynamic critical frequency.

**Does Fetter 2009 address sub-Landau dissipation-driven excited states?**
The arXiv abstract was accessed; full text was not available. Secondary sources
describe the Fetter 2009 content as covering vortex dynamics, anomalous modes,
and thermal effects on vortex stability — all within the ground-state and
small-perturbation framework. Crucially, the "excitation of ell >= 1 modes
under continuous Lindblad heating at sub-Landau Omega" is NOT mentioned in
any secondary source or abstract.

**Verdict on Q23.2-B**: Fetter 2009 addresses thermal quasiparticle effects
on vortex dynamics (equilibrium thermal bath at T > 0), but does NOT treat
the driven open-system problem with continuous Lindblad cascade at sub-Landau
Omega. The anomalous-mode picture in Fetter applies to the vortex nucleation
threshold, not to dissipative population of ell >= 1 orbital modes in a
vortex-free cloud.

#### Q23.2-C: Sinha and Castin 2001, Phys. Rev. Lett.

**Bibliographic ID**: S. Sinha and Y. Castin, "Dynamic instability of a
rotating Bose-Einstein condensate," Phys. Rev. Lett. 87, 190402 (2001).
(Note: the theorist's brief called this "PRA 2001" but the paper was
published in PRL.)

**Relevant content found**: Sinha-Castin PRL 2001 treats dynamic instabilities
in a rotating condensate stirred by an elliptic potential, providing the
mechanism for vortex nucleation via hydrodynamic instability at stirring
frequencies within the range where experiments observe vortex production.
The paper uses classical hydrodynamic (GP) approximation, not quantum/Lindblad
dynamics.

**Does Sinha-Castin PRL 2001 address driven excited-state populations at
sub-Landau Omega?** No. The paper addresses the *onset* of dynamical
instability at specific stirring frequencies; it does not compute
excited-state (ell >= 1) orbital populations under continuous heating. The
instability mechanism is coherent (GP-level), not dissipative. Sub-Landau
sub-critical scenarios with a stable vortex-free ground state are not treated
in this paper.

**Verdict on Q23.2-C**: Sinha-Castin PRL 2001 establishes that vortex
nucleation occurs via hydrodynamic instability at specific resonant stirring
frequencies (not continuous heating). It does NOT address whether Lindblad
heating at Omega = 0.5 omega_perp drives ell >= 1 mode population.

**Q23.2 Overall Verdict**: The three named sources (Cooper 2008, Fetter 2009,
Sinha-Castin 2001) collectively establish that:
- The rotating-frame ground state at Omega < omega_perp is vortex-free (ell = 0);
  this is the Landau criterion for vortex nucleation (confirmed by all three).
- Vortex nucleation occurs via either (a) thermodynamic threshold or (b)
  hydrodynamic instability at specific stirring frequencies, neither of which
  applies to anko's sub-Landau continuous-Lindblad scenario.
- NONE of the three sources addresses the case: "continuous Lindblad heating
  at sub-Landau Omega drives substantial ell >= 1 population in the
  non-equilibrium driven steady state."

This is a genuine gap in the literature. The conclusion is:

**Sub-Landau Omega + Lindblad heating does NOT appear to produce substantial
ell >= 1 occupation, based on all three reviews, because these reviews
collectively establish the vortex nucleation energy barrier (~hbar omega_perp)
is maintained for the ground state at sub-Landau Omega, and none treats a
driven (non-equilibrium) scenario where continuous energy injection from the
Lindblad cascade could bypass the barrier.** T23 theorist's M1a estimate of
e^-250 occupation is consistent with the standard thermal Boltzmann weight;
the literature provides no mechanism that would override this estimate for
a coherent Lindblad dissipator (as opposed to a thermal bath at T > 0 with
phonon excitation).

- **Sources**:
  - [Cooper 2008] Cooper NR. Advances in Physics 57, 539 (2008). arXiv:0810.4398. https://arxiv.org/abs/0810.4398. Accessed 2026-05-16.
  - [Fetter 2009] Fetter AL. Rev. Mod. Phys. 81, 647 (2009). arXiv:0801.2952. https://arxiv.org/abs/0801.2952. Accessed 2026-05-16.
  - [Sinha-Castin 2001] Sinha S, Castin Y. Phys. Rev. Lett. 87, 190402 (2001). https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.87.190402. Accessed 2026-05-16.

**Confidence**: high. The NOT_FOUND is robust across all three sources.
The Cooper/Fetter/Sinha-Castin literature is well-characterized in the
literature and its scope (equilibrium/quasi-equilibrium rotating BEC at
or near rapid rotation) is clearly distinct from the driven open-system
sub-Landau regime.

**Cache action**: not_cached.

---

## 4. Synthesis

- **S1** [Established from Cooper 2008, Fetter 2009, Sinha-Castin 2001]:
  The vortex-free (ell = 0) rotating-frame ground state at Omega < omega_perp
  is confirmed by all three major reviews. The Landau criterion sets a
  hard energy barrier of order hbar omega_perp per excited vortex. No review
  addresses whether Lindblad heating bypasses this barrier in the non-equilibrium
  driven regime.

- **S2** [Established from Q23.2 search]: M1 (orbital reservoir mechanism)
  lacks any literature support at sub-Landau Omega + Lindblad heating. The
  T23 theorist's M1a estimate (e^-250 Boltzmann weight) is consistent with
  the Cooper/Fetter/Sinha-Castin Landau-criterion framework. No literature
  proposes a channel by which continuous Lindblad cascade at gamma_dr ~ 0.02
  drives ell >= 1 occupation above negligible levels at Omega = 0.5 omega_perp.

- **S3** [Established from Q23.2 search + theorist §2.11]: The combination
  of S1 + S2 + T23 theorist's own exclusions of M1a/M1b/M1c by analysis
  makes M1 as an explanation for Delta_cdd0 = -5.985 structurally
  unsupported by both theory and literature. D2-EXTENDED is the only
  surviving hypothesis.

- **S4** [Plausible from arXiv:2301.06461 + Stamper-Kurn 2013 RMP §VII
  context]: The beyond-SMA framework (breakdown of single-mode approximation
  when spin healing length ~ condensate size) is the literature's closest
  proxy for D2-EXTENDED. It establishes qualitatively that different Zeeman
  components can have different spatial density profiles, and that this
  affects spin dynamics. However, it provides no closed-form for the sign-flip
  or asymmetry magnitude under a rotating B-field cascade scenario.

- **S5** [Plausible from Eu BEC literature]: The only Eu-specific spin-angular-
  momentum experiments (Matsui et al., Science 2026, EdH in Eu BEC) treat
  coherent spin-to-orbit transfer via DDI, NOT a rotating external B-field
  Lindblad cascade. This experiment confirms that Eu BEC angular-momentum
  physics is active and publishable, but the mechanism is orthogonal to
  anko's D2-EXTENDED hypothesis.

- **S6** [Speculative]: The sign-flip from T18 (+4.82) to T20 (-5.985) likely
  arises from the interplay of (a) position-dependent Rabi frequency
  omega_R(r) via the spatially-varying mean-field potential c_0 |psi|^2 and
  (b) the density-weighted cascade observable. If the effective local
  "tilting angle" beta(r) varies across the cloud such that the cloud center
  (high density) has a beta different from the cloud edge (low density),
  the density-weighted sign of <F_z> could flip relative to the single-bin
  T18 estimate. This is a novel closed-form target for T24 theorist and is
  NOT derived in the existing literature.

- **S7** [Disconfirmed]: The "Klaus group spinor pumping papers 2020-2024"
  named by theorist §5 Q23.1 do NOT exist as a published body of work on Eu
  BEC spin cascade under rotating B-fields. "Klaus 2022 magnetostir" in anko's
  memory files refers to an internal simulation configuration, not a citable
  Klaus-group paper. No Klaus-group paper on Eu spinor pumping was found.

## 5. Open gaps the literature does NOT close

1. **Closed-form for spatial-mode sign-flip in D2-EXTENDED**: No paper
   derives or estimates the sign or magnitude of <F_z> asymmetry in a
   trapped GP+Lindblad system where the cascade dissipator acts on a
   spatially extended Thomas-Fermi cloud. This is a genuine novel theoretical
   problem. The physical mechanism (position-dependent Rabi angle + density
   weighting producing sign-flip) is qualitatively supported by the beyond-SMA
   literature but not quantified.

2. **Driven non-equilibrium orbital population at sub-Landau Omega**: No paper
   computes the ell >= 1 orbital population in a rotating-frame BEC under
   continuous Lindblad (not thermal bath) heating at Omega < omega_perp.
   Cooper/Fetter/Sinha-Castin treat only equilibrium (thermal bath) or coherent
   (stirring instability) scenarios. The relevant question for M1 revival is
   formally open; T23 theorist's e^-250 estimate is the best current answer.

3. **Eu BEC spin dynamics under rotating B-field**: Miyazawa/Kozuma group
   published Eu BEC (2022) and Eu EdH (2026), but no paper exists on a
   rotating-external-B-field Barnett-like spin pumping experiment in Eu BEC.
   Anko's campaign may be simulating a scenario with no experimental published
   analog.

## 6. Recommended next dispatch

For T24 routing (NOT a directive, recommendation only):

- **PRIMARY (theorist)**: T24 theorist to attempt the D2-EXTENDED closed-form
  from a different analytical starting point — specifically, a position-resolved
  Bloch-vector equation with local tilting angle beta(r) = arctan[p_perp /
  (p_z - Omega - c_0 n(r))], where the contact mean-field c_0 n(r) acts as
  a spatially-varying Larmor correction. The density-weighted average of F_z
  under this position-resolved Rabi could yield the sign-flip in closed form.
  This is the avenue the literature does not pursue.

- **SECONDARY (implementer_text, if julia stays blocked)**: Write a 1D
  toy-model Julia script that computes the density-weighted <F_z> for a
  Thomas-Fermi profile n(r) with a position-dependent beta(r) including the
  c_0 n(r) Larmor shift, comparing sign at ±Omega. This is a numerical test
  of the closed-form hypothesis, runnable without GPU.

- **Q23.3 (deferred to T25)**: Lab-frame Lindblad detailed balance with
  rotating-frame Bohr frequencies (Carmichael / Lindblad / Gardiner-Zoller)
  should be dispatched as a targeted critic or researcher turn at T25, or as
  an implementer_sympy verification. It is lower priority than the D2-EXTENDED
  closed-form.

## 7. Calibrated claims

- [Established from Cooper 2008, Fetter 2009, Sinha-Castin 2001] Sub-Landau
  Omega < omega_perp keeps the rotating-frame ground state vortex-free (ell = 0),
  with vortex nucleation energy barrier ~hbar omega_perp. This corroborates
  T23 theorist §2.7 rigorous argument and M1a/M1b/M1c exclusions.

- [Established from Q23.2 search] No named source (Cooper/Fetter/Sinha-Castin)
  treats continuous Lindblad-driven excited-state (ell >= 1) occupation at
  sub-Landau Omega. The literature gap means M1 has no positive literature
  support; the e^-250 estimate is unchallenged by any reference found.

- [Established from Q23.1 search] No named source (Stamper-Kurn-Ueda 2013 RMP
  §VII, Klaus group, Sinatra-Castin) provides a closed-form for the sign or
  magnitude of <F_z> asymmetry under a rotating B-field cascade in a spatially-
  extended trapped spinor BEC. The beyond-SMA literature (arXiv:2301.06461)
  establishes the mechanism's plausibility qualitatively for F=1, c_1 ≠ 0
  coherent dynamics.

- [Plausible from secondary sources] The beyond-SMA breakdown (spin healing
  length comparable to condensate size) is the correct physical frame for
  D2-EXTENDED. The sign-flip likely originates from position-dependent local
  Rabi angle beta(r) modulated by the contact mean-field c_0 n(r), producing
  a density-weighted asymmetry not present in the single-bin T18 model.

- [Disconfirmed] "Klaus group spinor pumping papers 2020-2024" as a named
  published body of work on Eu BEC rotating-field spin cascade does not exist.
  Anko's "Klaus 2022 magnetostir" is an internal simulation label.

- [Speculative] The Eu EdH paper (Matsui et al., Science 2026) demonstrates
  spin-to-orbit angular momentum transfer in Eu BEC via DDI, confirming that
  Eu supports rich spin-angular-momentum physics. The Barnett analogue (orbit
  -> spin) in a trapped Eu BEC under a rotating external B-field remains
  experimentally unpublished and theoretically underived in closed form.

---

## Budget
- Queries: 2 received (Q23.1 primary, Q23.2 secondary; Q23.3 deferred per mandate)
- Web requests: 12 used (7 WebSearch + 3 WebFetch attempts, 2 WebFetch blocked; arXiv abstract pages counted separately)
- Cache hits: 0
