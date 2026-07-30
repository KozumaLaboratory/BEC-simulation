# Testing a simulator with no experiment

This code predicts things nobody has measured. ¹⁵¹Eu at $F=6$ has seven unknown
scattering channels; the phase diagram we compute is the reason the code exists.
So "compare to the answer" is unavailable, and any test that pretends otherwise
is pinning a number a past run happened to produce.

This document is the authority on what a test in this repository is allowed to
claim, how the suite is kept prunable, and what to do when it goes red. It is
the *why*; `test/runtests.jl` and `test/_tiers.jl` are the *what runs*.

## 1. The five ways to ground a claim

Without a measurement, correctness can only come from these. Every test must be
one of them, and must say which.

| method | what it asserts | tolerance comes from |
|---|---|---|
| `exact` | agreement with a closed form computed *inside the test* | the discretisation, derived |
| `order` | the error *scales* at the theoretical rate under refinement | the fitted exponent's CI |
| `invariant` | a conserved or algebraic property holds | machine epsilon × condition number |
| `metamorphic` | an observable transforms correctly under a symmetry | machine epsilon |
| `differential` | two independent statements of the same physics agree | machine epsilon, or a stated model gap |

`order` is the strongest tool available here and the most underused. It needs no
true answer at all: for the Strang sandwich the one-step error must fall as
$\Delta t^{3}$ and the global error as $\Delta t^{2}$; for a spectral derivative
the error must fall faster than any power of $\Delta x$. A wrong coefficient
changes the constant and passes a threshold test; a wrong *operator ordering*
changes the exponent, and only an order test sees it. `_YOSHIDA_W0` is exactly
this shape: breaking $\sum_i w_i = 1$ leaves every single-$\Delta t$ tolerance
green.

`metamorphic` is the second most underused. Translate the state and the trap
together and the energy must not move; rotate the spinor and the field together
and $|\langle \mathbf{F}\rangle|$ must not move; send $B \to -B$ and
$\langle F_z\rangle$ must change sign. None of these needs a reference value, and
they hold at $F=6$ where nothing else does.

## 2. The two things that are not grounding

- **`pin`** — a numeric literal from a past run (`@test E ≈ 0.4271`, `@test err
  < 1e-3`). Detects *change*, which is often a bug, so pins are worth having.
  They cannot support a physics claim, and they go red on every legitimate
  improvement. A tolerance that was chosen because it made the test pass is a
  pin no matter how physical the quantity looks.
- **`api`** — a spelling: a key name, a type, a `@test_throws`. Worth having for
  schema surfaces users type by hand. Also not a physics claim.

The rule that follows: **a pin may not be the only test defending a claim.** If
deleting every `order`/`invariant`/`metamorphic`/`differential`/`exact` test for
some physics leaves only a pin, that physics is untested.

## 3. Claim × path, not claim

A term is right in one place and wrong in another far more often than it is
wrong everywhere. The incident record here is almost entirely of this shape: the
LHY table was dropped on six separate paths while the sign was single-declared
and correct; the DDI energy branched on zero-padding while the gradient did not;
the fused RTP half-step declined padded DDI and the benchmark that would have
noticed bypassed the parser.

So the unit of coverage is the pair (claim, path), not the claim. The paths that
exist here:

`registry` · `fused` (spin-chain) · `gpu` · `lbfgs`/gradient · `yaml` (parser
defaults) · `dumb` (reference RHS) · `padded` vs bare · `f32`

An empty cell is a gap regardless of how many tests the claim already has.
`_spin_chain_reason` is the canonical enumeration of what a fusion would
otherwise silently drop — every entry in it needs an arm.

## 4. Test at the layer the claim lives at

The code is a stack, and so is the cost:

| layer | what it is | what its tests may assert | budget |
|---|---|---|---|
| L0 primitives | pure functions: spin matrices, Clebsch-Gordan, composition coefficients, $c \leftrightarrow g$, $Q$-tensor, filters | algebraic identities, exact values, order conditions | ms each, < 15 s total |
| L1 operators | one `HamTerm`, three faces | FD consistency, hermiticity, sign, per-term GPU = CPU, reference-RHS diff | < 60 s |
| L2 stepping | composition of operators | unitarity, time-reversibility, order of accuracy, fusion bit-identity | < 120 s |
| L3 solvers | ITP / L-BFGS / RTP loops | convergence to an exactly-known minimum, iteration monotonicity | < 120 s |
| L4 workflow | YAML → spec → run | wiring only: reachability, schema round-trip, CAS determinism, resume | < 120 s |

