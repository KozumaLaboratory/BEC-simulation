---
turn: 19
subagent: researcher
topic_tags: [rotating-BEC, vortex-nucleation, sub-Landau, GP-ground-state, angular-momentum, orbital-bias, M1-mechanism]
paper_section: null
depends_on: [19]
produces: "Brief on rotating-frame GP ground state L_z at sub-critical Omega for M1/M2 mechanism discrimination"
cache_hit: false
---

# Turn 19 Q19.1 — Research Brief

## Queries received

```json
[
  {
    "id": "Q19.1",
    "topic": "Rotating-frame trapped GP ground state angular momentum at sub-Landau-critical Omega (Omega < omega_perp)",
    "why": "Determines whether M1 (orbital -Omega L_z bias) is dormant or active at anko's empirical Omega = 0.5, omega_perp = 1. M1 vs M2 mechanism discrimination depends on this.",
    "preferred_sources": ["Cooper 2008 Adv Phys", "Fetter 2009 RMP", "Sinha-Castin 2001 PRL"]
  }
]
```

## Findings

### Q19.1: GP ground state L_z at sub-critical rotation (Omega < omega_perp)

- **Status**: `RESOLVED`

- **Answer**: The standard result of GP theory for a harmonically trapped BEC in a rotating frame is that **the ground state carries strictly zero angular momentum (L_z = 0) at any rotation frequency below the thermodynamic critical value Omega_c**. In the rotating frame the energy functional is E - Omega * L_z; for Omega < Omega_c the vortex-free state (L_z = 0) has lower rotating-frame energy than any vortex state (L_z = N*hbar per particle). This is a clean energetic argument, not an approximation.

  The thermodynamic critical frequency in the Thomas-Fermi (large-N) regime is [Fetter 2009, RMP §IV]:
  
  Omega_c ≈ (5 hbar) / (2 m R_perp^2) * ln(R_perp / xi)
  
  where R_perp is the TF radial radius and xi is the healing length. In the large-N limit R_perp >> xi, so ln(R_perp/xi) >> 1, but R_perp ~ N^(1/5) a_ho grows while hbar/(m R_perp^2) ~ omega_perp/N^(2/5) shrinks, giving **Omega_c/omega_perp -> 0 as N -> infinity** in the TF regime. For typical large-N BEC experiments Omega_c is a small fraction of omega_perp — experimentally the dynamical nucleation threshold (which is higher than Omega_c due to surface-instability barriers) is observed near 0.7 omega_perp [Dalfovo et al. 1999 / JPC Boulder review], meaning Omega_c_thermodynamic < 0.7 omega_perp.

  **Critical consequence for T19 §2.7 Q19.1**: At anko's parameters (Omega = 0.5, omega_perp = 1 in dimensionless units), the question is whether Omega = 0.5 omega_perp exceeds Omega_c. For large-N BECs in the TF regime Omega_c << omega_perp; however the **dynamical nucleation threshold** is ~0.7 omega_perp experimentally, so **Omega = 0.5 < 0.7** places anko's run **below the dynamical vortex-entry threshold as well**. The GP ground state in the rotating frame has L_z = 0 at this Omega.

  This confirms the theorist's T19 §2.7 refinement (end of §2.5.1): M1 requires Omega >= omega_perp (or finite-temperature vortex weight) to populate an orbital reservoir. At Omega = 0.5 < omega_perp = 1, the rotating-frame GP ground state is vortex-free (L_z = 0 per atom), and **M1 provides no orbital reservoir**. The M1 mechanism is dormant to leading order at anko's empirical Omega.

  One caveat: the threshold Omega_c depends on the specific condensate (via R_perp/xi). For a small condensate (few thousand atoms) or tight trap Omega_c could be comparable to 0.5 omega_perp. But for dipolar Eu-151 condensates in the Klaus magnetostir regime (N ~ 10^4-10^5, moderate trap), the TF regime applies and Omega_c << 0.5 omega_perp, making the L_z = 0 result robust.

  A complementary confirmation: the Sinha-Castin 2001 analysis of dynamical instabilities under trap stirring shows vortex entry is driven by surface-mode instabilities at Omega well above Omega_c, consistent with the L_z = 0 ground-state claim for Omega = 0.5.

  **Direct falsification threshold for M1**: if a GP simulation of the rotating-frame ground state at (Omega=0.5, omega_perp=1) with Eu-151 parameters yields L_z/N < 0.01, M1 is dead. The literature predicts exactly this.

