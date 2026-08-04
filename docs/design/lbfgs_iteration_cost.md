# What one L-BFGS iteration costs

> **FROZEN 2026-07-29.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Scope: `find_ground_state_lbfgs` (`src/solvers/lbfgs/`).

**This note replaces an earlier version whose headline numbers were wrong.**
Every figure it quoted came from a benchmark that measured its own startup
noise, and the conclusion it drew — "the two-loop recursion is 55-71 % of a CPU
iteration, and this branch is 1.6-2.4x faster" — does not survive a proper
measurement. What that mistake looked like is recorded at the end, because it is
a more useful thing to carry forward than the numbers were.

## Where the cost is

Eu-151 F=6, D=13, 24³, box 12, `m_lbfgs=20`, one `node_q` allocation,
`JULIA_NUM_THREADS=1`, ~5 minutes per measured point:

```
per-iteration                     235.6 ms
  energy_gradient!                 12.3 ms   ( 5.2 %)
  project x2                        1.3 ms   ( 0.5 %)
  sobolev precond                   2.6 ms   ( 1.1 %)
  two-loop dir                      9.8 ms   ( 4.2 %)
  line search TOTAL               223.9 ms   (95.0 %)   29.41 evals/iteration
```

**An iteration is its line search.** Everything else together is under 11 %,
and the two-loop recursion — which the earlier version of this note called the
dominant term — is 4 %.

The cost model is therefore

```
iteration = 26 ms  +  n · 7.6 ms
```

with `n` the number of total-energy evaluations the line search makes. It
reconciles: at the measured `n = 29.4` it predicts 224 ms against 236 ms
observed, closing to 5 %. `n` is now measured and returned
(`n_line_search_evals`), not inferred — the bench used to solve the residual
*for* `n`, which makes a breakdown close by construction and so can never
report that it does not.

## Why `n` was 29, and what that cost

`n ≈ 30` is the backtracking cap (`max_iter=30`). The line search was
exhausting it and returning `α = 0` on **94 % of steps**, after which the driver
threw the curvature history away and tried again from the same place.

That is not a solver defect. The problem's gradient floor is **5.03e-7**, and
the default `tol` is `1e-8` — fifty times below what an energy-gated line search
can resolve. The solve reaches the floor in a few dozen steps and then spends
every remaining step proving it cannot move: about 472 s of wall for ~0.9 s of
useful work, **99.8 % waste**, on a default-tolerance call.

Two changes follow, and they are worth two orders of magnitude more than
everything else here:

- **`stop_at_floor`** (default on). A line search that fails along the
  *steepest-descent* direction is conclusive: it leaves ψ, `grad` and `E`
  untouched with an empty history, so the next iteration rebuilds that exact
  direction from that exact gradient with that exact `E0` and repeats the same
  evaluations to the same answer. The iterate is a fixed point of the loop. No
  count and no tolerance are involved — one such failure ends the solve. (A
  failure along an L-BFGS direction is deliberately *not* conclusive: the reset
  to steepest descent is a genuinely different attempt and often succeeds.)
- **`floor_limited`**. `converged = false` cannot distinguish a solve that
  failed from one that got as far as the method allows, and the second is the
  common case. When the solver stops at its floor and that floor is above the
  `tol` it was asked for, it says so — with both numbers and the remedy, since
  `residual_polish=true` is not energy-gated and does reach below the floor.

## What the kernels are worth

The rest of this branch removes work outright. On a *descending* iteration
(`n = 1`, the healthy case) the model puts the largest of them — dropping the
duplicate total-energy evaluation — at

```
before: 26.0 + 2 x 7.6 = 41.2 ms      after: 18.5 + 1 x 7.6 = 26.1 ms
```

i.e. ~1.3x. That is a **model estimate, not a measurement**: this cell has no
descending regime long enough to measure, because it reaches its floor in a few
dozen steps. Measured directly at the floor — where the same change is diluted
thirty-fold by the futile evaluations — it is 244.3 → 226.0 ms, 1.08x, which is
consistent with the model.

Removed, each of them work whose answer the iteration already had:

