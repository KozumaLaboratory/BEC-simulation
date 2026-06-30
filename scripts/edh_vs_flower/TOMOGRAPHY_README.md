# EdH スピンテクスチャ × 傾斜SG トモグラフィ — 図・コード・論理の索引

¹⁵¹Eu（F=6, 13成分スピノルBEC）の Einstein–de-Haas (EdH, 急冷) と Flower (断熱) を、
**量子化軸を傾けた Stern–Gerlach 撮像だけ**からスピンテクスチャ ⟨F⟩(r) として再構成し、
シミュレーション真値で検証した一連の成果。**MILS**（Models In the Simulation）：シミュレーションで
再構成手順を完璧に検証し、同じ手順を実データに適用するのが目標。

図はすべて `runs/eu151_edh_vs_flower/figures/v4_edh_c1_36/`。スクリプトは本ディレクトリ。

---

## 論理の流れ（4段）

1. **再構成対象** = 局所スピン密度行列 ρ(r)_{mm'} = ψ_m ψ_{m'}* / n。観測量は ⟨F_a⟩=Tr(ρF_a)（rank-1）、
   ネマティック N_ab（rank-2）、…多重極ランク k=0..2F=12。
2. **測定モデル（前方）** P_m^(k)(r) = (R_k ρ R_k†)_{mm} = ∫dz |[R_k ψ]_m|²。
   R_k=exp(-iβF_axis)＝量子化軸の傾け。**位相も ψ も要らない線形写像**（占有数のみ）。
3. **再構成（逆問題, ψフリー）**
   - rank-1 ⟨F⟩: 恒等式 R_y(−90)†F_zR_y(−90)=F_x 等 → **3画像で厳密** ⟨F_a⟩=Σ_m m P_m^(k_a)。
   - フル ρ: 連立 P=Mr を制約付き最尤(RρR, ρ⪰0)で逆変換。13角度/軸＝2F+1調和でNyquist飽和。
4. **検証** 真値（ψから直接 Tr(ρF)）と照合。独立チェック（交差検証・解析状態・Julia診断）で循環論法を排除。

**物理結論**: スピン→軌道転化（⟨Lz⟩≠0, 渦チャージ=|Δm| のラダー, 横スピン渦, ⟨Fz⟩が−6から立つ）が
EdHの指紋。Flowerは全部起きない。傾斜SGトモグラフィで rank-1 でも rank-2 でも強く弁別できる。

---

## 0. 基底状態
| 図 | スクリプト | 論理 |
|---|---|---|
| `gs_convergence_c1_36.png/.mp4` | `gs_converge_viz2.py` ← `gs_trajectory.jl` | random→ITP→LBFGS(Sobolev) 収束（E,|∇|の log）。⟨Fz⟩=−6.0000, \|∇\|=1.2e-4 |

## 1. EdH スピンテクスチャ（物理, ψから直接）
| 図 | スクリプト | 論理 |
|---|---|---|
| `edh_3d_spin_texture.mp4`, `edh_3d_spin_frame.png` | `flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py` | 3D ⟨F⟩ ベクトル場（up=赤/down=青） |
| `edh_isosurface_m6m5m4_relphase.mp4`, `edh_isosurface_frame.png` | `flower_protocol_edh/..._isosurface_m6m5m4_second_half.py` | m=−6/−5/−4 密度等値面 + m=−6基準の相対位相 |
| `edh_spin_texture_zpeak.png` | `z_peak_spin.py` | z=±peak 断面のスピンテクスチャ |
| `edh_spin_xsection_xy_zx.mp4`, `edh_spin_xsection_t4ms.png` | `spin_xsection.py` | xy / zx 断面の実時間ダイナミクス |
| `edh_column_integrated_topside.png`, `edh_column_integrated_anim.mp4` | `col_integ_anim.py` | 上から∫dz・横から∫dy（吸収撮像風） |
| `edh_per_m_c1_36.png`, `edh_per_m_density_ladder.png` | `per_m_slices2.py`, `edh_compare_suite.py` | 個別 m 密度・位相（断面＋カラム） |
| `edh_vortex_ladder_EdH.png` | `gallery_vortex_ladder.py` | **角運動量ラダー**: 位相巻き 2π×\|Δm\| = 渦チャージ 0,1,2,3 = Einstein–de-Haas |
| `edh_spatial_coherence_vortex.png` | `spatial_coherence.py` | 局所コヒーレンス ρ_mn(r) の渦巻き（大域は対角で消える理由） |

## 2. 傾斜SGトモグラフィ — 手法（どう測るか）
| 図 | スクリプト | 論理 |
|---|---|---|
| `edh_tilt_tomography_algorithm.png` | `tomography_viz.py` | アルゴリズム全体（ρ・傾斜スキャン・調和↔ランク・漏れ） |
| `edh_SG_tilt_montage_m654.png`, `..._13angles_m654.png` | `sg_tilt_montage.py` | **生入力**: 傾斜SG積分像 n_m^(β)(x,y)、角度ごと（デフォルト13角度） |
| `edh_texture_tomography_from_SG.png`, `..._anim.mp4` | `texture_tomo.py`, `texture_tomo_anim.py` | 3画像→⟨F⟩(r) 厳密、ボクセル/カラム、時間発展 |
| `edh_localrho_from_SG_tiltscan.png` | `rho_from_images.py` | フル局所 ρ を傾斜スキャン+ML (fidelity 0.9995) |
| `edh_localrho_from_13angles.png` | `bridge_4level.py` | 13角度/軸で局所 ρ (fidelity 0.9997) |
| `edh_discrete_tilt_tomography.png` | `discrete_tomo.py` | 離散角の線形逆変換（caveat 5a: 階数欠損） |
| `edh_constrained_ML_tomography.png` | `constrained_ml.py` | 制約付きML(RρR)で階数欠損を克服 |

