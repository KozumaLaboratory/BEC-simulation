# What one L-BFGS iteration costs

Scope: `find_ground_state_lbfgs` (`src/solvers/lbfgs/`). This note records the
shape of the per-iteration cost and the redundancies removed on 2026-07-29, so
that the next person optimising it starts from the structure rather than from a
profile.

## Measured

TSUBAME, one UGE job on one node (`gpu_h`, `JULIA_NUM_THREADS=8`), both
revisions back to back — `550fe24e` (= `main`) against `915869c2`. Wall time
per L-BFGS iteration, as the slope of wall against `n_steps`; Eu-151 F=6,
D=13, box 12, `m_lbfgs=20`. Figure and full component breakdown:
`docs/figs/lbfgs_iteration_cost_ab.{png,csv}`.

| cell | CPU before | CPU after | | GPU before | GPU after |
|---|---|---|---|---|---|
| 16^3 contact | 14.27 ms | **8.26 ms** (1.73x) | | 4.22 ms | 4.26 ms |
| 16^3 +DDI    | 16.71 ms | **9.29 ms** (1.80x) | | 4.44 ms | 5.10 ms |
| 24^3 contact | 49.86 ms | **30.92 ms** (1.61x) | | 5.12 ms | **4.76 ms** (1.08x) |
| 24^3 +DDI    | 59.65 ms | **32.45 ms** (1.84x) | | 6.51 ms | **5.23 ms** (1.24x) |

The GPU 16^3 column is **inside run-to-run scatter** and no claim is made
there: an earlier job measured the same baseline cells at 4.82 and 5.29 ms,
a 14-19 % spread, which is larger than the difference. The 24^3 GPU cells
moved the same way in both jobs. The CPU column is unambiguous in every cell.

Component that moved most: the two-loop recursion, 10.1 -> 2.5 ms at 16^3 and
32.7 -> 7.7 ms at 24^3 (~4x, from splitting its axpys across threads). The
Sobolev preconditioner on the GPU went 0.46 -> 0.035 ms once it stopped
copying slices.

Reading the breakdown: it reconciles to -1.1 % on the baseline, so the
baseline split is trustworthy. It does **not** reconcile on the optimised
revision (residuals of -10 to -48 %), because the bench measures
`energy_gradient!` while the optimised driver calls `gradient_only!` — the
component model no longer matches the code. Per `bench/reconcile.jl`, an
unreconciled breakdown is not evidence; only the end-to-end slope is quoted
above, and it is measured identically in both arms.

## Gates

`tier=ci` at `915869c2`: 258 files, all passed, including
`test_lbfgs_fast_path_equivalence.jl` (44/44). That gate was moved from
`FULL_EXTRA` into `CI_EXTRA` on purpose — every other L-BFGS test lives in
`FULL_EXTRA`, so the earlier green `ci` run had executed 257 files without
running a single L-BFGS test.

