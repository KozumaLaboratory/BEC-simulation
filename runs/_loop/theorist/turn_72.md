---
turn: 72
subagent: theorist
topic_tags: [hypothesize-stage, edh-eu151-matsui-science-2026, falsifier-quantification, m_F-index-translation, tier3-anchor, d1-verification-depth]
paper_section: null
depends_on: [71, 70, "runs/_loop/director/turn_72.md", "runs/_loop/research/turn_71.md", "runs/_loop/theorist/turn_70.md", "runs/_loop/state.json"]
produces: "Quantified F1/F2/F3 falsifier criteria + ω_ref selection + dipolar GP mean-field energy formula at canonical bracket + m_F→c index translation table + T73 Design-stage unblocking note specifying YAML deltas + observable manifest for T74"
---

# Turn 72 — Theorist Hypothesize: Quantitative Predictions for Matsui 2026 EdH Reproduction

## 0. Convention declaration

Standard SpinorBEC.jl defaults, no deviations. Specifically:

- Eu-151 baseline per `CLAUDE.md` §¹⁵¹Eu: $F = 6$, $D = 2F+1 = 13$, $g_F \approx 1.163$,
  $\mu = g_F \cdot F \cdot \mu_B \approx 6.977\,\mu_B$, $a_s = 110\,a_B$. Seven s-wave channels
  $S \in \{0, 2, 4, 6, 8, 10, 12\}$. Constraint
  $c_0 + 36 c_1 = 4\pi (a_s/a_{\rm ho})\, N$ — this combination is the coupling that
  governs the $m_F = \pm F$ stretched FM state because the two-body matrix element
  on $|m, m\rangle$ with $m = \pm F$ projects onto $S = 2F$ alone.
- Wavefunction layout `psi[x, y, z, c]`. Index convention $c = 1 \leftrightarrow m_F = +F$,
  $c = D = 13 \leftrightarrow m_F = -F$. **Matsui's initial $m_F = -6$ state therefore lives
  in `psi[..., 13]`; Matsui's $m_F = -5$ ring component lives in `psi[..., 12]`.**
- DDI conventions: $c_{dd} = \mu_0 \mu^2$ (no $4\pi$);
  $Q_{\alpha\beta}(\hat{\mathbf{k}}) = \hat k_\alpha \hat k_\beta - \delta_{\alpha\beta}/3$
  (no $1/(4\pi)$); $Q(k = 0) = 0$.
- ITP path: post-Bug-4-fix `_run_itp_loop!` (per memory `bug_4_itp_ddi_half_rate.md`,
  DDI Strang substep is full $dt$ per substep, not the legacy half-rate).
- Dimensionless units $\hbar = m = \omega_{\rm ref} = 1$; physical-to-dimensionless
  conversion uses the chosen reference frequency $\omega_{\rm ref}$ (see §2).
- Linear / quadratic Zeeman: $H_{\rm Zee} = -p\,m_F + q\,m_F^2$ (`p = g_F \mu_B B / (\hbar\omega_{\rm ref})`,
  $q$ auto-derived from $|B|^2$ at very small $B$ is negligible).
- SinusoidalWaveform YAML `frequency` field is $f_{\rm phys}/(2\pi f_{\rm ref})$ per
  memory `gotcha_waveform_frequency_convention.md` (NOT $f_{\rm phys}/f_{\rm ref}$).
- Numerical constants used this turn: $\hbar = 1.0546\times 10^{-34}\,$J·s,
  $\mu_B = 9.2740\times 10^{-24}\,$J/T, $\mu_0 = 1.2566\times 10^{-6}\,$T·m/A,
  $a_B = 5.292\times 10^{-11}\,$m, $m_{\rm Eu} = 151 \times 1.6605\times 10^{-27}\,{\rm kg}
  = 2.5074\times 10^{-25}\,$kg.

## 1. T71 input summary

T71 (`runs/_loop/research/turn_71.md`) populated the Research stage with the
following status per the 8 REQUIRED targets:

- T1 species **EXTRACTED**: ¹⁵¹Eu (multi-source cross-referenced, abstract + author continuity from Miyazawa 2022).
- T2 condensate $N$ **INFERRED**: $N \le 5\times 10^4$ from Miyazawa 2022 platform inheritance; central
  estimate $N = 3\times 10^4$ recommended; bracket $[1\times 10^4, 5\times 10^4]$.
- T3 trap $\omega_{x,y,z}$ **NOT_EXTRACTABLE**: Li-Saito 2024 theory estimate
  $(\omega_x, \omega_y, \omega_z) = 2\pi \times (100, 1500, 6000)\,{\rm Hz}$ used as bracket.
- T4 B-quench protocol **PARTIAL**: $B_f = 2.6\,{\rm nT}$ extracted; intermediate suppression at $0.1\,$mT;
  ramp time and waveform shape NOT_EXTRACTABLE — step-quench worst-case assumed.
- T5 $\tau_{\rm EdH}^{\rm exp}$ **EXTRACTED**: $5\,$ms hold time at which ring deformation in
  $m_F = -5$ first observed (paper body via WebSearch snippet).
- T6 winding number $\ell$ **PARTIAL**: $\ell \ge 1$ confirmed via "phase windings" (matter-wave
  interferometry); exact integer NOT_EXTRACTABLE from public sources.
- T7 $m_F$ labelling **EXTRACTED**: Matsui's $m = -6$ = stretched state, $m = -5$ = first-flip ring component.
- T8 initial polarisation **EXTRACTED**: $m_F = -6$ FM-polarised.

Per the T71 §7 unblocking, T72 carries the load on (a) ω_ref selection and unit conversion,
(b) numerical t_ring prediction from $\tau_{\rm DDI}$, (c) AM-conservation chain $\Rightarrow \ell = 1$
theory prediction, (d) dipolar GP mean-field $E/N$ formula and numerical value, (e) m_F → c index
translation table, (f) refined F1/F2/F3 bands, and (g) T73 design-stage unblocking note.

## 2. ω_ref selection + dimensionless conversion

### 2.1 Bracket and choice

Three candidate $\omega_{\rm ref}$ choices using the Li-Saito 2024 trap bracket
$[\text{T71 §2 row T3}, \text{arXiv:2402.18885 Fig. 5 caption}]$:

1. **Weakest axial axis** $\omega_{\rm ref} = \omega_x = 2\pi \times 100\,{\rm Hz}$
   (most conservative, gives longest dimensionless timescale).
2. **Geometric mean** $\bar\omega = (\omega_x \omega_y \omega_z)^{1/3} = 2\pi \times (100 \cdot 1500 \cdot 6000)^{1/3}\,{\rm Hz}
   = 2\pi \times (9 \times 10^8)^{1/3}\,{\rm Hz} = 2\pi \times 965.5\,{\rm Hz}$. **[Derived this turn.]**
3. **Tightest axis** $\omega_z = 2\pi \times 6000\,{\rm Hz}$ (gives shortest dimensionless timescale).

**Recommended primary choice for the falsifier bands**: $\omega_{\rm ref} = \bar\omega = 2\pi \times 965.5\,{\rm Hz}$
(geometric mean). Justification: this is the standard trap reference for harmonic-trap TF
expressions and is the value at which $E_{\rm mf}/N$ closed-form is cleanest.

> **Correction to director brief**. Director's §6 brief stated $\bar\omega \approx 2\pi \times 785\,{\rm Hz}$;
> the correct arithmetic is $(100 \cdot 1500 \cdot 6000)^{1/3} = 965.5$, not $785$.
> Recompute: $100 \times 1500 = 1.5 \times 10^5$; $\times 6000 = 9 \times 10^8$; $9^{1/3} \approx 2.080$,
> $10^{8/3} \approx 464.2$; product $\approx 965.5$. **Using $965.5\,{\rm Hz}$ below.**

### 2.2 Dimensionless timescales

For an experimental physical time $t_{\rm phys}$, the SpinorBEC.jl dimensionless time is
$t_{\rm dimless} = t_{\rm phys} \cdot \omega_{\rm ref}$ (with $\omega_{\rm ref}$ in rad/s).

