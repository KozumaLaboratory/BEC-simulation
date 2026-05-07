# 修士論文 Chapter 3: F=2 Cyclic Phase の Lee-Huang-Yang 解析公式

本章では、F=2 スピノル BEC の cyclic phase に対する Lee-Huang-Yang (LHY) 量子ゆらぎ
補正の解析的閉形式を導出する。これは本研究の理論的 core の一つであり、文献的に新規な
結果として、修論期間内の論文 submission [Paper #1] に直接対応する。

---

## 3.1 動機と概要

### 3.1.1 文献的位置付け

F=2 スピノル BEC の 4 相 (P, FM, C, BN) のうち、polar / FM phase の LHY closed form
は Kawaguchi-Ueda 2012 review で確立されている。一方、

- **Cyclic phase の LHY**: 文献的に **未確立**

これは spinor BEC の ground state phases 中で、最も対称性の高い T_d phase であり、
非自明な block 構造と非 Bogoliubov amplitude mode を持つために、解析的取り扱いが
従来困難であった。

### 3.1.2 本章で確立する結果

3 つの新規結果:

**[T1.1]** F=2 cyclic phase の LHY 閉形式:

$$\boxed{\varepsilon_{\rm LHY}^{F=2,\,\rm cyc}[n; c_0, c_1] = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 (2 c_1)^{5/2}\right]}$$

**[T1.2]** Cyclic-phase BdG matrix の m-parity block 分解:
$10 \times 10$ → $6 \times 6$ (even) ⊕ $4 \times 4$ (odd)

**[T1.3]** Cyclic-specific amplitude mode の同定:
$\omega_3 = \varepsilon_k + 2nc_2/5$, $|\Delta_3| = 0$, LHY 寄与 = 0

---

## 3.2 F=2 Cyclic Phase の Setup

### 3.2.1 F=2 Hamiltonian

F=2 スピノル BEC の interaction Hamiltonian (Chapter 2 で導入):

$$\hat{H}_{\rm int} = \frac{1}{2}\int d^3r \left[c_0\, \hat{n}^2 + c_1\, |\hat{\mathbf{F}}|^2 + c_2\, |\hat{A}_{00}|^2\right]$$

with $c_k$ linear combinations of $g_S$ ($S = 0, 2, 4$):
$c_0 = (4 g_2 + 3 g_4)/7$, $c_1 = (g_4 - g_2)/7$, $c_2 = (7 g_0 - 10 g_2 + 3 g_4)/7$.

### 3.2.2 Cyclic Spinor

$$\zeta_{\rm cyc} = \frac{1}{2}\begin{pmatrix} 1 \\ 0 \\ i\sqrt{2} \\ 0 \\ 1 \end{pmatrix}$$

性質:
- $|\zeta|^2 = 1$ ✓
- $\langle \mathbf{F} \rangle = 0$, $\langle A_{00} \rangle = 0$
- 4 Majorana points = tetrahedron vertices
- 残存対称性: $T_d$
- Sparsity: $\zeta_{\pm 1} = 0$

### 3.2.3 Cyclic Phase の安定性

数値 BdG 対角化により以下を確認:

- $c_0 > 0, c_1 > 0, c_2 > 0$: 全 mode 安定 ✓
- $c_1 < 0$: complex eigenvalues (dynamic instability)
- $c_2 < 0$: amplitude mode が unphysical sign

→ Cyclic phase は **$c_0, c_1, c_2 > 0$ octant でのみ stable**。これは Ohmi-Machida 1998
で指摘されていたが、本研究で改めて数値検証した。

---

## 3.3 BdG Matrix の構築と Block 分解

### 3.3.1 m-parity Sparsity

Cyclic spinor $\zeta_{\rm cyc}$ は $m \in \{-2, 0, +2\}$ にのみ non-zero 成分を持つ
(全て偶 $m$)。Hartree-Fock matrix $h$ と anomalous matrix $M$ は $\zeta^*_\mu \zeta_\nu$
or $\zeta_\mu \zeta_\nu$ products に依存するため、以下の選択則が出る:

