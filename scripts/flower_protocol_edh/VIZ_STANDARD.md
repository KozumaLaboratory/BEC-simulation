# 描画の標準（永久版） — flower_protocol_edh

**この `scripts/flower_protocol_edh/` のプロットスクリプトが EdH/Flower 可視化の唯一の標準である。**
新しい描画方法を毎回作らない。下記の正典スクリプトを使う。

（背景：`runs/eu151_flower_protocol_edh/figures/edh_quench_63uG_k3_1e-40/` の図が
「綺麗で満足できる」基準。それを作ったのが下記のスクリプト群。commit #32
"paper-grade 3D spin texture" 系。2026-06-26 にこれを標準として確定。）

## 正典スクリプト（図 ↔ スクリプト）

| 図 | スクリプト | 内容 |
|---|---|---|
| `3d_spin_texture.mp4/gif` | **`plot_rtp_10mG_goto_3d_spin.py`** | 論文級3DスピンテクスチャHSV矢印場（Sadler 2006 / Vengalattore 2008 / Kawaguchi-Ueda 2012準拠）。矢色=方向(hue=φ_F, sat=sinθ_F, value=∓z), 長さ∝偏極率p=\|F\|/(F·n), 密度外殻, B(t)参照矢印, 色球凡例 |
| `volume_density_phase.mp4/gif` | `plot_rtp_10mG_goto_3d_density_phase.py` | 全密度grey殻 + m=-6位相塗り殻 |
| `isosurface_peak30_m6.mp4/gif` | `plot_rtp_10mG_goto_isosurface_m6.py` | m=-6等値面(marching tet)アニメ |
| `isosurface_peak30_m6m5m4_secondhalf.mp4/gif` | `plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py` | m=-6/-5/-4 等値面(後半) |
| `vortex_analysis_m6m5m4.png/csv` | `plot_rtp_10mG_goto_vortex_analysis.py` | 渦/循環解析 |
| 2Dスライス5列 | `plot_rtp_10mG_goto.py` | xy/xz密度・位相・スピン場 + スカラー |
| 傾斜投影 | `plot_rtp_10mG_goto_tilted_{contrast,diff,pair}.py` | ±16°傾斜イメージング |
| EdH vs Flower比較 | `compare_edh_vs_flower.py` | mass current/vorticity/Berry比較 |
| B-sweep | `plot_b_sweep*.py`, `plot_b_sweep_3d_spin.py`, etc. | B掃引可視化 |
| アニメ基盤 | `_anim_writer.py` | `save_via_png_dup`：FPSと再生時間を分離（高FPS+スロー） |

## 実行方法（env駆動）

```bash
cd scripts/flower_protocol_edh
RTP_H5=/path/to/<goto>.h5 \
OUT_GIF=/path/to/out.mp4 \
FPE_FPS=60 FPE_DURATION_S=20 \
python3 plot_rtp_10mG_goto_3d_spin.py
```
- `RTP_H5`：入力 h5（goto形式、下記キー）
- `OUT_GIF`：出力（`.mp4` か `.gif` で自動切替、ffmpeg/PIL）
- `FPE_FPS`(60) / `FPE_DURATION_S`(20)：滑らかさ(FPS)と再生速度(秒)を独立指定
- 等値面: `ISO_PEAK_RATIO`, `FPE_3D_*` 等

## 入力 h5（goto形式）のキー

`goto_protocol_10mG.jl` がRTP中に計算・保存する形式（HDF5.jl, column-major）:
- スカラー時系列: `t, E, N, Mz, Fz, B_gauss`
- 2Dスライス: `n_m_xy, n_m_xz, Fx/Fy/Fz_{xy,xz}, arg_psi_m6_{xy,xz}`
- 傾斜: `n_m6_tilted`
- 3Dサブサンプル: `n_total_3d, n_m{6,5,4}_3d, arg_psi_m{6,5,4}_3d, Fx/Fy/Fz_3d`
- メタ: `meta/{F,L_box,NX,vol_stride,omega_ref,theta_q_deg,...}`
- (任意) フルψ: `psi_full_re/im, t_psi, B_gauss_psi`
- プロットスクリプトは h5py で読み `transpose(3,2,1,0)`（column-major↔row-major）

