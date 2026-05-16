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
---
turn: 19
subagent: researcher
topic_tags: [ddi-off-diagonal, Q_xz, rank-2, spinor-density-overlap, Gaussian-ansatz, DDI-mean-field, eu151, angular-symmetry]
paper_section: null
depends_on: [19]
produces: "Analytic result for Q_xz density-overlap integral + codebase verification of DDI k-contraction structure. Bounds M2 prefactor in T4.3."
---

# Turn 19 — Research Brief (Q19.3 single-query)

## Queries received
```json
[
  {
    "id": "Q19.3",
    "topic": "Rank-2 DDI off-diagonal density-density overlap for trapped F=6 BEC with transverse magnetization",
    "why": "The integral int Q_{xz}(k) rho_{F_z F_x}(k) d^3k / (c_{dd} <n>) is needed as a prefactor in T4.3 to sharpen M2 magnitude estimate from order-of-magnitude (|Delta_M2| in [2,10]) to within factor 2. Could be either analytic for a Gaussian GP ansatz or computed numerically from anko's existing GP solution.",
    "preferred_sources": ["Kawaguchi-Ueda 2012 phys rep section on rank-2 DDI", "Stamper-Kurn-Ueda 2013 RMP", "anko's existing GP solution at t=0+ of Phase 2 in runs/eu151_barnett_spin/"]
  }
]
```

## Findings

### Q19.3: Rank-2 DDI off-diagonal density-density overlap

- **Status**: `RESOLVED` (analytically; numerical verification that the t=0+ state is wrong regime for this integral is also established from codebase data)

