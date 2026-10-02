# GPU throughput investigation history, 2026-10-02

> **FROZEN 2026-10-02.** Evidence from this investigation as of this date;
> not maintained as a description of future code.

Status: ongoing. The lazy energy reductions were removed from production after
a default-path regression; final validation of the remaining changes is pending.
The polished 64-cubed results below certify the earlier combined variant only.

## Current acceptance

The selected production changes are device-resident L-BFGS direction scalars,
true gradient-only Hessian work, correct trial-state residual projection, and
the guarded early residual-polish handoff. Energy reductions retain the original
implementation. Previously measured combined-variant results follow; the selected
variant must pass its own full-solve comparisons before completion.

- **64-cubed padded Eu F=6 solve:** mean 5.905 -> 3.720 s (1.587x), with
  same-grid warmup and ABBA order on one GPU. All residuals < 8.5e-14;
  phase-aligned state difference 3.29e-16, energy difference 1.42e-14.
  Jobs 8850913 and 8850975 both have qacct failed=0 and exit_status=0.
- **Weak-field 64-cubed padded Eu F=6 solve:** mean 10.597 -> 7.269 s
  (1.458x), same-grid warmup and ABBA on one GPU. Phase-aligned state
  difference 1.489e-14, energy difference 3.109e-15; all residuals < 9.6e-14.
  Job 8850964 passed its 12 state-comparison assertions and terminal
  accounting (failed=0, exit_status=0). Both 64-cubed fixtures use
  `residual_polish=true`; they do not establish a default unpolished speedup.
- **Correctness:** H100 suite 302 assertions passed (8850866); expanded
  accuracy/handoff suite 33 passed (8851069, failed=0, exit_status=0).
  All three local smoke views pass.
  Additional optional-term gradient-only coverage passed 163/163 in job 8851003.
  GPU stall fixed-point coverage passed 13/13 (8851024); both jobs have
  qacct failed=0 and exit_status=0. Local L-BFGS contracts passed 115/115.
- **Known baseline limitation:** the old macOS energy-based Newton ratio test
  fails identically in pristine 84466b0f and this tree. Its bound is unchanged.
- **Remaining:** final 128-cubed comparison and state certificates, plus a
  default unpolished diagnostic. Job 8850961 hit its 20-minute runtime limit (failed=44,
  exit_status=137) before completing the first timed candidate. Its control
  record is diagnostic only. Job 8851055 runs the corrected handoff predicate
  in a separate checkout with a one-hour allocation. Completed 64-cubed
  comparisons use the preceding, stricter handoff predicate; both candidates
  already satisfy it, so broadening acceptance does not change that branch.
- **Default-path regression:** job 8851083 measured `residual_polish=false`
  at the unchanged 1e-8 requested tolerance: baseline 1.550 s, candidate
  3.299 s, with 272 versus 661 line-search evaluations. Residuals are
  5.248e-7 and 3.170e-7 respectively: neither is a certified solution, and
  the longer default solve prevents adopting the combined patch generally.
  Job 8851108 restores only the old energy reductions, retaining the other
  changes: same-GPU baseline 2.165 s versus candidate 1.588 s (272 versus 313
  line-search evaluations), removing the large runtime regression. Neither
  reaches 1e-8 without polish; residuals are 5.248e-7 and 7.751e-7, so this is
  not a certified solution speedup. The rejected lazy-reduction implementation
  is preserved as `bench/gpu_lazy_energy.patch` for isolated reproduction.

Final selected-variant jobs run in
`/gs/fs/tga-kozuma-kouhi/uk07267/logperch-perf-20261002-v3`:
8851134 (strong 64 cubed), 8851140 (128 cubed, one-hour allocation),
8851152 (weak 64 cubed), and 8851151 (combined GPU/solver correctness gates).
The large and weak comparisons are held behind the first 64-cubed comparison.
The superseded combined-variant job 8851055 was deliberately cancelled after
its first candidate completed (255.037 -> 170.405 s, residual 2.663e-13).
Its incomplete ABBA is diagnostic only. No running numerical source was
changed; each selected-variant benchmark record hashes its source inputs.