1. **A second total-energy evaluation per iteration.** The line search
   evaluates `total_energy` at the step it accepts; `_lbfgs_grad!` then
   recomputed the same energy at the same ψ, because `energy_gradient!` returns
   `energy_decomposition(ws).total` on the CPU — a full second traversal of the
   registry. The line search now returns its accepted iterate, the driver adopts
   it rather than recomputing `psi += alpha*d` and renormalising, and the
   gradient goes through `gradient_only!` with the known energy passed in.
   Gated: `test_lbfgs_fast_path_equivalence.jl` asserts `total_energy` at the
   returned iterate equals the returned energy exactly, over a sweep of
   direction scales that exercises the backtracking branch, the expansion
   branch, and the corner where the first trial doubling is rejected.
2. **`_finalize_lbfgs_atomic!` evaluated the energy twice** — `total_energy(ws)`
   and then `energy_gradient!`, which returns that same total at that same ψ.
   Taking it from one pass also makes the `{psi, E, grad}` spine atomic by
   construction rather than by re-synchronisation.
3. **Per-iteration allocations.** `push!(s_hist, copy(s_k))` allocated two
   ψ-sized arrays every iteration and dropped two more. At capacity the evicted
   buffers are written into and re-pushed; `s_k`/`y_k` come from scratch.
4. **Three per-component FFT loops** — the Sobolev preconditioner, its forward
   metric, and the combined `P_V^½ P_K P_V^½` preconditioner had each
   independently grown the same `copy slice → fft → scale → ifft → copy back`:
   `2D` slice copies and `2D` single-transform plan calls per application. They
   share `batched_kspace_filter!` now, which transforms all `D` components in
   place and copies nothing. The filter is cached keyed on the IDENTITY of `k²`
   — two grids of the same shape but different box lengths have same-sized,
   differently-valued `k²`, so a size-keyed cache would be wrong.
5. **A host→device copy of `k²` per call.** `Grid.k_squared` is a host `Array`
   even for a GPU workspace, and the kinetic operator face ran `_to_device` on
   every call. Cached per grid by `_to_device_cached`.
6. **GPU per-call allocations.** `_gpu_energy_and_optional_grad` took its
   per-term buffer from `similar(psi)` on every call — and it is *both* the GPU
   `energy_decomposition` and the fused energy+gradient, so once per
   line-search trial too. `build_gradient_context` took the device density
   through the allocating `total_density`. MagneticGradient was evaluated
   unconditionally.

## Threading: measured negative

Splitting the two-loop's axpys across Julia threads made them **slower**, on an
exclusive node at 24³:

| threads | 1 | 4 | 16 | 48 |
|---|---|---|---|---|
| two-loop, ms | 9.8 | 22.6 | 13.2 | 32.4 |
| iteration, ms | 48.7 | 72.6 | 47.3 | 76.3 |

Each axpy is ~0.5 ms of real work and there are `2m` of them per direction, so a
`@threads` region per axpy is mostly launch cost — and that cost grows with the
thread count. The threading was removed. `_axpy!` is a sequential `@simd` loop,
bit-identical to the broadcast it replaces.

The dot products keep a 64-block structure but for **accuracy**, not
parallelism: blocking is one level of pairwise summation, so the error bound
improves from `O(n·eps)` to `O((n/64 + 64)·eps)`, gated against a `BigFloat`
reference on a deliberately ill-conditioned input. `_realdot` also avoids BLAS
`zdotc`, whose thread team is sized from the machine: worth 2.4 % here, because
BLAS level-1 only appears in the ~8 % of the iteration that is not the line
search. Pinning BLAS process-wide would have reached the same 2.4 % but would
also throttle the genuine level-3 work elsewhere (dense `eigen` in the
Bogoliubov solver), so the surgical version is preferred.

One negative result worth keeping: the first `_realdot` used hand-unrolled
scalar accumulators, chosen so the answer would be machine-independent. It
measured **8.20 ms against `zdotc`'s 7.72 ms** *with its blocks threaded* — the
scalar loads alone gave the whole advantage back. "Blocked and threaded" sounds
like it must be faster and was not.

## Two bugs found by the same reading

- The line search's expansion phase could return `best_E` while leaving the
  iterate at a **rejected** trial doubling: the guard was `best_alpha == alpha`,
  true exactly when the first doubling is rejected. Harmless while the driver
  recomputed the retraction; not harmless once it adopts the iterate.
- `result.dE` was **identically zero** from step 2 onward: `E_prev` was assigned
  the energy AT the accepted point, which is the same iterate `E_new` is
  measured at, so `abs(E - E_prev)` differenced a value against itself.

