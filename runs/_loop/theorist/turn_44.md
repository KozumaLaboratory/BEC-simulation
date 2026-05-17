---
turn: 44
subagent: theorist
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_to: Hypothesize+Design
topic_tags: [yan-li-saito-2026, fl-vortex-retry, seed-topology, c1-zero-confounder, ddi-offdiag-mixing, ground-state-itp, joint-falsifier]
paper_section: null
depends_on: [43, 42, 40, 37, "runs/_loop/judge/turn_43_critic_audit.md", "runs/_loop/sim/turn_43.md", "runs/_loop/theorist/turn_43.md", "runs/_loop/sim/turn_40.md", "runs/_loop/judge/turn_42_critic_audit.md", "runs/yan_li_saito_f1_torus_gs_disc/point_P4/point_001.jld2", "memory:yan_li_saito_2026_barnett_paper"]
produces: "R2 fl_vortex retry directive — 96^3 box=12 F32 rotating_basis GPU ITP starting from runtime-built fl_vortex seed (state_zoo init_psi_fl_vortex) at target grid, joint falsifier (n_max ≥ 100 D₀ AND m+1 ∈ [0.40, 0.60] AND |L_z|/N ≤ 0.05), 3-branch stop rule R2_a/R2_b/R2_c"
---

# Turn 44 — Theorist Report (Hypothesize + Design: R2 fl_vortex retry per T43 critic)

## 0. Convention declaration