The sections below preserve the investigation history, including rejected
measurements. Earlier small-grid-warmed full-solve timings are diagnostic;
the same-grid-warmed figures above are the accepted result.

## Scope and acceptance

Optimize the principal Eu F=6 simulation and ground-state workloads, including
the padded DDI production path. Preserve physical parameters, numerical
tolerances, boundary conditions, and output semantics. Accept changes using
same-process alternating A/B measurements plus energy/gradient parity and
relevant existing physics oracles. Report initialization separately from warm
execution. Kernel improvements must also improve their consuming workload.

Baseline checkout: `84466b0f`. Local changes are not committed yet.
Remote isolated checkout:
`/gs/fs/tga-kozuma-kouhi/uk07267/logperch-perf-20261002`.
Shared production checkouts and the shared Julia default are not changed.

## Evidence and current jobs

- Job 8850506: invalid initial measurement. UGE split the inline `bash -c`
  argument; only `export` ran. No timing from this job is admissible.
- Job 8850511: finished with recorded exit code 0, H100, Julia 1.12.6.
  Existing unpadded RTP benchmark: sequential Taylor 1.772 ms at 64 cubed and
  12.737 ms at 128 cubed; Euler 6.517 and 49.185 ms. These are existing
  optimizations, not improvements introduced by this investigation. Relative
  wavefunction difference was approximately 1.05e-13 at 128 cubed.
- Job 8850530: hardened FFT benchmark plus energy-reduction A/B, finished with
  recorded exit code 0. Inspect `logs/energy_reduction_ab.{out,err,rc}`.
  The baseline energy implementation is preserved in
  `logs/baseline_gpu_energy.jl`; the benchmark compiles its core under a
  separate function name for same-process comparison.
- Job 8850536: isolated Julia 1.13.1 compatibility/performance probe, completed
  with recorded exit code 0. Inspect `logs/julia113_probe.{out,err,rc}`.
  The binary in `tools/julia-1.13.1` passed official SHA-256 verification.
  `runtime-1.13` has its own Project/Manifest and `runtime-depot` is the writable
  depot; shared packages are a fallback. Compare resolved dependency versions
  before attributing a difference to Julia alone.

The two Manifest files compared byte-identically after instantiation. Julia
1.13.1 successfully loaded CUDA/SpinorBEC and passed all six energy A/B cells.
Unpadded RTP Taylor timings were 1.747 ms (64 cubed) and 12.621 ms (128 cubed),
versus 1.772/12.737 ms on 1.12.6 on another node. This approximately 1% difference
does not establish a runtime-version speedup. No shared runtime upgrade yet.

## FFT batching result

The original microbenchmark repeatedly applied unnormalised backward FFTs and
did not verify equality. It now restores inputs outside timing, alternates
arm order, reports medians as well as minima, and checks forward/inverse parity.
It also imports FFT planning through the declared FFTW dependency rather than
the undeclared transitive AbstractFFTs dependency.

Hardened results from job 8850530 (three Float64 fields):

| Padded FFT edge | Separate forward+backward minimum | Batched minimum | Speedup |
|---|---:|---:|---:|
| 128 | 282.5 us | 357.6 us | 0.790 |
| 256 | 2813.4 us | 2779.7 us | 1.012 |

Both forward and inverse parity errors were zero. At 128, median speedups were
0.782 forward and 0.773 backward; at 256, 1.014 and 1.012. Do not refactor the
padded context for this result: the smaller case regresses and the larger
gain is too small to justify it without broader evidence.

## Candidate currently under test

