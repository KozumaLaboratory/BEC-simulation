# 修論 Chapter 7: 結論と展望

本章では、本修論で確立した結果を統合的に総括し、D 論期間および post-修論 follow-up
論文への展望を整理する。

---

## 7.1 修論主要結果の概要

本修論は spin-F dipolar Bose-Einstein condensate (BEC)、特に F=6 ¹⁵¹Eu を中心
target として、**mean-field 構造定理** + **beyond-mean-field dynamics** + **experimental
connection** の 3 layer にわたる結果を確立した。Chapter 別 main contributions:

### Chapter 3 [Paper #1]: F=2 cyclic phase の LHY 閉形式

F=2 cyclic phase ($T_d$ 残存対称性) の Lee-Huang-Yang 量子ゆらぎ補正の解析的閉形式:

$$\varepsilon_{\rm LHY}^{F=2,\rm cyc}[n; c_0, c_1] = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 (2 c_1)^{5/2}\right]$$

主結果:
- 10×10 BdG matrix の m-parity による (6+4) block 分解
- non-Bogoliubov amplitude mode (Mode 3, $\omega_3 = \varepsilon_k + 2nc_2/5$, $|\Delta_3| = 0$) の同定
  → LHY 寄与 exactly zero、cyclic phase の structural feature
- Sympy symbolic factorization + 数値検証 (機械精度一致)

### Chapter 4 [Paper #3]: Universal Structure Theorem

任意 polyhedral 残存対称性 $H \in \{T, T_d, O, O_h, I, I_h\}$ を持つ inert spinor phase
についての構造定理:

$$\varepsilon_{\rm LHY}^{(H)} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3\,|\lambda_{\rm spin}^{(H)}|^{5/2}\right]$$

主結果 ([T2.1-T2.4]):
- Schur 補題 + Watanabe-Brauner Goldstone counting による厳密証明
- F-systematic classification: F=1 を唯一例外とし、$F \geq 2$ で polyhedral inert
  states の存在を character orthogonality (Table II) で完全分類
- Modified theorems (axial $D_n, C_n$ residual で multiplet 分裂)
- Selection rule の polyhedral harmonic 統合: $S$-channel 寄与は $F$ ではなく $H$ で決まる
- Sign Pattern Systematic 経験法則 + endpoint lemmas (β_0 = −1/(2F+1), β_{2F} > 0)
- 6 polyhedral cases (F=2 cyclic, F=3 octa A_2, F=4 cube, F=6 ico, F=8 cube-octa, F=10 dodec)
  empirical verification + verify-first audit pass

### Chapter 5 [Paper #4 候補]: TWA chaotic dipolar dynamics

F=6 ¹⁵¹Eu post-quench EdH dynamics の beyond-mean-field treatment:

主結果 ([T3.1-T3.3]):
- **LHY-insufficiency on Eu**: 5-mode LHY ablation で all modes が同じ z-elongated
  filament に collapse、LHY は < 1% effect、Dy droplet regime と異なる Eu-specific
  characterization
- **σ/μ chaos diagnostic**: Sinatra-clean 1/N test (`twa_N_scan_pinned_16g/`) で
  $\sigma/\mu \cdot \sqrt{N}$ が 17.7 → 41.5 → 259 へ growth (order-of-magnitude
  violation of 1/√N scaling) → σ/μ ≈ 0.4-0.8 は **classical chaos onset** を反映、
  TWA leading-order quantum fluctuation observable では**ない**
- **GS-resolution methodological caveat**: 16³×box=20 σ/μ shrinkage は ground-state
  resolution artifact、resolution-matched 比較 (16³×box=10) で chaos signature が
  Sinatra ratio 独立に persist
- Round 2/3 期 framing (= TWA O(1/N) controlled expansion) からの reframing は本研究
  methodological contribution として thesis-defensible

### Chapter 6 [Paper #2 + extras]: Polyhedral phase verifications

Chapter 4 Universal Structure Theorem の 6 polyhedral cases への explicit 適用:

