# SpinorBEC.jl

[![CI](https://github.com/KozumaLaboratory/BEC-simulation/actions/workflows/ci.yml/badge.svg)](https://github.com/KozumaLaboratory/BEC-simulation/actions/workflows/ci.yml)

A general-purpose solver for the spinor Gross–Pitaevskii equation: arbitrary
spin $F$, 1D/2D/3D, contact + dipolar + LHY + Raman/Zeeman, on CPU or CUDA,
driven entirely from YAML.

## What it does well

- **Arbitrary $F$.** The whole stack (spin matrices, Clebsch–Gordan, tensor
  interactions, observables) works for any $F$, not just $F=1$ or $F=2$.
  Polyhedral state classification verified through $F=12$ (Paper #3); the
  production target is ¹⁵¹Eu ($F=6$, 13 components).
- **A species registry, not a hard-coded atom.** Alkalis (Li, Na, K, Rb, Cs),
  alkaline earths and Yb, the magnetic species (Cr, Dy, Er, Eu) and metastable
  He\* ship with their masses, $g_F$ factors and scattering lengths; a run
  selects one by name.
- **Dipolar interactions are first-class.** $k$-space convolution in 6 FFTs,
  zero-padded or quasi-2D (erfcx kernel), with the spin-orbital coupling
  needed for Einstein–de Haas dynamics.
- **A rotating-basis solver for fast magnetostir.** When the magnetic-field
  direction $\hat B(t)$ varies on a timescale comparable to the Larmor
  precession, the standard spinor split-step blows up unless $\Delta t$ is
  pushed to absurd values. The `kind: rotating_basis` path co-rotates with
  $\hat B(t)$ and absorbs the Larmor phase analytically, so Klaus-2022-style
  protocols just work.
- **YAML in, results out.** A run is one YAML file: `pipeline:` (ground
  state → dynamics → analysis), `scan:` for sweeps, optional
  `calibration_history:` so lab-deck values (mV, mW) are written verbatim
  and parsed into physical units. Re-running a YAML resumes from the last
  completed point — and refuses to resume across a code change, because a
  cached point carries the commit that produced it.
- **GPU is not an afterthought.** Both kinetic and DDI paths are CUDA-native
  (CUFFT, in-place broadcasts), with a mixed-precision F32 path for large
  grids.
- **A live dashboard.** `serve_dashboard` exposes runs in a React + WebGPU
  UI: 3D volume raymarch, per-component column densities, scan heatmaps,
  and a status panel for in-progress runs.

## Usage

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run
julia --project=. -e 'using CUDA, SpinorBEC; run_yaml("runs/eu151_edh/config.yaml")'

# Browse
julia --project=. -e 'using SpinorBEC; serve_dashboard(8765; base_dir="runs")'

# Or from the CLI: inspect / launch / figure / preflight / autopilot / tag / catalog
julia --project=. scripts/cli.jl inspect runs/eu151_edh/config.yaml
```

`inspect` type-checks a config against the schema and grades what it finds
(block / error / warn / info) before anything is submitted — worth running on
any config that is about to cost GPU hours.

WSL2 GPU users: prepend `LD_LIBRARY_PATH=/usr/lib/wsl/lib`.

## Physics

$$H = \sum_m \int \psi_m^\ast \left[ -\tfrac{\nabla^2}{2} + V - p\,m + q\,m^2 + c_0 n + c_1 \langle\mathbf{F}\rangle \cdot \mathbf{F} + H_{\mathrm{ddi}} + c_{\mathrm{LHY}} n^{5/2} + H_{\mathrm{Raman}} \right] \psi_m \, d\mathbf{r}$$

— schematic; each term is switched on independently, and the LHY term takes
several forms (below). Internal units are dimensionless
($\hbar = m = \omega_{\mathrm{ref}} = 1$); the `Units` module handles physical
conversion. Higher-rank tensor interactions ($S = 4, 6, \ldots$) are built
from Clebsch–Gordan coefficients.

The beyond-mean-field (LHY) term is selected explicitly rather than assumed —
`scalar` and `quasi_2d` for the single-component limits, closed forms for
polar and ferromagnetic states (contact and dipolar), an icosahedral form,
and `full_bdg`, which integrates the Bogoliubov spectrum numerically and so
applies to any $F$ and any spinor. Each has a stated validity domain that the
config checker knows about — asking for the icosahedral form at $F \neq 6$, or
the two-channel form at $F = 6$ where it is 30–70 % off, is warned about by
default and refused under `strict` — and a form whose closed expression turns
non-finite in the requested regime fails at table-build time rather than
propagating a NaN into $\psi$. The closed forms are roughly two orders of
magnitude cheaper where they do apply. All of them take a single spinor for
the whole cloud, which is
exact for a uniform state and a few per cent on a real texture — `spatial`
tabulates against $|\langle\mathbf{F}\rangle|/F$ instead when that matters,
and reports its own residual.

A pipeline step chooses its equation of motion with `kind:`:

- `spinor` (default) — standard spinor GP. Static fields, weak-field phase
  transitions.
- `rotating_basis` — Larmor-following frame, for fast magnetostir and any
  protocol where $\hat B$ rotates faster than $1/\omega_{\mathrm{ref}}$.
- `binary` — two-component GP.

Everything else composes onto a step rather than replacing it, so a single run
can stack them: `sgpe:` (stochastic GPE — a growth/energy-damping reservoir,
the honest route to a finite-temperature initial state), `projected_gp:`
(number-conserving projection), `photon_scattering:`, `loss:` (three-body),
`absorbing_boundary:`, `adaptive_dt:`. `twa:` is different again — it wraps the
step in Truncated-Wigner sampling over an ensemble of trajectories.

Ground states use imaginary-time propagation or LBFGS; dynamics use
Strang/Yoshida integrators.

## Repository layout

```
src/    Solvers, Hamiltonian terms, workflow, analysis
runs/   YAML configs (Klaus magnetostir, Einstein–de Haas, phase diagrams, …)
docs/   guides/ reference/ conventions/ design/ validation/ theory/ … (see docs/index.md)
test/   Tiered suite (fast / ci / oracles / integration / full / physics)
dashboard/  React + WebGPU dashboard frontend
ext/    CUDA, Makie, HTTP and VTK extensions
scripts/    cli.jl and one-off audit drivers
bench/  Benchmarks
```

Each Hamiltonian term (kinetic, trap, Zeeman, contact, dipolar, LHY, tensor,
Raman, light shift, Coriolis, magnetic gradient, loss) is one unit that
declares its sign convention exactly once, in a single coefficient function
that its three faces — the propagator, the energy and the gradient — are all
written from. A single declaration is not by itself a proof that all three
agree, so the guarantee is carried by gates rather than by the shape of the
code: a finite-difference oracle differences every registry slot's gradient
against its own energy — every slot but the non-Hermitian loss term, and it
asserts that coverage itself rather than leaving it to be read off — a
per-term GPU/CPU parity check runs each term alone
so that a term contributing zero to the aggregate cannot hide a missing
kernel, and a master oracle compares the whole production stack against an
independently written reference implementation. That reference deliberately
restates physics the fast path already states — duplication is the point when
it is gated, and the thing to avoid is duplication nothing compares.
`docs/conventions/` documents the discipline, including the sign × path audit
table and the checklist for adding a term.

`docs/reference/yaml_schema_reference.md` is the full YAML schema.
`docs/index.md` is the documentation map; subsystem design notes live under
`docs/design/`, and `CLAUDE.md` records the internal conventions and
architectural boundaries the code is held to.

## Tests

```bash
SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'

# Parallel across CPU cores (N independent julia processes).
# ~2× faster on a 4-core box, more on bigger ones.
SPINORBEC_TEST_WORKERS=auto SPINORBEC_TEST_TIER=fast \
    julia --project=. -e 'using Pkg; Pkg.test()'
```

Tiers: `fast` (unit tests only), `ci` (fast + ITP/RTP integration),
`full` (everything; default) and `physics` (analytic validation only), plus
two derived views of the same files — `oracles` (the cross-checking gates:
sign conventions, GPU/CPU parity per term, energy-vs-gradient consistency)
and `integration` (the rest of `ci`: ground state, split-step, simulation,
config/experiment plumbing). Membership is listed explicitly in
`test/_tiers.jl`: a new test is added to a tier by hand rather than picked up
by discovery, so nothing joins or leaves a tier silently.

Per-push CI runs `fast`, `oracles` and `integration` as three parallel jobs,
which between them cover the whole `ci` tier without any one job paying for it
serially. That the three still cover `ci` is itself a test —
`test_tier_membership.jl` reads the tiers back out of the workflow file, so
deleting a job turns the suite red instead of quietly shrinking coverage. The
nightly workflow runs `full` with `SPINORBEC_RUN_HEAVY_YAML=true` to also cover
the gated YAML integration blocks.

Runner knobs (all read by `test/runtests.jl`):

- `SPINORBEC_TEST_WORKERS` — `1` (default, serial in-process) or `N` / `auto`
  (`auto` = one process per CPU thread). In parallel mode N independent julia
  processes take files **on demand** from a shared claim queue, heaviest
  first, and are aggregated by exit code. On demand rather than pre-assigned
  because per-file times swing ±30 % run to run, so static bin-packing left
  the makespan 8–21 % above the perfect-balance floor however well the cost
  model was fitted. Both modes share one per-file run/fail path
  (`test/_run_files.jl`): every file runs under its own testset, all files run
  (one failure never hides another), and the run exits non-zero iff anything
  failed. Parallelism is why each test file has to be a standalone unit — its
  own `using`, its own `@__DIR__` helpers, no `/tmp` path shared with a
  sibling.
- `SPINORBEC_TEST_SKIP` — comma-separated relative paths to omit (e.g.
  CUDA-importing oracles on a machine whose driver probe crashes the
  precompiler).
- `SPINORBEC_TEST_TIMING=quiet` — suppress the per-file timing table that
  otherwise prints at the end of every run.
- `SPINORBEC_TEST_TIMEOUT` — per-worker wall-clock cap in seconds under
  parallelism (default 1800; `0` disables). A hung worker is killed and
  reported as failed rather than stalling the whole suite; any file it had
  claimed but not finished is listed by name, so a timeout cannot silently
  turn into "that file passed".

## What a test here is allowed to claim

This code predicts things nobody has measured — ¹⁵¹Eu at $F=6$ has seven
unknown scattering channels, and computing that phase diagram is the reason the
code exists. "Compare against the answer" is therefore unavailable, so
correctness has to come from somewhere else. `docs/conventions/testing_strategy.md`
is the authority; the short version is that every test declares which of five
grounding methods it uses — `exact` (a closed form computed inside the test),
`order` (the error *scales* at the theoretical rate under refinement),
`invariant`, `metamorphic` (an observable transforms correctly under a
symmetry), `differential` (two independent statements of the same physics
agree) — and that two common things are *not* grounding: a `pin` (a number a
past run happened to produce) and an `api` check (a spelling). Pins are worth
having, since they detect change and change is often a bug, but a pin may not
be the only test defending a piece of physics.

Two instruments keep that honest rather than aspirational:

- `julia test/_inventory.jl` — a one-second source scan that labels every test
  file with what it grounds, so the split between real validation and pins is
  a measured number instead of a matter of taste.
- `julia --project=. test/mutation/run.jl` — a catalog of defects that actually
  happened here, each reduced to the smallest edit that reproduces its shape
  and re-injected into `src/` to ask which test goes red. A mutant nothing
  catches is a gap ranked by how bad the physics error is; a test file that
  catches nothing is a deletion candidate on evidence. It refuses to start on
  a dirty `src/`, restores in a `finally`, and re-checks `git diff` at the end
  — but it edits the real working tree, so any other julia process in the same
  worktree will read the injected defect while it runs. Give it a worktree to
  itself. Cost is one precompile per mutant, so it is an on-demand/nightly
  tool, not a PR gate.

The unit of coverage is the pair (claim, path), not the claim: a term is right
in one place and wrong in another far more often than it is wrong everywhere.
The paths are `registry`, `fused` (spin-chain), `gpu`, gradient/LBFGS, `yaml`
(parser defaults), `dumb` (the reference RHS), padded vs bare, and `f32`.
