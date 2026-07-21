# Perf / Accuracy Scorecard

_Generated 2026-07-21T22:20:01.351 from `observability/history.jsonl` (8 records). No composite score, no arbitrary targets — ratchet metrics track best-so-far vs a physical/hardware bound._

## Ratchet metrics (optimise forever · env_class = tsubame_h100_node_q)

| metric | dir | best-so-far | bound | headroom | since |
|---|---|--:|--:|--|---|
| `gpu_busy_pct` | maximize | 96.88 | 100.0 | 3.1 to 100 | 2026-07-21 |
| `gpu_step_us` | minimize | 3207.21 | 0.0 | →0 | 2026-07-21 |
| `gpu_ddi_rotation_us` | minimize | 334.89 | 0.0 | →0 | 2026-07-21 |

## Threshold gates (correctness · machine-eps floor · enforced in CI)

| metric | gate | source |
|---|--:|---|
| `hpsi_self_consistency_rel` | 1.0e-12 | `test/test_level10_hpsi_self_consistency.jl` |
| `gpu_cpu_parity_rel` | 1.0e-10 | `test/test_level0_gpu_cpu_consistency.jl` |

## TSUBAME budget (campaign cap = 30.0 points)

- balance: **338.77** points  · campaign spent: **0.0542** / 30.0  · /gs/fs disk: nothing GB