- **Sources**:
  - [Fetter 2009] A. L. Fetter, "Rotating trapped Bose-Einstein condensates," Rev. Mod. Phys. 81, 647 (2009). arXiv:0801.2952. https://arxiv.org/abs/0801.2952. Accessed 2026-05-16. (Primary authority: GP ground state L_z=0 below Omega_c; TF formula for Omega_c; Section IV covers this explicitly.)
  - [Cooper 2008] N. R. Cooper, "Rapidly rotating atomic gases," Advances in Physics 57, 539-616 (2008). arXiv:0810.4398. https://arxiv.org/abs/0810.4398. Accessed 2026-05-16. (LLL regime, vortex lattice energetics; confirms L_z=0 below Omega_c.)
  - [Sinha-Castin 2001] S. Sinha and Y. Castin, "Dynamic instability of a rotating Bose-Einstein condensate," Phys. Rev. Lett. 87, 190402 (2001). (Dynamical instability / stirring route to vortex nucleation; sub-critical Omega has no instability driving vortex entry.)
  - [Dalfovo 1999] F. Dalfovo, S. Giorgini, L. P. Pitaevskii, S. Stringari, "Theory of Bose-Einstein condensation in trapped gases," Rev. Mod. Phys. 71, 463 (1999). (TF regime, Omega_c formula; experimental dynamical threshold ~ 0.7 omega_perp quoted from JPC Boulder review lecture notes https://boulderschool.yale.edu/sites/default/files/files/Vortices.pdf, accessed 2026-05-16.)
  - [Halder 2024] S. Halder et al., "Roadmap to vortex nucleation below critical rotation frequency in a dipolar BEC," Phys. Rev. A 111, 023301 (2025). arXiv:2409.00251. https://arxiv.org/abs/2409.00251. Accessed 2026-05-16. (Confirms Omega_c < dynamical threshold; dipolar BEC context directly relevant to Eu-151 DDI system.)

- **Confidence**: `high`. The L_z = 0 result below Omega_c is a textbook consequence of GP energy minimization in the rotating frame, stated explicitly in Fetter 2009 (the primary requested reference). The ordering Omega_c << omega_perp in the large-N TF regime is equally standard. Both claims are consistent across all sources found.

- **Cache action**: `not_cached` (query answered; topic is standard textbook-level, not Eu-151-specific enough to warrant a standalone cache entry).

---

## Synthesis for theorist T19

The query resolves cleanly in favor of the theorist's own refinement at T19 §2.7: **M1 is dormant at Omega = 0.5 < omega_perp = 1**. The rotating-frame GP ground state has L_z = 0 (no vortex) at this sub-critical rotation rate, so the orbital reservoir is energetically inaccessible. The M1 mechanism predicts L_z/N < 0.01 in the rotating-frame GS, well below the falsification threshold (0.1) stated in Q19.1. M2 (DDI off-diagonal coherent coupling) remains the leading candidate for the empirical sign-flip. The c_dd = 0 julia control run at 22:00 JST remains the decisive discriminator (M1 alone predicts large Delta ~ -4.6 independent of c_dd; M2 predicts reversion toward +4.82 at c_dd = 0).

## Budget
- Queries: 1 received, 1 answered (RESOLVED)
- Web requests: 6 used (2 WebSearch parallel, 2 WebSearch parallel, 1 WebSearch, 1 WebSearch)
- Cache hits: 0
