# GPU throughput validation, 2026-10-02

> **FROZEN 2026-10-02.** Dated implementation and measurement evidence;
> not maintained as a description of future code.

Status: selected implementation passes both 64-cubed comparisons, the combined
correctness suite, and rotating-frame Hessian validation. At the user's request,
the completed work is the merge scope; the unfinished 128-cubed benchmark was
stopped and does not support a large-grid full-solve claim. The complete investigation
chronology, including rejected measurements, is in
[gpu_throughput_20261002_history.md](gpu_throughput_20261002_history.md).

## Selected implementation

1. **Device-resident L-BFGS direction scalars.** The CUDA specialization keeps
   the two-loop recurrence's dot products, alpha, beta, and scale on the GPU,
   eliminating its 2m+1 host scalar synchronizations. The recurrence, volume
   factor, history, and public API are unchanged.
2. **True gradient-only evaluations.** `gradient_only!` traverses the existing
   Hamiltonian operator registry without computing discarded energies. The
   finite-difference Hessian stencil and constrained-Hessian parameter setup
   use it. Both backends retain the real-gradient convention `2δE/δψ*`.
3. **Correct trial-state residual projection.** Residual Newton refinement
   projects a trial gradient onto the tangent space at that trial state,
   rather than at the preceding iterate. A constant-offset harmonic oscillator
   provides an independent exact-state/energy anchor for the fix.
4. **Guarded early residual-polish handoff.** When a unit-step decrease estimate
   rounds away, an already-requested residual polish is attempted once. It is
   accepted only if its fresh residual meets the requested solve tolerance;
   otherwise the original iterate and L-BFGS history continue. The guard
   excludes fixed magnetization and simultaneous energy-based Newton polish.
   The polish retains its original `min(tol, 1e-13)` target and iteration
   budgets. Final `converged` reflects the returned state, including polish.

Defaults and physical/numerical parameters are unchanged. In particular,
`residual_polish` still defaults to false. Shared production checkouts and the
shared Julia default were not modified. The energy-reduction rewrite was
**rejected and removed**; the selected version keeps the original reductions.

## Full-solve results for the selected version

All fixtures are padded Eu F=6, box 12 cubed, c0=100, c1=5, cdd=10,
trap frequencies (1,1,1.5), q=0.1, 1000 L-BFGS steps maximum, requested residual
1e-8, and `residual_polish=true`. Strong field uses p=10 and m=+F initialization;
weak field uses p=0.3 and a spin-coherent seed with theta=0.7, phi=0.4.
These are numerical solver fixtures, not experimental phase claims.

Each arm runs in a fresh Julia process, warms the measured grid, then times a
complete solve including workspace setup. ABBA order uses one allocated H100;
GPU synchronization brackets timing. Initialization/warmup is logged separately.
Means below summarize two measured solves per arm; they are not confidence
intervals or universal speed guarantees.

| Fixture | Baseline mean | Selected mean | Speedup | State certificate | Job |
|---|---:|---:|---:|---|---|
| Strong field, 64 cubed | 5.166 s | 4.023 s | 1.284x | passed | 8851134 |
| Weak field, 64 cubed | 10.759 s | 8.588 s | 1.253x | passed | 8851152 |
| Strong field, 128 cubed | incomplete | incomplete | unclaimed | incomplete | 8851140 |

Strong-field 64-cubed observations:

- Baseline timings 5.428/4.904 s; selected timings 4.963/3.083 s.
- Line-search evaluations 272 -> 75, iterations 78 -> 65; both selected
  handoffs accepted without a line-search failure.
- All final residuals below 8.5e-14, independently reevaluated at the returned
  state; phase-aligned relative state difference 3.234e-16 and energy
  difference 1.421e-14. Comparator passed 24 assertions, including source-hash
  and runtime/grid agreement. Scheduler accounting: failed=0, exit_status=0.

Weak-field 64-cubed observations: baseline 11.177/10.340 s and selected
8.768/8.408 s; line-search evaluations 1245 -> 446, iterations 410 -> 368.
All residuals are below 9.6e-14. Phase-aligned relative state difference is
1.489e-14 and energy difference 3.109e-15. The comparator passed 24 assertions;
scheduler accounting reports failed=0 and exit_status=0.