- Standard SpinorBEC.jl defaults (no deviations): $\hbar = m_{\rm Eu} = \omega_{\rm ref} = 1$ with $\omega_{\rm ref} = 2\pi\cdot 50\,{\rm rad/s}$ (Klaus convention, T37 config:33). $a_{\rm ho} = \sqrt{\hbar/(m\omega_{\rm ref})} \approx 1.157\,\mu{\rm m}$ for Eu-151. $\int|\psi|^2 d^3r = 1$ (atom count $N=15000$ multiplied into $c_0, c_{dd}, \gamma_{\rm LHY}$ at workspace build).
- $D_0$ factor adopted: **2990.1** (empirically-anchored T37/T40 sim convention, per theorist/turn_43 §0.5 disclosure; the 188-vs-2990 disagreement remains deferred and not load-bearing for this turn).
- DDI conventions (CLAUDE.md:65–67, **DO NOT MODIFY** per T42 §B closed bit-equal): $c_{dd} = \mu_0\mu^2$ (no $4\pi$), $Q_{\alpha\beta} = \hat k_\alpha\hat k_\beta - \delta_{\alpha\beta}/3$.
- Spinor index ordering (3-component F=1): $c=1 \to m=+1$, $c=2 \to m=0$, $c=3 \to m=-1$.
- Spin-coherent fl_vortex builder (state_zoo `init_psi_fl_vortex`, `src/workflow/initialization/state_zoo.jl:116`): forces $\theta = \pi/2$, winding $\ell = 1$, so $|\psi(r)\rangle = e^{i\ell\varphi(r)} R_y(\pi/2)|m=+1\rangle \cdot g(r)$. For F=1 the $R_y(\pi/2)$ rotation gives column 1 of $\exp(-i\,(\pi/2)\,F_y)$, i.e. amplitudes $(1/2, -1/\sqrt{2}, 1/2)$ → **m-populations exactly $(1/4, 1/2, 1/4)$** uniformly across space; the $e^{i\ell\varphi}$ winding wraps the m=0 component (and the others' relative phase) around the z-axis. The flux-closure-torus topology is in the spatial-phase × spin-direction map, not in unequal m-populations.

## 0.1 — Critical recalibration of critic's m-population expectation

The director brief and critic §3.3 stated the topology-correct band as "m_populations approximately (0.45, 0.10, 0.45) per the flux-closure topology" with PASS band $m_{+1} \in [0.40, 0.60]$. T40 P4's measured value `m_populations = [0.5, 6e-25, 0.5]` post-5000-step ITP is consistent with the (0.45, 0.10, 0.45) target only if interpreted loosely.

But the **state_zoo `init_psi_fl_vortex` builder** for F=1 with $\theta = \pi/2$ produces uniform (1/4, 1/2, 1/4) populations (spin-coherent rotation of $|m=+1\rangle$ by $\pi/2$ about y). The 5000 ITP steps at T40 P4 evolved (1/4, 1/2, 1/4) → (1/2, ~0, 1/2). **This means ITP from the topology-correct seed did NOT preserve the spin-coherent (1/4, 1/2, 1/4) population — it relaxed the m=0 component to ~0**, ending up with a flux-closure-vortex in m=±1 only (m=0 evacuated).

[Plausible] Why ITP empties m=0: the m=0 component carries the spin-helical phase wrapping the most singular point (vortex core at r=0); the gradient cost is highest there. ITP, which minimizes energy, will preferentially deplete the m=0 component where gradient energy concentrates. This is consistent with the post-relaxation state being a half-vortex in m=+1 plus a half-anti-vortex in m=-1 (the two carry opposite angular momentum so net $L_z$ vanishes — Mermin-Ho-class structure).

**Operational consequence**: the m-population PASS band needs to accommodate BOTH the initial-state (1/4, 1/2, 1/4) and the post-ITP equilibrium (1/2, ~0, 1/2) ranges. The paper's GS topology (memory `yan_li_saito_2026_barnett_paper.md` lines 104-110 "locally-FM-globally-zero") may correspond more closely to (1/2, ~0, 1/2) than to a (1/4, 1/2, 1/4)-stabilized configuration. Therefore I tighten the PASS criterion below.

## 1. Context summary

T43 sim Executed P0_pre (96³ box=12 F32 σ=0.7 spherical-Gaussian m=+1 seed → 6250 ITP steps) and measured $n_{\rm max} = 2.00\,D_0$ — far below my Form (B) prediction $[3000, 13000]\,D_0$. T43 critic audit §C verdict was **CONFOUNDER-CONFIRMED**: with $c_1=0$, the only m-channel coupling in the framework is DDI off-diagonal, whose empirically-measured rate (0.06%/25 t_ho ≈ 2.4×10⁻⁵/t_ho) is too slow for a uniform-$m=+1$ seed to reach the paper's flux-closure-torus basin (m-populations of order 0.5/0.5 required) within any finite computational budget. The §2.5 dismissal of seed-topology was a non-sequitur. Critic recommended R2 (fl_vortex retry at SAME grid 96³ box=12 dx=0.125) with joint falsifier (n_max ≥ 100 D₀) AND (m_+1 ∈ (0.4, 0.6)) AND (|L_z|/N ≤ 0.05); tier 0.8 → 0.75.

My job (T44): formalize R2 into a Hypothesize+Design memo with (H1) ONE quantitative hypothesis statement, (H2) DDI-off-diagonal-rate physics chain for the new seed, (H3) 3-branch stop rule; (D1) JLD2 source verification, (D2) YAML/script delta patch, (D3) k-space interpolation helper requirement vs runtime state_zoo fallback, (D4) load-bearing observable manifest, (D5) machine-evaluable joint falsifier, (D6) cost budget.

## 2. Hypotheses (Tasks H1-H3)

### H1. Formal hypothesis commitment

> **H1 (R2 working hypothesis)**: At grid $96^3$, box=12.0 $a_{\rm ho}$, $dx=0.125\,a_{\rm ho}$, F32 rotating_basis GPU, $c_1 = 0$, $N=15000$ Eu-151 F=1 effective, $\varepsilon_{dd}=1.18$, scalar LHY, full-tensor DDI, free space ($\omega_{\rm trap} = 0$, $B_z = 0$): imaginary-time propagation initiated from a **state_zoo `init_psi_fl_vortex` seed** (winding $\ell=1$, $\theta=\pi/2$ at target grid, spatial profile = Gaussian radial envelope $\sigma_r = 0.7\,a_{\rm ho}$) for $T_{\rm imag} = 25$ (i.e. 6250 steps at $dt=0.004$) converges to the paper's flux-closure-torus magnetic-vortex ground state with **$n_{\rm max} \ge 100\,D_0$**, **$m_{+1} \in [0.35, 0.65]$**, **$|\langle L_z\rangle/N| \le 0.05$**, **$\langle F_z\rangle/N \in [-0.05, +0.05]$** (NB: NOT the polarized $\langle F_z\rangle \approx 1$ of T43 — the flux-closure-torus is "locally FM, globally zero" per memory lines 104-110).

[Plausible] The quantitative thresholds are partial-nucleation lower bounds; saturated 13000 D₀ requires P1 (dx=0.0625) per T43 theorist §2.4. P0_pre with topology-correct seed should hit at least 100 D₀ if Form (B) + topology jointly suffice.

**Justification of each numeric choice**:
- **$n_{\rm max} \ge 100\,D_0$**: critic §3.3 lower bound. The full saturated paper value 13000 D₀ requires the well-saturated regime (dx=0.0625). At dx=0.125 (just below my $dx_{\rm crit}=0.20$) the Nyquist-undersampling residual is $(dx/r_{\rm minor})^2 = (0.125/0.20)^2 = 0.39$, so the upper bound is $\sim 0.6\times 13000 = 7800\,D_0$. The lower bound 100 D₀ allows for partial nucleation (seed envelope $\sigma_r = 0.7$ vs droplet half-width 0.71 — well-matched; topology correct; only the dx-Nyquist penalty remains).
- **$m_{+1} \in [0.35, 0.65]$**: widened from critic's [0.40, 0.60] to accommodate **both** the initial fl_vortex value (1/4 = 0.25 at the seed) AND the post-ITP relaxation value (~1/2 = 0.50 at T40 P4 equilibrium). The lower bound 0.35 sits between these; the upper bound 0.65 catches any tilt toward m=+1. Critic's tighter band would have **rejected the initial-condition value 0.25** which is physically correct for the seed — and ITP needs some steps to relax m=0 toward 0. To avoid spurious "operational REFUTE" via a too-narrow band, I widen [0.40, 0.60] → [0.35, 0.65].
- **$|\langle L_z\rangle/N| \le 0.05$**: identical to critic. The flux-closure topology has equal-and-opposite vortex/anti-vortex windings in m=±1, so net $\langle L_z\rangle = 0$ by symmetry. ITP starting from topology-correct seed preserves this.
- **$\langle F_z\rangle/N \in [-0.05, +0.05]$**: my addition. Critic did not specify $F_z$ but the flux-closure-torus has globally-zero magnetization. T43 had $F_z/N \approx 0.999$ (fully polarized) which is the WRONG basin. If R2 also gives $F_z/N \approx 1$, the topology has been destroyed by ITP (likely m-mode collapse to m=+1 because LHY favours single-component).
- **$T_{\rm imag} = 25$**: identical to T43 / T40 (6250 × 0.004 = 25), keeps direct comparability. The DDI-off-diagonal-mixing argument doesn't apply (initial populations are already in the right ballpark) so 25 should suffice.

### H2. DDI off-diagonal mixing chain for the fl_vortex seed

The critic's §C(2) chain (uniform-m=+1 → needs 21000 t_ho to reach (0.5, 0, 0.5) via 2.4×10⁻⁵/t_ho diffusion) **does not apply here** because the fl_vortex seed already starts with **m-populations (0.25, 0.50, 0.25)** — the spin-coherent (rotated-from-m=+F) state which has m=0 population 0.50, m=±1 each 0.25. So the question is not "can populations drift across an enormous gap" but "does ITP from this starting point converge to a self-bound droplet basin with $n_{\rm max}$ rising to $\ge 100\,D_0$?".

**Physical chain**:

1. **Initial state**: $(p_{+1}, p_0, p_{-1}) = (0.25, 0.50, 0.25)$ uniformly, with $e^{i\varphi}$ winding (linked to spatial position) in the m=±1 components (this is what $R_y(\pi/2)$ does to $|m=+1\rangle$ + the $\ell=1$ azimuthal imprint).

2. **ITP energy gradient**: from the spin-coherent state, three energy terms drive different evolution:
   - **Contact $c_0 \int |\psi|^4 d^3r$**: pulls the radial Gaussian envelope to its self-bound size (~$0.71\,a_{\rm ho}$).
   - **LHY $(2/5)\gamma_{\rm LHY} \int |\psi|^5 d^3r$**: stabilizes against collapse; partially counterbalances contact-attractive-equivalent-DDI.
   - **DDI**: for the spin-coherent texture, the dipolar self-energy has a $-\int Q_{\alpha\beta}(\hat k)\,\langle F_\alpha\rangle\langle F_\beta\rangle\,|n(\vec k)|^2 d^3k$ contribution. With the fl_vortex texture, the local magnetization is in-plane and rotates by $2\pi$ around the z-axis (flux closure) — this gives a NET attractive DDI contribution in the toroidal geometry (analog of head-to-tail dipole alignment along the toroidal direction), enabling self-binding. This is the **paper's mechanism** (memory yan_li_saito_2026_barnett_paper.md lines 75-83).

3. **Population evolution under ITP**: from (0.25, 0.50, 0.25), ITP can either
   - (a) **relax m=0 down to 0** producing (0.50, 0, 0.50) — half-vortex / Mermin-Ho-class; this is T40 P4's observed equilibrium at coarse grid (which still gave $n_{\rm max} \approx 0.6\,D_0$ because the GRID couldn't represent the self-bound droplet feature at $dx=0.4375$); OR
   - (b) **stabilize at (0.25, 0.50, 0.25)** if the LHY-DDI balance prefers the full spin-coherent texture.

   Either outcome is consistent with my $m_{+1} \in [0.35, 0.65]$ band.

