# HANDOFF — EdH vs Flower v6 高精度・全格子リラン + 成分表示トモグラフィ実データ検証
（2026-07-02、Opus 4.8 → 後続モデル引き継ぎ）

## 0. 全体の狙い（1行）
理論ノート `notes/quantization_axis_tomography/explicit_components.tex`（傾斜SGトモグラフィの成分表示：
R†F_zR=cosφF_z+sinφF_y、⟨m|RFR|m⟩ と ⟨ψ|RFR|ψ⟩、一次切りの破綻）を、**実シミュ96³全格子・f64データ**の上で検証し、
EdH(quench) vs Flower(adiabatic) を Mermin-Ho 残差＋トモグラフィで弁別する。

## 1. ユーザーの厳命（守るべき制約）
- **計算グリッド＝解析グリッド**：抽出の stride は 1（間引き禁止）。表示グリッド=計算ピクセル。
- **閾値で切らない**：解析/表示の密度フロアは既定0（`FPE_DENSITY_FLOOR`）。
- **精度重視**：96³、ψスナップショット f64、dt細分。
- **sim も描画も Tsubame ジョブで**（Macで重い描画をしない。Mac OOM 前科あり）。
- 描画標準は `scripts/flower_protocol_edh/` の正典スクリプト（アドホック再発明禁止）。

## 2. やったこと（コード、すべて `feat/edh-vs-flower-mermin-ho` ブランチ、ローカル＋Tsubame同期済）
- 設定: `runs/eu151_edh_vs_flower/{edh_quench_v6,flower_smooth_v6,_smoke_v6}.yaml`
  = 96³/box18、ψ保存 **f64**、c1=1/36、K3=2.1e-41、両レグ **288内部時間で time-match**（26µG着地）。
- `scripts/edh_vs_flower/gs_trajectory.jl` に `--n`（格子数）追加。
- `extract_psi13.jl`/`extract_3d.jl`：**stride 既定 2→1**、psi13 は `--dtype f64` 既定。
- `_floor.py` 新設 + トモ/比較6本の `0.04*max` 表示マスクを `FPE_DENSITY_FLOOR`(既定0) 化。
  再構成計算は元々全ボクセル使用（マスクは描画のみ）。
- ジョブ: `submit_{gs,edh,flower,viz}_v6.sh` + `submit_smoke_v6.sh`。

## 3. ★重大教訓（次も必ず踏む罠）
- `#$ -l gpu_h=1` は **MIG 12GB スライス**(gg_mig=1) が割当たり、96³/f64 は CUDA 初期化/ws 確保で **ハング**
  （cpu完全停止・gpu_usage NONE・maxvmem 12.3G 頭打ち）。64³は12GBに収まってたので今まで顕在化せず。
  **→ 96³以上のGPUジョブは `#$ -l node_q=1`（フルH100 1枚≈94GB）。** node_q版は cpu>wallclock で健全稼働。
- Tsubame の SSH ポーラーは wifi 断で qstat が空を返し「finished」誤検知する → 空返り＝断、で扱うこと。

## 4. Tsubame 実行結果（データ位置：`/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/`）
- GS 8049968（node_q）→ `cache/gs_10mG_c1_36_96.jld2`（96³ f64, grad_norm 1.6e-5, 良好）
- EdH 8049969 / Flower 8049970（node_q, 12h）：完走。各 run dir に
  `result.jld2`(13.8/15.7G) `spin3d.jld2`(5.6/6.3G, 全96³) `slices.jld2` `mermin_ho_diag.jld2` `goto.h5`。
  抽出 psi13（**全96³ f64**）: `edh_v6_psi13.jld2`(30.4G) / `flower_v6_psi13.jld2`(34G)。
- viz 8049971（最初）：cpu_40, **h_rt=4h で Flower途中タイムアウト** → EdH mp4 3本のみ。
- viz 8051043（再投入, h_rt=10h, トモ先頭・EdH済スキップ）：トモグラフィ全PNG + Flower 3D を生成。

## 5. 物理の結論（96³/f64・全格子で確定）★本物
- **Mermin-Ho 残差 ε_wmean（最終）：EdH 0.682 vs Flower 0.043 ≈ 16倍差** → 断熱性を明確に分離。
- ⟨Fz⟩_avg：EdH −6→−3.05、Flower −5.98→−3.36（K3ロスと転化の混在。per-atom sz と N崩壊の切り分けは
  [[edh-vs-flower-bec-simulation]] の 2026-06-29 訂正を厳守：⟨Fz⟩低下の主因はしばしば原子損失）。
- 両者 stable_arrest（K3で崩壊停止）。m=−6 占有 最終 EdH 0.638 / Flower 0.670。
- 傾斜SGトモグラフィが実データ96³で ⟨F⟩(r) を復元でき、EdH/Flower を弁別 → 理論ノートの手法が本物のsimで機能。

## 6. 成果物（Macに取得済み：`runs/eu151_edh_vs_flower/figures/v6/`）
- トモ: `edh_texture_tomography.png` `flower_texture_tomography.png` `edh_vs_flower_discrimination.png`
  `cmp_fields_zpeak.png` `cmp_fields_column.png` `cmp_metrics.png` `cmp_per_m_density.png`
- mp4: `edh_{3d_spin_texture,isosurface_m6m5m4_relphase,3d_density_phase}.mp4`
  `flower_{3d_spin_texture,isosurface_m6m5m4_relphase}.mp4`

## 7. 未完 / 既知バグ（次の一手）
1. `flower_3d_density_phase.mp4`：viz 8051043 の最終レンダ中（放置で完成予定）。背景ウォッチャー
   `scratchpad/fetch_viz2.sh`(task bnss1ngxp) が viz 終了時に `figures/v6/` へ自動 rsync。
2. **バグ: `edh_texture_tomo_anim.mp4` 失敗** = `ModuleNotFoundError: No module named '_anim_writer'`。
   原因：`scripts/edh_vs_flower/texture_tomo_anim.py`（と `edh_compare_anim.py`）が
   `sys.path.insert(0,"/Users/mitsuki/Desktop/.../flower_protocol_edh")` と **Macの絶対パス**を挿入していて
   Tsubame に無い。→ 修正：`os.path` で `flower_protocol_edh` を**スクリプト相対**で解決するか、
   `PROJECT_ROOT` 相対に。修正後 viz を該当スクリプトだけ再実行。
3. 3D quiver 矢印は 96³ 全部だと判読不能 → spin_texture mp4 のみ `FPE_3D_ARROW_STEP=2`
   （2Dスライス/等値面/トモ列画像は全96³）。ユーザーが「1ボクセル1矢印」を望むなら step=1 に。
4. 残ポイント：開始 85.91pt から GS+EdH+Flower(node_q GPU) 消費済。`t4-user-info group point -g tga-kozuma-kouhi` で確認。
5. git 未 finalize（Issue/push/PR）。ブランチ `feat/edh-vs-flower-mermin-ho`。

## 8. 環境メモ
- Tsubame: `ssh t4`（ue06186）。JULIA=共有直バイナリ、depot=node-local NVMe:group（[[project_tsubame_kozumalab]]）。
- 描画: `/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python`（numpy2.4/scipy1.17/skimage0.26/h5py OK）。
- 理論ノート: `notes/quantization_axis_tomography/explicit_components.{tex,pdf}`（13ページ、成分表示＋F=1手計算＋数値代入）。
- 詳細は memory `project_edh_vs_flower.md` の「v6 高精度・全格子リラン」節。
