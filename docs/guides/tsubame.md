# Running SpinorBEC on TSUBAME 4.0

Day-to-day workflow + scaling knobs for TSUBAME 4.0 (Altair Grid Engine / UGE + CUDA).

## One-time setup

```bash
ssh tsubame
cd $T4_GROUP/work     # NOT $HOME — only 30 GB quota there
git clone git@github.com:anko9801/BEC-simulation.git
cd BEC-simulation

source scripts/tsubame_setup.sh   # module load + depot + scratch + threads
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

`scripts/tsubame_setup.sh` exports `JULIA_DEPOT_PATH=$T4_TMPDIR/.julia`
(node-local NVMe to avoid Lustre metadata storms),
`SPINORBEC_SCRATCH_DIR=$T4_TMPDIR/spinorbec_snaps` (streamed snapshot
scratch), `JULIA_NUM_THREADS` sized from `$NSLOTS` (UGE slot count;
falls back to 4), and runs `module load cuda + julia`. Falls back
gracefully on dev machines without `$T4_TMPDIR`.

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

## Pre-flight

```bash
source scripts/tsubame/preflight.sh          # or --gpu for a CUDA job
```

Four environment requirements have each cost a whole job batch, and all four were
already documented — two of them in this file. Reading them did not prevent it, so
they are now asserted at second zero with the fix in the message: BLAS threads
pinned, project root off `$HOME`, group-volume headroom, `runs/` present, and (for
`--gpu`) the `import CUDA` ordering. The script says why for each.

## Filesystem layout

| path                   | type                | use                        |
|------------------------|---------------------|----------------------------|
| `$HOME`                | Lustre, **25 GB** quota | tiny (no project dirs) — measured 2026-08-01 with `t4-user-info disk home`; the 30 GB here was wrong and a batch died on it |
| `$T4_GROUP`            | Lustre, TB-scale    | code + finalised results   |
| `$T4_LOCAL`/`$T4_TMPDIR` | node-local NVMe   | depots, scratch snapshots  |
| `/scratch`             | per-node, ephemeral | cleared at job end         |

Lustre is bad at many small writes; `dynamics/psi_snapshots_streamed/frame_NNNNN` emits one metadata op per frame, which stacks. `SPINORBEC_SCRATCH_DIR=$T4_TMPDIR` redirects `.tmp` files to NVMe and copies to Lustre on success.

## Edit-test-submit loop

```bash
$EDITOR runs/eu151_edh_ext/config.yaml

# Dry-run check (calibration applied? schema OK?)
julia --project=. -e 'using SpinorBEC; run_yaml("runs/eu151_edh_ext/config.yaml"; dry_run=true)'

# Preview the rendered qsub script (no submission):
julia --project=. -e 'using SpinorBEC;
    print(render_uge_script("default", "runs/eu151_edh_ext/config.yaml";
        project_root=pwd(), log_dir="logs/tsubame"))'

# Submit through the autopilot (renders the qsub script on the fly):
julia --project=. scripts/cli.jl autopilot enqueue runs/eu151_edh_ext/config.yaml
julia --project=. scripts/cli.jl autopilot tick    # dispatches via UGEBackend

# Or submit a single config directly:
julia --project=. -e '
    using SpinorBEC
    b = UGEBackend(; ssh_host="tsubame", project_root="...", remote_runs_root="...")
    e = enqueue!(Experiment("runs/eu151_edh_ext/config.yaml"))
    dispatch!(b, e)
'

qstat -u $USER
tail -f logs/spinorbec-*.out
```

On TSUBAME the autopilot auto-registers a `UGEBackend` from the
`SPINORBEC_TSUBAME_{HOST,PROJECT_ROOT,RUNS_ROOT,GROUP,JULIA,DEPOT,SYSIMAGE,CUDA_MODULE,SYNC_CODE}`
env vars (the HOST/PROJECT_ROOT/RUNS_ROOT triple is required; the rest
default). The qsub resource directives live in `UGE_PROFILE_DIRECTIVES`
in `src/workflow/autopilot/backends_uge.jl` (`default` / `node_h` /
`node_f` / `gpu_1` / `long_q`) — edit there to tune walltime / node
class. Profiles escalate on OOM/TIMEOUT via the `next_profile` chain
(see `docs/guides/autopilot.md`). Note: `-g <group>` is passed as a
qsub CLI flag, not an `#$ -g` directive (the TSUBAME4 wrapper rejects
the directive form).

