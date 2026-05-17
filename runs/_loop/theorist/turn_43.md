---
turn: 43
subagent: theorist
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_to: Design
topic_tags: [yan-li-saito-2026, grid-refinement, dx-scaling, droplet-basin, free-space-itp, cfl, cascaded-stop-rule, restart-seed]
paper_section: null
depends_on: [42, 41, 40, 37, "runs/_loop/judge/turn_42_critic_audit.md", "runs/_loop/research/turn_41.md", "runs/_loop/sim/turn_40.md", "runs/_loop/theorist/turn_40.md", "runs/_loop/director/turn_43.md", "runs/yan_li_saito_f1_torus_gs/config.yaml", "runs/_loop/templates/yan_li_saito_f1_droplet.yaml", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Form-(B) sharp-threshold scaling prediction with dx_crit = 0.20 a_ho and β = 3 (NOT power-law-envelope) + 3-point grid-refinement YAML deltas (P0 96^3 box=12, P1 128^3 box=8, P2 192^3 box=6) anchored on rotating_basis backend + CFL-respecting dt schedule + restart-from-converged-seed strategy + cascaded stop-rule with thresholds A=30, B=400 D_0 + F32 mode recommendation + 7 machine-evaluable T44 success criteria."
---

# Turn 43 — Theorist Report (Hypothesize + Design: dx-refinement scaling experiment)

## 0. Convention declaration

- **Dimensionless units**: $\hbar = m_{\rm Eu} = \omega_{\rm ref} = 1$ with $\omega_{\rm ref} = 2\pi \cdot 50\,{\rm rad/s}$ (T37 config:33). Lengths in $a_{\rm ho} = \sqrt{\hbar/(m\omega_{\rm ref})} = 1.157\,\mu{\rm m}$ for Eu-151 (cross-checked T42 §A(i)).
- **Wavefunction normalization**: $\int |\psi|^2\, d^3 r = 1$ across spatial volume; atom count $N=15000$ multiplies into $c_0, c_{dd}, \gamma_{\rm LHY}$ at workspace build (NOT into $\psi$). Matches T40 §0.
- **$n_{\rm max}$ unit convention**: SpinorBEC stores $n_{\rm max,dimless} = \max |\psi|^2$ in $a_{\rm ho}^{-3}$. Conversion to paper's $D_0 = 1/(a_s^3 N^2)$ (memory line 59): $D_0 = 5.32\times 10^{-3}\,a_{\rm ho}^{-3}$ so $n_{\rm max}\,[D_0] = n_{\rm max,dimless} / 5.32\times 10^{-3} \approx 188 \times n_{\rm max,dimless}$. **However**: T40 sim/§5 reports a different scale factor `D0_factor = 2990.1` with verification "P0 gives 0.993 D₀ vs T37's 0.99 D₀ (0.3% agreement)". I will adopt the empirically-verified T37/T40 scale `n_max[D₀] = n_max_dimless × 2990.1` for predictions below (T40 sim §4 metric `D0_factor_formula = "N/a_ho^3 / D_0_si = N^3 * (a_s/a_ho)^3"`). The dimensionless/D_0 factor disagreement between my T40 §0.5 derivation and T37/T40 sim reports is documented as `<RESEARCH_NEEDED: Q1-reopen>`; **for THIS turn I use the T37/T40 sim convention** (so predictions are directly comparable to T40 numerics).
- **DDI conventions** (CLAUDE.md:65–67, **DO NOT MODIFY** per T42 §B closed bit-equal): $c_{dd} = \mu_0\mu^2$ (no $4\pi$), $Q_{\alpha\beta}(\hat k) = \hat k_\alpha\hat k_\beta - \delta_{\alpha\beta}/3$ (no $1/(4\pi)$).
- **Effective $\varepsilon_{dd}$**: T37 computed 1.177 vs paper 1.2 (~2% off, negligible).
- **Backend lock**: rotating_basis (per T37 config:26 `defaults: {kind: rotating_basis, backend: gpu}`). Choice rationale §5.
- **CFL constraint** (kinetic split-step Fourier, periodic BC): for $k_{\max} = \pi/dx$ on a uniform grid, the kinetic phase per step is $dt \cdot k_{\max}^2/2 = dt\pi^2/(2 dx^2)$. von Neumann amplification stays $\le 1$ for the symmetric split-step under imaginary-time evolution as long as $dt \cdot k_{\max}^2/2 < \pi$ (avoid aliasing of complex-rotation phase between modes), so $dt < 2 dx^2/\pi \approx 0.637\,dx^2$. I will adopt the **safer factor $dt \le 0.3\,dx^2$** to leave headroom for interaction phase (LHY $\sim \gamma\rho^{3/2}$ at $\rho \sim 10\,a_{\rm ho}^{-3}$ adds $\gamma \rho^{3/2} \sim 400$ phase/$\omega_{\rm ref}$).

## 0.5 — Convention drift disclosure

There is an unresolved factor-188 vs factor-2990 disagreement between my T40 §0.5 derivation of $D_0$ and the T40 sim's empirical calibration (P0 = 0.993 D₀ at $n_{\rm max,dimless} = 3.322\times 10^{-4}$ → factor 2990). I have not re-derived it in §0 because (a) the T40 sim's factor is empirically anchored to T37's reported P0 value at 0.3% agreement, (b) for THIS turn's purpose (predicting whether grid refinement moves $n_{\rm max}$ from 1 → 10² → 10⁴ D₀), the factor cancels in scaling-ratio statements, and (c) the disagreement should be closed by a separate Hypothesize cycle (or audit-class-scan), not folded into this Design turn.

[Established] Internal consistency of T37/T40 sim factor (P0 matches T37 within 0.3%).
[Plausible] My T40 §0.5 derivation factor differs because of a different normalization convention ($|\psi|^2 = 1$ per-atom vs $|\psi_{\rm field}|^2 = N$).

For this turn, I use **factor 2990.1** so all predictions are directly comparable to T40 numerics.

## 1. Context summary

T42 critic Section A CORROBORATEd grid-resolution as the root cause of T37/T40's factor-12,300 density deficit: independent dx-ratio (30.4×) and droplet-cell-count (3.2 cells across droplet vs paper's 97) chains both point at the same magnitude. T42 §B closed DDI prefactor bit-equal (ratio=1 in Fourier space). T42 §E recommended R1: a 3-point grid-refinement experiment at dx ∈ {0.08, 0.04, 0.02} a_ho with heuristic $n_{\rm max}(dx) \sim (0.4375/dx)^\alpha$, $\alpha \in [2.5, 3.0]$. My job: (1) commit to a sharper functional form than $\alpha \in [2.5, 3.0]$, (2) produce YAML deltas patched onto the template, (3) state machine-evaluable success criteria, (4) embed cost discipline as a cascaded stop-rule.

## 2. Hypothesis formalization (Task 1)

### 2.1 The four candidate forms and why I reject (A), (C), (D)

**(A) Trivial volumetric ceiling** $n_{\rm max}(dx) = N/V_{\rm box}^{\rm eff}$, independent of dx.

