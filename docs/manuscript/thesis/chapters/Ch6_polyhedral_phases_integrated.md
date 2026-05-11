# 修論 Chapter 6: Polyhedral Spinor Phases — 6 多角体 Universal Theorem 検証 (Round 6 final)

**Round-6 update**: §6.1-6.5 inlined from `master_thesis_Ch6_icosahedral.md` v1.
v2 §6.6 onwards (F=4 cube, F=10 dodec, F=3 octa NEW, F=8 octa NEW, sign pattern,
master summary) preserved as authoritative.

> **Remaining TODO before final submission**:
> - §6.6 (F=4 cube) and §6.7 (F=10 dodec) currently carry the v1-update
>   abbreviated summaries; the full closed-form derivations + Majorana
>   polynomial steps + sanity checks could be inlined for completeness, but
>   the closed-form expressions and selection rules are already stated.

---

## 6.1 Introduction

Chapter 3 で確立した F=2 cyclic phase の解析手法 (m-parity による block 分解 +
Bogoliubov 形式と非 Bogoliubov amplitude mode の組合せ) を、F=6 spinor BEC の
高対称 phase に拡張する。

具体的には Yukawa-Ueda (2011) と Mäkelä-Suominen (2007) で提案された **Icosahedral
$I_h$ phase** に焦点を当てる。$I_h$ phase は spin-6 系で実現可能な最も対称性の高い
uniform spinor 状態 (12 Majorana 点が icosahedron 頂点) で、F=2 cyclic phase ($T_d$
対称) の自然な拡張に位置付けられる。

本章で確立する主要結果は:

1. **C_5 symmetry による mod 5 block 分解**: 26×26 Nambu BdG が 5 つの independent
   block (sizes $6+6+6+4+4$) に decomposed
2. **4 つの Goldstone mode の同定**: 1 phonon + 3 spin Goldstones ($T_1$ irreducibly
   degenerate)
3. **F=6 I_h LHY closed form**:
   $$\varepsilon_{\rm LHY}^{F=6, I_h} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 |\lambda_{\rm spin}|^{5/2}\right]$$
   with explicit $c_0(g_S)$ and $\lambda_{\rm spin}(g_S)$
4. **Universal structure theorem (conjecture)**: discrete-rotation-symmetric phases
   全てに同形式が成立 (本章 §6.7 — v1 の §6.7 は Round 5 で Paper #3 main.md に
   昇格されたため、本章では §6.7 は v2 の F=10 dodec に rename された)

これは Chapter 3 (F=2 cyclic warmup) で確立した手法を、Chapter 4 (Universal Structure
Theorem) で代数化した universal framework を、6 polyhedral instances に explicit に
適用する流れで、Chapter 4 → Chapter 6 が "framework → verification" の自然な統合を成す。
D 論 Chapter 2 (F=5, 7, 9, 11 等の systematic completion) への橋渡しでもある。

---

## 6.2 F=6 Icosahedral Ground State Spinor

### 6.2.1 Majorana 表現と Icosahedron

スピン-F の状態 $|\zeta\rangle = \sum_m \zeta_m |F, m\rangle$ は Majorana の星表現
で 2F 個の Bloch 球面上の点 (Majorana points) で表される [Majorana 1932]。

F=6 では 12 個の Majorana 点を持ち、これらが正多面体の頂点に配置される場合、対応する
$\zeta$ は当該対称性の inert state (高対称 ground state 候補) となる [Mäkelä-Suominen
2007, Yukawa-Ueda 2011]。

12 = 12 (icosahedron 頂点) の場合に得られる **Icosahedral $I_h$ phase** が、F=6 で
realize できる最高対称性 phase である。

### 6.2.2 $\zeta^{(I_h)}$ Explicit Form

正二十面体配置の 12 Majorana 点から計算される spinor は [Mäkelä-Suominen 2007]:

$$\boxed{\zeta^{(I_h)}_{F=6} = \frac{1}{5}\left(\sqrt{7}\,|6,+5\rangle + \sqrt{11}\,|6,0\rangle - \sqrt{7}\,|6,-5\rangle\right)} \tag{6.1}$$

### 6.2.3 物性

直接計算 (Appendix C) により:

