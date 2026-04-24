# Session Handoff — 2026-04-25 @ commit `3414228`

Follow-up to `docs/session_handoff_2026-04-24.md`. This session closed out
the Phase 4/5 primitives backlog and launched a long-running phase-diagram
scan that should complete overnight.

## Detached long-running processes

```
PID 312389  SID 312389  → overnight batch (4 runs, ~18–20 h total) → logs/batch_overnight.log
PID 82239   SID 82239   → dashboard serve_dashboard(8765)           → logs/dashboard.log
```

### Overnight batch breakdown
Scripts/run_batch_overnight.jl runs these in sequence; progress with banners:

1. `klaus2022_full`         — Dy164 vortex-stripe reproduction (~45 min)
2. `eu151_sgpe_thermal`     — finite-T ensemble, 12 scan points (~1.2 h)
3. `eu151_kibble_zurek`     — quench τ × seed scan, 15 points (~6 h)
4. `eu151_phase_pq_hires`   — 64³ (p,q) phase map, 12×12 = 144 pts (~11 h)

Both are session leaders (`PID == SID`), so SIGHUP from Claude's shell
does not reach them. Health check:

```bash
ps -o pid,ppid,sid,etime,cmd -C julia
tail -f logs/eu151_phase_pq_hires.log
ls runs/eu151_phase_pq_hires/point_*.jld2 | wc -l   # progress counter
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv
```

Resume on crash / reboot:

```bash
setsid nohup bash -c 'LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. scripts/run_phase_pq_hires.jl' \
  > logs/eu151_phase_pq_hires.log 2>&1 < /dev/null &
disown
```

`run_yaml` is resumable — already-written `point_NNN.jld2` are skipped.

## Running config

`runs/eu151_phase_pq_hires/config.yaml` — 64³ Eu151 (p, q) 2D phase map.

- 12×12 = 144 scan points (up from 5×5 at 32³ in `runs/eu151_phase_pq/`).
- Per-point: ITP 10000 / dt=0.005 → LBFGS 300 steps / tol=1e-9 →
  phase_classify + bogoliubov(k_max=8, n_k=100, n_directions=30).
- Smoke rate: 50 ITP steps/s → point ≈ 4.5 min → 144 × 4.5 ≈ **10.8 h**.
- Axes:
  - `p` ∈ {0, 0.1, 0.3, 1, 2, 3, 5, 10, 30, 100, 200, 500} (log-ish)
  - `q` ∈ {-3, -1.5, -1, -0.5, -0.3, -0.1, 0, 0.3, 0.5, 1, 1.5, 3}
- Output: `runs/eu151_phase_pq_hires/point_001.jld2` … `point_144.jld2`,
  each ≈ 52 MB (ψ at ComplexF64). Total ≈ 7.5 GB.

## Commits pushed this session (on `main`)

```
da36f9d fix(analyze): defect_density vortex detection on 3D grids
59a52a1 fix(raman): GPU-safe apply_uniform_spin_rotation! via single D×D matmul
3414228 feat(solver): SGPE — stochastic projected Gross–Pitaevskii
6359b78 feat(workflow): lab calibration layer apply_calibration!
dc96eca feat(loss): spin-dependent three-body K₃^(m) per component
ae17e07 feat(analyze): pipeline-level topology + droplet_profile analyzers
```

The raman.jl fix unblocked the entire magnetostir / tilted-field path on
the GPU (Level 1/2 Zeeman with non-zero Bx/By). Klaus 2022 reproduction
now runs end-to-end on CUDA; previously every dynamics step with a
transverse Zeeman field hit a scalar-indexing error.

Phase 4/5 primitives inventory:

| # | Feature | Status |
|---|---|---|
| #1 | Topology analyzers wired to pipeline | ✅ |
| #2 | Spin-dependent K₃^(m) three-body loss | ✅ |
| #3 | Calibration layer `apply_calibration!` | ✅ |
| #4 | SGPE stochastic projected GPE | ✅ |
| #5 | Projected GP (already existed, survey was wrong) | ✅ |
| #6 | Self-bound droplet analyzer + `runs/eu151_droplet/` config | ✅ |

## Remaining plan items (next session)

See the plan doc in chat history or `PLAN.md`.

- **#51 Two-component immiscible GP** (~500 lines, explicitly deferred)
- **#53 Synthetic dimension** observables (~200 lines)
- **#67 Live monitoring socket** (~300 lines)
- **#68 Trap drift correction** (~200 lines, follow-on to calibration)
- **Phase 1.1**: named state builders (`init_psi_biaxial_nematic`, …) ~400 lines
- **Phase 6**: ~20 YAML scenario samples for features already implemented
- Out of scope per plan: #61 Bayesian / #62 differentiable / #63 NQS

## Pitfalls caught this session

- `_to_device(::CUDABackend, ::Array)` requires `import CUDA` **before**
  `using SpinorBEC` so the extension is loaded. Scripts that use CUDA
  backend must start with `import CUDA; using SpinorBEC`.
- Piping long-running Julia stdout through `tail -N` in a shell buffers
  everything until EOF — use a direct file redirect (`> logfile 2>&1`)
  for detached runs.
- Survey agent incorrectly flagged Projected GP and photon-heating as
  "missing" — both exist at `src/solvers/projected_gp.jl` and
  `src/solvers/photon_heating.jl`. Always grep `src/solvers/` before
  starting new solver implementations.