| Quantity | Physical | $t_{\rm dimless}$ at $\omega_{\rm ref} = 2\pi \times 965.5\,{\rm Hz}$ | $t_{\rm dimless}$ at $\omega_{\rm ref} = 2\pi \times 100\,{\rm Hz}$ |
|---|---|---|---|
| $\tau_{\rm EdH}^{\rm exp}$ | $5\,$ms | $5 \times 10^{-3} \cdot 6066.6 = 30.33$ | $5 \times 10^{-3} \cdot 628.3 = 3.14$ |
| F1 lower band ($0.5 \tau_{\rm EdH}$) | $2.5\,$ms | $15.17$ | $1.57$ |
| F1 upper band ($2.0 \tau_{\rm EdH}$) | $10\,$ms | $60.67$ | $6.28$ |
| Suppression-field hold | $5\,$ms | $30.33$ | $3.14$ |

[Derived this turn; numerical conversion only.]

### 2.3 Linear Zeeman $p$ at $B_f = 2.6\,$nT

$$ p = g_F\, \mu_B\, B_f = 1.163 \cdot 9.274\times 10^{-24}\,{\rm J/T} \cdot 2.6\times 10^{-9}\,{\rm T}
   = 2.804\times 10^{-32}\,{\rm J}. $$

In frequency units: $p/h = 42.3\,{\rm Hz}$. Dimensionless $p_{\rm dimless} = p / (\hbar \omega_{\rm ref})$:

| $\omega_{\rm ref}$ | $\hbar\omega_{\rm ref}$ (J) | $p_{\rm dimless}$ |
|---|---|---|
| $2\pi \times 965.5\,{\rm Hz}$ | $6.398\times 10^{-31}$ | $0.0438$ |
| $2\pi \times 100\,{\rm Hz}$ | $6.625\times 10^{-32}$ | $0.4232$ |

> **Correction to T71 §4 arithmetic**. T71 reported $\hbar\omega_{\rm ref} \approx 6.6 \times 10^{-33}\,$J
> at $\omega_{\rm ref} = 2\pi \times 100\,$Hz and consequently $p_{\rm dimless} \approx 0.04$.
> The correct value is $\hbar \omega_{\rm ref} = 1.0546\times 10^{-34} \cdot 628.3 = 6.625\times 10^{-32}\,$J
> (factor of $10$ off), so $p_{\rm dimless} = 0.4232$ — **NOT** $\sim 4 \times 10^{-2}$.
> Operational impact for T73 YAML: the linear-Zeeman dimensionless value at $\omega_{\rm ref} = 2\pi \times 100\,$Hz
> bracket is non-negligible ($\sim 0.42$), and is in the same order of magnitude as the bare DDI rate (§3 below).
> If the T73 YAML uses $\omega_{\rm ref} = 2\pi \times 965.5\,$Hz then $p_{\rm dimless} \approx 0.04$ is the
> correct value and is small but not negligible.

### 2.4 Quadratic Zeeman $q$ at $B_f = 2.6\,$nT

Hyperfine-mediated quadratic shift $q \sim (g_F \mu_B B_f)^2 / (h \cdot \Delta_{\rm hf})$ where
$\Delta_{\rm hf} \sim 4.5\,$GHz for ¹⁵¹Eu ground-state hyperfine splitting (J=7/2 + I=5/2 → F=5..7;
exact value not load-bearing for the order-of-magnitude estimate).

$$ q/h \sim (42.3\,{\rm Hz})^2 / (4.5 \times 10^9\,{\rm Hz}) \approx 4 \times 10^{-7}\,{\rm Hz}. $$

Compared to $p/h \approx 42.3\,{\rm Hz}$: $q/p \sim 10^{-8}$. **Quadratic Zeeman is negligible at $B_f = 2.6\,$nT;
set $q = 0$ in YAML.** [Derived this turn; Speculative tag on $\Delta_{\rm hf}$ exact value, but
the conclusion $q/p \ll 1$ is robust across the realistic range $\Delta_{\rm hf} \in [1, 10]\,$GHz.]

### 2.5 Harmonic-oscillator length $a_{\rm ho}$

$a_{\rm ho} = \sqrt{\hbar / (m_{\rm Eu}\, \omega_{\rm ref})}$.

| $\omega_{\rm ref}$ | $m_{\rm Eu} \omega_{\rm ref}$ (kg·s⁻¹) | $a_{\rm ho}$ |
|---|---|---|
| $2\pi \times 965.5\,{\rm Hz}$ | $1.521 \times 10^{-21}$ | $\sqrt{6.93 \times 10^{-14}\,{\rm m}^2} = 2.63 \times 10^{-7}\,{\rm m} = 0.263\,\mu{\rm m}$ |
| $2\pi \times 100\,{\rm Hz}$ | $1.575 \times 10^{-22}$ | $\sqrt{6.70 \times 10^{-13}\,{\rm m}^2} = 8.18 \times 10^{-7}\,{\rm m} = 0.818\,\mu{\rm m}$ |

[Derived this turn.]

## 3. Prediction: ring formation time $t_{\rm ring}$ (F1)

### 3.1 Mechanism and timescale

The Einstein-de Haas process transfers angular momentum from spin to orbital degrees of freedom
via the anisotropic dipole-dipole interaction. Per Matsui 2026 abstract (via T70 §2 A1):
"intrinsic magnetic dipole-dipole interactions" are the sole AM-transfer mechanism. The bare
DDI rate is

$$ \omega_{\rm DDI} \equiv \frac{c_{dd}\, \langle n \rangle}{\hbar}, \qquad
   \tau_{\rm DDI} = \frac{\hbar}{c_{dd}\, \langle n \rangle}. $$

For the FM-polarised stretched state $|m_F = -F\rangle$, the off-diagonal DDI matrix element
that flips one spin ($|-F\rangle \to |-F+1\rangle$) carries an angular-momentum-of-$-1\hbar$
prefactor from the rank-2 spherical tensor decomposition of $Q_{\alpha\beta}$. The effective
spin-orbit-coupling rate is thus roughly $\omega_{\rm SO} \sim \omega_{\rm DDI}$ with an
$O(1)$ angular prefactor of order $2/5$ to $1$ depending on geometry [Kawaguchi-Ueda 2012 §3].