## 新スキーム(現main)データをこの標準に流す方法

現行 RTP パイプライン(`runs/eu151_edh_vs_flower/*.yaml`)は **フルψのみ**保存する
（goto形式の派生量h5は保存しない）。正典スクリプトに流すには goto形式 h5 が必要：

- **[推奨] ブリッジ**：`extract_goto_h5.jl`（新フルψ result.jld2 → 上記キーの goto h5 を
  HDF5.jl で書く。`goto_protocol_10mG.jl` の extract_slices / extract_3d_observables /
  tilted_yint を流用）。**まだ未実装（TODO）。** ← これを作れば新データも正典スクリプトで描画。
- 旧データ（`~/bec-runs/flower_protocol_edh/rtp_*.h5`）は既に goto 形式なので
  正典スクリプトでそのまま描画可。

## 推奨 env 設定（2026-06-29 確定、崩壊しない雲＝K₃なし向け）

3Dスピンテクスチャ `plot_rtp_10mG_goto_3d_spin.py`：
```bash
FPE_SPIN_COLOR=updown            # 上=赤/下=青（虹色でなく）
FPE_3D_SPIN_USE_ABS_THRESH=1     # 絶対閾値=チラつき防止の要
FPE_3D_SPIN_ABS_THRESH=<n_totalのglobal maxの8%>   # 例 EdH 4.89e-4
FPE_3D_ARROW_STEP=3              # 約180本（崩壊しない雲は密になるので間引く）
FPE_3D_ARROW_LENGTH=1.4
FPE_FRAME_STRIDE=1               # 全フレーム＝滑らか
FPE_DURATION_S=40 FPE_FPS=30     # スロー再生
```
- **矢印が消える/チラつく原因＝相対閾値**（各フレームのピーク密度×0.10）。ピーク密度は
  フレーム間で1.7×変動するので閾値が動き雲全体が明滅する。**絶対閾値に切替で解消**
  （矢印数が全フレームほぼ一定になる）。ABS_THRESH は n_total の global-max×0.08 が目安。
- **重なり**＝崩壊しない雲は大きいので ARROW_STEP=2→3（356→約180本）。
- **飛び飛び**＝FRAME_STRIDE=1で全フレーム使う。保存間隔がLarmor周期(~22ms)に対し粗いと
  なお飛ぶ→その場合はTsubameで tstride=1 再抽出（258フレーム=1.8ms間隔）。

等値面 `..._isosurface_m6m5m4_second_half.py`：`FPE_PHASE_MODE=rel`（m=-6基準の相対位相、
既定）, `FPE_DURATION_S=20`, `FRAME_START_FRAC=0.0`。

## ローカル実行の注意（2026-06-26 修正済）
- `_anim_writer.py` の ffmpeg コマンドに `pad=ceil(iw/2)*2:ceil(ih/2)*2` を追加済。
  `bbox_inches=tight` が奇数pxの画像を吐くと libx264 の yuv420p が偶数寸法を要求して
  落ちる（exit 187）ため。Tsubame では問題なかったがローカル ffmpeg 7.x で顕在化。
- 実証：旧 goto h5 (`rtp_quench_63uG_k3_1.0e-40.h5`) を入力に
  `plot_rtp_10mG_goto_3d_spin.py` を回し、論文級の綺麗な3Dスピンテクスチャ
  MP4 (1648×1082, 30fps, 12s) を再生成できることを確認
  → `runs/.../edh_quench_63uG_k3_1e-40/3d_spin_texture_REGEN_*`。

## 禁止事項
- **新しい描画スクリプトを作らない。** 上記正典を使う/拡張する。
- PyVista/matplotlib のアドホックな再発明は廃止済（2026-06-26）。
