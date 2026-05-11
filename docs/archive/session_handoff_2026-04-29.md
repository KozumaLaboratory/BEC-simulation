# Session handoff — 2026-04-29

Long session: 4 review rounds, 12h batch completed, audit found ε=1e-3
Klaus regime numerical artifact, CUDA Graph alloc-reduction landed,
F32 mixed precision end-to-end, save format unified.

## What landed

### Reviews + bug fixes

- **Round 1 (F=6 hardening)**: `c_dd` docstring + `even_c_extra` helper
  + DDI Larmor advisory + `apply_singlet_pair_step!` rename. (commit
  `c6b1ed0`, push: yes, tests: 119/119 + 14 pinned)
- **Round 2 (silent bugs)**: `_parse_gs_interactions` was dropping
  `c_extra` YAML keys; `energy_gradient!` missing c2/c_extra/tensor;
  schema `c1_ratio` range allowed -1/F² singularity; CUDA Graph
  fallback documented. (commit `68bcf51`)
- **Round 3 (SGPE/Bogoliubov)**: SGPE FDR regression test (slope 0.871
  ≈ 1); Bogoliubov ferromagnetic Goldstone test pinned via
  `@test_broken` (gap 0.4 at F=1, 1440 at F=6 — μ convention bug);
  SGPE simple-growth limitation docstring; `add_thermal_seed!` rename;
  `_step_dispatch!` else-throw guard. (commit `638adc8`)
- **Bug-1 fix**: `SimParams` positional reconstruction was zeroing
  `rotating_frame_omega` / `spin_rotating_frame_omega` in 3 callsites;
  schema missing `rotating_frame_omega` for dynamics; pipeline not
  forwarding to `find_ground_state`; energy_decomposition lacking
  `-Ω⟨L_z⟩`. All fixed + 14 regression tests. (commit `0644360`)

### 12h thesis batch + audit

24 runs at 24×24×12 ε=1e-3 ran in 3h17m (faster than planned). Audit
discovered ε=1e-3 fails catastrophically for `p·F·dt > ~300`:
**`p_3000`** went 0.997 → 0.106 (full thermal scrambling, fake) at
ε=1e-3, but 0.997 → 0.999 (frozen, correct) at ε=1e-6. p_10000 also
quantitatively biased.

**Klaus reproduction confirmed real**: `dy164_main_eps1e6` (Dy164,
p=28428) gave 0.9995 → 0.9999 frozen + Lz [-0.52, +0.43]. Matches
Klaus 2022 paper's scalar-frozen + orbital Lz signature.

**Implication for thesis**: Eu151 at p=26700 (Klaus regime) is just as
frozen as Dy164. The original v2_full ε=1e-3 result (0.768 → 0.877)
was numerical artifact. Spinor extension visible only at low p
(~mG B field) — see phi_omega_scan results.

(commit `82dba17` configs, `2a352e7` Larmor guard + integrator
metadata, `docs/thesis_batch_audit_2026-04-28.md`,
`memory/eps_threshold_finding.md`)

### phi_omega scan

8 Eu151 points (24³, 500ms stir, ε=1e-6) at phi_omega ∈
{1, 2, 3, 4.524, 6, 8, 12, 18}. All m=+F frozen (1.0 → 1.0). Lz max
scales inversely with phi_omega: phi=1 → Lz_max +1.61, phi=18 → +0.68.
Slow stir = adiabatic following = more orbital Lz. Klaus 4.524 = +0.65.

scan v4 currently running (multi-phase save, full GS→tilt→chirp→stir
trajectory) — finishes ~22:00 JST, dashboard-ready immediately.

(commit `03beae9` configs, `de6ac43` analyzer, `02575ed`
multi-phase auto-save)

### Save format unification

Three result formats existed (streamed / 5D legacy / Vector legacy).
Dashboard handled (1) and (2) but not (3), forcing manual repack.
**Unified**: `save_rotating_basis_result!` writes canonical streamed
layout; auto-called by `run_pipeline` when `checkpoint_dir` set;
launchers no longer hand-roll JLD2; dashboard fallbacks added for old
data. `dashboard_repack_rotating_basis.jl` retired (`.obsolete`).

`_step_dispatch!` accumulates `:rotating_basis_history` so multi-phase
runs save the FULL trajectory from GS onward (previously only the
last phase survived `merge!`).

(commits `ebe8637`, `02575ed`, `dde694f` NamedTuple fix, `ca93bf7`
retire repack)

### CUDA Graph readiness

Three rounds of allocation reduction in the rotating_basis hot path.
After commit `adf51ef` the per-step CUDA temporaries are gone:

- `RotatingBasisWS.kspace_phase_buf` / `xspace_phase_buf` for
  kinetic / diagonal step phase factors (commit `a03d264`)