Both landed separately in #185.

## How the earlier numbers went wrong

Three compounding defects in the harness, each of which produced a confident
number:

1. **The estimator measured startup.** Per-iteration cost was
   `(t(20 steps) - t(4 steps)) / 16` — a difference of two ~1 s runs, each of
   which builds a workspace and plans FFTs under `FFTW.MEASURE`. Plan-measurement
   time varies by seconds between runs, so the "per-iteration" number was
   largely plan noise divided by sixteen. It moved the same baseline cell by
   20 % between jobs. With a ~450 s long arm the setup is 0.5 % and the slope is
   real.
2. **No differenced step ever had a full history.** `n_hi = 20` never exceeded
   `m_lbfgs = 20`, so the two-loop was averaging over depths 4-19 while the
   microbenchmark reported it at depth 20. That is how the component breakdown
   could show a part exceeding 100 % of the whole and nobody noticed.
3. **`tol = 0.0` measured the stall.** It was passed so that `n_steps` is
   consumed exactly and the slope is defined. The consequence is that
   essentially every measured iteration was a post-convergence one, at ~30
   futile energy evaluations. A change to one evaluation per iteration is
   diluted thirty-fold in that regime; the same change looks ~1.3x on a
   descending iteration and 1.08x at the floor.

Rules that fall out, and are now enforced by the bench itself:

- **Points are ~5 minutes and print their own step count and elapsed time.** A
  point that quietly ran for a second cannot then be read as a five-minute
  measurement.
- **Size the long arm from a slope, not from one short run.** Probing with a
  single 25-step run underestimated the steady-state iteration by 2x (116 ms vs
  245 ms) because most of those steps precede a full history — so a "5 minute"
  point ran for 11.
- **`n_lo` must clear `m_lbfgs`.**
- **Reconcile against a MEASURED count**, never one solved for from the residual.
- **Check the end state.** A cost measured on a solve that is not descending is
  a cost measured on the wrong problem. The bench now prints `E`, `|grad|` and
  `converged` next to the timing.

## Not done

- **A CPU fused energy+gradient.** The GPU has
  `_gpu_energy_and_optional_grad`; the CPU runs the registry twice. Fusing the
  line search's first trial with the gradient would replace an energy pass plus
  a gradient pass with one pass. Doing it without changing any energy value
  means fusing per term (share the forward FFT between `_kinetic_energy` and
  `_grad_kinetic!`, share the DDI potential between `_ddi_energy` and
  `_grad_ddi!`), not switching the energy faces to `factor·Re⟨ψ,Hψ⟩`.
- **The compact (Byrd-Nocedal-Schnabel) two-loop** would read each `s_i`, `y_i`
  once per direction instead of twice. At 4 % of an iteration it is not worth
  the summation-order change today.
- **Why the line search backtracks at all far from the floor.** `n` is the
  whole cost model; nothing here has measured it on a problem that is
  descending.
- **FFTW threads.** `FFTW.set_num_threads` has zero call sites, so every CPU
  transform is single-threaded. Plans capture the thread count at planning time
  and `FFTW.MEASURE` plan choice would change, so this is not a local decision.
- **`_grad_ddi!` ignores padding** while `_ddi_energy` honours it, so since
  `ddi_padding` defaulted on, a DDI ground state descends an unpadded gradient
  toward a padded energy. Correctness, not performance, and it changes every
  padded-DDI ground state, so it wants its own change.

## Measuring

`bench/bench_lbfgs.jl [cpu|gpu] [grid_n]`, with `SBEC_BENCH_SECONDS` (default
300) and `SBEC_BENCH_CELLS`. `bench/submit_lbfgs_blas_probe.sh` takes
`SBEC_POINTS` as `arm:julia_threads:blas_threads` triples and runs two
revisions back to back in one UGE job on one node — an A/B split across two jobs
puts a node-to-node and queue-epoch confound into the only number the work is
judged by. `bench/plot_lbfgs_ab.py` turns the logs into a CSV and a figure.

**On the DDI cells**: the benchmark calls `find_ground_state_lbfgs` directly,
where `ddi_padding` defaults to `false`, while the YAML parser has defaulted it
to `true` since 2026-07-29. A benchmark that bypasses the parser cannot see a
parser default flip; state which side of that line a number came from.