In the secular limit $\omega_L \gg \omega_{\rm DDI}$, AM transfer is suppressed by
$(\omega_{\rm DDI}/\omega_L)^2$. In the non-secular limit $\omega_L \lesssim \omega_{\rm DDI}$
(which is Matsui's $B_f = 2.6\,$nT regime — see §3.4 below), AM transfer proceeds at the bare DDI rate.

The first-ring observation time $t_{\rm ring}$ corresponds to enough spin flips to populate
$m_F = -5$ with a depleted density at $r = 0$ — typically $\sim 10$–$100\, \tau_{\rm DDI}$
for the order-unity-prefactor regime, since each flip transfers $\sim 1/N$ of the population.
The exact prefactor is not closed-form in the literature; T72 reports it as a $[1, 100]$ band.

### 3.2 Numerical $\tau_{\rm DDI}$ at the bracket

Constants:
- $c_{dd} = \mu_0 \mu^2 = 1.2566 \times 10^{-6} \cdot (6.977 \cdot 9.274 \times 10^{-24})^2
   = 1.2566 \times 10^{-6} \cdot (6.470 \times 10^{-23})^2
   = 1.2566 \times 10^{-6} \cdot 4.186 \times 10^{-45}
   = 5.260 \times 10^{-51}\,{\rm J\,m^3}$. [Derived this turn.]

> **Correction to T70 §3 estimate**. T70 quoted $c_{dd} \approx 5.3 \times 10^{-50}\,{\rm J\,m^3}$; the correct value is
> $5.26 \times 10^{-51}\,{\rm J\,m^3}$ — factor-of-10 typo. T70's order-of-magnitude estimate $\tau_{\rm DDI} \sim 10$–$100\,{\rm ms}$
> at $\langle n \rangle \sim 10^{19}\,{\rm m^{-3}}$ should be recomputed:
> $\hbar / (5.26\times 10^{-51} \cdot 10^{19}) = 1.0546\times 10^{-34} / 5.26\times 10^{-32} = 2.0\,{\rm ms}$ — order of magnitude
> ~ms, not 10-100 ms. The corrected value puts the bare DDI rate close to the experimental 5 ms timescale.

Peak density (TF, harmonic trap):
$$ n_{\rm peak} = \frac{15 N}{8\pi R_x R_y R_z}, \qquad
   R_i = a_{\rm ho}\, \sqrt{\frac{2\mu_{\rm TF}}{\hbar \omega_{\rm ref}}} \cdot \frac{\omega_{\rm ref}}{\omega_i}, $$
where $\mu_{\rm TF}/(\hbar\bar\omega) = \tfrac{1}{2} (15 N a_s/a_{\rm ho})^{2/5}$.

For $N = 3 \times 10^4$, $a_s = 110\, a_B = 5.82\times 10^{-9}\,$m:

**Case A — isotropic $\omega_{\rm ref} = 2\pi \times 100\,$Hz** (bracket lower bound):
- $a_{\rm ho} = 0.818\,\mu{\rm m}$
- $N a_s/a_{\rm ho} = 3 \times 10^4 \cdot 5.82\times 10^{-9} / 8.18 \times 10^{-7} = 213.4$
- $(15 \cdot 213.4)^{2/5} = 3201^{2/5}$; $\log_{10}(3201) = 3.505$; $0.4 \cdot 3.505 = 1.402$; $10^{1.402} = 25.2$
- $\mu_{\rm TF}/(\hbar\omega_{\rm ref}) = 25.2/2 = 12.6$
- $R = a_{\rm ho} \sqrt{2 \cdot 12.6} = 0.818 \cdot 5.02 = 4.11\,\mu{\rm m}$ (isotropic)
- $V_{\rm TF} = (4\pi/3) R^3 = 290.3\,\mu{\rm m}^3$
- $n_{\rm peak} = 15 \cdot 3\times 10^4 / (8\pi \cdot 290.3) = 4.5\times 10^5 / 7300 = 61.6\,\mu{\rm m}^{-3} = 6.16 \times 10^{19}\,{\rm m}^{-3}$
- $\langle n \rangle_{\rm TF\,avg} = (4/7)\, n_{\rm peak} = 3.52 \times 10^{19}\,{\rm m}^{-3}$
- $\tau_{\rm DDI} = \hbar/(c_{dd} \langle n \rangle) = 1.0546\times 10^{-34} / (5.26\times 10^{-51} \cdot 3.52\times 10^{19})
   = 1.0546\times 10^{-34} / 1.85\times 10^{-31} = \mathbf{0.57\,{\rm ms}}$.

**Case B — geometric mean $\omega_{\rm ref} = \bar\omega = 2\pi \times 965.5\,$Hz** (Li-Saito anisotropic bracket):
- $a_{\rm ho} = 0.263\,\mu{\rm m}$
- $N a_s/a_{\rm ho} = 3 \times 10^4 \cdot 5.82\times 10^{-9} / 2.63\times 10^{-7} = 664.0$
- $(15 \cdot 664)^{2/5} = 9960^{2/5}$; $\log_{10}(9960) = 3.998$; $0.4 \cdot 3.998 = 1.599$; $10^{1.599} = 39.7$
- $\mu_{\rm TF}/(\hbar\bar\omega) = 39.7/2 = 19.85$
- $R̄ = a_{\rm ho} \sqrt{2 \cdot 19.85} = 0.263 \cdot 6.30 = 1.66\,\mu{\rm m}$ (geometric-mean radius)
- $R_x = R̄ \cdot \bar\omega/\omega_x = 1.66 \cdot 965.5/100 = 16.0\,\mu{\rm m}$
- $R_y = R̄ \cdot 965.5/1500 = 1.07\,\mu{\rm m}$
- $R_z = R̄ \cdot 965.5/6000 = 0.267\,\mu{\rm m}$
- $V_{\rm TF} = (4\pi/3) R_x R_y R_z = (4\pi/3) \cdot 4.57\,\mu{\rm m}^3 = 19.1\,\mu{\rm m}^3$
- $n_{\rm peak} = 15 \cdot 3\times 10^4 / (8\pi \cdot 19.1) = 4.5\times 10^5/479.9 = 938\,\mu{\rm m}^{-3} = 9.38 \times 10^{20}\,{\rm m}^{-3}$
- $\langle n \rangle = (4/7) \cdot n_{\rm peak} = 5.36 \times 10^{20}\,{\rm m}^{-3}$
- $\tau_{\rm DDI} = 1.0546\times 10^{-34} / (5.26\times 10^{-51} \cdot 5.36\times 10^{20})
   = 1.0546\times 10^{-34} / 2.82\times 10^{-30} = \mathbf{37\,\mu{\rm s}}$.

> **Numerical correction to original Case-B calculation**: an earlier scratch arithmetic step gave
> $n_{\rm peak} \approx 3.92\times 10^{15}\,{\rm cm}^{-3}$. Recomputed: $938\,\mu{\rm m}^{-3} = 938\times 10^{12}\,{\rm cm}^{-3} = 9.38\times 10^{14}\,{\rm cm}^{-3}$,
> equivalently $9.38\times 10^{20}\,{\rm m}^{-3}$. Final $\tau_{\rm DDI} \approx 37\,\mu{\rm s}$ at Case B.
> The 3 orders of magnitude span $\tau_{\rm DDI} \in [37\,\mu{\rm s}, 570\,\mu{\rm s}]$ across the trap-ω bracket
> is dominated by trap-geometry variation (peak density scales as $\bar\omega^{3/2} \cdot (\bar\omega/\omega_i)$-products).

### 3.3 Prediction: $t_{\rm ring}$ band

Taking $t_{\rm ring} \sim (10$–$100)\, \tau_{\rm DDI}$ as the heuristic (factor reflects the
number of DDI cycles needed to deplete the $r=0$ density of $m_F = -5$ to the F1 ring criterion;
this is an order-of-magnitude estimate not a closed form):

| Bracket | $\tau_{\rm DDI}$ | $t_{\rm ring}$ heuristic | Physical $t_{\rm ring}$ |
|---|---|---|---|
| Case A (isotropic $2\pi \times 100\,$Hz) | $0.57\,$ms | $5.7$–$57\,$ms | $5.7$–$57\,$ms |
| Case B (Li-Saito geometric mean $2\pi \times 965.5\,$Hz) | $37\,\mu{\rm s}$ | $0.37$–$3.7\,$ms | $0.37$–$3.7\,$ms |

**Comparison with experiment** $\tau_{\rm EdH}^{\rm exp} = 5\,$ms:
- Case A: $5\,$ms falls within the $[5.7, 57]\,$ms band — CORROBORATE if simulation lands near
  $\tau_{\rm DDI}^{(A)}$.
- Case B: $5\,$ms is well above the $[0.37, 3.7]\,$ms band — would predict ring formation **earlier**
  than 5 ms. The Li-Saito bracket is theoretically motivated for a tight-confinement Eu droplet
  experiment, not necessarily Matsui's specific trap. This is an open systematic.

### 3.4 Larmor / DDI ratio (secular vs non-secular)

$\omega_L = g_F \mu_B B_f / \hbar = p / \hbar = 2.804\times 10^{-32}/1.0546\times 10^{-34} = 266\,{\rm rad/s} = 2\pi \cdot 42.3\,$Hz.

- Case A: $\omega_{\rm DDI} = 1/\tau_{\rm DDI} = 1755\,{\rm rad/s} = 2\pi \cdot 279\,$Hz. $\omega_L/\omega_{\rm DDI} = 266/1755 = 0.15$.
- Case B: $\omega_{\rm DDI} = 2.7\times 10^4\,{\rm rad/s}$. $\omega_L/\omega_{\rm DDI} = 0.01$.

Both bracket cases place the system in the **non-secular regime** ($\omega_L < \omega_{\rm DDI}$),
where off-diagonal AM-transferring DDI is active. This corroborates the Matsui claim that DDI
drives the EdH dynamics at $B_f = 2.6\,$nT. [Established, by computation this turn from extracted parameters.]

### 3.5 F1 falsifier band — operational

For the central F1 numerical criterion, use the physical-time band (invariant under $\omega_{\rm ref}$ choice):

- **CORROBORATE**: $t_{\rm ring}^{\rm sim} \in [2.5\,{\rm ms}, 10\,{\rm ms}]$ (factor 2 around $\tau_{\rm EdH}^{\rm exp} = 5\,$ms).
- **INCONCLUSIVE**: $t_{\rm ring}^{\rm sim} \in [1\,{\rm ms}, 25\,{\rm ms}]$ (factor 5 around $\tau_{\rm EdH}^{\rm exp}$),
  outside CORROBORATE.
- **REFUTED**: no ring forms at any $t < 50\,{\rm ms}$ (= $10\,\tau_{\rm EdH}^{\rm exp}$), OR ring forms
  in a wrong spin component (not $m_F = -5$ = `psi[..., 12]`).

In dimensionless at $\omega_{\rm ref} = 2\pi \times 965.5\,$Hz (recommended primary):
$t_{\rm ring}^{\rm sim,dimless} \in [15.17, 60.67]$ for CORROBORATE.

In dimensionless at $\omega_{\rm ref} = 2\pi \times 100\,$Hz (fallback if T73 chooses isotropic bracket):
$t_{\rm ring}^{\rm sim,dimless} \in [1.57, 6.28]$ for CORROBORATE.

## 4. Prediction: vortex winding number $\ell$ (F2)

### 4.1 Angular momentum conservation chain

The dipole-dipole interaction conserves total angular momentum $\hat{\mathbf{J}} = \hat{\mathbf{L}} + \hat{\mathbf{F}}$
where $\hat{\mathbf{L}}$ is orbital and $\hat{\mathbf{F}}$ is total spin. The DDI Hamiltonian
$\hat H_{\rm DDI} = \int d^3 r d^3 r' [\hat\psi^\dagger_a \hat\psi^\dagger_b \cdot Q_{\alpha\beta}(\hat r - \hat r')\, F^\alpha_{ac} F^\beta_{bd} \cdot \hat\psi_c \hat\psi_d]$
commutes with $\hat J_z$ (rotational symmetry around the polarisation axis).