主結果:
- F=6 icosahedral ($I_h$, paper #2 primary): 26×26 BdG の C_5 による mod-5 block 分解
  + 3-block factorization (phonon + spin GM + amplitude) + closed forms
  $c_0 = \frac{1}{13}g_0 + \frac{121}{323}g_6 + \frac{147}{391}g_{10} + \frac{980}{5681}g_{12}$
- F=3 octa A_2 (Round 5 NEW, 奇数 F + sign rep): $\zeta = (\|+2\rangle - \|-2\rangle)/\sqrt{2}$
  → Universal Theorem が奇数 F の sign-rep polyhedral states にも自動適用
- F=4 cube, F=10 dodecahedral, F=8 cube-like octa (Dy 関連): closed forms + selection rule
- Master verification table: 3 polyhedral families (T, O, I) × both F-parities ×
  Cr/Eu/Dy 実験 species をカバー

---

## 7.2 共通 framework: 4 つの load-bearing principle

4 章にわたる結果は、4 つの共通 framework によって統一される:

### 7.2.1 Schur の補題 (Chapter 4 の core)

ポリヘドラル残存対称性 $H$ の下で broken-generator subspace $T_1$ が irreducible
であることが、3 spin Goldstones の **完全縮退** を保証する。これが式 (4.6) の係数 3
+ 2 項構造の表現論的起源。

### 7.2.2 Goldstone 定理 + Watanabe-Brauner counting (Chapter 4, 5)

連続対称性破れ $U(1) \times SO(3) \to G$ により 4 type-I Goldstones (1 phonon + 3 spin
GMs) が生じる。BdG matrix の Bogoliubov form と $\xi = |\Delta|$ identity ($t = 0$)
が LHY 計算を 4 Goldstones 上の sum に reduce する。

### 7.2.3 m-parity / mod-n block 分解 (Chapter 3, 6)

F=2 cyclic で m-parity (mod 2) による (6+4) block 分解、F=6 icosahedral で C_5 によ
る mod-5 block 分解 ((6+6+6+4+4) = 26)。Sparse spinor + discrete residual symmetry が
高次元 BdG matrix を sub-block の集合に factorize し、symbolic な closed-form derivation
を可能にする方法論。

### 7.2.4 Character orthogonality + selection rule (Chapter 4)

$D^F |_H$ の irrep decomposition + harmonic content 計算が、polyhedral inert state の
**存在性** + **selection rule** ($g_S$ 寄与の有無) を同時に決定する。$F$-systematic
分類 (Table II) は character orthogonality の系統適用で得られる。

---

## 7.3 章間 cross-cutting findings

### 7.3.1 Mean-field の structural framework vs beyond-MF dynamics

Chapter 4 (Universal Theorem) は **uniform BEC の mean-field LHY** の universal structure
を確立。Chapter 5 (TWA chaos) は **inhomogeneous + post-quench dynamics** で mean-field
DDI dominant、LHY sub-leading という complementary boundary を示す。両者は互いに
contradiction せず、適用 regime が異なる:

- **Uniform polyhedral inert phase の equilibrium**: Universal Theorem (4.6) が定量
  predict (LHY balance で droplet 可能性)
- **Inhomogeneous post-quench dipolar collapse**: mean-field DDI が dominant、LHY < 1%、
  σ/μ は classical chaos onset

これは spinor BEC 系統で "**いつ LHY が物理を支配し、いつ classical chaos が支配するか**"
の boundary を実験 species level (Eu vs Dy) で characterize した結果。

### 7.3.2 Verify-first 哲学の累積

本修論期間 (~5 ヶ月) で 3 つの大規模 verify-first workflow を運用:

1. **Track A1+C+B integrator modernization** (Chapter 3 of D-thesis, post-修論):
   Y4-midpoint, Track C Force-Gradient, Track B Thalhammer modified-splitting の
   3 frameworks を相互 cross-validate
2. **paper3 v3 5-case polyhedral audit** (Chapter 4 / Chapter 6, 本修論):
   F=3/4/6/8/10 polyhedral inert states を independent reconstruction で
   machine-precision 一致確認
3. **TWA Sinatra-clean validation** (Chapter 5, 本修論):
   "1/√N scaling fails" finding は coupling-strength + Sinatra-mode の二重 variation
   を分離する Sinatra-clean test で初めて見える

Methodology template: (a) memory-based 主張禁止、(b) Phase -1 hard gate (paper transcribe
+ self-check)、(c) cross-framework cross-validation、(d) negative result も formal に
記録。本 template は post-修論 papers 全てに transferable。

### 7.3.3 Negative results catalogue

Chapter 3-6 にわたる negative results が **publishable structural failures** として整理:

1. **MPS-4 multi-scale failure** (D-thesis integrator chapter): Richardson coefficients
   が midpoint MF を異なる時間 scale で評価する → 4th-order recovery fails (order ~1)
2. **AVF state-averaging** ($D-thesis$ §3.7.4.b): $\cos(H\tau/2)$ even-power bias が
   Yoshida-4 composition の order recovery を破壊
3. **Force-Gradient state-avg Picard** ($D-thesis$ §3.7.4.c): AVF failure mode を
   Force-Gradient framework 内で reproduce
4. **F=12 sympy closed-form 単一-channel BdG** (本修論 F12 verification): single-channel
   $g_S$ perturbation での spin Goldstone identification が成立しない → multi-channel
   sympy derivation が proper path
5. **TWA leading-order 1/√N scaling** (Chapter 5): chaotic regime で fails、reframing
   が methodological contribution

これら 5 + (D-thesis 4) negative results の formal documentation は、研究 community
への "what doesn't work and why" の系統的提供として本研究の独立した contribution。

---

## 7.4 Publishable contributions: 4 paper seeds

修論期間中に submit-ready な 4 papers:

### Paper #1 (PRA target): F=2 cyclic LHY closed form

- Status: 完了、submission ready
- Content: Chapter 3 を expanded form で
- Length: ~10-12 pages
- Novel content: cyclic phase LHY 閉形式 (文献的に未確立だった) + non-Bogoliubov
  amplitude mode の同定 + m-parity block 分解 methodology

### Paper #2 (PRA / PRR target): F=6 icosahedral LHY closed form

- Status: 完了、submission ready
- Content: Chapter 6 §6.1-6.5 を expanded form で
- Length: ~10-12 pages
- Novel content: F=6 $I_h$ phase LHY 閉形式 + mod-5 block 分解 (新規 methodology) +
  Eu spinor BEC 実験への direct connection

### Paper #3 (PRR / PRX target): Universal Structure Theorem (comprehensive)

- Status: v3 完了、verify-first audit pass、PRR/PRX submission-ready
- Content: Chapter 4 を expanded + 6 polyhedral cases verification (Chapter 6 から
  pull) + Sign Pattern Systematic
- Length: ~14-16 pages
- Novel content: **Universal Structure Theorem** for polyhedral inert states +
  F-systematic classification + F=1 unique exception + modified theorems for axial
  symmetries + Sign Pattern Systematic empirical 法則 + endpoint lemmas

### Paper #4 (PRR target): Chaotic dipolar instability + TWA leading-order breakdown

- Status: Chapter 5 integrated draft 完了、submission-ready
- Content: Chapter 5 §5.4-5.6 を expanded
- Length: ~8-10 pages
- Novel content: **σ/μ chaos diagnostic** at marginal collapse + 1/√N scaling
  failure quantitative demonstration + GS-resolution methodological caveat + species
  universality

合計 ~42-50 pages の publishable material が本修論作成期間で確保された。

---

## 7.5 D 論への展望 (Year 1-3 plan)

修論で確立した framework を基盤として、D 論期間で展開可能な research directions:

### 7.5.1 Year 1: framework extension

- **Sign Pattern conjecture 厳密証明** (paper3 v4 → independent paper):
  Strategy A (Wigner-Eckart 6j) の Step 3-4 完成、6j-symbol product factorization に
  よる single-sign-change の rigorous proof
- **F=5, 7, 9, 11 systematic completion**: paper3 で deferred されていた奇数 F の
  polyhedral inert state verification、Universal Theorem の F-coverage を完全化
- **Dipolar generalization (Lima-Pelster $Q_5$)**: Universal Theorem の dipolar 拡張、
  Eu/Dy polyhedral phase での DDI-modified LHY closed form

### 7.5.2 Year 2: beyond-mean-field

- **TDHFB pilot on Eu** (Chapter 5 §5.8): pair amplitude tracking、chaotic regime
  での quantum fluctuation 抑制 (stabilize) vs re-renormalization の区別
- **Beliaev for uniform F=6 polyhedral phases**: full self-consistent Bogoliubov mode
  resummation、Universal Theorem との analytical comparison
- **Two-component / binary spinor extension**: Thalhammer 2026 J=2 framework の SpinorBEC
  への拡張、$^{87}$Rb-$^{23}$Na 系統への applicability

### 7.5.3 Year 3: experimental synthesis

- **上妻研 Eu single-shot collaboration**: σ/μ ≈ 0.4 chaos prediction の experimental
  verification (Faraday signal の shot-to-shot variability)
- **Innsbruck Dy spinor droplet**: F=8 cube-like octa polyhedral phase realization
  + Feshbach engineering ($g_{12}/g_{14}/g_{16}$ resonance) の collaboration target
- **Cr F=3 polyhedral**: Universal Theorem の奇数 F (sign rep $A_2$) instance、
  Stuttgart group の Cr 系統との connection

---

## 7.6 Methodology contribution (cross-cutting)

本修論は specific results に加え、**reusable methodology template** を確立した:

### 7.6.1 Verify-first protocol

(a) Memory-based 主張禁止、(b) Phase -1 hard gate (paper transcribe + self-check
+ limit reductions)、(c) cross-framework cross-validation (≥ 2 frameworks で同じ
finding を reproduce)、(d) negative result も formal に記録 (failure mode analysis として
publishable)。

これは Track A1+C+B integrator work (D-thesis pre-cursor) と paper3 audit で
load-bearing として機能、3 つの post-修論 papers 全てこの template で書ける。

### 7.6.2 sympy + 数値 cross-verification

Closed-form derivations を sympy で得て、別 framework (e.g., direct BdG diagonalization,
group-projection numerical reconstruction) で independent に verify する。Bug catch
率 + reviewer-defensibility 共に高い。

本修論期間で 2 bug を verify-first audit で catch:
- icosahedral 3-fold axis tilt 31.72° → 37.38° (azimuth π/5)
- F=3 octa A_2 character の C_2 axial classification ("commutes with $C_{4z}$" 誤、
  "$h^2$ for order-4 $h$" 正)

### 7.6.3 Resolution-matched comparison (Chapter 5 §5.7)

Beyond-mean-field validation は **ground-state attractor を fix した状態で** noise
/ mode-count を vary するべき。box-matched 比較 (e.g., 16³×box=20 vs 32³×box=20) は
GS-resolution artifact を生み、Sinatra ratio scaling の spurious "convergence" を
誤判定する。Universal lesson for any TWA / TDHFB / Beliaev validation in trap
geometries。

---

## 7.7 Acknowledgments

本研究の遂行にあたり、指導教員の松井先生からの一貫した助言とご指導をいただいた。
特に Eu spinor BEC の物理像の構築および thesis structure 設計について深く感謝する。

上妻研究室には Eu 実験の direct collaboration として、scattering length 測定の最新
値 + post-quench EdH protocol detail を共有いただいた。Stuttgart group (T. Pfau et al.)
および Innsbruck group (F. Ferlaino et al.) からも Cr / Dy 系統 dipolar spinor BEC
の experimental context について interactive discussions の機会を得た。

数値計算基盤として SpinorBEC.jl の development には研究室 mates + 並列セッション
collaboration が貢献した。GPU computational resources は TSUBAME 4.0 (東京科学大学)
で供与された。

実装 + 検証 workflow の高速化に Claude Code (Anthropic) を verify-first protocol の
co-pilot として活用した。Code/document の co-authoring + cross-framework consistency
checking の supporting tool としての位置付け。

---

## 7.8 修論 closure

本修論は spin-F dipolar BEC の **mean-field structural framework** (Universal Theorem)
+ **beyond-mean-field dynamics characterization** (TWA chaos diagnostic) + **F=2 cyclic
warmup case** + **6 polyhedral verifications** の 4 layer に統合された publishable
material を提供する。

4 paper seeds (Paper #1-4) は合計 ~42-50 pages、PRR/PRX target を含む高 impact journal
への投稿に直接対応。D 論期間 (3 years) では framework extension (Year 1)、beyond-mean-field
methods (Year 2)、experimental synthesis (Year 3) の roadmap で展開可能。

Methodology の verify-first protocol、negative results catalogue、resolution-matched
comparison という 3 つの **reusable methodology contribution** は specific physics
results を超えた contribution として位置付けられる。

本修論の確立した framework は、$^{151}$Eu spinor BEC の上妻研 experimental program
への direct theoretical support、および dipolar spinor BEC physics の Cr/Eu/Dy 統一
treatment への基盤として、当該研究 community への持続的 contribution となることを
意図する。

---

(章末 — 修論本体終了)