The control restores `84466b0f`'s energy implementation, generic L-BFGS direction,
GPU gradient-only behavior, and L-BFGS driver. The trial-state projection fix is
shared by both arms so the comparison is between correctly certified solves.
Thus this is not a comparison against the older incorrect residual projection.
The legacy pre-polish `converged` flag can be false despite an adequate final
state; acceptance uses freshly recomputed residuals and state/energy agreement.

## Component measurements

These measurements identify mechanisms; they do not replace the full-solve
comparisons or imply that every workload improves by the same factor.

| Operation | Baseline | Selected | Speedup |
|---|---:|---:|---:|
| L-BFGS direction, F64, 32 cubed, history 20 | 2.210 ms | 0.872 ms | 2.53x |
| L-BFGS direction, F64, 64 cubed, history 20 | 6.993 ms | 6.054 ms | 1.15x |
| L-BFGS direction, F32, 32 cubed, history 20 | 2.171 ms | 0.769 ms | 2.82x |
| L-BFGS direction, F32, 64 cubed, history 20 | 6.005 ms | 2.919 ms | 2.06x |
| Padded gradient only, F64, 64 cubed | 3.147 ms | 2.332 ms | 1.35x |
| Padded gradient only, F64, 128 cubed | 18.897 ms | 15.731 ms | 1.20x |

Gradient-only values matched the previous fused gradient bit for bit in all
eight tested precision/padding/size cells. Direction relative errors were below
1.5e-16 for F64 and 1e-7 for F32 across the 18 tested cells.

## Correctness evidence and limitations

- **Selected-version GPU/solver suite:** 401 assertions passed, job 8851151,
  failed=0 and exit_status=0. Covers F=1/6 Hessian parity and homogeneity,
  input preservation, anisotropic/padded energy axes, host input to GPU
  workspace, direction recurrence, stall fixed point, optional physical terms,
  BdG Hessian oracles, and accuracy/handoff contracts.
- **Expanded rotating-frame Hessian gate:** job 8851174 passed 40/40,
  failed=0 and exit_status=0. The new
  fixture doubles the F=1/6 and padding matrix with nonzero rotation, retaining
  CPU parity and tiny-direction homogeneity bounds.
- **Local checks:** all three required smoke views passed. Additional existing
  L-BFGS contracts passed 115/115. The handoff contract passed 15/15; replacing
  its acceptance test with the internal 1e-13 target fails exactly the intended
  regression assertion (14 pass, 1 fail). Formatting, diff checks, and all 42
  prior-art disposition records pass; generated STATE.md has no diff.
- **Known baseline macOS failure:** the old energy-based Newton ratio assertion
  fails identically in pristine `84466b0f` and the modified tree:
  4.44250381397067e-7 against a 6.29877810244119e-8 bound. Restoring the old
  Hessian energy calls does not remove it. The assertion remains unchanged;
  the entire macOS accuracy suite is not claimed green. The TSUBAME accuracy
  suite passes all 33 assertions.
- Full nightly tests and experimental apparatus acceptance are not claimed.
  CPU F32 fused energy entry has an existing `dV::Float64` limitation; the
  independent CPU operator/energy reference is used for GPU F32 comparisons.

Without residual polish, both the control and selected default-path fixture
stop above the requested 1e-8 tolerance. Job 8851108 measured 2.165 -> 1.588 s,
with residuals 5.248e-7 and 7.751e-7 respectively, and successful terminal
accounting. This removes the large runtime regression described below, but is
**not** a certified time-to-solution speedup: neither solve met its tolerance.

## Rejected alternatives

- **Lazy energy reductions:** reduced individual kernel costs, but changed
  reduction rounding enough to increase energy-based line-search work near
  the precision floor. The default unpolished fixture regressed from 1.550
  to 3.299 s (272 -> 661 line-search evaluations, job 8851083). It is removed
  from production. `bench/gpu_lazy_energy.patch` preserves the rejected
  implementation for application only in an isolated experimental checkout.
  Earlier polished combined-variant results (1.587x strong 64 cubed, 1.458x
  weak 64 cubed) do not describe the selected implementation.
- **Batched DDI transforms:** padded FFT edge 128 regressed to 0.79x; edge 256
  improved only about 1.01x. Batched and separate transforms agreed, but the
  result did not justify changing production layout/plans.
- **Per-component kinetic readback removal:** small extra gain, about 1–3%
  for the 128-cubed fused workload, with extra allocations and no full-solve
  certificate. Retained only as an experimental benchmark.