- **正規化**: $|\zeta|^2 = 7/25 + 11/25 + 7/25 = 25/25 = 1$ ✓
- **磁化**: $\langle F_x \rangle = \langle F_y \rangle = \langle F_z \rangle = 0$ ✓
- **C_5 不変**: $C_5^z |\zeta\rangle = |\zeta\rangle$ where $C_5^z = e^{i 2\pi F_z/5}$
  (機械精度確認)
- **Sparsity**: $\zeta_m \neq 0$ only for $m \in \{+5, 0, -5\}$ (= multiples of 5)
- **Reflection symmetry**: $\zeta_{-5} = -\zeta_{+5}$ (anti-symmetric, distinct from F=2
  cyclic where $\zeta_{-2} = +\zeta_{+2}$)

### 6.2.4 Symmetry breaking pattern

$\zeta^{(I_h)}$ は global $U(1) \times SO(3)$ 対称性を $I_h$ (= 60-element discrete
subgroup of $SO(3)$, 120-element with reflections) に break する。Goldstone counting:

- 1 broken U(1) generator → **1 phonon** (density Goldstone)
- 3 broken $SO(3)$ generators → **3 spin Goldstones** ($T_1$ irreducible representation)

合計 **4 Goldstones** 期待値。これは F=2 cyclic phase ($T_d$) と同じ count で、
"discrete-rotation-symmetric phase" の universal feature として理解できる。

---

## 6.3 BdG Matrix の構築

### 6.3.1 Hartree-Fock matrix h と anomalous matrix M

Chapter 2 で記述した generic spinor BdG framework を $\zeta^{(I_h)}$ に適用:

$$h_{m m'} = \sum_{S=0,2,4,6,8,10,12} g_S \cdot \mathcal{X}^{(S)}_{m m'}[\zeta]$$

$$M_{m m'} = \sum_S g_S \cdot \mathcal{Y}^{(S)}_{m m'}[\zeta]$$

with appropriate Clebsch-Gordan factors $\mathcal{X}, \mathcal{Y}$ involving $\zeta_\mu^* \zeta_\nu$
and $\zeta_\mu \zeta_\nu$ products.

直接 sympy 計算 (Appendix B) により全 169 (= 13²) 要素を取得。要点:

- $h$ matrix: 13 個の対角要素 + 多数の off-diagonal
- $M$ matrix: より sparse (anomalous の組合わせ条件による)
- $\mu = \langle\zeta|h|\zeta\rangle$ の閉形式 (chemical potential)

### 6.3.2 C_5 Symmetry Selection Rules

$\zeta^{(I_h)}$ の sparsity ($\zeta_m \neq 0$ only for $m \equiv 0 \pmod 5$) と Clebsch-
Gordan 結合則の組合わせにより、以下の選択則が出る:

