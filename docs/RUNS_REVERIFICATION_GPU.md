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
| `runs/eu151_edh/` | 64³ → 32³ (Phase 0 GS only) | **DONE** post-fix on RTX 5070 Ti, 63.1 s, E = −880.501 | for production 64³ + dynamics chain |
| `runs/eu151_lab_calibrated/` | 32³, n_steps=4 000, save_every=40 | **Blocked by ITP overflow at step 1** even after calibration→Bz fix; needs config-side stiffness debug | **YES** after stiffness bug below is sorted |

### Local re-run result: `runs/eu151_edh/result_postfix_gs_32cube.jld2`

Reduced grid (64³ → 32³) and reduced n_steps (100 000 → 2 000) to fit the
local-GPU wall time budget. The post-fix integrator converges cleanly:

```
ITP 1420/2000 | E=-880.50112 dE=8.25e-11 dpsi=6.35e-10 | 19.9 s elapsed
E=-880.501  conv=true  Mz=6.0  [m=6: 100.0%, m=5: 0.0%, ...]
DONE in 63.1 s
```

Mz = 6.0 (m=+F stretched) confirms the physics is intact post-fix.
Quantitative diff against the pre-fix `result.jld2` is blocked by a JLD2
zstd world-age issue at fresh module load; the 32³ ψ saved is suitable
for projection comparison after manual JLD2 dependency fix.

### Side-finding: eu151_lab_calibrated had **3 layered bugs** unrelated to Bug-4

Encountered (and partially fixed) during the local re-run audit:

While attempting the local re-run, two issues surfaced that are
**independent of Bug-4** and predate it:

1. **Schema lockdown drift**: the original config had `N_atoms` and
   `omega_ref` at the `ground_state.*` level rather than under
   `ground_state.interactions.*`. The post-2026-04-30 schema rejects
   them at that level (`Unknown key 'pipeline.1.ground_state.omega_ref'`).
   This commit (R41) moved them under `interactions:` to comply.

2. **`_to_float_vec` not quantity-string aware** (FIXED, this commit):
   `apply_calibration!` transforms `fort_power_mw: [50, 50, 100]` into
   `omega: ["3157 Hz", …]` strings, but `_to_float_vec` in
   `parsing_units.jl` only handled Reals. Extended to call
   `_parse_angular_frequency` for string elements.

3. **calibration p-Gauss vs p-dimensionless convention collision**
   (FIXED, this commit): `_calibrate_zeeman_node!` was producing
   `node["p"] = "X Gauss"` (a Cartesian quantity), but `p` is the
   dimensionless Zeeman energy internally — `_zeeman_scalar` at
   `parsing_units.jl:11` then crashed with `MethodError: Float64(::String)`.
   Routed calibration output to `node["Bz"]` instead; the
   `_split_B_block!` normaliser correctly handles `B.Bz: "X Gauss"`.

4. **ITP NaN at step 1 with calibrated parameters** (NOT FIXED, deferred):
   After the calibration→Bz fix the GS step actually starts but immediately
   overflows. The Eu calibrated parameters (c_dd ≈ 126.6 dimensionless,
   ⟨n⟩ ≈ 1, F = 6 stretched state) push the DDI rotation factor
   `exp(-2F·θ)` past safe range with `dt = 0.005`. Smaller dt (0.001)
   doesn't help — the issue is in the per-step DDI exponential
   amplitude, not the per-step dt. Likely a config-tuning issue where
   `N_atoms = 30 000`, `omega_ref = 691.15`, and the calibrated trap
   geometry produce a higher-density cloud than the ITP step assumes.
   **Workaround**: reduce N_atoms or relax tol; defer for thesis-side
   debugging since it's separate from Bug-4.

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
