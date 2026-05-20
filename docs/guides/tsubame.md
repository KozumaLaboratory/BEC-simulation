# Running SpinorBEC on TSUBAME 4.0

Day-to-day workflow + scaling knobs for TSUBAME 4.0 (or any SLURM + CUDA cluster).

## One-time setup

```bash
ssh tsubame
cd $T4_GROUP/work     # NOT $HOME — only 30 GB quota there
git clone git@github.com:anko9801/BEC-simulation.git
cd BEC-simulation

source scripts/tsubame_setup.sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

`tsubame_setup.sh` exports `JULIA_DEPOT_PATH=$T4_TMPDIR/.julia` (node-local NVMe to avoid Lustre metadata storms), `SPINORBEC_SCRATCH_DIR=$T4_TMPDIR/spinorbec_snaps` (streamed snapshot scratch), `JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK`, and runs `module load cuda + julia`. Falls back gracefully on dev machines (no `$T4_TMPDIR`).

## Memory and disk budget

ψ ∈ ℂ^{n³ × 13} for Eu151:

| n   | ψ (F64) | ψ (F32) | snapshot (F32) | 154 snapshots |
|-----|---------|---------|----------------|---------------|
| 32  | 1.7 MB  | 0.85 MB | 0.85 MB        | 131 MB        |
| 64  | 13.6 MB | 6.8 MB  | 6.8 MB         | 1.05 GB       |
| 96  | 46 MB   | 23 MB   | 23 MB          | 3.5 GB        |
| 128 | 110 MB  | 55 MB   | 55 MB          | 8.4 GB        |
| 192 | 372 MB  | 186 MB  | 186 MB         | 28.6 GB       |
| 256 | 880 MB  | 440 MB  | 440 MB         | 67.8 GB       |
| 384 | 2.97 GB | 1.49 GB | 1.49 GB        | 229 GB        |

Rule of thumb: peak GPU RAM ≈ 8 × ψ_F64. So 256³ needs ~7 GB; H100 80 GB holds it easily. A100 40 GB caps at ~128³ F64.

Throughput on H100 at 128³ × D=13:

| Phase            | sec / ω⁻¹ step |
|------------------|----------------|
| split-step       | 0.8–1.2        |
| + DDI            | +0.5           |
| + full tensor    | +2             |

128³ × 107.6 ω⁻¹ at dt=1e-4 ≈ 2.5 h walltime. 256³ ≈ 15 h.

## Filesystem layout

| path                   | type                | use                        |
|------------------------|---------------------|----------------------------|
| `$HOME`                | Lustre, 30 GB quota | tiny (no project dirs)     |
| `$T4_GROUP`            | Lustre, TB-scale    | code + finalised results   |
| `$T4_LOCAL`/`$T4_TMPDIR` | node-local NVMe   | depots, scratch snapshots  |
| `/scratch`             | per-node, ephemeral | cleared at job end         |

Lustre is bad at many small writes; `dynamics/psi_snapshots_streamed/frame_NNNNN` emits one metadata op per frame, which stacks. `SPINORBEC_SCRATCH_DIR=$T4_TMPDIR` redirects `.tmp` files to NVMe and copies to Lustre on success.

## Edit-test-submit loop

```bash
$EDITOR runs/eu151_edh_ext/config.yaml

# Dry-run check (calibration applied? schema OK?)
julia --project=. -e 'using SpinorBEC; run_yaml("runs/eu151_edh_ext/config.yaml"; dry_run=true)'

# Suggested SLURM flags from grid + scan size
julia --project=. scripts/slurm_helpers.jl sbatch-suggest runs/eu151_edh_ext/config.yaml

# Submit (single H100, 12 h)
sbatch scripts/slurm/eu151_h100_single.sbatch runs/eu151_edh_ext/config.yaml

squeue -u $USER
tail -f logs/spinorbec-*.out
```

Phase-diagram scans where points are independent → array job:

```bash
julia --project=. scripts/slurm_helpers.jl count runs/foo/config.yaml   # → 144
sbatch --array=1-144%12 scripts/slurm/scan_array.sbatch runs/foo/config.yaml
```

Each task writes `runs/foo/point_NNN.jld2`; resumable — re-submitting skips cached files. Wired via `SPINORBEC_SCAN_ONLY_INDEX` env var inside `_run_yaml_scan`.

## Recommended YAML knobs at scale

```yaml
pipeline:
  - ground_state:
      grid: {n: [128, 128, 128], box: [20.0, 20.0, 20.0]}
      backend: cuda
  - dynamics:
      duration: 107.6
      dt: 1.0e-4
      save_every: 7000         # → 154 snapshots
      save: {psi: true, precision: "f32"}  # streamed F32, ~8.4 GB at 128³
```

Pre-flight: `using SpinorBEC; estimate_run_budget("path/to/config.yaml")` reports VRAM, host RAM, disk per scan point + total disk.

## Singularity (alternative)

If a recent `julia` module isn't available, build the container once:

```bash
cd $T4_GROUP/work
singularity build --fakeroot spinorbec.sif \
    /path/to/BEC-simulation/containers/spinorbec.def

singularity exec --nv \
    --bind /path/to/BEC-simulation:/work \
    spinorbec.sif julia --project=/work -e '
        using SpinorBEC; run_yaml("/work/runs/eu151_edh_ext/config.yaml")'
```

The `%post` block pre-warms a depot inside the image so first-time precompile of FFTW / CUDA / etc. is amortised at build time.

## Live monitoring from your laptop

Dashboard runs on the compute node; SSH-tunnel via the login node:

```bash
# laptop
ssh -L 8765:cnode-h100-12:8765 tsubame

# compute node (via srun --pty bash)
julia --project=. -e 'using SpinorBEC; serve_dashboard(8765)' &

# laptop browser → http://localhost:8765
```

Lab-image push uses the same tunnel: `curl --data-binary @absorption_shot.png http://localhost:8765/api/lab/image/today`.

## Checkpoint and resume

`run_pipeline` writes periodic checkpoints to `$run_dir/.checkpoints/<filename>` during a dynamics step. Restart with the same `run_yaml(...)` call — the cache/resume logic picks up from the last checkpoint. Pair with SLURM `--requeue` for automatic restart after preemption.

For multi-attempt mixes of crashes + preemption: `sbatch scripts/slurm/eu151_h100_single.sbatch runs/foo/config.yaml`, or `scripts/supervised_run.sh foo 5` for 5 retries with 30 s backoff. `--requeue` covers most SLURM cases; the supervisor wrapper helps in interactive sessions.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| First run very slow (~10 min before any output) | precompile on Lustre | confirm `$JULIA_DEPOT_PATH` points at NVMe (`echo $JULIA_DEPOT_PATH` after sourcing) |
| `unable to load CUDA driver` | module not loaded | `source scripts/tsubame_setup.sh` first |
| `ENOSPC` mid-run | streamed snapshots filled `$T4_TMPDIR` | bigger `nvme:NN` or coarser `save.psi` cadence |
| Job killed at exact wall-clock limit | `--requeue` not set | re-submit; SLURM resumes from checkpoint |
| Phase-diagram scan progresses one-at-a-time | not using array job | switch to `scan_array.sbatch` with `--array=1-N%K` |
| GC pressure on big ψ across many scan points | implicit retention | `GC.gc()` between phases; `CUDA.memory_status()` to inspect |
| FFTW wisdom replanning on each new node | wisdom not shared | bake wisdom into `runs/shared/fftw.wisdom` if hopping CPU generations |