**Rule 1 ($h$ matrix)**:
$$h_{m m'} \neq 0 \quad \Leftrightarrow \quad m \equiv m' \pmod 5 \tag{6.2}$$

**Rule 2 ($M$ matrix)**:
$$M_{m m'} \neq 0 \quad \Leftrightarrow \quad m + m' \equiv 0 \pmod 5 \tag{6.3}$$

これらの選択則は $C_5$ 軸方向 ($\hat{z}$) の角運動量保存則の現れ。$\zeta^{(I_h)}$ が
$C_5^z$ の固有状態であるため、interaction matrix elements は $m \pmod 5$ に従って
grade される。

---

## 6.4 Mod 5 Block Decomposition

### 6.4.1 13 次元 spinor space の class 分解

m mod 5 で class 分け:

| Class $\alpha$ | $m$ values | 次元 |
|---|---|---|
| 0 | $\{-5, 0, +5\}$ | 3 |
| 1 | $\{-4, +1, +6\}$ | 3 |
| 2 | $\{-3, +2\}$ | 2 |
| 3 | $\{-2, +3\}$ | 2 |
| 4 | $\{-6, -1, +4\}$ | 3 |

合計: $3+3+2+2+3 = 13$ ✓ (= 2F+1)

### 6.4.2 26×26 Nambu BdG の block 構造

Selection rules (6.2)-(6.3) と Nambu structure を組合わせると、$26 \times 26$ BdG が
**5 つの independent block** に decomposed:

| BdG block | Particle class | Hole class | Nambu dim | 内容 |
|---|---|---|---|---|
| $\mathcal{B}_0$ | 0 | 0 | 6 | self-coupled, **Goldstones 集中** |
| $\mathcal{B}_{1,4}$ | 1 | 4 | 6 | particle class 1, hole class 4 |
| $\mathcal{B}_{4,1}$ | 4 | 1 | 6 | particle-hole conjugate of $\mathcal{B}_{1,4}$ |
| $\mathcal{B}_{2,3}$ | 2 | 3 | 4 | gapped modes |
| $\mathcal{B}_{3,2}$ | 3 | 2 | 4 | particle-hole conjugate of $\mathcal{B}_{2,3}$ |

合計: $6+6+6+4+4 = 26 = 2(2F+1)$ ✓

By particle-hole conjugation, $\mathcal{B}_{1,4}$ と $\mathcal{B}_{4,1}$ は同一 spectrum、
$\mathcal{B}_{2,3}$ と $\mathcal{B}_{3,2}$ も同一 spectrum。物理的 mode 数:

- $\mathcal{B}_0$: 3 unique modes
- $\mathcal{B}_{1,4} \cong \mathcal{B}_{4,1}$: 3 unique modes (各 2-fold degenerate)
- $\mathcal{B}_{2,3} \cong \mathcal{B}_{3,2}$: 2 unique modes (各 2-fold degenerate)

合計 unique modes: $3 + 3 + 2 = 8$、multiplicities 込み $3 + 6 + 4 = 13$ (= 2F+1) ✓

### 6.4.3 ζ 非ゼロ成分との対応

$\zeta^{(I_h)}$ の非ゼロ成分 ($m = -5, 0, +5$) は class 0 に完全に閉じる。これは
**$\mathcal{B}_0$ に Goldstone modes が集中する**ことを意味し、Goldstone 計算の
ほとんどの仕事が 6×6 BdG (= F=2 cyclic Even block と同サイズ) で完結することを
示す。

---

## 6.5 Mode Spectrum

### 6.5.1 Block $\mathcal{B}_0$ の closed form

$\mathcal{B}_0$ (6×6) は orthonormal 基底変換により **3 つの decoupled 2×2 blocks**
に factor される (本研究で Schur lemma を用いた直接対角化により証明):

$$\mathcal{M}_{\mathcal{B}_0} = \mathcal{M}_{\rm phonon}^{(2\times 2)} \oplus \mathcal{M}_{\rm spin\,GM}^{(2\times 2)} \oplus \mathcal{M}_{\rm amplitude}^{(2\times 2)}$$

各 sub-block は standard Bogoliubov 形式:

**Mode 1 (phonon)**: 基底 $v_0 = \zeta$:
$$\boxed{\omega_1^2(\mathbf{k}) = \varepsilon_k(\varepsilon_k + 2 n c_0)} \tag{6.4}$$

with stiffness:
$$\boxed{c_0 = \frac{1}{13}g_0 + \frac{121}{323}g_6 + \frac{147}{391}g_{10} + \frac{980}{5681}g_{12}} \tag{6.5}$$

**Mode 2 ($F_z$ spin Goldstone)**: 基底 $v_1 = (|+5\rangle + |-5\rangle)/\sqrt{2}$:
$$\boxed{\omega_2^2(\mathbf{k}) = \varepsilon_k(\varepsilon_k + 2 n \lambda_{\rm spin})} \tag{6.6}$$

with stiffness:
$$\boxed{\lambda_{\rm spin} = -\frac{1}{13}g_0 - \frac{121}{646}g_6 + \frac{91}{782}g_{10} + \frac{840}{5681}g_{12}} \tag{6.7}$$

**Mode 3 (amplitude)**: 基底 $v_2 = (\sqrt{11}|+5\rangle - 2\sqrt{7}|0\rangle - \sqrt{11}|-5\rangle)/(5\sqrt{2})$:
$$\omega_3^2(\mathbf{k}) = (\varepsilon_k + n \xi_{\rm amp})^2 - (n \Delta_{\rm amp})^2 \tag{6.8}$$

with $\xi_{\rm amp}, \Delta_{\rm amp}$ explicit linear combinations of $g_S$. Mode 3 は通常の
gapped Bogoliubov mode で、scalar limit で $\xi_{\rm amp} = \Delta_{\rm amp} = 0$ (free particle dispersion).

### 6.5.2 Block $\mathcal{B}_{1,4}$ (numerical)

数値対角化により 3 unique modes (各 2-fold degenerate by particle-hole conjugacy):

- 1 spin Goldstone ($F_\pm$, $T_1$ component, stiffness = $\lambda_{\rm spin}$ by isotropy)
- 2 gapped modes (cyclic-like amplitude)

### 6.5.3 Block $\mathcal{B}_{2,3}$ (numerical)

2 unique modes (各 2-fold degenerate), 全て gapped (no Goldstone in $\mathcal{B}_{2,3}$).

### 6.5.4 Goldstone Counting 検証

| Mode | Block | Multiplicity | Type |
|---|---|---|---|
| Phonon | $\mathcal{B}_0$ | 1 | U(1) Goldstone |
| $F_z$ spin GM | $\mathcal{B}_0$ | 1 | $T_1$, $m_z = 0$ |
| $F_\pm$ spin GMs | $\mathcal{B}_{1,4}$ | 2 | $T_1$, $m_z = \pm 1$ |

合計 **4 Goldstones** ✓ ($U(1) \times SO(3) \to I_h$ で 1 + 3 = 4 broken generators)

3 spin Goldstones は $T_1$ representation of $I_h$ irreducibility で **degenerate**。
Stiffness は全方向で同値 ($F_x, F_y, F_z$ → $\lambda_{\rm spin}$), $I_h$ isotropy の
直接表現。

### 6.5.5 LHY Closed Form for F=6 I_h

Universal LHY formula を 4 Goldstones に適用 (gapped/amplitude modes は $|\Delta|=0$
or sub-leading で寄与なし):

$$\boxed{\varepsilon_{\rm LHY}^{F=6, I_h} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 |\lambda_{\rm spin}|^{5/2}\right]} \tag{6.9}$$

with $c_0$ and $\lambda_{\rm spin}$ given by Eqs. (6.5), (6.7). この closed form は
SpinorBEC.jl の `compute_spinor_lhy_icosahedral` (Round 3 Task 1) として実装済。

**Selection rule**: $g_2, g_4, g_8$ contribute exactly zero — icosahedral harmonic
selection: $A_g$ exists only in $S = 0, 6, 10, 12$ subspaces of the symmetric tensor
product. 詳細は §6.10 (sign pattern systematic) で multi-phase 比較。

**Scalar limit**: $g_S \equiv g$ で $c_0 = g, \lambda_{\rm spin} = 0$ exactly (sympy
identity)。Spinor → scalar reduction の整合性確認。

**Eu reference**: $g_S = (1.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99)$ で
$c_0 = 1.0095, \lambda_{\rm spin} = -0.00406$ (並列セッション + 本研究 sympy 確認、
machine precision)。

---

## 6.6 F=4 Cube Phase ($O_h$) — 3rd Polyhedral Verification

(前 Ch6 update v1 内容)

Spinor: $\zeta^{(\rm cube)}_{F=4} = \sqrt{5/24}|+4\rangle + \sqrt{7/12}|0\rangle + \sqrt{5/24}|-4\rangle$

Closed forms:

$$c_0^{F=4, \rm cube} = \tfrac{1}{9}g_0 + \tfrac{98}{429}g_4 + \tfrac{40}{99}g_6 + \tfrac{10}{39}g_8$$

$$\lambda_{\rm spin}^{F=4, \rm cube} = -\tfrac{1}{9}g_0 - \tfrac{49}{429}g_4 + \tfrac{2}{99}g_6 + \tfrac{8}{39}g_8$$

Selection rule: $g_2$ excluded ($O_h$ harmonics).

---

## 6.7 F=10 Dodecahedral Phase ($I_h$) — F-Universality Demonstration

(前 Ch6 update v1 内容)

Spinor: $\zeta^{(\rm dodec)}_{F=10} = \frac{\sqrt{561}}{75}|\pm 10\rangle + \frac{\sqrt{209}}{25}(|+5\rangle - |-5\rangle) + \frac{\sqrt{741}}{75}|0\rangle$

7-term closed forms (g_2, g_4, g_8, g_{14} excluded by I_h harmonics).

---

## 6.8 F=3 Octahedral Phase ($O$, A_2 sign rep) — **NEW: 奇数 F 最初の Verification**

### 6.8.1 動機

Universal Structure Theorem の **奇数 F での verification** が theoretical completeness の
ため必須。F=3 octahedral phase は $^{52}$Cr spinor BEC で実現可能性ある phase で、
本研究で文献初出の closed form 派生。

### 6.8.2 Spinor 構築

F=3 で octahedron Majorana configuration ($\pm \hat{x}, \pm \hat{y}, \pm \hat{z}$ 6 vertices, $2F = 6$):

Majorana polynomial $P(u) = u^5 - u$ (本セッションで派生) →

$$\boxed{\zeta^{(\rm octa)}_{F=3} = \frac{1}{\sqrt{2}}(|3, +2\rangle - |3, -2\rangle)}$$

### 6.8.3 群論的特性

- $H = O$ (octahedral rotation, $|O| = 24$)
- $D^{F=3} | O$: $A_1$ multiplicity 0, **$A_2$ multiplicity 1** (sign-under-reflection)
- $T_1 |_O = T_1$ (3-dim irreducible) ⇒ Universal Theorem 適用 ✓
- F奇数 polyhedral phase は典型的に $A_2$ sign rep (理論的: §6.10 参照)

### 6.8.4 Closed forms (Round 5 並列セッション)

$$\boxed{c_0^{F=3, \rm octa} = \tfrac{1}{7}g_0 + \tfrac{6}{11}g_4 + \tfrac{24}{77}g_6}$$

$$\boxed{\lambda_{\rm spin}^{F=3, \rm octa} = -\tfrac{1}{7}g_0 - \tfrac{1}{11}g_4 + \tfrac{18}{77}g_6}$$

**Selection rule**: $g_2$ 係数 = 0 ($O$ harmonics, $S=2$ subspace に $A_1$ 不在; F=4 cube
と同 pattern)。

### 6.8.5 Sanity checks (全 PASS)

- $g_2 = 0$ ✓
- Scalar limit: 係数和 = 1 ($c_0$), 0 ($\lambda$) ✓
- Schur isotropy: $\lambda_x = \lambda_y = \lambda_z$ exactly
- $\langle F^2 \rangle = 12 = F(F+1)$ ✓
- BdG 7-mode 直接対角化: 1 phonon + 3 spin GMs (degenerate) + 3 amplitude gapped ✓

### 6.8.6 物理的意義

- F=3 = $^{52}$Cr 自然 Bose isotope hyperfine spin
- 文献初の F=3 octahedral phase LHY closed form
- **Cr droplet 物理への extension** 可能性
- Yukawa-Ueda 2011 の F=3 phase landscape (polar, FM, FL, H phase) に octahedral phase
  を新規 component として加える

---

## 6.9 F=8 Cube-like Octahedral Phase ($O$, A_1) — **NEW: Dy 拡張**

### 6.9.1 動機

F=8 = $^{164}$Dy 自然 Bose isotope hyperfine spin。Stuttgart, Innsbruck で世界的 dipolar
BEC 研究の主役 species。F=8 polyhedral phase の存在性は character analysis で本研究で
確認 (D^{F=8} | O で $A_1$ multiplicity = 1)。

### 6.9.2 Spinor 構築

並列セッション Round 5 で $Y_8^m$ projection on 6 octahedron vertices より:

$$\boxed{\zeta^{(F=8, \rm octa)} = \frac{\sqrt{390}}{48}|\pm 8\rangle + \frac{\sqrt{42}}{24}|\pm 4\rangle + \frac{\sqrt{33}}{8}|0\rangle}$$

(全 coefficients positive ⇒ parity even, $A_1$ irrep of $O$.)

### 6.9.3 群論的特性

- $H = O$ ($O_h$ to true invariance, $A_1$ multiplicity 1 confirmed)
- $T_1 |_O = T_1$ irreducible ⇒ Universal Theorem 適用 ✓
- 16 Majorana points in cube-like high-symmetry configuration

### 6.9.4 Closed forms (Round 5 並列セッション)

$$c_0^{F=8, \rm octa} = \tfrac{1}{17}g_0 + \tfrac{1372}{12597}g_4 + \tfrac{64}{22287}g_6 + \tfrac{330}{5681}g_8 + \tfrac{40768}{200583}g_{10} + \tfrac{1651420}{5816907}g_{12} + \tfrac{37856}{365769}g_{14} + \tfrac{1714570}{9490743}g_{16}$$

$$\lambda_{\rm spin}^{F=8, \rm octa} = -\tfrac{1}{17}g_0 - \tfrac{10633}{113373}g_4 - \tfrac{8}{3933}g_6 - \tfrac{165}{5681}g_8 - \tfrac{5096}{106191}g_{10} + \tfrac{412855}{17450721}g_{12} + \tfrac{52052}{1097307}g_{14} + \tfrac{13716560}{85416687}g_{16}$$

**Selection rule**: $g_2$ 係数 = 0 only excluded.

### 6.9.5 Sanity checks (全 PASS)

- $g_2 = 0$ unique exclusion ✓
- Scalar limit ✓
- Schur isotropy (17×17 symbolic verification) ✓
- $\langle F^2 \rangle = 72 = F(F+1)$ ✓
- BdG 直接対角化: 1 phonon + 3 spin GMs degenerate ✓

### 6.9.6 物理的意義

- $^{164}$Dy = leading dipolar BEC species (Schmitt 2016 droplet seminal)
- F=8 polyhedral phase で **Dy spinor droplet 物理への extension**
- Stuttgart / Innsbruck 実験との接続可能性
- $a_S$ measurement program (Innsbruck) との直接 collaboration target

---

## 6.10 Sign Pattern — Lemma 1 General-S Closed Form (Updated 2026-05-11)

### 6.10.1 観察 + 定理化

5 polyhedral verifications + 6 F-systematic predictions (F=7/9/11) で、systematic
な sign pattern が **closed form** に集約される結果:

$$\boxed{\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2 F(F+1)} \cdot \beta_S^{(c_0)}}$$

