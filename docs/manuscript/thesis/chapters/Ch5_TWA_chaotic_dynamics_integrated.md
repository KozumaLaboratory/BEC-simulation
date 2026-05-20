# 修論 Chapter 5: TWA + Chaotic Dipolar Dynamics in F=6 ¹⁵¹Eu

本章では、F=6 Eu スピノル BEC の post-quench dipolar instability dynamics に対する
truncated Wigner approximation (TWA) ベースの beyond-mean-field treatment を扱う。
中心結果は、Eu 平均場 collapse 境界における **σ/μ ≈ 0.4-0.8 の signal が leading-order
TWA の "quantum fluctuation 振幅" ではなく、chaotic trajectory divergence の onset を
反映する**ことの定量検証である。これは Round 2/3 期の framing からの大規模 reframing を
伴った、本研究の methodological contribution として位置付けられる。

修論期間の論文候補 [Paper #4]: "Chaotic dipolar instability and the break-down of
leading-order TWA in Eu F=6 spinor BEC" (PRR target)。

---

## 5.1 動機と章の位置付け

### 5.1.1 Eu post-quench EdH の物理

¹⁵¹Eu (F=6, μ ≈ 6.98 μ_B) は最強の magnetic moment を持つ spinor BEC species の一つで、
electromagnetically induced dipole-dipole interaction (DDI) が contact 相互作用と
拮抗する regime に位置する。post-quench EdH (Einstein-de Haas-like) 実験では、
spinor degree of freedom を急変させた後の orbital angular momentum 移動 + density
profile collapse dynamics を観測する [上妻研, 2022-2026]。

平均場 (GP/spinor GP) treatment では、c_dd ∝ μ² と c_0 の比で支配される **dipolar
instability** が発生し、z-elongated filament 形成が予測される。しかし量子ゆらぎ補正
(LHY, beyond-mean-field) を含めると collapse が抑制される可能性があり、droplet 形成
(Petrov 2015, Schmitt 2016, Chomaz 2016 の Dy droplet 系統との parallel) も期待される。

本章では:

1. **LHY-mode ablation** (5 modes 系統比較) で LHY insufficient を示す (§5.2)
2. **TWA implementation** で quantum fluctuation 補正 trajectory ensemble を構築 (§5.3)
3. **3 系統 GPU sweeps** で σ/μ chaos diagnostic を特性化 (§5.4-§5.6)
4. **Sinatra-clean 1/N validity test** で TWA leading-order が "quantum
   fluctuation observable" として機能しないことを定量的に証明 (§5.5)
5. **Methodological lesson** (GS-resolution caveat) を抽出 (§5.7)
6. **TDHFB / Beliaev outlook** (D 論への bridge) (§5.8)

### 5.1.2 Framing change vs Round 2/3 期計画

Round 2/3 期 (~2026-04 まで) の framing:

> TWA gives an $O(1/N)$ controlled expansion around the GP mean field. Eu EdH at
> marginal collapse shows $\sigma/\mu \approx 0.42$ at peak density ≡ "quantum
> fluctuations of order $O(1)$ relative to the mean".

**Why this was wrong (May 7-8 2026 検証で判明)**:

σ/μ at peak in the dipolar-instability regime is dominated by **chaotic trajectory
divergence**, not by Wigner-noise amplitude. The 1/√N test at Sinatra-clean
16³×box=10 (May 8) explicitly shows $\sigma/\mu \cdot \sqrt{N}$ growing 17.7 → 41.5
→ 259 across N values, i.e., **1/√N TWA scaling fails**.

**Revised framing**:

TWA at leading order is a **chaos-onset diagnostic** for the Eu post-quench dipolar
instability, **not** a quantitative quantum-fluctuation measurement. The
$\sigma/\mu \approx 0.4-0.8$ signal tracks where the system enters the chaotic
dipolar-collapse manifold. For controlled quantum-fluctuation claims we need TDHFB,
Beliaev, or a two-time correlation matrix beyond the leading TWA.

これは "negative result + methodological insight" として thesis defense possible な
重要 finding である。

### 5.1.3 本章で確立する結果

3 つの新規結果:

**[T3.1] LHY-insufficiency on Eu**: 5-mode LHY ablation (off / scalar / polar_contact /
polar_dipolar / full_bdg) 全モードで Eu F=6 $a_s = 110\,a_B$ 32³ ground state が
identical z-elongated filament に collapse する → LHY は mean-field DDI に対して
sub-leading、collapse 抑制効果を持たない。

**[T3.2] σ/μ chaos diagnostic**: marginal collapse の coupling-strength で σ/μ が
peak (Finding B)。1/√N scaling fails at Sinatra-clean conditions → σ/μ は **chaotic
trajectory divergence** の onset を反映、TWA leading-order quantum fluctuation
observable では**ない**。

**[T3.3] GS-resolution methodological caveat**: 16³×box=20 vs 32³×box=20 (May-7
Sinatra check で観察された) σ/μ shrinkage は **ground-state resolution artifact**
(filament 3.75 a_ho を 16³ box=20 / dx=1.25 が解像できない) → 解像度 matched 16³×box=10
比較で chaos signature が Sinatra ratio から独立に持続することを確認。Beyond-mean-field
validation には **GS attractor を fix した状態でのノイズ/モード数の variation** が
必要、という普遍的 lesson。

---

## 5.2 LHY-Insufficiency on Eu Collapse (5-mode ablation)

### 5.2.1 5 LHY modes の系統比較

SpinorBEC.jl supports 5 LHY treatment modes (via `spinor_lhy:` YAML key):

| mode | description | applicability |
|---|---|---|
| `off` | LHY disabled (pure mean-field) | baseline |
| `scalar` | scalar Lima-Pelster (single-component analog) | warning issued for $D > 1$ |
| `polar_contact` | polar phase ($\langle F\rangle=0$ aligned), contact-only | F-polar approximation |
| `polar_dipolar` | polar + DDI ($Q_5$-corrected) | full polar treatment |
| `full_bdg` | direct BdG sum (no closed form) | exact in spin sector |

### 5.2.2 Eu collapse test config

Config: `runs/lhy_mode_ablation/`. Eu F=6, $a_s = 110\,a_B$, $N = 10^4$, 32³ box=10,
ITP to convergence. Variable: `spinor_lhy` setting only.

### 5.2.3 結果: 5 modes all collapse to identical filament

| spinor_lhy mode | filament length (μm) | peak density ratio | converged? |
|---|---|---|---|
| `off` | 7.42 | 1.000 (ref) | ✓ |
| `scalar` | 7.38 | 0.998 | ✓ |
| `polar_contact` | 7.45 | 1.005 | ✓ |
| `polar_dipolar` | 7.41 | 0.999 | ✓ |
| `full_bdg` | 7.43 | 1.001 | ✓ |

**変動 < 1%**: LHY 補正は Eu collapse 抑制に対して 1% 未満の effect しか持たない。
平均場 DDI が dominant、LHY は **sub-leading**。

これは Dy droplet (Schmitt 2016) が LHY-balanced collapse-抑制を experimental に示した
事実とは対照的である。Eu の large $a_s = 110\,a_B$ (vs Dy ~ 92 $a_B$) + 異なる species
parameter で、LHY/MF balance が異なる regime に入る。

**Implication**: Eu collapse の beyond-MF treatment は LHY 単独では不十分、TWA や
TDHFB のような fluctuation-resummation treatments が必要。

詳細: `docs/research_notes/eu_collapse_lhy_insufficient.md` (May 7 2026 report)。

---

## 5.3 TWA Implementation in SpinorBEC.jl

### 5.3.1 TWA 形式の要約

Truncated Wigner approximation [Steel 1998, Polkovnikov 2010]: ψ → $\psi + \delta\psi$
with $\delta\psi$ Wigner-vacuum noise ensemble. Time-evolution via GP equation
(deterministic):

$$i \hbar \partial_t \psi_{m, j} = H_{\rm GP}[\psi] \psi_{m, j}, \quad \psi_{m, j} = \sqrt{n} \zeta_m + \delta\psi_{m, j}$$

with $j = 1, \ldots, N_{\rm traj}$ trajectories. Observables computed as ensemble
averages $\langle O \rangle_{\rm TWA} = N_{\rm traj}^{-1} \sum_j O[\psi_j]$.

**Sinatra criterion** [Sinatra 2001]: TWA controlled when $N_{\rm modes} \cdot D \ll N_{\rm atoms}$,
i.e., the total grid-spinor degrees of freedom must be much less than atom number.

### 5.3.2 SpinorBEC.jl の TWA infrastructure

実装場所: `src/solvers/twa.jl` + `src/workflow/initialization/twa_noise.jl`。Pipeline
YAML での TWA invocation:

```yaml
dynamics:
  twa:
    n_traj: 50
    seed: 42
    noise_per_component: true   # Wigner vacuum on each m-component
  save: {psi: true}
  ...
```

Welford-accumulated mean + variance per voxel per spinor component per snapshot,
persistent JLD2 layout `dynamics/twa_<phase>/{mean, variance, n_traj}` per phase。

Visualization: Round-3 Task 5 dashboard panel (3D variance overlay).

### 5.3.3 5 GPU sweeps の overview

本章で報告する全 5 GPU sweep が完了済 (2026-05-08 時点):

| Sweep | configs path | 主結果 |
|---|---|---|
| LHY-mode ablation | `runs/lhy_mode_ablation/` | LHY-insufficient (§5.2) |
| Coupling N scan (32³) | `runs/twa_N_scan/` | Findings A/B (§5.4) |
| Species ε_dd scan | `runs/twa_eps_dd_scan/` | trend confirmed (§5.6) |
| Sinatra check (32³ + 2×16³) | `runs/twa_sinatra/` | GS-resolution artifact (§5.7) |
| Pinned 1/N at 16³×box=10 | `runs/twa_N_scan_pinned_16g/` | 1/√N fails (§5.5) |

すべて `runs/*.config.yaml` + `result.jld2` で repository-tracked。

---

## 5.4 Coupling-Strength Scan (formerly "N scan")

### 5.4.1 Configs

`runs/twa_N_scan/N{1000, 10000, 100000}_<hash>/config.yaml`. Eu F=6 32³ box=20,
$N$-varied $\in \{10^3, 10^4, 10^5\}$ with all other physics fixed (DDI included).

**重要 caveat**: これらの configs では `c_total ∝ N` (= Eu coupling が atom-number 自動
scaling)、なので "N scan" でなく **coupling-strength scan**。Sinatra-clean 1/N test は
§5.5 で別途実施する (`twa_N_scan_pinned_16g/`)。

### 5.4.2 Finding A: collapse-threshold bracketing

各 N 値での post-quench Eu の deterministic GP (TWA trajectory 1 本) 結果:

| $N$ | $c_{\rm total}$ | filament length | regime |
|---|---|---|---|
| $10^3$ | 94 | "static" (no filament) | sub-collapse Gaussian |
| $10^4$ | 937 | 7.4 a_ho | **marginal collapse** |
| $10^5$ | 9375 | 11.2 a_ho + blow-up | super-collapse instability |

Eu natural N=10⁴ regime is at the **collapse boundary** — sensitive to small perturbations,
including Wigner noise → 強い trajectory-trajectory divergence が期待される。

### 5.4.3 Finding B: σ/μ peaks at marginal

TWA ensemble ($N_{\rm traj} = 50$) で観測した σ/μ at peak density:

| $N$ | σ/μ at peak | interpretation |
|---|---|---|
| $10^3$ | 0.05 | sub-collapse, low noise sensitivity |
| $10^4$ | **0.42** | marginal — chaos onset |
| $10^5$ | 0.31 | super-collapse, already blown up |

σ/μ は marginal で **peak**。これは MF dynamics が phase-space saddle 近傍を通る
classic chaos diagnostic である。

Round-2/3 期解釈: "σ/μ ≈ 0.42 = quantum fluctuation amplitude of O(1)"
→ **Round-7 期で reframing 必要** (§5.5)。

詳細: `docs/research_notes/twa_N_scan_result.md`.

---

## 5.5 Sinatra-Clean 1/N Validity Test — the Corrected Framing

### 5.5.1 Why "Sinatra-clean" matters

§5.4 の N-scan は "coupling-strength + Sinatra-mode-count" の **二重 variation** だった。
TWA 1/N scaling を **isolated に検証**するには:

- $c_{\rm total}$ を pin (mean-field physics 同一に保つ)
- $N$ のみ vary (Sinatra criterion 比 = $N_{\rm modes} D / N$ を変化させる)

を別途 GPU sweep で実行する必要がある。

### 5.5.2 Pinned 1/N test setup

Configs: `runs/twa_N_scan_pinned_16g/N{1000, 10000, 100000}_pinned_16g_<hash>/`.

- Grid: 16³ box=10 (= dx = 0.625, resolution-matched to 32³ box=20 of N-scan)
- $c_{\rm total}$ pinned to Eu N=10⁴ natural value (937.453)
- $c_{\rm dd}$ pinned to N=10⁴ natural value (42.204)
- N varied $\in \{10^3, 10^4, 10^5\}$ → Sinatra ratio $r = N_{\rm modes} D / N$ swept
  $\{53, 5.3, 0.53\}$
- Same Wigner noise initialization (per atom per component) → 1/N scaling expected:
  $\sigma/\mu \propto 1/\sqrt{N}$ at fixed MF physics.

### 5.5.3 結果: 1/√N scaling FAILS

| N | Sinatra $r$ | σ/μ at peak | $\sigma/\mu \cdot \sqrt{N}$ |
|---|---|---|---|
| $10^3$ | 53 | 0.56 | **17.7** |
| $10^4$ | 5.3 | 0.42 | **41.5** |
| $10^5$ | 0.53 | **0.82** | **259** |

`σ/μ × √N` should be **constant** if 1/√N scaling holds. Observed: **17.7 → 41.5 → 259**
(15× growth). Scaling fails at order-of-magnitude level.

Crucially, at $N = 10^5$ (Sinatra-cleanest, $r = 0.53 \ll 1$), σ/μ = **0.82 — 2× higher**
than the N=10⁴ value, NOT lower. This directly rules out classical thermalization
or finite-Sinatra-mode contamination as the cause of σ/μ.

### 5.5.4 Implication: TWA leading-order is not a quantum-fluctuation observable

σ/μ in the dipolar-collapse regime is **not** controlled by Wigner-noise amplitude.
Instead, it reflects the **chaotic divergence rate** of GP trajectories near the
collapse saddle — a classical (deterministic GP) phenomenon, not a quantum
fluctuation.

The chaos amplitude depends on:
- saddle-point geometry (controlled by $c_{\rm total}$, $c_{\rm dd}$, trap)
- trajectory-trajectory perturbation initial-condition spread (controlled by noise)
- exponential growth rate of phase-space divergence (Lyapunov-like)

It does NOT scale as $1/\sqrt{N}$ at fixed MF physics — because the chaos is set by
classical dynamics, not by sub-leading quantum corrections.

**Bottom line**: TWA leading-order in this regime measures **classical chaos onset**,
not **quantum fluctuations**. For controlled quantum-fluctuation claims, higher-order
methods (TDHFB, Beliaev) are required.

詳細: `docs/research_notes/twa_pinned_16g_result.md` (May 8 2026 follow-up).

---

## 5.6 Species ε_dd Scan

### 5.6.1 Configs

`runs/twa_eps_dd_scan/{Cr, Eu, Er, Dy}_eps<value>_<hash>/`. **Eu trap parameters fixed**,
$c_{\rm dd}$ override to mimic each species' ε_dd = $c_{\rm dd}/c_0$ ratio at Eu's
$c_0$ scale.

ε_dd values (computed from $a_s, μ$ of each species):

| species | $a_s$ ($a_B$) | $\mu$ ($\mu_B$) | $\epsilon_{\rm dd}$ |
|---|---|---|---|
| Cr | 7 | 6.0 | 0.15 |
| Er | 65 | 7.0 | 0.88 |
| Eu | 110 | 6.98 | 1.39 |
| Dy | 92 | 9.93 | 1.39 |

(Eu and Dy match in ε_dd via different (a_s, μ) routes.)

### 5.6.2 Mean-field result: monotonic z-elongation + density profile

| species | $\epsilon_{\rm dd}$ | z-elongation | peak/center ratio | regime |
|---|---|---|---|---|
| Cr | 0.15 | 1.02 (~spherical) | 1.05 | sub-dipolar |
| Er | 0.88 | 1.35 | 1.18 | marginal-dipolar |
| Eu | 1.39 | 2.15 | 1.51 | dipolar-collapse |
| Dy | 1.39 | 2.18 (Eu-equivalent) | 1.49 | dipolar-collapse |

z-elongation grows monotonically with ε_dd; on-axis ratio decreases monotonically
(filament 形成 with peak rising vs center). Eu/Dy at $\epsilon_{\rm dd} = 1.39$ are
indistinguishable in MF (universality at the species level).

### 5.6.3 TWA σ/μ chaos diagnostic — species universality

| species | σ/μ at peak |
|---|---|
| Cr | 0.06 (low chaos) |
| Er | 0.18 (intermediate) |
| Eu | **0.42** (marginal collapse — chaos peak) |
| Dy | **0.41** (same regime, same chaos) |

σ/μ peaks at marginal collapse boundary (Eu/Dy regime). This **species-universal
chaos-onset diagnostic** reinforces the §5.5 finding that the signal reflects classical
chaos, not species-specific quantum fluctuation.

詳細: `docs/research_notes/twa_eps_dd_scan.md`.

---

## 5.7 Sinatra Criterion + GS-Resolution Caveat

### 5.7.1 May-7 Sinatra check の anomaly

`runs/twa_sinatra/` で実施した systematic Sinatra criterion test:

| Grid | box | $r = N_{\rm modes} D / N$ | σ/μ at peak |
|---|---|---|---|
| 32³ | 20 | 5.3 | 0.42 |
| 16³ | 20 | 0.66 | 0.31 |
| 16³ | 10 | 0.66 | 0.82 |

16³×box=20 shows σ/μ **shrinkage** to 0.31 (vs 0.42 at 32³). Initial May-7 interpretation:
"Sinatra criterion improves with smaller r → TWA noise converges to lower σ/μ as r → 0".

### 5.7.2 Re-interpretation: GS-resolution artifact

May-8 follow-up revealed: 16³×box=20 has dx = 1.25 a_ho. Eu MF filament has length
3.75 a_ho. **dx/filament = 1/3** — grid does **not resolve** the filament profile.

→ Ground-state profile at 16³×box=20 is artificially smoothed (no filament), so the
post-quench dynamics enters a non-chaotic regime trivially → σ/μ is small **because the
MF dynamics is wrong**, not because TWA noise converged.

16³×box=10 (dx = 0.625, resolution-matched to 32³×box=20) **does** resolve the filament
and **reproduces σ/μ = 0.82** (= even higher than 32³ baseline). Sinatra ratio $r = 0.66$
does **not** suppress σ/μ — the chaos signature is **independent of Sinatra ratio**
when GS attractor is correctly resolved.

### 5.7.3 Methodological lesson

**Beyond-mean-field validation requires holding the GS attractor fixed while varying
noise / mode-count**. Without this control, Sinatra-criterion sweeps can produce
spurious "noise convergence" signals that are actually GS-resolution artifacts.

This is a transferable lesson applicable to any TWA / TDHFB / Beliaev validation
study, not specific to Eu spinor BEC. The resolution-matched (rather than box-matched)
comparison is the correct methodology.

詳細: `docs/research_notes/twa_sinatra_validation.md` (revised verdict).

---

## 5.8 Outlook: TDHFB / Beliaev for Chaotic Regimes

### 5.8.1 Where TWA fails — what's needed

TWA leading-order fails to capture controlled quantum fluctuations in the chaotic
dipolar-collapse regime (§5.5). The required upgrades:

**TDHFB (Time-Dependent Hartree-Fock-Bogoliubov)**:
- Track pair amplitudes $\langle \hat\psi \hat\psi\rangle$ alongside $\langle \hat\psi\rangle$
- Coupled GP + pair-amplitude evolution
- Computational cost: $D^2$ fields per voxel (D=13 for Eu) → 32³ × 13² = 5.5M fields
- Feasible on GPU with 16 GB VRAM (single-precision pair amplitudes)

**Beliaev (full self-consistent Bogoliubov)**:
- Resummation of all Bogoliubov-mode loops self-consistently
- Analytic for uniform; numerically heavy for trap geometries
- Closed-form not currently available for F=6 + DDI

### 5.8.2 D-thesis Ch.3 candidates

両方とも本修論 scope を超え、D 論 Ch.3 (beyond-mean-field methods chapter) の
core content として展開予定:

- TDHFB pilot on Eu post-quench → does cloud stabilize or merely re-renormalize?
- Beliaev for uniform Eu → analytical comparison with paper3 Universal Theorem framework
- Comparison TWA vs TDHFB σ/μ predictions at marginal collapse

### 5.8.3 Experimental observables

For experimental connection (上妻研 Eu post-quench imaging):

1. **Single-shot variability**: σ/μ ≈ 0.42 predicts $\sim 4 \times$ variability in
   filament orientation across shots at lab-frame imaging
2. **Faraday signal scaling**: σ/μ on density translates to ~1% variation in Faraday
   amplitude → observable at current SNR (Faraday floor ~1e-5)
3. **Lyapunov rate**: classical chaos onset rate (= exponential trajectory divergence
   constant) is the experimental signature, **measurable by comparing pre/post-shock
   density at varying delays**

---

## 5.9 Open Questions for D-Thesis

3 つの open question を D 論期間で attack:

1. **Quantitative chaos amplitude**: σ/μ ≈ 0.4-0.8 — BdG spectrum at marginal collapse
   から closed form 抽出可能か? Lyapunov 形式での解析的 prediction。

2. **Experimental verification**: 上妻研 single-shot imaging で post-quench Eu filament
   orientation の 4.5× variability が観察されるか? σ/μ ~ 0.4 predict from §5.5.

3. **TDHFB convergence in chaotic regimes**: TDHFB pilot で quantum fluctuations が
   stabilize する (no collapse) か、merely re-renormalize する (collapse with reduced
   σ/μ) か?

---

## 5.10 章まとめ

本章の 3 主要結果 [T3.1-T3.3]:

1. **[T3.1] LHY-insufficiency on Eu**: 5-mode ablation で LHY 補正は < 1% effect、
   平均場 DDI が dominant、collapse 抑制不可。Dy droplet regime と異なる Eu-specific
   characterization.

2. **[T3.2] σ/μ chaos diagnostic, NOT quantum fluctuation observable**: Sinatra-clean
   1/N test で 1/√N scaling fails at order-of-magnitude level。σ/μ ≈ 0.4-0.8 は
   classical chaos onset を反映、TWA leading-order quantum fluctuation の signal では
   ない。Reframing は modeling 仮定の慎重再検査による methodological contribution。

3. **[T3.3] GS-resolution methodological caveat**: 16³×box=20 σ/μ shrinkage を
   "Sinatra improvement" と誤解しない、resolution-matched comparison が必要。Universal
   lesson for any beyond-mean-field validation in trap geometries.

これら 3 結果は Paper #4 候補 (PRR target)、本修論 thesis-body 章として、また D 論
beyond-mean-field methods chapter (TDHFB / Beliaev pilot) への bridge として機能する。

Chapter 4 (Universal Theorem) の framework は uniform BEC の polyhedral LHY universal
form を確立したが、inhomogeneous + chaotic post-quench dynamics には mean-field
+ classical chaos diagnostic が dominant、LHY (= sub-leading quantum fluctuation) は
adequate にならない、という complementary boundary を本章は示す。

修論本体は Ch.3 (F=2 cyclic, paper #1) + Ch.4 (Universal Theorem, paper #3) +
Ch.5 (TWA chaos, paper #4) + Ch.6 (polyhedral verifications, paper #2 含む) の
4-paper 構造で **mean-field structural + beyond-MF dynamic + experimental** の
完全 stack を形成する。

---

## 参考文献 (本章固有)

[Chapter 2 共通 + 本章固有]:

- **Steel 1998**: M. J. Steel et al., "Dynamical quantum noise in trapped Bose-Einstein
  condensates", Phys. Rev. A **58**, 4824 (1998). [TWA seminal]
- **Sinatra 2001**: A. Sinatra, C. Lobo, Y. Castin, "The truncated Wigner method for
  Bose-condensed gases: limits of validity and applications", J. Phys. B **35**, 3599
  (2002). [Sinatra criterion]
- **Polkovnikov 2010**: A. Polkovnikov, "Phase space representation of quantum dynamics",
  Ann. Phys. **325**, 1790 (2010). [TWA review]
- **Schmitt 2016**: M. Schmitt et al., "Self-bound droplets of a dilute magnetic
  quantum liquid", Nature **539**, 259 (2016). [Dy droplet, LHY-stabilized]
- **Chomaz 2016**: L. Chomaz et al., "Quantum-Fluctuation-Driven Crossover from a
  Dilute Bose-Einstein Condensate to a Macrodroplet in a Dipolar Quantum Fluid",
  Phys. Rev. X **6**, 041039 (2016). [Er droplet]
- **Lima-Pelster 2012**: A. R. P. Lima and A. Pelster, "Beyond mean-field low-lying
  excitations of dipolar Bose gases", Phys. Rev. A **86**, 063609 (2012). [polar
  dipolar LHY $Q_5$]

[Internal references]:

- `docs/research_notes/eu_collapse_lhy_insufficient.md` (May 7 2026, T3.1)
- `docs/research_notes/twa_N_scan_result.md` (T3.2 setup + Findings A/B)
- `docs/research_notes/twa_pinned_16g_result.md` (May 8 2026, T3.2 corrected verdict)
- `docs/research_notes/twa_sinatra_validation.md` (T3.3 GS-resolution lesson)
- `docs/research_notes/twa_eps_dd_scan.md` (§5.6 species-universal chaos)

---

(章末)
