# TSUBAME dev workflow

Day-to-day workflow for editing, testing, and submitting SpinorBEC runs
on TSUBAME 4.0 (or any SLURM + CUDA cluster). Pairs with
`docs/tsubame_scaling.md` for the per-grid-size budget.

## One-time setup

```bash
# On a login node:
ssh tsubame
cd $T4_GROUP/work     # or wherever you keep code (NOT $HOME — 30 GB quota)
git clone git@github.com:anko9801/BEC-simulation.git
cd BEC-simulation

# Bootstrap once on a login node so the depot is on Lustre but cached
source scripts/tsubame_setup.sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

The first `Pkg.instantiate()` populates `$JULIA_DEPOT_PATH` (which
`tsubame_setup.sh` points at node-local NVMe inside compute jobs, but
falls back to `~/.julia` on login nodes). The first GPU run on a compute
node will trigger CUDA precompile (~30 s) — this lands in the
node-local depot and persists for that node's job lifetime.

## Edit-test-submit loop

```bash
# 1. Edit on the login node
$EDITOR runs/eu151_edh_ext/config.yaml

# 2. Dry-run check (verifies calibration applied, schema OK)
julia --project=. -e '
    using SpinorBEC
    run_yaml("runs/eu151_edh_ext/config.yaml"; dry_run = true)
'

# 3. Budget + suggested SLURM flags
julia --project=. scripts/slurm_helpers.jl sbatch-suggest \
    runs/eu151_edh_ext/config.yaml

# 4. Submit (single H100, 12 h)
sbatch scripts/slurm/eu151_h100_single.sbatch runs/eu151_edh_ext/config.yaml

# 5. Watch
squeue -u $USER
tail -f logs/spinorbec-*.out
```

For phase-diagram scans where points are independent:

```bash
# Count scan points
julia --project=. scripts/slurm_helpers.jl count runs/foo/config.yaml
# → 144

# Submit array job (12 in flight at once)
sbatch --array=1-144%12 scripts/slurm/scan_array.sbatch runs/foo/config.yaml

# Each task writes runs/foo/point_NNN.jld2; resumable if a task fails
# (re-submitting skips cached files).
```

## Singularity image (alternative)

If your TSUBAME group doesn't have julia/1.11 module loaded, build the
container once:

```bash
cd $T4_GROUP/work
singularity build --fakeroot spinorbec.sif /path/to/BEC-simulation/containers/spinorbec.def

# Bind project + runs/ at use time
singularity exec --nv \
    --bind /path/to/BEC-simulation:/work \
    spinorbec.sif julia --project=/work -e '
        using SpinorBEC
        run_yaml("/work/runs/eu151_edh_ext/config.yaml")
    '
```

The `%post` block pre-warms a depot inside the image so first-time
precompile of FFTW / CUDA / etc. is amortised at build time.

## Live monitoring from your laptop

The dashboard runs on the compute node — to view it from your laptop,
SSH-tunnel through the login node:

```bash
# On laptop
ssh -L 8765:cnode-h100-12:8765 tsubame

# In another terminal on TSUBAME compute node (via srun --pty bash):
julia --project=. -e 'using SpinorBEC; serve_dashboard(8765)' &

# Then on laptop, browse to http://localhost:8765
```

For lab-image push (the `/api/lab/image/<run>` POST endpoint added in
commit 82d6654), use the same tunnel:

```bash
curl --data-binary @absorption_shot.png \
    http://localhost:8765/api/lab/image/today
```

## Resuming after preemption

`#SBATCH --requeue` lets SLURM auto-restart a preempted job; SpinorBEC's
checkpoint logic in `find_ground_state` resumes from the last
`.checkpoints/itp_checkpoint.jld2`. For finished scan points, files in
`runs/<run>/point_NNN.jld2` cause `run_yaml` to skip those points
entirely on the next attempt.

For multi-attempt runs that mix crashes + preemption:

```bash
sbatch scripts/slurm/eu151_h100_single.sbatch runs/foo/config.yaml
# vs the supervisor pattern (handles arbitrary crashes too):
scripts/supervised_run.sh foo 5    # 5 retries with 30 s backoff
```

The supervisor wrapper is overkill on SLURM (--requeue covers most
cases) but useful on interactive sessions where you don't want to
babysit.

## Troubleshooting

| symptom | likely cause | fix |
|---|---|---|
| First run is very slow (~10 min before any output) | precompile on Lustre | confirm `$JULIA_DEPOT_PATH` points at NVMe (`echo $JULIA_DEPOT_PATH` after sourcing) |
| `unable to load CUDA driver` | module not loaded | `source scripts/tsubame_setup.sh` first |
| `ENOSPC` mid-run | streamed snapshots filled `$T4_TMPDIR` | increase `--gres=gpu:h100:1,nvme:NN` or smaller `save_psi_snapshots` cadence |
| Job killed at exact wall-clock limit | `--requeue` not set | re-submit; SLURM resumes from checkpoint |
| Phase-diagram scan progresses one-at-a-time | not using array job | switch to `scan_array.sbatch` with `--array=1-N%K` |