`tier=full` at `e8f4eb6e` fails 7 files. All 7 fail identically on `550fe24e`
(= `main`), which fails one more (`workflow/test_phase_diff_eval.jl:75`) — the
branch's failure set is a strict subset of the baseline's. Among them,
`solvers/test_lbfgs_accuracy_floor.jl:118` ("Newton-CG polish tightens the
gradient floor") is worth flagging: on `main` that polish returns a
**bit-identical** psi — every trust-region step rejected, so the pass is a
no-op — and the L-BFGS gradient floor it is compared against is not
reproducible run to run (5.7e-10, 1.4e-8 and 2.8e-8 measured for the same
commit and problem, while the energy is bit-exact at `E - 0.5 = -2.2e-16`).

## The iteration

```
direction   two-loop recursion over the m-deep (s, y) history      2m dot + 2m axpy
line search retract to the manifold, evaluate E                    k trials
step        adopt the accepted iterate
gradient    H·psi over the HamTerm registry, project, precondition  1 registry pass
history     y = g_new - g_old, push (s, y, rho)
```

with `m = m_lbfgs` (default 20) and `k` the number of line-search trials
(usually 1: the two-loop direction is curvature-scaled, so `alpha = 1` is the
Newton step and Armijo accepts it).

Three families of work, with quite different scaling:

- **Spectral**: kinetic (`D` FFT pairs), DDI (a 6-transform convolution),
  Sobolev preconditioning (one FFT pair over all `D` components). Scales with
  `n log n`.
- **Registry-wide broadcasts**: density, spin density, trap/Zeeman/c0/c1/LHY
  diagonals. Linear in `n·D`.
- **History traffic**: the two-loop recursion touches `2m` psi-sized arrays,
  twice each. At `m = 20`, `24^3`, `D = 13` that is a few hundred MB of memory
  traffic per iteration and is bandwidth-bound, not flop-bound. It is
  independent of the physics: an F=1 contact-only problem pays it too.

## What was removed (2026-07-29)

Each of these was work whose answer the iteration already had.

1. **A second total-energy evaluation per iteration.** The line search
   evaluates `total_energy` at the step it accepts. `_lbfgs_grad!` then
   recomputed the same energy at the same psi, because `energy_gradient!`
   returns `energy_decomposition(ws).total` on the CPU — a full second
   traversal of the registry. The line search now returns its accepted iterate
   (`psi_accepted`), the driver adopts it rather than recomputing
   `psi += alpha*d` and renormalising, and the gradient goes through
   `gradient_only!` with the known energy passed in.

   The coupling is deliberate and is gated: `test_lbfgs_fast_path_equivalence.jl`
   asserts that `total_energy` at the returned iterate equals the returned
   energy exactly, over a sweep of direction scales that exercises the
   backtracking branch, the expansion branch, and the corner where the first
   trial doubling is rejected.

2. **`_finalize_lbfgs_atomic!` evaluated the energy twice** — `total_energy(ws)`
   followed by `energy_gradient!`, which returns that same total at that same
   psi. Taking it from the one pass also makes the `{psi, E, grad}` spine atomic
   by construction instead of by re-synchronisation.

3. **Per-iteration allocations.** `push!(s_hist, copy(s_k))` allocated two
   psi-sized arrays every iteration and dropped two more for the GC (or the CUDA
   pool). At capacity the evicted buffers are now written into and re-pushed;
   `s_k` and `y_k` themselves come from the shared scratch registry.

4. **Three per-component FFT loops.** The Sobolev preconditioner, its forward
   metric (`_sobolev_metric!`, Newton-CG's trust-region norm) and the combined
   `P_V^1/2 P_K P_V^1/2` preconditioner had each independently grown the same
   `copy slice -> fft -> scale -> ifft -> copy slice back` loop: `2D` slice
   copies and `2D` single-transform plan calls per application. They now share
   `batched_kspace_filter!`, which transforms all `D` components in place
   through the batched plan pair in `ws.batched_kinetic` and copies nothing.
   The filter itself is cached by `cached_kspace_filter`, keyed on the identity
   of `k^2` — two grids of the same shape but different box lengths have
   same-sized, differently-valued `k^2`, so a size-keyed cache would be wrong.

5. **A host-to-device copy of `k^2` per call.** `Grid.k_squared` is a host
   `Array` even for a GPU workspace, and `apply_operator!(::KineticTerm, ...)`
   ran `_to_device(ws.backend, ws.grid.k_squared)` on every call — a fresh
   `CuArray` plus a full transfer per gradient and per energy evaluation.
   `_to_device_cached` allocates and copies once per grid.

6. **GPU per-call allocations.** `_gpu_energy_and_optional_grad` took its
   per-term buffer from `similar(psi)` on every call, and it is *both* the GPU
   `energy_decomposition` and the fused energy+gradient — so once per
   line-search trial as well as once per gradient. `build_gradient_context`
   took the device density through the allocating `total_density`, although
   `_total_density!` is already the GPU-safe broadcast form. MagneticGradient
   was evaluated unconditionally (a fill, an apply, a dot and an accumulate for
   a term that is absent in most configs).

## Two bugs found by the same reading

- The line search's expansion phase could return `best_E` while leaving the
  iterate at a **rejected** trial doubling: the guard was `best_alpha == alpha`,
  which is true when the very first doubling is rejected. Harmless while the
  driver recomputed the retraction; not harmless once it adopts the iterate.
  The guard is now on the last evaluated alpha.
- `result.dE` was **identically zero** from step 2 onward. `E_prev` was assigned
  `E_trial` — the energy AT the accepted point, which is the same iterate
  `E_new` is measured at — so `abs(E - E_prev)` differenced a value against
  itself. `E_prev` is now the energy before the step.

## Not done, and why

- **Fusing the line search's first trial with the gradient.** Since `alpha = 1`
  is usually accepted, computing E and grad together there would make the
  iteration cost one fused pass instead of one energy pass plus one gradient
  pass. Worth it only if the acceptance rate is high; measure it first.
- **Threading the two-loop *dot products*.** The axpys are already split
  (`_axpy_threaded!`); the dots are not, because splitting a reduction changes
  its summation order and this solver already sits close enough to the
  `sqrt(eps)` floor for that to be visible. They are now the larger half of
  what remains of the two-loop.
- **The compact (Byrd-Nocedal-Schnabel) form** would read each of `s_i`, `y_i`
  once per direction instead of twice, halving the history traffic, and would
  put it through BLAS-2. It changes the summation order, so it needs its own
  accuracy gate first.
- **FFTW threads.** `FFTW.set_num_threads` has zero call sites in the project,
  so every CPU transform is single-threaded. The blast radius is the whole
  codebase (plans capture the thread count at planning time, and plan choice
  under `FFTW.MEASURE` would change), so this is not a local decision.

## Measuring

`bench/bench_lbfgs.jl [cpu|gpu] [grid_n]` reports the end-to-end cost per
iteration as the *slope* of wall time against `n_steps`, so setup, JIT and
finalisation drop out, and breaks it into components measured with
`bench/reconcile.jl`'s warm-up-and-minimum `timed`. `bench/submit_lbfgs_bench.sh`
runs two revisions back to back in one UGE job on one node — an A/B split
across two jobs would put a node-to-node and queue-epoch confound into the only
number the work is judged by. `bench/plot_lbfgs_ab.py` turns the logs into a
CSV and a per-iteration figure.

**Caveat on the DDI cells.** The benchmark calls `find_ground_state_lbfgs`
directly, where `ddi_padding` defaults to `false`; the YAML parser has
defaulted it to `true` since 2026-07-29. So the DDI numbers here are the bare
periodic kernel, and a YAML production run pays a larger transform for the DDI
*energy*. Its DDI *gradient* is still the unpadded kernel either way, because
`_grad_ddi!` has no padded branch while `_ddi_energy` does — which is a
correctness question, not a performance one, and is not fixed here. A
benchmark that bypasses the parser cannot see a parser default flip; state
which side of that line a number came from.
