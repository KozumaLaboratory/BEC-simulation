# EdH vs Flower:断熱性の Mermin–Ho 診断 — 理論ノート

¹⁵¹Eu スピノル BEC における Einstein–de-Haas (EdH) 状態と Flower 状態を,
Mermin–Ho 関係式の残差によって区別するための理論的基礎をまとめる. 結論を
並べるのではなく, 動機・定義・導出・結論・解釈の順に, 教科書が省略する
行間をすべて埋めることを目的とする.

対応する数値実装:
- 設定: `runs/eu151_edh_vs_flower/{edh_quench,flower_smooth}.yaml`
- 解析: `scripts/edh_vs_flower/mermin_ho_diagnostic.jl`
- 描画: `scripts/edh_vs_flower/plot_edh_vs_flower.py`

---

## 1. 動機:なぜ断熱性を問うのか

¹⁵¹Eu (F=6, 磁気モーメント μ ≈ 6.98 μ_B) のスピノル凝縮体において, 強磁場で
m=+F に偏極させた基底状態から磁場を弱めていくと, 系は二通りの終状態を取りうる.

磁場 B(t) をゆっくり下げると, 局所スピン ⟨**F**⟩ は各時刻の磁場方向に追従する.
すなわち系は断熱的に各瞬間の基底状態をたどり, 双極子相互作用 (MDDI) が作る
なめらかなスピンテクスチャ (Flower 状態) に落ち着く. このとき軌道角運動量への
移行はほとんど起こらない.

一方, 磁場を急激に下げる (quench) と, スピンは磁場変化に追従できない. スピン
角運動量 ⟨F_z⟩ の一部が, 全角運動量保存を満たすために軌道角運動量 ⟨L_z⟩ へ
コヒーレントに移行する. これが Einstein–de-Haas 効果であり, その帰結として
非断熱的な渦 (vortex) が核形成される.

したがって EdH と Flower を分ける物理軸は, ただ一つ — **磁場降下の断熱性
(dB/dt)** である. 本研究の設計はこの軸だけを純粋に取り出す. 二つの計算は
同一の 10 mG 基底状態から出発し, 同一の終端磁場 26 µG に到達し, 弱磁場保持の
条件も同一にする. 違うのは降下にかける時間だけ (quench: 0.2 ms, smooth: 14.5 ms)
であり, 三体損失 K_3 はゼロに固定して損失が非断熱信号に混ざらないようにする.

問題は「断熱に追従できたか否か」を, 定量的・局所的に判定する観測量をどう
構成するか, である. その答えが Mermin–Ho 関係式の残差である.

---

## 2. 定義:スピンコヒーレント状態と超流動速度

### 2.1 スピンコヒーレント状態

スピン F の系で, 単位ベクトル $\hat{\mathbf{s}} = (\sin\theta\cos\varphi,\,
\sin\theta\sin\varphi,\,\cos\theta)$ の方向に最大限偏極した状態を
スピンコヒーレント状態と呼び,

$$
|\hat{\mathbf{s}}\rangle = R(\varphi,\theta)\,|F, m=F\rangle,
\qquad
R(\varphi,\theta) = e^{-i\varphi F_z}\,e^{-i\theta F_y}
$$

と書く. ここで $|F,F\rangle$ は z 軸方向に伸びた (stretched) 状態である.
この状態は $\hat{\mathbf{s}}\cdot\mathbf{F}$ の最大固有値 $F$ をもつ固有状態であり,
$\langle\hat{\mathbf{s}}|\mathbf{F}|\hat{\mathbf{s}}\rangle = F\hat{\mathbf{s}}$ を満たす.

本実験の初期状態 (10 mG で m=+F に偏極) はまさにこのコヒーレント多様体上に
あり, 磁場降下の間も — 少なくとも断熱的に進む限り — この多様体上に留まる
ことが期待される. 後述するように, この「コヒーレント多様体に留まる」という
仮定こそが Mermin–Ho 関係式の成立条件である.

### 2.2 凝縮体波動関数の単一モード仮定

局所的にスピンコヒーレント状態であると仮定すると, 凝縮体の波動関数は

$$
\psi(\mathbf{r}) = \sqrt{n(\mathbf{r})}\; e^{i\chi(\mathbf{r})}\;
|\hat{\mathbf{s}}(\mathbf{r})\rangle
$$

と分解できる. $n(\mathbf{r})$ は全粒子数密度, $\chi(\mathbf{r})$ は全体位相,
$\hat{\mathbf{s}}(\mathbf{r})$ は局所スピン方向である. スピン成分 $\psi_c$
($c=1,\dots,2F+1$, $c=1\leftrightarrow m=F$) はこの分解の成分展開で与えられる.

### 2.3 質量流と超流動速度

質量流密度 (確率流) は