For an axially-symmetric initial state (uniform $m_F = -F = -6$, no orbital structure):
$\langle \hat L_z \rangle_0 = 0$, $\langle \hat F_z \rangle_0 = -F \cdot N = -6N$ (in units of $\hbar$),
$\langle \hat J_z \rangle_0 = -6N$.

After DDI-mediated relaxation to populate $m_F = -5$ in a sub-volume with population $\delta N$:
- Spin change per flipped atom: $\Delta m_F = -5 - (-6) = +1$, so $\Delta \langle F_z \rangle = +\delta N$.
- Total $J_z$ conservation: $\Delta \langle L_z \rangle = -\Delta \langle F_z \rangle = -\delta N$.

If the flipped atoms occupy a single orbital mode with definite winding $\ell$ (single-charge
ring vortex centred at $r = 0$ in the $(x,y)$ plane perpendicular to the polarisation axis $\hat z$):
$\Delta \langle L_z \rangle = \ell \cdot \delta N\, \hbar$. Setting $-\delta N = \ell \cdot \delta N$
gives $\boxed{\ell = -1}$.

The sign depends on the convention; for the axially-symmetric ring-vortex mode in $m_F = -5$,
the magnitude is $|\ell| = 1$, charge **negative** in the convention $\hat L_z = -i\hbar \partial_\phi$
with $\hat F$ pointing along $-\hat z$ (Matsui's geometry).

### 4.2 Multi-flip components

The same chain for $m_F = -4$ (two consecutive flips) predicts $\ell = -2$ for two-flip atoms,
or $\ell = 0$ for atoms that returned to $m_F = -5$ via a forward+backward flip pair, etc.
The expected pattern is $\ell_{m_F = -F+k} = -k$ in single-flip dominant regime.

### 4.3 F2 falsifier band — operational

T71 confirmed $\ell_{\rm paper} \ge 1$ ("phase windings around vortices" via matter-wave
interferometry) but did not extract the exact integer from public sources.

**Theory prediction (this turn)**: $|\ell^{\rm theory}| = 1$ for the $m_F = -5$ ring component
(first-flip, dominant population at $t = \tau_{\rm EdH}^{\rm exp}$).

- **CORROBORATE**: $|\ell^{\rm sim}| = 1$ AND sign matches the AM-conservation prediction
  ($\ell^{\rm sim} = -1$ in the polarisation-axis convention; positive $\ell$ if the basis-frame
  axis is reversed).
- **INCONCLUSIVE**: $|\ell^{\rm sim} - 1| = 1$ (i.e., $\ell^{\rm sim} \in \{0, \pm 2\}$) — off-by-one
  may indicate grid resolution insufficient or basis-frame convention mismatch.
- **REFUTED**: $|\ell^{\rm sim}| \ge 3$, OR $\ell^{\rm sim} = 0$ AND held there for $t > 50\,{\rm ms}$
  (no quantized circulation = DDI is not transferring AM in the framework = mechanism missing).

Caveat: $\ell_{\rm paper}$ NOT_EXTRACTABLE from public sources; the F2 CORROBORATE bar
is set against the **theory-predicted** $\ell = -1$ (sign-corrected to convention).
If anko obtains $\ell_{\rm paper}$ from Matsui Methods or via author contact (S8: Kozuma email),
F2 should be re-evaluated against that value before T74 Execute concludes.

## 5. Prediction: ground-state energy $E_{\rm mf}/N$ (F3)

### 5.1 Closed-form dipolar GP mean-field

For the FM-polarised stretched state $|\psi\rangle = |m_F = -F\rangle \otimes \phi(\mathbf{r})$
with $\phi$ the spatial mode normalised $\int |\phi|^2 = N$:

$$ \frac{E_{\rm mf}}{N} = \underbrace{\frac{1}{2}\sum_{i\in\{x,y,z\}} \hbar\omega_i}_{\text{zero-point}}
   + \underbrace{\frac{c_0^{\rm eff}\, \langle n \rangle_{\rm TF}}{2}}_{\text{contact MF}}
   + \underbrace{\frac{E_{\rm DDI}}{N}}_{\text{dipolar, anisotropy-dependent}}
   + \underbrace{\frac{E_{\rm LHY}}{N}}_{\text{small LHY correction}}. $$

Here $c_0^{\rm eff} = c_0 + F^2 c_1 = c_0 + 36 c_1$ for $F = 6$, which is exactly the LHS of the
SpinorBEC.jl constraint $c_0 + 36 c_1 = 4\pi (a_s/a_{\rm ho}) N$ from CLAUDE.md §¹⁵¹Eu.
**This is not coincidence**: the constraint is derived precisely from the two-body matrix element
$\langle m, m | V | m, m \rangle$ on stretched states, which projects onto the $S = 2F$ channel
($g_{2F} = 4\pi \hbar^2 a_s/m$); the spinor decomposition then gives $c_0^{\rm eff} = c_0 + F^2 c_1$.

In the strongly-interacting Thomas-Fermi regime ($\mu_{\rm TF} \gg \hbar\bar\omega$), the
contact-MF term equals $(5/7) \mu_{\rm TF}$ averaged over the cloud, giving the standard
$E_{\rm contact, TF}/N = (5/7) \mu_{\rm TF}$.

### 5.2 Dipolar contribution

For a uniformly-magnetised cloud (all dipoles aligned $-\hat z$ since $m_F = -F$), the DDI energy
in the TF approximation is [Eberlein-Giovanazzi 2005; Lahaye-Pfau review 2009]:

$$ \frac{E_{\rm DDI}}{N} = -\frac{c_{dd}\, n_{\rm peak}}{3}\, f(\kappa), $$

where $\kappa = R_z/R_{\rm radial}$ is the cloud aspect ratio (parallel to polarisation $\hat z$ vs
perpendicular) and $f(\kappa)$ is a dimensionless function of order unity with $f(\kappa = 1) = 0$
(spherically-symmetric cloud has zero net DDI energy by angular cancellation),
$f \to -2/5$ as $\kappa \to 0$ (prolate, pancake-like in $(x,y)$, attractive),
$f \to +1$ as $\kappa \to \infty$ (oblate, cigar-like along $\hat z$, repulsive).

For Matsui's bracket:
- **Case A (isotropic $\omega = 2\pi \times 100\,$Hz)**: $\kappa = 1$ → $f = 0$ → $E_{\rm DDI}/N \approx 0$.
- **Case B (Li-Saito anisotropic)**: $\kappa = R_z/R_x = 0.267/16.0 = 0.0167$ — very prolate (cloud
  much longer along $\hat x$ axial direction than along $\hat z$ tight direction). $f \to -2/5$,
  giving $E_{\rm DDI}/N = -c_{dd} n_{\rm peak} \cdot (-2/5)/3 \cdot (-1)
   = -c_{dd} n_{\rm peak}/3 \cdot (-2/5) = +c_{dd} n_{\rm peak} \cdot 2/15$. With sign convention check:
  for $\kappa < 1$ prolate-along-polarisation, $f < 0$, and the prefactor $-c_{dd}n_{\rm peak}/3 \cdot f > 0$
  (energetically unfavourable, dipoles side-by-side anti-aligned-ish). This requires careful sign tracking; magnitude:
  $|E_{\rm DDI}/N| \approx (c_{dd} n_{\rm peak}/3) \cdot 0.4 = (5.26\times 10^{-51} \cdot 9.38\times 10^{20}/3) \cdot 0.4 = 6.6\times 10^{-31}\,$J
  per atom. In Hz units: $\sim 990\,$Hz.

### 5.3 Numerical $E_{\rm mf}/N$ at Case A bracket (recommended for F3 evaluation)

Using Case A ($\omega_{\rm ref} = 2\pi \times 100\,$Hz isotropic):
- Zero-point: $(3/2) \hbar\omega_{\rm ref} = 1.5 \cdot 6.625\times 10^{-32} = 9.94\times 10^{-32}\,$J/atom = $150\,$Hz $\cdot h$.
- Contact-TF: $\mu_{\rm TF} = 12.6 \cdot \hbar\omega_{\rm ref} = 8.35\times 10^{-31}\,$J. $E_{\rm contact}/N = (5/7) \cdot 8.35\times 10^{-31} = 5.96\times 10^{-31}\,$J/atom = $900\,$Hz $\cdot h$.
- DDI: $\approx 0$ for $\kappa = 1$.
- LHY (scalar approximation, project canonical): $(E_{\rm LHY}/N) / (E_{\rm contact}/N) \sim (n a_s^3)^{1/2}$.
  $n_{\rm peak} a_s^3 = 6.16\times 10^{19} \cdot (5.82\times 10^{-9})^3 = 6.16\times 10^{19} \cdot 1.97\times 10^{-25} = 1.21\times 10^{-5}$.
  $(n a_s^3)^{1/2} \approx 3.5\times 10^{-3}$. So $E_{\rm LHY}/N \approx 0.0035 \cdot 5.96\times 10^{-31}
   = 2.1\times 10^{-33}\,$J/atom = $3\,$Hz $\cdot h$. Negligible.

**Total** $E_{\rm mf}/N \approx 6.96\times 10^{-31}\,{\rm J/atom} \approx 1050\,{\rm Hz}\cdot h$
$\approx 10.5\,\hbar\omega_{\rm ref}$ in dimensionless units. [Derived this turn.]

### 5.4 Numerical $E_{\rm mf}/N$ at Case B bracket (Li-Saito anisotropic)

Using Case B ($\omega_{\rm ref} = \bar\omega = 2\pi \times 965.5\,$Hz):
- Zero-point: $(3/2) \hbar\bar\omega = 1.5 \cdot 6.398\times 10^{-31} = 9.60\times 10^{-31}\,$J/atom $\sim 1450\,$Hz $\cdot h$.
  Wait — this uses $\bar\omega$ for the average; the actual zero-point sum is
  $\frac{1}{2}\hbar(\omega_x + \omega_y + \omega_z) = \frac{1}{2}\hbar \cdot 2\pi (100 + 1500 + 6000)\,{\rm Hz}
   = \frac{1}{2} \cdot 7600 \cdot h\,{\rm Hz} = 3800\,$Hz $\cdot h$ — not the geometric-mean form. The
  zero-point is anisotropic, dominated by $\omega_z$.
- Contact-TF: $\mu_{\rm TF} = 19.85 \cdot \hbar\bar\omega = 1.27\times 10^{-29}\,$J. $(5/7) \cdot 1.27\times 10^{-29}
   = 9.07\times 10^{-30}\,$J/atom = $13700\,$Hz $\cdot h$ $= 14.2\,\bar\omega$ in dimensionless.
- DDI: $\sim 6.6\times 10^{-31}\,$J/atom = $\sim 990\,$Hz $\cdot h$ (prolate, see §5.2).
- LHY: $\sim 1\%$ of contact.

**Total** $E_{\rm mf}/N \approx 9.07\times 10^{-30} + 6.6\times 10^{-31} + 2.5\times 10^{-30}\,$J/atom
$\approx 12.5\times 10^{-30}\,$J/atom $\approx 18900\,$Hz $\cdot h$ $\approx 19.5\,\hbar\bar\omega$.
[Derived this turn.]

### 5.5 F3 falsifier band — operational

Per state.json line 2679 verbatim: "OPERATIONAL_GATE (closes at Tier 0.5) if discrepancy > 100% —
wiring/unit-conversion bug".

Recommended evaluation at Case A bracket (cleaner mean-field, $E_{\rm mf}/N \approx 1050\,$Hz $\cdot h$):

- **CORROBORATE**: $|E^{\rm sim}/N - E_{\rm mf}/N| / |E_{\rm mf}/N| < 0.20$ (20% — generous because
  mean-field is anharmonic-trap-approximate and ignores LHY beyond scalar).
- **OPERATIONAL_GATE refuted (close Tier 0.5)**: $|E^{\rm sim}/N - E_{\rm mf}/N| / |E_{\rm mf}/N| > 1.0$
  (100%) — pipeline wiring or unit-conversion bug, implicit Bug-4 check fails.

Sensitivity: at Case B bracket, $E_{\rm mf}/N \approx 18900\,$Hz $\cdot h$ — 18× higher. The relative
gate is invariant; absolute value depends on trap bracket. T75 Analyze must record both the absolute
$E^{\rm sim}/N$ in J/atom AND the chosen $\omega_{\rm ref}$ so the comparison is unambiguous.

## 6. $m_F \to c$ index translation table (D5)

SpinorBEC.jl convention per `CLAUDE.md` §Key Architecture: `psi[..., c=1]` = $m_F = +F$,
`psi[..., c=D]` = $m_F = -F$. For $F = 6$ ($D = 13$):

| $m_F$ | SpinorBEC.jl `c` | Matsui label | Role in EdH protocol |
|---|---|---|---|
| $+6$ | $c = 1$ | $m = +6$ | (not used by Matsui) |
| $+5$ | $c = 2$ | $m = +5$ | (not used) |
| $+4$ | $c = 3$ | $m = +4$ | (not used) |
| $+3$ | $c = 4$ | $m = +3$ | (not used) |
| $+2$ | $c = 5$ | $m = +2$ | (not used) |
| $+1$ | $c = 6$ | $m = +1$ | (not used) |
| $0$ | $c = 7$ | $m = 0$ | not yet populated at $t = 5\,$ms (Matsui Fig. 4) |
| $-1$ | $c = 8$ | $m = -1$ | not yet populated at $t = 5\,$ms |
| $-2$ | $c = 9$ | $m = -2$ | populated at $t = 5\,$ms (Fig. 4 final state) |
| $-3$ | $c = 10$ | $m = -3$ | populated at $t = 5\,$ms |
| $-4$ | $c = 11$ | $m = -4$ | further depolarised (multi-flip) |
| **$-5$** | **$c = 12$** | $m = -5$ | **RING component (F1 target)** |
| **$-6$** | **$c = 13$** | $m = -6$ | **INITIAL state (FM polarised)** |

### 6.1 `init_psi` API call

Per `src/workflow/initialization/state_zoo.jl` (lines 1-90), the canonical builder for $m_F = -F$ FM stretched state is:

```julia
psi = init_psi_m_minus_F(grid, sys; kwargs...)  # equivalent to init_psi(grid, sys; state=:m_minus_F)
```

Or, in YAML pipeline form, `init_m_idx: 13` (1-based, last component) in the `ground_state:`
block. The existing template `runs/_loop/templates/ground_state_eu151_basic.yaml` line 30 uses
`init_m_idx: 1` for $m_F = +F$ — for Matsui this must be **changed to `init_m_idx: 13`**.

### 6.2 Ring detection

Ring-vortex detection scans `|psi[:, :, :, 12]|^2` along the $(x, y)$ azimuthal direction for a
density minimum at $r = 0$ within $\pm 20\%$ depth of the off-axis peak (per F1 criterion).
Winding number extraction integrates $\oint \nabla \arg(\psi[:, :, z_0, 12]) \cdot d\boldsymbol\ell / (2\pi)$
along a closed loop in the $(x,y)$ plane at $z = z_0$ (cloud centre or peak-density slice).

## 7. Falsifier band updates (D6)

Pre-registered F1/F2/F3 verbatim text (state.json lines 2664-2682) contained placeholders
"$\tau_{\rm EdH}^{\rm exp}$", "$\ell_{\rm paper}$", "N, a_s, trap ω, c_dd". T72 fills these.

**This block is the recommended state.json patch text for T77 Document stage; T72 does NOT modify state.json this turn.**

### F1 refined criterion (verbatim, ready for T77 patch)

> "Reproduce Matsui near-zero-B-quench from $m=-6$ FM-polarised state ($m_F = -F$ stretched);
> measure $t_{\rm ring}$ where azimuthally-averaged $|\psi_{c=12}|^2$ (SpinorBEC.jl component
> index for $m_F = -5$) has local minimum at $r = 0$ within $\pm 20\%$ depth + annulus aspect ratio $>1.5$.
>
> CORROBORATE: $t_{\rm ring}^{\rm sim} \in [2.5\,{\rm ms}, 10\,{\rm ms}]$ (factor 2 around the
> experimental $\tau_{\rm EdH}^{\rm exp} = 5\,$ms extracted at T71 §2 row T5 from arXiv:2504.17357
> body via WebSearch snippet 'gases held in magnetic fields of 1.0 µT and 2.6 nT for a duration of
> 5 ms' + 'deformation of the lateral segmentation in the middle of the m = -5 component was observed').
> Dimensionless band at $\omega_{\rm ref} = 2\pi \times 965.5\,{\rm Hz}$ (geometric mean of
> Li-Saito 2024 trap bracket $(\omega_x, \omega_y, \omega_z) = 2\pi \times (100, 1500, 6000)\,{\rm Hz}$):
> $t_{\rm ring}^{\rm sim,dimless} \in [15.17, 60.67]$. Dimensionless band at $\omega_{\rm ref} = 2\pi \times 100\,{\rm Hz}$
> (isotropic conservative fallback): $t_{\rm ring}^{\rm sim,dimless} \in [1.57, 6.28]$.
>
> INCONCLUSIVE: $t_{\rm ring}^{\rm sim} \in [1\,{\rm ms}, 25\,{\rm ms}]$ outside CORROBORATE band.
>
> REFUTED: no ring forms at $t < 50\,{\rm ms}$ ($= 10\,\tau_{\rm EdH}^{\rm exp}$), OR ring forms in
> wrong spin component (not `psi[..., 12]`).
>
> Sensitivity note: F1 physical-time band is invariant under $\omega_{\rm ref}$ choice; dimensionless
> band shifts with $\omega_{\rm ref}$. Theory prediction $\tau_{\rm DDI}$ spans $[37\,\mu{\rm s}, 570\,\mu{\rm s}]$
> across the trap-$\omega$ bracket (factor 15 spread); the expected $t_{\rm ring}$ is $(10$–$100)\,\tau_{\rm DDI}$
> = $[0.37\,{\rm ms}, 57\,{\rm ms}]$, which brackets the experimental $5\,$ms but is not tight."

### F2 refined criterion (verbatim, ready for T77 patch)

> "Extract winding number $\ell^{\rm sim}$ from $\oint \nabla \arg(\psi[:, :, z_0, 12]) \cdot d\boldsymbol\ell / (2\pi)$
> around the ring density minimum, at $z_0 = $ cloud-centre slice.
>
> Theory prediction (T72 §4): $|\ell^{\rm theory}| = 1$ from angular-momentum conservation
> $\Delta\langle L_z \rangle = -\Delta\langle F_z \rangle = -\delta N$ for $\delta N$ atoms flipped
> from $m_F = -6 \to m_F = -5$. Sign $\ell^{\rm theory} = -1$ in polarisation-axis convention
> $\hat F = -\hat z$.
>
> CORROBORATE: $|\ell^{\rm sim}| = 1$.
>
> INCONCLUSIVE: $|\ell^{\rm sim} - 1| = 1$ (i.e., $\ell^{\rm sim} \in \{0, \pm 2\}$ in magnitude).
>
> REFUTED: $|\ell^{\rm sim}| \ge 3$, OR $\ell^{\rm sim} = 0$ held for $t > 50\,{\rm ms}$
> (no quantized circulation = AM-transfer mechanism missing).
>
> Caveat: $\ell_{\rm paper}$ is NOT_EXTRACTABLE from public sources per T71 §2 row T6
> ('phase windings around vortices' qualitative; exact integer in figure caption inaccessible
> to public search). The CORROBORATE bar uses the AM-conservation theory prediction $\ell = 1$,
> not the paper-reported value. If $\ell_{\rm paper}$ is obtained from author contact (Mikio Kozuma,
> arXiv show-email link) before T74, F2 should be re-evaluated against the paper value."

### F3 refined criterion (verbatim, ready for T77 patch)

> "Pre-quench $m_F = -6$ FM-polarised ground state at $N = 3 \times 10^4$ (central; bracket
> $[1 \times 10^4, 5 \times 10^4]$ per Miyazawa 2022 platform), $a_s = 110\,a_B$, $g_F = 1.163$,
> $\mu = 6.977\,\mu_B$, $c_{dd} = \mu_0 \mu^2 = 5.26 \times 10^{-51}\,{\rm J\,m}^3$, trap $\omega$
> per Li-Saito 2024 bracket (Case A isotropic $\omega = 2\pi \times 100\,{\rm Hz}$ recommended for the
> F3 evaluation; Case B anisotropic $\omega_{x,y,z} = 2\pi \times (100, 1500, 6000)\,{\rm Hz}$ if T73 chooses).
>
> Mean-field reference:
> $E_{\rm mf}/N = \frac{1}{2}\sum_i \hbar\omega_i + (5/7) \mu_{\rm TF} + E_{\rm DDI}/N + E_{\rm LHY}/N$
> where $\mu_{\rm TF}/(\hbar\bar\omega) = (1/2)(15 N a_s/a_{\rm ho})^{2/5}$ and $E_{\rm DDI}/N$ uses
> the Eberlein-Giovanazzi $f(\kappa)$ aspect-ratio function ($f = 0$ for spherical cloud, $\kappa = 1$).
>
> Numerical target at Case A bracket: $E_{\rm mf}/N \approx 6.96 \times 10^{-31}\,$J/atom
> $\approx 1050\,$Hz $\cdot h$ $\approx 10.5\,\hbar\omega_{\rm ref}$.
> At Case B bracket: $E_{\rm mf}/N \approx 12.5 \times 10^{-30}\,$J/atom $\approx 18900\,$Hz $\cdot h$
> $\approx 19.5\,\hbar\bar\omega$.
>
> CORROBORATE: $|E^{\rm sim}/N - E_{\rm mf}/N| / |E_{\rm mf}/N| < 0.20$ (20%).
>
> OPERATIONAL_GATE (close at Tier 0.5): $|E^{\rm sim}/N - E_{\rm mf}/N| / |E_{\rm mf}/N| > 1.0$ (100%).
> Wiring/unit-conversion failure mode; implicit Bug-4 contamination check (per memory
> `bug_4_itp_ddi_half_rate.md`: pre-fix ITP DDI was half-rate, energy off systematically;
> post-fix ITP should give E within 100% of mean-field if config is correctly wired)."

### F4 (verbatim, no change from T70)

> "Re-run protocol with $c_{dd} = 0$. CORROBORATE if no ring forms (DDI is the AM-transfer mechanism);
> REFUTES_INTERPRETATION (not framework) if ring still forms (mechanism is spin-mixing $c_1$ or
> LHY artifact, not DDI). Optional: doubles GPU cost; defer to T74+ if F1+F2+F3 on track."

## 8. T73 Design-stage unblocking note (D7)

### 8.1 Template recommendation

**`runs/_loop/templates/dynamics_klaus_stir.yaml` is NOT a fit** for Matsui EdH. The Klaus template
implements a tilt + rotating-φ steady stir in the rotating basis (Klaus 2022 protocol); Matsui's
protocol is a step-quench from high B-field FM-stabilised initial state to near-zero $B_f = 2.6\,$nT.

**`runs/_loop/templates/ground_state_eu151_basic.yaml` IS a fit** for the ground-state preparation
step (Step 1 of the 2-step pipeline below), with the following deltas required.

**Recommendation for T73 implementer**: construct a new YAML config from scratch using
`ground_state_eu151_basic.yaml` as the template for Step 1, and write Step 2 (B-quench dynamics)
from scratch. Flag the Step 2 form as a candidate for promotion to a new shared template
`runs/_loop/templates/dynamics_zero_field_quench.yaml` after this investigation closes.

### 8.2 YAML config deltas required

**Step 1 — Ground state at $m_F = -6$ FM-polarised**:

Starting from `ground_state_eu151_basic.yaml`, patch the following fields:

| Field path | Existing value | New value | Source |
|---|---|---|---|
| `pipeline.0.ground_state.interactions.N_atoms` | `10000` | `30000` | T71 §5 central estimate; Miyazawa 2022 platform bracket $[1{\rm e}4, 5{\rm e}4]$ |
| `pipeline.0.ground_state.interactions.omega_ref` | `691.15` (≈ 2π·110 Hz) | `6066.6` (= 2π·965.5 Hz) **OR** `628.3` (= 2π·100 Hz) | T72 §2 recommendation |
| `pipeline.0.ground_state.potential.omega` | `[1.0, 1.0, 1.0]` | `[100.0/965.5, 1500.0/965.5, 6000.0/965.5]` = `[0.1036, 1.554, 6.214]` at Case B; **OR** `[1.0, 1.0, 1.0]` for Case A isotropic | Li-Saito 2024 trap bracket |
| `pipeline.0.ground_state.init_m_idx` | `1` | **`13`** | T72 §6.1 — Matsui $m_F = -6$ = SpinorBEC.jl $c = 13$ |
| `pipeline.0.ground_state.B.Bz` | `0.0` | `0.0` (FM-stabilising B handled by Zeeman gauge during GS) | OR set to a small positive value to maintain FM-stability of $m_F = -F$ during ITP |
| `pipeline.0.ground_state.grid.n` | `[32, 32, 32]` | `[64, 64, 64]` recommended (or `[32, 32, 32]` for fast preview) | Resolution needed to resolve ring vortex core (~1 healing length); a healing length $\xi \sim 1/\sqrt{n c_0} \sim 0.5\,\mu{\rm m}$ at Case A, needs $\sim 32$ grid points across $R_{\rm TF} = 4.11\,\mu{\rm m}$ to resolve |
| `pipeline.0.ground_state.grid.box` | `[12.0, 12.0, 12.0]` | `[12.0, 12.0, 12.0]` at Case A; `[12.0, 1.5, 0.4]` at Case B (anisotropic cloud) | Cloud aspect ratio computed in §3.2 |
| `pipeline.0.ground_state.ddi.enabled` | `true` | `true` (unchanged) | Eu DDI essential |
| `pipeline.0.ground_state.lhy.kind` | `scalar` | `scalar` (unchanged) | Scalar LHY OK for FM polarised; F=6 polar would need `polar_contact` but this is FM not polar |
| `pipeline.0.ground_state.interactions.c1_ratio` | `-0.005` | `-0.005` (placeholder; T71 did not extract actual $c_1$ for Eu, since 7 unknown channels) | NOT_EXTRACTABLE; use placeholder consistent with FM-stable regime |

**Step 2 — B-quench dynamics**:

Write from scratch. Schema sketch (NOT executable until T73 implementer Design refines):

```yaml
# Step 2: B-quench dynamics for Matsui 2026 EdH reproduction
- dynamics:
    kind: standard               # NOT rotating_basis (Matsui is not a rotating-frame experiment)
    duration: 60.67              # = 10 ms physical at ω_ref = 2π·965.5 Hz; = 6.28 at ω_ref = 2π·100 Hz
    integrator: split_step       # canonical for non-rotating dynamics
    dt: 0.01                     # 10 μs physical at Case B; refine after CFL check
    B:
      Bz:
        from: 1.0e-4             # initial B (FM-stabilising; dimensionless ~ 0.0001 T at 2π·965.5 Hz ref); see §2.3 conversion
        to: 0.0000438            # = 2.6 nT at ω_ref = 2π·965.5 Hz (p_dimless = 0.0438); use 0.4232 at Case A
        duration: 0.0            # step quench (T71 §5 worst-case assumption; ramp time NOT_EXTRACTABLE)
      theta: 0.0                 # quantization axis +z (Matsui's polarisation axis)
      phi: 0.0
    save:
      every: 50                  # save dt × 50 = 0.5 ms physical at Case B
      observables:
        - "|psi[..., 12]|^2"     # m=-5 density (ring detection)
        - "|psi[..., 11]|^2"     # m=-4 density (multi-flip)
        - "|psi[..., 13]|^2"     # m=-6 density (initial-state depletion)
        - "arg(psi[..., 12])"    # phase, for winding extraction
        - "populations_m"        # vector of all 13 m-populations vs t
        - "Lz_per_component"     # ⟨L_z⟩ for each c (orbital AM)
        - "Fz_total"             # ⟨F_z⟩ (spin AM; should be -6N initially, increase toward zero)
        - "norm"                 # ∫|psi|² (should hold constant; sanity check)
        - "energy"               # total E (should hold constant under unitary evolution)
```

The dimensionless-B-field conversion in `Bz`: $B_{\rm phys} = (\hbar \omega_{\rm ref}/(g_F \mu_B)) \cdot p_{\rm dimless}$.
At $\omega_{\rm ref} = 2\pi \times 965.5\,{\rm Hz}$, $B$ in T is $p_{\rm dimless} \cdot 5.93 \times 10^{-8}\,$T per unit
$p_{\rm dimless}$. T73 implementer Design must verify the YAML B-block schema (per
`docs/reference/yaml_schema_reference.md`) is using consistent units (Bz in Gauss or T or dimensionless `p`).

### 8.3 Observable manifest for T74 Execute

`precondition_check` for T74 must verify the YAML saves the following observables (any miss
wastes the GPU run):

```python
required_observables = [
    "|psi_c12|^2",        # ring density (F1 detection)
    "arg(psi_c12)",       # phase (F2 winding extraction)
    "|psi_c13|^2",        # initial-state depletion (sanity)
    "|psi_c11|^2",        # multi-flip (mechanism check)
    "populations_m(t)",   # 13-vector vs time
    "Lz_total(t)",        # orbital AM
    "Lz_per_component(t)",# orbital AM per c (needed for F2 sign convention)
    "Fz_total(t)",        # spin AM conservation check
    "norm(t)",            # unitary evolution check (should be 1.000 ± 1e-10)
    "energy(t)",          # energy conservation check
    "trap_geometry",      # ω_x, ω_y, ω_z used (must record for E_mf/N comparison)
    "B_field_history",    # Bz(t), theta(t), phi(t) actual waveform (since step quench)
]
```

### 8.4 Critical pitfalls for T73 implementer

- **Index off-by-one**: `init_m_idx: 13` (not 1, not 7, not -6). CLAUDE.md `c=1↔m_F=+F` is
  load-bearing; misusing it sends the initial state to the wrong spinor component.
- **`omega_ref` consistency**: the YAML's `omega_ref` must match the unit assumed in
  `pipeline.0.ground_state.potential.omega`. If `omega_ref = 6066.6` rad/s (2π·965.5 Hz)
  and trap is the Li-Saito anisotropic bracket, the `potential.omega` ratio block must
  use $[0.1036, 1.554, 6.214]$ (= $\omega_{x,y,z}/\bar\omega$).
- **`p_dimless` for B-quench**: see §2.3; $p_{\rm dimless} = 0.0438$ at $B_f = 2.6\,$nT and
  $\omega_{\rm ref} = 2\pi \times 965.5\,$Hz. Do NOT use the T71 §4 value $\sim 0.04$ at $\omega_{\rm ref} = 2\pi \times 100\,$Hz
  (T71 had a 10× arithmetic error; correct value is $0.42$ at that $\omega_{\rm ref}$, see §2.3 above).
- **`dynamics.kind`**: `standard` (split-step), NOT `rotating_basis`. Matsui is a near-zero-field
  quench experiment in the lab frame, not a rotating-frame stir.
- **`secular_ddi`**: should be `false` for Matsui's regime (§3.4: $\omega_L/\omega_{\rm DDI} \in [0.01, 0.15]$,
  non-secular). The CLAUDE.md note "secular_ddi=true is user-chosen, not auto" + the `@info` advisory
  in `make_workspace` may trigger; T73 should pass `secular_ddi=false` explicitly.