(`paper3_universal_theorem/sign_pattern_lemma1_general_S.md`, exact rational
arithmetic 26 channel coefficients verified at F=3/4/6/8/10.)

**修正済 sign 境界**: $S_{\rm bd}(F) = \sqrt{2 F(F+1)} \approx \sqrt{2}\,F \approx 1.41\,F$
(NOT $2F$ as v1 empirical estimate)。

| F | Phase | $H$ | $S_{\rm bd}$ (closed form) | $S_{\rm bd}/F$ | Discrete boundary |
|---|---|---|---|---|---|
| 3 | octa ($A_2$) | $O$ | $\sqrt{24} \approx 4.90$ | 1.63 | $(4, 6)$ |
| 4 | cube ($A_1$) | $O_h$ | $\sqrt{40} \approx 6.32$ | 1.58 | $S=6$ first pos |
| 6 | icosahedral | $I_h$ | $\sqrt{84} \approx 9.17$ | 1.53 | $S=10$ first pos |
| 7 | T:A / O:A_2 | $T, O$ | $\sqrt{112} \approx 10.58$ | 1.51 | $(10, 12)$ |
| 8 | octa ($A_1$) | $O$ | $\sqrt{144} = 12$ exact | 1.50 | $S = 12$ exactly |
| 9 | O:A_1 / O:A_2 | $O$ | $\sqrt{180} \approx 13.42$ | 1.49 | $(12, 14)$ |
| 10 | dodecahedral | $I_h$ | $\sqrt{220} \approx 14.83$ | 1.48 | $(14, 16)$ |
| 11 | T:A / O:A_2 | $T, O$ | $\sqrt{264} \approx 16.25$ | 1.48 | $(14, 16)$ |
| 12 | (I:A) | $I$ | $\sqrt{312} \approx 17.66$ | 1.47 | $(16, 18)$ |

