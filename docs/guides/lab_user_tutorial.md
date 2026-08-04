# Lab user tutorial

End-to-end walkthrough for running a SpinorBEC simulation that mirrors a day-in-the-lab experiment: load calibration, write the YAML in lab units, run, analyze, plot. Assumes you have a working install (`julia --project=. -e 'using Pkg; Pkg.instantiate()'`).

---

## 1. Capture today's calibration

After the morning calibration run, write the constants either to a single YAML or append to a CSV history. Both work; CSV is Excel-friendly.

`runs/lab/calibration_history.csv` (example):

```csv
date,coil_strong_gauss_per_mv,coil_strong_gauss_offset,coil_weak_gauss_per_mv,coil_weak_gauss_offset,fort_x_hz,fort_y_hz,fort_z_hz,microwave_rad_per_s_per_mw
2026-04-15,0.42,0.04,0.038,0.003,443.0,443.0,596.0,1.18e6
2026-04-22,0.41,0.05,0.040,0.002,447.0,447.0,598.0,1.20e6
```

Append a row each calibration day. SpinorBEC will linearly interpolate between rows when `target_date:` is set.

## 2. Write the experiment YAML in lab units

`runs/today/config.yaml` (example):

```yaml
calibration_history:
  - {date: "2026-04-15", coil_strong: {gauss_per_mv: 0.42, gauss_offset: 0.04}, fort: {sqrt_coeffs_hz: [443, 443, 596]}, microwave: {rad_per_s_per_mw: 1.18e6}}
  - {date: "2026-04-22", coil_strong: {gauss_per_mv: 0.41, gauss_offset: 0.05}, fort: {sqrt_coeffs_hz: [447, 447, 598]}, microwave: {rad_per_s_per_mw: 1.20e6}}

target_date: "2026-04-25"        # interpolated → today's effective constants

pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [20.0, 20.0, 20.0]}
      interactions: {N_atoms: 50000, omega_ref: 691.15, c1_ratio: 0.028}
      ddi: {enabled: true}
      B:
        p_mv: 2.5             # ← knobs on your driver, not Gauss
        coil_mode: strong
        q: 0.1
      potential:
        type: harmonic
        fort_power_mw: [50, 50, 100]   # ← FORT power on your AOMs, not Hz
      dt: 0.005
      n_steps: 10000
      tol: 1.0e-7
      initial_state: polar
      backend: cuda

  - dynamics:
      duration: 5.0
      dt: 0.005
      save: {every: 100}          # NOT `save_every:` — folded into `save:`
      save:
        psi: true
        precision: "f32"
      interactions: {omega_ref: 691.15}
      zeeman:
        p_mv: {from: 2.5, to: 0.5}
        coil_mode: strong
        q: 0.1

  - analyze:
      - phase_classify: {}
      - droplet_profile: {}
      - column_density_movie: {axis: 3, output_dir: runs/today/frames}
      - summary_json: {path: runs/today/summary.json}
```

## 3. Dry-run preview

Before kicking off a long compute, check the calibration expanded correctly:

```julia
import CUDA
using SpinorBEC

run_yaml("runs/today/config.yaml"; dry_run = true)
```

Output is the post-calibration YAML printed to stdout. Verify `zeeman.p` has become a `"X Gauss"` string and `potential.omega` is now a list of `"Y Hz"` strings.

## 4. Estimate the run budget

```julia
estimate_run_budget("runs/today/config.yaml")
```

Prints VRAM / host RAM / disk estimates so you don't accidentally OOM the GPU.

## 5. Run

Foreground (you wait):

```julia
run_yaml("runs/today/config.yaml"; verbose = true)
```

Detached (overnight, survives Claude session close):

```bash
setsid nohup bash -c '
  LD_LIBRARY_PATH=/usr/lib/wsl/lib \\
  julia --project=. -e "
    import CUDA; using SpinorBEC;
    run_yaml(\"runs/today/config.yaml\"; verbose=true)
  "' > logs/today.log 2>&1 < /dev/null &
disown
```

Verify with `ps -o pid,sid,etime,cmd -C julia` — `PID == SID` means session leader, survives shell close.

## 6. Watch progress

```bash
tail -f logs/today.log
ls runs/today/frames/        # columns.jld2 + manifest.json after analyze step
```

If you opened the dashboard (`serve_dashboard(8765)`), the run shows up under the active runs list and the 3D viewer streams snapshots.

## 7. Analyze offline

After the run finishes, `runs/today/` (example) contains:

- `<run_name>.jld2` — full ψ + analyzer outputs per scan point
- `frames/columns.jld2` — Float32 column densities, key `frame_NNNNN`
- `frames/manifest.json` — frame metadata (`n_frames`, `times`, `axis`, …)
- `summary.json` — text summary of energies, norms, defect counts
- `_live_status.json` — present if `dynamics.live_monitor` was set
- `dynamics/` (inside .jld2) — streamed snapshot frames + populations
- `analyze/<analyzer>/<field>` (inside .jld2) — every analyzer's outputs

Re-analyze without re-running:

```julia
using JLD2
d = jldopen("runs/today/<run>.jld2", "r") do f
    Dict(k => f[k] for k in keys(f))
end

# Accessing analyzer outputs
phase = d["analyze/phase_classify/phase"]
n_peak = d["analyze/droplet_profile/n_peak"]
```

## 8. Common patterns

- **Parameter scan**: add a `scan: {product: {pipeline.0.zeeman.p: [...]}}` block; `run_yaml` writes one .jld2 per point and skips existing ones on re-run. See `docs/guides/pipeline_cookbook.md`.
- **Resume**: just rerun `run_yaml`. Cached point files are skipped.
- **Single-point rerun**: `julia --project=. REPL: run!(Experiment(yaml); force=true) <run_name>` cleans the .checkpoints/ but preserves completed point_NNN.jld2.
- **Resumable batch**: wrap a sequence of `run_yaml` calls in a `try/catch` so one failure doesn't kill the rest. Each call is already idempotent (cached point files are skipped).

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `Scalar indexing is disallowed` on dynamics | Zeeman with non-zero Bx/By on GPU on a pre-fix install | upgrade to ≥ commit 59a52a1 (`apply_uniform_spin_rotation!` matmul path) |
| ITP `NaN at step 1` | dt too large for ε_dd > 1 (Dy164, Eu151 strong DDI) | drop dt to 0.002 |
| `column_density_movie ... done` writes 0 frames | `save: {psi: true}` + pre-fix analyzer | upgrade to ≥ 3685fd7 (streamed-snapshot reader); since 2026-04-26 the analyzer writes `columns.jld2` + `manifest.json` (no PNGs) |
| Long scan OOMs at point ~100 | scan-loop GPU memory leak | upgrade to ≥ 7769d84 (CUDA.reclaim hook) |
| `unknown key 'a_s'` warning | scattering length parsing | use `c_total:` or `c1_ratio:` directly |
| `unknown key 'trap'` warning | shorthand notation | harmless, equivalent to `potential: {type: harmonic, omega: [...]}` |

## Where to look next

**More patterns:** `docs/guides/pipeline_cookbook.md` (recipes by scenario), `runs/samples/` (example) (6 runnable scenarios — quench, droplet+SGPE, Feshbach, lab-cal, SOC, pulse-Rabi).

**Looking something up:** `docs/reference/yaml_schema_reference.md` for every accepted YAML key.

**Repo conventions:** `CLAUDE.md`.