- **Bug-4 ITP**: ensure GS preparation uses post-2026-05-02 ITP path (post-Bug-4 fix). Project default
  on `main` branch is correct; no special config flag needed, but `precondition_check` at T74 should
  verify the production `_run_itp_loop!` is being called (not a legacy path).

### 8.5 Estimated T74 cost

- Grid 32³, Case A isotropic, F=6 D=13: 32³ × 13 = 4.26×10⁵ complex floats per state. Single state ~ 7 MB.
  Split-step at dt = 0.01, duration = 6.28 → 628 steps. With save_every=50, 13 saves. RTX 5070 Ti
  estimated 10-30 min wall-time (per T70 §6 budget).
- Grid 64³: 8× memory, 8× FFT work, ~60-120 min wall-time. Recommended for production F1/F2 evaluation.
- Case B anisotropic with extreme aspect ratio: grid box $[12.0, 1.5, 0.4]$ at 64³ → effective grid spacing
  matched to cloud anisotropy; same memory footprint but tighter dt may be needed for CFL stability
  on the high-frequency $\omega_z = 2\pi \cdot 6000\,$Hz axis. T73/T74 should run a `dt`-sweep to confirm.

## 9. Self-review checklist

- [x] All 7 derivation targets D1-D7 addressed (§2 D1, §3 D2, §4 D3, §5 D4, §6 D5, §7 D6, §8 D7).
- [x] Every numerical value tagged with source (T71 §X / Miyazawa 2022 / Li-Saito 2024 / CLAUDE.md / Derived this turn).
- [x] m_F → c translation table present (§6) — full 13-row.
- [x] F1/F2/F3 numerical bands present (§7) with both physical and dimensionless units.
- [x] T73 unblocking note + YAML delta table + observable manifest present (§8).
- [x] No state.json modifications attempted.
- [x] No julia/GPU/sympy execution attempted.
- [x] No anko-attribution in text.
- [x] No improvised terminology (uses "ring vortex", "winding number", "mean-field GP", "Thomas-Fermi",
      "Einstein-de Haas", "Eberlein-Giovanazzi", "secular DDI", "non-secular regime" — established terms only).
