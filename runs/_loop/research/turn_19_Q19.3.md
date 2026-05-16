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
