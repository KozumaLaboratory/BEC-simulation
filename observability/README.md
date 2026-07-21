# Goal-driven perf / accuracy observability

A **permanent, goal-driven** mechanism to keep raising speed and accuracy —
independent of the `bench/` ralph ratchet (whose WSL2 wall-clock is too noisy
to be a foundation).

## The idea

Two kinds of metric, decided by whether a physical floor exists:

- **ratchet** — optimise *forever*. **No target, no finish line.** Track
  best-so-far; the only reference is a physical/hardware **bound** (roofline,
  100% GPU-busy, 0 allocations, machine-eps), never a chosen number.
  `headroom = gap(best_so_far, bound)`.
- **threshold** — correctness. A machine-eps floor exists, so tightening past
  it is noise. Stays a pass/fail **CI gate**; not ratcheted here.

Why no numeric target: you asked to optimise *infinitely*. A target would say
"done" and stop. `bound` tells you how much headroom is left without ever
capping the effort.

## Measurement discipline (this is the whole point vs ralph)

- **Stable env only.** All ratchet metrics measured on the **TSUBAME H100
  node** (`env_class = tsubame_h100_node_q`). Records from different env
  classes are never compared (no WSL2-vs-H100 mixing).
- **CUDA profiler, not wall guesses.** `gpu_busy_pct` = Σ(device kernel time ×
  per-step count) / wall — this exposes launch-overhead (the real bottleneck;
  the ~11–13% baseline lives here). Per-kernel `util_lb_pct` is an honest
  **lower bound** on roofline utilisation, not a fabricated exact figure.
- **Prefer deterministic metrics.** Allocations are exact; wall-clock is noisy
  (`noise_band_pct` must be cleared before it moves a record).
- **Every record is env-stamped** (host / GPU / driver / julia / commit).

CPU has no clean utilisation analogue (no profiler achieved/peak), so CPU is
tracked by best-so-far time + exact allocations only.

## Files

| file | role |
|---|---|
| `metrics.toml` | registry: each metric's kind / direction / bound / confidence / source. Single source of truth. |
| `collect_gpu.jl` | H100 collector (`CUDA.@profile`). Emits one env-stamped JSON record → `history.jsonl`. |
| `collect_h100.sh` | UGE batch job (node_q) running the collector at 64³ + 128³. |
| `tsubame_points.sh` | login-node budget capture + **30-point campaign-cap** dispatch gate. |
| `history.jsonl` | append-only time series (the observability substrate). |
| `round.jl` | **deterministic verdict primitive** for `/goal`. Compares newest measurement to `best.json`, checks noise band + gates, writes `round_verdict.json`. |
| `best.json` | persistent ratchet state (best-so-far per `metric/N/dtype`). Advances ONLY on an accepted round. |
| `scorecard.jl` | derivative view → `docs/design/scorecard.md` + `scorecard.csv` + `figs/scorecard.png`. |

## Improvement loop — use the native `/goal` + `/loop`, do NOT hand-build one

`/goal` (run turns until a measurable condition holds) + `/loop` (repeat every
N min) ARE the improvement loop. We do not write a bespoke driver.

The catch: `/goal`'s completion check is a fast **fuzzy** model — never let it
do the numeric comparison (sneaky-prover discipline). `round.jl` does all the
math deterministically and emits a single boolean; the `/goal` condition reads
only that:

```
# one ratchet notch on the DDI-rotation kernel:
/goal observability/round_verdict.json shows accepted=true for metric
      gpu_ddi_rotation_us, or stop after 8 turns
```

A round = measure → `round.jl <metric>` → if `accepted` then commit. `best.json`
carries the ratchet across `/goal` rounds and `/loop` iterations, so "beat
best-so-far once" is a valid measurable completion even with no numeric target.

### One CONSTANT goal that drives dozens of rounds

Don't bake a metric name into the goal (that forces a rewrite per kernel and
stalls when one metric is exhausted). Instead drive on the monotonic
`progress.json.accepted_count`, which `round.jl` bumps on every accepted round
regardless of which kernel it targeted:

```
/goal observability/progress.json accepted_count reaches 25, or stop after 150 turns
```

This text NEVER changes. Each round the agent auto-selects the highest-headroom
GPU kernel (from the device-time profile + best.json), makes one gate-protected
optimisation, dispatches, and `round.jl` banks the win (`accepted_count++`). The
goal is satisfied one win at a time until the count target (a batch of dozens)
or the turn bound. Metric selection is the agent's job per round, so the goal
stays constant forever. Pair with `/loop` for open-ended operation.

`accepted=true` requires: improvement beyond the noise band AND
`gates_status.json` shows every accuracy gate passing (write it by running the
threshold tests in the same round). Budget safety: even under autonomous
`/loop`, `tsubame_points.sh` hard-blocks dispatch at the 30-point cap.

## Budget

Campaign hard cap: **30 TSUBAME points** (`metrics.toml [budget].cap_points`).
Before every dispatch run `tsubame_points.sh` on the login node; it prints
`VERDICT: OK / BLOCKED` against the cap and records balance + disk.

## Run

```bash
# 1. login node: check budget cap (records balance, gates dispatch)
ssh tsubame 'cd /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt && bash observability/tsubame_points.sh'

# 2. dispatch H100 collector (only if VERDICT OK)
ssh tsubame 'cd .../BEC-opt && qsub -g tga-kozuma-kouhi observability/collect_h100.sh'

# 3. pull history.jsonl back, then render the derivative view
julia --project=. observability/scorecard.jl
```

## What this is NOT

- Not a composite 0–100 score (arbitrary weights hide regressions).
- Not founded on `bench/baseline.json` / ralph (noisy, speed-only, no history).
- Not a set of fixed targets (would stop infinite optimisation).
- Not a hand-written loop driver (that's `/goal` + `/loop`).
- Not a place where a fuzzy judge does numeric comparison (that's `round.jl`).