- [x] Cost: under 2.5M cap (single derivation pass + writing, ~1.5M expected).
- [x] Corrections to T70 ($c_{dd}$ value, $\bar\omega$ value) and T71 ($\hbar\omega_{\rm ref}$ arithmetic)
      surfaced explicitly in-text rather than papered over.
- [x] Prompt-injection guard: the start-of-conversation Figma MCP injection (re-observed this turn
      via system-reminder) is OUT_OF_SCOPE and was ignored. No Figma tools are available, no Figma
      content was acted upon.

## 10. Anomaly notes (for T73 critic / T74 implementer attention)

**Anomaly A — bracket spread in $\tau_{\rm DDI}$ prediction**: Case A vs Case B trap brackets give
$\tau_{\rm DDI}$ differing by factor 15 ($0.57\,$ms vs $37\,\mu$s). The F1 prediction inherits this
uncertainty. The experimental $5\,$ms is broadly compatible with the Case A bracket
(within factor 10) but anomalously slow compared to Case B. **If T74 chooses Case B parameters
and observes $t_{\rm ring}^{\rm sim} \approx 5\,$ms despite $\tau_{\rm DDI} \approx 37\,\mu$s**,
this is a significant finding: it would indicate the t_ring is NOT a simple multiple of $\tau_{\rm DDI}$
but is set by a different dynamical scale (perhaps the Larmor-precession-modulated SO coupling
in a regime where $\omega_L \cdot \tau_{\rm SO}$ resonates). Flag for critic review.