漸近的: $S_{\rm bd}/F \to \sqrt{2} \approx 1.414$。

### 6.10.2 物理的解釈 (REVISED: spin-spin correlation)

Lemma 1 General-S の比は spin-spin correlation の表現:

$$\frac{\beta_S^{(\lambda_{\rm spin})}}{\beta_S^{(c_0)}} = \frac{\langle\mathbf{F}^{(1)}\cdot\mathbf{F}^{(2)}\rangle_{|S, M\rangle}}{F(F+1)}$$

= channel $S$ における 2 体 spin-spin 相関 / 単一 spin の最大値。

$S$ singlet ($S=0$): $\langle\mathbf{F}^{(1)}\cdot\mathbf{F}^{(2)}\rangle = -F(F+1)$ ⇒ 比 $= -1$ (反平行)
$S = 2F$ (max parallel): $\langle\mathbf{F}^{(1)}\cdot\mathbf{F}^{(2)}\rangle = F^2$ ⇒ 比 $= F/(F+1)$ (平行)

これは Spinor-Rank Matching Principle の **rigorous 化**。「sharp angular features
が resonate」という直感的解釈は、**spin-spin pair correlation の符号** という代数的
量で正確に表せる。

### 6.10.3 Predictive Recipe (REVISED)

実験的 polyhedral phase realization recipe (Lemma 1 General-S に基づき修正):

