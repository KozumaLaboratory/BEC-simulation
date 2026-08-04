# 修論 Chapter 1: 序論

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

本章では、本研究の motivation、background、および thesis structure を提示する。
具体的には:

1. **Spinor BEC + dipolar physics** の historical context と現状
2. **F=6 ¹⁵¹Eu spinor BEC** が dipolar quantum simulation において占める unique
   position
3. **Lee-Huang-Yang (LHY) 量子ゆらぎ補正** の universal structure を確立するに
   至った motivation
4. **本修論で得られた結果の overview** と thesis structure

---

## 1.1 Bose-Einstein 凝縮: 中性原子系における macroscopic quantum coherence

### 1.1.1 BEC の歴史的背景

Bose-Einstein 凝縮 (BEC) は、1924-1925 年に Bose と Einstein が予言した低温
ideal Bose 気体の macroscopic ground-state coherence 状態である。1995 年に
$^{87}$Rb [Anderson et al. 1995] および $^{23}$Na [Davis et al. 1995] の dilute
gas BEC が初めて実験的に実現されて以来、cold atom 実験技術の発展とともに、BEC は
quantum many-body physics の central platform として地位を確立してきた。

scalar BEC (1-component) を超えた **spinor BEC** の研究は、原子の hyperfine spin
$F$ の internal degree of freedom を ground state に内包する系として展開されてきた
[Stenger et al. 1998 ($^{23}$Na, F=1), Stamper-Kurn-Ueda 2013 review]。spinor BEC は
$2F+1$ 成分の order parameter $\zeta_m \in \mathbb{C}$ ($m = -F, \ldots, +F$) で
記述され、内部 spin-spin 相互作用 + Zeeman 相互作用 + 外部 trap によって rich な
ground-state phase 構造を持つ。

### 1.1.2 Spinor BEC の theoretical framework

$F$-成分 spinor BEC の interaction Hamiltonian は s-wave scattering channel の和:

$$\hat{H}_{\rm int} = \frac{1}{2}\int d^3 r \sum_{S \in \text{allowed}} g_S \hat{\mathcal{P}}_S(\mathbf{r})$$

ここで $g_S = 4\pi\hbar^2 a_S / M$、$a_S$ は全 spin $S$ channel の scattering 長。
Bose 統計より allowed $S = 0, 2, 4, \ldots, 2F$ (= $F+1$ independent couplings)。

各 spin-$F$ 系には $F$ + 1 個の independent couplings がある:
- F=1 ($^{87}$Rb): 2 channels (S=0, 2) → 2 effective couplings $c_0, c_1$
- F=2 ($^{87}$Rb F=2 state, $^{23}$Na excited state): 3 channels
- F=3 ($^{52}$Cr ground state): 4 channels
- F=6 ($^{151}$Eu): 7 channels
- F=8 ($^{164}$Dy): 9 channels

高 spin 系では couplings 数が増え、scattering channel 間の関係 (constraint, Feshbach
resonance での選択的 tuning) が複雑になる。

### 1.1.3 Ground-state phase diversity

F=1 系では 2 つの uniform phase が知られる: **polar** ($\zeta \propto (0, 1, 0)^T$,
residual symmetry $D_{\infty h}$) と **ferromagnetic** ($\zeta \propto (1, 0, 0)^T$,
residual $C_{\infty v}$) [Ohmi-Machida 1998, Ho 1998]。

F=2 では 4 つの uniform phases: polar (P), ferromagnetic (FM), antiferromagnetic /
**biaxial nematic** (BN, residual $D_4$), **cyclic** (C, residual $T_d$) [Ciobanu-Yip-Ho
2000, Koashi-Ueda 2000]。

F ≥ 3 系では更に rich な phase 構造、特に **polyhedral inert states** (Majorana 表現で
正多面体頂点配置) が予測される [Mäkelä-Suominen 2007, Yukawa-Ueda 2011]:
- F=3: T-invariant, O:A_2 invariant (octahedral)
- F=4: cube ($O_h$:A_1g)
- F=6: icosahedral ($I_h$:A_g, 12 Majorana points = icosahedron vertices)
- F=8: cube-like octahedral ($O$:A_1)
- F=10: dodecahedral ($I_h$:A_g, 20 Majorana points)

これら高対称 phases の LHY 量子ゆらぎ補正の解析的取扱いが本研究の中心 topic。

---

## 1.2 Dipolar BEC: long-range anisotropic interaction

### 1.2.1 Dipolar physics の motivation

