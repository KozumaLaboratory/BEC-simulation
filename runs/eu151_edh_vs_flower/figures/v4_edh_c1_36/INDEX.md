# 図の分類索引（v4_edh_c1_36）

図はカテゴリ別サブフォルダに整理。完全な図↔コード↔論理の対応は
`scripts/edh_vs_flower/TOMOGRAPHY_README.md` を参照。

```
0_ground_state/      基底状態の収束 (ITP→LBFGS)
1_spin_texture/      EdHスピンテクスチャ（ψから直接の物理）13図
2_tomography_method/ 傾斜SGトモグラフィの手法 9図
3_validation/        再構成 vs 真値の検証 8図
4_recipe_design/     角度・方向・数のレシピ設計 4図
5_edh_vs_flower/     EdH/Flower 弁別（物理目標）3図
```

## 0_ground_state
- `gs_convergence_c1_36.png/.mp4` — random→ITP→LBFGS 収束（E, |∇| の log）

## 1_spin_texture（ψから直接）
- `edh_3d_spin_texture.mp4`, `edh_3d_spin_frame.png` — 3D ⟨F⟩ ベクトル場
- `edh_isosurface_m6m5m4_relphase.mp4`, `edh_isosurface_frame.png` — m別密度等値面+相対位相
- `edh_spin_texture_zpeak.png` — z=±peak 断面
- `edh_spin_xsection_xy_zx.mp4`, `edh_spin_xsection_t4ms.png` — xy/zx 断面ダイナミクス
- `edh_column_integrated_topside.png`, `edh_column_integrated_anim.mp4` — カラム積分（吸収撮像風）
- `edh_per_m_c1_36.png`, `edh_per_m_density_ladder.png` — 個別 m 密度
- `edh_vortex_ladder_EdH.png` — 角運動量ラダー（渦チャージ=|Δm|, Einstein–de-Haas）
- `edh_spatial_coherence_vortex.png` — 局所コヒーレンス ρ_mn(r)

## 2_tomography_method
- `edh_tilt_tomography_algorithm.png` — アルゴリズム全体
- `edh_SG_tilt_montage_m654.png`, `edh_SG_tilt_montage_13angles_m654.png` — 生入力（傾斜SG積分像）
- `edh_texture_tomography_from_SG.png`, `edh_texture_tomography_from_SG_anim.mp4` — 3画像→⟨F⟩
- `edh_localrho_from_SG_tiltscan.png`, `edh_localrho_from_13angles.png` — フル局所ρ
- `edh_discrete_tilt_tomography.png`, `edh_constrained_ML_tomography.png` — 離散逆変換 / 制約付きML

## 3_validation
- `edh_principle_psifree_reconstruction.png` — ψ削除後の原理実証（誤差1e-17）
- `edh_recon_vs_true_zpeak/column/metrics.png`, `edh_recon_vs_true_anim.mp4` — 再構成vs真値+多指標
- `edh_incremental_convergence/texture_xy_zx/per_component.png` — 角度1つずつの収束

## 4_recipe_design
- `edh_tomography_angle_count.png` — なぜ13角度/面外第3軸
- `edh_T1_minimal_settings.png` — 最小設定数
- `edh_senpai_pm16_recipe.png` — 先輩±16° + 1角度追加効果
- `edh_add_angles_direction_rank.png` — 方向被覆 / rank-2改善

## 5_edh_vs_flower
- `edh_vs_flower_tomography_discrimination.png` — 5設定復元 + ⟨Lz⟩ラダー
- `edh_vs_flower_observables_panel.png` — ⟨Fz⟩/|F⊥|/Lz/ネマティック並置
- `edh_vs_flower_nematic_director.png` — rank-2 ネマティック director場
