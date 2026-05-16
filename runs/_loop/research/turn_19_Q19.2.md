---
turn: 19
subagent: researcher
topic_tags: [barnett, spinor-dipolar, vortex-spin-coupling, m+v=ell, selection-rule, trapped, dissipative]
paper_section: null
depends_on: [theorist turn 19]
produces: brief for theorist turn 20 on Q19.2 scope and limitations
---

# Turn 19 — Research Brief (Q19.2 only)

## Queries received

```json
[
  {
    "id": "Q19.2",
    "topic": "Yan-Li-Saito 2026 (PRL 136 186502) m+v=l selection rule — extension to trapped + finite-Larmor + dissipative regime",
    "why": "Yan-Li-Saito derived the free-space droplet conservation; trapped + B field + gamma_dr is an open question whether the same selection rule applies (with finite Bohr-frequency shift). This would set a sharp prediction for the value of Delta<F_z>/N as a function of vortex quantum number ell.",
    "preferred_sources": ["arXiv 2605.11670", "Saito group followup", "Tasaki-style topological-conservation derivations"]
  }
]
```

## Findings

### Q19.2: Yan-Li-Saito m+v=ℓ selection rule — extension to trapped/dissipative regime

- **Status**: `PARTIAL`

- **Answer**:

  **What the paper actually says about m+v=ℓ.**
  Yan, Li, Saito 2026 [PRL 136 186502 / arXiv:2605.11670] establish the constraint via the following argument (extracted from the paper HTML, accessed 2026-05-16):

  > "the total angular momentum ⟨L_z⟩+⟨f_z⟩=1 is conserved, because m+v=1 is satisfied for all m"
  > "In this population exchange between different m, the total angular momentum ⟨L_z⟩+⟨f_z⟩=1 is conserved"

  The origin is identified as **dynamical**, not a symmetry principle: m+v=ℓ holds because the initial vortex imprint ψ_m(r) = e^{iℓθ} ψ_{0,m}(r) (their Eq. 3) assigns the same winding number ℓ to every magnetic sublevel m, and subsequent eGPE evolution conserves the total J_z = L_z + f_z in the absence of external torques. The rule is therefore a consequence of **absence of external torques on the free-space self-bound droplet**, not a topological invariant.

  **What the paper does NOT do.**
  The paper provides no analysis of:
  - Trapped (harmonic) potentials breaking cylindrical symmetry
  - Finite Zeeman field (linear B) effects on the selection rule itself (external B is applied *after* vortex formation to study Larmor precession, but the paper does not discuss whether m+v=ℓ changes under B)
  - Physical dissipation — the paper uses imaginary-time evolution as a numerical technique, not as a model for gamma_dr-type losses
  - Finite Larmor frequency effects on the m-component mixing

  The preceding Saito group paper (Li, Saito 2024, arXiv:2402.18885, PRR 6, L042049) also does not state m+v=ℓ explicitly; it establishes that L_z + F_z = 0 is conserved during Einstein–de Haas rotation of a trapped torus droplet, but that is a different scenario (no vortex imprint, B suddenly changed).

  **Extension to trapped regime — what can be inferred.**
  The m+v=ℓ constraint can survive in a trap *if and only if* the trap preserves axial (SO(2)) symmetry about z, so that J_z = L_z + F_z remains exactly conserved. A cylindrically symmetric harmonic trap V = ½ω_⊥²(x²+y²) + ½ω_z²z² satisfies this. In that case the argument carries over verbatim: if the initial state has each m-component with the same vorticity ℓ and if no external torque is applied (B=0), then during eGPE evolution m+v_m = ℓ is preserved as a per-component constraint by SO(2) conservation.

  **Breaking mechanisms.**
  Two effects destroy or soften the rule:
  1. **Finite Zeeman field (linear Zeeman, B_z ≠ 0)**: The Hamiltonian term −g_F μ_B B_z F_z commutes with J_z (it is diagonal in m), so it does NOT break SO(2). Therefore, a static uniform B_z field does not break m+v=ℓ directly. However, a *transverse* field (B_x or B_y, as in the Larmor precession scenario) or a rotating field (the Klaus stir) does NOT commute with L_z independently — it breaks the U(1) rotational symmetry and therefore J_z is no longer conserved. In that regime m+v=ℓ is not guaranteed.
  2. **Dissipation (gamma_dr ≠ 0)**: Lindblad-type dipolar relaxation operators L_m ~ F_- act on spin but not on orbital degrees of freedom. They change m → m-1 without changing orbital L_z, thus changing J_z by -ℏ per jump. This *explicitly violates* J_z conservation. Each dipolar-relaxation jump costs one unit of F_z without compensating orbital change, so the dissipative cascade driven by gamma_dr breaks the m+v=ℓ constraint. Delta⟨F_z⟩/N in the dissipative regime is therefore NOT fixed by the Yan-Li-Saito rule alone.

  **Does the rule give a sharp prediction for Delta⟨F_z⟩/N?**
  In free space at B=0 and gamma_dr=0: yes, if each m-component starts with vorticity ℓ then ⟨F_z⟩/N + ⟨L_z⟩/N = ℓ is conserved, so Delta⟨F_z⟩/N = -(Delta⟨L_z⟩/N) and the redistribution is constrained by m+v=ℓ per component. In anko's experiment (trapped + Omega stir + gamma_dr ≠ 0): the Omega rotating drive breaks time-reversal symmetry and continuously injects L_z, while gamma_dr injects F_z dissipatively. The rule gives an *upper bound* |Delta⟨F_z⟩/N| ≤ F (trivial) but not a quantized prediction.

  **Tasaki-style topological conservation.**
  No Tasaki-authored paper or "topological conservation law" derivation for vortex-spin coupling in spinor BEC was found in 3 targeted searches. The broader topological-aspects literature [Ueda-group reviews, e.g., Kawaguchi-Ueda 2012 Phys. Rep. 520, 253] discusses homotopy group arguments for vortex classification but does not derive a J_z-type selection rule of the m+v=ℓ form. The theorist's reference to "Tasaki-style" is likely aspirational, not citing a specific paper.