## 3. 検証（再構成は真値と一致するか）
| 図 | スクリプト | 論理 |
|---|---|---|
| `edh_principle_psifree_reconstruction.png` | `principle_demo.py` | **ψを削除後**にSG画像だけで ⟨F⟩(r) 復元 → 誤差 1e-17 |
| `edh_recon_vs_true_{zpeak,column,metrics}.png`, `..._anim.mp4` | `edh_compare_suite.py`, `edh_compare_anim.py` | 再構成 vs 真値、多指標（RMS/相関/相対L2）、時間発展 |
| `edh_incremental_{convergence,texture_xy_zx,per_component}.png` | `incremental_recon.py` | 角度を1つずつ足す収束（⟨Fz⟩@k1, ⟨Fx⟩@k2, ⟨Fy⟩@k3） |
| （図なし） | `AUDIT.py` | 7項目の敵対的バグ監査（交差検証・解析状態・Julia診断で循環論法排除）全PASS |

## 4. レシピ設計（角度・方向・数）
| 図 | スクリプト | 論理 |
|---|---|---|
| `edh_tomography_angle_count.png` | `angle_harmonics.py` | なぜ13角度（2F+1調和のNyquist）/ 169フルは面外第3軸が必須 |
| `edh_T1_minimal_settings.png` | `t1_minimal.py` | 最小設定数（5設定でfidelity>0.999） |
| `edh_senpai_pm16_recipe.png` | `senpai_pm16.py` | 先輩の±16°レシピ + 1角度足して精度上がるか（rank-1は飽和） |
| `edh_add_angles_direction_rank.png` | `add_angles_improve.py` | ±16°は2方向必須 / 角度追加はrank-2以上で効く |
| （図は angle_count に統合） | `bridge_4level.py` | 4準位posture B、軸要件の逆転（169は面外/4準位は面内）、条件数、保存則 |

## 5. EdH vs Flower 弁別（物理目標）
| 図 | スクリプト | 論理 |
|---|---|---|
| `edh_vs_flower_tomography_discrimination.png` | `flower_vs_edh_tomo.py` | 5設定復元 + ⟨Lz⟩ラダー。⟨Lz⟩ −1.12 vs −0.07 |
| `edh_vs_flower_observables_panel.png` | `gallery_compare_obs.py` | ⟨Fz⟩/\|F⊥\|/Lz密度/ネマティック を並置（Lzは4000倍差, ネマは40倍差） |
| `edh_vs_flower_nematic_director.png` | `gallery_nematic_director.py` | rank-2 ネマティック director場（EdH 16・渦状 / Flower 0.4・放射状） |

---

## データ・パイプライン
- **シミュレーション**: SpinorBEC.jl（F=6 split-step）。GS=ITP→LBFGS、動力学=RTP。Tsubame 4.0 (GPU)。
- **フル13成分ψ抽出**: `extract_psi13.jl`（JLD2-only, ログインノード高速）→ `*_psi13.jld2`（32³, 全フレーム）。
  これが全 python 解析の入力。h5pyはJLD2を列優先で逆順に読むので `transpose(2,1,0,3)`。
- **真値ブリッジ**: `make_goto_h5.py`（Fx/Fy/Fz_3d + t + B_gauss を goto 形式 h5 に）。
- **データ**: `edh_v4_psi13.jld2`(c1=1/36, 140fr), `edh_v3_psi13.jld2`(140fr), `flower_v3_psi13.jld2`(311fr)。

## 再現方法（例）
```bash
# 入力データは scratchpad/newdata/ の *_psi13.jld2 + *_goto.h5
PSI13=edh_v4_psi13.jld2 GOTO=edh_v4_goto.h5 FRAME=100 python3 texture_tomo.py        # 3画像→⟨F⟩
FRAME=100 python3 AUDIT.py                                                             # バグ監査
PSI13=edh_v4_psi13.jld2 FRAME=100 OUTDIR=. python3 incremental_recon.py               # 角度収束
EDH=edh_v3_psi13.jld2 FLOWER=flower_v3_psi13.jld2 python3 flower_vs_edh_tomo.py        # 弁別
```
共通env: `PSI13`(フルψ), `GOTO`(真値h5), `FRAME`(フレーム), `OUT`/`OUTDIR`。

## 既知の注意（gotcha）
- 回転恒等式の符号: ⟨Fx⟩は **R_y(−90°)**, ⟨Fy⟩は **R_x(+90°)**（R_y(+90)は−F_xを返す）。
- ρ読み出しの虚部係数: Tr(ρOp) の im パラメータ寄与は **+2 Im(Op_ac)**（−だと⟨Fy⟩が符号反転）。
- 4準位ブロック復元は漏れ(12%, m≤−2)で誤差床~2.5e-3。フル13センモロイドなら機械精度。
- 保存則 ⟨Fz⟩ は**全13チャネル**で（ブロックのみだと0.46ずれる）。