- **Julia update:** isolated official Julia 1.13.1 loaded CUDA/SpinorBEC and
  passed compatibility/parity probes; package Manifests were byte-identical.
  RTP timings differed by about 1% on different nodes, which does not establish
  a runtime-version speedup. Shared Julia remains 1.12.6.
- **Earlier incomplete large comparisons:** job 8850961 hit its 20-minute
  scheduler limit. Superseded job 8851055 was intentionally cancelled after
  its first pair (255.037 -> 170.405 s) once the energy rewrite was rejected.
  Neither incomplete ABBA is a selected-version performance certificate.
  Selected-version job 8851140 was stopped when the user requested merging
  the completed work; it likewise provides no certified 128-cubed speedup.

## Reproduction and provenance

Selected remote checkout:
`/gs/fs/tga-kozuma-kouhi/uk07267/logperch-perf-20261002-v3`.
Earlier variants remain in sibling `logperch-perf-20261002` and `-v2` checkouts.
All compute runs through scheduler allocations; login nodes only stage files
and query job state. Benchmark JSON/JLD2 records and named stdout/stderr logs
are under each checkout's `logs/`; selected summaries are also copied to local
`logs/throughput/`. New records hash the numerical source files and reference
snapshots. The state comparator rejects unequal source hashes between arms.

Prepare baseline snapshots in a local checkout, then copy them with the
selected working tree into an isolated compute checkout:

```sh
mkdir -p logs
git show 84466b0f:ext/SpinorBECCUDAExt/gpu_energy.jl > logs/baseline_gpu_energy.jl
git show 84466b0f:src/solvers/lbfgs/energy_gradient.jl > logs/baseline_energy_gradient.jl
git show 84466b0f:src/solvers/lbfgs/driver.jl > logs/baseline_lbfgs_driver.jl
```

From the isolated TSUBAME checkout (choose unused output labels):

```sh
qsub -g tga-kozuma-kouhi -N repeat64 -o logs/repeat64.out -e logs/repeat64.err \
  -v SPINORBEC_BENCH_GRID=64,SPINORBEC_BENCH_PREFIX=REPEAT64_ \
  bench/submit_energy_solver_ab.sh
qsub -g tga-kozuma-kouhi -l h_rt=01:00:00 -N repeat128 \
  -o logs/repeat128.out -e logs/repeat128.err \
  -v SPINORBEC_BENCH_GRID=128,SPINORBEC_BENCH_PREFIX=REPEAT128_ \
  bench/submit_energy_solver_ab.sh
qsub -g tga-kozuma-kouhi -N correctness \
  -o logs/correctness.out -e logs/correctness.err \
  bench/submit_gpu_throughput.sh bench/validate_gradient_only.jl
```

Set `SPINORBEC_BENCH_PROFILE=weak` in the submission's `-v` list for the weak
fixture. The final wrapper compares all saved states after ABBA and records a
job-specific exit status. Check both this status and scheduler accounting.
The expanded correctness driver now includes 40 rotating/nonrotating Hessian
assertions rather than the 20 in job 8851151; that run is checked separately.

## Primary sources

- [cuBLAS scalar parameters](https://docs.nvidia.com/cuda/cublas/index.html#scalar-parameters):
  device-resident scalar results; the pinned CUDA.jl binding was checked too.
- [CUDA.jl profiling](https://cuda.juliagpu.org/stable/development/profiling/):
  synchronized timing and compilation/warmup separation.
- [cuFFT documentation](https://docs.nvidia.com/cuda/cufft/index.html):
  batching, plans, layout, and memory requirements; measured before adoption.
- [GPUArrays reductions](https://github.com/JuliaGPU/GPUArrays.jl/blob/master/src/host/mapreduce.jl):
  broadcast shape and reduction behavior behind the rejected energy experiment.
- [Hager and Zhang, SIAM J. Optim. 16 (2005)](https://people.clas.ufl.edu/hager/files/cg_descent.pdf):
  near-minimum cancellation in energy-decrease tests. Their approximate-Wolfe
  algorithm was not transplanted into this constrained solver.
- [Julia releases](https://www.julialang.org/downloads/manual-downloads/):
  official runtime/version/checksum source for the isolated 1.13.1 probe.

Context7 resolver/query tools were unavailable; official documentation and
installed package sources were used instead.
