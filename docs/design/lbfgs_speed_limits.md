# What limits L-BFGS on Eu-151 F=6 +DDI

> **FROZEN 2026-08-04.** A measurement report for the tree as of this date, not a
> maintained description of the code. Live sources: `CLAUDE.md`, and
> `src/solvers/lbfgs/` itself.

Scope: `find_ground_state_lbfgs` (`src/solvers/lbfgs/`), measured 2026-07-29 to
2026-08-04. Supersedes the per-iteration half of
[`lbfgs_iteration_cost.md`](lbfgs_iteration_cost.md), which is frozen at
2026-07-29 and no longer describes the code.

Two questions, answered separately because they have different answers:

- **What does one iteration cost, and what of that is avoidable?** Answered.
  Two things were collectable and are now collected: −27…−30 % on the GPU and
  −21 % on the CPU. Everything else was measured and closed.
- **Why are there ~600 iterations?** Answered: **conditioning**, and the method
  is achieving what its conditioning permits. The cheap fix that would follow
  does not work, because the soft end of the spectrum is a cluster.

Production cell throughout: Eu-151 F=6, D=13, 24³, box 12, `m_lbfgs=20`,
`OPENBLAS_NUM_THREADS=1`, `tol=1e-6`, ~600 iterations.

---

## 1. Per-iteration cost

Each point timed over 3 s of repeats. Breakdowns reconcile against a slope taken
over *working* iterations — a slope over `tol=0.0` differences post-convergence
steps and is what made an earlier version of this analysis wrong.

| pass | CPU contact / +DDI | GPU contact |
|---|---|---|
| `total_energy` | 6.6 / 7.1 ms | 1.306 ms |
| `gradient_only!` | 6.1 / 7.9 | 1.382 |
| `energy_gradient!` (before) | 12.8 / 15.1 | 1.383 |
| two-loop (m = 20) | 9.5 / 10.3 | 2.098 |
| `project_constraints` | 0.6 / 0.6 | 0.065 |
| iteration | ~30 / 32 | 5.83 |

### The redundancy, and how it differed by backend

`energy_gradient!` and `gradient_only!` are the **same fused kernel on the
GPU** — 1.383 against 1.382 ms — because the energy falls out of the pass that
forms `H·ψ`. The driver was nonetheless evaluating the line search with
`total_energy` and then running a separate gradient pass: 1.306 ms paid for a
number the next call produces for nothing.