magnetic dipole-dipole interaction (DDI) は long-range ($\sim 1/r^3$) + anisotropic な
相互作用で、neutral atom BEC では原子の magnetic moment $\mu$ に由来する:

$$V_{\rm DDI}(\mathbf{r}_1 - \mathbf{r}_2) = \frac{\mu_0 \mu^2}{4\pi r^3} \left(1 - 3 \cos^2\theta\right)$$

DDI の典型 dipolar species は magnetic moment $\mu$ の大きい transition / rare-earth
原子:
- $^{52}$Cr: $\mu = 6 \mu_B$ (F=3 ground state)
- $^{166,168,170}$Er: $\mu = 7 \mu_B$ (F=6 ground state)
- $^{151,153}$Eu: $\mu = 6.98 \mu_B$ (F=6, $g_F \approx 1.163$)
- $^{162,164}$Dy: $\mu = 9.93 \mu_B$ (F=8 ground state, largest natural $\mu$)

dipolar BEC の主要 phenomena:
- **dipolar instability**: contact (= $c_0$) vs DDI (= $c_{\rm dd} = \mu_0 \mu^2$)
  の balance、 $\epsilon_{\rm dd} = c_{\rm dd}/c_0 > 0$ で z-elongated filament 形成
- **Rosensweig instability**: classical ferrofluid analog の pattern formation
- **dipolar droplets**: LHY-stabilized self-bound 状態 [Schmitt 2016, Chomaz 2016]
- **Einstein-de Haas effect (EdH)**: spin-orbit coupled angular momentum 移動

### 1.2.2 F=6 ¹⁵¹Eu の unique position

¹⁵¹Eu (F=6, μ ≈ 6.98 μ_B, $g_F \approx 1.163$) は以下の特徴で **spinor BEC + dipolar
quantum simulation** の unique platform を提供する:

1. **高 spin (F=6) + 強 DDI**: 13 spinor components + Dy に匹敵する DDI 強度
2. **Polyhedral inert state**: 12 Majorana points = icosahedron vertices の $I_h$ phase
   が ground-state candidate (Mäkelä-Suominen 2007 で系統的に同定)
3. **7 scattering channels** (S = 0, 2, 4, 6, 8, 10, 12) で 6 unknown coupling: 大規模
   parameter space + Feshbach resonance による selective tuning の余地
4. **実験 group: 上妻研** (東大): post-quench EdH protocol + Faraday imaging で
   single-shot variability + density profile 測定が可能

これら因子により、Eu spinor BEC は本研究の primary target species となる。

### 1.2.3 dipolar species comparison

| species | F | $a_s$ ($a_B$) | $\mu$ ($\mu_B$) | $\epsilon_{\rm dd}$ | polyhedral inert? |
|---|---|---|---|---|---|
| ⁵²Cr | 3 | 7 | 6.0 | 0.15 | O:A_2 (octa) |
| ¹⁶⁸Er | 6 | 65 | 7.0 | 0.88 | $I_h$:A_g (icosa) |
| ¹⁵¹Eu | 6 | 110 | 6.98 | 1.39 | $I_h$:A_g (icosa) |
| ¹⁶⁴Dy | 8 | 92 | 9.93 | 1.39 | O:A_1 (cube-octa) |

Eu と Dy は $\epsilon_{\rm dd} = 1.39$ で同じ dipolar regime に達するが、F (6 vs 8)
+ scattering channel 数 (7 vs 9) で 物理 contents が異なる。本研究では Eu を primary
focus、Cr/Dy を comparative species として treatment。

---

## 1.3 Lee-Huang-Yang 量子ゆらぎ補正: motivation for universal structure

### 1.3.1 LHY の history と significance

Lee-Huang-Yang (LHY) 補正 [Lee-Huang-Yang 1957] は、Bose 気体の zero-temperature
ground-state energy への量子ゆらぎ寄与:

$$\varepsilon_{\rm LHY}^{\rm scalar} = \frac{8\sqrt{M^3}}{15 \pi^2 \hbar^3} (g n)^{5/2} \cdot \frac{1}{g^2} = \frac{8 g}{15 \pi^2 \hbar^3} \sqrt{M^3 g^3} n^{5/2}$$

scalar BEC では $\sim n^{5/2}$ で contact $g n^2$ mean-field を sub-leading 補正する。

dipolar BEC では LHY 補正が決定的役割を果たす: **dipolar droplet** (Petrov 2015 で
予言、Schmitt 2016 で Dy 系初観測) は LHY が contact-mean-field collapse を抑制して
self-bound 状態を実現する quantum-fluctuation-stabilized 系。