`gpu_energy.jl` reduces lazy broadcasts directly rather than materializing
full grid/spinor temporaries for kinetic, trap, Zeeman, and DDI energies. The
three spin-energy reductions become one. Broadcasting axes are retained;
multi-array mapreduce would flatten mismatched shapes and is unsuitable for
the trap/Zeeman arrays. Gradient operations are unchanged.

Same-process Float64 A/B passed all 31 assertions per cell at 8/64/128 cubed
with and without padding (186 total), including bit-identical gradients.
At 128 cubed, energy-only evaluation fell from 7.305 to 5.295 ms unpadded
(1.380x) and 10.323 to 8.293 ms padded (1.245x). Fused energy/gradient fell
from 15.832 to 14.654 ms unpadded (1.080x) and 18.810 to 17.652 ms padded
(1.066x). These are function-level measurements, not full-solve speedups.

Job 8850574 completed with exit 0: anisotropic Float32/Float64 baseline A/B
128/128, small cubic A/B 62/62, existing GPU/CPU term parity 156/156, padded
corner parity 32/32, host-psi GPU-workspace gate 12/12. New permanent independent
CPU/GPU shape tests are registered in `_tiers.jl`. Job 8850633 reported 64/64
assertions, with qacct failed=0 and exit_status=0.

The first version of that test (job 8850600) hit a pre-existing CPU F32 fused
energy entry-point defect: `operator_and_energy_via_registry!` requires
`dV::Float64`. The revised reference uses the independent CPU energy and
gradient-only traversals, retaining the same inputs and tolerances. That CPU
F32 fused-entry limitation is not fixed by these GPU changes.

## Full-solve acceptance is still open

The 32-cubed, padded F=6 fixture in `energy_solver_ab.jl` asks for a projected
gradient norm at most 1e-8. Job 8850575 exposed the baseline energy-comparison
floor (2.75e-7). Residual polish, applied to both arms without changing the
tolerance, drove the baseline below 1e-8. The legacy `converged` flag still
describes the pre-polish loop, so job 8850583 rejected a state whose measured
residual was 8.72e-10. The benchmark now independently re-evaluates the gradient
and energy of the final state instead of trusting that flag.

Job 8850596: baseline 7.704 s, residual 8.72e-10; energy-reduction candidate
1.970 s, residual 7.61e-7. **This is NOT an accepted full-solve speedup**: the
candidate misses the unchanged residual requirement. Both energies agree to
about 2e-14, illustrating why energy agreement alone is insufficient. Investigate
the rounding-sensitive line search/polish and verify time-to-solution before
accepting the overall optimization. Logs are cumulative across these attempts;
read the job's timestamp and final records, not the first matching line.

## Device-resident L-BFGS recurrence

