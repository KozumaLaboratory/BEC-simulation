# EdH vs Flower — ¹⁵¹Eu 断熱性比較

磁場降下の断熱性 (dB/dt) という単一軸で Einstein–de-Haas (EdH) 状態と
Flower 状態を分離し, Mermin–Ho 残差で定量診断する実験一式. 計算スキームは
最新 main, runs/scripts/描画は Tsubame の蓄積資産を最新スキームへ移植したもの.

理論的背景と導出の全行間: [`docs/research_notes/edh_vs_flower_theory.md`](../../docs/research_notes/edh_vs_flower_theory.md)

## パラメータ (確定)

- **N = 5·10⁴, box = 18, grid 64³, LHY なし** (以前の研究と同じ; 旧 Tsubame 資産と整合).
- **終端磁場 26 µG** (= 2.6 nT, Matsui 値), 両モード共通. **K_3 = 0** (純粋な断熱性比較).
- **EdH**: 10 mG → 26 µG を 0.2 ms で急冷 (quench, 非断熱).
- **Flower**: 後藤 (Goto) プロトコル — 線形降下 (10→2.8 mG) → C¹ 平滑コーナー →
  放物線 1 mG·(1−0.749τ)² (τ=1.12 で 26 µG). descent 274 ms.
- 両 leg とも総時間 288 internal (417 ms) で揃え, 終端磁場・終端時刻が一致.

## 構成

| ファイル | 役割 |
|---|---|
| `edh_quench.yaml`   | EdH: 急冷 (quench) leg |
| `flower_smooth.yaml`| Flower: 後藤プロトコル (線形→放物線) leg |
| `_smoke_edh.yaml`   | 配管確認用の極小 smoke (16³, CPU) |
| `cache/gs_10mG_repolished.jld2` | 共有 10 mG 基底状態 (Tsubame キャッシュを新 LBFGS で再 polish) |

解析・計算スクリプト [`scripts/edh_vs_flower/`](../../scripts/edh_vs_flower/):
- `repolish_gs.jl` — 旧 Tsubame キャッシュ GS を seed に新スキーム LBFGS で再 polish (Sobolev α=0.5)
- `verify_cached_gs.jl` — キャッシュ GS が新スキームで定常か検証
- `run_all.jl` — 両 config 実行 + Mermin–Ho 診断 (単一プロセス)
- `mermin_ho_diagnostic.jl` — 保存済みフル ψ から ε_z, Ω_z, ω_z, Q_sk, ⟨F⟩ 等を post-hoc 計算
- `submit_edh_vs_flower.sh` — TSUBAME UGE バッチ

描画スイート [`scripts/edh_vs_flower/viz/`](../../scripts/edh_vs_flower/viz/) — 31 個の旧描画資産を **3 本**に集約:
- `viz_dynamics.py` — 単一 run のリッチ可視化 (`--view {slices,spin3d,phase3d,tilted,all}`).
  論文級 HSV スピンテクスチャ・2D スライス・density+phase・傾斜投影. スナップショット/アニメ.
- `viz_compare.py` — EdH vs Flower 定量比較 + Mermin–Ho 診断 (4 図).
- `viz_sweep.py` — B-sweep 基底状態ランドスケープ (E(B) 曲線 + 空間).
- 裏方: `extract_observables.py` (フル ψ→描画用 HDF5 キャッシュのブリッジ),
  `_anim_writer.py` (GIF/MP4), `viz_io.py` (キャッシュ読込 + 色変換).

## 設計上の約束

- **共有基底状態**: 両 leg は同一の `cache/gs_10mG_repolished.jld2` を読む. 違いは B(t) だけ.
- **再 polish**: Tsubame の b_sweep キャッシュ (N=5e4/box=18/旧スキーム 9925f41a) は現スキームで
  非定常 (検証済: E 12→9.5 降下) なので, 新 LBFGS で再収束させて使う. b_sweep も全点同様.
- **間引きなしの全保存**: 各 dynamics ステージで `save: {psi: true, precision: f32}`.
  全観測量 (Mermin–Ho 残差, Berry 曲率, skyrmion charge, mass/spin current, ⟨F⟩歳差) を
  保存済みフル ψ から **再シミュレーションなしで** post-hoc 再構成.
- **描画ブリッジ**: HDF5.jl 依存も Julia 改変もなし — h5py が JLD2 を読めるので, 新フル ψ から
  numpy で派生量を計算し標準 HDF5 キャッシュを書く. 31 描画スクリプトを 3 本に集約.
- **崩壊タイムスケール注意** (理論 §4): N=5e4/LHY なしの弱磁場保持は roton/Townes 不安定の
  恐れ. 初回 H100 実行で n_max(t) を観測し, 必要なら hold 短縮 / `loss: {gamma_dr}` 追加.

## 実行手順

```bash
# 1. ローカル smoke (配管確認)
julia --project=. -e 'using SpinorBEC; run_yaml("runs/eu151_edh_vs_flower/_smoke_edh.yaml")'

# 2. Tsubame へ同期 (現 main のスキーム + 本一式)
rsync -avz --exclude '*.jld2' \
    ~/Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/ \
    t4:bec-runs/BEC-simulation/

# 3. GS 再 polish (GPU; 旧キャッシュを seed に新スキームで磨く)
#    + 4. EdH / Flower RTP は run_all.jl / submit がオーケストレート
qsub -g tga-kozuma-kouhi scripts/edh_vs_flower/submit_edh_vs_flower.sh

# 5. 結果を持ち帰り, ブリッジ→描画 (ローカル)
python3 scripts/edh_vs_flower/viz/extract_observables.py <edh_result.jld2> edh_cache.h5
python3 scripts/edh_vs_flower/viz/viz_dynamics.py edh_cache.h5 --view all --anim edh.mp4
python3 scripts/edh_vs_flower/viz/viz_compare.py \
    <edh_dir>/mermin_ho_diag.jld2 <flower_dir>/mermin_ho_diag.jld2 figures
```

## 最初の診断実行で観測すべきこと

1. **崩壊タイミング**: 弱磁場保持で n_max(t) がいつ発散し始めるか.
2. **Mermin–Ho 残差**: EdH で max|ε_z| が渦核形成とともに立ち上がるか; Flower でバルク ≈0 か.
3. **角運動量移行**: EdH で ⟨F_z⟩ が減るか (スピン→軌道).
4. **再 polish 収束**: 10mG は near-degenerate で渋い; 高磁場点ほど grad が下がるか.
