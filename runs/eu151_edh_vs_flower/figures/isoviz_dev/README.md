# isoviz_dev — EdH vs Flower スピンテクスチャ トモグラフィ

傾斜Stern–Gerlach吸収撮像（視線=y, ∫dy）だけからスピンテクスチャを再構成する手法の
検証・可視化。EdH = par_T90（放物線ランプ→26µG, quench的）、Flower = flower120（放物線ランプ→120µG, 断熱）。

## データ（ルート直下・スクリプトが参照）
- `par_T90_psi13.jld2` / `par_T90_goto.h5` — EdH 完全13成分スピノル(32³,80フレーム) と Fx/Fy/Fz/n
- `flower120_psi13.jld2` / `flower120_goto.h5` — Flower @120µG（同上, 80フレーム, tms 3→260）
- `par_T90_tilted_goto.h5` — 148ms で量子化軸を傾けた派生データ

## フォルダ
- `01_poster/` — ポスター用の仕上げ図（poster_spintex_{xy,xz}, tilt吸収像, ℓ縮退の図 など）
- `02_pipeline_stills/` — 手法パイプラインの静止画（raw_montage → intermediate → recon_vs_truth → recon_xy、後藤法再現 reproduce_goto）
- `notes/` — LaTeX ノート（recon_note = 手法理論, rotation_matrix = 回転行列）
- `videos/` — mp4（spintex 2D/3D, iso, reproduce_goto_anim, pipe_* end-to-endパイプライン）
- `99_misc/` — 探索・途中段階の図（decomp, scope, null-space, 較正, 純度 など）

## パイプライン mp4（videos/, 実験の吸収積分データのみから）
`pipe_raw_*`(生20枚) → `pipe_mid_*`(重心→列⟨F⟩) → `pipe_xz_*`(子午面) → `pipe_xy_*`(軸対称+ℓ=1で3D→xy)

## 主なスクリプト
`../../../scripts/edh_vs_flower/` : recon_vs_truth_par.py, recon_xy_zscan.py, recon_xy_ell.py,
poster_spintex_3panel.py, poster_spintex_xz.py, poster_tilt_absorption_combined.py,
reproduce_goto.py / reproduce_goto_anim.py, raw_montage.py, intermediate_pipeline.py,
pipeline_anim.py（STAGE=raw/mid/xz/xy）, build_goto_flower120.py, submit_flower120.sh