NVIDIA documents that reading dot products into host scalars synchronizes the
GPU. CUDA.jl 5.11.0's `CUBLAS.dotc(n,x,y,result)` accepts a device result and its
handle defaults to device pointer mode. Keeping alpha/beta/gamma on the device
removes 2m+1 scalar readbacks without changing the two-loop recurrence or dV
scaling. Source: [cuBLAS scalar parameters](https://docs.nvidia.com/cuda/cublas/index.html#scalar-parameters).

Prototype job 8850608 passed 18/18 comparisons at 8/32/64 cubed, history sizes
0/1/20, Float32/Float64. At history 20, F64 32 cubed fell from 2.223 to 0.876 ms
(2.54x), 64 cubed from 7.000 to 6.055 ms (1.16x). F32 32 cubed: 2.172 to
0.747 ms (2.91x); 64 cubed: 6.026 to 2.912 ms (2.07x). F64 relative direction
errors were below 1.5e-16; F32 below 1e-7. Earlier job 8850589 had a benchmark
fixture promotion bug (Float64 literal promoted the F32 history), fixed before
these results.

Implemented as the CUDA extension's `gpu_lbfgs.jl` specialization with cached
scalar buffers. The CPU method remains the reference and fallback. Permanent
CPU/GPU recurrence/descent/input-preservation test: `test_gpu_lbfgs_direction.jl`.
Job 8850646 passed 64/64 assertions; job 8850651 passed 18/18 comparisons of
the actual production dispatch against the generic method via `invoke`.
Both completed with qacct failed=0 and exit_status=0. No full-solve
claim for this change yet. The earlier solve comparison predates this dispatch.

## Residual-polish correction

The trial residual was projected against the captured old state instead of
its own trial state. Job 8850671 proved the effect on the saved failed B1
state: unchanged code stalled at 7.6068e-7; projecting at the trial state
reached a freshly evaluated residual of 6.5579e-14 (same parameters).
Job 8850679 independently tested the scalar harmonic oscillator with constant
potential offsets 0 and 100. The correction reached residual 3.22e-12 in
four iterations in both cases, with energy error below 4.3e-14. Old code at
offset 100 stopped at residual 0.01247 after eight iterations. Both jobs have
qacct failed=0 and exit_status=0. This is a constant-offset invariance anchor,
not merely agreement between two implementations.

Production `residual_newton_refine` now projects the trial gradient at `psi_t`.
The oscillator regression lives in `test_lbfgs_accuracy_floor.jl` and checks
fresh energy, residual, and norm. Job 8850740 passed all 18 assertions
(12 existing, 6 new), with qacct failed=0 and exit_status=0. Job 8850739 reruns the full-solve ABBA with
the same correction in BOTH arms, restoring old energy reductions and generic
L-BFGS dispatch only for the baseline. Labels C1/D1/D2/C2 distinguish this from
the rejected A/B run. Acceptance still requires residual <= 1e-8.
Completed ABBA job 8850739 (qacct failed=0, exit_status=0): baseline 4.312/4.218 s,
candidate 2.735/2.755 s, mean speedup 1.554x. Both baseline residuals were
5.28e-14 and both candidate residuals were 3.42e-14. Energies agreed within
2.2e-14. This certifies the 32-cubed fixture, not arbitrary ground states.
Job 8850771 repeats the same acceptance at 64 cubed, labels N64_C1/D1/D2/C2,
logs `energy_solver64.{out,err}`. First 64-cubed pair REGRESSES:
baseline 5.675 s/272 line-search evaluations, candidate 8.066 s/661
evaluations (78 vs 97 steps). Both residuals are about 8.5e-14. This is a
workload regression despite faster individual kernels; do not accept the
combined optimization generally from the 32-cubed result. The benchmark now
has `energy` and `direction` modes to isolate the two changes. The wrapper's rc file is shared; scheduler
accounting and the named output records distinguish jobs.

Local smoke_fast: tier membership, prior art, generated STATE, physics claim
ledger, spin matrices, grid, and atoms passed. The documentation date-header
gate first failed for this report; adding its dated snapshot header resolved
the isolated gate (73/73). Local smoke_oracles also passed all four files, and smoke_integration passed
all three files (127 assertions).
JuliaFormatter 2.5.0 applied to changed Julia files.

Next: inspect the 64-cubed solve and kinetic readback probe, broaden to a
realistic Eu weak-field/production-sized solve, run required suite/format/tier
checks, and consolidate benchmark job wrappers before final review.

## Next synchronization probe

`bench/energy_kinetic_device.jl` dynamically replaces only the kinetic-energy
readback in a process-local copy of the current core. It keeps each per-component
reduction on the device and reads their sum once after the FFT loop. The
existing same-process energy A/B harness checks anisotropic F32/F64 and
8/64/128-cubed parity plus timings. No production change is adopted from this
probe until the measurements pass. Job 8850779 passed 128 anisotropic plus 186 cubic assertions. At padded
64 cubed, energy-only 1.661 -> 1.406 ms and fused 3.083 -> 2.846 ms; at padded
128 cubed, 8.271 -> 8.050 ms and 17.644 -> 17.404 ms. This extra 0.2–0.25 ms
saving is not yet adopted into production or a full solve.

## Roundoff-sensitive solve cost

Job 8850771 completed its four records: baseline 5.675/5.033 s vs candidate
8.066/8.398 s. Completed energy-only ablation job 8850787 gives 8.841/8.446 s
and 798 line-search evaluations (108 steps). Device-direction-only arms give
4.856/6.613 s and 313 evaluations (76 steps). These historical measurements
used the earlier small-grid warmup, so they identify iteration-count changes
but are not the accepted same-shape timing comparison. The combined candidate's
slowdown is therefore not solely the new direction.

Hager and Zhang's primary paper discusses the loss of accuracy in sufficient
energy-decrease tests near a minimum and replaces them with approximate Wolfe
conditions: [SIAM J. Optim. 16 (2005), 170–192](https://people.clas.ufl.edu/hager/files/cg_descent.pdf).
This supports investigating the cancellation mechanism; it does not certify a
manifold adaptation of their unconstrained method here.

Job 8850803 tests a smaller change in a process-local driver: when residual
polish is already requested and `E + slope == E` for a negative unit-step
slope, hand off to that same polish instead of spending energy comparisons
below the representable decrement. The final residual tolerance is unchanged.
Job 8850803 reached residual 8.38e-14 with 82 line-search evaluations
instead of 661. Time was 6.700 s: still above the original baseline's
5.03–5.67 s, so this is not an accepted speedup. A same-node ABBA with the
handoff in both baseline and candidate is needed to separate stage costs.
No production handoff has been adopted.
Further evidence must cover weak-field conditioning and a fallback if early
polish does not converge.

## Gradient-only Hessian work

`hessian_vector_product` evaluates and discards four energies per fourth-order
stencil; `constrained_hessian_params` also discards the energy. Moreover,
`gradient_only!` still routes GPU calls to fused energy+gradient, based on an
old claim that the energy was free. Job 8850836 compares the existing registry
operator traversal (same physical terms and factor 2) to the fused path on
H100, Float32/64, padded/unpadded, and up to 128 cubed. All eight cells
returned bit-identical gradients. Padded F64: 64 cubed 3.147 -> 2.332 ms
(1.35x); 128 cubed 18.897 -> 15.731 ms (1.20x). The production gradient-only
entry now uses the existing registry on both backends; Hessian stencil and
parameter calls use it instead of discarding energies. Local CPU BdG oracle,
homogeneity, and alias rejection passed 28/28. New GPU Hessian test covers
F=1/6, padding both ways, CPU comparison, tiny-direction homogeneity, and
input preservation. Its cluster suite also reruns per-term, host-input,
anisotropic, BdG, and accuracy-floor checks.

Full-solve controls now restore the previous GPU gradient-only implementation
from `logs/baseline_energy_gradient.jl` (baseline HEAD's source), so baseline
Hessian work still evaluates energies and the candidate can measure the saving.
The residual projection correction remains common to all arms.

The controlled handoff ABBA is job 8850821, log `handoff_ab64`. First baseline
record: 5.035 s total, 1.502 s inside the L-BFGS loop, residual 8.74e-14;
polish/setup/finalization now dominate. Completed handoff-only records:
baseline 5.035/4.455 s vs candidate 4.597/6.230 s. Timing variability and
the candidate mean regression prevent an acceptance claim. Job 8850867
(`gradient_ab64`) repeats with the new gradient-only Hessian in the candidate.
Job 8850866 (`gradient_validation`) runs the broader correctness suite. This motivates measuring the discarded
energy work rather than changing the requested tolerance.

## Primary sources checked

- [cuFFT documentation](https://docs.nvidia.com/cuda/cufft/index.html): batching,
  plan reuse, memory requirements, transform layouts. Vendor batching guidance
  is a hypothesis, not a substitute for the measurements above.
- [CUDA.jl profiling](https://cuda.juliagpu.org/stable/development/profiling/):
  synchronize GPU work around timing.
- [GPUArrays reduction source](https://github.com/JuliaGPU/GPUArrays.jl/blob/master/src/host/mapreduce.jl):
  lazy Broadcasted input support and multi-array shape semantics. Runtime
  tests must establish support for this checkout's pinned package versions.
- [Julia releases](https://www.julialang.org/downloads/manual-downloads/):
  latest stable 1.13.1, released 2026-09-25. Baseline Manifest and TSUBAME
  default are 1.12.6. Updating Julia is an experiment, not an assumed speedup.

Context7 was searched in available tool metadata but no callable Context7
resolver/query tools were available; official sources were used instead.

The weak-field smoke probe is job 8850870 (`weak_handoff`): 16 cubed,
p=0.3, q=0.1, and a spin-coherent initial state (theta=0.7, phi=0.4), with
the same interaction/trap/DDI settings and unchanged 1e-8 final certificate.
This is a solver fixture, not a claim about an experimental Eu phase.

## Final implementation checks in progress

The residual handoff now has a one-attempt guard and accepts only a result
below the requested solve tolerance, while the polish still uses its
unchanged tighter target. If it fails, the original iterate and
L-BFGS history continue. It is disabled for simultaneous energy-based Newton
polish and fixed magnetization, whose ordering/constraints need separate care.
Final `converged` now follows the returned fresh residual, including polish.
A constant-offset oscillator test checks accepted handoff and a zero-budget
fallback that reproduces the ordinary loop exactly: 10/10 passed on macOS.

The macOS accuracy-floor suite failed its pre-existing energy-based Newton
ratio assertion; restoring the old Hessian energy calls did not remove the
failure. The pristine `84466b0f` checkout reproduced the exact same failure:
4.44250381397067e-7 against the 6.29877810244119e-8 bound. The modified tree
and restored-old-Hessian control returned these same values. This is an
existing macOS limitation; the assertion has not been weakened.
The TSUBAME suite with gradient-only Hessians passed 302/302 assertions before
the production handoff was added. Weak-field 16 cubed reached 9.10e-14.

All full-solve timings above warmed only 8 cubed. This may leave large-grid
reduction specialization and planning in the timed section. The final harness
warms the measured grid itself and prints the GPU UUID. Earlier timings remain
diagnostic, not the final performance certificate. The final baseline also
restores the original L-BFGS driver, so handoff gains are included rather than
silently applied to both arms.

Final-shape-warmed production comparisons: job 8850913 (`final_solver64`),
labels FINAL64_C1/D1/D2/C2. Job 8850914 (`accuracy_final`, cpu_4) runs the
updated accuracy suite including accepted-handoff and fallback cases on
TSUBAME. These are the current acceptance jobs; older probe jobs are done.

## Reproducing the final comparison

Prepare the reference snapshots in a checkout that has the baseline commit:

```sh
mkdir -p logs
git show 84466b0f:ext/SpinorBECCUDAExt/gpu_energy.jl > logs/baseline_gpu_energy.jl
git show 84466b0f:src/solvers/lbfgs/energy_gradient.jl > logs/baseline_energy_gradient.jl
git show 84466b0f:src/solvers/lbfgs/driver.jl > logs/baseline_lbfgs_driver.jl
qsub -g GROUP -o logs/solve64.out -e logs/solve64.err -v SPINORBEC_BENCH_GRID=64,SPINORBEC_BENCH_PREFIX=N64_ bench/submit_energy_solver_ab.sh
```

Both arms share the trial-projection correction. The control restores the
old energy reduction, generic two-loop direction, fused gradient-only GPU
entry, and L-BFGS driver. The candidate uses production dispatch. Same-grid
warmup precedes timing; final energy and projected gradient are independently
recomputed and certified at the returned state. A `weak` profile can be set
with `SPINORBEC_BENCH_PROFILE=weak`.

The one-off submit wrappers were consolidated into
`bench/submit_gpu_throughput.sh`, which takes a Julia script and its arguments.
The dedicated ABBA wrapper keeps all four solve arms on the same allocated GPU.
The historical `residual_polish_handoff.jl` probe now refuses the new driver;
use the production comparison above rather than injecting a second handoff.

Final production handoff tests on TSUBAME: job 8850914 passed all 28
assertions (12 existing, 6 trial-projection, 10 handoff/fallback). Local
smoke_fast passed all eight files after the final source edits.

First same-shape-warmed 64-cubed pair: baseline 6.257 s, candidate 3.989 s,
residuals 8.45e-14 and 8.38e-14. Candidate reports handoff accepted and
converged=true. Reverse order remains pending. Job 8850961 runs the final
128-cubed comparison after 8850913. Large/weak comparisons also run a saved
state cross-check: relative phase-aligned state error <= 1e-5 and energy
agreement to 1e-10, as well as both independently certified residuals.

Job 8850964 (`final_weak64`, prefix FINALWEAK64_) follows the 128-cubed job
serially. The generic benchmark launcher and ABBA wrapper both record
job-specific exit status, avoiding the earlier shared rc-file ambiguity.

Completed same-shape-warmed 64-cubed records: baseline 6.257/5.553 s,
candidate 3.989/3.451 s. Means 5.905 -> 3.720 s (1.587x). All four returned
residuals below 8.5e-14; both candidate handoffs were accepted. A separate
CPU job compares saved FINAL64_ states because this job predated the new
post-benchmark state comparator.

The final review expanded the existing optional-term GPU/CPU gate to call
`gradient_only!` too (including transverse Zeeman, LHY, tensor, magnetic
gradient, light shift, and Raman). It passed 163/163 on H100; this closes a
coverage gap that the earlier fused-gradient-only assertions did not address.
Additional existing line-search/iterate contracts passed 115/115 locally;
the GPU stall fixed-point gate passed 13/13 in job 8851024. Both this job and
the optional-term job have successful terminal accounting.

At 128 cubed, the baseline's first timed solve took 250.961 s and returned
residual 2.693e-13, above the internal polish target 1e-13 but far below the
requested 1e-8. This exposed an overly strict new handoff acceptance predicate:
it should check the public solve tolerance after running the original polish,
not require that the polish also beat its internal roundoff target. The local
predicate is corrected; the active 128-cubed job still uses the previous
predicate so its records are not mixed. No numerical tolerance or iteration
budget passed into the polisher has been changed.

The original 128-cubed allocation subsequently reached its runtime limit;
its candidate warmup took 433.358 s, but no timed candidate completed.
This is not an accepted comparison. Job 8851055 (`public128_ab`, prefix
PUBLIC128_) uses the corrected predicate and a one-hour allocation in
`/gs/fs/tga-kozuma-kouhi/uk07267/logperch-perf-20261002-v2`.
The original checkout remains unchanged for the weak-field job 8850964.
New benchmark records include SHA-256 hashes of the changed solver sources,
the benchmark, and the reference sources to distinguish these variants.

The new small-grid offset regression explicitly exercises a residual between
the internal and requested tolerances: adding a constant 1e4 to the oscillator
potential leaves the exact state unchanged, but returns residual 1.451e-11.
The expanded local handoff contract passes 15/15. Restoring the strict internal
acceptance predicate makes exactly its handoff assertion fail (14 pass, 1 fail),
showing that this test distinguishes the fix from the rejected implementation.
Job 8851069 passed the expanded accuracy suite (33/33) against the corrected
driver on TSUBAME CPU resources; qacct failed=0 and exit_status=0. Formatting,
diff checks, and all 43 prior-art dispositions pass; regenerating STATE.md
produces no diff.