### Array jobs (multi-point scans)

```bash
julia --project=. -e 'using SpinorBEC; println(scan_point_count(ARGS[1]))' \
    runs/foo/config.yaml   # → 144
```

For an array submission, add `#$ -t 1-N` + `#$ -tc K` to the rendered
script — extend `UGE_PROFILE_DIRECTIVES` with a new `"scan_array"`
profile carrying the array directive, or pipe `render_uge_script`
output through `sed`. Each task writes `runs/foo/point_NNN.jld2` (example);
resumable — re-submitting skips cached files (`SPINORBEC_SCAN_ONLY_INDEX`
env var inside `_run_yaml_scan`).

### Manual per-job qsub script

The autopilot's `UGEBackend` renders this shape automatically via
`render_uge_script`. To submit by hand (`qsub` / `qstat` / `qdel`),
use a per-job script of the form:

```bash
#!/bin/bash
#$ -cwd
#$ -l h_rt=06:00:00
#$ -l f_node=1
#$ -N spinor_run
#$ -o logs/tsubame/$JOB_NAME_$JOB_ID.log
#$ -j y

. /etc/profile.d/modules.sh
source scripts/tsubame_setup.sh
export SPINORBEC_SCRATCH_DIR=$T3TMPDIR

# Name the binary. There is NO julia modulefile on TSUBAME 4 — `module load
# julia` fails and `tsubame_setup.sh` swallows it, so a bare `julia` in a UGE
# job dies with "command not found". A login shell only works because the
# lab profile puts the shared juliaup on PATH, which qsub does not inherit.
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

# Sysimage support (optional):
SYSIMAGE_FLAG=""
[ -f "spinor_sysimage.so" ] && SYSIMAGE_FLAG="--sysimage=spinor_sysimage.so"

"$JULIA" --project=. $SYSIMAGE_FLAG scripts/cli.jl launch <run_name>
```

For a project tree synced fresh (a new `$HOME/<name>` rather than an
established one), also point the depot at the warm shared one —
`export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia` **before**
sourcing `tsubame_setup.sh`, which otherwise defaults it to node-local NVMe and
precompiles SpinorBEC from an empty cache. `tsubame_setup.sh` only sets the
depot when it is unset, so the export wins.

Add `#$ -t 1-N` + `#$ -tc K` for array jobs; `mapfile -t CONFIGS < <(ls -d runs/<batch>/*/ | sort)`
then `RUN_NAME="${CONFIGS[$((SGE_TASK_ID - 1))]}"` to pick the per-task
config.

The autopilot ships two backends: `LocalBackend` (subprocess on the
current host) and `UGEBackend` (TSUBAME / Altair Grid Engine over SSH).
TSUBAME 4 dispatch goes through `UGEBackend`; the manual script above is
only needed for ad-hoc one-offs outside the queue.

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
    /path/to/BEC-simulation/scripts/spinorbec.def

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

# compute node (interactive via qrsh)
julia --project=. -e 'using SpinorBEC; serve_dashboard(8765)' &

# laptop browser → http://localhost:8765
```

Lab-image push uses the same tunnel: `curl --data-binary @absorption_shot.png http://localhost:8765/api/lab/image/today`.

## Checkpoint and resume

`run_pipeline` writes periodic checkpoints to `$run_dir/.checkpoints/<filename>` during a dynamics step. Restart with the same `run_yaml(...)` call — the cache/resume logic picks up from the last checkpoint. Pair with a rerunnable job (`#$ -r y`) for automatic restart after preemption.

For multi-attempt mixes of crashes + preemption: enqueue via
`julia --project=. scripts/cli.jl autopilot enqueue runs/foo/config.yaml` (example)
and let the autopilot's `retry_failed!` (called per-tick by the systemd
timer) handle re-dispatch with profile escalation on OOM/TIMEOUT.

## High-res scan inventory (target table for `runs/tsubame_scan/` (example))