> **「$S > \sqrt{2 F(F+1)} \approx \sqrt{2}\,F$ の Feshbach resonances を targeting
> すれば polyhedral phase の $\lambda_{\rm spin}$ を maximize できる」**

各 species (REVISED):

- $^{52}$Cr (F=3): $S_{\rm bd} \approx 4.90$; target $g_6$ Feshbach (= first allowed positive)
- $^{151}$Eu (F=6): $S_{\rm bd} \approx 9.17$; target $g_{10}, g_{12}$ Feshbach
- $^{164}$Dy (F=8): $S_{\rm bd} = 12.0$ exact (marginal); target $g_{12}$ (marginal +)
  and $g_{14}, g_{16}$ (strong +) Feshbach

### 6.10.4 D 論への展望 (UPDATED 2026-05-11)

Sign pattern conjecture は **D 論 Q2 で Theorem 昇格済** (Lemma 1 General-S
closed form + L2 unique sign change PROVED):

- ~~F=5, 7, 9, 11, 12 等の systematic completion~~ → Lemma 1 General-S で
  closed form 予測のみで済む (Q3 paper #6)。
- ~~法則の rigorous proof~~ → S=0 case rigorously proved; general $S$ rank-2
  cross-channel vanishing は唯一の残された analytic gap (6j-symbol identity)。

主要 D 論 contribution:
1. **Lemma 1 General-S Theorem**: paper #3 v4 で submission-ready
2. **F=5/7/9/11/12 mechanical completion**: paper #6 systematic completion
3. **Rank-2 cross-channel vanishing rigorous proof**: D 論 Year 1 Q2 target
4. **Dipolar generalization ($Q_5$)**: Lima-Pelster correction to closed form

---

## 6.11 Master Verification Summary (6 polyhedral + 1 axial)

| # | F | Phase | Residual rot. | F-parity | Round | Notes |
|---|---|---|---|---|---|---|
| 1 | 2 | cyclic | $T$ | even | Paper #1 | $T_d$ family の F=2 instance |
| **2** | **3** | **octa ($A_2$)** | **$O$** | **ODD** | **R5-1** | **奇数 F 最初** |
| 3 | 4 | cube | $O$ | even | Round 4 | $O_h$ family |
| 4 | 6 | icosahedral | $I$ | even | Paper #2 | $I_h$ family の F=6 |
| **5** | **8** | **octa ($A_1$)** | **$O$** | **even** | **R5-2** | **Dy** |
| 6 | 10 | dodecahedral | $I$ | even | Round 4 | $I_h$ family の F=10, F-univ. demo |

Edge case (axial): F=2 BN ($D_4$) — modified theorem $c_0^{5/2} + |\lambda_z|^{5/2} + 2|\lambda_\perp|^{5/2}$.

→ **3 polyhedral families covered + F-parity (even AND odd) covered + Dy connection**

---

## 6.12 修論 / Paper Final Status

### 6.12.1 Submission ready papers

- **Paper #1** (F=2 cyclic LHY): PRA submission ready
- **Paper #2** (F=6 icosahedral LHY): PRA / PRR submission ready
- **Paper #3 v3** (Universal Theorem comprehensive): PRX submission ready ⭐
  - 6 polyhedral cases verified
  - 1 axial edge case verified
  - F-systematic classification F=0..12
  - Sign pattern systematic discovery
- Paper #4 (TWA Eu): GPU 結果待ち, PRR target

### 6.12.2 D 論への展望

修論で確立した Universal theorem framework を基盤として、D 論 Ch.2 で:

- **R5-3**: F=3 axial phases (Yukawa-Ueda 2011: FL, H phases) modified theorem
- **F=5, 7, 9, 11, 12 systematic completion**: 全 F polyhedral verification
- **Sign pattern conjecture proof**: representation theory + spectral analysis
- **Dipolar generalization**: $Q_5$ for spin Goldstones
- **TDHFB / Beliaev**: beyond-LHY corrections
- **上妻研実験 collaboration**: F=6 Eu polyhedral phase 実現

これで spinor BEC LHY 物理が **representation-theoretic に完全 systematized** された
research framework として確立する。
