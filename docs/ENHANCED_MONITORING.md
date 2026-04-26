# Enhanced Monitoring System

> **Status (2026-04-26):** historical document. The features described
> below still exist, but the paths have moved:
>
> | doc claim                       | current location                                   |
> |---------------------------------|----------------------------------------------------|
> | `src/progress.jl`               | `src/workflow/monitoring/progress.jl`              |
> | `src/ascii_plot.jl`             | `src/workflow/monitoring/ascii_plot.jl`            |
> | `src/logging.jl`                | `src/workflow/monitoring/logging.jl`               |
> | `src/resource_monitor.jl`       | `src/workflow/monitoring/resource_monitor.jl`      |
> | `src/notifications.jl`          | `src/workflow/monitoring/notifications.jl`         |
> | `src/adaptive_advice.jl`        | `src/workflow/experiments/adaptive_advice.jl`      |
>
> The "Future" section's "ブラウザダッシュボード" is now the live
> dashboard at `serve_dashboard(8765)` (see `architecture.md` §
> Dashboard). The `dynamics.live_monitor` YAML knob plus
> `/api/live/*` endpoints replace the imagined WebSocket server. For
> the API listing, see `docs/dynamics.md`.

包括的な進捗監視・ログ・診断システム

## 実装済み機能

### 1. ✅ 拡張進捗表示 (`src/progress.jl`)

**機能**:
- プログレスバー (30文字、カラー対応)
- 物理量のリアルタイム表示 (E, ⟨mz⟩, P(m), norm)
- トレンド矢印 (↗↘→)
- パフォーマンス監視 (step/s, メモリ)
- 異常検知 (エネルギードリフト、norm違反)
- ETA計算 (実測ベース)
- Phase間比較 (速度比較)
- 最終サマリー

**表示例**:
```
  relaxation: ████████████████░░░░░░░░░░░░░░ 60% (3000/5000)
    t=3.000 ω⁻¹ | E=12.3567 ↗ | ⟨mz⟩=-0.0456 ↘ | norm=1.00002 | P(m=-6)=0.734 | P(m=-5)=0.178
    12.1 step/s | 156MB | elapsed: 4m 8s | ETA: 2m 45s
    ⚠️  Energy drift 2.3% over last 100 steps
```

**使い方**:
```julia
using SpinorBEC

# 自動的に有効化 (verbose=true のとき)
config = load_config("experiment.yaml")
run_config(config; verbose=true)
```

### 2. ✅ ASCIIプロット (`src/ascii_plot.jl`)

**機能**:
- 時系列プロット (8行×60文字)
- スパークライン (1行コンパクト)
- ヒストグラム

**使い方**:
```julia
# 時系列プロット
plot = plot_ascii(energy_history; width=60, height=8, title="Energy")
println(plot)

# スパークライン (コンパクト)
spark = plot_sparkline(energy_history; width=40)
println("E: ", spark)
```

**出力例**:
```
Energy evolution
12.40 ┤        ╭─╮
12.38 ┤      ╭─╯ ╰─╮
12.36 ┤    ╭─╯     ╰─╮
12.34 ┤╭───╯         ╰─
      └──────────────────
      0              100
```

### 3. ✅ ログシステム (`src/logging.jl`)

**機能**:
- 構造化ログ出力 (テキスト + JSON)
- タイムスタンプ付き
- レベル別 (INFO/WARNING/ERROR/DEBUG)
- イベント記録

**使い方**:
```julia
logger = SimulationLogger("output/logs"; enabled=true)

log_info!(logger, "Phase started", phase="quench", duration=0.1)
log_warning!(logger, "Energy drift detected", drift=0.023)
log_error!(logger, "Simulation failed", error="Norm violation")

finalize_log!(logger)
```

**出力**:
```
output/logs/simulation_2026-04-06_103015.log  # テキスト
output/logs/simulation_2026-04-06_103015.json # JSON
```

### 4. ✅ リソース監視 (`src/resource_monitor.jl`)

**機能**:
- CPU使用率 (Linux)
- RAM使用量 (プロセス + 全体)
- GPU使用率 + VRAM (CUDA利用時)
- 1秒ごとに更新

**使い方**:
```julia
monitor = ResourceMonitor(enabled=true)

# 定期的に更新
update!(monitor)

# フォーマット済み文字列
println(format_resources(monitor))
# 出力: "CPU: 87% | RAM: 156/32000 MB | GPU Mem: 45%"
```

### 5. ✅ 通知システム (`src/notifications.jl`)