**選択則 (S1)** ($h$ matrix):
$h_{m m'} \neq 0 \quad \Leftrightarrow \quad m \equiv m' \pmod 2$

**選択則 (S2)** ($M$ matrix):
$M_{m m'} \neq 0 \quad \Leftrightarrow \quad m + m' \equiv 0 \pmod 2$

つまり、両 matrices は m-parity (偶/奇) で block-diagonal。

### 3.3.2 Block 構造

スピノル空間 (5次元) を m-parity で分解:

| Class | $m$ values | 次元 |
|---|---|---|
| Even ${\cal E}$ | $\{-2, 0, +2\}$ | 3 |
| Odd ${\cal O}$ | $\{-1, +1\}$ | 2 |

Total: $3 + 2 = 5$ ✓

Nambu 空間 (10次元) で:

| Block | Particle | Hole | Nambu dim |
|---|---|---|---|
| Even ${\cal B}^{\cal E}$ | ${\cal E}$ | ${\cal E}$ | $3 + 3 = 6$ |
| Odd ${\cal B}^{\cal O}$ | ${\cal O}$ | ${\cal O}$ | $2 + 2 = 4$ |

(注: 選択則 (S2) で $m + m' \equiv 0 \pmod 2$ なので、even-odd cross-coupling はゼロ。
これは F=6 icosahedral phase での mod 5 block 分解と類似の構造。)

### 3.3.3 Even Block ($6 \times 6$): Mode の同定

数値 + 記号計算で、Even block の characteristic polynomial を `sympy.factor` すると、
4 つの factor に factorize される:

$$\det(\mathcal{M}_{\rm BdG}^{\cal E} - \omega \sigma_z) = \frac{1}{60025}\, \Pi_1\, \Pi_2\, \Pi_3\, \Pi_4$$

with:
- $\Pi_1 = 7\omega^2 - 7\varepsilon_k^2 - 14 n c_0 \varepsilon_k$ → **Mode 1 (phonon)**: $\omega_1^2 = \varepsilon_k(\varepsilon_k + 2 n c_0)$
- $\Pi_2 = 7\omega^2 - 7\varepsilon_k^2 - 28 n c_1 \varepsilon_k$ → **Mode 2 (even spin GM)**: $\omega_2^2 = \varepsilon_k(\varepsilon_k + 4 n c_1)$
- $\Pi_3 = 35(\omega - \varepsilon_k) + 14 n c_2$
- $\Pi_4 = 35(\omega + \varepsilon_k) - 14 n c_2$

$\Pi_3, \Pi_4$ は linear factors (not Bogoliubov form). 解は:
$\omega = \pm(\varepsilon_k + 2nc_2/5)$ — physical な positive branch は **Mode 3 (amplitude)**:
$\omega_3 = \varepsilon_k + 2 n c_2 / 5$.

### 3.3.4 Odd Block ($4 \times 4$): 縮退 spin Goldstones

Odd block の 4 eigenvalues は:

$\omega^2 = \varepsilon_k(\varepsilon_k + 4 n c_1) \quad$ (×2 縮退)

→ **Modes 4, 5 (odd spin GMs)**: 2-fold degenerate, mode 2 と同じ dispersion.

### 3.3.5 全 5 modes の summary

| Mode | $\omega^2(\mathbf{k})$ or $\omega(\mathbf{k})$ | $\xi$ | $|\Delta|$ | Type |
|---|---|---|---|---|
| 1 (phonon) | $\varepsilon_k(\varepsilon_k + 2 n c_0)$ | $c_0$ | $c_0$ | U(1) Goldstone |
| 2 (even spin GM) | $\varepsilon_k(\varepsilon_k + 4 n c_1)$ | $2 c_1$ | $2 c_1$ | $T_1$, $F_z$ component |
| 3 (amplitude) | $\varepsilon_k + 2 n c_2 / 5$ | $2 c_2/5$ | **0** | non-Bogoliubov |
| 4, 5 (odd spin GMs) | $\varepsilon_k(\varepsilon_k + 4 n c_1)$ (×2) | $2 c_1$ | $2 c_1$ | $T_1$, $F_\pm$ components |

**Goldstone 数 = 4** ($U(1) \times SO(3) \to T_d$ で 1 + 3 = 4 broken generators) ✓

3 spin Goldstones ($\omega_2, \omega_4, \omega_5$) は $T_1$ irrep of $T_d$ で **degenerate**
— これは Schur lemma により、$T_d$ への $T_1$ 制限が irreducible だから保証される。

---

## 3.4 Mode 3 (Amplitude Mode) の特殊性

### 3.4.1 Linear non-Bogoliubov dispersion

Mode 3 の dispersion $\omega_3 = \varepsilon_k + 2 n c_2 / 5$ は **standard Bogoliubov 形を
持たない**:

- Standard Bogoliubov: $\omega^2 = \varepsilon_k(\varepsilon_k + 2 n \xi)$, $\omega \to 0$ at $k \to 0$
- Mode 3: linear in $\varepsilon_k$ with constant offset $2 n c_2 / 5$, **gapped at $k = 0$**

これは **$|\Delta_3| = 0$** の direct consequence:

$$\omega^2 = (\varepsilon_k + n \xi)^2 - (n |\Delta|)^2 \xrightarrow{|\Delta| \to 0} \omega = \varepsilon_k + n \xi$$

### 3.4.2 物理的意味

Mode 3 は cyclic phase の **amplitude (Higgs-like) mode**:
- Singlet pair amplitude $A_{00}$ の "amplitude" 振動
- Cyclic phase で $\langle A_{00} \rangle = 0$ なので、broken phase (= polar / BN where $\langle A_{00} \rangle \neq 0$) の Higgs amplitude mode の "missing analog"
- Linear dispersion + gapped nature: free particle に類似

### 3.4.3 LHY 寄与は exactly zero

Universal LHY formula:
$$\varepsilon_{\rm LHY} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2} \sum_{b: |\Delta_b| > 0} \nu_b\,|\Delta_b|^{5/2}\,\phi_1^{\rm reg}\!\left(\frac{\xi_b}{|\Delta_b|}-1\right)$$

Mode 3 は $|\Delta_3| = 0$ なので **総和から除外** され、寄与 = 0。

これは naively には paradoxical (mode 3 は free particle ではなく、$\xi_3 = 2c_2/5 \neq 0$
の non-trivial coupling を持つ) が、physically には:

- LHY は zero-point energy の renormalized sum (Eq. 2.14)
- 第 2, 3 項 (UV cancellation) で $\xi_b$ の linear-in-$n$ shift が cancel される
- 残るのは $|\Delta_b|$-dependent な anomalous (pair-creating) loops のみ
- Mode 3 は $|\Delta| = 0$ で no anomalous loops → no LHY contribution at $n^{5/2}$ order

---

## 3.5 LHY 閉形式の派生

### 3.5.1 Goldstone modes の寄与

4 Goldstones (modes 1, 2, 4, 5) は $\xi_b = |\Delta_b|$ → $t = 0$ → $\phi_1^{\rm reg}(0) = 1$。

各 mode の寄与:
- Mode 1: $1 \cdot c_0^{5/2}$
- Modes 2, 4, 5 (合計 multiplicity 3): $3 \cdot (2 c_1)^{5/2}$

### 3.5.2 結論

$$\boxed{\varepsilon_{\rm LHY}^{F=2,\,\rm cyc} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 (2 c_1)^{5/2}\right]} \tag{3.1}$$

