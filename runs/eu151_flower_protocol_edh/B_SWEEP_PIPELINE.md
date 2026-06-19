# Eu-151 Flower Protocol — B-Sweep Pipeline (finalized 2026-06-19)

Single canonical pipeline for producing tight LBFGS-converged ground
states across a B grid, used as **waypoints** for the Goto RTP adiabaticity
test and for the broader phase-diagram work.

## Active scripts (the only ones to use)

| File | Role |
|---|---|
| `scripts/flower_protocol_edh/b_sweep_all.jl` | **Canonical pipeline.** Two phases: Phase 1 ITP (rough) → Phase 2 LBFGS (polish). Per-chunk progress bars + cache writes + `progress.json`. |
| `scripts/flower_protocol_edh/b_sweep_status_grid.py` | **Dashboard.** 2D grid showing Phase 1 ITP-step progress + Phase 2 \|grad\| precision per B. Run via `ssh t4 'python3 .../b_sweep_status_grid.py'`. |
| `runs/eu151_flower_protocol_edh/main/submit_b_sweep_all.sh` | UGE submit (h_rt = 8 h, 1 GPU). |

The B grid is **a single source of truth** repeated identically in
`b_sweep_all.jl::B_LIST` and `b_sweep_status_grid.py::B_LIST`. Don't
diverge them.

## B grid (25 points)

```
-10, 0, 10, 20, 30, 40                                  (low-B, 10 μG step)
50, 52, 54, 55, 56, 58, 60, 62, 64, 65, 66, 68, 70      (DDI/Zeeman crossover, 2 μG step)
80, 90, 100, 120, 150, 200                              (high-B, coarse)
```

Rationale: fine grid where the m=−F polarized GS reorganizes against
DDI; coarse where the GS is trivially polarized; thinned at low-B (the
expensive part) because each 5 μG step doesn't add much information.

## Two-phase design

### Phase 1 — ITP coarse (rough → unbiased GS)

- For each B with **no usable cache**: run ITP from `:m_minus_F` initial
  state, dt = 0.01, 30000 steps split into 6 chunks of 5000.
- "No usable cache" = either no file at all, or only a stalled
  `phase1-ITP` record with `iter < 30000`. A polish cache OR a non-ITP
  LBFGS cache (any prior LBFGS-touched ψ) is preserved untouched.
- Output: `lbfgs_<B>uG_final_psi.jld2` with `method = "phase1-ITP …"`
  and `grad_norm = Inf` sentinel (ITP doesn't measure it).

### Phase 2 — LBFGS polish (rough → tight)

- For each B not yet at `LBFGS_TOL = 5e-4`: run chunked LBFGS
  (CHUNK = 100, cap 30 × 100 = 3000 iter), tol = 5e-4, m = 20,
  Sobolev α = 0.5.
- **Seed = the better of `final` and `polish` slots** (`best_cached_psi`).
  So pre-existing polish ψ (from the deprecated `b_sweep_polish.jl`
  outputs) is reused when it beats the primary slot.
- Floor detector: windowed range-ratio (window = 6 chunks); if
  `max/min < 1.5` we declare the optimizer stuck at numerical floor and
  move to the next B. Prevents 70 μG-style 3-h burn near minimum.
- Output: overwrites `lbfgs_<B>uG_final_psi.jld2` with `method =
  "phase2-LBFGS …"` and the real `grad_norm`.

## Dashboard symbols

```
.    no cache (this B will/has-been processed by Phase 1)
?    cache exists, but no LBFGS measurement (Phase 1 done, Phase 2 pending)
blank cache exists but coarser than this row's threshold
@    at this threshold (or tighter)
```

Phase 1 rows show ITP step thresholds (≥5k, ≥10k, ≥15k, ≥20k, ≥25k, 30k).
Phase 2 rows show \|grad\| thresholds (1e-1, 1e-2, 1e-3, 5e-4, 1e-4, 5e-5).

## Cache files on Tsubame

```
$FPE_ROOT/lbfgs_<B>uG_final_psi.jld2     ← primary, written by b_sweep_all
$FPE_ROOT/lbfgs_<B>uG_polish_psi.jld2    ← legacy (b_sweep_polish output);
                                            read-only fallback seed.
$FPE_ROOT/b_sweep_all_progress.json      ← live single-B progress snapshot
$FPE_ROOT/logs/b_sweep_all.o<jobid>      ← per-chunk progress-bar log
```

`$FPE_ROOT` defaults to `/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh`.

## Submit

```bash
ssh t4 'cd ~/bec-simulation && qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_b_sweep_all.sh'
```

8-hour wall. Phase 1 is skipped wherever cache already exists, so a
single 8-hour job typically completes Phase 1 for the few fresh B and
then advances Phase 2 across ~10 B points. Repeated re-submission picks
up from where the last job left off (per-chunk cache writes survive job
boundaries).

## Deprecated scripts (kept for history)

| File | Replaced by |
|---|---|
| `scripts/flower_protocol_edh/b_sweep_lbfgs_tight.jl` | `b_sweep_all.jl` (two-phase + clearer skip rules) |
| `scripts/flower_protocol_edh/b_sweep_polish.jl` | Phase 2 of `b_sweep_all.jl` |
| `scripts/flower_protocol_edh/monitor_b_sweep_tight.sh` | `b_sweep_status_grid.py` |
| `runs/eu151_flower_protocol_edh/main/submit_b_sweep_lbfgs_tight.sh` | `submit_b_sweep_all.sh` |
| `runs/eu151_flower_protocol_edh/main/submit_b_sweep_polish.sh` | `submit_b_sweep_all.sh` |

The deprecated outputs (especially `lbfgs_<B>uG_polish_psi.jld2` files)
are still consulted by `b_sweep_all` as fallback seeds, so the
historical compute investment is preserved.
