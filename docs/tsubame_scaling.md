# Running SpinorBEC on TSUBAME 4.0

Concrete knobs for scaling runs from a laptop / WSL2 box to TSUBAME's H100
nodes without surprises. Covers grid-size budgets, filesystem layout, SLURM
job templates, and the optimisations the simulator already supports.

## Memory and disk budget per grid

Full-resolution Eu-151 spinor state: ψ ∈ ℂ^{n_x × n_y × n_z × 13}.

| n  | ψ (ComplexF64) | ψ (ComplexF32) | snapshot (F32) | 154 snapshots |
| -- | -------------- | -------------- | -------------- | ------------- |
| 32 | 1.7 MB         | 0.85 MB        | 0.85 MB        | 131 MB        |
| 64 | 13.6 MB        | 6.8 MB         | 6.8 MB         | 1.05 GB       |
| 96 | 46 MB          | 23 MB          | 23 MB          | 3.5 GB        |
| 128| 110 MB         | 55 MB          | 55 MB          | 8.4 GB        |
| 192| 372 MB         | 186 MB         | 186 MB         | 28.6 GB       |
| 256| 880 MB         | 440 MB         | 440 MB         | 67.8 GB       |
| 384| 2.97 GB        | 1.49 GB        | 1.49 GB        | 229 GB        |

Approximate run-time memory = ψ_main + ψ_buffers (split-step needs ~5×) +
DDI FFT workspace (~2× padded) + snapshot buffer (~1×). Rough rule:

    RAM_budget ≈ 8 × ψ_ComplexF64  (single-GPU dynamics)

So 256³ needs ~7 GB on the GPU side; an H100 80 GB holds it easily.

H100 SXM (80 GB, 3.35 TB/s HBM3) is the practical target. A100 40 GB
(TSUBAME 3) caps at ~128³ with ComplexF64.

## Filesystem layout

TSUBAME 4.0 exposes:

- `$HOME`          — Lustre, small quota (30 GB), slow metadata
- `$T4_GROUP`      — Lustre group dir, TB-scale, also shared Lustre
- `$T4_LOCAL`/`$T4_TMPDIR` — node-local NVMe, fast per-node
- `/scratch`       — per-node temporary, cleared at job end

Lustre hurts on **many small writes** — the `dynamics/psi_snapshots_streamed/
frame_XXXXX` layout emits one metadata op per frame, which stacks up.

**SpinorBEC knob:**

    export SPINORBEC_SCRATCH_DIR=$T4_TMPDIR

When this env var is set, all `.tmp` JLD2 files are written to the scratch
dir and copied to the final Lustre path only on success. Scratch dir must
already exist or be auto-creatable; if it isn't, the path falls back to
colocated `.tmp`.

## Recommended YAML knobs at scale

```yaml
pipeline:
  - ground_state:
      grid: {n: [128, 128, 128], box: [20.0, 20.0, 20.0]}
      # ... usual settings, backend: cuda ...

  - dynamics:
      duration: 107.6
      dt: 1.0e-4
      save_every: 7000         # → 154 snapshots
      save_psi_snapshots: true # streamed ComplexF32, ~8.4 GB/run at 128³
```

Budget check before you launch:

    julia --project=. -e 'using SpinorBEC;
      println(SpinorBEC.estimate_run_budget("path/to/config.yaml"))'

(`estimate_run_budget` — TODO helper to prints VRAM / host RAM / disk
estimates given the config.)

## SLURM job template (H100 single node)

```bash
#!/bin/bash
#SBATCH --job-name=eu151_edh
#SBATCH --partition=gpu-h100
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x-%j.out

module load cuda/12.4
module load julia/1.12

export SPINORBEC_SCRATCH_DIR=$TMPDIR
export JULIA_NUM_THREADS=4
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

cd $SLURM_SUBMIT_DIR

julia --project=. -e '
  using CUDA, SpinorBEC
  @info "CUDA" dev=CUDA.name(CUDA.device()) mem_gb=CUDA.totalmem(CUDA.device())/2^30
  run_yaml("runs/eu151_edh_ext/config.yaml")
'
```

## Walltime vs. evolution

Rough throughput on H100 at 128³ × 13 spinor:

| Phase              | sec / ω⁻¹ step |
| ------------------ | -------------- |
| split-step         | 0.8–1.2        |
| + DDI              | +0.5           |
| + full tensor (KU) | +2             |

For 128³ × 107.6 ω⁻¹ at dt=1e-4, expect ~2.5 h walltime. Add analyzers as
needed. At 256³, x4 for the grid and ~x1.5 for the larger FFT plan gives
~15 h — use `--time=24:00:00` and provision checkpoints.

## Checkpoint & resume

`run_pipeline` already writes periodic checkpoints to
`$run_dir/.checkpoints/<filename>` during a dynamics step. Restart with:

    julia --project=. -e 'using SpinorBEC; run_yaml("runs/eu151_edh_ext/config.yaml")'

— the cache/resume logic will pick up from the last checkpoint. Pair with
SLURM's `--requeue` for automatic restart after preemption.

## Known gotchas

- **GC pressure on big ψ**: `GC.gc()` between pipeline phases helps when
  running many scan points in sequence.
- **CUDA.memory_status()**: call before a `run_yaml` to catch leftover
  allocations from a previous notebook session.
- **Precompile cache on Lustre**: `~/.julia/compiled/` on home can thrash;
  consider `JULIA_DEPOT_PATH=$T4_LOCAL/.julia` to keep it on node-local.
- **fftw wisdom**: cached in user depot; consistent across nodes but the
  first run on a new CPU model pays the 10–30 s planning cost. Bake a
  wisdom file into `runs/shared/fftw.wisdom` if you hop between generations.
- **Mixed precision (future)**: simulating ψ in ComplexF32 would halve
  VRAM and roughly double throughput, but the split-step accuracy on
  DDI-heavy runs hasn't been validated. Not yet supported.