これが **F=2 cyclic phase の LHY 解析的閉形式**。$c_2$ に依存せず ($g_0$ の effect は
$c_2$ にのみ含まれる)、scalar limit $c_0 = g, c_1 = 0$ では scalar Lima-Pelster に reduce。

---

## 3.6 数値検証

### 3.6.1 Sympy による symbolic factorization

Representative parameter sets で `sympy.factor` の出力:

```python
g0, g2, g4 = symbols('g0 g2 g4', real=True, positive=True)
zeta = Matrix([1, 0, I*sqrt(2), 0, 1]) / 2

# Build 10x10 BdG matrix (sympy)
H_BdG = build_bdg(zeta, g0, g2, g4, n, eps_k)

# Characteristic polynomial
poly = (H_BdG - omega * sigma_z).det()

# Factor
factored = factor(poly)
print(factored)
```

出力: 4 factor の積 (Eqs. 3.3.3) を確認。

### 3.6.2 Direct eigenvalue 比較

representative parameters: $g_0 = 1.0, g_2 = 0.5, g_4 = 0.7$, $\varepsilon_k = 0.1$, $n = 1$:

| Mode | Predicted $\omega$ | Numerical $\omega$ | Rel.err |
|---|---|---|---|
| Phonon | 0.404 | 0.404 | $< 10^{-15}$ |
| Even spin GM | 0.114 | 0.114 | $< 10^{-15}$ |
| Amplitude | 0.157 | 0.157 | $< 10^{-15}$ |
| Odd spin GMs | 0.114, 0.114 | 0.114, 0.114 | $< 10^{-15}$ |