$$
\mathbf{j} = \frac{\hbar}{M}\,\mathrm{Im}\!\left[\psi^\dagger \nabla\psi\right]
= \frac{\hbar}{M}\sum_{c}\mathrm{Im}\!\left[\psi_c^{*}\nabla\psi_c\right]
$$

で定義される (`src/analysis/currents.jl::probability_current`, 内部単位 ℏ=M=1
では前因子は 1). 超流動速度は $\mathbf{v}_s = \mathbf{j}/n$
(`superfluid_velocity`, 密度カットオフ付き) である.

---

## 3. 導出:Mermin–Ho 関係式

ここが本ノートの中心である. 「渦度 = スピンテクスチャの立体角密度」という
Mermin–Ho 関係式を, 行間を省かずに導く.

### 3.1 超流動速度のなかの Berry 接続

§2.2 の分解 $\psi = \sqrt{n}\,e^{i\chi}|\hat{\mathbf{s}}\rangle$ を質量流の式に
代入する. まず勾配を計算すると,

$$
\nabla\psi = \left[\tfrac{1}{2}\tfrac{\nabla n}{n} + i\nabla\chi\right]\psi
+ \sqrt{n}\,e^{i\chi}\,\nabla|\hat{\mathbf{s}}\rangle .
$$

これを $\psi^\dagger\nabla\psi = n\,e^{-i\chi}\langle\hat{\mathbf{s}}|\cdots$ に
代入する. $\langle\hat{\mathbf{s}}|\hat{\mathbf{s}}\rangle = 1$ より第一項は

$$
\psi^\dagger\psi\left[\tfrac{1}{2}\tfrac{\nabla n}{n} + i\nabla\chi\right]
= n\left[\tfrac{1}{2}\tfrac{\nabla n}{n} + i\nabla\chi\right]
$$

となる. このうち実数部 $\tfrac{1}{2}\nabla n$ は $\mathrm{Im}$ を取ると消える.
第二項は $n\,\langle\hat{\mathbf{s}}|\nabla\hat{\mathbf{s}}\rangle$ である.
したがって

$$
\mathrm{Im}\!\left[\psi^\dagger\nabla\psi\right]
= n\,\nabla\chi + n\,\mathrm{Im}\langle\hat{\mathbf{s}}|\nabla\hat{\mathbf{s}}\rangle .
$$

ここで **Berry 接続** を

$$
\mathbf{A} \equiv -\,\mathrm{Im}\langle\hat{\mathbf{s}}|\nabla\hat{\mathbf{s}}\rangle
$$

と定義すると (符号は慣例), 超流動速度は

$$
\boxed{\;\mathbf{v}_s = \frac{\hbar}{M}\bigl(\nabla\chi - \mathbf{A}\bigr)\;}
$$

と書ける. 全体位相の勾配 $\nabla\chi$ に加えて, スピン方向の空間変化が幾何学的な
位相 (Berry 接続) として超流動速度に寄与する. これが「スピンが動かす超流動流」
の起源である.

### 3.2 スピン-F コヒーレント状態の Berry 接続

$\mathbf{A}$ を $(\theta,\varphi)$ で具体的に評価する. $R = e^{-i\varphi F_z}
e^{-i\theta F_y}$ を用いると,

$$
\langle\hat{\mathbf{s}}|\nabla\hat{\mathbf{s}}\rangle
= \langle F,F|\,R^\dagger \nabla R\,|F,F\rangle .
$$

$\nabla R$ は $\nabla\theta$ と $\nabla\varphi$ の二項からなる. $\nabla\varphi$ の項を
取り出すと, $R^\dagger(\partial_\varphi R) = R^\dagger(-iF_z)R$ である. 
$e^{i\theta F_y}F_z e^{-i\theta F_y} = F_z\cos\theta - F_x\sin\theta$
(回転の随伴作用) を使い, さらに $e^{i\varphi F_z}$ 部分は $F_z$ と可換なので,

$$
R^\dagger(\partial_\varphi R) = -i\,(F_z\cos\theta - F_x\sin\theta).
$$

$|F,F\rangle$ での期待値は $\langle F_z\rangle = F$, $\langle F_x\rangle = 0$ だから,
$\langle F,F|R^\dagger\partial_\varphi R|F,F\rangle = -iF\cos\theta$. 同様に
$\nabla\theta$ の項は $R^\dagger(\partial_\theta R) = -iF_y$ を与え, その期待値は
$\langle F_y\rangle = 0$ でゼロになる. よって

$$
\langle\hat{\mathbf{s}}|\nabla\hat{\mathbf{s}}\rangle
= -i\,F\cos\theta\,\nabla\varphi,
$$

これは純虚数なので, Berry 接続は