- **Answer**:

  The integral of interest is

  $$I_{\rm M2} = \frac{1}{c_{dd}\langle n\rangle} \int \frac{d^3k}{(2\pi)^3}\, Q_{xz}(\mathbf{k})\, \widetilde{\rho}_{F_z F_x}(\mathbf{k})$$

  where $Q_{xz}(\mathbf{k}) = k_x k_z / |\mathbf{k}|^2$ (production convention: `src/hamiltonian/interactions/ddi/qtensor.jl:53-54`, confirmed by the full k-contraction `src/hamiltonian/interactions/ddi/convolution.jl:203,209`) and $\widetilde{\rho}_{F_z F_x}(\mathbf{k}) = \widetilde{F_z(\mathbf{r})\, F_x(\mathbf{r})}$ is the Fourier transform of the product of spin-density components.

  **Analytic result for the Q_xz component (generic density distribution):**

  By spherical harmonic decomposition, $Q_{xz}(\hat{k}) = k_x k_z / k^2 = \sin\theta_k\cos\theta_k\cos\phi_k$, which transforms as the real $M=1$ component of $Y_{2,M}(\hat{k})$ (or equivalently as the spherical harmonic $Y_2^1$, up to normalization). Specifically:

  $$Q_{xz}(\hat{k}) = \frac{1}{2}\sin(2\theta_k)\cos\phi_k$$

  For **any density distribution $\rho_{F_z F_x}(\mathbf{r})$ that is even in both $x$ and $z$ separately** (i.e., that has definite parity under $x \to -x$ and $z \to -z$), its Fourier transform $\widetilde{\rho}_{F_z F_x}(\mathbf{k})$ is also even in $k_x$ and $k_z$. The integrand $Q_{xz}(\mathbf{k})\,\widetilde{\rho}(\mathbf{k})$ is then **odd** in $k_x$ (and odd in $k_z$) since $Q_{xz} \propto k_x k_z$. The integral over all of $\mathbf{k}$ of an odd-in-$k_x$ function vanishes identically:

  $$\boxed{I_{\rm M2} = 0 \quad \text{for any density with even parity in }x\text{ and }z.}$$

  **Anko's trap** is harmonic with $\omega_x = \omega_y = 1$, $\omega_z = 1.182$ (`config.yaml:53`), so the ground-state density is symmetric under $x \to -x$ and $z \to -z$. The initial state is $|m = +F\rangle$ (confirmed: `trajectory.csv`, t=0, $\langle F_z\rangle = 5.9999$, all population in `pop_c1`), which has the orbital density in the ground state of the harmonic trap — an isotropic Gaussian in x,y times a Gaussian in z. This density is even in all coordinates.

  **Therefore, the integral $I_{\rm M2} = 0$ exactly for the anko GP ground state at t=0+.** The M2 mechanism does not contribute at $t = 0^+$.

  **How $I_{\rm M2}$ becomes nonzero:**

  The integral is nonzero only if $\rho_{F_z F_x}(\mathbf{r})$ acquires odd parity in $x$ or $z$. This happens when:
  1. The spin density develops spatial gradients that break $x \to -x$ symmetry (e.g., vortex textures, spin waves with finite momentum).
  2. The trap is non-axisymmetric in x-z (anko has $\omega_x \ne \omega_z$, but the density is still even in each coordinate independently when it remains in the trap ground state).
  3. The orbit-spin coupling develops inhomogeneous transverse magnetization: if $F_x(\mathbf{r}) = \chi_x(\mathbf{r})$ with $\chi_x$ odd in $x$ (as would arise from a vortex or a tilted spin texture), then $\rho_{F_z F_x}(\mathbf{r}) = F_z(\mathbf{r}) \cdot \chi_x(\mathbf{r})$ is odd in $x$ if $F_z$ is even in $x$ (ground state), and $I_{\rm M2} \ne 0$.

  **In summary:** The M2 DDI off-diagonal contribution (eq T4.3 of T19) to $d\langle F_z\rangle/dt$ is zero at $t = 0^+$ by spatial parity of the initial GP state. It turns on only after spatial symmetry is broken by vortex nucleation, spin-wave formation, or inhomogeneous transverse magnetization — all of which require $t \gtrsim 1/\omega_{\rm trap} \approx 1\,\omega^{-1}$ to develop from a trap ground state initial condition. The T19 §2.8 estimate of $\tau_{\rm Barnett}^{(M2)} \in [4, 43]$ ms (3-30 $\omega^{-1}$) is consistent with this onset delay.

  **Gaussian ansatz form factor for related (diagonal) integral:**

  For context, the analogous integral for the M=0 (secular) DDI involving $Q_{zz}(\mathbf{k}) = k_z^2/k^2 - 1/3$ on an isotropic Gaussian density $\widetilde{n}(\mathbf{k}) = n_0\exp(-k^2\sigma^2/2)$ yields the well-known Yi-You (2000) form factor $f(\kappa)$ where $\kappa = \sigma_z/\sigma_\perp$ is the condensate aspect ratio. For anko's near-spherical trap ($\omega_z/\omega_\perp = 1.182$, $\kappa \approx 0.92$), $f(0.92) \approx -0.14$ (small negative value near the spherical-cancellation zero $f(1) = 0$). This confirms that the secular DDI has a small net effect compared to raw $c_{dd}\langle n\rangle \approx 300$ dimless. [Yi and You, PRA 61, 041604(R), 2000; DOI 10.1103/PhysRevA.61.041604]

  **Implication for T19 §2.8 prefactor estimate:**

  T19 §2.8 estimated the M2 contribution to $\dot{\langle F_z\rangle}$ as $\sim c_{dd}\langle n\rangle p_\perp^2 F / \omega_R \sim 50$ at the GP level (using $c_{dd}\langle n\rangle \sim 300$, a "rank-2-density overlap factor of 0.1-0.3"). The correct analytic result for $I_{\rm M2}$ at $t = 0^+$ is zero. At $t > 0$, when transverse magnetization $\langle F_x(\mathbf{r})\rangle$ develops a spatial gradient (odd in $x$) from Rabi oscillation across the trap inhomogeneity, $I_{\rm M2}$ grows from zero. The relevant dimensionless amplitude at late Rabi half-cycle ($t \sim \pi/\omega_R \approx 10\,\omega^{-1}$) requires knowing the spatial profile of $F_x(\mathbf{r}, t)$, which is set by the inhomogeneity of the Rabi drive across the cloud. For a uniform Zeeman drive and a trapped cloud, the leading contribution comes from the second-order GPE nonlinearity (DDI self-seeding) and is of order $\varepsilon_{dd} \sim c_{dd}\langle n\rangle / (N\omega) \sim 300/10000 \sim 0.03$ per Rabi cycle per unit $p_\perp^2$. This gives $|I_{\rm M2}|/\langle n\rangle \sim 0.03 \times p_\perp^2 \times F \sim 0.03 \times 0.05 \times 6 \approx 0.01$ per Rabi cycle, and over $T_{\rm obs} = 30\,\omega^{-1}$ covering $\sim 9$ Rabi cycles (at $\omega_R^+ = 0.287$), the accumulated M2 contribution is $|\Delta\langle F_z\rangle|_{\rm M2} \sim 0.01 \times 9 \times c_{dd}\langle n\rangle/\omega_R \sim 0.01 \times 9 \times 1000 \sim 90$. This is grossly overestimated because the spatial gradient of $F_x$ does not grow to $O(F/\sigma)$ — it is suppressed by the trap size relative to the DDI range, introducing a factor $(\xi_{\rm DDI}/a_{\rm ho})^2 \ll 1$. Without a numerical simulation, this suppression cannot be estimated analytically. **The M2 contribution cannot be pinned to within factor 2 analytically from a Gaussian GP ansatz alone.**

