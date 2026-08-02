# Where the Fig. 4B campaign's wall-clock actually goes

Measured 2026-08-02, H100. Ablation (`scripts/validation/step_cost_ablation_gpu.jl`,
UGE 8318420) plus the campaign's own per-point records. Type A.

Asked because "can we speed this up?" was pointed at the integrator. **The
integrator is the smallest of the three levers.**

## The job

Campaign job 8310846.15: `ru_wallclock` **600 s** for 45 points. From the points'
own `started_at` / `finished_at` / `duration_seconds`:

| | s | share |
|---|---|---|
| Julia startup + package precompile | ~115 | 19 % |
| First-point JIT (the point with no `duration_seconds`) | ~240 | 40 % |
| Scan span, 44 points × 5.33 s median | 245 | 41 % |
| — of which dynamics stepping (44 × 3456 × 0.604 ms) | 92 | **15 %** |
| — of which per-point setup (GS, 2× `make_workspace`, analyze, save) | 143 | 24 % |
| Between-point overhead (save + next setup) | 12 | 2 % |

Startup was measured separately: the 32³ ablation task does 0.18 s of stepping
and takes **117 s of wall-clock**. `tsubame_setup.sh` points `JULIA_DEPOT_PATH`
at a job-local `/tmp/<jobid>/.julia`, so **every array task precompiles from
scratch**.

## The step

`split_step!`, Eu F=6 D=13, box 16, ms/step. Each row differs from the one above
by one feature, so the delta is that feature's cost. By ablation, not
`@timeit_debug`: GPU launches are async and an unsynchronised timer charges the
work to whichever region contains the next sync.

| configuration | 32³ | 64³ | 128³ |
|---|---|---|---|
| no DDI at all | 0.150 | 1.249 | 10.581 |
| DDI secular, unpadded | 0.480 | 1.743 | 12.450 |
| DDI full, unpadded | 0.477 | 1.749 | 12.501 |
| DDI full, pad 1.5 | 0.523 | 2.271 | 17.275 |
| **DDI full, pad 2 (production)** | **0.604** | **2.768** | **25.070** |

Three results:

- **`secular_ddi` is not a speed optimisation.** Full vs secular is 12.501 vs
  12.450 ms at 128³ and 0.477 vs 0.480 at 32³ — inside the noise. It is an
  approximation with a physics justification, not a cheaper kernel.
- **Zero-padding is 50 % of the step at 128³** (12.57 of 25.07 ms) and 21 % at
  32³. `pad_factor` 2 → 1.5 recovers 31 % at 128³.
- **The midpoint predictor-corrector is 19 % at 128³, 33 % at 32³** (25.07 →
  20.19; 0.604 → 0.403). Turning it off drops the DDI path to 1st order, so this
  is what the accuracy costs, not a free saving.

## What is worth doing, in measured order

1. **A sysimage.** ~355 s of 600 (59 %) is startup and first-point JIT.
   `scripts/build_sysimage.jl` and `build_sysimage_full.jl` already exist and the
   Matsui submit script does not use one.
2. **`SPINORBEC_STAGE_CACHE=1`.** The ground state is identical across all 45
   points — the scan axis is `pipeline.1.B.Bz.to`, inside the *dynamics* block —
   and the stage cache is opt-in and off by default. Other submit scripts in this
   repo (`runs/eu_gs_phase_c1_B_kappa/*.sh`) set it; the Matsui one does not.
   Bounded above by the 143 s of per-point setup.
3. **Drop the DDI zero-padding for this observable.** Worth 21 % of the step at
   32³ (19 s over the campaign), and the campaign's own kernel factorial already
   measured its effect on the answer: **0.0016 nT**, against a dip centre of
   −2.51 and a residual of 0.040. Cheap in a way the other kernel knobs are not.
4. **The integrator.** Caps out at the 15 % of the job that is stepping, and
   RK4IP specifically is a *loss* at this tolerance
   (`rk4ip_cost_on_gpu.md`).

## Method note

The first attempt at the job-level breakdown ran four full 45-point scans while
labelling them 1- and 3-point timings: the trimmer handled explicit vector scan
axes and this config uses a `{from, to, step}` range, so it silently returned the
config unchanged. Caught only because the run sat 29 minutes without printing its
first row. `scan_job_cost_breakdown.jl` now counts the points the trimmed config
will expand to and errors if it is not what was asked for.