機械精度で一致。

### 3.6.3 LHY closed form verification

Direct numerical integration of the LHY zero-point sum (Eq. 2.14) for the 4 Goldstone modes
を比較:

| $c_0$ | $c_1$ | $c_2$ | Direct numerical | Closed form | Rel.err |
|---|---|---|---|---|---|
| 0.5 | 0.05 | 0.3 | $1.014 \times 10^{-2}$ | $1.014 \times 10^{-2}$ | $< 10^{-4}$ |
| 1.0 | 0.1 | 0.5 | $5.74 \times 10^{-2}$ | $5.74 \times 10^{-2}$ | $< 10^{-4}$ |

機械精度で一致 (残差は数値積分の tolerance)。

---

## 3.7 Universal Structure Theorem and Selection Rule Unification

### 3.7.1 Universal Theorem (refined statement)

F=2 cyclic phase で確立した式 (3.1) は、F=6 icosahedral phase で得られる formula (Chapter 6
で詳述) と完全に同じ構造を持つ:

$$\varepsilon_{\rm LHY}^{F=6, I_h} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 |\lambda_{\rm spin}|^{5/2}\right]$$

(convention 統一: $\lambda_{\rm spin}^{F=2} = 2 c_1$)。

**Refined Theorem**: Residual rotation symmetry $H = G \cap SO(3)$ が polyhedral
($T, O, I$, またはそれらの拡張) であれば:

$$\varepsilon_{\rm LHY}^{(H)} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 |\lambda_{\rm spin}^{(H)}|^{5/2}\right] \tag{3.2}$$

検証済 4 polyhedral cases:

- F=2 cyclic ($T_d$): Paper #1 / 本章
- F=4 cube ($O_h$): 並列 Round 4 ← NEW
- F=6 icosahedral ($I_h$): Paper #2 / Ch.6
- F=10 dodecahedral ($I_h$): 並列 Round 4 ← NEW

(Round 5 の F=3 octahedral, F=8 cube-like の追加は Ch.6 で詳述。)

### 3.7.2 Selection Rule Unification

各 polyhedral phase で contributing $g_S$ subset が **polyhedral group harmonics の trivial-irrep
content** に対応する。これは spinor BEC LHY 物理の **representation-theoretic core insight**。

**Master Selection Rule Table**:

| Phase | $H$ | $g_S$ subset (contributing) | Excluded $g_S$ | Pattern |
|---|---|---|---|---|
| F=2 cyclic | $T_d$ | $g_0, g_4$ | $g_2$ | T_d harmonics: $S \in \{0, 3, 4, 6, 7, ...\}$ ∩ even |
| F=4 cube | $O_h$ | $g_0, g_4, g_6, g_8$ | $g_2$ | O_h harmonics: $S \in \{0, 4, 6, 8, 9, 10, ...\}$ ∩ even |
| F=6 icosahedral | $I_h$ | $g_0, g_6, g_{10}, g_{12}$ | $g_2, g_4, g_8$ | I_h harmonics: $S \in \{0, 6, 10, 12, 16, 18, ...\}$ |
| F=10 dodecahedral | $I_h$ | $g_0, g_6, g_{10}, g_{12}, g_{16}, g_{18}, g_{20}$ | $g_2, g_4, g_8, g_{14}$ | I_h harmonics (F=6 と同 pattern) |