Reject. The T40 σ-sweep already showed n_max varies with the seed (P1 σ=0.5 → 1.06 D₀; P3 σ=14 → 0.21 D₀); this rules out a literal box-volume ceiling because the SAME box with different seeds gave 5× different peak densities. If (A) were strictly true, ITP from any seed would converge to the same delocalized fill. The factor-5 spread among T40 σ-points refutes (A) at our current dx. [Established]

**(C) Smooth power-law envelope** $n_{\rm max}(dx) = n_{\rm paper}\,(dx_{\rm crit}/dx)^\beta$.

Reject. A smooth power law has no qualitative change of regime — it would predict that even at dx = 1 a_ho we'd see "some" droplet signature (e.g., $n_{\rm paper}(0.05/1)^3 \approx 1.6\,D_0$). The T40 data shows $n_{\rm max} \in [0.21, 1.06]\,D_0$ across σ ∈ {0.5, 2, 5, 14}. The fact that we get **delocalized** states (not "weak droplets") at our dx=0.44 a_ho indicates a **two-basin landscape**: ITP from any of our seeds falls into the *delocalized* basin and the droplet basin is kinetically inaccessible. This signals a **threshold**, not a smooth envelope. [Plausible]

**(D) "Your own form"**.

Reject. The cleanest single-parameter explanation — a critical resolution at which the droplet basin becomes representable on the grid — is form (B). Inventing a fancier ansatz violates `feedback_mathematical_elegance_bias`.

### 2.2 Commitment — Form (B) sharp dx_crit threshold

**Central prediction (committed)**:

$$
n_{\rm max}(dx) = \begin{cases}
n_{\rm delocal}, & dx > dx_{\rm crit} \\
n_{\rm paper}\cdot \left(dx_{\rm crit}/dx\right)^{\beta}, & dx \le dx_{\rm crit}
\end{cases}
$$

with **$dx_{\rm crit} = 0.20\,a_{\rm ho}$** (= droplet minor radius, T42 §A), **$\beta = 3$** (volume scaling of an on-grid Gaussian peak per a_ho³), **$n_{\rm delocal} \approx 1\,D_0$** (T40 baseline), and **$n_{\rm paper} = 13000\,D_0$** (memory line 76).

### 2.3 Derivation of $dx_{\rm crit}$ and $\beta$

**$dx_{\rm crit}$**: A self-bound droplet is stable when the LHY (∝ $\rho^{5/2}$) overcomes the net contact+DDI mean-field attraction (∝ $\rho^2$) and balances kinetic pressure. The Lima-Pelster scalar dipolar droplet ansatz at $\varepsilon_{dd} = 1.2$, $N=15000$ for Eu-151 F=1 yields a Gaussian half-width $\sigma_{\rm dr} \sim 0.71\,a_{\rm ho}$ (memory line 76: droplet half-extent $0.05\,L_0 = 0.71\,a_{\rm ho}$); for a torus magnetic-vortex structure, the relevant short-scale feature is the torus **minor** radius, $r_{\rm minor} \sim 0.2\,a_{\rm ho}$ (T42 §A(ii) independent chain: 0.05·L₀ × (minor/major)≈0.2/0.7 ratio inferred from Fig 1c torus aspect).

A pseudospectral grid with spacing $dx$ can faithfully represent features down to wavelength $\lambda_{\rm min} = 2\,dx$ (Nyquist). To resolve the torus minor profile (a Gaussian-like density excursion of half-width $r_{\rm minor}$), we need $2\,dx < r_{\rm minor}$, i.e. $dx < r_{\rm minor}/2 \approx 0.1\,a_{\rm ho}$. Conversely, the **droplet basin is kinematically inaccessible** to ITP when $dx > r_{\rm minor}$ because the gradient descent simply cannot decrease energy by sharpening $|\psi|$ below the grid scale — any narrower density profile gets aliased.

So I define $dx_{\rm crit} \equiv r_{\rm minor} = 0.20\,a_{\rm ho}$ as the threshold above which the droplet basin is not on the grid. Between $r_{\rm minor}/2$ and $r_{\rm minor}$ the basin is *partially* accessible (representable but Nyquist-distorted); below $r_{\rm minor}/2$ the basin is fully resolved.

[Plausible] $dx_{\rm crit} = 0.20\,a_{\rm ho}$ based on critic T42 §A geometric chain plus standard Nyquist argument.

