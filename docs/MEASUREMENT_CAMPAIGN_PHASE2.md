# Measurement Campaign — Phase 2 (修論 deadline 直前)

**Purpose**: R32-R39 で実装した optimization / continuation インフラの
ROI 数値を **実 Eu real-physics config で取得** する。Phase 1 の合成
検証は完了済み。Phase 2 は TSUBAME 1 週間の burst で全数値を揃える。

**Owner**: anko (修論)
**Reviewer**: TBD
**Deadline**: 修論提出 (date TBD)
**Compute**: TSUBAME 4.0 H100 (job array, f_node, T3TMPDIR scratch)

---

## 測定マトリクス

各 round の (a) 測定すべき数値、(b) 期待値、(c) 既測定値、(d) Eu real
config で取り直す bench、(e) 想定 wall time。

### R32 — Sobolev preconditioner

| 項目 | 値 |
|---|---|
| **測定**: F=6 + DDI で α sweep の iter 数 | TODO |
| **期待**: ~ 2-3× iter 削減 (stiff DDI で benefit) | — |
| **既測**: F=1/F=6 16³ で **iter 削減なし** (negative result) | ✅ |
| **Eu config**: `runs/measurement_R3x_eu/r32_sobolev_eu_64/config.yaml` | TODO |
| **wall time**: 6 α × ~30 min/run @ 64³ ≈ 3 h | — |

実 Eu 64³ で iter 削減が出れば修正、出なければ negative result を
修論に明記。L-BFGS history が既に強い preconditioner として機能する
ことを論じる。

### R33 — Multi-fidelity Bayesian optimisation

| 項目 | 値 |
|---|---|
| **測定**: SF (single-fidelity BO) vs MFBO の wall-time + quality | TODO |
| **期待**: cost_ratio 30-60 ⇒ wall-clock 8-15× 削減 | — |
| **既測**: F=1 SpinorBEC pair (10³ vs 20³) で **3.11× speedup**, high-fid 12→2 | ✅ |
| **Eu config**: `runs/measurement_R3x_eu/r33_mfbo_eu_phase/config.yaml` | TODO |
| **wall time**: 16³ low (~1 min) + 32³ high (~30 min); 50 evals total ≈ 4-5 h | — |

Eu real config で MFBO が単一 fidelity 比で何倍速いか測る。**期待値
8-15× を実証できれば 修論 figure に直入** (TSUBAME wall-clock log を
そのまま使える)。

### R34 — MFBO YAML wrapper

| 項目 | 値 |
|---|---|
| **測定**: heavy gate 経由 Eu real run (R33 と同じ config を YAML 経由) | TODO |
| **期待**: in-memory R33 と同等 wall-clock | — |
| **既測**: 1D F=1 throwaway YAML で E2E 動作確認 | ✅ (heavy-gate skip) |
| **Eu config**: R33 と同じ `r33_mfbo_eu_phase/config.yaml` を YAML wrapper 経由 | TODO |

YAML wrapper のオーバーヘッドは parse_pipeline + workspace
specialisation の per-call cost。R33 (in-memory) と差が出るかを測る。

### R35 — Pseudo-arclength continuation (B-1 boundary)

| 項目 | 値 |
|---|---|
| **測定**: B-1 (FL vs uniform polarization) boundary 100 点 trace の wall time | TODO |
| **期待**: 2D grid scan (121 点 × 30 min) = 60 h vs continuation 100 点 ≈ 50 min ⇒ **70×** | — |
| **既測**: synthetic 2D (vertical line, unit circle) で residual < 1e-7 | ✅ |
| **Eu config**: `runs/measurement_R3x_eu/r35_b1_boundary_trace/config.yaml` | TODO |
| **wall time**: cold 1 min + warm 30 s × 99 = ~ 50 min | — |

修論 figure: B-1 boundary curve in (c₁, c_dd) plane with 100 traced
points; overlay grid-scan baseline for visual proof of speedup.

### R36 — Active learning phase scan

| 項目 | 値 |
|---|---|
| **測定**: 4D Eu (c₁/c₀, c_dd/c₀, p, q) AL で 200-500 evals の boundary concentration | TODO |
| **期待**: ~3-5× sample efficiency vs uniform (full softmax-GP なら 100×) | — |
| **既測**: 合成 2D で **66.7%** boundary concentration vs 40% baseline | ✅ |
| **Eu config**: `runs/measurement_R3x_eu/r36_4d_phase_al/config.yaml` | TODO |
| **wall time**: 200-500 evals × 5-30 min/eval ≈ 30 h - 250 h (heavy) | — |

