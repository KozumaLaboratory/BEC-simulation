# Where the Fig. 4B campaign's wall-clock actually goes

> **FROZEN 2026-08-02.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

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

## Applied and re-measured: the stage cache

The scan axis is `pipeline.1.B.Bz.to`, inside the *dynamics* block, so all 45
points share one ground state and each was re-relaxing it. `SPINORBEC_STAGE_CACHE`
has existed all along, opt-in and off by default; other submit scripts in this
repo (`runs/eu_gs_phase_c1_B_kappa/*.sh`) set it, the Matsui one did not.

A/B on this exact config (UGE 8318863, 3 points): **5.44 → 3.93 s/point, −27.8 %.**

Whole job, same 45 points:

| | `ru_wallclock` |
|---|---|
| before (8310846.15) | 600.3 s |
| **with the stage cache (8318964.15)** | **528.5 s** |
| | **−71.8 s (−12 %)** |

Predicted 44 × 1.51 = 66 s, measured 72 s. The log confirms the mechanism rather
than just the number: `GS stage-cache key` 45 times, `Loading cached GS` **44**
— point 1 populates, the other 44 reuse. No physics change; it is the same
ground state, loaded instead of re-relaxed.

## The sysimage does not help — measured, and retired

This was the largest estimated lever (~364 s, 65 % of the job). It is dead.

**Three build attempts, two of which could not build at all.** `create_sysimage`
dies on CUDA device code:

```
LLVM ERROR: Cannot select: intrinsic %llvm.nvvm.read.ptx.sreg.envreg2   (GPU workload)
LLVM ERROR: Cannot select: intrinsic %llvm.nvvm.membar.sys              (CPU workload)
```

PackageCompiler compiles traced code for the host target and CUDA.jl's device
code is NVVM/PTX. It gets compiled in because **`Project.toml` declares CUDA in
`[deps]` while also naming it as the trigger for `SpinorBECCUDAExt` in
`[extensions]`** — an extension trigger belongs in `[weakdeps]`, so that pair is
inconsistent. `include_transitive_dependencies=false` keeps CUDA out and the
build then succeeds (560 MB), at the cost that nothing CuArray-parameterised is
in the image.

**And the image that does build makes the job slower:**

| | `ru_wallclock` |
|---|---|
| stage cache only (8318964.15) | 528.5 s |
| **+ sysimage (8319472.15)** | **574.4 s** |
| | **+45.9 s (+8.7 %)** |

Same 45 points, same config, `[sysimage]` confirmed in the log and the stage
cache still hitting 44 times. Single run each, so ±5 % of node variation is
possible, but the predicted −364 s is not within any plausible error bar.

The reason is the same as the build failure: the CuArray-parameterised
`make_workspace` / `find_ground_state` / `split_step!` specialisations — where
the 277 s of first-point JIT plausibly lives — cannot be in the image, so
nothing that matters was cached, and 560 MB now has to be read off Lustre at
startup.

**Getting this lever would mean restructuring the CUDA dependency**, not tuning a
build flag. Out of scope for a performance pass, and recorded here so the next
person does not re-derive the 364 s estimate.

## Dropping the DDI padding costs half the residual — not taken

Zero-padding is 21 % of the step at 32³. The campaign's own kernel factorial had
put its effect on the dip centre at **0.0016 nT** — but that was measured at
`N = 5×10⁴` and production runs `N = 3.5×10⁴`, so it was re-measured rather than
inherited (UGE 8319532, 45 points, same config with `padded: false`).

Prediction recorded in the config before the run: centre within 0.005 nT, and
not worth taking beyond 0.01 nT.

| | centre [nT] | width [nT] |
|---|---|---|
| padded (production) | −2.5099 | 12.7400 |
| unpadded | −2.4913 | 12.7284 |
| **difference** | **+0.0187** | −0.0116 |
| Matsui | −2.5495 | 12.7524 |

**The centre moves 0.0187 nT — 12× the figure that would have been inherited**,
47 % of the whole unexplained 0.040 nT residual, and in the direction *away* from
Matsui (0.0396 → 0.0582). Per-field `N_{m=−6}` shifts by up to 5.3×10⁻³.

The saving was 528.5 → 510.2 s (−18.3 s, −3.5 %). Trading half the residual for
3.5 % of wall-clock is not a trade worth making, so production keeps `padded:
true`. The unpadded config is kept as the A/B.

The transferable part: a kernel-treatment difference measured at one atom number
did **not** carry to another 30 % away. Two earlier retractions in this campaign
came from exactly that kind of inheritance.

## What is left

**The integrator**, which caps out at the 92 s of stepping — 15 % of the job —
and where RK4IP specifically is a *loss* at this tolerance
(`rk4ip_cost_on_gpu.md`).

Net result of this pass: **600.3 → 528.5 s, −12 %**, from one environment
variable that was already in the repo. The two larger-looking levers — a
sysimage and the DDI padding — were both measured and both rejected, one because
it made the job slower and one because it moved the physics.

## Method note

The first attempt at the job-level breakdown ran four full 45-point scans while
labelling them 1- and 3-point timings: the trimmer handled explicit vector scan
axes and this config uses a `{from, to, step}` range, so it silently returned the
config unchanged. Caught only because the run sat 29 minutes without printing its
first row. `scan_job_cost_breakdown.jl` now counts the points the trimmed config
will expand to and errors if it is not what was asked for.