**機能**:
- デスクトップ通知 (Linux/macOS/Windows)
- Slack通知 (Webhook)
- Email (プレースホルダー)

**使い方**:
```julia
config = NotificationConfig(
    enabled=true,
    slack_webhook="https://hooks.slack.com/services/YOUR/WEBHOOK",
    email=nothing,
    desktop=true
)

notify_simulation_complete(config, ["quench", "relaxation"], 432.5)
notify_simulation_failed(config, "Norm violation")
```

### 6. ✅ 適応的アドバイス (`src/adaptive_advice.jl`)

**機能**:
- 自動問題検出
  - エネルギー不安定
  - Norm違反
  - 負密度
  - 低CPU使用率
  - DDIパディング推奨
- 修正提案
- 自動修正可能性の判定

**使い方**:
```julia
advice = analyze_simulation_health(ws, energy_hist, norm_hist)
print_advice(advice)
auto_fix_suggestions(ws, advice)
```

**出力例**:
```
🔍 Simulation Health Analysis
════════════════════════════════════════════════════════════════

⚠️  Problem: High energy volatility detected
Suggestions:
   → [Auto-fixable] Reduce dt by factor of 2 (current: 0.001)
   → Enable adaptive integrator
   → Check if DDI padding is enabled
   → Verify LHY correction is appropriate

❗ Problem: Norm conservation violated (norm = 1.0052)
Suggestions:
   → [Auto-fixable] Reduce dt immediately (current: 0.001)
   → Check for numerical instabilities
   → Verify FFT precision settings
```

## 統合例

すべての機能を使った完全な例:

```julia
using SpinorBEC

# 設定読み込み
config = load_config("eu151_experiment_32_enhanced.yaml")

# ロガー初期化
logger = SimulationLogger(config.output.dir)
log_info!(logger, "Simulation started", config=config.name)

# 通知設定
notifications = NotificationConfig(
    enabled=true,
    desktop=true,
    slack_webhook=get(ENV, "SLACK_WEBHOOK", nothing)
)

try
    # シミュレーション実行 (進捗表示自動)
    result = run_config(config; verbose=true)

    # 完了通知
    notify_simulation_complete(
        notifications,
        result.phase_names,
        sum(result.phase_times)
    )

    log_info!(logger, "Simulation completed successfully")

catch e
    # エラー通知
    notify_simulation_failed(notifications, string(e))
    log_error!(logger, "Simulation failed", error=string(e))

    rethrow(e)

finally
    # ログ保存
    finalize_log!(logger)
end
```

## 今後の拡張

### ブラウザダッシュボード (実装予定)
```julia
# WebSocketサーバーでリアルタイム可視化
start_dashboard_server(port=8080)
# → http://localhost:8080 でグラフ表示
```

### インタラクティブモード (実装予定)
```julia
# キーボード入力でシミュレーション制御
# 'p' = pause, 'r' = resume, 'q' = quit
# 'd' = dump state, 's' = save checkpoint
```

### 自動リカバリー (実装予定)
```julia
# 不安定検出時に自動チェックポイント + dt削減
monitoring:
  auto_recovery: true
  checkpoint_on_anomaly: true
```

## パフォーマンス影響

| 機能 | CPU影響 | メモリ影響 |
|------|---------|-----------|
| 拡張進捗表示 | < 0.1% | ~1 MB |
| ASCIIプロット | < 0.1% | ~0.1 MB |
| ログ出力 | < 0.5% | ~10 MB |
| リソース監視 | ~1% | ~1 MB |
| 通知 | negligible | negligible |
| アドバイス | < 0.1% | ~1 MB |

合計: **< 2% CPU, ~15 MB メモリ**

## トラブルシューティング

### Q: 進捗が表示されない
A: `verbose=true` を確認、または `run_config(config; verbose=true)`

### Q: カラーが表示されない
A: ターミナルがカラー対応か確認。`ENV["TERM"]` が "dumb" でないこと。

### Q: デスクトップ通知が動かない
A:
- Linux: `notify-send` コマンドがインストールされているか
- macOS: 自動的に動作するはず
- Windows: PowerShell 5.0+ が必要

### Q: GPU監視が0%のまま
A: CUDA.jl がロードされ、`CUDA.functional()` が true であることを確認

## まとめ

全機能により:
- ✅ **完全放置可能** - 進捗・問題・完了が全て見える
- ✅ **早期問題検出** - 不安定性を即座に発見
- ✅ **詳細記録** - 全イベントがログに記録
- ✅ **リモート監視** - Slack/Email/デスクトップ通知
- ✅ **自動アドバイス** - 問題に対する具体的な解決策
