# Performance and accuracy measurements

Use these tools for a scoped performance task under [CLAUDE.md](../CLAUDE.md).
The metric registry describes how to compare measurements; it does not authorize
an ongoing campaign, cluster spending, automatic commits, or a recurring agent.

## Measurement rules

- Compare records from the same environment class and record host, GPU, driver,
  Julia version, and producing commit. Inspect the actual collector allocation:
  `collect_h100.sh` requests `gpu_1`, while the registry's historical environment
  label is `tsubame_h100_node_q`. The label alone does not prove equal hardware.
- Use device profiling for GPU timings and the registry's noise bands for noisy
  metrics. Kernel utilization estimates are lower bounds.
- A ratchet tracks the best measured value; a threshold checks correctness.
  Neither chooses the scope or stopping condition of the user's task.
- Preserve measurement history and verify accuracy for the measured revision.
  A numerical improvement alone does not establish a valid optimization.

## Tools and state

| File | Role |
|---|---|
| `metrics.toml` | Metric definitions, environment label, noise bands, and historical budget setting. |
| `collect_gpu.jl` | GPU profiler; appends environment-stamped measurements to `history.jsonl`. |
| `collect_h100.sh` | Host-specific batch script; inspect account, paths, allocation, and failure handling before reuse. |
| `gates.jl` | Writes accuracy results to `gates_status.json`. |
| `round.jl` | Compares a measurement with `best.json`; writes `round_verdict.json` and may advance best/progress state. |
| `tsubame_points.sh` | Reports balance and a local spending counter; limitations below. |
| `scorecard.jl` | Renders the history into a scorecard, CSV, and figure. |

## Current limitations

These are inspection findings, not guarantees supplied by the tooling:
Repair and acceptance evidence are tracked in
[#512](https://github.com/KozumaLaboratory/BEC-simulation/issues/512).

- `round.jl` accepts an empty gate map because `all` over an empty collection
  is true. It does not bind gate results to the measurement's commit or time.
  `accepted=true` therefore does not prove that this revision passed accuracy tests.
- `collect_h100.sh` prints `GATES_RUN_FAILED` after a gate-process failure and
  continues to `ALLDONE`. An earlier gate file may remain.
- `tsubame_points.sh` hard-codes a historical cap, defaults a missing
  `.points_spent` to zero, and does not reserve the proposed job's cost. Its
  `OK` verdict is not a verified spending authorization or a fail-closed budget gate.

Use the campaign's current execution and budget checks before any dispatch.
The account and paths in the scripts belong to the original environment and must
be checked on the host being used. The implementation defects above require
repair before these verdicts can drive unattended work.

## Local reporting

With an existing history, render a scorecard from the repository root:

```bash
julia --project=. observability/scorecard.jl
```

For a comparison, first inspect the measurement and same-revision gate evidence,
then run `julia --project=. observability/round.jl <metric> [N] [dtype]`.
This command mutates the local best/progress files. Report the measured change,
validation, and remaining uncertainty against the current task's exit condition.