$$
\mathbf{A} = -\,\mathrm{Im}\langle\hat{\mathbf{s}}|\nabla\hat{\mathbf{s}}\rangle
= F\cos\theta\,\nabla\varphi .
$$

定数ゲージ項を $\nabla\chi$ に吸収させて $\mathbf{A} = -F(1-\cos\theta)\nabla\varphi$
と書く流儀もあるが, 渦度 (回転) を取る次節では定数差は消えるので, ここでは
$\mathbf{A} = F\cos\theta\,\nabla\varphi$ のまま進める.

### 3.3 渦度 = 立体角密度

超流動速度の回転を取る. $\nabla\chi$ は (渦芯を除き) 渦なし $\nabla\times\nabla\chi=0$
だから,

$$
\nabla\times\mathbf{v}_s
= -\frac{\hbar}{M}\,\nabla\times\mathbf{A}
= -\frac{\hbar}{M}\,\nabla\times\!\bigl(F\cos\theta\,\nabla\varphi\bigr).
$$

積の回転公式 $\nabla\times(f\nabla g) = \nabla f\times\nabla g$ を
$f=F\cos\theta$, $g=\varphi$ に適用すると, $\nabla(F\cos\theta) =
-F\sin\theta\,\nabla\theta$ だから,

$$
\nabla\times\mathbf{v}_s
= -\frac{\hbar}{M}\,(-F\sin\theta\,\nabla\theta)\times\nabla\varphi
= \frac{\hbar F}{M}\,\sin\theta\,(\nabla\theta\times\nabla\varphi).
$$

最後に, 右辺がスピンテクスチャの立体角密度に等しいことを示す. 単位ベクトル
$\hat{\mathbf{s}}(\theta,\varphi)$ について,

$$
\partial_i\hat{\mathbf{s}} = \partial_i\theta\,\hat{\boldsymbol{\theta}}
+ \sin\theta\,\partial_i\varphi\,\hat{\boldsymbol{\varphi}},
$$

ここで $\hat{\boldsymbol{\theta}},\hat{\boldsymbol{\varphi}}$ は球面上の正規直交基底で
$\hat{\boldsymbol{\theta}}\times\hat{\boldsymbol{\varphi}} = \hat{\mathbf{s}}$.
したがって

$$
\hat{\mathbf{s}}\cdot(\partial_i\hat{\mathbf{s}}\times\partial_j\hat{\mathbf{s}})
= \sin\theta\,(\partial_i\theta\,\partial_j\varphi - \partial_j\theta\,\partial_i\varphi)
= \sin\theta\,(\nabla\theta\times\nabla\varphi)_k
$$

(ここで $k$ は $i,j$ に直交する成分). すなわち
$\sin\theta(\nabla\theta\times\nabla\varphi) = \boldsymbol{\Omega}$,
$\Omega_k \equiv \hat{\mathbf{s}}\cdot(\partial_i\hat{\mathbf{s}}\times
\partial_j\hat{\mathbf{s}})$ であり, これは
`src/analysis/vorticity.jl::berry_curvature` が計算する量そのものである.

以上をまとめると, **Mermin–Ho 関係式**

$$
\boxed{\;\nabla\times\mathbf{v}_s = \frac{\hbar F}{M}\,\boldsymbol{\Omega},
\qquad
\Omega_k = \hat{\mathbf{s}}\cdot(\partial_i\hat{\mathbf{s}}\times\partial_j\hat{\mathbf{s}})\;}
$$

を得る. 内部単位 $\hbar=M=1$ では z 成分について
$\omega_z \equiv (\nabla\times\mathbf{v}_s)_z = F\,\Omega_z$ である.

---

## 4. Oracle:Flower と EdH を分ける判定基準

### 4.1 Mermin–Ho 残差

数値的に計算する診断量を, 内部単位で

$$
\varepsilon_z(\mathbf{r},t) \equiv
\underbrace{(\nabla\times\mathbf{v}_s)_z}_{\text{`superfluid\_vorticity`}}
- \;F\;
\underbrace{\Omega_z}_{\text{`berry\_curvature`}}
$$

と定義する. §3 の導出により, 局所状態がスピンコヒーレント多様体上にある限り
$\varepsilon_z = 0$ が恒等的に成立する. したがって残差 $\varepsilon_z$ は
「コヒーレント多様体からのずれ」と「非断熱渦核での特異性」を測る.

### 4.2 二つの状態の理論予測 (oracle)

**Flower (断熱):** 磁場降下に追従してスピンは各瞬間の基底状態に留まる. 系は
コヒーレント多様体上を動き続けるので, バルク全域で $\varepsilon_z \approx 0$.
スピンテクスチャはなめらかで, z 中面のスカイミオン電荷

$$
Q_{\rm sk}(t) = \frac{1}{4\pi}\int \Omega_z\,dA
$$