spinor BEC の LHY: F=1 polar, FM については Kawaguchi-Ueda 2012 review で closed form
確立 [Phuc-Ueda 2014, Lima-Pelster 2011-2012 関連]。**F ≥ 2 の高対称 phase (cyclic,
polyhedral) は未確立** — これが本研究の motivation。

### 1.3.2 Polyhedral phase LHY の困難性

F=2 cyclic, F=6 icosahedral などの polyhedral phases は:
- $10 \times 10$ (F=2) から $26 \times 26$ (F=6) までの BdG matrix を持つ
- discrete residual symmetry の下で sparse spinor + complex block structure
- 既存の case-by-case 計算では 17×17 (F=8) 等の大規模 BdG で symbolic factorization
  が非自明

これら個別 case 計算を超え、**polyhedral residual symmetry 自体に基づいた universal
form** の確立が、本研究の表現論的 contribution。

### 1.3.3 本研究の position

本研究は、

1. **F=2 cyclic phase の LHY closed form** を確立 (Chapter 3, Paper #1)
2. **F=6 icosahedral phase の LHY closed form** を確立 (Chapter 6, Paper #2)
3. これらを動機として **Universal Structure Theorem** を Schur 補題 + representation
   theory で証明 (Chapter 4, Paper #3)
4. 6 polyhedral phases (F=2 cyclic, F=3 octa, F=4 cube, F=6 ico, F=8 cube-octa, F=10
   dodec) で empirical verify
5. **Sign Pattern Systematic** という empirical 法則を発見 (paper3 §IX.B, "spinor-rank
   matching")

mean-field structural framework に加え、

6. **F=6 ¹⁵¹Eu post-quench dipolar collapse** の TWA dynamics を解析、σ/μ ≈ 0.4 が
   chaos onset を反映、classical chaos が dominant という reframing を行う
   (Chapter 5, Paper #4)

これら 4 papers + verify-first methodology + negative results catalogue が本修論の
publishable contribution。

---

## 1.4 Numerical infrastructure: SpinorBEC.jl

### 1.4.1 Motivation

spinor BEC + DDI 数値計算は、本研究で 3D F=6 26-component grids を扱うため、
GPU acceleration + high-level YAML pipeline + reproducibility infrastructure が必須。

既存 spinor BEC codes (TWA / GP / BdG 専用) は F ≤ 2 / scalar / specific species
limited で、F=6 + DDI + multi-stage pipeline には fit せず、専用 framework の開発が
必要となった。

### 1.4.2 SpinorBEC.jl の architecture

本研究で開発した SpinorBEC.jl (Julia, ~ 60K LOC, 8451 tests pass):
- **split-step Fourier** integrator (1D/2D/3D, F=1 to F=6+ generic)
- **CPU + GPU backends** (CUDA extension)
- **YAML pipeline runner** + experiment scheduler + checkpoint/resume
- **dashboard** (Vite + React + WebGPU 3D visualization)
- **mode-by-mode**: ITP (ground state), RTP (dynamics), TWA (ensemble), TDHFB (future)

詳細: Chapter 2 で technical scaffold、Appendix B で API reference。

本研究の全ての mean-field + LHY + TWA + dynamics 結果は SpinorBEC.jl で再現可能、
runs/ 配下に config.yaml + result.jld2 として repository-tracked。

---

## 1.5 Thesis structure

本修論の構成と各章の position:

### Chapter 2: Spinor BEC framework (技術 scaffold)

Spinor BEC Hamiltonian, $c_n \leftrightarrow g_S$ conventions, BdG matrix 構成,
Goldstone 定理, mean-field ground state (ITP), real-time evolution (RTP),
SpinorBEC.jl architecture overview。Ch.3-6 で使う tools の preview。

### Chapter 3: F=2 cyclic phase LHY 解析的閉形式 [Paper #1]

F=2 cyclic phase の 10×10 BdG matrix を m-parity (mod 2) で (6+4) block 分解、
sympy + 数値で symbolic factorization、closed form
$\varepsilon_{\rm LHY}^{F=2,{\rm cyc}} \propto c_0^{5/2} + 3(2c_1)^{5/2}$ の確立。
non-Bogoliubov amplitude mode (Mode 3) の同定 + LHY 寄与 zero の structural 起源。

### Chapter 4: Universal Structure Theorem [Paper #3]

Schur 補題による polyhedral inert state LHY 閉形式の universal form 定理証明、
F-systematic classification (F=1 unique exception)、modified theorems (axial),
Sign Pattern Systematic empirical 法則 + endpoint lemmas。

### Chapter 5: TWA chaotic dipolar dynamics in F=6 Eu [Paper #4]

post-quench Eu dipolar instability の beyond-mean-field treatment、5-mode LHY
ablation で LHY-insufficient、Sinatra-clean 1/N test で TWA leading-order が
**chaos onset diagnostic** であり quantum fluctuation observable でないことを定量証明。
GS-resolution methodological caveat。

### Chapter 6: Polyhedral phase verifications [Paper #2 + extras]

Universal Structure Theorem (Ch.4) の 6 polyhedral cases への explicit 適用、
F=6 icosahedral (paper #2 primary) + F=3 octa A_2 (Round 5 NEW odd F) + F=4 cube +
F=8 cube-like octa (Dy 関連) + F=10 dodec + F=2 BN axial edge case。Sign Pattern
Systematic の 6-case empirical 検証。

### Chapter 7: 結論と展望

4 papers の synthesis、共通 framework (Schur + Goldstone + block 分解 + character
orthogonality)、verify-first methodology contribution、negative results catalogue、
D 論 outlook (3-year plan)。

### Appendices

- **A**: Sympy verification scripts (全 6 polyhedral cases + F=2 BN edge case)
- **B**: SpinorBEC.jl API reference + reproducibility chain (runs/ configs)
- **C**: Wigner D matrix + Clebsch-Gordan + 6j-symbol Racah algebra basics
- **D**: F=0 .. 12 multiplicity table (Universal Theorem F-classification) derivation
- **E**: Verify-first audit details (paper3 audit + F=12 verification)

---

## 1.6 Conventions and notation

### 1.6.1 単位系

本修論では **dimensionless units** ($\hbar = M = \omega_{\rm ref} = 1$) を default
で使用。physical units が必要な場合 (実験 connection §1.6.3, Eu species
parameters §1.2.2) は明示的に $\mu_B, a_0$ 等で記述。

### 1.6.2 Spinor 表記

spinor: $|\zeta\rangle = \sum_m \zeta_m |F, m\rangle$, components indexed by
$m \in \{F, F-1, \ldots, -F\}$ (high to low)。array layout in code:
`psi[x, y, z, c]` with `c = 1 → m=F`, `c = D → m=-F`.

### 1.6.3 Interaction coupling conventions

2 つの coupling convention を併用 (mutual translation Appendix C):

- **$c_n$ (KU convention)**: F=1 で $c_0$ (density), $c_1$ ($|F|^2$); F=2 で
  $c_0, c_1, c_2$ ($|A_{00}|^2$)。物理的解釈は容易だが F ≥ 3 で完備性なし。
- **$g_S$ (channel convention)**: 全 spin $S$ channel の scattering coupling
  $g_S = 4\pi\hbar^2 a_S / M$。Bose-symmetric $S = 0, 2, ..., 2F$。Universal Theorem
  内で primary convention。

両者は **invertible linear transformation** で結ばれる (Chapter 2 §2.3.4)。

### 1.6.4 DDI convention (CLAUDE.md "do NOT fix")

本研究の DDI convention は:
- $c_{\rm dd} = \mu_0 \mu^2$ (without $4\pi$ factor)
- $Q_{\alpha\beta} = \hat{k}_\alpha \hat{k}_\beta - \delta_{\alpha\beta}/3$
  (without $1/(4\pi)$ factor)
- $Q(\mathbf{k} = 0) = 0$ (self-consistent chain convention)

これは Saito-Ueda 系統 + Eu 上妻研実験 + SpinorBEC.jl で consistent な convention。
公式変換は Appendix C にあり。

---

## 1.7 章末: 本章の lessons

Chapter 1 で:

- spinor BEC の history と多 spin (F=6 Eu) における unique position を概観
- dipolar physics + LHY 量子ゆらぎ補正の意義を説明
- 本研究で確立する **Universal Structure Theorem** + **TWA chaos diagnostic** の
  motivation
- 4 paper seeds + thesis 7 章構造の overview
- conventions (dimensionless units, $c_n$/$g_S$ coupling, DDI normalization) を定義

以降の chapters では:
- **Chapter 2** で technical framework (Hamiltonian, BdG, SpinorBEC.jl) の preview
- **Chapter 3** で F=2 cyclic warmup
- **Chapter 4** で Universal Structure Theorem の formal 証明
- **Chapter 5** で TWA chaos diagnostic
- **Chapter 6** で 6 polyhedral phases の explicit verification
- **Chapter 7** で 4-paper synthesis + 展望

を順に展開する。

---

(章末)