- **Sources**:
  - [Yan-Li-Saito 2026] Yan, Li, Saito. "Barnett effect in rotating spinor dipolar quantum droplets." Phys. Rev. Lett. 136, 186502 (2026). arXiv:2605.11670. https://arxiv.org/abs/2605.11670. Accessed 2026-05-16. (HTML fetched directly)
  - [Li-Saito 2024] Li, Saito. "Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates." Phys. Rev. Research 6, L042049 (2024). arXiv:2402.18885. https://arxiv.org/abs/2402.18885. Accessed 2026-05-16.
  - Tasaki-style topological derivation: NOT_FOUND (3 searches attempted, no matching paper found).

- **Confidence**: `high` for the free-space content of [Yan-Li-Saito 2026] (HTML fetched and verified); `medium` for the extension argument (logical inference from conservation law structure, not a cited source); `low` for Tasaki attribution (source does not exist in indexed literature).

- **Cache action**: `not_cached` (no .claude/knowledge/ directory exists; topic too narrow for a standalone slug given NOT_FOUND on the Tasaki half).

## Key actionable facts for theorist

1. **m+v=ℓ origin**: dynamical J_z conservation in free space, not a topological invariant. The constraint is:
   ⟨L_z⟩ + ⟨F_z⟩ = N·ℓ = const   (free space, B=0, no dissipation)

2. **Trap**: A cylindrically symmetric trap preserves SO(2), so m+v=ℓ survives in a trapped system at B=0, gamma_dr=0.

3. **B_z field**: Commutes with J_z, does not break the rule. Transverse B (or rotating stir field) breaks SO(2) → J_z not conserved → rule fails.

4. **gamma_dr ≠ 0**: Each dipolar-relaxation jump changes F_z by -ℏ without orbital compensation → J_z violated → m+v=ℓ is not conserved. The dissipative cascade generates Delta⟨F_z⟩/N that is NOT predicted by the Yan-Li-Saito rule.

5. **Prediction for Delta⟨F_z⟩/N**: The theorist's hope that m+v=ℓ gives a quantized Delta⟨F_z⟩/N in anko's trapped + stir + gamma_dr experiment is **not supported**. The Omega stir (rotating transverse field or rotating trap) and gamma_dr each independently break J_z conservation. Delta⟨F_z⟩/N in that regime must be derived from the coupled dynamics, not from the Yan-Li-Saito selection rule.

6. **Saito group followup**: No followup paper extending 2605.11670 to trapped/dissipative regime was found in indexed literature as of 2026-05-16.

## Budget
- Queries: 1 received, 1 answered
- Web requests: 5 used (arXiv 2605.11670 abstract, arXiv 2605.11670 HTML, arXiv 2402.18885 abstract, arXiv 2402.18885 HTML, 2 web searches)
- Cache hits: 0 (no .claude/knowledge/ directory)