は整数に量子化され, 時間的に安定する.

**EdH (非断熱):** quench により取り残されたスピンは局所的にコヒーレント多様体
から外れ (中間 m 成分の励起), 渦が核形成される. 渦芯では $\hat{\mathbf{s}}$ が
特異になり Mermin–Ho が破綻するため, $\varepsilon_z$ は渦芯位置に有限の
明るいスポットを示す. $Q_{\rm sk}(t)$ は渦核形成に伴い時間変化する.

判定は次の通り:
$\max_{\mathbf r}|\varepsilon_z|$ が時間とともに有限に立ち上がり, かつその空間
分布が渦芯 (`extract_vortex_lines_per_m` で独立に同定) と一致すれば, それは
非断熱 EdH の動かぬ証拠である. 逆にバルクで $|\varepsilon_z|$ が密度重み平均で
ほぼゼロに留まれば Flower である.

### 4.3 補助診断

- 全角運動量保存: $\langle F_z\rangle(t) + \langle L_z\rangle(t) = \text{const}$.
  EdH では $\langle F_z\rangle$ が減り $\langle L_z\rangle$ が増える (スピン→軌道移行).
  Flower では両者ともほぼ不変.
- スピン歳差 $\langle\mathbf F\rangle(t)$: 横成分 $\langle F_x\rangle,\langle F_y\rangle$ の
  時間発展が歳差運動を直接示す. 本実験では弱磁場で歳差周期が ~22 ms と長く,
  保存間隔 (quench 中 ~7 µs, hold 中 ~0.14 ms) で十分に分解される.
- 単極子 (hedgehog) 電荷 $Q_{\rm 3D}(t)$ = `total_monopole_charge`: 3 次元
  テクスチャの位相幾何学的電荷.

---

## 5. 注意点と近似の範囲 (検証の type 区分)

本診断の妥当性を誠実に述べる. CLAUDE.md の検証 type 区分に従う.

**(A) コード正当性:** $\nabla\times\mathbf{v}_s$ と $\Omega_z$ はともに監査済み
関数 (`vorticity.jl`) であり, FFT 微分の符号・軸順序はオラクルテストで担保
されている. これは A 級の主張である.

**(B) 物理一致 — コヒーレント多様体仮定:** §3 の導出は, 局所状態が常に
スピン-F コヒーレント状態 $|\hat{\mathbf s}\rangle$ であるという単一モード仮定に
依存する. ¹⁵¹Eu は伸びた状態から出発するためこの仮定は初期に厳密に成り立つ
が, 動力学が中間 m 成分や nematic 性を励起すると関係式は補正を受ける. ゆえに
$\varepsilon_z \neq 0$ は「非断熱渦」だけでなく「コヒーレント多様体からの逸脱」
をも意味する. この二つは物理的に絡んでおり (EdH ではどちらも同時に起こる),
残差はその複合信号として解釈する. 係数 $F$ は完全偏極多様体での値であり,
部分偏極では $\langle F_z\rangle/F$ 程度の局所スケーリングを受ける点も留意する.

**(C) モデル忠実度 — 崩壊タイムスケール:** 弱磁場保持中, scalar-LHY 近似下では
~1.5 ms で Townes 的密度特異点へ崩壊する (F=6 スピノル LHY の二チャネル表が
未完であることに起因, CLAUDE.md「Known limitations」参照). したがって保持
時間は崩壊前の信頼できる窓 (~1 internal 単位) に留める. Flower の断熱ランプは
本来 ~250 ms を要するが, 放物線降下は大半の時間を高磁場で過ごし弱磁場の
危険域に入るのは最後の ~1.5 ms のみなので, 初回診断はこの窓内に収まる.
最初の H100 実行で崩壊タイミングを観測し, 必要なら `loss: {gamma_dr}` で
崩壊核を散逸させるか, ランプ時間を調整する.

これらは Matsui et al. (Science 391, 384, 2026) の実験データとの C 級比較を
行う際に, とくに明示すべき近似である.

---

## 6. まとめ

断熱性という単一の物理軸を, 同一基底状態・同一終端磁場・同一保持条件のもとで
$dB/dt$ だけ変えて取り出す. Mermin–Ho 残差 $\varepsilon_z = \omega_z - F\Omega_z$
は, コヒーレント多様体に留まる Flower でバルク全域ゼロ, 非断熱渦を生む EdH で
渦芯に有限スポットを示す. これに全角運動量移行・スカイミオン電荷の量子化・
スピン歳差を重ねて, EdH と Flower を多層的に判定する. 係数 $F$ の由来と
コヒーレント多様体仮定・崩壊タイムスケールという近似の範囲を明示したうえで,
保存済みフル ψ から全観測量を post-hoc に再構成する.