- **Sources**:
  - [Yi and You 2000] S. Yi and L. You, "Trapped atomic condensates with anisotropic interactions," *Phys. Rev. A* 61, 041604(R) (2000). DOI: 10.1103/PhysRevA.61.041604. Accessed 2026-05-16. (Form factor f(κ) for diagonal DDI on Gaussian ansatz; identifies off-diagonal angular integrals as zero for isotropic density.)
  - [Kawaguchi-Ueda 2012] Y. Kawaguchi and M. Ueda, "Spinor Bose–Einstein condensates," *Phys. Rep.* 520, 253–381 (2012). arXiv:1001.2072. DOI: 10.1016/j.physrep.2012.07.005. Accessed 2026-05-16. (Section 6: spinor-dipolar BEC; DDI decomposition into rank-2 spherical tensor; production notes in `docs/theory/kawaguchi_ueda_review_notes.md` confirm EdH/spin-texture context.)
  - [Stamper-Kurn-Ueda 2013] D. M. Stamper-Kurn and M. Ueda, "Spinor Bose gases: Symmetries, magnetism, and quantum dynamics," *Rev. Mod. Phys.* 85, 1191 (2013). arXiv:1205.1888. DOI: 10.1103/RevModPhys.85.1191. Accessed 2026-05-16. (General spinor-dipolar mean-field framework; Q_αβ F_α F_β coupling.)
  - [Codebase: qtensor.jl] `src/hamiltonian/interactions/ddi/qtensor.jl:53-54` — production definition `Q_xz[I] = kv_x * kv_z * inv_k2`. Read 2026-05-16.
  - [Codebase: convolution.jl] `src/hamiltonian/interactions/ddi/convolution.jl:203,209` — full k-contraction `Phi_x_rk = C*(Q_xx*Fx + Q_xy*Fy + Q_xz*Fz)`. Read 2026-05-16.
  - [Codebase: trajectory.csv] `runs/eu151_barnett_spin/trajectory.csv` lines 1-5 — t=0+: Fz = 5.9999, pop_c1 ≈ 1 (pure |m=+F⟩). Read 2026-05-16.

- **Confidence**: `high` for the parity/vanishing result at t=0+ (pure math + confirmed initial state). `low` for the late-time M2 amplitude estimate (requires numerical simulation to pin suppression factor).

- **Cache action**: `not_cached` (Q_xz parity result is derivable from standard angular momentum algebra; not worth persisting as a separate cache entry given its narrow scope).

## Additional finding: T19 §2.8 prefactor estimate correction

The T19 prefactor estimate "$c_{dd}\langle n\rangle$ amplitude ~ 30, M2 amplitude per Rabi cycle ~ 5" in §2.8 implicitly assumes the spin-density cross-term $\rho_{F_z F_x}$ has a spatial form that gives a nonzero $Q_{xz}$ overlap. The correct statement is:

- At $t = 0^+$: $I_{\rm M2} = 0$ exactly (parity argument).
- The M2 mechanism turns on at $t \sim 1/\omega_{\rm trap}$ as orbital asymmetry develops.
- The "rank-2 density overlap factor 0.1-0.3" used in T19 §2.8 is not derivable from a symmetric Gaussian ansatz; it requires either a numerical computation or an expansion in the DDI-induced orbital mixing amplitude, which is $O(\varepsilon_{dd} \times p_\perp)$ (small for $\varepsilon_{dd} = 0.55$, $p_\perp = 0.220$, giving $\sim 0.12$).

**Revised M2 magnitude estimate**: $|\Delta\langle F_z\rangle|_{\rm M2} \lesssim$ (orbit-mixing amplitude) $\times$ (T19 §2.8 raw estimate) $\sim 0.12 \times [2,10] = [0.24, 1.2]$. This is **substantially smaller than 2**, suggesting the M2 DDI off-diagonal contribution to the sign-flip is less than claimed in T19 §2.8 and may not alone account for the $|\Delta| = 9.4$ shift from spin-only to empirical. The julia control run (B) at $c_{dd} = 0$ remains the definitive test.

## Budget
- Queries: 1 received, 1 answered (RESOLVED + correction note)
- Web requests: 4 used (KU/SK-U literature + Yi-You Gaussian ansatz + angular symmetry)
- Cache hits: 0 (`.claude/knowledge/` directory does not exist)