α = 1 is accepted on 85–93 % of useful iterations (`n_ls` = 1.07–1.13), so
evaluating the first trial with `energy_gradient!` and reusing its gradient when
that trial is the accepted one removes the whole energy pass. **GPU: 6.88 → 4.81
and 7.15 → 5.21 ms/it, iteration count and energy bit-identical** (#278).

The CPU was excluded, and that was a measurement rather than caution: there
`energy_gradient!` traversed the term registry **twice**, once for the gradient
and once for `energy_decomposition`. Fusing would have cost 0.1 ms.

That second traversal is avoidable. `terms/base.jl` had already stated the
relation — each term's energy is a fixed multiple of its operator expectation,
`1` for one-body terms, `½` for the density-quadratic mean-field ones — so
`operator_and_energy_via_registry!` reads the energy off the accumulation
`grad` is already building: `Re⟨ψ,grad⟩` after term *k* minus the same after
*k−1* is `Re⟨ψ, H_k ψ⟩`. One extra reduction per term, no extra buffer, no
term's inner loop touched. `energy_gradient!` 14.2 → 8.8 ms, and the fusion
arithmetic inverts:

```
separate  1.08 × 6.63 + 7.71 = 14.9 ms
fused     8.53 + 0.08 × 6.63 =  9.1 ms
```

**CPU: 31.50 → 24.84 ms/it, −21.1 %, resolved at n = 10** through
`bench/ab_report.jl`; energy, `evals/it` and `grad_norm` unchanged (#302).

Total wall does **not** resolve (median −26.6 %, ranges overlap) because the
iteration count scatters ±25 % between processes — the solve is deterministic
*within* a process, and the FFTW plan chosen at startup changes the rounding and
diverges the trajectory. `wall = ms/it × iters` with `iters` statistically
unchanged gives an expected −21 %, which is an inference and not a measurement.

### One defect this exposed

`energy_operator_ratio(::LHYTerm) = 0.4` is right for the **closed form**
(`ε ∝ n^{5/2}`, `V = dε/dn` ⇒ `n·V = (5/2)ε`) and wrong for the implementation,
which integrates a piecewise-linear table: measured 0.96. Total energy off by
0.93 %, which made **every cached ground state fail its own verdict check** in
`test_gs_admission_axes.jl`. Declared `NaN` (non-derivable) rather than 0.96 —
a fitted constant where the physics derives one is a mistake this repository has
made before. **Open:** `ε` is the exact integral of the same piecewise-linear
`V` the propagator evaluates, so the relation is probably recoverable; that is a
change to `energy_contribution`, not a coefficient to guess.

---

## 2. Iteration count

`stop_at_floor` (#210) removed the largest single waste before this arc: the
default `tol = 1e-8` sits below this problem's ~5e-7 gradient floor, so 97.8 %
of 2000 steps burned a 30-deep backtrack and found nothing — ~472 s of wall for
~0.9 s of work. What follows is about the ~600 iterations that remain.

### The chain

| measurement | result |
|---|---|
| orbit fraction of a step | **2.4e-17** (positive control 1.000000). The step is orthogonal to the exact axial U(1) `e^{-iθ(L_z+F_z)}` orbit to machine precision. |
| sampled curvature | `κ_sampled ≈ 6e2` ⇒ 164–208 iterations vs ~600. Undecidable: a **lower** bound over the 20 directions the history holds. |
| decay rate | `κ_eff ≈ 9e3` from `‖∇E‖ ~ r^k`. Ratio 14.6 — still undecidable, one side is a bound. |
| spin-rotation generators | F_x, F_y at **0.23**, level with the sampled λ_min of 0.18. Exact generators 1.3e-4 ≈ 0. |
| λ_min bound | **λ_min ≤ 3.0e-2**, overlap 0.0000 with the exact generator ⇒ a genuine soft mode. |
| mode structure | **100 % spin, 97 % below 0.1·k_max, rank 1 in spin space to 99.6 %** (random control 8.1 % = 1/13 exactly). |
| block LOBPCG ladder | λ₁ = 3.07e-2 settled (2.3 % across b = 6 → 9); **λ₂ ≤ 4.27e-2 ⇒ gap ≤ 1.39**. |

### What it means

```
κ ≥ μ_max/λ_min = 1.4e2 / 3.0e-2 = 4.7e3     vs   κ_eff ≈ 9e3   (within 2×)
n = ln(1e-6)/ln((√κ−1)/(√κ+1)) = 472         vs   ~600 observed
```

**The method is achieving what its conditioning permits.** The apparent 15× gap
was `κ_sampled` being a poor lower bound, not the method losing.

Two hypotheses died on the way, both mine:

- **Gauge alignment / quotienting the symmetry.** The literature's remedy for a
  degenerate minimum ([Danaila & Protas](https://arxiv.org/abs/1703.07693);
  [arXiv:2603.28174](https://arxiv.org/abs/2603.28174), which also shows the
  degeneracy does not preclude local linear convergence — Morse–Bott holds when
  the minimisers are finitely many orbits, and one orbit is finitely many). It
  has nothing to recover here: the gradient is exactly orthogonal to an exact
  symmetry's orbit, normalisation preserves that, and the two-loop is built from
  gradients, so **every direction the solver can produce is orthogonal to the
  orbit**. The iterate never drifts along it.
- **A pseudo-Goldstone from an approximate symmetry.** Spin rotations about x
  and y are broken only by the DDI and the quadratic Zeeman, so they were the
  natural candidates. They come back at 0.23, level with the bulk of the
  sampled spectrum.

### Preconditioning is the lever, and the cheap version does not work

`P_C = P_V^½ P_K P_V^½` ([Antoine, Levitt & Tang](https://arxiv.org/abs/1611.02045),
where preconditioning *is* the dominant lever for trapped, gapped problems) was
measured **~40× worse** on this cell in 2026-06-23 (`d496dd71`). The mechanism
recorded at the time — "a diagonal preconditioner cannot precondition a
collective Goldstone" — does not survive the orbit measurement above; the
Goldstone is not in the iterate path. The real reason is visible in the mode:
`P_V` is diagonal in real space and structureless across the 13 spin
components, and the mode is **100 % spin**; `P_K` is nearly constant over the
mode's low-k support. Neither factor can see it.

The mode being rank 1 in spin space suggests a rank-1 deflation,
`P = I + (1/λ₁ − 1)v₁v₁†` — one global dot and one axpy, free against a 25 ms
iteration. **It does not pay.** After deflating one mode `κ = μ_max/λ₂`, and

- λ₁ = 3.07e-2 is settled (moves 2.3 % between block sizes, and matches an
  independent single-vector bound of 3.0e-2);
- λ₂ ≤ 4.27e-2, so the true gap is **≤ 1.39**, against the ~3 needed.

The bound goes the right way — λ₂ can only fall — so this is established, not
suspected. Rank-1 deflation moves κ from 4.5e3 to at best 3.3e3: n from ~470 to
~400, **about 15 %**. And there is no gap above 3 anywhere in a 9-mode block
spanning 3.07e-2…9.99e-2, so a useful preconditioner needs **rank > 9**,
unbounded by this measurement. That is a different and not-cheap design.

---

## 3. Levers measured and closed

| lever | verdict |
|---|---|
| line search (interpolation, Wolfe, initial α) | **1.07–1.25 evals/it** in the useful regime — α = 1 is accepted. Nothing there. The 29.4 evals/it in the frozen note was the post-convergence stall. |
| `m_lbfgs` | per-iteration cost linear in m (0.2–0.4 ms per unit) but the +DDI iteration count rises as m falls; **total wall flat over m = 5…40** across three `c1_ratio` values. |
| threading the two-loop | negative: 9.8 → 22.6 → 32.4 ms at 1 / 4 / 48 threads. |
| `history_precision = Float32` | −3.6 ms/it in both cells, but +16–36 % iterations on +DDI ⇒ **net loss up to 21 %**; −9 % on contact. Opt-in, default `Float64` (#255). |
| CPU energy/gradient fusion, before #302 | `energy_gradient!` 12.80 == `total_energy` 6.57 + `gradient_only!` 6.11. Zero. |
| combined preconditioner `P_C` | ~40× worse, structurally (see above). Off by default and pinned as such (#298). |
| rank-1 deflation of the soft mode | ~15 %, because the soft end is a cluster (#318). |

## 4. Open

- The LHY energy ↔ operator relation for the tabulated modes (§1).
- A preconditioner of rank > 9 acting in spin space. The mode's structure says
  what it must diagonalise; nothing says it is affordable.
- GPU: the two-loop is 2.098 of 5.83 ms (36 %) and was never attacked there.

## 5. How this was measured

`bench/ab_driver.sh` + `bench/ab_report.jl` (#301). The driver holds four
invariants, each of which was violated by a hand-rolled script during this arc
and each of which cost a wrong or unattributable answer: refuse a dirty tree and
stamp every row with the SHA; full SHAs, never branch names; interleave the
arms; harvest rows from the raw log rather than filtering at generation. The
report refuses to state a difference smaller than the spread *within* an arm.

It earned itself immediately: it refuted a "−20 % iterations, systematic" claim
of mine twice, on the same branch, from the same data I had read by eye.

Probes, all under `bench/`: `probe_lbfgs_line_search.jl`,
`probe_lbfgs_history_depth.jl`, `probe_lbfgs_pass_costs.jl`,
`probe_inline_energy_accumulation.jl`, `probe_lbfgs_orbit_fraction.jl`,
`probe_lbfgs_curvature_spectrum.jl`, `probe_lbfgs_soft_modes.jl`,
`probe_lbfgs_lambda_min_bound.jl`, `probe_lbfgs_soft_mode_structure.jl`,
`probe_lbfgs_soft_mode_block.jl`, `rayleigh_descent.jl`.

### What went wrong with the instruments

Recorded because it cost more than the physics did, and because every one of
these was a decision rule that read a state its own instrument had already
computed:

- **Four verdicts fired on a non-converged or absent state.** A null with signal
  and control both `0.0000` (from a fixture where the two generators coincide);
  "no such mode found" printed after a fixed iteration count while the quotient
  was still falling 8 % per step; "ISOLATED" from the ratio of two unconverged
  upper bounds; a coverage claim asserted as a *count*, which cannot say what is
  missing.
- **Then the correction overshot**: the block verdict demanded λ₂ converge when
  the question needed only one side of the bound. λ's here are upper bounds, so
  `gap ≤ 3` establishes a cluster with no convergence required while `gap > 3`
  does not. Ask which direction a bound goes before demanding convergence.
- **A per-term gate whose fixture activated 5 of 14 terms.** When its coverage
  guard failed I lowered the threshold, and when I replaced the count with names
  I listed only the terms already lit. The defect it existed to catch — the LHY
  ratio — was found by an unrelated cache-hit test. **When a coverage assertion
  fails, widen the fixture, never the threshold.**
- **Two measurement tables withdrawn** for reasons that were not physics: an
  estimator differencing two ~1 s runs of a ~50 ms quantity, and jobs running a
  dirty worktree while printing a clean commit (`FETCH_HEAD` is shared across
  worktrees, and `git checkout --detach` aborts on a dirty tree without stopping
  the job).