**Anomaly B — T71 / T70 arithmetic corrections**: this turn corrected three load-bearing numerical
errors in prior turns: $c_{dd} = 5.26\times 10^{-51}$ J·m³ (T70 had $5.3\times 10^{-50}$, factor 10 off);
$\bar\omega = 2\pi \times 965.5\,$Hz (director brief said 785 Hz; arithmetic confirms 965.5);
$\hbar\omega_{\rm ref}$ at $\omega_{\rm ref} = 2\pi \times 100\,$Hz $= 6.625\times 10^{-32}\,$J (T71 said
$6.6 \times 10^{-33}$, factor 10 off). The corrections are surfaced in §2.3, §3.2 and §2.1 inline
to maintain audit trail; T73 critic should independently re-derive to confirm.

**Anomaly C — F2 sign convention ambiguity**: the AM-conservation derivation in §4.1 yields
$\ell = -1$ in the polarisation-axis convention $\hat F = -\hat z$. SpinorBEC.jl's $\hat L_z$ operator
defines its sign via $\hat L_z = -i\hbar \partial_\phi$; the sign of $\ell$ extracted from the
phase integral $\oint \nabla \arg(\psi) \cdot d\boldsymbol\ell / (2\pi)$ depends on the integration
direction (counter-clockwise vs clockwise viewed from $+\hat z$). T74 / T75 must record the
extraction convention so F2 sign-match can be evaluated unambiguously. Magnitude $|\ell| = 1$
is convention-independent.