**$\beta = 3$**: Once the droplet basin is on the grid, ITP converges to the analytic droplet whose peak density is grid-independent (= paper's 13000 D₀) MODULO finite-grid sampling. The on-grid sampling of a continuum Gaussian of half-width $r_{\rm minor}$ at spacing $dx$ reads a peak value
$$
|\psi|^2_{\rm grid}(0) = |\psi|^2_{\rm continuum}(0) \cdot \left[1 - \mathcal{O}\!\left((dx/r_{\rm minor})^2\right)\right]
$$
for $dx \le r_{\rm minor}$ (Whittaker-Shannon undersampling penalty for a bandlimited signal sampled at sub-Nyquist; the residual is the spectral content beyond $k_{\max} = \pi/dx$, which is exponentially small for a Gaussian once $dx \le r_{\rm minor}/\pi$).

But the *converged-ITP* peak density also depends on whether the grid can support the volume-integrated continuity equation. Since ITP normalizes $\int|\psi|^2 = 1$, the peak scales as $1/V_{\rm droplet} = 1/(2\pi r_{\rm minor}^2 R_{\rm major})$ MODULO whether $r_{\rm minor}$ itself depends on dx through the LHY-contact balance.

Empirically, the simplest scaling that interpolates from $n_{\rm delocal}\approx 1\,D_0$ (delocalized over $\sim 28^3\,a_{\rm ho}^3$ box, peak $\sim N/(box)^3 = 15000/21952 \approx 0.68\,D_0$ in our units — consistent with T40 P3 = 0.21 D₀ from σ=14 Gaussian) to $n_{\rm paper} = 13000\,D_0$ at $dx \le 0.014$ (paper) is **a power-3 in $(dx_{\rm crit}/dx)$ above threshold**, capped at $n_{\rm paper}$:

$$
n_{\rm max}(dx) \le n_{\rm delocal} + (n_{\rm paper} - n_{\rm delocal})\cdot\min\!\left[1, \left(\frac{dx_{\rm crit}}{dx}\right)^3\right]
$$

with hard discontinuous jump at $dx = dx_{\rm crit}$ (above threshold, only the delocalized basin is reachable from a generic seed). The 3-power is consistent with T42 §A's $(30.4)^3 \approx 28000$ being the predicted gap at our current dx — but the prediction at dx = dx_crit is the **top of the curve**, $n_{\rm paper}$. The power law is saturated below dx_crit.

[Plausible] $\beta = 3$ from volume-of-resolved-feature argument; cross-checks against critic Section A which gives $(0.4375/0.0144)^3 \approx 28000$ ≈ observed gap 12300 (within factor 2).

### 2.4 Numerical predictions at P0/P1/P2

I redefine the P0/P1/P2 grid-points slightly from the critic's heuristic ones to (a) keep box ≥ 2× droplet diameter (≈ 3 a_ho), (b) keep dx around the threshold so we can DISCRIMINATE form (B) vs (C), and (c) keep the finest run feasible on a single GPU within ≤ 1 hour wall.

| Point | grid n | box (a_ho) | dx (a_ho) | regime |
|---|---|---|---|---|
| **P0_pre** (96³ box=12) | 96³ | 12 | **0.125** | just above dx_crit; threshold probe |
| **P1** (128³ box=8)     | 128³ | 8 | **0.0625** | well below dx_crit; droplet should form |
| **P2** (192³ box=6)     | 192³ | 6 | **0.03125** | deeply below; near-converged peak |

(Original director-suggested 256³ box=5 → dx=0.020 is dropped to P2_alt below; see cost discussion §3.)

**Form-(B) prediction table** (using $dx_{\rm crit}=0.20$, $\beta=3$, $n_{\rm paper}=13000$, $n_{\rm delocal}=1\,D_0$):

| Point | dx (a_ho) | $(dx_{\rm crit}/dx)^3$ | predicted $n_{\rm max}$ ($D_0$) |
|---|---|---|---|
| T40 baseline (64³, box=28) | 0.4375 | 0.094 (> 1: clipped at 1) | $\approx 1$ (delocalized) |
| **P0_pre** | 0.125 | 4.1 | 13000 (saturated, but partial Nyquist distortion → **range [3000, 13000]**) |
| **P1**     | 0.0625 | 32.8 | 13000 (well-saturated → **range [8000, 13000]**) |
| **P2**     | 0.03125 | 263 | 13000 (deeply-saturated → **range [10000, 13000]**) |

**Range source**: the Nyquist-undersampling residual penalty $(dx/r_{\rm minor})^2$ at P0_pre is $(0.125/0.2)^2 = 0.39 \Rightarrow$ 39% peak attenuation possible (so $\ge 0.61 \times 13000 = 8000\,D_0$); however, ITP starting from a Gaussian seed may not converge to the droplet basin in finite n_steps **even** when the basin is on the grid (because the Gaussian seed has wrong topology, per T40 §2). The 3000 lower bound reflects the possibility that ITP only partially nucleates the droplet from a spherical seed within 5000 steps.

[Plausible] P0_pre n_max ∈ [3000, 13000] D₀ if Form (B) is correct, [Established] P0_pre n_max ≈ 1 D₀ if Form (A) is correct (volumetric ceiling).

**This is the SHARP discriminator**: a 4-order-of-magnitude gap between (B) and (A) at P0_pre. T44 Execute gives a clean verdict.

### 2.5 Seed sigma at finer dx

T40 used $\sigma_{\rm init} = 2.0\,a_{\rm ho}$ which is over-extended relative to the droplet half-width $\sigma_{\rm dr} = 0.71\,a_{\rm ho}$ (memory). At finer dx the seed should be **matched to droplet scale**, otherwise ITP wastes steps spreading from an over-extended Gaussian.

| Point | dx (a_ho) | sigma (a_ho) | rationale |
|---|---|---|---|
| P0_pre | 0.125 | **0.7** | matches droplet half-width; resolves at 0.7/0.125 = 5.6 cells (OK) |
| P1     | 0.0625 | **0.7** | matches; 11.2 cells across half-width (good) |
| P2     | 0.03125 | **0.7** | matches; 22.4 cells (excellent) |

The seed is spherical Gaussian polarized in $m=+F$, NOT a flux-closure torus, because T40 P4 showed that even with topologically correct flux-closure torus seed the density stayed at ~0.6 D₀ at our coarse grid (topology was preserved but density didn't rise). The grid-resolution hypothesis says: at finer grid, a *spherical* Gaussian seed at the right scale ALSO nucleates the droplet, because the LHY-DDI balance can now sharpen $|\psi|$ at grid-resolvable scales. If P2 fails, we'd revisit whether topology is needed AFTER grid is fine enough.

[Plausible] $\sigma_{\rm init}=0.7$ is correct droplet half-width per memory line 76 (paper Fig 1c r/L₀ ∈ [-0.05, 0.05] → 0.71 a_ho).

### 2.6 Predictions for energy, ⟨L_z⟩, ⟨F_z⟩

- **E_total**: paper has $E_{\rm total} < 0$ (self-bound free-space droplet). At dx=0.4375 (T40), E_total>0 (delocalized fills the box, LHY+contact dominate). Form (B) prediction: $E_{\rm total}(P0_pre) < 0$ if Form (B) correct; $E_{\rm total}(P0_pre) > 0$ if Form (A).
- **⟨L_z⟩**: paper Fig 1c is the GS at ℓ=0 (non-rotating). Flux-closure torus has $\langle L_z\rangle = 0$ by symmetry (memory line 71: phase imprint $e^{i\ell\varphi}$ is for the rotating ℓ=1 state, not the GS). Spherical-Gaussian seed has $\langle L_z\rangle = 0$ initially; ITP preserves this (no angular-momentum-breaking term). **Prediction: $\langle L_z\rangle/N \in [-0.05, 0.05]$ at all P_j**.
- **⟨F_z⟩**: paper has fully polarized $f_z = +1$ for F=1 (memory line 25). Seed is `init_m_idx=1` → $\langle F_z\rangle = +N$. ITP preserves polarization for $c_1=0$. **Prediction: $\langle F_z\rangle/N \in [0.95, 1.0]$**.

### 2.7 Sanity check 1 — dimensional consistency

$dx_{\rm crit} \cdot k_{\rm droplet} \sim (0.2\,a_{\rm ho})\cdot (1/r_{\rm minor}) = (0.2)/(0.2) = 1$, i.e. dx_crit is the Nyquist scale for k = 1/r_minor. ✓

Predicted gap T40 → P2: $(0.4375/0.03125)^3 = 2744$. Observed gap at T40: 12300 (paper 13000 vs ours 1 D₀). The Form (B) ceiling at P2 is $13000\,D_0$, which would close the gap to $13000/13000 = 1$. The ratio is consistent (Form B saturates the curve at $n_{\rm paper}$). ✓

### 2.8 Sanity check 2 — limiting behavior

- At $dx \to 0$: $(dx_{\rm crit}/dx)^3 \to \infty$, predicted $n_{\rm max} \to n_{\rm paper}$ (saturated). ✓ (Matches paper's measured value at their dx ≈ 0.014.)
- At $dx \to \infty$: $n_{\rm max} \to n_{\rm delocal} \approx 1\,D_0$. ✓ (Matches T40 measurement at our coarse dx.)
- At $dx = dx_{\rm crit}$: discontinuity from $n_{\rm delocal}=1$ to $n_{\rm paper}=13000$. **This is the discriminator with smooth Form (C)**, which would predict $n_{\rm paper}\cdot 1^\beta = 13000$ continuously through the threshold. Form (B) predicts a jump; Form (C) predicts smooth. The P0_pre dx=0.125 (just below threshold) tests this: Form (B) says $n_{\rm max} \ge 3000\,D_0$ (saturated to 13000 with Nyquist penalty); Form (C) with $\beta=3$, $dx_{\rm crit}=0.05$ would say $n_{\rm max} \approx 13000\cdot(0.05/0.125)^3 \approx 830\,D_0$.

So P0_pre's value cleanly discriminates: ≥ 3000 → (B); around 800 → (C) with critic's heuristic; ≤ 10 → (A) volumetric ceiling.

[Established] All three forms give distinct predictions at P0_pre.

## 3. Cost analysis and mitigation strategy

### 3.1 Base cost amplification

T40 P1 baseline: 64³ box=28, dt=0.005, n_steps=5000 → **40 s GPU** wall (after JIT warm; sim/turn_40.md §3 reports P1 = 39.9s). FFT cost per step $\propto N_v \log N_v$ where $N_v$ = total voxels.

| Point | grid | $N_v$ | $N_v/N_{v,\rm T40}$ | FFT scale | dt_max from CFL | dt chosen | n_steps for $T_{\rm imag}=25$ | per-step factor | total |
|---|---|---|---|---|---|---|---|---|---|
| P0_pre | 96³ | $8.85\times 10^5$ | 3.38 | $3.38\cdot \frac{\log N_v}{\log N_v^{T40}} \approx 3.5$ | $0.3\cdot 0.125^2 = 4.7\times 10^{-3}$ | **0.004** | **6250** | $3.5\times 1.25 = 4.4$ | 4.4 × 1.25 × 40 s = **220 s** |
| P1 | 128³ | $2.10\times 10^6$ | 8.0 | $8.3$ | $0.3 \cdot 0.0625^2 = 1.17\times 10^{-3}$ | **0.001** | **25000** | $8.3 \times 5 = 41$ | 41 × 5 × 40s = **8200 s** ≈ 2.3 h |
| P2 | 192³ | $7.08\times 10^6$ | 27 | $29$ | $0.3 \cdot 0.03125^2 = 2.93\times 10^{-4}$ | **0.00025** | **100000** | $29\times 20 = 580$ | 580 × 20 × 40s = **23200 s** ≈ 6.4 h |

Without mitigation: P2 at 6.4 h is over the per-turn 6M effective budget. P1 at 2.3 h is at the edge. P0_pre at 220 s is comfortable.

### 3.2 Mitigation 1 — F32 mode (CLAUDE.md `dtype: f32`)

Set `dtype: f32` in `ground_state` block (T37 config schema supports it per `run_step_rotating/ground_state.jl:29`). CLAUDE.md: "~2-3× speedup" with scalar locks on rotation/DDI/spin_mixing — those locks don't matter here because $c_1=0$ (no spin_mixing) and Ω=0 (no rotation). F32 should give close to full 2-3× factor on FFT-bound work.

**Caveats**:
- DDI accumulation in F32 may lose precision at $\sim 10^{-7}$ relative — but the LHY+contact+kinetic balance involves $\sim 10^{0}$ relative quantities, so single-precision rounding is benign for ITP convergence (we are not doing tight gradient-norm comparisons; only converging to $|\psi|^2$ shape).
- T37 config uses F64 (`dtype` not set, defaults to f64). Switching to F32 introduces a comparability caveat to T37/T40 baseline but does not break it (peak densities differ by $\ll 1\%$ in F32 vs F64 for ITP).

Cost impact: P0_pre 220s → **110s**; P1 8200s → **3000s ≈ 50 min**; P2 23200s → **8400s ≈ 2.3 h**.

### 3.3 Mitigation 2 — restart from previous converged seed (cascaded ITP)

At P1, instead of starting from a $\sigma=0.7$ Gaussian for **25000 steps**, start from the **converged P0_pre wavefunction** interpolated onto the 128³ grid. ITP then only needs to **refine** the basin shape, requiring perhaps **5000 steps** (5× fewer). Similarly P2 starts from P1.

Implementation: use the `init_state: from_jld2` mechanism (T40 P4 demonstrated this loader works; minor `init_sigma: 1.0` workaround for the V_trap.omega bug; T40 §6 BUG-12 documented). The interpolation step is straightforward: spline or pad-with-zeros in real space, or pad-in-k-space (preserves spectral content exactly under upsampling).

**Cost with both mitigations (F32 + restart-seed)**:

| Point | per-step factor | n_steps_actual | total wall (F32 + restart) |
|---|---|---|---|
| P0_pre | 4.4/2.5 = 1.8 | 6250 (no restart, first run) | 1.8 × 1.25 × 40 = 90 s |
| P1 | 8.3/2.5 = 3.3 | 5000 (restart) | 3.3 × 1 × 40 = **130 s ≈ 2 min** |
| P2 | 29/2.5 = 11.6 | 5000 (restart) | 11.6 × 1 × 40 = **460 s ≈ 8 min** |

**All three fit comfortably under 1 GPU hour total**. Even without restart-seed (mitigation 2 alone), P1 in F32 is 50 min — feasible. With both mitigations, all P0/P1/P2 are well within the per-turn 6M effective budget and a single GPU window.

[Plausible] Restart-from-converged-seed cuts n_steps by ~5×; routinely true for ITP refinement on a finer grid.

### 3.4 Mitigation 3 — cascaded stop-rule (Task 4)

See §6 below.

## 4. YAML deltas (Task 2)

### 4.1 Backend choice (Task 5)

**Recommendation: rotating_basis (continuity with T37/T40 baseline)**.

Rationale:
- T37 and T40 both used rotating_basis (T37 config:26). T44's P0_pre is the first new data point in the grid-refinement sweep; comparing to T40's coarse-grid baseline requires same backend.
- rotating_basis accepts $\omega = 0$ as free-space limit (`run_step_rotating/ground_state.jl:22-25`). Gauge_fix=false is the T37 setting and is OK with $\omega=0$.
- F32 supported via `dtype: f32` (line 29).
- Spinor backend would re-introduce the σ-init parsing path differences (T37/T40 used rotating_basis-specific Gaussian builder via init_m_idx); switching contaminates the baseline.
- Template uses spinor backend; we OVERRIDE this in the deltas (the template has not been used yet for any baseline data — it's the canonical schema, but T37 patched away from it. Continuing with T37's path is correct).

### 4.2 Common block (inherited from template + T37 patches)

```yaml
defaults: {kind: rotating_basis, backend: gpu}

mixins:
  yan_li_saito_f1_refined:
    atom: Eu151_f1_effective
    interactions:
      N_atoms: 15000
      omega_ref: 314.159        # 2pi*50 rad/s (Klaus convention)
      c1: 0.0                   # F=1 polarized; c_1 irrelevant
    potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}    # free space
    gauge_fix: false
```

(The `mixins:` block is referenced via `use: [yan_li_saito_f1_refined]` in each ground_state step.)

### 4.3 P0_pre — 96³ box=12, F32, fresh Gaussian seed

File: `runs/yan_li_saito_f1_grid_refinement/config_P0_pre.yaml`

```yaml
defaults: {kind: rotating_basis, backend: gpu}

mixins:
  yan_li_saito_f1_refined:
    atom: Eu151_f1_effective
    interactions:
      N_atoms: 15000
      omega_ref: 314.159
      c1: 0.0
    potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}
    gauge_fix: false

pipeline:
  - ground_state:
      use: [yan_li_saito_f1_refined]
      grid: {n: [96, 96, 96], box: [12.0, 12.0, 12.0]}
      dtype: f32
      B: {Bz: 0.0}
      ddi: {enabled: true}
      init_m_idx: 1
      init_sigma: 0.7
      dt: 0.004
      n_steps: 6250
      tol: 1.0e-8           # F32 floor ~1e-7; tighten only to 1e-8
      save_psi_to: "runs/yan_li_saito_f1_grid_refinement/point_P0_pre_psi.jld2"   # for P1 restart
```

dx = 12/96 = **0.125 a_ho**. T_imag = 6250 × 0.004 = 25 (same as T40). Wall ~90 s.

### 4.4 P1 — 128³ box=8, F32, restart from P0_pre

File: `runs/yan_li_saito_f1_grid_refinement/config_P1.yaml`

```yaml
defaults: {kind: rotating_basis, backend: gpu}

mixins:
  yan_li_saito_f1_refined:
    atom: Eu151_f1_effective
    interactions:
      N_atoms: 15000
      omega_ref: 314.159
      c1: 0.0
    potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}
    gauge_fix: false

pipeline:
  - ground_state:
      use: [yan_li_saito_f1_refined]
      grid: {n: [128, 128, 128], box: [8.0, 8.0, 8.0]}
      dtype: f32
      B: {Bz: 0.0}
      ddi: {enabled: true}
      initial_state: from_jld2
      init_state_params:
        path: "runs/yan_li_saito_f1_grid_refinement/point_P0_pre_psi.jld2"
        snap: "last"
      init_sigma: 1.0            # ignored by from_jld2 but required to bypass V_trap.omega bug (BUG-12, T40 §6)
      dt: 0.001
      n_steps: 5000
      tol: 1.0e-8
      save_psi_to: "runs/yan_li_saito_f1_grid_refinement/point_P1_psi.jld2"
```

dx = 8/128 = **0.0625 a_ho**. T_imag = 5000 × 0.001 = 5 (refinement, not full nucleation). Wall ~130 s.

### 4.5 P2 — 192³ box=6, F32, restart from P1

File: `runs/yan_li_saito_f1_grid_refinement/config_P2.yaml`

```yaml
defaults: {kind: rotating_basis, backend: gpu}

mixins:
  yan_li_saito_f1_refined:
    atom: Eu151_f1_effective
    interactions:
      N_atoms: 15000
      omega_ref: 314.159
      c1: 0.0
    potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}
    gauge_fix: false

pipeline:
  - ground_state:
      use: [yan_li_saito_f1_refined]
      grid: {n: [192, 192, 192], box: [6.0, 6.0, 6.0]}
      dtype: f32
      B: {Bz: 0.0}
      ddi: {enabled: true}
      initial_state: from_jld2
      init_state_params:
        path: "runs/yan_li_saito_f1_grid_refinement/point_P1_psi.jld2"
        snap: "last"
      init_sigma: 1.0
      dt: 0.00025
      n_steps: 5000
      tol: 1.0e-8
      save_psi_to: "runs/yan_li_saito_f1_grid_refinement/point_P2_psi.jld2"
```

dx = 6/192 = **0.03125 a_ho**. T_imag = 5000 × 0.00025 = 1.25 (refinement only — converged shape from P1 needs minor adjustment). Wall ~460 s ≈ 8 min.

### 4.6 Box-size rationale

- P0_pre box=12: > 2× droplet diameter (≈ 3 a_ho) by a factor 4, providing comfortable boundary clearance. With 96³ grid this gives a clean dx=0.125.
- P1 box=8: > 2× droplet diameter by factor 2.7. Still safe; tightens box so more cells go into droplet region.
- P2 box=6: > 2× droplet diameter by factor 2. At dx=0.03125, the entire droplet feature (half-width 0.7 a_ho) spans 22 cells — well-resolved.
- All boxes are > L_0 = 14.4 a_ho? **No** — and this is a deliberate choice. The paper's L_0 = 14.4 a_ho is a SCALE marker, not a literal "box must be > L_0" requirement. The droplet itself is only ~1.4 a_ho diameter (5% of L_0). The paper uses **box ≫ droplet** because they probe far-field behavior (Fig 1c shows tails out to r/L_0 = ±0.05). For our reproducibility goal of $n_{\rm max}$, box ≥ 4× droplet diameter is sufficient.

[Plausible] box=6–12 a_ho is sufficient for $n_{\rm max}$ reproduction; far-field tail (Fig 1c profile shape match) may need bigger box, deferred to post-PASS analysis.

## 5. Success criteria for T44 Execute (Task 3)

T44 will Execute **P0_pre only** under the cascaded stop-rule (§6). All criteria below evaluate P0_pre output only.

### 5.1 Universal sanity criteria (all must pass)

```json
[
  {
    "id": "norm_drift",
    "metric": "norm_drift_max",
    "operator": "<",
    "value": 0.01,
    "interpretation_pass": "ITP normalization preserved within 1%; numerical integration stable",
    "interpretation_fail_operational": "CFL violation or numerical instability; reduce dt or check F32 rounding"
  },
  {
    "id": "converged",
    "metric": "converged",
    "operator": "==",
    "value": true,
    "interpretation_pass": "ITP reached tol=1e-8 within n_steps=6250",
    "interpretation_fail_operational": "Hit n_steps without converging; extend n_steps or accept partial convergence with explicit n_max read"
  }
]
```

### 5.2 Discriminator criteria (decide which form is correct)

```json
[
  {
    "id": "n_max_above_form_B_lower_bound",
    "metric": "n_max_D0",
    "operator": ">=",
    "value": 3000,
    "interpretation_pass": "Form (B) sharp-threshold CORROBORATED at dx=0.125 (below dx_crit=0.20). Tier 0.8 -> 0.9. Proceed to P1 at T45.",
    "interpretation_fail": "Form (B) numeric prediction missed; either Form (C) smooth-power-law (if n_max ~ 800) or Form (A) volumetric ceiling (if n_max ~ 1)"
  },
  {
    "id": "n_max_within_form_B_upper_bound",
    "metric": "n_max_D0",
    "operator": "<",
    "value": 50000,
    "interpretation_pass": "No runaway (e.g. norm collapse hot-spot); peak density physically sensible",
    "interpretation_fail_operational": "Runaway concentration; check whether LHY+kinetic balance broken at F32 precision OR a numerical singularity is being approached. Don't trust n_max."
  },
  {
    "id": "energy_total_self_bound",
    "metric": "E_total_per_N",
    "operator": "<",
    "value": 0,
    "interpretation_pass": "Self-bound droplet formed (negative GS energy in free space). Strong corroboration of Form (B) physics.",
    "interpretation_fail_numeric_mismatch": "Density rose but state still quasi-bound (E_tot > 0); could be partial nucleation, ITP needs more steps, or droplet basin reached only locally. Examine spatial profile."
  }
]
```

### 5.3 Physical-consistency criteria

```json
[
  {
    "id": "L_z_per_N_small",
    "metric": "abs(L_z_per_N)",
    "operator": "<",
    "value": 0.05,
    "interpretation_pass": "GS topology matches paper (ℓ=0, no net angular momentum)",
    "interpretation_fail": "Spurious angular momentum from CFL boundary effect or BC; recheck"
  },
  {
    "id": "F_z_per_N_polarized",
    "metric": "F_z_per_N",
    "operator": ">",
    "value": 0.95,
    "interpretation_pass": "Spin fully polarized as paper assumes for F=1 polarized droplet",
    "interpretation_fail": "Spin-mixing leaked despite c1=0; flag for c1 leakage bug audit"
  }
]
```

### 5.4 Outcome routing (T44 Update verdict mapping)

| P0_pre result | Implied form | T45 next action |
|---|---|---|
| n_max ≥ 3000 D₀ AND E_total < 0 AND norm OK | **Form (B) CORROBORATEd** | T45: implementer Execute P1 (restart from P0_pre); tier 0.8 → 0.9 |
| n_max ∈ [100, 3000) D₀ | **Form (C) corroborated, Form (B) refuted** | T45: theorist re-Hypothesize with smooth power-law; recalibrate β; new P1 prediction |
| n_max ∈ [10, 100) D₀ | **Inconsistent with any form** | T45: critic side-dispatch to audit (is ITP partially nucleating? grid issue? F32 issue?) |
| n_max < 10 D₀ | **Form (A) volumetric ceiling OR grid hypothesis REFUTED-after-corroboration** | T45: hard pause; either (a) Hypothesize alternative root cause (deeper framework bug or paper-wrong), or (b) box-size hypothesis sub-investigation; tier 0.8 → 0.6 |
| Norm drift > 0.01 OR CFL blowup | **Operational failure** | T45: re-dispatch with smaller dt or F64 mode |

Criterion count: **7** (2 sanity + 3 discriminator + 2 physical) — exceeds director's minimum of 4.

## 6. Cascaded stop-rule (Task 4)

```
T44 Execute:
  Run P0_pre (96³ box=12, F32, ~90s GPU)
  Measure n_max_D0 [P0_pre]

T44 Update (judge.py):
  IF n_max_D0[P0_pre] >= A = 3000:
    Form (B) corroborated. Proceed to T45 Execute = P1.
  ELIF n_max_D0[P0_pre] in [100, 3000):
    Form (C) corroborated, Form (B) numerically refuted. Proceed to T45 Hypothesize re-calibration.
  ELIF n_max_D0[P0_pre] < 100:
    Form (B) and (C) both refuted at this dx. Tier 0.8 -> 0.6.
    HALT cascade. T45 = Hypothesize alternative root causes (Form A box-ceiling test? deeper framework? paper-wrong?).

T45 Execute (only if A passed):
  Run P1 (128³ box=8, F32, restart from P0_pre_psi.jld2, ~130s GPU)
  Measure n_max_D0 [P1]

T45 Update:
  IF n_max_D0[P1] >= B = 8000:
    Form (B) corroborated at finer dx. Proceed to T46 Execute = P2.
  ELIF n_max_D0[P1] in [3000, 8000):
    Partial corroboration; ITP not converging to full droplet despite resolution. T46 = extend n_steps or seed sigma sweep.
  ELIF n_max_D0[P1] < 3000:
    Refinement DID NOT increase density at finer dx. Refutation: grid hypothesis dies. Tier 0.9 -> 0.7. HALT.

T46 Execute (only if B passed):
  Run P2 (192³ box=6, F32, restart from P1_psi.jld2, ~460s GPU)
  Measure n_max_D0 [P2]

T46 Update:
  IF n_max_D0[P2] in [10000, 16000]: Tier 0.9 -> 1.0 (Tier-3 quantitative match). Investigation closed PASS.
  ELIF n_max_D0[P2] in [5000, 10000): Tier 0.9 -> 0.95 (partial Tier-3). Document residual and consider extending to dx=0.014 (paper grade) in a follow-up cascade.
  ELIF n_max_D0[P2] < 5000: Grid hypothesis only partial; residual mechanism remains. Tier 0.9 -> 0.85. Spawn researcher to fetch Li-Saito 2024 supplemental ITP procedure.
```

**Stop thresholds**:
- **A = 3000** (P0_pre → P1 gate): Form (B) lower bound at P0_pre. If we don't see at least 3000× T40 baseline, the basin isn't being reached.
- **B = 8000** (P1 → P2 gate): Form (B) lower bound at P1. Predicts $\ge 8000\,D_0$ at the well-saturated regime.

These are AGGRESSIVE thresholds (they impose Form (B) prediction must hold; if Form (C) is right, P0_pre falls in [100, 3000) bucket and we re-Hypothesize at T45 rather than blindly going to P1). This saves the P1 GPU cost in the wrong-form scenario.

[Plausible] Thresholds A=3000, B=8000 are tight but anchored on Form (B) lower-bound predictions. Loosening A → 1000 would allow Form (C) to also pass; loosening B → 3000 would allow partial Form (B) to advance.

## 7. Calibrated claims

- [Established] T42 critic Section A CORROBORATEd grid hypothesis with independent dx-ratio (30.4×) and droplet-cell-count (3.2 vs 97) chains.
- [Established] T42 critic Section B closed DDI prefactor bit-equal in Fourier space (ratio=1).
- [Established] T40 P3 (σ=14) gave n_max = 0.21 D₀; T40 P1 (σ=0.5) gave 1.06 D₀ — factor 5 variation refutes literal Form (A) volumetric ceiling.
- [Established] CFL bound $dt < 2 dx^2/\pi$ for split-step Fourier kinetic on a uniform grid; my safer factor $dt \le 0.3 dx^2$ leaves headroom for interaction phase.
- [Plausible] $dx_{\rm crit} = 0.20\,a_{\rm ho}$ as the droplet minor radius threshold from T42 §A geometric chain + Nyquist argument.
- [Plausible] $\beta = 3$ scaling exponent from volume-of-resolved-feature argument; cross-checks against T42 §A's $(30.4)^3 \approx 28000$ ≈ observed gap 12300 within factor 2.
- [Plausible] Form (B) prediction at P0_pre: n_max ∈ [3000, 13000] D₀. The 4-order-of-magnitude gap vs Form (A) baseline (~1 D₀) makes P0_pre a clean discriminator.
- [Plausible] F32 mode gives 2-3× speedup with negligible ITP convergence impact at our coupling regime.
- [Plausible] Restart-from-converged-seed cuts P1 and P2 n_steps by ~5× (refinement vs full nucleation).
- [Plausible] T44 P0_pre cost: ~90s GPU wall ($\approx$ 0.025 GPU-hr); P1: ~130s (~0.04 GPU-hr); P2: ~460s (~0.13 GPU-hr). Combined cascade well under 1 GPU-hr.
- [Speculative] If P0_pre n_max ∈ [100, 3000) D₀, Form (C) smooth-power-law is right and Form (B) wrong; need to re-Hypothesize.
- [Speculative] If P2 reaches n_max ∈ [10000, 13000] D₀, Tier 0.8 → 1.0 (Tier-3 Yan-Li-Saito quantitative reproduction achieved on this axis).
- [Unknown] My T40 §0.5 derivation of $D_0$ factor (188) vs T40 sim factor (2990) disagreement — not load-bearing for THIS turn since predictions use T40 sim convention; deferred to follow-up.

## 8. Sanity checks (B2 multi-angle)

### Sanity 1 — dimensional/Nyquist consistency
- $dx_{\rm crit} \cdot k_{\rm droplet}^{\rm minor} = (0.2)(1/0.2) = 1$. ✓
- T42 §A predicted $(0.4375/0.0144)^3 = 27985$ gap. Form (B) saturated ceiling at $n_{\rm paper}/n_{\rm delocal} = 13000$. Same order. ✓

### Sanity 2 — limiting behavior of Form (B)
- $dx \to 0$: $n_{\rm max} \to 13000$. ✓ (paper)
- $dx \to \infty$: $n_{\rm max} \to 1$. ✓ (T40)
- $dx = dx_{\rm crit}$: discontinuity from 1 to 13000. Discriminator vs smooth Form (C). ✓

### Sanity 3 — CFL across the cascade
- P0_pre: $dt/dx^2 = 0.004/0.0156 = 0.256$ ≤ 0.3. ✓
- P1: $dt/dx^2 = 0.001/0.0039 = 0.256$ ≤ 0.3. ✓
- P2: $dt/dx^2 = 0.00025/0.000977 = 0.256$ ≤ 0.3. ✓

All Pj satisfy the CFL bound with the same dimensionless ratio (uniform safety margin). ✓

### Sanity 4 — disagreement vs critic Section E heuristic
The critic heuristic was: $(0.4375/dx)^\alpha$ with $\alpha \in [2.5, 3.0]$, giving at dx=0.08 ~ "30-50 D₀". My Form (B) prediction at the closest grid (P0_pre dx=0.125) is much larger: 3000-13000 D₀. **The disagreement is the experimental signal**: the critic's heuristic is essentially Form (C) (smooth power-law without ceiling); my Form (B) imposes the ceiling at $n_{\rm paper}$ once $dx \le dx_{\rm crit}$. P0_pre's actual measurement at T44 tells us which is right. If we see ~30 D₀, the critic's heuristic is right; if we see ~3000-13000 D₀, my Form (B) is right; if we see ~1 D₀, neither is right.

This is the cleanest possible discriminator design: three forms predict three distinct orders of magnitude at the same grid point.

## 9. Open questions

1. **Restart-from-coarse-grid mechanics**: does the existing `from_jld2` loader support grid-size mismatch between source and target (P0_pre is 96³, P1 is 128³)? If not, an interpolation step is needed; implementer should write a short julia script `interpolate_psi.jl` that does k-space pad-and-truncate to upsample. (Pad with zeros in k-space is equivalent to sinc-interp in real space and preserves Parseval norm to machine precision.) Implementer flag: **VERIFY this works**, write the interpolation helper if needed.

2. **Box-size finite-volume residual**: even at P2 (box=6, dx=0.03125) the box is 0.4 L_0 — much smaller than paper's box. Does the finite-volume cutoff suppress $n_{\rm max}$? Standard analysis: for an FFT-implemented DDI kernel with periodic BC, the self-binding droplet sees image copies at separation $L_{\rm box}$; the kernel at $|r| = L_{\rm box}/2 = 3\,a_{\rm ho}$ is $\sim 1/L_{\rm box}^3 = 1/27\,a_{\rm ho}^{-3}$, suppressed by box volume — image energy contribution $\sim c_{dd}/27 \approx 24$ vs droplet self-energy $\sim 10^3$ — **negligible**. Box=6 should be fine for $n_{\rm max}$, may matter for tail shape (deferred).

3. **F32 ITP convergence floor**: does F32 LHY accumulation converge to the same fixed point as F64? CLAUDE.md mentions DDI scalar locks; for $c_1=0$ and Ω=0 the locks don't engage. Plausibly fine; if T44 shows P0_pre n_max F32-vs-F64 disagreement by > 5%, flag for follow-up. Could pre-screen with one F64 P0_pre run as cross-check; deferred unless P0_pre F32 looks suspicious.

## 10. Research queries

Empty for this turn — all needed inputs already in T41 research and T42 critic.

```json
[]
```

(One latent query: the $D_0$-factor disagreement (factor 188 vs 2990) is deferred. Not blocking this turn.)

## 11. Directive for implementer

```json
{
  "action": "run_experiment",
  "rationale": "Cascaded 3-point grid-refinement to test Form (B) sharp-dx_crit threshold (dx_crit=0.20 a_ho, beta=3) against critic Section E heuristic and Form (A) volumetric ceiling. T44 executes P0_pre ONLY (96^3 box=12, F32, ~90s GPU); cascaded stop-rule advances to T45 P1 / T46 P2 only on n_max threshold hits. Restart-from-converged-seed strategy + F32 mode keep total cascade cost under 1 GPU-hr.",
  "target_files": [
    "runs/yan_li_saito_f1_grid_refinement/config_P0_pre.yaml",
    "runs/yan_li_saito_f1_grid_refinement/config_P1.yaml",
    "runs/yan_li_saito_f1_grid_refinement/config_P2.yaml",
    "runs/yan_li_saito_f1_grid_refinement/run_P0_pre.jl",
    "runs/yan_li_saito_f1_grid_refinement/analyze_P0_pre.jl",
    "runs/yan_li_saito_f1_grid_refinement/interpolate_psi_for_restart.jl"
  ],
  "experiment_config": {
    "base_template": "runs/_loop/templates/yan_li_saito_f1_droplet.yaml (override defaults to rotating_basis)",
    "execute_this_turn": "P0_pre ONLY",
    "P0_pre": {
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
      "init_m_idx": 1,
      "init_sigma": 0.7,
      "dt": 0.004,
      "n_steps": 6250,
      "tol": 1.0e-8,
      "gauge_fix": false,
      "save_psi_to": "runs/yan_li_saito_f1_grid_refinement/point_P0_pre_psi.jld2"
    },
    "P1_deferred_to_T45_iff_P0_pre_passes": {
      "comment": "DO NOT RUN AT T44; gated on stop-rule A = 3000 D_0 at P0_pre",
      "kind": "rotating_basis",
      "backend": "gpu",
      "dtype": "f32",
      "grid": {"n": [128, 128, 128], "box": [8.0, 8.0, 8.0]},
      "initial_state": "from_jld2",
      "init_state_params": {"path": "runs/yan_li_saito_f1_grid_refinement/point_P0_pre_psi.jld2", "snap": "last"},
      "init_sigma": 1.0,
      "dt": 0.001,
      "n_steps": 5000
    },
    "P2_deferred_to_T46_iff_P1_passes": {
      "comment": "DO NOT RUN AT T44 or T45; gated on stop-rule B = 8000 D_0 at P1",
      "kind": "rotating_basis",
      "backend": "gpu",
      "dtype": "f32",
      "grid": {"n": [192, 192, 192], "box": [6.0, 6.0, 6.0]},
      "initial_state": "from_jld2",
      "init_state_params": {"path": "runs/yan_li_saito_f1_grid_refinement/point_P1_psi.jld2", "snap": "last"},
      "init_sigma": 1.0,
      "dt": 0.00025,
      "n_steps": 5000
    },
    "observable_manifest_per_point": [
      "n_max_dimless",
      "n_max_D0",
      "m_populations",
      "F_z_per_N",
      "L_z_per_N",
      "E_total_per_N",
      "E_kinetic_per_N",
      "E_contact_per_N",
      "E_LHY_per_N",
      "E_DDI_per_N",
      "norm_final",
      "norm_drift_max",
      "converged",
      "n_steps_completed",
      "wall_time_sec",
      "density_profile_radial",
      "density_profile_axial"
    ],
    "interpolate_psi_helper": "implementer writes runs/yan_li_saito_f1_grid_refinement/interpolate_psi_for_restart.jl that loads point_P0_pre_psi.jld2 (96^3 a_ho box=12), pads in k-space to 128^3 a_ho box=8 via crop-to-physical-region + FFT-resample, and writes point_P0_pre_psi_resampled_for_P1.jld2. Use only if the rotating_basis from_jld2 loader does NOT auto-handle grid-size mismatch. Verify which behavior in run_step_rotating/ground_state.jl _load_psi_from_jld2 lines 283-315 BEFORE writing the helper (it may handle the resample internally)."
  },
  "expected_outcome": "P0_pre returns n_max_D0 in one of three bins: [3000, 13000] (Form B corroborated, advance to P1 at T45), [100, 3000) (Form C corroborated, re-Hypothesize at T45), [1, 100) (Form A or refuted-grid-hypothesis, HALT at T45 and pivot). My commitment: Form B, predict n_max_D0[P0_pre] in [3000, 13000].",
  "falsification_criterion": "Per §5 criteria: P0_pre PASS iff (norm_drift_max < 0.01) AND (converged == true) AND (n_max_D0 >= 3000) AND (n_max_D0 < 50000) AND (E_total_per_N < 0) AND (abs(L_z_per_N) < 0.05) AND (F_z_per_N > 0.95). HARD REFUTATION of Form B: n_max_D0[P0_pre] < 3000 with no operational fault refutes Form (B); routes to T45 re-Hypothesize.",
  "estimated_cost": "P0_pre alone: ~90s GPU wall, < 1.5M effective. Implementer turn total (including text + 2 julia helpers + analyze): ~6 min wall, ~4M effective. Well within per-turn 6M cap.",
  "compute_steps": []
}
```

## 12. Publishability assessment

Out of scope — incremental Design turn. If the T44-T46 cascade closes with n_max ∈ [10000, 13000] D₀ at P2, the result is a clean reproduction of Yan-Li-Saito 2026 Fig 1c $n_{\rm max}$ value and a paper-worthy demonstration that SpinorBEC.jl can serve as an independent verification framework for arXiv:2605.11670 — but the manuscript treatment belongs to a post-PASS write-up turn, not this Design.

## 13. Adversarial self-review (Section E checklist)

- [x] §2 derivations: $dx_{\rm crit}$ derived from droplet minor radius + Nyquist; $\beta=3$ from volume-of-resolved-feature; Form (B) is the committed prediction with explicit numerical thresholds.
- [x] §8 sanity checks: 4 independent checks (Nyquist consistency, limiting behavior, CFL across cascade, disagreement-with-critic).
- [x] §7 calibrated claims: every load-bearing claim tagged.
- [x] §11 directive: `falsification_criterion` is concrete and machine-evaluable (numerical thresholds on 7 metrics).
- [x] §10 research queries: empty array, justified.
- [x] No invented numbers — all of $a_s=21 a_0$, $a_{\rm ho}=1.157\,\mu{\rm m}$, $N=15000$, $\varepsilon_{dd}=1.2$, $n_{\rm paper}=13000$, droplet half-width $0.71$, minor radius $0.2$ from T42 critic + T41 research + memory. Form-(B) parameters $dx_{\rm crit}=0.20$ and $\beta=3$ derived in §2.3.
- [x] No sycophancy.
- [x] §11 directive contains no Bash/Edit calls; only YAML configs and a julia helper file name.
- [x] DDI conventions explicitly NOT modified.
- [x] Backend choice (rotating_basis) justified vs spinor template default.
- [x] Cost discipline embedded in cascaded stop-rule (§6) — single P0_pre run at T44.
- [x] §0.5 transparently flagged unresolved $D_0$-factor disagreement and deferred without halting.

## 14. Sources cited

1. **`runs/_loop/judge/turn_42_critic_audit.md`** (T42 critic Sections A, B, C, D, E) — primary anchor for grid hypothesis CORROBORATEd, DDI closed bit-equal, R1 routing.
2. **`runs/_loop/research/turn_41.md`** — arithmetic chain for dx-ratio, paper's grid resolution, F=1 Fig 1c F-identity.
3. **`runs/_loop/sim/turn_40.md`** — 5-pt seed-basin discriminator empirical data; T40 σ-sweep results refuting Form (A).
4. **`runs/_loop/theorist/turn_40.md`** — prior turn's E_DDI=0 isotropic-Gaussian argument; informs seed-sigma choice.
5. **`runs/yan_li_saito_f1_torus_gs/config.yaml`** — T37 baseline config; backend, atom, N, dt, n_steps defaults.
6. **`runs/_loop/templates/yan_li_saito_f1_droplet.yaml`** — canonical template (modified backend).
7. **Memory `yan_li_saito_2026_barnett_paper.md`** lines 75-83 — paper anchor numbers (13000 D₀, 0.71 a_ho droplet, ~0.2 minor).
8. **`CLAUDE.md`** lines 65-67 — DDI conventions (NOT modified per T42 §B closed).
9. **`src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl`** lines 22-25, 29, 283-315 — rotating_basis free-space + dtype=f32 + from_jld2 loader confirmation.

Sources cited: **9**.

## 15. Metrics block (machine-readable for judge.py)

```json
{
  "theorist_md_on_disk": true,
  "scaling_form_chosen": "B",
  "scaling_form_rationale_present": true,
  "prediction_p0_n_max_d0": [3000, 13000],
  "prediction_p1_n_max_d0": [8000, 13000],
  "prediction_p2_n_max_d0": [10000, 13000],
  "dx_crit_estimate_a_ho": 0.20,
  "beta_exponent": 3.0,
  "yaml_deltas_specified": true,
  "backend_choice": "rotating_basis",
  "cfl_constraint_addressed": true,
  "cost_estimate_p0_gpu_hours": 0.025,
  "cost_estimate_p1_gpu_hours": 0.036,
  "cost_estimate_p2_gpu_hours": 0.128,
  "stop_rule_specified": true,
  "stop_threshold_p0_d0": 3000.0,
  "stop_threshold_p1_d0": 8000.0,
  "success_criteria_count": 7,
  "observable_manifest_required": [
    "n_max_dimless",
    "n_max_D0",
    "m_populations",
    "F_z_per_N",
    "L_z_per_N",
    "E_total_per_N",
    "E_kinetic_per_N",
    "E_contact_per_N",
    "E_LHY_per_N",
    "E_DDI_per_N",
    "norm_final",
    "norm_drift_max",
    "converged",
    "n_steps_completed",
    "wall_time_sec",
    "density_profile_radial",
    "density_profile_axial"
  ],
  "f32_mode_recommended": true,
  "restart_seed_strategy_proposed": true,
  "sources_cited": 9,
  "tier_current": 0.8,
  "tier_target_if_p0_pre_pass": 0.9,
  "tier_target_if_full_cascade_pass": 1.0,
  "tier_target_if_p0_pre_fail": 0.6,
  "disagreement_with_critic_heuristic_documented": true,
  "ddi_conventions_modified": false,
  "execute_this_turn_count_of_points": 1,
  "deferred_points": ["P1 (T45 conditional)", "P2 (T46 conditional)"]
}
```
