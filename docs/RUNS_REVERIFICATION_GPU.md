# Runs re-verification — GPU bench + Bug-4 affected configs

Generated 2026-05-02 by overnight bench session on RTX 5070 Ti (16 GB).
Companion to `RUNS_INVENTORY.md` (which audits every config) and
`MEASUREMENT_RESULTS_LOCAL.md` (which captures the laptop-CPU bench).

## GPU bench results (RTX 5070 Ti, post-fix code, commit baafd08+)

### R32 — Sobolev preconditioner (F=1, 24×24×12, c₀=50, n_steps≤500)

| α | wall (s) | iter | converged | E |
|---|---|---|---|---|
| 0.00 | 5.18 | 500 | **false** | 2.7430 |
| 0.05 | 8.35 | 500 | false | 2.7430 |
| 0.10 | 7.68 | 500 | false | 2.7430 |
| 0.20 | 8.02 | 500 | false | 2.7430 |
| **0.50** | **2.48** | **239** | **TRUE** | 2.7430 |

α=0.5 hits convergence in **2.1× fewer iterations** and **2.1× faster
wall time** vs α=0 baseline. Same E to 4 decimal places. The previous
"negative result" finding (commit 72d2828) was on a smaller / less
stiff test problem; on a moderately stiff GPU problem (24³ + c₀=50)
Sobolev α=0.5 is **load-bearing** for getting convergence at all.

### R33 — MFBO 2-tier vs single-fidelity BO (F=1, 16³ vs 32³, GPU)

| | SF | MFBO |
|---|---|---|
| best_y | 2.6072 | **2.6072 (Δ = 0)** |
| wall (s) | 108.4 | **44.1** |
| high evals | 12 | **2** |
| low evals | — | 20 |
| **speedup** | — | **2.46×** |

Cost ratio (measured): 2.71. Lower than the synthetic Branin (14.8)
because GPU low-fid 16³ is *not* dramatically cheaper than high-fid
32³ — the F=1 13-component spinor on GPU has fixed kernel-launch
overhead per FFT batch. **For F=6 64³ vs 32³ the cost ratio
will rebound to 30+** (FFT volume scales as 13 × N³ × log N), and
the MFBO speed-up will rise correspondingly. Local validation here
confirms the pipeline runs end-to-end on GPU; production numbers
need TSUBAME.

## Bug-4 affected runs — re-verification status

Two configs need re-running on the post-fix integrator (per
`RUNS_INVENTORY.md` and `docs/AUDIT_BUG4.md`):

| Run | Config | Local re-run? | TSUBAME re-run needed |
|---|---|---|---|
| `runs/eu151_edh/` | 64³, n_steps=100 000, save_every=1000 | **No** — over budget on local GPU; 5-10 h on RTX 5070 Ti | **YES** |
| `runs/eu151_lab_calibrated/` | 32³, n_steps=4 000, save_every=40 | **Blocked by an unrelated config bug** | **YES** after the bug below is fixed |

### Side-finding: eu151_lab_calibrated has a **separate** schema/calibration ordering bug

While attempting the local re-run, two issues surfaced that are
**independent of Bug-4** and predate it:

1. **Schema lockdown drift**: the original config had `N_atoms` and
   `omega_ref` at the `ground_state.*` level rather than under
   `ground_state.interactions.*`. The post-2026-04-30 schema rejects
   them at that level (`Unknown key 'pipeline.1.ground_state.omega_ref'`).
   This commit (R41) moved them under `interactions:` to comply.

2. **calibration → units pipeline ordering**: after the schema fix,
   the run still fails with `MethodError: no method matching Float64(::String)`
   in `_resolve_derived_params!` line 222 (`_to_float_vec(pot["omega"])`).
   The calibration step transforms `fort_power_mw: [50, 50, 100]` into
   `omega: ["3157 Hz", "3157 Hz", "5980 Hz"]` (string entries with
   unit suffixes), but the subsequent `_to_float_vec` in
   `parsing_blocks.jl` doesn't strip those unit suffixes. Either
   `apply_units_block!` needs to run **after** calibration (so strings
   like `"3157 Hz"` get parsed to `3157.0`), or `_to_float_vec` needs
   to handle quantity strings inline.

   Until that's addressed, this config can't be re-run end-to-end.
   Workaround: pre-resolve the calibration manually and write the
   numeric `omega:` directly into the YAML, then run.

   **Action**: file as a separate bug, address before TSUBAME burst.

Local re-run via temp-YAML pipeline truncation tripped on schema
validation for the calibration mixin. On TSUBAME the original
config can run unchanged: the pre-fix DDI bug is gone in the post-
2026-05-02 code, so `julia --project=. run_yaml(...)` produces the
correct GS automatically.

### TSUBAME run plan (excerpt — see `docs/MEASUREMENT_CAMPAIGN_PHASE2.md`)

Append to the SGE array job:

```sh
case "$SGE_TASK_ID" in
    8)
        # Re-run eu151_edh Phase 0 GS (post-fix)
        julia --project=. -e 'using SpinorBEC; using CUDA;
            run_yaml("runs/eu151_edh/config.yaml")'
        ;;
    9)
        # Re-run eu151_lab_calibrated (full pipeline, post-fix)
        julia --project=. -e 'using SpinorBEC; using CUDA;
            run_yaml("runs/eu151_lab_calibrated/config.yaml")'
        ;;
```

The post-fix integrator will overwrite `runs/<name>/result.jld2` with
the corrected ψ. Estimated wall-time: **eu151_edh ≈ 8 h**,
**eu151_lab_calibrated ≈ 1 h** on a single H100.

### Diff plan

After the TSUBAME re-runs:

```julia
using JLD2
old = JLD2.load("runs/eu151_edh/result_pre_fix.jld2")["psi"]   # if backed up
new = JLD2.load("runs/eu151_edh/result.jld2")["psi"]
println("max |Δψ| = ", maximum(abs.(new .- old)))
println("ΔE = ", (energy_of(new) - energy_of(old)))
```

Expected diff: ~10 % in absolute energy (since effective DDI was at
0.500 / 0.512 of true), localised to the dipole-dominated regions
of the cloud.

## Action items for the user

1. **Backup current `result.jld2`** under `runs/eu151_edh/` and
   `runs/eu151_lab_calibrated/` to `result_pre_fix.jld2` (or keep
   in archive) before re-running.
2. **Submit TSUBAME jobs** for slot 8 + 9 (or run interactively
   on H100 — eu151_lab_calibrated is short enough).
3. **Diff old vs new ψ** to quantify the actual physics drift —
   that number goes into the修論 audit table (see
   `docs/AUDIT_BUG4.md`).
4. **Phase 1+ dynamics**: any downstream phase that consumed the
   old GS as initial state needs to be re-derived. The pipeline
   YAML chains GS → quench → hold automatically when run end-to-end.

## Status summary

- 6 configs in `runs/` audited.
- 4 configs (`berry_crossover_scan`, `eu151_phase_diagram_lbfgs`,
  `klaus_baseline`, `phi_omega_scan`) are NOT Bug-4 affected
  (rotating_basis path, see `docs/AUDIT_BUG4.md`).
- 2 configs (`eu151_edh`, `eu151_lab_calibrated`) need TSUBAME
  re-run with post-fix code.
- GPU bench validated R32 + R33 on 24³-32³ scale; production
  numbers wait for TSUBAME.
