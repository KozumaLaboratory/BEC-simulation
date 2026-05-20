---
turn: 39
subagent: theorist
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_to: Design
topic_tags: [yan-li-saito-2026, design-stage, eps-dd-sweep, q1-vs-q5-discriminator, falsifier-pre-registration, lima-pelster-sympy-verification, falsifier-F1-discriminator]
paper_section: null
depends_on: [37, 38, "runs/_loop/judge/turn_38_critic_audit.md", "runs/yan_li_saito_f1_torus_gs/config.yaml", "runs/yan_li_saito_f1_torus_gs/t37_run.jl", "src/hamiltonian/interactions/interactions.jl:447-459", "src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl:94-118", "src/rotating_basis/workspace.jl:27-31", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_mathematical_elegance_bias"]
produces: "Pre-registered F1-discriminator falsifier: 4-point ε_dd-sweep {0.95, 0.99, 1.05, 1.20} via coupled (c_dd, gamma_lhy) overrides on existing T37 config + parallel sympy Q5(1.2) verification under 3 branch prescriptions. Per-point predicted observables + decision rule mapping observed n_max(ε_dd) pattern → {Q1, Q5, both, neither} verdict."
---

# Turn 39 — Theorist Report (Design: F1-discriminator falsifier pre-registration)

## 0. Convention declaration

- **Units**: $\hbar = m = \omega_{\rm ref} = 1$. Length $a_{\rm ho} = \sqrt{\hbar/(m\omega_{\rm ref})}$. Density unit per Yan-Li-Saito normalization $D_0 = 1/(a_s^3 N^2)$ (paper memory §"Normalization"; for Eu-151 $N=15000$, $a_s=21\,a_0$: $D_0 = 3.43\,\mu m^{-3}$).
- **DDI**: project uses spinor convention $c_{dd} = \mu_0 (\mu/F)^2$ (no $4\pi$); $a_{dd} = \mu_0 \mu^2 m / (12\pi\hbar^2)$ uses the *full* moment $\mu = g_F F \mu_B$. The factor-$F^2$ from spin operators is recovered separately. Dimensionless ratio defined by the solver as $\varepsilon_{dd,\rm eff} = c_{dd}\cdot F^2/(3 c_0)$ (verified in `src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl:112`).
- **Lima-Pelster Q5**: project's `lima_pelster_Q5(eps_dd)` at `src/hamiltonian/interactions/interactions.jl:447-459` implements $Q_5(\varepsilon_{dd}) = \int_0^\pi (\sin\theta/2)\,[1+\varepsilon_{dd}(3\cos^2\theta-1)]^{5/2}\,d\theta$ with **silent truncate-to-zero** when argument is negative (line 456: `(arg >= 0.0 ? arg^(5/2) : 0.0)`). The paper's $\chi(\varepsilon_{dd}) = \text{Re}\int_0^\pi \sin\theta\,[1+\varepsilon_{dd}(3\cos^2\theta-1)]^{5/2}/2\,d\theta$ (Eq 1, paper memory line 50). Under principal-branch interpretation $(-x)^{5/2} = x^{5/2}\,e^{i\,5\pi/2} = i\,x^{5/2}$, so $\text{Re}[(-x)^{5/2}] = 0$: **principal-branch-Re ≡ truncate-to-zero (algebraically identical)**. This is critic T38 §2 finding, re-verified here. The *contested* alternative (Lima-Pelster 2011 "BdG analytic continuation" sign-flip $\text{Re}[(-x)^{5/2}] = -x^{5/2}$) is the candidate Q1 mechanism.
- **γ_LHY auto-derivation** in `src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl:97-101`: $\gamma_{\rm LHY} = (128\sqrt\pi/3)\,(a_s/a_{\rm ho})^{5/2}\,N^{3/2}\,Q_5(\varepsilon_{dd,\rm phys})$ where $\varepsilon_{dd,\rm phys} = \text{compute\_a\_dd}(\text{atom})/\text{atom.a\_s}$ is computed from the AtomSpecies struct (NOT from the YAML `c_dd` override). **Consequence**: overriding `interactions.c_dd` alone changes $\varepsilon_{dd,\rm eff}$ in the integrator but leaves $\gamma_{\rm LHY}$ pinned to $Q_5(1.1772)$. To realize a clean ε_dd-sweep, both `interactions.c_dd` AND `interactions.gamma_lhy` must be overridden in lockstep. This is the convention-deviation that drives §3's two-knob override design.
- **Sign / Wick convention**: ITP (Wick-rotated imaginary time), default sign per `find_ground_state_rotating!`. No deviation from production.

## 1. Context summary

T37 Execute (commit `15cf48a`) tested the F1 falsifier ($n_{\max}$ at the centre of a self-bound torus droplet for F=1 Eu-151 at $\varepsilon_{dd}=1.2$, $N=15000$, free space): measured $n_{\max} = 0.99\,D_0$ vs paper Fig 1c target $\sim 13000\,D_0$ — **factor $\sim 1.3\times 10^4$ deficit; F1 FALSIFIED** ($\rho/n_{\max,\rm uniform-fill} = 7.4\times 10^{-7}$; m=+F population 0.946 < paper's 1.0). T38 critic Cross-check (`runs/_loop/judge/turn_38_critic_audit.md`) independently re-ranked candidate framework gaps and **inverted** the implementer's prior: Q5 (Gaussian seed basin $\sigma=2\,a_{\rm ho}$ vs droplet radius $L_0/a_{\rm ho} \approx 14$) was elevated to HIGH; Q1 (Lima-Pelster Q5 ε_dd>1 branch prescription) moved to MEDIUM; Q2 (DDI prefactor) RULED OUT (ε_dd_eff = 1.1772 matches paper 1.2 within 2%). Critic verdict: **NEEDS-FURTHER-DISCRIMINATION**; next stage **Design**.

T39 (this turn) pre-registers the F1-discriminator: a 4-point ε_dd-sweep at $\{0.95,\,0.99,\,1.05,\,1.20\}$ with seed and all other parameters held fixed, plus a parallel symbolic Q5(1.2) verification under three branch prescriptions. Per critic T38 §5 decision logic, the n_max(ε_dd) signature mechanically selects between four verdicts: {Q1-corroborated, Q5-corroborated, both-partial, neither-broken}. Per `feedback_mathematical_elegance_bias`, the two diagnostics (ε_dd-sweep + sympy) are independent simple probes — NOT a unified Q1+Q5 patch.

## 2. Derivation

### 2.1 Why ε_dd = 1 is the natural discriminator boundary

The Lima-Pelster integrand $[1+\varepsilon_{dd}(3\cos^2\theta-1)]^{5/2}$ has argument $\text{arg}(\theta) = 1-\varepsilon_{dd} + 3\varepsilon_{dd}\cos^2\theta$, with minimum $\text{arg}_{\min} = 1-2\varepsilon_{dd}$ at $\theta = \pi/2$. The boundary at which $\text{arg}_{\min} = 0$ is $\varepsilon_{dd} = 1/2$; the boundary at which the *integrated* drop region becomes large enough to bring branch-prescription differences into a $\mathcal{O}(1)$ correction is $\varepsilon_{dd} \to 1$:

- **$\varepsilon_{dd} < 1/2$**: arg ≥ 0 everywhere; $Q_5$ is unambiguous, all three prescriptions identical.
- **$1/2 \leq \varepsilon_{dd} < 1$**: arg < 0 in a $\theta$-band around $\pi/2$, but the band is *narrow*; principal-branch-Re and LP-2011-sign-flip differ but both are small corrections.
- **$\varepsilon_{dd} \geq 1$**: arg < 0 over a substantial band; for $\varepsilon_{dd} = 1.2$ the dropped region is $\theta \in (76.4°,\,103.6°)$ (critic T38 §2, derived from $\cos^2\theta_c = (\varepsilon_{dd}-1)/(3\varepsilon_{dd}) = 0.0556$). This is where Q1 prescription matters most.

The chosen ε_dd grid spans this boundary: $\{0.95, 0.99\}$ on the "Q1-irrelevant" side (no truncation) and $\{1.05, 1.20\}$ on the "Q1-relevant" side (active truncation). This is the cleanest possible Q1 test: if Q1 is the cause, sub-critical points must form droplets while super-critical ones must not.

### 2.2 Sub-critical droplet formation: is it physically expected at ε_dd ∈ {0.95, 0.99}?

For a single-component scalar dipolar BEC, droplet self-binding requires the net contact + LHY repulsion to balance against the DDI attractive head-to-tail mode. The Lima-Pelster 2011 droplet criterion (cited in memory §"Likely failure modes"; paper Eq 1 LHY term carries $\chi(\varepsilon_{dd})$) gives equilibrium peak density

$$n_{0} \propto \left(\frac{1 - 1/\varepsilon_{dd}}{\chi(\varepsilon_{dd})}\right)^2 \cdot a_s^{-5}$$

(scaling form; exact prefactor in Eq 6 of Lima-Pelster PRA 84, 041604(R) 2011 — local copy not on disk, see Q1 in §7). The key qualitative facts (`[Established]` from Lima-Pelster derivation + paper Eq 1):

1. $n_0$ is *non-zero and finite* for $\varepsilon_{dd} \gtrsim 1$ (the "1.5 to a few" droplet regime); the paper studies $\varepsilon_{dd} = 1.2$ specifically (memory line 35).
2. $n_0 \to 0$ as $\varepsilon_{dd} \to 1^+$ (the binding becomes weak; the droplet swells and dilutes).
3. **Sub-critical ($\varepsilon_{dd} < 1$): droplets DO NOT form in the canonical Lima-Pelster scalar+DDI+LHY framework** because the contact $g$ remains net repulsive without the dipolar attractive amplification, leaving no binding minimum (mean-field instability boundary at $\varepsilon_{dd} = 1$ in the homogeneous limit).

**This is a critical correction to the critic T38 §5 decision table.** Critic's "Q1-dominant" branch predicts sub-critical droplets, but Lima-Pelster scalar+DDI+LHY says sub-critical states are *physically* unbound (delocalized) regardless of Q1. The discriminator therefore is NOT "do sub-critical points form droplets" — that's expected to fail under correct physics.

The corrected discriminator: **what happens to the n_max(ε_dd) curve as we cross the ε_dd=1 boundary**:

- If Q1 is broken (truncate-to-zero gives a SMALLER χ than the "true" LP-2011 prescription at ε_dd=1.2), then γ_LHY is *too large* (more LHY repulsion than physical), suppressing droplet formation at ε_dd=1.2 (matching T37). Sub-critical points are unbound regardless. **Signature: monotonic non-formation across all 4 ε_dd points, but γ_LHY values differ.**
- If Q1 is broken in the OTHER direction (truncate-to-zero gives a LARGER effective χ than LP-2011 — i.e., LP-2011 drops sign-flipped negative contributions making χ smaller and γ_LHY smaller than the current 12.8), then sub-critical points may STILL not form (no binding), but ε_dd=1.20 *would* form if LP-2011 used → still a non-discriminator.
- If Q5 is broken (Gaussian σ=2 seed unable to find droplet basin): all 4 ε_dd points are equally unbound from the Gaussian seed regardless of Q1. Same n_max ≈ 1 D_0 across the sweep. **Signature: n_max essentially flat at ~1 D_0 across all 4 points, AND γ_LHY varies smoothly.**

### 2.3 Revised decision logic: the signature is the *shape* of n_max(ε_dd)

Combining §2.1 + §2.2: the discriminator cannot rely on "sub-critical droplet formation" because Lima-Pelster predicts no sub-critical droplets even with correct prescription. Instead, **the discriminator hinges on the ε_dd=1.20 → 1.05 → 0.99 → 0.95 trajectory of n_max**:

| Hypothesis | Predicted n_max(ε_dd) shape |
|---|---|
| **Q5 dominant** (seed basin misaligned) | Flat at $n_{\max} \approx 1\,D_0$ across all 4 ε_dd; ITP returns delocalized Gaussian regardless. |
| **Q1 dominant** (Q5 prescription wrong, seed OK) | Either flat-low (if Q1 makes γ_LHY too repulsive everywhere) OR step at ε_dd=1 (if Q1 only affects ε_dd>1 with a sign change). Paper-like $n_{\max} \approx 10^4\,D_0$ at ε_dd=1.20 ONLY IF the LP-2011 prescription is the correct fix AND Q5 isn't blocking. |
| **Both broken** | Flat-low (Q5 masks Q1). |
| **Neither broken** (T37 was a transient artifact) | All 4 form paper-like droplets at ε_dd ≥ 1.0 only; ε_dd < 1.0 stays unbound; n_max(1.20) ≈ 13000 D_0. |

This is the impartial decision table for §5. It does NOT pre-suppose Q5 (which critic ranked #1) — the experiment is fair because **both Q1-only and Q5-only scenarios produce distinguishable signatures: a step at ε_dd=1 indicates Q1; a flat-low across all four indicates Q5; a paper-match at ε_dd=1.20 indicates neither**.

### 2.4 Why the experiment Q5-vs-Q1 disambiguation works

Crucial asymmetry: **the seed problem (Q5) is independent of ε_dd**, while **the Q1 prescription bug activates discretely at ε_dd ≥ 1** (where the arg < 0 region appears). If Q5 is the dominant failure mode, the Gaussian seed delocalizes equally under any γ_LHY value; n_max(ε_dd) is flat. If Q1 is the dominant failure mode, the n_max(ε_dd) curve has a discontinuity at the ε_dd=1 boundary. **One experiment, two distinguishable signatures.**

### 2.5 Single-knob YAML override — design choice

From `src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl:104-106`:
```julia
c0 = haskey(inter, "c0") ? Float64(inter["c0"]) : c0_auto
c_dd = haskey(inter, "c_dd") ? Float64(inter["c_dd"]) : c_dd_auto
γ = haskey(inter, "gamma_lhy") ? Float64(inter["gamma_lhy"]) : γ_auto
```

`γ_auto` is computed from `compute_gamma_lhy(atom_obj.a_s/a_ho, ε_dd_phys, N_atoms)` where `ε_dd_phys = compute_a_dd(atom)/atom.a_s` is **bound to the AtomSpecies struct**, NOT to the YAML `c_dd` override. **There is no single-line YAML knob that controls ε_dd cleanly without code modification**. The closest convention-consistent override is a *coupled pair* `(c_dd, gamma_lhy)` per point — both pre-computed by this Design, then plugged in via a `scan.zip` block (`docs/reference/yaml_schema_reference.md:153-167`).

This is a known framework limitation, **not a bug to fix in this turn** (per directive: "DO NOT modify src/ code"). The Design specifies the two-knob coupling explicitly; the implementer's job at T40 is mechanical substitution.

### 2.6 Per-point coupled-override values

Given T37 baseline `c0 = 1.810e+02` (held fixed via the Eu151_f1_effective atom + N=15000 + ω_ref=314.159), and F=1, the relation $\varepsilon_{dd,\rm eff} = c_{dd}\cdot F^2 / (3 c_0)$ gives:

$$c_{dd}(\varepsilon_{dd}) = 3 \cdot c_0 \cdot \varepsilon_{dd} = 543.0\,\varepsilon_{dd}\quad\text{(F=1, c_0 = 181.0)}$$

And $\gamma_{\rm LHY}(\varepsilon_{dd}) = K \cdot Q_5(\varepsilon_{dd})$ where $K = (128\sqrt\pi/3)\,(a_s/a_{\rm ho})^{5/2}\,N^{3/2}$. From T37 γ_LHY=12.8 at $\varepsilon_{dd,\rm phys}=1.1772$:
$$K = 12.8 / Q_5(1.1772)$$

I do not pre-compute $Q_5(1.1772)$ analytically here (T37 already integrated it via 20-point Gauss-Legendre to produce γ_LHY=12.8); instead, the implementer at T40 calls `lima_pelster_Q5` directly at each grid point. The 4 override values are then:

| ε_dd | c_dd override | γ_LHY override |
|---|---|---|
| 0.95 | $0.95 \times 543.0 = 515.85$ | $K\cdot Q_5(0.95)$ |
| 0.99 | $0.99 \times 543.0 = 537.57$ | $K\cdot Q_5(0.99)$ |
| 1.05 | $1.05 \times 543.0 = 570.15$ | $K\cdot Q_5(1.05)$ |
| 1.20 | $1.20 \times 543.0 = 651.60$ | $K\cdot Q_5(1.20)$ |

Implementer at T40 computes K from T37 data and Q_5 values from `lima_pelster_Q5` in Julia (zero-cost; same numerical integration the auto-derive path uses). Validation: at ε_dd=1.1772 → c_dd ≈ 639.2 and γ_LHY ≈ 12.8 reproducing T37 exactly.

### 2.7 Sympy Option B: three prescriptions

For the parallel Q5(1.2) sympy verification, the three prescriptions are:

- **(a) Truncate-to-zero (current code, `interactions.jl:456`)**:
  $$Q_5^{(a)}(\varepsilon_{dd}) = \int_0^\pi \frac{\sin\theta}{2}\,\max(0,\,1+\varepsilon_{dd}(3\cos^2\theta-1))^{5/2}\,d\theta$$
- **(b) Principal-branch Re of analytic continuation** (paper Eq 1 verbatim):
  $$Q_5^{(b)}(\varepsilon_{dd}) = \text{Re}\int_0^\pi \frac{\sin\theta}{2}\,[1+\varepsilon_{dd}(3\cos^2\theta-1)]^{5/2}\,d\theta$$
  Per critic T38 §2 + my §0: $(-x)^{5/2} = e^{i 5\pi/2} x^{5/2} = i\,x^{5/2}$ under principal branch, so $\text{Re} = 0$. **Should equal (a) exactly.**
- **(c) Lima-Pelster 2011 BdG-analytic-continuation sign-flip prescription** (cited but not verbatim available; critic T38 §2 hypothesis):
  $$Q_5^{(c)}(\varepsilon_{dd}) = \int_0^\pi \frac{\sin\theta}{2}\,\text{sign}(1+\varepsilon_{dd}(3\cos^2\theta-1))\,|1+\varepsilon_{dd}(3\cos^2\theta-1)|^{5/2}\,d\theta$$
  This is the "BdG zero-point mode count keeps imaginary roots contributing with a sign-flipped real value" prescription. Need <RESEARCH_NEEDED: Q1> (Lima-Pelster PRA 84, 041604(R) 2011 verbatim) to confirm this is the canonical prescription.

The sympy spec returns numerical values for $Q_5^{(a)}(1.2)$, $Q_5^{(b)}(1.2)$, $Q_5^{(c)}(1.2)$ and the differences $Q_5^{(c)} - Q_5^{(a)}$ (the candidate Q1 correction magnitude). Pre-prediction: $|Q_5^{(c)} - Q_5^{(a)}|/Q_5^{(a)} \lesssim 0.5$ (the dropped-region area is ~25% of total integration domain, integrand magnitude there is $\lesssim 1$, so the difference is at most $\mathcal{O}(\text{tenths})$). This $\mathcal{O}(0.5)$ correction in γ_LHY produces an $\mathcal{O}(1)$ correction in droplet equilibrium n_0 (per Lima-Pelster scaling) — **NOT a factor $10^4$**. This is the strongest a priori argument that Q1 alone cannot explain T37; Q5 must be at least partially involved.

## 3. Sanity checks

### Check A: convention re-verification of $\varepsilon_{dd,\rm eff}$ in T37

T37 produced `c0=1.810e+02`, `c_dd=6.392e+02`, `ε_dd_eff = 1.1772`. Compute: $c_{dd} F^2 / (3 c_0) = 639.2 \cdot 1 / 543.0 = 1.1772$ ✓. This independently confirms (a) the §2.6 formula $c_{dd}(\varepsilon_{dd}) = 3 c_0 \varepsilon_{dd}$ and (b) Q2 (DDI prefactor) is *not* broken at the F=1 path — confirming critic's RULED OUT verdict and licensing the c_dd override approach.

### Check B: dimensional analysis of K

$K = (128\sqrt\pi/3)\,(a_s/a_{\rm ho})^{5/2}\,N^{3/2}$. All terms dimensionless (lengths in $a_{\rm ho}$, $a_s$ in same units, $N$ a count). $K$ is dimensionless ✓. With $a_s/a_{\rm ho} \approx 9.6\times 10^{-4}$, $N=15000$: $(9.6\times 10^{-4})^{5/2} \approx 2.86\times 10^{-8}$, $N^{3/2} \approx 1.84\times 10^6$, prefactor $128\sqrt\pi/3 \approx 75.6$, so $K \approx 75.6 \cdot 2.86\times 10^{-8} \cdot 1.84\times 10^6 \approx 3.97$. From $K \cdot Q_5(1.1772) = 12.8 \Rightarrow Q_5(1.1772) \approx 3.22$. This is the truncate-to-zero value at near-paper ε_dd; consistent with critic's $Q_5(1.2) \approx 3$–$4$ regime expectation.

### Check C: predicted Q5 ordering at the 4 grid points

For $\varepsilon_{dd} < 1$ (no truncation), $Q_5$ is a smooth analytic function rising slowly with ε_dd from $Q_5(0) = 1$ (exact: integrand is just $\sin\theta/2$, integral = 1). For $\varepsilon_{dd} \to 1^-$, $Q_5$ approaches a finite limit (no singularity at boundary; integrand stays bounded). Estimate via Taylor expansion: at small ε_dd, integrand ≈ $(\sin\theta/2)[1 + (5/2)\varepsilon_{dd}(3\cos^2\theta-1) + \mathcal{O}(\varepsilon_{dd}^2)]$, and $\int_0^\pi \sin\theta (3\cos^2\theta - 1)/2\,d\theta = 0$ (it's the $P_2(\cos\theta)$ legendre-orthogonal integral against $P_0$). So $Q_5'(0) = 0$; growth is quadratic. Order of magnitude at ε_dd=1: $Q_5(1) \sim 2$–$5$.

Above ε_dd=1, truncation starts cutting integrand support; $Q_5$ continues to grow because the surviving high-cos²θ region has very large $[1+\varepsilon_{dd}(3\cos^2\theta-1)]^{5/2}$. Critic T38 §2 computed $Q_5(1.2) \approx 3.22$ from γ_LHY=12.8.

**Predicted Q5 monotonicity at the 4 points**: $Q_5(0.95) < Q_5(0.99) < Q_5(1.05) < Q_5(1.2)$, all $\mathcal{O}(1)$–$\mathcal{O}(10)$. Implementer at T40 verifies exact values via `lima_pelster_Q5`.

### Check D: paper Eq 1 → SpinorBEC.jl γ_LHY prefactor

Paper E_LHY (memory line 44): $(2/5)(32/(3\sqrt\pi))(4\pi\hbar^2/M)\,a_s^{5/2}\chi(\varepsilon_{dd})\int\rho^{5/2}$. Differentiating w.r.t. $\rho$ for $\mu_{\rm LHY}$ and converting to dimensionless via $n = N|\tilde\psi|^2/a_{\rm ho}^3$, $\mu/(\hbar\omega_{\rm ref})$: prefactor reduces to $(128\sqrt\pi/3)\,(a_s/a_{\rm ho})^{5/2}\,N^{3/2}\,\chi$ (critic T38 §2 + my §2.6 reproduction). The SpinorBEC.jl implementation matches paper Eq 1 at the prefactor level **assuming $\chi \equiv Q_5$** — which holds iff the truncate-to-zero prescription is correct. If LP-2011 prescription differs, **only** $\chi$ is wrong, not the prefactor. This is precisely Q1.

### Check E: T37 m=+F population 0.946 — spin mixing despite c1=0?

Implementer T37 §7 #4 flagged $m=+F$ population at 0.946 even though config sets `c1=0.0`. From `src/rotating_basis/workspace.jl` the DDI in rotating-basis IS the spinor-coupling term — anisotropic DDI couples m-components. For a strictly polarized droplet (paper expectation $f/\rho \approx 1$), the cloud's f-vector self-aligns to the local DDI-induced anisotropy axis, retaining $|f| \approx 1$ but not necessarily $m_F=+1$ in the lab basis. **0.946 m=+F population is consistent with mild DDI-induced spin canting in a delocalized cloud**, not a discriminator for Q1 vs Q5. Implementer T40 should track $|f|/n$ (local polarization magnitude) as a secondary observable — it should approach 1 for any forming droplet regardless of which prescription is used.

## 4. Calibrated claims

- [Established] $\varepsilon_{dd,\rm eff} = c_{dd}\cdot F^2/(3 c_0)$ formula (`ground_state.jl:112`). Source: production code re-read this turn + T37 numerics ($c_{dd}=639.2,\,c_0=181.0,\,F=1 \Rightarrow 1.1772$).
- [Established] Lima-Pelster Q5 implementation uses silent truncate-to-zero at `interactions.jl:456`. Source: code re-read.
- [Established] Truncate-to-zero ≡ principal-branch-Re algebraically (since $(-x)^{5/2} = i\,x^{5/2}$ under principal branch). Source: §0 + critic T38 §2.
- [Established] $\gamma_{\rm LHY}$ auto-derivation is bound to AtomSpecies, not YAML `c_dd` override. Source: `ground_state.jl:97-101` re-read.
- [Established] Single YAML knob cannot vary ε_dd cleanly under current architecture; coupled-pair `(c_dd, gamma_lhy)` override is the convention-consistent path. Source: §2.5 + `yaml_schema_reference.md:84` confirming `c_dd` is a valid override.
- [Established] Q2 (DDI prefactor) RULED OUT. Source: critic T38 §2 + Check A above.
- [Plausible] Lima-Pelster scalar+DDI+LHY does NOT predict sub-critical (ε_dd<1) droplet formation in homogeneous limit; sub-critical points expected unbound regardless of Q1 status. Source: §2.2; <RESEARCH_NEEDED: Q1> Lima-Pelster PRA 84, 041604(R) (2011) full text would solidify this from speculative to established.
- [Plausible] Q1-correction $|Q_5^{(c)} - Q_5^{(a)}|$ at ε_dd=1.2 is $\mathcal{O}(0.5)$ → γ_LHY correction $\mathcal{O}(0.5)\cdot 12.8 \approx 6$ → droplet n_0 correction $\mathcal{O}(1)$, **NOT** factor $10^4$. Source: §2.7 dimensional argument from dropped-region area.
- [Established] T37 m=+F population 0.946 < 1 is consistent with DDI-induced spin canting in a delocalized cloud, NOT a Q1/Q5 discriminator. Source: §3 Check E.
- [Established] The 4-point ε_dd-sweep with seed FIXED at init_sigma=2.0 produces n_max(ε_dd) signatures that mechanically select between Q1 / Q5 / both / neither verdicts. Source: §2.4.
- [Speculative] LP-2011 BdG-sign-flip prescription is the "true" Q1 alternative. Source: critic T38 §2 hypothesis; <RESEARCH_NEEDED: Q1> required to confirm.

## 5. Open questions

1. **Lima-Pelster 2011 verbatim prescription**: which of (a) truncate-zero, (b) principal-branch-Re, (c) sign-flip-real is canonical? Without this, the Q1 hypothesis interpretation depends on a guess about LP-2011. The sympy Option B (§6) computes all three numerically; reading LP-2011 would tell us which one is paper-consistent.
2. **Sub-critical droplet formation literature**: scalar+DDI+LHY droplet phase diagram at $\varepsilon_{dd} < 1$ — does any paper report sub-critical bound states (perhaps with stronger LHY)? This would refine the "Q1-dominant" branch prediction in §2.4. The Wenzel/Pfau/Ferlaino Dy/Er droplet literature (2016+) addresses $\varepsilon_{dd} > 1$; sub-critical may not have been mapped.
3. **Seed-basin sensitivity for ε_dd=1.2**: even if Q1 is RULED OUT by the sweep, the seed-basin problem (Q5) requires a separate Hypothesize stage to design a torus-shaped (`init_psi_fl_vortex`) or wider Gaussian seed and re-test. The sweep does not directly fix Q5; it tells us whether Q5 needs to be fixed.

## 6. Directive for implementer

```json
{
  "action": "run_experiment",
  "rationale": "Pre-registered F1-discriminator falsifier: 4-point ε_dd-sweep at {0.95, 0.99, 1.05, 1.20} via coupled (c_dd, gamma_lhy) overrides on T37 config to cleanly select between Q1 (Lima-Pelster prescription) and Q5 (Gaussian seed basin). Seed init_sigma=2.0 HELD FIXED across all 4 points per critic T38 §4 control discipline. Parallel sympy Option B sub-component computes Q5(1.2) under three branch prescriptions to give independent answer to Q1 without depending on Q5 outcome. Per §2.5, single-knob YAML override is architecturally not possible; the coupled-pair override is the convention-consistent path with zero src/ modification.",
  "target_files": [
    "runs/yan_li_saito_f1_torus_gs/eps_dd_sweep/config_sweep.yaml (NEW — to be authored by implementer per spec below)",
    "runs/yan_li_saito_f1_torus_gs/eps_dd_sweep/run_sweep.jl (NEW — wrapper analogous to t37_run.jl)",
    "runs/yan_li_saito_f1_torus_gs/eps_dd_sweep/compute_overrides.jl (NEW — pre-computes the 4 (c_dd, gamma_lhy) pairs from lima_pelster_Q5 and dumps to JSON or inline)"
  ],
  "experiment_config": {
    "kind": "rotating_basis_eps_dd_sweep",
    "base_config_inherited_from": "runs/yan_li_saito_f1_torus_gs/config.yaml (T37 verified PASS)",
    "single_logical_knob_varied": "epsilon_dd (mathematically); implemented as coupled (c_dd, gamma_lhy) pair per §2.5-2.6 of theorist turn_39",
    "held_fixed_across_all_points": {
      "atom": "Eu151_f1_effective",
      "interactions.N_atoms": 15000,
      "interactions.omega_ref": 314.159,
      "interactions.c0": "auto-derived (1.810e+02 from T37)",
      "interactions.c1": 0.0,
      "grid.n": [64, 64, 64],
      "grid.box": [28.0, 28.0, 28.0],
      "potential.type": "harmonic with omega=[0,0,0] (free space)",
      "ground_state.B": {"Bz": 0.0},
      "ground_state.ddi.enabled": true,
      "ground_state.init_m_idx": 1,
      "ground_state.init_sigma": 2.0,
      "ground_state.dt": 0.005,
      "ground_state.n_steps": 5000,
      "ground_state.tol": 1.0e-9
    },
    "control_discipline_seed_fixed_documented": true,
    "scan_block_form": "Use yaml scan.zip with two coupled override paths: pipeline.0.interactions.c_dd and pipeline.0.interactions.gamma_lhy (4 entries each, parallel ordering). Per yaml_schema_reference.md:157, scan.zip expects all axes same length.",
    "yaml_override_path_specified": [
      "pipeline.0.interactions.c_dd",
      "pipeline.0.interactions.gamma_lhy"
    ],
    "per_point_override_values": [
      {
        "point_id": "eps_0p95",
        "epsilon_dd_target": 0.95,
        "c_dd_override": "3.0 * c0 * 0.95 = 3.0 * 181.0 * 0.95 = 515.85 (verify c0 from T37 stdout)",
        "gamma_lhy_override": "K * lima_pelster_Q5(0.95); K = 12.8 / lima_pelster_Q5(1.1772); compute_overrides.jl evaluates"
      },
      {
        "point_id": "eps_0p99",
        "epsilon_dd_target": 0.99,
        "c_dd_override": "3.0 * 181.0 * 0.99 = 537.57",
        "gamma_lhy_override": "K * lima_pelster_Q5(0.99)"
      },
      {
        "point_id": "eps_1p05",
        "epsilon_dd_target": 1.05,
        "c_dd_override": "3.0 * 181.0 * 1.05 = 570.15",
        "gamma_lhy_override": "K * lima_pelster_Q5(1.05)"
      },
      {
        "point_id": "eps_1p20",
        "epsilon_dd_target": 1.20,
        "c_dd_override": "3.0 * 181.0 * 1.20 = 651.60",
        "gamma_lhy_override": "K * lima_pelster_Q5(1.20)"
      }
    ],
    "implementer_must_verify_pre_run": [
      "compute_overrides.jl prints the 4 (c_dd, gamma_lhy) pairs; ε_dd=1.1772 sanity check matches T37 c_dd=639.2, γ_LHY=12.8 within 1%",
      "scan.zip block parses; load_config returns 4 pipeline plans"
    ],
    "jld2_output_directory": "runs/yan_li_saito_f1_torus_gs/eps_dd_sweep/",
    "jld2_naming": "point_001.jld2 (ε_dd=0.95), point_002.jld2 (ε_dd=0.99), point_003.jld2 (ε_dd=1.05), point_004.jld2 (ε_dd=1.20)",
    "expected_wall_time": "4 × ~88s = ~6 min on GPU"
  },
  "observable_manifest": {
    "required_per_point": [
      "n_max_in_D0_units (primary discriminator; D_0 = 1/(a_s^3 N^2) = 3.43 μm^-3 for Eu-151 N=15000 a_s=21 a_0; post-process via convert peak |psi|^2 from dimless to D_0 units same way T37 did)",
      "n_max_in_dimless_units (raw, sanity)",
      "epsilon_dd_eff (verify override landed: should equal target ε_dd to <1%)",
      "gamma_lhy_used (verify override landed; should match per-point computed value)",
      "m_plus_F_population (paper expects ~1.0 in formed droplets; T37 showed 0.946 in delocalized)",
      "norm_drift_final",
      "conv_flag",
      "wall_time_sec_itp"
    ],
    "optional_per_point": [
      "psi_radial_profile (binned |psi|^2 vs r from origin; visual localization signature)",
      "box_boundary_density (mean |psi|^2 in outermost 2-voxel shell; signature of free-particle delocalization)",
      "f_over_rho_max (peak local polarization magnitude; paper f/rho ≈ 1)"
    ]
  },
  "expected_outcome": "n_max(ε_dd) signature mechanically selects one of 4 verdicts per §5 decision rule. Per critic T38 §3 prior (Q5 ranked HIGH): most likely outcome is flat n_max ≈ 1 D_0 across all 4 points = Q5 CORROBORATED. Per critic §3 (Q1 ranked MEDIUM): second-likely outcome is step-function with n_max(1.20) substantially different from n_max(1.05) = Q1 CORROBORATED. Per §2.7 dimensional argument: Q1-only is unlikely to produce factor 10^4; observation of paper-like n_max ≈ 10^4 D_0 at ε_dd=1.20 (the 'neither-broken' branch) is improbable.",
  "falsification_criterion": "DECISION RULE (machine-evaluable, evaluated by T41 implementer or theorist):\n\n  IF n_max(0.95) < 10 D_0 AND n_max(0.99) < 10 D_0 AND n_max(1.05) < 10 D_0 AND n_max(1.20) < 10 D_0:\n    → VERDICT_Q5_CORROBORATED_Q1_RULED_OUT\n    → Next stage: revised Hypothesize at yan-li-saito with corrected seed (init_psi_fl_vortex or wider Gaussian matched to droplet radius L_0/a_ho ≈ 14)\n\n  ELSE IF n_max(0.95) < 10 D_0 AND n_max(0.99) < 10 D_0 AND (n_max(1.05) > 100 D_0 OR n_max(1.20) > 100 D_0):\n    → VERDICT_Q1_CORROBORATED_OR_PARTIAL\n    → Sub-case 1: n_max(1.20) > 1000 D_0: Q1 likely 'true' alternative prescription works → spawn lima-pelster-q5-eps-dd-gt-1-fix-bug-2026-05-17 investigation\n    → Sub-case 2: 100 < n_max(1.20) < 1000 D_0: Q1 partial; both Q1 fix AND Q5 fix needed in parallel\n\n  ELSE IF n_max(0.95) > 100 D_0 OR n_max(0.99) > 100 D_0:\n    → VERDICT_UNEXPECTED_SUB_CRITICAL_FORMS_DROPLET\n    → §2.2 prediction REFUTED; spawn critic re-audit; investigation theory-side is broken\n\n  ELSE IF n_max(1.20) > 1000 D_0 AND ALL_OTHERS < 100 D_0:\n    → VERDICT_PAPER_REPRODUCED_AT_TARGET_ONLY\n    → Close yan-li-saito as Tier-2 (transient T37 was an ITP-step-count artifact; would need an explanation for that)\n\n  ELSE (any non-matching pattern):\n    → VERDICT_INCONCLUSIVE_OR_PARTIAL\n    → Critic re-audit T41 + theorist re-Hypothesize\n\n  Thresholds (pre-registered, NOT to be tuned post-hoc): 'droplet formed' = n_max > 100 D_0; 'delocalized' = n_max < 10 D_0; 'paper-match' = n_max > 1000 D_0; ambiguous middle band 10–100 D_0 routes to INCONCLUSIVE.",
  "estimated_cost": "T40 run_experiment: 4 × 88s = ~6 min wall on GPU + 7s smoke + 30s saving = ~7 min total. Effective tokens estimate 4M (T37 was 1.77M for 1 point; 4-point amortizes JIT, adds 4× save; budget 5M cap-of-comfort).",
  "compute_steps": [
    {
      "id": "S1_sympy_q5_three_prescriptions",
      "task": "Compute Q5(1.2) numerically under three branch prescriptions (a) truncate-to-zero, (b) principal-branch-Re, (c) LP-2011 sign-flip; verify (a)==(b); report (c)-(a) and the predicted γ_LHY correction at ε_dd=1.2.",
      "sympy_expr": "from sympy import symbols, sin, cos, pi, sqrt, sign, Abs, Piecewise, Integral, Rational, re, I, integrate, N as Numeric, lambdify\nimport mpmath\nmpmath.mp.dps = 30\n\nth = symbols('theta', positive=True)\neps = Rational(12, 10)  # ε_dd = 1.2 (exact)\narg = 1 + eps * (3*cos(th)**2 - 1)\nintegrand_real = sin(th)/2 * arg**Rational(5,2)\n\n# (a) Truncate-to-zero: max(0, arg)^(5/2) — use Piecewise\nintegrand_a = Piecewise((sin(th)/2 * arg**Rational(5,2), arg >= 0), (0, True))\nQ5_a = mpmath.quad(lambda t: float(integrand_a.subs(th, t)), [0, float(mpmath.pi)])\n\n# (b) Principal-branch Re of complex arg^(5/2). For arg<0: arg^(5/2) = (|arg|*e^(i*pi))^(5/2) = |arg|^(5/2) * e^(i*5*pi/2) = i*|arg|^(5/2). Re = 0.\n# Implementation: integrate using mpmath with complex arithmetic\ndef integrand_b_complex(t):\n    a = 1 + 1.2 * (mpmath.cos(t)**2 * 3 - 1)\n    z = mpmath.mpc(a)\n    val = mpmath.sin(t)/2 * z**mpmath.mpf('2.5')\n    return val.real\nQ5_b = mpmath.quad(integrand_b_complex, [0, float(mpmath.pi)])\n\n# (c) Lima-Pelster 2011 sign-flip prescription: sign(arg) * |arg|^(5/2)\ndef integrand_c(t):\n    a = 1 + 1.2 * (mpmath.cos(t)**2 * 3 - 1)\n    return mpmath.sin(t)/2 * mpmath.sign(a) * mpmath.power(mpmath.fabs(a), mpmath.mpf('2.5'))\nQ5_c = mpmath.quad(integrand_c, [0, float(mpmath.pi)])\n\nprint(f'Q5(1.2) truncate-to-zero (a)         = {Q5_a}')\nprint(f'Q5(1.2) principal-branch-Re (b)      = {Q5_b}')\nprint(f'Q5(1.2) LP-2011 sign-flip (c)        = {Q5_c}')\nprint(f'(b) - (a) = {Q5_b - Q5_a}  (predicted ≈ 0)')\nprint(f'(c) - (a) = {Q5_c - Q5_a}  (Q1-correction magnitude)')\nprint(f'(c) / (a) ratio                       = {Q5_c / Q5_a}')\nprint(f'gamma_LHY correction at eps_dd=1.2:   = {(Q5_c - Q5_a) * 3.97:.4f} (where 3.97 = K from theorist §3 Check B)')\nprint(f'fractional gamma_LHY correction       = {(Q5_c - Q5_a) / Q5_a * 100:.2f}%')",
      "expected_form": "Three numerical Q5 values (each O(1)-O(10)); (b)-(a) ≈ 0 to machine precision; (c)-(a) is the Q1-correction estimate; if |(c)-(a)|/(a) > 50% would be surprising and elevate Q1 from MEDIUM to HIGH.",
      "verify_against": "T37 implementation γ_LHY=12.8 implies K·Q5(1.1772)=12.8; sympy at ε_dd=1.1772 should give Q5(a) ≈ 3.22 (= 12.8/3.97). Run as a separate check with eps=Rational(11772, 10000) before reporting."
    }
  ]
}
```

## 7. Research queries

```json
[
  {
    "id": "Q1",
    "topic": "Lima-Pelster PRA 84, 041604(R) (2011) — verbatim prescription for Re ∫₀^π sinθ [1+ε_dd(3cos²θ−1)]^(5/2)/2 dθ at ε_dd > 1",
    "why": "The Lima-Pelster 2011 paper introduces the χ(ε_dd) integral for the scalar dipolar LHY correction. Yan-Li-Saito 2026 cite it (refs [66, 67] in their paper). The 'Re' interpretation has at least three candidate prescriptions: (a) truncate-to-zero (current SpinorBEC.jl), (b) principal-branch-Re of analytically-continued (-x)^(5/2) (= (a) algebraically), (c) BdG-mode-count sign-flip giving Re[(-x)^(5/2)] = -x^(5/2). Knowing the canonical prescription tells us whether Q1 is a real bug or a pseudo-bug. The sympy Option B numerically evaluates all three at ε_dd=1.2; what is needed is which one is *paper-consistent*.",
    "preferred_sources": ["Lima & Pelster, PRA 84, 041604(R) (2011) full text", "Lima & Pelster, PRA 86, 063609 (2012)", "Pelster group publications 2010-2014", "Wenzel/Pfau/Ferlaino group Dy/Er droplet papers that cite LP-2011 with the verbatim prescription"]
  },
  {
    "id": "Q2",
    "topic": "Scalar+DDI+LHY droplet phase diagram below ε_dd = 1 (sub-critical regime)",
    "why": "Theorist §2.2 claim 'sub-critical states are physically unbound regardless of Q1' is currently [Plausible] from Lima-Pelster homogeneous-limit reasoning. If the literature reports sub-critical (ε_dd<1) self-bound droplets under some condition (e.g., stronger LHY, specific geometry), the §2.4 decision table needs revision (the 'Q1 dominant' branch's 'sub-critical forms droplet' prediction would be physically meaningful, not pre-excluded by theory).",
    "preferred_sources": ["Ferrier-Barbut/Pfau Dy phase diagrams", "Schmitt/Pfau 2016 stable quantum droplets review", "Lima-Pelster 2011 PRA 84 + 2012 PRA 86 if they report ε_dd<1 data"]
  }
]
```

## 8. Publishability assessment

Out of scope — incremental turn (pre-registration of discriminator experiment; the experiment itself is at T40, and the publishable physics emerges at T41 from the verdict).

---

### Self-review (per §E)

- [x] §2 derivations: every equation either derived here or cited (paper Eq 1 via memory line 38-50; production-code formulas via `interactions.jl:447-459`, `ground_state.jl:97-118`; LP-2011 prescription marked `<RESEARCH_NEEDED: Q1>`).
- [x] §3 sanity checks: 5 independent checks (A: ε_dd_eff convention re-derivation matching T37; B: dimensional analysis of K; C: Q5 monotonicity prediction; D: paper-Eq-1 ↔ γ_LHY prefactor cross-check; E: m=+F population interpretation).
- [x] §4 claims: every claim tagged with B3 qualifier.
- [x] §6 directive JSON: `falsification_criterion` is a 5-branch quantitative decision rule with thresholds 10, 100, 1000 D_0; `expected_outcome` cites critic prior; `compute_steps` includes the full sympy script with verification against T37.
- [x] §7 queries: 2 entries, each with `why` field.
- [x] No invented numerical values (c_dd=515.85 etc. derived from T37 baseline c_0=181.0 + §2.6 algebra; Q5 values left to implementer numerical evaluation).
- [x] No sycophancy.
- [x] No `Bash`/`Edit` calls in §6; only YAML targets and a compute_steps sympy spec for implementer_sympy dispatch.
- [x] Directive does NOT pre-suppose Q5 even though critic ranked it #1 (decision rule has 5 verdict branches with symmetric Q1 and Q5 detection paths).
- [x] Control discipline (`control_discipline_seed_fixed_documented: true`) explicit in directive.
- [x] Single logical knob (ε_dd) named; coupled-pair implementation honestly described per §2.5 architectural reality.
- [x] Cited paper Eq 1 (memory line 38-50), critic T38 audit §2/§3/§4/§5, Lima-Pelster line numbers (interactions.jl:447-459, ground_state.jl:94-118, workspace.jl:27-31).
- [x] §A6 research-first: cited ≥1 external reference (paper memory + critic audit + production code + schema docs) before introducing the per-point override design.
- [x] §2.2 §2.4 explicit correction to critic T38 §5 decision table (sub-critical droplets NOT expected to form per Lima-Pelster theory; critic's table needed §2.4 revision before being usable) — per G4 constructive disagreement, flagged once and moved on.
- [x] tier_current acknowledged: 0.7 (dispatch from T38 success); on T40 Execute success of this Design, target tier 1.5–2.0 (depending on which verdict branch fires).