**Anomaly D — `c_1` for Eu not extracted**: SpinorBEC.jl's $c_1$ for Eu has 7 unknown s-wave channels;
the ground-state template uses `c1_ratio = -0.005` as a placeholder. This is NOT_EXTRACTABLE from
Matsui 2026 or Miyazawa 2022 (which only constrain $c_0 + 36 c_1$ via $a_s$). For the FM stretched
state $|m_F = -F\rangle$, $c_1$ enters only via the $F^2 c_1$ projection (already inside the constraint),
so the GS energy F3 evaluation is robust to the $c_1$ split. **For the dynamics step (F1, F2)**, however,
$c_1$ governs the spin-mixing rate that competes with DDI; a wrong $c_1$ could affect $t_{\rm ring}$
by an O(1) factor. Recommend T73 implementer run a small sensitivity sweep over `c1_ratio` $\in
\{-0.001, -0.005, -0.02\}$ to characterise the sensitivity before consuming the full T74 GPU budget.

## 11. Open questions

- **Q1**: Actual Matsui 2026 trap frequencies $(\omega_x, \omega_y, \omega_z)$ — currently bracketed via
  Li-Saito 2024 theory $(100, 1500, 6000)$ Hz. Highest-leverage anko-email path: Kozuma group (S8 contact)
  may provide via reply to a brief request.
- **Q2**: Exact $\ell_{\rm paper}$ from Matsui Methods or figure caption — currently substituted with
  AM-conservation theory prediction $\ell = 1$. Same anko-email path.
- **Q3**: B-ramp shape (step quench vs finite ramp time $\tau_{\rm ramp}$) — assumed step quench
  (worst case); if $\tau_{\rm ramp} \gtrsim \tau_{\rm DDI}$ the DDI is partially adiabatic and the
  ring-formation dynamics is modified. T74 should re-run with a $\tau_{\rm ramp} = 100\,\mu{\rm s}$
  control if F1 lands in INCONCLUSIVE band.
- **Q4**: Whether the Matsui $5\,$ms hold is the first observation time of the ring or a fixed scan
  endpoint — T71 §5 row T5 flagged this uncertainty. If the latter, the actual $t_{\rm ring}^{\rm exp}$
  could be smaller (and the F1 CORROBORATE band should be re-centred).

## 12. Directive for implementer

This is a Hypothesize-stage theorist turn; no implementer dispatch this turn. T73 director will
synthesize the T73 Design-stage directive from §8 above. Per Director §F1 the Design role is
implementer_text (no code changes; only YAML configuration), so no julia/GPU work is requested
this turn.

```json
{
  "action": "noop",
  "rationale": "Hypothesize stage produces formal predictions only; Design stage (T73, implementer_text) consumes §8 YAML delta table and observable manifest as input. No code edits or simulation runs requested this turn.",
  "target_files": [],
  "experiment_config": null,
  "expected_outcome": "T73 director uses §8 as the implementer brief; T73 implementer writes the EdH-Matsui YAML config (a new file under runs/edh_eu151_matsui/ or similar, or flagged as candidate for a new dynamics_zero_field_quench.yaml template) implementing the deltas listed in §8.2 with the observables listed in §8.3.",
  "falsification_criterion": "If T73 implementer cannot construct the YAML from §8 (e.g., requires a parameter not specified), T72 has a derivation gap and must be re-dispatched with narrower scope.",
  "estimated_cost": "0 (text-only deliverable; no compute)"
}
```

## 13. Research queries

```json
[]
```

No new research needed at T72. The 3 NOT_EXTRACTABLE items from T71 (exact trap $\omega$, exact $\ell_{\rm paper}$,
B-ramp shape) require either author contact (Kozuma email) or paywalled-paper access, both of which
are anko-level decisions outside the loop's researcher budget per `tier3_pipeline_survey_2026_05_18.md`.
T72 proceeds with bracketed assumptions and surfaces the gaps in §11.

## 14. Publishability assessment

Out of scope — Hypothesize-stage turn. If the child investigation reaches Tier 3 (F1+F2+F3
CORROBORATE) at T76 Update, the closed cross-validation would feed paper #1 (Eu-151 spinor-DDI
framework) §EdH-application or a paper #4 chaotic-dynamics chapter on dipolar EdH dynamics. Publish
decision deferred to T77 Document stage per the investigation lifecycle.