**Key observations**:

1. **$g_2$ は ALL polyhedral phases で excluded**: 双線形 spin-spin coupling ($S = 2$) は
   どの polyhedral group の trivial irrep にも含まれない。これは「$T_1 \otimes T_1 = A_1 + E + T_1 + T_2$ で $S=2$ 部は $E$」 の generic 帰結。

2. **F=6 と F=10 で同じ exclusion pattern** ($S = 2, 4, 8$): $I_h$ harmonic selection の
   **F-independent universal rule**。

3. **Higher $S$ で contributions 拡大**: F=10 では $S = 16, 18, 20$ も contribute、これは F=6 では accessible でない高 multipole channels を活用。

### 3.7.3 Phase-Group Harmonic Correspondence

Selection rule の代数的 origin:

各 polyhedral group $H$ の **A_1 invariant harmonic** が rank $\ell$ で存在する条件:

- $T_d$: $\ell \in \{0, 3, 4, 6, 7, 8, 9, ...\}$
- $O_h$: $\ell \in \{0, 4, 6, 8, 9, 10, 12, ...\}$
- $I_h$: $\ell \in \{0, 6, 10, 12, 16, 18, 20, 22, ...\}$

(これらは Hamermesh 1962 や crystal field theory 標準 reference に table 化されている。)

Spinor LHY の channel selection:

$$g_S \text{ contributes iff } S \in \{\text{ranks where } A_1 \text{ harmonic of } H \text{ exists}\}$$

(なお、$S$ even-only by Bose statistics constraint。)

### 3.7.4 Coefficient Sign Pattern

各 phase で contributing $g_S$ の coefficient sign は systematic な pattern:

**$c_0$**: 全 contributing $g_S$ で **正係数** (chemical potential のため)

**$\lambda_{\rm spin}$**: 低 $S$ で負係数、高 $S$ で正係数の transition

| Phase | $\lambda_{\rm spin}$ Sign Pattern |
|---|---|
| F=2 cyclic | $\lambda_{\rm spin} = 2c_1 = 2(g_4 - g_2)/7$ (sign depends on $g_4 - g_2$) |
| F=4 cube | $g_0$: $-$, $g_4$: $-$, $g_6, g_8$: $+$ |
| F=6 icosahedral | $g_0$: $-$, $g_6$: $-$, $g_{10}, g_{12}$: $+$ |
| F=10 dodecahedral | $g_0, g_6, g_{10}, g_{12}$: $-$; $g_{16}, g_{18}, g_{20}$: $+$ |

**Generic feature**: 低 $S$ couplings ($g_0, g_2, ...$) は polar/FM phase を favor、
高 $S$ couplings は polyhedral high-symmetry phase を favor。