Generate the YAMLs via the sweep API (see `docs/guides/experiment_api.md`)
on `runs/klaus_eu151_v2_full/config.yaml` (gone) as the template:

### Dy164 (3 configs)
| name | grid | duration | est. wall (H100) |
|---|---|---|---|
| `dy164_klaus_500ms`            | 48×48×24 | 500 ms  | 4–5h |
| `dy164_klaus_1000ms`           | 48×48×24 | 1000 ms | 8–9h |
| `dy164_klaus_64cube_200ms`     | 64×64×32 | 200 ms  | 4–5h |

### Eu151 (8 configs)
| name | grid | duration | est. wall (H100) |
|---|---|---|---|
| `eu151_full_500ms_48cube`      | 48×48×24 | 500 ms  | 3–4h |
| `eu151_full_1000ms_48cube`     | 48×48×24 | 1000 ms | 6–7h |
| `eu151_no_ddi_500ms_48cube`    | 48×48×24 | 500 ms  | 3–4h |
| `eu151_p_300_48cube`           | 48×48×24 | 500 ms  | 3–4h |
| `eu151_p_3000_48cube`          | 48×48×24 | 500 ms  | 3–4h |
| `eu151_c1_FM_48cube`           | 48×48×24 | 500 ms  | 3–4h |
| `eu151_c1_AFM_48cube`          | 48×48×24 | 500 ms  | 3–4h |
| `eu151_full_64cube_200ms`      | 64×64×32 | 200 ms  | 3–4h |

All configs use `epsilon: 1.0e-6` per the audit finding (Y6 ε=1e-3
silently fails for `p·F·dt > 300` in Klaus regime — see
`docs/archive/thesis_batch_audit_2026-04-28.md` and the
`gotcha_K3_routing_pre_2026_05_13` memory note).

Total budget: 11 jobs × ~5h average = 55 GPU-hours; ~14h wall clock
with 4-way concurrency. Disk: psi_snapshots at 48³ × D=13 × ComplexF64
× ~60 frames ≈ 200 MB / run.

### Pulling results back

```bash
rsync -av --include='*.jld2' --include='*/' --exclude='*' \
    user@login.t3.gsic.titech.ac.jp:/gs/bs/$USER/SpinorBEC.jl/runs/tsubame_scan/ \
    runs/tsubame_scan/

# REPL audit:
julia --project=. -e '
    using SpinorBEC
    exps = [Experiment(p) for p in
            sort(filter(endswith(".yaml"), readdir("runs/tsubame_scan"; join=true)))]
    tab = tabulate(exps, [norm_drift, Fz_t, per_m_t])
'
```

### Pre-submit checklist

1. **`dy164_main_eps1e6` parity**: if local ε=1e-6 result still shows
   m=+F: 1.0→1.0 frozen, the Dy164 Klaus reproduction is real (just
   deeply adiabatic); fine to submit. If it differs, the original was
   a numerical artifact — investigate before committing TSUBAME hours.
2. **Project.toml + Manifest.toml** must match TSUBAME's Julia
   version. Add a compatible version or pin to 1.12 via juliaup.
3. **CUDA driver compat**: `nvidia-smi` on the cluster must report a
   driver compatible with the `module load`'d CUDA toolkit.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| First run very slow (~10 min before any output) | precompile on Lustre | confirm `$JULIA_DEPOT_PATH` points at NVMe (`echo $JULIA_DEPOT_PATH` after sourcing) |
| `unable to load CUDA driver` | module not loaded | `source scripts/tsubame_setup.sh` first |
| `ENOSPC` mid-run | streamed snapshots filled `$T4_TMPDIR` | bigger `nvme:NN` or coarser `save.psi` cadence |
| Job killed at exact wall-clock limit | job not rerunnable | re-submit (or `#$ -r y`); resumes from checkpoint |
| Phase-diagram scan progresses one-at-a-time | not using array job | switch to a `scan_array` profile with `#$ -t 1-N -tc K` |
| GC pressure on big ψ across many scan points | implicit retention | `GC.gc()` between phases; `CUDA.memory_status()` to inspect |
| FFTW wisdom replanning on each new node | wisdom not shared | bake wisdom into `runs/shared/fftw.wisdom` (example) if hopping CPU generations |