- `_ROTATION_RT_CACHE` for the small D×D R^T device buffer in
  `_apply_rotation_to_spin_axis!` (commit `a03d264`)
- `_DDIRotationCache.cis_PD` for the (N, D) phase scratch in the
  fused-Euler 5-stage rotation (commit `adf51ef`)

`apply_euler_5stage_fused!` now takes an optional `cis_PD=` scratch
kwarg; `_apply_ddi_rotation!` GPU branch threads it through.

**Bench script `scripts/bench_cuda_graph_rotating.jl`**: ready to run
once GPU is free (scan v4 finishes), measures plain vs `CUDA.@captured`
on Eu151 D=13 24³. If captured beats plain, re-enable
`split_step_captured!` in `ext/SpinorBECCUDAExt/gpu_graph.jl`.

### F32 mixed precision

End-to-end working. `dtype: f32` YAML keyword propagates through
Grid → V_trap → workspace → split_step. Five boundary fixes:

1. `make_grid(...; dtype=T_float)` — Grid precision must match V_trap
2. `find_ground_state_rotating!(ws, n_steps, T_float(dt_itp))` — dt
   narrowing
3. `_apply_UB!` — angle Float64 conversion (rotation builder locked)
4. `apply_ddi_step!` — dt Float64 conversion (legacy spinor solver)
5. `psi_tilde::AbstractArray{<:Complex,4}` — relaxed type assertion
6. `DDIParams.C_dd` stays Float64 (mixed: scalar F64, array F32)

`@compile_workload` extended to specialise both Float64 and Float32
paths at package precompile, so first runtime call is fast.

(commit `df6a1eb`)

### TSUBAME deployment

Generator + job array driver + sysimage + JLD2 zstd compression +
preflight check.

`scripts/tsubame/`:
- `generate_hires_scan.jl` — phi_omega scan at thesis res (48³, 1000ms)
- `run_scan_array.sbatch` — UGE job array, picks up sysimage if built
- `build_sysimage.jl` — PackageCompiler one-shot, saves ~30-60s/job
- `preflight.sh` — interactive-node CUDA + Julia + smoke test
- `README.md` — submit + result-pull workflow

(commits `5de4805`, `b19736b`, `204d554`)

## What's running right now

- **phi_omega_scan_v4** (PID `176957`, master). Master detached
  (`setsid nohup`), survives session close. ~22:00 JST completion.
  Output: `runs/phi_omega_scan/<name>/result.jld2` per the canonical
  multi-phase save layout.
- **Dashboard** (PID `78539`) on `localhost:8765`. Run list shows
  the 8 phi_omega entries via top-level symlinks.

## What's pending

### High-value, ready to run

1. **CUDA Graph capture bench**: `scripts/bench_cuda_graph_rotating.jl`.
   30 min on free GPU (after scan v4). Tells us whether the alloc
   reduction work paid off — if yes, re-enable `split_step_captured!`.
2. **F32 GPU bench**: same script with `dtype=:f32` workspace, measure
   wall time vs F64.

### Medium-value, planned

3. **Bogoliubov μ convention re-derivation** (round-3 finding):
   `_bdg_k_scan` includes k̂-direction-dependent DDI in μ, leaving
   gap at k=0 even in symmetry-breaking regime. Test pinned at
   `@test_broken`. Affects absolute roton / sound speed values; less
   so the instability scan (uses Im ω at finite k).
4. **`apply_spin_mixing_step!` F32 specialisation**: currently the
   c1≠0 path silently upcasts to Float64 inside the spinor utils
   `_apply_euler_spin_rotation`. For Eu thesis runs c1=0 so non-issue
   in production; would matter for c1-sweep at thesis grade.

### Multi-week

5. **Multi-GPU per-run** via cuFFTMp. Design doc:
   `docs/multi_gpu_design.md`. Implementation gated on actual TSUBAME
   access for testing.
6. **F=6 closed-form LHY** — research-level (no published closed form
   for general F).

## Key contacts (file-level)

- `docs/thesis_batch_audit_2026-04-28.md` — ε threshold finding,
  regime classification table
- `docs/optimization_roadmap_2026-04-29.md` — next-tier opt list
- `docs/multi_gpu_design.md` — 4-phase cuFFTMp plan
- `memory/eps_threshold_finding.md` — concise rule for next session
- `runs/README.md` — full directory inventory

## TL;DR for next session

1. Wait for phi_omega scan v4 to finish (or read its `result.jld2`s
   if already done)
2. Run `scripts/analyze_phi_omega_scan.jl` for summary table
3. Run `scripts/bench_cuda_graph_rotating.jl` to validate CUDA Graph
4. Open `localhost:8765` to inspect column density / vortex
5. For B-1 (FL vs uniform polarization): use ε=1e-6 + low p (~mG)
   to land in the regime where Berry connection actually drives
   transitions