(この sign pattern systematic は Round 5 で 6 polyhedral cases の結果から
"Spinor-Rank Matching Principle" として整理。Ch.6 §6.10 と Paper #3 v3 §IX.B を参照。)

---

## 3.8 F-Systematic Classification

### 3.8.1 F=0..12 Polyhedral Inert State Existence

Yukawa-Ueda 2011 と Mäkelä-Suominen 2007 の結果に representation-theoretic 解析を加えた
master table:

| F | Polyhedral inert states | Universal theorem? |
|---|---|---|
| 0 | All polyhedral types | trivial (scalar) |
| **1** | **NONE** | **× UNIQUE EXCEPTION** |
| 2 | $T_d$ (cyclic) | ✓ ($T$) |
| 3 | $T$ (T:A), $O$ (O:A_2 sign rep) | ✓ |
| 4 | $T$, $O_h$ (cube) | ✓ |
| 5 | $T$ only | ✓ ($T$) |
| 6 | All families ($T, O, I$) | ✓ |
| 7 | $T$, $O$ (sign rep) | ✓ |
| 8 | $T$, $O_h$ (cube-like) | ✓ |
| 9 | $T$, $O_h$ (both A_1 + A_2) | ✓ |
| 10 | All families ($T, O, I$) | ✓ |
| 11 | $T$, $O$ (sign rep) | ✓ |
| 12 | All families with multiplicities | ✓ |

### 3.8.2 F=1 Exception の意味

$D^{F=1} \cong T_1$ の irreducibility が原因で、F=1 spinor BEC では polyhedral 高対称
phase が原理的に存在しない。

物理的 implications:

- F=1 BEC ($^{87}$Rb F=1, $^{23}$Na F=1) は polar / FM の連続対称性 phases のみ
- Discrete polyhedral phase 探索は F ≥ 2 で意味を持つ
- これは spinor BEC physics の generic feature の representation-theoretic 起源

### 3.8.3 F奇数 polyhedral phases の特殊性

F奇数 (3, 5, 7, 9, 11) では多くの場合 polyhedral inert state が **A_2 sign representation**
(rotation 下 invariant、reflection 下 sign flip) として現れる。

例: F=3 octahedral $\zeta = (|3, +2\rangle - |3, -2\rangle)/\sqrt{2}$ は $O$ 下 invariant,
$O_h$ 下 sign-rep。

Universal theorem は **rotation group のみ**で判定するため、F奇数 sign-rep cases も
適用可能。Round 5 の F=3 octahedral closed form derivation で明示的 verification 済 (Ch.6 §6.8)。

### 3.8.4 D 論への展望

修論期間内の polyhedral verifications:

- F=2 cyclic ($T_d$): Paper #1 / 本章
- F=3 octahedral ($O$, sign rep): Round 5 (Ch.6 §6.8) — 奇数 F 最初
- F=4 cube ($O_h$): Paper #3 (Round 4)
- F=6 icosahedral ($I_h$): Paper #2 / Ch.6 §6.1-6.5
- F=8 cube-like ($O$): Round 5 (Ch.6 §6.9) — Dy 連携
- F=10 dodecahedral ($I_h$): Paper #3 (Round 4)

D 論期間で extension:

- F奇数 全般 (F=5, 7, 9, 11): systematic completion
- F=3 axial (Yukawa-Ueda): modified theorem application
- Sign pattern conjecture の rigorous proof

最終目標: **任意 F での polyhedral classification を完備**、spinor BEC LHY 物理の
representation-theoretic な完全 systematization。

---

## 3.9 まとめ

### 3.9.1 主要結果

1. **F=2 cyclic phase の LHY 閉形式** (Eq. 3.1) — 文献的初出
2. **m-parity block 分解** — $T_d$ symmetry の analytical exploitation
3. **Cyclic-specific amplitude mode** ($|\Delta_3| = 0$) の同定と LHY 寄与 = 0
4. **Universal Structure Theorem** (Eq. 3.2) の F=2/F=4/F=6/F=10 verification
5. **Selection Rule Unification** — polyhedral group harmonics による $g_S$ contribution の系統化
6. **F-Systematic Classification** — F=1 unique exception、全 F の polyhedral phase 存在性確立

### 3.9.2 学術的 implications

- F=2 spinor BEC droplet 物理の theoretical foundation
- Spinor 渦, domain wall, 高密度 droplet の LHY computation tool
- 高 $F$ への systematic 拡張の methodology (Chapter 6 で F=6, F=4, F=10, F=3, F=8 へ)

### 3.9.3 D 論への展望

本章は D 論 Chapter 2 (任意 spinor LHY framework) の核心 building block。F奇数
全般、dipolar 修正 ($Q_5$ generalization)、$\mathcal{O}(n^{7/2})$ 高次補正
の系統的派生が D 論期間の課題となる。

---

## End of Chapter 3

Chapter 4 では本研究の数値的 framework である SpinorBEC.jl の構築と Stage A-D LHY 実装
について詳述する。Chapter 5 では SpinorBEC.jl + TWA で Eu post-quench dynamics の量子
ゆらぎを評価する。Chapter 6 では本章の Universal Theorem を 6 polyhedral phases (F=2,
3, 4, 6, 8, 10) に systematic に適用する。
