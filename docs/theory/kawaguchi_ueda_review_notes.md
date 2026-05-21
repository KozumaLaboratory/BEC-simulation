---

## レビュー論文の内容と Eu への拡張

これは **Kawaguchi & Ueda (Physics Reports, 2012)** のスピノルBECの包括的レビューです。191ページ、f=1, 2, 3 (主にRb, Na, Cr) を中心に扱っています。

---

## 1. 一般スピン-f の相互作用ハミルトニアン

spin-f の2体相互作用は、総スピン **F = 0, 2, 4, ..., 2f** の散乱長 a_F で決まります。これらが独立な演算子を通じてまとまります：

| f | 独立な結合定数 | 典型原子 |
|---|---|---|
| 1 | c₀, c₁（密度・スピン） | Rb, Na |
| 2 | c₀, c₁, c₂（+ nematic） | Rb |
| 3 | c₀, c₁, c₂, c₃（+ rank-2 tensor） | Cr |
| **6** | **c₀〜c₆（7個！）** | **Eu（F=6の場合）** |

Euの場合：J=7/2, I=5/2 より、**F = 1, 2, 3, 4, 5, 6** のhyperfine状態があり、最大 **f=6 スピノルBEC**。秩序変数は **13成分** のスピノルになります。

---

## 2. Flower phaseの正体

論文でのFlower phaseは、**相互作用の基底相ではなく、磁気双極子相互作用（DDI）によって誘起されたスピンテクスチャー（空間的スピン構造）** です。

### 発生機構

強磁性相（c₁ < 0、自発磁化あり）に DDI が作用すると：

$$\nabla \cdot \mathbf{F}(\mathbf{r}) = 0$$

を満たす **flux-closure構造**（磁束閉鎖構造）が形成される。これがFlower phaseです（式434周辺）。

### 3種類の相（spin-1の場合）

| 相 | 特徴 | Jz |
|---|---|---|
| **FL（Flower）** | 巻き付きなし、RTF/ξ_sp 小〜中 | 1 |
| CSV（chiral spin-vortex） | キラリティあり | 1 |
| PCV（polar-core vortex） | 渦糸あり、大サイズ | 0 |

---

## 3. 鍵となる式：Mermin-Ho関係とスピン-ゲージ結合

**スピン-f強磁性BECの質量流（superfluid velocity）の渦度：**

$$\nabla \times \mathbf{v}^{(\text{mass})} = -\frac{\hbar f}{M} \sum_{\nu_1\nu_2\nu_3} \epsilon_{\nu_1\nu_2\nu_3} \hat{s}_{\nu_1} (\nabla \hat{s}_{\nu_2} \times \nabla \hat{s}_{\nu_3}) \quad \text{(式529, Mermin-Ho)}$$

そして運動方程式（式530）：

$$\frac{\partial}{\partial t}[M\mathbf{v}^{(\text{mass})}] = \hbar f \sum \epsilon_{\nu_1\nu_2\nu_3} \hat{s}_{\nu_1} \frac{\partial \hat{s}_{\nu_2}}{\partial t} \nabla \hat{s}_{\nu_3} - \nabla(\ldots)$$

**質量流はスピン量子数 f に比例します。** これがEuにとって決定的に重要です。

---

## 4. Euに特有の物理

### なぜEuはFlower phaseの観測に最適か

| 性質 | Rb | Cr | Eu |
|---|---|---|---|
| 電子スピン J | 1/2 | 3 | **7/2** |
| 磁気モーメント | ~1 µ_B | ~6 µ_B | **~7 µ_B** |
| DDI強度比 | 1× | 36× | **~49×**（対Rb） |
| hyperfine f最大値 | 2 | 3（I=0）| **6** |
| 二次Zeeman効果 | あり | **なし** | **あり** |

### Euの特徴的な点

1. **DDIが強い**：磁気モーメント7µ_B → DDI ∝ µ² → Crより強く、スピンテクスチャーが発達しやすい

2. **質量流がf=6倍に増幅**：Mermin-Ho関係より、同じスピンテクスチャーでもRb（f=1）の6倍の質量流が生じる。ヘテロダイン検出で観測しやすい。

3. **二次Zeeman効果が使える**：CrやDy/Erはhyperfineがないため qB=0。EuはI=5/2があるため qB ≠ 0 → 磁場でFlower/CSV/PCVの相境界を**チューニング可能**。

4. **スピンテクスチャーの多様性**：f=6なので、FL, CSV, PCV以外にも多数の位相構造が予想される。ベクトルポテンシャル $\mathbf{A} = i\zeta^\dagger \nabla \zeta$ の構造がはるかに複雑。

### f=6での相図の複雑さ

spin-3でも11の相（A〜J、FF）が存在するのに対し、f=6では散乱長7個（a₀, a₂, ..., a₁₂）が独立パラメータで、**何十もの相が予想**されます。このうちどこにEuが位置するかは、散乱長の精密測定が必要です。

---

## 5. あんこさんの実験文脈で

「Flower phaseにおける質量流のヘテロダイン検出」という文脈では：