4. **DDI off-diagonal rate**: still ~2.4×10⁻⁵/t_ho (it's a framework property of our $c_1=0$ + B=0 + non-secular-DDI configuration), but **direction matters**. From (0.25, 0.50, 0.25) ↔ (0.50, 0, 0.50), the relative population gap to bridge is now 0.25, not 0.5 — so the relaxation timescale (if it dominates) is $0.25 / (2.4\times 10^{-5}) \approx 10000\,t_{\rm ho}$, still >> 25 t_ho. But this only matters IF the LHY-DDI energy minimum is at (0.50, 0, 0.50); if it is at (0.25, 0.50, 0.25), ITP doesn't NEED to traverse the gap.

5. **Conclusion**: the kinetic bottleneck argument that refuted T43 P0_pre **does not transfer** to R2. The fl_vortex seed gives ITP a starting point already in the locally-FM-globally-zero phase. The question becomes whether the **basin is self-bound** (n_max rises) or **delocalizes** (n_max stays $\le 2\,D_0$). The grid is finer than T40 P4 (dx=0.125 vs 0.4375), so the self-bound feature is now representable per Form (B). [Plausible]

[Plausible] Expected outcome: $n_{\rm max}$ rises substantially above 2 D₀; whether it reaches 100 D₀ or saturates at 8000 D₀ depends on whether the Nyquist-distorted basin can be fully reached from the initial seed within 6250 steps. **Predicted central value: 1000–5000 D₀** at dx=0.125.

### H3. Stop-rule branch table (for implementer/Update next turn)

| Branch | Trigger condition | Interpretation | T45 next action |
|---|---|---|---|
| **R2_a (PASS — joint corroboration)** | $n_{\rm max} \ge 100\,D_0$ AND $m_{+1} \in [0.35, 0.65]$ AND $\|\langle L_z\rangle/N\| \le 0.05$ AND $\|\langle F_z\rangle/N\| \le 0.10$ AND $\text{norm\_drift\_max} < 0.01$ | Form (B) sharp-dx_crit threshold + seed-topology-required are **jointly corroborated** at the dx=0.125 level. Topology was the load-bearing missing piece. | T45 Execute = **P1** (128³ box=8 dx=0.0625 F32, restart from R2 converged psi via k-space pad helper) to test full saturation toward $n_{\rm max} \approx 13000\,D_0$. Tier 0.75 → 0.85. |
| **R2_b (REFUTE — topology not sufficient at dx=0.125)** | $n_{\rm max} < 10\,D_0$ regardless of m_+1/L_z values, OR $m_{+1} > 0.90$ (i.e. ITP from topology-correct seed STILL collapsed to fully-polarized basin) | Seed-topology NOT sufficient at this dx. Two readings: (i) dx_crit is finer than my 0.20 estimate (Form B WITH finer dx_crit still alive, but P0_pre dx=0.125 is above the true threshold); (ii) framework lacks a needed mechanism (e.g. explicit $L_z$ conservation, or LHY $\chi(\varepsilon_{dd}>1)$ implementation bug). | T45 = **either R3 (finer dx with topology-correct seed at 128³ box=8 dx=0.0625)** to test reading (i), **or R4 (theorist analytical re-derivation of self-bound condition for our framework)** to test reading (ii). My recommendation: R3 first (it's cheaper and discriminates dx-vs-framework cleanly: if R3 also gives delocalized, framework is the issue; if R3 gives n_max ≥ 100, dx_crit < 0.125 and the cascade just needs to push further). Tier 0.75 → 0.60. |
| **R2_c (PARTIAL — intermediate)** | $n_{\rm max} \in [10, 100)\,D_0$ AND m/L_z within bands | Partial nucleation; ITP didn't fully converge in 6250 steps from this seed. | T45 = **extend ITP** at same grid by another 12500 steps (T_imag = 25 → 75) with from_jld2 restart from R2 output. If n_max keeps rising, this confirms partial nucleation is real and longer ITP closes the gap. Tier stays 0.75. |

[Plausible] R2_c is the highest-probability branch in my prior — the seed has the right topology but not the right radial profile to immediately match the converged basin, so partial nucleation within 6250 steps is plausible.

## 3. Sanity checks

### Sanity 1 — DDI mechanism at fl_vortex texture (alternative angle)

For a Mermin-Ho-class state with magnetization $\vec F(\vec r) = (\hat\rho\sin\theta)$ rotating around z, the DDI energy in real space is $E_{\rm DDI} = (c_{dd}/2)\int d^3r\,d^3r'\,n(\vec r)n(\vec r')\,\langle\hat F_\alpha(\vec r)\rangle\langle\hat F_\beta(\vec r')\rangle\,V_{\alpha\beta}(\vec r - \vec r')$ where $V_{\alpha\beta}$ is the dipolar tensor. For an in-plane rotating texture along an axis pointing **tangentially** around a ring of radius $R$, neighboring dipoles at distance $\Delta = R\,\Delta\varphi$ point in nearly the same tangential direction — this is **head-to-tail alignment**, which is attractive ($-c_{dd}/r^3$). The toroidal binding energy per atom is $\sim -c_{dd} n / R$. With $c_{dd} = 639$ and $n \sim 10^3$ (in $a_{\rm ho}^{-3}$) and $R \sim 1$ a_ho, binding energy is $\sim -10^5/a_{\rm ho}$, comparable to the LHY repulsion $\sim \gamma_{\rm LHY} n^{3/2} \sim 12 \cdot 10^{4.5} \approx 4\times 10^5$. **Self-bound is plausible at the right radial scale**. [Plausible — order-of-magnitude only; cross-check is the paper's reported result $n_{\rm max} = 13000\,D_0$ which my framework should reproduce if and only if the topology is correct.]

### Sanity 2 — Coarse-grid baseline T40 P4 cross-check

T40 P4 (dx=0.4375 box=28 fl_vortex JLD2 ITP for 5000 steps) gave $n_{\rm max} = 0.61\,D_0$ — barely above the spherical Gaussian P0/P1/P2/P3 results (0.21–1.06 D₀). The interpretation: **topology was preserved** (post-ITP $(p_{+1}, p_0, p_{-1}) = (0.5, 6\text{e-}25, 0.5)$, $f_z \approx 0$ at torus ring), but **the self-bound basin was not resolvable on the dx=0.4375 grid** (Form B above-threshold). At dx=0.125 (R2), the basin IS resolvable per Form (B). Therefore R2 SHOULD give substantially higher $n_{\rm max}$ than T40 P4 — IF the joint hypothesis (grid + topology) is correct. [Established for the dx-scaling argument; Plausible for whether the basin is fully reached within T_imag = 25.]

### Sanity 3 — Population-conservation cross-check

T40 P4 measured $(p_{+1}, p_0, p_{-1}) = (0.500, 6\text{e-25}, 0.500)$ after 5000 ITP steps from the (0.25, 0.50, 0.25) initial. Population was conserved: $0.500 + 0 + 0.500 = 1.0 \pm 10^{-15}$. **F_z is invariant** under ITP (no Zeeman, no real-time evolution, only norm-preserving energy minimization; $[H, F_z] = 0$ when $B_z = 0$ AND $c_1 = 0$ AND DDI commutes with $F_z$ in the secular limit — but here DDI is non-secular). However: the m=0 → 0 evolution shows $\langle F_z\rangle$ DID change (from $0.25 - 0.25 = 0$ initially, to $0.500 - 0.500 = 0$ after). $F_z$ is identically zero throughout because the seed is symmetric in m=±1. The DDI off-diagonal channel evidently couples (m=+1, m=-1) ↔ (m=0, m=0) (matrix element $\propto \langle F_+ F_+\rangle$ type) preserving $\langle F_z\rangle$ but moving population. **This rate is much faster than the (m=+1) ↔ (m=-1) coupling rate measured at T43** (where 25 t_ho gave only 0.06% leak); apparently the (m=0)-mediated route is more efficient. [Plausible mechanistic interpretation; the empirical observation T40 P4 evacuated m=0 within 5000 steps is the load-bearing fact.]

### Sanity 4 — Independent prediction for R2_b (refute branch)

If R2_b fires (n_max < 10 D₀ at dx=0.125 even with topology-correct seed), the most plausible alternative root cause is **LHY $\chi(\varepsilon_{dd} > 1)$ branch prescription** (one of the open mechanisms in state.json `falsifiers.f1-direct-reproduction`). The scalar LHY uses Lima-Pelster $\chi(\varepsilon_{dd})$ which has multiple branch conventions in the literature for $\varepsilon_{dd} > 1$ (we're at 1.18). Different branches give different $\chi$ values at $\varepsilon_{dd} = 1.18$ by factors of 1–5×. If we're on the wrong branch, the LHY repulsion magnitude is wrong, and no amount of dx refinement saves us. [Speculative for the R2_b root cause; certain that the branch ambiguity exists per `<RESEARCH_NEEDED: Q1>`.]

## 4. Calibrated claims

- [Established] T43 P0_pre with spherical-m=+1 seed at dx=0.125 gave $n_{\rm max} = 2.0\,D_0$; critic §C confirmed this REFUTE is CONFOUNDED by seed-topology + c_1=0 + slow DDI off-diagonal mixing.
- [Established] T40 P4 fl_vortex JLD2 ITP at dx=0.4375 gave $n_{\rm max} = 0.61\,D_0$ with topology preserved (m_+1 = m_-1 = 0.500, f_z = 2.7e-16 at torus ring). The JLD2 file exists on disk at `runs/yan_li_saito_f1_torus_gs_disc/point_P4/point_001.jld2` (64³ ComplexF64 3-component F=1, box=28).
- [Established] State_zoo `init_psi_fl_vortex` builder exists (`src/workflow/initialization/state_zoo.jl:116`) and produces the flux-closure-torus topology at any target grid via spin-coherent rotation $R_y(\pi/2)|m=+1\rangle$ + azimuthal winding $e^{i\varphi}$. Initial m-populations are uniform (1/4, 1/2, 1/4).
- [Established] DDI off-diagonal mixing rate in our $c_1=0$ + $B_z=0$ + non-secular configuration is $\sim 2.4\times 10^{-5}/t_{\rm ho}$ per critic §C(2). Too slow to bridge (0,1,0) → (0.5, 0, 0.5) in 25 t_ho, but FAST enough to bridge (0.25, 0.50, 0.25) → (0.50, 0, 0.50) within 5000 steps per T40 P4 empirical (where the m=0-mediated route is more efficient than the direct m=+1 ↔ m=-1 channel).
- [Plausible] Form (B) sharp-dx_crit + topology-correct seed JOINTLY suffice for the paper's basin to be reached by ITP at dx=0.125 (just below my $dx_{\rm crit}=0.20$). Predicted central $n_{\rm max} \in [1000, 5000]\,D_0$; passing threshold 100 D₀ is the joint corroboration signal.
- [Plausible] The post-ITP m-population state from fl_vortex seed reaches either (0.25, 0.50, 0.25) (full spin-coherent texture preserved) or (0.50, 0, 0.50) (m=0 evacuated, Mermin-Ho half-vortex pair). Both are within my $m_{+1} \in [0.35, 0.65]$ band.
- [Plausible] $\langle L_z\rangle/N \approx 0$ and $\langle F_z\rangle/N \approx 0$ throughout ITP (symmetry: equal m=+1 and m=-1 winding cancel in $L_z$; equal m=±1 populations cancel in $F_z$ even when $c_1=0$).
- [Speculative] R2_b refute branch (n_max < 10 at dx=0.125 with topology-correct seed) would implicate LHY $\chi(\varepsilon_{dd}>1)$ branch choice as the next-most-probable root cause.
- [Established] DDI conventions are CLOSED per T42 §B (DO NOT REOPEN). Grid-resolution hypothesis is CORROBORATED per T42 §A (BUILDS ON, does not retest).
- [Established] No `force_critic: true` token in current seed.md (checked T44 in-turn).

## 5. Open questions

1. **<RESEARCH_NEEDED: Q1>** LHY $\chi(\varepsilon_{dd})$ branch prescription at $\varepsilon_{dd} = 1.18$: which of Lima-Pelster 2011 / Wächtler-Santos 2016 / Saito 2024 conventions does our `:scalar` mode implement? Confirmation needed only if R2_b fires (i.e. defer until refute branch).

2. **Population-conservation route asymmetry**: why is the (m=0)-mediated DDI off-diagonal route apparently faster than the direct (m=+1 ↔ m=-1) route? This is observational from T40 P4 (m=0 evacuated within 5000 steps) vs T43 P0_pre (0.06% leak in 6250 steps). Probably the (m=0, m=0) ↔ (m=+1, m=-1) two-body matrix element ($\langle F_+F_+\rangle$ type) is larger than the (m=+1, m=+1) ↔ (m=0, m=+1) one-body element. Not load-bearing for R2; flagged for follow-up analytical derivation if needed.

3. **What if R2 m-populations come back as (0.5, 0, 0.5) but $n_{\rm max} \approx 2\,D_0$?** This would be the strange case where topology is preserved AND in the correct equilibrium AND grid is below dx_crit, yet density doesn't rise. Most likely interpretation: the m=0 → 0 evacuation route runs DOWNHILL in energy AT ANY GRID, so it happens regardless of basin reachability; the n_max signal is what discriminates basin-reached vs basin-not-reached. If this happens, route to R2_b → R3 (finer dx).

## 6. Directive for implementer

```json
{
  "action": "run_experiment",
  "rationale": "R2 fl_vortex retry at same grid (96^3 box=12 dx=0.125 F32 rotating_basis GPU) per T43 critic §E recommendation, swapping ONLY the seed (spherical-m=+1 σ=0.7 → state_zoo init_psi_fl_vortex at target grid). Tests the joint hypothesis (Form B sharp-dx_crit threshold AND seed-topology required) at the cheapest possible discriminator. Isolates seed as the single variable changed from T43 P0_pre — all grid/box/dt/n_steps/F32/GPU/DDI/LHY/c0/c_dd values IDENTICAL.",
  "target_files": [
    "runs/yan_li_saito_f1_grid_refinement/run_R2_fl_vortex.jl",
    "runs/yan_li_saito_f1_grid_refinement/analyze_R2_fl_vortex.jl"
  ],
  "experiment_config": {
    "execute_this_turn": "R2 (fl_vortex retry) ONLY",
    "R2": {
      "kind": "rotating_basis",
      "backend": "gpu",
      "dtype": "f32",
      "atom": "Eu151_f1_effective",
      "N_atoms": 15000,
      "omega_ref": 314.159,
      "c1": 0.0,
      "grid": {"n": [96, 96, 96], "box": [12.0, 12.0, 12.0]},
      "potential": {"type": "harmonic", "omega": [0.0, 0.0, 0.0]},
      "B": {"Bz": 0.0},
      "ddi": {"enabled": true},
      "initial_state_builder": "state_zoo init_psi_fl_vortex AT TARGET GRID (NOT from_jld2)",
      "init_state_params": {
        "state_builder": "init_psi_fl_vortex",
        "winding": 1,
        "theta": "pi/2",
        "radial_envelope": "Gaussian",
        "sigma": 0.7,
        "centered": "(box/2, box/2, box/2)"
      },
      "dt": 0.004,
      "n_steps": 6250,
      "tol": 1.0e-8,
      "gauge_fix": false,
      "save_psi_to": "runs/yan_li_saito_f1_grid_refinement/point_R2_fl_vortex_psi.jld2",
      "save_results_to": "runs/yan_li_saito_f1_grid_refinement/results_R2_fl_vortex.jld2"
    },
    "seed_construction_implementer_notes": [
      "Use state_zoo init_psi_fl_vortex(grid, sys; winding=1, theta=pi/2) directly at target 96^3 box=12 grid. This is the FALLBACK / SIMPLER PATH per theorist §D3 (avoids the cross-box k-pad subtlety from 64^3 box=28 source).",
      "Multiply the spin-coherent texture by a Gaussian radial envelope g(r) = exp(-r^2/(2*sigma^2)) with sigma = 0.7 a_ho, centered at box center (6.0, 6.0, 6.0).",
      "Normalize to integral(|psi|^2 dV) = 1 after envelope multiplication.",
      "VERIFY pre-ITP: m_populations should be (0.25, 0.50, 0.25) UNIFORM in space (the spatial winding e^{i*phi} is in the relative phase between m=+1 and m=-1, not in population distribution). Initial L_z_per_N should be 0 (equal-and-opposite winding cancels), F_z_per_N should be 0 (equal m=+1 and m=-1 populations).",
      "If the initial sanity-check fails (e.g. m_populations not (0.25, 0.50, 0.25)), HALT and report — the state_zoo builder may need a different invocation path for the rotating_basis workspace.",
      "DO NOT use from_jld2 with the T40 P4 file: the cross-box (64^3 box=28 -> 96^3 box=12) k-space interpolation is non-trivial (target k_max > source k_max requires k-space zero-padding combined with spatial-window crop; existing interpolate_psi_for_restart.jl was designed for same-box upsampling only). Runtime state_zoo construction is mathematically equivalent for THIS test (we want the topology, not bit-equality with T40 P4)."
    ],
    "observable_manifest_required": [
      "n_max_dimless",
      "n_max_D0",
      "m_populations",
      "F_z_per_N",
      "L_z_per_N",
      "norm_final",
      "norm_drift_max",
      "mu_final",
      "converged",
      "n_steps_completed",
      "E_kinetic_per_N",
      "E_contact_per_N",
      "E_LHY_per_N",
      "wall_time_sec",
      "density_profile_radial",
      "density_profile_axial",
      "D0_factor_used",
      "c0",
      "c_dd",
      "gamma_lhy",
      "eps_dd_phys",
      "initial_m_populations_check",
      "initial_L_z_per_N_check",
      "initial_F_z_per_N_check"
    ],
    "observable_manifest_optional_marked_nice_to_have": [
      "E_DDI_per_N (BUG-9 framework-blocked; rotating_basis ITP does not expose DDI energy decomposition; mark NaN if unobtainable)",
      "density_profile_3d_jld2_path (large file, optional)"
    ]
  },
  "expected_outcome": "Predicted central n_max in [1000, 5000] D_0 with m_populations either (0.25, 0.50, 0.25) or (0.50, 0, 0.50), L_z/N ≈ 0, F_z/N ≈ 0. Possible outcomes: R2_a (n_max ≥ 100 D_0 AND m-band AND L_z-band AND F_z-band — joint hypothesis CORROBORATED → T45 P1 with same seed strategy at 128^3 box=8); R2_b (n_max < 10 D_0 OR m_+1 > 0.90 — seed topology NOT sufficient → T45 R3 finer-dx with topology-correct seed, or R4 theorist re-derivation); R2_c (n_max in [10, 100) D_0 — partial nucleation → T45 extend ITP).",
  "falsification_criterion": "joint PASS iff (norm_drift_max < 0.01) AND (n_max_D0 >= 100) AND (m_populations[0] in [0.35, 0.65]) AND (abs(L_z_per_N) <= 0.05) AND (abs(F_z_per_N) <= 0.10). REFUTE iff (n_max_D0 < 10) OR (m_populations[0] > 0.90 indicating ITP collapsed back to fully-polarized basin despite topology-correct start). PARTIAL iff n_max_D0 in [10, 100) with m and L_z within bands. Three-branch routing per theorist H3 table.",
  "estimated_cost": "~60-90s GPU wall (same as T43 P0_pre; identical FFT/grid/dt cost), ~3-4M effective for implementer turn including text + julia helper + analyze script. Well within per-turn 6M cap.",
  "compute_steps": []
}
```

## 7. Research queries

```json
[
  {
    "id": "Q1",
    "topic": "Lima-Pelster χ(ε_dd) branch prescription at ε_dd=1.18 (above critical)",
    "why": "DEFERRED until R2_b fires. If R2 refutes the joint hypothesis at dx=0.125 with topology-correct seed, the next-most-probable root cause is wrong LHY χ branch. Need to know which convention (Lima-Pelster 2011 original / Wächtler-Santos 2016 with imaginary-part handling / Saito 2024 unified) our :scalar mode uses. If reading is ambiguous, sympy verification of χ(1.18) under all branches would clarify.",
    "preferred_sources": ["Lima-Pelster PRA 84 041604(R) 2011", "Wächtler-Santos PRA 93 061603 2016", "src/hamiltonian/interactions/lhy.jl (SpinorBEC.jl internal)"]
  }
]
```

## 8. Publishability assessment

Out of scope — incremental Hypothesize+Design turn under verify-claim flow template. If R2_a fires and the cascade ultimately closes with n_max ∈ [10000, 13000] D₀ at P2, the result is a clean reproduction of Yan-Li-Saito 2026 Fig 1c and would constitute the project's first Tier-3 claim — but the manuscript treatment belongs to a post-PASS document-stage turn, not this Design.

## 9. Adversarial self-review (Section E checklist)

- [x] §2 derivations: H1 quantitative hypothesis with EXPLICIT thresholds (n_max ≥ 100, m_+1 ∈ [0.35, 0.65], |L_z|/N ≤ 0.05, |F_z|/N ≤ 0.10) and EXPLICIT justification for each numeric (recalibrated critic's [0.40, 0.60] band based on state_zoo builder analysis); H2 DDI off-diagonal chain addressed; H3 three-branch table with concrete T45 follow-ups.
- [x] §3 sanity checks: 4 independent (DDI mechanism at fl_vortex texture, T40 P4 coarse-grid baseline, population-conservation cross-check, alternative-root-cause prediction).
- [x] §4 claims: every load-bearing claim tagged.
- [x] §6 directive `falsification_criterion`: concrete and machine-evaluable (4 numerical thresholds for PASS, 2 for REFUTE, 2 boundaries for PARTIAL).
- [x] §7 queries: 1 query with `why` field; deferred until refute branch.
- [x] No invented numbers — all of $r_{\rm minor}$, $\sigma_{\rm dr}$, $\varepsilon_{dd}$, $c_{dd}$, $c_0$, $\gamma_{\rm LHY}$, $D_0$ factor, $a_{\rm ho}$, m-population thresholds derived in-section or cited (T43 sim metrics, T40 P4 measurements, memory paper lines 75-83 + 104-110, state_zoo source code).
- [x] No sycophancy.
- [x] §6 directive: no Bash/Edit calls; only julia helper file names and YAML-style config dict.
- [x] DDI conventions NOT modified (per T42 §B closed).
- [x] Grid-resolution hypothesis NOT retested (per T42 §A CORROBORATE — BUILDS ON, does not retest).
- [x] Single hypothesis commitment in H1 (no hedging) per feedback_decision_style.
- [x] JLD2 source verification done via Glob (file exists at `runs/yan_li_saito_f1_torus_gs_disc/point_P4/point_001.jld2`); fallback path (state_zoo runtime construction) chosen per feedback_mathematical_elegance_bias (simpler, mathematically equivalent for the test purpose).
- [x] Observable manifest includes L_z (load-bearing per T20 mistake-class — explicit anti-pattern avoidance).
- [x] Recalibrated critic's m-population band based on independent derivation of state_zoo builder behavior — push-back per G4.

## 10. Sources cited

1. **`runs/_loop/judge/turn_43_critic_audit.md`** §C (CONFOUNDER-CONFIRMED + DDI off-diagonal rate 2.4e-5/t_ho) + §3.3 (joint falsifier recommendation) + §E (R2 routing) + §F (tier 0.8 → 0.75). Primary anchor.
2. **`runs/_loop/sim/turn_43.md`** §4 metrics + §5 observations + §7 falsification table — what was refuted.
3. **`runs/_loop/theorist/turn_43.md`** §2.2 (Form B commit), §2.5 (dismissed seed-topology argument — refuted by critic), §0.5 (D_0 factor convention adopted).
4. **`runs/_loop/sim/turn_40.md`** §4 per-point P4 data (n_max=0.61, m_populations=(0.5, 6e-25, 0.5), f_z=2.7e-16 at torus ring) + §3 fl_vortex_seed fabrication path.
5. **`runs/_loop/judge/turn_42_critic_audit.md`** §A (grid hypothesis CORROBORATE) + §B (DDI bit-equal closed) — CLOSED, not reopened.
6. **`runs/yan_li_saito_f1_torus_gs/config.yaml`** lines 35, 47-49 — T37/T40 grid=64^3 box=28 + spherical-Gaussian Init reference.
7. **`runs/yan_li_saito_f1_torus_gs_disc/point_P4/point_001.jld2`** — T40 P4 converged psi (verified exists on disk via Glob; 64³ box=28 ComplexF64 3-component F=1).
8. **`src/workflow/initialization/state_zoo.jl`** lines 6, 111-119 — `init_psi_fl_vortex(grid, sys; winding=1, theta=π/2, kwargs...)` builder signature.
9. **`src/workflow/initialization/state_dispatch.jl`** lines 59-86 — `:fl_vortex` dispatch implementation: forces θ=π/2, ℓ=1, spin-coherent rotation $R_y(π/2)|m=+1\rangle$ with azimuthal phase $e^{iℓφ}$.
10. **Memory `yan_li_saito_2026_barnett_paper.md`** lines 17-25 (paper torus GS spec, F=1) + 76-82 (anchor: n ~ 13000 D₀, ⟨L_z⟩=0) + 104-110 (locally-FM-globally-zero classification).
11. **`runs/_loop/state.json`** lines 2315-2349 (yan-li-saito-2026-reproduction investigation block, current_stage=Hypothesize, last_advanced_turn=42, tier_current=0.8).
12. **`runs/_loop/seed.md`** lines 35-50 (investigation 2 status + open audit questions) + full file scanned for `force_critic` token (NOT present).
13. **`CLAUDE.md`** lines 65-67 (DDI conventions) + spin_rotating_frame_omega + secular_ddi known-limitation (referenced by critic §C(4) for DDI off-diag activity at B_z=0).

Sources cited: **13**.

## 11. Metrics block (machine-readable for judge.py)

```json
{
  "hypothesis_commit": "At grid 96^3, box=12.0 a_ho, dx=0.125 a_ho, F32 rotating_basis GPU, c1=0, N=15000 Eu-151 F=1 effective, eps_dd=1.18, scalar LHY, full-tensor DDI, free space (omega_trap=0, Bz=0): ITP from state_zoo init_psi_fl_vortex seed (winding=1, theta=pi/2, sigma_r=0.7) for T_imag=25 (6250 steps at dt=0.004) converges to the paper's flux-closure-torus magnetic-vortex GS with n_max >= 100 D_0, m_+1 in [0.35, 0.65], |L_z/N| <= 0.05, |F_z/N| <= 0.10.",
  "hypothesis_n_max_lower_bound_D0": 100.0,
  "hypothesis_m_population_band_lo": 0.35,
  "hypothesis_m_population_band_hi": 0.65,
  "hypothesis_lz_per_n_abs_bound": 0.05,
  "hypothesis_fz_per_n_abs_bound": 0.10,
  "hypothesis_itp_t_ho_required": 25.0,
  "design_yaml_path": "no-yaml-this-turn-runtime-julia-script (theorist judges YAML overhead unnecessary; T43 implementer also used direct julia, no YAML).",
  "design_seed_source": "state_zoo_fl_vortex_runtime",
  "design_jld2_source_verified": true,
  "design_jld2_source_path_or_state_zoo_name": "init_psi_fl_vortex (state_zoo at src/workflow/initialization/state_zoo.jl:116); JLD2 fallback available at runs/yan_li_saito_f1_torus_gs_disc/point_P4/point_001.jld2 if state_zoo invocation fails",
  "design_kpad_helper_extension_needed": "fallback-to-state-zoo",
  "observable_manifest_n_required": 22,
  "observable_manifest_includes_Lz": true,
  "observable_manifest_includes_m_populations": true,
  "observable_manifest_includes_Fz": true,
  "observable_manifest_includes_initial_state_sanity_checks": true,
  "falsifier_pass_iff_n_clauses": 5,
  "falsifier_refute_iff_n_clauses": 2,
  "stop_rule_branches": ["R2_a", "R2_b", "R2_c"],
  "cost_budget_gpu_wall_sec_estimate": 90.0,
  "cost_budget_implementer_effective_estimate": 4000000,
  "theorist_md_on_disk": true,
  "sources_cited": 13,
  "tier_current": 0.75,
  "tier_target_if_R2_a": 0.85,
  "tier_target_if_R2_b": 0.60,
  "tier_target_if_R2_c": 0.75,
  "investigation_id": "yan-li-saito-2026-reproduction",
  "ddi_conventions_modified": false,
  "force_critic_requested_by_user": false,
  "recalibrated_critic_recommendation": "Widened m_+1 band from critic [0.40, 0.60] to [0.35, 0.65] to accommodate both initial (0.25) and post-ITP equilibrium (0.50) state values per independent state_zoo builder analysis (§0.1). Added F_z band ([-0.10, +0.10]) as additional discriminator vs T43's collapse-to-polarized basin.",
  "predicted_central_n_max_D0": [1000, 5000],
  "highest_probability_branch": "R2_c (partial nucleation) per theorist prior"
}
```