**A test belongs at the lowest layer that can express its claim.** A defect caught
at L4 arrives with no localisation and costs two to three orders of magnitude
more to detect than the same defect caught at L0.

The measured state of this suite when the rule was written: 117 files classified
as "primitive" carried 847 s, i.e. **389 ms per assertion** — nothing at that
price is a primitive test. Almost everything builds a `Workspace` or runs a
simulation, whatever it is actually asserting.

### The descent procedure

For each expensive test, write down the claim, then ask what it is standing in
for. Two worked examples:

**Yoshida order.** `test/solvers/test_yoshida_ddi_order.jl` runs sixteen
Eu $F=6$ ($D = 13$) $6^3$ split-step simulations with DDI at four $\Delta t$
levels — 14 s, `full` tier, off the PR gate, and red means "the order collapsed
somewhere". It decomposes into three separate claims:

- L0 — the composer coefficients have the claimed order.
  `test/hamiltonian/test_composer_order_conditions.jl`, 8×8 matrices, ms.
- L1 — each substep is a faithful $e^{H\Delta t}$, *including for $\Delta t < 0$*,
  which the Yoshida middle substep needs.
  `test/oracles/test_negative_dt_substeps.jl`.
- L3 — the spinor stack realises that order with real operators. One cell.

The 2026-07-29 regression was the L1 claim (a substep silently no-oped for
$\Delta t < 0$), and the L3 test was the only thing that saw it.

**Per-path physics reachability.** Six incidents of `ws.lhy` being dropped on one
path produced six files. The claim is one table — (block × path) — and it is
`test/workflow/test_yaml_physics_reaches_workspace.jl`. A new path is a row.

### The trap: a cheap stand-in must keep the structural assumptions

The first version of the composer test used a generic pair of non-commuting
matrices, and reported that `_COMP_BLANES_MOAN_S6` is 4th order. That conclusion
happened to be right, but the test was wrong: these are RKN-type composers whose
extra order conditions are bought with $[V,[V,[V,K]]] = 0$, and a generic pair
does not have that structure. Testing a structure-exploiting method on a
structure-free example measures a different method.

The verified form uses the split the propagator actually performs — kinetic
diagonal in $k$, potential diagonal in $x$ — and was cross-checked against a pair
satisfying the RKN condition exactly. **Descending a test means preserving its
assumptions, not just shrinking its inputs.**

### Canary every new gate

A gate that passes against the known-bad code is worse than no gate, because it
reads as coverage. Every new gate is run against a deliberately broken version
of the code it defends, and must go red. Two of the three fixture attempts for
`test_negative_dt_substeps.jl` passed against the known-bad code — the first
because $F=1$ dispatches to a different kernel than the $F \geq 2$ path holding
the defect, the second because the guard's floor is $10^{-14}$ and a Gaussian
tail on an 8-point box does not reach it. Only a fixture with a genuine vacuum
voxel — what every trapped cloud has — reproduced it.

## 5. Instruments

### `test/_inventory.jl` — what each file *can* prove

Classifies every test file by the strongest method it uses, and reports the cost
of each class per directory. Run it before adding a test: if the directory you
are adding to is mostly `pin`, adding another pin is not progress.

```
julia test/_inventory.jl [--files] [--csv out.csv]
```

### `test/mutation/` — what each file *does* catch

The catalog (`test/mutation/catalog.jl`) is the incident log in executable form:
each entry is a defect that actually happened here, reduced to the smallest edit
that reproduces its shape, anchored to the source by a regex that must match
exactly once. The harness injects each one and records which test files go red.

```
julia --project=. test/mutation/run.jl --workers 12
```

It answers three questions that reading tests cannot:

- a mutant **no** test catches is a gap, ranked by the severity of the physics
  error it causes;