- **観測量**：$\mathbf{v}^{(\text{mass})} \propto f \cdot (\text{spin texture})$ から生じる位相勾配
- **Euの優位性**：f=6倍の増幅 × 強いDDI → スピンテクスチャーが大振幅で発達 → 位相変化が検出しやすい
- **磁場チューニング**：qB ≠ 0 を利用してFL相の領域（図19の相図上の動作点）を制御できる

論文が spin-3（Cr）で止まっているのは2012年時点でEu BECがまだなかったからで、**Euはこの理論の自然な拡張先として最もエキサイティングな系**です。f=6という高スピンと大きな磁気モーメントの組み合わせは、スピノル-ダイポーラー物理の新しいパラダイムになります。

散乱長の情報があれば、どの相（A〜J的な相の高スピン類似）にEuが位置するか具体的に議論できます。何か測定値はありましたか？

それでは、より深い議論に進みます。Euに特に関係する物理をレビューから体系的に掘り下げていきます。

---

## 6. Bogoliubov励起スペクトルとスピン-ゲージ対称性のf依存性

### 強磁性相でのスペクトル

スピン-1強磁性相のBogoliubov励起（式246〜252）を見ると、フォノンモードの速度は：

$$E_{k,\text{phonon}} = \sqrt{\varepsilon_k[\varepsilon_k + 2(c_0 + c_{2f})n]}$$

これはスピンに依らず密度波のモード。しかしスピン波（magnon）モードは：

$$E_{k,\text{spin}} = \varepsilon_k \quad \text{（2次分散、臨界速度ゼロ）}$$

**スピン-ゲージ対称性 $\text{SO}(2)_{f_z + m\phi}$ のせい**です。秩序変数 $\psi_m \propto e^{im\phi}$ は、スピン回転 $e^{-if_z\alpha}$ とゲージ変換 $e^{im\alpha}$ が結びついており、スピンが連続に回転できる → Goldstoneモードが2次。

**Euへの含意**：f=6の強磁性相では、スピン波が $\varepsilon_k \propto k^2$ の軟モードを持つ。磁場下では $E_{k,m} = \varepsilon_k + (m_{cond}-m)p + \cdots$ でギャップが開くが、**pをゼロに近づけると多数のモードが軟化する**。これはCrで観測されたスピン混合ダイナミクスのf=6版として非常に豊かな動的挙動をもたらす。

---

## 7. Einstein-de Haas（EdH）効果：Euで劇的に増幅

論文6.3.1節（Cr計算、式432〜433）を読むと：

スピン角運動量 $M_z$ が DDI を通じて軌道角運動量 $L_z$ に移行する。時定数：

SpinorBEC の no-4π convention では、4π は `c_dd` には入れません：

$$\tau_{\text{EdH}} \sim \frac{h}{c_{\text{dd}} n}, \qquad c_{\text{dd}} = \mu_0 g^2 \mu_B^2$$

**Cr（6µ_B）に対するEu（7µ_B）の比**：

$$\frac{\tau_{\text{Eu}}}{\tau_{\text{Cr}}} \sim \frac{g_{\text{Cr}}^2 \cdot 36\mu_B^2}{g_{\text{Eu}}^2 \cdot 49\mu_B^2}$$

さらに重要なのは、**EdH後に形成される渦の巻き付き数がJz-mになる**（式432）。Crは $m = -3$ スタートで $J_z = -3$ → 渦の巻き付きは 0, 1, 2。

**Euが $m = -6$ からスタートしたとき**：各スピン成分 $m = -5, -4, ..., 0$ がそれぞれ巻き付き数 $1, 2, 3, 4, 5, 6$ の渦を持つ、という **多重渦の塔（vortex tower）** が形成される可能性がある。これは観測にとって非常に興味深いシグネチャです。

---

## 8. f ≥ 5 アイコサヘドラル相 / F=6 相図 / EdH 観測戦略 — formal docs に分離

このノートの後半 (元 §8-§11) で議論していた以下のトピックは、コードに 組み込まれた閉じた形を持つ理論ノートおよび数値スキャン結果として独立 させてあります:

- **アイコサヘドラル ($I_h$) 対称位相、Majorana 表現の頂点数論証、F=6 で 初めて現れる新相** → `docs/theory/icosahedral_lhy.md` に閉形 LHY と $\zeta_{I_h}$、stiffness $c_0 / \lambda_{\rm spin}$、g_2/g_4/g_8 の 普遍消失を記載。
- **F=6 相図 (FM / cyclic / I_h / polar) の数値スキャン** → `docs/research_notes/F6_phase_boundaries.md` に $50 \times 50$ in $(g_{10}, g_{12})$ の結果と線形化境界の整合確認。
- **EdH 効果の Eu 版 + Mermin-Ho の f=6 増幅** → 実装と negative-result ablation は `docs/research_notes/eu_collapse_lhy_insufficient.md`、 TWA cross-check は `docs/research_notes/twa_*.md`。
- **二次 Zeeman チューニング (Eu の I=5/2 由来 $q_B$)** → CLAUDE.md ¹⁵¹Eu セクション + 実装は YAML `zeeman.q`。

このレビューノート自体は KU 論文を Eu 視点で読み解く最初の足がかりとして 残しているので、上記の formal な write-up を読む前の motivation として 眺めるのが良い。