実 Eu で 200 sample 以下にしたい。Phase 6 の 4D phase mapping は
このベンチが load-bearing。

### R37 — Triple-point hunting

| 項目 | 値 |
|---|---|
| **測定**: F=6 spinor で AL → triple-point detection → 3 boundary traces | TODO |
| **期待**: 文献に F=6 triple point の数値 mapping は未踏 → **新規発見** | — |
| **既測**: 合成 2D 3-fold equilateral で 21/21 pass、中心の triple 検出 | ✅ |
| **Eu config**: `runs/measurement_R3x_eu/r37_triple_point_hunt/config.yaml` | TODO |
| **wall time**: AL 100 evals + 3 boundary traces × ~50 min = 12-15 h | — |

**論文化候補** (修論 → 共同研究 → D 論研究テーマ)。KU §5 が議論する
F=1,2,3 の FL/CSV/PCV triple point の F=6 拡張。

### R38 — AL YAML wrapper

| 項目 | 値 |
|---|---|
| **測定**: heavy gate 経由 R36 と同じ Eu config で動作 | TODO |
| **既測**: 1D F=1 throwaway で unit + skip-path 確認 | ✅ |
| **Eu config**: R36 と同じ `r36_4d_phase_al/config.yaml` を YAML 経由 | TODO |

### R39 — BdG spectrum along boundary

| 項目 | 値 |
|---|---|
| **測定**: B-1 boundary 50 点上の Bogoliubov spectrum heatmap (k vs arclength) | TODO |
| **期待**: roton softening の連続 mapping (修論 figure) | — |
| **既測**: F=1 weak (8³, 30 k_values) で max_growth ≈ 0 stable | ✅ |
| **Eu config**: `runs/measurement_R3x_eu/r39_bdg_along_b1/config.yaml` | TODO |
| **wall time**: 50 points × (warm GS 30 s + BdG 0.1 s) ≈ 25 min | — |

修論 figure: 2D heatmap, x = boundary arclength, y = k, color = Re ω
or growth rate. Roton minimum が boundary に沿ってどう evolve するか
1 plot で見える。

---

## TSUBAME run plan

| Slot | What | Wall time | Output |
|---|---|---|---|
| Day 1 | R33 MFBO Eu phase scan | 4-5 h | `runs/measurement_R3x_eu/r33_*/result.jld2` |
| Day 1 | R35 B-1 boundary trace | 1 h | `…/r35_*/trace.jld2` |
| Day 1 | R39 BdG along B-1 | 30 min | `…/r39_*/spectra.jld2` |
| Day 2-3 | R36 4D AL Eu | 30+ h (job array) | `…/r36_*/trajectory.jld2` |
| Day 4-5 | R37 triple-point hunt | 12-15 h | `…/r37_*/candidates.jld2` |
| Day 6 | R32 Sobolev sweep (low priority) | 3 h | `…/r32_*/sweep.jld2` |
| Day 7 | Re-run / debugging slack | — | — |

各 job は `#!/bin/sh` + `julia --project=. run_measurement.jl` 形式、
`SPINORBEC_RUN_HEAVY_YAML=true` env で gate を opens。

---

## 修論 table テンプレート

執筆時に上の "Eu config" 列の TODO が埋まり、(d) が実値になったら以下を
修論 §X.X に貼る:

```
| Method                    | Wall (h) | Speedup | Quality (E_min Δ) |
|---------------------------|----------|---------|-------------------|
| Grid scan baseline        |  60.0   |  1.0×   |   0.0             |
| Bayesian optimisation     |  16.0   |  3.8×   |   < 1e-3          |
| Multi-fidelity BO (R33)   |   ?.?   |   ?.?× |   < 1e-3          |
| Pseudo-arclength (R35)    |   ?.?   |   ?.?× |   < 1e-3          |
| Active learning (R36)     |   ?.?   |   ?.?× |   < 1e-3          |
```

R33 までは既に 3.11× 確認済。

---

## Canonical Eu YAML configs

**Location**: `runs/measurement_R3x_eu/`
**Status**: 雛形のみ commit、実行は TSUBAME burst time

各 sub-dir の README に R3x との対応 + run command を記載。