- a file that catches nothing another file does not also catch is a deletion
  candidate — *evidence, not proof*, since the catalog only covers cataloged
  classes;
- the minimum-cost file subset covering every mutant is what a `fast` tier
  should be, rather than the files that happen to run quickly.

An anchor that stops matching is reported STALE and aborts the run. A catalog
entry that silently stops testing anything is the failure mode the catalog
exists to prevent, so it is never allowed to be silent.

Cost is one package precompile per mutant, so this is an on-demand and nightly
instrument, never a PR gate.

### `test/oracles/` — the standing gates

Already organised along the five methods (analytic / covariance / conservation /
parity / per-term FD consistency). This is the part of the suite to imitate.

## 6. Growth control

The suite reached 326 files and ~2,800 s of modelled serial cost by depositing
one file per incident, with nothing recording what any file defended, so nothing
could ever be removed. Three rules keep that from recurring:

1. **A new test either fills an empty (claim, path) cell or adds a row to the
   test that already owns that cell.** Adding a file is not the default.
2. **Each tier has a wall-clock budget.** A test that does not fit displaces
   one; it does not extend the budget.
3. **Pins are quarantined.** They may run, but they may not be the gate on a
   physics claim, and they are expected to be re-baselined rather than debugged
   when an intended improvement moves them.

## 7. Triage when the suite goes red

Classify before debugging. The method tells you what red means:

- `order`, `invariant`, `metamorphic`, `differential`, `exact` red → **the code
  is probably wrong.** These do not go red on legitimate changes.
- `pin` red → *did the number move for a reason?* If yes, re-baseline and record
  why in the commit. Do not widen the tolerance.
- `api` red → the surface changed on purpose; update the test, or the rename was
  incomplete.
- infrastructure red (timeout, unrun file, missing GPU) → not a test result at
  all. An unrun file must never be reported as a pass; the runner writes a
  per-file verdict marker specifically so this cannot be confused.

Widening a tolerance to make a test pass converts a grounded test into a pin.
If that is the right call, say so and change the label.

### The suite does not run the code production runs

`Pkg.test()` compiles with `--check-bounds=yes`, which disables `@inbounds` and
therefore changes vectorisation and summation order. Any quantity that lives at
round-off reads *differently* inside the suite than in a plain build. Measured on
the finite-difference Hessian's homogeneity residual: $1.3\times10^{-16}$ plain,
$4.7\times10^{-11}$ under `--check-bounds=yes` — a factor of $3\times10^{5}$, and
constant, not noisy.

Two rules follow:

- A tolerance calibrated in a REPL will fail under `Pkg.test()` if the claim is
  round-off-limited. Derive the bound from the construction (here: gradient
  round-off $\sim 10^{-16}$ divided by the finite-difference step $2\varepsilon$),
  not from one measurement.
- "Green standalone, red in the suite" is not automatically cross-test
  contamination. Check the codegen difference first — it is cheaper to test and
  it was the answer both times it was checked here.

### …and the default FFT planner is not reproducible

`FFTW.MEASURE` — the production default for every `make_workspace` — benchmarks
candidate algorithms at plan time and keeps the fastest, so the summation order of
every transform depends on machine load. Measured on the L-BFGS projected-gradient
floor, four fresh processes each:

| planner | grad_norm |
|---|---|
| `MEASURE` | 1.709e-8 · 2.130e-8 · 5.258e-8 · 1.709e-8 (energy varies in its last two digits) |
| `ESTIMATE` | 4.1453063004739704e-9 × 4 (energy identical to all digits) |

So a round-off-limited quantity is not even reproducible run to run under the
production planner, let alone comparable to a recorded value. `test/runtests.jl`
sets `SPINORBEC_FFT_ESTIMATE=1`, which switches `default_fft_flags()` to the
deterministic planner for the suite only (`src/foundation/fft_planning.jl`).

This does not make such quantities meaningful — a pin on round-off is still a pin.
It makes them REPRODUCIBLE, which is what lets a test distinguish "the code
changed" from "the plan changed". Both of the tests that were mysteriously "green
alone, red in the suite" were round-off claims; the two effects above are why.
